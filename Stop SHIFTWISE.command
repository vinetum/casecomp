#!/bin/bash
cd "$(dirname "$0")" || exit 1
if [ -x .venv-mac/bin/python ]; then .venv-mac/bin/python -m deployment.local_backup stop; fi
read -r -p 'Press Return to close. '
