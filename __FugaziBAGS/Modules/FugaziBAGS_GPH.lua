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

--- Scan differences in bags for the session (inventory ledger).
local function ScanGPHSessionDeltas(session, sessionBaseline, sessionGained, isGPH)
    local current = A.ScanBags and A.ScanBags()
    if not current then return end
    
    local currentEquipped = A.GetEquippedItemIds and A.GetEquippedItemIds()
    
    -- UNIFIED GEAR PROTECTION: Runs always, even without a GPH session active
    if A.HandleGearProtection and currentEquipped then
        A.HandleGearProtection(currentEquipped, A.lastEquippedItemIds)
    end
    
    -- Update tracking of historical gear (always)
    if currentEquipped then
        wipe(A.lastEquippedItemIds)
        for id in pairs(currentEquipped) do A.lastEquippedItemIds[id] = true end
    end

    if not session then return end
    -- (rest of the session-only logic follows below)

    for itemId, count in pairs(current) do
        local base = sessionBaseline[itemId] or 0
        local delta = count - base
        
        local itemLinksCache = A.itemLinksCache
        local link = itemLinksCache and itemLinksCache[itemId]
        -- Fallback to GetItemInfo if link is missing from primary cache
        if not link then
            _, link = A.GetCachedItemInfo(itemId)
        end
        
        local quality = 0
        if link then
            _, _, quality = A.GetCachedItemInfo(link)
            quality = quality or 0
        end

        local protected = (A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, quality))
        
        if delta > 0 then
            if (protected or itemId == A.HEARTHSTONE_ID) then
                sessionGained[itemId] = delta
            else
                local prevSeen = sessionGained[itemId] or 0
                if delta > prevSeen then
                    local diff = delta - prevSeen
                    sessionGained[itemId] = delta
                    
                    local itemLinksCache = A.itemLinksCache
                    local link = itemLinksCache and itemLinksCache[itemId]
                    -- Fallback to GetItemInfo if link is missing from primary cache
                    if not link and GetItemInfo then
                        _, link = A.GetCachedItemInfo(itemId)
                    end
                    
                    if link then
                        local name, _, quality = A.GetCachedItemInfo(link)
                        quality = quality or 0
                        session.qualityCounts[quality] = (session.qualityCounts[quality] or 0) + diff
                        if not session.items[itemId] then
                            session.items[itemId] = { link = link, quality = quality, count = 0, name = name or "Unknown" }
                        end
                        session.items[itemId].count = session.items[itemId].count + diff
                        session.items[itemId].link = link
                    end
                end
            end
        end
    end
    
    for itemId, data in pairs(session.items or {}) do
        local cur = current[itemId] or 0
        local base = sessionBaseline[itemId] or 0
        local net = cur - base
        data.remaining = math.max(0, net)
        if net == 0 then sessionGained[itemId] = nil else sessionGained[itemId] = net end
    end
    
    local SV = _G.FugaziBAGSDB
    if SV then 
        SV.gphSession, SV.gphBagBaseline, SV.gphItemsGained = session, sessionBaseline, sessionGained 
    end
end

local function StartGPHSession()
    A.AddonPrint("|cff66ccff[GPH]|r Starting session init...")
    gphSession = { 
        startTime = time(), 
        startUptime = GetTime(),
        startGold = GetMoney(), 
        items = {}, 
        qualityCounts = {}, 
        deaths = 0,
        vendoredItemCount = {},
        autodeletedItemCount = {}
    }
    
    local scan = A.ScanBags and A.ScanBags()
    gphBagBaseline = {}
    if scan then
        for id, cnt in pairs(scan) do gphBagBaseline[id] = cnt end
    end
    gphItemsGained = {}
    
    -- Protect currently equipped items
    local protectedSet = A.GetGphProtectedSet and A.GetGphProtectedSet()
    if protectedSet and A.GetEquippedItemIds then
        for id in pairs(A.GetEquippedItemIds()) do protectedSet[id] = true end
    end
    
    local SV = _G.FugaziBAGSDB
    if SV then SV.gphSession, SV.gphBagBaseline, SV.gphItemsGained = gphSession, gphBagBaseline, gphItemsGained end
    _G.gphSession = gphSession
    A.AddonPrint("|cff66ccff[GPH]|r session started.")
