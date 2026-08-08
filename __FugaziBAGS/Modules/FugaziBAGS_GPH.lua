local addonName, Addon = ...; Addon = Addon or _G.FugaziBAGS
local A = Addon
local DB = _G.FugaziBAGSDB

-- GPH SESSION TRACKING (Gold Per Hour / Timer)
local gphSession = nil
local gphBagBaseline = {}
local gphItemsGained = {}
-- lastEquippedItemIds is stored in A.lastEquippedItemIds (from Protection module)

do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_DEAD")
    f:SetScript("OnEvent", function(_, ev)
        if ev == "PLAYER_DEAD" and gphSession then
            gphSession.deaths = (gphSession.deaths or 0) + 1
        end
    end)
end

--- Collapse a count map that may still use old hyperlink keys → itemId -> count.
--- Stack totals SUM (physical); used for baseline/current only.
local function CoalesceCountMapToItemIds(map)
    if type(map) ~= "table" then return end
    local hasString = false
    for k in pairs(map) do
        if type(k) == "string" then hasString = true; break end
    end
    if not hasString then return end
    local out = {}
    for k, v in pairs(map) do
        local id = k
        if type(k) == "string" then
            id = tonumber(k:match("item:(%d+)"))
        end
        id = tonumber(id)
        if id then
            out[id] = (out[id] or 0) + (tonumber(v) or 0)
        end
    end
    wipe(map)
    for id, c in pairs(out) do
        map[id] = c
    end
end

--- Merge session.items that were keyed by unstable full links into itemId keys.
--- Count/remaining take MAX across aliases (re-key inflation); next delta pass repairs.
local function CoalesceSessionItemsToItemIds(session)
    if not session or type(session.items) ~= "table" then return end
    local items = session.items
    local hasString = false
    for k in pairs(items) do
        if type(k) == "string" then hasString = true; break end
    end
    if not hasString then return end

    local out = {}
    for k, data in pairs(items) do
        if type(data) == "table" then
            local id = data.id
                or (type(k) == "string" and tonumber(k:match("item:(%d+)")))
                or tonumber(k)
            id = tonumber(id)
            if id then
                local e = out[id]
                if not e then
                    out[id] = {
                        link = data.link,
                        id = id,
                        quality = data.quality or 0,
                        count = tonumber(data.count) or 0,
                        name = data.name or "Unknown",
                        iLvl = data.iLvl,
                        remaining = tonumber(data.remaining) or 0,
                    }
                else
                    e.count = math.max(e.count or 0, tonumber(data.count) or 0)
                    e.remaining = math.max(e.remaining or 0, tonumber(data.remaining) or 0)
                    if data.link then e.link = data.link end
                    if data.name and data.name ~= "Unknown" then e.name = data.name end
                    if data.quality and (not e.quality or data.quality > e.quality) then
                        e.quality = data.quality
                    end
                    if data.iLvl then e.iLvl = data.iLvl end
                end
            end
        end
    end
    session.items = out
end

--- True when equip id sets differ (order-independent).
local function EquippedSetsDiffer(a, b)
    a, b = a or {}, b or {}
    for id in pairs(a) do
        if not b[id] then return true end
    end
    for id in pairs(b) do
        if not a[id] then return true end
    end
    return false
end

--- Mark live status bar to revalue remaining loot (counts/sold/delete changed).
local function MarkSessionValueDirty()
    A._gphSessionValueDirty = true
end

--- Scan differences in bags for the session (inventory ledger).
--- Keys are always numeric itemId (see ScanBags).
--- currentBags: optional precomputed ScanBags() map (avoids a second full scan from UI refresh).
--- Returns true when remaining session counts changed (loot/sell/destroy).
local function ScanGPHSessionDeltas(session, sessionBaseline, sessionGained, isGPH, currentBags)
    -- Gear path first (cheap when equip unchanged). No full bag scan required.
    local currentEquipped = A.GetEquippedItemIds and A.GetEquippedItemIds() or {}
    local lastEq = A.lastEquippedItemIds or {}
    if EquippedSetsDiffer(currentEquipped, lastEq) then
        if A.UpdateLootIgnoreFromGear then
            A.UpdateLootIgnoreFromGear(currentEquipped, lastEq)
        end
        if A.HandleGearProtection then
            A.HandleGearProtection(currentEquipped, lastEq)
        end
        A.lastEquippedItemIds = A.lastEquippedItemIds or {}
        wipe(A.lastEquippedItemIds)
        for id in pairs(currentEquipped) do
            A.lastEquippedItemIds[id] = true
        end
    end

    if not session then return false end

    local current = currentBags
    if not current then
        current = A.ScanBags and A.ScanBags()
    end
    if not current then return false end

    -- One-shot migrate of pre-fix SV maps (link keys). Skip once clean.
    if not session._keysCoalesced then
        CoalesceCountMapToItemIds(sessionBaseline)
        CoalesceSessionItemsToItemIds(session)
        local gainedHasString = false
        for k in pairs(sessionGained or {}) do
            if type(k) == "string" then gainedHasString = true; break end
        end
        if gainedHasString then
            wipe(sessionGained)
            for id, data in pairs(session.items or {}) do
                local n = tonumber(data and data.remaining) or 0
                if n > 0 then sessionGained[tonumber(id) or id] = n end
            end
        end
        session._keysCoalesced = true
    end

    session.items = session.items or {}
    session.qualityCounts = session.qualityCounts or {}
    local countsChanged = false

    for itemId, count in pairs(current) do
        itemId = tonumber(itemId)
        if itemId then
            local base = sessionBaseline[itemId] or 0
            local delta = count - base
            local link = A.itemLinksCache and A.itemLinksCache[itemId]
            if not link then
                _, link = A.GetCachedItemInfo(itemId)
            end

            -- Gear swap / hearthstone: never session loot (protect setting does not matter)
            local skipLoot = (A.ShouldSkipBagGainAsLoot and A.ShouldSkipBagGainAsLoot(itemId))
                or (itemId == A.HEARTHSTONE_ID)

            if delta > 0 then
                if skipLoot then
                    sessionGained[itemId] = nil
                else
                    local prevSeen = sessionGained[itemId] or 0
                    if delta > prevSeen then
                        local diff = delta - prevSeen
                        sessionGained[itemId] = delta
                        countsChanged = true

                        if link then
                            local name, _, quality, itemLevel = A.GetCachedItemInfo(link)
                            quality = quality or 0
                            session.qualityCounts[quality] = (session.qualityCounts[quality] or 0) + diff
                            if not session.items[itemId] then
                                session.items[itemId] = {
                                    link = link,
                                    id = itemId,
                                    quality = quality,
                                    count = 0,
                                    name = name or "Unknown",
                                    iLvl = itemLevel,
                                }
                            end
                            session.items[itemId].count = (session.items[itemId].count or 0) + diff
                            session.items[itemId].link = link
                            session.items[itemId].id = itemId
                        end
                    end
                end
            end
        end
    end

    for itemId, data in pairs(session.items or {}) do
        local id = tonumber(data.id) or tonumber(itemId)
        local cur = (id and current[id]) or 0
        local base = (id and sessionBaseline[id]) or 0
        local net = math.max(0, cur - base)
        data.id = id
        if (data.remaining or 0) ~= net then
            data.remaining = net
            countsChanged = true
        else
            data.remaining = net
        end
        if id then
            if net == 0 then sessionGained[id] = nil else sessionGained[id] = net end
        end
    end

    -- SV already holds the same table refs from StartGPHSession — no reassign every loot.
    if countsChanged then
        MarkSessionValueDirty()
    end
    return countsChanged
