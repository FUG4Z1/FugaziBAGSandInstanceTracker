local addonName, L = ...

----------------------------------------------------------------------
-- Shared UI kit: object pools and row/text factories.
-- Domain windows live in Cap / Ledger / Items / RunDetails.
----------------------------------------------------------------------

----------------------------------------------------------------------
-- UI: Object pools (wrapped in do block to stay under Lua 5.1 limit of 200 locals per function)
----------------------------------------------------------------------
do
    L.ROW_POOL, L.ROW_POOL_USED = {}, 0
    L.TEXT_POOL, L.TEXT_POOL_USED = {}, 0
    L.STATS_ROW_POOL, L.STATS_ROW_POOL_USED = {}, 0
    L.STATS_TEXT_POOL, L.STATS_TEXT_POOL_USED = {}, 0

    L.ResetPools = function()
    for i = 1, L.ROW_POOL_USED do
        if L.ROW_POOL[i] then
            L.ROW_POOL[i]:Hide()
            if L.ROW_POOL[i].deleteBtn then L.ROW_POOL[i].deleteBtn:Hide() end
        end
    end
    L.ROW_POOL_USED = 0
    for i = 1, L.TEXT_POOL_USED do if L.TEXT_POOL[i] then L.TEXT_POOL[i]:Hide() end end
    L.TEXT_POOL_USED = 0
    end

    --- Ledger row/text pools: we reuse the same row and text frames instead of creating new ones each refresh (avoids memory leak and keeps UI snappy).
    L.ResetStatsPools = function()
    for i = 1, L.STATS_ROW_POOL_USED do
        local r = L.STATS_ROW_POOL[i]
        if r then
            r:Hide()
            r:EnableMouse(false)
            r:SetScript("OnUpdate", nil)
            r.gotoPage = nil
            r.runRef = nil
            if r.pendingDeleteBg then r.pendingDeleteBg:Hide() end
            if r.selectedBg then r.selectedBg:Hide() end
            if r.clickArea then
                r.clickArea:Hide()
                r.clickArea:EnableMouse(false)
                r.clickArea:SetScript("OnClick", nil)
                r.clickArea:SetScript("OnEnter", nil)
                r.clickArea:SetScript("OnLeave", nil)
            end
            if r.deleteBtn then
                r.deleteBtn:Hide()
                r.deleteBtn:EnableMouse(false)
            end
        end
    end
    L.STATS_ROW_POOL_USED = 0
    if L.ClearPendingRunDelete then L.ClearPendingRunDelete() end
    for i = 1, L.STATS_TEXT_POOL_USED do
        if L.STATS_TEXT_POOL[i] then L.STATS_TEXT_POOL[i]:SetText(""); L.STATS_TEXT_POOL[i]:Hide() end
    end
    L.STATS_TEXT_POOL_USED = 0
    L.ResetTopItemRowPool()
    end

    L.GetRow = function(parent, showDelete)
    L.ROW_POOL_USED = L.ROW_POOL_USED + 1
    local row = L.ROW_POOL[L.ROW_POOL_USED]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetWidth(L.SCROLL_CONTENT_WIDTH)
        row:SetHeight(16)
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:EnableMouse(true)
        delBtn:SetHitRectInsets(0, 0, 0, 0)
        delBtn:SetWidth(14)
        delBtn:SetHeight(14)
        delBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
        delBtn:SetNormalFontObject(GameFontNormalSmall)
        delBtn:SetHighlightFontObject(GameFontHighlightSmall)
        delBtn:SetText("|cffff4444x|r")
        delBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        delBtn:SetScript("OnEnter", function(self)
            self:SetText("|cffff8888x|r")
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:AddLine("Remove this entry", 1, 0.4, 0.4)
            GameTooltip:Show()
        end)
        delBtn:SetScript("OnLeave", function(self)
            self:SetText("|cffff4444x|r")
            GameTooltip:Hide()
        end)
        row.deleteBtn = delBtn
        local left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        left:SetPoint("LEFT", delBtn, "RIGHT", 2, 0)
        left:SetJustifyH("LEFT")
        row.left = left
        local right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        right:SetJustifyH("RIGHT")
        row.right = right
        L.ROW_POOL[L.ROW_POOL_USED] = row
    end
    row:SetParent(parent)
    row:Show()
    
    local fontSettings = L.GetFugaziFontSettings()
    local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
    local rh = fontSettings.rowSize and (fontSettings.rowSize + 4) or 16
    row:SetHeight(rh)
    row.left:SetFont(rowFont, fontSettings.rowSize, "")
    row.right:SetFont(rowFont, fontSettings.rowSize, "")
    
    row.left:SetText("")
    row.right:SetText("")
    if showDelete then
        row.deleteBtn:Show()
        row.deleteBtn:EnableMouse(true)
        row.deleteBtn:SetText("|cffff4444x|r")
        row.left:ClearAllPoints()
        row.left:SetPoint("LEFT", row.deleteBtn, "RIGHT", 2, 0)
    else
        -- Fully suppress delete control so a recycled row never leaves a red "x" under text
        row.deleteBtn:Hide()
        row.deleteBtn:EnableMouse(false)
        row.deleteBtn:SetText("")
        row.left:ClearAllPoints()
        row.left:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    return row
    end

    L.GetText = function(parent)
    L.TEXT_POOL_USED = L.TEXT_POOL_USED + 1
    local fs = L.TEXT_POOL[L.TEXT_POOL_USED]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        L.TEXT_POOL[L.TEXT_POOL_USED] = fs
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:Show()
    fs:SetText("")
    return fs
    end

    --- Same pattern as __FugaziBAGS list rows: full-size Button clickArea.
    --- Textures for select/delete stay on the row (under fontstrings); clickArea is a transparent hit Button on top.
    local function EnsureStatsRowClickArea(row)
        if row.clickArea then return row.clickArea end
        local clickArea = CreateFrame("Button", nil, row)
        clickArea:SetAllPoints(row)
        clickArea:EnableMouse(true)
        clickArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        clickArea:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
        -- Soft hover wash (HIGHLIGHT layer is tracked by the Button mouse region)
        local hl = clickArea:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        hl:SetVertexColor(1, 1, 1, 0.12)
        clickArea.highlight = hl
        row.clickArea = clickArea
        row.highlight = hl
        return clickArea
    end

    L.GetStatsRow = function(parent, withDelete, isTwoLine)
    L.STATS_ROW_POOL_USED = L.STATS_ROW_POOL_USED + 1
    local row = L.STATS_ROW_POOL[L.STATS_ROW_POOL_USED]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetWidth(L.SCROLL_CONTENT_WIDTH)
        row:SetHeight(L.GetFugaziRowHeight(16))

        -- Selection / arm tints on the row so they sit under OVERLAY fontstrings
        local selBg = row:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        selBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        selBg:SetVertexColor(0.22, 0.42, 0.18, 0.55)
        selBg:Hide()
        row.selectedBg = selBg
        local pendBg = row:CreateTexture(nil, "BORDER")
        pendBg:SetAllPoints()
        pendBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        pendBg:SetVertexColor(0.9, 0.12, 0.1, 0.55)
        pendBg:Hide()
        row.pendingDeleteBg = pendBg

        -- Delete button (created once, shown when needed)
        local delBtn = CreateFrame("Button", nil, row)
        delBtn:EnableMouse(true)
        delBtn:SetHitRectInsets(0, 0, 0, 0)
        delBtn:SetWidth(14)
        delBtn:SetHeight(14)
        delBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
        delBtn:SetNormalFontObject(GameFontNormalSmall)
        delBtn:SetHighlightFontObject(GameFontHighlightSmall)
        delBtn:SetText("|cffff4444x|r")
        delBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        delBtn:SetScript("OnEnter", function(self)
            self:SetText("|cffff8888x|r")
            L.AnchorTooltipRight(self)
            GameTooltip:AddLine("Remove this run", 1, 0.4, 0.4)
            GameTooltip:Show()
        end)
        delBtn:SetScript("OnLeave", function(self)
            self:SetText("|cffff4444x|r")
            GameTooltip:Hide()
        end)
        row.deleteBtn = delBtn

        local left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        left:SetPoint("LEFT", delBtn, "RIGHT", 2, 0)
        left:SetJustifyH("LEFT")
        row.left = left
        local right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        right:SetJustifyH("RIGHT")
        row.right = right
        
        local subLeft = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subLeft:SetPoint("BOTTOMLEFT", delBtn, "BOTTOMRIGHT", 2, 0)
        subLeft:SetJustifyH("LEFT")
        row.subLeft = subLeft
        local subRight = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
        subRight:SetJustifyH("RIGHT")
        row.subRight = subRight

        EnsureStatsRowClickArea(row)
        delBtn:SetFrameLevel((row.clickArea:GetFrameLevel() or 1) + 2)

        L.STATS_ROW_POOL[L.STATS_ROW_POOL_USED] = row
    end
    row:SetParent(parent)
    row:Show()
    if not row.selectedBg then
        local selBg = row:CreateTexture(nil, "BACKGROUND")
        selBg:SetAllPoints()
        selBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        selBg:SetVertexColor(0.22, 0.42, 0.18, 0.55)
        selBg:Hide()
        row.selectedBg = selBg
    end
    if not row.pendingDeleteBg then
        local pendBg = row:CreateTexture(nil, "BORDER")
        pendBg:SetAllPoints()
        pendBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        pendBg:SetVertexColor(0.9, 0.12, 0.1, 0.55)
        pendBg:Hide()
        row.pendingDeleteBg = pendBg
    end
    local clickArea = EnsureStatsRowClickArea(row)
    if clickArea.highlight then row.highlight = clickArea.highlight end

    local fontSettings = L.GetFugaziFontSettings()
    local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
    
    if isTwoLine then
        row:SetHeight(math.max(26, fontSettings.rowSize * 2.2 + 2))
        local leftOff = withDelete and 16 or 4
        row.left:ClearAllPoints()
        row.left:SetPoint("TOPLEFT", row, "TOPLEFT", leftOff, -2)
        row.right:ClearAllPoints()
        row.right:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -2)
        row.subLeft:ClearAllPoints()
        row.subLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", leftOff, 2)
        row.subRight:ClearAllPoints()
        row.subRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 2)
        row.subLeft:Show()
        row.subRight:Show()
    else
        row:SetHeight(L.GetFugaziRowHeight(16))
        local leftOff = withDelete and 16 or 4
        row.left:ClearAllPoints()
        row.left:SetPoint("LEFT", row, "LEFT", leftOff, 0)
        row.right:ClearAllPoints()
        row.right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.subLeft:Hide()
        row.subRight:Hide()
    end

    -- Full-row hit target (BAGS-style): pin after height is known
    clickArea:ClearAllPoints()
    clickArea:SetAllPoints(row)
    clickArea:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
    clickArea:EnableMouse(false)
    clickArea:Hide()
    clickArea:SetScript("OnClick", nil)
    clickArea:SetScript("OnEnter", nil)
    clickArea:SetScript("OnLeave", nil)
    clickArea:SetScript("OnMouseUp", nil)
    
    row.left:SetFont(rowFont, fontSettings.rowSize, "")
    row.right:SetFont(rowFont, fontSettings.rowSize, "")
    local subSize = math.max(8, fontSettings.rowSize - 2)
    row.subLeft:SetFont(rowFont, subSize, "")
    row.subRight:SetFont(rowFont, subSize, "")
    
    row.left:SetText("")
    row.right:SetText("")
    row.subLeft:SetText("")
    row.subRight:SetText("")
    if row.selectedBg then row.selectedBg:Hide() end
    if row.pendingDeleteBg then row.pendingDeleteBg:Hide() end
    row:SetScript("OnUpdate", nil)
    row.gotoPage = nil
    row.runRef = nil
    row:EnableMouse(false)
    row:SetScript("OnMouseUp", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:SetWidth(L.SCROLL_CONTENT_WIDTH or 296)
    row:SetHitRectInsets(0, 0, 0, 0)

    if withDelete then
        row.deleteBtn:Show()
        row.deleteBtn:EnableMouse(true)
        row.deleteBtn:SetFrameLevel((clickArea:GetFrameLevel() or 1) + 2)
    else
        row.deleteBtn:Hide()
        row.deleteBtn:EnableMouse(false)
    end
    return row
    end

    L.GetStatsText = function(parent)
    L.STATS_TEXT_POOL_USED = L.STATS_TEXT_POOL_USED + 1
    local fs = L.STATS_TEXT_POOL[L.STATS_TEXT_POOL_USED]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        L.STATS_TEXT_POOL[L.STATS_TEXT_POOL_USED] = fs
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:Show()
    fs:SetText("")
    local fontSettings = L.GetFugaziFontSettings()
    local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
    fs:SetFont(rowFont, fontSettings.rowSize, "")
    return fs
    end

    --- Pool of 10 row frames for "Top autodeleted" / "Top autosold" (item name with rarity+link+tooltip, count+gold with full-amount tooltip).
    L.TOP_ITEM_ROW_POOL, L.TOP_ITEM_ROW_POOL_USED = {}, 0
    L.ResetTopItemRowPool = function()
    for i = 1, L.TOP_ITEM_ROW_POOL_USED do
        local row = L.TOP_ITEM_ROW_POOL[i]
        if row then
            row:Hide()
            if row.itemBtn then row.itemBtn:EnableMouse(false) end
            if row.goldHover then row.goldHover:EnableMouse(false) end
        end
    end
    L.TOP_ITEM_ROW_POOL_USED = 0
    end
    L.GetTopItemRow = function(parent, fontSettings, rowH, rightMargin, rightBlockW)
    L.TOP_ITEM_ROW_POOL_USED = L.TOP_ITEM_ROW_POOL_USED + 1
    local row = L.TOP_ITEM_ROW_POOL[L.TOP_ITEM_ROW_POOL_USED]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetHeight(rowH)
        row:EnableMouse(false)
        local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
        local rs = fontSettings.rowSize or 11
        local idx = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        idx:SetPoint("LEFT", row, "LEFT", 8, 0)
        idx:SetFont(rowFont, rs, "")
        row.indexFs = idx
        local nameFrame = CreateFrame("Frame", nil, row)
        nameFrame:SetPoint("LEFT", idx, "RIGHT", 2, 0)
        nameFrame:SetPoint("RIGHT", row, "RIGHT", -(rightBlockW + rightMargin), 0)
        nameFrame:SetHeight(rowH)
        nameFrame:EnableMouse(true)
        nameFrame.fs = nameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFrame.fs:SetPoint("LEFT", nameFrame, "LEFT", 0, 0)
        nameFrame.fs:SetFont(rowFont, rs, "")
        nameFrame.fs:SetJustifyH("LEFT")
        nameFrame.fs:SetWordWrap(false)
        nameFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemLink then
                local lp = self.itemLink:match("|H(item:[^|]+)|h") or self.itemLink
                if lp then GameTooltip:SetHyperlink(lp) end
            end
            if self.fullName and #(self.fullName or "") > 14 then
                GameTooltip:AddLine(self.fullName, 0.8, 0.8, 0.8)
            end
            GameTooltip:AddLine("Shift+Right-click: link in chat", 0.5, 0.7, 0.5)
            GameTooltip:Show()
        end)
        nameFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        nameFrame:SetScript("OnMouseUp", function(self, button)
            if IsShiftKeyDown() and button == "RightButton" and self.itemLink then
                local toInsert = self.itemLink
                if not toInsert:match("|Hitem:") and GetItemInfo then
                    local id = tonumber(toInsert:match("item:(%d+)"))
                    if id then
                        local _, link = GetItemInfo(id)
                        if link then toInsert = link end
                    end
                end
                local chatBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
                if not chatBox and ChatEdit_ActivateChat and _G.ChatFrame1EditBox then ChatEdit_ActivateChat(_G.ChatFrame1EditBox); chatBox = _G.ChatFrame1EditBox end
                if chatBox then chatBox:Insert(toInsert) end
            end
        end)
        row.itemBtn = nameFrame
        local rightFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightFs:SetPoint("TOPRIGHT", row, "TOPRIGHT", -rightMargin, 0)
        rightFs:SetJustifyH("RIGHT")
        rightFs:SetWordWrap(false)
        rightFs:SetFont(rowFont, rs, "")
        row.rightFs = rightFs
        local goldHover = CreateFrame("Frame", nil, row)
        goldHover:SetPoint("TOPRIGHT", row, "TOPRIGHT", -rightMargin, 0)
        goldHover:SetSize(rightBlockW, rowH)
        goldHover:EnableMouse(true)
        goldHover:SetScript("OnEnter", function(self)
            if self.copper then
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:AddLine(L.FormatGold(self.copper), 1, 0.85, 0.4)
                GameTooltip:Show()
            end
        end)
        goldHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row.goldHover = goldHover
        L.TOP_ITEM_ROW_POOL[L.TOP_ITEM_ROW_POOL_USED] = row
    end
    row:SetParent(parent)
    if row.itemBtn then row.itemBtn:EnableMouse(true) end
    if row.goldHover then row.goldHover:EnableMouse(true) end
    row:Show()
    return row
    end
end

-- End of shared render kit.

