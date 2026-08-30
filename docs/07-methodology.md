# How to reproduce and verify this

## Start with the daemon's own output

Before any binary analysis:

    /usr/sbin/bsd -H     # the complete flag reference, from the vendor
    /usr/sbin/bsd -i     # parsed config, every flag decoded into English

`-H` prints the field layouts and every flag constant with its hex value. `-i`
prints how the daemon actually interpreted your current configuration. Between
them they answer most questions about the format directly, and they take
seconds.

Bound them anyway, and confirm the running daemon survived:

    /usr/sbin/bsd -i > /tmp/bsd_i.txt 2>&1 &
    _p=$!; _n=0
    while kill -0 $_p 2>/dev/null && [ $_n -lt 8 ]; do sleep 1; _n=$((_n+1)); done
    kill -9 $_p 2>/dev/null
    pidof bsd

See `09-diagnostics.md` for what each option produces.

**This section is deliberately first.** The binary-extraction method below was
developed before those options were discovered, and produced exactly the same
table — but it took hours rather than seconds. If you are verifying this
repository against your own firmware, `bsd -H` is the fast path, and the
extraction below is the independent check.

---

## Extracting the flag table from the binary

Worth doing if you want to confirm the vendor output rather than trust it, or
if you are working with a build whose `bsd` lacks these options.

### 1. Get binutils onto the router

Entware, on a USB stick. See the companion repository for setup.

    unset LD_LIBRARY_PATH LD_PRELOAD    # mandatory, or nothing from /opt runs
    opkg update
    opkg install binutils

The busybox `strings` will do, but it does not support `-t`, so offsets have to
come from `readelf`.

### 2. Find the flag-name strings

    readelf -p .rodata /usr/sbin/bsd | grep BSD_STEERING_POLICY_FLAG_

Offsets are **relative to the section**, so get its address:

    readelf -S /usr/sbin/bsd | grep .rodata

Absolute address = section address + offset.

### 3. Find the value table

The names alone give you an ordering, and ordering is a tempting shortcut.
**It is wrong.** On this binary the string order matches the real values for
one enum and diverges for two others — `CHAN_OVERSUB` is at bit 31, not bit 9,
and the qualify enum skips two bits entirely.

The real values live in a `{value, name}` pair table. Dump the data sections
and search for words matching your computed string addresses:

    objdump -s -j .data       /usr/sbin/bsd
    objdump -s -j .data.rel.ro /usr/sbin/bsd
    objdump -s -j .rodata     /usr/sbin/bsd

On the reference build the steering table sits at `0x40420` in `.data`.

### 4. Read the word BEFORE each pointer

The struct is `{value, name}` — the value **precedes** its name pointer:

    0x4041c   00000040          <- LOAD_BAL's value
    0x40420   <ptr to "BSD_STEERING_POLICY_FLAG_LOAD_BAL">
    0x40424   00000080          <- STA_NUM_BAL's value
    0x40428   <ptr to "BSD_STEERING_POLICY_FLAG_STA_NUM_BAL">

Read the word *after* each pointer instead and you get a sequence that is
internally consistent, plausible, and shifted by exactly one entry. Every value
is wrong and nothing looks wrong.

### 5. Verify against an anchor

`LOAD_BAL` must land on `0x40`. It is independently confirmable: the GUI drives
bit 6 from its "Enable Load Balance" control, and `bsd -i` prints
`LOAD BALANCE: YES/NO` for that bit.

If your table puts it anywhere else, the pair alignment is off by one.

`tools/dump-flag-tables.sh` automates steps 2–5.

---

## Other things the binary yields

Debug format strings name struct fields in order:

    strings /usr/sbin/bsd | grep -E "idle_rate|min_bw|max=|Policy:"

That is how the `sta_select` weight vector and the undocumented third field of
`bsd_if_qualify_policy` were identified, before `bsd -i` confirmed both.

---

## What none of this tells you

Reading tables and help text gives you names, constants and layouts. It does
**not** tell you how the daemon weighs one condition against another, how it
arbitrates when two balance modes are enabled at once, or what the strategy
presets behind `scheme` and `algo` actually do.

Those need either behavioural testing or disassembly of the decision path. See
`08-open-questions.md`.

## A note on method

The VHT flags were misread in an earlier revision of this repository. The name,
the GUI source, and the stored values were all consistent with the wrong
interpretation, and it survived several rounds of checking. What settled it was
the daemon printing its own interpretation in English.

Where a component can be made to explain itself, that beats inference — even
careful inference against good evidence.
