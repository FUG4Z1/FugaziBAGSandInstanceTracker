--[[
  FugaziBAGS English (enUS) locale — source of truth for translators.

  Functional phrase lists (BIND_*, BANK_TITLE_*, PET_*, etc.) drive behavior
  (tooltip scans, bank detection, pet mute). Copy them from a LIVE client of
  the target language; do not machine-translate bind/bank/chat phrases.

  UI-style keys (MSG_*, LABEL_*, TOOLTIP_*) are player-facing text.
]]

-- Prefer the TOC private table (`...`) so modules that use `local _, Addon = ...`
-- and modules that use `_G.FugaziBAGS` stay on ONE object. Creating a fresh `{}`
-- here used to split the namespace (Destroyer methods on Addon, UI on global → nil API).
local _, Addon = ...
if Addon then
    if _G.FugaziBAGS and _G.FugaziBAGS ~= Addon then
        for k, v in pairs(_G.FugaziBAGS) do
            if Addon[k] == nil then Addon[k] = v end
        end
    end
    _G.FugaziBAGS = Addon
else
    _G.FugaziBAGS = _G.FugaziBAGS or {}
end
local A = _G.FugaziBAGS
A._localeTables = A._localeTables or {}

local L = {}

----------------------------------------------------------------------
-- BIND PHRASES (tooltip lines, already matched lowercase)
-- Used by: GPH valuation, Bankview deposit skip, Mail skip
-- Wrong list → wrong soulbound skip / wrong GPH loot value
-- Does NOT include plain "Binds when equipped" (see BIND_BOE).
----------------------------------------------------------------------
L.BIND_NONTRADEABLE = {
    "soulbound",
    "soul bound",
    "binds when picked up",
    "account bound",
    "accountbound",
    "binds to account",
    -- Ascension realm vanity (Realm Bank items)
    "realm bound",
    "realmbound",
    "binds to realm",
}

-- BoE warning only (unbound gear still tradeable). Used by bag-slot "any bind" path
-- in GPH vendor totals — NOT by permanent-bind valuation / bank / mail skips.
L.BIND_BOE = {
    "binds when equipped",
}

----------------------------------------------------------------------
-- BANK WINDOW TITLE SCAN (Ascension reuses GuildBankFrame)
-- Used by: Bankview GetOpenGuildBankKind
-- Wrong list → personal bank may reject soulbound, or realm bank may accept it
----------------------------------------------------------------------
L.BANK_TITLE_PERSONAL = { "personal" }
L.BANK_TITLE_REALM = { "realm" }

L.LABEL_PERSONAL_BANK = "Personal Bank"
L.LABEL_REALM_BANK = "Realm Bank"
L.LABEL_GUILD_BANK = "Guild Bank"
L.LABEL_MAIL = "mail"
L.LABEL_DESTINATION = "destination"

----------------------------------------------------------------------
-- PET / VENDOR NAMES (Ascension companions)
-- Used by: AutoSell summon, vendor target check, chat mute
-- IDs (600135 / 600126) remain primary; names are fallbacks
----------------------------------------------------------------------
L.NPC_GOBLIN_MERCHANT = "Goblin Merchant"
L.PET_GREEDY_SCAVENGER = "Greedy scavenger"
-- Companion name must contain ALL tokens (case-insensitive)
L.PET_GREEDY_NAME_TOKENS = { "greedy", "scavenger" }
L.PET_GOBLIN_NAME_TOKENS = { "goblin", "merchant" }
-- Chat mute: message body substring + speech markers
L.CHAT_GREEDY_PHRASE = "greedy scavenger"
L.CHAT_SPEECH_MARKERS = { " says", " yells", " whispers" }

