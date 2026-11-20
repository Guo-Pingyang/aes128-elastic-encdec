#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build

simulate() {
    local source="$1" view="$2"
    if ! iverilog -g2012 -s smoke -o "build/$view.vvp" "$source" smoke.sv \
        >"build/$view.compile.log" 2>&1; then
        tail -30 "build/$view.compile.log" >&2
        return 1
    fi
    timeout 15s vvp "build/$view.vvp"
}

synthesize() {
    if ! timeout 45s yosys -Q -T -p 'read_verilog -sv aes128.sv; synth -flatten -top aes128; check -assert; write_json build/mapped.json; write_verilog -noattr build/mapped.v' \
        >build/yosys.log 2>&1; then
        tail -30 build/yosys.log >&2
        return 1
    fi
    python3 - <<'PY'
import json
with open("build/mapped.json") as handle:
    top = json.load(handle)["modules"]["aes128"]
cells = top["cells"]
flip_flops = sum("DFF" in cell["type"] for cell in cells.values())
print(f"Mapped cells: {len(cells)}")
print(f"Mapped flip-flops: {flip_flops}")
PY
}

case "${1:-rtl}" in
    rtl) simulate aes128.sv rtl ;;
    area) synthesize ;;
    gate)
        synthesize
        simulate build/mapped.v gate
        ;;
    *) printf 'Usage: %s [rtl|gate|area]\n' "$0" >&2; exit 2 ;;
esac
