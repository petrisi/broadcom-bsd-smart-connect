# Open questions

Most of what was originally listed here has been answered — see the bottom of
this page for the corrections, including one where this repository was simply
wrong.

---

## Still open

### 1. How `STA_NUM_BAL` and `LOAD_BAL` interact

`BSD_STEERING_POLICY_FLAG_STA_NUM_BAL = 0x80` is confirmed by the vendor's own
`bsd -H` output, and `bsd -i` prints `LOAD BALANCE` and `STA NUM BALANCE` as
two independent lines — so they are complementary flags rather than alternative
settings of one field.

What is **not** established is the behaviour:

- with only bit 7 set, does the daemon balance purely by station count?
- with both bits set, how does it arbitrate between airtime and count?
- does bit 7 occupy the same position in the decision pipeline as bit 6?

**To settle it:** set bit 7 with bit 6 clear on a router with several clients
and watch redistribution over 48 hours; then set both and compare. Per-radio
client counts are the measurement. The `bsd -l` steering log will name the
reason for each move, so the reason code should distinguish the two directly.

### 2. `bsd_scheme`, `policy` and `algo`

`bsd -i` exposes them but does not explain the value space:

    scheme: 2[3]
    policy=3[6]   algo=0[2]     (per interface)

The bracketed second number looks like a maximum or a count, which would make
these selectors over a small enumerated set. Related strings in the binary —
`bsd_steer_scheme_balance`, `bsd_steer_scheme_5g`, `bsd_steer_scheme_policy`,
`bsd_2g5g_policy`, `bsd_5g2g_policy`, `bsd_5glo_2g_5ghi_policy` — suggest
schemes and policies are named strategy presets.

**To settle it:** disassemble the comparisons against these values, or step
`bsd_scheme` through 0..3 and diff the `bsd -i` output at each.

### 3. Why the qualify enum skips bits 3 and 4

`BSD_QUALIFY_POLICY_FLAG_*` runs `0x1, 0x2, 0x4, 0x20, 0x40, 0x80, 0x100`. The
gap is real — it is in the vendor's own help output, so it is deliberate rather
than an extraction artefact. Whether those bits were removed during development
or are reserved is not answerable from the binary alone.

Low value. Recorded for completeness.

### 4. Coverage

Everything here comes from **one firmware build on one model**:

    ASUS GT-AC5300, Broadcom BCM4908, tri-band
    firmware 3.0.0.4.386_51582 (the final release)

`bsd -H` makes verification on other hardware trivial — it prints the flag
table directly. Confirmations or contradictions from other models and firmware
generations remain the most useful contribution anyone could make.

---

## Answered, and one correction

### The VHT "contradiction" did not exist — this repository was wrong

Earlier revisions of this document asserted that the binary and the GUI
disagreed about bits 2 and 3, and speculated that ASUS's labels were inverted.

**They are not. The GUI is correct.**

`bsd -i` prints the daemon's own interpretation:

    flags=0x68   (bit 3, NON_VHT, set)   ->   NON VHT: Not-Allowed
    flags=0x64   (bit 2, VHT, set)       ->   VHT: Not-Allowed
    neither set                          ->   both Allowed

The flags are **exclusions, not selectors**. Setting `NON_VHT` excludes
non-VHT stations, which leaves only 802.11ac — exactly what the GUI labels
"AC only". Setting `VHT` excludes AC stations, which the GUI labels
"not-allowed".

The error was reading flag names as though they selected a class of station
when they suppress one. Worth stating plainly because it is a good example of
how a plausible reading of a name can survive several rounds of checking:
the name, the GUI source and the observed values were all consistent with the
wrong interpretation, and only the daemon's own decoded output settled it.

### `bsd_steering_policy` fields 1 and 2

`<sample period>` and `<consecutive sample count>`, from `bsd -H`, confirmed in
`bsd -i` as `period=5 cnt=3`. A hysteresis window — N consecutive breaches
within a period before the daemon acts.

### Bit 5 (`PHYRATE_HIGH`) being set everywhere

Not an enable. It selects the **comparison direction** for the `phyrate_high`
field, exactly as bit 1 does for RSSI. `bsd -i` renders it as
`PHYRATE (HIGH): Greater than or Equal to`. With the threshold left at `0`,
the condition is trivially true — an operator with a null operand rather than
sloppy configuration.

The same applies to bit 0, which selects `Rule Logic: OR` versus AND.
