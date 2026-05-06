#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/gate1/run_gate1_smoke.sh <model-id>"
  echo
  echo "Example:"
  echo "  scripts/gate1/run_gate1_smoke.sh matmulfree/hgrnbit_370m"
  exit 1
fi

MODEL_ID="$1"
shift

if [[ ! -d .venv ]]; then
  echo "Creating local virtual environment at .venv"
  python3 -m venv .venv
  source .venv/bin/activate
  python3 -m pip install -q --upgrade pip
  python3 -m pip install -r scripts/gate1/requirements-gate1.txt
else
  source .venv/bin/activate
fi

python3 scripts/gate1/run_gate1_smoke.py \
  --model-id "$MODEL_ID" \
  "$@"
