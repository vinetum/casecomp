"""Rehearse the real five-step UI and create source-backed deck assets."""

import json, time, os, urllib.request
from pathlib import Path
from urllib.parse import urlsplit
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "artifacts/DEMO_ASSETS"
OUT.mkdir(exist_ok=True)
URL = "http://127.0.0.1:" + os.environ.get("PORT", "8000")
for _ in range(120):
    try:
        with urllib.request.urlopen(URL + "/api/health", timeout=3) as r:
            if json.load(r)["submission_valid"]:
                break
    except OSError:
        time.sleep(1)
else:
    raise RuntimeError("Local app not ready")
start = time.perf_counter()
with urllib.request.urlopen(
    urllib.request.Request(URL + "/api/demo/preflight", method="POST"), timeout=90
) as r:
    preflight = json.load(r)
latency = time.perf_counter() - start
(OUT / "live_demo_decisions.json").write_text(json.dumps(preflight, indent=2))
errors = []
external = []
checks = []
with sync_playwright() as pw:
    browser = pw.chromium.launch(
        executable_path="/usr/bin/chromium", headless=True, args=["--no-sandbox"]
    )
    context = browser.new_context(
        viewport={"width": 1600, "height": 1100}, device_scale_factor=1
    )

    def local_only(route):
        if urlsplit(route.request.url).hostname not in ["127.0.0.1", "localhost"]:
            external.append(route.request.url)
            route.abort()
        else:
            route.continue_()

    context.route("**/*", local_only)
    page = context.new_page()
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto(URL)
    page.locator('.result[aria-busy="false"]').wait_for(timeout=120000)
    page.get_by_role("button", name="Start guided demo", exact=True).click()
    files = [
        "01-BASE.png",
        "02-PEAK.png",
        "03-DISRUPT.png",
        "04-LAST-WORKER.png",
        "05-DECISION-EXPORT.png",
    ]
    live = []
    for step, file in enumerate(files):
        if step:
            with page.expect_response(
                lambda r: r.url.endswith("/api/decision") and r.request.method == "POST"
            ) as response:
                page.locator(".guide-progress button").nth(step).click()
            d = response.value.json()
            assert d["plan"]["solver_status"] == "OPTIMAL"
            live.append(d)
        page.locator('.result[aria-busy="false"]').wait_for()
        assert page.locator(f'[data-demo-step="{step}"]').is_visible()
        assert page.locator(".guide-progress button").count() == 5
        if step == 3:
            assert (
                "Lender effect"
                in page.locator(".demo-stage .worker-choices").inner_text()
            )
            assert (
                page.locator(".demo-stage")
                .get_by_text("Reject this transfer:", exact=False)
                .is_visible()
            )
        page.screenshot(path=str(OUT / file), full_page=True)
    with page.expect_download() as download:
        page.get_by_role(
            "button", name="Download 567-row official plan", exact=True
        ).click()
    download.value.save_as(str(OUT / "downloaded_staffing.csv"))
    page.get_by_role("button", name="Reset guided demo", exact=True).click()
    page.locator('.result[aria-busy="false"]').wait_for()
    assert page.locator('[data-demo-step="0"]').is_visible()
    checks.append(
        "Five real solver scenes, Balanced marginal example, lender loss, reset and validated export"
    )
    page.set_viewport_size({"width": 430, "height": 900})
    page.screenshot(path=str(OUT / "06-mobile-guide.png"), full_page=True)
    assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
    checks.append("Responsive projector guide has no mobile page overflow")
    page.get_by_role("button", name="Close guided demo", exact=True).click()
    page.route(
        "**/api/decision",
        lambda r: r.fulfill(
            status=503,
            content_type="application/json",
            body='{"detail":"simulated solver timeout"}',
        ),
    )
    page.get_by_role("button", name="PEAK", exact=True).click()
    page.get_by_role("alert").wait_for()
    assert page.locator(".result").count() == 0
    assert page.get_by_role(
        "heading", name="Official week reference · no new recommendation"
    ).is_visible()
    page.screenshot(path=str(OUT / "07-timeout-reference.png"), full_page=True)
    page.unroute("**/api/decision")
    page.get_by_role("button", name="Retry calculation", exact=True).click()
    page.locator('.result[aria-busy="false"]').wait_for()
    checks.append(
        "Injected solver timeout shows labeled official reference, hides stale plan, and retries successfully"
    )
    assert not errors, errors
    assert not external, external
    checks.append(
        "All browser Internet destinations blocked; local API, assets and export still work"
    )
    browser.close()
