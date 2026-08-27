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
