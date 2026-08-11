# Netmiko Multi-Device Config Backup Automation

## Overview

This lab builds a Python automation script that connects to multiple network devices, both virtual and physical, and pulls a full running-config backup from each one. The goal was to move past manual CLI work and start building the kind of automation skills that show up in real NOC and junior network admin roles: config backup, credential handling, and mixed-protocol device access.

The lab covers three devices across two access methods:

- Two FRR routers (frr1, frr2) running in GNS3 Docker containers, accessed over SSH
- One physical Cisco Catalyst 2950 switch, accessed over Telnet with enable mode

Using both SSH and Telnet in the same script was intentional. Real environments often have a mix of modern SSH-capable gear and older devices that only support Telnet, and the 2950 turned out to be a genuine example of that rather than a contrived one.

## Topology

- frr1 and frr2 sit in a dedicated GNS3 project, each connected to a GNS3 NAT node so the Acer host can reach them without needing VLAN trunking or physical cabling.
- The 2950 is physical hardware, connected to the Acer's onboard NIC on FastEthernet0/1, with a management IP assigned on VLAN 1.
- The automation script runs directly on the Acer, inside a Python virtual environment, and reaches all three devices over the network.

## Environment setup

The script runs in a dedicated virtual environment to keep dependencies isolated from the system Python install (Ubuntu 24.04 blocks system-wide pip installs by default):

```bash
python3 -m venv netauto-env
source netauto-env/bin/activate
pip install netmiko python-dotenv
```

Core dependency is Netmiko, which handles SSH and Telnet sessions to network devices with device-type-specific logic built in. python-dotenv was added later to handle credentials properly (see below).

## Building the script

### Proof of concept

Before writing anything reusable, the first step was confirming Netmiko could actually reach and authenticate to a single device. frr1 was used as the test case:

```python
from netmiko import ConnectHandler

frr1 = {
    'device_type': 'linux',
    'host': '192.168.122.165',
    'username': 'root',
    'password': 'Pass4ubuntu!',
    'use_keys': False,
    'allow_agent': False,
}

conn = ConnectHandler(**frr1)
output = conn.send_command('show running-config')
print(output)
```

A few things came up here that are worth documenting rather than glossing over:

**FRR appliances drop straight into vtysh.** SSH into the FRR image lands directly at the `frr#` prompt rather than a normal Linux shell. Netmiko's `linux` device type still works fine here since it just sends raw commands over the session, but it's a good example of why `device_type` isn't always a straightforward match to the underlying OS.

**Netmiko can fail auth even when manual SSH works.** The first connection attempt threw a `NetmikoAuthenticationException` even though the same credentials worked fine over a manual `ssh` session. The cause was Paramiko (the SSH library Netmiko uses under the hood) trying key-based auth first, which can interfere with password auth depending on the server's `MaxAuthTries` setting. Adding `use_keys: False` and `allow_agent: False` to the connection dict forces password-only auth and resolved it.

### Scaling to multiple devices

Once the single-device connection worked, the script was restructured around a list of device dictionaries so it could loop through all of them instead of hardcoding one connection:

```python
devices = [
    {'name': 'frr1', 'device_type': 'linux', ...},
    {'name': 'frr2', 'device_type': 'linux', ...},
]

for device in devices:
    name = device.pop('name')
    try:
        conn = ConnectHandler(**device)
        output = conn.send_command('show running-config')
        conn.disconnect()
        # write to timestamped file
        print(f'[OK] {name} backed up')
    except Exception as e:
        print(f'[FAIL] {name}: {e}')
```

Wrapping each device in its own try/except was a deliberate choice. Without it, one unreachable or misconfigured device would kill the entire run. With it, the script logs a failure for that device and keeps going, which matters once the device list grows.

Backups are written to timestamped files (`backups/frr1_2026-08-10_115713.cfg`) rather than overwritten in place, so repeated runs build a history instead of destroying the previous state. That history is also what would feed a future diff step to detect config drift.

### Adding frr2: a same-image, different-behavior gotcha

Adding frr2 to the topology surfaced a good troubleshooting example. Both FRR nodes were built from the same base image, so the expectation was that whatever worked on frr1 would work identically on frr2. SSH access instead failed outright with repeated password rejections, even with a verified-correct password.

The actual cause was `PermitRootLogin`. frr1's image already had `PermitRootLogin yes` set. frr2's image had the OpenSSH default, `PermitRootLogin prohibit-password`, which silently blocks any password-based root login regardless of whether the password is correct. The fix was setting it explicitly on frr2:

```bash
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
service sshd restart
```

This was a useful reminder that "same base image" does not guarantee "same running configuration," especially across nodes that may have been cloned or built at different points.

### Adding the 2950: SSH is not always available

The plan was to add the 2950 to the script using SSH, matching the FRR nodes. That assumption broke immediately: the switch's IOS image (`c2950-i6q4l2-mz.121-22.EA2`) has no crypto support at all. The `crypto` command tree doesn't exist on this image, confirmed by running `crypto key generate rsa` and getting an immediate "unrecognized command" rather than a normal prompt sequence.

This is a real hardware constraint, not a config mistake, so the fix was switching that device to Telnet instead of trying to force SSH onto an image that doesn't support it:

```python
{
    'name': '2950',
    'device_type': 'cisco_ios_telnet',
    'host': '10.10.30.10',
    'password': 'Pass4ubuntu!',
    'secret': 'Pass4ubuntu!',
},
```

Getting basic Telnet reachability working also took some troubleshooting on the switch side:

