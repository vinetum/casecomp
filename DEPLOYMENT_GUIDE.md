# SHIFTWISE on Render Free — $0 hosting only

**Do not choose Standard, Starter, a paid workspace, a disk, database, worker, or paid add-on.** This branch now declares `plan: free`. No Render deployment or paid resource was created by this task. The app remains the complete audited React/Python application with login, live forecasting/optimization, all scenarios, Last Worker, feasibility, frontier and 567-row export.

**Qualification:** see `FREE_TIER_READINESS.md` and its measurements. This coding environment's rootless Docker does not enforce cgroups. It cannot certify a strict whole-container 512 MiB limit; the local application probe is explicitly different. Do not substitute requested Docker flags for a measured limit. A one-click strict Docker Desktop test is provided below. There is no public URL until you explicitly deploy and verify one.

## If you previously created a paid Render service

Changing `render.yaml` in GitHub does **not** stop an already-running paid service or its charges. Sign in to Render, open that service → **Settings / Instance Type**, select **Free** if supported, and save; otherwise suspend/delete the paid service when you no longer need it. Check **Billing** for all other paid resources. This task cannot inspect or change your Render account. Do not leave Standard running because the repository now says Free.

## Understand Free before presentation day

- Render Free web services sleep after inactivity (normally around 15 minutes). Cold wakeups must load Python, audit the original inputs, train the models and rebuild the real staffing plans. Expect a loading/waking screen and allow several minutes. The completed CPU-paced probe took **212 seconds** to cold-start and another **14 seconds** to prepare the guide; restarts took **211–228 seconds**. Its recorded process-memory bound was **242.14 MiB**, excluding aggregate container charges. These are local probe measurements, not a Render uptime or strict-memory promise.
- Free CPU is shared; the acceptance target is **0.1 CPU and 512 MiB RAM with no swap**. Shared-host performance can vary. A cold service is not suitable for a surprise first click in front of judges.
- Free workspace instance hours, bandwidth and build-minute allowances are shared and subject to Render's current terms. Check your dashboard's included quotas. Do not add paid overages, payment-backed auto-upgrades, extra services or custom domains to work around a quota. If the account cannot offer a $0 Free service, stop and use the installed Mac backup.
- No persistent disk or external database is needed. Models and outputs are rebuilt from bundled inputs after process loss. A restart can discard caches; it does not discard the source data or fabricate new results.
- Do not add an artificial keep-alive/ping service to defeat the provider's sleep policy. Manually open and rehearse before your slot; keep the real Mac backup running.

## Optional: verify a real strict resource cap on your Mac first

The source has `Test Render Free.command`. It builds and tests locally; it does **not** create a website or a paid service.

1. Complete the normal Mac backup installation (`LOCAL_BACKUP_GUIDE.md`). Your reported MacBook Air / Tahoe 26.6.2 is above the documented minimum.
2. Install and open Docker Desktop using its Personal/education free entitlement, if applicable to you; do not buy a subscription or start a cloud build service. Let its local engine become ready.
3. Double-click **Test Render Free.command** while online for its first dependency/image build. It installs the optional test browser, builds the actual image and runs the full protected guide under **512 MiB, no swap, 0.1 CPU**, with two restarts. Allow up to 15 minutes per startup on very slow hardware.
4. Open `artifacts/render_free_cgroup_check.json`. Only `strict_container_test_passed: true` confirms the kernel-enforced test passed. The script aborts if the actual `memory.max`, `memory.swap.max` and `cpu.max` do not match. It records peak charged container memory, cold/restart timing, guide latency, authentication and exact CSV verification. It removes its test container afterward.
5. If it fails, keep the error/report and use the Mac backup. Do not hide the failure by increasing memory, CPU, solver tolerance, or dropping a feature.

Docker Desktop is optional for the **native Mac backup** itself, which needs only the existing Python/Node installation. Native Mac and container tests are separate.

## Create a Free Blueprint only when you choose to deploy

