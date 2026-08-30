# Open questions

What is not settled. If you can close any of these, the evidence needed is
noted with each.

---

## 1. The VHT labelling contradicts the binary

The flag table says:

    bit 2 = VHT
    bit 3 = NON_VHT

The GUI's own source comments say the opposite:

    if (bin[2]==0 && bin[3]==1)  vht_s = 1;   // "ac only"
    if (bin[2]==1 && bin[3]==0)  vht_s = 2;   // "legacy"

So the GUI treats **bit 3** as "AC only", while the binary names bit 3
`NON_VHT`. The same inversion appears in the qualify enum, where a stock value
of `0x4` decodes as `NON_VHT` while the GUI displays "AC only".

Possible explanations, none confirmed:

- ASUS's labels are simply wrong
- the flag names read as exclusions ("exclude non-VHT") rather than inclusions
- the daemon's use sites do something less direct than a straight bit test

**To settle it:** disassemble around the `VHT not qualified` /
`Non-VHT not qualified` log paths and read which bit is actually tested.

Practical impact: if you set the VHT policy through the GUI, you may be getting
the opposite of the label. Anyone relying on VHT filtering should verify
empirically with a known AC and a known non-AC client.

---

## 2. `STA_NUM_BAL` is derived but untested

Bit 7 of `bsd_steering_policy` is confirmed as
`BSD_STEERING_POLICY_FLAG_STA_NUM_BAL` from the binary's value table. What is
**not** confirmed is how the daemon behaves when it is set:

- does it replace `LOAD_BAL`, or complement it?
- what happens when both bits are set — does one win, or do they combine?
- does it use the same trigger pipeline position as `LOAD_BAL`?

**To settle it:** set bit 7 with bit 6 clear on a router with several clients
and observe redistribution over time; then set both and compare.

---

## 3. `bsd_steering_policy` fields 1 and 2

Always `5` and `3` on stock firmware, on every radio, and no GUI control
touches them.

A debug string reads `bsd_trigger_policy min=%d max=%d rssi=%d flags=0x%x`,
which hints at a min/max pair, but that string may belong to a different
struct.

**To settle it:** trace where the parsed policy struct is populated and which
members these two feed.

---

## 4. Bit 5 is set everywhere

`PHYRATE_HIGH` (bit 5) is set on every radio in stock firmware, while the
corresponding PHY-rate field is `0`. A threshold that is enabled and null.

Either the flag has a secondary meaning, or the stock configuration is simply
sloppy. Both are plausible.

---

## 5. Unused bits in the qualify enum

`BSD_QUALIFY_POLICY_FLAG_*` skips values `0x8` and `0x10` — bits 3 and 4 have
no name. Removed during development, or reserved. No way to tell from the data
table alone.

---

## 6. `bsd_scheme`

Stock value `2` on a tri-band unit. A string named `bsd_steer_scheme_balance`
exists in the binary, so the scheme selector plainly influences steering
strategy, but the value space is undocumented.

---

## 7. Coverage

Everything here comes from **one firmware build on one model**:

    ASUS GT-AC5300, Broadcom BCM4908, tri-band
    firmware 3.0.0.4.386_51582 (the final release)

The daemon is common across Broadcom-based Asuswrt routers of this generation,
so much should transfer. But bit positions already differ *between policy types
inside the same binary*, which is ample reason not to assume they hold across
builds. Re-run `tools/dump-flag-tables.sh` on your own hardware before relying
on any of it.

Confirmations or contradictions from other models are the most useful thing
anyone could add to this.
