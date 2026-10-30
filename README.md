# Hybrid Physical/Virtual Network Lab

This is my main hands-on networking lab, where I mix real hardware (two Cisco 881 routers, a Cisco Catalyst 2950 and a TP-Link SG105E) with virtual gear in GNS3 and Packet Tracer. Each folder below is its own lab covering a different topic, usually with a topology diagram, configs, and a writeup of how the build went, including whatever broke along the way.

## Hardware

- 2x Cisco 881G routers (physical, IOS 15.7(3)M9 with the advipservices license)
- Cisco Catalyst 2950 (physical switch)
- TP-Link SG105E (physical switch)
- Acer Aspire A515-54 running Ubuntu 24.04 + GNS3, with KVM acceleration (FRR, Docker nodes and Cisco c2691 IOS routers)
- MacBook Air M4 for general lab work and as a physical test host

## Labs

| Folder | Topic |
|---|---|
| `00-enterprise-vlan-ospf-lab/` | **Flagship build.** This is the lab the whole repo grew out of: a two-site (HQ + Branch) multi-VLAN enterprise network with real Cisco/TP-Link switching hardware bridged into a GNS3 virtual OSPF routing setup. |
| `01-lacp-vs-static-etherchannel/` | Comparing LACP EtherChannel (GNS3 Docker, Linux bonding) against static EtherChannel on physical gear, with failover testing on both. |
| `02-three-legged-firewall-nat/` | A three-legged firewall/NAT setup with inside, outside, and DMZ zones. iptables ACLs, NAT masquerade, and a real host sitting on the inside leg. |
| `03-site-to-site-gre-ipsec-vpn/` | Site-to-site GRE-over-IPsec VPN using strongSwan, built across a routed "ISP" hop and then extended into a hybrid build with a real host on each end. |
| `04-netmiko-config-backup/` | A Python/Netmiko script that pulls and timestamps config backups from the FRR routers and the physical 2950. |
| `05-l2-security-suite/` | Layer 2 security on the physical 2950: DHCP snooping with a legit vs. rogue DHCP server setup, plus port security. |
| `06-hybrid-lab-rebuild/` | Rebuild of the original hybrid lab: two FRR routers running dual-VLAN OSPF, trunked through the physical 2950. |
| `07-tacacs-aaa/` | Centralized AAA on the 2950 against a self-hosted tac_plus server, with privilege levels, command accounting, and accounting records fed into Loki. |
| `08-dot1x-nac/` | 802.1X port-based access control with FreeRADIUS, the 2950 as authenticator and a Linux supplicant, including what the 2950's image can't do. |
| `09-ebgp-multias/` | A three-AS eBGP triangle on FRR, with a LOCAL_PREF policy that flips the best path, checked by traceroute and a BGP UPDATE capture. |
| `10-vrrp-fhrp/` | VRRP on FRR QEMU nodes. Master/Backup election works; the failover demo is listed as a known gap. |
| `11-redistribution/` | EIGRP, OSPF and BGP redistribution across a five-router Cisco c2691 chain, with the two redistribution gotchas I hit. |
| `12-hsrp-fhrp/` | HSRP on virtual Cisco c2691 routers. |
| `13-wan-monitoring/` | Synthetic WAN monitoring of my home internet path, with latency and loss graphed in Loki and Grafana. |
| `14-mpls-l3vpn/` | MPLS L3VPN on c2691s: P and PE core, two customers in separate VRFs with overlapping subnets to prove isolation. |
| `15-stp-pvst/` | PVST+ on c2691 EtherSwitch modules: root election, per-VLAN root split, blocking, failover timing and BPDU capture. |
| `16-hsrp-physical/` | **First lab on the physical 881s.** HSRP with interface tracking and a real cable-pull failover, measured from a client pinging the virtual gateway. |
| `17-ip-sla-tracking/` | Extends lab 16 with IP SLA, so the Active router steps down when its upstream stops answering even though its link stays up. |

## Why hybrid

Most of these labs mix physical and virtual gear on purpose instead of staying fully virtual. The point is to get comfortable with the stuff that only shows up on real hardware, like console cabling, STP forwarding delays, and cable-pull failover, while still keeping the repeatability that GNS3/Docker topologies give you.
