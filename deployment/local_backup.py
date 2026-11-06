"""Portable loopback backup launcher. macOS wrappers use a native .venv-mac."""

from pathlib import Path
import argparse, json, os, signal, subprocess, sys, time, urllib.request, webbrowser

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / ".local-run"
RECORD = STATE / "backup-server.json"


def identity(record):
    try:
        text = subprocess.check_output(
            ["ps", "-ww", "-p", str(record["pid"]), "-o", "command="], text=True
        )
        return record["python"] in text and "uvicorn backend.app:app" in text
    except (KeyError, OSError, subprocess.CalledProcessError):
        return False


def request(url, path, data=None):
    r = urllib.request.Request(
        url + path,
        data=b"" if data is not None else None,
        method="POST" if data is not None else "GET",
    )
    with urllib.request.urlopen(r, timeout=90) as response:
        return json.load(response)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=["start", "stop", "status"])
    p.add_argument("--python", default=str(ROOT / ".venv-mac/bin/python"))
    p.add_argument("--port", type=int, default=8000)
    p.add_argument("--no-browser", action="store_true")
    args = p.parse_args()
    old = json.loads(RECORD.read_text()) if RECORD.exists() else None
    if args.action == "stop":
        if old and identity(old):
            os.kill(old["pid"], signal.SIGTERM)
            for _ in range(80):
                if not identity(old):
                    break
                time.sleep(0.25)
            if identity(old):
                raise SystemExit(
                    "Server is still stopping. Try Stop again shortly; no unrelated process was killed."
                )
        RECORD.unlink(missing_ok=True)
        print("SHIFTWISE backup stopped.")
        return
    if args.action == "status":
        print("Running" if old and identity(old) else "Stopped")
        return
    if old and identity(old):
        url = "http://127.0.0.1:" + str(old["port"])
        print("Backup is already running on port", old["port"])
        if not args.no_browser:
            webbrowser.open(url)
        return
    if not 1024 <= args.port <= 65535:
        raise SystemExit("Choose a port between 1024 and 65535.")
    python = Path(args.python).absolute()
    if not python.exists() or not (ROOT / "frontend/dist/index.html").exists():
        raise SystemExit(
            "Backup installation is incomplete. Run Install Mac Backup.command first."
        )
    STATE.mkdir(mode=0o700, exist_ok=True)
    env = os.environ.copy()
    env.update(
        SHIFTWISE_ENV="local",
        MPLCONFIGDIR=str(STATE / "matplotlib"),
        XDG_CACHE_HOME=str(STATE / "cache"),
        OMP_NUM_THREADS="1",
        OPENBLAS_NUM_THREADS="1",
    )
    # The child is deliberately loopback-only and never needs an Internet connection.
    with (STATE / "backup.log").open("ab") as log:
        proc = subprocess.Popen(
            [
                str(python),
                "-m",
                "uvicorn",
                "backend.app:app",
                "--host",
                "127.0.0.1",
                "--port",
                str(args.port),
                "--workers",
                "1",
            ],
            cwd=ROOT,
            env=env,
            stdout=log,
            stderr=log,
            start_new_session=True,
        )
    record = {"pid": proc.pid, "port": args.port, "python": str(python)}
    temporary_record = RECORD.with_suffix(".tmp")
    temporary_record.write_text(json.dumps(record))
    temporary_record.replace(RECORD)
    url = "http://127.0.0.1:" + str(args.port)
    print(
        "Starting the real local model and optimizer. This may take up to two minutes.",
        flush=True,
    )
    for _ in range(180):
        if proc.poll() is not None:
            RECORD.unlink(missing_ok=True)
            raise SystemExit(
                "Startup failed. The port may be in use. See .local-run/backup.log; existing services were not stopped."
            )
        try:
            if request(url, "/api/health").get("submission_valid"):
                break
        except OSError:
            pass
        time.sleep(1)
    else:
        proc.terminate()
        RECORD.unlink(missing_ok=True)
        raise SystemExit("Startup timed out; see .local-run/backup.log.")
    try:
        ready = request(url, "/api/demo/preflight", data=True)
        if not ready["ready"]:
            raise RuntimeError("Guide warmup failed")
    except Exception:
        proc.terminate()
        RECORD.unlink(missing_ok=True)
        raise SystemExit("Demo warmup failed. See .local-run/backup.log; please retry.")
    print(
        "READY: SHIFTWISE is running locally on port",
        args.port,
        "with four live guide selections calculated. Internet is not required.",
        flush=True,
    )
    if not args.no_browser:
        webbrowser.open(url)


if __name__ == "__main__":
    main()