(ROOT / "artifacts/demo_acceptance.json").write_text(
    json.dumps(
        {
            "passed": True,
            "checks": checks,
            "browser_errors": errors,
            "external_requests": external,
            "preflight_seconds": latency,
        },
        indent=2,
    )
)
# Publication-quality figures built from executed source-derived results.
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 12,
        "axes.spines.top": False,
        "axes.spines.right": False,
        "axes.labelcolor": "#345e61",
        "text.color": "#163e44",
        "axes.titleweight": "bold",
    }
)
s = pd.read_csv(ROOT / "artifacts/scenario_summary.csv")
colors = ["#168879", "#8eb6b0", "#d8ac62"]
fig, ax = plt.subplots(1, 2, figsize=(12, 4.8))
ax[0].bar(s.scenario_code, s.cost / 1000, color=colors)
ax[0].set(
    ylabel="Projected labor cost ($000)", title="Each scenario is a separate plan"
)
ax[1].bar(s.scenario_code, s.modeled_service * 100, color=colors)
ax[1].set(
    ylim=(0, 105),
    ylabel="Mean modeled target attainment (%)",
    title="Feasible staffing can retain service risk",
)
for axis, vals in zip(ax, [s.cost / 1000, s.modeled_service * 100]):
    for i, v in enumerate(vals):
        axis.text(i, v + 1, f"{v:.1f}", ha="center")
fig.text(
    0.05,
    0.02,
    "Simulated case • model estimates, not observed outcomes • source: artifacts/scenario_summary.csv",
    fontsize=9,
)
fig.tight_layout(rect=(0, 0.06, 1, 1))
for ext in ["png", "svg"]:
    fig.savefig(OUT / f"scenario-comparison.{ext}", dpi=200)
plt.close(fig)
d = preflight["scenes"][-1]
p = d["frontier"]
fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(
    [x["cost"] for x in p], [x["service"] * 100 for x in p], "o-", color="#168879", lw=2
)
ax.set(
    xlabel="Projected selected-block labor cost ($)",
    ylabel="Mean modeled target attainment (%)",
    title="Qualified capacity creates a finite frontier",
)
ax.grid(alpha=0.15)
fig.text(
    0.05,
    0.01,
    "W2 · Feb 13 OPEN · DISRUPT • sampled nondominated plans • source: live_demo_decisions.json",
    fontsize=8,
)
fig.tight_layout(rect=(0, 0.05, 1, 1))
for ext in ["png", "svg"]:
    fig.savefig(OUT / f"cost-service-frontier.{ext}", dpi=200)
plt.close(fig)
# The diagram depicts logic, without invented business quantities.
(OUT / "FORGE.svg").write_text(
    """<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="260" viewBox="0 0 1400 260"><rect width="1400" height="260" fill="#f2f7f4"/><text x="40" y="45" font-family="sans-serif" font-size="22" fill="#153c43">SHIFTWISE / FORGE — a repeatable management decision</text>"""
    + "".join(
        f'<rect x="{40+i*270}" y="85" width="240" height="110" rx="12" fill="#153c43"/><text x="{60+i*270}" y="125" font-family="sans-serif" font-size="28" fill="#8bd5b9">{letter}</text><text x="{60+i*270}" y="167" font-family="sans-serif" font-size="20" fill="white">{word}</text>'
        + (
            f'<text x="{288+i*270}" y="150" font-family="sans-serif" font-size="25" fill="#7a9e96">→</text>'
            if i < 4
            else ""
        )
        for i, (letter, word) in enumerate(
            zip(
                "FORGE",
                [
                    "Forecast demand",
                    "Optimize staffing",
                    "Reallocate workers",
                    "Guard service",
                    "Evaluate outcomes",
                ],
            )
        )
    )
    + '<text x="40" y="235" font-family="sans-serif" font-size="14" fill="#63827b">Official source data → validated models → integer workforce allocation → independent feasibility check → decision</text></svg>'
)
# Exact rehearsal figures are generated, not typed as demonstration answers.
lines = [
    "# SHIFTWISE live run of show",
    "",
    "Use the audited corrected CSV and current DEMO_ASSETS. All numerical effects below are projections from the executed local API, not observed or causal effects.",
    "",
    "## Before the audience arrives",
    "",
    "Run `./scripts/demo.sh` after installation. Wait for “demo ready”. It calculates and warms the four distinct official selections. Open port 8000 in a browser. Use a 1600×1100 or larger viewport; browser zoom 90–100%. Click Start guided demo. Reset always returns to Scene 1, official BASE, Service First. Do not alter source inputs.",
    "",
    "## Four-minute version",
    "",
    "| Time / slide cue | Exact click | What appears and what to say | Backup |",
    "|---|---|---|---|",
]
for i, scene in enumerate(preflight["scenes"]):
    if i < 3:
        rows = "; ".join(
            f"{a['department']}: {a['draft_employees']} draft → {a['employees']} recommended"
            for a in scene["plan"]["allocations"]
        )
        say = [
            "Start with the expected week. These are full-block employee assignments, not unique people.",
            "Promotion and weather increase official demand. The same capacity must do more work.",
            "Illness changes availability. A feasible plan may still have severe modeled service risk; low-probability plateaus are not evidence that real workers have no value.",
        ][i]
        content = f"{rows}. Selected-group projected cost ${scene['plan']['cost']:,.2f}; mean modeled target probability {scene['plan']['service']:.1%}. {say}"
    else:
        a = scene["last_worker"]["recommendation"]
        transfer = next(
            (o for o in scene["last_worker"]["alternatives"] if o["donor"]), None
        )
        content = (
            f"Balanced mode: add unused eligible capacity to { {38:'Front End',92:'Merchandising',95:'Pharmacy'}[a['recipient']] }; recipient +{a['recipient_gain']*100:.2f} pp, lender {a['donor_effect']*100:.2f} pp, incremental ${a['incremental_cost']:.2f}. "
            if a
            else "No beneficial one-worker change; retain allocation. "
        ) + (
            f"The borrowing alternative has net expected-target change {transfer['net_expected_targets_gain']:.4f}. Both departments matter; do not choose on recipient gain alone."
            if transfer
            else "No transfer preserves the workforce constraints."
        )
    lines.append(
        f"| {['0:00–0:40 / diagnosis','0:40–1:20 / pressure','1:20–2:10 / resilience','2:10–3:10 / signature decision'][i]} | {['Start guided demo','Click 2 PEAK','Click 3 DISRUPT','Click 4 LAST WORKER'][i]} | {content} | `DEMO_ASSETS/{files[i]}` |"
    )
