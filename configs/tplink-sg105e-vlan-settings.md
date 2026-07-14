# TP-Link SG105E — VLAN Configuration

The SG105E is a web-managed "easy smart" switch with no CLI/config export, so settings are documented here manually.

**Device:** TL-SG105E, Hardware Version 5.0
**Firmware:** 1.0.0 Build 20250710 Rel.71066
**Management IP:** 192.168.0.1 (default, factory static)

## 802.1Q VLAN

| VLAN ID | VLAN Name | Member Ports | Tagged Ports | Untagged Ports |
|---|---|---|---|---|
| 1 | Default | 1-5 | — | 1-5 |
| 30 | BRANCH | 1, 5 | 5 | 1 |

- **Port 5**: tagged member of VLAN 30 — this is the trunk uplink to the Catalyst 2950 (Fa0/23)
- **Port 1**: untagged member of VLAN 30 — access port for test client

## 802.1Q PVID Setting

| Port | PVID |
|---|---|
| 1 | 30 |
| 5 | 1 (default, native VLAN for the trunk) |

PVID on Port 1 must match its untagged VLAN membership (30) — otherwise incoming untagged frames get classified into VLAN 1 by default instead of VLAN 30, even though the port is a member of VLAN 30.
