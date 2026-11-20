#!/usr/bin/env python3
"""Evaluate Codex models with Bash tools and grading isolated by Bubblewrap."""

import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from sandbox_tools import (
    MAX_TURNS,
    SECONDS_PER_TRIAL,
    TASK,
    append_event,
    execute,
    execute_shell,
    feedback,
    json_file,
    sandbox,
)


MODELS = ("gpt-6.1-terra",)
TOOL_NAME = "trial_terminal"
TOOL_INSTRUCTIONS = (
    "Use the trial_terminal Bash tool to read, edit, and test the files in /app. "
    "Files in /app persist, and /tmp is recreated for each call. "
    f"Each call starts in /app. You have up to {MAX_TURNS} Bash calls "
    "and 25 seconds per call. Make all changes to the actual submission file "
    "in /app and return a brief summary when finished."
)
BASH_TOOL = {
    "name": "bash",
    "description": "Run a Bash command in the isolated AES-128 task directory /app.",
    "inputSchema": {
        "type": "object",
        "properties": {"command": {"type": "string"}},
        "required": ["command"],
        "additionalProperties": False,
    },
}


def serve_terminal(directory, bwrap):
    app = directory / "app"
    (app / "check.sh").chmod(0o755)
    agent = sandbox(bwrap, [(app, "/app", True)])
    status, output = execute_shell(
        agent, "test -w . && test -x check.sh && test ! -e /tests && "
        "test ! -e /solution && test ! -e /mnt/c && command -v yosys && "
        "command -v iverilog", 10,
    )
    if status:
        raise SystemExit(f"Terminal sandbox check failed: {output}")
    append_event(directory / "trajectory.jsonl", {"type": "terminal_ready"})

    calls = 0
    for line in sys.stdin:
        request = json.loads(line)
        if "id" not in request:
            continue
        method = request["method"]
        params = request.get("params", {})
        response = {"jsonrpc": "2.0", "id": request["id"]}
        if method == "initialize":
            result = {
                "protocolVersion": params["protocolVersion"],
                "serverInfo": {"name": TOOL_NAME, "version": "1.0.0"},
                "capabilities": {"tools": {}},
                "instructions": TOOL_INSTRUCTIONS,
            }
        elif method == "ping":
            result = {}
        elif method in ("resources/list", "resources/templates/list", "prompts/list"):
            key = method.split("/")[0] if method != "resources/templates/list" else "resourceTemplates"
            result = {key: []}
        elif method == "tools/list":
            result = {"tools": [BASH_TOOL]}
        elif method == "tools/call" and params.get("name") == "bash":
            command = params.get("arguments", {}).get("command")
            if not isinstance(command, str) or not command.strip() or "\x00" in command:
                result = {"content": [{"type": "text", "text": "Provide a nonempty Bash command."}], "isError": True}
            elif calls >= MAX_TURNS:
                result = {"content": [{"type": "text", "text": "The Bash call budget is exhausted."}], "isError": True}
            else:
                calls += 1
                status, output = execute_shell(agent, command, 25)
                append_event(directory / "trajectory.jsonl", {
                    "type": "shell", "step": calls, "command": command,
                    "status": status, "output": output,
                })
                result = {"content": [{"type": "text", "text": feedback(status, output)}]}
        else:
            response["error"] = {"code": -32601, "message": "Method not found"}
            print(json.dumps(response), flush=True)
            continue
        response["result"] = result
        print(json.dumps(response), flush=True)


def verify_submission(directory, bwrap):
    artifact = directory / "app/aes128.sv"
    logs = directory / "verifier"
    logs.mkdir()
    with tempfile.TemporaryDirectory(prefix="aes128-gpt-submission-") as temp:
        submission = Path(temp)
        try:
            info = artifact.lstat()
        except FileNotFoundError:
            info = None
        if info and stat.S_ISREG(info.st_mode) and info.st_size <= 256 * 1024:
            shutil.copyfile(artifact, submission / "aes128.sv")
            shutil.copyfile(submission / "aes128.sv", directory / "submission.sv")
        verifier = sandbox(bwrap, [
            (submission, "/app", False),
            (TASK / "tests", "/tests", False),
            (logs, "/logs/verifier", True),
        ])
        status, output = execute(verifier + ["/usr/bin/bash", "/tests/test.sh"], 240)
        (directory / "verifier.log").write_text(output, encoding="utf-8")
    return status


