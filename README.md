# Broadcom `bsd` / ASUS Smart Connect — reverse-engineered

Smart Connect is ASUS's name for band steering: one SSID across all radios,
with the router deciding which band each client sits on. The work is done by
`bsd`, Broadcom's closed-source band steering daemon.

The GUI exposes a "Smart Connect Rule" page with a dozen controls. What it
writes to nvram are opaque strings like:

    wl0_bsd_steering_policy = "0 5 3 -62 0 0 0x62"

No vendor documentation for that format is published. The community write-ups
that exist describe the GUI fields, and one long-standing forum thread notes
that the hex flags were never decoded.

**This repository decodes them** — and, it turns out, so does the daemon.
`bsd -H` is an undocumented option that prints the complete flag reference, and
`bsd -i` prints the parsed configuration with every flag rendered in English.
Neither appears in the GUI, ASUS's documentation, or any community write-up
found so far. See [09-diagnostics.md](docs/09-diagnostics.md) — **start there.**

The reverse-engineering came first and the built-in reference was found later.
Both are kept: the extracted tables and the vendor output agree exactly, which
makes each an independent check on the other.

<img width="776" height="1064" alt="image" src="https://github.com/user-attachments/assets/c1c47128-a97d-4e48-a8cb-bc1040b0699d" />

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
| [09-diagnostics.md](docs/09-diagnostics.md) | **the daemon's own undocumented diagnostic options** |

`tools/` has two small scripts: one decodes a policy string into flag names,
the other re-derives the flag tables on your own router.

## Confidence

The flag tables in `04-flag-bits.md` are **confirmed by the vendor**: `bsd -H`
prints them directly. They were originally derived by extracting the daemon's
own {value, name} lookup table from `.data`, and the two agree exactly —
including the out-of-sequence `CHAN_OVERSUB` at bit 31 and the deliberate gaps
in the qualify enum.

Field layouts come from `bsd -H` and are confirmed live by `bsd -i`, which
prints the parsed struct.

`08-open-questions.md` records what is still unresolved — and one place where
an earlier revision of this repository was **wrong**. The VHT flags were read as
selecting a class of station when they in fact exclude one, which led to a claim
that the GUI's labels were inverted. They are not. The correction is documented
rather than quietly removed, because how the error survived several rounds of
checking is itself worth knowing.

## Scope

One firmware build (`3.0.0.4.386_51582`) on one model (ASUS GT-AC5300,
Broadcom BCM4908, tri-band). The daemon is common to Broadcom-based Asuswrt
routers of this generation, so much of this should transfer — but bit
positions differ *between policy types within the same binary*, so assume
nothing across models without re-running `tools/dump-flag-tables.sh`.

MIT licensed.