end

local function StartGPHSession()
    gphSession = { 
        startTime = time(), 
        startUptime = GetTime(),
        -- Always a number so GetSessionRawGold never sees nil/string SV leftovers.
        startGold = tonumber(GetMoney and GetMoney()) or 0,
        items = {}, 
        qualityCounts = {}, 
        deaths = 0,
        vendoredItemCount = {},
        autodeletedItemCount = {},
        itemsAutodeleted = 0,
        autodeletedVendorCopper = 0,
    }
    
    local scan = A.ScanBags and A.ScanBags()
    gphBagBaseline = {}
    if scan then
        for id, cnt in pairs(scan) do gphBagBaseline[id] = cnt end
    end
    gphItemsGained = {}

    -- Gear swaps → loot-ignore only (does NOT force sell/delete protect)
    if A.BeginLootIgnoreTracking then A.BeginLootIgnoreTracking() end
    
    local SV = _G.FugaziBAGSDB
    if SV then SV.gphSession, SV.gphBagBaseline, SV.gphItemsGained = gphSession, gphBagBaseline, gphItemsGained end
    _G.gphSession = gphSession
    A._gphCachedSessionItemValue = 0
    A._gphSessionValueDirty = false
    A.AddonPrint("|cff66ccff[GPH]|r session started.")
end