----------------------------------------------------------------------
-- ITEM CLASS / SUBTYPE (must match GetItemInfo on this client language)
-- Used by: GPH ResolveIsGear, Destroyer DE/prospect/mill gates, category order
----------------------------------------------------------------------
L.ITEM_CLASS_WEAPON = "Weapon"
L.ITEM_CLASS_ARMOR = "Armor"
L.ITEM_CLASS_CONTAINER = "Container"
L.ITEM_CLASS_CONSUMABLE = "Consumable"
L.ITEM_CLASS_GEM = "Gem"
L.ITEM_CLASS_TRADE_GOODS = "Trade Goods"
L.ITEM_CLASS_RECIPE = "Recipe"
L.ITEM_CLASS_QUEST = "Quest"
L.ITEM_CLASS_MISCELLANEOUS = "Miscellaneous"
L.ITEM_CLASS_OTHER = "Other"
L.ITEM_CLASS_REAGENT = "Reagent" -- GetItemInfo subtype sometimes promoted to Trade Goods

L.ITEM_SUBTYPE_METAL_STONE = "Metal & Stone"
L.ITEM_SUBTYPE_HERB = "Herb"
-- Prospect ore name substring (e.g. "Copper Ore")
L.ITEM_NAME_ORE = "Ore"

-- CATEGORY_ORDER / CATEGORY_ORDER_BAG_PROTECTED are built in Locale.lua
-- from ITEM_CLASS_* so translators only edit the class strings.

----------------------------------------------------------------------
-- TOOLTIP LINES we write (and re-detect to avoid duplicates)
-- Used by: Actions tooltip protection block
----------------------------------------------------------------------
L.TOOLTIP_UNPROTECTED = "Unprotected"
L.TOOLTIP_PROTECTED = "Protected"
L.TOOLTIP_PREVIOUSLY_WORN = "Previously worn gear"
L.TOOLTIP_ALT_LMB_PROTECT = "Alt+LMB: Protect"
L.TOOLTIP_ALT_LMB_UNPROTECT = "Alt+LMB: Unprotect"
L.TOOLTIP_CTRL_RMB_AUTODELETE = "Ctrl+RMB (2x): Autodelete"
-- Markers for "do we already have our lines?" (substring ok)
L.TOOLTIP_MARKER_AUTODELETE = "Autodelete"
L.TOOLTIP_MARKER_ALT_LMB = "Alt+LMB:"
-- Recipe Learn button: tooltip line when pattern is already known (scan lowercase).
L.TOOLTIP_ALREADY_KNOWN = "already known"

----------------------------------------------------------------------
-- PLAYER-FACING MESSAGES (light UI sample pattern)
----------------------------------------------------------------------
L.MSG_SKIPPED_SOULBOUND_MAIL = "Skipped %d soulbound item%s (cannot mail)."
L.MSG_SKIPPED_SOULBOUND_MOVE = "Skipped %d soulbound item%s (cannot move to %s)."
L.MSG_SKIPPED_CANNOT_MAIL = "Skipped %d item%s that cannot be mailed (soulbound or blocked)."
L.MSG_CANNOT_AUTODELETE_PROTECTED = "|cffff3333Cannot autodelete protected item.|r"
L.MSG_NO_MATCHING_UNPROTECTED = "No matching unprotected items found."
L.MSG_NO_MATCHING_SEARCH = "No matching items for search \"%s\"."
L.MSG_NO_UNPROTECTED_CATEGORY = "No unprotected items in category \"%s\"."
L.LABEL_SUMMON_GOBLIN_MERCHANT = "Summon Goblin Merchant"
L.LABEL_SUMMON_GREEDY_SCAVENGER = "Summon Greedy scavenger"
L.LABEL_AUTOSUMMON_GREEDY = "Autosummon Greedy scavenger"

-- Prefix for print lines
L.ADDON_PRINT_PREFIX = "|cffff6666[FugaziBAGS]|r "

A._localeTables.enUS = L
-- enGB clients share US English strings unless a separate table is registered.
A._localeTables.enGB = A._localeTables.enGB or L
