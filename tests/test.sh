#!/usr/bin/env bash
set -euo pipefail
mkdir -p /logs/verifier
printf '0\n' >/logs/verifier/reward.txt
tests_dir="$(cd "$(dirname "$0")" && pwd)"
python3 "$tests_dir/grade.py" /app/aes128.sv /logs/verifier
