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
            if inv.gphDestroyBtn then inv.gphDestroyBtn:SetScale(total) end
            
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

function A.RefreshGPHUI()
    local gphFrame = A.Inventory
    if not gphFrame then return end
    
    if A.RefreshGPHBagRow then A.RefreshGPHBagRow(gphFrame) end
    local DB = _G.FugaziBAGSDB or {}
    local gphSession = _G.gphSession
    
    local now = (GetTime and GetTime()) or time()
    local immediate = gphFrame._refreshImmediate
    gphFrame._refreshImmediate = nil

    -- Improved Throttling: Ensure we don't drop the last update in a burst.
    if not immediate and gphFrame._lastRefreshGPHUI and (now - gphFrame._lastRefreshGPHUI) < 0.1 then
        if not gphFrame._refreshGPHScheduler then
            gphFrame._refreshGPHScheduler = CreateFrame("Frame", nil, gphFrame)
            gphFrame._refreshGPHScheduler:Hide()
            gphFrame._refreshGPHScheduler:SetScript("OnUpdate", function(self, elapsed)
                self._timer = (self._timer or 0) + elapsed
                if self._timer >= 0.1 then
                    self._timer = 0
                    self:Hide()
                    if A.RefreshGPHUI then A.RefreshGPHUI() end
                end
            end)
        end
        gphFrame._refreshGPHScheduler._timer = 0
        gphFrame._refreshGPHScheduler:Show() -- Start/Reset trailing edge timer
        return
    end
    gphFrame._lastRefreshGPHUI = now
    if gphFrame._refreshGPHScheduler then gphFrame._refreshGPHScheduler:Hide() end
    
    if A.DiffBagsGPH then
        A.DiffBagsGPH()
    end
    
    local inCombat = InCombatLockdown and InCombatLockdown()
    if not inCombat then
        if gphFrame.NegotiateSizes then gphFrame:NegotiateSizes() end
    end
    
    if gphFrame.gphGridMode and _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then
        _G.FugaziBAGS_CombatGrid.RefreshSlots()
    end
    

    if gphFrame.gphTitle and Skins and Skins.ApplyGphInventoryTitle then Skins.ApplyGphInventoryTitle(gphFrame.gphTitle) end
    
    if not inCombat then
        if gphFrame.UpdateGphTitleBarButtonLayout then gphFrame:UpdateGphTitleBarButtonLayout() end
        if gphFrame.UpdateGPHProfessionButtons then gphFrame:UpdateGPHProfessionButtons() end
        if gphFrame.UpdateGPHButtonVisibility then gphFrame:UpdateGPHButtonVisibility() end
    end
    if Skins and Skins.ApplyGPHFrameSkin then Skins.ApplyGPHFrameSkin(gphFrame) end
    if gphFrame.ApplySkin then gphFrame:ApplySkin() end
    if _G.UpdateSortIcon then _G.UpdateSortIcon() end
    
    if not gphFrame.gphGridMode then
        if A.ResetGPHPools then A.ResetGPHPools() end
    end
    
    A.ResetGPHDataPools()

    

    local refreshOk, refreshErr = pcall(function()
    local content = gphFrame.content
    local sf = gphFrame.scrollFrame
    if sf and content then
        local sfW = sf:GetWidth()
        if not sfW or sfW < 50 then sfW = 340 end
        content:SetWidth(sfW)
        gphFrame.gphDynContentWidth = sfW
    end

    local header = gphFrame.gphHeader
    local now = time()
    local nowGph = GetTime and GetTime() or time()  

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
    -- Status text is now handled by the Master Clock in f.MasterUpdate for optimal combat performance.
    -- We only hide it here if the Instance Tracker is not loaded.
    if not IsAddOnLoaded("__FugaziInstanceTracker") then
        gphFrame.statusText:Hide()
    end

    
    local header = gphFrame.gphHeader
    local headerY = 0
    local xOffset = 0
    local headerParent = header or content

    A.pendingQuality = A.pendingQuality or {}
    for q = 0, 5 do
        if A.pendingQuality[q] and (nowGph - A.pendingQuality[q]) > 5 then
            A.pendingQuality[q] = nil
        end
    end

    if gphFrame.gphItemIndexToY then wipe(gphFrame.gphItemIndexToY) end
    if A.ScanBags then A.ScanBags() end
	
    -- 1. Setup collections (Localized to prevent Zombie memory leaks)
    local workingList = {} -- This is our master list for this refresh
    
    local aggregated = {}
	
    local typeCache = DB.gphItemTypeCache or {}
    DB.gphItemTypeCache = typeCache
    local aggregated, usedSlots, totalSlots = A.GetInventoryData({0, 1, 2, 3, 4})

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

    for _, agg in pairs(aggregated) do
        local isProtected = (A.IsItemProtectedAPI and A.IsItemProtectedAPI(agg.itemId, agg.quality)) or false
        local isWorn = (A.IsItemWorn and A.IsItemWorn(agg.itemId)) or false

        local itemRecord = A.GetRecycledInventoryTable()
        itemRecord.bag = agg.firstBag
        itemRecord.slot = agg.firstSlot
        itemRecord.link = agg.link
        itemRecord.texture = agg.texture
        itemRecord.count = agg.totalCount
        itemRecord.name = agg.name
        itemRecord.quality = agg.quality
        itemRecord.itemId = agg.itemId
        itemRecord.sellPrice = agg.sellPrice
        itemRecord.itemLevel = agg.itemLevel
        itemRecord.itemType = agg.itemType
        itemRecord.isProtected = (isProtected or isWorn)
        itemRecord.previouslyWorn = isWorn

        table.insert(workingList, itemRecord)
    end
    
    -- Update rarity bar counts from the fresh working list (Unified in Sort.lua)
	if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(workingList, gphFrame) end
    
    
    
    

    local qualityButtons = (header and header.qualityButtons) or content.qualityButtons
    if not qualityButtons then
        if header then header.qualityButtons = {} else content.qualityButtons = {} end
        qualityButtons = header and header.qualityButtons or content.qualityButtons
    end

    
    local headerW = headerParent and headerParent:GetWidth() or content:GetWidth() or 300
    local rightEdgeGap = 4  
    local qualityRight = headerW - rightEdgeGap
    local leftPad = 0  
    local bagGap = 12  
    local spacing = 4  
    local numRarityBtns = 5
    local ROW_H = 18 
    local bagW, bagH = 36, 18

    
    local startX = leftPad + bagW + bagGap
    local rarityTotalW = qualityRight - startX
    local slotWidth = math.floor((rarityTotalW - spacing * (numRarityBtns - 1)) / numRarityBtns)
    if slotWidth < 10 then slotWidth = 10 end

    
    if gphFrame.gphBagSpaceBtn and gphFrame.gphBagSpaceBtn.fs then
        local bagText = usedSlots .. "/" .. totalSlots
        A.SafeSetText(gphFrame.gphBagSpaceBtn.fs, bagText)
        
        local SV = _G.FugaziBAGSDB
        if SV and SV.gphCategoryHeaderFontCustom then
            local path = A.GetCategoryHeaderFontAndSize()
            gphFrame.gphBagSpaceBtn.fs:SetFont(path, 10, "")
        else
            gphFrame.gphBagSpaceBtn.fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
        end
        gphFrame.gphBagSpaceBtn:SetSize(bagW, bagH)
        gphFrame.gphBagSpaceBtn:ClearAllPoints()
        
        gphFrame.gphBagSpaceBtn:SetPoint("TOPLEFT", headerParent, "TOPLEFT", 0, headerY)
        
        -- Redundant gphSep anchoring removed to prevent circular dependency







        if headerParent and headerParent.GetFrameLevel then
            gphFrame.gphBagSpaceBtn:SetFrameLevel(headerParent:GetFrameLevel() + 20)
        end
        gphFrame.gphBagSpaceBtn:Show()
        table.insert(header and header.headerElements or content.headerElements, gphFrame.gphBagSpaceBtn)
    end

    -- Shared Rarity Bar Layout (Inventory)
    A.LayoutRarityBar(gphFrame, headerParent, A.GPHQualBtn_OnClick)
        
    -- Layout is now handled by LayoutRarityBar and OnSizeChanged hooks inside it.
    if headerParent and not headerParent._fugaziLayoutHooked then
        headerParent._fugaziLayoutHooked = true
        headerParent:HookScript("OnSizeChanged", function() 
            A.LayoutRarityBar(gphFrame, headerParent, A.GPHQualBtn_OnClick)
        end)
    end

    
    if gphFrame then
        gphFrame._gphQualityButtons = qualityButtons

    end

    if headerParent.LayoutGPHQualityButtons then
        headerParent:LayoutGPHQualityButtons()
    end

    
    

    
    if gphFrame.gphGridMode then return end

    local yOff = 4  
    gphFrame.gphHomebaseRowY = yOff
    local sortMode = DB.gphSortMode or "rarity"

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

    
    -- Filter Logic (Apply to workingList)
    if gphFrame.gphFilterQuality ~= nil then
        local q = gphFrame.gphFilterQuality
        local filtered = {}
        for _, item in ipairs(workingList) do
            local itemQ = item.quality or 0
            if itemQ == q or (q == 4 and itemQ >= 4) then
                table.insert(filtered, item)
            end
        end
        wipe(workingList)
        for _, item in ipairs(filtered) do table.insert(workingList, item) end
    end

    
    local searchLower = (gphFrame.gphSearchText and gphFrame.gphSearchText ~= "") and gphFrame.gphSearchText:lower():match("^%s*(.-)%s*$") or nil
    if searchLower and searchLower ~= "" then
        local matched = {}
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

    
    local destroyList = A.GetGphDestroyList and A.GetGphDestroyList() or {}
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
                        local tempItem = { itemId = did, link = "item:"..did, name = name, quality = (A.GetCachedItemInfo and select(3, A.GetCachedItemInfo(did))) or 0 }
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
    
    
    local normal = {}
    local destroyed = {}
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
            local draw = {}
            for _, item in ipairs(normal) do table.insert(draw, item) end
            table.insert(draw, { divider = "DELETE", collapsed = defCollapsed })
            if not defCollapsed then for _, item in ipairs(destroyed) do table.insert(draw, item) end end
            gphFrame.gphCategoryDrawList = draw
        end
    end

    if gphFrame.gphCategoryDividerPool then for _, d in ipairs(gphFrame.gphCategoryDividerPool) do d:Hide() end end
    if #workingList == 0 then
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
        if gphFrame.gphCategoryDividerPool then for _, d in ipairs(gphFrame.gphCategoryDividerPool) do d:Hide() end end
        if gphFrame.gphHearthSpacerTex then gphFrame.gphHearthSpacerTex:Hide() end
        if gphFrame.gphHearthSpacerFrame then gphFrame.gphHearthSpacerFrame:Hide() end
        
        gphFrame._gphPrevDefaultScrollY = gphFrame.gphDefaultScrollY
        gphFrame.gphDefaultScrollY = nil  
        local selectedStillExists = false
        local selectedRowBtn = nil  
        local hadSelectedItemId = gphFrame and gphFrame.gphSelectedItemId ~= nil
        local itemIdToSlot = A.GetItemIdToBagSlot()
        gphFrame._gphIdToSlotMap = itemIdToSlot 
        local listToUse = gphFrame.gphCategoryDrawList or workingList
        local listForAdvance = gphFrame.gphCategoryItemList or workingList
        local itemIdx = 0
        local dividerIndex = 0
        local dividerClickHandler = function(self)
            if not gphFrame.gphCategoryCollapsed then gphFrame.gphCategoryCollapsed = {} end
            local cat = self.categoryName
            local isCollapsed = (cat == "DELETE") and (gphFrame.gphCategoryCollapsed["DELETE"] ~= false) or gphFrame.gphCategoryCollapsed[cat]
            gphFrame.gphCategoryCollapsed[cat] = not isCollapsed
            if A.RefreshGPHUI then A.RefreshGPHUI() end
        end

        gphFrame._gphDivIdx = 0
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
                spacer:ClearAllPoints()
                spacer:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
                spacer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -yOff)
                spacer:SetHeight(10)
                spacer:Show()
                if spacer.tex then spacer.tex:SetHeight(1); spacer.tex:Show() end
                yOff = yOff + 10
                if gphFrame.gphDefaultScrollY == nil then
                    gphFrame.gphDefaultScrollY = yOff  
                end
                rowBelowDivider = true
            end
            local btn = A.GetGPHItemBtn(content)
            local rowOk, rowErr = pcall(A.UpdateGPHRowVisuals, btn, item, itemIdx, yOff, rowBelowDivider, destroyList, gphFrame, itemIdToSlot)
            
            if rowOk then
                -- Formatting like icon size and font is already applied in UpdateGPHRowVisuals
                -- but we should ensure isSelected is handled correctly for the visual feedback.
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
            else
                A.AddonPrint("[Fugazi] GPH row " .. tostring(itemIdx) .. " error: " .. tostring(rowErr))
            end
            
            local rowStep = A.ComputeItemDetailsRowHeight(18)
            yOff = yOff + rowStep
            end
        end
        
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
        gphFrame.gphScrollBar:SetMinMaxValues(0, maxScroll)
        gphFrame.gphScrollBar:SetValue(cur)
    end
    
    local sf = gphFrame.scrollFrame
    local scrollChild = sf and sf:GetScrollChild()
    if scrollChild and scrollChild == content then
        scrollChild:ClearAllPoints()
        scrollChild:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, gphFrame.gphScrollOffset or 0)
        scrollChild:SetWidth(gphFrame.gphDynContentWidth or sfW or 340)
    end
    end)  
    if not refreshOk then
        A.AddonPrint("[Fugazi] GPH refresh error: " .. tostring(refreshErr))
    end
    
    
    if refreshOk and gphFrame and gphFrame._pendingScrollToDefault ~= nil then
        local wantCur = gphFrame._pendingScrollToDefault
        local f = gphFrame
        C_Timer.After(0.01, function()
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
    A._gphIsCleaningBuffer = GetTime()
end


--- Dropdown menu for the Inventory frame (title bar right-click).
--- (GPHTitleMenu_Initialize moved to Options.lua)


-------------------------------------------------------------------------------
-- Event Listener: BAG_UPDATE etc to trigger RefreshGPHUI.
-------------------------------------------------------------------------------
local _gphEventFrame = CreateFrame("Frame")
_gphEventFrame:RegisterEvent("BAG_UPDATE")
_gphEventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
_gphEventFrame:RegisterEvent("PLAYER_MONEY")
_gphEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
_gphEventFrame:RegisterEvent("BAG_CLOSED")

_gphEventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_MONEY" then
        if _G.RefreshGPHUI then _G.RefreshGPHUI() end
        return
    end
    
    if event == "BAG_UPDATE" then
        if A.WipeBagLinkCache then A.WipeBagLinkCache(arg1) end
    end
    
    -- Throttled Refresh
    A._gphBagSpaceDirty = true
    if _G.RefreshGPHUI then _G.RefreshGPHUI() end
end)

-- Global Export
_G.RefreshGPHUI = A.RefreshGPHUI
_G.FugaziBAGS_RefreshGPHUI = A.RefreshGPHUI