local function StopGPHSession()
    if not gphSession then return end
    
    -- Do one final delta scan
    ScanGPHSessionDeltas(gphSession, gphBagBaseline, gphItemsGained)

    local now = time()
    local nowUptime = GetTime()
    local dur = (gphSession.startUptime and (nowUptime - gphSession.startUptime)) or (now - gphSession.startTime)
    if dur < 0 then dur = 0 end
    -- Inline (helper is defined later in this file; keep stop path self-contained).
    local curMoney = (GetMoney and GetMoney()) or 0
    local startMoney = tonumber(gphSession.startGold) or curMoney
    local gold = curMoney - startMoney
    if gold < 0 then gold = 0 end

    -- Final bag snapshot (itemId keys) so FIT stamp cannot inherit link-key ghosts.
    local curBags = A.ScanBags and A.ScanBags() or {}
    CoalesceCountMapToItemIds(gphBagBaseline)
    CoalesceSessionItemsToItemIds(gphSession)

    local itemList = {}
    local qualityCounts = {}
    local seenIds = {}
    local deletedMap = gphSession.autodeletedItemCount or {}
    local soldMap = gphSession.vendoredItemCount or {}

    local function pushItemRow(baseId, data)
        if not baseId or baseId == A.HEARTHSTONE_ID or seenIds[baseId] then return end
        seenIds[baseId] = true

        local link = (data and data.link) or (A.itemLinksCache and A.itemLinksCache[baseId])
        if not link then
            local name0, l0 = A.GetCachedItemInfo(baseId)
            link = l0
            if data and not data.name and name0 then data.name = name0 end
        end

        -- Prefer bag math: looted ≈ still held (vs baseline) + autosold + autodeleted.
        local baseCnt = (gphBagBaseline and gphBagBaseline[baseId]) or 0
        local curCnt = curBags[baseId] or 0
        local remaining = math.max(0, curCnt - baseCnt)
        local sold = soldMap[baseId] or 0
        local deleted = deletedMap[baseId] or 0
        local total = remaining + sold + deleted
        -- Fully consumed loot only tracked on the cumulative counter (no sink tables).
        if total == 0 and data then
            total = tonumber(data.count) or 0
            remaining = tonumber(data.remaining) or 0
        end
        -- Prefer explicit sink when we know it was deleted (don't reclassify as "kept").
        if deleted > 0 and remaining == 0 and sold == 0 and total < deleted then
            total = deleted
        end

        if total > 0 and link then
            local name = (data and data.name) or (A.GetCachedItemInfo(link)) or "Unknown"
            local quality = (data and data.quality) or (select(3, A.GetCachedItemInfo(link))) or 0
            local itemLevel = (data and data.iLvl) or (select(4, A.GetCachedItemInfo(link))) or 0

            qualityCounts[quality] = (qualityCounts[quality] or 0) + total
            table.insert(itemList, {
                link = link,
                id = baseId,
                itemId = baseId,
                quality = quality,
                count = total,
                name = name,
                iLvl = itemLevel,
                remainingCount = remaining,
                soldCount = sold,
                deletedCount = deleted,
                soldDuringSession = sold > 0 and remaining == 0 and deleted == 0,
                -- Gone from bags and sunk via autodelete → FIT red-wash block at bottom.
                autodeletedDuringSession = deleted > 0 and remaining == 0,
            })
        end
    end

    for itemKey, data in pairs(gphSession.items or {}) do
        if type(data) == "table" then
            local baseId = tonumber(data.id)
                or (type(itemKey) == "string" and tonumber(itemKey:match("item:(%d+)")))
                or tonumber(itemKey)
            pushItemRow(baseId, data)
        end
    end
    -- Orphans: deleted before a session.items row existed (should be rare after RecordAutodelete).
    for baseId, n in pairs(deletedMap) do
        baseId = tonumber(baseId)
        if baseId and (tonumber(n) or 0) > 0 and not seenIds[baseId] then
            pushItemRow(baseId, nil)
        end
    end

    -- Kept first (by quality), autodeleted last (by quality) — red-wash block at bottom.
    table.sort(itemList, function(a, b)
        local aDel = a.autodeletedDuringSession and 1 or 0
        local bDel = b.autodeletedDuringSession and 1 or 0
        if aDel ~= bDel then return aDel < bDel end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return (a.name or "") < (b.name or "")
    end)

    local RecordToIT = _G.FugaziInstanceTracker_RecordGPHRun
    if type(RecordToIT) == "function" then
        -- Value remaining loot only (same model as dungeon FinalizeRun):
        -- sold cash is already inside raw gold; do not re-price sold stacks.
        local vendorValue, ahValue, destroyValue = 0, 0, 0
        for _, itm in ipairs(itemList) do
            local cnt = tonumber(itm.remainingCount) or 0
            if cnt > 0 and itm.link then
                local price, action = 0, "VENDOR"
                if A.GetItemValuationAndAction then
                    local _, _, _, _, _, itemClass = GetItemInfo(itm.link or itm.id or 0)
                    price, action = A.GetItemValuationAndAction(itm.link, itm.id, itm.quality, itm.iLvl, itemClass)
                else
                    price = select(11, A.GetCachedItemInfo(itm.link or itm.id or 0)) or 0
                end
                price = tonumber(price) or 0
                local line = price * cnt
                if action == "AH" then
                    ahValue = ahValue + line
                elseif action == "DE" or action == "PROSPECT" or action == "MILL" then
                    destroyValue = destroyValue + line
                else
                    vendorValue = vendorValue + line
                end
            end
        end

        -- Total estimated = raw gold + remaining item value under valuation matrix.
        -- (Legacy ComputeGPHEstimatedValue forced every non-grey to AH*0.85 and blew past 100g.)
        local estimatedValueCopper = gold + vendorValue + ahValue + destroyValue
        -- FIT stores duration as wall-clock (endTime - startTime); keep GPH on that basis.
        local fitDur = now - (gphSession.startTime or now)
        if fitDur < 0 then fitDur = 0 end
        local estimatedGPHCopper = (fitDur > 0) and math.floor(estimatedValueCopper / (fitDur / 3600)) or 0

        local saved = RecordToIT(
            gphSession.startTime,
            now,
            gphSession.startGold,
            gold,
            itemList,
            qualityCounts,
            estimatedValueCopper,
            estimatedGPHCopper,
            gphSession.repairCount or 0,
            gphSession.repairCopper or 0,
            gphSession.deaths or 0,
            gphSession.itemsAutodeleted or 0,
            gphSession.vendorGold or 0,
            gphSession.autodeletedVendorCopper or 0,
            vendorValue, -- 15
            ahValue,     -- 16
            destroyValue -- 17
        )
        -- One chat line only (FIT no longer prints a second "session recorded" line).
        -- Idle sessions (no loot/gold/repairs/etc.) return false and are not ledgered.
        if saved then
            A.AddonPrint("|cff66ccff[InstanceTracker]|r GPH session stopped. |cff99ff99Saved to Ledger|r")
        else
            A.AddonPrint("|cff66ccff[InstanceTracker]|r GPH session stopped. (Nothing to save)")
        end
    else
        A.AddonPrint("|cff66ccff[InstanceTracker]|r GPH session stopped. (Not saved to Ledger)")
    end

    -- Cleanup
    if A.EndLootIgnoreTracking then A.EndLootIgnoreTracking() end
    gphSession = nil; _G.gphSession = nil
    A._gphCachedSessionItemValue = nil
    A._gphSessionValueDirty = nil
    local SV = _G.FugaziBAGSDB
    if SV then SV.gphSession, SV.gphBagBaseline, SV.gphItemsGained = nil, nil, nil end
    if A.RefreshGPHUI then A.RefreshGPHUI() end
end

local function ResetGPHSession()
    if gphSession and A.EndLootIgnoreTracking then A.EndLootIgnoreTracking() end
    StartGPHSession()
    if A.RefreshGPHUI then A.RefreshGPHUI() end
end

--- Restore an open GPH session after /reload or login.
--- Must run after SavedVariables are available (ADDON_LOADED / PLAYER_LOGIN),
--- not at file load — FugaziBAGSDB is still empty when modules first execute.
local function SyncGPHSessionFromDB()
    local SV = _G.FugaziBAGSDB
    if not SV or type(SV.gphSession) ~= "table" then
        return false
    end
    -- Already live in this session (avoid double-print / re-baseline).
    if gphSession and _G.gphSession == gphSession and gphSession == SV.gphSession then
        return true
    end

    gphSession = SV.gphSession
    gphBagBaseline = SV.gphBagBaseline or {}
    gphItemsGained = SV.gphItemsGained or {}

    -- Pre-fix sessions keyed by full hyperlinks — coalesce to itemId or FIT stamps ghost rows.
    CoalesceCountMapToItemIds(gphBagBaseline)
    CoalesceSessionItemsToItemIds(gphSession)
    -- Rebuild gained from remaining (do not SUM old per-link nets — that re-inflates).
    wipe(gphItemsGained)
    for id, data in pairs(gphSession.items or {}) do
        local n = tonumber(data and data.remaining) or 0
        if n > 0 then
            gphItemsGained[tonumber(id) or id] = n
        end
    end

    -- GetTime() resets on reload; rebuild startUptime from wall-clock startTime
    -- so the timer continues instead of jumping or going negative.
    local wallStart = tonumber(gphSession.startTime)
    if wallStart and wallStart > 0 then
        local wallElapsed = time() - wallStart
        if wallElapsed < 0 then wallElapsed = 0 end
        -- Cap absurd values (clock skew / corrupted SV)
        if wallElapsed > 7 * 24 * 3600 then wallElapsed = 0 end
        gphSession.startUptime = GetTime() - wallElapsed
    else
        gphSession.startTime = time()
        gphSession.startUptime = GetTime()
    end

    -- Keep SV pointing at the same table we use in memory.
    SV.gphSession = gphSession
    SV.gphBagBaseline = gphBagBaseline
    SV.gphItemsGained = gphItemsGained
    _G.gphSession = gphSession
    gphSession._keysCoalesced = true
    A._gphSessionValueDirty = true
    A._gphCachedSessionItemValue = nil

    -- Corrupted / old SV without startGold would freeze raw at weird values — reseed once.
    if tonumber(gphSession.startGold) == nil then
        gphSession.startGold = (GetMoney and GetMoney()) or 0
    end

    if A.BeginLootIgnoreTracking then A.BeginLootIgnoreTracking() end
    A.AddonPrint("|cff66ccff[GPH]|r Session restored after reload.")
    return true
end




--- Snapshot current bag state to clear the baseline.
local function SnapshotBags()
    gphBagBaseline = A.ScanBags()
    gphItemsGained = {}
end


--------------------------------------------------------------------------------
-- Valuation result cache (Phase 4) — engine rules unchanged; generation bump
-- invalidates. Also clears internal DE value cache (one path; no double-index).
--------------------------------------------------------------------------------
local valuationResultCache = {} -- key -> { gen, price, action }
local valuationCacheGen = 0
-- Link → non-tradeable bind (soulbound / realm / account / heirloom). Declared early
-- so InvalidateValuationCache can wipe it without global-leak.
local gphSoulboundCache = {}

A.InvalidateValuationCache = function(reason)
    -- Options matrix can fire many times in one frame at login — one wipe is enough.
    local now = (GetTime and GetTime()) or 0
    if A._valCacheInvTime and (now - A._valCacheInvTime) < 0.05 then
        return
    end
    A._valCacheInvTime = now
    valuationCacheGen = valuationCacheGen + 1
    wipe(valuationResultCache)
    wipe(gphSoulboundCache)
    if A.InvalidateInternalDECache then
        A.InvalidateInternalDECache()
    end
end

-- Single source of truth for bag / list / FIT valuation action badges.
A.VALUATION_ACTION_ICONS = {
    AH       = "Interface\\Icons\\INV_Misc_Coin_02",
    DE       = "Interface\\Icons\\INV_Enchant_Disenchant",
    PROSPECT = "Interface\\Icons\\inv_misc_gem_bloodgem_01",
    MILL     = "Interface\\Icons\\ability_miling",
    VENDOR   = "Interface\\Icons\\inv_misc_coin_18",
}

--- Texture path for a valuation action (AH / DE / PROSPECT / MILL / VENDOR), or nil.
function A.GetValuationActionIcon(action)
    if not action then return nil end
    local map = A.VALUATION_ACTION_ICONS
    return map and map[action] or nil
end

--- Tooltip line (already lowercased) indicates a permanent non-tradeable bind.
--- Phrases live in Locales/enUS.lua (BIND_NONTRADEABLE). Does NOT match plain BoE.
local function IsNonTradeableBindText(t)
    if A.IsNonTradeableBindText then
        return A.IsNonTradeableBindText(t)
    end
    return false
end

--- Bag/slot permanent bind for valuation. Returns isBound, confident.
--- confident=false → empty/failed tooltip; caller must not sticky-cache "not bound".
--- Does NOT treat unbound BoE ("Binds when equipped") as bound.
local function IsBagSlotPermanentlyBound(bag, slot)
    if bag == nil or slot == nil then return false, false end
    local gt = A.GetScanTooltip and A.GetScanTooltip()
    if not gt or not gt.SetBagItem then return false, false end
    local ok = pcall(function()
        gt:Hide()
        gt:SetOwner(UIParent, "ANCHOR_NONE")
        gt:ClearLines()
        gt:SetBagItem(bag, slot)
    end)
    if not ok then return false, false end
    local n = (gt.NumLines and gt:NumLines()) or 0
    if n < 5 then n = 30 end
    local sawText = false
    local lineCount = 0
    for i = 1, n do
        local line = _G["Fugazi_ScanTooltipTextLeft" .. i]
        if line and line.GetText then
            local t = (line:GetText() or ""):lower()
            if t ~= "" then
                sawText = true
                lineCount = lineCount + 1
                if IsNonTradeableBindText(t) then
                    return true, true
                end
            end
        end
    end
    if not sawText or lineCount < 2 then
        return false, false
    end
    return false, true
end

--- Weapon/Armor for valuation rules. Accepts class string/number; falls back to
--- GetItemInfo class and locale-stable equipLoc (INVTYPE_*).
local function ResolveIsGear(itemClass, itemLink, itemID)
    local numericClass = 0
    if type(itemClass) == "string" then
        if A.IsItemClassWeapon and A.IsItemClassWeapon(itemClass) then
            return true, 2
        elseif A.IsItemClassArmor and A.IsItemClassArmor(itemClass) then
            return true, 4
        end
    elseif type(itemClass) == "number" and itemClass > 0 then
        numericClass = itemClass
        if numericClass == 2 or numericClass == 4 then
            return true, numericClass
        end
    end

    local classStr, equipLoc
    if itemLink or itemID then
        local ok, _, _, _, _, _, c, _, _, eq = pcall(GetItemInfo, itemLink or itemID)
        if ok then
            classStr, equipLoc = c, eq
        end
    end
    if A.IsItemClassWeapon and A.IsItemClassWeapon(classStr) then return true, 2 end
    if A.IsItemClassArmor and A.IsItemClassArmor(classStr) then return true, 4 end

    if type(equipLoc) == "string" and equipLoc:find("^INVTYPE_", 1, false) then
        if equipLoc == "INVTYPE_NON_EQUIP" or equipLoc == "INVTYPE_BAG"
            or equipLoc == "INVTYPE_QUIVER" or equipLoc == "INVTYPE_AMMO"
            or equipLoc == "INVTYPE_TABARD" or equipLoc == "INVTYPE_BODY"
            or equipLoc == "INVTYPE_RELIC" then
            return false, 0
        end
        if equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_2HWEAPON"
            or equipLoc == "INVTYPE_WEAPONMAINHAND" or equipLoc == "INVTYPE_WEAPONOFFHAND"
            or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT"
            or equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_HOLDABLE" then
            return true, 2
        end
        -- Armor slots (head/chest/cloak/shield/etc.)
        if equipLoc ~= "" then
            return true, 4
        end
    end
    return false, numericClass
end

--- isSoulboundOpt: when non-nil, use it (bag-slot path already scanned). nil → link path.
--- bindConfident: false means bag scan was incomplete — do not sticky-cache the action.
local function ComputeItemValuationAndAction(itemLink, itemID, quality, iLvl, itemClass, isSoulboundOpt, bindConfident)
    if not itemLink or not itemID then return 0, "VENDOR", false end

    -- Inventory paths pass bag-slot bind (shows "Soulbound" on owned BoP).
    -- GPH/ledger omit it and use the link/hyperlink path.
    local isSoulbound = isSoulboundOpt
    if isSoulbound == nil then
        isSoulbound = A.IsLinkSoulbound and A.IsLinkSoulbound(itemLink) or false
    end

    local name, _, _, _, _, _, _, _, _, _, vendorPrice = A.GetCachedItemInfo(itemLink)
    vendorPrice = vendorPrice or 0
    -- ItemInfo not ready yet — do not cache incomplete results.
    -- Incomplete bag bind scan: also not cacheable (else DE sticks until /reload).
    local cacheable = (name ~= nil) and (bindConfident ~= false)

    -- Heirlooms are never GPH loot value (and often still have phantom AH listings).
    -- Realm/account vanity is handled via isSoulbound → AH forced to 0 below.
    if quality == 7 then
        return 0, "NONE", cacheable
    end

    if quality == 0 then
        if vendorPrice > 0 then
            return vendorPrice, "VENDOR", cacheable
        end
        return 0, "NONE", cacheable
    end

    -- Raw Auctionator/TSM min buyout (per item). No 0.85 cut here — that only
    -- applies to GPH session gold estimates, not action icons / Auto Best.
    local ahPrice = 0
    if not isSoulbound and A.GetAuctionPriceFromAPI then
        ahPrice = A.GetAuctionPriceFromAPI(itemLink) or 0
    end

    local destroyPrice = 0
    local destroyType = "DE"
    local DB = _G.FugaziBAGSDB

    local isGear, numericClass = ResolveIsGear(itemClass, itemLink, itemID)

    if DB then
        if DB.evaluateDisenchant and A.DestroyData and A.DestroyData.Disenchanting then
            if A.GetDisenchantPriceFromAPI then
                local tsmDe = A.GetDisenchantPriceFromAPI(itemLink)
                if tsmDe and tsmDe > 0 then
                    destroyPrice = tsmDe
                end
            end

            if destroyPrice == 0 then
                -- Internal DE tables use classic base (unscaled) iLvl, not Ascension scaled.
                local unscaledForDe = iLvl
                if itemID then
                    local _, _, _, baseILvl = GetItemInfo(itemID)
                    if baseILvl then unscaledForDe = baseILvl end
                end
                destroyPrice = A.GetInternalDisenchantValue(itemLink, itemID, quality, unscaledForDe, numericClass)
            end

            if destroyPrice > 0 then destroyType = "DE" end
        end
        if destroyPrice == 0 and DB.evaluateProspect and A.DestroyData and A.DestroyData.Conversions then
            destroyPrice = A.GetInternalConversionValue(itemID, "prospect")
            if destroyPrice > 0 then destroyType = "PROSPECT" end
        end
        if destroyPrice == 0 and DB.evaluateMilling and A.DestroyData and A.DestroyData.Conversions then
            destroyPrice = A.GetInternalConversionValue(itemID, "mill")
            if destroyPrice > 0 then destroyType = "MILL" end
        end
    end

    local finalPrice = vendorPrice
    local suggestedAction = "VENDOR"

    local valuationMatrix = A.GetOption and A.GetOption("valuationMatrix")
    if valuationMatrix and valuationMatrix[quality] then
        local rules = valuationMatrix[quality]
        -- Force-destroy iLvl rules use BASE item level (GetItemInfo by id), same as DE tables.
        -- Not Ascension scaled iLvl on the link — matches classic Item Level / essence brackets.
        local ilvlCheck = iLvl or 0
        if itemID then
            local _, _, _, baseILvl = GetItemInfo(itemID)
            if baseILvl then ilvlCheck = baseILvl end
        end

        -- Per-rarity AH filters (work WITH Auto Best — if AH fails, Auto Best picks vendor/destroy).
        -- 1) minAuctionCopper — min buyout must be at least this (absolute, per item)
        -- 2) Min profit over vendor: EITHER minAuctionProfitCopper (fixed g/s/c more than vendor)
        --    OR minAuctionProfitPct (% profit over vendor) — never both (UI clears the other).
        -- Prices are per-item unit prices (stack of 20 cloth uses one cloth's prices).
        local function ApplyAhFloors(price)
            if not price or price <= 0 then return 0 end
            local minAh = tonumber(rules.minAuctionCopper) or 0
            local minProfit = tonumber(rules.minAuctionProfitCopper) or 0
            local minPct = tonumber(rules.minAuctionProfitPct) or 0
            -- Legacy account-wide fallback
            if minAh == 0 and DB and type(DB.minAuctionCopper) == "number" then minAh = DB.minAuctionCopper end
            if minProfit == 0 and DB and type(DB.minAuctionProfitCopper) == "number" then minProfit = DB.minAuctionProfitCopper end
            if minPct == 0 and DB and type(DB.minAuctionProfitPct) == "number" then minPct = DB.minAuctionProfitPct end

            if minAh > 0 and price < minAh then return 0 end

            local vp = vendorPrice or 0
            local profit = price - vp
            -- Money mode takes priority if both somehow set; UI keeps them exclusive.
            if minProfit > 0 then
                if profit < minProfit then return 0 end
            elseif minPct > 0 and vp > 0 then
                -- 20% profit means need (AH - vendor) >= 20% of vendor
                if profit < (vp * minPct / 100) then return 0 end
            end
            return price
        end
        ahPrice = ApplyAhFloors(ahPrice)

        -- Never treat Weapon/Armor as AH when excludeGearFromAH is set for this rarity.
        -- Applies in Auto Best, force rules, and fallback (not only Auto Best).
        -- nil defaults: on for Common/Uncommon (matches Config defaults for fresh installs).
        local excludeGear = rules.excludeGearFromAH
        if excludeGear == nil then
            excludeGear = (quality == 1 or quality == 2)
        end
        if isGear and excludeGear then
            ahPrice = 0
        end

        -- Always vendor soulbound Weapon/Armor (not herbs/ores/etc.).
        -- Wins over Auto Best DE and Force destroy — if you can't AH or DE them, vendor.
        -- Bind: bag-slot "Soulbound" when bag/slot passed; else IsLinkSoulbound (link path).
        -- Unbound BoE still uses normal valuation.
        if rules.alwaysVendorSoulboundGear and isGear and isSoulbound then
            if vendorPrice > 0 then
                return vendorPrice, "VENDOR", cacheable
            end
            return 0, "NONE", cacheable
        end

        -- Rule 1: Auto Best Value
        if rules.autoBestValue then
            if ahPrice > vendorPrice and ahPrice > destroyPrice then
                finalPrice = ahPrice
                suggestedAction = "AH"
            elseif destroyPrice > vendorPrice and destroyPrice > ahPrice then
                finalPrice = destroyPrice
                suggestedAction = destroyType
            elseif vendorPrice > 0 then
                finalPrice = vendorPrice
                suggestedAction = "VENDOR"
            else
                finalPrice = 0
                suggestedAction = "NONE"
            end
            return finalPrice, suggestedAction, cacheable
        end

        -- Rule 2: Forced overrides (Only runs if Auto Best Value is OFF)
        local function CheckRule(rMin, rMax, rOp)
            rMin = rMin or 0
            rMax = rMax or 0
            if rMin == 0 and rMax == 0 then return false end
            local activeVal = (rMax > 0) and rMax or rMin
            if rOp == "<" then return ilvlCheck < activeVal
            elseif rOp == ">" then return ilvlCheck > activeVal
            else
                local low = (rMin > 0) and rMin or 0
                local high = (rMax > 0) and rMax or 9999
                return ilvlCheck >= low and ilvlCheck <= high
            end
        end

        local destroyMin = rules.destroyMin or rules.forceDeMinIlvl or 0
        local destroyMax = rules.destroyMax or rules.forceDeMaxIlvl or 0
        local destroyOp = rules.destroyOp or "-"

        local vendorMin = rules.vendorMin or rules.forceVendorMinIlvl or 0
        local vendorMax = rules.vendorMax or rules.forceVendorMaxIlvl or 0
        local vendorOp = rules.vendorOp or "-"

        local ahMin = rules.ahMin or 0
        local ahMax = rules.ahMax or 0
        local ahOp = rules.ahOp or "-"

        if CheckRule(destroyMin, destroyMax, destroyOp) and destroyPrice > 0 then
            return destroyPrice, destroyType, cacheable
        end
        if CheckRule(vendorMin, vendorMax, vendorOp) and vendorPrice > 0 then
            return vendorPrice, "VENDOR", cacheable
        end
        if CheckRule(ahMin, ahMax, ahOp) and ahPrice > 0 then
            return ahPrice, "AH", cacheable
        end
    end

    -- Default fallback if no rules trigger
    if ahPrice > vendorPrice and ahPrice > destroyPrice then
        return ahPrice, "AH", cacheable
    elseif destroyPrice > vendorPrice and destroyPrice > ahPrice then
        return destroyPrice, destroyType, cacheable
    elseif vendorPrice > 0 then
        return vendorPrice, "VENDOR", cacheable
    end

    return 0, "NONE", cacheable
end

--- Optional bag, slot: when present, bind state uses SetBagItem (owned Soulbound).
--- GPH/ledger may omit them and use the link/hyperlink path only.
A.GetItemValuationAndAction = function(itemLink, itemID, quality, iLvl, itemClass, bag, slot)
    if not itemLink or not itemID then return 0, "VENDOR" end

    -- Key by bag:slot when available so bind is scanned only on cache miss (not every paint).
    -- link + quality + iLvl (caller's display/scaled iLvl); force rules resolve base iLvl inside
    local locKey = "L"
    if bag ~= nil and slot ~= nil then
        locKey = "@" .. tostring(bag) .. ":" .. tostring(slot)
    end
    local key = itemLink .. "|" .. tostring(quality or -1) .. "|" .. tostring(iLvl or -1) .. "|" .. locKey
    local hit = valuationResultCache[key]
    if hit and hit.gen == valuationCacheGen then
        return hit.price, hit.action
    end

    local bagBound = nil
    local bindConfident = nil -- nil = link path (own cache rules inside IsLinkSoulbound)
    if bag ~= nil and slot ~= nil then
        local conf
        bagBound, conf = IsBagSlotPermanentlyBound(bag, slot)
        bindConfident = conf
        if not conf then
            -- Incomplete bag tooltip: fall back to link scan for this pass.
            bagBound = A.IsLinkSoulbound and A.IsLinkSoulbound(itemLink) or false
        end
    end

    local price, action, cacheable = ComputeItemValuationAndAction(
        itemLink, itemID, quality, iLvl, itemClass, bagBound, bindConfident
    )
    if cacheable then
        valuationResultCache[key] = { gen = valuationCacheGen, price = price, action = action }
    end
    return price, action
end

local function ComputeGPHTotalValue(session, liveGold)
    local val = liveGold or 0
    local breakdown = { vendor = 0, destroy = 0, ah = 0 }
    if not session or not session.items then return val, breakdown end
    for id, data in pairs(session.items) do
        local cnt = data.remaining or data.count or 0
        if cnt > 0 and id ~= A.HEARTHSTONE_ID then
            local price = 0
            if A.GetItemValuationAndAction then
                local _, _, _, _, _, itemClass = GetItemInfo(data.link or id)
                local action
                price, action = A.GetItemValuationAndAction(data.link, id, data.quality, data.iLvl, itemClass)
                
                local totalItemValue = price * cnt
                if action == "VENDOR" then breakdown.vendor = breakdown.vendor + totalItemValue
                elseif action == "AH" then breakdown.ah = breakdown.ah + totalItemValue
                elseif action == "DE" or action == "PROSPECT" or action == "MILL" then breakdown.destroy = breakdown.destroy + totalItemValue
                end
            elseif GetItemInfo then
                price = select(11, A.GetCachedItemInfo(data.link or id)) or 0
                breakdown.vendor = breakdown.vendor + (price * cnt)
            end
            val = val + (price * cnt)
        end
    end
    return val, breakdown
end


--- Check if AH addon (TSM etc) is loaded for price tooltips.
local function AuctionAddonLoaded()
    return (_G.TSMAPI and _G.TSMAPI.GetItemPrices) or _G.Atr_GetAuctionPrice
end

--- Get AH price for link (TSM/Appraiser style).
local priceCache = {}
local function GetPriceInternal(link, itemId)
    if _G.TSM_API and type(_G.TSM_API.GetCustomPriceValue) == "function" then
        local ok, price = pcall(_G.TSM_API.GetCustomPriceValue, "DBMinBuyout", link)
        if ok and type(price) == "number" and price > 0 then return price end
        ok, price = pcall(_G.TSM_API.GetCustomPriceValue, "DBMarket", link)
        if ok and type(price) == "number" and price > 0 then return price end
        ok, price = pcall(_G.TSM_API.GetCustomPriceValue, "DBHistorical", link)
        if ok and type(price) == "number" and price > 0 then return price end
    elseif _G.TSMAPI and type(_G.TSMAPI.GetItemValue) == "function" then
        local ok, price = pcall(_G.TSMAPI.GetItemValue, _G.TSMAPI, link, "DBMinBuyout")
        if ok and type(price) == "number" and price > 0 then return price end
        ok, price = pcall(_G.TSMAPI.GetItemValue, _G.TSMAPI, link, "DBMarket")
        if ok and type(price) == "number" and price > 0 then return price end
        ok, price = pcall(_G.TSMAPI.GetItemValue, _G.TSMAPI, link, "DBHistorical")
        if ok and type(price) == "number" and price > 0 then return price end
    end
    
    if _G.TSMAPI and type(_G.TSMAPI.GetItemPrices) == "function" then
        local ok, prices = pcall(_G.TSMAPI.GetItemPrices, _G.TSMAPI, link)
        if ok and prices and type(prices) == "table" then
            if type(prices.DBMinBuyout) == "number" and prices.DBMinBuyout > 0 then return prices.DBMinBuyout end
            if type(prices.DBMarket) == "number" and prices.DBMarket > 0 then return prices.DBMarket end
            if type(prices.DBHistorical) == "number" and prices.DBHistorical > 0 then return prices.DBHistorical end
        end
    end
    
    if _G.Atr_GetAuctionPrice then
        local ok, v = pcall(_G.Atr_GetAuctionPrice, link)
        if not ok or not v then
            ok, v = pcall(_G.Atr_GetAuctionPrice, itemId)
        end
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return 0
end

A.GetAuctionPriceFromAPI = function(link)
    if not link then return 0 end
    if priceCache[link] then return priceCache[link] end
    
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId then return 0 end
    
    local exactPrice = GetPriceInternal(link, itemId)
    if exactPrice > 0 then 
        priceCache[link] = exactPrice
        return exactPrice 
    end
    
    local baseLink = "item:" .. itemId .. ":0:0:0:0:0:0"
    local basePrice = GetPriceInternal(baseLink, itemId)
    priceCache[link] = basePrice
    return basePrice
end

local deCache = {}
A.GetDisenchantPriceFromAPI = function(link)
    if not link then return 0 end
    if deCache[link] then return deCache[link] end
    
    local val = 0
    if _G.TSM_API and type(_G.TSM_API.GetCustomPriceValue) == "function" then
        local ok, price = pcall(_G.TSM_API.GetCustomPriceValue, "Destroy", link)
        if ok and type(price) == "number" and price > 0 then val = price end
        if val == 0 then
            ok, price = pcall(_G.TSM_API.GetCustomPriceValue, "Disenchant", link)
            if ok and type(price) == "number" and price > 0 then val = price end
        end
    elseif _G.TSMAPI and type(_G.TSMAPI.GetItemValue) == "function" then
        local ok, price = pcall(_G.TSMAPI.GetItemValue, _G.TSMAPI, link, "Destroy")
        if ok and type(price) == "number" and price > 0 then val = price end
        if val == 0 then
            ok, price = pcall(_G.TSMAPI.GetItemValue, _G.TSMAPI, link, "Disenchant")
            if ok and type(price) == "number" and price > 0 then val = price end
        end
    end
    
    if val == 0 and _G.TSMAPI and type(_G.TSMAPI.GetItemPrices) == "function" then
        local ok, prices = pcall(_G.TSMAPI.GetItemPrices, _G.TSMAPI, link)
        if ok and prices and type(prices) == "table" and type(prices.Disenchant) == "number" then
            val = prices.Disenchant
        end
    end
    
    if val > 0 then deCache[link] = val end
    return val
end

--- Is this item link permanently non-tradeable for valuation (BoP / quest / realm /
--- account / heirloom)? Hyperlinks do not show "currently bound BoE" — those stay false.
--- Never permanently cache "false" on empty/failed tooltip scans (3.3.5 race → DE wins forever).
A.IsLinkSoulbound = function(link)
    if not link then return true end
    if gphSoulboundCache[link] ~= nil then
        return gphSoulboundCache[link]
    end

    local okInfo, name, _, quality, _, _, _, _, _, _, _, _, _, _, bindType = pcall(GetItemInfo, link)
    if not okInfo then
        -- Don't cache failures — item info may arrive a moment later.
        return false
    end
    -- Quality 7 = Heirloom — never AH/vendor farm value for GPH/ledger.
    if quality == 7 then
        gphSoulboundCache[link] = true
        return true
    end

    -- Classic bindType: 1 BoP, 4 Quest. 2 BoE / 3 BoU / 0 None do not prove tradeable on
    -- Ascension — Realm Bank-style items often report 0/2 while the tooltip says Realm Bound.
    -- Note: 3.3.5 GetItemInfo often has no 14th return; bindType stays nil → tooltip path.
    if bindType == 1 or bindType == 4 then
        gphSoulboundCache[link] = true
        return true
    end

    -- Always tooltip-scan permanent bind phrases (cached). Skip BoE-only lines on hyperlinks.
    -- pcall: bad/partial links during AOE loot must never kill the GPH status-bar clock.
    local gt = A.GetScanTooltip and A.GetScanTooltip()
    local sawText = false
    local lineCount = 0
    if gt and gt.SetHyperlink then
        local okScan = pcall(function()
            gt:Hide()
            gt:SetOwner(UIParent, "ANCHOR_NONE")
            gt:ClearLines()
            gt:SetHyperlink(link)
        end)
        if okScan then
            local n = (gt.NumLines and gt:NumLines()) or 0
            if n < 5 then n = 30 end
            for i = 1, n do
                local line = _G["Fugazi_ScanTooltipTextLeft" .. i]
                if line and line.GetText then
                    local t = (line:GetText() or ""):lower()
                    if t ~= "" then
                        sawText = true
                        lineCount = lineCount + 1
                        if IsNonTradeableBindText(t) then
                            gphSoulboundCache[link] = true
                            return true
                        end
                    end
                end
            end
        else
            -- Scan failed — do not cache false.
            return false
        end
    else
        -- No tooltip available yet — do not cache false.
        return false
    end

    -- Incomplete scan (item not in cache / empty tooltip): retry later, never sticky-false.
    if not name or not sawText or lineCount < 2 then
        return false
    end

    gphSoulboundCache[link] = false
    return false
end

--- Is bag slot item currently non-tradeable (bound in-slot, realm/account, or BoE warning)?
--- Do not tooltip:Show() — GetScanTooltip used to Hide on Show and wipe lines.
local function IsBagItemSoulbound(bag, slot)
    local gt = A.GetScanTooltip()
    if not gt or not gt.SetBagItem then return false end
    gt:Hide()
    gt:SetOwner(UIParent, "ANCHOR_NONE")
    gt:ClearLines()
    gt:SetBagItem(bag, slot)
    local n = (gt.NumLines and gt:NumLines()) or 0
    if n < 5 then n = 30 end
    for i = 1, n do
        local line = _G["Fugazi_ScanTooltipTextLeft" .. i]
        if line and line.GetText then
            local t = (line:GetText() or ""):lower()
            if t ~= "" then
                if IsNonTradeableBindText(t)
                    or (A.IsBoEBindText and A.IsBoEBindText(t)) then
                    return true
                end
            end
        end
    end
    return false
end

local function ComputeVendorAuctionTotalsSync()
    local vendorCopper = 0   
    local auctionCopper = 0  
    local itemCounts = {}    
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            if link and not IsBagItemSoulbound(bag, slot) then
                local _, count = GetContainerItemInfo(bag, slot)
                count = count or 1
                local itemId = tonumber(link:match("item:(%d+)"))
                local _, _, quality = A.GetCachedItemInfo(link)
                local isProtected = A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, quality)
                if not isProtected then
                    local _, _, _, _, _, _, _, _, _, _, vendorPrice = A.GetCachedItemInfo(link)
                    vendorCopper = vendorCopper + (vendorPrice or 0) * count
                end
                if itemId then
                    if not itemCounts[itemId] then itemCounts[itemId] = { count = 0, link = link } end
                    itemCounts[itemId].count = itemCounts[itemId].count + count
                end
            end
        end
    end
    for _, entry in pairs(itemCounts) do
        auctionCopper = auctionCopper + (A.GetAuctionPriceFromAPI and A.GetAuctionPriceFromAPI(entry.link) or 0) * entry.count
    end
    return vendorCopper, auctionCopper
end

--- Estimated remaining-loot value via the same valuation matrix as the stamp/live bar.
--- Prefer remainingCount when present so sold stacks are not double-counted with raw gold.
local function ComputeGPHEstimatedValue(itemList)
    if not itemList then return 0 end
    local total = 0
    for _, data in ipairs(itemList) do
        if type(data) == "table" and data.link then
            local count = tonumber(data.remainingCount)
            if count == nil then count = tonumber(data.count) or 0 end
            if count > 0 then
                local price = 0
                if A.GetItemValuationAndAction then
                    local _, _, _, _, _, itemClass = GetItemInfo(data.link)
                    price = A.GetItemValuationAndAction(data.link, data.id, data.quality, data.iLvl, itemClass)
                else
                    price = select(11, A.GetCachedItemInfo(data.link)) or 0
                end
                total = total + (tonumber(price) or 0) * count
            end
        end
    end
    return total
end

--------------------------------------------------------------------------------
-- UI UTILITIES (Moved from Listview.lua for modularization)
--------------------------------------------------------------------------------

--- Wallet copper gained this session (GetMoney - startGold, never negative).
--- Hardened: missing/corrupt startGold reseeds instead of erroring (which used to
--- kill RegisteredUpdaters["StatusUpdate"] via Core pcall and freeze the bar at 0c).
local function GetSessionRawGold(session)
    if not session then return 0 end
    local cur = (GetMoney and GetMoney()) or 0
    local start = tonumber(session.startGold)
    if not start then
        session.startGold = cur
        return 0
    end
    local raw = cur - start
    if raw < 0 then raw = 0 end
    return raw
end

--- total, breakdown — never throws (valuation/tooltip faults fall back to raw only).
local function SafeComputeGPHTotalValue(session, rawGold)
    rawGold = rawGold or 0
    if not session then return rawGold, { vendor = 0, destroy = 0, ah = 0 } end
    local ok, total, breakdown = pcall(ComputeGPHTotalValue, session, rawGold)
    if ok and type(total) == "number" then
        return total, breakdown
    end
    return rawGold, { vendor = 0, destroy = 0, ah = 0 }
end

-- Match LayoutRarityBar right pad (frameW - 36) so the "c" ends with the rarity bar.
local STATUS_RIGHT_PAD = 36

--- Initialize the GPH Status Bar (Total/Time/GPH) on a frame.
function A.CreateGPHStatusBar(f)
    if not f or f.statusText then return end
    
    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetJustifyH("RIGHT")
    f.statusText = statusText
    
    -- Right edge aligns with rarity bar end (not flush to frame -8).
    statusText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -STATUS_RIGHT_PAD, -53)
    statusText:SetWordWrap(false)
    if statusText.SetNonSpaceWrap then statusText:SetNonSpaceWrap(false) end
    
    local font, size, flags = statusText:GetFont()
    f._statusTextBaseFont, f._statusTextBaseSize, f._statusTextBaseFlags = font, size or 12, flags

    local ttFrame = CreateFrame("Frame", nil, f)
    ttFrame:SetAllPoints(statusText)
    ttFrame:EnableMouse(true)
    ttFrame:SetScript("OnEnter", function(self)
        if not _G.gphSession then return end
        if A.AnchorTooltipSmart then A.AnchorTooltipSmart(self, "RIGHT", f) else GameTooltip:SetOwner(self, "ANCHOR_RIGHT") end
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Session Value Breakdown", 1, 0.82, 0)
        
        local rawGold = GetSessionRawGold(_G.gphSession)
        local total, breakdown = SafeComputeGPHTotalValue(_G.gphSession, rawGold)
        
        GameTooltip:AddDoubleLine("Raw Gold:", A.FormatGold(rawGold), 1,1,1, 1,1,1)
        if breakdown then
            if breakdown.vendor > 0 then GameTooltip:AddDoubleLine("Vendor Value:", A.FormatGold(breakdown.vendor), 1,1,1, 1,1,1) end
            if breakdown.destroy > 0 then GameTooltip:AddDoubleLine("Destroy Value:", A.FormatGold(breakdown.destroy), 1,1,1, 1,1,1) end
            if breakdown.ah > 0 then GameTooltip:AddDoubleLine("Auction Value:", A.FormatGold(breakdown.ah), 1,1,1, 1,1,1) end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total:", A.FormatGold(total), 0,1,0, 0,1,0)
        GameTooltip:Show()
    end)
    ttFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.statusTooltipFrame = ttFrame
