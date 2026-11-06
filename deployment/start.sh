#!/bin/sh
set -eu
# Render terminates TLS and forwards traffic to this sole application process.
# Trust forwarded headers only in this private container behind Render's ingress.
exec python -m uvicorn backend.app:app --host 0.0.0.0 --port "${PORT:-10000}" \
  --workers 1 --lifespan on --proxy-headers --forwarded-allow-ips '*' \
  --limit-concurrency 24 --backlog 32 --timeout-keep-alive 5 --timeout-graceful-shutdown 35
