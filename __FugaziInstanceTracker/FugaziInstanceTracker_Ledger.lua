local addonName, L = ...


L.LedgerData = {}

local function IsGPHRun(run)
    return run and run.name and run.name:find('^GPH')
end

--- Filtered/sorted history entries. Delegates to FilterBar (time/scope/sort/lens).
function L.LedgerData.GetFilteredRuns(tabIndex, searchText)
    if L.FilterBar and L.FilterBar.GetFilteredRuns then
        return L.FilterBar.GetFilteredRuns(tabIndex, searchText)
    end
    -- Fallback if FilterBar failed to load: realm + tab only (old baseline)
    local history = _G.InstanceTrackerDB and _G.InstanceTrackerDB.runHistory or {}
    local currentRealm = GetRealmName and GetRealmName() or ""
    local results = {}
    for i, run in ipairs(history) do
        if not run.realmName or run.realmName == currentRealm then
            local isGPH = IsGPHRun(run)
            local passesTab = (tabIndex == 1) or (tabIndex == 2 and isGPH) or (tabIndex == 3 and not isGPH)
            if passesTab then
                results[#results + 1] = { index = i, run = run }
            end
        end
    end
    return results
end

--- Aggregate stats from filtered history (respects Time/Scope; gold uses Value lens when available).
function L.LedgerData.GetLifetimeStats()
    local stats = {
        totalGold = 0,
        totalTime = 0,
        totalDeaths = 0,
        totalItemsGained = 0,
        totalRuns = 0,
        autoDeleteCopper = 0,
        autoVendorCopper = 0,
        repairCopper = 0,
        zoneEfficiency = {}
    }

    local entries
    if L.FilterBar and L.FilterBar.GetFilteredRuns then
        entries = L.FilterBar.GetFilteredRuns(1, nil) -- Lifetime tab = all types unless scope forces
    else
        entries = L.LedgerData.GetFilteredRuns(1, nil)
    end

    local lens = (L.FilterBar and L.FilterBar.GetField and L.FilterBar.GetField("lens")) or "raw"
    for _, entry in ipairs(entries) do
        local run = entry.run
        if run then
            stats.totalRuns = stats.totalRuns + 1
            local gold
            if L.FilterBar and L.FilterBar.GetRunValue then
                gold = L.FilterBar.GetRunValue(run, lens == "gph" and "est" or lens)
            else
                gold = run.goldCopper or 0
            end
            stats.totalGold = stats.totalGold + (gold or 0)
            stats.totalTime = stats.totalTime + (run.duration or 0)
            stats.totalDeaths = stats.totalDeaths + (run.deaths or 0)

            if run.qualityCounts then
                for _, c in pairs(run.qualityCounts) do
                    stats.totalItemsGained = stats.totalItemsGained + (c or 0)
                end
            end

            if not IsGPHRun(run) and run.name then
                if not stats.zoneEfficiency[run.name] then
                    stats.zoneEfficiency[run.name] = { totalGold = 0, totalDuration = 0, runCount = 0 }
                end
                local zGold = run.goldCopper or 0
                if L.FilterBar and L.FilterBar.GetRunValue then
                    zGold = L.FilterBar.GetRunValue(run, lens == "gph" and "est" or lens)
                end
                stats.zoneEfficiency[run.name].totalGold = stats.zoneEfficiency[run.name].totalGold + (zGold or 0)
                stats.zoneEfficiency[run.name].totalDuration = stats.zoneEfficiency[run.name].totalDuration + (run.duration or 0)
                stats.zoneEfficiency[run.name].runCount = stats.zoneEfficiency[run.name].runCount + 1
            end
        end
    end

    local bestZones = {}
    for name, data in pairs(stats.zoneEfficiency) do
        if data.runCount > 0 and data.totalDuration > 30 then
            local gph = data.totalGold / (data.totalDuration / 3600)
            table.insert(bestZones, { name = name, gph = gph, count = data.runCount })
        end
    end
    table.sort(bestZones, function(a, b) return a.gph > b.gph end)
    stats.bestZones = bestZones

    return stats
end

-- ==========================================
-- LEDGER UI (Modernized)
-- ==========================================

-- Quality search aliases (BAGS-style rarity names; not color words like "blue")
local SEARCH_QUALITY = {
    poor = 0, trash = 0, grey = 0, gray = 0,
    common = 1, white = 1,
    uncommon = 2, green = 2,
    rare = 3,
    epic = 4,
    legendary = 5, orange = 5,
}

local function ResolveSearchQuality(queryLower)
    if not queryLower or queryLower == "" then return nil end
    if queryLower:sub(1, 2) == "q:" then
        queryLower = queryLower:sub(3)
    end
    -- Exact token only (avoids "o" matching "common")
    if SEARCH_QUALITY[queryLower] ~= nil then
        return SEARCH_QUALITY[queryLower]
    end
    return nil
end

local function IterRunItems(run, fn)
    local items = run and run.items
    if not items then return end
    if #items > 0 then
        for i = 1, #items do fn(items[i]) end
    else
        for _, item in pairs(items) do fn(item) end
    end
end

--- First history run matching zone/name, item name, or rarity keyword (rare/epic/...).
function L.LedgerData.GetFirstSearchMatch(searchText)
    if not searchText or searchText == "" then return nil, nil end
    local searchLower = searchText:lower():match("^%s*(.-)%s*$") or ""
    if searchLower == "" then return nil, nil end
    local history = _G.InstanceTrackerDB and _G.InstanceTrackerDB.runHistory or {}
    local qWant = ResolveSearchQuality(searchLower)

    for i, run in ipairs(history) do
        local runNameLower = (run.name or ""):lower()
        local customLower = (run.customName or ""):lower()
        local runMatches = runNameLower:find(searchLower, 1, true)
            or (customLower ~= "" and customLower:find(searchLower, 1, true))

        -- Rarity-only query: any item of that quality in the run
        if qWant ~= nil then
            local hit = false
            IterRunItems(run, function(item)
                if not hit and (item.quality or 0) == qWant then hit = true end
            end)
            if hit then return i, run end
        elseif runMatches then
            return i, run
        else
            local itemHit = false
            IterRunItems(run, function(item)
                if itemHit then return end
                local itemNameLower = (item.name or ""):lower()
                if itemNameLower ~= "" and itemNameLower:find(searchLower, 1, true) then
                    itemHit = true
                end
            end)
            if itemHit then return i, run end
        end
    end
    return nil, nil
end

function L.RefreshStatsUI(forceRebuild)
    local statsF = _G.InstanceTrackerStatsFrame or L.statsFrame
    L.statsFrame = statsF
    if not statsF then return end
    if not forceRebuild and not statsF:IsShown() then return end
    if type(L.ResetStatsPools) == "function" then L.ResetStatsPools() end

    local content = statsF.content
    if not content then return end

    -- Lifetime tab owns sticky hover overlays (not in the row pool). Always hide them so
    -- Sessions/Dungeons do not inherit Lifetime mouseovers.
    if content._statHoverFrames then
        for _, hf in ipairs(content._statHoverFrames) do
            if hf then hf:Hide(); hf:EnableMouse(false) end
        end
    end
    if content.summaryGoldHoverFrame then
        content.summaryGoldHoverFrame:Hide()
        content.summaryGoldHoverFrame:EnableMouse(false)
    end
    if content.lifetimeGoldHoverFrame then
        content.lifetimeGoldHoverFrame:Hide()
        content.lifetimeGoldHoverFrame:EnableMouse(false)
    end
    if content.lifetimeDeathsHoverFrame then
        content.lifetimeDeathsHoverFrame:Hide()
        content.lifetimeDeathsHoverFrame:EnableMouse(false)
    end

    local fontSettings = L.GetFugaziFontSettings()
    local hdrSpacing = (fontSettings.headerSize or 11) + 6
    local rowH = L.GetFugaziRowHeight(18)
    local smallH = L.GetFugaziRowHeight(16)
    local yOff = 0

    -- Ledger search drives path only (tab + Detail + item list). Do this before tab check so typing from Lifetime switches to Sessions/Dungeons.
    local searchTextEarly = (statsF.ledgerSearchEditBox and statsF.ledgerSearchEditBox:GetText() or ""):match("^%s*(.-)%s*$")
    if searchTextEarly and searchTextEarly ~= "" then
        local firstRunIndex, firstRun = L.LedgerData.GetFirstSearchMatch(searchTextEarly, nil)
        if firstRunIndex and firstRun then
            local wantTab = (firstRun.name and firstRun.name:find("^GPH")) and 2 or 3
            statsF.selectedTab = wantTab
            local selectedColor = { 0.4, 0.35, 0.15, 0.9 }
            local normalColor = { 0.15, 0.15, 0.15, 0.7 }
            local greyColor = { 0.25, 0.25, 0.22, 0.85 }
            if statsF.statsTab1 and statsF.statsTab1.bg then statsF.statsTab1.bg:SetTexture(unpack(wantTab == 1 and greyColor or normalColor)) end
            if statsF.statsTab2 and statsF.statsTab2.bg then statsF.statsTab2.bg:SetTexture(unpack(wantTab == 2 and selectedColor or normalColor)) end
            if statsF.statsTab3 and statsF.statsTab3.bg then statsF.statsTab3.bg:SetTexture(unpack(wantTab == 3 and selectedColor or normalColor)) end
            if type(_G.ShowLedgerDetail) == "function" then _G.ShowLedgerDetail(firstRunIndex) end
            if type(L.ShowItemDetail) == "function" then L.ShowItemDetail(firstRun) end
        end
    end

    -- Keep filter bar glows in sync with tab + dirty state
    if L.FilterBar and L.FilterBar.UpdateGlows then
        L.FilterBar.UpdateGlows(statsF)
    end

    -- 1. Get Clean Data
    local stats = L.LedgerData.GetLifetimeStats()
    local visibleRuns = L.LedgerData.GetFilteredRuns(statsF.selectedTab, nil)
    local showLive = (not L.FilterBar or not L.FilterBar.ShowLiveSection) and true or L.FilterBar.ShowLiveSection(statsF.selectedTab)
    local showHistory = (not L.FilterBar or not L.FilterBar.ShowHistorySection) and true or L.FilterBar.ShowHistorySection(statsF.selectedTab)
    local showStatsSec = (not L.FilterBar or not L.FilterBar.ShowStatsSection) and true or L.FilterBar.ShowStatsSection(statsF.selectedTab)
    local valueLens = (L.FilterBar and L.FilterBar.GetField and L.FilterBar.GetField("lens")) or "raw"
    local historyFiltered = (L.FilterBar and L.FilterBar.IsHistoryFiltered and L.FilterBar.IsHistoryFiltered()) or false

    -- 2. Build Lifetime Tab
    if statsF.selectedTab == 1 then
        if L.RefreshStatsLifetimeUI then
            L.RefreshStatsLifetimeUI(content)
        end
        return
    end

    -- 3. Build Sessions / Dungeons Headers
    local hdr = L.GetStatsText(content)
    hdr:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
    L.StyleFugaziHeader(hdr)
    
    -- Current Run block
    statsF._liveRunDurRow = nil
    statsF._liveRunItemsRow = nil
    statsF._liveRawGoldRow = nil
    statsF._liveEstTotalRow = nil
    statsF._liveGphRow = nil
    statsF._liveValueParts = nil
    if showLive and statsF.selectedTab == 3 and L.currentRun then
        local dur = time() - L.currentRun.enterTime
        local liveGold = GetMoney() - L.startingGold
        if liveGold < 0 then liveGold = 0 end
        hdr:SetText("--- Current: " .. (L.currentRun.name or "?") .. " ---")
        yOff = yOff + hdrSpacing
        
        -- Live value breakdown first (needed for lens value on header + green rows).
        local vendorCu, ahCu, destroyCu, totalCu = 0, 0, 0, liveGold
        local Bags = _G.FugaziBAGS
        if Bags and type(Bags.ComputeGPHTotalValue) == "function" then
            local total, breakdown = Bags.ComputeGPHTotalValue(L.currentRun, liveGold)
            totalCu = total or liveGold
            if breakdown then
                vendorCu = breakdown.vendor or 0
                ahCu = breakdown.ah or 0
                destroyCu = breakdown.destroy or 0
            end
        end
        local gphCu = (dur > 0) and (totalCu / (dur / 3600)) or 0
        local liveLensCopper = liveGold
        if valueLens == "vendor" then liveLensCopper = vendorCu
        elseif valueLens == "ah" then liveLensCopper = ahCu
        elseif valueLens == "destroy" then liveLensCopper = destroyCu
        elseif valueLens == "est" then liveLensCopper = totalCu
        elseif valueLens == "gph" then liveLensCopper = gphCu
        end
        local liveGoldText = L.FormatGold and L.FormatGold(liveLensCopper) or tostring(math.floor(liveLensCopper + 0.5))
        if valueLens == "gph" then
            liveGoldText = liveGoldText .. " |cffffd700/h|r"
        end

        local rDur = L.GetStatsRow(content, false, true)
        rDur:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD or 8, -yOff)
        local liveName = "|cffffffcc" .. (L.currentRun.name or "?") .. "|r"
        if L.runSoftPaused then
            liveName = liveName .. " |cff888888(paused)|r"
        end
        local liveSubLeft = "|cffaaaaaa" .. (L.FormatTimeMedium and L.FormatTimeMedium(dur) or dur .. "s") .. "|r  |cff888888" .. (L.FormatDateTime and L.FormatDateTime(L.currentRun.enterTime) or "") .. "|r"
        if L.LayoutStatsRowTexts then
            L.LayoutStatsRowTexts(rDur, liveName, "", liveSubLeft, liveGoldText)
        else
            rDur.left:SetText(liveName)
            rDur.right:SetText("")
            rDur.subLeft:SetText(liveSubLeft)
            rDur.subRight:SetText(liveGoldText)
        end
        statsF._liveRunDurRow = rDur
        statsF._liveValueParts = { vendor = vendorCu, ah = ahCu, destroy = destroyCu, total = totalCu }
        yOff = yOff + rDur:GetHeight()

        local rItems = L.GetStatsRow(content, false)
        rItems:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD or 8, -yOff)
        local qcText = L.FormatQualityCounts and L.FormatQualityCounts(L.currentRun.qualityCounts) or ""
        if qcText == "|cff555555-|r" or qcText == "" then qcText = "|cff888888None|r" end
        local itemsLeft = "|cffccccccItems gained:|r " .. qcText
        if valueLens == "vendor" or valueLens == "ah" or valueLens == "destroy" then
            local short = (L.FilterBar.LensShort and L.FilterBar.LensShort(valueLens)) or valueLens
            itemsLeft = "|cff88ff88Items (" .. short .. "):|r " .. qcText
        end
        if L.LayoutStatsRowTexts then
            L.LayoutStatsRowTexts(rItems, itemsLeft, "")
        else
            rItems.right:SetText("")
            rItems.left:SetText(itemsLeft)
        end
        statsF._liveRunItemsRow = rItems
        if L.BindRowClickArea then
            L.BindRowClickArea(rItems, function()
                if L.PlayUIClickSound then L.PlayUIClickSound() end
                if L.currentRun and type(L.ShowItemDetail) == "function" then
                    L.ShowItemDetail(L.currentRun, "live")
                end
            end, function(self)
                GameTooltip:SetOwner(self.clickArea or self, "ANCHOR_CURSOR")
                if valueLens == "vendor" or valueLens == "ah" or valueLens == "destroy" then
                    GameTooltip:AddLine("Click: live items for " .. ((L.FilterBar.LensLabel and L.FilterBar.LensLabel(valueLens)) or valueLens), 0.5, 0.9, 0.5)
                else
                    GameTooltip:AddLine("Click to view live items", 0.7, 0.7, 0.7)
                end
                GameTooltip:Show()
            end, function() GameTooltip:Hide() end)
        end
        yOff = yOff + rItems:GetHeight()

        local function AddLiveValueRow(label, copper, color)
            local row = L.GetStatsRow(content, false)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD or 8, -yOff)
            local leftT = (color or "|cffcccccc") .. label .. "|r"
            local rightT = L.FormatGold and L.FormatGold(copper or 0) or tostring(copper or 0)
            if label == "GPH:" then
                rightT = rightT .. " |cffffd700/h|r"
            end
            if L.LayoutStatsRowTexts then
                L.LayoutStatsRowTexts(row, leftT, rightT)
            else
                row.left:SetText(leftT)
                row.right:SetText(rightT)
            end
            yOff = yOff + row:GetHeight()
            return row
        end
        local function lensColor(key)
            if valueLens == key then return "|cff88ff88" end
            return "|cffcccccc"
        end
        statsF._liveRawGoldRow = AddLiveValueRow("Raw gold:", liveGold, lensColor("raw"))
        AddLiveValueRow("Vendor:", vendorCu, lensColor("vendor"))
        AddLiveValueRow("Auction:", ahCu, lensColor("ah"))
        AddLiveValueRow("Destroy:", destroyCu, lensColor("destroy"))
        -- Total only greens on Total lens (not GPH — that was double-highlighting).
        statsF._liveEstTotalRow = AddLiveValueRow("Total:", totalCu, lensColor("est"))
        statsF._liveGphRow = AddLiveValueRow("GPH:", gphCu, lensColor("gph"))
    elseif showLive then
        if statsF.selectedTab == 3 then
            hdr:SetText("--- Current Run ---")
            yOff = yOff + hdrSpacing
            local noRun = L.GetStatsText(content)
            noRun:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
            noRun:SetText("|cff888888Not in an instance.|r")
            yOff = yOff + smallH
        else
            hdr:SetText("--- Sessions ---")
            yOff = yOff + hdrSpacing
        end
    else
        -- Live section hidden by view mode; still need a minimal tab header
        if statsF.selectedTab == 2 then
            hdr:SetText("--- Sessions ---")
        else
            hdr:SetText("--- Dungeons ---")
        end
        yOff = yOff + hdrSpacing
    end
    if showLive or showHistory then
        yOff = yOff + 10
    end

    -- 4. Build Run List
    if showHistory then
        local hdr2 = L.GetStatsText(content)
        hdr2:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
        if historyFiltered then
            hdr2:SetText("--- Filtered History (" .. #visibleRuns .. ") ---")
        else
            hdr2:SetText("--- History (" .. #visibleRuns .. "/" .. (L.MAX_RUN_HISTORY or 500) .. ") ---")
        end
        L.StyleFugaziHeader(hdr2)
        yOff = yOff + hdrSpacing

        if #visibleRuns == 0 then
            local noHist = L.GetStatsText(content)
            noHist:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
            noHist:SetText(historyFiltered and "|cff888888No runs matching filter.|r" or "|cff888888No runs recorded yet.|r")
            yOff = yOff + smallH
        else
            local detailPage = (L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown()) and L.ledgerDetailFrame.detailPage or nil
            for _, entry in ipairs(visibleRuns) do
                local run = entry.run
                local dur = run.duration or 0
                local row = L.GetStatsRow(content, false, true)
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
                row.gotoPage = entry.index
                row.runRef = run

                local histLeft = "|cff666666" .. entry.index .. ".|r |cffffffcc" .. (L.GetRunDisplayName and L.GetRunDisplayName(run) or (run.name or "Unknown")) .. "|r"
                local histSubLeft = "|cffaaaaaa" .. L.FormatTimeMedium(dur) .. "|r  |cff888888" .. L.FormatDateTime(run.enterTime) .. "|r"
                local histSubRight
                if L.FilterBar and L.FilterBar.FormatRunValue then
                    histSubRight = L.FilterBar.FormatRunValue(run, valueLens)
                else
                    histSubRight = L.FormatGold(run.goldCopper)
                end
                if L.LayoutStatsRowTexts then
                    L.LayoutStatsRowTexts(row, histLeft, "", histSubLeft, histSubRight)
                else
                    row.left:SetText(histLeft)
                    row.right:SetText("")
                    row.subLeft:SetText(histSubLeft)
                    row.subRight:SetText(histSubRight)
                end

                if row.selectedBg then
                    if detailPage and entry.index == detailPage then row.selectedBg:Show() else row.selectedBg:Hide() end
                end
                if L.BindRowClickArea then
                    L.BindRowClickArea(row, function(r, button)
                        if button == "RightButton" then
                            if IsControlKeyDown() and r.gotoPage then
                                if L.PlayUIClickSound then L.PlayUIClickSound() end
                                if L.ArmOrConfirmRunDelete then
                                    L.ArmOrConfirmRunDelete(r, r.gotoPage)
                                elseif L.RemoveRunEntry then
                                    L.RemoveRunEntry(r.gotoPage)
                                end
                                return
                            end
                            if L.PlayUIClickSound then L.PlayUIClickSound() end
                            if r.runRef then StaticPopup_Show("INSTANCETRACKER_RENAME_RUN", nil, nil, r.runRef) end
                        else
                            if L.PlayUIClickSound then L.PlayUIClickSound() end
                            if r.gotoPage and type(_G.ShowLedgerDetail) == "function" then
                                _G.ShowLedgerDetail(r.gotoPage)
                            end
                        end
                    end, function(r)
                        GameTooltip:SetOwner(r.clickArea or r, "ANCHOR_CURSOR")
                        GameTooltip:AddLine("Left-click: view details", 0.5, 0.8, 1)
                        GameTooltip:AddLine("Right-click: rename", 0.7, 0.7, 0.7)
                        GameTooltip:AddLine("Ctrl+Right-click twice: delete", 1, 0.3, 0.3)
                        if L.FilterBar and L.FilterBar.LensLabel then
                            GameTooltip:AddLine("Value: " .. L.FilterBar.LensLabel(valueLens), 0.85, 0.8, 0.5)
                        end
                        -- Full text when scale/font forced truncation
                        if r._fullLeftPlain then
                            GameTooltip:AddLine(r._fullLeftPlain, 1, 1, 0.85, true)
                        end
                        if r._fullSubLeftPlain then
                            GameTooltip:AddLine(r._fullSubLeftPlain, 0.75, 0.75, 0.75, true)
                        end
                        GameTooltip:Show()
                    end, function() GameTooltip:Hide() end)
                end
                yOff = yOff + row:GetHeight() + 2
            end
        end
    end

    if showStatsSec and statsF.selectedTab == 3 then
        yOff = yOff + 8
        local rbHeader = L.GetStatsText(content)
        rbHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
        rbHeader:SetText("--- Rarity Breakdown ---")
        L.StyleFugaziHeader(rbHeader)
        yOff = yOff + hdrSpacing

        -- Build from the same filtered run set as History
        local rarityBreakdown, zoneEfficiency = {}, {}
        for _, entry in ipairs(visibleRuns) do
            local run = entry.run
            if run and not IsGPHRun(run) and run.name and run.name ~= "" then
                if run.qualityCounts then
                    for q, count in pairs(run.qualityCounts) do
                        rarityBreakdown[q] = (rarityBreakdown[q] or 0) + count
                    end
                end
                local dur = run.duration or 0
                local gold = run.goldCopper or 0
                if L.FilterBar and L.FilterBar.GetRunValue then
                    gold = L.FilterBar.GetRunValue(run, valueLens == "gph" and "est" or valueLens)
                end
                local ze = zoneEfficiency[run.name] or { totalGold = 0, totalDuration = 0, runCount = 0 }
                ze.totalGold = ze.totalGold + gold
                ze.totalDuration = ze.totalDuration + dur
                ze.runCount = ze.runCount + 1
                zoneEfficiency[run.name] = ze
            end
        end

        local rbText = L.GetStatsText(content)
        rbText:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
        rbText:SetText((L.FormatQualityCounts and L.FormatQualityCounts(rarityBreakdown)) or "|cff888888No data|r")
        yOff = yOff + rowH + 4

        local zeHeader = L.GetStatsText(content)
        zeHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
        zeHeader:SetText("--- Best Zones (GPH) ---")
        L.StyleFugaziHeader(zeHeader)
        yOff = yOff + hdrSpacing

        local list = {}
        for name, data in pairs(zoneEfficiency or {}) do
            if data.runCount > 0 and data.totalDuration > 30 then
                local gph = data.totalGold / (data.totalDuration / 3600)
                table.insert(list, { name = name, gph = gph, count = data.runCount })
            end
        end
        table.sort(list, function(a, b) return a.gph > b.gph end)

        if #list == 0 then
            local none = L.GetStatsText(content)
            none:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
            none:SetText("|cff888888No instance data yet.|r")
            yOff = yOff + smallH
        else
            for i = 1, math.min(5, #list) do
                local item = list[i]
                local row = L.GetStatsRow(content, false, true)
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOff)
                local topLeft = "|cff666666" .. i .. ".|r |cffffffcc" .. (item.name or "?") .. "|r"
                local topRight = (L.FormatGold and L.FormatGold(item.gph) or tostring(item.gph)) .. " |cffffd700/h|r"
                local topSub = "|cff888888(" .. item.count .. " runs)|r"
                if L.LayoutStatsRowTexts then
                    L.LayoutStatsRowTexts(row, topLeft, topRight, topSub, "")
                else
                    row.left:SetText(L.TruncateWithColors and L.TruncateWithColors(topLeft, 22) or topLeft)
                    row.right:SetText(topRight)
                    row.subLeft:SetText(topSub)
                    row.subRight:SetText("")
                end
                yOff = yOff + row:GetHeight()
            end
        end
        yOff = yOff + 4
    end

    if not showLive and not showHistory and not showStatsSec then
        local empty = L.GetStatsText(content)
        empty:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
        empty:SetText("|cff888888Nothing to show for this view mode on this tab.|r")
        yOff = yOff + smallH
    end

    yOff = yOff + 8
    content:SetHeight(yOff)
end

----------------------------------------------------------------------
-- Ledger UI shell, lifetime paint, history mutations (moved from Render)
----------------------------------------------------------------------

-- Two-step Ctrl+Right-click delete: first arm (red fade), second confirms.
L.PENDING_DELETE_SECONDS = 1.0
L._pendingDeleteIndex = nil
L._pendingDeleteRow = nil

function L.ClearPendingRunDelete()
    local row = L._pendingDeleteRow
    if row then
        row:SetScript("OnUpdate", nil)
        local pend = row.pendingDeleteBg or (row.clickArea and row.clickArea.pendingDeleteBg)
        if pend then pend:Hide() end
    end
    L._pendingDeleteIndex = nil
    L._pendingDeleteRow = nil
end

--- First Ctrl+Right arms the row (red tint fades over ~1s). Second within the window deletes.
function L.ArmOrConfirmRunDelete(row, index)
    if not row or not index then return end
    if L._pendingDeleteIndex == index and L._pendingDeleteRow == row then
        L.ClearPendingRunDelete()
        if L.PlayUISwooshSound then L.PlayUISwooshSound() end
        if L.RemoveRunEntry then L.RemoveRunEntry(index) end
        return
    end
    L.ClearPendingRunDelete()
    L._pendingDeleteIndex = index
    L._pendingDeleteRow = row
    local pend = row.pendingDeleteBg or (row.clickArea and row.clickArea.pendingDeleteBg)
    if not pend and row.clickArea then
        pend = row.clickArea:CreateTexture(nil, "ARTWORK")
        pend:SetAllPoints()
        pend:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        pend:SetVertexColor(0.9, 0.12, 0.1, 0.55)
        row.clickArea.pendingDeleteBg = pend
        row.pendingDeleteBg = pend
    end
    if not pend then return end
    pend:SetVertexColor(0.9, 0.12, 0.1, 0.65)
    pend:SetAlpha(0.65)
    pend:Show()
    row._pendingFade = 0
    local dur = L.PENDING_DELETE_SECONDS or 1
    row:SetScript("OnUpdate", function(self, elapsed)
        self._pendingFade = (self._pendingFade or 0) + (elapsed or 0)
        local a = 1 - (self._pendingFade / dur)
        local p = self.pendingDeleteBg or (self.clickArea and self.clickArea.pendingDeleteBg)
        if a <= 0 then
            self:SetScript("OnUpdate", nil)
            if p then p:Hide() end
            if L._pendingDeleteRow == self then
                L._pendingDeleteIndex = nil
                L._pendingDeleteRow = nil
            end
            return
        end
        if p then p:SetAlpha(0.65 * a) end
    end)
end

local function HideItemDetailFrame()
    local itemFrame = _G.InstanceTrackerItemDetailFrame
    if itemFrame and itemFrame:IsShown() then
        itemFrame:Hide()
        if L.SaveFrameLayout then
            L.SaveFrameLayout(itemFrame, "itemDetailShown", "itemDetailPoint")
        end
    end
end

L.RemoveRunEntry = function(index)
    local history = InstanceTrackerDB.runHistory or {}
    if index < 1 or index > #history then return end

    local detailFrame = L.ledgerDetailFrame
    local detailShown = detailFrame and detailFrame:IsShown()
    local detailPage = detailShown and detailFrame.detailPage or nil

    table.remove(history, index)
    L.ClearPendingRunDelete()

    if detailShown and detailPage then
        if detailPage == index then
            -- Deleted the open/highlighted run: close Run details + Items
            detailFrame:Hide()
            HideItemDetailFrame()
        else
            if detailPage > index then
                detailFrame.detailPage = detailPage - 1
            end
            if L.RefreshLedgerDetailUI then L.RefreshLedgerDetailUI() end
            -- Keep Items on the (possibly shifted) open run if still open
            local itemFrame = _G.InstanceTrackerItemDetailFrame
            if itemFrame and itemFrame:IsShown() and L.ShowItemDetail then
                local run = history[detailFrame.detailPage]
                if run then L.ShowItemDetail(run) end
            end
        end
    end

    L.AddonPrint(
        L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1) .. "Removed run #" .. index .. "."
    )
    if L.RefreshStatsUI then L.RefreshStatsUI() end
end

----------------------------------------------------------------------
-- Confirmation dialog for clearing history
----------------------------------------------------------------------
-- Rename run (ledger history entry); run.customName is saved in runHistory
StaticPopupDialogs["INSTANCETRACKER_RENAME_RUN"] = {
    text = "Rename this run:",
    button1 = "OK",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 80,
    editBoxWidth = 260,
    OnShow = function(self)
        if self.data and (self.data.customName or self.data.name) then
            self.editBox:SetText(self.data.customName or self.data.name or "")
            self.editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local run = self.data
        if run then
            run.customName = self.editBox:GetText():match("^%s*(.-)%s*$")
            if run.customName == "" then run.customName = nil end
            if L.statsFrame and L.statsFrame:IsShown() then L.RefreshStatsUI() end
            if L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown() and type(L.RefreshLedgerDetailUI) == "function" then
                L.RefreshLedgerDetailUI()
            end
            if _G.InstanceTrackerItemDetailFrame and _G.InstanceTrackerItemDetailFrame:IsShown() and _G.InstanceTrackerItemDetailFrame.RefreshItemDetailList then
                _G.InstanceTrackerItemDetailFrame:RefreshItemDetailList()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- GPH_AUTOSELL_CONFIRM is owned by __FugaziBAGS; do not register it here or it overwrites BAGS's popup and breaks "Yes, enable" (wrong DB + wrong L.frame).

StaticPopupDialogs["INSTANCETRACKER_CLEAR_ALL_DATA"] = {
    text = "Are you sure you want to HARD RESET all run history and lifetime stats for the current realm?\nThis cannot be undone.",
    button1 = "Yes, Hard Reset",
    button2 = "Cancel",
    OnAccept = function()
        local currentRealm = (GetRealmName and GetRealmName()) or ""
        local rh = InstanceTrackerDB.runHistory
        if rh then
            for idx = #rh, 1, -1 do
                local run = rh[idx]
                if not run.realmName or run.realmName == currentRealm then
                    table.remove(rh, idx)
                end
            end
        end
        if InstanceTrackerDB.lifetimeStatsByRealm then
            InstanceTrackerDB.lifetimeStatsByRealm[currentRealm] = {
                totalGoldCopper = 0,
                totalRuns = 0,
                rarityBreakdown = {},
                bestGPH = 0,
                zoneEfficiency = {},
                vendorCopper = 0,
                vendorItemCount = 0,
                repairCopper = 0,
                repairCount = 0,
                instanceDeaths = 0,
                autodeletedCount = 0,
                autodeletedCopper = 0,
            }
            L.LS = InstanceTrackerDB.lifetimeStatsByRealm[currentRealm]
        end
        if InstanceTrackerDB.autoVendorStatsByRealm then
            InstanceTrackerDB.autoVendorStatsByRealm[currentRealm] = { items = {}, totalCount = 0, totalVendorCopper = 0 }
            L.autoVendorStats = InstanceTrackerDB.autoVendorStatsByRealm[currentRealm]
        end
        if InstanceTrackerDB.autoDeleteStatsByRealm then
            InstanceTrackerDB.autoDeleteStatsByRealm[currentRealm] = { items = {}, totalCount = 0, totalVendorCopper = 0 }
            L.autoDeleteStats = InstanceTrackerDB.autoDeleteStatsByRealm[currentRealm]
        end
        if InstanceTrackerDB.lifetimeGoldGained then
            for key in pairs(InstanceTrackerDB.lifetimeGoldGained) do
                if key:match("^(.-)#") == currentRealm then
                    InstanceTrackerDB.lifetimeGoldGained[key] = nil
                end
            end
        end
        if InstanceTrackerDB.lifetimeDeaths then
            for key in pairs(InstanceTrackerDB.lifetimeDeaths) do
                if key:match("^(.-)#") == currentRealm then
                    InstanceTrackerDB.lifetimeDeaths[key] = nil
                end
            end
        end
        if _G.InstanceTrackerStatsFrame and _G.InstanceTrackerStatsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI(true) end
        if type(L.PrintMsg) == "function" then L.PrintMsg("All data hard reset for this realm.") end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["INSTANCETRACKER_CLEAR_HISTORY"] = {
    text = "Are you sure you want to clear run history for the current realm?\nThis cannot be undone.\n\nLifetime stats (vendored, repairs, autodeleted) will NOT be cleared.",
    button1 = "Yes, Clear",
    button2 = "Cancel",
    OnAccept = function()
        -- Only clear the run list for the current realm.
        -- Never touch lifetimeStats, autoVendorStats, autoDeleteStats, or any other persistent data.
        local rh = InstanceTrackerDB.runHistory
        if rh then
            local currentRealm = (GetRealmName and GetRealmName()) or ""
            for idx = #rh, 1, -1 do
                local run = rh[idx]
                if not run.realmName or run.realmName == currentRealm then
                    table.remove(rh, idx)
                end
            end
        else
            InstanceTrackerDB.runHistory = {}
        end
        if L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown() then L.ledgerDetailFrame:Hide() end
        L.AddonPrint(
            L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1) .. "Current realm run history cleared. Lifetime stats unchanged."
        )
        L.RefreshStatsUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

--- Returns { indices = list of runHistory indices for the tab (Sessions = GPH, Dungeons = non-GPH), ordinal = 1-based position of detailPage in that list }.
--- For tab 1 (Lifetime) returns session indices so nav can show "Run 1 of N" and Next goes to first session. Defined early for Ledger nav buttons.

----------------------------------------------------------------------
-- Ledger (Stats) Window: the "run log" Ã¢â‚¬â€ current run + history list.
-- L.CreateStatsFrame builds the window once; L.RefreshStatsUI fills it with rows.
----------------------------------------------------------------------
function L.CreateStatsFrame()
    local backdrop = {
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    }
    local f = CreateFrame("Frame", "InstanceTrackerStatsFrame", UIParent)
    f:SetWidth(340)
    f:SetHeight(400)
    -- Anchor by TOP so expanding grows downward (toward mouse), not upward
    f:SetPoint("TOP", UIParent, "CENTER", 0, 400)
    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.92)
    f:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local mainF = _G.InstanceTrackerFrame
        if mainF and mainF:IsShown() then
            local sx, mx = f:GetLeft(), mainF:GetRight()
            if sx and mx and (sx - mx) >= -120 and (sx - mx) <= 120 then
                local sb, st, mb, mt = f:GetBottom(), f:GetTop(), mainF:GetBottom(), mainF:GetTop()
                if sb and st and mb and mt and st > mb and sb < mt then
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", mainF, "TOPRIGHT", 4, 0)
                end
            end
        end
        L.SaveFrameLayout(f, "statsShown", "statsPoint")
    end)
    f:SetScript("OnHide", function()
        L.SaveFrameLayout(f, "statsShown", "statsPoint")
        f:SetScript("OnUpdate", nil)  -- stop update loop when closed so closure can be GC'd (reduces memory climb)
    end)
    f:SetScript("OnShow", function()
        if f._statsOnUpdate then f:SetScript("OnUpdate", f._statsOnUpdate) end
    end)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(10)

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    titleBar:SetBackdropColor(0.35, 0.28, 0.1, 0.7)
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    title:SetText("Ledger")
    title:SetTextColor(1, 0.85, 0.4, 1)

    -- Expose for skinning
    f.itTitleBar = titleBar
    f.itTitleText = title

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Search bar at top of Ledger (run name / item / rarity; opens Detail + item list on match)
    local ledgerSearchBar = CreateFrame("Frame", nil, f)
    ledgerSearchBar:SetHeight(26)
    ledgerSearchBar:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -4)
    ledgerSearchBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -4)
    f.ledgerSearchBar = ledgerSearchBar
    local ledgerSearchEdit = CreateFrame("EditBox", nil, ledgerSearchBar)
    ledgerSearchEdit:SetHeight(20)
    ledgerSearchEdit:SetPoint("LEFT", ledgerSearchBar, "LEFT", 0, 0)
    ledgerSearchEdit:SetPoint("RIGHT", ledgerSearchBar, "RIGHT", 0, 0)
    ledgerSearchEdit:SetAutoFocus(false)
    ledgerSearchEdit:SetFontObject("GameFontHighlightSmall")
    ledgerSearchEdit:SetTextInsets(6, 4, 0, 0)
    local searchBg = ledgerSearchEdit:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints()
    searchBg:SetTexture(0.1, 0.1, 0.15, 0.9)
    -- Watermark so empty bar still reads as "search" (3.3.5 has no native placeholder)
    local searchHint = ledgerSearchEdit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", ledgerSearchEdit, "LEFT", 6, 0)
    searchHint:SetPoint("RIGHT", ledgerSearchEdit, "RIGHT", -4, 0)
    searchHint:SetJustifyH("LEFT")
    searchHint:SetText("Search: zone, item, rare, epic, agility...")
    searchHint:SetTextColor(0.45, 0.45, 0.5, 0.9)
    ledgerSearchEdit.placeholder = searchHint
    local function UpdateLedgerSearchPlaceholder(self)
        local empty = not self:GetText() or self:GetText() == ""
        if self.placeholder then
            if empty then self.placeholder:Show() else self.placeholder:Hide() end
        end
    end
    ledgerSearchEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ledgerSearchEdit:SetScript("OnEditFocusGained", function(self)
        -- Keep hint while empty so the field still looks like search; hide only when typing
        UpdateLedgerSearchPlaceholder(self)
    end)
    ledgerSearchEdit:SetScript("OnEditFocusLost", function(self)
        UpdateLedgerSearchPlaceholder(self)
    end)
    -- BAGS search: click.ogg per character (OnChar), hover.ogg on backspace/shrink (OnTextChanged)
    ledgerSearchEdit:SetScript("OnChar", function()
        if L.PlayUIClickSound then L.PlayUIClickSound() end
    end)
    ledgerSearchEdit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local txt = self:GetText() or ""
            if (self._prevSearchLen or 0) > #txt then
                if L.PlayUIHoverSound then L.PlayUIHoverSound() end
            end
            self._prevSearchLen = #txt
        end
        UpdateLedgerSearchPlaceholder(self)
        if type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI() end
    end)
    ledgerSearchEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    UpdateLedgerSearchPlaceholder(ledgerSearchEdit)
    f.ledgerSearchEditBox = ledgerSearchEdit
    -- Ledger filter bar (Sort / Time / Scope / Value lens / Live+history / Reset)
    local ledgerBar = CreateFrame("Frame", nil, f)
    ledgerBar:SetHeight(18)
    ledgerBar:SetPoint("TOPLEFT", ledgerSearchBar, "BOTTOMLEFT", 0, -2)
    ledgerBar:SetPoint("TOPRIGHT", ledgerSearchBar, "BOTTOMRIGHT", 0, -2)
    f.ledgerBar = ledgerBar
    -- Width is known after anchors resolve; force layout size for slot math
    ledgerBar:SetWidth(340 - 12)
    if L.FilterBar and L.FilterBar.Attach then
        L.FilterBar.Attach(f, ledgerBar)
    else
        f.ledgerBarButtons = {}
    end

    -- Detail nav bar (Prev / Run X of Y / Next) at bottom of Ledger Ã¢â‚¬â€ always visible; Ledger is the "brain" navigator
    local detailNavBar = CreateFrame("Frame", nil, f)
    detailNavBar:SetHeight(26)
    detailNavBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 6)
    detailNavBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    f.detailNavBar = detailNavBar
    local detailPrevBtn = CreateFrame("Button", nil, detailNavBar)
    detailPrevBtn:SetSize(50, 20)
    detailPrevBtn:SetPoint("LEFT", detailNavBar, "LEFT", 0, 0)
    detailPrevBtn:SetNormalFontObject(GameFontNormalSmall)
    detailPrevBtn:SetHighlightFontObject(GameFontHighlightSmall)
    detailPrevBtn:SetText(L.ColorizeFugaziRowLabel("< Prev"))
    detailPrevBtn:SetScript("OnClick", function()
        if L.PlayUIClickSound then L.PlayUIClickSound() end
        local history = InstanceTrackerDB.runHistory or {}
        if #history == 0 then return end
        local detailPage = (L.ledgerDetailFrame and L.ledgerDetailFrame.detailPage) or 1
        local currentRealm = (GetRealmName and GetRealmName()) or ""
        local prevIdx = nil
        for i = detailPage - 1, 1, -1 do
            local r = history[i]
            if not r.realmName or r.realmName == currentRealm then
                prevIdx = i
                break
            end
        end
        if prevIdx then
            local run = history[prevIdx]
            local wantTab = IsGPHRun(run) and 2 or 3
            f.selectedTab = wantTab
            if _G.InstanceTrackerStatsFrame then _G.InstanceTrackerStatsFrame.selectedTab = wantTab end
            if type(ShowLedgerDetail) == "function" then ShowLedgerDetail(prevIdx) end
            if f:IsShown() and type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI() end
            local sc, nc, gc = { 0.4, 0.35, 0.15, 0.9 }, { 0.15, 0.15, 0.15, 0.7 }, { 0.25, 0.25, 0.22, 0.85 }
            if f.statsTab1 and f.statsTab1.bg then f.statsTab1.bg:SetTexture(unpack(nc)) end
            if f.statsTab2 and f.statsTab2.bg then f.statsTab2.bg:SetTexture(unpack(wantTab == 2 and sc or nc)) end
            if f.statsTab3 and f.statsTab3.bg then f.statsTab3.bg:SetTexture(unpack(wantTab == 3 and sc or nc)) end
        else
            f.selectedTab = 1
            if _G.InstanceTrackerStatsFrame then _G.InstanceTrackerStatsFrame.selectedTab = 1 end
            if L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown() then L.ledgerDetailFrame:Hide() end
            if f:IsShown() and type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI() end
            local sc, nc, gc = { 0.4, 0.35, 0.15, 0.9 }, { 0.15, 0.15, 0.15, 0.7 }, { 0.25, 0.25, 0.22, 0.85 }
            if f.statsTab1 and f.statsTab1.bg then f.statsTab1.bg:SetTexture(unpack(gc)) end
            if f.statsTab2 and f.statsTab2.bg then f.statsTab2.bg:SetTexture(unpack(nc)) end
            if f.statsTab3 and f.statsTab3.bg then f.statsTab3.bg:SetTexture(unpack(nc)) end
        end
        local page = (L.ledgerDetailFrame and L.ledgerDetailFrame.detailPage) or 1
        local run = history[page]
        if run and _G.InstanceTrackerItemDetailFrame and _G.InstanceTrackerItemDetailFrame:IsShown() then L.ShowItemDetail(run) end
    end)
    detailPrevBtn:SetScript("OnEnter", function(self)
        if L.PlayUIHoverSound then L.PlayUIHoverSound() end
        self:SetText("|cffffcc88< Prev|r")
    end)
    detailPrevBtn:SetScript("OnLeave", function(self) self:SetText(L.ColorizeFugaziRowLabel("< Prev")) end)
    f.detailNavPrevBtn = detailPrevBtn
    local detailNextBtn = CreateFrame("Button", nil, detailNavBar)
    detailNextBtn:SetSize(50, 20)
    detailNextBtn:SetPoint("RIGHT", detailNavBar, "RIGHT", 0, 0)
    detailNextBtn:SetNormalFontObject(GameFontNormalSmall)
    detailNextBtn:SetHighlightFontObject(GameFontHighlightSmall)
    detailNextBtn:SetText(L.ColorizeFugaziRowLabel("Next >"))
    detailNextBtn:SetScript("OnClick", function()
        if L.PlayUIClickSound then L.PlayUIClickSound() end
        local history = InstanceTrackerDB.runHistory or {}
        if #history == 0 then return end
        local tab = (f and f.selectedTab) or 1
        local detailPage = (L.ledgerDetailFrame and L.ledgerDetailFrame.detailPage) or 1
        local currentRealm = (GetRealmName and GetRealmName()) or ""
        local nextIdx = nil
        if tab == 1 then
            for i = 1, #history do
                local r = history[i]
                if not r.realmName or r.realmName == currentRealm then
                    nextIdx = i
                    break
                end
            end
        else
            for i = detailPage + 1, #history do
                local r = history[i]
                if not r.realmName or r.realmName == currentRealm then
                    nextIdx = i
                    break
                end
            end
        end
        if nextIdx then
            local run = history[nextIdx]
            local wantTab = IsGPHRun(run) and 2 or 3
            f.selectedTab = wantTab
            if _G.InstanceTrackerStatsFrame then _G.InstanceTrackerStatsFrame.selectedTab = wantTab end
            if type(ShowLedgerDetail) == "function" then ShowLedgerDetail(nextIdx) end
            if f:IsShown() and type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI() end
            local sc, nc, gc = { 0.4, 0.35, 0.15, 0.9 }, { 0.15, 0.15, 0.15, 0.7 }, { 0.25, 0.25, 0.22, 0.85 }
            if f.statsTab1 and f.statsTab1.bg then f.statsTab1.bg:SetTexture(unpack(nc)) end
            if f.statsTab2 and f.statsTab2.bg then f.statsTab2.bg:SetTexture(unpack(wantTab == 2 and sc or nc)) end
            if f.statsTab3 and f.statsTab3.bg then f.statsTab3.bg:SetTexture(unpack(wantTab == 3 and sc or nc)) end
        end
        local page = (L.ledgerDetailFrame and L.ledgerDetailFrame.detailPage) or 1
        local run = history[page]
        if run and _G.InstanceTrackerItemDetailFrame and _G.InstanceTrackerItemDetailFrame:IsShown() then L.ShowItemDetail(run) end
    end)
    detailNextBtn:SetScript("OnEnter", function(self)
        if L.PlayUIHoverSound then L.PlayUIHoverSound() end
        self:SetText("|cffffcc88Next >|r")
    end)
    detailNextBtn:SetScript("OnLeave", function(self) self:SetText(L.ColorizeFugaziRowLabel("Next >")) end)
    f.detailNavNextBtn = detailNextBtn
    local detailPageLabel = detailNavBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailPageLabel:SetPoint("CENTER", detailNavBar, "CENTER", 0, 0)
    detailPageLabel:SetTextColor(0.85, 0.75, 0.5, 1)
    f.detailNavPageLabel = detailPageLabel

    -- Scroll frame; sits below ledger bar, above detail nav when visible
    local scrollFrame = CreateFrame("ScrollFrame", "InstanceTrackerStatsScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", ledgerBar, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", detailNavBar, "TOPRIGHT", -28, 4)
    f.scrollFrame = scrollFrame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(L.SCROLL_CONTENT_WIDTH)
    content:SetHeight(1)
    content:EnableMouse(true)
    scrollFrame:SetScrollChild(content)
    f.content = content

    -- Enable shared skinning with __FugaziBAGS
    f.ApplySkin = function()
        L.ApplyInstanceTrackerSkin(f)
    end
    L.ApplyInstanceTrackerSkin(f)
    -- Match FugaziBAGS scrollbar look
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.SkinScrollBar then
        _G.__FugaziBAGS_Skins.SkinScrollBar(scrollFrame)
    end

    -- Clear button with confirmation
    local clearBtn = CreateFrame("Button", nil, f)
    clearBtn:EnableMouse(true)
    clearBtn:SetHitRectInsets(0, 0, 0, 0)
    clearBtn:SetWidth(45)
    clearBtn:SetHeight(18)
    clearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    local clearBg = clearBtn:CreateTexture(nil, "BACKGROUND")
    clearBg:SetAllPoints()
    clearBg:SetTexture(0.3, 0.15, 0.1, 0.7)
    clearBtn.bg = clearBg
    local clearText = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    clearText:SetPoint("CENTER")
    clearText:SetText("|cffff8844Clear|r")
    clearBtn.label = clearText
    clearBtn:SetScript("OnClick", function()
        if IsControlKeyDown() then
            StaticPopup_Show("INSTANCETRACKER_CLEAR_ALL_DATA")
        else
            StaticPopup_Show("INSTANCETRACKER_CLEAR_HISTORY")
        end
    end)
    clearBtn:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.5, 0.25, 0.1, 0.8)
        self.label:SetText("|cffffaa66Clear|r")
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Clear All Run History", 1, 0.6, 0.2)
        GameTooltip:AddLine("Hold CTRL to Hard Reset ALL data", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    clearBtn:SetScript("OnLeave", function(self)
        self.bg:SetTexture(0.3, 0.15, 0.1, 0.7)
        self.label:SetText("|cffff8844Clear|r")
        GameTooltip:Hide()
    end)

    -- Tabs: Lifetime (always-on stats) | Sessions (manual GPH) | Dungeons (auto-recorded)
    local statsTab1 = CreateFrame("Button", nil, f)
    statsTab1:SetSize(58, 20)
    statsTab1:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 4, -4)
    local statsTab1Bg = statsTab1:CreateTexture(nil, "BACKGROUND")
    statsTab1Bg:SetAllPoints()
    statsTab1.bg = statsTab1Bg
    local statsTab1Text = statsTab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsTab1Text:SetPoint("CENTER")
    statsTab1Text:SetText("Lifetime")
    statsTab1.text = statsTab1Text

    local statsTab2 = CreateFrame("Button", nil, f)
    statsTab2:SetSize(58, 20)
    statsTab2:SetPoint("LEFT", statsTab1, "RIGHT", 2, 0)
    local statsTab2Bg = statsTab2:CreateTexture(nil, "BACKGROUND")
    statsTab2Bg:SetAllPoints()
    statsTab2.bg = statsTab2Bg
    local statsTab2Text = statsTab2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsTab2Text:SetPoint("CENTER")
    statsTab2Text:SetText("Sessions")
    statsTab2.text = statsTab2Text

    local statsTab3 = CreateFrame("Button", nil, f)
    statsTab3:SetSize(58, 20)
    statsTab3:SetPoint("LEFT", statsTab2, "RIGHT", 2, 0)
    local statsTab3Bg = statsTab3:CreateTexture(nil, "BACKGROUND")
    statsTab3Bg:SetAllPoints()
    statsTab3.bg = statsTab3Bg
    local statsTab3Text = statsTab3:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsTab3Text:SetPoint("CENTER")
    statsTab3Text:SetText("Dungeons")
    statsTab3.text = statsTab3Text
    f.statsTab1 = statsTab1
    f.statsTab2 = statsTab2
    f.statsTab3 = statsTab3

    f.selectedTab = 1
    if L.currentRun then f.selectedTab = 3 end
    local function UpdateStatsTabs()
        -- Use global L.frame as source of truth so nav-button tab switch always matches
        local frameRef = _G.InstanceTrackerStatsFrame or f
        local tab = (frameRef and frameRef.selectedTab) or 1
        local selectedColor = { 0.4, 0.35, 0.15, 0.9 }
        local normalColor = { 0.15, 0.15, 0.15, 0.7 }
        local greyColor = { 0.25, 0.25, 0.22, 0.85 }

        -- Search bar + ledger bar visible on all tabs (Lifetime, Sessions, Dungeons)
        if f.ledgerSearchBar then f.ledgerSearchBar:Show() end
        if f.ledgerBar then f.ledgerBar:Show() end
        f.scrollFrame:SetPoint("TOPLEFT", f.ledgerBar, "BOTTOMLEFT", 0, -4)
        if f.scrollFrame and f.scrollFrame.SetVerticalScroll then f.scrollFrame:SetVerticalScroll(0) end

        L.RefreshStatsUI()
        -- Apply tab button highlight from current selectedTab (re-read in case L.RefreshStatsUI or handler set it)
        local curTab = (frameRef and frameRef.selectedTab) or 1
        statsTab1.bg:SetTexture(unpack(curTab == 1 and greyColor or normalColor))
        statsTab2.bg:SetTexture(unpack(curTab == 2 and selectedColor or normalColor))
        statsTab3.bg:SetTexture(unpack(curTab == 3 and selectedColor or normalColor))
        if L.FilterBar and L.FilterBar.UpdateGlows then
            L.FilterBar.UpdateGlows(f)
        end
    end
    statsTab1:SetScript("OnClick", function()
        f.selectedTab = 1; UpdateStatsTabs()
    end)
    statsTab2:SetScript("OnClick", function()
        f.selectedTab = 2; UpdateStatsTabs()
    end)
    statsTab3:SetScript("OnClick", function()
        f.selectedTab = 3; UpdateStatsTabs()
    end)
    f.UpdateStatsTabs = UpdateStatsTabs
    UpdateStatsTabs()

    -- Search bar repositioned below tabs
    ledgerSearchBar:ClearAllPoints()
    ledgerSearchBar:SetPoint("TOPLEFT", statsTab1, "BOTTOMLEFT", 0, -4)
    ledgerSearchBar:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -4)

    local stats_elapsed = 0
    f._statsOnUpdate = function(self, elapsed)
        stats_elapsed = stats_elapsed + elapsed
        if stats_elapsed >= 1 then
            stats_elapsed = 0
            local fontSettings = L.GetFugaziFontSettings()
            local fontHash = (fontSettings.titlePath or "") .. (fontSettings.titleSize or 0) .. (fontSettings.rowSize or 0) .. (fontSettings.rowFontPath or "")
            if not f.lastFontHash then f.lastFontHash = fontHash end
            if f.lastFontHash ~= fontHash then
                f.lastFontHash = fontHash
                if _G.InstanceTrackerFrame then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerFrame) end
                if _G.InstanceTrackerStatsFrame then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerStatsFrame) end
                if _G.InstanceTrackerLedgerDetailFrame then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerLedgerDetailFrame) end
                if _G.InstanceTrackerItemDetailFrame then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerItemDetailFrame) end
                if type(L.RefreshUI) == "function" then L.RefreshUI() end
                if type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI() end
                if type(L.RefreshLedgerDetailUI) == "function" then L.RefreshLedgerDetailUI() end
            end
            -- Live dungeon timer/gold only: set text on existing rows (no full rebuild).
            if L.currentRun and self.selectedTab == 3 then
                local rDur = self._liveRunDurRow
                local dur = time() - L.currentRun.enterTime
                local liveGold = GetMoney() - (L.startingGold or 0)
                if liveGold < 0 then liveGold = 0 end
                local p = self._liveValueParts or {}
                local vendorCu, ahCu, destroyCu = p.vendor or 0, p.ah or 0, p.destroy or 0
                local totalCu = liveGold + vendorCu + ahCu + destroyCu
                local lens = (L.FilterBar and L.FilterBar.GetField and L.FilterBar.GetField("lens")) or "raw"
                local lensCu = liveGold
                if lens == "vendor" then lensCu = vendorCu
                elseif lens == "ah" then lensCu = ahCu
                elseif lens == "destroy" then lensCu = destroyCu
                elseif lens == "est" then lensCu = totalCu
                elseif lens == "gph" then lensCu = (dur > 0) and (totalCu / (dur / 3600)) or 0
                end
                if rDur and rDur:IsShown() then
                    local liveName = "|cffffffcc" .. (L.currentRun.name or "?") .. "|r"
                    if L.runSoftPaused then
                        liveName = liveName .. " |cff888888(paused)|r"
                    end
                    local liveSubLeft = "|cffaaaaaa" .. (L.FormatTimeMedium and L.FormatTimeMedium(dur) or dur .. "s") .. "|r  |cff888888" .. (L.FormatDateTime and L.FormatDateTime(L.currentRun.enterTime) or "") .. "|r"
                    local liveGoldText = L.FormatGold and L.FormatGold(lensCu) or tostring(math.floor(lensCu + 0.5))
                    if lens == "gph" then liveGoldText = liveGoldText .. " |cffffd700/h|r" end
                    if L.LayoutStatsRowTexts then
                        L.LayoutStatsRowTexts(rDur, liveName, "", liveSubLeft, liveGoldText)
                    else
                        if rDur.subLeft then rDur.subLeft:SetText(liveSubLeft) end
                        if rDur.subRight then rDur.subRight:SetText(liveGoldText) end
                    end
                end
                if self._liveRawGoldRow and self._liveRawGoldRow:IsShown() then
                    local g = L.FormatGold and L.FormatGold(liveGold) or tostring(liveGold)
                    if L.LayoutStatsRowTexts and self._liveRawGoldRow._fullLeftText then
                        L.LayoutStatsRowTexts(self._liveRawGoldRow, self._liveRawGoldRow._fullLeftText, g)
                    elseif self._liveRawGoldRow.right then
                        self._liveRawGoldRow.right:SetText(g)
                    end
                end
                if self._liveEstTotalRow and self._liveEstTotalRow:IsShown() then
                    local g = L.FormatGold and L.FormatGold(totalCu) or tostring(totalCu)
                    if L.LayoutStatsRowTexts and self._liveEstTotalRow._fullLeftText then
                        L.LayoutStatsRowTexts(self._liveEstTotalRow, self._liveEstTotalRow._fullLeftText, g)
                    elseif self._liveEstTotalRow.right then
                        self._liveEstTotalRow.right:SetText(g)
                    end
                end
                if self._liveGphRow and self._liveGphRow:IsShown() then
                    local gphLive = (dur > 0) and (totalCu / (dur / 3600)) or 0
                    local g = L.FormatGold and L.FormatGold(gphLive) or tostring(math.floor(gphLive + 0.5))
                    g = g .. " |cffffd700/h|r"
                    if L.LayoutStatsRowTexts and self._liveGphRow._fullLeftText then
                        L.LayoutStatsRowTexts(self._liveGphRow, self._liveGphRow._fullLeftText, g)
                    elseif self._liveGphRow.right then
                        self._liveGphRow.right:SetText(g)
                    end
                end
            end
        end
    end
    -- Light OnUpdate for font-hash + live timer; loot-driven rebuilds go through DiffBags / events.
    f:SetScript("OnUpdate", f._statsOnUpdate)
    return f