end

--- Shrinks the GPH status text to fit if it's too long for the allocated space.
function A.SetGphStatusTextFitted(f, text)
    local fs = f.statusText
    if not fs or not text then return end

    -- Keep right edge locked to rarity-bar pad (in case something re-anchored it).
    fs:ClearAllPoints()
    fs:SetPoint("TOPRIGHT", f, "TOPRIGHT", -STATUS_RIGHT_PAD, -53)
    fs:SetText(text)

    -- Gap between Search button and status right edge (not frame outer edge).
    local btn = f.gphSearchBtn
    local frameRight = f:GetRight()
    local btnRight = btn and btn:GetRight()
    if not frameRight or not btnRight then return end
    
    local available = frameRight - STATUS_RIGHT_PAD - btnRight - 8
    if available <= 0 then return end

    local font, size, flags = fs:GetFont()
    local baseFont = f._statusTextBaseFont or font
    local baseSize = f._statusTextBaseSize or size or 12
    local baseFlags = f._statusTextBaseFlags or flags

    fs:SetFont(baseFont, baseSize, baseFlags)
    local currentWidth = fs:GetStringWidth()
    local wantedSize = baseSize
    local minSize = 8

    if currentWidth > available then
        while wantedSize > minSize do
            wantedSize = wantedSize - 1
            fs:SetFont(baseFont, wantedSize, baseFlags)
            if fs:GetStringWidth() <= available then break end
        end
    end
