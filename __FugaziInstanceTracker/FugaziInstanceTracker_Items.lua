local addonName, L = ...
local FB = _G.FugaziBAGS
local itemDetailFrame -- InstanceTrackerItemDetailFrame (local handle)

----------------------------------------------------------------------
-- Data Layer
----------------------------------------------------------------------
L.ItemsData = {}

-- Prefer BAGS shared icon map so FIT badges always match bag/list valuation icons.
local function GetValActionIcon(action)
    local bags = _G.FugaziBAGS or FB
    if bags and bags.GetValuationActionIcon then
        return bags.GetValuationActionIcon(action)
    end
    if bags and bags.VALUATION_ACTION_ICONS then
        return bags.VALUATION_ACTION_ICONS[action]
    end
    -- Fallback if BAGS not ready (should be rare; FIT RequiredDeps BAGS)
    local fallback = {
        AH       = "Interface\\Icons\\INV_Misc_Coin_02",
        DE       = "Interface\\Icons\\INV_Enchant_Disenchant",
        PROSPECT = "Interface\\Icons\\inv_misc_gem_bloodgem_01",
        MILL     = "Interface\\Icons\\ability_miling",
        VENDOR   = "Interface\\Icons\\inv_misc_coin_18",
    }
    return action and fallback[action] or nil
end

local function IsAutodeletedRow(item)
    if not item then return false end
    if item.autodeletedDuringSession then return true end
    -- Live dungeon map: remaining gone + counted in currentRun.autodeletedItems
    local id = item.itemId or item.id
    if id and L.currentRun and L.currentRun.autodeletedItems then
        local del = tonumber(L.currentRun.autodeletedItems[id]) or 0
        if del > 0 then
            local rem = item.remainingCount
            if rem == nil or rem == 0 then return true end
        end
    end
    return false
end

--- Kept loot first (high quality first); fully-autodeleted block last for red-wash.
local function SortItemsByQualityName(a, b)
    local aDel = IsAutodeletedRow(a) and 1 or 0
    local bDel = IsAutodeletedRow(b) and 1 or 0
    if aDel ~= bDel then return aDel < bDel end
    if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
    return (a.name or "") < (b.name or "")
end

--- Live dungeon run stores items as itemId -> row; history stores an array. Always return an array for the list UI.
function L.BuildCurrentRunSnapshot()
    if not L.currentRun then return nil end
    local itemList = {}
    local deletedMap = L.currentRun.autodeletedItems or {}
    for itemId, item in pairs(L.currentRun.items or {}) do
        itemId = tonumber(itemId) or itemId
        local del = tonumber(deletedMap[itemId]) or 0
        local cnt = item.count or 0
        -- Fully deleted when sink covers (or exceeds) recorded loot count.
        local fullyDel = del > 0 and del >= cnt
        table.insert(itemList, {
            link = item.link,
            quality = item.quality,
            count = cnt,
            name = item.name,
            itemId = item.itemId or itemId,
            iLvl = item.iLvl or item.itemLevel,
            deletedCount = del,
            remainingCount = fullyDel and 0 or nil,
            autodeletedDuringSession = fullyDel,
        })
    end
    table.sort(itemList, SortItemsByQualityName)
    return {
        name = L.currentRun.name,
        qualityCounts = L.currentRun.qualityCounts,
        items = itemList,
        itemsAutodeleted = L.currentRun.itemsAutodeleted or 0,
        autodeletedVendorCopper = L.currentRun.autodeletedVendorCopper or 0,
    }
end

