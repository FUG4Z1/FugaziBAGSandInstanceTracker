# Locales (FugaziBAGS + FIT)

English (`enUS`) is the **source of truth**. Other languages are community contributions.

## What is done

- **Functional strings** that the addon matches against the game client:
  - Item bind tooltips (soulbound, account/realm bound, BoE)
  - Personal / Realm bank window titles
  - Greedy scavenger / Goblin Merchant names and chat mute
  - Item class/subtype strings used for DE / prospect / mill / gear rules
  - FIT system chat (Manastorm, instance cap, reset) and lockout boss status
- **Helpers** so modules never hardcode those phrases
- **Light UI samples** (skip messages, protect tooltip lines) as the pattern for later full UI work

## Adding a language (e.g. Spanish)

### FugaziBAGS

1. Copy `Locales/enUS.lua` → `Locales/esES.lua`
2. Change the last assignment to:
   ```lua
   A._localeTables.esES = L
   ```
   (Use the real locale code: `esES`, `esMX`, `ruRU`, `zhCN`, `deDE`, `frFR`, …)
3. Translate **values only**. Keep key names (`BIND_NONTRADEABLE`, etc.)
4. Add the file to `__FugaziBAGS.toc` **after** `Locales\enUS.lua` and **before** `Locales\Locale.lua`:
   ```
   Locales\enUS.lua
   Locales\esES.lua
   Locales\Locale.lua
   ```
5. **Playtest on that client** — especially bank deposit, mail skip, GPH soulbound value, pet vendor.

### FugaziInstanceTracker

Same pattern under `__FugaziInstanceTracker/Locales/`, using:

```lua
ns._localeTables.esES = Loc
```

and TOC entries before `Locales\Locale.lua`. FIT needs `__FugaziBAGS` loaded (`RequiredDeps`).

## Critical rules for translators

| Do | Don't |
|----|--------|
| Copy bind lines from a **live tooltip** on your client | Machine-translate "Soulbound" / "Binds when picked up" |
| Copy bank title words from the open Personal/Realm bank frame | Guess from Google Translate |
| Keep phrase lists as **lowercase substrings** where the English file uses them | Change key names or table structure |
| Mark unverified AI translations in a comment at the top of the file | Claim a language works without login testing |

## How matching works

- Tooltip bind scans: lowercase line → `A.IsNonTradeableBindText(t)` / `A.IsBoEBindText(t)`
- Bank titles: `A.ClassifyBankTitleText(text)` → `"personal"` / `"realm"` / `nil`
- Pets: name tokens must **all** appear; NPC exact name for vendor target
- Missing locale file → full **enUS** fallback
- Missing key in a partial locale → enUS value, then the key string

## Intentionally not fully localized yet

Options panel, most buttons, long help text, and FIT ledger chrome still use hardcoded English. Move those into `L` / `L.Loc` over time using the same keys pattern. Behavior does not depend on those strings.