end

--- Main pulse for the GPH status bar. Called from the Master Update loop.
--- Bar shows session TOTAL (raw + kept loot value); raw/vendor/AH/DE stay on mouseover.
--- Item revaluation runs only when session counts change (or money force / first paint).
function A.UpdateGPHStatusBar(f, now)
    if not f or not f.statusText then return end
    
    local session = _G.gphSession
    if not session then
        if f.statusText:IsShown() then f.statusText:Hide() end
        A._gphCachedSessionItemValue = nil
        return
    end
    now = now or (GetTime and GetTime()) or 0
    -- force=true (PLAYER_MONEY) bypasses 1s throttle so copper/silver shows immediately.
    local force = f._gphStatusForce
    f._gphStatusForce = nil
    f._lastGPHUpdate = f._lastGPHUpdate or 0
    if not force and (now - f._lastGPHUpdate) < 1 then return end
    f._lastGPHUpdate = now

    local startUptime = tonumber(session.startUptime) or now
    local dur = now - startUptime
    if dur < 0 then dur = 0 end

    local rawGold = GetSessionRawGold(session)

    -- Revalue remaining loot only when counts changed (or never cached yet).
    if A._gphSessionValueDirty or A._gphCachedSessionItemValue == nil then
        local total = select(1, SafeComputeGPHTotalValue(session, 0))
        -- SafeCompute with rawGold=0 returns item-only total.
        A._gphCachedSessionItemValue = total or 0
        A._gphSessionValueDirty = false
    end
    local totalValue = rawGold + (A._gphCachedSessionItemValue or 0)
    local gph = (dur > 0) and (totalValue / (dur / 3600)) or 0
    
    -- Refresh when timer, total, or GPH changes.
    if force or f._lastDur ~= dur or f._lastTotal ~= totalValue or f._lastGPH ~= gph then
        f._lastDur = dur
        f._lastTotal = totalValue
        f._lastGold = rawGold
        f._lastGPH = gph
        -- Padded s/c and timer seconds so the row does not scoot every tick.
        local totalStr = (A.FormatGoldPadded and A.FormatGoldPadded(totalValue)) or A.FormatGold(totalValue)
        local timerStr = (A.FormatTimeMediumPadded and A.FormatTimeMediumPadded(dur)) or A.FormatTimeMedium(dur)
        local gphStr = (A.FormatGoldPadded and A.FormatGoldPadded(math.floor(gph))) or A.FormatGold(math.floor(gph))
        
        local fullText = "|cffdaa520Total:|r "..totalStr.."   |cffdaa520Timer:|r |cffffffff"..timerStr.."|r   |cffdaa520GPH:|r "..gphStr
        A.SetGphStatusTextFitted(f, fullText)
        f.statusText:Show()
    end
