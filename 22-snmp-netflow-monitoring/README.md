# 22 - SNMP and NetFlow Monitoring (LibreNMS + nfdump)

## Overview

Every lab before this one sent syslog or AAA accounting somewhere, but nothing in the network was being polled or watched for state changes. Most NOCs still run on SNMP polling, SNMP traps and flow data, so this lab adds that layer on top of the lab 20 network.

Both physical 881s are monitored. 881-R1 (the HQ hub) sits on the same segment as the collector, and 881-R2 (the branch spoke) is polled across the WAN, through DMVPN over the lab 20 MPLS carrier. The monitoring covers:

- SNMPv3 polling (authPriv, SHA + AES-128) into LibreNMS for interface, CPU, memory and uptime graphs
- SNMPv3 traps for link and config changes, decoded by LibreNMS's snmptrapd container
- Flexible NetFlow v9 exported to an nfdump collector for top talker analysis

On top of that, LibreNMS alert rules were tested against a cable pull on the hub and a full WAN outage to the branch, with each alert firing and then clearing on its own. NetFlow is configured on 881-R1 only.

## Topology

| Role | Device | Address |
|---|---|---|
| HQ router (DMVPN hub) | 881-R1 (C881G+7-A-K9, IOS 15.7(3)M9) | Vlan1 10.10.30.1 |
| Branch router (DMVPN spoke) | 881-R2 (C881G+7-A-K9) | 10.20.50.1 |
| Collector | Acer (Ubuntu 24.04), enp1s0 via the 2950 | 10.10.30.250 |
| Mgmt switch | Cisco 2950 | Vlan1 10.10.30.10 |

881-R1 and the collector sit on the same 10.10.30.0/24 segment through the physical 2950, so polling, traps and flow export for the hub stay on one flat management network. 881-R2 is only reachable from there across the WAN: Acer to 881-R1, then through the DMVPN tunnel over the MPLS carrier (the c2691s in the lab 20 GNS3 project) to the branch. Monitoring the branch this way means a WAN failure shows up in LibreNMS as the branch going down, which is how a real NOC sees a remote site.

## Collector stack

LibreNMS runs as a plain Docker Compose stack on the Acer host, built from the official `librenms/docker` example (LibreNMS, MariaDB, Redis, dispatcher, snmptrapd). I ran it on the host rather than as GNS3 Docker nodes, which follows the lab 13 approach and avoids the GNS3 console proxy and lost-IP problems from earlier labs.

I removed the example's syslog-ng sidecar before starting the stack because it publishes UDP 514, which the Acer's rsyslog already uses for lab 20's device logs:

```
sed -i '/^  syslogng:/,/^  snmptrapd:/{/^  snmptrapd:/!d}' compose.yml
docker compose config --services
docker compose up -d
```

NetFlow is collected by `nfcapd` from Ubuntu's `nfdump` package, which runs as a system service writing 5 minute capture files to `/var/cache/nfdump`.

## Router configuration (881-R1)

### SNMPv3

```
ip access-list standard SNMP-MGMT
 permit host 10.10.30.250
snmp-server view ALLVIEW iso included
snmp-server group NOC-RO v3 priv read ALLVIEW access SNMP-MGMT
snmp-server user librenms NOC-RO v3 auth sha <AUTH_PASS> priv aes 128 <PRIV_PASS>
snmp-server ifindex persist
snmp-server location HomeLab
snmp-server contact Eddy
snmp-server enable traps snmp linkdown linkup coldstart
snmp-server enable traps config
snmp-server enable traps hsrp
snmp-server host 10.10.30.250 version 3 priv librenms
snmp-server trap-source Vlan1
```

The ACL limits SNMP access to the collector only, and `ifindex persist` keeps interface indexes stable across reboots so LibreNMS graphs don't get mixed up.

### Flexible NetFlow

```
flow exporter EXP-ACER
 destination 10.10.30.250
 source Vlan1
 transport udp 2055
flow monitor MON-FNF
 exporter EXP-ACER
 record netflow ipv4 original-input
 cache timeout active 60
interface FastEthernet4
 ip flow monitor MON-FNF input
interface Vlan1
 ip flow monitor MON-FNF input
interface Tunnel0
 ip flow monitor MON-FNF input
```

NetFlow v9 is the default export protocol, so IOS doesn't show `export-protocol netflow-v9` in the running config.

## Trap receiver configuration

SNMPv3 traps are sent by the router as the authoritative engine, so the receiver needs the router's engine ID as well as the user credentials. I got the engine ID from `show snmp engineID` on R1 and added the trap settings to `librenms.env`:

```
SNMP_USER=librenms
SNMP_AUTH=<AUTH_PASS>
SNMP_PRIV=<PRIV_PASS>
SNMP_AUTH_PROTO=SHA
SNMP_PRIV_PROTO=AES
SNMP_SECURITY_LEVEL=priv
SNMP_ENGINEID=<R1_ENGINE_ID>
```

After `docker compose up -d`, I confirmed the generated config inside the container:

```
docker compose exec snmptrapd grep createUser /etc/snmp/snmptrapd.conf
```

## Verification

### Polling

I tested SNMPv3 from the collector before touching the LibreNMS UI, so a failure would point clearly at either the network or the app:

```
snmpget -v3 -l authPriv -u librenms -a SHA -A '<AUTH_PASS>' -x AES -X '<PRIV_PASS>' 10.10.30.1 1.3.6.1.2.1.1.1.0
```

This returned the full IOS version string. I used the numeric OID because Ubuntu's SNMP tools don't load MIB names by default.

After adding the device, LibreNMS discovered R1 as a C881G+7-A-K9 running IOS 15.7(3)M9, with 12 ports and 12 health sensors.

![LibreNMS device list](screenshots/01-librenms-device.png)

### Traps

Bouncing Loopback0 sent linkDown and linkUp traps to the collector. In tcpdump they show `F=ap` (authenticated and encrypted) and an unreadable payload, since tcpdump doesn't have the keys:

![Encrypted traps in tcpdump](screenshots/02-trap-tcpdump-encrypted.png)

LibreNMS decoded the same traps and logged them in R1's Eventlog:

![Eventlog showing Loopback0 down and up](screenshots/03-eventlog-loopback.png)

### NetFlow

The flow cache on R1 showed flows being created and aged out for export:

```
show flow monitor MON-FNF cache
```

![Flow cache on R1](screenshots/04-flow-cache.png)

Top talkers from the collector:

```
sudo nfdump -R /var/cache/nfdump -s ip/bytes -n 10
```

![nfdump top talkers](screenshots/05-nfdump-top-talkers.png)

Over about 15 minutes nfdump processed 114 flows. What showed up:

- **10.10.30.250 and 10.10.30.1** made up about 75% of bytes. This was SNMP polling from LibreNMS plus my SSH session, so on a quiet LAN the monitoring system was the biggest talker.
- **0.0.0.0 to 255.255.255.255 on UDP 67/68** arrived on FE4, about 15% of bytes. With the lab 20 GNS3 project shut down, the far end of the DMVPN underlay cable was sending DHCP requests. That turned out to be one of the Acer's USB-to-Ethernet adapters, which has no IPv4 address configured.
- **10.10.20.10 to 239.255.255.250 and 224.0.0.251** was SSDP and mDNS from the Acer's second address on the lab segment. Desktop service discovery was leaking onto the lab LAN from the monitoring host itself.
- **10.10.30.10**, the 2950's SVI, had a handful of small flows.

### Alerting

I added four rules from LibreNMS's built-in collection: Devices up/down, Port status up/down, Device rebooted, and Processor usage over 85%.

The port rule is meant to fire when a port is operationally down while still admin up, so that a deliberate `shutdown` is ignored. To test with a real failure I pulled the FE4 cable on R1. (In phase 2 an admin shutdown of Tunnel0 fired this rule anyway. See finding 7.)

The alert fired at 10:22:11 and recovered at 10:30:39 after the cable went back in:

![Alert log showing fire and recovery](screenshots/06-alert-log.png)

The alert was raised on Tunnel0 (DMVPN hub). FE4 is the tunnel's underlay, so when the cable came out, the tunnel lost its source interface and its route to the peer, and its line protocol dropped as well. One physical fault showed up as an alert on a logical interface that depends on it, which is the kind of symptom versus root cause tracing a NOC has to do.

## Phase 2: monitoring the branch over the WAN

### Reaching the branch

The Acer needed a route to the branch LAN via 881-R1. I added it to the `enp1s0` NetworkManager profile so it survives reboots:

```
sudo nmcli connection modify "Wired connection 1" +ipv4.routes "10.20.50.0/24 10.10.30.1"
sudo nmcli connection up "Wired connection 1"
```

881-R2 got the same SNMPv3 config as 881-R1, with its trap source set to the interface holding 10.20.50.1. I checked it with `snmpget` against 10.20.50.1 before adding it to LibreNMS.

### A second trap user

881-R2 has its own engine ID, and the LibreNMS container's environment variables only create one trap user. The container generates `/etc/snmp/snmptrapd.conf` at startup by editing it in place, so mounting a replacement over that file would break the startup script. Instead I mounted a second config file, which snmptrapd also reads, holding 881-R2's user:

```
createUser -e 0x<R2_ENGINE_ID> librenms SHA <AUTH_PASS> AES <PRIV_PASS>
```

```yaml
  snmptrapd:
    volumes:
      - "./librenms:/data"
      - "./snmptrapd/extra-users.conf:/usr/share/snmp/snmptrapd.conf:ro"
```

881-R1 keeps using the user from `librenms.env`. A `conf t` / `end` on each router produced a config change trap from both in the Eventlog, which confirmed both users work.

### Branch outage test

To simulate a WAN failure I shut Tunnel0 on 881-R1 and watched how 881-R2 showed up in LibreNMS:

| Time | Event |
|---|---|
| 11:57:09 | linkDown trap from 881-R1 for Tunnel0, 7 seconds after the shutdown |
| 11:57:09 | Port status alert fires on 881-R1 Tunnel0 |
| 11:57:26 | 10.20.50.1 marked down by ICMP and SNMP checks, Devices up/down alert fires |
| 12:00:15 | Tunnel0 restored, linkUp trap, port alert clears |
| 12:01:49 | 10.20.50.1 marked up again |
| 12:02:20 | Devices up/down alert for 10.20.50.1 clears |

![Eventlog for the branch outage](screenshots/07-eventlog-branch-outage.png)

![Alert log for the branch outage](screenshots/08-alert-log-branch-outage.png)

The trap was the fastest signal. Marking the branch down depends on polling, and catching it in 17 seconds here was partly timing, since the worst case is a full 5 minute polling cycle. Recovery also lagged: the branch only came back about 1.5 minutes after the tunnel interface was up, because IKEv2 had to renegotiate and the spoke had to register with NHRP again before anything could reach it.

## Findings and troubleshooting

1. **The old management SVI was gone.** `snmp-server trap-source vlan 50` was rejected even though `?` listed Vlan as an option. IOS rejects the whole interface name when the interface doesn't exist, which is why the caret pointed at `vlan` rather than the number. After the lab 20 rebuild, R1's management address had moved to Vlan1 (10.10.30.1), so the collector target changed to 10.10.30.250 on the same segment.

2. **SNMPv3 users never appear in the running config.** After entering `snmp-server user`, the line isn't in `show run`. `show snmp user` and `show snmp group` are the way to verify it.

3. **Traps arrived but were silently dropped.** tcpdump showed traps reaching UDP 162, but nothing appeared in LibreNMS and the snmptrapd log showed no errors. The trap container was still running with its default user and engine ID. Once it had R1's engine ID and credentials, the same traps were decoded and logged.

4. **A second collector was already listening.** Installing `nfdump` on Ubuntu also starts an nfcapd service on UDP 2055 writing to `/var/cache/nfdump`. My manually started nfcapd pointed at `~/netflow` never received anything. `ss -ulpn` showed the system service owned the port, so I used that collector instead.

5. **Monitoring only the WAN interface showed almost nothing.** NetFlow was first applied only to FE4, the DMVPN underlay. With the carrier project in GNS3 shut down, FE4 carried barely any traffic, and when it is up it only carries ESP between the two tunnel endpoints. Adding the monitor to Vlan1 and Tunnel0 gave useful data: Vlan1 shows LAN hosts, and Tunnel0 shows the decrypted traffic inside the VPN.

6. **SNMPv3 traps need one user entry per sending router.** Each router sends traps under its own engine ID, so a single `createUser` line only covers one device. 881-R2's traps were dropped until it had its own entry in the extra config file.

7. **An admin shutdown still fired the port alert.** Shutting Tunnel0 on 881-R1 raised a Port status alert, even though the rule is supposed to skip admin-down ports. The Eventlog recorded the trap as `linkDown up/down Tunnel0`, meaning admin up and oper down, so LibreNMS treated it as an unplanned failure. In practice you'd put the device in maintenance mode in LibreNMS before planned work so this doesn't page anyone.

## Known gaps and next steps

- **NetFlow only runs on 881-R1.** Adding it to 881-R2 would show branch traffic, with the exports crossing the tunnel to the collector.
- **The 2950 hasn't been added.** Its image has no crypto support, so SNMPv3 authNoPriv is the best it can do.
- **An HSRP state change alert** would catch failovers where nothing actually goes down. The HSRP traps are enabled on both 881s, but no HSRP failover was tested in this lab.
- **There's no alert transport yet.** Alerts only show in the web UI. Sending them to a ticketing system by webhook is planned for the next lab.
- **A Wireshark capture comparing SNMPv2c (community string in plaintext) with SNMPv3** would make the security point clearer.

## Files

Credentials in `.env` and `librenms.env` are kept out of the repo. The values above are placeholders.
