#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
.venv/bin/python - <<'PY'
import os,json,urllib.request,io,pandas as pd
from backend.verify import validate_submission
url='http://127.0.0.1:'+os.environ.get('PORT','8000')
with urllib.request.urlopen(url+'/api/health',timeout=10) as r:assert json.load(r)['submission_valid']
with urllib.request.urlopen(urllib.request.Request(url+'/api/demo/preflight',method='POST'),timeout=90) as r:
    result=json.load(r);assert result['ready'] and len(result['scenes'])==4
with urllib.request.urlopen(url+'/api/export',timeout=10) as r:frame=pd.read_csv(io.StringIO(r.read().decode()))
assert validate_submission(frame)['valid']
print('PASS: local readiness, four live solved scenes, and validated 567-row HTTP export')
PY
