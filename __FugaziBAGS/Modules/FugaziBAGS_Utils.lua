local addonName, Addon = ...
-- Keep TOC private table and global as one object (same rule as Locales / Initialize).
if Addon then
    if _G.FugaziBAGS and _G.FugaziBAGS ~= Addon then
        for k, v in pairs(_G.FugaziBAGS) do
            if Addon[k] == nil then Addon[k] = v end
        end
    end
    _G.FugaziBAGS = Addon
else
    _G.FugaziBAGS = _G.FugaziBAGS or {}
end
local A = _G.FugaziBAGS

--- Returns true if playing on Project Ebonhold.
local function IsEbonhold()
    local realm = (GetRealmName and GetRealmName()) or ""
    return realm == "Rogue-Lite (Live)"
end

--- Returns true if the player is dead or a ghost.
function A.IsPlayerDeadOrGhost()
    if UnitIsDead and UnitIsDead("player") then return true end
    if UnitIsGhost and UnitIsGhost("player") then return true end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return true end
    return false
end


--- Returns true if playing on any Project Ascension realm.
local function IsAscension()
    local realm = (GetRealmName and GetRealmName()) or ""
    local isAscName = (realm == "Bronzebeard" or realm == "Area 52" or realm == "Elune")
    return isAscName or (_G.AscensionUI ~= nil) or (_G.AscensionCharacterFrame ~= nil)
end

A.QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62, hex = "9d9d9d", label = "Poor" },
    [1] = { r = 1.00, g = 1.00, b = 1.00, hex = "ffffff", label = "Common" },
    [2] = { r = 0.12, g = 1.00, b = 0.00, hex = "1eff00", label = "Uncommon" },
    [3] = { r = 0.00, g = 0.44, b = 0.87, hex = "0070dd", label = "Rare" },
    [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "a335ee", label = "Epic" },
    [5] = { r = 1.00, g = 0.50, b = 0.00, hex = "ff8000", label = "Legendary" },
    [6] = { r = 0.90, g = 0.80, b = 0.50, hex = "e6cc80", label = "Artifact" },
    [7] = { r = 0.00, g = 0.80, b = 1.00, hex = "00ccff", label = "Heirloom" },
}

-- Shared Data Pools for Aggregation & Drawing
local _inventoryItemPool, _inventoryItemPoolUsed = {}, 0
local _bankItemPool, _bankItemPoolUsed = {}, 0
-- Category group arrays / divider entries only — never mix with item row records
-- (using GetRecycledInventoryTable for groups can wipe live item.count mid-refresh).
-- Separate inv/bank so bank refresh does not wipe inv divider shells still on screen.
local _structTablePoolInv, _structTablePoolInvUsed = {}, 0
local _structTablePoolBank, _structTablePoolBankUsed = {}, 0
local _inventoryDataCache = {}
local _bagLinkCache = {}
local _scanCounts = {}
local _itemLinksCache = {}
A.itemLinksCache = _itemLinksCache

--- Format seconds as HH:MM:SS or shorter.
local function FormatTime(seconds)
    if seconds <= 0 then return "Ready" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dh %02dm %02ds", h, m, s)
    elseif m > 0 then return string.format("%dm %02ds", m, s)
    else return string.format("%ds", s) end
end

--- Format seconds as MM:SS (longer runs).
local function FormatTimeMedium(seconds)
    if seconds <= 0 then return "0s" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dh %dm", h, m)
    elseif m > 0 then return string.format("%dm %ds", m, s)
    else return string.format("%ds", s) end
end

--- Session status timer: zero-pad units so the row does not scoot each second
--- (e.g. "1m 08s" not "1m 8s").
local function FormatTimeMediumPadded(seconds)
    if not seconds or seconds <= 0 then return "0m 00s" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then return string.format("%dh %02dm", h, m)
    end
    return string.format("%dm %02ds", m, s)
end

--- Format copper as gold string (e.g. "1g 23s 45c").
local function FormatGold(copper)
    local DB = _G.FugaziBAGSDB
    if not copper or copper <= 0 then return "|cffeda55f0c|r" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("|cffffd700%d|rg |cffc7c7cf%d|rs |cffeda55f%d|rc", g, s, c)
    elseif s > 0 then return string.format("|cffc7c7cf%d|rs |cffeda55f%d|rc", s, c)
    else return string.format("|cffeda55f%d|rc", c) end
end

--- Session status gold: zero-pad silver/copper so width stays stable
--- (e.g. "2g 24s 05c" not "2g 24s 5c"). Gold digits still grow at 10g/100g.
local function FormatGoldPadded(copper)
    if not copper or copper <= 0 then return "|cffeda55f00c|r" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return string.format("|cffffd700%d|rg |cffc7c7cf%02d|rs |cffeda55f%02d|rc", g, s, c)
    elseif s > 0 then
        return string.format("|cffc7c7cf%02d|rs |cffeda55f%02d|rc", s, c)
    else
        return string.format("|cffeda55f%02d|rc", c)
    end
end

--- Format copper as plain number (no color).
local function FormatGoldPlain(copper)
    if not copper or copper <= 0 then return "0c" end
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then return string.format("%dg %ds %dc", g, s, c)
    elseif s > 0 then return string.format("%ds %dc", s, c)
    else return string.format("%dc", c) end
end

--- Format timestamp for run list (date/time).
local function FormatDateTime(timestamp)
    if not timestamp then return "" end
    local dt = date("*t", timestamp)
    if not dt then return "" end
    return string.format("%d.%d.%d - %02d:%02d", dt.day, dt.month, dt.year % 100, dt.hour, dt.min)
end


local itemInfoCache = {}
local tooltipScanner
local pendingIlvlRescanBags
local ilvlRescanFrame
local ILVL_RESCAN_MAX_ATTEMPTS = 6

local function StripColorCodes(text)
    if not text then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

--- After loot, Ascension tooltips can lag a frame or two. Queue one short deferred dirty paint.
local function ScheduleIlvlRescan(bag)
    if bag == nil then return end
    pendingIlvlRescanBags = pendingIlvlRescanBags or {}
    pendingIlvlRescanBags[bag] = true
    if not ilvlRescanFrame then
        ilvlRescanFrame = CreateFrame("Frame")
    end
    if ilvlRescanFrame._armed then return end
    ilvlRescanFrame._armed = true
    ilvlRescanFrame.elapsed = 0
    ilvlRescanFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        -- Small delay so Ascension can populate scaled Item Level on the bag instance.
        if self.elapsed < 0.2 then return end
        self:SetScript("OnUpdate", nil)
        self._armed = false
        local bags = pendingIlvlRescanBags
        pendingIlvlRescanBags = nil
        if not bags then return end
        A._gphDirtyBags = A._gphDirtyBags or {}
        for b in pairs(bags) do
            A._gphDirtyBags[b] = true
        end
        if A.PromoteGPHRefreshLevel then A.PromoteGPHRefreshLevel(1) end
        local inv = A.Inventory
        if inv and inv:IsShown() and A.RefreshGPHUI then
            A.RefreshGPHUI(1)
        end
        local bank = A.BankFrame or (A.GetBankFrame and A.GetBankFrame())
        if not bank and _G.FugaziBAGS_BankFrame then bank = _G.FugaziBAGS_BankFrame end
        if bank and bank:IsShown() and A.RefreshBankUI then
            A.RefreshBankUI(true)
        end
    end)
end

--- Ascension scales ilvl per bag instance. GetItemInfo is base only; scan tooltip for real ilvl.
--- Returns: scannedLevel (number|nil), scanComplete (bool). Incomplete tooltips must not be cached forever.
local function ScanAscensionItemLevel(itemIdOrLink, bag, slot)
    if not (IsAscension and IsAscension()) then return nil, true end
    if not tooltipScanner then
        tooltipScanner = CreateFrame("GameTooltip", "FugaziBAGS_ItemLevelScanner", UIParent, "GameTooltipTemplate")
    end
    tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    tooltipScanner:ClearLines()

    if bag and slot then
        if bag == -1 then
            local invSlot = (BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(slot)) or (38 + slot)
            tooltipScanner:SetInventoryItem("player", invSlot)
        else
            tooltipScanner:SetBagItem(bag, slot)
        end
    else
        local scanLink = (type(itemIdOrLink) == "string") and itemIdOrLink or nil
        if not scanLink then
            local _, l = GetItemInfo(itemIdOrLink)
            scanLink = l
        end
        if not scanLink then
            tooltipScanner:Hide()
            return nil, false
        end
        tooltipScanner:SetHyperlink(scanLink)
    end

    local numLines = tooltipScanner:NumLines() or 0
    local scannedLevel = nil
    for i = 2, numLines do
        local fs = _G["FugaziBAGS_ItemLevelScannerTextLeft"..i]
        if fs then
            local text = fs:GetText()
            if text then
                text = StripColorCodes(text)
                -- Case-insensitive; Ascension/client variants exist.
                local n = text:match("[Ii]tem [Ll]evel (%d+)")
                if n then
                    scannedLevel = tonumber(n)
                    break
                end
            end
        end
    end
    tooltipScanner:Hide()

    -- Fresh loot: SetBagItem often returns an empty/partial tooltip for a frame or two.
    -- Treat sparse tooltips as incomplete so we retry instead of caching base GetItemInfo ilvl.
    if scannedLevel then
        return scannedLevel, true
    end
    if numLines < 3 then
        return nil, false
    end
    return nil, true
end

function A.GetCachedItemInfo(itemId, bag, slot)
    if not itemId then return nil end
    
    local cached
    if bag and slot then
        local bagCache = itemInfoCache[bag]
        if not bagCache then bagCache = {}; itemInfoCache[bag] = bagCache end
        cached = bagCache[slot]
        if cached and cached.cacheId ~= itemId then cached = nil end
    else
        cached = itemInfoCache[itemId]
    end
    
    -- Retry unfinished Ascension ilvl scans (common right after loot).
    if cached then
        if not cached.ilvlScanned and IsAscension and IsAscension() then
            local attempts = cached.ilvlAttempts or 0
            if attempts < ILVL_RESCAN_MAX_ATTEMPTS then
                cached.ilvlAttempts = attempts + 1
                local scanned, complete = ScanAscensionItemLevel(itemId, bag, slot)
                if scanned then
                    cached[4] = scanned
                    cached.ilvlScanned = true
                elseif complete then
                    cached.ilvlScanned = true
                elseif bag ~= nil then
                    ScheduleIlvlRescan(bag)
                end
            else
                -- Give up; keep last known (base) rather than rescan forever.
                cached.ilvlScanned = true
            end
        end
        return cached[1], cached[2], cached[3], cached[4], cached[5], cached[6], cached[7], cached[8], cached[9], cached[10], cached[11]
    end
    
    local name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, itemEquipLoc, texture, sellPrice = GetItemInfo(itemId)
    
    local ilvlScanned = true
    local ilvlAttempts = 0
    if link and IsAscension and IsAscension() then
        local scanned, complete = ScanAscensionItemLevel(itemId, bag, slot)
        ilvlAttempts = 1
        if scanned then
            iLevel = scanned
            ilvlScanned = true
        elseif complete then
            ilvlScanned = true
        else
            -- Keep base GetItemInfo ilvl for now; retry after Ascension fills the bag tooltip.
            ilvlScanned = false
            if bag ~= nil then
                ScheduleIlvlRescan(bag)
            end
        end
    end

    if name then
        local data = {
            name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, itemEquipLoc, texture, sellPrice,
            cacheId = itemId,
            ilvlScanned = ilvlScanned,
            ilvlAttempts = ilvlAttempts,
        }
        if bag and slot then
            local bagCache = itemInfoCache[bag]
            if not bagCache then bagCache = {}; itemInfoCache[bag] = bagCache end
            bagCache[slot] = data
        else
            itemInfoCache[itemId] = data
        end
    end
    return name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, itemEquipLoc, texture, sellPrice
end

function A.ClearItemInfoCache(itemID)
    if not itemID then
        wipe(itemInfoCache)
        return
    end
    local targetID = tostring(itemID)
    for k, v in pairs(itemInfoCache) do
        if type(k) == "number" then
            if type(v) == "table" and not v.cacheId then
                -- It's a bag sub-table (keys are numeric slots)
                for slot, slotData in pairs(v) do
                    if slotData and slotData.cacheId and type(slotData.cacheId) == "string" and slotData.cacheId:match("item:"..targetID..":") then
                        v[slot] = nil
                    elseif slotData and slotData.cacheId == itemID then
                        v[slot] = nil
                    end
                end
            elseif k == itemID then
                itemInfoCache[k] = nil
            end
        elseif type(k) == "string" and k:match("item:"..targetID..":") then
            itemInfoCache[k] = nil
        end
    end
end



