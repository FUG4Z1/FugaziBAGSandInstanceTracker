local addonName, L = ...

----------------------------------------------------------------------
-- Formatting: thin L.* → __FugaziBAGS only (no dual implementations).
-- FIT is RequiredDeps BAGS, so these should always hit BAGS in production.
----------------------------------------------------------------------
--- Countdown timer: "5m 30s" or "Ready" when zero (like the hourly cap next-slot display).
function L.FormatTime(...)
    local FB = _G.FugaziBAGS
    if FB and FB.FormatTime then return FB.FormatTime(...) end
    return ""
end

--- Short duration: "5m 30s" (used in Ledger and run tooltips).
function L.FormatTimeMedium(...)
    local FB = _G.FugaziBAGS
    if FB and FB.FormatTimeMedium then return FB.FormatTimeMedium(...) end
    return ""
end

--- Turns copper into colored "Xg Xs Xc" (gold/silver/copper) for display.
function L.FormatGold(...)
    local FB = _G.FugaziBAGS
    if FB and FB.FormatGold then return FB.FormatGold(...) end
    return ""
end

--- Short gold for tight UI; falls back to FormatGold when BAGS has no short form.
function L.FormatGoldShort(...)
    local FB = _G.FugaziBAGS
    if FB and FB.FormatGoldShort then return FB.FormatGoldShort(...) end
    if FB and FB.FormatGold then return FB.FormatGold(...) end
    return ""
end

--- Copper to plain "Xg Xs Xc" (no color).
function L.FormatGoldPlain(...)
    local FB = _G.FugaziBAGS
    if FB and FB.FormatGoldPlain then return FB.FormatGoldPlain(...) end
    return ""
end

--- Timestamp to "DD.M.YY - HH:MM" (BAGS owns when present; tiny local fallback for chat stamps).
function L.FormatDateTime(timestamp)
    local FB = _G.FugaziBAGS
    if FB and FB.FormatDateTime then return FB.FormatDateTime(timestamp) end
    if not timestamp then return "" end
    local dt = date("*t", timestamp)
    if not dt then return "" end
    return string.format("%d.%d.%d - %02d:%02d", dt.day, dt.month, dt.year % 100, dt.hour, dt.min)
end

