# Hybrid Physical/Virtual Network Lab

This is my main hands-on networking lab, where I mix real hardware (a Cisco Catalyst 2950 and a TP-Link SG105E) with virtual gear in GNS3 and Packet Tracer. Each folder below is its own lab covering a different topic, usually with a topology diagram, configs, and a writeup of how the build went, including whatever broke along the way.

## Hardware

- Cisco Catalyst 2950 (physical switch)
- TP-Link SG105E (physical switch)
- Acer Aspire A515-54 running Ubuntu 24.04 + GNS3, with KVM acceleration
- MacBook Air M4 for general lab work and as a physical test host

## Labs

| Folder | Topic |
|---|---|
| [`00-enterprise-vlan-ospf-lab/`](./00-enterprise-vlan-ospf-lab) | **Flagship build.** This is the lab the whole repo grew out of: a two-site (HQ + Branch) multi-VLAN enterprise network with real Cisco/TP-Link switching hardware bridged into a GNS3 virtual OSPF routing setup. |
| [`01-lacp-vs-static-etherchannel/`](./01-lacp-vs-static-etherchannel) | Comparing LACP EtherChannel (GNS3 Docker, Linux bonding) against static EtherChannel on physical gear, with failover testing on both. |
| [`02-three-legged-firewall-nat/`](./02-three-legged-firewall-nat) | A three-legged firewall/NAT setup with inside, outside, and DMZ zones. iptables ACLs, NAT masquerade, and a real host sitting on the inside leg. |
| [`03-site-to-site-gre-ipsec-vpn/`](./03-site-to-site-gre-ipsec-vpn) | Site-to-site GRE-over-IPsec VPN using strongSwan, built across a routed "ISP" hop and then extended into a hybrid build with a real host on each end. |
| [`04-netmiko-config-backup/`](./04-netmiko-config-backup) | A Python/Netmiko script that pulls and timestamps config backups from the FRR routers and the physical 2950. |
| [`05-l2-security-suite/`](./05-l2-security-suite) | Layer 2 security on the physical 2950: DHCP snooping with a legit vs. rogue DHCP server setup, plus port security. |

A port-mirroring/Wireshark lab and an OSPF multi-area topology are in progress and will get added here once they're pushed.

## Why hybrid

Most of these labs mix physical and virtual gear on purpose instead of staying fully virtual. The point is to get comfortable with the stuff that only shows up on real hardware, like console cabling, STP forwarding delays, and cable-pull failover, while still keeping the repeatability that GNS3/Docker topologies give you.
