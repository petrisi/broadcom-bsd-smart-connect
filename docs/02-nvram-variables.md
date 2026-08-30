# The nvram variables

## The master switch

    smart_connect_x = 0    off
                    = 1    tri-band  (all three radios steered)
                    = 2    5 GHz only (the two 5 GHz radios; 2.4 GHz excluded)

## Two parallel sets, and this is a trap

Every policy variable exists twice:

    wl{0,1,2}_bsd_steering_policy       used when smart_connect_x = 1
    wl{0,1,2}_bsd_steering_policy_x     used when smart_connect_x = 2

    bsd_bounce_detect                   mode 1
    bsd_bounce_detect_x                 mode 2

The GUI selects the correct set with a clean `if/else` in both directions, and
in mode 2 it also skips index 0 entirely, because 2.4 GHz takes no part.

**The two sets hold materially different values in stock firmware.** On the
reference unit, `wl1_bsd_steering_policy` had an RSSI threshold of −82 while
`wl1_bsd_steering_policy_x` had 0 and a PHY-rate threshold of 600 instead.
Editing the wrong one is a silent no-op, and reading the wrong one gives a
completely misleading picture of the current configuration.

Check `smart_connect_x` first, every time.

## The per-radio policy variables

    wl{0,1,2}_bsd_steering_policy      when to steer          (7 fields)
    wl{0,1,2}_bsd_sta_select_policy    which client to move   (11 fields)
    wl{0,1,2}_bsd_if_select_policy     where to send it       (2 fields)
    wl{0,1,2}_bsd_if_qualify_policy    is a target acceptable (3 fields)

Index maps to radio: `wl0` = 2.4 GHz, `wl1` = 5 GHz-1, `wl2` = 5 GHz-2. Confirm
with `nvram get wl_ifnames`, which on the reference unit gives `eth6 eth7 eth8`
in that order.

Field layouts are in `03-policy-formats.md`.

## The global variables

| variable | reference value | meaning |
|---|---|---|
| `bsd_role` | `3` | 0 off, 1 helper, 2 primary, 3 standalone |
| `bsd_ifnames` | `eth6 eth7 eth8` | radios participating in steering |
| `bsd_scheme` | `2` | steering scheme selector |
| `bsd_bounce_detect` | `60 2 180` | window sec, count, dwell sec |
| `bsd_hit_cnt_2g` / `_5g` | `2` / `1` | threshold breaches before acting |
| `bsd_aclist_timeout` | `3` | |
| `bsd_primary` / `bsd_helper` | addresses | multi-AP steering only |
| `bsd_hport` / `bsd_pport` | `9877` / `9878` | multi-AP steering ports |

`bsd_primary` and `bsd_helper` are only used for cross-AP steering (roles 1 and
2). With `bsd_role=3` they are inert, and on a stock unit they often still hold
default addresses from a network the router has never been on.

## Bounce detection

    bsd_bounce_detect = "<window sec> <count> <dwell sec>"

`60 2 180` means: if a station is steered twice within 60 seconds, leave it
alone for the next 180. This is what stops clients ping-ponging between bands.

## Applying changes

Writing nvram changes nothing on its own — `bsd` reads its configuration at
startup:

    nvram set wl0_bsd_steering_policy="..."
    nvram commit
    service restart_wireless

`restart_wireless` is exactly what the GUI's Apply button posts
(`action_script=restart_wireless`). It briefly drops associated clients.
