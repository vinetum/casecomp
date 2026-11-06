"""Clean-image production acceptance with ephemeral credentials and pinned local TLS.
No Render service is created. Secrets/certificates stay in a temporary directory.
"""

import concurrent.futures, hashlib, http.client, json, os, ssl, subprocess, tempfile, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlencode
import httpx
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
DOCKER = ["docker", "--host=unix:///var/run/docker.sock"]
NAME = "shiftwise-production-check"


def cmd(*args, **kw):
    return subprocess.check_output(list(args), text=True, **kw).strip()


checks = []
with tempfile.TemporaryDirectory(prefix="shiftwise-production-") as directory:
    tmp = Path(directory)
    import secrets

    password = secrets.token_urlsafe(24)
    signing = secrets.token_urlsafe(48)
    env = tmp / "runtime.env"
    env.write_text(
        "SHIFTWISE_ENV=production\nSHIFTWISE_DEMO_PASSWORD="
        + password
        + "\nSHIFTWISE_SESSION_SECRET="
        + signing
        + "\nSHIFTWISE_ALLOWED_HOSTS=127.0.0.1,localhost\n"
    )
    env.chmod(0o600)
    # Ephemeral CA and an IP/DNS-valid leaf. Python verifies the CA chain; Chromium
    # trusts only this leaf SPKI pin, not arbitrary invalid certificates.
    quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-days",
            "1",
            "-keyout",
            str(tmp / "ca.key"),
            "-out",
            str(tmp / "ca.crt"),
            "-subj",
            "/CN=SHIFTWISE local acceptance CA",
        ],
        check=True,
        **quiet,
    )
    subprocess.run(
        [
            "openssl",
            "req",
            "-new",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(tmp / "leaf.key"),
            "-out",
            str(tmp / "leaf.csr"),
            "-subj",
            "/CN=localhost",
        ],
        check=True,
        **quiet,
    )
    (tmp / "ext.cnf").write_text(
        "subjectAltName=IP:127.0.0.1,DNS:localhost\nextendedKeyUsage=serverAuth\n"
    )
    subprocess.run(
        [
            "openssl",
            "x509",
            "-req",
            "-in",
            str(tmp / "leaf.csr"),
            "-CA",
            str(tmp / "ca.crt"),
            "-CAkey",
            str(tmp / "ca.key"),
            "-CAcreateserial",
            "-out",
            str(tmp / "leaf.crt"),
            "-days",
            "1",
            "-extfile",
            str(tmp / "ext.cnf"),
        ],
        check=True,
        **quiet,
    )
    pub = subprocess.check_output(
        ["openssl", "x509", "-in", str(tmp / "leaf.crt"), "-pubkey", "-noout"]
    )
    der = subprocess.check_output(
        ["openssl", "pkey", "-pubin", "-outform", "DER"], input=pub
    )
    import base64

    pin = base64.b64encode(hashlib.sha256(der).digest()).decode()

    def cleanup():
        subprocess.run(
            DOCKER + ["rm", "-f", NAME],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    cleanup()
    try:
        invalid_name = NAME + "-missing"
        try:
            invalid = subprocess.run(
                DOCKER
                + [
                    "run",
                    "--rm",
                    "--name",
                    invalid_name,
                    "--network",
                    "none",
                    "--read-only",
                    "--tmpfs",
                    "/tmp",
                    "shiftwise-demo:prepared",
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )
            assert (
                invalid.returncode != 0
                and "Production requires" in invalid.stderr + invalid.stdout
            )
            checks.append(
                "Production image exits on missing required secrets/hostname before serving requests"
            )
        finally:
            subprocess.run(
                DOCKER + ["rm", "-f", invalid_name],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        started = time.monotonic()
        subprocess.run(
            DOCKER
            + [
                "run",
                "-d",
                "--name",
                NAME,
                "--read-only",
                "--tmpfs",
                "/tmp:rw,nosuid,noexec,size=128m",
                "--tmpfs",
                "/app/artifacts:rw,nosuid,noexec,size=32m,uid=10001,gid=10001",
                "--cpus",
                "1",
                "--memory",
                "1g",
                "--pids-limit",
                "128",
                "--env-file",
                str(env),
                "-p",
                "127.0.0.1:18080:10000",
                "shiftwise-demo:prepared",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        for _ in range(180):
            try:
                with httpx.Client(trust_env=False) as probe:
                    if (
                        probe.get(
                            "http://127.0.0.1:18080/healthz", timeout=3
                        ).status_code
                        == 200
                    ):
                        break
            except httpx.HTTPError:
                pass
            time.sleep(1)
        else:
            raise RuntimeError(
                "Container readiness failed; inspect the local container log"
            )
        startup = time.monotonic() - started
        assert cmd(*DOCKER, "exec", NAME, "id", "-u") == "10001"
        subprocess.run(
            DOCKER
            + ["exec", NAME, "sh", "-c", "test ! -w /app/comp_FactShiftDemand.csv"],
            check=True,
        )
        checks.append(
            "Clean Docker startup as uid 10001 with read-only source/image and bounded memory/CPU/PIDs"
        )

        class Proxy(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def handle(self):
                try:
                    super().handle()
                except (BrokenPipeError, ConnectionResetError):
                    pass  # Browser closed an idle test TLS connection.

            def log_message(self, *args):
                pass

            def do_GET(self):
                self.forward()

            def do_POST(self):
                self.forward()

            def forward(self):
                data = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                headers = {
                    k: v
                    for k, v in self.headers.items()
                    if k.lower() not in ["connection", "transfer-encoding"]
                }
                headers["X-Forwarded-Proto"] = "https"
                headers["X-Forwarded-For"] = "127.0.0.1"
                upstream = http.client.HTTPConnection("127.0.0.1", 18080, timeout=90)
                upstream.request(
                    self.command,
                    self.path,
                    body=data if data else None,
                    headers=headers,
                )
                response = upstream.getresponse()
                body = response.read()
                self.send_response(response.status)
                for k, v in response.getheaders():
                    if k.lower() not in [
                        "connection",
                        "transfer-encoding",
                        "content-length",
                    ]:
                        self.send_header(k, v)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                upstream.close()

        server = ThreadingHTTPServer(("127.0.0.1", 18443), Proxy)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(tmp / "leaf.crt", tmp / "leaf.key")
        server.socket = tls.wrap_socket(server.socket, server_side=True)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        url = "https://127.0.0.1:18443"
        origin = {"Origin": url}
        context = ssl.create_default_context(cafile=str(tmp / "ca.crt"))
        with httpx.Client(
            base_url=url, verify=context, trust_env=False, timeout=90
        ) as c:
            assert c.get("/api/bootstrap").status_code == 401
            assert c.get("/", follow_redirects=False).status_code == 303
            assert (
                c.post(
                    "/login",
                    data={"password": password},
                    headers={"Origin": "https://evil.test"},
                ).status_code
                == 403
            )
            r = c.post("/login", data={"password": password}, headers=origin)
            assert r.status_code == 303
            assert all(
                x in r.headers["set-cookie"]
                for x in ["HttpOnly", "Secure", "SameSite=strict"]
            )
            assert c.get("/api/bootstrap").status_code == 200
            for path in [
                "/data/raw/v_ShiftHistory.csv",
                "/artifacts/TEAM_SUBMISSION_COMPLETED.csv",
                "/v_ShiftHistory.csv",
                "/docs",
                "/openapi.json",
                "/backend/app.py",
                "/%2e%2e/comp_FactShiftDemand.csv",
            ]:
                assert c.get(path).status_code == 404, (path, c.get(path).status_code)
            assert (
                c.post(
                    "/api/decision", json={}, headers={"Origin": "https://evil.test"}
                ).status_code
                == 403
            )
            assert (
                c.post("/api/decision", content="x" * 4097, headers=origin).status_code
                == 413
            )
            assert (
                c.get("/api/bootstrap", headers={"Host": "evil.test"}).status_code
                == 400
            )
            preflight = c.post("/api/demo/preflight", headers=origin).json()
            assert preflight["ready"]
            for d in preflight["scenes"]:
                assert d["certificate"]["independent_verification"]["valid"]
            csv = c.get("/api/export").content
            assert (
                hashlib.sha256(csv).hexdigest()
                == "910ee279b0f25a720623051b54aebbc4b1148d8b0c0caffa1e6cbc01823bebe6"
            )
            (ROOT / "artifacts/production_download.csv").write_bytes(csv)
            checks.append(
                "CA-verified local HTTPS: session cookie, CSRF, hostname, payload limits and raw-source/OpenAPI denial"
            )
            checks.append(
                "Four official live scenario/marginal decisions, solver feasibility, and byte-identical audited HTTP CSV"
            )
        errors = []
        with sync_playwright() as pw:
            browser = pw.chromium.launch(
                executable_path="/usr/bin/chromium",
                headless=True,
                args=["--no-sandbox", "--ignore-certificate-errors-spki-list=" + pin],
            )
            page = browser.new_page(viewport={"width": 1600, "height": 1100})
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(url)
            assert page.get_by_role(
                "heading", name="Competition demo access"
            ).is_visible()
            page.get_by_label("Password", exact=True).fill(password)
            page.get_by_role("button", name="Open the demo", exact=True).click()
            page.locator('.result[aria-busy="false"]').wait_for(timeout=15000)
            page.get_by_role("button", name="Start guided demo", exact=True).click()
            page.locator('.result[aria-busy="false"]').wait_for()
            for step in range(1, 5):
                page.locator(".guide-progress button").nth(step).click()
                page.locator('.result[aria-busy="false"]').wait_for()
                assert page.locator(f'[data-demo-step="{step}"]').is_visible()
            with page.expect_download() as download:
                page.get_by_role(
                    "button", name="Download 567-row official plan", exact=True
                ).click()
            assert (
                hashlib.sha256(Path(download.value.path()).read_bytes()).hexdigest()
                == hashlib.sha256(csv).hexdigest()
            )
            page.get_by_role("button", name="Close guided demo", exact=True).click()
            page.get_by_role("button", name="Scenario Lab", exact=True).click()
            page.get_by_label("Demand multiplier", exact=True).focus()
            page.keyboard.press("Home")
            page.keyboard.press("ArrowRight")
            page.get_by_label("Available workforce", exact=True).focus()
            page.keyboard.press("Home")
            for _ in range(16):
                page.keyboard.press("ArrowRight")
            with page.expect_response(
                lambda r: r.url.endswith("/api/decision") and r.request.method == "POST"
            ) as custom:
                page.get_by_role("button", name="Recalculate", exact=True).click()
            custom_result = custom.value.json()
            assert custom_result["selection"]["availability_factor"] == 0.8
            assert custom_result["selection"]["demand_factor"] == 0.75
            page.locator('.result[aria-busy="false"]').wait_for()
            page.route(
                "**/api/decision",
                lambda r: r.fulfill(
                    status=503,
                    content_type="application/json",
                    body='{"detail":"injected production timeout"}',
                ),
            )
            page.get_by_role("button", name="BASE", exact=True).click()
            page.get_by_role("alert").wait_for()
            assert page.locator(".result").count() == 0
            assert page.get_by_role(
                "heading", name="Official week reference · no new recommendation"
            ).is_visible()
            page.unroute("**/api/decision")
            page.get_by_role("button", name="Retry calculation", exact=True).click()
            page.locator('.result[aria-busy="false"]').wait_for(timeout=15000)
            page.get_by_role("button", name="Lock demo", exact=True).click()
            page.get_by_role("heading", name="Competition demo access").wait_for()
            assert not errors, errors
            browser.close()
        checks.append(
            "Production Chromium login, five guided scenes, real demand/availability recalculation, timeout/retry, CSV download and logout; no page exceptions"
        )
        server.shutdown()
        result = {
            "passed": True,
            "startup_seconds": startup,
            "checks": checks,
            "public_site_live": False,
            "image": "shiftwise-demo:prepared",
            "public_tls_verified": False,
            "tls_test": "Ephemeral local CA verified by httpx; Chromium trusts only the generated leaf SPKI. Render public TLS is not tested until deployment.",
        }
        (ROOT / "artifacts/production_acceptance.json").write_text(
            json.dumps(result, indent=2)
        )
        print(json.dumps(result, indent=2))
    finally:
        cleanup()
