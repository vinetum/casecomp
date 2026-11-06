# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim AS frontend
WORKDIR /build/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi; \
    npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build

FROM python:3.12-slim-bookworm AS python-deps
WORKDIR /build
COPY backend/requirements.lock ./
RUN python -m venv /opt/venv
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then export PIP_CERT=/run/secrets/proxy_ca; fi; \
    /opt/venv/bin/python -m pip install --no-cache-dir -r requirements.lock

FROM python:3.12-slim-bookworm AS runtime
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 \
    MPLCONFIGDIR=/tmp/shiftwise-mpl XDG_CACHE_HOME=/tmp/shiftwise-cache \
    OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 \
    MALLOC_ARENA_MAX=2 PORT=10000 SHIFTWISE_ENV=production
WORKDIR /app
COPY --from=python-deps /opt/venv /opt/venv
COPY backend/ backend/
COPY data/raw/ data/raw/
# These originals are required by the independent source audit; none are static-served.
COPY *.csv ./
COPY --from=frontend /build/frontend/dist frontend/dist
COPY deployment/start.sh deployment/start.sh
COPY deployment/resource_probe.py deployment/resource_probe.py
RUN groupadd --gid 10001 demo && useradd --uid 10001 --gid demo --no-create-home demo \
    && mkdir -p /app/artifacts && chown demo:demo /app/artifacts \
    && chmod -R a+rX /app && chmod +x deployment/start.sh
USER 10001:10001
EXPOSE 10000
HEALTHCHECK --start-period=600s --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','10000')+'/healthz',timeout=3)" || exit 1
CMD ["/app/deployment/start.sh"]
