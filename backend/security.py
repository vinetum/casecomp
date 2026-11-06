"""Single-instance competition-demo boundary: shared login, signed cookies, quotas.
This is intentionally not an enterprise identity provider or multi-instance limiter.
"""

import asyncio
from collections import OrderedDict, deque
from dataclasses import dataclass
import hashlib, hmac, html, os, secrets, time
from urllib.parse import parse_qs, urlsplit
from starlette.datastructures import Headers
from starlette.responses import HTMLResponse, JSONResponse, RedirectResponse
from .runtime_budget import DEADLINE

COOKIE = "shiftwise_session"


@dataclass(frozen=True)
class Settings:
    production: bool = False
    password: str = ""
    secret: str = ""
    hosts: tuple = ("localhost", "127.0.0.1", "testserver", "[::1]")
    session_seconds: int = 8 * 3600
    rate_limit: int = 120
    calculation_limit: int = 30
    login_limit: int = 5
    calculation_seconds: float = 30.0
    body_seconds: float = 5.0

    @classmethod
    def from_env(cls):
        mode = os.environ.get("SHIFTWISE_ENV", "local")
        if mode not in ("local", "production"):
            raise ValueError("SHIFTWISE_ENV must be local or production")
        prod = mode == "production"
        password = os.environ.get("SHIFTWISE_DEMO_PASSWORD", "")
        secret = os.environ.get("SHIFTWISE_SESSION_SECRET", "")
        hosts = os.environ.get("SHIFTWISE_ALLOWED_HOSTS") or os.environ.get(
            "RENDER_EXTERNAL_HOSTNAME"
        )
        if prod and (not 16 <= len(password) <= 256 or len(secret) < 32 or not hosts):
            raise ValueError(
                "Production requires a demo password (16–256 chars), session secret (32+ chars), and allowed hostname (or Render hostname). Values must be supplied securely in environment settings."
            )
        allowed = (
            tuple(h.strip().lower() for h in hosts.split(",")) if hosts else cls.hosts
        )
        if any("/" in h or "*" in h or not h for h in allowed):
            raise ValueError(
                "Use exact allowed hostnames without URL schemes, paths, or wildcards"
            )
        return cls(
            production=prod,
            password=password,
            secret=secret,
            hosts=allowed,
            rate_limit=120 if prod else 600,
            calculation_limit=30 if prod else 120,
        )


