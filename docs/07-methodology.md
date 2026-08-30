# How to reproduce this

Everything in `04-flag-bits.md` can be re-derived on any Asuswrt router running
`bsd`. You should, if you are relying on it — bit positions may differ between
firmware builds, and this was verified on exactly one.

`tools/dump-flag-tables.sh` automates the whole sequence. What follows is what
it does and why.

## 1. Get binutils onto the router

Entware, on a USB stick. See the companion repository for setup.

    unset LD_LIBRARY_PATH LD_PRELOAD    # mandatory, or nothing from /opt runs
    opkg update
    opkg install binutils

You need `readelf` and `objdump`. The busybox `strings` will do, but it does
not support `-t`, so offsets have to come from `readelf`.

## 2. Find the flag-name strings

    readelf -p .rodata /usr/sbin/bsd | grep BSD_STEERING_POLICY_FLAG_

Offsets are **relative to the section**, so get its address:

    readelf -S /usr/sbin/bsd | grep .rodata

Absolute address = section address + offset.

## 3. Find the value table

The names alone give you an ordering, and ordering is a tempting shortcut.
**Do not trust it** — on this binary it is correct for one enum and wrong for
two others.

The real values live in a `{value, name}` pair table. Dump the writable data
sections and search for words matching your computed string addresses:

    objdump -s -j .data       /usr/sbin/bsd
    objdump -s -j .data.rel.ro /usr/sbin/bsd
    objdump -s -j .rodata     /usr/sbin/bsd

On the reference build the steering table sits at `0x40420` in `.data`.

## 4. Read the word BEFORE each pointer

This is the part that catches people, and it caught me.

The struct is `{value, name}` — the value **precedes** its name pointer:

    0x4041c   00000040          <- LOAD_BAL's value
    0x40420   <ptr to "BSD_STEERING_POLICY_FLAG_LOAD_BAL">
    0x40424   00000080          <- STA_NUM_BAL's value
    0x40428   <ptr to "BSD_STEERING_POLICY_FLAG_STA_NUM_BAL">

Read the word *after* each pointer instead and you get a sequence that is
internally consistent, plausible, and shifted by exactly one entry. Every value
is wrong and nothing looks wrong.

## 5. Verify against an anchor

Never accept the table without an independent check. `LOAD_BAL` is the natural
anchor because it can be confirmed two other ways:

- the GUI reads and writes bit 6 from its "Enable Load Balance" control
  (`bsd_steering_policy_bin[i][6]` in `Advanced_Smart_Connect.asp`)
- setting bit 6 on a live router produces an observable behavioural change

If your table puts `LOAD_BAL` anywhere other than bit 6, the alignment is off
by one entry. Recheck step 4.

## 6. Other things worth pulling out of the binary

Debug format strings name struct fields in order, which is how the
`bsd_sta_select_policy` weight vector was identified:

    strings /usr/sbin/bsd | grep -E "idle_rate|min_bw|Policy:"

That gives you:

    Policy: idle_rate=%d rssi=%d phyrate_low=%d phyrate_high=%d wprio=%d
            wrssi=%d wphy_rate=%d wtx_failures=%d wtx_rate=%d wrx_rate=%d
            flags=0x%x

    bsd_if_qualify_policy min_bw[%d] flags[0x%x] rssi[%d]

Eleven fields and three fields respectively, matching the nvram layouts
exactly. Also present are the internal default policy names —
`bsd_2g5g_policy`, `bsd_5g2g_policy`, `bsd_5glo_2g_5ghi_policy` — selected by
band layout.

## What this approach cannot tell you

Reading data tables gives you names and constants. It does **not** tell you how
the daemon *uses* a flag — for that you need to disassemble the use sites and
trace the bit tests, which is a substantially bigger job.

That gap is why `08-open-questions.md` exists.
