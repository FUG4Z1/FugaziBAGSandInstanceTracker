local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}
-- DB is fetched dynamically inside major functions to avoid stale reference issues.

local Skins = _G.__FugaziBAGS_Skins
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerItemCooldown = _G.GetContainerItemCooldown
local GetTime = _G.GetTime

--- Constants
local SCROLL_CONTENT_WIDTH = 296

-- Phase 5: module-level working tables (wipe + refill). Not UI row pools — data only.
local _lvWorkingList = {}
local _lvFilterList = {}
local _lvMatchList = {}
local _lvNormalList = {}
local _lvDestroyedList = {}
local _lvDrawList = {}
local _lvBagsToScan = { 0, 1, 2, 3, 4 }
local _lvDestroySearchTemp = {}

-- Phase 9: list smart count-patch (same itemId set → no re-aggregate walk/sort).
-- Snapshot is full-inventory itemId→count after a successful list rebuild (not filter ghosts).
local _lvSmartAggCounts = {}
local _lvSmartAggN = 0
local _lvSmartValid = false

--- Patch count/slot fields on list entries from a fresh aggregate dict (itemId → agg).
local function PatchListCountsFromAgg(list, aggregated)
    if not list or not aggregated then return end
    for _, item in ipairs(list) do
        if item and item.itemId and not item.divider then
            local agg = aggregated[item.itemId]
            if agg then
                local stackTotal = tonumber(agg.totalCount) or 0
                if stackTotal < 1 then stackTotal = 1 end
                item.count = stackTotal
                item.totalCount = stackTotal
                item.bag = agg.firstBag
                item.slot = agg.firstSlot
                if agg.link then item.link = agg.link end
                if agg.texture then item.texture = agg.texture end
            end
        end
    end
end

--- Remember aggregate itemId set/counts for the next L1 smart path.
local function SnapshotSmartAgg(aggregated)
    wipe(_lvSmartAggCounts)
    local n = 0
    if aggregated then
        for itemId, agg in pairs(aggregated) do
            local c = tonumber(agg.totalCount) or 0
            if c < 1 then c = 1 end
            _lvSmartAggCounts[itemId] = c
            n = n + 1
        end
    end
    _lvSmartAggN = n
    _lvSmartValid = true
end

--- True when L1 loot only grew/shrunk existing stacks (no itemId appear/disappear).
local function CanSmartListPatch(aggregated)
    if not _lvSmartValid or not aggregated then return false end
    if #_lvWorkingList == 0 then return false end
    local n = 0
    for itemId, agg in pairs(aggregated) do
        n = n + 1
        if _lvSmartAggCounts[itemId] == nil then return false end
    end
    if n ~= _lvSmartAggN then return false end
    return true
end

--- Public Pool Collections (Note: Performance-critical lists are now localized to RefreshGPHUI)



-- Register listeners for architectural "A-Grade" refresh system
if A.OnOptionChanged then
    A.OnOptionChanged("gphSortMode", function()
        local gphFrame = A.Inventory
        if gphFrame and gphFrame:IsShown() and not gphFrame.gphGridMode then
            gphFrame._refreshImmediate = true
            if A.RefreshGPHUI then A.RefreshGPHUI() end
        end
    end)
    
    A.OnOptionChanged("gphFrameScale", function(val)
        local inv = A.Inventory
        local bank = A.Bank
        if inv then
            local base = A.GetOption("gphScale15") and 1.5 or 1
            local total = base * val
            inv:SetScale(total)
            if inv.gphDisenchantBtn then inv.gphDisenchantBtn:SetScale(total) end
            if inv.gphProspectBtn then inv.gphProspectBtn:SetScale(total) end
            if inv.gphMillingBtn then inv.gphMillingBtn:SetScale(total) end
            if inv.gphOpenBtn then inv.gphOpenBtn:SetScale(total) end
            
            if bank then
                -- Only scale the bank if it's not a child of the inventory (independent bank)
                bank:SetScale(bank:GetParent() == inv and 1 or total)
            end
        end
    end)
end


--- Clear rarity drag-paint when mouse button released.
function A.GPH_StartRarityDragPaintClear()
    local f = A._gphRarityDragPaintClearFrame
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f:SetScript("OnUpdate", function(self)
            if not (A.rarityDragPaint and A.rarityDragPaint.active) then
                self:SetScript("OnUpdate", nil)
                self:Hide()
                return
            end
            local down = (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) or false
            if not down then
                A.rarityDragPaint.active = false
                local gf = A.Inventory
                if gf then gf._refreshImmediate = true end
                if A.RefreshGPHUI then A.RefreshGPHUI() end
                self:SetScript("OnUpdate", nil)
                self:Hide()
            end
        end)
        A._gphRarityDragPaintClearFrame = f
    end
    f:Show()
    f:SetScript("OnUpdate", f:GetScript("OnUpdate"))
end



--- Rarity bar button: filter, protect, delete all, mail to bank.
--- (GPHQualBtn_OnClick moved to Options.lua)



-- Rarity button scripts (OnEnter, OnLeave, OnUpdate, OnMouseDown) are now handled globally in FugaziBAGS_Utils.lua










-- Global Category Sort Comparator (static to avoid churn)
local function GPH_Internal_Sort_Comparator(a, b)
    if a.isDestroy and b.isDestroy then
        local atA = a.addedTime or 0
        local atB = b.addedTime or 0
        if atA ~= atB then return atA > atB end
        return (a.name or "") < (b.name or "")
    end
    return A.GPH_Sort_CategoryGroup and A.GPH_Sort_CategoryGroup(a, b) or false
end