--- Wrap text in color (r,g,b 0-1).
function L.ColorText(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

-- Anchor tooltip just to the RIGHT of the whole window that owns this control,
-- with a small horizontal gap, so it never overlaps the scrollbar or content.
local TOOLTIP_FRAME_GAP = 5
function L.AnchorTooltipRight(ownerFrame)
    if not ownerFrame then return end

    -- Walk up parents until we find the movable top-level window (stats, GPH, main, etc.)
    local host = ownerFrame
    while host and host:GetParent() and host ~= UIParent and (not host.IsMovable or not host:IsMovable()) do
        host = host:GetParent()
    end

    if not host or host == UIParent then
        -- Fallback: normal right-anchored tooltip on the control itself
        GameTooltip:SetOwner(ownerFrame, "ANCHOR_RIGHT")
        return
    end

    GameTooltip:SetOwner(ownerFrame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint("LEFT", host, "RIGHT", TOOLTIP_FRAME_GAP, 0)
end

--- Format quality counts for Ledger: numbers only in rarity color (no labels) to save space.
--- Accepts numeric or string keys; if qc empty but items present, rebuilds from run.items.
function L.FormatQualityCounts(qc, items)
    local counts = {}
    if type(qc) == "table" then
        for k, v in pairs(qc) do
            local q = tonumber(k)
            local n = tonumber(v) or 0
            if q and n > 0 then
                counts[q] = (counts[q] or 0) + n
            end
        end
    end
    -- Fallback: some runs have items but empty/missing qualityCounts (GPH or older stamps).
    local empty = true
    for _, n in pairs(counts) do
        if n and n > 0 then empty = false; break end
    end
    if empty and type(items) == "table" then
        for _, it in pairs(items) do
            if type(it) == "table" then
                local q = tonumber(it.quality) or 0
                local n = tonumber(it.count) or 0
                if n > 0 then
                    counts[q] = (counts[q] or 0) + n
                end
            end
        end
    end
    local parts = {}
    for q = 0, 7 do
        local count = counts[q]
        if count and count > 0 then
            local info = L.QUALITY_COLORS and L.QUALITY_COLORS[q]
            if info and info.hex then
                table.insert(parts, "|cff" .. info.hex .. count .. "|r")
            else
                table.insert(parts, tostring(count))
            end
        end
    end
    if #parts == 0 then return "|cff555555-|r" end
    return table.concat(parts, "  ")
end

--- True on Project Ascension (or same family). Prefer BAGS.IsAscension when present.
function L.IsAscensionRealm()
    local FB = _G.FugaziBAGS
    if FB and type(FB.IsAscension) == "function" then
        return FB.IsAscension() and true or false
    end
    if _G.AscensionUI ~= nil or _G.AscensionCharacterFrame ~= nil then
        return true
    end
    local realm = (GetRealmName and GetRealmName()) or ""
    local r = string.lower(realm)
    r = string.gsub(r, "[%s%p]", "")
    if r:find("bronzebeard") or r:find("area52") or r:find("elune")
        or r:find("rexxar") or r:find("voljin") or r:find("dawnrise") or r:find("darkmoon") then
        return true
    end
    return false
end

--- Main /fit window: classic = hourly cap + lockouts; Ascension = lockouts.
function L.IsMainTrackerUIEnabled()
    return true
end

--- Check if hourly cap applies on this realm (Ascension / modern private servers don't use it)
function L.IsHourlyCapEnabled()
    if L.IsAscensionRealm and L.IsAscensionRealm() then return false end
    local realm = GetRealmName()
    if not realm then return true end
    local r = string.lower(realm)
    r = string.gsub(r, "[%s%p]", "")
    if r:find("rexxar") or r:find("voljin") or r:find("dawnrise") or r:find("darkmoon") or r:find("bronzebeard") or r:find("area52") then
        return false
    end
    return true
end

--- Drops instance entries older than 1 hour from the "recent instances" list (so the X/5 count is accurate).
function L.PurgeOld()
    local now = time()
    local fresh = {}
    for _, entry in ipairs(InstanceTrackerDB.recentInstances or {}) do
        if (entry.time + L.HOUR_SECONDS) > now then fresh[#fresh + 1] = entry end
    end
    InstanceTrackerDB.recentInstances = fresh
end

--- Return current instance count this hour (after purging old entries).
function L.GetInstanceCount()
    L.PurgeOld()
    return #(InstanceTrackerDB.recentInstances or {})
end

--- Remove a single entry from recentInstances by index.
function L.RemoveInstance(index)
    local recent = InstanceTrackerDB.recentInstances or {}
    if index >= 1 and index <= #recent then
        table.remove(recent, index)
        L.AddonPrint(
            L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1) .. "Removed entry #" .. index .. "."
        )
    end
end

--- Record entering an instance (name) and print count this hour.
function L.RecordInstance(name)
    if not InstanceTrackerDB.recentInstances then InstanceTrackerDB.recentInstances = {} end
    L.PurgeOld()
    local now = time()
    for _, entry in ipairs(InstanceTrackerDB.recentInstances) do
        if entry.name == name and (now - entry.time) < 60 then return end
    end
    table.insert(InstanceTrackerDB.recentInstances, { name = name, time = time() })
    
    local countStr = ""
    if L.IsHourlyCapEnabled() then
        countStr = " (" .. L.ColorText(L.GetInstanceCount() .. "/" .. L.MAX_INSTANCES_PER_HOUR, 1, 0.6, 0.2) .. " this hour)"
    end
    
    L.AddonPrint(
        L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
        .. "Entered: " .. L.ColorText(name, 1, 1, 0.6)
        .. countStr
    )
end

--- Bag scanning: returns { [itemId] = count } and fills L.itemLinksCache.
function L.ScanBags()
    local counts = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = GetContainerItemLink(bag, slot)
            if itemLink then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                local itemId = tonumber(itemLink:match("item:(%d+)"))
                if itemId then
                    counts[itemId] = (counts[itemId] or 0) + (itemCount or 1)
                    L.itemLinksCache[itemId] = itemLink
                end
            end
        end
    end
    return counts
end

--- Takes a snapshot of your bags when you enter a dungeon; we compare later to see what you looted this run.
function L.SnapshotBags()
    L.bagBaseline = L.ScanBags()
    L.itemsGained = {}
end

--- Build set of item IDs currently equipped (slots 1–19). Used to ignore unequip-as-loot.
function L.GetEquippedItemIds()
    local ids = {}
    for slot = 1, 19 do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then ids[id] = true end
        end
    end
    return ids
end

--- Compares current bags to the snapshot we took when you entered; adds any increase to "items gained this run".
--- Loot vs gear-swap: BAGS ShouldSkipBagGainAsLoot only (not sell/delete protect).
function L.DiffBags()
    local current = L.ScanBags()
    local A = _G.FugaziBAGS
    local currentEquipped = (A and A.GetEquippedItemIds and A.GetEquippedItemIds()) or L.GetEquippedItemIds()
    local lastEq = (A and A.lastEquippedItemIds) or L.lastEquippedItemIds or {}

    if A then
        if type(A.UpdateLootIgnoreFromGear) == "function" then
            A.UpdateLootIgnoreFromGear(currentEquipped, lastEq)
        end
        if type(A.HandleGearProtection) == "function" then
            A.HandleGearProtection(currentEquipped, lastEq)
        end
        A.lastEquippedItemIds = A.lastEquippedItemIds or {}
        wipe(A.lastEquippedItemIds)
        for id in pairs(currentEquipped or {}) do A.lastEquippedItemIds[id] = true end
    end
    L.lastEquippedItemIds = currentEquipped

    if not L.currentRun then return end
    local lootChanged = false
    for itemId, curCount in pairs(current) do
        local baseCount = L.bagBaseline[itemId] or 0
        local delta = curCount - baseCount
        local skipLoot = (A and type(A.ShouldSkipBagGainAsLoot) == "function" and A.ShouldSkipBagGainAsLoot(itemId))
            or itemId == 6948
        if delta > 0 and skipLoot then
            -- Gear swap / hearthstone: absorb into L.itemsGained only, never run loot
            L.itemsGained[itemId] = delta
        elseif delta > 0 then
            local prev = L.itemsGained[itemId] or 0
            if delta > prev then
                local diff = delta - prev
                L.itemsGained[itemId] = delta

                local link = L.itemLinksCache[itemId]
                if link then
                    local name, _, quality = GetItemInfo(link)
                    quality = quality or 0
                    name = name or "Unknown"

                    L.currentRun.qualityCounts[quality] = (L.currentRun.qualityCounts[quality] or 0) + diff
                    -- Track all qualities including greys (quality 0) so the item list shows full loot.
                    if not L.currentRun.items[itemId] then
                        L.currentRun.items[itemId] = {
                            link = link, quality = quality, count = 0, name = name
                        }
                    end
                    L.currentRun.items[itemId].count = L.currentRun.items[itemId].count + diff
                    L.currentRun.items[itemId].link = link
                    lootChanged = true
                end
            end
        end
    end
    if L.currentRun then
        InstanceTrackerDB.currentRun = L.currentRun
        InstanceTrackerDB.bagBaseline = L.bagBaseline
        InstanceTrackerDB.itemsGained = L.itemsGained
        if lootChanged then
            -- Open live item list: rebuild only when loot changed (no 1s poll).
            if type(L.RefreshItemDetailLive) == "function" then
                L.RefreshItemDetailLive()
            end
            -- Dungeons tab "Items gained" line when Ledger is open.
            local statsF = _G.InstanceTrackerStatsFrame or L.statsFrame
            if statsF and statsF:IsShown() and statsF.selectedTab == 3 and type(L.RefreshStatsUI) == "function" then
                L.RefreshStatsUI(true)
            end
        end
    end
end

-- GPH sessions + valuation live in __FugaziBAGS. FIT only persists finished
-- sessions (RecordGPHRun) and stamps run items via BAGS GetItemValuationAndAction.

--- API for __FugaziBAGS: record a finished GPH session into the InstanceTracker ledger.
--- Safe no-op when FIT DB missing. BAGS alone never needs this (only called if FIT loaded).
--- Signature (stable):
---   startTime, endTime, startGold, goldEarned, itemList, qualityCounts
---   [, estimatedValueCopper, estimatedGPHCopper, repairCount, repairCopper, deaths,
---      itemsAutodeleted, vendorGoldCopper, autodeletedVendorCopper, vendorValue, ahValue, destroyValue]
_G.FugaziInstanceTracker_RecordGPHRun = function(startTime, endTime, startGold, goldEarned, itemList, qualityCounts, estimatedValueCopper, estimatedGPHCopper, repairCount, repairCopper, deaths, itemsAutodeleted, vendorGoldCopper, autodeletedVendorCopper, vendorValue, ahValue, destroyValue)
    if not startTime or not endTime then return false end
    if type(startTime) ~= "number" or type(endTime) ~= "number" then return false end
    if not InstanceTrackerDB then return false end
    if endTime < startTime then return false end

    local dur = endTime - startTime
    goldEarned = tonumber(goldEarned) or 0
    if type(itemList) ~= "table" then itemList = {} end
    if type(qualityCounts) ~= "table" then qualityCounts = {} end
    repairCount = tonumber(repairCount) or 0
    repairCopper = tonumber(repairCopper) or 0
    deaths = tonumber(deaths) or 0
    itemsAutodeleted = tonumber(itemsAutodeleted) or 0
    vendorGoldCopper = tonumber(vendorGoldCopper) or 0
    vendorValue = tonumber(vendorValue) or 0
    ahValue = tonumber(ahValue) or 0
    destroyValue = tonumber(destroyValue) or 0

    -- Skip idle sessions (timer only, no loot/gold/repairs/etc.). Chat is owned by BAGS StopGPHSession.
    local hasItems = #itemList > 0
    if not hasItems then
        for _, c in pairs(qualityCounts) do
            if (tonumber(c) or 0) > 0 then
                hasItems = true
                break
            end
        end
    end
    local hasActivity = (goldEarned ~= 0)
        or hasItems
        or (repairCount > 0)
        or (repairCopper ~= 0)
        or (deaths > 0)
        or (itemsAutodeleted > 0)
        or (vendorGoldCopper ~= 0)
        or (vendorValue ~= 0)
        or (ahValue ~= 0)
        or (destroyValue ~= 0)
    if not hasActivity then
        return false
    end

    local stamp = (L.FormatDateTime and L.FormatDateTime(startTime)) or ""
    local run = {
        name = "GPH" .. (stamp ~= "" and (" - " .. stamp) or ""),
        enterTime = startTime,
        exitTime = endTime,
        duration = dur,
        goldCopper = goldEarned,
        qualityCounts = qualityCounts,
        items = itemList,
        estimatedValueCopper = tonumber(estimatedValueCopper) or estimatedValueCopper,
        estimatedGPHCopper = tonumber(estimatedGPHCopper) or estimatedGPHCopper,
        repairCount = repairCount,
        repairCopper = repairCopper,
        deaths = deaths,
        itemsAutodeleted = itemsAutodeleted,
        vendorGold = vendorGoldCopper,
        autodeletedVendorCopper = tonumber(autodeletedVendorCopper) or 0,
        vendorValue = vendorValue,
        ahValue = ahValue,
        destroyValue = destroyValue,
        characterName = (UnitName and UnitName("player")) or nil,
        realmName = (GetRealmName and GetRealmName()) or nil,
    }
    if not InstanceTrackerDB.runHistory then InstanceTrackerDB.runHistory = {} end
    table.insert(InstanceTrackerDB.runHistory, 1, run)
    if L.TrimRunHistory then L.TrimRunHistory() end
    -- No chat here — BAGS prints a single "GPH session stopped. Saved to Ledger" line.

    -- Lifetime analytics (realm-scoped via L.LS after InitializeLifetimeStats)
    if L.LS then
        L.LS.totalGoldCopper = (L.LS.totalGoldCopper or 0) + goldEarned
        L.LS.totalRuns = (L.LS.totalRuns or 0) + 1

        L.LS.rarityBreakdown = L.LS.rarityBreakdown or {}
        for q, count in pairs(qualityCounts) do
            L.LS.rarityBreakdown[q] = (L.LS.rarityBreakdown[q] or 0) + (tonumber(count) or 0)
        end

        local gph = tonumber(estimatedGPHCopper) or (dur > 60 and (goldEarned / (dur / 3600))) or 0
        if gph > (L.LS.bestGPH or 0) then
            L.LS.bestGPH = gph
        end

        if dur > 30 then
            local zoneName = (GetRealZoneText and GetRealZoneText()) or "Unknown"
            if zoneName and zoneName ~= "" then
                L.LS.zoneEfficiency = L.LS.zoneEfficiency or {}
                local ze = L.LS.zoneEfficiency[zoneName]
                if not ze then
                    ze = { totalGold = 0, totalDuration = 0, runCount = 0 }
                    L.LS.zoneEfficiency[zoneName] = ze
                end
                ze.totalGold = ze.totalGold + (goldEarned / 10000)
                ze.totalDuration = ze.totalDuration + dur
                ze.runCount = ze.runCount + 1
            end
        end
    end

    if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
        L.RefreshStatsUI()
    end
    return true
end

----------------------------------------------------------------------
----------------------------------------------------------------------
-- LIVE UPDATE ENGINE
----------------------------------------------------------------------
local elapsed_acc = 0
function L.OnUpdate(self, elapsed)
    elapsed_acc = elapsed_acc + elapsed
    if elapsed_acc >= 1 then
        elapsed_acc = 0
        -- Hourly cap numbers only. Do not rebuild lockouts or RequestRaidInfo here.
        if type(L.TickHourlyCapText) == "function" then
            L.TickHourlyCapText()
        end
    end
end

----------------------------------------------------------------------
-- Stats: run tracking helpers
----------------------------------------------------------------------
--- Keep runHistory under L.MAX_RUN_HISTORY. One chat notice the first time the cap
--- is hit so players know oldest rows auto-drop (not silent data loss forever).
function L.TrimRunHistory()
    if not InstanceTrackerDB then return 0 end
    if not InstanceTrackerDB.runHistory then InstanceTrackerDB.runHistory = {} end
    local hist = InstanceTrackerDB.runHistory
    local cap = L.MAX_RUN_HISTORY or 999
    local removed = 0
    while #hist > cap do
        table.remove(hist)
        removed = removed + 1
    end
    if #hist >= cap then
        if not InstanceTrackerDB.historyCapNotified then
            InstanceTrackerDB.historyCapNotified = true
            if L.AddonPrint then
                L.AddonPrint(
                    L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
                    .. "Run history full (" .. cap .. "). Oldest runs drop as new ones save."
                )
            end
        end
    else
        -- Allow a fresh notice after Clear / manual prune brings count back under cap
        InstanceTrackerDB.historyCapNotified = nil
    end
    return removed
end

--- If the player re-enters the same dungeon (e.g. after dying and being teleported out),
-- restore the most recent run for that zone from history so the session continues.
-- Only restores if the run ended within L.MAX_RESTORE_AGE_SECONDS (5 min); after that or if instance reset, start fresh.
function L.RestoreRunFromHistory(zoneName)
    local history = InstanceTrackerDB.runHistory
    if not history or #history == 0 or not zoneName or zoneName == "" then return false end
    -- If this zone was just reset, don't restore (start fresh) but keep the run in the list
    if lastResetZoneName and lastResetZoneName == zoneName then
        lastResetZoneName = nil
        return false
    end
    local now = time()
    for i = 1, #history do
        local run = history[i]
        if run and run.name == zoneName then
            local currentRealm = (GetRealmName and GetRealmName()) or ""
            local playerChar = (UnitName and UnitName("player")) or ""
            if (run.realmName and run.realmName ~= currentRealm) or (run.characterName and run.characterName ~= playerChar) then
                -- Skip runs from other realms/characters
            else
                local exitTime = run.exitTime or run.enterTime
            if (now - exitTime) > L.MAX_RESTORE_AGE_SECONDS then
                return false  -- run too old, don't restore any run for this zone
            end
            table.remove(history, i)
            -- Rebuild L.currentRun.items as itemId -> { link, quality, count, name }
            local itemsById = {}
            for _, item in ipairs(run.items or {}) do
                local link = item.link
                if link then
                    local itemId = tonumber(link:match("item:(%d+)"))
                    if itemId then
                        itemsById[itemId] = {
                            link = link,
                            quality = item.quality or 0,
                            count = item.count or 0,
                            name = item.name or "Unknown",
                        }
                    end
                end
            end
            L.currentRun = {
                name = run.name,
                enterTime = run.enterTime,
                goldCopper = run.goldCopper or 0,
                qualityCounts = run.qualityCounts and (function()
                    local qc = {}
                    for k, v in pairs(run.qualityCounts) do qc[k] = v end
                    return qc
                end)() or {},
                items = itemsById,
                repairCount = run.repairCount or 0,
                repairCopper = run.repairCopper or 0,
                deaths = run.deaths or 0,
                itemsAutodeleted = run.itemsAutodeleted or 0,
                autodeletedVendorCopper = run.autodeletedVendorCopper or 0,
                autodeletedItems = {},
            }
            L.startingGold = GetMoney() - (run.goldCopper or 0)
            L.bagBaseline = L.ScanBags()
            L.itemsGained = {}
            for itemId, item in pairs(itemsById) do
                L.itemsGained[itemId] = item.count
            end
            InstanceTrackerDB.currentRun = L.currentRun
            InstanceTrackerDB.bagBaseline = L.bagBaseline
            InstanceTrackerDB.itemsGained = L.itemsGained
            InstanceTrackerDB.startingGold = L.startingGold
            InstanceTrackerDB.currentZone = L.currentZone
            InstanceTrackerDB.isInInstance = L.isInInstance
            local BA = _G.FugaziBAGS
            if BA and type(BA.BeginLootIgnoreTracking) == "function" then
                BA.BeginLootIgnoreTracking()
            end
            L.AddonPrint(
                L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
                .. "Resumed previous run: " .. L.ColorText(run.name, 1, 1, 0.6) .. "."
            )
            if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
                L.RefreshStatsUI()
            end
            return true
            end
        end
    end
    return false
end

function L.StartRun(name)
    L.currentRun = {
        name = name,
        enterTime = time(),
        goldCopper = 0,
        qualityCounts = {},
        items = {},
        repairCount = 0,
        repairCopper = 0,
        deaths = 0,
        itemsAutodeleted = 0,
        autodeletedVendorCopper = 0,
        autodeletedItems = {},
    }
    L.SnapshotBags()
    L.startingGold = GetMoney()
    -- BAGS: equip/unequip during this run is not loot (independent of protect)
    local A = _G.FugaziBAGS
    if A and type(A.BeginLootIgnoreTracking) == "function" then
        A.BeginLootIgnoreTracking()
    end
    -- Save state for persistence
    InstanceTrackerDB.currentRun = L.currentRun
    InstanceTrackerDB.bagBaseline = L.bagBaseline
    InstanceTrackerDB.itemsGained = L.itemsGained
    InstanceTrackerDB.startingGold = L.startingGold
    InstanceTrackerDB.currentZone = L.currentZone
    InstanceTrackerDB.isInInstance = L.isInInstance
    L.AddonPrint(
        L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
        .. "Stats tracking started for " .. L.ColorText(name, 1, 1, 0.6) .. "."
    )
end

--- True if a live or finished run has anything worth keeping in history.
function L.RunHasRecordedData(run)
    if not run then return false end
    if (run.goldCopper or 0) > 0 then return true end
    if (run.repairCount or 0) > 0 or (run.repairCopper or 0) > 0 then return true end
    if (run.deaths or 0) > 0 then return true end
    if (run.itemsAutodeleted or 0) > 0 or (run.autodeletedVendorCopper or 0) > 0 then return true end
    if run.qualityCounts then
        for _, c in pairs(run.qualityCounts) do
            if (c or 0) > 0 then return true end
        end
    end
    local items = run.items
    if type(items) == "table" then
        if #items > 0 then return true end
        for _ in pairs(items) do return true end
    end
    return false
end

local function ClearCurrentRunState(zoneNameForExit)
    if zoneNameForExit then
        lastExitedZoneName = zoneNameForExit
    elseif L.currentRun then
        lastExitedZoneName = L.currentRun.name
    end
    L.currentRun = nil
    if L.ClearSoftPause then L.ClearSoftPause() else L.runSoftPaused = false end
    if InstanceTrackerDB then
        InstanceTrackerDB.currentRun = nil
        InstanceTrackerDB.bagBaseline = nil
        InstanceTrackerDB.itemsGained = nil
        InstanceTrackerDB.startingGold = nil
        InstanceTrackerDB.runSoftPaused = false
    end
    L.bagBaseline = nil
    L.itemsGained = nil
    L.startingGold = nil
end

--- Called when you leave the instance: saves the run to the Ledger (duration, gold, items) and clears current run state.
--- Empty visits (no loot/gold/deaths/repairs) are discarded so 4-second walk-ins never clutter history.
function L.FinalizeRun()
    if not L.currentRun then return end
    L.DiffBags()
    local A = _G.FugaziBAGS
    if A and type(A.EndLootIgnoreTracking) == "function" then
        A.EndLootIgnoreTracking()
    end
    -- Gold earned = current money - starting money
    local goldEarned = GetMoney() - L.startingGold
    if goldEarned < 0 then goldEarned = 0 end
    L.currentRun.goldCopper = goldEarned

    local now = time()
    local zoneName = L.currentRun.name

    -- Final bag snapshot so we can distinguish between "kept" vs "sold during run"
    local finalCounts = L.ScanBags()
    local baseCounts = L.bagBaseline or {}

    -- Dungeon runs: loot map + sink maps (autodelete during run). Sold = leftover gap after remaining+deleted.
    local deletedMap = L.currentRun.autodeletedItems or {}
    local itemList = {}
    local seen = {}
    for itemId, item in pairs(L.currentRun.items) do
        itemId = tonumber(itemId) or itemId
        seen[itemId] = true
        local totalCount = item.count or 0
        local finalCount = math.max(0, (finalCounts[itemId] or 0) - (baseCounts[itemId] or 0))
        local deletedCount = tonumber(deletedMap[itemId]) or 0
        local soldCount = totalCount - finalCount - deletedCount
        if soldCount < 0 then soldCount = 0 end
        -- Prefer sink totals when cumulative loot under-counted.
        if totalCount < (finalCount + soldCount + deletedCount) then
            totalCount = finalCount + soldCount + deletedCount
        end
        local fullyDeleted = deletedCount > 0 and finalCount == 0
        table.insert(itemList, {
            link = item.link,
            itemId = itemId,
            id = itemId,
            quality = item.quality,
            count = totalCount,
            name = item.name,
            iLvl = item.iLvl or item.itemLevel,
            remainingCount = finalCount,
            soldCount = soldCount,
            deletedCount = deletedCount,
            soldDuringSession = soldCount > 0 and finalCount == 0 and deletedCount == 0,
            autodeletedDuringSession = fullyDeleted,
        })
    end
    -- Orphans only in autodeletedItems (delete raced DiffBags before items map fill).
    for itemId, n in pairs(deletedMap) do
        itemId = tonumber(itemId) or itemId
        n = tonumber(n) or 0
        if not seen[itemId] and n > 0 then
            local link = L.itemLinksCache and L.itemLinksCache[itemId]
            local name, quality, iLvl
            if link and GetItemInfo then
                name, _, quality, iLvl = GetItemInfo(link)
            elseif GetItemInfo then
                name, link, quality, iLvl = GetItemInfo(itemId)
            end
            quality = quality or 0
            table.insert(itemList, {
                link = link,
                itemId = itemId,
                id = itemId,
                quality = quality,
                count = n,
                name = name or ("Item " .. tostring(itemId)),
                iLvl = iLvl,
                remainingCount = 0,
                soldCount = 0,
                deletedCount = n,
                soldDuringSession = false,
                autodeletedDuringSession = true,
            })
        end
    end
    -- Kept first, fully-autodeleted last (red-wash block at bottom).
    table.sort(itemList, function(a, b)
        local aDel = a.autodeletedDuringSession and 1 or 0
        local bDel = b.autodeletedDuringSession and 1 or 0
        if aDel ~= bDel then return aDel < bDel end
        if a.quality ~= b.quality then return a.quality > b.quality end
        return (a.name or "") < (b.name or "")
    end)

    local vendorValue = 0
    local ahValue = 0
    local destroyValue = 0
    local Addon = _G.FugaziBAGS or _G.FugaziBAGS
    
    for _, item in ipairs(itemList) do
        local link = item.link
        local count = item.remainingCount or item.count or 0
        if link and count > 0 then
            local price, action = 0, "VENDOR"
            if Addon and Addon.GetItemValuationAndAction then
                local _, _, _, _, _, itemClass = GetItemInfo(link)
                price, action = Addon.GetItemValuationAndAction(link, item.itemId, item.quality, item.iLvl or 0, itemClass)
            else
                price = select(11, GetItemInfo(link)) or 0
            end
            
            local total = price * count
            if action == "AH" then
                ahValue = ahValue + total
            elseif action == "DE" or action == "PROSPECT" or action == "MILL" then
                destroyValue = destroyValue + total
            else
                vendorValue = vendorValue + total
            end
        end
    end
    
    local duration = now - L.currentRun.enterTime
    local estimatedValueCopper = L.currentRun.goldCopper + vendorValue + ahValue + destroyValue
    local estimatedGPHCopper = (duration > 0) and math.floor(estimatedValueCopper / (duration / 3600)) or 0

    local run = {
        name = L.currentRun.name,
        enterTime = L.currentRun.enterTime,
        exitTime = now,
        duration = duration,
        goldCopper = L.currentRun.goldCopper,
        qualityCounts = L.currentRun.qualityCounts,
        items = itemList,
        vendorValue = vendorValue,
        ahValue = ahValue,
        destroyValue = destroyValue,
        estimatedValueCopper = estimatedValueCopper,
        estimatedGPHCopper = estimatedGPHCopper,
        repairCount = L.currentRun.repairCount or 0,
        repairCopper = L.currentRun.repairCopper or 0,
        deaths = L.currentRun.deaths or 0,
        itemsAutodeleted = L.currentRun.itemsAutodeleted or 0,
        autodeletedVendorCopper = L.currentRun.autodeletedVendorCopper or 0,
        characterName = UnitName("player"),
        realmName = GetRealmName(),
    }

    -- No loot / gold / deaths / repairs → discard (also blocks 5‑min resume of empty visits).
    if not L.RunHasRecordedData(run) then
        L.AddonPrint(
            L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
            .. "Empty visit ignored: " .. L.ColorText(zoneName or "?", 1, 1, 0.6)
            .. " (no loot or gold)."
        )
        ClearCurrentRunState(zoneName)
        if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
            L.RefreshStatsUI()
        end
        return
    end

    if not InstanceTrackerDB.runHistory then InstanceTrackerDB.runHistory = {} end
    table.insert(InstanceTrackerDB.runHistory, 1, run)
    if L.TrimRunHistory then L.TrimRunHistory() end

    L.AddonPrint(
        L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
        .. "Run complete: " .. L.ColorText(run.name, 1, 1, 0.6)
        .. " - " .. L.FormatTimeMedium(run.duration)
        .. " | " .. L.FormatGoldPlain(run.goldCopper)
    )

    -- [ADVANCED STATS] Update lifetime/analytic data
    local LS = L.LS
    if L.LS then
        L.LS.totalGoldCopper = (L.LS.totalGoldCopper or 0) + (run.goldCopper or 0)
        L.LS.totalRuns = (L.LS.totalRuns or 0) + 1
        
        -- Rarity breakdown
        L.LS.rarityBreakdown = L.LS.rarityBreakdown or {}
        if run.qualityCounts then
            for q, count in pairs(run.qualityCounts) do
                L.LS.rarityBreakdown[q] = (L.LS.rarityBreakdown[q] or 0) + count
            end
        end

        -- Best GPH (Gold Per Hour)
        if run.duration and run.duration > 60 then -- Only count runs > 1 min
            local gph = (run.goldCopper or 0) / (run.duration / 3600)
            if gph > (L.LS.bestGPH or 0) then
                L.LS.bestGPH = gph
            end
        end

        -- Zone Efficiency
        if run.name and run.name ~= "" and not run.name:find("GPH") then
            L.LS.zoneEfficiency = L.LS.zoneEfficiency or {}
            local ze = L.LS.zoneEfficiency[run.name] or { totalGold = 0, totalDuration = 0, runCount = 0 }
            ze.totalGold = ze.totalGold + (run.goldCopper or 0)
            ze.totalDuration = ze.totalDuration + (run.duration or 0)
            ze.runCount = ze.runCount + 1
            L.LS.zoneEfficiency[run.name] = ze
        end
    end


    -- Refresh stats window if it's open (prevents nil error)
    if L.statsFrame and L.statsFrame:IsShown() then
        if type(L.RefreshStatsUI) == "function" then
            L.RefreshStatsUI()
        end
    end

    ClearCurrentRunState(zoneName)
end

-- Mail gold must not pollute lifetime "gold gained" or active-run gold.
-- While the mailbox UI is open (or briefly after close), money deltas are
-- neutralized against L.startingGold for live runs.
-- Lifetime: suppress player/alt mail, but ALLOW Auction House sale takes
-- (AH gold is delivered via mailbox — invoiceType "seller" / auction sender).
L._mailMoneySuppressUntil = 0
L._pendingAhMailCopper = 0
L._pendingAhMailExpire = 0

local function IsMailMoneySuppressed()
    if (MailFrame and MailFrame:IsShown()) or (SendMailFrame and SendMailFrame:IsShown())
        or (OpenMailFrame and OpenMailFrame:IsShown()) then
        return true
    end
    local untilT = L._mailMoneySuppressUntil or 0
    return untilT > 0 and GetTime() < untilT
end

local function IsAuctionSaleMail(index)
    if not index then return false end
    local money = select(5, GetInboxHeaderInfo(index)) or 0
    if money <= 0 then return false end
    -- WotLK/Ascension: seller invoice = successful AH sale proceeds.
    if type(GetInboxInvoiceInfo) == "function" then
        local invoiceType = GetInboxInvoiceInfo(index)
        if invoiceType == "seller" then return true end
    end
    local sender = select(3, GetInboxHeaderInfo(index)) or ""
    local subject = select(4, GetInboxHeaderInfo(index)) or ""
    local s = sender:lower()
    local sub = subject:lower()
    if s:find("auction", 1, true) then
        -- Refunds / outbids are not "sales" for lifetime gain.
        if sub:find("outbid", 1, true) or sub:find("won", 1, true)
            or sub:find("expired", 1, true) or sub:find("cancelled", 1, true)
            or sub:find("canceled", 1, true) then
            return false
        end
        return true
    end
    if sub:find("auction successful", 1, true) or sub:find("sale successful", 1, true) then
        return true
    end
    return false
end

local function NotePendingAhMailTake(index)
    if not IsAuctionSaleMail(index) then return end
    local money = select(5, GetInboxHeaderInfo(index)) or 0
    if money <= 0 then return end
    L._pendingAhMailCopper = (L._pendingAhMailCopper or 0) + money
    L._pendingAhMailExpire = (GetTime() or 0) + 5
end

-- Pre-hooks so we read invoice/header before the client clears the row.
if not L._mailAhHooksInstalled then
    L._mailAhHooksInstalled = true
    if type(TakeInboxMoney) == "function" then
        local orig = TakeInboxMoney
        _G.TakeInboxMoney = function(index, ...)
            NotePendingAhMailTake(index)
            return orig(index, ...)
        end
    end
    if type(AutoLootMailItem) == "function" then
        local orig = AutoLootMailItem
        _G.AutoLootMailItem = function(index, ...)
            NotePendingAhMailTake(index)
            return orig(index, ...)
        end
    end
end

local function ConsumePendingAhMail(delta)
    if not delta or delta <= 0 then return 0 end
    local exp = L._pendingAhMailExpire or 0
    if exp > 0 and GetTime() > exp then
        L._pendingAhMailCopper = 0
        L._pendingAhMailExpire = 0
        return 0
    end
    local pending = L._pendingAhMailCopper or 0
    if pending <= 0 then return 0 end
    local allow = delta
    if allow > pending then allow = pending end
    L._pendingAhMailCopper = pending - allow
    return allow
end

L.coreEventFrame = CreateFrame("Frame")
L.coreEventFrame:RegisterEvent("PLAYER_LOGIN")
L.coreEventFrame:RegisterEvent("PLAYER_MONEY")
L.coreEventFrame:RegisterEvent("PLAYER_DEAD")
L.coreEventFrame:RegisterEvent("BAG_UPDATE")
L.coreEventFrame:RegisterEvent("MERCHANT_SHOW")
L.coreEventFrame:RegisterEvent("MERCHANT_CLOSED")
L.coreEventFrame:RegisterEvent("GOSSIP_SHOW")
L.coreEventFrame:RegisterEvent("QUEST_GREETING")
L.coreEventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
L.coreEventFrame:RegisterEvent("MAIL_SHOW")
L.coreEventFrame:RegisterEvent("MAIL_CLOSED")
L.coreEventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
L.coreEventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
L.coreEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "MAIL_SHOW" or event == "MAIL_SEND_SUCCESS" or event == "MAIL_INBOX_UPDATE" then
        -- Keep suppress armed while mailbox is in use (incl. attach take / send).
        L._mailMoneySuppressUntil = (GetTime() or 0) + 3
        return
    elseif event == "MAIL_CLOSED" then
        -- Gold can settle a tick after the frame hides.
        L._mailMoneySuppressUntil = (GetTime() or 0) + 2
        return
    end
    if event == "PLAYER_LOGIN" then
        -- Run migrations and initialization after SavedVariables are fully loaded
        L.InitializeLifetimeStats()
        L.EnsureAutoStatTables()
        L.MigrateOldRuns()

        if not InstanceTrackerDB.recentInstances then InstanceTrackerDB.recentInstances = {} end
        if not InstanceTrackerDB.runHistory then InstanceTrackerDB.runHistory = {} end
        if not InstanceTrackerDB.accountGold then InstanceTrackerDB.accountGold = {} end
        if not InstanceTrackerDB.lifetimeGoldGained then InstanceTrackerDB.lifetimeGoldGained = {} end
        if not InstanceTrackerDB.lastKnownMoney then InstanceTrackerDB.lastKnownMoney = {} end
        if not InstanceTrackerDB.lifetimeDeaths then InstanceTrackerDB.lifetimeDeaths = {} end
        if not InstanceTrackerDB.resettableInstances then InstanceTrackerDB.resettableInstances = {} end
        local key = L.GetGphCharKey()
        InstanceTrackerDB.accountGold[key] = GetMoney()
        InstanceTrackerDB.lastKnownMoney[key] = GetMoney()
        L.PurgeOld()
        if not _G.InstanceTrackerKeybindOwner then
            _G.InstanceTrackerKeybindOwner = CreateFrame("Frame", "InstanceTrackerKeybindOwner", UIParent)
        end
        -- Restore current run state if it exists
        if InstanceTrackerDB.currentRun then
            L.currentRun = InstanceTrackerDB.currentRun
            L.bagBaseline = InstanceTrackerDB.bagBaseline or {}
            L.itemsGained = InstanceTrackerDB.itemsGained or {}
            L.startingGold = InstanceTrackerDB.startingGold or GetMoney()
            L.currentZone = InstanceTrackerDB.currentZone or ""
            L.isInInstance = InstanceTrackerDB.isInInstance or false
            L.runSoftPaused = InstanceTrackerDB.runSoftPaused or false
            -- Do not re-snapshot bags on reload: that would replace "bags at enter" with "bags now" and make every item show as vendored in the items window.
            local BA = _G.FugaziBAGS
            if BA and type(BA.BeginLootIgnoreTracking) == "function" then
                BA.BeginLootIgnoreTracking()
            end
            -- Reconcile soft-pause after reload / login.
            local inInst, iType = IsInInstance()
            local inDungeon = inInst and (iType == "party" or iType == "raid")
            -- Ascension Manastorm: drop restored run only if tracker UI is live (not sticky).
            if L.DetectManastormNow and L.DetectManastormNow() then
                if L.AbortRunNoHistory then
                    L.AbortRunNoHistory((L.Loc and L.Loc.MSG_MANASTORM_IGNORED) or "Manastorm ignored — not saved to Ledger")
                else
                    L.currentRun = nil
                    InstanceTrackerDB.currentRun = nil
                end
                L.manastormActive = true
                L.isInInstance = inDungeon and true or false
                L.runSoftPaused = false
                InstanceTrackerDB.runSoftPaused = false
            elseif inDungeon then
                L.isInInstance = true
                L.runSoftPaused = false
                InstanceTrackerDB.runSoftPaused = false
                if not L.currentZone or L.currentZone == "" then
                    L.currentZone = (GetInstanceInfo and select(1, GetInstanceInfo())) or GetRealZoneText() or L.currentRun.name or ""
                end
            elseif L.IsPlayerGhost and L.IsPlayerGhost() then
                -- Still ghost outside: keep run open, timer continues.
                L.isInInstance = false
                L.runSoftPaused = true
                InstanceTrackerDB.isInInstance = false
                InstanceTrackerDB.runSoftPaused = true
            else
                -- Alive outside with a dangling open run → finalize for real.
                if L.MaybeFinalizeAliveOutside then
                    L.MaybeFinalizeAliveOutside()
                elseif L.FinalizeRun then
                    L.FinalizeRun()
                end
            end
        end
        
        -- GPH session/vendor/destroy live in __FugaziBAGS; no session restore here.

        -- Main tracker (classic cap+lockouts / Ascension lockouts+bosses).
        if L.IsMainTrackerUIEnabled and L.IsMainTrackerUIEnabled() then
            L.frame = L.CreateMainFrame()
            L.frame:SetScript("OnHide", function() L.frame:SetScript("OnUpdate", nil) end)
            L.frame:SetScript("OnShow", function() L.frame:SetScript("OnUpdate", L.OnUpdate) end)
            L.RestoreFrameLayout(L.frame, "frameShown", "framePoint")
            if not (InstanceTrackerDB.framePoint and InstanceTrackerDB.framePoint.point) then
                L.frame:ClearAllPoints()
                L.frame:SetPoint("TOP", UIParent, "CENTER", 0, 200)
            end
            if L.frame:IsShown() then L.frame:SetScript("OnUpdate", L.OnUpdate) end
            if L.CapData and L.CapData.EnsureResetReplayHooks then
                L.CapData.EnsureResetReplayHooks()
            end
            if RequestRaidInfo then RequestRaidInfo() end
            if L.UpdateLockoutCache then L.UpdateLockoutCache() end
            if L.frame:IsShown() then L.RefreshUI(true) end
        end
        -- GPH/inventory window + gphDockedToMain live in __FugaziBAGS / FugaziBAGSDB only.
        if InstanceTrackerDB.statsShown then
            if not L.statsFrame then L.statsFrame = L.CreateStatsFrame() end
            L.statsFrame:ClearAllPoints()
            local pt = InstanceTrackerDB.statsPoint
            if pt and pt.point and pt.relativePoint and pt.x and pt.y then
                L.statsFrame:SetPoint(pt.point, UIParent, pt.relativePoint, pt.x, pt.y)
            elseif L.frame then
                L.statsFrame:SetWidth(L.frame:GetWidth())
                L.statsFrame:SetHeight(L.frame:GetHeight())
                L.statsFrame:SetPoint("TOPLEFT", L.frame, "TOPRIGHT", 4, 0)
            else
                L.statsFrame:SetPoint("TOP", UIParent, "CENTER", 0, 100)
            end
            L.statsFrame:Show()
            L.RefreshStatsUI()
        end
        if L.IsAscensionRealm and L.IsAscensionRealm() then
            L.AddonPrint(
                L.ColorText("[Fugazi Instance Tracker] ", 0.4, 0.8, 1)
                .. "Loaded (Ascension lockouts). " .. L.ColorText("/fit", 1, 1, 0.6) .. " / "
                .. L.ColorText("/ledger", 1, 1, 0.6) .. "."
            )
        else
            L.AddonPrint(
                L.ColorText("[Fugazi Instance Tracker] ", 0.4, 0.8, 1)
                .. "Loaded. " .. L.ColorText("/fit", 1, 1, 0.6) .. " / "
                .. L.ColorText("/ledger", 1, 1, 0.6) .. "."
            )
        end
        end

    if event == "UPDATE_INSTANCE_INFO" then
        if L.frame and L.frame:IsShown() then
            if L.UpdateLockoutCache then L.UpdateLockoutCache() end
            if L.RefreshUI then L.RefreshUI(true) end
        end

    elseif event == "PLAYER_MONEY" then
        local key = L.GetGphCharKey()
        local now = GetMoney()
        local last = InstanceTrackerDB.lastKnownMoney and InstanceTrackerDB.lastKnownMoney[key]
        local delta = (last and now) and (now - last) or 0
        local mailSuppressed = IsMailMoneySuppressed()

        if InstanceTrackerDB.accountGold then
            InstanceTrackerDB.accountGold[key] = now
        end

        -- Neutralize ALL mailbox money (alts + AH) against live run gold.
        -- Run GPH should reflect the dungeon, not inbox looting mid-run.
        if mailSuppressed and delta ~= 0 and L.startingGold then
            L.startingGold = L.startingGold + delta
            if InstanceTrackerDB then InstanceTrackerDB.startingGold = L.startingGold end
        end

        -- Lifetime gold gained: wallet increases.
        -- While mailbox is open, skip alt/player mail — but keep AH sale takes.
        if InstanceTrackerDB.lifetimeGoldGained and key and last and delta > 0 then
            local add = 0
            if not mailSuppressed then
                add = delta
            else
                add = ConsumePendingAhMail(delta)
            end
            if add > 0 then
                InstanceTrackerDB.lifetimeGoldGained[key] = (InstanceTrackerDB.lifetimeGoldGained[key] or 0) + add
            end
        end
        if InstanceTrackerDB.lastKnownMoney and key then
            InstanceTrackerDB.lastKnownMoney[key] = now
        end
    elseif event == "MERCHANT_SHOW" or event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        L.gphNpcDialogTime = GetTime()
        if event == "MERCHANT_SHOW" then
            L.merchantGoldAtOpen = GetMoney()
            L.merchantRepairCostAtOpen = (GetRepairAllCost and select(1, GetRepairAllCost())) or 0
        end
    elseif event == "MERCHANT_CLOSED" then
        if L.LS then
            local LS = L.LS

            local nowGold = GetMoney()
            if L.merchantGoldAtOpen then
                local delta = nowGold - L.merchantGoldAtOpen
                if delta > 0 then
                    LS.vendorCopper = (LS.vendorCopper or 0) + delta
                    LS.vendorItemCount = (LS.vendorItemCount or 0) + 1
                    -- Per-run vendor gold (instance runs only for now; GPH sessions are handled separately in BAGS)
                    if L.currentRun then
                        L.currentRun.vendorGold = (L.currentRun.vendorGold or 0) + delta
                    end
                end
                L.merchantGoldAtOpen = nil
            end

            -- Repair: detect via GetRepairAllCost (like EbonholdStuff) so we count repair even when player also sold
            local repairCostNow = (GetRepairAllCost and select(1, GetRepairAllCost())) or 0
            local repairSpent = (L.merchantRepairCostAtOpen or 0) - repairCostNow
            if repairSpent > 0 then
                LS.repairCopper = (LS.repairCopper or 0) + repairSpent
                LS.repairCount = (LS.repairCount or 0) + 1
                if L.currentRun then
                    L.currentRun.repairCopper = (L.currentRun.repairCopper or 0) + repairSpent
                    L.currentRun.repairCount = (L.currentRun.repairCount or 0) + 1
                end
                -- Live-refresh lifetime + run details so repairs show up immediately.
                if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
                    L.RefreshStatsUI()
                end
                if L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown() and type(L.RefreshLedgerDetailUI) == "function" then
                    L.RefreshLedgerDetailUI()
                end
            end
            L.merchantRepairCostAtOpen = nil
        end
        L.gphNpcDialogTime = nil
    elseif event == "PLAYER_DEAD" then
        local key = L.GetGphCharKey()
        if InstanceTrackerDB.lifetimeDeaths then
            InstanceTrackerDB.lifetimeDeaths[key] = (InstanceTrackerDB.lifetimeDeaths[key] or 0) + 1
        end
        if L.currentRun then
            L.currentRun.deaths = (L.currentRun.deaths or 0) + 1
        end
        if L.LS and (L.currentRun or (IsInInstance and IsInInstance())) then
            local LS = L.LS
            LS.instanceDeaths = (LS.instanceDeaths or 0) + 1
        end
        -- Live-refresh lifetime + run details so deaths show up immediately.
        if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
            L.RefreshStatsUI()
        end
        if L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown() and type(L.RefreshLedgerDetailUI) == "function" then
            L.RefreshLedgerDetailUI()
        end
    elseif event == "BAG_UPDATE" then
        if L.currentRun then L.DiffBags() end
        -- GPH window, destroy list, and vendor/summon live in __FugaziBAGS only.
    end
end)
