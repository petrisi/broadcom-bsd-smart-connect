# `bsd`'s built-in diagnostics

The daemon ships with four undocumented command-line options. None of them
appear in the GUI, the ASUS documentation, or any community write-up found so
far — and between them they answer most of what this repository originally set
out to reverse-engineer.

    bsd -H    usage, and the complete flag reference
    bsd -i    parsed configuration, with every flag decoded into English
    bsd -s    per-station summary
    bsd -l    steering history with reason codes
    bsd -F    run in the foreground
    bsd -f    (undocumented in the help output itself)

**Look here before disassembling anything.**

## Running them safely

These start a second, short-lived `bsd` process. On the reference unit the
running daemon was unaffected, but bound them anyway rather than assuming:

    /usr/sbin/bsd -i > /tmp/bsd_i.txt 2>&1 &
    _p=$!; _n=0
    while kill -0 $_p 2>/dev/null && [ $_n -lt 8 ]; do sleep 1; _n=$((_n+1)); done
    kill -9 $_p 2>/dev/null

Confirm the real daemon is still alive afterwards with `pidof bsd`.

---

## `bsd -H` — the flag reference

Prints the field layout for each policy string followed by every flag constant
with its hex value. This is vendor documentation, and it confirms the tables in
`04-flag-bits.md` exactly.

It also reveals field names that the GUI never shows — notably that
`bsd_steering_policy` fields 1 and 2 are **sample period** and **consecutive
sample count**.

---

## `bsd -i` — parsed configuration

The most useful of the four. It prints what the daemon *actually parsed*, with
every flag decoded into a human-readable line — so you can verify your
understanding of a hex value against the daemon's own interpretation rather
than against your own arithmetic.

    === Basic info ===
    max_ifnum: 3
    mode: 2
    role: 3
    status_poll: 5
    idle_rate: 10
    prefer_5g: 1
    scheme: 2[3]
    steer_timeout: 15
    sta_timeout: 120
    probe_timeout: 3600
    probe_gap: 30
    poll_interval: 1
    slowest_at_ratio: 40
    phyrate_delta: 200

Several of those have no GUI control at all.

Per interface:

    idx=0 band=2 remote=0 enabled=1 steering_flags=0x0
    Steer Policy:
    max=0 period=5 cnt=3 rssi=-62 phyrate_high=0 phyrate_low=0 flags=0x62 state=3
    Rule Logic: OR
    RSSI: Greater than
    VHT: Allowed
    NON VHT: Allowed
    NEXT RF: NO
    PHYRATE (HIGH): Greater than or Equal to
    LOAD BALANCE: YES
    STA NUM BALANCE: NO
    PHYRATE (LOW): Less than
    N ONLY: NO

Note how the flags decode. They are not simple enables:

| flag | decoded as |
|---|---|
| bit 0 `RULE` | `Rule Logic: OR` when clear, AND when set |
| bit 1 `RSSI` | `Greater than` when set, `Less than or Equal to` when clear |
| bit 2 `VHT` | `VHT: Not-Allowed` when set |
| bit 3 `NON_VHT` | `NON VHT: Not-Allowed` when set |
| bit 5 `PHYRATE_HIGH` | comparison direction for the phyrate_high field |
| bit 6 `LOAD_BAL` | `LOAD BALANCE: YES` |
| bit 7 `STA_NUM_BAL` | `STA NUM BALANCE: NO` |

Bits 1, 2, 3 and 5 select a **comparison or a restriction**, not on/off. See
`06-behaviour.md`.

---

## `bsd -s` — station summary

    STA_MAC           Interface TimeStamp Tx_rate Rssi Bounce Picky PSTA DUALBAND VHT SteerFlag
    aa:bb:cc:11:22:33 eth6      1340642   57      -83  No     Yes   No   Yes      Yes 0
    aa:bb:cc:44:55:66 eth8      1294807   780     -53  No     No    No   No       Yes 0

`DUALBAND` and `VHT` are the station capabilities the selection policy tests
against — so this tells you directly whether a device *can* be steered before
you wonder why it is not being.

`Picky` corresponds to an internal `bsd_check_picky_sta` routine and appears to
mark stations that have previously refused or failed a transition.

---

## `bsd -l` — steering history

    Seq TimeStamp STA_MAC           Fm_ch  To_ch  Reason     Description
      1   1294922 aa:bb:cc:11:22:33 0xe06a 0xe23a 0x00000042 RSSI
      2   1294926 aa:bb:cc:11:22:33 0xe06a 0xe23a 0x00020000 steer fail
      7   1294994 aa:bb:cc:44:55:66 0x1003 0xe23a 0x00000040 load balance
      8   1294997 aa:bb:cc:44:55:66 0x1003 0xe23a 0x00010000 steer succ

`Fm_ch` and `To_ch` are chanspecs, so you can see which band a station moved
between.

**The `Reason` column is expressed in the same flag bits** as the steering
policy, which is a useful independent confirmation of the table:

    0x00000002   RSSI
    0x00000040   LOAD_BAL
    0x00000042   RSSI | LOAD_BAL
    0x00010000   steer succeeded
    0x00020000   steer failed

The two high values are outcome codes rather than policy flags.

This log is far more informative than the syslog `bsd:` lines, which only show
the 802.11v request and response. Here you see *why* the daemon decided to act.

---

## Enabling verbose logging

`bsd_msglevel` is the debug mask. The levels, from `bsd -H`:

    0x00000001 ERROR      0x00000002 WARNING    0x00000004 INFO
    0x00000008 TO         0x00000010 STEER      0x00000020 EVENT
    0x00000040 HISTO      0x00000080 CCA        0x00000100 AT
    0x00000200 RPC        0x00000400 RPCD       0x00000800 RPCEVT
    0x00001000 MULTI_RF   0x00002000 BOUNCE     0x00100000 DUMP
    0x00400000 PROBE      0x00800000 ALL

    nvram set bsd_msglevel=0x14      # STEER + INFO
    nvram commit
    service restart_wireless

Start narrow. `ALL` on a busy router produces a great deal of output, and
syslog here is small enough that it will rotate away everything else.
