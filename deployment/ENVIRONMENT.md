# Runtime configuration (no secret values in this repository)

| Variable | Render / production | Local Mac |
|---|---|---|
| `SHIFTWISE_ENV` | `production` (Docker default; never set `local` on a public service) | Launcher forces `local` |
| `SHIFTWISE_DEMO_PASSWORD` | Required, 16–256 characters; shared only with authorized judges/team; set securely in Render | Not needed; loopback only |
| `SHIFTWISE_SESSION_SECRET` | Required, at least 32 random characters; Blueprint generates it securely | Not needed |
| `RENDER_EXTERNAL_HOSTNAME` | Render injects the actual service hostname; used as exact allowed Host | Not used |
| `SHIFTWISE_ALLOWED_HOSTS` | Optional exact comma-separated hostnames, without schemes, paths or wildcards; overrides Render hostname. Required for a non-Render production deployment or a custom domain. Include the Render hostname too if retaining it. | Defaults to localhost/127.0.0.1/testserver/[::1] |
| `PORT` | Render supplies the listening port; Docker defaults to 10000 | Default 8000; Mac launcher validates 1024–65535 |
| `HOST` | Not used by Docker entrypoint; listens internally on 0.0.0.0 | 127.0.0.1; keep this for laptop backup |
| `SHIFTWISE_PYTHON` | Not used in Docker | Mac launcher selects its dedicated .venv-mac Python |
| `MALLOC_ARENA_MAX` | 2, bounds glibc allocator arenas in the Linux image | Not required for native Mac |
| `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS` | Set to 1 in image; bound numerical-library parallelism | Optional |

Production fails closed at startup if the required password, signing secret or hostname is missing. Never put secrets in Docker build arguments, `render.yaml`, source files, screenshots, URLs, or the browser bundle. Rotating either production secret invalidates existing sessions. No Render token, GitHub token or external model API key is required by the running app.

Runtime limits are intentionally fixed in `backend/security.py`: 120 HTTP requests/minute/IP, 5 sign-in attempts/minute/IP and 20 total sign-in attempts/minute, 30 expensive requests/minute/session and 60 total expensive requests/minute; one expensive calculation at a time, no application calculation queue; 4096-byte POST bodies with a five-second total body-read timeout; 30-second total HTTP calculation budget checked before each CP-SAT phase, 15-second maximum per phase. Uvicorn has one worker, 24 concurrent connections, backlog 32, five-second idle keepalive and 35-second shutdown grace. A busy engine returns 503/Retry-After; quota exhaustion returns 429. Do not horizontally scale without a shared rate limiter and capacity design.

Sessions expire after eight hours; cookies are signed, HttpOnly, Secure and SameSite=Strict. The shared-password model does not provide individual accounts, MFA or per-user revocation. Lock demo clears the browser cookie; rotate a secret to revoke all tickets. HTTP /healthz exposes only readiness and is public for Render health probes. UI assets, APIs, CSV export and model/history data require authentication. No raw datasets or source documents are mounted as public static files. CORS is not enabled; production POST requests require an exact same-origin Origin header. Render's HTTPS ingress is required; direct public access to the internal Docker port is unsupported.

The Blueprint selects **Free / $0** and intentionally omits numInstances/scaling, disks and databases. Numerical threads remain one; the application thread pool is bounded to four and the decision cache to 64 selections. The production web engine skips offline Matplotlib PNG generation only; the live calibration chart and all models remain available. CLI exports still generate the original diagnostic artifacts. Sleep/restart regenerates models from original bundled sources, and cookies remain valid until expiry when secrets stay constant. See `FREE_TIER_READINESS.md` for measured resource scope and the outstanding kernel-cgroup test. Do not disable authentication to work around a slow cold start.
