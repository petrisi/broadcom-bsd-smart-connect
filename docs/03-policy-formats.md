# Policy string formats

Four policy types, four different layouts. Fields are space-separated; the last
one is always a hex flag word.

Field names come from two sources: the GUI's JavaScript, which reads and writes
specific indices, and debug format strings compiled into `bsd` itself that name
every field in order.

---

## `bsd_steering_policy` — 7 fields

*When should steering be considered at all?*

    <bandwidth_util%> <?> <?> <RSSI> <PHY_low> <PHY_high> <flags>
           0           1   2     3        4         5        6

| # | field | GUI control |
|---|---|---|
| 0 | bandwidth utilisation %, 0–100 | yes |
| 1 | unknown, always `5` on stock | none |
| 2 | unknown, always `3` on stock | none |
| 3 | RSSI threshold, dBm | yes |
| 4 | PHY rate "less than", Mbps | yes |
| 5 | PHY rate "greater than", Mbps | yes |
| 6 | flags, hex | yes |

Fields 1 and 2 are preserved by read-modify-write when the GUI saves, so they
survive edits even though nothing exposes them. A related debug string reads
`bsd_trigger_policy min=%d max=%d rssi=%d flags=0x%x`, which suggests fields 1
and 2 are a min/max pair, but that is inference rather than confirmation.

Example: `0 5 3 -62 0 0 0x62`

---

## `bsd_sta_select_policy` — 11 fields

*Once steering is triggered, which client gets moved?*

A debug format string in the binary names the whole struct:

    idle_rate rssi phyrate_low phyrate_high wprio wrssi wphy_rate
    wtx_failures wtx_rate wrx_rate flags

    <idle_rate> <RSSI> <PHY_low> <PHY_high> <wprio> <wrssi> <wphy_rate>
         0         1       2          3         4       5        6
    <wtx_failures> <wtx_rate> <wrx_rate> <flags>
          7             8          9        10

The GUI only touches 1, 2, 3 and 10.

Fields 4–9 are a **weight vector**. `bsd` scores candidate stations against
each other, and these weight the contribution of priority, RSSI, PHY rate, TX
failures, TX rate and RX rate. On stock firmware they are `0 1 1 0 0 0` — equal
weight on RSSI and PHY rate, everything else ignored.

Field 0, `idle_rate`, is `30` on every radio on stock firmware.

Example: `30 -62 0 0 0 1 1 0 0 0 0x162`

---

## `bsd_if_select_policy` — 2 fields

*Where does a steered client go?*

    <first target ifname> <second target ifname>

Interface names, not indices — `eth6 eth7` and so on. The second is the
fallback if the first does not qualify. In 5 GHz-only mode this may hold a
single entry.

**This is the highest-leverage setting in the whole system**, and the least
obvious. It determines which radio receives clients, and stock defaults are not
necessarily right for your RF environment. See `06-behaviour.md`.

Example: `eth7 eth8`

---

## `bsd_if_qualify_policy` — 3 fields

*Is a candidate target radio acceptable right now?*

Confirmed by the debug string `bsd_if_qualify_policy min_bw[%d] flags[0x%x]
rssi[%d]`:

    <min bandwidth %> <flags> <RSSI>
            0             1      2

**Field 2 has no GUI control at all.** It is preserved on save but never
exposed — an RSSI qualifier that stock firmware sets to `-100`, i.e. effectively
disabled. It is reachable by nvram if you want it.

Note this policy's flag enum differs from the others: see `04-flag-bits.md`.

Example: `0 0x4 -100`

---

## `bsd_bounce_detect` — 3 fields

    <window seconds> <count> <dwell seconds>

Stock: `60 2 180`.
