import asyncio, os, time
from dataclasses import replace
from unittest.mock import patch
import pytest
from fastapi.testclient import TestClient
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from backend.security import DemoBoundary, Settings, COOKIE
from backend.runtime_budget import DEADLINE, solver_seconds


@pytest.fixture
def settings():
    import secrets

    return Settings(
        production=True,
        password=secrets.token_urlsafe(24),
        secret=secrets.token_urlsafe(48),
        hosts=("demo.test",),
    )


def boundary(settings):
    async def ok(request):
        return JSONResponse({"ok": True})

    return DemoBoundary(
        Starlette(
            routes=[
                Route("/api/decision", ok, methods=["POST"]),
                Route("/api/bootstrap", ok),
                Route("/healthz", ok),
            ]
        ),
        settings,
    )


def login(c, s):
    return c.post(
        "/login",
        data={"password": s.password},
        headers={"Origin": "https://demo.test"},
        follow_redirects=False,
    )


def test_production_fails_closed():
    with patch.dict(os.environ, {"SHIFTWISE_ENV": "production"}, clear=True):
        with pytest.raises(ValueError):
            Settings.from_env()


def test_auth_cookie_headers_and_raw_files(settings):
    with TestClient(boundary(settings), base_url="https://demo.test") as c:
        assert c.get("/api/bootstrap").status_code == 401
        assert c.get("/").url.path == "/login"
        assert (
            c.get("/data/raw/v_ShiftHistory.csv", follow_redirects=False).status_code
            == 303
        )
        r = login(c, settings)
        assert r.status_code == 303
        cookie = r.headers["set-cookie"]
        assert all(v in cookie for v in ["HttpOnly", "Secure", "SameSite=strict"])
        r = c.get("/api/bootstrap")
        assert r.status_code == 200
        assert (
            r.headers["x-frame-options"] == "DENY"
            and "frame-ancestors 'none'" in r.headers["content-security-policy"]
        )
        assert "no-store" in r.headers["cache-control"]
        assert c.get("/data/raw/v_ShiftHistory.csv").status_code == 404
        assert (
            c.post(
                "/logout",
                headers={"Origin": "https://demo.test"},
                follow_redirects=False,
            ).status_code
            == 303
        )
        assert c.get("/api/bootstrap").status_code == 401


def test_bad_hosts_http_csrf_and_size(settings):
    with TestClient(boundary(settings), base_url="https://demo.test") as c:
        assert c.get("/", headers={"Host": "attacker.test"}).status_code == 400
        assert c.get("/healthz").status_code == 200
        assert (
            c.post(
                "/login",
                data={"password": settings.password},
                headers={"Origin": "https://attacker.test"},
            ).status_code
            == 403
        )
        login(c, settings)
        assert (
            c.post(
                "/api/decision", json={}, headers={"Origin": "https://evil.test"}
            ).status_code
            == 403
        )
        assert c.post("/api/decision", json={}).status_code == 403
        assert (
            c.post(
                "/api/decision",
                content=b"x" * 4097,
                headers={"Origin": "https://demo.test"},
            ).status_code
            == 413
        )
        assert (
            c.post(
                "/api/decision",
                content=iter([b"x" * 3000, b"y" * 3000]),
                headers={"Origin": "https://demo.test"},
            ).status_code
            == 413
        )
        assert (
            c.options(
                "/api/decision", headers={"Origin": "https://evil.test"}
            ).status_code
            == 405
        )
    with TestClient(
        boundary(settings), base_url="http://demo.test", follow_redirects=False
    ) as c:
        r = c.get("/")
        assert r.status_code == 307 and r.headers["location"].startswith(
            "https://demo.test"
        )


def test_forged_expired_tickets_and_rotation(settings):
    b = boundary(settings)
    ticket = b.ticket()
    assert b.valid(ticket)
    assert not b.valid(ticket[:-1] + ("1" if ticket[-1] != "1" else "2"))
    with patch(
        "backend.security.time.time",
        return_value=time.time() + settings.session_seconds + 1,
    ):
        assert not b.valid(ticket)
    assert not boundary(replace(settings, secret=settings.secret + "rotate")).valid(
        ticket
    )
    assert not boundary(replace(settings, password=settings.password + "rotate")).valid(
        ticket
    )


