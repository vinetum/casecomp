# Prompt 3 local demo release

Prepared from audited commit `d008a0b`, with the audit's CONDITIONAL PASS and modeling caveats preserved. No deployment was performed.

## Implemented

- A five-scene presentation workspace with larger projector metrics, visible step progression, direct scene navigation, reset and exit. The full five-tab application remains available outside presentation mode. Navigation exits the guide intentionally.
- BASE and PEAK use official scenario assumptions; DISRUPT demonstrates capacity feasibility separately from residual risk. The audited W2 / Feb 14 / MID example was retained because it produces a real staffing/demand change and exposes the severe lower-bound service plateau honestly. The large caution explicitly rejects interpreting the model as a permission to cut real staffing.
- The Last Worker scene automatically selects the audited W2 / Feb 13 / OPEN / DISRUPT **Balanced** case. It contrasts the computed eligible addition with a rejected borrowing alternative, including recipient gain, lender loss and net expected-target change. Interactive alternatives show before/after employee counts and probability bars for all departments. No results are hardcoded.
- Feasibility rails show local regular and lent workers within the same source pool, borrowed counts and overtime against its cap. Pharmacy sharing remains prohibited. The frontier and official export show scope and model qualifications.
- Improved font sizes, content hierarchy, reduced-motion handling, responsive layouts and clear pp/probability labels. Removed duplicate legacy Last Worker/certificate panels. Corrected the visible precision note to the audited 0.000001.
- A bounded request timeout and understandable failure messages. Failed requests hide the old recommendation; a separate panel shows labeled official weekly reference data, not fabricated answers for the failed custom input. Retry and restoration were exercised with an injected HTTP 503.
- `scripts/demo.sh` starts the production app locally, checks readiness and computes four distinct guide selections into the existing process-local decision cache. `scripts/smoke.sh` checks readiness, live scene computations and validated HTTP CSV export. The cache is not a saved-results fallback; a new process computes its values again from original source data.
- `artifacts/DEMO_ASSETS/` contains seven real UI screenshots, PNG and SVG scenario/frontier figures, a FORGE workflow diagram, the live API decisions and the actual downloaded staffing CSV. `artifacts/demo_run_of_show.md` supplies exact clicks, executed values, slide cues, words to say, screenshot backups and 3-/4-minute versions plus a five-minute discussion.
- `artifacts/presentation_evidence.json` now includes explicit source paths, audit/verified-claims references, presentation asset paths, assumptions and limitations.

## Actually executed

- Full automated suite: **45 passed, zero failed**. This includes every audit regression, a real demo-preflight API contract test, and complete model generation/decision/export under patched socket operations that reject every attempted network connection.
- TypeScript and Vite production build: passed. No dependency versions changed. A non-failing Starlette/httpx test-client deprecation warning remains.
- Existing Chromium browser workflow: all five application screens, modes, scenario changes, real demand/availability sliders, honest Pharmacy minimum conflict, frontier, Last Worker, CSV download and mobile layout pass; no JavaScript page errors.
- Guided Chromium rehearsal: all five real scenes, Balanced marginal example, reset, actual export, mobile overflow check, simulated solver timeout, labeled fallback and retry pass. Every non-local browser destination is blocked; the rehearsal recorded **zero external requests**. This tests operation without Internet services after installation, not installation without package registry access.
- `scripts/demo.sh`: exercised locally, including readiness and live cache warmup. `scripts/smoke.sh`: passed against the running production server. Repeated preflight latency in `artifacts/demo_acceptance.json` is a warmed local measurement, not a performance guarantee for other hardware.
- `scripts/export.sh`: passed. `.venv/bin/python -m scripts.validate_submission`: valid, 567 rows, no errors. The separate Prompt 2 oracle also validates the actual presentation download and recomputes $982,297.695 across the three alternative scenario plans.
- `git diff d008a0b` confirms no changes to optimizer, forecast, service model, independent verifier, original CSVs or `data/raw`. All source-audit checks pass. The official CSV SHA-256 remains `910ee279b0f25a720623051b54aebbc4b1148d8b0c0caffa1e6cbc01823bebe6`, byte-identical to the audited submission.

## Presenter instructions

After installation, run `./scripts/demo.sh`; wait for “SHIFTWISE demo ready”, open local port 8000 and click Start guided demo. Follow `artifacts/demo_run_of_show.md`. If port 8000 is already occupied, stop that server or use `PORT=8001 ./scripts/demo.sh` and match the port when running smoke/capture scripts. Use `./scripts/start.sh` for ordinary startup without demo warmup. Start from Reset before each rehearsal. The application does not require external fonts, APIs, credentials or a database.

Use the PNG screenshots as explicitly labeled captured results if the local server fails. The live guide is not a slide screenshot player. The export always uses official Service First for all three scenarios even when the on-screen marginal example uses Balanced. Scenario costs are alternatives, never summed as one realized week's spending.

## Before external deployment

No current local demo acceptance check is blocked. External deployment is a separate authorized stage: decide and implement authentication/authorization, HTTPS/access routing, process/concurrency management, persistence and monitoring appropriate to the intended audience. Runtime processes and cache do not survive a snapshot/restart. Installing dependencies still requires registry access. Validate calibration on suitable real data before operational decisions; simulated service plateaus, neutral holiday assumptions, short backtests and aggregate employee qualifications remain limitations. This release does not establish individual rosters, causal labor effects, guaranteed wait times or production readiness.
