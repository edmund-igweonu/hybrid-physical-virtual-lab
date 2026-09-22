# Observed events

## 2026-09-12 22:12:37Z - local wireless
All three targets degraded within 3s. Gateway 807ms / 80% loss,
cloudflare 178ms / 20%, google 145ms / 80%. Gateway worst.
Signature: simultaneous, gateway included -> local link.
Radio at the time: -84 dBm, TX MCS 0 (9 Mbit/s).

## 2026-09-12 ~20:28Z - upstream
Cloudflare 543ms avg / 753ms max, zero loss. Gateway steady at 2ms,
google steady at 38ms. Recovered within ~90s.
Traceroute after recovery showed identical 12-hop path to baseline.
Signature: single target, no path change, no loss -> transient
queuing inside provider network.

## 2026-09-13 19:27:38Z - local wireless
Gateway 377ms / 40% loss, cloudflare degraded 2s later.
Appears at 16:57 on the local-time dashboard.

## Daily counts (cumulative degraded samples)
2026-09-13: 69 total - cloudflare 32, gateway 24, google 13
2026-09-14: 78 total - cloudflare 33, gateway 28, google 17
  Delta 9 (cloudflare +1, gateway +4, google +4)
  Quiet day. Single local-wireless event ~06:00 local, all three
  targets, gateway peak ~45ms.
2026-09-15: 93 total - cloudflare 40, gateway 32, google 21
  Delta 15 (cloudflare +7, gateway +4, google +4)
  Quiet day. Gateway bumps ~03:00 and ~08:00 local, peak ~10ms.

## Notes on hypotheses that did not hold
The early reading that cloudflare degrades more often than the other
targets came almost entirely from the disturbed period on 2026-09-12.
Two quiet days since show gateway and google contributing as much or
more. Not supported.

An evening-congestion pattern was suggested by 2026-09-12 but did not
appear on any subsequent evening. Not supported.
2026-09-16: 182 total. NOT VALID DATA.
  At approximately 08:00 local the host roamed off BELL116 onto a
  neighbouring network (BELLX, 08:b4:b1:88:b2:aa, channel 149).
  Everything after that point measures the path through the mesh backhaul rather than a direct association to the router.
  Visible as a step change: gateway 2ms to 7ms, cloudflare and
  google each up about 4ms, plus heavy afternoon noise.
  Cause: no autoconnect priority set on BELL116, so the client
  roamed when signal dropped. Fixed by pinning priority and
  disabling autoconnect on other networks.
2026-09-17: 190 total. Delta 8 since the roam was corrected.
  Back on BELL116 (0e:ac:8a:f0:79:cb) since about 22:10 on 09-16.
  Rate matches the 09-14 and 09-15 quiet days, which supports the
  view that the 09-16 spike to 89 events was the neighbouring
  network rather than a change in conditions.
  Host signal on BELL116 is -82 dBm. Pinned deliberately for
  measurement consistency, at the cost of link quality.
2026-09-17: 222 total. Delta 32, NOT comparable to quiet days.
  This window includes deliberate changes: association moved to the
  BELLX mesh and back, gateway target switched to 192.168.86.1 and
  reverted, four reassociations, two probe restarts (startup markers
  at 11:47:49Z and 11:54:43Z). Samples between those two markers used
  the wrong gateway target and should be excluded.
  One genuine local-wireless event around 13:50 local: gateway peak
  265ms, cloudflare and google 60-110ms, simultaneous, gateway worst.
  Host on BELL116 5GHz at -82 dBm.

Note on reading the dashboard: logs are UTC, Grafana renders NDT
(UTC-2:30). The right edge of a 24h window can look like a data gap
if the offset is forgotten. Verify with date and date -u before
treating a gap as an outage.
2026-09-18: 260 total. Delta 38. First clean day on the settled
  configuration since 09-17.
  Higher event rate than the 09-14 and 09-15 quiet days (8 to 15),
  consistent with the gateway baseline shifting from 2.46ms to
  5.72ms on the same BSSID.
  Overnight events are paired, not isolated: 00:17 gateway 664ms
  then cloudflare 1s later, 00:46 cloudflare and google together,
  01:56 gateway and cloudflare together. Local link.
  Two samples at 02:37 and 02:48 show 20% loss with normal latency
  (5.1ms, 2.8ms). Loss without latency, likely interference.

Method note: the 5m averaging window can make paired events look
like single-target events on the graph. Always confirm event
classification against the raw log before calling it.
Correction to the 2026-09-18 entry: the elevated event count was
partly caused by repeated Wi-Fi disconnects on screen lock, not by
link conditions alone. Deleting the duplicate NetworkManager
profiles left the surviving profile storing its PSK in the user
keyring, which locks with the session. Fixed by setting
802-11-wireless-security.psk-flags to 0 so the secret is system
owned. Data between roughly 2026-09-18 13:25 and 16:15 local is a
connectivity gap from this cause.

Method note: apparent gaps in the Grafana panel are not evidence of
missing data. On 2026-09-18 a blank region between roughly 13:25 and
16:15 local turned out to be a stale render. The probe log had
continuous entries throughout, promtail reported no errors, and a
direct Loki API query for the window returned the data. Verify any
suspected gap against the log file and the Loki API before recording
it as an outage.
