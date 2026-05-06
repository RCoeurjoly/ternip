#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/../.." && pwd)"
cd "$repo_root"

basejump_stl="${BASEJUMP_STL:?set BASEJUMP_STL to a BaseJump STL checkout}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for gate2 parity runner"
  exit 1
fi

python3 scripts/gate2/run_gate2_tmatmul_parity.py \
  --basejump-stl "$basejump_stl" \
  "$@"
