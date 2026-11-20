#!/usr/bin/env python3
"""Run independent terminal-agent attempts against the task without Docker.

Only the agent directory is mounted into its shell. The verifier receives a
copy of the submitted RTL in a fresh, separate bubblewrap namespace.
"""

import argparse
import concurrent.futures
import hashlib
import html
import http.client
import json
import os
import re
import shutil
import stat
import tempfile
import time
import urllib.error
import urllib.request
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

SHELL_PROMPT = """You are a terminal coding agent working in /app. Your goal is
to finish the task by editing the actual submission file. You can run shell
commands to read files, test, and make edits. The terminal is Linux Bash with
Python 3, Icarus, and Yosys. Each reply should contain exactly one fenced bash
block with a command. The command will run from /app and you will receive its
exit status and output. Commands may contain multiple lines. When you are
finished with your edits and checks, reply with only DONE. Do not just describe
the proposed changes. Only commands in the fenced block can modify files.
Files in /app persist across calls. The /tmp directory is recreated each time."""
MAX_TOKENS = 12000
TOKENS_PER_TURN = 4000
TEMPERATURE = 0.35
TOP_P = 0.95
SEEDS = (101, 202, 303)
FENCE = re.compile(r"```(?:bash|sh|shell)?[ \t]*\r?\n(.*?)```", re.S | re.I)
DEEPSEEK_COMMAND = re.compile(
    r'<｜｜DSML｜｜ invoke name="bash">\s*'
    r'<｜｜DSML｜｜ parameter name="command" string="true">(.*?)</｜｜DSML｜｜ parameter>\s*'
    r'</｜｜DSML｜｜ invoke>', re.S,
)
DEEPSEEK = "https://api.deepseek.com/chat/completions"
TOOL_PROMPT = """You are a terminal coding agent working in /app. Finish the task
by editing the actual submission file. Use the bash tool to inspect, edit, and
test the files. Each call runs a fresh Bash shell from /app. Files in /app
persist across calls. /tmp is recreated for each call. Call the tool at most
once per reply. When done, reply with a brief summary."""
BASH_TOOL = {
    "type": "function",
    "function": {
        "name": "bash",
        "description": "Run a Bash command in the isolated task directory /app.",
        "parameters": {
            "type": "object",
            "properties": {"command": {"type": "string"}},
            "required": ["command"],
            "additionalProperties": False,
        },
    },
}



class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def complete(args, key, messages, trial, budget, deadline):
    payload = {
        "model": args.model, "messages": messages,
        "temperature": TEMPERATURE, "top_p": TOP_P,
        "max_tokens": min(TOKENS_PER_TURN, budget), "stream": False,
    }
    headers = {"Content-Type": "application/json"}
    if args.provider == "deepseek":
        endpoint = DEEPSEEK
        headers["Authorization"] = f"Bearer {key}"
        payload["thinking"] = {"type": "disabled"}
        payload["tools"] = [BASH_TOOL]
    else:
        endpoint = f"http://127.0.0.1:{args.port}/v1/chat/completions"
        payload.update(seed=SEEDS[trial - 1], top_k=0, min_p=0.0)
    request = urllib.request.Request(
        endpoint, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST",
    )
    if args.provider == "deepseek":
        opener = urllib.request.build_opener(NoRedirect)
    else:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect)
    timeout = min(180, max(1, deadline - time.monotonic()))
    with opener.open(request, timeout=timeout) as response:
        result = json.load(response)
    choice = result["choices"][0]
    return (choice["message"], choice.get("finish_reason"),
            result.get("usage", {}), result.get("model"), result.get("id"))


def shell_command(content):
    # Some DeepSeek completions emit the provider's textual tool envelope
    # even when the prompt requests a fenced command.
    calls = DEEPSEEK_COMMAND.findall(content)
    if len(calls) == 1:
        return html.unescape(calls[0]).strip()
    blocks = FENCE.findall(content)
    return blocks[0].strip() if len(blocks) == 1 else None


FORMAT_FEEDBACK = "No command ran. Send one fenced bash block, or DONE after editing the file."


