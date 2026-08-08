# FIT Locales

FIT uses **`L.Loc`** for strings (`L` is the addon namespace).

English source: `enUS.lua`. Loader: `Locale.lua` (must load first in the TOC).

To add a language, follow the same steps as `__FugaziBAGS/Locales/README.md`:

1. Copy `enUS.lua` → `esES.lua` (or `ruRU`, `zhCN`, …)
2. Assign `ns._localeTables.esES = Loc`
3. Add the file to `__FugaziInstanceTracker.toc` after `enUS.lua` and before `Locale.lua`
4. Playtest Manastorm chat, instance reset, lockout boss rows on that client

Bind/bank/pet phrases are owned by **FugaziBAGS** (`FugaziBAGS.L`), not FIT.
