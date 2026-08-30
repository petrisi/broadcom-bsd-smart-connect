#!/bin/sh
#
# Decode a bsd policy flag word, or a whole policy string, into flag names.
#
# Usage:
#   ./decode-flags.sh steering   0x62
#   ./decode-flags.sh sta_select "30 -62 0 0 0 1 1 0 0 0 0x162"
#   ./decode-flags.sh qualify    0x4
#   ./decode-flags.sh live                 # decode everything on this router
#
# Bit positions differ per policy type -- see docs/04-flag-bits.md. Verify them
# on your own firmware with dump-flag-tables.sh before trusting this.

names_steering="0:RULE 1:RSSI 2:VHT 3:NON_VHT 4:NEXT_RF 5:PHYRATE_HIGH 6:LOAD_BAL 7:STA_NUM_BAL 8:PHYRATE_LOW 9:N_ONLY 31:CHAN_OVERSUB"
names_sta_select="0:RULE 1:RSSI 2:VHT 3:NON_VHT 4:NEXT_RF 5:PHYRATE_HIGH 6:LOAD_BAL 7:SINGLEBAND 8:DUALBAND 9:ACTIVE_STA 10:PHYRATE_LOW 11:N_ONLY"
names_qualify="0:RULE 1:VHT 2:NON_VHT 5:PHYRATE 6:LOAD_BAL 7:STA_BAL 8:N_ONLY"

decode() {
    _type=$1; _word=$2
    case "$_type" in
        steering)   _map="$names_steering" ;;
        sta_select) _map="$names_sta_select" ;;
        qualify)    _map="$names_qualify" ;;
        *) echo "unknown policy type: $_type (steering|sta_select|qualify)"; return 1 ;;
    esac

    # strip 0x if present, parse as hex
    _v=$(printf '%d' "$_word" 2>/dev/null) || { echo "  cannot parse: $_word"; return 1; }

    _out=""
    for _pair in $_map; do
        _bit=${_pair%%:*}; _name=${_pair#*:}
        # shift in awk: the shell has no >> and would overflow on bit 31 anyway
        _set=$(awk -v v="$_v" -v b="$_bit" 'BEGIN { printf "%d", int(v / (2 ^ b)) % 2 }')
        [ "$_set" = "1" ] && _out="$_out${_out:+ | }$_name"
    done
    printf '  %-11s %-10s = %s\n' "$_type" "$_word" "${_out:-<none set>}"
}

# pull the last whitespace-separated field, so a whole policy string works too
lastfield() { echo "$1" | awk '{print $NF}'; }

case "$1" in
    live)
        for n in 0 1 2; do
            for t in steering sta_select; do
                _v=$(nvram get "wl${n}_bsd_${t}_policy" 2>/dev/null)
                [ -n "$_v" ] && { echo "wl$n ${t}: $_v"; decode "$t" "$(lastfield "$_v")"; }
            done
            _v=$(nvram get "wl${n}_bsd_if_qualify_policy" 2>/dev/null)
            [ -n "$_v" ] && { echo "wl$n qualify: $_v"; decode qualify "$(lastfield "$_v")"; }
            _v=$(nvram get "wl${n}_bsd_if_select_policy" 2>/dev/null)
            [ -n "$_v" ] && echo "wl$n targets: $_v"
            echo
        done
        echo "smart_connect_x = $(nvram get smart_connect_x)   (1 = tri-band, 2 = 5 GHz only)"
        echo "bounce detect   = $(nvram get bsd_bounce_detect)   (window s, count, dwell s)"
        ;;
    steering|sta_select|qualify)
        [ -n "$2" ] || { echo "usage: $0 $1 <flags|policy string>"; exit 1; }
        decode "$1" "$(lastfield "$2")"
        ;;
    *)
        sed -n '3,12p' "$0" | sed 's/^# \?//'
        exit 1
        ;;
esac
