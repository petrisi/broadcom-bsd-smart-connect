# Flag bits

The hex word at the end of every policy string.

**These are confirmed by the vendor.** `bsd -H` prints the complete flag
reference — see `09-diagnostics.md`. The tables below were originally derived
by extracting `bsd`'s `{value, name}` lookup table from `.data`
(`07-methodology.md`), and the vendor output matches that extraction exactly,
including the out-of-sequence `CHAN_OVERSUB` and the gaps in the qualify enum.

## The critical warning

**The three policy types use three different enums.** The same name lands on
different bits depending on which variable it appears in:

| flag | steering | sta_select | qualify |
|---|---|---|---|
| `LOAD_BAL` | 0x40 | 0x40 | 0x40 |
| `STA_NUM_BAL` / `STA_BAL` | **0x80** | *(absent)* | **0x80** |
| `PHYRATE_LOW` | **0x100** | **0x400** | *(absent)* |
| `N_ONLY` | **0x200** | **0x800** | **0x100** |

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

`CHAN_OVERSUB` sits at bit **31**, out of sequence with the rest.

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

**Bits 3 and 4 are unused** — the values skip from `0x004` to `0x020`. This is
in the vendor's own output, so the gap is deliberate.

---

## Most of these are not on/off switches

This is the part that is easy to get wrong, and reading the names alone will
mislead you. `bsd -i` decodes each flag in English, and the meanings are:

| bit | clear | set |
|---|---|---|
| 0 `RULE` | `Rule Logic: OR` | `Rule Logic: AND` |
| 1 `RSSI` | `RSSI: Less than or Equal to` | `RSSI: Greater than` |
| 2 `VHT` | `VHT: Allowed` | `VHT: Not-Allowed` |
| 3 `NON_VHT` | `NON VHT: Allowed` | `NON VHT: Not-Allowed` |
| 5 `PHYRATE_HIGH` | — | comparison direction for `phyrate_high` |
| 6 `LOAD_BAL` | `LOAD BALANCE: NO` | `LOAD BALANCE: YES` |
| 7 `STA_NUM_BAL` | `STA NUM BALANCE: NO` | `STA NUM BALANCE: YES` |

So bits 1, 2, 3 and 5 select a **comparison or a restriction**, not enablement.

The VHT pair are **exclusions**: setting `NON_VHT` excludes non-802.11ac
stations, which leaves only AC — which is what the GUI calls "AC only".
Setting `VHT` excludes AC stations. Neither set means both are allowed. Reading
these names as *selectors* rather than *exclusions* inverts their meaning, and
an earlier revision of this repository made exactly that error.

---

## Worked examples

Stock values from the reference unit, decoded with the steering map:

    0x22  = RSSI | PHYRATE_HIGH
    0x28  = NON_VHT | PHYRATE_HIGH
    0x62  = RSSI | PHYRATE_HIGH | LOAD_BAL
    0x68  = NON_VHT | PHYRATE_HIGH | LOAD_BAL

`PHYRATE_HIGH` is set on every radio in stock firmware with the corresponding
threshold left at `0`, giving `Greater than or Equal to 0` — always true.

`tools/decode-flags.sh` does this conversion. `bsd -i` does it authoritatively.

## Reason codes use the same bits

`bsd -l` reports why each steering attempt happened, in the same flag values:

    0x00000002   RSSI
    0x00000040   LOAD_BAL
    0x00000042   RSSI | LOAD_BAL
    0x00010000   steer succeeded      (outcome, not a policy flag)
    0x00020000   steer failed

A useful independent check on the table.