end


local function StopGPHSession()
    if not gphSession then return end
    
    -- Do one final delta scan
    ScanGPHSessionDeltas(gphSession, gphBagBaseline, gphItemsGained)

    local now = time()
    local nowUptime = GetTime()
    local dur = (gphSession.startUptime and (nowUptime - gphSession.startUptime)) or (now - gphSession.startTime)
    local gold = GetMoney() - gphSession.startGold
    if gold < 0 then gold = 0 end

    local itemList = {}
    local qualityCounts = {}
    for itemId, data in pairs(gphSession.items or {}) do
        local total = data.count or 0
        if total > 0 and data.link and itemId ~= A.HEARTHSTONE_ID then
            local remaining = data.remaining or total
            local name = data.name or (A.GetCachedItemInfo(data.link)) or "Unknown"
            local quality = data.quality or (select(3, A.GetCachedItemInfo(data.link))) or 0
            
            qualityCounts[quality] = (qualityCounts[quality] or 0) + total
            table.insert(itemList, {
                link = data.link, 
                quality = quality, 
                count = total, 
                name = name,
                remainingCount = remaining,
                soldDuringSession = (gphSession.vendoredItemCount and gphSession.vendoredItemCount[itemId] and gphSession.vendoredItemCount[itemId] > 0),
                autodeletedDuringSession = (gphSession.autodeletedItemCount and gphSession.autodeletedItemCount[itemId] and gphSession.autodeletedItemCount[itemId] > 0),
            })
        end
    end
    
    table.sort(itemList, function(a, b)
        if a.quality ~= b.quality then return a.quality > b.quality end
        return (a.name or "") < (b.name or "")
    end)

    local RecordToIT = _G.FugaziInstanceTracker_RecordGPHRun
    if type(RecordToIT) == "function" then
        local estimatedValueCopper = gold
        if A.ComputeGPHEstimatedValue then
            estimatedValueCopper = gold + (A.ComputeGPHEstimatedValue(itemList) or 0)
        end
        local rawGPHCopper = (dur > 0) and math.floor(gold / (dur / 3600)) or 0
        
        RecordToIT(
            gphSession.startTime, 
            now, 
            gphSession.startGold, 
            gold, 
            itemList, 
            qualityCounts, 
            estimatedValueCopper, 
            rawGPHCopper, 
            gphSession.repairCount or 0, 
            gphSession.repairCopper or 0, 
            gphSession.deaths or 0, 
            gphSession.itemsAutodeleted or 0, 
            gphSession.vendorGold or 0
        )
        A.AddonPrint("|cff66ccff[InstanceTracker]|r GPH session stopped. |cff99ff99Saved to Ledger|r")
    else
        A.AddonPrint("|cff66ccff[InstanceTracker]|r GPH session stopped. (Not saved to Ledger)")
    end

    -- Cleanup
    gphSession = nil; _G.gphSession = nil
    local SV = _G.FugaziBAGSDB
    if SV then SV.gphSession, SV.gphBagBaseline, SV.gphItemsGained = nil, nil, nil end
    if A.RefreshGPHUI then A.RefreshGPHUI() end
end

local function ResetGPHSession()
    StartGPHSession()
    if A.RefreshGPHUI then A.RefreshGPHUI() end
end

local function SyncGPHSessionFromDB()
    local SV = _G.FugaziBAGSDB
    if SV and SV.gphSession then
        gphSession = SV.gphSession
        gphBagBaseline = SV.gphBagBaseline or {}
        gphItemsGained = SV.gphItemsGained or {}
        _G.gphSession = gphSession
    end
end




--- Snapshot current bag state to clear the baseline.
local function SnapshotBags()
    gphBagBaseline = A.ScanBags()
    gphItemsGained = {}
end

local function ComputeGPHTotalValue(session, liveGold)
    local val = liveGold or 0
    if not session or not session.items then return val end
    for id, data in pairs(session.items) do
        local cnt = data.remaining or data.count or 0
        if cnt > 0 and id ~= A.HEARTHSTONE_ID then
            local price = 0
            if GetItemInfo then
                price = select(11, A.GetCachedItemInfo(data.link or id)) or 0
            end
            val = val + (price * cnt)
        end
    end
    return val
