#!/bin/bash
NODE_IP=${NODE_IP:-10.10.30.245/24}
GW=${GW:-10.10.30.10}

for i in $(seq 1 30); do
    ip link show eth0 >/dev/null 2>&1 && break
    sleep 1
done

ip addr add $NODE_IP dev eth0 2>/dev/null
ip link set eth0 up
ip route add default via $GW 2>/dev/null

exec /bin/bash
