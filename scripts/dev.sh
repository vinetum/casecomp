#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/shiftwise-mpl}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/shiftwise-cache}"
.venv/bin/python -m uvicorn backend.app:app --host 0.0.0.0 --port 8000 --reload &
backend_pid=$!
trap 'kill "$backend_pid" 2>/dev/null || true' EXIT
npm run dev --prefix frontend