end


--- Check if AH addon (TSM etc) is loaded for price tooltips.
local function AuctionAddonLoaded()
    return (_G.TSMAPI and _G.TSMAPI.GetItemPrices) or _G.Atr_GetAuctionPrice
end

--- Get AH price for link (TSM/Appraiser style).
local function GetAuctionPriceFromAPI(link)
    if not link then return 0 end
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId then return 0 end
    if _G.TSMAPI and _G.TSMAPI.GetItemPrices then
        local ok, prices = pcall(_G.TSMAPI.GetItemPrices, _G.TSMAPI, link)
        if ok and prices then
            local v = prices.DBMinBuyout or prices.DBMarket or 0
            return (type(v) == "number" and v > 0) and v or 0
        end
    end
    if _G.Atr_GetAuctionPrice then
        local ok, v = pcall(_G.Atr_GetAuctionPrice, itemId)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return 0
end

local gphSoulboundCache = {}

--- Is this item link soulbound? (tooltip scan.)
local function IsLinkSoulbound(link)
    if not link then return true end
    if gphSoulboundCache[link] ~= nil then
        return gphSoulboundCache[link]
    end
    local gt = A.GetScanTooltip()
    if not gt or not gt.SetHyperlink then return false end
    gt:ClearLines()
    gt:SetOwner(UIParent, "ANCHOR_NONE")
    gt:SetHyperlink(link)
    gt:Show()
    local n = (gt.NumLines and gt:NumLines()) or 0
    for i = 1, n do
        local line = _G["Fugazi_ScanTooltipTextLeft" .. i]
        if line and line.GetText then
            local t = (line:GetText() or ""):lower()
            if t:find("soul bound") or t:find("soulbound") or t:find("binds when picked up") or t:find("binds when equipped") or t:find("account bound") then
                gt:ClearLines()
                gt:Hide()
                gphSoulboundCache[link] = true
                return true
            end
        end
    end
    gt:ClearLines()
    gt:Hide()
    gphSoulboundCache[link] = false
    return false
end

--- Is bag slot item soulbound?
local function IsBagItemSoulbound(bag, slot)
    local gt = A.GetScanTooltip()
    if not gt or not gt.SetBagItem then return false end
    gt:ClearLines()
    gt:SetOwner(UIParent, "ANCHOR_NONE")
    gt:SetBagItem(bag, slot)
    gt:Show()
    local n = (gt.NumLines and gt:NumLines()) or 0
    for i = 1, n do
        local line = _G["Fugazi_ScanTooltipTextLeft" .. i]
        if line and line.GetText then
            local t = (line:GetText() or ""):lower()
            if t:find("soul bound") or t:find("soulbound") or t:find("binds when picked up") or t:find("binds when equipped") or t:find("account bound") then
                gt:ClearLines()
                gt:Hide()
                return true
            end
        end
    end
    gt:ClearLines()
    gt:Hide()
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
        auctionCopper = auctionCopper + GetAuctionPriceFromAPI(entry.link) * entry.count
    end
    return vendorCopper, auctionCopper
end

--- Estimated total value (vendor + AH) for a list of items.
local function ComputeGPHEstimatedValue(itemList)
    if not itemList then return 0 end
    local vendor = 0
    local auction = 0
    for _, data in ipairs(itemList) do
        local link = data and data.link
        local count = (data and data.count) or 0
        local quality = (data and data.quality) or 0
        if link and count > 0 and not IsLinkSoulbound(link) then
            if quality == 0 then
                local _, _, _, _, _, _, _, _, _, _, vp = A.GetCachedItemInfo(link)
                vendor = vendor + (vp or 0) * count
            else
                auction = auction + GetAuctionPriceFromAPI(link) * count
            end
        end
    end
    return vendor + math.floor(auction * 0.85)
end

--------------------------------------------------------------------------------
-- UI UTILITIES (Moved from Listview.lua for modularization)
--------------------------------------------------------------------------------

