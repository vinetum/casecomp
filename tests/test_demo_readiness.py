from unittest.mock import patch
from fastapi.testclient import TestClient
from backend.app import app
from backend.data import read
import socket


def test_demo_preflight_warms_real_audited_decisions(engine):
    with patch("backend.app.get_engine", return_value=engine), TestClient(app) as c:
        r = c.post("/api/demo/preflight")
        assert r.status_code == 200
        scenes = r.json()["scenes"]
        assert len(scenes) == 4
        assert [s["selection"]["scenario_id"] for s in scenes] == [1, 2, 3, 3]
        for d in scenes:
            assert d["certificate"]["independent_verification"]["valid"]
            assert d["plan"]["solver_status"] == "OPTIMAL"
            assert d["plan"] == engine.decision(**d["selection"])["plan"]
        assert scenes[-1]["selection"]["mode"] == "Balanced"


def test_offline_model_generation_never_connects_outward():
    from backend.engine import Engine

    def denied(*args, **kwargs):
        raise AssertionError("Network attempted in offline model execution")

    with patch.object(socket.socket, "connect", denied), patch(
        "socket.create_connection", denied
    ):
        e = Engine()
        d = e.decision(3, 2, "2026-02-13", "OPEN", "Balanced")
        assert d["certificate"]["independent_verification"]["valid"]
        assert len(e.submission("SHIFTWISE")) == 567
