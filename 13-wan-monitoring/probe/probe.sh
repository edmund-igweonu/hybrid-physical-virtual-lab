#!/bin/bash
INTERVAL="${INTERVAL:-30}"
GATEWAY="${GATEWAY:-192.168.2.1}"
LOGDIR=/var/log/wan-probe
LOGFILE="$LOGDIR/wan-probe.log"

mkdir -p "$LOGDIR"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { echo "$1" >> "$LOGFILE"; }

probe_icmp() {
  local name="$1" dest="$2" out loss rtt status
  out=$(ping -c 5 -i 0.2 -W 2 -q "$dest" 2>/dev/null)
  loss=$(echo "$out" | grep -o '[0-9]\+% packet loss' | grep -o '[0-9]\+')
  rtt=$(echo "$out" | awk -F'/' '/rtt|round-trip/ {split($4,a," "); print a[3]}')
  rtt_max=$(echo "$out" | awk -F'/' '/rtt|round-trip/ {print $5}')
  [ -z "$loss" ] && loss=100
  [ -z "$rtt" ] && rtt=0
  if [ "$loss" = "100" ]; then
    status=fail
  elif [ "$loss" != "0" ]; then
    status=degraded
  elif awk "BEGIN{exit !($rtt > 100)}"; then
    status=degraded
  else
    status=ok
  fi
    log "ts=$(ts) probe=icmp target=$name dest=$dest rtt_ms=$rtt rtt_max_ms=$rtt_max loss_pct=$loss status=$status"
}

probe_dns() {
  local name="$1" server="$2" out qtime status
  out=$(dig +tries=1 +time=2 @"$server" example.com A 2>/dev/null)
  qtime=$(echo "$out" | awk '/Query time:/ {print $4}')
  if [ -z "$qtime" ]; then
    qtime=0
    status=fail
  else
    status=ok
  fi
  log "ts=$(ts) probe=dns target=$name dest=$server query_ms=$qtime status=$status"
}

probe_http() {
  local name="$1" url="$2" res code total status
  res=$(curl -o /dev/null -s -m 10 -w '%{http_code} %{time_total}' "$url" 2>/dev/null)
  code=$(echo "$res" | awk '{print $1}')
  total=$(echo "$res" | awk '{printf "%.1f", $2*1000}')
  [ -z "$code" ] && code=000
  [ -z "$total" ] && total=0
  if [ "$code" = "000" ]; then status=fail; else status=ok; fi
  log "ts=$(ts) probe=http target=$name http_code=$code total_ms=$total status=$status"
}

log "ts=$(ts) probe=startup target=self gateway=$GATEWAY interval_s=$INTERVAL status=ok"

while true; do
  probe_icmp gateway "$GATEWAY"
  probe_icmp cloudflare 1.1.1.1
  probe_icmp google 8.8.8.8
  probe_dns gateway_dns "$GATEWAY"
  probe_dns cloudflare_dns 1.1.1.1
  probe_http google204 https://www.google.com/generate_204
  sleep "$INTERVAL"
done
