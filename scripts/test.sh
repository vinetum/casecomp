#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/shiftwise-mpl}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/shiftwise-cache}"
.venv/bin/python -m pytest tests -q --junitxml=artifacts/test_results.xml
npm run build --prefix frontend
