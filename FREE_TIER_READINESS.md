# SHIFTWISE Free-tier readiness

**Render Free is configured at $0. Capacity/reliability on Render Free remains UNVERIFIED: this environment cannot certify a strict whole-container 512 MiB limit. Nothing was deployed, no public URL was created, and no paid resource was requested.**

## What changed without changing recommendations

- `render.yaml` now selects `plan: free` and omits paid scaling. One non-root Docker service serves React and FastAPI; production API addresses remain relative.
- Ridge training is performed once per identical warehouse/department/training origin, rather than refitting identical data for every predicted day. It is never reused across backtest folds. The original selected forecast and all exported forecast diagnostics remain unchanged.
- The source workbook is opened once for all nine audited sheets. Every original source consistency check still runs.
- The CP-SAT model discards component rows whose service score is below that component's maximum minus the entire permitted global service loss. Because all other independent components can achieve at most their own maxima, these rows cannot participate in a feasible global solution. All remaining constraints, cost precision, solver optimality requirements, objectives, and tie-breaks remain unchanged. No heuristic or relaxed recommendation replaces integer optimization.
- The web engine skips generating offline Matplotlib PNGs at startup; its live model/calibration views still use real model metrics. CLI exports retain complete PNG diagnostics. Numerical libraries use one thread, the application worker pool four tokens, the decision cache 64 selections, and Linux allocator arenas two. Existing request/concurrency/security limits remain.
- No original input, audited recommendation, frontend feature or Mac backup launcher was removed.

## Measurement scope: an important restriction

The daemon reports cgroup driver **none**. The guest sees `memory.max=34359738368` and `cpu.max=400000 100000` belonging to the shared outer environment, even when Docker is passed `--memory 512m --memory-swap 512m --cpus 0.1`. Consequently **the requested strict container-limit test is blocked here**. It is not a pass and is not a demonstrated application OOM. The earlier Standard-plan capacity assertion is withdrawn in `DEPLOYMENT_READINESS_REPORT.md`; the first attempted Free result is marked invalid in `artifacts/render_free_baseline.json`.

The separate application probe runs the **actual production image, application, original models and protected HTTPS/browser workflow**. An acceptance-only supervisor measures process CPU and pauses/resumes the application to pace combined application/supervisor consumption to approximately 0.1 CPU. It checks combined resident process memory against 512 MiB, records `/proc` RSS high-water marks and applies separate hard virtual-address guards (768 MiB app / 48 MiB supervisor). An initial 448 MiB virtual-address experiment failed while loading OpenBLAS; virtual mappings are not resident RAM, so this does not demonstrate failure under a 512 MiB physical RAM cap.

RSS excludes file cache and the full container's tmpfs/kernel charges. Pausing/resuming differs from the kernel CPU bandwidth controller and provider shared-CPU scheduling. The test's proxy/browser run outside the server container, as they would in a client browser. The supervisor runs only during this labeled test, never in the Render production entrypoint. No aggregate resource-limit pass is inferred from these measurements.

## Completed resource probe and restart/browser rehearsal

Evidence: [application probe JSON](artifacts/render_free_application_probe.json), [blocked strict-test report](artifacts/render_free_cgroup_check.json), [strict-test error](artifacts/render_free_strict_check.txt). The completed rehearsal was recovered after the interrupted session; no expensive test was repeated merely to regenerate this report.

| Measurement/check | Actual result and scope |
|---|---|
| Highest recorded combined process RSS high-water bound | **253,906,944 bytes / 242.14 MiB**, including the acceptance supervisor. This sums process high-water marks, so it is a conservative process-RSS upper bound; it excludes aggregate container file-cache/tmpfs/kernel charges. |
| CPU pacing | Final process lifetime measured **26.77 CPU seconds / 267.88 wall seconds = 0.09993 CPU** including supervisor; target 0.1. This is software pacing, not a kernel CPU quota. |
| Initial process-cold readiness | **211.92 seconds (3 min 32 sec)** from container launch until actual initialized health readiness. Image pull/build time is excluded; host filesystem cache was not cleared. |
| First live guide preflight | **13.61 seconds** to prepare all four distinct real guide selections. |
| Restart 1 | Ready **210.96 seconds**, guide/export recovery **12.53 seconds**. Previously signed login ticket worked; CSV hash unchanged. |
| Restart 2 | Ready **228.07 seconds**, guide/export recovery **15.55 seconds**. Previously signed login ticket worked; CSV hash unchanged. |
| Warm browser guide transitions | **1.38 / 4.38 / 2.40 / 0.14 seconds** for the four transitions after BASE. All five scenes passed. These include browser rendering/network overhead. |
| Custom scenario | Actual request verified demand multiplier **0.75** and available workforce **0.80**; recalculated successfully. |
| Error recovery | Injected 503 showed the error and labeled reference, hid a stale recommendation, and successfully retried. |
| Protected end-to-end functionality | HTTPS browser login, BASE/PEAK/DISRUPT, Last Worker, certificate/frontier, actual CSV download, logout and zero JavaScript page exceptions: **PASS**. |
| Strict 512 MiB / no-swap / 0.1 CPU container test | **BLOCKED, not passed**: Docker cgroup driver none. The software probe and guest OOM flag cannot establish a true aggregate-memory pass. |
| Render natural sleep/wake and public HTTPS | **NOT TESTED**: deployment expressly excluded. Docker restart recovery does not establish provider wakeup reliability. |

