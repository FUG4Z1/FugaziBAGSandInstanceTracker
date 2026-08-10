# Changelog

All notable changes to Fugazi Instance Tracker are listed here.


## [3.0.1] — 2026-10-08

small fix:
ignore sticky IsAltKeyDown after /reload for protect overlay
Arm Alt/Ctrl only after real MODIFIER_STATE_CHANGED; guard equip race on secure row clicks 
invalidate DE val after wardrobe collect
add Callboard/Mythical Cache to opener.

## [3.0.0] — 2026-08-08

The Gold-Per-Hour (GPH) tracking system has been completely gutted and rebuilt to be infinitely smarter.

--Smart Item Valuation: The addon now actively evaluates the items you loot to tell you the most profitable action. It automatically analyzes your items to figure out if you should Vendor, Auction, Disenchant, Prospect, or Mill them based on your TSM or Auctionator Scan data.
--Visual Stamping: The engine places tiny icons next to your items (both in Grid View and List View) telling you what to do with them. (e.g., A copper coin for Vendoring, Gold stack for auctioning, a Disnchanter icon for Disenchanting).
--Auction Data Integration: The engine hooks directly into your Auctionator or TSM addon database to scan the Auction House value of your loot on the fly.
--Total Session Value Breakdown: Mousing over the Session Value tracker now gives you a tooltip breaking down the exact value of your session by category (Raw Gold vs Vendor Value vs Auction Value vs Destroy Value).



Opener" & Profession Button Overhaul
completely reworked the engine that handles opening items, lockboxes, and chests.

--Learn Recipes Automatically: Added a massive new feature that lets you learn unlearned recipes and patterns directly from the UI.
--Smooth Animations: Clicking openable items or learning recipes from the new buttons now triggers fading and opening animations instead of just awkwardly disappearing in Gridview.
--Combat Safety: The Profession Buttons will now intelligently hide themselves while you are in combat or dead to prevent the addon from tainting or throwing UIErrors.



Filtered Autosell Intelligence
The Autosell system has been heavily upgraded to hook into the new Valuation Engine.

--if you use Filtered Autosell, the vendor engine will now only sell the items that the Valuation Engine explicitly flags as "Most Profitable to Vendor". It leaves your Auction and Disenchanting loot alone. Autosell also won't sell Blue BOP items or Epics.
--We've reinforced the Protection API across the entire addon to ensure your prized items are never touched. 
--Protected items are strictly ignored by the new Valuation Engine. They will never get evaluated, and they will never have vendor/auction coins stamped over them.
--Mass-Deleter Safety: The Mass-Deleter worker has been updated to use the absolute latest Protection API. It is physically impossible for the deleter to accidentally scrap a protected item.



Speed & Smoothness
Bags should feel a lot lighter again — especially while farming.

--Mass loot / AOE dumps with bags open no longer make the whole UI stutter and rebuild.
--Stack counts update in place instead of the list thrashing every time something stacks.
--Leaving bags open idle no longer causes random refreshes or count flicker.
--Bank deposit / withdraw is snappier once the bank is open (first open is still a full scan — that’s normal).



Rarity Filter Upgrades
The color bar at the top got smarter.

--Left-click a quality to filter it. Drag across several buttons to filter multiple rarities at once (e.g. green + blue).
--Right-click clears all rarity filters in one go.
--Filters actually paint correctly now — matching items stay clear, the rest dim as expected.
--Search + rarity filters apply to bulk bank / mail moves too (only the filtered stuff moves).



Bank, Mail & Bulk Moves

--Bulk move tools respect your search box and active rarity filters.
--Shift + Right-click a category header in List View to move that whole category (bags ↔ bank / mail).
--Ascension bank awareness: Personal / Realm / Guild banks behave correctly (e.g. soulbound only goes where it’s allowed).
--Mail “Send All” / rarity sends play nicer with filters and recipients.



Options & Guidance

--New Instructions tab (Quick Guide): short player-facing how-to for shortcuts, rarity bar, moves, mail, GPH, and safety.
--Valuation options cleaned up — clearer wording for what the icons / always-valuate / matrix rules actually do for you.
--List categories are more reliable (items land in the right section more consistently).



More Bug Fixes & Polish

--Disenchant spam no longer risks equipping BoE gear by accident.
--Opening caches / clams / boxes: fewer stuck “dark” slots; chains more reliably after empty loots.
--Auto-delete is even stricter about protected items and skips work when your delete list is empty.
--Value icons layout fixed when item icons are hidden (no more stamps under text).
--Bag window sizing is more stable (list auto-size, bank height, less tall→short flicker while moving items).
--Bank list no longer goes empty / half-empty after a dungeon when the grid still looks full.
--Free-float position polish: less snapping / weird stacking when bank and bags are both open.
--Tracked down and eradicated a terrible flickering issue inside the Grid View that was driving me crazy.
--Fixed an issue where the addon was incorrectly tracking Item Levels (iLvl) under certain conditions.
--Fixed a handful of tooltip bugs when hovering over items in the Bank.
--Polished up several UI elements inside the Options menu for a cleaner look.



