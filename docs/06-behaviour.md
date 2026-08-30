# What steering actually does

## The three-stage pipeline

    1. TRIGGER   should any steering happen at all?
    2. SELECT    which client gets moved?
    3. TARGET    which radio does it go to?

Each stage is a different policy variable — `bsd_steering_policy`,
`bsd_sta_select_policy`, and `bsd_if_select_policy` with
`bsd_if_qualify_policy`. Keeping the stages distinct is the key to reasoning
about the configuration.

## Steering is a request, not an order

When `bsd` decides to move a client it sends an **802.11v BSS Transition
Management Request** — the log line looks like:

    bsd: Sending act Frame to <mac> with transition target eth7 ...
    bsd: BSS Transit Response: STA accept

The client decides. On the reference unit, 3 of 10 requests got `no response`.
The firmware can escalate to deauthenticating a client so it re-associates and
hopefully picks the intended band, but that costs a visible disconnect.

**No amount of tuning makes steering reliable**, because the final decision
belongs to a device you do not control. Tuning changes how often the router
asks, and what it asks for.

## What Load Balance changes — and what it does not

This is the most misunderstood setting, and the answer is precise:

**Load Balance replaces stage 1 only.** Stages 2 and 3 run identically either
way. Evidence is in `05-gui-encoding.md`: the CSS class that Load Balance
toggles appears only in the Steering Trigger section of the page.

| | Load Balance OFF | Load Balance ON |
|---|---|---|
| trigger | a client crossing a threshold you set | the daemon's own view of band utilisation |
| idle, balanced network | nothing happens | nothing happens |
| idle, **lopsided** network | **nothing happens** | steers to even it out |
| STA selection (RSSI, PHY, VHT) | active | **active** |
| target order and qualification | active | **active** |
| predictability | deterministic, yours | proprietary heuristic |

In one line: **OFF reacts to a bad client; ON reacts to a bad distribution.**

### The blind spot this creates

With Load Balance off — which is the stock default on this model — steering
fires only when a client crosses a threshold. If every client is comfortably
above the RSSI floor and no PHY-rate rule applies, **nothing ever happens, no
matter how lopsided the distribution is**.

On the reference unit this produced a stable 24-hour state where both clients
sat on one 5 GHz radio while the other, measurably cleaner one carried nothing
at all. No threshold describes "the other radio is empty", so no threshold
tuning could have fixed it. Enabling Load Balance redistributed them within
minutes.

If your clients cluster on one band and never move, check bit 6 before you
touch anything else.

### A third mode nobody exposes

`BSD_STEERING_POLICY_FLAG_STA_NUM_BAL` (bit 7) sits immediately after
`LOAD_BAL` in the enum and balances by **client count** rather than airtime
utilisation. There is no GUI control for it.

On a network with a handful of clients, count-balancing is arguably the better
fit: airtime utilisation on a nearly-idle network is a noisy signal, whereas
"one client each" is unambiguous. It is reachable by nvram — but see
`08-open-questions.md`, because it has not been exercised on hardware.

## Target order is the highest-leverage setting

`bsd_if_select_policy` decides where clients end up, and stock defaults are
chosen without knowledge of your RF environment. On the reference unit the
2.4 GHz radio's first target was the *noisier* of the two 5 GHz radios — 8 dB
higher noise floor and roughly 200× the glitch count, measured over 24 hours.

Before tuning thresholds, look at which radio is actually better:

    wl -i eth6 chanim_stats     # noise, glitch, idle per radio
    wl -i eth7 chanim_stats
    wl -i eth8 chanim_stats

then make the better one the first target. That single change moves more than
any threshold adjustment.

## Bounce detection

    bsd_bounce_detect = "60 2 180"

Two steers per 60-second window, then that client is left alone for 180
seconds. This is what prevents ping-ponging. If you widen the trigger
conditions and clients start oscillating, this is the brake.
