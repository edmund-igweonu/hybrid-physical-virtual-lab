# Centralized logging lab - build notes

## Status

**Phase 1 (2950 -> rsyslog-node -> Loki -> Grafana): complete and
verified end-to-end.** Real syslog events from the physical 2950
switch are confirmed flowing through the full pipeline and queryable
out of Loki (see "Verify" section below for the exact command and
what it returns).

**Phase 2 (frr1/frr2 integration): planned, not started.** frr1 and
frr2 currently live in a separate GNS3 project
(hybrid-physical-virtual-lab) and aren't reachable from this one.
Bringing them in requires either merging this lab's nodes into that
project, or bridging the two projects' Cloud nodes - a distinct
chunk of work, intentionally left for a follow-up rather than
blocking this phase's commit.

Built in a dedicated GNS3 project (`log-monitoring-lab`), separate
from the main hybrid-physical-virtual-lab project, so this could be
built/broken freely without risking the working lab.

Topology: 2950 (physical) -> Cloud node (bound to the Acer's onboard
NIC, enp1s0) -> Switch1 (GNS3 built-in Ethernet switch) -> rsyslog-node,
loki-node, grafana-node (all three linked to Switch1, flat L2 segment).

Addressing: **10.10.30.0/24**, matching the 2950's existing Vlan1 SVI
(10.10.30.10) rather than routing between subnets.
- rsyslog-node: 10.10.30.241
- loki-node: 10.10.30.242
- grafana-node: 10.10.30.243

All three nodes are custom-built Ubuntu 24.04 images, not the stock
grafana/loki or grafana/grafana images - see "Known issues" below for
why. Each has its own Dockerfile + entrypoint.sh in this repo.

