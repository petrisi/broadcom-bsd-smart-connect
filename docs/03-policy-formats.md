# Policy string formats

Four policy types, four different layouts. Fields are space-separated; the last
one is always a hex flag word.

Field names come from `bsd -H`, which prints the vendor's own layout, and are
confirmed against `bsd -i`, which shows the parsed values live. See
`09-diagnostics.md`.

---

## `bsd_steering_policy` — 7 fields

*When should steering be considered at all?*

`bsd -H` gives the layout:

    <bw util percentage> <sample period> <consecutive sample count>
    <rssi threshold> <phy rate threshold> <extension flag>

The "phy rate threshold" is two fields in practice — high and low — matching
the separate `PHYRATE_HIGH` and `PHYRATE_LOW` flags. `bsd -i` prints the parsed
struct and resolves the ambiguity:

    max=0 period=5 cnt=3 rssi=-62 phyrate_high=0 phyrate_low=0 flags=0x62 state=3

So the nvram layout is:

| # | field | meaning |
|---|---|---|
| 0 | bandwidth utilisation % | reported as `max` |
| 1 | **sample period** | hysteresis window |
| 2 | **consecutive sample count** | breaches needed before acting |
| 3 | RSSI threshold, dBm | |
| 4 | PHY rate threshold (high) | |
| 5 | PHY rate threshold (low) | |
| 6 | flags, hex | |

Fields 1 and 2 have no GUI control and are preserved by read-modify-write when
the GUI saves. They are a **hysteresis**: N consecutive samples must breach the
condition within the period before the daemon acts, which is what stops a
single bad sample from triggering a steer.

Example: `0 5 3 -62 0 0 0x62` — five-sample period, three consecutive
breaches required.

---

## `bsd_sta_select_policy` — 11 fields

*Once steering is triggered, which client gets moved?*

From `bsd -H`:

    <idle_rate> <rssi> <phy rate> <wprio> <wrssi> <wphy_rate>
    <wtx_failures> <wtx_rate> <wrx_rate> <extension_flag>

and from `bsd -i`, with "phy rate" again split in two:

    idle_rate=30 rssi=-62 phyrate_high=0 phyrate_low=0 wprio=0 wrssi=1
    wphy_rate=1 wtx_failures=0 wtx_rate=0 wrx_rate=0 flags=0x162

| # | field |
|---|---|
| 0 | `idle_rate` |
| 1 | RSSI threshold |
| 2 | PHY rate high |
| 3 | PHY rate low |
| 4 | `wprio` |
| 5 | `wrssi` |
| 6 | `wphy_rate` |
| 7 | `wtx_failures` |
| 8 | `wtx_rate` |
| 9 | `wrx_rate` |
| 10 | flags |

Fields 4–9 are a **weight vector**. The daemon scores candidate stations
against each other, and these weight the contribution of priority, RSSI, PHY
rate, TX failures, TX rate and RX rate. Stock firmware uses `0 1 1 0 0 0` —
equal weight on RSSI and PHY rate, everything else ignored.

The GUI only exposes fields 1, 2, 3 and 10.

---

## `bsd_if_select_policy` — 2 fields

*Where does a steered client go?*

    <first target ifname> <second target ifname>

Interface names, not indices. The second is the fallback if the first does not
qualify. In 5 GHz-only mode this may hold a single entry.

**This is the highest-leverage setting in the whole system**, and the least
obvious — it decides which radio receives clients, and the stock default is
chosen without any knowledge of your RF environment. See `06-behaviour.md`.

---

## `bsd_if_qualify_policy` — 3 fields, of which the vendor documents 2

*Is a candidate target radio acceptable right now?*

`bsd -H` documents only:

    <bw util percentage> <extension_flag>

But the stored value has **three** fields, and `bsd -i` prints all three:

    min_bw=0 rssi=-100 flags=0x0

So the layout is:

| # | field | documented |
|---|---|---|
| 0 | minimum bandwidth % | yes |
| 1 | flags | yes |
| 2 | RSSI qualifier | **no** |

Field 2 has no GUI control and no mention in the vendor's own help, yet the
daemon parses and reports it. Stock value is `-100`, i.e. effectively disabled.
It is reachable by nvram.

Note this policy uses a **different flag enum** — see `04-flag-bits.md`.

---

## `bsd_bounce_detect` — 3 fields

    <window seconds> <count> <dwell seconds>

Stock: `60 2 180` — two steers per 60-second window, then that station is left
alone for 180 seconds. The dwell also throttles re-requests to a station that
rejected, which is the practical reason to raise it — see `06-behaviour.md`.

---

## Global tunables

`bsd -i` exposes a set of daemon-wide values, most with no GUI control:

    status_poll: 5        idle_rate: 10         prefer_5g: 1
    steer_timeout: 15     sta_timeout: 120      maclist_timeout: 3
    probe_timeout: 3600   probe_gap: 30         poll_interval: 1
    slowest_at_ratio: 40  phyrate_delta: 200    scheme: 2[3]

Corresponding nvram names appear in the binary (`bsd_prefer_5g`,
`bsd_steer_timeout`, `bsd_phyrate_delta` and so on) and are unset on stock
firmware, meaning the daemon is using compiled-in defaults. Setting them is
untested.
