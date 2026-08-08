local addonName, L = ...

----------------------------------------------------------------------
-- DETAIL DATA LAYER
-- Pure data for one run index. UI reads this table; no frames here.
----------------------------------------------------------------------
L.DetailData = L.DetailData or {}

function L.DetailData.GetRunDetails(runIndex)
    local history = _G.InstanceTrackerDB and _G.InstanceTrackerDB.runHistory or {}
    local page = runIndex or 1
    if page < 1 then page = 1 end
    if page > #history then page = math.max(1, #history) end

    local run = history[page]
    if not run then return nil end

    local dur = run.duration or 0
    local dateStr = ""
    if run.enterTime and L.FormatDateTime then
        dateStr = L.FormatDateTime(run.enterTime) or ""
    end

    local qcText = (L.FormatQualityCounts and L.FormatQualityCounts(run.qualityCounts, run.items)) or ""
    if qcText == "" or qcText == "|cff555555-|r" then
        qcText = "|cff888888No items|r"
    end

    -- Stamped at record time by BAGS (GPH stop) / dungeon FinalizeRun — no FIT re-valuation.
    local rawGold = run.goldCopper or 0
    local vendorItems = run.vendorValue or 0
    local auctionItems = run.ahValue or 0
    local destroyItems = run.destroyValue or 0
    local estTotal = run.estimatedValueCopper or (rawGold + vendorItems + auctionItems + destroyItems)
    local estGPH = run.estimatedGPHCopper or 0
    if (not run.estimatedGPHCopper) and dur > 0 then
        estGPH = math.floor(estTotal / (dur / 3600))
    end

    return {
        page = page,
        run = run,
        characterName = (run.characterName and run.characterName ~= "") and run.characterName or "Run details",
        runName = (L.GetRunDisplayName and L.GetRunDisplayName(run)) or (run.name or "?"),
        duration = dur,
        dateStr = dateStr,
        qcText = qcText,
        rawGold = rawGold,
        vendorItems = vendorItems,
        auctionItems = auctionItems,
        destroyItems = destroyItems,
        estTotal = estTotal,
        estGPH = estGPH,
        repairs = run.repairCount or 0,
        repairCopper = run.repairCopper or 0,
        deaths = run.deaths or 0,
        autodel = run.itemsAutodeleted or 0,
        autodelCopper = run.autodeletedVendorCopper or 0,
    }
end

----------------------------------------------------------------------
-- DETAIL UI POOLS
----------------------------------------------------------------------
L.DETAIL_ROW_POOL, L.DETAIL_ROW_POOL_USED = {}, 0
L.DETAIL_TEXT_POOL, L.DETAIL_TEXT_POOL_USED = {}, 0

function L.ResetDetailPools()
    for i = 1, L.DETAIL_ROW_POOL_USED do
        local row = L.DETAIL_ROW_POOL[i]
        if row then
            row:Hide()
            row:EnableMouse(false)
            row:SetScript("OnMouseUp", nil)
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row.runRef = nil
            if row.clickArea then
                row.clickArea:Hide()
                row.clickArea:EnableMouse(false)
                row.clickArea:SetScript("OnClick", nil)
                row.clickArea:SetScript("OnEnter", nil)
                row.clickArea:SetScript("OnLeave", nil)
            end
        end
    end
    L.DETAIL_ROW_POOL_USED = 0
    for i = 1, L.DETAIL_TEXT_POOL_USED do
        if L.DETAIL_TEXT_POOL[i] then L.DETAIL_TEXT_POOL[i]:Hide() end
    end
    L.DETAIL_TEXT_POOL_USED = 0
end

----------------------------------------------------------------------
-- DETAIL ROW FACTORIES
----------------------------------------------------------------------
function L.GetDetailText(parent)
    L.DETAIL_TEXT_POOL_USED = L.DETAIL_TEXT_POOL_USED + 1
    local fs = L.DETAIL_TEXT_POOL[L.DETAIL_TEXT_POOL_USED]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        L.DETAIL_TEXT_POOL[L.DETAIL_TEXT_POOL_USED] = fs
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:Show()
    fs:SetText("")
    fs:SetWidth((L.SCROLL_CONTENT_WIDTH or 296) - 24)
    fs:SetWordWrap(false)
    local fontSettings = L.GetFugaziFontSettings and L.GetFugaziFontSettings() or nil
    if fontSettings then
        local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
        if rowFont and fontSettings.rowSize then
            fs:SetFont(rowFont, fontSettings.rowSize, "")
        end
    end
    return fs