function L.ItemsData.GetFilteredItems(run, searchText)
    local items = {}
    local qc = {}
    local titleText = run and run.name or "Unknown"

    if searchText and searchText ~= "" then
        local searchLower = searchText:lower()
        local history = InstanceTrackerDB.runHistory or {}
        local currentRealm = (GetRealmName and GetRealmName()) or ""

        for runIndex, r in ipairs(history) do
            if not r.realmName or r.realmName == currentRealm then
                local runDisp = L.GetRunDisplayName(r)
                local runNameLower = (r.name and r.name:lower()) or ""
                local customLower = (r.customName and r.customName:lower()) or ""
                local runMatches = runNameLower:find(searchLower, 1, true)
                    or (customLower ~= "" and customLower:find(searchLower, 1, true))

                for _, item in ipairs(r.items or {}) do
                    local isMatch = false
                    if runMatches then
                        isMatch = true
                    elseif FB and FB.Search and FB.Search.Matches then
                        isMatch = FB.Search.Matches(item, searchLower)
                    else
                        local itemNameLower = (item.name and item.name:lower()) or ""
                        local itemMatches = itemNameLower:find(searchLower, 1, true)
                        local qualityMatches = false
                        for q = 0, 5 do
                            local info = L.QUALITY_COLORS[q]
                            if info and info.label and info.label:lower():find(searchLower, 1, true) and item.quality == q then
                                qualityMatches = true
                                break
                            end
                        end
                        isMatch = itemMatches or qualityMatches
                    end

                    if isMatch then
                        local c = item.count or 0
                        table.insert(items, {
                            link = item.link,
                            quality = item.quality,
                            count = c,
                            name = item.name,
                            runDisplayName = runDisp,
                            runIndex = runIndex,
                            runRef = r,
                            itemId = item.itemId or item.id,
                            iLvl = item.iLvl or item.itemLevel,
                            autodeletedDuringSession = item.autodeletedDuringSession,
                            deletedCount = item.deletedCount,
                        })
                        qc[item.quality] = (qc[item.quality] or 0) + c
                    end
                end
            end
        end
        table.sort(items, SortItemsByQualityName)
        titleText = "Search: " .. searchText
    else
        items = run and run.items or {}
        -- Live L.currentRun.items is a map; never ipairs a map
        if type(items) == "table" and items[1] == nil then
            local list = {}
            for _, item in pairs(items) do table.insert(list, item) end
            table.sort(list, SortItemsByQualityName)
            items = list
        end
        qc = run and run.qualityCounts or {}
        if run and run.name and run.name:find("^GPH") and #items > 0 then
            table.sort(items, SortItemsByQualityName)
        end
    end

    return items, qc, titleText
end

----------------------------------------------------------------------
-- UI helpers
----------------------------------------------------------------------
L.ITEM_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

function L.GetSafeItemTexture(linkOrId, _storedTexture)
    local id = type(linkOrId) == "number" and linkOrId or nil
    if not id and type(linkOrId) == "string" then id = tonumber((linkOrId or ""):match("item:(%d+)")) end
    local tex = nil
    if GetItemInfo then
        tex = (id and select(10, GetItemInfo(id))) or (linkOrId and select(10, GetItemInfo(linkOrId)))
    end
    if tex and type(tex) == "string" and tex ~= "" and tex:match("^Interface") then return tex end
    return L.ITEM_ICON_FALLBACK
end

local function GetItemDockTarget()
    local d = L.ledgerDetailFrame
    local stats = _G.InstanceTrackerStatsFrame
    if d and d:IsShown() then return d end
    if stats and stats:IsShown() then return stats end
    local gph = rawget(_G, "gphFrame") or rawget(_G, "FugaziBAGSFrame")
    if gph and gph.IsShown and gph:IsShown() then return gph end
    return nil
end

local function DockItemDetail(f)
    local target = GetItemDockTarget()
    if not target then return false end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", target, "TOPRIGHT", 4, 0)
    return true
end

local function ApplyValuationBadge(btn, item)
    if not btn.valIcon then return nil end
    local action = nil
    local bags = _G.FugaziBAGS or FB
    if bags and bags.GetItemValuationAndAction then
        local link = item.link
        local id = item.itemId
        if not id and link then id = tonumber(link:match("item:(%d+)")) end
        local _, _, _, _, _, itemClass = GetItemInfo(link or id)
        local _, valAction = bags.GetItemValuationAndAction(link, id, item.quality, item.iLvl or item.itemLevel, itemClass)
        action = valAction
    end
    local tex = GetValActionIcon(action)
    if tex then
        btn.valIcon:SetTexture(tex)
        btn.valIcon:SetWidth(16)
        btn.valIcon:SetHeight(16)
        btn.valIcon:Show()
        return btn.valIcon
    end
    btn.valIcon:Hide()
    return nil
end

----------------------------------------------------------------------
-- Row pool
----------------------------------------------------------------------
L.ITEM_BTN_POOL, L.ITEM_BTN_POOL_USED = {}, 0

function L.ResetItemBtnPool()
    for i = 1, L.ITEM_BTN_POOL_USED do if L.ITEM_BTN_POOL[i] then L.ITEM_BTN_POOL[i]:Hide() end end
    L.ITEM_BTN_POOL_USED = 0
end