--- Get a unique key for the current character (Realm#Name).
local function GetGphCharKey()
    return A.GetCharKey and A.GetCharKey() or "Error#NoKey"
end


--- (Hook logic moved to SecurePathsHandler.lua)

A.itemLinksCache = A.itemLinksCache or {}

local function SafeSetText(fs, text)
    if not fs then return end
    if fs:GetText() == text then return end
    fs:SetText(text)
end

local function SafeSetTexture(tex, texture)
    if not tex then return end
    if tex:GetTexture() == texture then return end
    tex:SetTexture(texture)
end

A._nameHexCache = {}
local function GetItemNameHex(q, isProtected, qInfo)
    local key = (q or 0) .. (isProtected and "P" or "N")
    if A._nameHexCache[key] then return A._nameHexCache[key] end
    
    local hex
    if isProtected then
        local mix, grey = 0.28, 0.48
        local r = (qInfo.r or 0.5) * mix + grey * (1 - mix)
        local g = (qInfo.g or 0.5) * mix + grey * (1 - mix)
        local b = (qInfo.b or 0.5) * mix + grey * (1 - mix)
        hex = string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    else
        hex = qInfo.hex or "cccccc"
    end
    A._nameHexCache[key] = hex
    return hex
end

local function GetCachedBagLink(bag, slot, force)
    if bag == nil or slot == nil then return nil end
    local key = (bag * 100) + slot
    local old = _bagLinkCache[key]
    if not force and old then return old end
    
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    _bagLinkCache[key] = link
    return link
end

--- Clear bag-link cache only (no dirty flags). Prefer WipeBagLinkCache when a bag *changed*
--- and you also need slot-memory / aggregate rebuild flags.
local function ClearBagLinkCache(bagID)
    if bagID == nil then
        wipe(_bagLinkCache)
    else
        local prefix = bagID * 100
        for slot = 1, 100 do
            _bagLinkCache[prefix + slot] = nil
        end
    end
    if A.Search and A.Search.ClearTooltipCache then
        A.Search.ClearTooltipCache()
    end
end
local scanTooltip = nil

--- Returns the centralized hidden scan tooltip for item data extraction.
--- Keep off-screen; do NOT Show()/Hide() during scans — Hide wipes lines and
--- made soulbound/bind detection always return false (bulk-mail skip broken).
function A.GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "Fugazi_ScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTooltip:ClearAllPoints()
        scanTooltip:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10000, 10000)
        scanTooltip:Hide()
    end
    return scanTooltip
end

local _FugaziBAGS_IdToSlotTemp = {}
local _gphSlotLinkCache = {}
local _gphSlotIdCache = {}
local _gphCoordPool = {}
local _gphCoordCount = 0

local function GetSlotItemId(bag, slot, link)
    if not link then return nil end
    local key = bag * 100 + slot
    if _gphSlotLinkCache[key] == link then return _gphSlotIdCache[key] end
    
    local id = tonumber(link:match("item:(%d+)"))
    _gphSlotLinkCache[key] = link
    _gphSlotIdCache[key] = id
    return id
end

--- Map item ID -> bag,slot for cooldown lookup. (Uses a coordinate pool to avoid leaks).
local function GetItemIdToBagSlot()
    local out = _FugaziBAGS_IdToSlotTemp
    wipe(out)
    _gphCoordCount = 0
    
    for bag = 0, 4 do
        local n = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = GetSlotItemId(bag, slot, link)
                if itemId and not out[itemId] then
                    _gphCoordCount = _gphCoordCount + 1
                    local coord = _gphCoordPool[_gphCoordCount]
                    if not coord then
                        coord = {}
                        _gphCoordPool[_gphCoordCount] = coord
                    end
                    coord.bag = bag
                    coord.slot = slot
                    out[itemId] = coord
                end
            end
        end
    end
    return out
end


local _scanCounts = {}
--- Scan all bags → itemId -> total count (for GPH session baseline/delta).
--- MUST key by numeric itemId, never full hyperlink: Ascension/3.3.5 links change
--- uniqueId / scale fields when stacks split, merge, or bonus-loot toasts refresh the
--- slot — link keys created phantom session rows (same leather as x124 / x140 / x36).
local function ScanBags()
    local counts = _scanCounts
    if counts then wipe(counts) end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local itemLink = A.GetCachedBagLink(bag, slot)
            if itemLink then
                local _, itemCount = GetContainerItemInfo(bag, slot)
                local itemId = GetSlotItemId(bag, slot, itemLink)
                if itemId then
                    counts[itemId] = (counts[itemId] or 0) + (itemCount or 1)
                    if A.itemLinksCache[itemId] ~= itemLink then
                        A.itemLinksCache[itemId] = itemLink
                    end
                end
            end
        end
    end
    return counts
end

local _equippedIdTemp = {}
--- Set of equipped item IDs (for "previously worn" protect).
local function GetEquippedItemIds()
    local ids = _equippedIdTemp
    if ids then wipe(ids) end
    for slot = 1, 19 do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if link then
            local id = tonumber(link:match("item:(%d+)"))
            if id then ids[id] = true end
        end
    end
    return ids
end




local TOOLTIP_FRAME_GAP = 5
local MIN_SPACE_RIGHT = 260
local _anchorProbe

--- Anchor tooltip smartly next to a frame (avoid overflow).
--- ALWAYS ensures GameTooltip has an owner. Early-return without SetOwner lets
--- SetBagItem fail and HandleBagSlotEnter AddLine-stack on every UpdateTooltip pulse
--- (keyring hover spam after reload when host layout coords are briefly nil/0).
function A.AnchorTooltipSmart(ownerFrame, preferredSide, anchorFrame)
    if not ownerFrame then return end
    
    -- 1. IRON ANCHOR: Direct lookup for the host window. 
    -- Avoid climbing the parent tree as frames may be "Loose" during refreshes.
    local bank = A.Bank
    local inv = A.Inventory
    local host = anchorFrame
    
    if not host then
        -- Deducing the host from the owner's context
        local isBankOwner = ownerFrame._isBank or ownerFrame._isBankBtn or (ownerFrame.bagID and ownerFrame.bagID >= 5) or (ownerFrame.bagID == -1)
        host = isBankOwner and bank or inv
    end

    local hostReady = host and host.GetRight and host:GetRight() and host:GetRight() > 0

    -- 2. CLICK-SHIELD: If we just sold/used an item (last 0.15s), freeze the tooltip anchor POSITION.
    -- RELAXED: If the frame reference changed (recycling) or tooltip is hidden, we MUST update.
    local isShieldActive = A.gphTooltipShield and (GetTime() < A.gphTooltipShield)
    if isShieldActive and GameTooltip:IsShown() and GameTooltip:GetOwner() == ownerFrame then
        return 
    end

    -- Host not laid out yet (post-reload race): still own the tooltip so SetBagItem + AddLine
    -- rebuild cleanly instead of stacking orphan lines on UpdateTooltip thrash.
    if not hostReady then
        if GameTooltip:GetOwner() ~= ownerFrame then
            GameTooltip:SetOwner(ownerFrame, "ANCHOR_RIGHT")
        end
        return
    end

    -- 3. SIDE NEGOTIATION
    local screenWidth = GetScreenWidth() * (GetCVar("uiScale") or 1)
    local gap = TOOLTIP_FRAME_GAP or 5
    local side = preferredSide or "RIGHT"

    -- DUAL MODE SEAL: If both are open, force Bank=LEFT, Inventory=RIGHT. No Math.
    -- Verification: Ensure 'inv' is valid even if found via variant name.
    local isFreeFloat = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphBankFreeFloat
    if bank and bank:IsShown() and inv and inv:IsShown() and not isFreeFloat then
        if host == bank then side = "LEFT" else side = "RIGHT" end
    else
        -- Solo Mode (or Free Float): Space-based flip (using 330px as buffer)
        local hRight = host:GetRight() or 0
        local hLeft = host:GetLeft() or 0
        if side == "RIGHT" and (hRight + 330) > screenWidth then
            side = "LEFT"
        elseif side == "LEFT" and hLeft < 330 then
            side = "RIGHT"
        end
    end

    -- 4. ANCHORING
    -- Always SetOwner if it literally changed (Fixes disappearance during rapid re-pooling)
    if GameTooltip:GetOwner() ~= ownerFrame then
        GameTooltip:SetOwner(ownerFrame, "ANCHOR_NONE")
    end

    local targetPoint = (side == "RIGHT") and "TOPLEFT" or "TOPRIGHT"
    local targetRel = (side == "RIGHT") and "TOPRIGHT" or "TOPLEFT"
    local targetX = (side == "RIGHT") and gap or -gap

    local currentPoint, currentRelativeTo, _, currentX = GameTooltip:GetPoint(1)
    if currentPoint == targetPoint and currentRelativeTo == host and math.abs((currentX or 0) - targetX) < 1 then
        return
    end

    GameTooltip:ClearAllPoints()
    GameTooltip:SetPoint(targetPoint, host, targetRel, targetX, 0)
end


--------------------------------------------------------------------------------
-- Inventory position helpers (engine StartMoving + soft-clamp on drag stop).
--------------------------------------------------------------------------------
local function GphFrameSizeUIParent(frame)
    if not frame or not UIParent then return 0, 0 end
    local uis = UIParent:GetEffectiveScale() or 1
    if uis == 0 then uis = 1 end
    local fes = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or uis
    local w = (frame:GetWidth() or 0) * (fes / uis)
    local h = (frame:GetHeight() or 0) * (fes / uis)
    return w, h
end

local function GphClampToScreen(frame, left, bottom)
    if not frame or not UIParent or left == nil or bottom == nil then return left, bottom end
    local sw = UIParent:GetWidth() or 0
    local sh = UIParent:GetHeight() or 0
    local fw, fh = GphFrameSizeUIParent(frame)
    if sw < 10 or sh < 10 then return left, bottom end
    if left < 0 then left = 0 end
    if bottom < 0 then bottom = 0 end
    if left + fw > sw then left = sw - fw end
    if bottom + fh > sh then bottom = sh - fh end
    return left, bottom
end

--- Set BOTTOMLEFT without ClearAllPoints when already that pin (cheaper + safer).
local function GphSetBottomLeft(frame, left, bottom)
    if not frame or left == nil or bottom == nil then return end
    -- Prefer replace-in-place: one BOTTOMLEFT@UIParent already → no ClearAllPoints.
    local n = frame.GetNumPoints and frame:GetNumPoints() or 0
    if n == 1 and frame.GetPoint then
        local p, rel, rp = frame:GetPoint(1)
        if p == "BOTTOMLEFT" and rp == "BOTTOMLEFT" and rel == UIParent then
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            return
        end
    end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

--- Thin pin for free-float SetSize (sibling dock does not need this).
--- Skips combat — ClearAllPoints on this frame is blocked while lockdown is on.
function A.PinFrameBottomLeft(frame)
    if not frame or not frame.GetLeft then return false end
    if frame._isDragging then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom or left ~= left or bottom ~= bottom then return false end
    GphSetBottomLeft(frame, left, bottom)
    return true
end

--- Soft-clamp frame to screen edges after engine drag (SetClampedToScreen is off).
--- Skips combat — ClearAllPoints/SetPoint blocked on secure hosts.
--- Returns true only when the frame was actually repositioned.
function A.SoftClampFrameToScreen(frame)
    if not frame or not frame.GetLeft then return false end
    if frame._isDragging then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom or left ~= left or bottom ~= bottom then return false end
    local cl, cb = GphClampToScreen(frame, left, bottom)
    if cl ~= left or cb ~= bottom then
        GphSetBottomLeft(frame, cl, cb)
        return true
    end
    return false
end

--- Save frame position/size to DB (BOTTOMLEFT@UIParent).
local function SaveFrameLayout(frame, shownKey, pointKey)
    if not frame then return end
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if left and bottom and left == left and bottom == bottom then
        SV[pointKey] = SV[pointKey] or {}
        SV[pointKey].point = "BOTTOMLEFT"
        SV[pointKey].relativePoint = "BOTTOMLEFT"
        SV[pointKey].x = left
        SV[pointKey].y = bottom
        SV[pointKey].w = frame:GetWidth()
        SV[pointKey].h = frame:GetHeight()
    end
    if shownKey then SV[shownKey] = frame:IsShown() end
    if pointKey == "gphPoint" and frame.GetScale then
        SV.gphScale15 = (frame:GetScale() or 1) >= 1.4
    end
end

