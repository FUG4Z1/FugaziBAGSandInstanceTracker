local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}
_G.FugaziBAGS = A

--[[
  FugaziBAGS_Config: The Central "Source of Truth" for all user settings.

  Preferences are character-wide (stored under FugaziBAGSDB.gphPerChar[Realm#Name]).
  Top-level FugaziBAGSDB[key] is a live mirror for the current character so existing
  SV.foo reads across the codebase keep working within a session.

  Lifecycle:
    - HydrateCharSettings() on login: load this character's prefs into the top-level mirror
    - SetOption / SnapshotCharSettings: keep gphPerChar and the mirror in sync
    - Direct SV.foo writes still persist via logout Snapshot
]]

local DEFAULTS = {
    -- General
    gphInvKeybind = true,
    -- Master switch for merchant autosell (title menu "Autoselling"). Safe default on:
    -- greys only, unless Filtered Auto-Sell / Autosell EVERYTHING! is enabled separately.
    gphAutoVendor = true,
    gphAutosellEverything = false,
    gphClickSound = true,
    gridConfirmAutoDel = true,
    gphAutosellPingMs = 200,
    gphScrollStep = 100,

    -- Rendering / Layout
    gphFrameScale = 1.0,
    gphFrameAlpha = 0.90,
    gphScale15 = false, -- Legacy toggle for 1.5 multiplier
    gphSortMode = "category", -- "rarity", "vendor", "itemlevel", "category"
    gphSkin = "elvui_real",
    gphCategoryHeaderFontCustom = false,
    gphItemDetailsCustom = false,
    gphItemDetailsIconSize = 27,

    -- Grid/List specific
    gphGridMode = true,
    gridCols = 11,
    gridSlotSize = 37,
    gridSpacing = 3,
    gridBorderSize = 2,
    gridGlowAlpha = 0.55,
    gridProtDesat = 0.35,
    gridProtectedKeyAlpha = 0.20,

    -- Sorting / Protection (structural tables stay account-wide; see ACCOUNT_KEYS)
    gphItemTypeCache = {},
    gphDestroyListPerChar = {}, -- Keyed by "Realm#Name"
    _manualUnprotected = {},

    -- Tweaks
    gphAutoQuestGossip = false,
    gphProtectPreviouslyWorn = true,
    gphAutoConfirmBOP = false,

    gphListViewHeightAuto = true,
    gphListViewHeight = 420,
    gphListViewWidthAuto = true,
    gphListViewWidth = 340,
    gphBankFreeFloat = false,

    -- Skins extras
    gphCategoryHeaderFont = "Fonts\\ARIALN.TTF",
    gphCategoryHeaderFontSize = 11,
    gphItemDetailsFont = "Fonts\\FRIZQT__.TTF",
    gphItemDetailsFontSize = 11,
    gphItemDetailsAlpha = 0.55,
    gphHideIconsInList = false,
    gphHideTopButtons = false,
    gphBankHideTopButtons = false,
    gphSkinOverrides = {},

    -- Valuation Matrix
    enableFilteredAutoSell = false,
    evaluateDisenchant = false,
    evaluateProspect = false,
    evaluateMilling = false,
    showValuationIcons = true,
    alwaysValuateItems = false,
    gphSummonGreedy = true,
    -- Per-rarity AH floors live on valuationMatrix[q] (see below). Global keys kept only as
    -- migration fallback if an older session wrote account-wide floors.
    minAuctionCopper = 0,
    minAuctionProfitCopper = 0,
    minAuctionProfitPct = 0,
    valuationMatrix = {
        -- excludeGearFromAH: never treat Weapon/Armor as AH (defaults on for white/green).
        -- alwaysVendorSoulboundGear: always value soulbound Weapon/Armor as Vendor (not DE/AH).
        -- minAuctionCopper: ignore AH if min buyout < this (per item).
        -- minAuctionProfitCopper OR minAuctionProfitPct (exclusive): min profit over vendor.
        -- AH prices are raw Auctionator/TSM min buyout (no 0.85 cut in Auto Best).
        [1] = { autoBestValue = true, excludeGearFromAH = true, alwaysVendorSoulboundGear = false, minAuctionCopper = 0, minAuctionProfitCopper = 0, minAuctionProfitPct = 0, destroyMin = 0, destroyMax = 0, destroyOp = "-", vendorMin = 0, vendorMax = 0, vendorOp = "-", ahMin = 0, ahMax = 0, ahOp = "-" },
        -- Force destroy off by default for all rarities (user opt-in, not first-run surprise).
        [2] = { autoBestValue = true, excludeGearFromAH = true, alwaysVendorSoulboundGear = false, minAuctionCopper = 0, minAuctionProfitCopper = 0, minAuctionProfitPct = 0, destroyMin = 0, destroyMax = 0, destroyOp = "-", vendorMin = 0, vendorMax = 0, vendorOp = "-", ahMin = 0, ahMax = 0, ahOp = "-" },
        [3] = { autoBestValue = true, excludeGearFromAH = false, alwaysVendorSoulboundGear = false, minAuctionCopper = 0, minAuctionProfitCopper = 0, minAuctionProfitPct = 0, destroyMin = 0, destroyMax = 0, destroyOp = "-", vendorMin = 0, vendorMax = 0, vendorOp = "-", ahMin = 0, ahMax = 0, ahOp = "-" },
        [4] = { autoBestValue = true, excludeGearFromAH = false, alwaysVendorSoulboundGear = false, minAuctionCopper = 0, minAuctionProfitCopper = 0, minAuctionProfitPct = 0, destroyMin = 0, destroyMax = 0, destroyOp = "-", vendorMin = 0, vendorMax = 0, vendorOp = "-", ahMin = 0, ahMax = 0, ahOp = "-" },
    },

    -- First-run help (per character)
    seenInstructions = false,
}

-- Keys that must stay account-wide (shared data / structural tables, not player prefs).
local ACCOUNT_KEYS = {
    gphPerChar = true,
    gphDestroyListPerChar = true,
    gphProtectedItemIdsPerChar = true,
    gphProtectedRarityPerChar = true,
    gphPreviouslyWornOnlyPerChar = true,
    gphWornItemIdsPerChar = true,
    gphPreviouslyWornItemIds = true,
    gphItemTypeCache = true,
    _manualUnprotected = true,
    _manualUnprotectedPerChar = true,
    charClasses = true,
    gphSession = true,
    gphBagBaseline = true,
    gphItemsGained = true,
    -- not a preference key; destroy/protect lists are separate
}

-- Preference keys snapshotted per character (DEFAULTS minus account/structural).
local PREF_KEYS = {
    "gphInvKeybind",
    "gphAutoVendor",
    "gphAutosellEverything",
    "gphClickSound",
    "gridConfirmAutoDel",
    "gphAutosellPingMs",
    "gphScrollStep",
    "gphFrameScale",
    "gphFrameAlpha",
    "gphScale15",
    "gphSortMode",
    "gphSkin",
    "gphCategoryHeaderFontCustom",
    "gphItemDetailsCustom",
    "gphItemDetailsIconSize",
    "gphGridMode",
    "gridCols",
    "gridSlotSize",
    "gridSpacing",
    "gridBorderSize",
    "gridGlowAlpha",
    "gridProtDesat",
    "gridProtectedKeyAlpha",
    "gphAutoQuestGossip",
    "gphProtectPreviouslyWorn",
    "gphAutoConfirmBOP",
    "gphListViewHeightAuto",
    "gphListViewHeight",
    "gphListViewWidthAuto",
    "gphListViewWidth",
    "gphBankFreeFloat",
    "gphCategoryHeaderFont",
    "gphCategoryHeaderFontSize",
    "gphItemDetailsFont",
    "gphItemDetailsFontSize",
    "gphItemDetailsAlpha",
    "gphHideIconsInList",
    "gphHideTopButtons",
    "gphBankHideTopButtons",
    "gphSkinOverrides",
    "enableFilteredAutoSell",
    "evaluateDisenchant",
    "evaluateProspect",
    "evaluateMilling",
    "showValuationIcons",
    "alwaysValuateItems",
    "gphSummonGreedy",
    "minAuctionCopper",
    "minAuctionProfitCopper",
    "minAuctionProfitPct",
    "valuationMatrix",
    "seenInstructions",
    -- Extra per-char toggles used via GetPerChar / title menu
    "gphPauseAutodelete",
    "gphBankGridMode",
}

local PREF_KEY_SET = {}
for _, k in ipairs(PREF_KEYS) do
    PREF_KEY_SET[k] = true
end

-- Registry for option change listeners
local listeners = {}
local hydratedCharKey = nil

local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return out
end

local function IsAccountKey(key)
    return ACCOUNT_KEYS[key] == true
end

local function IsPrefKey(key)
    if not key or IsAccountKey(key) then
        return false
    end
    if PREF_KEY_SET[key] then
        return true
    end
    -- Unknown keys written via SetOption are treated as per-character prefs
    -- (unless they look like structural multi-char tables).
    if type(key) == "string" and key:find("PerChar", 1, true) then
        return false
    end
    return true
end

--- Character-specific key generator (consistent across modules).
function A.GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then
        return nil
    end
    return realm .. "#" .. name
end

local function GetCharStore(charKey)
    local SV = _G.FugaziBAGSDB
    if not SV then
        return nil
    end
    SV.gphPerChar = SV.gphPerChar or {}
    local k = charKey or A.GetCharKey()
    if not k or k == "" then
        return nil
    end
    if not SV.gphPerChar[k] then
        SV.gphPerChar[k] = {}
    end
    return SV.gphPerChar[k], k
end

local function SeedPrefIfMissing(charStore, SV, key)
    if charStore[key] ~= nil then
        return
    end
    -- First-run help must not inherit another character's "already seen" flag
    -- from the top-level mirror (that would skip instructions on alts).
    if key == "seenInstructions" then
        charStore[key] = false
        return
    end
    -- Do NOT seed from the live top-level mirror by default: after Char A logs out,
    -- SV[key] still holds A's values until B hydrates. Copying that into a brand-new
    -- gphPerChar[B] made alts silently inherit valuation/skins (looked account-wide).
    -- Legacy migration only: if NO character profile has this key yet, promote the
    -- old account-wide top-level value into the first profile that needs it.
    local anyCharHasKey = false
    if SV.gphPerChar then
        for _, store in pairs(SV.gphPerChar) do
            if type(store) == "table" and store[key] ~= nil then
                anyCharHasKey = true
                break
            end
        end
    end
    if not anyCharHasKey and SV[key] ~= nil then
        charStore[key] = type(SV[key]) == "table" and DeepCopy(SV[key]) or SV[key]
    elseif DEFAULTS[key] ~= nil then
        charStore[key] = type(DEFAULTS[key]) == "table" and DeepCopy(DEFAULTS[key]) or DEFAULTS[key]
    end
end

--- SavedVariables sometimes reloads quality keys as strings ("1") while UI uses numbers (1).
--- Prefer the row that actually has floors set when both "1" and 1 exist (do not drop edits).
local function NormalizeValuationMatrixKeys(matrix)
    if type(matrix) ~= "table" then
        return matrix
    end
    local function rowScore(row)
        if type(row) ~= "table" then return -1 end
        local n = 0
        for k, v in pairs(row) do
            if k == "minAuctionCopper" or k == "minAuctionProfitCopper" or k == "minAuctionProfitPct" then
                if type(v) == "number" and v > 0 then n = n + 10 end
            elseif v ~= nil then
                n = n + 1
            end
        end
        return n
    end
    local promoted = {}
    for k, v in pairs(matrix) do
        local nk = tonumber(k)
        if nk and type(k) == "string" and type(v) == "table" then
            local existing = matrix[nk]
            if type(existing) ~= "table" then
                promoted[nk] = v
            elseif rowScore(v) > rowScore(existing) then
                -- String-key row from WTF had the real floors; numeric was empty defaults.
                promoted[nk] = v
            end
            matrix[k] = nil
        end
    end
    for nk, v in pairs(promoted) do
        matrix[nk] = v
    end
    return matrix
end

--- Keep gphPerChar[key] pointed at the live top-level table so nested in-place edits
--- (valuationMatrix.minAuctionCopper, gphSkinOverrides colors, etc.) are what Copy sees.
function A.SyncPrefTable(key)
    if not key or not IsPrefKey(key) then
        return
    end
    local SV = _G.FugaziBAGSDB
    if not SV or SV[key] == nil then
        return
    end
    local charStore = GetCharStore()
    if not charStore then
        return
    end
    if type(SV[key]) == "table" then
        if key == "valuationMatrix" then
            NormalizeValuationMatrixKeys(SV[key])
        end
        -- Prefer sharing the live table (no silent divergence).
        charStore[key] = SV[key]
    else
        charStore[key] = SV[key]
    end
end

--- Persist one nested pref table into the character profile immediately (deep copy).
--- Call after valuation floor edits so /reload keeps values even if logout order is weird.
function A.PersistPrefTable(key)
    if not key or not IsPrefKey(key) then
        return
    end
    local SV = _G.FugaziBAGSDB
    if not SV or SV[key] == nil then
        return
    end
    local charStore = GetCharStore()
    if not charStore then
        return
    end
    if type(SV[key]) == "table" then
        if key == "valuationMatrix" then
            NormalizeValuationMatrixKeys(SV[key])
        end
        charStore[key] = DeepCopy(SV[key])
        -- Re-share so further in-place edits keep writing the profile table.
        SV[key] = charStore[key]
    else
        charStore[key] = SV[key]
    end
end

--- Load this character's preferences into the top-level FugaziBAGSDB mirror.
--- Call once per login after the player unit is available.
function A.HydrateCharSettings()
    local SV = _G.FugaziBAGSDB
    if not SV then
        return
    end
    local charStore, charKey = GetCharStore()
    if not charStore or not charKey then
        return
    end

    for _, key in ipairs(PREF_KEYS) do
        SeedPrefIfMissing(charStore, SV, key)
        if key == "valuationMatrix" and type(charStore[key]) == "table" then
            NormalizeValuationMatrixKeys(charStore[key])
        end
        if charStore[key] ~= nil then
            -- Share table references so in-place edits (valuation matrix, skin overrides)
            -- stay on the character profile during the session.
            SV[key] = charStore[key]
        end
    end

    -- Any extra keys already living only under gphPerChar (older SetPerChar usage).
    for key, val in pairs(charStore) do
        if not IsAccountKey(key) and SV[key] == nil then
            SV[key] = val
        end
    end

    hydratedCharKey = charKey
end

--- Persist current top-level prefs into this character's profile (logout / before copy).
function A.SnapshotCharSettings(charKey)
    local SV = _G.FugaziBAGSDB
    if not SV then
        return
    end
    local charStore = GetCharStore(charKey)
    if not charStore then
        return
    end

    local curKey = A.GetCharKey and A.GetCharKey()
    local isCurrent = (not charKey) or (charKey == curKey)

    for _, key in ipairs(PREF_KEYS) do
        if SV[key] ~= nil then
            if type(SV[key]) == "table" then
                if key == "valuationMatrix" then
                    NormalizeValuationMatrixKeys(SV[key])
                end
                -- Always deep-copy nested prefs so profile holds a true snapshot of live
                -- state (min AH floors, force-destroy text, skin color overrides, etc.).
                -- Shared-ref early-out used to leave charStore pointing at a stale table
                -- after EnsureMatrix replaced SV.valuationMatrix.
                charStore[key] = DeepCopy(SV[key])
                if isCurrent then
                    -- Re-share so further in-place edits keep writing the profile table.
                    SV[key] = charStore[key]
                end
            else
                charStore[key] = SV[key]
            end
        end
    end
end

--- Copy preference settings from one character profile to another (not destroy/protect lists).
-- @param sourceKey "Realm#Name"
-- @param destKey optional; defaults to current character
-- @return ok, message
function A.CopyCharSettings(sourceKey, destKey)
    local SV = _G.FugaziBAGSDB
    if not SV or not sourceKey then
        return false, "Nothing to copy."
    end
    SV.gphPerChar = SV.gphPerChar or {}
    local src = SV.gphPerChar[sourceKey]
    if not src or next(src) == nil then
        return false, "That character has no saved settings yet. Log them in once first."
    end

    destKey = destKey or A.GetCharKey()
    if not destKey or destKey == "" then
        return false, "Current character unknown."
    end
    if sourceKey == destKey then
        return false, "That is already this character."
    end

    -- Capture any unsaved top-level edits on the current character first.
    if destKey == A.GetCharKey() then
        A.SnapshotCharSettings(destKey)
    end

    local dst = SV.gphPerChar[destKey] or {}
    SV.gphPerChar[destKey] = dst
    -- Clear previous pref keys so we don't keep stale values the source never set.
    for _, key in ipairs(PREF_KEYS) do
        dst[key] = nil
    end

    local copied = 0
    for _, key in ipairs(PREF_KEYS) do
        if src[key] ~= nil then
            local val = src[key]
            if type(val) == "table" then
                val = DeepCopy(val)
                if key == "valuationMatrix" then
                    NormalizeValuationMatrixKeys(val)
                end
            end
            dst[key] = val
            copied = copied + 1
        end
    end
    -- Also copy any extra non-structural keys present on the source profile.
    for key, val in pairs(src) do
        if dst[key] == nil and not IsAccountKey(key) and key ~= "seenInstructions" then
            dst[key] = type(val) == "table" and DeepCopy(val) or val
            copied = copied + 1
        end
    end

    if copied == 0 then
        return false, "That character has no settings to copy."
    end

    if destKey == A.GetCharKey() then
        hydratedCharKey = nil
        A.HydrateCharSettings()
        if A.InvalidateValuationCache then
            A.InvalidateValuationCache("CopyCharSettings")
        end
    end
    return true, "Settings copied."
end

--- List character keys that have a non-empty preference profile (for copy dropdowns).
function A.GetCharactersWithSettings()
    local SV = _G.FugaziBAGSDB
    local out = {}
    if not SV or not SV.gphPerChar then
        return out
    end
    for key, store in pairs(SV.gphPerChar) do
        if type(store) == "table" and next(store) ~= nil then
            table.insert(out, key)
        end
    end
    table.sort(out)
    return out
end

--- Centralized Getter for all settings.
-- @param key (string) The setting key.
-- @return The current value (or default).
function A.GetOption(key)
    local SV = _G.FugaziBAGSDB
    if not SV then
        return DEFAULTS[key]
    end

    if IsAccountKey(key) then
        local val = SV[key]
        if val == nil then
            return DEFAULTS[key]
        end
        return val
    end

    -- Prefer live top-level mirror (current character after hydrate).
    if SV[key] ~= nil then
        return SV[key]
    end

    local charStore = GetCharStore()
    if charStore and charStore[key] ~= nil then
        return charStore[key]
    end

    return DEFAULTS[key]
end

--- Centralized Setter for all settings.
-- @param key (string) The setting key.
-- @param value (any) The new value.
-- @param silent (boolean) If true, skips triggering listeners.
function A.SetOption(key, value, silent)
    local SV = _G.FugaziBAGSDB
    if not SV then
        return
    end

    local oldVal = SV[key]
    if oldVal == value then
        -- Still ensure char profile is aligned for prefs.
        if IsPrefKey(key) then
            local charStore = GetCharStore()
            if charStore and charStore[key] ~= value then
                charStore[key] = value
            end
        end
        return
    end

    SV[key] = value

    if IsPrefKey(key) then
        local charStore = GetCharStore()
        if charStore then
            charStore[key] = value
        end
    end

    if not silent and listeners[key] then
        for _, callback in ipairs(listeners[key]) do
            local ok, err = pcall(callback, value, oldVal)
            if not ok then
                print("|cffff3333[FugaziBAGS Config Error]|r on listener " .. tostring(key) .. ": " .. tostring(err))
            end
        end
    end
end

--- Register a callback for when a specific option changes.
-- @param key (string) The setting key.
-- @param callback (function) The function to call. Signature: (newValue, oldValue)
function A.OnOptionChanged(key, callback)
    if not key or not callback then
        return
    end
    listeners[key] = listeners[key] or {}
    table.insert(listeners[key], callback)
end

--- Helper to get character-specific destroy list.
function A.GetGphDestroyList()
    local key = A.GetCharKey()
    if not key then
        return {}
    end

    local SV = _G.FugaziBAGSDB
    if not SV then
        return {}
    end

    SV.gphDestroyListPerChar = SV.gphDestroyListPerChar or {}
    SV.gphDestroyListPerChar[key] = SV.gphDestroyListPerChar[key] or {}
    return SV.gphDestroyListPerChar[key]
end

-- Export DEFAULTS for initialization logic if needed
A._ConfigDefaults = DEFAULTS
A._PrefKeys = PREF_KEYS
A.DeepCopy = DeepCopy
