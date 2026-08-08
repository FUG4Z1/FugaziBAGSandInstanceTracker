local addonName, Addon = ...; Addon = Addon or _G.FugaziBAGS
local A = Addon
A.lastEquippedItemIds = A.lastEquippedItemIds or {}

--- Realm#Char key (per-toon save key).
function A.GetGphCharKey()
    if A.GetCharKey then return A.GetCharKey() end
    local r = (GetRealmName and GetRealmName()) or ""
    local c = (UnitName and UnitName("player")) or ""
    return (r or "") .. "#" .. (c or "")
end

function A.IsItemWorn(itemId)
    if not itemId then return false end
    if A.GetPerChar and A.GetPerChar("gphProtectPreviouslyWorn", true) == false then return false end
    local ledger = A.GetGphWornLedger()
    return ledger and ledger[itemId]
end

--- Returns per-char ledger of items that have been worn (IDs).
function A.GetGphWornLedger()
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphWornItemIdsPerChar then SV.gphWornItemIdsPerChar = {} end
    local key = A.GetGphCharKey()
    if not SV.gphWornItemIdsPerChar[key] then
        SV.gphWornItemIdsPerChar[key] = {}
        -- One-time migration from the RULE table to the LEDGER table
        local ruleTable = SV.gphPreviouslyWornOnlyPerChar and SV.gphPreviouslyWornOnlyPerChar[key]
        if type(ruleTable) == "table" then
            for id in pairs(ruleTable) do
                if id > 100 then -- Filter out rarity indices (0-7)
                    SV.gphWornItemIdsPerChar[key][id] = true
                    ruleTable[id] = nil
                end
            end
        end
    end
    return SV.gphWornItemIdsPerChar[key]
end

function A.GetGphProtectedSet()
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphProtectedItemIdsPerChar then SV.gphProtectedItemIdsPerChar = {} end
    local key = A.GetGphCharKey()
    if not SV.gphProtectedItemIdsPerChar[key] then
        SV.gphProtectedItemIdsPerChar[key] = {}
        local legacy = SV.gphPreviouslyWornItemIds
        if type(legacy) == "table" then
            for id in pairs(legacy) do SV.gphProtectedItemIdsPerChar[key][id] = true end
        end
    end
    return SV.gphProtectedItemIdsPerChar[key]
end


--- Per-char "only protect previously worn" item set.
function A.GetGphPreviouslyWornOnlySet()
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphPreviouslyWornOnlyPerChar then SV.gphPreviouslyWornOnlyPerChar = {} end
    local key = A.GetGphCharKey()
    if not SV.gphPreviouslyWornOnlyPerChar[key] then 
        SV.gphPreviouslyWornOnlyPerChar[key] = {} 
    end
    return SV.gphPreviouslyWornOnlyPerChar[key]
end

--- Per-char flags: protect whole quality (e.g. all greens).
function A.GetGphProtectedRarityFlags()
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphProtectedRarityPerChar then SV.gphProtectedRarityPerChar = {} end
    local key = A.GetGphCharKey()
    if not SV.gphProtectedRarityPerChar[key] then 
        SV.gphProtectedRarityPerChar[key] = {} 
    end
    return SV.gphProtectedRarityPerChar[key]
end

--- Soulbound-to-vendor check: item or quality protected?
function A.IsItemProtectedAPI(itemId, qualityArg, ignoreRarity)
    if not itemId then return false end
    itemId = tonumber(itemId)
    if itemId == A.HEARTHSTONE_ID then return true end

    local SV = _G.FugaziBAGSDB or {}
    local key = A.GetGphCharKey()
    
    -- Check the new per-char manual unprotect first
    if SV._manualUnprotectedPerChar and SV._manualUnprotectedPerChar[key] and SV._manualUnprotectedPerChar[key][itemId] then
        return false
    end
    
    -- Backward compatibility for old global manual unprotect (migration check)
    if SV._manualUnprotected and SV._manualUnprotected[itemId] then
        return false
    end

    local set = A.GetGphProtectedSet and A.GetGphProtectedSet()
    if set and set[itemId] == true then return true end

    -- "Previously worn only" check: worn items behave as Protected by default
    if A.GetPerChar and A.GetPerChar("gphProtectPreviouslyWorn", true) ~= false then
        local ledger = A.GetGphWornLedger()
        if ledger and ledger[itemId] then return true end
    end

    if ignoreRarity then return false end

    local flags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
    if not flags then return false end

    local q = qualityArg
    if q == nil and A.GetCachedItemInfo then
        local _, _, qq = A.GetCachedItemInfo(itemId)
        q = qq
    end
    if not q then return false end
    if flags[q] then return true end
    -- Only epic (4): "protect purple" also protects legendary/artifact/heirloom (5,6,7)
    if flags[4] and q >= 4 then return true end

    return false