end

-- EXPORTS
--- Flush live GPH tables onto FugaziBAGSDB so /reload / logout keep the session.
local function SyncGPHSessionToDB()
    local SV = _G.FugaziBAGSDB
    if not SV then return end
    if gphSession then
        SV.gphSession = gphSession
        SV.gphBagBaseline = gphBagBaseline or {}
        SV.gphItemsGained = gphItemsGained or {}
        _G.gphSession = gphSession
    end
end

A.StartGPHSession = StartGPHSession
A.StopGPHSession = StopGPHSession
A.ResetGPHSession = ResetGPHSession
_G.ResetGPHSession = ResetGPHSession
A.SyncGPHSessionFromDB = SyncGPHSessionFromDB
A.SyncGPHSessionToDB = SyncGPHSessionToDB
A.ComputeGPHTotalValue = ComputeGPHTotalValue
A.ComputeGPHEstimatedValue = ComputeGPHEstimatedValue
A.ComputeVendorAuctionTotalsSync = ComputeVendorAuctionTotalsSync
A.ScanGPHSessionDeltas = ScanGPHSessionDeltas
A.AuctionAddonLoaded = AuctionAddonLoaded
A.SnapshotBags = SnapshotBags
A.IsBagItemSoulbound = IsBagItemSoulbound
A.IsBagSlotPermanentlyBound = IsBagSlotPermanentlyBound
--- Optional currentBags = ScanBags() result to avoid a second full bag walk.
A.DiffBagsGPH = function(currentBags)
    return ScanGPHSessionDeltas(gphSession, gphBagBaseline, gphItemsGained, true, currentBags)
