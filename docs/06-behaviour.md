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

`BSD_STEERING_POLICY_FLAG_STA_NUM_BAL` (bit 7, confirmed by `bsd -H`) sits
immediately after `LOAD_BAL` and balances by **client count** rather than
airtime utilisation. There is no GUI control for it, but `bsd -i` reports it —
`LOAD BALANCE` and `STA NUM BALANCE` print as two independent lines, so they
are complementary flags rather than two settings of one field.

On a network with a handful of clients, count-balancing is arguably the better
fit: airtime utilisation on a nearly-idle network is a noisy signal, whereas
"one client each" is unambiguous. It is reachable by nvram — but see
`08-open-questions.md`: the value is vendor-confirmed, but how the daemon
arbitrates when both balance modes are enabled has not been tested.

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

## Bounce detection — and what it actually gates

    bsd_bounce_detect = "<window sec> <count> <dwell sec>"
    bsd_bounce_detect = "60 2 180"          # ASUS stock default

Two steers per 60-second window, then that client is left alone for the dwell.
This is the brake that stops ping-ponging: if you widen the trigger conditions
and clients start oscillating, this is what you reach for.

**The dwell also gates re-requests to a station that simply refused**, which is
less obvious and matters more in practice. `bsd` has no separate give-up path
for a station that rejects — it re-sends at the dwell interval, indefinitely.

### Measured

One station rejecting every request, over a single window:

    BTM requests sent        76
    responses rejecting      62 of 67   (status=1 x40, status=6 x22)
    accepted                  5
    worst station            26 attempts / 26 rejects  (100%)
    inter-request gap        188-225 s, median 191     <- 180 s dwell + poll

Raising the dwell to 1800 s and re-measuring over a clean six-hour window, with
that station still associated to the same radio throughout:

    act frames sent    ~47/hour  ->  0.33/hour
    STA rejects        60        ->  0

So the dwell is the retry throttle for a refusing station, not only an
anti-oscillation guard. Stock `180` means a station that will never move is
asked roughly every three minutes, forever.

### Two failure modes that look identical in syslog

    bsd: Sending act Frame to <MAC> with transition target eth7
    bsd: BSS Transit Response: STA reject
    bsd: Skip STA:<MAC> reject BSSID

That sequence covers both a station that **refuses**, and one that **accepts,
moves, then returns on its own** — the second produces the same repeating log
with a shorter and far more erratic gap. Tell them apart by checking whether the
station actually changed radio:

    wlceventd: eth7: Auth <MAC> ... ReAssoc <MAC>
    wlceventd: eth8: Disassoc <MAC>

Present means it moved and came back: a genuine ping-pong, and bounce detect is
exactly the right tool. Absent means it never moved, and you are watching futile
retries. Measuring the gap distribution separates them quickly — a rejecting
station clusters tightly on the dwell, a bouncing one scatters.

### If the dwell is not enough

`bsd` honours a static maclist of stations that are not steerable:

    sta[...] not steerable match w/ static maclist. Skipped.

On Asuswrt this is fed by `sta_binding_list` — per-client band binding, exposed
on the ACL page. That is the surgical fix for one or two stations that will
never move, and it leaves steering intact for everything else.

Note also that `bsd_check_steer_fail` exists in the binary and emits

    STA <MAC> Steering failed %d times on ifidx [%d]

which never reaches syslog because `bsd_msglevel` is unset by default. Raise it
if you want to see whether that internal counter escalates or simply resets.

## Reading why a steer happened

`bsd -l` prints a steering history with a reason code per attempt, expressed in
the same flag bits as the policies:

    Seq TimeStamp STA_MAC           Fm_ch  To_ch  Reason     Description
      1   1294922 aa:bb:cc:11:22:33 0xe06a 0xe23a 0x00000042 RSSI
      7   1294994 aa:bb:cc:44:55:66 0x1003 0xe23a 0x00000040 load balance
      8   1294997 aa:bb:cc:44:55:66 0x1003 0xe23a 0x00010000 steer succ

    0x00000002  RSSI          0x00000040  LOAD_BAL
    0x00000042  both          0x00010000  succeeded    0x00020000  failed

This is considerably more informative than the syslog `bsd:` lines, which show
only the 802.11v request and the station's response. Here you see which policy
condition fired, and whether the station complied.

Pair it with `bsd -s`, which lists each station's `DUALBAND` and `VHT`
capabilities — so you can tell whether a device is being ignored by policy or is
simply incapable of moving. See `09-diagnostics.md`.
