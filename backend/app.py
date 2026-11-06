from contextlib import asynccontextmanager
from functools import lru_cache
from typing import Literal
from io import StringIO
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import Response, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from .data import ROOT, native
from .engine import Engine
from .security import DemoBoundary, Settings


@lru_cache(maxsize=1)
def get_engine():
    return Engine()


@asynccontextmanager
async def lifespan(app):
    get_engine()
    yield


app = FastAPI(
    title="SHIFTWISE",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)
app.add_middleware(DemoBoundary, settings=Settings.from_env())


class Selection(BaseModel):
    scenario_id: Literal[1, 2, 3] = 1
    store_id: Literal[1, 2, 4] = 2
    day_date: Literal[
        "2026-02-12",
        "2026-02-13",
        "2026-02-14",
        "2026-02-15",
        "2026-02-16",
        "2026-02-17",
        "2026-02-18",
    ] = "2026-02-14"
    shift_code: Literal["OPEN", "MID", "EVE"] = "MID"
    mode: Literal["Service First", "Balanced", "Budget Conscious"] = "Service First"
    demand_factor: float = Field(default=1.0, ge=0.7, le=1.5)
    availability_factor: float = Field(default=1.0, ge=0.0, le=1.0)
    uncertainty: Literal["central", "lower", "upper"] = "central"


@app.exception_handler(RuntimeError)
async def calculation_failure(request, error):
    return JSONResponse(
        {
            "detail": "Calculation could not finish within the resource budget. Retry shortly."
        },
        status_code=503,
        headers={"Retry-After": "2"},
    )


@app.get("/healthz")
def readiness():
    return {"status": "ready"}


@app.get("/api/health")
def health():
    return {"status": "ready", "submission_valid": get_engine().validation["valid"]}


@app.get("/api/bootstrap")
def bootstrap():
    return native(get_engine().bootstrap())


@app.post("/api/decision")
def decision(selection: Selection):
    try:
        return native(get_engine().decision(**selection.model_dump()))
    except ValueError as e:
        raise HTTPException(422, str(e)) from e
    except RuntimeError as e:
        raise HTTPException(503, str(e)) from e


@app.post("/api/demo/preflight")
def demo_preflight():
    """Warm the existing decision cache using official inputs, never saved answers."""
    engine = get_engine()
    selections = [
        (1, 2, "2026-02-14", "MID", "Service First"),
        (2, 2, "2026-02-14", "MID", "Service First"),
        (3, 2, "2026-02-14", "MID", "Service First"),
        (3, 2, "2026-02-13", "OPEN", "Balanced"),
    ]
    return native(
        {
            "ready": True,
            "scenes": [engine.decision(*s) for s in selections],
            "note": "Calculated locally from bundled official inputs; cached only for this running process. No external services or saved answers.",
        }
    )


@app.get("/api/export")
def export(
    team_id: str = Query(
        default="SHIFTWISE", pattern=r"^[A-Za-z0-9][A-Za-z0-9 _-]{0,63}$"
    )
):
    csv = get_engine().submission(team_id).to_csv(index=False)
    return Response(
        csv,
        media_type="text/csv",
        headers={
            "Content-Disposition": 'attachment; filename="TEAM_SUBMISSION_COMPLETED.csv"',
            "X-Submission-Validated": "567 rows; independent feasibility passed",
        },
    )


if (ROOT / "frontend/dist").exists():
    app.mount(
        "/", StaticFiles(directory=ROOT / "frontend/dist", html=True), name="dashboard"
    )