--- Refresh inventory UI (main house switch for the open bag window).
---
--- Levels (Phase 2; keep split — do not collapse):
---   L1 content — loot / bag change: dirty memory + list/grid paint. No NegotiateSizes/skin.
---   L2 list    — filter/sort rebuild (between content and full open).
---   L3 chrome  — open, skin, size, mode switch, bank dock, bag capacity.
---
--- forceOrLevel:
---   1 / "content" / "L1" → L1
---   2 / "list" / "L2" → L2
---   3 / true / "full" / "chrome" / "L3" → L3
---   nil → pending _refreshLevel, else 3 (safe default for older callers)
--- Pending _refreshLevel may only RAISE level (never demote open/options L3 to bag L1).
--- _refreshImmediate bypasses the 0.15s throttle (options / protect / destroy).
---
--- Phase 9 L1 list: when only existing stack counts change, patch rows + rarity
--- and skip full working-list rebuild/sort/filter (see CanSmartListPatch).
---
--- Combat: NegotiateSizes hard-stops inside itself (taint compromise).
--- Sacred: no size renegotiate on routine L1 loot.
function A.RefreshGPHUI(forceOrLevel)
    local gphFrame = A.Inventory
    if not (gphFrame and gphFrame:IsVisible()) then return end
    if gphFrame._isRefreshing then
        return
    end

    local DB = _G.FugaziBAGSDB or {}
    local gphSession = _G.gphSession

    local now = (GetTime and GetTime()) or time()
    local immediate = gphFrame._refreshImmediate
    gphFrame._refreshImmediate = nil

    -- Resolve refresh level (explicit arg base; pending may raise only).
    local level = 3
    if forceOrLevel == 1 or forceOrLevel == "content" or forceOrLevel == "L1" then
        level = 1
    elseif forceOrLevel == 2 or forceOrLevel == "list" or forceOrLevel == "L2" then
        level = 2
    elseif forceOrLevel == 3 or forceOrLevel == true or forceOrLevel == "full" or forceOrLevel == "chrome" or forceOrLevel == "L3" then
        level = 3
    elseif forceOrLevel == nil and gphFrame._refreshLevel then
        -- Bag-event path: PromoteGPHRefreshLevel then RefreshGPHUI() with no arg
        level = gphFrame._refreshLevel
    end
    if gphFrame._refreshLevel and gphFrame._refreshLevel > level then
        level = gphFrame._refreshLevel
    end

    -- Trailing-edge throttle: keep highest pending level so a burst ends on the right tier.
    if not immediate and gphFrame._lastRefreshGPHUI and (now - gphFrame._lastRefreshGPHUI) < 0.15 then
        gphFrame._refreshLevel = math.max(gphFrame._refreshLevel or 0, level)
        if not gphFrame._refreshGPHScheduler then
            gphFrame._refreshGPHScheduler = CreateFrame("Frame", nil, gphFrame)
            gphFrame._refreshGPHScheduler:Hide()
            gphFrame._refreshGPHScheduler:SetScript("OnUpdate", function(self, elapsed)
                self._timer = (self._timer or 0) + elapsed
                if self._timer >= 0.15 then
                    self._timer = 0
                    self:Hide()
                    if A.RefreshGPHUI then A.RefreshGPHUI() end
                end
            end)
        end
        gphFrame._refreshGPHScheduler._timer = 0
        gphFrame._refreshGPHScheduler:Show()
        return
    end
    -- Consume pending level; we are actually running now
    gphFrame._refreshLevel = nil
    if gphFrame._refreshGPHScheduler then gphFrame._refreshGPHScheduler:Hide() end

    -- L3 chrome only: negotiate + skin. L1 loot must not call NegotiateSizes.
    local doChrome = (level >= 3)

    if A.RefreshGPHBagRow then A.RefreshGPHBagRow(gphFrame) end

    -- One bag scan for session ledger (reuse — do not ScanBags again later in this refresh).
    local sessionBagSnap = nil
    if _G.gphSession and A.ScanBags then
        sessionBagSnap = A.ScanBags()
    end
    if A.DiffBagsGPH then
        A.DiffBagsGPH(sessionBagSnap)
    end
    
    local inCombat = InCombatLockdown and InCombatLockdown()
    if doChrome and not inCombat then
        if gphFrame.NegotiateSizes then gphFrame:NegotiateSizes() end
    end
    
    if gphFrame.gphGridMode and _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then
        _G.FugaziBAGS_CombatGrid.RefreshSlots()
    end
    
    if doChrome then
        if gphFrame.gphTitle and Skins and Skins.ApplyGphInventoryTitle then Skins.ApplyGphInventoryTitle(gphFrame.gphTitle) end
        if not inCombat then
            if gphFrame.UpdateGphTitleBarButtonLayout then gphFrame:UpdateGphTitleBarButtonLayout() end
        end
        -- One skin path only (same idea as ApplyTestSkin). Skip when id/gen unchanged.
        local needSkin = (not A.FrameNeedsSkinApply) or A.FrameNeedsSkinApply(gphFrame)
        if needSkin then
            if gphFrame.ApplySkin then
                gphFrame:ApplySkin()
            elseif Skins and Skins.ApplyGPHFrameSkin then
                Skins.ApplyGPHFrameSkin(gphFrame)
            end
            if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(gphFrame) end
        end
    end
    -- Profession / button visibility: cheap enough and state can change while looting mail/merchant.
    if gphFrame.UpdateGPHProfessionButtons then gphFrame:UpdateGPHProfessionButtons() end
    if gphFrame.UpdateGPHButtonVisibility then gphFrame:UpdateGPHButtonVisibility() end
    if _G.UpdateSortIcon then _G.UpdateSortIcon() end
    
    if not gphFrame.gphGridMode then
        if A.ResetGPHQualityPool then A.ResetGPHQualityPool() end
    end
    
    A.ResetGPHDataPools()

    

    local refreshOk, refreshErr = pcall(function()
    local content = gphFrame.content
    local sf = gphFrame.scrollFrame
    -- Same width source as NegotiateSizes (scroll viewport). frameW-44 fought
    -- sf:GetWidth() (~frameW-38) and made count/name truncation jitter L/R.
    local sfW
    if sf and content then
        if sf.GetWidth then
            local sw = sf:GetWidth()
            if sw and sw > 50 then sfW = sw end
        end
        if not sfW then
            sfW = (gphFrame:GetWidth() or 340) - 44
            if sfW < 50 then sfW = 340 end
        end
        if content:GetWidth() ~= sfW then
            content:SetWidth(sfW)
        end
        gphFrame.gphDynContentWidth = sfW
    end

    local header = gphFrame.gphHeader
    local now = time()
    local nowGph = GetTime and GetTime() or time()
    local headerParent = header or content

    -- L3: rebuild header chrome. L1/L2: leave rarity bar / bag-space anchors alone.
    if doChrome then
        if header and header.headerElements then
            for _, el in ipairs(header.headerElements) do
                el:ClearAllPoints()
                el:Hide()
            end
            wipe(header.headerElements)
        end
        if header then header.headerElements = header.headerElements or {} end

        if content.headerElements then
            for _, el in ipairs(content.headerElements) do
                el:ClearAllPoints()
                el:Hide()
            end
            wipe(content.headerElements)
        end
        content.headerElements = content.headerElements or {}

        if gphFrame.gphSearchEditBox then
            if gphFrame.gphSearchBarVisible then
                gphFrame.gphSearchEditBox:Show()
                gphFrame.gphSearchEditBox:SetPoint("RIGHT", gphFrame, "TOPRIGHT", -8, -53)
            else
                gphFrame.gphSearchEditBox:Hide()
            end
        end
    end

    -- Status text is now handled by the Master Clock in f.MasterUpdate for optimal combat performance.
    -- We only hide it here if the Instance Tracker is not loaded.
    if not IsAddOnLoaded("__FugaziInstanceTracker") then
        gphFrame.statusText:Hide()
    end

    local headerY = 0

    A.pendingQuality = A.pendingQuality or {}
    for q = 0, 5 do
        if A.pendingQuality[q] and (nowGph - A.pendingQuality[q]) > 5 then
            A.pendingQuality[q] = nil
        end
    end

    if gphFrame.gphItemIndexToY then wipe(gphFrame.gphItemIndexToY) end
    -- Session path already scanned above; UI uses GetInventoryData/slot memory, not this map.
    if not sessionBagSnap and A.ScanBags then A.ScanBags() end
	
    -- 1. Setup collections (Phase 5: wipe + refill reusable tables, no new {} every open).
    -- Phase 9: do NOT wipe _lvWorkingList yet — L1 smart count-patch reuses it when the itemId set is unchanged.
    local workingList = _lvWorkingList
	
    local typeCache = DB.gphItemTypeCache or {}
    DB.gphItemTypeCache = typeCache
    local bagsToScan = _lvBagsToScan
    bagsToScan[1], bagsToScan[2], bagsToScan[3], bagsToScan[4], bagsToScan[5] = 0, 1, 2, 3, 4
    if gphFrame._keyringForcedShown then
        bagsToScan[6] = -2
    else
        bagsToScan[6] = nil
    end
    -- Trim any leftover length if keyring was previously forced
    while #bagsToScan > (gphFrame._keyringForcedShown and 6 or 5) do
        bagsToScan[#bagsToScan] = nil
    end
    local aggregated, usedSlots, totalSlots = A.GetInventoryData(bagsToScan)

    -- Bag space and border color logic now uses the cached/pre-calculated values
    do
        local total = A._gphTotalSlotsCached or totalSlots
        local used = A._gphUsedSlotsCached or usedSlots
        local freeSlots = total - used
        if freeSlots <= 3 then
            gphFrame:SetBackdropBorderColor(1, 0.2, 0.2, 0.9)
        else
            gphFrame:SetBackdropBorderColor(A.GetActiveSkinBorderColor())
        end
    end

    local qualityButtons = gphFrame.qualityButtons or (header and header.qualityButtons) or content.qualityButtons
    local needRarityLayout = doChrome or not (gphFrame.qualityButtons and gphFrame.qualityButtons[0])
    local bagW, bagH = 36, 18

    -- Bag space count text: always update. Full re-anchor only on chrome / first layout.
    if gphFrame.gphBagSpaceBtn and gphFrame.gphBagSpaceBtn.fs then
        local bagText = usedSlots .. "/" .. totalSlots
        A.SafeSetText(gphFrame.gphBagSpaceBtn.fs, bagText)
        
        -- Fit bag space text in fixed 36px: shrink if needed, restore base if shorter.
        -- Always re-derive base from header settings (sticky cache fought the size slider → flicker).
        local fs = gphFrame.gphBagSpaceBtn.fs
        local font, _, flags = fs:GetFont()
        local path, headerSize
        if A.GetCategoryHeaderFontAndSize then
            path, headerSize = A.GetCategoryHeaderFontAndSize()
        end
        font = path or font or "Fonts\\FRIZQT__.TTF"
        -- Match skins.lua BagSpace: header size - 1, clamped 6..12
        local baseSize = math.min(12, math.max(6, (headerSize or 11) - 1))
        gphFrame._bagSpaceFontBase = baseSize
        fs:SetFont(font, baseSize, flags or "")
        local wantedSize = baseSize
        while wantedSize > 6 and fs:GetStringWidth() > 36 do
            wantedSize = wantedSize - 1
            fs:SetFont(font, wantedSize, flags or "")
        end

        if doChrome then
            gphFrame.gphBagSpaceBtn:SetSize(bagW, bagH)
            gphFrame.gphBagSpaceBtn:ClearAllPoints()
            gphFrame.gphBagSpaceBtn:SetPoint("TOPLEFT", headerParent, "TOPLEFT", 0, headerY)
            -- Stay just above host chrome; large absolute offsets float over the bank window.
            if A.SyncFrameChromeLevels then
                A.SyncFrameChromeLevels(gphFrame)
            elseif gphFrame.GetFrameLevel then
                local lvl = (gphFrame:GetFrameLevel() or 20) + 4
                if A.SafeSetFrameLevel then
                    A.SafeSetFrameLevel(gphFrame.gphBagSpaceBtn, lvl)
                else
                    gphFrame.gphBagSpaceBtn:SetFrameLevel(lvl)
                end
            end
            gphFrame.gphBagSpaceBtn:Show()
            table.insert(header and header.headerElements or content.headerElements, gphFrame.gphBagSpaceBtn)
        else
            gphFrame.gphBagSpaceBtn:Show()
        end
    end

    -- Rarity bar: full geometry only when chrome/missing; counts always when buttons exist.
    if needRarityLayout and A.LayoutRarityBar then
        A.LayoutRarityBar(gphFrame, headerParent, A.GPHQualBtn_OnClick)
    end
    if doChrome and headerParent and not headerParent._fugaziLayoutHooked then
        headerParent._fugaziLayoutHooked = true
        headerParent:HookScript("OnSizeChanged", function() 
            A.LayoutRarityBar(gphFrame, headerParent, A.GPHQualBtn_OnClick)
        end)
    end

    qualityButtons = gphFrame.qualityButtons or qualityButtons
    if gphFrame then
        gphFrame._gphQualityButtons = qualityButtons
    end

    if doChrome and headerParent.LayoutGPHQualityButtons then
        headerParent:LayoutGPHQualityButtons()
    end

    -- -------------------------------------------------------------------------
    -- Phase 9 paths:
    --   Grid L1: rarity from aggregate only (no working-list rebuild). Dirty slots already painted.
    --   List L1 smart: same itemId set → patch counts only, skip sort/filter/category rebuild.
    --   Else: full working-list rebuild (open, new/gone itemId, filter/search/sort chrome).
    -- -------------------------------------------------------------------------
    local smartList = false
    local destroyList = A.GetGphDestroyList and A.GetGphDestroyList() or {}

    if gphFrame.gphGridMode then
        -- Aggregated dict is enough for rarity totals (pairs + totalCount).
        if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(aggregated, gphFrame) end
        return
    end

    -- Smart only for throttled bag-content L1 (loot). Options / protect / destroy
    -- set _refreshImmediate and must rebuild destroy split + row chrome.
    if level == 1 and not immediate and CanSmartListPatch(aggregated) then
        local countsChanged = false
        for itemId, agg in pairs(aggregated) do
            local c = tonumber(agg.totalCount) or 0
            if c < 1 then c = 1 end
            if _lvSmartAggCounts[itemId] ~= c then
                countsChanged = true
                break
            end
        end
        -- Counts identical → list data/paint has nothing to do (grid already painted at top).
        -- Previously gridDirtyN>0 fell through to a full list rebuild (~40ms idle thrash).
        if not countsChanged then
            return
        end
        PatchListCountsFromAgg(workingList, aggregated)
        if gphFrame.gphCategoryDrawList then
            PatchListCountsFromAgg(gphFrame.gphCategoryDrawList, aggregated)
        end
        if gphFrame.gphCategoryItemList then
            PatchListCountsFromAgg(gphFrame.gphCategoryItemList, aggregated)
        end
        SnapshotSmartAgg(aggregated)
        -- Full-inventory rarity (not the filtered working list).
        if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(aggregated, gphFrame) end
        smartList = true
    end

    if not smartList then
    wipe(workingList)

    for _, agg in pairs(aggregated) do
        local isProtected = (A.IsItemProtectedAPI and A.IsItemProtectedAPI(agg.itemId, agg.quality)) or false
        local isWorn = (A.IsItemWorn and A.IsItemWorn(agg.itemId)) or false

        local itemRecord = A.GetRecycledInventoryTable()
        itemRecord.bag = agg.firstBag
        itemRecord.slot = agg.firstSlot
        itemRecord.link = agg.link
        itemRecord.texture = agg.texture
        -- Coerce once; mirror totalCount so rarity bar + row paint agree.
        local stackTotal = tonumber(agg.totalCount) or 0
        if stackTotal < 1 then stackTotal = 1 end
        itemRecord.count = stackTotal
        itemRecord.totalCount = stackTotal
        itemRecord.name = agg.name
        itemRecord.quality = agg.quality
        itemRecord.itemId = agg.itemId
        itemRecord.sellPrice = agg.sellPrice
        itemRecord.itemLevel = agg.itemLevel
        itemRecord.itemType = agg.itemType
        itemRecord.isProtected = (isProtected or isWorn)
        itemRecord.previouslyWorn = isWorn
        itemRecord.isEquip = agg.isEquip

        table.insert(workingList, itemRecord)
    end

    -- Full-inventory rarity before filter/search shrinks workingList.
    if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(workingList, gphFrame) end

    local sortMode = DB.gphSortMode or "category"

    -- ASCENSION NOTE: The standard GetItemInfo API on Ascension returns incorrect/base 
    -- Price and ItemLevel data for many scaled items. Sorting by these values is 
    -- chronically inaccurate and "all over the place". Disabled on Ascension until 
    -- a more reliable data source (like tooltip scanning) is implemented.
    local isAsc = A.IsAscension and A.IsAscension()

    if sortMode == "vendor" and not isAsc then
        table.sort(workingList, A.GPH_Sort_Vendor)
    elseif sortMode == "itemlevel" and not isAsc then
        table.sort(workingList, A.GPH_Sort_ItemLevel)
    else
        table.sort(workingList, A.GPH_Sort_Rarity)
    end

    -- [MODULARIZED] Special item sorting (Hearthstone/Protection) now handled in Sort.lua

    
    -- Filter Logic (Apply to workingList) — multi-quality set supported
    local filterSet = A.GetFilterQualities and A.GetFilterQualities(gphFrame) or gphFrame.gphFilterQuality
    if filterSet ~= nil then
        local filtered = _lvFilterList
        wipe(filtered)
        for _, item in ipairs(workingList) do
            local itemQ = item.quality or 0
            if A.QualityPassesFilter then
                if A.QualityPassesFilter(filterSet, itemQ) then
                    table.insert(filtered, item)
                end
            elseif type(filterSet) == "table" then
                if filterSet[itemQ] or (filterSet[4] and itemQ >= 4) then
                    table.insert(filtered, item)
                end
            elseif itemQ == filterSet or (filterSet == 4 and itemQ >= 4) then
                table.insert(filtered, item)
            end
        end
        wipe(workingList)
        for _, item in ipairs(filtered) do table.insert(workingList, item) end
    end

    
    local searchLower = (gphFrame.gphSearchText and gphFrame.gphSearchText ~= "") and gphFrame.gphSearchText:lower():match("^%s*(.-)%s*$") or nil
    if searchLower and searchLower ~= "" then
        local matched = _lvMatchList
        wipe(matched)
        for _, item in ipairs(workingList) do
            if A.Search and A.Search.Matches then
                if A.Search.Matches(item, searchLower) then table.insert(matched, item) end
            else
                if item.name and item.name:lower():find(searchLower, 1, true) then table.insert(matched, item) end
            end
        end
        wipe(workingList)
        for _, item in ipairs(matched) do table.insert(workingList, item) end
    end

    
    for did in pairs(destroyList) do
        if did ~= A.HEARTHSTONE_ID then 
            local inList = false
            for _, it in ipairs(workingList) do
                if it.itemId == did then inList = true; break end
            end
            if not inList then
                local info = destroyList[did]
                local storedName = type(info) == "table" and info.name
                local storedTex = type(info) == "table" and info.texture
                
                if info == true then
                    local n, _, _, _, _, _, _, _, _, t = A.GetCachedItemInfo(did)
                    if n or t then
                        destroyList[did] = { name = n, texture = t, addedTime = time() }
                        storedName, storedTex = n, t
                    end
                end
                local name = storedName or (A.GetCachedItemInfo and A.GetCachedItemInfo(did)) or ("Item " .. tostring(did))
                
                local addDestroyEntry = true
                if searchLower and searchLower ~= "" then
                    if A.Search and A.Search.Matches then
                        local tempItem = _lvDestroySearchTemp
                        wipe(tempItem)
                        tempItem.itemId = did
                        tempItem.link = "item:" .. did
                        tempItem.name = name
                        tempItem.quality = (A.GetCachedItemInfo and select(3, A.GetCachedItemInfo(did))) or 0
                        addDestroyEntry = A.Search.Matches(tempItem, searchLower)
                    else
                        addDestroyEntry = name and name:lower():find(searchLower, 1, true)
                    end
                end
                if addDestroyEntry then
                    local _, _, q = A.GetCachedItemInfo and A.GetCachedItemInfo(did)
                    q = q or 0
                    
                    local isProtected = A.RarityIsProtected and A.RarityIsProtected(did, q)
                    local itm = A.GetRecycledInventoryTable()
                    itm.itemId = did
                    itm.link = "item:" .. did
                    itm.name = name
                    itm.texture = storedTex or (A.GetCachedItemInfo and select(10, A.GetCachedItemInfo(did)))
                    itm.count = 0
                    itm.quality = q or 0
                    itm.sellPrice = 0
                    itm.itemLevel = (select(4, A.GetCachedItemInfo(did))) or 0
                    itm.isProtected = isProtected and true or nil
                    itm.previouslyWorn = (did and A.IsItemWorn and A.IsItemWorn(did)) and true or nil
                    itm.isDestroy = true
                    itm.addedTime = (type(info) == "table" and info.addedTime) or 0
                    itm.bag = nil
                    itm.slot = nil
                    table.insert(workingList, itm)
                end
            end
        end
    end
    
    
    local normal = _lvNormalList
    local destroyed = _lvDestroyedList
    wipe(normal)
    wipe(destroyed)
    for _, item in ipairs(workingList) do
        if item.itemId and item.itemId ~= A.HEARTHSTONE_ID and destroyList[item.itemId] then
            item.isDestroy = true
            local info = destroyList[item.itemId]
            item.addedTime = (type(info) == "table" and info.addedTime) or 0
            table.insert(destroyed, item)
        else
            table.insert(normal, item)
        end
    end
    
    table.sort(destroyed, GPH_Internal_Sort_Comparator)
    wipe(workingList)
    for _, item in ipairs(normal) do table.insert(workingList, item) end
    for _, item in ipairs(destroyed) do table.insert(workingList, item) end

    
    gphFrame.gphCategoryGroups = gphFrame.gphCategoryGroups or {}
    gphFrame.gphCategoryItemList = gphFrame.gphCategoryItemList or {}
    wipe(gphFrame.gphCategoryGroups)
    wipe(gphFrame.gphCategoryItemList)
    -- Categorization Logic (Centralized in Sort Module)
    if sortMode == "category" and #workingList > 0 and A.OrganizeBagCategories then
        -- Pass our specific pool to the sorting engine
    A.OrganizeBagCategories(workingList, gphFrame, sortMode, DB, A.GetRecycledInventoryTable)
        
        -- Throttled async retry for items that were UNKNOWN during scan
        local needsAsync = false
        for _, item in ipairs(workingList) do if item.itemType == "UNKNOWN" then needsAsync = true; break end end
        if needsAsync and not (A._gphCategoryScheduled) then
            A._gphCategoryScheduled = true
            local cf = A.gphCategoryRefreshFrame or CreateFrame("Frame")
            A.gphCategoryRefreshFrame = cf
            cf._accum = 0
            cf:SetScript("OnUpdate", function(self, elapsed)
                self._accum = (self._accum or 0) + elapsed
                if self._accum >= 2.0 then 
                    self:SetScript("OnUpdate", nil); A._gphCategoryScheduled = nil
                    if gphFrame:IsShown() and DB.gphSortMode == "category" then A.RefreshGPHUI() end
                end
            end)
        end
    else
        gphFrame.gphCategoryDrawList = nil
        if #destroyed > 0 then
            local defCollapsed = (gphFrame.gphCategoryCollapsed and gphFrame.gphCategoryCollapsed["DELETE"] ~= false)
            local draw = _lvDrawList
            wipe(draw)
            for _, item in ipairs(normal) do table.insert(draw, item) end
            -- divider entry: structural pool only (never wipe an item row table)
            local divEntry = (A.GetRecycledStructTable and A.GetRecycledStructTable())
                or (A.GetRecycledInventoryTable and A.GetRecycledInventoryTable())
                or {}
            divEntry.divider = "DELETE"
            divEntry.collapsed = defCollapsed
            table.insert(draw, divEntry)
            if not defCollapsed then for _, item in ipairs(destroyed) do table.insert(draw, item) end end
            gphFrame.gphCategoryDrawList = draw
        end
    end

    SnapshotSmartAgg(aggregated)
    end -- not smartList

    local yOff = 4  
    gphFrame.gphHomebaseRowY = yOff

    local listToUse = gphFrame.gphCategoryDrawList or workingList
    local listForAdvance = gphFrame.gphCategoryItemList or workingList

    if #workingList == 0 then
        if gphFrame.gphCategoryDividerPool then for _, d in ipairs(gphFrame.gphCategoryDividerPool) do d:Hide() end end
        if A.ResetGPHTextPool then A.ResetGPHTextPool() end
        if A.ResetGPHItemPool then A.ResetGPHItemPool() end
        local noItems = A.GetGPHText(content)
        noItems:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -yOff)
        noItems:SetText("")
        
        if gphFrame then
            gphFrame.gphSelectedItemId = nil
            gphFrame.gphSelectedBag = nil
            gphFrame.gphSelectedSlot = nil
            gphFrame.gphSelectedRowBtn = nil
            gphFrame.gphSelectedItemLink = nil
        end
    else
        gphFrame._gphPrevDefaultScrollY = gphFrame.gphDefaultScrollY
        gphFrame.gphDefaultScrollY = nil  
        local selectedStillExists = false
        local selectedRowBtn = nil  
        local hadSelectedItemId = gphFrame and gphFrame.gphSelectedItemId ~= nil
        local itemIdToSlot = A.GetItemIdToBagSlot()
        gphFrame._gphIdToSlotMap = itemIdToSlot 
        
        local itemIdx = 0
        local dividerClickHandler = function(self)
            if not gphFrame.gphCategoryCollapsed then gphFrame.gphCategoryCollapsed = {} end
            local cat = self.categoryName
            local isCollapsed = (cat == "DELETE") and (gphFrame.gphCategoryCollapsed["DELETE"] ~= false) or gphFrame.gphCategoryCollapsed[cat]
            gphFrame.gphCategoryCollapsed[cat] = not isCollapsed
            if A.RefreshGPHUI then A.RefreshGPHUI() end
        end

        gphFrame._gphDivIdx = 0
        local GPH_ITEM_POOL = A.GetGPHItemPool and A.GetGPHItemPool()
        local new_GPH_ITEM_POOL_USED = 0
        
        if gphFrame.gphHearthSpacerFrame then gphFrame.gphHearthSpacerFrame:Hide() end
        
        for idx, entry in ipairs(listToUse) do
            local newY, isDiv = A.GPH_RenderCategoryDivider(gphFrame, content, entry, yOff, dividerClickHandler)
            if isDiv then
                yOff = newY
            elseif entry.divider then
                -- Skip hidden headers
            else
                itemIdx = (gphFrame.gphCategoryDrawList and (itemIdx + 1)) or idx
                local item = entry
                if gphFrame then
                    gphFrame.gphItemIndexToY = gphFrame.gphItemIndexToY or {}
                    gphFrame.gphItemIndexToY[itemIdx] = yOff
                end
            
                local curHearth = item.itemId == A.HEARTHSTONE_ID or (item.link and item.link:match("item:" .. A.HEARTHSTONE_ID))
                local rowBelowDivider = false
                if curHearth then
                    if not gphFrame.gphHearthSpacerFrame then
                        local frame = CreateFrame("Frame", nil, content)
                        frame:EnableMouse(false)
                        local tex = frame:CreateTexture(nil, "ARTWORK")
                        tex:SetTexture(0.5, 0.42, 0.18, 0.75)
                        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
                        tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -4)
                        tex:SetHeight(1)
                        tex:Show()
                        frame.tex = tex
                        gphFrame.gphHearthSpacerFrame = frame
                        gphFrame.gphHearthSpacerFrame._gphDebugName = "HearthstoneSpacer"
                        gphFrame.gphHearthSpacerTex = tex
                    end
                    local spacer = gphFrame.gphHearthSpacerFrame
                    spacer:SetParent(content)
                    if spacer._gphCurrentYOff ~= yOff then
                        spacer:ClearAllPoints()
                        spacer:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
                        spacer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -yOff)
                        spacer:SetHeight(10)
                        spacer._gphCurrentYOff = yOff
                    end
                    spacer:Show()
                    if spacer.tex then spacer.tex:SetHeight(1); spacer.tex:Show() end
                    yOff = yOff + 10
                    if gphFrame.gphDefaultScrollY == nil then
                        gphFrame.gphDefaultScrollY = yOff  
                    end
                    rowBelowDivider = true
                end
                
                -- DELTA RENDER INVENTORY ROW
                new_GPH_ITEM_POOL_USED = new_GPH_ITEM_POOL_USED + 1
                
                local btn = GPH_ITEM_POOL and GPH_ITEM_POOL[new_GPH_ITEM_POOL_USED]
                if not btn then
                    if A.SetGPHItemPoolUsed then A.SetGPHItemPoolUsed(new_GPH_ITEM_POOL_USED - 1) end
                    btn = A.GetGPHItemBtn(content)
                else
                    -- Keep _visualState for early-out. Count is painted before early-out in
                    -- FillListRowVisuals; wiping state every loot forced full name re-anchor
                    -- (truncation flicker) and blank→repaint count jitter.
                    local wasHidden = not btn:IsShown()
                    if btn:GetParent() ~= content then btn:SetParent(content) end
                    if wasHidden then
                        btn:Show()
                        btn._gphCurrentYOff = nil
                        btn._gphCurrentWidth = nil
                    elseif not btn:IsShown() then
                        btn:Show()
                    end
                end
                
                if btn._gphCurrentYOff ~= yOff then
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
                    btn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -yOff)
                    btn._gphCurrentYOff = yOff
                end
                
                local rowOk, rowErr = pcall(A.UpdateGPHRowVisuals, btn, item, new_GPH_ITEM_POOL_USED, yOff, rowBelowDivider, destroyList, gphFrame, itemIdToSlot, true)
                if rowOk then
                    local capturedId = item.itemId or (item.link and tonumber(item.link:match("item:(%d+)")))
                    local isSelected = gphFrame and (
                        (item.bag ~= nil and item.slot ~= nil and gphFrame.gphSelectedBag == item.bag and gphFrame.gphSelectedSlot == item.slot)
                        or (item.bag == nil and gphFrame.gphSelectedItemId and capturedId == gphFrame.gphSelectedItemId)
                        or (gphFrame.gphSelectedIndex and gphFrame.gphSelectedIndex == itemIdx)
                    )
                    if isSelected then
                        selectedStillExists = true
                        selectedRowBtn = btn
                        gphFrame.gphSelectedIndex = itemIdx
                        gphFrame.gphSelectedRowY = yOff
                        gphFrame.gphSelectedBag = item.bag
                        gphFrame.gphSelectedSlot = item.slot
                    end
                end
                
                local rowStep = A.ComputeItemDetailsRowHeight(18)
                yOff = yOff + rowStep
            end
        end
        
        -- HIDE LEFTOVERS (Garbage Collection)
        if GPH_ITEM_POOL then
            for i = new_GPH_ITEM_POOL_USED + 1, #GPH_ITEM_POOL do
                if GPH_ITEM_POOL[i] then GPH_ITEM_POOL[i]:Hide() end
            end
        end
        
        if gphFrame.gphCategoryDividerPool then
            for i = gphFrame._gphDivIdx + 1, #gphFrame.gphCategoryDividerPool do
                if gphFrame.gphCategoryDividerPool[i] then gphFrame.gphCategoryDividerPool[i]:Hide() end
            end
        end
        
        if A.SetGPHItemPoolUsed then A.SetGPHItemPoolUsed(new_GPH_ITEM_POOL_USED) end
        
        if gphFrame and not selectedStillExists and hadSelectedItemId then
            local nextIdx = gphFrame.gphSelectedIndex and math.min(gphFrame.gphSelectedIndex, #listForAdvance) or 1
            local nextItem = listForAdvance[nextIdx]
            if nextItem and nextItem.link then
                local nextId = tonumber(nextItem.link:match("item:(%d+)"))
                if nextId then
                    gphFrame.gphSelectedItemId = nextId
                    gphFrame.gphSelectedIndex = nextIdx
                    gphFrame.gphSelectedRowBtn = nil  
                    
                    
                    local oldRowY = gphFrame.gphSelectedRowY
                    local idxToY = gphFrame.gphItemIndexToY
                    local oldScroll = gphFrame.gphScrollOffset or 0
                    if oldRowY and idxToY and idxToY[nextIdx] then
                        local newRowY = idxToY[nextIdx]
                        local wantScroll = newRowY - oldRowY + oldScroll
                        
                        if oldRowY <= 40 then
                            gphFrame.gphScrollToRowYOnLayout = 0
                        
                        elseif math.abs(wantScroll - oldScroll) > 80 then
                            gphFrame.gphScrollToRowYOnLayout = nil  
                        else
                            gphFrame.gphScrollToRowYOnLayout = wantScroll
                        end
                    end
                    
                    local df = A._gphSelectionDeferFrame
					if df then
						df:Show()
						df:SetScript("OnUpdate", function(self)
							self:SetScript("OnUpdate", nil)
							self:Hide()
							if A.RefreshGPHUI then A.RefreshGPHUI() end
						end)
					end
                else
                    gphFrame.gphSelectedItemId = nil
                    gphFrame.gphSelectedIndex = nil
                    gphFrame.gphSelectedItemLink = nil
                end
            else
                gphFrame.gphSelectedItemId = nil
                gphFrame.gphSelectedIndex = nil
                gphFrame.gphSelectedItemLink = nil
            end
        end
        if gphFrame and selectedRowBtn and gphFrame.gphSelectedItemId then
            gphFrame.gphSelectedRowBtn = selectedRowBtn
        end
    end

    yOff = yOff + 8
    
    local viewHeight = gphFrame.scrollFrame and gphFrame.scrollFrame:GetHeight() or 0
    local fillerHeight = 0
    if gphFrame.gphDefaultScrollY and viewHeight > 0 then
        fillerHeight = math.max(0, gphFrame.gphDefaultScrollY + viewHeight - yOff)
    end
    if fillerHeight > 0 then
        if not gphFrame.gphBottomSpacer then
            local spacer = CreateFrame("Frame", nil, content)
            spacer:EnableMouse(false)
            spacer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
            gphFrame.gphBottomSpacer = spacer
            gphFrame.gphBottomSpacer._gphDebugName = "BottomSpacer"
        end
        local spacer = gphFrame.gphBottomSpacer
        spacer:SetParent(content)
        spacer:ClearAllPoints()
        spacer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
        local sfW_spacer = gphFrame.scrollFrame and gphFrame.scrollFrame:GetWidth() or 340
        spacer:SetSize(sfW_spacer, fillerHeight)
        spacer:Show()
    elseif gphFrame.gphBottomSpacer then
        gphFrame.gphBottomSpacer:Hide()
    end
    content:SetHeight(yOff + fillerHeight)
    
        if gphFrame.gphScrollBar then
            viewHeight = gphFrame.scrollFrame:GetHeight()
            local contentHeight = content:GetHeight()
            local maxScroll = math.max(0, contentHeight - viewHeight)
            local cur = gphFrame.gphScrollOffset or 0
            
            
            if gphFrame.gphScrollToDefaultOnNextRefresh then
                if gphFrame.gphDefaultScrollY and maxScroll > 0 then
                    cur = math.min(gphFrame.gphDefaultScrollY, maxScroll)
                    gphFrame.gphScrollToDefaultOnNextRefresh = nil
                    gphFrame._gphHomebaseRetryScheduled = nil  
                    gphFrame._pendingScrollToDefault = cur
                elseif maxScroll == 0 and gphFrame.gphDefaultScrollY then
                    
                    cur = 0
                    if not gphFrame._gphHomebaseRetryScheduled then
                        gphFrame._gphHomebaseRetryScheduled = true
                        local retryFrame = A._gphHomebaseRetryFrame
                        if not retryFrame then
                            retryFrame = CreateFrame("Frame")
                            A._gphHomebaseRetryFrame = retryFrame
                        end
                        retryFrame:SetScript("OnUpdate", function(self)
                            self:SetScript("OnUpdate", nil)
                            self:Hide()
                            if gphFrame and gphFrame.gphScrollToDefaultOnNextRefresh and RefreshGPHUI then
                                gphFrame._refreshImmediate = true
                                A.RefreshGPHUI()
                            end
                        end)
                        retryFrame:Show()
                    end
                else
                    cur = 0
                    gphFrame.gphScrollToDefaultOnNextRefresh = nil
                end
            end
            
            if gphFrame.gphScrollToRowYOnLayout then
                cur = math.max(0, math.min(maxScroll, gphFrame.gphScrollToRowYOnLayout))
                gphFrame.gphScrollToRowYOnLayout = nil
            end
            
            
            do
                local prevDefault = gphFrame._gphPrevDefaultScrollY
                local newDefault = gphFrame.gphDefaultScrollY
                if prevDefault and newDefault
                   and not gphFrame.gphScrollToDefaultOnNextRefresh
                   and not gphFrame.gphScrollToRowYOnLayout then
                    local diff = cur - prevDefault
                    if diff < 0 then diff = -diff end
                    -- Snap to homebase if we are very close, OR if homebase moved and we were previously anchored.
                    local anchored = (diff < 5)
                    local threshold = 20
                    if anchored or (diff <= threshold and prevDefault ~= newDefault) then
                        cur = math.max(0, math.min(maxScroll, newDefault))
                    end
                end
            end
            if cur > maxScroll then cur = maxScroll end
        gphFrame.gphScrollOffset = cur
        -- Only touch scrollbar when range/value actually change (avoids thumb jitter every loot).
        local prevMax = gphFrame._gphScrollMax
        local prevCur = gphFrame._gphScrollBarCur
        if prevMax ~= maxScroll or prevCur ~= cur then
            gphFrame.gphScrollBar:SetMinMaxValues(0, maxScroll)
            gphFrame.gphScrollBar:SetValue(cur)
            gphFrame._gphScrollMax = maxScroll
            gphFrame._gphScrollBarCur = cur
        end
    end
    
    local sf = gphFrame.scrollFrame
    local scrollChild = sf and sf:GetScrollChild()
    if scrollChild and scrollChild == content then
        local wantOff = gphFrame.gphScrollOffset or 0
        local wantW = gphFrame.gphDynContentWidth or sfW or 340
        if gphFrame._scrollChildOffset ~= wantOff or gphFrame._scrollChildW ~= wantW then
            scrollChild:ClearAllPoints()
            scrollChild:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, wantOff)
            if scrollChild:GetWidth() ~= wantW then
                scrollChild:SetWidth(wantW)
            end
            gphFrame._scrollChildOffset = wantOff
            gphFrame._scrollChildW = wantW
        end
    end
    end)  
    
    if refreshOk and gphFrame and gphFrame._pendingScrollToDefault ~= nil then
        if not gphFrame._scrollCorrectionFrame then
            gphFrame._scrollCorrectionFrame = CreateFrame("Frame")
            gphFrame._scrollCorrectionFrame:Hide()
            gphFrame._scrollCorrectionFrame:SetScript("OnUpdate", function(self)
                self:Hide()
                local f = self._target
                local wantCur = self._wantCur
                if not (f and f.gphScrollBar and f.scrollFrame) then return end
                if f.gphGridMode then return end
                local content = f.scrollFrame:GetScrollChild()
                local viewHeight = f.scrollFrame:GetHeight()
                local contentHeight = content and content:GetHeight() or 0
                local maxScroll = math.max(0, contentHeight - viewHeight)
                local cur = math.min(wantCur, maxScroll)
                f.gphScrollOffset = cur
                f.gphScrollBar:SetMinMaxValues(0, maxScroll)
                f.gphScrollBar:SetValue(cur)
                if content then
                    content:ClearAllPoints()
                    content:SetPoint("TOPLEFT", f.scrollFrame, "TOPLEFT", 0, cur)
                    content:SetWidth(f.gphDynContentWidth or 340)
                end
                f._pendingScrollToDefault = nil
            end)
        end
        gphFrame._scrollCorrectionFrame._target = gphFrame
        gphFrame._scrollCorrectionFrame._wantCur = gphFrame._pendingScrollToDefault
        gphFrame._scrollCorrectionFrame:Show()
    end

    -- Cleanup unused pool frames (Hides what was not used this refresh)
    if A.CleanupGPHPools then A.CleanupGPHPools() end
    
    -- Tooltip Sync: Ensure tooltips don't stay hidden or stale after a refresh.
    local focus = (GetMouseFocus and GetMouseFocus())
    
    if focus and focus:IsShown() then
        local isFugazi, p = false, focus
        for i = 1, 6 do -- Verify ownership 
            if p == gphFrame or p == gphFrame.content then isFugazi = true; break end
            p = p:GetParent(); if not p then break end
        end
        if isFugazi then
            local onEnter = focus.GetScript and focus:GetScript("OnEnter")
            if onEnter then pcall(onEnter, focus) end
        end
    end
    
    gphFrame._lastRefreshGPHUI = (GetTime and GetTime()) or time()

