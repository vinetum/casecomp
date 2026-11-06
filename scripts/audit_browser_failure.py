"""Ensure an API failure never leaves stale decision values under changed filters."""

import json
from playwright.sync_api import sync_playwright
from pathlib import Path
import os

with sync_playwright() as p:
    b = p.chromium.launch(
        executable_path="/usr/bin/chromium", headless=True, args=["--no-sandbox"]
    )
    page = b.new_page()
    page.goto("http://127.0.0.1:" + os.environ.get("PORT", "8000") + "")
    page.locator('.result[aria-busy="false"]').wait_for(timeout=90000)
    page.route(
        "**/api/decision",
        lambda r: r.fulfill(
            status=503,
            content_type="application/json",
            body='{"detail":"audit injected failure"}',
        ),
    )
    page.get_by_role("button", name="PEAK", exact=True).click()
    page.get_by_role("alert").wait_for()
    assert page.locator(".result").count() == 0
    page.unroute("**/api/decision")
    page.get_by_role("button", name="Retry calculation", exact=True).click()
    page.locator('.result[aria-busy="false"]').wait_for()
    assert page.get_by_role("alert").count() == 0
    b.close()
Path("artifacts/audit_browser_failure.json").write_text(
    json.dumps(
        {
            "passed": True,
            "checks": [
                "Injected 503 hides stale decision",
                "Retry restores fresh computed values",
            ],
        },
        indent=2,
    )
)
