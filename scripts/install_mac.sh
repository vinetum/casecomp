#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This installer is for macOS. Use scripts/install.sh on Linux.' >&2; exit 1
fi
backup_python=""
for candidate in /Library/Frameworks/Python.framework/Versions/3.12/bin/python3.12 python3.12; do
  if command -v "$candidate" >/dev/null 2>&1; then backup_python="$(command -v "$candidate")"; break; fi
done
if [[ -z "$backup_python" ]]; then echo 'Install Python 3.12 from python.org, then double-click this installer again.' >&2; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo 'Install Node.js 24 LTS from nodejs.org, then try again.' >&2; exit 1; fi
"$backup_python" -c 'import sys; assert sys.version_info[:2] == (3,12), "Python 3.12 is required"'
node -e 'if(Number(process.versions.node.split(".")[0])<22){throw Error("Install Node.js 24 LTS")}'
echo 'Preparing your Mac backup. Keep this window open. This first installation requires Internet access.'
"$backup_python" -m venv .venv-mac
.venv-mac/bin/python -m pip install -r backend/requirements.lock
npm ci --prefix frontend --no-audit --no-fund
npm run build --prefix frontend
MPLCONFIGDIR="${TMPDIR:-/tmp}/shiftwise-mpl" .venv-mac/bin/python -m scripts.export --team-id SHIFTWISE
.venv-mac/bin/python -m scripts.validate_submission
echo 'Installation and submission validation passed. You can now double-click Start SHIFTWISE.command without Internet.'