The reporting script was corrected to take the maximum of **all** saved stages and restarts: the first preflight peak exceeded the final process peak. The JSON preserves every raw reading and notes that correction. The final image rebuild succeeded; the rehearsal used the same application/runtime code, with Docker healthchecks disabled for the software probe. The final image extends the Docker startup health grace to 600 seconds; this does not alter mathematical results or provider readiness behavior.

**Assessment:** the complete functionality passed at a measured CPU rate near 0.1 and a process-memory bound well below 512 MiB, which is encouraging. It is insufficient evidence to declare Render Free viable under its actual aggregate memory cap. The demonstrated bottleneck is **cold-start latency of 3½–4 minutes**, followed by 13–16 seconds of guide preparation. No application failure under a real 512 MiB physical-memory cap was demonstrated. Complete the strict local cap check and later actual hosted wakeup rehearsal before relying on Free for judges. Do not pay to bypass an unresolved result.

## Functional, numerical and package evidence

- **61 automated tests passed, zero failed**, with one existing Starlette/httpx deprecation warning. This includes audit/forecast/service/solver/constraint, offline operation, guide/API, authentication, CSRF, body limits, quotas, concurrency and timeout regressions plus Free-specific regressions.
- TypeScript and the Vite production build passed; the final multi-stage Docker image builds from locked Python/Node inputs. The final image healthcheck allows a long cold startup; `/healthz` reports ready only after actual model generation.
- `scripts/export.sh` passed, including the independent submission verifier and complete CLI diagnostic outputs.
- `python -m scripts.audit_independent` re-enumerated **342,687 candidate triples over 189 groups**, found **zero dominated groups and zero score gap**, checked all official Last Worker decisions and independently recalculated the submitted costs using decimal arithmetic.
- The official CSV remains **567 rows, valid, unchanged**, SHA-256 **910ee279b0f25a720623051b54aebbc4b1148d8b0c0caffa1e6cbc01823bebe6**. Recalculated sum over the three alternative scenarios is **982297.695**, not one simultaneous operating-week budget.
- Existing secure settings remain mandatory. Production without secrets/hostname exits; raw case/source files and interactive API docs are denied. Signing values remain stable across ordinary restarts so unexpired authenticated tickets recover. No secret values are committed.

## How to finish the strict check without paying for hosting

On the installed Mac, open local Docker Desktop (free Personal/education eligibility applies) and double-click **Test Render Free.command**. This is a local-only checker, not a deployment. It installs the optional test browser and builds the exact production image, then executes:

```bash
python scripts/test_container.py --memory 512m --cpus 0.1 --startup-timeout 900 --restarts 2 --report artifacts/render_free_cgroup_check.json
```

It verifies `memory.max=536870912`, `memory.swap.max=0`, and CPU quota/period = 0.1, then checks protected startup, real calculations, all five browser guide scenes, custom demand/availability, error/retry, exact CSV, and two restarts. Only a report with **strict_container_test_passed: true** certifies success. Keep any failure output; do not silently increase the caps or remove features. The measured peak is then cgroup `memory.peak`, including file cache/tmpfs. Native offline Mac startup itself does not require Docker.

After any later Free deployment, test the provider's actual HTTPS URL and natural inactivity/sleep/wakeup. A Docker process restart tests loss/reconstruction of process memory; it cannot verify Render's router, public TLS, quota, region capacity or wakeup scheduling. See [Render's current Free documentation](https://render.com/docs/free) and your dashboard before accepting any account setting. Free shared CPU, cold sleep and changing included quotas preclude an uptime/performance guarantee.

## Genuinely free fallback

The existing **native Mac offline app** uses the same models and actual calculations and has no hosting charge, account dependency or runtime Internet requirement. Install while online and rehearse with Wi-Fi off. It is the presentation fallback after native installation and rehearsal if Free sleeps, hits a quota or fails the strict test; screenshots remain labeled captured results.

If a public link is still needed when Free cannot run reliably, a zero-hosting-cost alternative is the existing Mac plus a **Cloudflare Quick Tunnel** (`trycloudflare.com`) to a separately started **production-authenticated, loopback-bound** backend serving the built frontend. This uses your own laptop CPU/RAM rather than a 512 MiB hosted worker and does not require a paid domain. It needs an awake Mac and Internet, has a temporary URL and no uptime guarantee. It was **not started or verified here** because deployment is excluded. Follow the current official Quick Tunnel instructions, obtain its actual hostname, set `SHIFTWISE_ENV=production`, secure password/signing values and that exact `SHIFTWISE_ALLOWED_HOSTS`, and use Uvicorn proxy headers trusted only from the local tunnel process. Never expose the normal authentication-disabled native backup through a tunnel, never use wildcard hosts, and never publish credentials. Have a technical helper verify HTTPS, login, source denial and the full guide before sharing a temporary link. This alternative is a documented fallback, not a claimed live deployment.

## Before judging

Open and manually rehearse the Free website well ahead of your slot, allow several minutes for cold startup, and keep the native Mac running alongside it. Do not use artificial keep-alive traffic to bypass sleep, authorize a paid upgrade, weaken authentication, or present a failed calculation as a recommendation. The complete mathematical model is preserved; resource or provider failures must remain visible.