end
A.MarkSessionValueDirty = MarkSessionValueDirty

-- Do NOT SyncGPHSessionFromDB() here — SavedVariables are not ready until ADDON_LOADED.
-- Core calls A.SyncGPHSessionFromDB on ADDON_LOADED / PLAYER_LOGIN.

-- Register Master Ticker for Status Bar Updates.
-- Never throw out of this callback — Core removes failing RegisteredUpdaters permanently,
-- which froze session gold at 0c during AOE loot valuation faults.
-- Use a *named* tick body with pcall(fn, ...) — do NOT pcall(function() ... end) here.
-- An anonymous function every frame was allocating forever (~0.01MB/s) even with bags closed.
local function StatusUpdateTick(now, elapsed)
    if A.Inventory and A.Inventory:IsShown() then
        A.UpdateGPHStatusBar(A.Inventory, now)
    end
    if A.Bank and A.Bank:IsShown() then
        A.UpdateGPHStatusBar(A.Bank, now)
    end
end

A.RegisteredUpdaters = A.RegisteredUpdaters or {}
A.RegisteredUpdaters["StatusUpdate"] = function(now, elapsed)
    -- Swallow errors so Core does not drop this updater permanently.
    pcall(StatusUpdateTick, now, elapsed)
end

-- Instant total/raw refresh when wallet changes (quest, mob copper, loot pet money).
do
    local moneyFrame = CreateFrame("Frame")
    moneyFrame:RegisterEvent("PLAYER_MONEY")
    moneyFrame:SetScript("OnEvent", function()
        if not _G.gphSession then return end
        local inv = A.Inventory
        if inv and inv:IsShown() and inv.statusText then
            inv._gphStatusForce = true
            A.UpdateGPHStatusBar(inv, GetTime and GetTime())
        end
        local bank = A.Bank
        if bank and bank:IsShown() and bank.statusText then
            bank._gphStatusForce = true
            A.UpdateGPHStatusBar(bank, GetTime and GetTime())
        end
    end)
end