end

--- Fills the scroll content with always-on lifetime stats (no sessions/dungeons). Tab 1 only.
function L.RefreshStatsLifetimeUI(content)
    -- Use existing lifetimeStats; never replace it (lifetime must never reset on reload).
    local LS = L.LS or {}
    local yOff = 6
    local fontSettings = L.GetFugaziFontSettings()
    local hdrSpacing = (fontSettings.headerSize or 11) + 8
    local rowH = L.GetFugaziRowHeight(18)
    local sectionGap = 8
    content._statHoverFrames = content._statHoverFrames or {}
    for _, hf in ipairs(content._statHoverFrames) do if hf then hf:Hide() end end

    local currentRealm = (GetRealmName and GetRealmName()) or ""
    local playerName = (UnitName and UnitName("player")) or ""
    local scope = (L.FilterBar and L.FilterBar.GetField and L.FilterBar.GetField("scope")) or "realm"
    local scopeChar = (scope == "char")

    -- Realm#Name key match for wallet / death maps (Scope Char vs Realm).
    local function KeyInScope(key)
        if not key then return false end
        local r, c = tostring(key):match("^(.-)#(.*)$")
        if not r then return false end
        if r ~= currentRealm then return false end
        if scopeChar then return c == playerName end
        return true
    end
    local function ScopeLabelShort()
        return scopeChar and "this character" or "this realm"
    end

    local statsHost = _G.InstanceTrackerStatsFrame or L.statsFrame

    -- Smart tooltip anchor (same as filter bar: prefer left of Ledger, flip if needed)
    local function LifetimeTipAnchor(owner)
        if L.FilterBar and L.FilterBar.AnchorTooltip then
            L.FilterBar.AnchorTooltip(owner, statsHost)
        else
            GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        end
        GameTooltip:ClearLines()
    end

    local statHoverIdx = 0
    --- Label left, value right; left is width-capped so gold never overlaps (shared layout helper).
    local function LayoutValueRow(row, label, valueText)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
        local leftT = L.ColorizeFugaziRowLabel and L.ColorizeFugaziRowLabel(label) or label
        if L.LayoutStatsRowTexts then
            L.LayoutStatsRowTexts(row, leftT, valueText or "")
        else
            row.right:ClearAllPoints()
            row.left:ClearAllPoints()
            row.right:SetJustifyH("RIGHT")
            row.right:SetWordWrap(false)
            row.right:SetText(valueText or "")
            local rightW = row.right:GetStringWidth() or 80
            if rightW < 64 then rightW = 64 end
            if rightW > 150 then rightW = 150 end
            row.right:SetWidth(rightW)
            row.right:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.left:SetJustifyH("LEFT")
            row.left:SetWordWrap(false)
            row.left:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
            row.left:SetText(leftT)
        end
        return row:GetHeight()
    end

    local function AddStat(label, value, color, fullTextForTooltip)
        local row = L.GetStatsRow(content, false)
        local displayValue = (value and value:match("|c")) and value or ((color or "|cffffffff") .. (value or "") .. "|r")
        local plainValue = fullTextForTooltip or (L.StripColorCodes and L.StripColorCodes(displayValue)) or displayValue
        LayoutValueRow(row, label .. ":", displayValue)
        if fullTextForTooltip and #plainValue > 20 then
            statHoverIdx = statHoverIdx + 1
            local hf = content._statHoverFrames[statHoverIdx]
            if not hf then
                hf = CreateFrame("Frame", nil, content)
                hf:EnableMouse(true)
                content._statHoverFrames[statHoverIdx] = hf
            end
            hf._fullText = fullTextForTooltip
            hf:SetScript("OnEnter", function(self)
                if not self._fullText then return end
                LifetimeTipAnchor(self)
                GameTooltip:AddLine(self._fullText, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            hf:SetScript("OnLeave", function() GameTooltip:Hide() end)
            hf:ClearAllPoints()
            hf:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
            hf:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", L.SCROLL_CONTENT_WIDTH - 8, -(yOff + row:GetHeight()))
            hf:EnableMouse(true)
            hf:Show()
        end
        yOff = yOff + row:GetHeight()
    end

    local function PlaceStickyHover(hoverFrame, height)
        hoverFrame:ClearAllPoints()
        hoverFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
        hoverFrame:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", L.SCROLL_CONTENT_WIDTH - 8, -(yOff + height))
        hoverFrame:EnableMouse(true)
        hoverFrame:Show()
    end

    -- --- Wallet first (stable position; scope only changes header/totals) ---
    local walletHdr = L.GetStatsText(content)
    walletHdr:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
    walletHdr:SetText("--- Wallet (" .. ScopeLabelShort() .. ") ---")
    L.StyleFugaziHeader(walletHdr)
    yOff = yOff + hdrSpacing

    local AG = InstanceTrackerDB.accountGold or {}
    local ckey = L.GetGphCharKey()
    AG[ckey] = GetMoney()
    local accountGoldTotal = 0
    for key, v in pairs(AG) do
        if KeyInScope(key) then
            accountGoldTotal = accountGoldTotal + (v or 0)
        end
    end
    local currentGoldRow = L.GetStatsRow(content, false)
    -- Scope is in the section header; keep labels short so amounts never collide
    local currentGoldRowH = LayoutValueRow(currentGoldRow, "Current gold:", L.FormatGold(accountGoldTotal))
    if not content.summaryGoldHoverFrame then
        content.summaryGoldHoverFrame = CreateFrame("Frame", nil, content)
        content.summaryGoldHoverFrame:EnableMouse(true)
        content.summaryGoldHoverFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    content.summaryGoldHoverFrame:SetScript("OnEnter", function(self)
        LifetimeTipAnchor(self)
        GameTooltip:AddLine(scopeChar and "This character" or "Per character (this realm); main line = sum", 0.6, 0.85, 0.6)
        local map = InstanceTrackerDB.accountGold or {}
        local total = 0
        for key, v in pairs(map) do
            if KeyInScope(key) then total = total + (v or 0) end
        end
        GameTooltip:AddLine(L.FormatGoldPlain(total), 1, 0.85, 0.4)
        for key, copper in pairs(map) do
            if KeyInScope(key) then
                local label = (key and tostring(key):gsub("#", " - ")) or "?"
                GameTooltip:AddLine(label .. ": " .. L.FormatGoldPlain(copper or 0), 0.8, 0.8, 0.8)
            end
        end
        GameTooltip:Show()
    end)
    PlaceStickyHover(content.summaryGoldHoverFrame, currentGoldRowH)
    yOff = yOff + currentGoldRowH + 2

    local totalGained = 0
    for key, v in pairs(InstanceTrackerDB.lifetimeGoldGained or {}) do
        if KeyInScope(key) then totalGained = totalGained + (v or 0) end
    end
    local lifetimeGoldRow = L.GetStatsRow(content, false)
    local lifetimeGoldRowH = LayoutValueRow(lifetimeGoldRow, "Gold gained:", L.FormatGold(totalGained))
    if not content.lifetimeGoldHoverFrame then
        content.lifetimeGoldHoverFrame = CreateFrame("Frame", nil, content)
        content.lifetimeGoldHoverFrame:EnableMouse(true)
        content.lifetimeGoldHoverFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    content.lifetimeGoldHoverFrame:SetScript("OnEnter", function(self)
        LifetimeTipAnchor(self)
        GameTooltip:AddLine("Lifetime gold gained (per character in scope)", 0.6, 0.85, 0.6)
        local LG = InstanceTrackerDB.lifetimeGoldGained or {}
        for key, copper in pairs(LG) do
            if KeyInScope(key) then
                local label = (key and tostring(key):gsub("#", " - ")) or "?"
                GameTooltip:AddLine(label .. ": " .. L.FormatGold(copper or 0), 0.8, 0.8, 0.8)
            end
        end
        GameTooltip:Show()
    end)
    PlaceStickyHover(content.lifetimeGoldHoverFrame, lifetimeGoldRowH)
    yOff = yOff + lifetimeGoldRowH + sectionGap

    -- Filter preview BELOW wallet (Time/Scope/Lens). No grey "always-on" note.
    local showFilterPreview = false
    if L.FilterBar and L.FilterBar.Get then
        local st = L.FilterBar.Get()
        local d = L.FilterBar.DEFAULTS
        if st and d and (st.time ~= d.time or st.scope ~= d.scope or st.lens ~= d.lens) then
            showFilterPreview = true
        end
    end
    if showFilterPreview then
        local fStats = L.LedgerData.GetLifetimeStats and L.LedgerData.GetLifetimeStats() or nil
        local filtHdr = L.GetStatsText(content)
        filtHdr:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
        filtHdr:SetText("--- History filter preview ---")
        L.StyleFugaziHeader(filtHdr)
        yOff = yOff + hdrSpacing

        -- Two-line: left truncates, gold pinned right (same rules as live/history).
        local row = L.GetStatsRow(content, false, true)
        row:SetWidth(L.SCROLL_CONTENT_WIDTH or 296)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD or 4, -yOff)
        if fStats then
            local nRuns = fStats.totalRuns or 0
            local goldStr = L.FormatGold and L.FormatGold(fStats.totalGold or 0) or tostring(fStats.totalGold or 0)
            local lensShort = (L.FilterBar.LensShort and L.FilterBar.LensShort()) or "value"
            local lensTip = (L.FilterBar.LensLabel and L.FilterBar.LensLabel()) or lensShort
            local topLeft = string.format("|cffaaaaaa%d runs|r", nRuns)
            local subLeft = string.format("|cff888888(%s)|r", lensShort)
            if L.LayoutStatsRowTexts then
                L.LayoutStatsRowTexts(row, topLeft, goldStr, subLeft, "")
            else
                row.left:SetText(topLeft)
                row.right:SetText(goldStr)
                if row.subLeft then row.subLeft:SetText(subLeft) end
            end
            local fullTip = string.format("%d runs · %s · %s", nRuns, lensTip,
                (L.StripColorCodes and L.StripColorCodes(goldStr)) or goldStr)
            if L.BindRowClickArea then
                L.BindRowClickArea(row, nil, function(self)
                    GameTooltip:SetOwner(self.clickArea or self, "ANCHOR_CURSOR")
                    GameTooltip:AddLine("History filter preview", 0.6, 0.85, 0.6)
                    GameTooltip:AddLine(fullTip, 1, 1, 1, true)
                    if L.FilterBar and L.FilterBar.Get then
                        local st = L.FilterBar.Get()
                        if st then
                            GameTooltip:AddLine("Time: " .. tostring(st.time or "?"), 0.75, 0.75, 0.75)
                            GameTooltip:AddLine("Scope: " .. tostring(st.scope or "?"), 0.75, 0.75, 0.75)
                            GameTooltip:AddLine("Lens: " .. tostring(lensTip), 0.75, 0.75, 0.75)
                        end
                    end
                    GameTooltip:Show()
                end, function() GameTooltip:Hide() end)
            end
        else
            if L.LayoutStatsRowTexts then
                L.LayoutStatsRowTexts(row, "|cff888888Filters active (preview unavailable).|r", "", "", "")
            else
                row.left:SetText("|cff888888Filters active (preview unavailable).|r")
            end
        end
        yOff = yOff + row:GetHeight() + sectionGap
    end

    -- --- Economy & activity ---
    local econHeader = L.GetStatsText(content)
    econHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
    econHeader:SetText("--- Economy & activity ---")
    L.StyleFugaziHeader(econHeader)
    yOff = yOff + hdrSpacing
    -- Label left, gold right only (counts go in the label — not crammed into the right value).
    local vendN = LS.vendorItemCount or 0
    AddStat("Vendored (" .. vendN .. ")", L.FormatGold(LS.vendorCopper or 0), nil)
    local repN = LS.repairCount or 0
    AddStat("Repairs (" .. repN .. ")", L.FormatGold(LS.repairCopper or 0), nil)
    if LS.bestGPH and LS.bestGPH > 0 then
        AddStat("Best GPH", L.FormatGold(LS.bestGPH) .. " |cffffd700/h|r", nil, "Best recorded gold-per-hour (lifetime)")
    end

    local totalDeaths = 0
    for key, v in pairs(InstanceTrackerDB.lifetimeDeaths or {}) do
        if KeyInScope(key) then totalDeaths = totalDeaths + (v or 0) end
    end
    local deathsRow = L.GetStatsRow(content, false)
    local deathsRowH = LayoutValueRow(deathsRow, "Deaths:", "|cffcc6666" .. tostring(totalDeaths) .. "|r")
    if not content.lifetimeDeathsHoverFrame then
        content.lifetimeDeathsHoverFrame = CreateFrame("Frame", nil, content)
        content.lifetimeDeathsHoverFrame:EnableMouse(true)
        content.lifetimeDeathsHoverFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    content.lifetimeDeathsHoverFrame:SetScript("OnEnter", function(self)
        LifetimeTipAnchor(self)
        GameTooltip:AddLine("Deaths (per character in scope)", 0.6, 0.85, 0.6)
        local LD = InstanceTrackerDB.lifetimeDeaths or {}
        for key, n in pairs(LD) do
            if KeyInScope(key) then
                local label = (key and tostring(key):gsub("#", " - ")) or "?"
                GameTooltip:AddLine(label .. ": " .. tostring(n or 0), 0.8, 0.8, 0.8)
            end
        end
        GameTooltip:Show()
    end)
    PlaceStickyHover(content.lifetimeDeathsHoverFrame, deathsRowH)
    yOff = yOff + deathsRowH + sectionGap

    local delStats = L.autoDeleteStats
    local totalDeleted = (delStats and delStats.totalCount) or (LS.deletedItemCount or 0)
    local totalDeletedCopper = (delStats and delStats.totalVendorCopper) or 0
    local autodelTooltip = string.format("%d items, %s lost", totalDeleted or 0, L.FormatGoldPlain(totalDeletedCopper or 0))
    AddStat("Autodeleted (" .. (totalDeleted or 0) .. ")", L.FormatGold(totalDeletedCopper or 0), nil, autodelTooltip)
    yOff = yOff + sectionGap

    -- Shared painter for top autodelete / autosell lists
    local function PaintTopItemList(headerText, statsTable, emptyText)
        if not statsTable or not statsTable.items then return end
        local delHeader = L.GetStatsText(content)
        delHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
        delHeader:SetText(headerText)
        L.StyleFugaziHeader(delHeader)
        yOff = yOff + hdrSpacing
        local tmp = {}
        for itemId, entry in pairs(statsTable.items) do
            tmp[#tmp + 1] = { itemId = itemId, count = entry.count or 0, copper = entry.vendorCopper or 0 }
        end
        table.sort(tmp, function(a, b) return a.copper > b.copper end)
        local rightMargin, rightBlockW, shown = 12, 108, 0
        for i = 1, math.min(5, #tmp) do
            local row = tmp[i]
            if row.count > 0 then
                local r = L.GetTopItemRow(content, fontSettings, rowH, rightMargin, rightBlockW)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
                r:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                r:SetHeight(rowH)
                r.indexFs:SetText(string.format("|cffcccccc%d.|r ", i))
                local name, quality, link = tostring(row.itemId), 0, nil
                if GetItemInfo then
                    local n, l, q = GetItemInfo(row.itemId)
                    if n then name = n end
                    if q then quality = q end
                    if l then link = l end
                end
                local fullName = name
                if #name > 14 then name = name:sub(1, 11) .. "..." end
                local qInfo = L.QUALITY_COLORS[quality] or L.QUALITY_COLORS[1]
                r.itemBtn.fs:SetText("|cff" .. qInfo.hex .. name .. "|r")
                r.itemBtn.itemLink = link or ("item:" .. row.itemId)
                r.itemBtn.fullName = (#(fullName or "") > 14) and fullName or nil
                r.rightFs:SetText(string.format("|cffffffffx%d|r  %s", row.count, L.FormatGoldShort(row.copper or 0)))
                r.rightFs:SetWidth(rightBlockW)
                r.rightFs:SetWordWrap(false)
                r.goldHover.copper = row.copper or 0
                r.goldHover:ClearAllPoints()
                r.goldHover:SetPoint("TOPRIGHT", r, "TOPRIGHT", -rightMargin, 0)
                r.goldHover:SetSize(rightBlockW, rowH)
                yOff = yOff + rowH
                shown = shown + 1
            end
        end
        if shown == 0 then
            local none = L.GetStatsText(content)
            none:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
            none:SetText(emptyText or "|cff888888No data yet.|r")
            yOff = yOff + rowH
        end
        yOff = yOff + sectionGap
    end

    PaintTopItemList("--- Top autodeleted items ---", delStats, "|cff888888No autodelete data yet.|r")
    PaintTopItemList("--- Top autosold items ---", L.autoVendorStats, "|cff888888No autosell data yet.|r")

    -- History counts: Clear only wipes *this realm*; other realms remain in the table.
    local hist = InstanceTrackerDB.runHistory or {}
    local cap = L.MAX_RUN_HISTORY or 999
    local totalStored = #hist
    local realmStored = 0
    for _, run in ipairs(hist) do
        if not run.realmName or run.realmName == currentRealm then
            realmStored = realmStored + 1
        end
    end
    local capNote = L.GetStatsText(content)
    capNote:SetPoint("TOPLEFT", content, "TOPLEFT", L.CONTENT_LEFT_PAD, -yOff)
    if totalStored >= cap then
        capNote:SetText("|cff886622Stored: " .. totalStored .. "/" .. cap .. " (full)|r")
    else
        -- Global stored count (Clear only wipes this realm; other realms remain)
        capNote:SetText("|cff555555Stored (all realms): " .. totalStored .. "/" .. cap .. "|r")
    end
    yOff = yOff + rowH

    content:SetHeight(math.max(24, yOff + sectionGap))
    return yOff + 4
end