end


--- Dropdown menu for the Inventory frame (title bar right-click).
--- (GPHTitleMenu_Initialize moved to Options.lua)


-------------------------------------------------------------------------------
-- Inventory bag-event bus — PRIMARY inv UI path (Phase 6.5 sole owner).
--
--   Listview: BAG_UPDATE / DELAYED / CLOSED / lock / money → Wipe + schedule RefreshGPHUI
--   Core:     DE locks, destroyer scan, item-info/transmog backup only (no bag UI pending)
--   Bankview: bank bags only; ForceBankDataRescan stays here-not-Core
--   Grid:     paints dirty slots when RefreshGPHUI/RefreshSlots runs
--
-- Dirty only the bag that changed (Phase 1). Nil bag → player 0–4 L1, never idle L3 FULL.
-------------------------------------------------------------------------------
local _gphEventFrame = CreateFrame("Frame")
_gphEventFrame:RegisterEvent("BAG_UPDATE")
_gphEventFrame:RegisterEvent("BAG_UPDATE_DELAYED") -- was Core-only; Listview owns inv UI fully
_gphEventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
_gphEventFrame:RegisterEvent("PLAYER_MONEY")
-- UNIT_INVENTORY_CHANGED removed: equipment flicker (stale refresh ~350ms before BAG_UPDATE).
_gphEventFrame:RegisterEvent("BAG_CLOSED")

