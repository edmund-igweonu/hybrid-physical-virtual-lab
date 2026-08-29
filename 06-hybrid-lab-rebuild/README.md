# Hybrid Lab Rebuild — frr1/frr2 dual-VLAN OSPF through physical 2950

Rebuilt after losing the original GNS3 project folder. Topology: Cloud1 (physical
2950 uplink) → Switch1 (GNS3 virtual switch, dot1q trunk ports) → frr1/frr2.

- OSPF Area 0, dual-homed across VLAN 10 (10.10.10.0/24) and VLAN 20 (10.10.20.0/24)
- Explicit router-IDs: frr1 = 1.1.1.1, frr2 = 2.2.2.2
- Loopbacks advertised into OSPF, confirmed ECMP (two equal-cost paths between loopbacks)
- Real 2950 in the path, trunk on Fa0/1 (`switchport mode trunk` — no encapsulation
  command needed/available on this hardware, dot1q is the only option)
- GNS3 built-in switch's "dot1q" port type is the trunk equivalent; frr1/frr2 do their
  own VLAN tagging via Linux `ip link add ... type vlan` subinterfaces (eth0.10, eth0.20)

## Extension: WAN link, VLAN 30, and persistent VLAN config

- Added a direct point-to-point WAN link between frr1/frr2 (192.168.100.0/30), separate from the VLAN trunk
- Added VLAN 30 (10.10.40.0/24) to the trunk — deliberately a different subnet from the
  log-monitoring lab's 10.10.30.0/24, kept separate on purpose
- frr1/frr2 are QEMU VMs (Alpine Linux, frr-8.2.2.qcow2), not Docker containers — reachable
  via GNS3 console, not `docker exec`
- Fixed VLAN subinterface persistence: Alpine's ifupdown/vlan package wasn't available, so
  VLAN creation is handled by an OpenRC `local` service script at
  `/etc/local.d/vlan-setup.start`, enabled via `rc-update add local default` — confirmed to
  survive a full VM reboot
- Full mesh OSPF adjacency across all four segments (VLAN 10, VLAN 20, VLAN 30, WAN link),
  confirmed 4-way ECMP to both loopbacks (1.1.1.1 and 2.2.2.2)