1. On GitHub, open **vinetum/casecomp**, choose branch **work**, and confirm `render.yaml` says **plan: free**. Do not deploy an older commit with Standard. The task pushes the final branch but does not apply it to Render.
2. Sign in at **https://dashboard.render.com/**. Click **New + → Blueprint**.
3. Connect/authorize GitHub if asked. In GitHub, authorize **only the selected repository casecomp**, then return to Render and click **Connect** beside it. Account authorization must be done by you; no Render credentials are available in this coding environment.
4. Select branch **work**, Blueprint path **render.yaml**, and a recognizable Blueprint name. Review the proposed Docker web service.
5. Confirm the instance type explicitly shows **Free / $0**. There must be no paid extra resource, minimum scaling or persistent disk. The Free plan cannot autoscale; `numInstances` is intentionally omitted. Automatic deployment stays **off**. Confirm the final pushed Free-plan commit, not an older Standard-plan revision.
6. Enter **SHIFTWISE_DEMO_PASSWORD** using a password-manager-generated random password of 24+ characters (maximum 256). Share it only with your team/authorized judges. **SHIFTWISE_SESSION_SECRET** is generated securely by the Blueprint. Keep **SHIFTWISE_ENV=production**. Do not commit or paste these values in chat, source, URLs, build arguments or screenshots. Render supplies the real external hostname and listening PORT.
7. If Render shows a monthly charge or asks you to upgrade to make this service work, stop; your budget is $0. Do not approve a paid fallback.
8. When you are satisfied it is Free, click **Deploy Blueprint / Apply**. That is your actual deployment action; this task does not do it. Watch **Events / Logs** until **Live**. The health path `/healthz` becomes ready only after genuine startup validation and model generation.
9. Click the **actual HTTPS URL displayed by Render**. Save that URL; do not guess a service hostname. The first anonymous page must be **Competition demo access**. Before signing in, `/api/bootstrap` must deny access without data. Raw paths such as `/data/raw/v_ShiftHistory.csv` must not download source files even after signing in.
10. Sign in and run **Start guided demo → BASE → PEAK → DISRUPT → LAST WORKER → DECIDE & EXPORT**. Exit the guide, change both demand and workforce availability, and click Recalculate. Inspect the certificate/frontier and download the 567-row official CSV. Click Lock demo and confirm data APIs require login again.
11. Let the service sleep naturally, reopen it, wait for real startup, and repeat the guide/export check. This is the provider-specific wakeup test that local Docker restarts cannot replace. Keep the session password/signing values stable; signed tickets survive ordinary process restarts until expiry.

## Zero-cost competition procedure

Open the actual site well before your slot, wait until it is ready, sign in and rehearse the guide. Start the **native Mac backup** as well. Reset to BASE before presenting. If the hosted service is asleep, unavailable, quota-limited or too slow, switch to the actual local app rather than changing plans or paying. Read `artifacts/demo_run_of_show.md` for the timed script and honest limitations. A captured screenshot must be called a captured result, not a fresh calculation.

## Protections preserved

One worker, one expensive calculation at a time, four bounded application worker threads, signed eight-hour Secure/HttpOnly/SameSite=Strict sessions, exact host/Origin checks, no cross-origin API allowance, CSP/frame protection, no-store/no-index responses, body/time limits and request quotas remain. Shared-password access is a competition gate, not enterprise identity or DRM. The public readiness endpoint exposes no case data. Only compiled frontend files are static-served. Keep the GitHub repository private if case-distribution rules require it.

The allocator/cache changes are performance controls, not looser staffing constraints: one training fit is reused only within the same fold/group; globally impossible lookup rows are pruned exactly; the web skips only offline PNG rendering while its live calibration chart remains. CLI exports still generate the complete diagnostic artifacts. The audited submission hash is unchanged.

## Troubleshooting without spending

| Issue | Action |
|---|---|
| Waking/loading screen | Wait for cold startup, then refresh/retry. Do not repeatedly hammer Recalculate. Keep the Mac ready. |
| 429 / busy 503 | Wait and retry; protections remain enabled. Repeated normal-use failures need investigation, not a paid upgrade or weakened constraints. |
| Memory restart / OOM | Keep the logs and measured resource report. Switch to the native Mac; a desktop strict test or actual Render metrics is needed before claiming reliability. |
| Missing secrets/hostname | Correct secure Environment settings; never bypass by setting production mode to local. |
| Quota exhausted / card or charge requested | Do not approve charges. Use the installed Mac until free allowance renews, or use the genuinely free self-hosted alternative described in `FREE_TIER_READINESS.md`. |
| Older paid configuration appears | Stop. Check branch work and the deployed commit, then review the Free Blueprint. Source changes alone do not downgrade a running paid service. |

No public Render service or public-certificate success was verified by this task. The exact current evidence, testing limitation and free alternative are recorded in `FREE_TIER_READINESS.md`.