function L.GetItemBtn(parent)
    L.ITEM_BTN_POOL_USED = L.ITEM_BTN_POOL_USED + 1
    local btn = L.ITEM_BTN_POOL[L.ITEM_BTN_POOL_USED]
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetHitRectInsets(0, 0, 0, 0)
        btn:SetWidth(L.SCROLL_CONTENT_WIDTH)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", btn, "LEFT", 0, 0)
        btn.icon = icon

        local nameFs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFs:SetPoint("RIGHT", btn, "RIGHT", -40, 0)
        nameFs:SetJustifyH("LEFT")
        btn.nameFs = nameFs

        local countFs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countFs:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
        countFs:SetJustifyH("RIGHT")
        btn.countFs = countFs

        local valIcon = btn:CreateTexture(nil, "OVERLAY")
        valIcon:SetPoint("LEFT", icon, "RIGHT", 2, 0)
        btn.valIcon = valIcon
        valIcon:Hide()

        -- Soft red wash for fully-autodeleted session/dungeon rows (no delete badge).
        local delWash = btn:CreateTexture(nil, "BACKGROUND")
        delWash:SetAllPoints()
        delWash:SetTexture(1, 0.12, 0.12, 0.22)
        delWash:Hide()
        btn.deletedWash = delWash

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(1, 1, 1, 0.1)

        L.ITEM_BTN_POOL[L.ITEM_BTN_POOL_USED] = btn
    end
    btn:SetParent(parent)
    btn:Show()

    local fontSettings = L.GetFugaziFontSettings()
    local rowFont = fontSettings.rowFontPath or fontSettings.fontPath
    local rh = L.GetFugaziRowHeight(18)
    btn:SetHeight(rh)
    btn.icon:SetWidth(rh - 2)
    btn.icon:SetHeight(rh - 2)
    btn.nameFs:SetFont(rowFont, fontSettings.rowSize, "")
    btn.countFs:SetFont(rowFont, fontSettings.rowSize, "")

    btn.itemLink = nil
    btn.runIndex = nil
    btn.runRef = nil
    if btn.deletedWash then btn.deletedWash:Hide() end
    btn:SetAlpha(1)
    if btn.icon then btn.icon:SetVertexColor(1, 1, 1) end
    if btn.RegisterForClicks then btn:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    return btn
end

function L.ItemDetailBtn_OnClick(self, button)
    if button == "LeftButton" and self.runIndex and self.runRef then
        if L.PlayUIClickSound then L.PlayUIClickSound() end
        if not L.statsFrame then L.statsFrame = _G.InstanceTrackerStatsFrame end
        if not L.statsFrame and L.CreateStatsFrame then L.statsFrame = L.CreateStatsFrame() end
        if L.statsFrame and not L.statsFrame:IsShown() and L.frame and L.frame:IsShown() then
            L.statsFrame:ClearAllPoints()
            L.statsFrame:SetWidth(L.frame:GetWidth())
            L.statsFrame:SetHeight(L.frame:GetHeight())
            L.statsFrame:SetPoint("TOPLEFT", L.frame, "TOPRIGHT", 4, 0)
            L.statsFrame:Show()
            L.SaveFrameLayout(L.statsFrame, "statsShown", "statsPoint")
        end
        if type(ShowLedgerDetail) == "function" then ShowLedgerDetail(self.runIndex) end
        L.ShowItemDetail(self.runRef)
        if type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI() end
        return
    end
    if not (IsShiftKeyDown() and button == "RightButton" and self.itemLink) then return end
    if L.PlayUIClickSound then L.PlayUIClickSound() end
    local chatBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if not chatBox and ChatEdit_ActivateChat and _G.ChatFrame1EditBox then
        ChatEdit_ActivateChat(_G.ChatFrame1EditBox)
        chatBox = _G.ChatFrame1EditBox
    end
    if not chatBox then
        for ci = 1, NUM_CHAT_WINDOWS do
            local eb = _G["ChatFrame" .. ci .. "EditBox"]
            if eb and eb:IsVisible() then chatBox = eb; break end
        end
    end
    if chatBox then chatBox:Insert(self.itemLink) end
end

function L.ItemDetailBtn_OnEnter(self)
    if L.PlayUIHoverSound then L.PlayUIHoverSound() end
    if self.itemLink then
        L.AnchorTooltipRight(self)
        local lp = self.itemLink:match("|H(item:[^|]+)|h")
        if lp then GameTooltip:SetHyperlink(lp) end
        GameTooltip:AddLine("From: " .. (self.runDisplayName or "?"), 0.6, 0.8, 0.6)
        if self._fbagsAutodeleted then
            GameTooltip:AddLine("Autodeleted during this run/session", 1, 0.35, 0.35)
        end
        GameTooltip:AddLine("Shift+Right-click: link in chat", 0.5, 0.7, 0.5)
        GameTooltip:Show()
    end
end