--- Restore frame position/size from DB.
--- Caller should SetScale *before* this so GetLeft-space matches the saved snapshot.
local function RestoreFrameLayout(frame, shownKey, pointKey)
    if not frame then return end
    local SV = _G.FugaziBAGSDB
    if not SV then return end
    local pt = SV[pointKey]
    if pt and pt.x ~= nil and pt.y ~= nil then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pt.x, pt.y)
    end
    -- Ignore poisoned tiny sizes (bad list-auto path). NegotiateSizes owns real size.
    local minW, minH = 200, 200
    if pt and pt.w and pt.w >= minW then frame:SetWidth(pt.w) end
    if pt and pt.h and pt.h >= minH then frame:SetHeight(pt.h) end
    if shownKey then
        if SV[shownKey] then
            frame:Show()
            return true
        else
            frame:Hide()
        end
    end
    return false
end


local BlizzardBagAPI
do
    local function Hide(noCloseAllBags)
        local n = _G.NUM_CONTAINER_FRAMES or 13
        for i = 1, n do
            local frame = _G["ContainerFrame" .. i]
            if frame then
                frame:SetScript("OnShow", function(self) self:Hide() end)
                frame:Hide()
            end
        end
        if not noCloseAllBags and CloseAllBags then CloseAllBags() end
    end
    local function Show()
        local n = _G.NUM_CONTAINER_FRAMES or 13
        for i = 1, n do
            local frame = _G["ContainerFrame" .. i]
            if frame then frame:SetScript("OnShow", nil) end
        end
        local openBackpack = A.origToggleBackpack or ToggleBackpack
        if openBackpack then openBackpack() end
    end
    BlizzardBagAPI = { Hide = Hide, Show = Show }
end



--- Calculate total list-row height from icon size and (when custom) name font size.
--- Previously only icon grew the row, so large names with small icons clipped the backdrop.
local function ComputeItemDetailsRowHeight(baseHeight)
    local SV = _G.FugaziBAGSDB
    local iconSize = 16
    local fontSize = 11
    if SV then
        local ic = tonumber(SV.gphItemDetailsIconSize)
        if ic and ic >= 12 and ic <= 28 then iconSize = ic end
        -- Name size only applies when row customisation is on (same as paint path).
        if SV.gphItemDetailsCustom then
            local fs = tonumber(SV.gphItemDetailsFontSize)
            if fs and fs >= 6 and fs <= 24 then fontSize = fs end
        end
    end
    -- +2 icon pad; +6 font pad so glyphs sit inside the 1px-gapped row wash.
    local byIcon = iconSize + 2
    local byFont = fontSize + 6
    return math.max(baseHeight or 18, byIcon, byFont)
end

A.ComputeItemDetailsRowHeight = ComputeItemDetailsRowHeight

--- Get header font and size from settings.
local function GetCategoryHeaderFontAndSize()
    local SV = _G.FugaziBAGSDB
    if not SV or not SV.gphCategoryHeaderFontCustom then
        return "Fonts\\ARIALN.TTF", 11
    end
    local path = (SV.gphCategoryHeaderFont and SV.gphCategoryHeaderFont ~= "") and SV.gphCategoryHeaderFont or "Fonts\\ARIALN.TTF"
    local size = tonumber(SV.gphCategoryHeaderFontSize)
    if not size or size < 6 or size > 24 then size = 11 end
    return path, size
end
A.GetCategoryHeaderFontAndSize = GetCategoryHeaderFontAndSize


--- Print to chat with addon prefix (like /print).
local function AddonPrint(msg, force)
    local DB = _G.FugaziBAGSDB
    if msg and msg ~= "" and (force or not (DB and DB.fitMute)) then
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(msg)
        end
    end
end


--- Shared mouse wheel handler for all list-based windows.
function A.HandleMouseWheel(sf, delta, stateFrame, offsetKey, onScrollCallback, customWidth)
    if not sf or not stateFrame or not offsetKey then return end
    local c = sf:GetScrollChild()
    if not c then return end

    local cur = stateFrame[offsetKey] or 0
    local viewHeight = sf:GetHeight()
    local contentHeight = c:GetHeight()
    local maxScroll = math.max(0, contentHeight - viewHeight)
    if maxScroll <= 0 then return end

    local step = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphScrollStep) or 100
    local newScroll = (delta < 0) and math.min(maxScroll, cur + step) or math.max(0, cur - step)

    stateFrame[offsetKey] = newScroll

    local scrollBar = stateFrame.scrollBar or stateFrame.gphScrollBar
    if scrollBar then
        scrollBar:SetMinMaxValues(0, maxScroll)
        scrollBar:SetValue(newScroll)
    end

    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, newScroll)
    if customWidth then c:SetWidth(customWidth) end
    c:SetHeight(contentHeight)

    if onScrollCallback then onScrollCallback() end
end


local function GetActiveSkinBorderColor()
    local SV = _G.FugaziBAGSDB
    local val = SV and SV.gphSkin or "elvui_real"
    local Skins = _G.__FugaziBAGS_Skins
    local SKIN = Skins and Skins.SKIN or {}
    local s = SKIN[val] or SKIN.elvui_real or SKIN.original
    if s and s.mainBorder then
        return unpack(s.mainBorder)
    end
    return 0.6, 0.5, 0.2, 0.8
end




--- Get saved setting for this character (per-toon).
local function GetPerChar(key, default)
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphPerChar then SV.gphPerChar = {} end
    local k = A.GetGphCharKey and A.GetGphCharKey() or ""
    if not SV.gphPerChar[k] then SV.gphPerChar[k] = {} end
    if SV.gphPerChar[k][key] == nil then
        local g = SV[key]
        SV.gphPerChar[k][key] = (g ~= nil) and g or default
    end
    return SV.gphPerChar[k][key]
end

--- Save setting for this character (also mirrors into top-level DB via SetOption when available).
local function SetPerChar(key, value)
    if A.SetOption then
        A.SetOption(key, value)
        return
    end
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphPerChar then SV.gphPerChar = {} end
    local k = A.GetGphCharKey and A.GetGphCharKey() or ""
    if not SV.gphPerChar[k] then SV.gphPerChar[k] = {} end
    SV.gphPerChar[k][key] = value
    SV[key] = value
end

A.GetPerChar = GetPerChar
A.SetPerChar = SetPerChar

--- Apply frame transparency (like UI opacity slider).
function A.ApplyFrameAlpha(f)
    if not f then return end
    local SV = _G.FugaziBAGSDB
    local fa = (SV and SV.gphFrameAlpha) or 1
    
    if fa > 0.99 then fa = 1 end

    -- Cleanup old multi-layer background technique
    if f._gphAlphaBg then
        f._gphAlphaBg:Hide()
        f._gphAlphaBg:SetAlpha(0)
    end

    -- Always re-paint main backdrop with fa (Main uses mainBg.a * gphFrameAlpha).
    -- Full chrome re-skin only when the value changes (slider spam).
    local Skins = _G.__FugaziBAGS_Skins
    local alphaChanged = (f._gphLastAppliedAlpha ~= fa)
    if alphaChanged then
        -- Do NOT BumpSkinGeneration here — that forced L3 skin every bag open.
        if f.ApplySkin then
            f.ApplySkin()
        elseif Skins and Skins.ApplyGPHFrameSkin then
            Skins.ApplyGPHFrameSkin(f)
        elseif Skins and Skins.ApplyBankFrameSkin and f._isBankFrame then
            Skins.ApplyBankFrameSkin(f)
        end
        if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(f) end
        f._gphLastAppliedAlpha = fa
    elseif Skins and Skins.ApplyToComponent then
        -- Skin switch with same opacity: keep panel translucent without full re-skin.
        Skins.ApplyToComponent(f, "Main")
    end
    
    f:SetAlpha(1)
    
    local itemAlpha = 0.8 + (fa - 0.1) * (0.2 / 0.9)
    if fa < 0.1 then itemAlpha = 0.8 end
    if fa > 0.98 then itemAlpha = 1 end
    
    if f.scrollFrame then f.scrollFrame:SetAlpha(itemAlpha) end
    if f.gphGridContent then f.gphGridContent:SetAlpha(itemAlpha) end
    if f.scroll then f.scroll:SetAlpha(itemAlpha) end -- bank scroll
    -- Reuse one chrome list per frame (avoid new {} every call).
    local chrome = f._gphAlphaChrome
    if not chrome then
        chrome = { f.gphTitleBar, f.titleBar, f.gphSep, f.sep, f.gphHeader, f.bankHeader, f.gphBottomBar }
        f._gphAlphaChrome = chrome
    else
        chrome[1], chrome[2], chrome[3], chrome[4] = f.gphTitleBar, f.titleBar, f.gphSep, f.sep
        chrome[5], chrome[6], chrome[7] = f.gphHeader, f.bankHeader, f.gphBottomBar
    end
    local ca = fa > 0.98 and 1 or fa
    for i = 1, 7 do
        local r = chrome[i]
        if r then r:SetAlpha(ca) end
    end
end

--- Refresh skin on inventory + bank frames (reapply theme).
function A.ApplyTestSkin()
    -- Options/skin change path: force full re-skin next open/L3 as well.
    if A.BumpSkinGeneration then A.BumpSkinGeneration() end
    local Skins = _G.__FugaziBAGS_Skins
    if A.Inventory then
        -- Inventory often has no frame.ApplySkin; L3 uses ApplyGPHFrameSkin.
        if A.Inventory.ApplySkin then
            A.Inventory.ApplySkin()
        elseif Skins and Skins.ApplyGPHFrameSkin then
            Skins.ApplyGPHFrameSkin(A.Inventory)
        end
        if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(A.Inventory) end
        -- Skin paint can leave solid mainBg; re-apply Scale > window opacity every skin switch.
        A.Inventory._gphLastAppliedAlpha = nil
        if A.ApplyFrameAlpha then A.ApplyFrameAlpha(A.Inventory) end
    end
    if A.Bank then
        if A.Bank.ApplySkin then
            A.Bank.ApplySkin()
        elseif Skins and Skins.ApplyBankFrameSkin then
            Skins.ApplyBankFrameSkin(A.Bank)
        end
        if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(A.Bank) end
        A.Bank._gphLastAppliedAlpha = nil
        if A.ApplyFrameAlpha then A.ApplyFrameAlpha(A.Bank) end
    end
end
_G.ApplyTestSkin = A.ApplyTestSkin


--------------------------------------------------------------------------------
-- Multi-quality rarity filter helpers (single click + LMB drag-paint)
--------------------------------------------------------------------------------

--- Resolve inventory/bank host frame from a rarity button.
function A.GetRarityBtnHostFrame(btn)
    if not btn then return nil end
    local host = btn:GetParent()
    if host and host.GetName then
        local n = host:GetName()
        if n == "InventoryMainFrame" or n == "BankMainFrame" then
            return host
        end
        local p = host:GetParent()
        if p and p.GetName then
            local pn = p:GetName()
            if pn == "InventoryMainFrame" or pn == "BankMainFrame" then
                return p
            end
        end
    end
    if btn.isBankBtn then
        return A.Bank
    end
    return A.Inventory
end

--- Active multi-set of filtered qualities on a frame, or nil if no filter.
--- Migrates legacy single-number gphFilterQuality / bankRarityFilter once.
function A.GetFilterQualities(f)
    if not f then
        return nil
    end
    if type(f.gphFilterQualities) == "table" then
        if next(f.gphFilterQualities) then
            return f.gphFilterQualities
        end
        f.gphFilterQualities = nil
        return nil
    end
    local single = f.gphFilterQuality
    if single == nil and type(f.bankRarityFilter) == "number" then
        single = f.bankRarityFilter
    end
    if type(single) == "number" then
        f.gphFilterQualities = { [single] = true }
        f.gphFilterQuality = nil
        if type(f.bankRarityFilter) == "number" then
            f.bankRarityFilter = f.gphFilterQualities
        end
        return f.gphFilterQualities
    end
    if type(f.bankRarityFilter) == "table" and next(f.bankRarityFilter) then
        f.gphFilterQualities = f.bankRarityFilter
        return f.gphFilterQualities
    end
    return nil
end

--- True if this quality button is currently selected as a filter.
function A.IsQualityFilterSelected(f, q)
    local set = A.GetFilterQualities(f)
    return set and set[q] == true or false
end

--- True if item quality passes the active filter (no filter = always true).
--- filterOrFrame: host frame, multi-set table, or legacy single number.
function A.QualityPassesFilter(filterOrFrame, q)
    if filterOrFrame == nil then
        return true
    end
    local set
    local t = type(filterOrFrame)
    if t == "number" then
        q = q or 0
        if q == filterOrFrame then
            return true
        end
        if filterOrFrame == 4 and q >= 4 then
            return true
        end
        return false
    end
    if t ~= "table" then
        return true
    end
    -- Host frame (inventory/bank) vs multi-set {[q]=true}.
    if filterOrFrame.GetName or filterOrFrame.qualityButtons
        or filterOrFrame.gphFilterQualities ~= nil
        or filterOrFrame.gphFilterQuality ~= nil
        or filterOrFrame.bankRarityFilter ~= nil then
        set = A.GetFilterQualities(filterOrFrame)
    else
        set = filterOrFrame
        if not next(set) then
            return true
        end
    end
    if not set then
        return true
    end
    q = q or 0
    if set[q] then
        return true
    end
    if set[4] and q >= 4 then
        return true
    end
    return false
