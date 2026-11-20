"""Evaluate a single SystemVerilog artifact in an isolated verifier."""

import json
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


TESTS = Path(__file__).resolve().parent
CELL_LIMIT = 5100
FLIP_FLOP_LIMIT = 720
RANDOM_BLOCKS = 12
STREAM_BLOCKS = 16
SEED = 0xA3512802
KATS = (
    ("000102030405060708090a0b0c0d0e0f", "00112233445566778899aabbccddeeff",
     "69c4e0d86a7b0430d8cdb78070b4c55a"),
    ("0" * 32, "0" * 32, "66e94bd4ef8a2c3b884cfa59ca342b2e"),
    ("2b7e151628aed2a6abf7158809cf4f3c", "3243f6a8885a308d313198a2e0370734",
     "3925841d02dc09fbdc118597196a0b32"),
)
SUITES = {
    "encrypt": len(KATS) + RANDOM_BLOCKS, "decrypt": len(KATS) + RANDOM_BLOCKS,
    "warm": 8, "overlap": 6, "reset": 2, "stream": STREAM_BLOCKS,
}
PORTS = {
    "clk": ("input", 1), "rst_n": ("input", 1), "in_valid": ("input", 1),
    "in_ready": ("output", 1), "in_decrypt": ("input", 1),
    "in_key": ("input", 128), "in_block": ("input", 128),
    "out_valid": ("output", 1), "out_ready": ("input", 1), "out_block": ("output", 128),
}
COMBINATIONAL = {
    "$_BUF_", "$_NOT_", "$_AND_", "$_NAND_", "$_OR_", "$_NOR_", "$_XOR_",
    "$_XNOR_", "$_ANDNOT_", "$_ORNOT_", "$_MUX_", "$_NMUX_", "$_AOI3_",
    "$_OAI3_", "$_AOI4_", "$_OAI4_",
}
FLIP_FLOP = re.compile(r"\$_(?:DFF_P|DFFE_P[PN]|SDFF_P[PN][01]|SDFF(?:E|CE)_P[PN][01][PN])_")


def run(command, cwd, timeout, deadline):
    timeout = min(timeout, deadline - time.monotonic())
    if timeout <= 0:
        return 124, "Verifier time budget exhausted"
    try:
        result = subprocess.run(command, cwd=cwd, timeout=timeout, check=False,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                encoding="utf-8", errors="replace")
    except subprocess.TimeoutExpired:
        return 124, f"Timed out after {timeout:g}s"
    return result.returncode, result.stdout


def openssl_block(key, block, decrypt=False):
    result = subprocess.run(
        ["openssl", "enc", "-d" if decrypt else "-e", "-aes-128-ecb",
         "-K", key.hex(), "-nosalt", "-nopad"],
        input=block, capture_output=True, timeout=5, check=True,
    )
    if len(result.stdout) != 16:
        raise RuntimeError("OpenSSL did not return a single AES block")
    return result.stdout


def vector_row(key, plaintext):
    ciphertext = openssl_block(key, plaintext)
    if openssl_block(key, ciphertext, decrypt=True) != plaintext:
        raise RuntimeError("OpenSSL inverse check failed")
    return key.hex() + plaintext.hex() + ciphertext.hex()