-- Track bag capacity so equip/swap of a bag container still forces a full rescan.
local _gphLastBagNumSlots = {}

-- Phase 9: AOE mass-loot coalesce — trailing quiet window + max wait so a 60-mob
-- pet dump becomes one (or few) RefreshGPHUI instead of one-per-BAG_UPDATE next-frame.
local BAG_BURST_QUIET = 0.10   -- seconds of no bag events before paint
local BAG_BURST_MAX = 0.22     -- never wait longer than this from first event in a burst
local _burstQuietAcc = 0
local _burstFirstAt = nil
local _burstForceSoon = false  -- capacity / chrome: next frame, no quiet wait

local _gphEventDeferFrame = CreateFrame("Frame")
_gphEventDeferFrame:Hide()
_gphEventDeferFrame:SetScript("OnUpdate", function(self, elapsed)
    _burstQuietAcc = (_burstQuietAcc or 0) + (elapsed or 0)
    local now = (GetTime and GetTime()) or 0
    local age = _burstFirstAt and (now - _burstFirstAt) or 0
    if not _burstForceSoon then
        if _burstQuietAcc < BAG_BURST_QUIET and age < BAG_BURST_MAX then
            return
        end
    end
    self:Hide()
    _burstQuietAcc = 0
    _burstFirstAt = nil
    _burstForceSoon = false
    local inv = A.Inventory
    if inv and inv:IsVisible() then
        -- Default bag-event path is L1 content (no negotiate/skin). Capacity may have promoted to L3.
        if A.PromoteGPHRefreshLevel then A.PromoteGPHRefreshLevel(1) end
        if _G.RefreshGPHUI then _G.RefreshGPHUI() end
    elseif _G.gphSession and A.DiffBagsGPH then
        -- Bags closed: still advance the session ledger (no full UI paint).
        A.DiffBagsGPH()
    end
end)