- The management IP had never actually been assigned to VLAN 1; an earlier ping success was coming from a stale device on the same subnet left over from prior labs, not the switch itself, which was misleading until it was checked directly with `show ip interface brief`.
- Once a real IP was assigned, VLAN 1 came up but stayed in a protocol-down state. The physical link (FastEthernet0/1) was still a member of a leftover `channel-group` from the earlier static EtherChannel lab, bundled on VLAN 10, which conflicted with the port being reset to VLAN 1 and suspended it. Removing it from the channel-group with `no channel-group 1 mode on` resolved it.

### Enable mode: auto-enable does not always fire

Even after Telnet access worked, `show running-config` failed with "Invalid input detected," despite the credentials being correct. Checking `conn.find_prompt()` showed the session was still sitting in user mode (`Switch>`) rather than privileged mode (`Switch#`), which explains the error since `show running-config` requires privileged EXEC.

Netmiko is supposed to auto-enable when a `secret` is provided in the device dictionary, but that didn't happen reliably for this device. Calling `conn.enable()` explicitly worked immediately. The fix in the script was to check enable state and enable manually rather than relying on the automatic behavior:

```python
if not conn.check_enable_mode():
    conn.enable()
```

This check is also why FRR devices weren't affected: `check_enable_mode()` only triggers the enable sequence when needed, so it doesn't try to force an enable step on devices where that concept doesn't apply.

## Credential handling

The working script initially had all device passwords hardcoded as plain strings, which is fine for interactive testing but not something to commit to a public GitHub repo. The fix was moving every credential into a `.env` file and loading it at runtime with python-dotenv:

```
FRR1_PASSWORD=Pass4ubuntu!
FRR2_PASSWORD=test1234
SW2950_PASSWORD=Pass4ubuntu!
SW2950_SECRET=Pass4ubuntu!
```

```python
from dotenv import load_dotenv
import os

load_dotenv()

devices = [
    {
        'name': 'frr1',
        'device_type': 'linux',
        'host': '192.168.122.165',
        'username': 'root',
        'password': os.getenv('FRR1_PASSWORD'),
        'use_keys': False,
        'allow_agent': False,
    },
    ...
]
```

The `.env` file was locked down with `chmod 600` and excluded from version control via `.gitignore`, along with the `backups/` folder (which contains real device configs) and the `netauto-env/` virtual environment folder (large, platform-specific, and trivially reproducible from `requirements.txt`).

## Final script structure

```python
from netmiko import ConnectHandler
from datetime import datetime
from dotenv import load_dotenv
import os

load_dotenv()

devices = [
    {
        'name': 'frr1',
        'device_type': 'linux',
        'host': '192.168.122.165',
        'username': 'root',
        'password': os.getenv('FRR1_PASSWORD'),
        'use_keys': False,
        'allow_agent': False,
    },
    {
        'name': 'frr2',
        'device_type': 'linux',
        'host': '192.168.122.107',
        'username': 'root',
        'password': os.getenv('FRR2_PASSWORD'),
        'use_keys': False,
        'allow_agent': False,
    },
    {
        'name': '2950',
        'device_type': 'cisco_ios_telnet',
        'host': '10.10.30.10',
        'password': os.getenv('SW2950_PASSWORD'),
        'secret': os.getenv('SW2950_SECRET'),
    },
]

os.makedirs('backups', exist_ok=True)

for device in devices:
    name = device.pop('name')
    try:
        conn = ConnectHandler(**device)

        if not conn.check_enable_mode():
            conn.enable()

        output = conn.send_command('show running-config')
        conn.disconnect()

        timestamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')
        filename = f'backups/{name}_{timestamp}.cfg'

        with open(filename, 'w') as f:
            f.write(output)

        print(f'[OK] {name} backed up to {filename}')

    except Exception as e:
        print(f'[FAIL] {name}: {e}')
```

## Verification

Running the script produces a clean result across all three devices, mixing SSH and Telnet transports in a single run:

```
[OK] frr1 backed up to backups/frr1_2026-08-10_115713.cfg
[OK] frr2 backed up to backups/frr2_2026-08-10_115713.cfg
[OK] 2950 backed up to backups/2950_2026-08-10_115717.cfg
```

Each backup file contains the device's real running-config, confirmed by manual inspection against the output of `show running-config` run interactively on each device.

## Key takeaways

- Netmiko's `device_type` needs to match the actual session behavior, not just the OS. FRR's vtysh-on-login and the 2950's Telnet-only, enable-required access both needed adjustments outside the "just SSH in and run a command" default case.
- Identical base images can still behave differently. frr1 and frr2 needed different SSH configuration despite coming from the same image, which is a good example of not assuming environment parity without checking.
- Older hardware can impose hard protocol constraints. The 2950's lack of crypto support wasn't a misconfiguration to fix, it was a real limitation that shaped the design (Telnet instead of SSH, `cisco_ios_telnet` instead of `cisco_ios`).
- Automatic behaviors in libraries like Netmiko (auto-enable, in this case) are convenient when they work but worth verifying rather than trusting blindly, especially on less common platforms.
- Credential hygiene should happen before a script is considered done, not as an afterthought. Moving to `.env` plus `.gitignore` took about ten minutes and turned a working-but-unsafe script into something actually shareable.

## Next steps

- Add diff logic to compare each new backup against the previous one and flag config drift.
- Schedule the script via cron for nightly runs, with logging.
- Extend config push capability (`send_config_set`) once backup/pull is proven solid, since push carries more risk if something goes wrong mid-change.