lines += [
    "| 3:10–4:00 / recommendation | Click 5 DECIDE & EXPORT; inspect frontier; click Download 567-row official plan | Regular pools include outgoing loans once. Pharmacy never shares. Costs and service are projections. Export covers all official scenarios in Service First; this Balanced scene does not overwrite it. Close with: “The right worker, in the right place, within real limits.” | `DEMO_ASSETS/05-DECISION-EXPORT.png` |",
    "",
    "## Three-minute cut",
    "",
    "Spend 25 seconds each on BASE and PEAK, 40 on DISRUPT, 55 on Last Worker and 35 on certificate/frontier/export. Use the same five clicks and actual outputs; omit the forecast-method appendix and alternative-option exploration. At 2:25 move to Scene 5.",
    "",
    "## Optional five-minute discussion",
    "",
    "Exit presentation, open Scenario Lab, select warehouse 2, planning date Feb 14, MID shift and BASE. Move Demand multiplier to 125% and Available workforce to 80%, then click Recalculate. The Saturday Pharmacy pool can conflict with its minimum; explain that capacity-feasible best effort is not a valid minimum-staff schedule. Restore official assumptions before returning to the guide.",
    "",
    "## Failure and offline rehearsal",
    "",
    "No Internet is required after installation: all inputs, models, fonts and application code are local. Browser acceptance blocks every external hostname, and the Python test forbids outbound socket connections during model generation. If the solver times out, the app hides the stale recommendation and shows labeled official week reference totals. Retry once or reset assumptions. If the local server is unavailable, switch to the matching DEMO_ASSETS screenshot and explicitly call it a captured model result. Never imply the backup is a fresh calculation.",
    "",
    "## Presenter guardrails",
    "",
    "The forecast matches the supplied benchmark within rounding; do not claim it beats the benchmark. Six-week simulated history cannot prove a new holiday effect or real-world causal staffing benefit. Stress ranges are not confidence intervals. The frontier samples eight service tolerances. Equal-weight attainment excludes closed blocks. Standalone certificate maxima are not jointly additive. The 567-row CSV and audit remain the submission authority.",
    "",
    "Sources: `DEMO_ASSETS/live_demo_decisions.json`, `verified_presentation_claims.csv`, `INDEPENDENT_AUDIT.md`, `scenario_summary.csv`.",
]
(ROOT / "artifacts/demo_run_of_show.md").write_text("\n".join(lines) + "\n")
print(
    "Presentation assets and run of show created from live calculations. External requests:",
    external,
)

# Keep generated vector figures reviewable without altering SVG geometry.
for vector in OUT.glob("*.svg"):
    vector.write_text("\n".join(line.rstrip() for line in vector.read_text().splitlines()) + "\n")
