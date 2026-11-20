#!/usr/bin/env bash
set -euo pipefail
solution_dir="$(cd "$(dirname "$0")" && pwd)"
cp "$solution_dir/aes128.sv" /app/aes128.sv
