#!/bin/bash
set -e

# Assign a static IP to eth0 on every start, so this node doesn't
# need to be manually re-IP'd after every GNS3 restart. Override
# NODE_IP via the template's environment variables if needed.
NODE_IP="${NODE_IP:-10.10.30.241/24}"

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

# Clear any stale pidfile left over from a previous run (container
# restarts can leave /run/rsyslogd.pid behind, causing a fresh
# rsyslogd launch to fail thinking another instance is active).
rm -f /run/rsyslogd.pid

# Start rsyslogd in the background
rsyslogd -n &
RSYSLOG_PID=$!

# Give it a second to create /var/log/remote entries before promtail scans
sleep 2

# Start promtail in the foreground so it's PID 1's child and keeps the
# container alive; if rsyslogd dies, kill promtail too so GNS3/Docker
# sees the node as stopped rather than half-alive.
promtail -config.file=/etc/promtail/promtail-config.yaml &
PROMTAIL_PID=$!

wait -n "$RSYSLOG_PID" "$PROMTAIL_PID"
