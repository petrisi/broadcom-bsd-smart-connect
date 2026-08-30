#!/bin/sh
#
# Re-derive the bsd flag tables from the binary on THIS router.
#
# Run it before trusting docs/04-flag-bits.md on any firmware other than the
# one it was written against. See docs/07-methodology.md for what it is doing.
#
# Requires Entware binutils:   opkg install binutils

BSD=${1:-/usr/sbin/bsd}
OUT=${TMPDIR:-/tmp}/bsdflags.$$

# MANDATORY: rc exports LD_LIBRARY_PATH, which makes every Entware binary load
# the wrong libc and die -- silently, because rc.func discards stderr.
unset LD_LIBRARY_PATH LD_PRELOAD

RE=/opt/bin/readelf
OD=/opt/bin/objdump
[ -x "$RE" ] || { echo "readelf not found at $RE  (opkg install binutils)"; exit 1; }
[ -x "$OD" ] || { echo "objdump not found at $OD  (opkg install binutils)"; exit 1; }
[ -f "$BSD" ] || { echo "no such binary: $BSD"; exit 1; }

echo "=== target ==="
"$RE" -h "$BSD" | grep -E "Class|Machine" | sed 's/^/  /'

# .rodata base address: string offsets from readelf -p are section-relative
RODATA=$("$RE" -S "$BSD" | awk '/\.rodata/ {print $5; exit}')
[ -n "$RODATA" ] || { echo "could not find .rodata"; exit 1; }
echo "  .rodata at 0x$RODATA"

echo
echo "=== flag name strings ==="
"$RE" -p .rodata "$BSD" 2>/dev/null | grep -E "BSD_(STEERING|STA_SELECT|QUALIFY)_POLICY_FLAG_" > "$OUT.names"
wc -l < "$OUT.names" | sed 's/^/  names found: /'

# dump every section that could hold the value table
{ "$OD" -s -j .rodata "$BSD"; "$OD" -s -j .data "$BSD"; "$OD" -s -j .data.rel.ro "$BSD"; } > "$OUT.hex" 2>/dev/null

echo
echo "=== resolving {value, name} pairs ==="
echo "  (the value PRECEDES its name pointer -- reading the word after gives a"
echo "   plausible, internally consistent, and completely wrong answer)"
echo

awk -v rodata="0x$RODATA" '
# --- load the hex dump into an address->byte map ---
FNR == NR {
    if (match($0, /^ [0-9a-f]+ /)) {
        addr = strtonum("0x" $1)
        for (i = 2; i <= NF; i++) {
            if ($i !~ /^[0-9a-f]+$/ || length($i) > 8) continue
            for (j = 1; j <= length($i); j += 2) {
                mem[addr++] = strtonum("0x" substr($i, j, 2))
            }
        }
    }
    next
}
# --- second file: the name list ---
{
    if (match($0, /\[ *[0-9a-f]+\]/)) {
        off = strtonum("0x" substr($0, RSTART+1, RLENGTH-2))
        nm  = $NF
        addr = strtonum(rodata) + off
        want[addr] = nm
    }
}
END {
    base = strtonum(rodata)
    for (a in mem) {
        v = rd32(a)
        if (v in want) { hitaddr[++n] = a; hitname[n] = want[v] }
    }
    # sort by table address
    for (i = 1; i <= n; i++) for (j = i+1; j <= n; j++)
        if (hitaddr[j] < hitaddr[i]) {
            t=hitaddr[i]; hitaddr[i]=hitaddr[j]; hitaddr[j]=t
            s=hitname[i]; hitname[i]=hitname[j]; hitname[j]=s
        }
    for (i = 1; i <= n; i++) {
        val = rd32(hitaddr[i] - 4)          # the value PRECEDES the pointer
        bit = -1
        if (val > 0) { p = val; b = 0; while (p % 2 == 0) { p = int(p/2); b++ }
                       if (p == 1) bit = b }
        printf "  %-12s  %-8s  %s\n",
               sprintf("0x%x", val),
               (bit >= 0 ? sprintf("bit %d", bit) : "  -"),
               hitname[i]
    }
}
function rd32(a) {
    if (!((a) in mem) || !((a+1) in mem) || !((a+2) in mem) || !((a+3) in mem)) return -1
    return mem[a] + mem[a+1]*256 + mem[a+2]*65536 + mem[a+3]*16777216
}
' "$OUT.hex" "$OUT.names"

echo
echo "=== sanity check ==="
echo "  LOAD_BAL must land on bit 6. It is confirmed independently by the GUI,"
echo "  which drives bit 6 from its 'Enable Load Balance' control."
echo "  If it does not, the pair alignment is off by one entry."

rm -f "$OUT.names" "$OUT.hex"