def make_vectors(path):
    for k, p, expected in KATS:
        if vector_row(bytes.fromhex(k), bytes.fromhex(p)) != k + p + expected:
            raise RuntimeError("OpenSSL self-check against the known answers failed")

    rng = random.Random(SEED)
    rows = ["".join(vector) for vector in KATS]
    for index in range(RANDOM_BLOCKS):
        key, plaintext = rng.randbytes(16), rng.randbytes(16)
        if index % 12 == 10:
            key = bytes(16)
        elif index % 12 == 11:
            plaintext = b"\xff" * 16
        rows.append(vector_row(key, plaintext))
    base = int.from_bytes(rng.randbytes(16), "big")
    keys = [base ^ delta for delta in (0, 1, 0, 1 << 127, 1 << 63, 0)]
    for index in range(STREAM_BLOCKS):
        key = keys[(index // 2) % len(keys)].to_bytes(16, "big")
        rows.append(vector_row(key, rng.randbytes(16)))
    path.write_text("\n".join(rows) + "\n", encoding="ascii")


def source_error(path):
    if not path.is_file() or path.is_symlink():
        return "missing regular aes128.sv"
    if not 0 < path.stat().st_size <= 256 * 1024:
        return "expected 1 to 262144 bytes"
    try:
        source = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return "source must be UTF-8"
    if re.search(r"\btranslate_(?:off|on)\b", source, re.IGNORECASE):
        return "synthesis exclusion directive"
    code = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)
    if chr(96) in code or '"' in code:
        return "preprocessor directive or string literal"
    modules = re.findall(r"\bmodule\s+(\w+)", code)
    if modules != ["aes128"] or len(re.findall(r"\bendmodule\b", code)) != 1:
        return "expected exactly one aes128 module"
    if re.search(r"\b(?:initial|final|force|release|bind|specify|primitive|DPI)\b", code):
        return "unsupported simulation construct"
    system_functions = set(re.findall(r"(?<![\w$])\$[A-Za-z_]\w*", code))
    system_functions -= {"$clog2", "$bits", "$signed", "$unsigned"}
    if system_functions:
        return "unsupported system function " + ", ".join(sorted(system_functions))
    return None


def mapped_error(netlist):
    modules = netlist.get("modules", {})
    if set(modules) != {"aes128"}:
        return "expected one flattened aes128 top"
    top = modules["aes128"]
    ports = {
        name: (port["direction"], len(port["bits"]))
        for name, port in top["ports"].items()
    }
    if ports != PORTS:
        return "mapped port names, directions, or widths differ"
    for name in ("in_key", "in_block", "out_block"):
        port = top["ports"][name]
        if port.get("upto", 0) or port.get("offset", 0):
            return f"{name} must be indexed [127:0]"

    clock = top["ports"]["clk"]["bits"]
    for cell in top["cells"].values():
        kind = cell["type"]
        if kind in COMBINATIONAL:
            continue
        if not FLIP_FLOP.fullmatch(kind):
            return f"unsupported mapped primitive {kind}"
        if cell["connections"]["C"] != clock:
            return "mapped flip-flop not clocked directly by clk"
    return None


def simulate(view, source, cwd, logs, checks, deadline):
    image = f"{view}.vvp"
    status, transcript = run(
        ["iverilog", "-g2012", "-s", "aes128_tb", "-o", image, source,
         str(TESTS / "aes128_tb.sv")], cwd, 20, deadline,
    )
    (logs / f"{view}.compile.log").write_text(transcript, encoding="utf-8")
    if status:
        checks[f"{view}_compile"] = {"pass": False, "detail": transcript[-1200:].strip()}
        return
    checks[f"{view}_compile"] = {"pass": True}
    for suite, blocks in SUITES.items():
        status, transcript = run(
            ["vvp", image, f"+suite={suite}"], cwd, 60 if view == "gate" else 30, deadline,
        )
        (logs / f"{view}.{suite}.log").write_text(transcript, encoding="utf-8")
        marker = re.search(
            rf"^TB_PASS suite={suite} blocks={blocks} max_latency=(\d+) warm_max_latency=(\d+)$",
            transcript, re.M,
        )
        passed = status == 0 and marker is not None
        check = {"pass": passed}
        if passed:
            check["blocks"] = blocks
            if suite != "stream":
                check["max_latency"] = int(marker[1])
            if suite == "warm":
                check["warm_max_latency"] = int(marker[2])
        else:
            failure = next((line.split("TB_FAIL ", 1)[1] for line in transcript.splitlines()
                            if "TB_FAIL " in line), transcript[-500:].strip())
            check["detail"] = failure or f"vvp exited {status} without a pass marker"
        checks[f"{view}_{suite}"] = check


def grade(candidate, logs, deadline):
    checks = {}
    error = source_error(candidate)
    checks["source_contract"] = {"pass": error is None}
    if error:
        checks["source_contract"]["detail"] = error
        return checks

    with tempfile.TemporaryDirectory(prefix="aes128-grader-") as temp:
        cwd = Path(temp)
        shutil.copyfile(candidate, cwd / "aes128.sv")
        make_vectors(cwd / "vectors.mem")
        simulate("rtl", "aes128.sv", cwd, logs, checks, deadline)

        script = ("read_verilog -sv aes128.sv; synth -flatten -top aes128; "
                  "check -assert; write_json mapped.json; write_verilog -noattr mapped.v")
        status, transcript = run(["yosys", "-Q", "-T", "-p", script], cwd, 45, deadline)
        (logs / "yosys.log").write_text(transcript, encoding="utf-8")
        checks["synthesis"] = {"pass": status == 0}
        if status:
            checks["synthesis"]["detail"] = transcript[-1200:].strip()
            return checks

        netlist = json.loads((cwd / "mapped.json").read_text(encoding="utf-8"))
        error = mapped_error(netlist)
        checks["mapped_structure"] = {"pass": error is None}
        if error:
            checks["mapped_structure"]["detail"] = error
            return checks
        mapped_cells = netlist["modules"]["aes128"]["cells"].values()
        cells = len(mapped_cells)
        flip_flops = sum(FLIP_FLOP.fullmatch(cell["type"]) is not None for cell in mapped_cells)
        checks["cell_budget"] = {"pass": cells <= CELL_LIMIT, "cells": cells, "limit": CELL_LIMIT}
        checks["flip_flop_budget"] = {
            "pass": flip_flops <= FLIP_FLOP_LIMIT, "flip_flops": flip_flops, "limit": FLIP_FLOP_LIMIT,
        }
        simulate("gate", "mapped.v", cwd, logs, checks, deadline)
    return checks


def main():
    candidate, logs = map(Path, sys.argv[1:])
    logs.mkdir(parents=True, exist_ok=True)
    (logs / "reward.txt").write_text("0\n", encoding="ascii")
    started = time.monotonic()
    checks = grade(candidate, logs, started + 225)
    reward = int(bool(checks) and all(result["pass"] for result in checks.values()))
    result = {"reward": reward, "checks": checks, "grader_seconds": round(time.monotonic() - started, 3)}
    (logs / "grade.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    (logs / "reward.txt").write_text(f"{reward}\n", encoding="ascii")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
