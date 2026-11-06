#!/bin/bash
cd "$(dirname "$0")" || exit 1
bash scripts/check_render_free.sh
result=$?
if [ "$result" -ne 0 ]; then echo 'Resource test did not pass. Read the error above; no Render service was created.'; fi
read -r -p 'Press Return to close. '
exit "$result"
