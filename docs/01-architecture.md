# Architecture

Understanding who wrote which piece explains why the system behaves as it does,
and where you can safely intervene.

Evidence for the split is the shared-library dependency fingerprint: Broadcom's
daemons link a tight, uniform set; ASUS's binaries link sprawling in-house ones.

## Layer 1 — silicon and driver (Broadcom, closed)

    dhd.ko      ~1.5 MB    FullMAC wireless driver
    wlcsm.ko    ~18 KB     config/state helper
    emf / igs              multicast forwarding and snooping

**FullMAC** means the 802.11 state machine runs on the radio firmware, not in
Linux. Consequences: no `mac80211`, no `iw`, no monitor mode, and `wl` is the
only way to talk to the radios.

## Layer 2 — userland daemons (Broadcom, closed, from the router SDK)

    bsd        band steering          <- what this repository documents
    acsd       auto channel selection
    nas        WPA/WPA2 authenticator
    wlconf     applies wl_* nvram to the driver

All four link **exactly** `libnvram + libwlcsm + libshared` plus libc. Nothing
ASUS-specific. These are SDK components included largely unmodified, which is
why their log lines and nvram names look nothing like the rest of the firmware.

## Layer 3 — nvram (the integration bus)

A flat key-value store, roughly 82 KB in use, with visibly separate namespaces:

    wl_* / wl0_* ...        ~1500 entries   Broadcom
    bsd_* / acsd_*          ~13 entries     Broadcom daemon config
    asus* / webs_* / cfg_* / amas_* / bwdpi_*   ASUS

**This is the key architectural fact: the two codebases never call each other.**
ASUS's code writes nvram. Broadcom's daemons read nvram at startup. That store
is the entire coupling between them.

Three consequences follow, and they matter in practice:

1. **Editing nvram directly is equivalent to using the GUI.** The GUI is a
   validating nvram editor and nothing more. There is no additional state.

2. **Changes require a daemon restart.** The daemons read configuration at
   startup, so writing nvram alone changes nothing until `service
   restart_wireless` (which is exactly what the GUI's Apply button posts).

3. **A GUI page can disagree with what the daemon honours**, because nothing
   enforces agreement between them. See `08-open-questions.md` — that is not
   hypothetical here.

## Layer 4 — Asuswrt (ASUS, closed)

    rc          ~2 MB     init and service manager, ~30 libraries
    httpd       ~635 KB   GUI web server, ~200 .asp pages
    wlceventd             wireless client event handler

`rc`'s dependency list is the tell: `libbwdpi` (Trend Micro DPI),
`libamas-utils` (AiMesh), `libletsencrypt`, `libasuslog`, `libvpn`,
`libcfgmnt`, `libnt`, `libconn_diag`. None of that is Broadcom.

## Layer 5 — open source

busybox for the base userland, plus dnsmasq, dropbear and lighttpd.

## Why this matters when tuning steering

Wireless behaviour — steering, channel selection, association — belongs to
**Broadcom**. You tune it through `bsd_*` and `wl*_bsd_*` nvram, and its log
lines are prefixed `bsd:`.

Everything surrounding it — GUI, services, boot, telemetry — is **ASUS's**.

Because the seam between them is nvram, direct nvram edits are a legitimate
configuration path rather than a hack: you are writing to precisely the
interface the GUI writes to, and the daemon cannot tell the difference.
