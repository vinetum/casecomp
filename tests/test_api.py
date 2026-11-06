from io import StringIO
import pandas as pd
import pytest
from fastapi.testclient import TestClient
from backend.app import app
from backend.verify import validate_submission


@pytest.fixture(scope="module")
def client(engine):
    from unittest.mock import patch

    with patch("backend.app.get_engine", return_value=engine), TestClient(app) as c:
        yield c


def test_live_health_and_bootstrap(client):
    assert client.get("/api/health").json()["submission_valid"]
    data = client.get("/api/bootstrap").json()
    assert len(data["allocations"]) == 567 and len(data["summary"]) == 3


def test_scenario_recalculation_and_no_invented_capacity(client):
    base = {
        "scenario_id": 1,
        "store_id": 2,
        "day_date": "2026-02-14",
        "shift_code": "MID",
    }
    normal = client.post("/api/decision", json=base)
    assert normal.status_code == 200
    changed = client.post(
        "/api/decision",
        json=base
        | {"scenario_id": 2, "demand_factor": 1.25, "availability_factor": 0.8},
    )
    assert changed.status_code == 200
    a = normal.json()
    b = changed.json()
    assert a["plan"]["allocations"] != b["plan"]["allocations"]
    assert b["certificate"]["capacity_verified"]
    assert b["certificate"]["status"] == "MINIMUM_CONFLICT"
    assert (
        b["certificate"]["minimum_shortfall"] == 1
    )  # source pharmacy pool floors to one worker
    zero = client.post("/api/decision", json=base | {"availability_factor": 0}).json()
    assert zero["certificate"]["status"] == "MINIMUM_CONFLICT"
    assert all(r["employees"] == 0 for r in zero["plan"]["allocations"])


@pytest.mark.parametrize(
    "bad",
    [
        {"store_id": 999},
        {"availability_factor": 1.1},
        {"demand_factor": -1},
        {"day_date": "2026-03-01"},
        {"uncertainty": "fake"},
    ],
)
def test_invalid_scenarios_rejected(client, bad):
    assert client.post("/api/decision", json=bad).status_code == 422


def test_download_validated_and_team_configurable(client):
    r = client.get("/api/export", params={"team_id": "TEAM_TEST"})
    assert r.status_code == 200 and "X-Submission-Validated" in r.headers
    t = pd.read_csv(StringIO(r.text))
    assert t.team_id.eq("TEAM_TEST").all() and validate_submission(t)["valid"]
    assert (
        client.get("/api/export", params={"team_id": "=INVALID()"}).status_code == 422
    )