end

--- Alias for IsItemProtectedAPI used in AutoDelete and Sort.
function A.RarityIsProtected(itemId, quality)
    return A.IsItemProtectedAPI(itemId, quality)
end

--- Protect or unprotect a whole quality (e.g. all greens).
function A.GPH_SetRarityProtection(q, value)
    local flags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
    if not flags then return end
    if flags[q] == value then return end
    flags[q] = value
    if value then
        local SV = _G.FugaziBAGSDB
        if SV then
            if SV._manualUnprotected then SV._manualUnprotected = {} end
            local key = A.GetGphCharKey and A.GetGphCharKey()
            if key and SV._manualUnprotectedPerChar and SV._manualUnprotectedPerChar[key] then
                for itemId, itemVal in pairs(SV._manualUnprotectedPerChar[key]) do
                    local itemIdNum = tonumber(itemId)
                    if itemIdNum then
                        local qVal = itemVal
                        if qVal == true then
                            local _, _, resolvedQ = A.GetCachedItemInfo and A.GetCachedItemInfo(itemIdNum)
                            qVal = resolvedQ
                        end
                        
                        local matches = false
                        if qVal then
                            if q == 4 then
                                matches = (qVal >= 4)
                            else
                                matches = (qVal == q)
                            end
                        end
                        
                        if matches then
                            SV._manualUnprotectedPerChar[key][itemId] = nil
                        end
                    end
                end
            end
        end
    end
    if A.RefreshBagUIs then
        local gf = A.Inventory
        if gf then gf._refreshImmediate = true end
        local bf = A.Bank
        -- Bank uses _bankForceFull (not inv's _refreshImmediate) to skip smart/NOOP.
        if bf then
            bf._bankForceFull = true
            if bf.gphGridMode then bf._bankGridForceFull = true end
        end
        
        local dummyBag = (bf and bf:IsShown()) and -1 or nil
        A.RefreshBagUIs(dummyBag)
    else
        local gf = A.Inventory
        if gf then gf._refreshImmediate = true end
        if _G.RefreshGPHUI then _G.RefreshGPHUI() end
        
        local bf = A.Bank
        if bf and bf:IsShown() then
            bf._bankForceFull = true
            if bf.gphGridMode then bf._bankGridForceFull = true end
            if _G.RefreshBankUI then _G.RefreshBankUI(true) end
        end
    end
end

----------------------------------------------------------------------
-- Loot-ignore (equip/unequip) — NOT sell/delete protection.
-- Used by GPH session + FIT dungeon runs so bag gains from gear swaps
-- never count as loot. Independent of "protect previously worn".
----------------------------------------------------------------------
A._lootIgnoreIds = A._lootIgnoreIds or {}
A._lootIgnoreRef = A._lootIgnoreRef or 0

--- Start tracking (dungeon run and/or GPH session). Refcounted if both active.
function A.BeginLootIgnoreTracking()
    A._lootIgnoreIds = A._lootIgnoreIds or {}
    A._lootIgnoreRef = (A._lootIgnoreRef or 0) + 1
    if A._lootIgnoreRef == 1 then
        wipe(A._lootIgnoreIds)
    end
    local eq = A.GetEquippedItemIds and A.GetEquippedItemIds() or {}
    for id in pairs(eq) do
        local itemId = tonumber(id)
        if itemId then A._lootIgnoreIds[itemId] = true end
    end
    A.lastEquippedItemIds = A.lastEquippedItemIds or {}
    wipe(A.lastEquippedItemIds)
    for id in pairs(eq) do
        local itemId = tonumber(id)
        if itemId then A.lastEquippedItemIds[itemId] = true end
    end
end

function A.EndLootIgnoreTracking()
    A._lootIgnoreRef = math.max(0, (A._lootIgnoreRef or 0) - 1)
    if A._lootIgnoreRef == 0 and A._lootIgnoreIds then
        wipe(A._lootIgnoreIds)
    end
end

--- Call on each gear/bag scan while tracking: mark worn + just-unequipped IDs.
function A.UpdateLootIgnoreFromGear(currentEquipped, lastEquippedItemIds)
    if (A._lootIgnoreRef or 0) <= 0 then return end
    A._lootIgnoreIds = A._lootIgnoreIds or {}
    currentEquipped = currentEquipped or {}
    lastEquippedItemIds = lastEquippedItemIds or {}
    for id in pairs(lastEquippedItemIds) do
        local itemId = tonumber(id)
        if itemId and not currentEquipped[itemId] then
            A._lootIgnoreIds[itemId] = true
        end
    end
    for id in pairs(currentEquipped) do
        local itemId = tonumber(id)
        if itemId then A._lootIgnoreIds[itemId] = true end
    end
end

--- True = bag count up is gear movement (or hearthstone), not loot for GPH/FIT.
function A.ShouldSkipBagGainAsLoot(itemId)
    itemId = tonumber(itemId)
    if not itemId then return false end
    if itemId == A.HEARTHSTONE_ID then return true end
    if (A._lootIgnoreRef or 0) <= 0 then return false end
    return A._lootIgnoreIds and A._lootIgnoreIds[itemId] == true
end

--- Handle gear change for sell/delete protect system (worn ledger). Not loot tracking.
function A.HandleGearProtection(currentEquipped, lastEquippedItemIds)
    local SV = _G.FugaziBAGSDB
    if not SV then return end
    
    local ledger = A.GetGphWornLedger()
    local key = A.GetGphCharKey()
    
    -- Ensure manual unprotect is per-character
    if not SV._manualUnprotectedPerChar then SV._manualUnprotectedPerChar = {} end
    if not SV._manualUnprotectedPerChar[key] then SV._manualUnprotectedPerChar[key] = {} end
    local mu = SV._manualUnprotectedPerChar[key]

    lastEquippedItemIds = lastEquippedItemIds or {}
    currentEquipped = currentEquipped or {}

    -- 1. Items that left equipment: worn ledger (for protect-previously-worn setting)
    for id in pairs(lastEquippedItemIds) do
        local itemId = tonumber(id)
        if itemId and not currentEquipped[itemId] then
            mu[itemId] = nil
            if ledger then ledger[itemId] = true end
        end
    end

    -- 2. Clear manual unprotect for anything currently worn
    for id in pairs(currentEquipped) do
        local itemId = tonumber(id)
        if itemId then mu[itemId] = nil end
    end
end

function A.ToggleItemProtection(itemId, link, clickArea)
    if not Addon or not itemId then return end
    itemId = tonumber(itemId)
    local _, _, q = A.GetCachedItemInfo(link)
    q = q or 0
    local protNow = A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, q) or false

    local SV = _G.FugaziBAGSDB or {}
    local key = A.GetGphCharKey()
    
    if not SV._manualUnprotectedPerChar then SV._manualUnprotectedPerChar = {} end
    if not SV._manualUnprotectedPerChar[key] then SV._manualUnprotectedPerChar[key] = {} end
    local mu = SV._manualUnprotectedPerChar[key]
    
    local set = A.GetGphProtectedSet and A.GetGphProtectedSet() or {}

    set[itemId] = nil
    if SV.gphPreviouslyWornItemIds then SV.gphPreviouslyWornItemIds[itemId] = nil end
    
    -- Clear it from the active worn ledger
    local ledger = A.GetGphWornLedger and A.GetGphWornLedger()
    if ledger then ledger[itemId] = nil end

    if protNow then
        mu[itemId] = q
    else
        mu[itemId] = nil
        set[itemId] = true
    end
    -- Do not pulse here: protect re-sorts list rows immediately after, and this frame is
    -- often rebound to the item that was above. HandleModifierAction pulses by itemId post-refresh.