--- Initialize the GPH Status Bar (Gold/Time/GPH) on a frame.
function A.CreateGPHStatusBar(f)
    if not f or f.statusText then return end
    
    local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetJustifyH("RIGHT")
    f.statusText = statusText
    
    -- Default placement for Listview (Grid anchors will override this)
    statusText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -53)
    statusText:SetWordWrap(false)
    if statusText.SetNonSpaceWrap then statusText:SetNonSpaceWrap(false) end
    
    local font, size, flags = statusText:GetFont()
    f._statusTextBaseFont, f._statusTextBaseSize, f._statusTextBaseFlags = font, size or 12, flags
end

--- Shrinks the GPH status text to fit if it's too long for the allocated space.
function A.SetGphStatusTextFitted(f, text)
    local fs = f.statusText
    if not fs or not text then return end

    fs:SetText(text)

    -- Dynamic sizing logic: find the available gap between the Search Button and the right edge
    local btn = f.gphSearchBtn
    local frameRight = f:GetRight()
    local btnRight = btn and btn:GetRight()
    if not frameRight or not btnRight then return end
    
    local available = frameRight - btnRight - 12 -- 12px margin
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
function A.UpdateGPHStatusBar(f, now)
    if not f.statusText then return end
    
    local gphSession = _G.gphSession
    if not gphSession then
        if f.statusText:IsShown() then f.statusText:Hide() end
        return
    end

    local dur = now - (gphSession.startUptime or now) 
    local liveGold = (GetMoney and GetMoney()) and (GetMoney() - gphSession.startGold) or 0
    if liveGold < 0 then liveGold = 0 end
    local totalValue = A.ComputeGPHTotalValue and A.ComputeGPHTotalValue(gphSession, liveGold) or liveGold
    local gph = dur > 0 and (totalValue / (dur / 3600)) or 0
    
    -- Throttling UI updates: only refresh text if something meaningful changed.
    if (f._lastDur ~= dur or f._lastGold ~= liveGold or f._lastGPH ~= gph) then
        f._lastDur = dur; f._lastGold = liveGold; f._lastGPH = gph
        local goldStr = A.FormatGold(liveGold)
        local timerStr = A.FormatTimeMedium(dur)
        local gphStr = A.FormatGold(math.floor(gph))
        
        local fullText = "|cffdaa520Gold:|r "..goldStr.."   |cffdaa520Timer:|r |cffffffff"..timerStr.."|r   |cffdaa520GPH:|r "..gphStr
        A.SetGphStatusTextFitted(f, fullText)
        f.statusText:Show()
    end
end

-- EXPORTS
A.StartGPHSession = StartGPHSession
A.StopGPHSession = StopGPHSession
A.ResetGPHSession = ResetGPHSession
_G.ResetGPHSession = ResetGPHSession
A.SyncGPHSessionFromDB = SyncGPHSessionFromDB
A.ComputeGPHTotalValue = ComputeGPHTotalValue
A.ComputeGPHEstimatedValue = ComputeGPHEstimatedValue
A.ComputeVendorAuctionTotalsSync = ComputeVendorAuctionTotalsSync
A.ScanGPHSessionDeltas = ScanGPHSessionDeltas
A.GetAuctionPriceFromAPI = GetAuctionPriceFromAPI
A.IsLinkSoulbound = IsLinkSoulbound
A.AuctionAddonLoaded = AuctionAddonLoaded
A.SnapshotBags = SnapshotBags
A.DiffBagsGPH = function() ScanGPHSessionDeltas(gphSession, gphBagBaseline, gphItemsGained, true) end

-- Sync on load
SyncGPHSessionFromDB()

-- Register Master Ticker for Status Bar Updates
A.RegisteredUpdaters = A.RegisteredUpdaters or {}
A.RegisteredUpdaters["StatusUpdate"] = function(now, elapsed)
    if A.Inventory and A.Inventory:IsShown() then
        A.UpdateGPHStatusBar(A.Inventory, now)
    end
    if A.Bank and A.Bank:IsShown() then
        A.UpdateGPHStatusBar(A.Bank, now)
    end
end
