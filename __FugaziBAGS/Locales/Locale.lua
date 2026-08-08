--[[
  FugaziBAGS locale loader + functional match helpers.

  Load order (TOC): enUS.lua → Locale.lua → modules.

  Active table: FugaziBAGS.L
  - Built from enUS base, overlaid by GetLocale() table when present
  - Missing keys fall back to enUS, then to the key string (UI style)

  To add a language: copy Locales/enUS.lua → Locales/esES.lua (etc.),
  change the assignment to A._localeTables.esES = L, translate values,
  add the file to the TOC after enUS.lua. See Locales/README.md.
]]

-- Same namespace rule as enUS.lua: never orphan a second empty global table.
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

local function shallowCopy(src)
    local t = {}
    if type(src) ~= "table" then return t end
    for k, v in pairs(src) do
        t[k] = v
    end
    return t
end

local function buildLocale()
    local tables = A._localeTables
    local base = tables.enUS or {}
    local code = (GetLocale and GetLocale()) or "enUS"
    local over = tables[code]
    -- enGB falls back to enUS table if no distinct enGB override content
    if code == "enGB" and over == base then
        over = nil
    end

    local L
    if over and over ~= base then
        L = shallowCopy(base)
        for k, v in pairs(over) do
            L[k] = v
        end
    else
        L = shallowCopy(base)
    end

    setmetatable(L, {
        __index = function(_, key)
            local v = base[key]
            if v ~= nil then return v end
            if type(key) == "string" then return key end
            return nil
        end,
    })

    -- Keep category order in sync with localized class strings (one place to translate).
    if type(L.CATEGORY_ORDER) ~= "table" or not L.CATEGORY_ORDER._localeBuilt then
        L.CATEGORY_ORDER = {
            "HIDDEN_FIRST",
            L.ITEM_CLASS_WEAPON or "Weapon",
            L.ITEM_CLASS_ARMOR or "Armor",
            L.ITEM_CLASS_CONTAINER or "Container",
            L.ITEM_CLASS_CONSUMABLE or "Consumable",
            L.ITEM_CLASS_GEM or "Gem",
            L.ITEM_CLASS_TRADE_GOODS or "Trade Goods",
            L.ITEM_CLASS_RECIPE or "Recipe",
            L.ITEM_CLASS_QUEST or "Quest",
            L.ITEM_CLASS_MISCELLANEOUS or "Miscellaneous",
            L.ITEM_CLASS_OTHER or "Other",
        }
        L.CATEGORY_ORDER._localeBuilt = true
    end
    if type(L.CATEGORY_ORDER_BAG_PROTECTED) ~= "table" or not L.CATEGORY_ORDER_BAG_PROTECTED._localeBuilt then
        L.CATEGORY_ORDER_BAG_PROTECTED = {
            "BAG_PROTECTED",
            "HIDDEN_FIRST",
            L.ITEM_CLASS_WEAPON or "Weapon",
            L.ITEM_CLASS_ARMOR or "Armor",
            L.ITEM_CLASS_CONTAINER or "Container",
            L.ITEM_CLASS_CONSUMABLE or "Consumable",
            L.ITEM_CLASS_GEM or "Gem",
            L.ITEM_CLASS_TRADE_GOODS or "Trade Goods",
            L.ITEM_CLASS_RECIPE or "Recipe",
            L.ITEM_CLASS_QUEST or "Quest",
            L.ITEM_CLASS_MISCELLANEOUS or "Miscellaneous",
            L.ITEM_CLASS_OTHER or "Other",
        }
        L.CATEGORY_ORDER_BAG_PROTECTED._localeBuilt = true
    end

    A.L = L
    A.localeCode = code
    return L
end

buildLocale()

----------------------------------------------------------------------
-- Match helpers (used by GPH, Bankview, AutoSell, Destroyer, Actions)
----------------------------------------------------------------------

--- True if `text` contains any phrase in `phrases` (plain find).
--- @param text string|nil
--- @param phrases table|nil list of substrings
--- @param alreadyLower boolean|nil if true, do not lower text again
function A.LocaleTextMatches(text, phrases, alreadyLower)
    if not text or text == "" or type(phrases) ~= "table" then return false end
    local t = alreadyLower and text or string.lower(text)
    for i = 1, #phrases do
        local p = phrases[i]
        if type(p) == "string" and p ~= "" and t:find(p, 1, true) then
            return true
        end
    end
    return false
end

--- True if lowercased name contains every token in the list.
function A.LocaleNameHasAllTokens(name, tokens)
    if not name or type(name) ~= "string" or type(tokens) ~= "table" then return false end
    local l = name:lower()
    for i = 1, #tokens do
        local tok = tokens[i]
        if type(tok) ~= "string" or tok == "" or not l:find(tok, 1, true) then
            return false
        end
    end
    return #tokens > 0
end

--- Tooltip line (already lowercased) = permanent non-tradeable bind.
--- Does NOT match plain BoE ("binds when equipped").
function A.IsNonTradeableBindText(t)
    if not t or t == "" then return false end
    local L = A.L
    return A.LocaleTextMatches(t, L and L.BIND_NONTRADEABLE, true)
end

--- Tooltip line (already lowercased) = BoE bind warning only.
function A.IsBoEBindText(t)
    if not t or t == "" then return false end
    local L = A.L
    return A.LocaleTextMatches(t, L and L.BIND_BOE, true)
end

--- Classify Ascension bank title text → "personal" | "realm" | nil
function A.ClassifyBankTitleText(text)
    if not text or text == "" then return nil end
    local L = A.L
    local t = text:lower()
    if A.LocaleTextMatches(t, L and L.BANK_TITLE_PERSONAL, true) then
        return "personal"
    end
    if A.LocaleTextMatches(t, L and L.BANK_TITLE_REALM, true) then
        return "realm"
    end
    return nil
end

--- Human label for open guild-style bank kind.
function A.GetBankKindLabel(kind)
    local L = A.L
    if kind == "personal" then return (L and L.LABEL_PERSONAL_BANK) or "Personal Bank" end
    if kind == "realm" then return (L and L.LABEL_REALM_BANK) or "Realm Bank" end
    if kind == "guild" then return (L and L.LABEL_GUILD_BANK) or "Guild Bank" end
    return (L and L.LABEL_GUILD_BANK) or "Guild Bank"
end

--- Item class string is Weapon (locale-aware).
function A.IsItemClassWeapon(classStr)
    local L = A.L
    return classStr ~= nil and classStr == ((L and L.ITEM_CLASS_WEAPON) or "Weapon")
end

--- Item class string is Armor (locale-aware).
function A.IsItemClassArmor(classStr)
    local L = A.L
    return classStr ~= nil and classStr == ((L and L.ITEM_CLASS_ARMOR) or "Armor")
end

--- Category sort order tables (locale-aware).
function A.GetCategoryOrder()
    local L = A.L
    return (L and L.CATEGORY_ORDER) or {
        "HIDDEN_FIRST", "Weapon", "Armor", "Container", "Consumable", "Gem",
        "Trade Goods", "Recipe", "Quest", "Miscellaneous", "Other",
    }
end

function A.GetBagProtectedCategoryOrder()
    local L = A.L
    return (L and L.CATEGORY_ORDER_BAG_PROTECTED) or {
        "BAG_PROTECTED", "HIDDEN_FIRST", "Weapon", "Armor", "Container", "Consumable", "Gem",
        "Trade Goods", "Recipe", "Quest", "Miscellaneous", "Other",
    }
end