## Topology

    2950 (physical)
      |
    Cloud1  (bound to Acer's enp1s0 - bridges the physical wire in)
      |
    Switch1  (GNS3 built-in Ethernet switch, flat L2 segment)
      |-- rsyslog-node-1  (10.10.30.241)
      |-- loki-node-1     (10.10.30.242)
      |-- grafana-node-1  (10.10.30.243)

Data flow: 2950 sends syslog -> rsyslog-node writes it to disk and
forwards via Promtail -> loki-node stores/indexes it -> grafana-node
queries Loki for display.

A screenshot of the live GNS3 canvas is saved as `topology.png` in
this folder - drop the actual PNG file alongside this notes.md so it
renders in any repo viewer.

## Build order

## 1. Build all three images

    cd log-monitoring-lab/rsyslog-node && docker build -t rsyslog-node .
    cd ../loki-node && docker build -t loki-node .
    cd ../grafana-node && docker build -t grafana-node .

## 2. Create GNS3 templates

For each: Edit -> Preferences -> Docker -> Docker containers -> New ->
Existing image -> pick the locally-built tag (`rsyslog-node:latest`,
`loki-node:latest`, `grafana-node:latest` - NOT the stock grafana/*
images, which will also show in the picker since Docker caches them
locally). 1 adapter each. Console type `http` for loki-node (port
3100) and grafana-node (port 3000); telnet is fine for rsyslog-node.

## 3. IP assignment

rsyslog-node self-assigns its IP on every boot (baked into
entrypoint.sh via a `NODE_IP` env var, defaults to 10.10.30.241/24).
loki-node and grafana-node entrypoints now do the same
(10.10.30.242/24 and 10.10.30.243/24) - this was a manual `ip addr
add` step for a while during debugging; it's fixed in the current
Dockerfiles.

If a node ever needs a different IP, override the `NODE_IP`
environment variable on its GNS3 template instead of editing the
entrypoint.

## 4. Point the 2950 at the collector

    conf t
    logging host 10.10.30.241
    logging trap informational
    logging facility local0
    end
    write memory

`logging trap informational` covers interface up/down, STP topology
changes, and config changes - enough to generate real events without
flooding on debug-level noise.

## 5. Point frr1 / frr2 at the collector (not yet done)

frr1/frr2 live in the *other* GNS3 project and aren't reachable from
this one without bridging the two topologies or merging the nodes
into one project. Not attempted yet - see "Later" section.

    echo '*.* @@10.10.30.241:514' >> /etc/rsyslog.conf
    systemctl restart rsyslog

## 6. Skip the SG105E

No syslog support on this switch, consistent with it lacking STP
and any managed logging features. Same call as the DAI limitation
on the 2950 - document it in the writeup rather than working around
it with a substitute device.

## 7. Verify

Confirmed working via Loki's own HTTP API (bypasses the Grafana UI
bug noted below entirely):

    curl -s -G "http://10.10.30.242:3100/loki/api/v1/query_range" \
      --data-urlencode 'query={job="syslog"}' \
      --data-urlencode "start=$(date -d '1 hour ago' +%s%N)" \
      --data-urlencode "end=$(date +%s%N)"

Returns real 2950 log lines labeled with `host`, `job`, `filename`.
This is the authoritative verification method for this lab - screen-
shots of Grafana's UI are not reliable given the bug below.

## Known issues / environment quirks

- **GNS3 always wraps container startup with `/gns3/init.sh`**,
  regardless of console type. This requires a working `/bin/bash` and
  a sane account/nsswitch setup inside the image, which the stock
  `grafana/loki` (Alpine, no bash) and `grafana/grafana` images don't
  have. Fixed by building custom Ubuntu 24.04 images for both instead
  of using the stock ones.
- **Loki's ring lifecycler fails on boot** if `eth0` has no IP yet
  when Loki starts (tries to autodetect an address on eth0/en0/lo and
  crashes if none found). Fixed by setting `instance_addr: 127.0.0.1`
  explicitly under `common.ring` in loki-config.yaml.
- **The apt-installed Grafana binary lives at `/usr/sbin/grafana-server`**,
  not `/usr/share/grafana/bin/grafana-server` (that path is correct
  for the tarball release, not the .deb package).
- **rsyslogd leaves a stale `/run/rsyslogd.pid`** if the container is
  restarted without a clean shutdown, causing the next `rsyslogd -n`
  to fail thinking another instance is running. Fixed by `rm -f
  /run/rsyslogd.pid` at the top of rsyslog-node's entrypoint.sh.
- **Every fresh/recreated container gets a new MAC address**, and the
  2950 caches ARP entries. If you delete and recreate a node, the
  switch's `show arp` may still point syslog traffic at the dead MAC,
  silently dropping it with no error on either side. Fix: `clear
  arp-cache` on the 2950 after recreating any node. This was the
  single hardest bug to isolate this build - confirmed via GNS3's
  per-link Wireshark capture that packets *were* leaving the switch
  and reaching rsyslog-node's eth0, before finding the switch's ARP
  table was the actual block.
- **This Grafana instance's Explore UI will not honor Loki as the
  selected data source**, through any entry point tried (the picker
  dropdown, the per-query source selector, Loki's own "Explore data"
  button, a hand-built URL with the datasource UID embedded, a fresh
  private/incognito browser session). The Loki data source itself is
  confirmed correctly registered (visible and correct under
  Connections -> Data sources, `Save & test` succeeds). Root cause
  not identified - suspected Grafana version quirk or an interaction
  with GNS3's HTTP console proxy rewriting the page in a way that
  breaks Explore's client-side state. Workaround: verify ingestion via
  Loki's HTTP API directly (see "Verify" above) rather than the
  Grafana UI.
- **The host machine (the Acer itself) has no clean route into
  10.10.30.0/24** since that subnet only exists inside GNS3's Cloud
  node bridge, not as a real host interface. A manual `ip addr add
  10.10.30.250/24 dev enp1s0` on the host works but is not
  persistent and still hits intermittent ARP failures reaching lab
  nodes directly from the host/browser. Prefer running curl/exec
  commands *inside* one of the lab containers (e.g. `docker exec
  rsyslog-node curl ...`) over from the host directly.
- **Grafana's provisioned datasource only inserts once** - if the
  provisioning YAML is edited after first boot, Grafana won't
  re-insert or auto-update it on restart. Fix drift via the API
  directly: `curl -X PUT .../api/datasources/uid/<uid> -d '{...}'`
  rather than editing the file and hoping for a re-provision.
- **Grafana's own "Add new data source" search returns nothing**,
  since this instance has no internet access to fetch the plugin
  catalog. Add/update data sources via the REST API instead of the
  UI search.

## Still open / not yet done

- Not documented as git history yet - other lab repos use a numbered
  subfolder convention; this one hasn't been committed.
- frr1/frr2 not wired in (see step 5) - would need either merging
  this project's nodes into the main hybrid lab project, or bridging
  the two GNS3 projects' Cloud nodes.
- No security hardening noted/scoped: rsyslog accepts UDP/TCP 514
  with no auth, Grafana still on default-changed-once credentials.
  Worth an explicit "out of scope" callout in any writeup, same as
  the SG105E STP/DAI limitations.
- No topology diagram yet.

## Later: bringing the AD lab in

The AD lab's KVM NAT network (192.168.122.0/24) doesn't currently
route to the GNS3 lab network. When picking this back up, that's a
separate phase: either add a routed leg between the two networks
(extra NIC on the DC, or a router node bridging both subnets), or
just get Windows Event Forwarding pointed at rsyslog-node once
reachability exists. Don't block phase 1 on this.