local function ScheduleInvRefresh(forceSoon)
    if forceSoon then _burstForceSoon = true end
    if not _gphEventDeferFrame:IsShown() then
        _burstFirstAt = (GetTime and GetTime()) or 0
        _burstQuietAcc = 0
        _gphEventDeferFrame:Show()
    else
        -- Another bag event in the flurry: reset quiet clock (trailing edge).
        _burstQuietAcc = 0
    end
end

--- True for bag container IDs we care about (backpack, bags, bank, keyring).
local function isBagContainerId(bag)
    return type(bag) == "number" and bag >= -2 and bag <= 11
end

--- Player inventory bags only (this listener owns inv UI, not bank).
local function isPlayerInvBag(bag)
    return type(bag) == "number" and ((bag >= 0 and bag <= 4) or bag == -2)
end

_gphEventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    local wantChrome = false
    local scheduleInv = true

    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        local bag = arg1
        if bag ~= nil and isBagContainerId(bag) then
            local n = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
            local prev = _gphLastBagNumSlots[bag]
            _gphLastBagNumSlots[bag] = n

            -- Bank bags: Bankview owns. Inv rebuild on bank BAG_UPDATE = double flicker.
            if not isPlayerInvBag(bag) then
                scheduleInv = false
            else
                -- Capacity change (equip/unequip/swap bag) → full dirty + L3 chrome.
                if prev ~= nil and prev ~= n then
                    if A.WipeBagLinkCache then A.WipeBagLinkCache(nil) end
                    wantChrome = true
                else
                    -- Soft-dirty single bag (client also fires DELAYED(bag) on the ~20s idle
                    -- pulse; hard wipe forced dirtyBags=1 + L1 after bare NOOP).
                    local any = true
                    if A.DirtyBagsIfContentsChanged then
                        any = A.DirtyBagsIfContentsChanged({ bag })
                    elseif A.WipeBagLinkCache then
                        A.WipeBagLinkCache(bag)
                    end
                    if not any then
                        scheduleInv = false
                    end
                end
            end
        else
            -- Nil/unknown: soft-dirty player bags (never L3). Client fires bare BAG_UPDATE
            -- ~every 20s with no content change — hard wipe caused idle L1 thrash.
            local any = true
            if A.DirtyBagsIfContentsChanged then
                any = A.DirtyBagsIfContentsChanged({ 0, 1, 2, 3, 4 })
            elseif A.WipeBagLinkCache then
                for b = 0, 4 do A.WipeBagLinkCache(b) end
            else
                A._gphDirtyBags = A._gphDirtyBags or {}
                for b = 0, 4 do A._gphDirtyBags[b] = true end
            end
            wantChrome = false
            if not any then
                scheduleInv = false
            end
        end

    elseif event == "BAG_CLOSED" then
        -- Bag container closed/unequipped — slot count may change (player bags matter for inv).
        local bag = arg1
        if bag ~= nil and isBagContainerId(bag) then
            _gphLastBagNumSlots[bag] = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
            if isPlayerInvBag(bag) then
                if A.WipeBagLinkCache then A.WipeBagLinkCache(bag) end
                A._gphBagSpaceDirty = true
                wantChrome = true
            else
                scheduleInv = false
            end
        else
            if A.WipeBagLinkCache then A.WipeBagLinkCache(nil) end
            wantChrome = true
        end

    elseif event == "ITEM_LOCK_CHANGED" then
        -- Lock alone does not change aggregates / counts. Full list rebuild here flickered
        -- twice during bank moves (lock + bag). Grid still needs a dirty paint.
        local bag, slot = arg1, arg2
        if bag ~= nil and slot ~= nil and isBagContainerId(bag) then
            if A.MarkGridSlotDirty then A.MarkGridSlotDirty(bag, slot) end
            if isPlayerInvBag(bag) then
                local inv = A.Inventory
                if inv and inv:IsShown() and inv.gphGridMode then
                    -- Grid: paint lock state only (L1). List skips — no lock-only chrome.
                    scheduleInv = true
                else
                    scheduleInv = false
                end
            else
                scheduleInv = false
            end
        else
            -- Worn-equipment lock; not inv bag contents.
            scheduleInv = false
        end

    elseif event == "PLAYER_MONEY" then
        -- Money does not change bag contents — skip inv rebuild.
        -- GPH status bar listens on its own PLAYER_MONEY handler for live total/raw.
        scheduleInv = false
    end

    if not scheduleInv then
        -- Drop a pending idle burst only when nothing is dirty (don't cancel real loot).
        local anyDirty = false
        if A._gphDirtyBags then
            for _, v in pairs(A._gphDirtyBags) do
                if v then anyDirty = true; break end
            end
        end
        if not anyDirty and not A._gphBagSpaceDirty and _gphEventDeferFrame:IsShown() then
            _gphEventDeferFrame:Hide()
            _burstQuietAcc = 0
            _burstFirstAt = nil
            _burstForceSoon = false
        end
        return
    end

    if wantChrome and A.PromoteGPHRefreshLevel then
        A.PromoteGPHRefreshLevel(3)
    end

    -- Phase 9: coalesce bag-event flurry (AOE loot). Chrome/capacity paints next frame.
    -- Dirty flags still control how heavy GetInventoryData is once we run.
    ScheduleInvRefresh(wantChrome)
end)

-- Global Export
_G.RefreshGPHUI = A.RefreshGPHUI
_G.FugaziBAGS_RefreshGPHUI = A.RefreshGPHUI
