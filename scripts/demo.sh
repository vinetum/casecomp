#!/usr/bin/env bash
# Local/offline runtime: dependencies must already be installed.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/start.sh &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
.venv/bin/python - <<'PY'
import os,time,json,urllib.request
url='http://127.0.0.1:'+os.environ.get('PORT','8000')
for _ in range(120):
    try:
        with urllib.request.urlopen(url+'/api/health',timeout=3) as r:
            if json.load(r)['submission_valid']:break
    except OSError:time.sleep(1)
else:raise SystemExit('Readiness failed; inspect server output')
request=urllib.request.Request(url+'/api/demo/preflight',method='POST')
with urllib.request.urlopen(request,timeout=90) as r:assert json.load(r)['ready']
print('SHIFTWISE demo ready on port '+os.environ.get('PORT','8000')+'. Four live decision scenes warmed. No Internet services required.',flush=True)
PY
wait "$server_pid"