def restore_trial(trail, messages, agent):
    """Replay completed commands into a fresh workdir after an interrupted client."""
    replies = tokens = 0
    for line in trail.read_text(encoding="utf-8").splitlines():
        event = json.loads(line)
        if event["type"] == "reply":
            replies += 1
            tokens += event["usage"].get("completion_tokens", 0)
            message = {"role": "assistant", "content": event["content"]}
            if event.get("tool_calls"):
                message["tool_calls"] = event["tool_calls"]
            messages.append(message)
        elif event["type"] == "shell":
            status, _ = execute_shell(agent, event["command"], 25)
            if status != event["status"]:
                raise RuntimeError(f"shell replay changed exit status at step {event['step']}")
            response = {"role": "user", "content": feedback(event["status"], event["output"])}
            if event.get("tool_call_id"):
                response.update(role="tool", tool_call_id=event["tool_call_id"])
            messages.append(response)
        elif event["type"] == "format_error":
            if event.get("tool_call_id"):
                messages.append({"role": "tool", "tool_call_id": event["tool_call_id"],
                                 "content": "Submit one valid Bash tool call per reply."})
            else:
                messages.append({"role": "user", "content": event.get("observation", FORMAT_FEEDBACK)})
    return replies, tokens


def run_trial(args, key, trial):
    name = f"{args.label}-trial-{trial}"
    directory = args.results / name
    directory.mkdir(exist_ok=args.resume)
    trail = directory / "trajectory.jsonl"
    started = time.monotonic()
    deadline = started + SECONDS_PER_TRIAL
    instruction = (TASK / "instruction.md").read_text(encoding="utf-8")
    messages = [
        {"role": "system", "content": TOOL_PROMPT if args.provider == "deepseek" else SHELL_PROMPT},
        {"role": "user", "content": instruction},
    ]
    metadata = {
        "model": args.model, "provider": args.provider, "trial": trial,
        "temperature": TEMPERATURE, "top_p": TOP_P, "max_turns": MAX_TURNS,
        "completion_token_budget": MAX_TOKENS, "tokens_per_reply": TOKENS_PER_TURN,
        "seconds_limit": SECONDS_PER_TRIAL,
        "thinking": "disabled" if args.provider == "deepseek" else None,
        "adapter": "bash-function" if args.provider == "deepseek" else "bash-fence-or-dsml-v2",
        "seed": SEEDS[trial - 1] if args.provider == "local" else None,
        "instruction_sha256": hashlib.sha256(instruction.encode("utf-8")).hexdigest(),
        "starter_sha256": hashlib.sha256((TASK / "environment/aes128.sv").read_bytes()).hexdigest(),
        "shell_seconds_limit": 25,
    }
    if args.resume:
        if (directory / "result.json").exists() or not trail.is_file():
            raise RuntimeError(f"{name}: expected an interrupted trial")
        if json.loads((directory / "config.json").read_text(encoding="utf-8")) != metadata:
            raise RuntimeError(f"{name}: resume configuration differs")
    else:
        json_file(directory / "config.json", metadata)
        append_event(trail, {"type": "prompt", "messages": messages})
    print(f"{name}: {'resuming' if args.resume else 'started'}", flush=True)
    output_tokens = 0
    stop = "turn_limit"
    replies = 0
    api_error = None
    with tempfile.TemporaryDirectory(prefix="aes128-agent-") as temp:
        scratch = Path(temp)
        app = scratch / "app"
        shutil.copytree(TASK / "environment", app, ignore=shutil.ignore_patterns("Dockerfile"))
        (app / "check.sh").chmod(0o755)
        agent = sandbox(args.bwrap, [(app, "/app", True)])
        if args.resume:
            replies, output_tokens = restore_trial(trail, messages, agent)
            append_event(trail, {"type": "transport_resume", "completed_turns": replies})
        for step in range(replies + 1, MAX_TURNS + 1):
            if time.monotonic() >= deadline:
                stop = "time_limit"
                break
            if output_tokens >= MAX_TOKENS:
                stop = "token_limit"
                break
            for attempt in range(2):
                try:
                    message, finish_reason, usage, model, request_id = complete(
                        args, key, messages, trial, MAX_TOKENS - output_tokens, deadline,
                    )
                    api_error = None
                    break
                except (urllib.error.URLError, http.client.HTTPException, TimeoutError,
                        ValueError, KeyError, IndexError) as error:
                    status = getattr(error, "code", None)
                    api_error = {"kind": type(error).__name__, "http_status": status}
                    append_event(trail, {"type": "inference_error", "step": step,
                                         "attempt": attempt + 1, **api_error})
                    if status is not None and status < 500 and status != 429:
                        break
                    if time.monotonic() >= deadline:
                        break
            if api_error:
                stop = "inference_error"
                break
            content = message.get("content") or ""
            tool_calls = message.get("tool_calls") or []
            replies += 1
            output_tokens += usage.get("completion_tokens", 0)
            append_event(trail, {
                "type": "reply", "step": step, "content": content, "finish_reason": finish_reason,
                "usage": usage, "reported_model": model, "request_id": request_id,
                **({"tool_calls": tool_calls} if tool_calls else {}),
            })
            if tool_calls:
                messages.append({"role": "assistant", "content": content, "tool_calls": tool_calls})
                for index, call in enumerate(tool_calls):
                    function = call.get("function", {})
                    try:
                        arguments = json.loads(function.get("arguments", ""))
                    except (ValueError, TypeError):
                        arguments = {}
                    command = arguments.get("command") if isinstance(arguments, dict) else None
                    if index or function.get("name") != "bash" or not isinstance(command, str) or not command.strip() or "\x00" in command:
                        observation = "Submit one valid Bash tool call per reply."
                        append_event(trail, {"type": "format_error", "step": step, "tool_call_id": call["id"]})
                    else:
                        status, output = execute_shell(
                            agent, command, min(25, max(1, deadline - time.monotonic())),
                        )
                        observation = feedback(status, output)
                        append_event(trail, {
                            "type": "shell", "step": step, "command": command,
                            "status": status, "output": output, "tool_call_id": call["id"],
                        })
                    messages.append({"role": "tool", "tool_call_id": call["id"], "content": observation})
                continue
            if content.strip() == "DONE" or (
                args.provider == "deepseek" and finish_reason == "stop"
                and content.strip() and not shell_command(content)
            ):
                stop = "done"
                break
            messages.append({"role": "assistant", "content": content})
            command = shell_command(content)
            if command:
                status, output = execute_shell(
                    agent, command, min(25, max(1, deadline - time.monotonic())),
                )
                append_event(trail, {"type": "shell", "step": step, "command": command,
                                     "status": status, "output": output})
                observation = feedback(status, output)
            else:
                observation = (
                    "Your reply was truncated. Continue by using one Bash tool call to edit or test the file."
                    if args.provider == "deepseek" and finish_reason == "length" else FORMAT_FEEDBACK
                )
                append_event(trail, {"type": "format_error", "step": step, "observation": observation})
            messages.append({"role": "user", "content": observation})

        artifact = app / "aes128.sv"
        submission = scratch / "submission"
        submission.mkdir()
        candidate = directory / "submission.sv"
        try:
            info = artifact.lstat()
        except FileNotFoundError:
            info = None
        if info and stat.S_ISREG(info.st_mode) and info.st_size <= 256 * 1024:
            shutil.copyfile(artifact, candidate)
            shutil.copyfile(candidate, submission / "aes128.sv")

        verifier_logs = directory / "verifier"
        verifier_logs.mkdir()
        verifier = sandbox(args.bwrap, [
            (submission, "/app", False), (TASK / "tests", "/tests", False),
            (verifier_logs, "/logs/verifier", True),
        ])
        status, output = execute(verifier + ["/usr/bin/bash", "/tests/test.sh"], 240)
        (directory / "verifier.log").write_text(output, encoding="utf-8")

    grade_path = verifier_logs / "grade.json"
    grade = json.loads(grade_path.read_text(encoding="utf-8")) if status == 0 and grade_path.exists() else None
    result = {
        **metadata, "termination": stop, "replies": replies, "completion_tokens": output_tokens,
        "agent_seconds": round(time.monotonic() - started - (grade or {}).get("grader_seconds", 0), 3),
        "resumed": args.resume,
        "inference_error": api_error, "verifier_exit": status,
        "reward": grade["reward"] if grade else None,
        "submission_sha256": hashlib.sha256(candidate.read_bytes()).hexdigest() if candidate.exists() else None,
    }
    json_file(directory / "result.json", result)
    print(f"{name}: reward={result['reward']} stop={stop} replies={replies}", flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", required=True, choices=["deepseek", "local"])
    parser.add_argument("--model", required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--results", required=True, type=Path)
    parser.add_argument("--bwrap", default="bwrap")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--key-file", type=Path)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--resume", action="store_true", help="replay and resume interrupted trial logs")
    parser.add_argument("--trials", type=int, nargs="+", default=[1, 2, 3], choices=[1, 2, 3])
    args = parser.parse_args()
    if not re.fullmatch(r"[a-zA-Z0-9_-]+", args.label):
        parser.error("invalid label")
    key = None
    if args.provider == "deepseek":
        if args.model not in {"deepseek-flash", "deepseek-v4-pro"}:
            parser.error("DeepSeek adapter supports deepseek-flash and deepseek-v4-pro")
        key = (args.key_file.read_text(encoding="utf-8").strip() if args.key_file
               else os.environ.get("DEEPSEEK_API_KEY", ""))
        if not key or any(ch.isspace() for ch in key):
            parser.error("provide a valid DeepSeek credential with --key-file or DEEPSEEK_API_KEY")
    args.results = args.results.resolve()
    args.results.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda trial: run_trial(args, key, trial), args.trials))
    if any(result["reward"] is None or result["inference_error"] for result in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
