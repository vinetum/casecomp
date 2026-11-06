#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/shiftwise-mpl}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/shiftwise-cache}"
if [[ ! -f frontend/dist/index.html ]]; then npm run build --prefix frontend; fi
exec "${SHIFTWISE_PYTHON:-.venv/bin/python}" -m uvicorn backend.app:app --host "${HOST:-127.0.0.1}" --port "${PORT:-8000}"