end

--- Per-char auto-destroy list (item ID -> info); Hearthstone excluded.
function A.GetGphDestroyList()
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphDestroyListPerChar then SV.gphDestroyListPerChar = {} end
    local key = A.GetGphCharKey()
    if not SV.gphDestroyListPerChar[key] then
        SV.gphDestroyListPerChar[key] = {}
        local legacy = SV.gphDestroyList or {}
        for id, v in pairs(legacy) do SV.gphDestroyListPerChar[key][id] = v end
    end
    local list = SV.gphDestroyListPerChar[key]
    list[A.HEARTHSTONE_ID] = nil 
    return list
end

--- Sync current equipment vs last seen (protect anything unequipped).
function A.DiffBags()
    local currentEquipped = A.GetEquippedItemIds and A.GetEquippedItemIds()
    if A.HandleGearProtection and currentEquipped then
        A.HandleGearProtection(currentEquipped, A.lastEquippedItemIds)
    end
    -- Update tracking
    if currentEquipped then
        wipe(A.lastEquippedItemIds or {})
        A.lastEquippedItemIds = A.lastEquippedItemIds or {}
        for id in pairs(currentEquipped) do A.lastEquippedItemIds[id] = true end
    end
end

_G.FugaziInstanceTracker_IsItemProtected = function(id) return A.IsItemProtectedAPI(id) end
