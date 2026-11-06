"""Acceptance-only kernel rlimit + measured CPU supervisor when cgroups are unavailable.
NOT the Render entrypoint. Does not pretend a per-process limit is a container cgroup.
"""

import json, os, resource, signal, subprocess, time
from pathlib import Path

CPU = float(os.environ.get("PROBE_CPUS", "0.1"))
APP_BYTES = 768 * 1024**2
OUT = Path("/app/artifacts/resource_probe.json")


def usage(pid):
    try:
        values = {
            line.split(":")[0]: line.split(":")[1].strip()
            for line in Path(f"/proc/{pid}/status").read_text().splitlines()
            if ":" in line
        }
        tail = Path(f"/proc/{pid}/stat").read_text().split(")")[-1].split()
        return (
            int(values.get("VmRSS", "0 kB").split()[0]) * 1024,
            int(values.get("VmHWM", "0 kB").split()[0]) * 1024,
            (int(tail[11]) + int(tail[12])) / os.sysconf("SC_CLK_TCK"),
        )
    except (FileNotFoundError, ProcessLookupError):
        return 0, 0, 0.0


def bound():
    resource.setrlimit(resource.RLIMIT_AS, (APP_BYTES, APP_BYTES))


child = subprocess.Popen(
    ["/app/deployment/start.sh"], preexec_fn=bound, start_new_session=True
)
# Combined hard address-space ceilings for the application and its supervisor:
# Virtual mappings are not resident RAM. The 768 MiB AS guard is separate
# from the monitored 512 MiB RSS ceiling, and is NOT a cgroup limit.
resource.setrlimit(resource.RLIMIT_AS, (48 * 1024**2, 48 * 1024**2))
begin = time.monotonic()
parent_base = usage(os.getpid())[2]
stopping = False
last_write = 0.0
peak = 0
app_hwm = 0
super_hwm = 0
child_cpu = 0.0


def stop(*_):
    global stopping
    stopping = True
    try:
        os.killpg(child.pid, signal.SIGCONT)
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
try:
    while child.poll() is None:
        rss, hwm, cpu = usage(child.pid)
        prss, phwm, pcpu = usage(os.getpid())
        wall = time.monotonic() - begin
        peak = max(peak, rss + prss)
        if rss + prss > 512 * 1024**2:
            stop()
            raise RuntimeError("Observed application/supervisor RSS exceeded 512 MiB")
        app_hwm = max(app_hwm, hwm)
        super_hwm = max(super_hwm, phwm)
        child_cpu = max(child_cpu, cpu)
        if time.monotonic() - last_write > 1:
            payload = {
                "application_address_space_limit_bytes": APP_BYTES,
                "supervisor_address_space_limit_bytes": 48 * 1024**2,
                "sampled_peak_rss_bytes": peak,
                "application_peak_rss_bytes": app_hwm,
                "supervisor_peak_rss_bytes": super_hwm,
                "conservative_sum_peak_rss_bytes": app_hwm + super_hwm,
                "application_cpu_seconds": child_cpu,
                "total_cpu_seconds": child_cpu + pcpu - parent_base,
                "wall_seconds": wall,
                "cpu_fraction": (child_cpu + pcpu - parent_base) / max(wall, 0.001),
                "target_cpu_fraction": CPU,
                "container_cgroups_enforced": False,
                "measurement": "/proc VmHWM + sampled RSS; hard per-process RLIMIT_AS. File cache is excluded.",
            }
            temporary = OUT.with_suffix(".tmp")
            temporary.write_text(json.dumps(payload, indent=2))
            temporary.replace(OUT)
            last_write = time.monotonic()
        debt = (cpu + pcpu - parent_base) - wall * CPU - 0.01
        if debt > 0 and not stopping:
            os.killpg(child.pid, signal.SIGSTOP)
            time.sleep(min(0.25, max(0.005, debt / CPU)))
            os.killpg(child.pid, signal.SIGCONT)
        else:
            time.sleep(0.01)
    raise SystemExit(child.returncode)
finally:
    if child.poll() is None:
        stop()
        child.wait(timeout=30)
