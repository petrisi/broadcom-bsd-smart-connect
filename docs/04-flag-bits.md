# Flag bits

The hex word at the end of every policy string. These values are read directly
out of `bsd`'s own `{value, name}` lookup table in `.data` — see
`07-methodology.md` to reproduce it.

## The critical warning

**The three policy types use three different enums.** The same name lands on
different bits depending on which variable it is in:

| flag | steering | sta_select | qualify |
|---|---|---|---|
| `LOAD_BAL` | bit 6 | bit 6 | bit 6 |
| `STA_NUM_BAL` / `STA_BAL` | **bit 7** | *(absent)* | **bit 7** |
| `PHYRATE_LOW` | **bit 8** | **bit 10** | *(absent)* |
| `N_ONLY` | **bit 9** | **bit 11** | **bit 8** |

`0x80` means STA-number-balance in a steering policy and `SINGLEBAND` in a
sta-select policy. Never carry a value from one variable to another.

---

## `BSD_STEERING_POLICY_FLAG_*`

| value | bit | name |
|---|---|---|
| `0x00000001` | 0 | `RULE` |
| `0x00000002` | 1 | `RSSI` |
| `0x00000004` | 2 | `VHT` |
| `0x00000008` | 3 | `NON_VHT` |
| `0x00000010` | 4 | `NEXT_RF` |
| `0x00000020` | 5 | `PHYRATE_HIGH` |
| `0x00000040` | 6 | `LOAD_BAL` |
| `0x00000080` | 7 | `STA_NUM_BAL` |
| `0x00000100` | 8 | `PHYRATE_LOW` |
| `0x00000200` | 9 | `N_ONLY` |
| `0x80000000` | 31 | `CHAN_OVERSUB` |

Note `CHAN_OVERSUB` at bit **31**, out of sequence. Anyone inferring the enum
from the order of the name strings — which is otherwise a decent heuristic —
gets this one wrong, and `N_ONLY` with it.

## `BSD_STA_SELECT_POLICY_FLAG_*`

| value | bit | name |
|---|---|---|
| `0x001` | 0 | `RULE` |
| `0x002` | 1 | `RSSI` |
| `0x004` | 2 | `VHT` |
| `0x008` | 3 | `NON_VHT` |
| `0x010` | 4 | `NEXT_RF` |
| `0x020` | 5 | `PHYRATE_HIGH` |
| `0x040` | 6 | `LOAD_BAL` |
| `0x080` | 7 | `SINGLEBAND` |
| `0x100` | 8 | `DUALBAND` |
| `0x200` | 9 | `ACTIVE_STA` |
| `0x400` | 10 | `PHYRATE_LOW` |
| `0x800` | 11 | `N_ONLY` |

## `BSD_QUALIFY_POLICY_FLAG_*`

| value | bit | name |
|---|---|---|
| `0x001` | 0 | `RULE` |
| `0x002` | 1 | `VHT` |
| `0x004` | 2 | `NON_VHT` |
| `0x020` | 5 | `PHYRATE` |
| `0x040` | 6 | `LOAD_BAL` |
| `0x080` | 7 | `STA_BAL` |
| `0x100` | 8 | `N_ONLY` |

**Bits 3 and 4 are unused** in this enum — the values skip from `0x004` to
`0x020`. This is the enum that a name-order heuristic gets most wrong.

---

## Worked examples

Stock values from the reference unit, decoded with the steering map:

    0x22  = RSSI | PHYRATE_HIGH
    0x28  = NON_VHT | PHYRATE_HIGH
    0x62  = RSSI | PHYRATE_HIGH | LOAD_BAL
    0x68  = NON_VHT | PHYRATE_HIGH | LOAD_BAL

`PHYRATE_HIGH` (bit 5) is set on every radio in stock firmware, with the
corresponding PHY-rate field left at `0` — enabled, with a null threshold.

`tools/decode-flags.sh` does this conversion for you.

## Corroboration

`LOAD_BAL` resolving to bit 6 is confirmed three ways: the binary's own value
table, the GUI reading and writing bit 6 from its "Enable Load Balance"
control, and an observed behavioural change when that bit was set on hardware.

That agreement is what anchors the rest of the table, since a single-entry
offset error would shift everything and still look plausible.
