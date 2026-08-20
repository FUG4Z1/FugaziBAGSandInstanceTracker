<p align="center">
  <strong>Download from <a href="../../releases">Releases</a></strong> — not from the raw source tree.
</p>

# FugaziBAGS & FIT

Inventory, bank, loot cleanup, and GPH farm tracking for **World of Warcraft 3.3.5a** (WotLK).  
Made for private servers (currently Ascension CoA).

![Version](https://img.shields.io/badge/version-3.0.3-blue)
![Interface](https://img.shields.io/badge/interface-3.3.5a-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Two addons:

| Addon | What it is |
|--------|------------|
| **FugaziBAGS** | Your bags and bank. Works on its own. |
| **FugaziInstanceTracker** | Optional. Instance lockouts, run history, and the Ledger. Needs FugaziBAGS. |

You only need the folders from the latest **Release**.  
If you still have an old `FugaziInstanceTracker` folder (without the `__`), remove it — it is obsolete.

---

## FugaziBAGS

Replaces the default bag UI with **one inventory window** and a matching **bank**.  
List view and grid view, with skins shared by both windows (and by InstanceTracker if you use it).

<img width="1378" height="870" alt="2" src="https://github.com/user-attachments/assets/69226565-1f02-4343-be1d-49d7951ef160" />
<img width="1377" height="867" alt="1" src="https://github.com/user-attachments/assets/6795cf99-19c6-4ba7-b4e7-f89172476668" />


**Skins:** ElvUI  · ElvUI (Ebonhold) · Bagnon · Pimp Purple · FUGAZI

### Everyday use

- **Search** — find items by name, stats (and more); works in list and grid.
- **Rarity bar** — filter by quality; drag across colors for multi-filter; right-click clears.
- **Protect** — mark items or whole rarities so they are hard to vendor, mail, or delete by accident. Previously worn gear can be protected too.
- **Sort & categories** — list items by type; move whole categories between bags, bank, and mail when those windows are open. Respects search filters.
- **Bank** — custom bank UI that follows the same layout, filters, and skins as bags.
- **Mail helpers** — bulk send tools that respect search and rarity filters.
- **Notepad** — simple in-game notes with tabs.
- **Ascension extras** — e.g. add bag items to Wardrobe where supported.

### Cleanup while farming

- Mass-burst-delete unprotected Items by rarity, or add specific items to an **auto-delete** list.
- Continuous delete for junk as it lands (optional).
- Open boxes / lockboxes / caches, and learn recipes, from buttons on the bag frame.
- One-click style **Disenchant / Prospect / Mill** flows where your character can do them. Search filters respect the disenchanting. (Mill and Prospecting needs testing)
- **Auto-sell** at vendors. Can stick to selling trash, “best as vendor” items when valuation is on, or sell more aggressively — protection is always checked first.

### Gold-per-hour (GPH)

Start a session from the inventory. It tracks time, gold and items you pick up while it runs.

- Live session timer and value on the bag frame.
- Optional **valuation** stamps (vendor / auction / DE / prospect / mill) using Auctionator or TSM prices when those addons are present.
- When **InstanceTracker** is installed, finished farming sessions can be saved to the **Ledger** and reviewed at a later time.

### Valuation Engine

Per rarity (Common → epic) you set rules in **Escape → Interface → FugaziBAGS → Valuation**. For each item the engine builds a few candidate values, then picks an action:

<img width="902" height="824" alt="Ledger" src="https://github.com/user-attachments/assets/a1c7cd81-3a07-4bcf-8fd3-0c8161688cf9" />

| Source | Where the number comes from |
|--------|-----------------------------|
| **Vendor** | Item sell price from the client |
| **Auction** | Min buyout from **Auctionator** or **TSM** (when installed). Soulbound / realm-bound items never use AH value. |
| **Disenchant** | TSM DE price if available, otherwise the addon's internal essence tables (classic base iLvl) (other AddOns like Auctionator use a different formula and can show different values) |
| **Prospect / Mill** | Internal conversion tables (ores / herbs) when those options are on (still needs testing) |

With **Auto Best** on (default for most rarities), it picks the highest of vendor / AH / destroy after your filters. Filters like min AH price, min profit over vendor, and **No AH for gear** stay active with Auto Best — they only raise the floor (or drop AH), they do not replace the smart pick. **Force destroy** (iLvl band) is the exception: it is greyed out while Auto Best is on, and only hard-overrides when Auto Best is off for that rarity.

Useful filters (per rarity):

- **No AH for gear** — weapons/armor never count as Auction (handy for whites/greens that never sell). Works with Auto Best.
- **Always vendor soulbound** — soulbound gear is always Vendor (for alts without Enchanting, no phantom DE value). Overrides Auto Best for that gear.
- **Min AH price / min profit over vendor** — ignore weak AH listings; if AH fails the floor, Auto Best falls back to vendor or destroy.
- **Force destroy** — only when Auto Best is **off**: items in the iLvl band are valued as Destroy even if AH/vendor would win.

Stamps on the bag UI and filtered auto-sell use the same engine. **Protected** items are never sold or destroyed by FugaziBAGS regardless of valuation.

`B` opens the bags UI.  
Full in-game help guide: **Escape → Interface → FugaziBAGS** (Instructions tab).

---

## FugaziInstanceTracker (optional)

Depends on **FugaziBAGS**. Same skins. Tracks dungeon / farm activity so you do not have to spreadsheet it.

- **`/fit`** — main tracker (lockouts; hourly instance cap on realms that still use it).
- **`/ledger`** — run history: gold, duration, items, filters, search, per-run details.
- Lifetime-style stats from the runs you keep.
- Ties into bag GPH sessions and auto-delete stats where relevant.

You can run bags alone. Install InstanceTracker only if you want lockouts and the Ledger.

## Screenshots

<img width="985" height="1151" alt="Instance tracker" src="https://github.com/user-attachments/assets/948e76d7-16fa-472f-aa3a-29ab0e820691" />

---

## Install

1. Download the latest package from **Releases**.
2. Extract into `Interface\AddOns\` so you get:
   - `__FugaziBAGS`
   - `__FugaziInstanceTracker` (optional)
3. Restart the client.
4. Open bags as usual. Options to customize and the quick guide are under the Escape menu.

---

## Disclaimer

Provided **as-is**. You are responsible for anything that happens with auto-sell, auto-delete, mass delete, mail tools, and related features.

FugaziBAGS only follows **its own** protection rules. Other addons that sell or destroy items can ignore those rules. If you stack several cleanup addons, expect conflicts.


### Locales / translations

English (`Locales/enUS.lua`) is the base language. Functional strings (bind tooltips, bank titles, pet names, FIT system chat) are centralized so other languages can be added without editing game logic.

- How to add Spanish/Russian/Chinese/etc.: see **`Locales/README.md`**
- Only English is maintained in-repo; community locales should be verified on a live client of that language

---

## License

MIT — use it, change it, share it.

— **Fugazi**
