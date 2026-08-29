#!/bin/bash
set -e

# Assign a static IP to eth0 on every start, so this node doesn't
# need to be manually re-IP'd after every GNS3 restart. Override
# NODE_IP via the template's environment variables if needed.
NODE_IP="${NODE_IP:-10.10.30.243/24}"

# GNS3 attaches eth0 a moment after the container starts, so wait
# for it to actually exist (up to ~10s) before assigning the IP.
for i in $(seq 1 20); do
    if ip link show eth0 >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done
ip addr add "$NODE_IP" dev eth0 2>/dev/null || true
ip link set eth0 up

exec /usr/sbin/grafana-server \
    --homepath=/usr/share/grafana \
    --config=/etc/grafana/grafana.ini \
    cfg:default.paths.provisioning=/etc/grafana/provisioning
