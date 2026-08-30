# How the GUI encodes and decodes

Everything here is from `/www/Advanced_Smart_Connect.asp` on the router itself
— roughly 1800 lines of ASP-templated JavaScript. Reading it is the fastest way
to understand the format, because ASUS had to solve the same problem.

Two functions matter:

    handle_bsd_nvram()   nvram -> form   (decode)
    applyRule()          form -> nvram   (encode)

## The flag encoding

    parseInt(field)  ->  32-bit binary string  ->  REVERSED

`reverse_bin(createBinaryString(parseInt(x)))` produces a string where index N
is bit N, LSB first. So `bsd_steering_policy_bin[i][6]` is bit 6.

`parseInt` handles the `0x` prefix, so `"0x22"` becomes 34.

On save it goes back the other way:

    '0x' + parseInt(reverse_bin(bits.join("")), 2).toString(16)

## Which form control maps to which bit

| control | bit |
|---|---|
| RSSI comparison (`Less` / `Greater`) | 1 |
| VHT policy | 2 and 3 as a pair |
| Enable Load Balance | 6 |

VHT is encoded as a bit pair:

    (0,0) = All        (0,1) = "AC only"        (1,0) = "not-allowed"

The GUI's own source comments label these `//all`, `//ac only` and `//legacy`.
**These labels contradict the flag names in the binary** — see
`08-open-questions.md`.

## Read-modify-write preserves unknown fields

`applyRule()` splits the existing nvram value, overwrites only the indices it
owns, and re-joins. So `bsd_steering_policy` fields 1 and 2, the
`bsd_sta_select_policy` weight vector, and the GUI-invisible RSSI field of
`bsd_if_qualify_policy` all survive a GUI save untouched.

Useful to know if you set them by hand: the GUI will not clobber them.

## Load Balance hides controls

    change_lb(1, idx)   swaps every  steering_on_<idx>  ->  steering_off_<idx>

and `.steering_off_*` is `display: none`. The elements carrying that class are
exactly the Steering Trigger Condition fields — bandwidth utilisation, RSSI,
PHY rates, VHT — replaced in the UI by `- -`.

Crucially, those classes appear **only** in `gen_bsd_steering_div()`. The STA
Selection and Interface Select sections have none, so they stay live. See
`06-behaviour.md`, because this is the single most misunderstood part of Smart
Connect.

## Interface targets

Stored as interface names, but the form works in indices, mapped through
per-radio label arrays:

    wl0_names = ['5GHz-1', '5GHz-2', 'none']
    wl1_names = ['5GHz-2', '2.4GHz', 'none']
    wl2_names = ['5GHz-1', '2.4GHz', 'none']

Each radio's own band is excluded from its own target list, which is why the
arrays differ.

## What Apply actually posts

    action_mode   = apply_new
    action_script = restart_wireless
    action_wait   = 3

So `service restart_wireless` from a shell is exactly equivalent — which is
what makes nvram editing a first-class path rather than a workaround.

## Language tokens

The page is full of `<#1528#>` placeholders resolved from `/www/EN.dict`. That
file is **line-indexed with a one-line offset**: token `<#N#>` is line `N+1`.
`<#1528#>` resolves to line 1529, which is "All".

Worth knowing if you are reading the page source and want to know what a
control actually says.
