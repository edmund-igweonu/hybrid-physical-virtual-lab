#!/usr/bin/env python3
"""Lab 20 (NOC in a Box) config backup.

Pulls the running-config from every device in the lab and saves each one to
backups/<UTC timestamp>/<device>.cfg, so folder names line up with the
device logs.

Physical devices (881-R1, 881-R2, 2950) log in with the TACACS+ account from .env.
Carrier routers (R2, R3, R4) are Dynamips nodes reached through their GNS3 console
ports, which are looked up from the GNS3 server API on every run.

Exit code is 0 if every device was backed up, 1 otherwise, so it can run from cron later.
"""

import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests
from dotenv import load_dotenv
from netmiko import ConnectHandler

load_dotenv()

LAB_USER = os.getenv("LAB_USER")
LAB_PASS = os.getenv("LAB_PASS")
LAB_ENABLE = os.getenv("LAB_ENABLE", "")

GNS3_URL = os.getenv("GNS3_URL", "http://127.0.0.1:3080")
GNS3_PROJECT = os.getenv("GNS3_PROJECT", "20-noc-in-a-box")
GNS3_USER = os.getenv("GNS3_USER")
GNS3_PASS = os.getenv("GNS3_PASS")

CARRIER_NODES = ["R2", "R3", "R4"]

PHYSICAL_DEVICES = [
    {"name": "881-R1", "device_type": "cisco_ios", "host": "10.10.30.1"},
    {"name": "881-R2", "device_type": "cisco_ios", "host": "10.20.50.1"},
    {"name": "2950", "device_type": "cisco_ios_telnet", "host": "10.10.30.10"},
]


def gns3_get(path):
    auth = (GNS3_USER, GNS3_PASS) if GNS3_USER else None
    response = requests.get(f"{GNS3_URL}/v2{path}", auth=auth, timeout=5)
    response.raise_for_status()
    return response.json()


def carrier_devices():
    """Build connection details for the carrier routers from the GNS3 API."""
    try:
        projects = gns3_get("/projects")
    except requests.RequestException as error:
        print(f"WARN  could not reach the GNS3 server at {GNS3_URL}: {error}")
        return []

    project = next((p for p in projects if p["name"] == GNS3_PROJECT), None)
    if project is None:
        print(f"WARN  GNS3 project '{GNS3_PROJECT}' not found")
        return []
    if project.get("status") != "opened":
        print(f"WARN  GNS3 project '{GNS3_PROJECT}' is not open")
        return []

    devices = []
    found = set()
    for node in gns3_get(f"/projects/{project['project_id']}/nodes"):
        if node["name"] not in CARRIER_NODES:
            continue
        found.add(node["name"])
        if node["status"] != "started":
            print(f"SKIP  {node['name']}: node is {node['status']}")
            continue
        devices.append(
            {
                "name": node["name"],
                "device_type": "cisco_ios_telnet",
                "host": "127.0.0.1",
                "port": node["console"],
                # GNS3 consoles have no login, so no credentials
                "username": "",
                "password": "",
            }
        )
    for name in CARRIER_NODES:
        if name not in found:
            print(f"SKIP  {name}: no node with that name in the GNS3 project")
    return devices


def backup(device, outdir):
    """Connect to one device, save its running-config, and report the result."""
    name = device["name"]
    params = {
        "username": LAB_USER,
        "password": LAB_PASS,
        "secret": LAB_ENABLE,
        "fast_cli": False,
        **{key: value for key, value in device.items() if key != "name"},
    }

    try:
        with ConnectHandler(**params) as conn:
            if not conn.check_enable_mode():
                conn.enable()
            config = conn.send_command("show running-config", read_timeout=90)
    except Exception as error:  # report every failure and keep going
        print(f"FAIL  {name}: {type(error).__name__}: {error}")
        return False

    if "hostname" not in config:
        print(f"FAIL  {name}: output does not look like a config")
        return False

    (outdir / f"{name}.cfg").write_text(config)
    print(f"OK    {name}")
    return True


def main():
    if not LAB_USER or not LAB_PASS:
        sys.exit("Set LAB_USER and LAB_PASS in .env first")

    outdir = Path(__file__).parent / "backups" / datetime.now(timezone.utc).strftime("%Y-%m-%d_%H%MZ")
    outdir.mkdir(parents=True, exist_ok=True)

    devices = PHYSICAL_DEVICES + carrier_devices()
    expected = len(PHYSICAL_DEVICES) + len(CARRIER_NODES)

    results = [backup(device, outdir) for device in devices]
    saved = sum(results)

    print(f"\n{saved} of {expected} devices backed up to {outdir}")
    sys.exit(0 if saved == expected else 1)


if __name__ == "__main__":
    main()