def test_quotas(settings):
    with TestClient(
        boundary(replace(settings, login_limit=2)), base_url="https://demo.test"
    ) as c:
        for _ in range(2):
            assert (
                c.post(
                    "/login",
                    data={"password": "wrong"},
                    headers={"Origin": "https://demo.test"},
                ).status_code
                == 401
            )
        assert login(c, settings).status_code == 429
    with TestClient(
        boundary(replace(settings, calculation_limit=1)), base_url="https://demo.test"
    ) as c:
        login(c, settings)
        assert (
            c.post(
                "/api/decision", json={}, headers={"Origin": "https://demo.test"}
            ).status_code
            == 200
        )
        assert (
            c.post(
                "/api/decision", json={}, headers={"Origin": "https://demo.test"}
            ).status_code
            == 429
        )


def test_busy_engine_and_deadline(settings):
    b = boundary(settings)
    with TestClient(b, base_url="https://demo.test") as c:
        login(c, settings)
        b.calculation._locked = True
        assert (
            c.post(
                "/api/decision", json={}, headers={"Origin": "https://demo.test"}
            ).status_code
            == 503
        )
        b.calculation._locked = False
    token = DEADLINE.set(time.monotonic() - 1)
    try:
        with pytest.raises(RuntimeError):
            solver_seconds()
    finally:
        DEADLINE.reset(token)


def test_parallel_calculations_have_no_queue(settings):
    import httpx

    active = 0
    maximum = 0

    async def slow(request):
        nonlocal active, maximum
        active += 1
        maximum = max(maximum, active)
        try:
            await asyncio.sleep(0.1)
            return JSONResponse({"ok": True})
        finally:
            active -= 1

    b = DemoBoundary(
        Starlette(routes=[Route("/api/decision", slow, methods=["POST"])]), settings
    )

    async def exercise():
        async with httpx.AsyncClient(
            transport=httpx.ASGITransport(app=b), base_url="https://demo.test"
        ) as c:
            c.cookies.set(COOKIE, b.ticket())
            replies = await asyncio.gather(
                *(
                    c.post(
                        "/api/decision",
                        json={},
                        headers={"Origin": "https://demo.test"},
                    )
                    for _ in range(2)
                )
            )
            assert sorted(r.status_code for r in replies) == [200, 503]

    asyncio.run(exercise())
    assert maximum == 1 and not b.calculation.locked()


def test_global_signin_budget_cannot_be_reset_with_new_ip(settings):
    b = boundary(settings)
    with TestClient(b, base_url="https://demo.test") as c:
        # Populate the aggregate budget independently of the per-IP key.
        for _ in range(20):
            assert b.quota(("login-global", "all"), 20)
        assert login(c, settings).status_code == 429


def test_slow_request_body_times_out(settings):
    b = boundary(replace(settings, body_seconds=0.01))
    messages = []

    async def receive():
        await asyncio.sleep(0.1)
        return {"type": "http.request", "body": b"{}", "more_body": False}

    async def send(message):
        messages.append(message)

    scope = {
        "type": "http",
        "method": "POST",
        "path": "/api/decision",
        "scheme": "https",
        "headers": [(b"host", b"demo.test"), (b"origin", b"https://demo.test")],
        "client": ("127.0.0.1", 1),
    }
    asyncio.run(b(scope, receive, send))
    assert messages[0]["status"] == 408


def test_production_module_import_rejects_missing_secrets():
    import subprocess, sys

    environment = os.environ.copy()
    environment["SHIFTWISE_ENV"] = "production"
    for name in [
        "SHIFTWISE_DEMO_PASSWORD",
        "SHIFTWISE_SESSION_SECRET",
        "SHIFTWISE_ALLOWED_HOSTS",
        "RENDER_EXTERNAL_HOSTNAME",
    ]:
        environment.pop(name, None)
    result = subprocess.run(
        [sys.executable, "-c", "import backend.app"],
        env=environment,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0 and "Production requires" in result.stderr