FIT:
------

FIT is rebuilt around a run ledger and related windows, not the old all-in-one mega UI. It’s aimed more clearly at Ascension (and expects Fugazi Bags (and Auctionator/TSM data) for pricing / auto-sell / auto-delete style data).

What you use day to day
--Ledger as the main place to browse runs: live “current run,” history, filters, search.
--Run details when you click into a run.
--Items view for loot from your runs.
--Shared filter bar (time range, search, value lens, etc.) instead of scattered controls.
--Value lens so you can flip how gold is shown: GPH, Total (estimate), Raw, Vendor, Auction, Destroy.
--Item values line up with how Bags values things, so FIT and Bags should feel consistent.
--Search is snappier / more usable on big histories.

Ascension-specific behavior
--Classic-style instance lockout UI is basically not the point on Ascension (that path is treated as N/A).
--Manastorm runs are not logged as normal dungeon runs (so they don’t pollute the ledger).

While you’re in a dungeon
--Mid-run /reload keeps the run going instead of starting from zero.
--If you leave and re-enter within ~5 minutes, the same run resumes.
--Empty pop-ins (walk in, leave, nothing meaningful happened) are not saved

Smaller quality-of-life
--Cleaner windows / skinning and live refresh when settings change.
--Sounds and row layout feel closer to the Bags UI.
--Slash / window setup is simpler: focus on ledger, run details, and items rather than a big classic /fit control panel.
--Can monitor "live" current run

---

## [1.7.2] — 2026-02-13

**1.7.2 turns the addon into a full loot manager.** On-the-fly blacklisting, auto-deleting, and inventory sorting from the GPH and Ledger windows — no setup in multiple menus. One flow: instance cap, run history, gold-per-hour, and full loot control.

### What’s different from 1.7.1

#### GPH is now a full loot manager
- **Sort your loot** by rarity, vendor price, or item level — one click in the GPH title bar. No addon config.
- **Protection (blacklist):** Mark items with (*) so they’re never vendored or mass-deleted. Rarity bar toggles protect *all* items of that quality (grey, green, blue, etc.) until you turn it off. Other addons (e.g. EbonholdStuff) may ignore this addon’s blacklist — not compatible for vendoring; use one or the other.
- **Auto-destroy list:** Shift+double-click the **[x]** on any GPH row to add that item to the destroy list. Those items are then auto-deleted when the list runs. One-click Disenchant/Prospect button for the next destroyable item. No menus — mark and go.
- **Delete on the fly:** Double-click **[x]** on a row to delete that item (or stack). Double-click a rarity header to delete *all* items of that quality in one go (respects blacklist).
- **Right-click** items in the GPH list to use or equip (game allows or blocks by context).
- **Bag key** can open GPH instead of default bags (optional). **/gph** on your bag key for one-key access.

#### Ledger and item detail
- **“Click to view items”** on a run opens the item detail window **docked to the right of the Ledger (or GPH)** so run list and item list sit side by side.
- **Item detail stays docked** when you expand it — no more jumping back.
- **Search** in the item detail window (instance name, item name, or rarity) to filter what you see.

#### Auto-vendor and auto-summon at Goblin Merchant
- **Auto-vendor** at the Goblin Merchant respects (*) and rarity blacklist; epics never auto-sold. **Auto-summon** Greedy Scavenger after selling (1.5s delay) when AutoSummon is on. Greedy’s chat spam is muted.
- **Autopet button** in GPH title bar: LMB = toggle AutoSummon after vendor, RMB = summon Greedy (or dismiss and resummon). Hidden if you don’t have the Greedy scavenger pet; magnify, bag, and disenchant buttons shift left.

#### Smoother and more reliable
- **Icons** in the item viewer and GPH list stay correct or use a grey fallback (no more red “?” after vendoring/deleting).
- **Tooltips** improved and wording simplified (e.g. Stats = “View Ledger”).
- **README** reordered to lead with GPH and full loot manager; terminology aligned to “blacklist” for protection; **disclaimer** added (use at your own risk; not responsible for lost items/gold/data).

### Summary vs 1.7.1

| 1.7.1 | 1.7.2 |
|-------|--------|
| Instance cap + run ledger + basic GPH session | Same, plus **full loot management**: sort, blacklist (per-item and rarity), destroy list, one-click DE/Prospect, mass-delete by rarity |
| Item detail could open but didn’t always dock | Item detail **docks to Ledger or GPH** and **stays docked** |
| No autopet layout for players without Greedy | **Autopet button hidden** when you don’t have Greedy; other title bar buttons shift left |
| No README disclaimer | **Disclaimer** (use at your own risk) |

---

## [1.7.1] — 2026-02-11

(Previous release; see [GitHub Releases](https://github.com/FUG4Z1/FugaziInstanceTracker/releases) for earlier history.)

---

[1.7.2]: https://github.com/FUG4Z1/FugaziInstanceTracker/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/FUG4Z1/FugaziInstanceTracker/releases/tag/v1.7.1
