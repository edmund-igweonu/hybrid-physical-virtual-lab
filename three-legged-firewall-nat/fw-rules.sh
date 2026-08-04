#!/bin/bash

IN=eth0    # inside, 10.10.10.0/24
OUT=eth1   # outside, 203.0.113.0/24
DMZ=eth2   # dmz, 172.16.0.0/24

iptables -F
iptables -X
iptables -t nat -F

# default deny
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# allow traffic to/from the firewall itself (lab convenience: ping/curl testing)
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT

# established/related traffic passes back through in both directions
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# NAT: inside and dmz masquerade out the WAN leg
iptables -t nat -A POSTROUTING -o $OUT -s 10.10.10.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -o $OUT -s 172.16.0.0/24 -j MASQUERADE

# inside -> dmz: web ports only
iptables -A FORWARD -i $IN -o $DMZ -p tcp --dport 80  -j ACCEPT
iptables -A FORWARD -i $IN -o $DMZ -p tcp --dport 443 -j ACCEPT

# outside -> dmz: web ports only (the public-facing service rule)
iptables -A FORWARD -i $OUT -o $DMZ -p tcp --dport 80  -j ACCEPT
iptables -A FORWARD -i $OUT -o $DMZ -p tcp --dport 443 -j ACCEPT

# inside -> outside: general egress
iptables -A FORWARD -i $IN -o $OUT -j ACCEPT

# dmz -> inside: explicitly denied and logged
iptables -A FORWARD -i $DMZ -o $IN -j LOG --log-prefix "DMZ->INSIDE-BLOCKED: " --log-level 4
iptables -A FORWARD -i $DMZ -o $IN -j DROP

# outside -> inside: explicitly denied and logged
iptables -A FORWARD -i $OUT -o $IN -j LOG --log-prefix "OUTSIDE->INSIDE-BLOCKED: " --log-level 4
iptables -A FORWARD -i $OUT -o $IN -j DROP

echo "Rules applied."
iptables -L -v -n