function L.ItemDetailBtn_OnLeave()
    GameTooltip:Hide()
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
function L.CreateItemDetailFrame()
    local f = CreateFrame("Frame", "InstanceTrackerItemDetailFrame", UIParent)
    f:SetWidth(340)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent, "CENTER", -200, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        -- Soft snap to Run Details / Ledger when dropped nearby
        local d = L.ledgerDetailFrame
        local stats = _G.InstanceTrackerStatsFrame
        local snapTo = nil
        if d and d:IsShown() then
            local lx, rx = f:GetLeft(), d:GetRight()
            if lx and rx and (lx - rx) >= -120 and (lx - rx) <= 120 then
                local fb, ft, sb, st = f:GetBottom(), f:GetTop(), d:GetBottom(), d:GetTop()
                if fb and ft and sb and st and ft > sb and fb < st then snapTo = d end
            end
        end
        if not snapTo and stats and stats:IsShown() then
            local lx, rx = f:GetLeft(), stats:GetRight()
            if lx and rx and (lx - rx) >= -120 and (lx - rx) <= 120 then
                local fb, ft, sb, st = f:GetBottom(), f:GetTop(), stats:GetBottom(), stats:GetTop()
                if fb and ft and sb and st and ft > sb and fb < st then snapTo = stats end
            end
        end
        if snapTo then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", snapTo, "TOPRIGHT", 4, 0)
        end
        L.SaveFrameLayout(f, "itemDetailShown", "itemDetailPoint")
    end)
    f:SetScript("OnHide", function()
        L.SaveFrameLayout(f, "itemDetailShown", "itemDetailPoint")
    end)
    f:SetScript("OnShow", function()
        DockItemDetail(f)
    end)
    f:SetFrameStrata("HIGH")

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetTextColor(1, 0.85, 0.4, 1)
    f.title = title
    f.itTitleBar = titleBar
    f.itTitleText = title

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        L.SaveFrameLayout(f, "itemDetailShown", "itemDetailPoint")
        f:Hide()
    end)

    local qualLine = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    qualLine:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 4, -6)
    qualLine:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -4, -6)
    qualLine:SetJustifyH("LEFT")
    f.qualLine = qualLine

    local scrollFrame = CreateFrame("ScrollFrame", "InstanceTrackerItemScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", qualLine, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 6)
    f.scrollFrame = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(L.SCROLL_CONTENT_WIDTH)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    f.content = content

    f.ApplySkin = function()
        L.ApplyInstanceTrackerSkin(f)
    end
    L.ApplyInstanceTrackerSkin(f)
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.SkinScrollBar then
        _G.__FugaziBAGS_Skins.SkinScrollBar(scrollFrame)
    end

    function f:RefreshItemDetailList()
        local run = self.currentRun
        if not run then return end

        local searchText = (L.statsFrame and L.statsFrame.ledgerSearchEditBox
            and (L.statsFrame.ledgerSearchEditBox:GetText() or ""):match("^%s*(.-)%s*$")) or ""

        local items, qc, titleText = L.ItemsData.GetFilteredItems(run, searchText)

        -- Value lens: show only vendor / AH / destroy items when that lens is active
        local lens = (L.FilterBar and L.FilterBar.GetField and L.FilterBar.GetField("lens")) or "raw"
        if L.FilterBar and L.FilterBar.FilterItemsByLens and (lens == "vendor" or lens == "ah" or lens == "destroy") then
            items, qc = L.FilterBar.FilterItemsByLens(items, lens)
            local short = (L.FilterBar.LensShort and L.FilterBar.LensShort(lens)) or lens
            titleText = (titleText or "Items") .. " |cff88ff88(" .. short .. ")|r"
        end

        self.title:SetText(titleText)
        self.qualLine:SetText(L.FormatQualityCounts(qc))
        L.ResetItemBtnPool()
        local yOff = 4

        if #items == 0 and (lens == "vendor" or lens == "ah" or lens == "destroy") then
            self.qualLine:SetText("|cff888888No items for this value lens.|r")
        end

        -- Stable order: kept first, autodeleted last (red-wash block).
        if type(items) == "table" and #items > 1 then
            table.sort(items, SortItemsByQualityName)
        end

        for _, item in ipairs(items) do
            local btn = L.GetItemBtn(self.content)
            btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, -yOff)
            btn.itemLink = item.link
            btn.runDisplayName = item.runDisplayName or L.GetRunDisplayName(run)
            btn.runIndex = item.runIndex
            btn.runRef = item.runRef

            local deleted = IsAutodeletedRow(item)
            btn._fbagsAutodeleted = deleted and true or nil
            local qInfo = L.QUALITY_COLORS[item.quality] or L.QUALITY_COLORS[1]
            btn.icon:SetTexture(L.GetSafeItemTexture(item.link, nil))
            if deleted then
                btn.icon:SetVertexColor(1, 0.55, 0.55)
                btn:SetAlpha(0.85)
                if btn.deletedWash then btn.deletedWash:Show() end
            else
                btn.icon:SetVertexColor(1, 1, 1)
                btn:SetAlpha(1)
                if btn.deletedWash then btn.deletedWash:Hide() end
            end
            btn.nameFs:SetText("|cff" .. qInfo.hex .. (item.name or "Unknown") .. "|r")

            -- No valuation badge on fully-deleted junk (value was not kept).
            local leadingIcon = nil
            if not deleted then
                leadingIcon = ApplyValuationBadge(btn, item)
            elseif btn.valIcon then
                btn.valIcon:Hide()
            end

            local cnt = item.count or 0
            if deleted then
                btn.countFs:SetText(cnt > 1 and ("|cffff6666 x" .. cnt .. "|r") or "|cffff6666del|r")
            else
                btn.countFs:SetText(cnt > 1 and ("|cffaaaaaa x" .. cnt .. "|r") or "")
            end
            btn:SetScript("OnClick", L.ItemDetailBtn_OnClick)
            btn:SetScript("OnEnter", L.ItemDetailBtn_OnEnter)
            btn:SetScript("OnLeave", L.ItemDetailBtn_OnLeave)

            local hideIcons = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphHideIconsInList
            btn.nameFs:ClearAllPoints()
            if hideIcons then
                btn.icon:Hide()
                if leadingIcon then
                    leadingIcon:Show()
                    leadingIcon:ClearAllPoints()
                    leadingIcon:SetPoint("LEFT", btn, "LEFT", 4, 0)
                    btn.nameFs:SetPoint("LEFT", leadingIcon, "RIGHT", 4, 0)
                else
                    btn.nameFs:SetPoint("LEFT", btn, "LEFT", 4, 0)
                end
            else
                btn.icon:Show()
                if leadingIcon then
                    leadingIcon:Show()
                    leadingIcon:ClearAllPoints()
                    leadingIcon:SetPoint("LEFT", btn.icon, "RIGHT", 2, 0)
                    btn.nameFs:SetPoint("LEFT", leadingIcon, "RIGHT", 4, 0)
                else
                    btn.nameFs:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
                end
            end
            btn.nameFs:SetPoint("RIGHT", btn, "RIGHT", -40, 0)
            yOff = yOff + btn:GetHeight()
        end
        if #items == 0 then yOff = yOff + 4 end
        self.content:SetHeight(yOff + 8)
    end

    return f
