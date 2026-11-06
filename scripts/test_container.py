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
import sys

DOCKER = (
    ["docker"]
    if sys.platform == "darwin"
    else ["docker", "--host=unix:///var/run/docker.sock"]
)
NAME = "shiftwise-production-check"


def cmd(*args, **kw):
    return subprocess.check_output(list(args), text=True, **kw).strip()


import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--cpus", default="1")
parser.add_argument("--memory", default="1g")
parser.add_argument("--startup-timeout", type=int, default=180)
parser.add_argument("--restarts", type=int, default=0)
parser.add_argument("--software-probe", action="store_true")
parser.add_argument("--report", default="artifacts/production_acceptance.json")
args = parser.parse_args()
report_path = ROOT / args.report
# A failed rerun must never leave a previous successful result looking current.
report_path.write_text(
    json.dumps(
        {
            "passed": False,
            "strict_container_test_passed": False,
            "status": "Test started but has not completed successfully; consult terminal output",
            "public_site_live": False,
        },
        indent=2,
    )
)
if (
    not args.software_probe
    and cmd(*DOCKER, "info", "--format", "{{.CgroupDriver}}") == "none"
):
    report_path.write_text(
        json.dumps(
            {
                "passed": False,
                "strict_container_test_passed": False,
                "status": "BLOCKED: Docker cgroup driver is none; requested CPU/RAM limits are not enforced",
                "public_site_live": False,
            },
            indent=2,
        )
    )
    raise SystemExit(
        "STRICT RESOURCE TEST BLOCKED: this daemon has no cgroup driver. Docker --memory/--cpus are not enforced. Use cgroup-enabled Docker or explicitly select the separately labeled --software-probe test."
    )
checks = []


def probe_sample():
    return json.loads(
        cmd(*DOCKER, "exec", NAME, "cat", "/app/artifacts/resource_probe.json")
    )


