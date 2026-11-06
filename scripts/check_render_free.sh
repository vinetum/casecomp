#!/usr/bin/env bash
# Local-only acceptance. Does not create a Render service or paid resource.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if [[ "$(uname -s)" == Darwin ]]; then
  check_python=.venv-mac/bin/python
else
  check_python=.venv/bin/python
fi
if [[ ! -x "$check_python" ]]; then echo 'Run the application installer first.' >&2; exit 1; fi
# An aborted installation/check must not leave an older pass report behind.
rm -f artifacts/render_free_cgroup_check.json
if ! command -v docker >/dev/null 2>&1; then echo 'Install and open Docker Desktop (Personal/education free usage), then retry. This script does not purchase or deploy anything.' >&2; exit 1; fi
cgroup_driver="$(docker info --format '{{.CgroupDriver}}')"
if [[ "$cgroup_driver" == none ]]; then echo 'Cannot enforce the strict test: this Docker daemon has no cgroup driver. Use Docker Desktop or a rootful cgroup-enabled local Linux Docker daemon.' >&2; exit 1; fi
"$check_python" -m pip install -r backend/requirements-browser.txt
"$check_python" -m playwright install chromium
docker build -t shiftwise-demo:prepared .
"$check_python" scripts/test_container.py --memory 512m --cpus 0.1 --startup-timeout 900 --restarts 2 --report artifacts/render_free_cgroup_check.json
echo 'Finished. Read artifacts/render_free_cgroup_check.json; strict_container_test_passed must be true.'