end

--- Open/update the items popup.
-- liveSource: truthy when showing the in-progress dungeon run (updates only when loot changes via DiffBags).
L.ShowItemDetail = function(run, liveSource)
    if not itemDetailFrame then itemDetailFrame = L.CreateItemDetailFrame() end
    local f = itemDetailFrame
    L.statsFrame = _G.InstanceTrackerStatsFrame
    local wasShown = f:IsShown()

    local isLive = liveSource and true or false
    if isLive or (run and L.currentRun and run == L.currentRun) then
        local snap = L.BuildCurrentRunSnapshot()
        if snap then run = snap end
        isLive = true
    end

    f.currentRun = run
    f.liveSource = isLive and (liveSource or "current") or nil
    f:RefreshItemDetailList()

    if not DockItemDetail(f) and not wasShown then
        if InstanceTrackerDB.itemDetailPoint and InstanceTrackerDB.itemDetailPoint.point then
            L.RestoreFrameLayout(f, nil, "itemDetailPoint")
        end
    end
    f:Show()
    DockItemDetail(f)
    L.SaveFrameLayout(f, "itemDetailShown", "itemDetailPoint")
end

L.RefreshItemDetailLive = function()
    if not itemDetailFrame or not itemDetailFrame:IsShown() or not itemDetailFrame.liveSource then return end
    if not L.currentRun then return end
    local ledgerSearch = (L.statsFrame and L.statsFrame.ledgerSearchEditBox
        and (L.statsFrame.ledgerSearchEditBox:GetText() or ""):match("^%s*(.-)%s*$")) or ""
    if ledgerSearch and ledgerSearch ~= "" then return end
    local snap = L.BuildCurrentRunSnapshot()
    if not snap then return end
    itemDetailFrame.currentRun = snap
    itemDetailFrame:RefreshItemDetailList()
end
