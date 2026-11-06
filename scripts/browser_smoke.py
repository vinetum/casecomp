"""Run against the production server. Uses a real browser, API controls and CSV download."""

import argparse
import csv
import io
import json
import os
import time
import urllib.request
from pathlib import Path
from playwright.sync_api import sync_playwright

p = argparse.ArgumentParser()
p.add_argument("--url", default="http://127.0.0.1:8000")
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
out = root / "artifacts"
screens = out / "screenshots"
screens.mkdir(exist_ok=True)
for attempt in range(120):
    try:
        with urllib.request.urlopen(args.url + "/api/health", timeout=5) as r:
            if json.load(r)["submission_valid"]:
                break
    except OSError:
        time.sleep(1)
else:
    raise RuntimeError("Server did not become ready")
errors = []
checks = []
with sync_playwright() as pw:
    browser = pw.chromium.launch(
        executable_path=os.environ.get("CHROMIUM_PATH", "/usr/bin/chromium"),
        headless=True,
        args=["--no-sandbox"],
    )
    page = browser.new_page(
        viewport={"width": 1600, "height": 1100}, device_scale_factor=1
    )
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto(args.url, wait_until="networkidle")
    page.locator('.result[aria-busy="false"]').wait_for(timeout=120000)
    assert page.get_by_role("heading", name="Command Center", exact=True).is_visible()
    page.screenshot(path=str(screens / "01-command-center.png"), full_page=True)
    checks.append("Production dashboard renders actual computed data")
    for tab, name in [
        ("Demand Intelligence", "02-demand"),
        ("Staffing Optimizer", "03-staffing"),
    ]:
        page.get_by_role("button", name=tab, exact=True).click()
        assert page.get_by_role("heading", name=tab, exact=True).is_visible()
        page.screenshot(path=str(screens / f"{name}.png"), full_page=True)
    checks.append("Demand and optimizer screens render")
    with page.expect_response(
        lambda r: r.url.endswith("/api/decision") and r.request.method == "POST"
    ) as response:
        page.get_by_role("button", name="Balanced", exact=True).click()
    assert response.value.status == 200
    assert response.value.json()["selection"]["mode"] == "Balanced"
    page.locator('.result[aria-busy="false"]').wait_for()
    checks.append("Operating mode invokes solver")
    page.get_by_role("button", name="Scenario Lab", exact=True).click()
    results = []
    for scenario in ["PEAK", "DISRUPT", "BASE"]:
        with page.expect_response(
            lambda r: r.url.endswith("/api/decision") and r.request.method == "POST"
        ) as response:
            page.get_by_role("button", name=scenario, exact=True).click()
        d = response.value.json()
        assert response.value.status == 200
        assert d["certificate"]["independent_verification"]["valid"]
        results.append([a["employees"] for a in d["plan"]["allocations"]])
        page.locator('.result[aria-busy="false"]').wait_for()
    assert len({tuple(x) for x in results}) > 1
    checks.append("BASE, PEAK and DISRUPT produce recomputed feasible allocations")
    page.get_by_label("Demand multiplier", exact=True).focus()
    page.keyboard.press("Home")
    for _ in range(11):
        page.keyboard.press("ArrowRight")
    page.get_by_label("Available workforce", exact=True).focus()
    page.keyboard.press("Home")
    for _ in range(16):
        page.keyboard.press("ArrowRight")
    with page.expect_response(
        lambda r: r.url.endswith("/api/decision") and r.request.method == "POST"
    ) as response:
        page.get_by_role("button", name="Recalculate", exact=True).click()
    d = response.value.json()
    assert (
        d["selection"]["demand_factor"] == 1.25
        and d["selection"]["availability_factor"] == 0.8
    )
    assert d["certificate"]["capacity_verified"]
    assert d["certificate"]["status"] == "MINIMUM_CONFLICT"
    page.locator('.result[aria-busy="false"]').wait_for()
    page.screenshot(path=str(screens / "04-scenario-lab.png"), full_page=True)
    checks.append(
        "Demand and availability sliders run real optimization and disclose a genuine pharmacy minimum conflict"
    )
    page.get_by_role("button", name="Decision & Export", exact=True).click()
    assert page.get_by_role("heading", name="The Last Worker", exact=True).is_visible()
    assert page.get_by_role(
        "heading", name="Feasibility Certificate", exact=True
    ).is_visible()
    page.get_by_role(
        "button", name="Inspect frontier alternative 1", exact=True
    ).click()
    page.get_by_label("Team ID", exact=True).fill("BROWSER_TEST")
    with page.expect_download() as download:
        page.get_by_role(
            "button", name="Download staffing submission", exact=True
        ).click()
    downloaded = Path(download.value.path())
    download.value.save_as(str(out / "browser_download.csv"))
    rows = list(csv.DictReader(io.StringIO(downloaded.read_text())))
    assert len(rows) == 567 and all(r["team_id"] == "BROWSER_TEST" for r in rows)
    assert all(int(r["submitted_employees"]) >= 0 for r in rows)
    assert all(r["is_open"] != "0" or int(r["submitted_employees"]) == 0 for r in rows)
    checks.append(
        "Last Worker, certificate, interactive frontier and 567-row download work"
    )
    page.screenshot(path=str(screens / "05-decision-export.png"), full_page=True)

    def change_control(action):
        with page.expect_response(
            lambda r: r.url.endswith("/api/decision") and r.request.method == "POST"
        ) as response:
            action()
        value = response.value.json()
        assert response.value.status == 200
        page.locator('.result[aria-busy="false"]').wait_for()
        return value

    change_control(lambda: page.get_by_role("button", name="Reset", exact=True).click())
    change_control(
        lambda: page.get_by_label("Planning date", exact=True).select_option(
            "2026-02-13"
        )
    )
    change_control(lambda: page.get_by_label("Shift", exact=True).select_option("OPEN"))
    snapshot = change_control(
        lambda: page.get_by_role("button", name="DISRUPT", exact=True).click()
    )
    assert snapshot["certificate"]["independent_verification"]["valid"]
    (out / "demonstration_snapshot.json").write_text(json.dumps(snapshot, indent=2))
    page.screenshot(path=str(screens / "07-last-worker-official.png"), full_page=True)
    checks.append("Official DISRUPT Last Worker decision captured from the running UI")
    page.get_by_role("button", name="Start guided demo", exact=True).click()
    page.locator('.result[aria-busy="false"]').wait_for()
    assert page.get_by_text("Scene 1 / 4", exact=False).is_visible()
    checks.append("Guided tour invokes real scenario selection")
    page.set_viewport_size({"width": 430, "height": 900})
    page.screenshot(path=str(screens / "06-mobile.png"), full_page=True)
    assert page.evaluate("document.documentElement.scrollWidth <= window.innerWidth")
    checks.append("Mobile viewport has no page-level horizontal overflow")
    assert not errors, errors
    browser.close()
result = {
    "passed": True,
    "checks": checks,
    "browser_errors": errors,
    "screenshots": sorted(p.name for p in screens.glob("*.png")),
}
(out / "browser_test_results.json").write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
