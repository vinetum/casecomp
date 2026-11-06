# SHIFTWISE deployment readiness — Free / $0 revision

**No public website or paid resource has been created. Render Free is configured; strict free-tier resource certification remains outstanding.**

This report supersedes the previous Standard-plan recommendation. See [FREE_TIER_READINESS.md](FREE_TIER_READINESS.md) for the latest measurements, exact test scope, and remaining limits. Use [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for Free-only deployment steps. No paid fallback is authorized.

## Correction to previous resource evidence

The earlier protected production acceptance genuinely tested the full application, HTTPS login, scenarios, browser guide, CSV, and route protections. However, subsequent inspection found this managed rootless Docker daemon has **cgroup driver `none`**. It accepts `--memory` and `--cpus` without enforcing them. The earlier report's claim to have passed under 1 GiB / 1 CPU was unsupported and is withdrawn. The first attempted 512 MiB result likewise read the outer host's memory counter and is explicitly marked invalid in `artifacts/render_free_baseline.json`. Neither result certifies Free-plan capacity.

The acceptance script now rejects an unenforced resource test and verifies actual Linux `memory.max`, `memory.swap.max`, and `cpu.max`. The separately labeled process probe uses measured CPU pacing and process RSS/virtual-address guards; it does not claim kernel-enforced whole-container limits. The optional Docker Desktop checker supplies a reproducible path to the outstanding strict test without creating a hosting service.

## Delivered and preserved

- One Docker web service serves React and Python using relative `/api` addresses. The Free Blueprint has no disk, database, paid add-on, scaling declaration, or automatic deployment.
- Every audited model and feature remains: original source auditing, forecasting, calibrated service estimates, integer staffing optimization, BASE/PEAK/DISRUPT, Last Worker, feasibility, frontier, guided demo, and official export.
- Identical training fits are reused within a fold/group; workbook parsing is shared across sheets; mathematically impossible solver lookup rows are pruned exactly. The web skips only offline PNG rendering. CLI artifacts and the live calibration chart remain available. Numerical threads, worker pool, and decision cache are bounded.
- Authentication, signed eight-hour Secure/HttpOnly/SameSite=Strict cookies, exact host/Origin checks, no CORS, CSP, no-store/no-index, body/deadline/connection limits, aggregate quotas, and one-heavy-request gating remain. Original files are not public static assets. This is a shared competition gate, not enterprise identity or DRM.
- Mac installers and native offline launchers remain available. The user reports MacBook Air / Tahoe 26.6.2; both Apple Silicon and Intel wheel compatibility was checked previously. Physical Mac installation, Finder behavior, and Wi-Fi-off rehearsal still require that device.

## Completed Free adaptation verification

The preserved full suite passed **61 tests**, the production frontend and final Docker image build passed, and the independent oracle rechecked **342,687 candidate triples / 189 groups** with zero score gap. The unchanged **567-row CSV** passed source-based validation and HTTPS/browser hash comparisons. The complete browser guide, custom scenario, error/retry, login/logout and **two restarts** passed in the software CPU-paced probe: **242.14 MiB** recorded combined process high-water bound, **211.92 seconds** initial readiness, **210.96 / 228.07 seconds** restart readiness, measured approximately **0.10 CPU**. These are process measurements, not a whole-container cap certification. The report documents the first-stage peak aggregation correction and exact evidence links. No expensive test was repeated solely because the session was interrupted.

## Remaining outside actions

1. Optionally run **Test Render Free.command** with local Docker Desktop to obtain real whole-container 512 MiB/no-swap/0.1 CPU evidence; this environment cannot supply that certification.
2. When choosing to deploy, authorize GitHub in Render, select branch work, verify **Free / $0**, and enter the password through secure environment settings. Stop if any charge/upgrade is proposed. Existing paid resources must be downgraded/deleted separately; repository changes do not stop billing.
3. Verify the actual Render HTTPS URL, login, complete guide, recalculation, export, logout, and natural sleep/wakeup. No invented URL or provider sleep result is asserted here.
4. Install and rehearse the native Mac backup offline. Free service sleep/shared CPU and quotas remain presentation risks even after a local cap test passes.

The source audit's model limitations remain unchanged: simulated inputs, short history, neutral central holiday assumptions, sensitivity ranges rather than confidence intervals, aggregate qualified pools, and low-probability plateaus. No real-world service guarantee or causal permission to cut staff is implied.