def linux_path(path):
    path = path.resolve()
    if os.name != "nt":
        return str(path)
    if not re.fullmatch(r"[A-Za-z]:", path.drive):
        raise ValueError("Use a Windows drive mounted in WSL at /mnt/<drive>.")
    return f"/mnt/{path.drive[0].lower()}/" + "/".join(path.parts[1:])


def cli_command(args, model, cwd, server):
    mcp = f"mcp_servers.{TOOL_NAME}"
    config = {
        "model_reasoning_effort": args.effort,
        "approval_policy": "never",
        "web_search": "disabled",
        f"{mcp}.command": server[0],
        f"{mcp}.args": server[1:],
        f"{mcp}.required": True,
        f"{mcp}.startup_timeout_sec": 30,
        f"{mcp}.tool_timeout_sec": 35,
        f"{mcp}.default_tools_approval_mode": "approve",
    }
    command = [
        args.codex, "exec", "--json", "--ephemeral", "--ignore-user-config",
        "--ignore-rules", "--skip-git-repo-check", "--sandbox", "read-only",
        "--cd", str(cwd), "--model", model,
    ]
    for feature in ("shell_tool", "unified_exec", "view_image", "multi_agent", "multi_agent_v2", "apps", "plugins"):
        command += ["--disable", feature]
    for key, value in config.items():
        command += ["-c", f"{key}={json.dumps(value)}"]
    return command + ["-"]


