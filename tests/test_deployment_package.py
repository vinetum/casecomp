from pathlib import Path
import hashlib, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]


def test_audited_submission_is_unchanged():
    assert (
        hashlib.sha256(
            (ROOT / "artifacts/TEAM_SUBMISSION_COMPLETED.csv").read_bytes()
        ).hexdigest()
        == "910ee279b0f25a720623051b54aebbc4b1148d8b0c0caffa1e6cbc01823bebe6"
    )


def test_no_absolute_local_api_in_frontend_and_explicit_production_contract():
    source = (ROOT / "frontend/src/main.tsx").read_text()
    assert "http://localhost" not in source and "http://127.0.0.1" not in source
    assert "fetch(`/api/export" in source
    blueprint = (ROOT / "render.yaml").read_text()
    for value in [
        "runtime: docker",
        "healthCheckPath: /healthz",
        "plan: free",
        "branch: work",
        "sync: false",
        "generateValue: true",
    ]:
        assert value in blueprint
    assert "value: local" not in blueprint
    assert "plan: standard" not in blueprint and "numInstances" not in blueprint


def test_mac_shell_wrappers_parse_and_do_not_disable_tls():
    scripts = [
        "Install Mac Backup.command",
        "Start SHIFTWISE.command",
        "Stop SHIFTWISE.command",
        "scripts/install_mac.sh",
    ]
    for script in scripts:
        subprocess.run(["bash", "-n", str(ROOT / script)], check=True)
        text = (ROOT / script).read_text()
        assert "--trusted-host" not in text and "strict-ssl=false" not in text
