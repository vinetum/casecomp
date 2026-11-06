"""Free-tier changes preserve data, models, solver results and access controls."""

import hashlib
import numpy as np
from sklearn.linear_model import Ridge
from backend.forecast import predict
from backend.engine import Engine
from backend.service import Service
from backend.data import ROOT


def test_ridge_fits_once_per_group_and_training_origin(engine, monkeypatch):
    tr = engine.forecast.daily[engine.forecast.daily.day_date < "2026-01-29"]
    hold = engine.forecast.daily[engine.forecast.daily.day_date >= "2026-01-29"].head(
        63
    )
    fitted = []
    original = Ridge.fit

    def counted(self, *args, **kwargs):
        fitted.append(len(args[0]))
        return original(self, *args, **kwargs)

    monkeypatch.setattr(Ridge, "fit", counted)
    p = predict(tr, hold, "ridge")
    assert np.isfinite(p).all()
    assert len(fitted) == len(hold[["store_id", "dept_id"]].drop_duplicates())


def test_web_engine_skips_only_offline_png_rendering(engine, monkeypatch):
    def forbidden(*args, **kwargs):
        raise AssertionError("Offline plot renderer loaded by web engine")

    monkeypatch.setattr(Service, "chart", forbidden)
    web = Engine(diagnostics=False)
    assert web.forecast.selected == engine.forecast.selected
    for dept in [38, 92, 95]:
        assert (
            web.service.metrics[dept]["test"]["brier"]
            == engine.service.metrics[dept]["test"]["brier"]
        )
    assert web.decision.cache_info().maxsize == 64
    assert (
        hashlib.sha256(
            web.submission("SHIFTWISE").to_csv(index=False).encode()
        ).hexdigest()
        == "910ee279b0f25a720623051b54aebbc4b1148d8b0c0caffa1e6cbc01823bebe6"
    )


def test_zero_cost_blueprint_and_mac_backup_preserved():
    blueprint = (ROOT / "render.yaml").read_text()
    assert "plan: free" in blueprint and "plan: standard" not in blueprint
    assert "numInstances" not in blueprint and "minInstances" not in blueprint
    assert "SHIFTWISE_ENV" in blueprint and "value: production" in blueprint
    assert "generateValue: true" in blueprint and "sync: false" in blueprint
    for p in [
        "Install Mac Backup.command",
        "Start SHIFTWISE.command",
        "Stop SHIFTWISE.command",
    ]:
        assert (ROOT / p).is_file()