end

--- Enable/disable one quality in the multi-filter set.
function A.SetQualityFilter(f, q, enabled)
    if not f or q == nil then
        return
    end
    A.GetFilterQualities(f) -- migrate legacy singles first
    f.gphFilterQualities = f.gphFilterQualities or {}
    if enabled then
        f.gphFilterQualities[q] = true
    else
        f.gphFilterQualities[q] = nil
    end
    if not next(f.gphFilterQualities) then
        f.gphFilterQualities = nil
    end
    f.gphFilterQuality = nil
    if f.isBankFrame or f._isBankFrame or (f.GetName and f:GetName() == "BankMainFrame") then
        f.bankRarityFilter = f.gphFilterQualities
    end
end

function A.ClearQualityFilters(f)
    if not f then
        return
    end
    f.gphFilterQualities = nil
    f.gphFilterQuality = nil
    f.bankRarityFilter = nil
end

--- Stable cache key for multi-filter (e.g. grid searchKey).
function A.FilterQualitiesKey(f)
    local set = A.GetFilterQualities(f)
    if not set then
        return ""
    end
    local parts = {}
    for q = 0, 7 do
        if set[q] then
            parts[#parts + 1] = tostring(q)
        end
    end
    return table.concat(parts, ",")
end

local function FilterValSelected(filterVal, q)
    if filterVal == nil then
        return false
    end
    if type(filterVal) == "number" then
        return filterVal == q
    end
    if type(filterVal) == "table" then
        return filterVal[q] == true
    end
    return false
end

--- Shared Visual Update for Rarity Buttons (Inventory + Bank).
local function UpdateRarityBtnVisual(f, btn, q, filterVal)
    if not btn or not btn.bg then return end
    if filterVal == nil and f then
        filterVal = A.GetFilterQualities(f)
    end
    local info = (A.QUALITY_COLORS and A.QUALITY_COLORS[q]) or { r = 0.5, g = 0.5, b = 0.5 }
    local r, g, b = info.r or 0.5, info.g or 0.5, info.b or 0.5
    if q == 0 then r, g, b = 0.58, 0.58, 0.58 elseif q == 1 then r, g, b = 0.96, 0.96, 0.96 end
    local alpha = 0.35
    
    -- PROTECTION FLAGS (MARKING)
    local rarityFlags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
    local isProtected = not btn.noProtection and (rarityFlags and rarityFlags[q])
    
    -- BURST/CONTINUOUS DELETE COLOR OVERRIDES (Inventory Only)
    local contStage = not btn.isBankBtn and A.continuousDelStage and A.continuousDelStage[q]
    local delStage = not btn.isBankBtn and A.rarityDelStage and A.rarityDelStage[q]
    local isContinuous = not btn.isBankBtn and A.continuousDelActive and A.continuousDelActive[q]
    local isPending = not btn.isBankBtn and A.pendingQuality and A.pendingQuality[q]

    if isContinuous or (contStage and (contStage.clicks or 0) >= 1) or (delStage and (delStage.clicks or delStage.stage or 0) >= 1) or isPending then
        -- Let the OnUpdate script handle the fading/pulsing colors!
        -- We return early from color setting here or use a subtle tinted base.
        r, g, b = 0.8, 0.4, 0.4 -- Tinted red base
        alpha = 0.6
    end

    local isFiltered = FilterValSelected(filterVal, q)
    if isFiltered then
        r = math.min(1, r * 2.2); g = math.min(1, g * 2.2); b = math.min(1, b * 2.2)
        alpha = 0.95
    end
    
    if isProtected then
        -- Add pulsing logic if needed, or just standard bright state
    end
    
    local Skins = _G.__FugaziBAGS_Skins
    local useOriginalRarity = f and f._useOriginalRarityStyle and f._originalMainBorder and f._originalTitleBg and Skins and Skins.AddRarityBorder
    if btn.SetBackdrop then btn:SetBackdrop(nil) end
    for _, suffix in ipairs({ "top", "bottom", "left", "right" }) do
        local border = btn["rarityBorder" .. suffix:gsub("^%l", string.upper)] or btn["_border" .. suffix:gsub("^%l", string.upper)]
        if border then border:Hide() end
    end
    if btn._rarityBorderFrame then btn._rarityBorderFrame:Hide(); btn._rarityBorderFrame:SetBackdrop(nil) end

    if useOriginalRarity then
        local tb = f._originalTitleBg
        local br = math.min(1, (tb[1] or 0.35) * 0.6 + r * 0.4)
        local bg = math.min(1, (tb[2] or 0.28) * 0.6 + g * 0.4)
        local bb = math.min(1, (tb[3] or 0.1) * 0.6 + b * 0.4)
        local isSelected = FilterValSelected(filterVal, q)
        local fillAlpha = isSelected and 0.95 or 0.72
        if isSelected then br, bg, bb = math.min(1, br * 1.5), math.min(1, bg * 1.5), math.min(1, bb * 1.5) end
        btn.bg:ClearAllPoints()
        btn.bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        btn.bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        btn.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        btn.bg:SetVertexColor(br, bg, bb, fillAlpha)
        Skins.AddRarityBorder(btn, f._originalMainBorder, f._originalEdgeFile, f._originalEdgeSize)
        if btn.hl then btn.hl:SetVertexColor(1, 1, 1, 0.12) end
    else
        btn.bg:ClearAllPoints(); btn.bg:SetAllPoints()
        btn.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        btn.bg:SetVertexColor(r, g, b, alpha)
        if btn.hl then btn.hl:SetVertexColor(1, 1, 1, 0.30) end
    end

    -- Protection Flags (Alt+Click marking)
    local rarityFlags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
    if not btn.noProtection and rarityFlags and rarityFlags[q] then
        local inset = 0
        btn.rarityBorderTop = btn.rarityBorderTop or btn:CreateTexture(nil, "OVERLAY")
        btn.rarityBorderBottom = btn.rarityBorderBottom or btn:CreateTexture(nil, "OVERLAY")
        btn.rarityBorderLeft = btn.rarityBorderLeft or btn:CreateTexture(nil, "OVERLAY")
        btn.rarityBorderRight = btn.rarityBorderRight or btn:CreateTexture(nil, "OVERLAY")
        
        local tArr = { btn.rarityBorderTop, btn.rarityBorderBottom, btn.rarityBorderLeft, btn.rarityBorderRight }
        for _, t in ipairs(tArr) do
            t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            t:SetVertexColor(1, 1, 1, 0.5) -- Lowered alpha
            t:Show()
        end
        btn.rarityBorderTop:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
        btn.rarityBorderTop:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", -inset, -inset - 1) -- 1px
        btn.rarityBorderBottom:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", inset, inset + 1) -- 1px
        btn.rarityBorderBottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
        btn.rarityBorderLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
        btn.rarityBorderLeft:SetPoint("BOTTOMRIGHT", btn, "BOTTOMLEFT", inset + 1, inset) -- 1px
        btn.rarityBorderRight:SetPoint("TOPLEFT", btn, "TOPRIGHT", -inset - 1, -inset) -- 1px
        btn.rarityBorderRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    end
end

--- Generic Rarity Button Handlers.
function A.GPHQualBtn_OnEnter(self)
    self._isHovered = true
    if A.PlayHoverSound then A.PlayHoverSound() end
    local info = (A.QUALITY_COLORS and A.QUALITY_COLORS[self.quality]) or { r = 0.5, g = 0.5, b = 0.5, label = "Rarity" }
    local r, g, b = (info.r or 0.5) * 1.2, (info.g or 0.5) * 1.2, (info.b or 0.5) * 1.2
    if self.quality == 0 then r, g, b = 0.65, 0.65, 0.65 elseif self.quality == 1 then r, g, b = 1, 1, 1 end
    self.bg:SetVertexColor(r, g, b, 0.55)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local info = A.QUALITY_COLORS[self.quality] or { label = "Trash" }
    GameTooltip:SetText(info.label or "Unknown")
    
    if self.helpLines then
        for _, line in ipairs(self.helpLines) do
            GameTooltip:AddLine(unpack(line))
        end
    else
        -- Inventory Default Tooltips (Context Aware)
        GameTooltip:AddLine("LMB: Filter quality (drag to multi-filter)", 1, 1, 1)
        
        -- Only show Alt-Click protection if not disabled
        if not self.noProtection then
            GameTooltip:AddLine("Alt+LMB: Protect rarity (drag to multi-protect)", 1, 1, 1)
        end

        -- Check context for Mail/Bank/GuildBank
        local atBank = (A.Bank and A.Bank:IsShown()) or (_G.GuildBankFrame and _G.GuildBankFrame:IsShown())
        local atMail = _G.MailFrame and _G.MailFrame:IsShown()
        
        if atBank or atMail then
            local location = "Mailbox"
            if atBank then
                if _G.GuildBankFrame and _G.GuildBankFrame:IsShown() then
                    location = (A.GetOpenGuildBankLabel and A.GetOpenGuildBankLabel()) or "Guild Bank"
                else
                    location = "Bank"
                end
            end
            GameTooltip:AddLine("Shift+RMB: Move rarity to " .. location, 0.6, 1, 0.6)
            local inv = A.Inventory
            local hasSearch = inv and inv.gphSearchText and inv.gphSearchText ~= ""
            local hasFilter = inv and A.GetFilterQualities and A.GetFilterQualities(inv)
            if hasSearch or hasFilter then
                GameTooltip:AddLine("Respects active search / rarity filters", 0.5, 0.85, 1.0)
            end
        end

        -- Only show deletion tools if not disabled
        if not self.noProtection then
            GameTooltip:AddLine("Ctrl+LMB (3x): Toggle Continuous Auto-Delete", 0.75, 0.45, 0.45)
            GameTooltip:AddLine("Ctrl+RMB (3x): Burst Delete all from bags", 0.75, 0.45, 0.45)
        end
    end
    GameTooltip:Show()
    if self.labelFs then self.labelFs:SetAlpha(1) end

    local f = A.GetRarityBtnHostFrame and A.GetRarityBtnHostFrame(self)
    local isBank = self.isBankBtn or (f and (f.isBankFrame or f._isBankFrame))

    -- Filter drag-paint (works on inventory + bank)
    if A._filterDragInitiated and not IsAltKeyDown() and not IsControlKeyDown()
        and IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
        if A.IsQualityFilterSelected(f, self.quality) ~= A._filterDragValue then
            A.SetQualityFilter(f, self.quality, A._filterDragValue)
            if f then
                f._refreshImmediate = true
                if isBank then
                    f._bankForceFull = true
                    if f.gphGridMode then f._bankGridForceFull = true end
                end
            end
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            if A.MarkGridFullRefresh then A.MarkGridFullRefresh() end
            if isBank and _G.RefreshBankUI then
                _G.RefreshBankUI()
            elseif _G.RefreshGPHUI then
                _G.RefreshGPHUI()
            end
        end
    end

    -- Protection drag-paint (inventory only)
    if self.noProtection then return end
    if A._rarityDragInitiated and IsAltKeyDown() and not IsControlKeyDown() and IsMouseButtonDown("LeftButton") then
        local flags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
        if flags and flags[self.quality] ~= A._rarityDragValue then
            if A.GPH_SetRarityProtection then A.GPH_SetRarityProtection(self.quality, A._rarityDragValue) end
            if _G.RefreshGPHUI then _G.RefreshGPHUI() end
            if self.isBankBtn and _G.RefreshBankUI then _G.RefreshBankUI() end
        end
    end
end

function A.GPHQualBtn_OnMouseDown(self, button)
    if button ~= "LeftButton" then
        return
    end
    local ctrl = IsControlKeyDown and IsControlKeyDown()
    local alt = IsAltKeyDown and IsAltKeyDown()
    local shift = IsShiftKeyDown and IsShiftKeyDown()
    if ctrl or shift then
        return
    end

    local f = A.GetRarityBtnHostFrame and A.GetRarityBtnHostFrame(self) or self:GetParent()
    local isBank = self.isBankBtn or (f and (f.isBankFrame or f._isBankFrame))

    -- Alt+LMB: protect paint (inventory only)
    if alt and not self.noProtection then
        A._rarityDragInitiated = true
        A._filterDragInitiated = nil
        A._rarityDragValue = not (A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()[self.quality])
        if A.GPH_SetRarityProtection then
            A.GPH_SetRarityProtection(self.quality, A._rarityDragValue)
        end
        if _G.RefreshGPHUI then
            _G.RefreshGPHUI()
        end
        if isBank and _G.RefreshBankUI then
            _G.RefreshBankUI()
        end
        return
    end

    -- Plain LMB: filter paint (inventory + bank) — click toggles, drag multi-filters
    -- Skip if continuous auto-delete is active for this quality (OnClick cancels that).
    if not alt then
        if A.continuousDelActive and A.continuousDelActive[self.quality] then
            return
        end
        A._filterDragInitiated = true
        A._rarityDragInitiated = nil
        A._filterDragValue = not A.IsQualityFilterSelected(f, self.quality)
        A.SetQualityFilter(f, self.quality, A._filterDragValue)
        if f then
            f._refreshImmediate = true
            if isBank then
                f._bankForceFull = true
                if f.gphGridMode then
                    f._bankGridForceFull = true
                end
            else
                f.gphScrollToDefaultOnNextRefresh = true
            end
        end
        if A.DirtyDestroyableCache then
            A.DirtyDestroyableCache()
        end
        if A.MarkGridFullRefresh then
            A.MarkGridFullRefresh()
        end
        if isBank and _G.RefreshBankUI then
            _G.RefreshBankUI()
        elseif _G.RefreshGPHUI then
            _G.RefreshGPHUI()
        end
    end
end

function A.GPHQualBtn_OnLeave(self)
    self._isHovered = false
    local f = A.GetRarityBtnHostFrame and A.GetRarityBtnHostFrame(self) or self:GetParent()
    local filter = A.GetFilterQualities and A.GetFilterQualities(f) or nil
    A.UpdateRarityBtnVisual(f, self, self.quality, filter)
    GameTooltip:Hide()
    -- Only hide the label if no special stage is active
    local q = self.quality
    local active = A.continuousDelActive and A.continuousDelActive[q]
    local stage = A.continuousDelStage and A.continuousDelStage[q]
    local burst = A.rarityDelStage and A.rarityDelStage[q]
    local isFiltered = A.IsQualityFilterSelected and A.IsQualityFilterSelected(f, q)
    local isProtected = not self.noProtection and A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()[q]
    if not (active or stage or burst or isFiltered or isProtected) then
        if self.labelFs then self.labelFs:SetAlpha(0) end
    end
end

-- Visual logic functions (UpdateRarityButtonState, UpdateAllRarityVisuals) moved to Frames.lua

--- Stop any in-flight row pulse (pool reuse would otherwise leave the flash on the wrong item).
local function ClearRowPulse(btn)
    if not btn or not btn.pulseTex then return end
    local tex = btn.pulseTex
    if _G.UIFrameFadeRemoveFrame then
        _G.UIFrameFadeRemoveFrame(tex)
    end
    tex:SetAlpha(0)
    tex:Hide()
end

--- Trigger a quick visual pulse/flash on a row (feedback for click).
--- This is now in Utils so it can be shared by Inventory and Bank.
local function TriggerRowPulse(btn)
    if not btn or not btn.pulseTex then return end
    ClearRowPulse(btn)
    btn.pulseTex:Show()
    btn.pulseTex:SetAlpha(0.7)
    if _G.UIFrameFadeOut then
        _G.UIFrameFadeOut(btn.pulseTex, 0.2, 0.7, 0)
    else
        btn.pulseTex:Hide()
    end
end

--- Pulse the list row currently bound to itemId (post-refresh; pool frames move on protect sort).
local function PulseListRowByItemId(itemId)
    itemId = tonumber(itemId)
    if not itemId or not TriggerRowPulse then return end
    local function scan(pool, used)
        if not pool then return false end
        local n = used or #pool
        for i = 1, n do
            local row = pool[i]
            if row and row:IsShown() and tonumber(row.cachedItemId) == itemId then
                TriggerRowPulse(row)
                return true
            end
        end
        return false
    end
    local invPool, invUsed = A.GetGPHItemPool and A.GetGPHItemPool()
    if scan(invPool, invUsed) then return end
    if A.GPH_BANK_POOL then
        scan(A.GPH_BANK_POOL, A.GPH_BANK_POOL_USED)
    end
end


--- Create the shared Bag Space indicator button (used in both Inventory and Bank).
function A.CreateBagSpaceIndicator(f, parent, isBank)
    local btn = CreateFrame("Button", nil, parent)
    btn._isBank = isBank
    btn._parentFrame = f
    btn:SetSize(36, 18) 
    btn:SetPoint("LEFT", parent, "LEFT", 0, 0)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    btn.bg = bg
    
    local Skins = _G.__FugaziBAGS_Skins
    if Skins and Skins.ApplyToComponent then
        Skins.ApplyToComponent(btn, "Button", "BagSpace")
    else
        bg:SetTexture(0.1, 0.3, 0.15, 0.7)
    end
    
    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    if Skins and Skins.ApplyToComponent then
        Skins.ApplyToComponent(fs, "Text", "BagSpace")
    else
        fs:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
        fs:SetTextColor(isBank and 1 or 0.92, isBank and 0.85 or 0.82, isBank and 0.4 or 0.55, 1)
    end
    btn.fs = fs
    
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    glow:SetVertexColor(1, 0.85, 0.2, 0.5)
    glow:SetBlendMode("ADD")
    glow:Hide()
    btn.glow = glow

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    highlight:SetVertexColor(1, 1, 1, 0.15)
    highlight:SetBlendMode("ADD")
    btn.highlight = highlight

    btn:SetScript("OnEnter", function(self)
        if A.PlayHoverSound then A.PlayHoverSound() end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if GetCursorInfo and GetCursorInfo() == "item" then
            GameTooltip:SetText(isBank and "Drop to place in first free Bank Slot" or "Drop to place in first free slot")
        else
            GameTooltip:SetText(isBank and "Bank space / Dropspace" or "Drop Space")
            if isBank then
                GameTooltip:AddLine("Ctrl+LMB: Toggle bank bags", 0.6, 0.6, 0.6)
                GameTooltip:AddLine("LMB: Place item in first free slot", 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("Ctrl+LMB: Manage Bags & Keys.", 0.6, 0.6, 0.6)
            end
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnHide", function(self)
        GameTooltip:Hide()
    end)

    return btn
end


-- EXPORTS
A.AddonPrint = AddonPrint
A.GetActiveSkinBorderColor = GetActiveSkinBorderColor

A.FormatDateTime = FormatDateTime
A.GetGphCharKey = GetGphCharKey
A.SaveFrameLayout = SaveFrameLayout
A.RestoreFrameLayout = RestoreFrameLayout
A.HideBlizzardBags = BlizzardBagAPI and BlizzardBagAPI.Hide
A.ShowBlizzardBags = BlizzardBagAPI and BlizzardBagAPI.Show
A.ComputeItemDetailsRowHeight = ComputeItemDetailsRowHeight
A.GetCategoryHeaderFontAndSize = GetCategoryHeaderFontAndSize
A.IsEbonhold = IsEbonhold
A.IsAscension = IsAscension
A.FormatTime = FormatTime
A.FormatTimeMedium = FormatTimeMedium
A.FormatTimeMediumPadded = FormatTimeMediumPadded
A.FormatGold = FormatGold
A.FormatGoldPadded = FormatGoldPadded
A.FormatGoldPlain = FormatGoldPlain
A.GetPerChar = GetPerChar
A.SetPerChar = SetPerChar
A.SafeSetText = SafeSetText
A.SafeSetTexture = SafeSetTexture
A.GetItemNameHex = GetItemNameHex
A.GetCachedBagLink = GetCachedBagLink
A.ClearBagLinkCache = ClearBagLinkCache
A.GetItemIdToBagSlot = GetItemIdToBagSlot
A.ScanBags = ScanBags
A.GetEquippedItemIds = GetEquippedItemIds
A.UpdateRarityBtnVisual = UpdateRarityBtnVisual
A.GPHQualBtn_OnEnter = A.GPHQualBtn_OnEnter
A.GPHQualBtn_OnLeave = A.GPHQualBtn_OnLeave
A.GPHQualBtn_OnMouseDown = A.GPHQualBtn_OnMouseDown
A.TriggerRowPulse = TriggerRowPulse
A.ClearRowPulse = ClearRowPulse
A.PulseListRowByItemId = PulseListRowByItemId




--- Universal Layout tool to create/reposition the rarity bar.
local function LayoutRarityBar(f, parent, clickHandler, xStart, xEnd)
    if not f or not parent then return end
    f.qualityButtons = f.qualityButtons or {}
    local spacing, numBtns = 4, 5
    local frameW = f:GetWidth() or 340
    local leftPad, bagW, bagGap = 4, 44, 16 -- Increased padding and bag space room
    local startX = xStart or (leftPad + bagW + bagGap)
    local endX = xEnd or (frameW - 36) -- Increased right-side gap to 36
    local totalW = endX - startX
    local slotW = math.floor((totalW - (spacing * (numBtns - 1))) / numBtns)
    if slotW < 24 then slotW = 24 end

    for i, q in ipairs({0, 1, 2, 3, 4}) do
        local btn = f.qualityButtons[q]
        if not btn then
            btn = CreateFrame("Button", nil, parent)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
            btn.hl:SetAllPoints()
            btn.hl:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            btn.hl:SetVertexColor(1, 1, 1, 0.3)
            btn.labelFs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.labelFs:SetAllPoints()
            btn.labelFs:SetJustifyH("CENTER")
            btn.labelFs:SetFont("Fonts\\FRIZQT__.TTF", 8, "") -- Removed OUTLINE
            -- Map shared scripts
            btn:SetScript("OnEnter", f.qualityOnEnter or A.GPHQualBtn_OnEnter)
            btn:SetScript("OnLeave", A.GPHQualBtn_OnLeave)
            btn:SetScript("OnMouseDown", A.GPHQualBtn_OnMouseDown)
            f.qualityButtons[q] = btn
        end
        btn.quality = q
        btn.noProtection = f.noProtection -- Pass protection disabled flag
        btn.isBankBtn = f.isBankFrame -- Unique flag for bank buttons
        btn:SetScript("OnClick", clickHandler)
        btn:SetSize(slotW, 14) -- Back to 14px height per user request
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", parent, "LEFT", startX + (i - 1) * (slotW + spacing), 0)
        btn:Show()
    end
end


--- Play click sound (bag slot / button).
--- Separate, short per-kind throttle so hover does not eat the following click.
function A.PlayClickSound()
    local SV = _G.FugaziBAGSDB
    if not SV or SV.gphClickSound == false then return end
    local now = GetTime and GetTime() or 0
    local last = A._gphClickSoundLast or 0
    if now - last < 0.04 then return end
    A._gphClickSoundLast = now
    if PlaySoundFile then PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\click.ogg") end
end

--- Play swoosh sound (item autodelete / removal).
function A.PlaySwooshSound()
    local SV = _G.FugaziBAGSDB
    if not SV or SV.gphClickSound == false then return end
    if PlaySoundFile then PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\Swoosh2.ogg", "Master") end
end


--- Play hover sound (rarity bar etc).
--- Uses its own throttle (not shared with click) so row-hover then click both play.
function A.PlayHoverSound()
    local SV = _G.FugaziBAGSDB
    if not SV or SV.gphClickSound == false then return end
    local now = (GetTime and GetTime()) or 0
    local last = A._gphHoverSoundLast or 0
    if now - last < 0.05 then return end
    A._gphHoverSoundLast = now
    if PlaySoundFile then PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\hover.ogg") end
end


-- 5. DEBUG UTILITIES (Slash commands)
--- Debug: list protected frame children (for taint).
local function DebugProtectedChildren()
    local c = A.Inventory and A.Inventory.gphInventoryContainer
    if not c then
        print("[FugaziBAGS] No FugaziBAGS_InventoryContainer yet.")
        return
    end

    print("[FugaziBAGS] Protected children under FugaziBAGS_InventoryContainer:")
    local function scan(frame, depth)
        depth = depth or 0
        local indent = string.rep("  ", depth)
        local name = frame:GetName() or "<unnamed>"
        local prot = (frame.IsProtected and frame:IsProtected()) and "P" or "-"
        local forb = (frame.IsForbidden and frame:IsForbidden()) and "F" or "-"
        print(indent .. prot .. forb, name, frame:GetObjectType())

        local num = frame.GetNumChildren and frame:GetNumChildren() or 0
        if num > 0 then
            local children = { frame:GetChildren() }
            for i = 1, #children do
                scan(children[i], depth + 1)
            end
        end
    end
    scan(c, 0)
end

SLASH_FUGAZIDEBUGPROT1 = "/fugaziprot"
SlashCmdList["FUGAZIDEBUGPROT"] = function()
    DebugProtectedChildren()
end

SLASH_FUGAZITAINT1 = "/fugazitaint"
SlashCmdList["FUGAZITAINT"] = function(msg)
    local arg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    local wantOn = (arg == "" or arg == "on" or arg == "1" or arg == "true")
    local wantOff = (arg == "off" or arg == "0" or arg == "false")
    if wantOn then
        if SetCVar then SetCVar("taintLog", "1") end
        print("|cff00aaff[FugaziBAGS]|r Taint logging |cff44ff44ON|r. Log file: Logs\\taint.log (updates when taint occurs or on logout).")
    elseif wantOff then
        if SetCVar then SetCVar("taintLog", "0") end
        print("|cff00aaff[FugaziBAGS]|r Taint logging |cffff4444OFF|r.")
    else
        local cur = (GetCVar and GetCVar("taintLog")) or "0"
        local isOn = (cur == "1")
        print("|cff00aaff[FugaziBAGS]|r Taint log is " .. (isOn and "|cff44ff44ON|r" or "|cffff4444OFF|r") .. ". Use |cffffcc00/fugazitaint on|r or |cffffcc00/fugazitaint off|r.")
    end
end

--- Universal Category Divider Renderer (Inventory + Bank).
function A.GPH_RenderCategoryDivider(f, content, entry, yOff, clickHandler)
    if not entry or not entry.divider then return yOff, false end
    
    local catName = entry.divider
    if catName == "HIDDEN_FIRST" or catName == "BAG_PROTECTED" then 
        return yOff, false 
    end

    if not f.gphCategoryDividerPool then f.gphCategoryDividerPool = {} end
    f._gphDivIdx = (f._gphDivIdx or 0) + 1
    
    local div = f.gphCategoryDividerPool[f._gphDivIdx]
    if not div then
        div = CreateFrame("Button", nil, content)
        div:EnableMouse(true)
        div:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        
        local tex = div:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(0.4, 0.35, 0.2, 0.7)
        tex:SetPoint("TOPLEFT", div, "TOPLEFT", 0, 0)
        tex:SetPoint("TOPRIGHT", div, "TOPRIGHT", 0, 0)
        tex:SetHeight(1)
        div.tex = tex
        
        local label = div:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", div, "LEFT", 4, 0)
        label:SetJustifyH("LEFT")
        div.label = label
        
        local toggle = CreateFrame("Frame", nil, div)
        toggle:SetSize(14, 12)
        toggle:SetPoint("BOTTOMLEFT", div, "BOTTOMLEFT", 0, 0)
        local tfs = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tfs:SetPoint("CENTER")
        toggle.text = tfs
        local ti = toggle:CreateTexture(nil, "ARTWORK")
        ti:SetAllPoints()
        toggle.icon = ti
        div.toggleBtn = toggle
        
        div.label:ClearAllPoints()
        div.label:SetPoint("LEFT", toggle, "RIGHT", 2, 0)
        
        div:SetScript("OnClick", function(self, button)
            local shift = IsShiftKeyDown and IsShiftKeyDown()
            if shift and button == "RightButton" then
                local bf = A.Bank
                local gbf = _G.GuildBankFrame
                local mf = _G.MailFrame
                if f.isBankFrame then
                    if A.StartRarityMoveJob then
                        A.StartRarityMoveJob("bank_to_bags", nil, self.categoryName)
                    else
                        A.RarityMoveJob = { mode = "bank_to_bags", category = self.categoryName }
                        if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
                    end
                    return
                elseif mf and mf:IsShown() then
                    -- Use real mail send worker (search-aware), not attach-only move ticks.
                    local recipient = _G.SendMailNameEditBox and _G.SendMailNameEditBox:GetText()
                    if not recipient or recipient:match("^%s*$") then
                        print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
                    elseif A.StartSendRarityMail then
                        local searchLower, filterQ = nil, nil
                        if A.SnapshotMoveJobFilters then
                            searchLower, filterQ = A.SnapshotMoveJobFilters()
                        end
                        A.StartSendRarityMail(nil, {
                            category = self.categoryName,
                            searchLower = searchLower,
                            filterQuality = filterQ,
                        })
                    elseif A.StartRarityMoveJob then
                        A.StartRarityMoveJob("bags_to_mail", nil, self.categoryName)
                    end
                    return
                elseif (bf and bf:IsShown()) or (gbf and gbf:IsShown()) then
                    local mode = (gbf and gbf:IsShown()) and "bags_to_guildbank" or "bags_to_bank"
                    if A.StartRarityMoveJob then
                        A.StartRarityMoveJob(mode, nil, self.categoryName)
                    else
                        A.RarityMoveJob = { mode = mode, category = self.categoryName }
                        if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
                    end
                    return
                end
            end
            if button == "LeftButton" then
                if clickHandler then clickHandler(self) end
            end
        end)
        
        div:SetScript("OnEnter", function(self)
            if A.PlayHoverSound then A.PlayHoverSound() end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to collapse/expand")
            local atBank = (A.Bank and A.Bank:IsShown()) or (_G.GuildBankFrame and _G.GuildBankFrame:IsShown())
            local atMail = _G.MailFrame and _G.MailFrame:IsShown()
            if atBank or atMail then
                local loc = "Mailbox"
                if f.isBankFrame then
                    loc = "Bags"
                elseif _G.GuildBankFrame and _G.GuildBankFrame:IsShown() then
                    loc = (A.GetOpenGuildBankLabel and A.GetOpenGuildBankLabel()) or "Guild Bank"
                elseif atBank then
                    loc = "Bank"
                end
                GameTooltip:AddLine("Shift+RMB: Move category to " .. loc, 0.6, 1, 0.6)
                local inv = A.Inventory
                local hasSearch = inv and inv.gphSearchText and inv.gphSearchText ~= ""
                local hasFilter = inv and A.GetFilterQualities and A.GetFilterQualities(inv)
                if hasSearch or hasFilter then
                    GameTooltip:AddLine("Respects active search / rarity filters", 0.5, 0.85, 1.0)
                end
            end
            GameTooltip:Show()
            if self.categoryName == "DELETE" then
                if self.label then self.label:SetAlpha(0.7) end
                if self.toggleBtn and self.toggleBtn.icon then self.toggleBtn.icon:SetAlpha(0.7) end
            end
        end)
        
        div:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if self.categoryName == "DELETE" then
                if self.label then self.label:SetAlpha(0.4) end
                if self.toggleBtn and self.toggleBtn.icon then self.toggleBtn.icon:SetAlpha(0.4) end
            end
        end)
        
        table.insert(f.gphCategoryDividerPool, div)
    end

    local collapsed = entry.collapsed
    local isDelete = (catName == "DELETE")
    local fontPath, fontSize = A.GetCategoryHeaderFontAndSize()
    
    yOff = yOff + 4
    div:SetParent(content)
    if div._gphCurrentYOff ~= yOff then
        div:ClearAllPoints()
        div:SetPoint("TOPLEFT", content, "TOPLEFT", f.isBankFrame and 4 or 0, -yOff)
        div:SetPoint("TOPRIGHT", content, "TOPRIGHT", f.isBankFrame and -4 or 0, -yOff)
        div:SetHeight(16)
        div._gphCurrentYOff = yOff
    end
    
    if isDelete then
        div.label:SetText("Autodelete")
        div.label:SetFont(fontPath, fontSize, "ITALIC")
    else
        div.label:SetText(catName)
        div.label:SetFont(fontPath, fontSize, "")
    end
    
    if div.toggleBtn and fontSize then
        local base = math.max(10, fontSize)
        div.toggleBtn:SetSize(isDelete and (base - 2) or base, isDelete and (base - 4) or base)
    end
    
    div.categoryName = catName
    if div.toggleBtn and div.toggleBtn.icon then
        local r, g, b = 1, 1, 1
        local SV = _G.FugaziBAGSDB
        local customHeader = SV and SV.gphCategoryHeaderFontCustom
        local hColor = (customHeader and SV.gphSkinOverrides and SV.gphSkinOverrides.headerTextColor) or f.gphAccentTextColor or f.bankSpaceTextColor
        
        if isDelete then 
            r, g, b = 0.65, 0.22, 0.22 
        elseif hColor and #hColor >= 3 then
            r, g, b = hColor[1], hColor[2], hColor[3]
        end
        
        div.toggleBtn.icon:SetTexture(collapsed 
            and "Interface\\AddOns\\__FugaziBAGS\\media\\expand.blp" 
            or  "Interface\\AddOns\\__FugaziBAGS\\media\\collapse.blp")
        div.toggleBtn.icon:SetAlpha(isDelete and (collapsed and 0.7 or 0.4) or (collapsed and 1.0 or 0.7))
        div.toggleBtn.icon:SetVertexColor(r, g, b, 1)
        div.toggleBtn.text:SetText("")
    end

    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(div.tex, "Divider", nil, isDelete and "Delete" or "Category")
        _G.__FugaziBAGS_Skins.ApplyToComponent(div.label, "Text", "Header", isDelete and "Delete" or nil)
    end
    
    div:Show()
    return yOff + 16 + 4, true
end


--- Data Table Pools (Moved from Listview to Utils for shared access)
-- Phase 5: finish abandoned aggregate pools — reuse per cacheKey, never row/UI identity.
--------------------------------------------------------------------------------
-- Data pools (Phase 5) — not UI rows. Story:
--   Utils: aggregate dicts/entries, inv/bank item tables, structural category tables
--   Listview module: _lvWorkingList / filter / draw (wipe+refill, file-local)
--   Pools.lua: UI row/text/quality frames only (identity sacred — do not Gemini-rewrite)
-- Bank pools must never alias inv pools (ResetBankDataPools is bank-only).
--------------------------------------------------------------------------------
local _aggDictByKey = {}       -- cacheKey -> wipeable itemId->agg map
local _aggEntryPoolByKey = {}  -- cacheKey -> { pool={}, used=0 }
local _aggCacheWrapByKey = {}  -- cacheKey -> { agg, used, total } wrapper

-- Skin-skip generation: bump when options force a re-skin so open/L3 can skip when unchanged.
A._gphSkinGen = A._gphSkinGen or 0

function A.BumpSkinGeneration()
    A._gphSkinGen = (A._gphSkinGen or 0) + 1
    if A.Inventory then A.Inventory._gphLastAppliedSkin = nil; A.Inventory._gphLastSkinGen = nil end
    if A.Bank then A.Bank._gphLastAppliedSkin = nil; A.Bank._gphLastSkinGen = nil end
end

--- True if frame still needs full ApplySkin for current skin id + generation.
function A.FrameNeedsSkinApply(f)
    if not f then return false end
    local SV = _G.FugaziBAGSDB
    local skinId = (SV and SV.gphSkin) or "elvui_real"
    local gen = A._gphSkinGen or 0
    return f._gphLastAppliedSkin ~= skinId or f._gphLastSkinGen ~= gen
end

function A.NoteFrameSkinApplied(f)
    if not f then return end
    local SV = _G.FugaziBAGSDB
    f._gphLastAppliedSkin = (SV and SV.gphSkin) or "elvui_real"
    f._gphLastSkinGen = A._gphSkinGen or 0
end

local function GetReusableAggDict(cacheKey)
    local t = _aggDictByKey[cacheKey]
    if not t then
        t = {}
        _aggDictByKey[cacheKey] = t
    else
        wipe(t)
    end
    return t
end

local function ResetAggEntryPool(cacheKey)
    local p = _aggEntryPoolByKey[cacheKey]
    if p then
        p.used = 0
    end
end

local function GetRecycledAggEntry(cacheKey)
    local p = _aggEntryPoolByKey[cacheKey]
    if not p then
        p = { pool = {}, used = 0 }
        _aggEntryPoolByKey[cacheKey] = p
    end
    p.used = p.used + 1
    local t = p.pool[p.used]
    if not t then
        t = {}
        p.pool[p.used] = t
    end
    wipe(t)
    return t
end

local function GetReusableCacheWrap(cacheKey)
    local w = _aggCacheWrapByKey[cacheKey]
    if not w then
        w = {}
        _aggCacheWrapByKey[cacheKey] = w
    end
    return w
end

function A.GetRecycledInventoryTable()
    _inventoryItemPoolUsed = _inventoryItemPoolUsed + 1
    local t = _inventoryItemPool[_inventoryItemPoolUsed]
    if not t then t = {}; _inventoryItemPool[_inventoryItemPoolUsed] = t end
    wipe(t)
    return t
end

function A.GetRecycledBankTable()
    _bankItemPoolUsed = _bankItemPoolUsed + 1
    local t = _bankItemPool[_bankItemPoolUsed]
    if not t then t = {}; _bankItemPool[_bankItemPoolUsed] = t end
    wipe(t)
    return t
end

--- Structural tables for category group arrays / divider stubs (not item rows).
--- @param isBank boolean|nil use bank structural pool when true
function A.GetRecycledStructTable(isBank)
    if isBank then
        _structTablePoolBankUsed = _structTablePoolBankUsed + 1
        local t = _structTablePoolBank[_structTablePoolBankUsed]
        if not t then t = {}; _structTablePoolBank[_structTablePoolBankUsed] = t end
        wipe(t)
        return t
    end
    _structTablePoolInvUsed = _structTablePoolInvUsed + 1
    local t = _structTablePoolInv[_structTablePoolInvUsed]
    if not t then t = {}; _structTablePoolInv[_structTablePoolInvUsed] = t end
    wipe(t)
    return t
end

function A.ResetGPHDataPools()
    _inventoryItemPoolUsed = 0
    _structTablePoolInvUsed = 0
end

function A.ResetBankDataPools()
    _bankItemPoolUsed = 0
    _structTablePoolBankUsed = 0
end

function A.CreateBagBarButton(parent, name, bagID, onClick)
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(20, 20)
    btn.bagID = bagID

    -- Modern Visuals (Matching Fixed Bank)
    btn:SetNormalTexture("")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    local slotBg = btn:CreateTexture(nil, "BACKGROUND")
    slotBg:SetAllPoints()
    btn.slotBg = slotBg
    
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Slot", "Bag")
    else
        -- Fallback matches classic ContainerFrame empty slot chrome.
        slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        slotBg:SetVertexColor(1, 1, 1, 1)
        slotBg:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon = icon

    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Shared Tooltip logic
    btn:SetScript("OnEnter", function(self)
        if A.PlayHoverSound then A.PlayHoverSound() end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        local isBankBag = (self.bagID >= 5 and self.bagID <= 11) or self.bagID == -1 or self.bagID == -3
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(self.bagID) or 0
        
        if isBankBag then
            -- Bank bag logic (Handled by RefreshBankUI for state, but tooltip is shared)
            if self.bagID == -3 then
                GameTooltip:SetText("Buy Bank Slot")
            elseif self.bagID == -1 then
                GameTooltip:SetText("Bank Main Container ("..numSlots.." slots)")
            else
                GameTooltip:SetText("Bank Bag Slot ("..numSlots.." slots)")
            end
        elseif self.bagID == -2 then
            GameTooltip:SetText("Keyring")
        else
            GameTooltip:SetText((self.bagID == 0 and "Backpack" or "Bag Slot").." ("..numSlots.." slots)")
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end


--- Shared bag/bank section label (category headers + move-by-category).
--- Priority: Keys → Hearthstone → Protected → Quest → grey/obsolete Misc → Reagent→Trade Goods
--- → gphItemTypeCache (self-heals when live GetItemInfo type differs) → live type / Other / UNKNOWN.
--- info fields: itemId, link, quality, bag, slot, isProtected, isQuest,
---              name, itemType, itemSubType (optional pre-fetched GetItemInfo fields).
function A.ResolveItemCategory(info)
    info = info or {}
    local itemId = info.itemId
    local link = info.link
    if (not itemId) and type(link) == "string" then
        itemId = tonumber(link:match("item:(%d+)"))
    end
    local bag = info.bag
    local slot = info.slot

    if bag == -2 then
        return "Keys"
    end
    if itemId and A.HEARTHSTONE_ID and itemId == A.HEARTHSTONE_ID then
        return "HIDDEN_FIRST"
    end
    if info.isProtected then
        return "BAG_PROTECTED"
    end

    local isQuest = info.isQuest
    if isQuest == nil then
        if bag ~= nil and slot and GetContainerItemQuestInfo then
            if GetContainerItemQuestInfo(bag, slot) then
                isQuest = true
            end
        end
        if not isQuest and link and A.IsQuestItem then
            isQuest = A.IsQuestItem(link) and true or false
        end
    end
    local Loc = A.L
    local catMisc = (Loc and Loc.ITEM_CLASS_MISCELLANEOUS) or "Miscellaneous"
    local catTrade = (Loc and Loc.ITEM_CLASS_TRADE_GOODS) or "Trade Goods"
    local catOther = (Loc and Loc.ITEM_CLASS_OTHER) or "Other"
    local catQuest = (Loc and Loc.ITEM_CLASS_QUEST) or "Quest"
    local subReagent = (Loc and Loc.ITEM_CLASS_REAGENT) or "Reagent"

    if isQuest then
        return catQuest
    end

    local name, quality, itemType, itemSubType = info.name, info.quality, info.itemType, info.itemSubType
    if (name == nil or quality == nil or itemType == nil or itemSubType == nil) and (link or itemId) and A.GetCachedItemInfo then
        local n, _, q, _, _, ty, st = A.GetCachedItemInfo(link or itemId, bag, slot)
        if name == nil then name = n end
        if quality == nil then quality = q end
        if itemType == nil then itemType = ty end
        if itemSubType == nil then itemSubType = st end
    end
    quality = quality or 0

    local function isObsolete(s)
        return type(s) == "string" and s:upper():find("OBSOLETE", 1, true) ~= nil
    end

    if isObsolete(itemType) or isObsolete(itemSubType) then
        return catMisc
    end
    if quality == 0 then
        return catMisc
    end
    if itemSubType == subReagent then
        return catTrade
    end

    local liveType = (itemType and itemType ~= "" and itemType) or nil
    local nameOk = name and name ~= "" and name ~= "Unknown"

    local SV = _G.FugaziBAGSDB
    local typeCache = SV and SV.gphItemTypeCache
    if SV and type(typeCache) ~= "table" then
        typeCache = {}
        SV.gphItemTypeCache = typeCache
    end

    local cached = (itemId and typeCache) and typeCache[itemId] or nil

    -- Self-heal sticky wrong entries (e.g. enchant scroll cached as Trade Goods while API says Consumable).
    if itemId and typeCache and nameOk and liveType and cached and cached ~= liveType then
        typeCache[itemId] = liveType
        cached = liveType
    end

    if cached then
        return cached
    end

    -- Item data not loaded yet — do not poison the cache.
    if not name and (itemId or link) then
        return "UNKNOWN"
    end

    local resolved = liveType or catOther
    if itemId and typeCache and nameOk then
        typeCache[itemId] = resolved
    end
    return resolved
end

local _inventoryDataCache = {}
--- Performs a unified scan of specified bags and returns aggregated item data.
--- @param bagList table Array of bag IDs to scan.
--- @return table aggregated (itemID -> data), number usedSlots, number totalSlots
function A.BuildBagSlotMemory(bag, typeCache)
    A.gphSlotMemory = A.gphSlotMemory or {}
    local bagExisted = A.gphSlotMemory[bag] ~= nil
    A.gphSlotMemory[bag] = A.gphSlotMemory[bag] or {}
    local nSlots = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0

    -- Brand-new bag memory (first scan after login / full wipe) → full grid paint next.
    if not bagExisted then
        A.MarkGridFullRefresh()
    end
    
    -- Clear out any slots that might be past the current bag size (e.g. if bag was swapped)
    for slot = nSlots + 1, 100 do
        if A.gphSlotMemory[bag][slot] then
            if A.gphSlotMemory[bag][slot].link or A.gphSlotMemory[bag][slot].itemId then
                A.MarkGridSlotDirty(bag, slot)
            end
            A.gphSlotMemory[bag][slot].link = nil
            A.gphSlotMemory[bag][slot].itemId = nil
            A.gphSlotMemory[bag][slot].count = 0
        end
    end

    for slot = 1, nSlots do
        local link = A.GetCachedBagLink and A.GetCachedBagLink(bag, slot) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
        -- 3.3.5: texture, count, locked, quality, readable, lootable, link
        local texture, count = nil, 0
        if GetContainerItemInfo then
            local t1, t2, t3, t4, t5 = GetContainerItemInfo(bag, slot)
            texture = t1
            local n2, n3, n4, n5 = tonumber(t2), tonumber(t3), tonumber(t4), tonumber(t5)
            if n2 and n2 > 0 then count = n2
            elseif n3 and n3 > 0 then count = n3
            elseif n4 and n4 > 0 then count = n4
            elseif n5 and n5 > 0 then count = n5
            end
        end
        if link and (not count or count < 1) then
            count = 1
        end
        count = (count and count > 0) and count or 0

        local mem = A.gphSlotMemory[bag][slot] or {}
        A.gphSlotMemory[bag][slot] = mem

        -- Phase 3: detect slot-level deltas for grid dirty paint.
        local oldLink = mem.link
        local oldCount = mem.count or 0
        local oldName = mem.name
        local oldQuality = mem.quality
        local changed = (oldLink ~= link) or (link and oldCount ~= count)
        
        if link then
            mem.link = link
            mem.count = count
            mem.bag = bag
            mem.slot = slot
            local itemId = tonumber(link:match("item:(%d+)"))
            mem.itemId = itemId
            if itemId then
                local name, _, quality, iLevel, _, itemType, itemSubType, _, itemEquipLoc, tex, sellPrice = A.GetCachedItemInfo(link, bag, slot)
                quality = quality or 0
                
                local isProtected = (A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, quality)) or false
                -- Category: one shared resolver (specials + live type + self-healing type cache).
                itemType = A.ResolveItemCategory({
                    itemId = itemId,
                    link = link,
                    quality = quality,
                    bag = bag,
                    slot = slot,
                    isProtected = isProtected,
                    name = name,
                    itemType = itemType,
                    itemSubType = itemSubType,
                })
                
                mem.texture = tex or texture
                mem.name = name or "Unknown"
                mem.quality = quality
                mem.sellPrice = sellPrice or 0
                mem.itemLevel = iLevel or 0
                mem.itemType = itemType
                
                local isEquip = false
                if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" and itemEquipLoc ~= "INVTYPE_TABARD" and itemEquipLoc ~= "INVTYPE_BODY" then
                    isEquip = true
                end
                mem.isEquip = isEquip

                -- Name/quality filled in later (GET_ITEM_INFO_RECEIVED) without link change.
                if not changed and oldLink == link then
                    if (oldName or "") ~= (mem.name or "") or (oldQuality or -1) ~= (quality or -1) then
                        changed = true
                    end
                end
            end
        else
            mem.link = nil
            mem.itemId = nil
            mem.count = 0
        end

        if changed then
            A.MarkGridSlotDirty(bag, slot)
        end
    end
end

function A.GetInventoryData(bagList)
    local cacheKey = table.concat(bagList, ",")
    
    local hasDirty = false
    local dirtyCount = 0
    if A._gphDirtyBags then
        for _, bag in ipairs(bagList) do
            if A._gphDirtyBags[bag] then
                hasDirty = true
                dirtyCount = dirtyCount + 1
            end
        end
    end
    
    if not A._gphBagSpaceDirty and not hasDirty and _inventoryDataCache[cacheKey] then
        local c = _inventoryDataCache[cacheKey]
        -- Poisoned empty bank cache: bank scanned before items were ready (used=0, total>0).
        -- CACHE HIT then keeps list empty forever; grid looks fine (reads slots live).
        -- Only reject bank-like bag lists (main bank -1 or bank bag slots > 4).
        local emptyPoison = c and c.used == 0 and c.total and c.total > 0
        if emptyPoison then
            local looksLikeBank = false
            for _, bag in ipairs(bagList) do
                if bag == -1 or bag > (NUM_BAG_SLOTS or 4) then looksLikeBank = true; break end
            end
            if looksLikeBank then
                _inventoryDataCache[cacheKey] = nil
            else
                return c.agg, c.used, c.total
            end
        elseif c then
            return c.agg, c.used, c.total
        end
    end

    local forceBagSpace = A._gphBagSpaceDirty
    A.gphSlotMemory = A.gphSlotMemory or {}
    local SV = _G.FugaziBAGSDB or {}
    local typeCache = SV.gphItemTypeCache or {}
    SV.gphItemTypeCache = typeCache
    
    if forceBagSpace then
        -- Full bag-space rebuild for bags in THIS list only.
        -- Do not clear _gphBagSpaceDirty here: inventory scan (0-4) must not cancel a
        -- pending full rebuild for bank bags (-1,5-11). Convert flag → per-bag dirty for
        -- any bag in this request, then clear global only when no dirty bags remain.
        A.MarkGridFullRefresh()
        for _, bag in ipairs(bagList) do
            A.BuildBagSlotMemory(bag, typeCache)
            if A._gphDirtyBags then A._gphDirtyBags[bag] = nil end
        end
    else
        for _, bag in ipairs(bagList) do
            if not A.gphSlotMemory[bag] or (A._gphDirtyBags and A._gphDirtyBags[bag]) then
                A.BuildBagSlotMemory(bag, typeCache)
                if A._gphDirtyBags then A._gphDirtyBags[bag] = nil end
            end
        end
    end

    -- Phase 5: reuse aggregate dict + entry tables per cacheKey (inv vs bank stay separate).
    ResetAggEntryPool(cacheKey)
    local aggregated = GetReusableAggDict(cacheKey)
    local usedSlots, totalSlots = 0, 0
    
    for _, bag in ipairs(bagList) do
        local nSlots = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        totalSlots = totalSlots + nSlots
        local bagMem = A.gphSlotMemory[bag]
        if bagMem then
            for slot = 1, nSlots do
                local item = bagMem[slot]
                if item and item.link then
                    usedSlots = usedSlots + 1
                    local itemId = item.itemId
                    if itemId then
                        if not aggregated[itemId] then
                            local agg = GetRecycledAggEntry(cacheKey)
                            agg.totalCount = 0
                            agg.firstBag = item.bag
                            agg.firstSlot = item.slot
                            agg.link = item.link
                            agg.texture = item.texture
                            agg.name = item.name
                            agg.quality = item.quality
                            agg.itemId = itemId
                            agg.sellPrice = item.sellPrice
                            agg.itemLevel = item.itemLevel
                            agg.itemType = item.itemType
                            agg.isEquip = item.isEquip
                            aggregated[itemId] = agg
                        end
                        local addCount = tonumber(item.count) or 0
                        if addCount < 1 then addCount = 1 end
                        aggregated[itemId].totalCount = (tonumber(aggregated[itemId].totalCount) or 0) + addCount
                    end
                end
            end
        end
    end
    
    local wrap = GetReusableCacheWrap(cacheKey)
    wrap.agg = aggregated
    wrap.used = usedSlots
    wrap.total = totalSlots
    _inventoryDataCache[cacheKey] = wrap

    
    -- If this call ran under global bag-space dirty but only rebuilt a subset (e.g. inv
    -- 0-4), mark the other bags dirty so bank is not left on a poisoned empty cache.
    -- Do NOT nil unrebuilt gphSlotMemory here — that forced a bank full rescan thrash
    -- after every inv FULL (idle FULL rebuild should not force bank PARTIAL dirtyBags=8).
    if forceBagSpace then
        A._gphDirtyBags = A._gphDirtyBags or {}
        local rebuilt = {}
        for _, bag in ipairs(bagList) do rebuilt[bag] = true end
        for _, bag in ipairs({ -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }) do
            if not rebuilt[bag] then
                A._gphDirtyBags[bag] = true
            end
        end
        A._gphBagSpaceDirty = false
    else
        local anyDirtyLeft = false
        if A._gphDirtyBags then
            for k, v in pairs(A._gphDirtyBags) do
                if v then anyDirtyLeft = true; break end
            end
        end
        if not anyDirtyLeft then
            A._gphBagSpaceDirty = false
        end
    end

    return aggregated, usedSlots, totalSlots
end

--- Force next bank list build to re-scan bank bags (not inventory). Clears poisoned empty cache.
function A.ForceBankDataRescan()
    A.gphSlotMemory = A.gphSlotMemory or {}
    A._gphDirtyBags = A._gphDirtyBags or {}
    -- Main bank + bank bag slots (3.3.5: -1 and 5..11 when NUM_BAG_SLOTS=4).
    local bags = { -1 }
    local numBag = NUM_BAG_SLOTS or 4
    local numBank = NUM_BANKBAGSLOTS or 7
    for i = 1, numBank do
        bags[#bags + 1] = numBag + i
    end
    for _, bag in ipairs(bags) do
        A.gphSlotMemory[bag] = nil
        A._gphDirtyBags[bag] = true
    end
    -- Drop aggregate cache entries so we cannot CACHE HIT an empty bank scan.
    if _inventoryDataCache then
        wipe(_inventoryDataCache)
    end
end

--- Updates consistent visual state for rarity filter buttons across all views.
function A.GPH_UpdateRarityBarCounts(f, counts)
    if not (f and f.qualityButtons) then return end
    local qFlagFunc = A.GetGphProtectedRarityFlags
    local filterQ = A.GetFilterQualities and A.GetFilterQualities(f) or (f.gphFilterQuality or f.bankRarityFilter)
    local SV = _G.FugaziBAGSDB
    local customHeader = SV and SV.gphCategoryHeaderFontCustom
    local fontPath = customHeader and A.GetCategoryHeaderFontAndSize() or "Fonts\\FRIZQT__.TTF"

    for q = 0, 4 do
        local btn = f.qualityButtons[q]
        if btn then
            local count = (counts and counts[q]) or 0
            btn.currentCount = count
            local rarityFlags = qFlagFunc and qFlagFunc()
            local isProtected = rarityFlags and rarityFlags[q]
            local isFiltered = A.IsQualityFilterSelected and A.IsQualityFilterSelected(f, q)
            
            if btn.labelFs then
                if isFiltered or isProtected then
                    btn.labelFs:SetAlpha(1)
                else
                    btn.labelFs:SetAlpha(0)
                end
                
                if customHeader then
                    btn.labelFs:SetFont(fontPath, 10, "")
                else
                    btn.labelFs:SetFont(fontPath, 8, "")
                end
                
                local isContinuous = not btn.isBankBtn and A.continuousDelActive and A.continuousDelActive[q]
                local contStage = not btn.isBankBtn and A.continuousDelStage and A.continuousDelStage[q]
                local delStage = not btn.isBankBtn and A.rarityDelStage and A.rarityDelStage[q]
                local isPending = not btn.isBankBtn and A.pendingQuality and A.pendingQuality[q]
                local isActiveState = isContinuous or (contStage and (contStage.clicks or 0) >= 1) or (delStage and (delStage.clicks or delStage.stage or 0) >= 1) or isPending
                
                if not isActiveState then
                    A.SafeSetText(btn.labelFs, count > 0 and count or "")
                end
            end
            
            if A.UpdateRarityBtnVisual then
                A.UpdateRarityBtnVisual(f, btn, q, filterQ)
            end
        end
    end
end

A.LayoutRarityBar = LayoutRarityBar

--- Bag contents changed: clear links + mark dirty bags / full space as needed.
--- Single API for Listview / Core / Grid / Bank. Same bag+time is a no-op so dual
--- listeners (Core DE path + Listview UI) do not wipe twice per event.
local _wipeStampByBag = {}
local _wipeAllStamp = nil

function A.WipeBagLinkCache(bag)
    local t = (GetTime and GetTime()) or 0
    if not bag then
        if _wipeAllStamp == t then return end
        _wipeAllStamp = t
        wipe(_wipeStampByBag)
        wipe(_bagLinkCache)
        A._gphBagSpaceDirty = true
        wipe(_inventoryDataCache)
    else
        if _wipeStampByBag[bag] == t or _wipeAllStamp == t then return end
        _wipeStampByBag[bag] = t
        for i = 0, 100 do
            _bagLinkCache[(bag * 100) + i] = nil
        end
        A._gphDirtyBags = A._gphDirtyBags or {}
        A._gphDirtyBags[bag] = true
        wipe(_inventoryDataCache)
    end
end

--- Drop only the aggregate inventory cache (does not mark bag-space full dirty).
function A.InvalidateInventoryDataCache()
    wipe(_inventoryDataCache)
end

--- Soft-dirty: compare live bag contents to slot memory; wipe only bags that actually changed.
--- Used for bare/nil BAG_UPDATE (client idle pulse ~20s) so we do not thrash L1 every tick
--- when nothing moved. Returns true if any bag was dirtied.
--- @param bagList table|nil array of bag ids (default player 0–4)
function A.DirtyBagsIfContentsChanged(bagList)
    bagList = bagList or { 0, 1, 2, 3, 4 }
    local any = false
    A.gphSlotMemory = A.gphSlotMemory or {}
    for _, bag in ipairs(bagList) do
        local nSlots = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        local memBag = A.gphSlotMemory[bag]
        local changed = false
        if not memBag then
            -- Soft pulse must not invent work for bags never scanned (e.g. bank while
            -- closed). Hard BAG_UPDATE(bagId) / open still builds memory normally.
            -- Only flag if live bag already has items we have never memorized.
            for slot = 1, nSlots do
                if GetContainerItemLink and GetContainerItemLink(bag, slot) then
                    changed = true
                    break
                end
            end
        else
            -- Memory longer than live bag (bag swapped smaller) counts as change.
            for slot = nSlots + 1, 100 do
                local m = memBag[slot]
                if m and (m.link or m.itemId) then
                    changed = true
                    break
                end
            end
            if not changed then
                for slot = 1, nSlots do
                    local liveLink = GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
                    local liveCount = 0
                    if GetContainerItemInfo then
                        local t1, t2 = GetContainerItemInfo(bag, slot)
                        liveCount = tonumber(t2) or 0
                        if liveLink and liveCount < 1 then liveCount = 1 end
                    elseif liveLink then
                        liveCount = 1
                    end
                    local m = memBag[slot]
                    local oldLink = m and m.link or nil
                    local oldCount = m and (m.count or 0) or 0
                    if oldLink ~= liveLink then
                        changed = true
                        break
                    end
                    if liveLink and oldCount ~= liveCount then
                        changed = true
                        break
                    end
                end
            end
        end
        if changed then
            if A.WipeBagLinkCache then
                A.WipeBagLinkCache(bag)
            else
                A._gphDirtyBags = A._gphDirtyBags or {}
                A._gphDirtyBags[bag] = true
            end
            any = true
        end
    end
    return any
end

--------------------------------------------------------------------------------
-- Phase 3: grid dirty-slot tracking
-- BuildBagSlotMemory marks slots whose link/count changed.
-- Grid paints only those slots on L1 loot; full paint on open/filter/search/layout.
--------------------------------------------------------------------------------
A._gphDirtySlots = A._gphDirtySlots or {}
A._gphGridFullRefresh = A._gphGridFullRefresh or false

function A.MarkGridSlotDirty(bag, slot)
    if bag == nil or slot == nil then return end
    A._gphDirtySlots = A._gphDirtySlots or {}
    local bagSlots = A._gphDirtySlots[bag]
    if not bagSlots then
        bagSlots = {}
        A._gphDirtySlots[bag] = bagSlots
    end
    bagSlots[slot] = true
end

function A.MarkGridFullRefresh()
    A._gphGridFullRefresh = true
end

function A.ClearGridDirtyState()
    if A._gphDirtySlots then
        for bag, slots in pairs(A._gphDirtySlots) do
            if type(slots) == "table" then wipe(slots) end
        end
        wipe(A._gphDirtySlots)
    end
    A._gphGridFullRefresh = false
end

--- Clear dirty slots only for bags in bagList (inv vs bank share one map).
--- @param bagList table array of bag ids
--- @param clearFullFlag boolean|nil if true, also clear _gphGridFullRefresh
function A.ClearGridDirtySlotsForBags(bagList, clearFullFlag)
    if not bagList or not A._gphDirtySlots then
        if clearFullFlag then A._gphGridFullRefresh = false end
        return
    end
    for _, bag in ipairs(bagList) do
        local slots = A._gphDirtySlots[bag]
        if type(slots) == "table" then
            wipe(slots)
            A._gphDirtySlots[bag] = nil
        end
    end
    if clearFullFlag then A._gphGridFullRefresh = false end
end

--- Count dirty slots among bagList only (bank must not count inv dirties as its work).
--- @param bagList table
--- @return number dirtyCount
function A.GetGridDirtyCountForBags(bagList)
    local n = 0
    if not bagList or not A._gphDirtySlots then return 0 end
    for _, bag in ipairs(bagList) do
        local slots = A._gphDirtySlots[bag]
        if type(slots) == "table" then
            for _, v in pairs(slots) do
                if v then n = n + 1 end
            end
        end
    end
    return n
end

--- Returns: forceFull (bool), dirtyCount (number)
--- Optional bagList: when set, dirtyCount is only those bags (full flag still global).
function A.GetGridDirtyState(bagList)
    if A._gphGridFullRefresh then
        return true, 0
    end
    if bagList then
        return false, A.GetGridDirtyCountForBags(bagList)
    end
    local n = 0
    if A._gphDirtySlots then
        for _, slots in pairs(A._gphDirtySlots) do
            if type(slots) == "table" then
                for _, v in pairs(slots) do
                    if v then n = n + 1 end
                end
            end
        end
    end
    return false, n
end

--- Promote pending inventory refresh level (1=content, 2=list, 3=chrome). Never demotes.
function A.PromoteGPHRefreshLevel(level)
    level = tonumber(level) or 1
    local inv = A.Inventory
    if not inv then return end
    local cur = inv._refreshLevel or 0
    if level > cur then inv._refreshLevel = level end
end