def read_events(path):
    events = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def run_trial(args, model, trial, cli_version):
    directory = args.results / f"{model}-trial-{trial}"
    directory.mkdir()
    app = directory / "app"
    app.mkdir()
    cwd = directory / "codex-cwd"
    cwd.mkdir()
    for name in ("aes128.sv", "check.sh", "smoke.sv"):
        shutil.copyfile(TASK / "environment" / name, app / name)

    instruction = (TASK / "instruction.md").read_text(encoding="utf-8")
    prompt = instruction + "\n" + TOOL_INSTRUCTIONS + "\n"
    metadata = {
        "model": model,
        "provider": "codex-cli",
        "codex_cli_version": cli_version,
        "reasoning_effort": args.effort,
        "trial": trial,
        "max_shell_calls": MAX_TURNS,
        "seconds_limit": SECONDS_PER_TRIAL,
        "instruction_sha256": hashlib.sha256(instruction.encode("utf-8")).hexdigest(),
        "starter_sha256": hashlib.sha256((app / "aes128.sv").read_bytes()).hexdigest(),
    }
    json_file(directory / "config.json", metadata)
    trail = directory / "trajectory.jsonl"
    append_event(trail, {"type": "prompt", "content": prompt})
    prefix = ["wsl.exe", "-d", args.wsl_distro, "--exec"] if os.name == "nt" else []
    helper = prefix + ["/usr/bin/python3", linux_path(Path(__file__))]
    bwrap = linux_path(Path(args.bwrap)) if os.name == "nt" and Path(args.bwrap).is_file() else args.bwrap
    command = cli_command(args, model, cwd, helper + ["--terminal", linux_path(directory), "--bwrap", bwrap])
    cli_log = directory / "codex.raw.jsonl"
    cli_env = {k: v for k, v in os.environ.items() if not k.startswith(("CODEX_APP_", "CODEX_TOOL_CALL_"))}
    print(f"{directory.name}: started", flush=True)
    start = time.monotonic()
    with cli_log.open("wb") as stdout, (directory / "codex.stderr.log").open("wb") as stderr:
        try:
            result = subprocess.run(
                command, input=prompt.encode("utf-8"), stdout=stdout, stderr=stderr,
                env=cli_env, timeout=SECONDS_PER_TRIAL, check=False,
            )
            cli_exit = result.returncode
        except subprocess.TimeoutExpired:
            cli_exit = 124
    agent_seconds = round(time.monotonic() - start, 3)

    events = read_events(cli_log)
    completed = [event for event in events if event.get("type") == "turn.completed"]
    usage = completed[-1].get("usage") if completed else None
    messages = [
        event["item"].get("text", "")
        for event in events if event.get("type") == "item.completed"
        and event.get("item", {}).get("type") == "agent_message"
    ]
    if messages:
        append_event(trail, {"type": "final_message", "content": messages[-1]})
    tool_events = read_events(trail)
    shell_calls = sum(event["type"] == "shell" for event in tool_events)
    tool_ready = any(event["type"] == "terminal_ready" for event in tool_events)
    transport_closed = any(
        event.get("item", {}).get("server") == TOOL_NAME
        and "Transport closed" in str(event["item"].get("error", ""))
        for event in events
    )
    termination = "time_limit" if cli_exit == 124 else "completed"
    if not tool_ready or transport_closed or (cli_exit != 124 and (cli_exit or not completed)):
        termination = "infrastructure_error"

    grader_exit = None
    grade = None
    if termination != "infrastructure_error":
        grader = subprocess.run(
            helper + ["--verify", linux_path(directory), "--bwrap", bwrap],
            capture_output=True, check=False, timeout=270,
        )
        grader_exit = grader.returncode
        grade_file = directory / "verifier/grade.json"
        if grader_exit == 0 and grade_file.exists():
            grade = json.loads(grade_file.read_text(encoding="utf-8"))
        else:
            (directory / "verifier-helper.log").write_bytes(grader.stderr)

    candidate = directory / "submission.sv"
    result = {
        **metadata,
        "termination": termination,
        "cli_exit": cli_exit,
        "usage": usage,
        "shell_commands": shell_calls,
        "agent_seconds": agent_seconds,
        "verifier_exit": grader_exit,
        "reward": grade["reward"] if grade else None,
        "submission_sha256": hashlib.sha256(candidate.read_bytes()).hexdigest() if candidate.is_file() else None,
    }
    json_file(directory / "result.json", result)
    print(f"{directory.name}: reward={result['reward']} calls={shell_calls} stop={termination}", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--terminal", type=Path, help=argparse.SUPPRESS)
    mode.add_argument("--verify", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--bwrap", default="bwrap")
    parser.add_argument("--results", type=Path)
    parser.add_argument("--models", nargs="+", choices=MODELS, default=list(MODELS))
    parser.add_argument("--trials", type=int, nargs="+", choices=(1, 2, 3), default=[1, 2, 3])
    parser.add_argument("--effort", choices=("low", "medium", "high", "xhigh"), default="medium")
    parser.add_argument("--codex", default="codex")
    parser.add_argument("--wsl-distro", default="Ubuntu")
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()
    if args.terminal:
        serve_terminal(args.terminal, args.bwrap)
        return
    if args.verify:
        raise SystemExit(verify_submission(args.verify, args.bwrap))
    if args.results is None or args.workers < 1:
        parser.error("--results and a positive --workers value are required")
    if len(args.models) != len(set(args.models)) or len(args.trials) != len(set(args.trials)):
        parser.error("model and trial lists must contain unique values")

    version = subprocess.run(
        [args.codex, "--version"], capture_output=True, check=True, text=True, encoding="utf-8",
    ).stdout.strip()
    args.results = args.results.resolve()
    args.results.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        jobs = [pool.submit(run_trial, args, model, trial, version) for trial in args.trials for model in args.models]
        results = [job.result() for job in concurrent.futures.as_completed(jobs)]
    if any(result["reward"] is None for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