end

function L.GetDetailRow(parent)
    L.DETAIL_ROW_POOL_USED = L.DETAIL_ROW_POOL_USED + 1
    local row = L.DETAIL_ROW_POOL[L.DETAIL_ROW_POOL_USED]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetWidth(L.SCROLL_CONTENT_WIDTH or 296)
        row:SetHeight(L.GetFugaziRowHeight and L.GetFugaziRowHeight(18) or 18)
        -- Fixed right block so labels never collide with gold values.
        local rightBlockW = 100
        local left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        left:SetPoint("LEFT", row, "LEFT", 0, 0)
        left:SetPoint("RIGHT", row, "RIGHT", -rightBlockW - 8, 0)
        left:SetJustifyH("LEFT")
        left:SetWordWrap(false)
        row.left = left
        local right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        right:SetJustifyH("RIGHT")
        right:SetWidth(rightBlockW)
        right:SetWordWrap(false)
        row.right = right
        -- BAGS-style full-row Button hit target (Frame alone is flaky on 3.3.5)
        local clickArea = CreateFrame("Button", nil, row)
        clickArea:SetAllPoints(row)
        clickArea:EnableMouse(true)
        clickArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickArea:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
        local hl = clickArea:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        hl:SetVertexColor(1, 1, 1, 0.12)
        clickArea.highlight = hl
        row.clickArea = clickArea
        row.highlight = hl
        L.DETAIL_ROW_POOL[L.DETAIL_ROW_POOL_USED] = row
    end
    if not row.clickArea then
        local clickArea = CreateFrame("Button", nil, row)
        clickArea:SetAllPoints(row)
        clickArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local hl = clickArea:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        hl:SetVertexColor(1, 1, 1, 0.12)
        clickArea.highlight = hl
        row.clickArea = clickArea
        row.highlight = hl
    end
    row:SetParent(parent)
    row:Show()
    local fontSettings = L.GetFugaziFontSettings and L.GetFugaziFontSettings() or nil
    if fontSettings then
        local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
        local h = L.GetFugaziRowHeight and L.GetFugaziRowHeight(18) or 18
        row:SetHeight(h)
        if rowFont and fontSettings.rowSize then
            row.left:SetFont(rowFont, fontSettings.rowSize, "")
            row.right:SetFont(rowFont, fontSettings.rowSize, "")
        end
    end
    row.left:SetText("")
    row.right:SetText("")
    row.runRef = nil
    row:EnableMouse(false)
    row:SetScript("OnMouseUp", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row.left:SetPoint("LEFT", row, "LEFT", 0, 0)
    local ca = row.clickArea
    ca:ClearAllPoints()
    ca:SetAllPoints(row)
    ca:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
    ca:EnableMouse(false)
    ca:Hide()
    ca:SetScript("OnClick", nil)
    ca:SetScript("OnEnter", nil)
    ca:SetScript("OnLeave", nil)
    return row
end

----------------------------------------------------------------------
-- DETAIL FRAME
----------------------------------------------------------------------
function L.CreateLedgerDetailFrame()
    local f = CreateFrame("Frame", "InstanceTrackerLedgerDetailFrame", UIParent)
    f:SetWidth(340)
    f:SetHeight(400)
    f:SetPoint("TOP", UIParent, "CENTER", 0, 0)

    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:SetFrameStrata("DIALOG")
    f.detailPage = 1

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("Run details")
    title:SetTextColor(1, 0.85, 0.4, 1)

    f.itTitleBar = titleBar
    f.itTitleText = title

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local scrollFrame = CreateFrame("ScrollFrame", "InstanceTrackerLedgerDetailScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(L.SCROLL_CONTENT_WIDTH or 296)
    content:SetHeight(1)
    content:EnableMouse(true)
    scrollFrame:SetScrollChild(content)
    f.content = content
    f.scrollFrame = scrollFrame

    f.ApplySkin = function()
        if L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(f) end
    end
    if L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(f) end

    return f
end

----------------------------------------------------------------------
-- REFRESH HELPERS (local)
----------------------------------------------------------------------
local detailHoverIdx = 0

--- Truncate value for display; tooltip when truncated or tooltipLine set.
local function MaybeTruncateDetail(fs, fullText, rowY, rowH, maxChars, tooltipLine, content)
    if not fs or not content then return end
    local strip = L.StripColorCodes
    local valuePlain = (strip and strip(fullText or "")) or (fullText or "")
    local limit = maxChars or L.LEDGER_STAT_MAX_CHARS or 30
    local needsTruncate = #valuePlain > limit
    if needsTruncate then
        if L.TruncateWithColors then
            fs:SetText(L.TruncateWithColors(fullText or "", limit))
        else
            fs:SetText(valuePlain:sub(1, math.max(0, limit - 3)) .. "...")
        end
    end

    if not needsTruncate and not tooltipLine then return end

    detailHoverIdx = detailHoverIdx + 1
    content._detailHoverFrames = content._detailHoverFrames or {}
    local hf = content._detailHoverFrames[detailHoverIdx]
    if not hf then
        hf = CreateFrame("Frame", nil, content)
        hf:EnableMouse(true)
        hf:SetScript("OnEnter", function(self)
            if self._fullText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self._fullText, 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        hf:SetScript("OnLeave", function() GameTooltip:Hide() end)
        content._detailHoverFrames[detailHoverIdx] = hf
    end

    local tooltipPlain = tooltipLine and ((strip and strip(tooltipLine)) or tooltipLine) or valuePlain
    hf._fullText = tooltipPlain
    hf:ClearAllPoints()
    local w = (L.SCROLL_CONTENT_WIDTH or 296) - 8
    hf:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -rowY)
    hf:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", w, -(rowY + rowH))
    hf:Show()
end

local function LabelText(label)
    if L.ColorizeFugaziRowLabel then
        return L.ColorizeFugaziRowLabel(label)
    end
    return label
end

--- Update Ledger "Run X of Y" + Prev/Next visibility for current realm runs.
local function UpdateDetailNavLabel(page)
    local stats = L.statsFrame
    if not stats or not stats.detailNavPageLabel then return end

    local history = _G.InstanceTrackerDB and _G.InstanceTrackerDB.runHistory or {}
    local currentRealm = (GetRealmName and GetRealmName()) or ""
    local totalRealmRuns = 0
    local ordinal = 0
    for i, r in ipairs(history) do
        if not r.realmName or r.realmName == currentRealm then
            totalRealmRuns = totalRealmRuns + 1
            if i == page then
                ordinal = totalRealmRuns
            end
        end
    end

    if totalRealmRuns == 0 then
        stats.detailNavPageLabel:SetText("-")
        if stats.detailNavPrevBtn then stats.detailNavPrevBtn:Hide() end
        if stats.detailNavNextBtn then stats.detailNavNextBtn:Hide() end
        return
    end

    if ordinal == 0 then ordinal = 1 end
    stats.detailNavPageLabel:SetText("Run " .. ordinal .. " of " .. totalRealmRuns)
    if stats.detailNavPrevBtn then
        if ordinal > 1 then stats.detailNavPrevBtn:Show() else stats.detailNavPrevBtn:Hide() end
    end
    if stats.detailNavNextBtn then
        if ordinal < totalRealmRuns then stats.detailNavNextBtn:Show() else stats.detailNavNextBtn:Hide() end
    end
end

----------------------------------------------------------------------
-- REFRESH + SHOW
----------------------------------------------------------------------
L.RefreshLedgerDetailUI = function(forceRebuild)
    if not L.ledgerDetailFrame then return end
    if not forceRebuild and not L.ledgerDetailFrame:IsShown() then return end

    L.ResetDetailPools()
    if L.ledgerDetailFrame.scrollFrame then
        L.ledgerDetailFrame.scrollFrame:SetVerticalScroll(0)
    end

    local content = L.ledgerDetailFrame.content
    content._detailHoverFrames = content._detailHoverFrames or {}
    for _, hf in ipairs(content._detailHoverFrames) do
        if hf then hf:Hide() end
    end
    detailHoverIdx = 0

    local yOff = 6
    local leftPad = L.CONTENT_LEFT_PAD or 4
    local lineH = (L.GetFugaziRowHeight and L.GetFugaziRowHeight(18)) or 18
    local rowGap = 4
    local sectionGap = 8

    local details = L.DetailData.GetRunDetails(L.ledgerDetailFrame.detailPage)
    if not details then
        local noRun = L.GetDetailText(content)
        noRun:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, -yOff)
        noRun:SetText("|cff888888No run at this index.|r")
        content:SetHeight(24)
        UpdateDetailNavLabel(L.ledgerDetailFrame.detailPage or 1)
        return
    end

    L.ledgerDetailFrame.detailPage = details.page
    if L.ledgerDetailFrame.itTitleText then
        L.ledgerDetailFrame.itTitleText:SetText(details.characterName)
    end

    local goldFunc = L.FormatGold or tostring
    local plainGoldFunc = L.FormatGoldPlain or tostring

    local valueLens = (L.FilterBar and L.FilterBar.GetField and L.FilterBar.GetField("lens")) or "raw"
    local function lensHi(key)
        return L.FilterBar and L.FilterBar.LensHighlights and L.FilterBar.LensHighlights(key, valueLens)
    end
    local HI = "|cff88ff88"

    local function MakeDetailStatRow(y, label, valStr, tooltipText, maxChars, hi)
        local r = L.GetDetailRow(content)
        r:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, -y)
        local leftT = hi and (HI .. label .. "|r") or LabelText(label)
        local rightT = valStr or ""
        if hi and rightT ~= "" and not rightT:find("|cff88ff88", 1, true) then
            rightT = HI .. rightT .. "|r"
        end
        local strip = L.StripColorCodes
        local tt = tooltipText
        if not tt then
            local leftPlain = strip and strip(leftT or "") or (leftT or "")
            local valPlain = strip and strip(valStr or "") or (valStr or "")
            tt = leftPlain .. "  " .. valPlain
        end
        if L.LayoutLeftRightTexts then
            L.LayoutLeftRightTexts(r, r.left, r.right, leftT, rightT, { leftPad = 0, rightPad = 4 })
            MaybeTruncateDetail(r.left, leftT, y, lineH, maxChars or 40, tt, content)
        else
            r.left:SetText(leftT)
            r.right:SetText(rightT)
            MaybeTruncateDetail(r.right, rightT, y, lineH, maxChars or 16, tt, content)
        end
        return y + lineH + rowGap
    end

    -- Run name (click to rename) — full-row clickArea like BAGS listview
    local nameRow = L.GetDetailRow(content)
    nameRow:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, -yOff)
    nameRow.runRef = details.run
    nameRow.left:SetText(details.runName)
    nameRow.right:SetText("")
    if L.StyleFugaziHeader then L.StyleFugaziHeader(nameRow.left) end
    -- No MaybeTruncateDetail hover frame here: it would sit on content and steal the row clickArea.
    if L.BindRowClickArea then
        L.BindRowClickArea(nameRow, function(self, button)
            if button ~= "LeftButton" then return end
            if L.PlayUIClickSound then L.PlayUIClickSound() end
            if self.runRef then
                StaticPopup_Show("INSTANCETRACKER_RENAME_RUN", nil, nil, self.runRef)
            end
        end, function(self)
            GameTooltip:SetOwner(self.clickArea or self, "ANCHOR_CURSOR")
            GameTooltip:AddLine("Click to rename", 0.5, 0.8, 1)
            GameTooltip:Show()
        end, function() GameTooltip:Hide() end)
    end
    yOff = yOff + lineH + rowGap

    -- Duration + date
    local durText = "|cffffffff"
        .. ((L.FormatTimeMedium and L.FormatTimeMedium(details.duration)) or tostring(details.duration))
        .. "|r"
    if details.dateStr ~= "" then
        durText = durText .. "  |cff666666" .. details.dateStr .. "|r"
    end
    yOff = MakeDetailStatRow(yOff, "Duration:", durText, nil, L.LEDGER_STAT_MAX_CHARS)
    yOff = yOff + 4

    -- Items gained (click opens item list; lens filters items when Items is open)
    local rItems = L.GetDetailRow(content)
    rItems:SetPoint("TOPLEFT", content, "TOPLEFT", leftPad, -yOff)
    local itemsLbl = "Items gained:"
    local filterLens = (valueLens == "vendor" or valueLens == "ah" or valueLens == "destroy")
    if filterLens then
        itemsLbl = HI .. "Items (" .. ((L.FilterBar.LensShort and L.FilterBar.LensShort(valueLens)) or valueLens) .. "):|r"
        rItems.left:SetText(itemsLbl)
    else
        rItems.left:SetText(LabelText(itemsLbl))
    end
    rItems.right:SetText(details.qcText)
    rItems.runRef = details.run
    if L.BindRowClickArea then
        L.BindRowClickArea(rItems, function(self, button)
            if button ~= "LeftButton" then return end
            if L.PlayUIClickSound then L.PlayUIClickSound() end
            if self.runRef and L.ShowItemDetail then
                L.ShowItemDetail(self.runRef)
            end
        end, function(self)
            GameTooltip:SetOwner(self.clickArea or self, "ANCHOR_CURSOR")
            if filterLens then
                GameTooltip:AddLine("Click: items for " .. ((L.FilterBar.LensLabel and L.FilterBar.LensLabel(valueLens)) or valueLens), 0.5, 0.9, 0.5)
            else
                GameTooltip:AddLine("Click to view items", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end, function() GameTooltip:Hide() end)
    end
    yOff = yOff + lineH + sectionGap

    -- Valuations (green = active value lens)
    yOff = MakeDetailStatRow(yOff, "Raw gold:", goldFunc(details.rawGold), nil, nil, lensHi("raw"))
    yOff = MakeDetailStatRow(yOff, "Vendor value:", goldFunc(details.vendorItems), nil, nil, lensHi("vendor"))
    yOff = MakeDetailStatRow(yOff, "Auction value:", goldFunc(details.auctionItems), nil, nil, lensHi("ah"))
    yOff = MakeDetailStatRow(yOff, "Destroy value:", goldFunc(details.destroyItems), nil, nil, lensHi("destroy"))
    yOff = yOff + sectionGap

    -- Estimations
    yOff = MakeDetailStatRow(yOff, "Estimated gold/hour:", goldFunc(details.estGPH) .. "/h", nil, nil, lensHi("gph"))
    yOff = MakeDetailStatRow(yOff, "Total estimated value:", goldFunc(details.estTotal), nil, nil, lensHi("est"))
    yOff = yOff + sectionGap

    -- Misc
    yOff = MakeDetailStatRow(
        yOff,
        "Repairs:",
        details.repairs .. " repairs, " .. goldFunc(details.repairCopper),
        nil,
        L.LEDGER_STAT_MAX_CHARS
    )
    yOff = MakeDetailStatRow(
        yOff,
        "Deaths:",
        "|cffcc6666" .. details.deaths .. "|r",
        nil,
        L.LEDGER_STAT_MAX_CHARS
    )
    local autodelStr = string.format("%d items, %s lost", details.autodel, plainGoldFunc(details.autodelCopper))
    yOff = MakeDetailStatRow(yOff, "Items autodeleted:", autodelStr, nil, L.LEDGER_STAT_MAX_CHARS)

    yOff = yOff + sectionGap
    content:SetHeight(yOff)

    UpdateDetailNavLabel(details.page)
end

--- Highlight the Ledger history row for the open detail page (no full list rebuild).
local function SyncLedgerRowHighlight(detailPage)
    local used = L.STATS_ROW_POOL_USED or 0
    local pool = L.STATS_ROW_POOL
    if not pool or used < 1 then return end
    for i = 1, used do
        local row = pool[i]
        if row and row.selectedBg then
            if detailPage and row.gotoPage == detailPage then
                row.selectedBg:Show()
            else
                row.selectedBg:Hide()
            end
        end
    end
end

--- If Item Details is already open, retarget it to the same run as Run Details.
local function SyncOpenItemDetail(run)
    if not run or not L.ShowItemDetail then return end
    local itemFrame = _G.InstanceTrackerItemDetailFrame
    if itemFrame and itemFrame:IsShown() then
        L.ShowItemDetail(run)
    end
end

function _G.ShowLedgerDetail(runIndex)
    if not L.statsFrame then return end
    if not L.ledgerDetailFrame then
        L.ledgerDetailFrame = L.CreateLedgerDetailFrame()
    end
    L.ledgerDetailFrame:ClearAllPoints()
    L.ledgerDetailFrame:SetPoint("TOPLEFT", L.statsFrame, "TOPRIGHT", 4, 0)
    L.ledgerDetailFrame:SetWidth(L.statsFrame:GetWidth())
    L.ledgerDetailFrame:SetHeight(L.statsFrame:GetHeight())
    L.ledgerDetailFrame.detailPage = runIndex or 1
    L.ledgerDetailFrame:Show()
    L.RefreshLedgerDetailUI()

    -- Keep the three windows (Ledger / Run details / Items) on the same run.
    -- Prev/Next already did this; plain row clicks only opened details before.
    local page = L.ledgerDetailFrame.detailPage
    SyncLedgerRowHighlight(page)
    local history = _G.InstanceTrackerDB and _G.InstanceTrackerDB.runHistory or {}
    SyncOpenItemDetail(history[page])
end

L.ShowLedgerDetail = _G.ShowLedgerDetail
