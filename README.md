# Broadcom `bsd` / ASUS Smart Connect — reverse-engineered

Smart Connect is ASUS's name for band steering: one SSID across all radios,
with the router deciding which band each client sits on. The work is done by
`bsd`, Broadcom's closed-source band steering daemon.

The GUI exposes a "Smart Connect Rule" page with a dozen controls. What it
writes to nvram are opaque strings like:

    wl0_bsd_steering_policy = "0 5 3 -62 0 0 0x62"

There is no vendor documentation for that format. The community write-ups that
exist describe the GUI fields, and one long-standing forum thread notes that
the hex flags were never decoded.

**This repository decodes them**, from the firmware itself.

## What is here

| | |
|---|---|
| [01-architecture.md](docs/01-architecture.md) | the five layers, and why nvram is the seam that matters |
| [02-nvram-variables.md](docs/02-nvram-variables.md) | the variable set, and the `_x` suffix trap |
| [03-policy-formats.md](docs/03-policy-formats.md) | every field of all four policy types |
| [04-flag-bits.md](docs/04-flag-bits.md) | **the three flag tables, read from the binary** |
| [05-gui-encoding.md](docs/05-gui-encoding.md) | how the GUI encodes and decodes them |
| [06-behaviour.md](docs/06-behaviour.md) | what steering actually does, and what Load Balance changes |
| [07-methodology.md](docs/07-methodology.md) | **how to reproduce all of this yourself** |
| [08-open-questions.md](docs/08-open-questions.md) | what is still unresolved |

`tools/` has two small scripts: one decodes a policy string into flag names,
the other re-derives the flag tables on your own router.

## Confidence

Everything in `04-flag-bits.md` is read out of `bsd`'s own `{value, name}`
lookup table in `.data`. That is as authoritative as it gets short of source
code, and it is independently corroborated: `LOAD_BAL` resolves to the same bit
the GUI drives from its "Enable Load Balance" control, and setting that bit
produced the expected behavioural change on hardware.

The field maps in `03-policy-formats.md` come from the GUI's own JavaScript
plus a debug format string in the binary that names every field in order.

`08-open-questions.md` is where the honest gaps live, and it is not empty. One
contradiction between the binary and the GUI is unresolved, several positional
fields remain unexplained, and one flag is derived but never exercised.

## Scope

One firmware build (`3.0.0.4.386_51582`) on one model (ASUS GT-AC5300,
Broadcom BCM4908, tri-band). The daemon is common to Broadcom-based Asuswrt
routers of this generation, so much of this should transfer — but bit
positions differ *between policy types within the same binary*, so assume
nothing across models without re-running `tools/dump-flag-tables.sh`.

MIT licensed.
