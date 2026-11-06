# Your offline MacBook backup

The backup is the real SHIFTWISE application: it trains the same models, solves the same workforce problems, runs the guide and exports the actual audited CSV. It is not a slideshow or a screenshot substitute. Internet is needed for the **first installation only**. Do the installation and a Wi-Fi-off rehearsal before competition day.

## What your Mac needs

You reported a **MacBook Air running Tahoe 26.6.2**. That reported OS meets the minimum below. The chip was not specified; Python universal2 and the checked dependency wheels cover both Apple Silicon and Intel. This is a compatibility assessment, not a completed installation on your device.

- **macOS 14 (Sonoma) or later**, Apple Silicon (M-series) or Intel. All locked Python dependencies were successfully downloaded as native wheels for both architectures and Python 3.12. The locked SciPy release requires the macOS 14 wheels; do not assume an older Mac is supported.
- Enough free space for Python, Node and the environment (allow several GB), power, and a current Safari/Chrome browser.
- This task ran on Linux, not a physical MacBook. The portable launch/start/stop logic and offline app were tested; native Finder, installers, Gatekeeper and actual Mac hardware must still be rehearsed on your laptop. If your Mac is older, report its version before the event so a compatible dependency configuration can be investigated and revalidated.

## First-time setup — while you have Internet

1. Download and install **Python 3.12** for macOS from **https://www.python.org/downloads/macos/**. Choose the macOS **universal2 installer** for Python 3.12, not an older system Python. Run the downloaded `.pkg` and follow its Install prompts. If the Python installer provides **Install Certificates.command**, run it once; do not disable certificate checking if a download fails.
2. Download and install **Node.js 24 LTS** from **https://nodejs.org/** using its macOS installer. Run that `.pkg` and complete installation. These are one-time tools, not something you need to operate during the demo.
3. Sign in to GitHub, open **vinetum/casecomp**, choose branch **work**, then click **Code → Download ZIP**. Extract the ZIP. Move the entire extracted folder to an easy location, such as a SHIFTWISE folder in Documents. Keep it outside a cloud-only/“optimize storage” folder so files remain physically downloaded. Do not move only the .command files: they need the application folders beside them.
4. Open the extracted folder. Double-click **Install Mac Backup.command**. A Terminal window opens and installs the locked dependencies, builds the frontend and independently validates the submission. Keep the window open and Internet connected until it says installation passed.
5. If macOS blocks a `.command` file, confirm it came from your own verified repository, then use Finder's **Control-click → Open** if offered, or **System Settings → Privacy & Security → Open Anyway** for that specific file. Do not turn off Gatekeeper globally or run a random downloaded script. A managed school/work laptop may require its administrator's approval.
6. If Terminal says **permission denied** rather than a Gatekeeper message, use Terminal to give the three launchers execution permission: type `chmod +x ` (including a space), drag the `.command` file from Finder into Terminal, then press Return. Repeat for each launcher. You are not writing application code. If the error says Python or Node is missing, finish steps 1–2 and reopen the installer.
7. When the installer completes, press Return to close it. Leave `.venv-mac`, `frontend/dist`, the original source files and all other folders in place. Installation uses a dedicated native Mac environment; a Linux `.venv` copied from the cloud is not usable on a Mac.

## Start the real backup

1. Double-click **Start SHIFTWISE.command**.
2. Wait for **READY**. The first start may take up to two minutes while the source audit, models and official staffing plans are computed. The four guide selections are warmed from real calculations.
3. Your default browser opens the local dashboard. This address belongs to your own laptop, not Render. If the browser does not open, enter `http://127.0.0.1:8000` in its address bar.
4. Click **Start guided demo** and follow the five scenes. You do not need the hosted demo password: the backup is bound only to the Mac's loopback interface, not the Wi-Fi network.
5. You may close the startup window after READY; the app keeps running. To stop it, double-click **Stop SHIFTWISE.command**. Stop only targets the process started by this backup launcher. Opening Start again reuses an already-running backup rather than starting a second optimizer.

## Rehearse without Internet

1. Start once while online and verify all five scenes and CSV download.
2. Stop the app. Turn Wi-Fi off and disconnect any network cable.
3. Double-click Start again. This forces a genuinely offline startup from local inputs; do not merely leave an already-loaded page open.
4. Run BASE, PEAK, DISRUPT and Last Worker, exit the guide, change demand and availability in Scenario Lab, click Recalculate, then download the 567-row plan. Confirm the file is saved locally in Downloads.
5. Keep the Mac plugged in and prevent sleep during the presentation. Reconnect Internet only when you want to return to the hosted site.

The automated offline test forbids network connections during complete model generation. Browser rehearsal blocks external hosts while the local API and export work. Those checks do not replace testing your own Mac after its first installation.

## If something goes wrong

| Message / symptom | Action |
|---|---|
| “Install ... first” | Run Install Mac Backup.command while online; do not try downloading dependencies during the event. |
| “Port may be in use” | Close an older SHIFTWISE server with Stop. Do not kill unrelated apps. If you intentionally need a different port, a technical helper can run `.venv-mac/bin/python -m deployment.local_backup start --port 8001` from the folder. |
| Startup/warmup failed | Open `.local-run/backup.log` in the project folder (Finder Command-Shift-. shows hidden files). Keep the error text for diagnosis; do not post a secret. Retry once, then use a clearly labeled captured screenshot if the server cannot recover. |
| You moved the folder after installation | Stop first and rerun Install from the new location while online. Do not copy an environment between different Macs/architectures. |
| You removed Python/Node after installing | Restore Python 3.12; the running backup needs its Python interpreter. Node is needed to reinstall/rebuild but not during an already prepared offline demo. |
| macOS is below 14 | Do not assume this build works. Ask for a revalidated compatible setup before competition day. |

For a technical helper, all launcher code is in `scripts/install_mac.sh` and `deployment/local_backup.py`. No Docker, Render account, database, external model API or manual code changes are required on the Mac.
