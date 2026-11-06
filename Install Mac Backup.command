#!/bin/bash
cd "$(dirname "$0")" || exit 1
bash scripts/install_mac.sh
result=$?
if [ "$result" -ne 0 ]; then echo 'Installation did not finish. Read the error above and LOCAL_BACKUP_GUIDE.md.'; fi
read -r -p 'Press Return to close this window. '
exit "$result"