class DemoBoundary:
    def __init__(self, app, settings=None):
        self.app = app
        self.settings = settings or Settings.from_env()
        self.events = OrderedDict()
        self.calculation = asyncio.Lock()

    def ticket(self):
        payload = f"1.{int(time.time())+self.settings.session_seconds}.{secrets.token_hex(16)}"
        return payload + "." + self.sign(payload)

    def sign(self, payload):
        key = (
            self.settings.secret
            + hashlib.sha256(self.settings.password.encode()).hexdigest()
        ).encode()
        return hmac.new(key, payload.encode(), hashlib.sha256).hexdigest()

    def valid(self, ticket):
        if not ticket or len(ticket) > 256:
            return False
        try:
            version, expires, nonce, signature = ticket.split(".")
            now = time.time()
            end = int(expires)
            return (
                version == "1"
                and len(nonce) == 32
                and now < end <= now + self.settings.session_seconds + 5
                and hmac.compare_digest(
                    signature, self.sign(".".join((version, expires, nonce)))
                )
            )
        except (ValueError, TypeError):
            return False

    def quota(self, key, limit):
        now = time.monotonic()
        q = self.events.pop(key, deque())
        while q and q[0] <= now - 60:
            q.popleft()
        allowed = len(q) < limit
        if allowed:
            q.append(now)
        self.events[key] = q
        while len(self.events) > 2048:
            self.events.popitem(last=False)
        return allowed

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        s = self.settings
        headers = Headers(scope=scope)
        path = scope.get("path", "")
        method = scope["method"]

        async def secured(message):
            if message["type"] == "http.response.start":
                message["headers"] += [
                    (b"x-content-type-options", b"nosniff"),
                    (b"x-frame-options", b"DENY"),
                    (b"x-robots-tag", b"noindex, noarchive, nosnippet"),
                    (b"referrer-policy", b"same-origin"),
                    (b"cache-control", b"private, no-store"),
                    (
                        b"permissions-policy",
                        b"camera=(), microphone=(), geolocation=()",
                    ),
                    (
                        b"content-security-policy",
                        b"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; frame-ancestors 'none'; object-src 'none'; base-uri 'none'; form-action 'self'",
                    ),
                ]
                if s.production:
                    message["headers"].append(
                        (b"strict-transport-security", b"max-age=31536000")
                    )
            await send(message)

        async def respond(response):
            return await response(scope, receive, secured)

        host = headers.get("host", "").lower()
        # Keep IPv6 bracketed while stripping an optional port.
        hostname = (
            host.split("]")[0] + "]" if host.startswith("[") else host.split(":")[0]
        )
        if path == "/healthz":
            return await self.app(scope, receive, secured)
        if hostname not in s.hosts:
            return await respond(JSONResponse({"detail": "Unrecognized host"}, 400))
        if s.production and scope.get("scheme") != "https":
            return await respond(
                RedirectResponse(
                    "https://"
                    + host
                    + scope.get("raw_path", b"/").decode("ascii", "ignore"),
                    status_code=307,
                )
            )
        ip = (scope.get("client") or ("unknown", 0))[0]
        if not self.quota(("http", ip), s.rate_limit):
            return await respond(
                JSONResponse(
                    {"detail": "Too many requests; wait one minute."},
                    429,
                    headers={"Retry-After": "60"},
                )
            )
        if method not in ("GET", "HEAD", "POST"):
            return await respond(JSONResponse({"detail": "Method not allowed"}, 405))
        if method == "POST":
            expected = (
                ("https" if s.production else scope.get("scheme", "http"))
                + "://"
                + host
            )
            origin = headers.get("origin")
            if (s.production and origin != expected) or (
                origin is not None and origin != expected
            ):
                return await respond(
                    JSONResponse({"detail": "Cross-origin request rejected"}, 403)
                )
        body = b""
        if method == "POST":
            try:
                if int(headers.get("content-length", "0")) > 4096:
                    raise ValueError()
            except ValueError:
                return await respond(
                    JSONResponse({"detail": "Request body exceeds 4096 bytes"}, 413)
                )
            body_deadline = time.monotonic() + s.body_seconds
            while True:
                try:
                    message = await asyncio.wait_for(
                        receive(), timeout=max(0.001, body_deadline - time.monotonic())
                    )
                except asyncio.TimeoutError:
                    return await respond(
                        JSONResponse(
                            {"detail": "Request body timed out. Retry."},
                            408,
                            headers={"Connection": "close"},
                        )
                    )
                if message["type"] == "http.disconnect":
                    return
                body += message.get("body", b"")
                if len(body) > 4096:
                    return await respond(
                        JSONResponse({"detail": "Request body exceeds 4096 bytes"}, 413)
                    )
                if not message.get("more_body", False):
                    break
        delivered = False

        async def replay():
            nonlocal delivered
            if not delivered:
                delivered = True
                return {"type": "http.request", "body": body, "more_body": False}
            return await receive()

        from http.cookies import SimpleCookie

        try:
            cookies = SimpleCookie()
            cookies.load(headers.get("cookie", ""))
            ticket = cookies[COOKIE].value if COOKIE in cookies else ""
        except Exception:
            ticket = ""
        authenticated = not s.production or self.valid(ticket)
        if path == "/login":
            if not s.production:
                return await respond(RedirectResponse("/", 303))
            if method == "GET":
                return await respond(HTMLResponse(LOGIN))
            if not self.quota(("login", ip), s.login_limit) or not self.quota(
                ("login-global", "all"), 20
            ):
                return await respond(
                    JSONResponse(
                        {"detail": "Too many sign-in attempts. Wait one minute."},
                        429,
                        headers={"Retry-After": "60"},
                    )
                )
            supplied = parse_qs(body.decode("utf-8", errors="replace")).get(
                "password", [""]
            )[0]
            if not hmac.compare_digest(supplied.encode(), s.password.encode()):
                return await respond(
                    HTMLResponse(
                        LOGIN.replace(
                            "Enter the shared competition password.",
                            "Password not recognized. Please try again.",
                        ),
                        401,
                    )
                )
            response = RedirectResponse("/", 303)
            response.set_cookie(
                COOKIE,
                self.ticket(),
                httponly=True,
                secure=True,
                samesite="strict",
                max_age=s.session_seconds,
                path="/",
            )
            return await respond(response)
        if path == "/logout" and method == "POST":
            response = RedirectResponse("/login" if s.production else "/", 303)
            response.delete_cookie(
                COOKIE, path="/", secure=s.production, httponly=True, samesite="strict"
            )
            return await respond(response)
        if not authenticated:
            if path.startswith("/api/"):
                return await respond(
                    JSONResponse(
                        {"detail": "Sign in to access the competition demo."}, 401
                    )
                )
            return await respond(RedirectResponse("/login", 303))
        if path == "/api/session":
            return await respond(JSONResponse({"protected": s.production}))
        heavy = path in ("/api/decision", "/api/demo/preflight") and method == "POST"
        token = None
        if heavy:
            identity = hashlib.sha256((ticket or ip).encode()).hexdigest()
            if not self.quota(("compute", identity), s.calculation_limit) or (
                s.production and not self.quota(("compute-global", "all"), 60)
            ):
                return await respond(
                    JSONResponse(
                        {"detail": "Calculation limit reached; wait one minute."},
                        429,
                        headers={"Retry-After": "60"},
                    )
                )
            if self.calculation.locked():
                return await respond(
                    JSONResponse(
                        {"detail": "A calculation is already running. Retry shortly."},
                        503,
                        headers={"Retry-After": "2"},
                    )
                )
            await self.calculation.acquire()
            token = DEADLINE.set(time.monotonic() + s.calculation_seconds)
        try:
            await self.app(scope, replay if method == "POST" else receive, secured)
        finally:
            if token is not None:
                DEADLINE.reset(token)
                self.calculation.release()


LOGIN = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SHIFTWISE · Competition access</title><style>body{margin:0;background:#102f37;color:#dfede8;font:16px system-ui;display:grid;min-height:100vh;place-items:center}main{max-width:420px;margin:25px;padding:35px;background:#183e46;border:1px solid #42746d;border-radius:14px}h1{letter-spacing:3px}p{line-height:1.7;color:#b4ccc6}label{display:block;margin:24px 0}input,button{box-sizing:border-box;width:100%;padding:14px;border-radius:6px;font:inherit}input{margin-top:10px;border:1px solid #8bb5a9}button{background:#9be0bf;color:#123d33;border:0;font-weight:650}small{display:block;line-height:1.7;margin-top:24px;color:#9ab7af}</style></head><body><main><h1>SHIFTWISE</h1><p>Workforce resilience command center</p><h2>Competition demo access</h2><p>Enter the shared competition password.</p><form method="post" action="/login"><label>Password<input type="password" name="password" autocomplete="current-password" required maxlength="256" autofocus></label><button type="submit">Open the demo</button></form><small>Simulated case information. Access is intended for the presenting team and authorized judges. Do not share the password publicly.</small></main></body></html>"""