def memory_sample():
    if args.software_probe:
        return probe_sample()["conservative_sum_peak_rss_bytes"]
    return int(cmd(*DOCKER, "exec", NAME, "cat", "/sys/fs/cgroup/memory.peak"))


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
                *(["--no-healthcheck"] if args.software_probe else []),
                "--tmpfs",
                "/tmp:rw,nosuid,noexec,size=128m",
                "--tmpfs",
                "/app/artifacts:rw,nosuid,noexec,size=32m,uid=10001,gid=10001",
                "--cpus",
                args.cpus,
                "--memory",
                args.memory,
                "--memory-swap",
                args.memory,
                "--pids-limit",
                "128",
                "--env-file",
                str(env),
                "-p",
                "127.0.0.1:18080:10000",
                *(
                    ["-e", "PROBE_CPUS=" + args.cpus, "--entrypoint", "python"]
                    if args.software_probe
                    else []
                ),
                "shiftwise-demo:prepared",
                *(["/app/deployment/resource_probe.py"] if args.software_probe else []),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )
        for iteration in range(args.startup_timeout):
            if iteration % 10 == 0:
                state = json.loads(
                    cmd(*DOCKER, "inspect", "--format", "{{json .State}}", NAME)
                )
                if not state["Running"]:
                    logs = cmd(*DOCKER, "logs", "--tail", "25", NAME)
                    raise RuntimeError("Application exited before readiness: " + logs)
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
        kernel_memory = cmd(*DOCKER, "exec", NAME, "cat", "/sys/fs/cgroup/memory.max")
        kernel_swap = cmd(
            *DOCKER, "exec", NAME, "cat", "/sys/fs/cgroup/memory.swap.max"
        )
        kernel_cpu = cmd(*DOCKER, "exec", NAME, "cat", "/sys/fs/cgroup/cpu.max")
        expected_memory = 512 * 1024**2 if args.memory == "512m" else 1024**3
        quota, period = kernel_cpu.split()
        cgroups_verified = (
            kernel_memory == str(expected_memory)
            and kernel_swap == "0"
            and quota != "max"
            and abs(int(quota) / int(period) - float(args.cpus)) < 0.0001
        )
        if not args.software_probe and not cgroups_verified:
            raise RuntimeError(
                "Docker resource flags are NOT kernel-enforced in this environment. Use a cgroup-enabled runner for the strict test. --software-probe is explicitly a different, per-process test."
            )
        startup_memory = memory_sample()
        assert cmd(*DOCKER, "exec", NAME, "id", "-u") == "10001"
        subprocess.run(
            DOCKER
            + ["exec", NAME, "sh", "-c", "test ! -w /app/comp_FactShiftDemand.csv"],
            check=True,
        )
        checks.append(
            "Clean Docker startup as uid 10001 with read-only source/image; actual resource enforcement is separately recorded"
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
            first_warm = time.monotonic()
            preflight = c.post("/api/demo/preflight", headers=origin).json()
            first_warm_seconds = time.monotonic() - first_warm
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
        stage_memory = {
            "startup_peak_bytes": startup_memory,
            "preflight_and_api_peak_bytes": memory_sample(),
        }
        restart_runs = []
        for restart in range(args.restarts):
            begin = time.monotonic()
            cmd(*DOCKER, "restart", "-t", "35", NAME)
            for _ in range(args.startup_timeout):
                try:
                    with httpx.Client(trust_env=False, timeout=3) as probe:
                        if (
                            probe.get("http://127.0.0.1:18080/healthz").status_code
                            == 200
                        ):
                            break
                except httpx.HTTPError:
                    pass
                time.sleep(1)
            else:
                raise RuntimeError("Restart did not become ready")
            ready_seconds = time.monotonic() - begin
            with httpx.Client(
                base_url=url, verify=context, trust_env=False, timeout=90
            ) as recovered:
                # Signing values remain the same; old session tickets must still work after process loss.
                recovered.cookies.update(c.cookies)
                assert recovered.get("/api/bootstrap").status_code == 200
                warm_begin = time.monotonic()
                r = recovered.post("/api/demo/preflight", headers=origin)
                assert r.status_code == 200, r.text
                assert len(r.json()["scenes"]) == 4
                assert (
                    hashlib.sha256(recovered.get("/api/export").content).hexdigest()
                    == hashlib.sha256(csv).hexdigest()
                )
            restart_runs.append(
                {
                    "ready_seconds": ready_seconds,
                    "guide_warm_seconds": time.monotonic() - warm_begin,
                    "peak_bytes": memory_sample(),
                    "cookie_recovered": True,
                    "csv_unchanged": True,
                }
            )
        scene_seconds = []
        errors = []
        with sync_playwright() as pw:
            browser = pw.chromium.launch(
                executable_path=os.environ.get("CHROMIUM_PATH")
                or (
                    "/usr/bin/chromium"
                    if Path("/usr/bin/chromium").exists()
                    else pw.chromium.executable_path
                ),
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
                scene_begin = time.monotonic()
                page.locator(".guide-progress button").nth(step).click()
                page.locator('.result[aria-busy="false"]').wait_for()
                assert page.locator(f'[data-demo-step="{step}"]').is_visible()
                scene_seconds.append(time.monotonic() - scene_begin)
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
        stage_memory["complete_demo_peak_bytes"] = memory_sample()
        oom_state = json.loads(
            cmd(*DOCKER, "inspect", "--format", "{{json .State}}", NAME)
        )
        assert not oom_state["OOMKilled"]
        server.shutdown()
        # Restarts reset the process counters. Include every recorded stage,
        # including the first preflight, rather than only the final process.
        peak_memory = max(
            list(stage_memory.values()) + [r["peak_bytes"] for r in restart_runs]
        )
        result = {
            "passed": True,
            "strict_container_test_passed": cgroups_verified,
            "verdict": (
                "PASS under actual container limits"
                if cgroups_verified
                else "Functional application-probe pass only; strict container limits unverified"
            ),
            "startup_seconds": startup,
            "first_guide_warm_seconds": first_warm_seconds,
            "warm_scene_seconds": scene_seconds,
            "memory_limit": args.memory,
            "memory_swap_limit": args.memory,
            "cpus": args.cpus,
            "peak_memory_bytes": peak_memory,
            "peak_memory_mib": peak_memory / 1024**2,
            "resource_limits_verified": cgroups_verified,
            "kernel_memory_max": kernel_memory,
            "kernel_cpu_max": kernel_cpu,
            "kernel_swap_max": kernel_swap,
            "software_probe": probe_sample() if args.software_probe else None,
            "memory_measurement": (
                "768 MiB virtual-address guard and monitored 512 MiB RSS ceiling; VmHWM high-water measurement; NOT a cgroup/file-cache limit"
                if args.software_probe
                else "Linux cgroup v2 memory.peak, including file cache/tmpfs"
            ),
            "stage_memory": stage_memory,
            "restart_runs": restart_runs,
            "oom_killed": False,
            "checks": checks,
            "public_site_live": False,
            "image": "shiftwise-demo:prepared",
            "public_tls_verified": False,
            "tls_test": "Ephemeral local CA verified by httpx; Chromium trusts only the generated leaf SPKI. Render public TLS is not tested until deployment.",
        }
        report_path.write_text(json.dumps(result, indent=2))
        print(json.dumps(result, indent=2))
    finally:
        cleanup()
