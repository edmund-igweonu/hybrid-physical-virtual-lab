# Baseline, 2026-09-12

Host: Acer, wlp0s20f3, associated to BELL116 (0e:ac:8a:f0:79:cb), 5 GHz
Wi-Fi power save: disabled
Gateway: 192.168.2.1

Gateway RTT: ~2 ms avg
Cloudflare 1.1.1.1: ~33 ms avg
Google 8.8.8.8: ~38 ms avg

Path: 12 hops to 1.1.1.1, 13 to 8.8.8.8. Latency steps once between
hop 2 and hop 3 inside Bell's network, then plateaus. Hop 2
(142.124.47.77, BELL-ICNEN21) drops direct ICMP echo but forwards
normally.

Pre-run corrections: host was on a TP-Link range extender (bridged,
invisible to the routing table); probe parser was reading max RTT
instead of avg.

## Time handling
Probe writes UTC. Grafana renders browser-local (NDT, UTC-2:30).
Subtract 2h30m from a log timestamp to find it on the dashboard.
Example: gateway event at 19:27:38Z appears at 16:57 on the graph.

## Association comparison, same host position, same probe
BELL116 5GHz  (0e:ac:8a:f0:79:cb)  -80 dBm   avg 2.46ms   mdev 0.66  (09-12)
BELL116 5GHz  (same BSSID)         -82 dBm   avg 5.72ms   mdev 2.33  (09-17)
BELL116 2.4GHz (0c:ac:8a:f0:79:c9) -71 dBm   avg 29.6ms   mdev 46.8
BELLX mesh 2.4GHz (08:b4:b1:88:b2:ae) -56 dBm avg 202ms   mdev 210
TP-Link extender: not tested, rejected on topology (adds a
wireless backhaul hop, same objection as the mesh).

From this position the strongest signal gave the worst latency and
the weakest gave the best. Every stronger option sat on the
contended 2.4GHz band or behind a backhaul. Signal strength and
latency stability are not the same property.

Root cause of repeated unintended roaming: duplicate NetworkManager
profiles. The active profile had priority 0 and no BSSID pin while
the configured settings sat on an inactive duplicate of the same
name. Resolved by deleting all but the active profile.
