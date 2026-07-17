local addonName, Addon = ...
_G.FugaziBAGS = _G.FugaziBAGS or Addon or {}
local A = _G.FugaziBAGS

--- Returns true if playing on Project Ebonhold.
local function IsEbonhold()
    local realm = (GetRealmName and GetRealmName()) or ""
    return realm == "Rogue-Lite (Live)"
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

--- Wrap text in color codes (for chat/UI).
local function ColorText(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

local itemInfoCache = {}
function A.GetCachedItemInfo(itemId)
    if not itemId then return nil end
    local cached = itemInfoCache[itemId]
    if cached then 
        return cached[1], cached[2], cached[3], cached[4], cached[5], cached[6], cached[7], cached[8], cached[9], cached[10], cached[11]
    end
    
    local name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, itemEquipLoc, texture, sellPrice = GetItemInfo(itemId)
    if name then
        itemInfoCache[itemId] = {name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, itemEquipLoc, texture, sellPrice}
    end
    return name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, itemEquipLoc, texture, sellPrice
end

--- Format quality counts into a colored string.
local function FormatQualityCounts(qc)
    if not qc then return "|cff555555-|r" end
    local parts = {}
    for q = 0, 7 do
        local count = qc[q]
        if count and count > 0 then
            local info = A.QUALITY_COLORS[q]
            if info then
                table.insert(parts, "|cff" .. info.hex .. count .. " " .. info.label .. "|r")
            end
        end
    end
    if #parts == 0 then return "|cff555555-|r" end
    return table.concat(parts, "  ")
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

local function ClearBagLinkCache(bagID)
    if bagID == nil then
        wipe(_bagLinkCache)
    else
        -- Clear all slots for this bag
        local prefix = bagID * 100
        for slot = 1, 100 do
            _bagLinkCache[prefix + slot] = nil
        end
    end
end
local scanTooltip = nil

--- Returns the centralized hidden scan tooltip for item data extraction.
function A.GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "Fugazi_ScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        scanTooltip:ClearAllPoints()
        scanTooltip:SetPoint("CENTER", UIParent, "CENTER", 99999, 99999)  
        scanTooltip:SetScript("OnShow", function(self) self:Hide() end)
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

--- Does this item ID have a cooldown in bags?
local function ItemIdHasCooldown(itemId, itemIdToSlot)
    if not itemId or not itemIdToSlot then return false end
    local t = itemIdToSlot[itemId]
    if not t or not GetContainerItemCooldown then return false end
    local start, duration = GetContainerItemCooldown(t.bag, t.slot)
    if not duration or duration <= 0 then return false end
    return (start or 0) + duration > GetTime()
end

--- Does this link have cooldown remaining? (scan tooltip.)
local function ItemLinkHasCooldownRemaining(link)
    if not link or link == "" then return false end
    local st = A.GetScanTooltip()
    st:ClearLines()
    st:SetHyperlink(link)
    st:Show()  
    local found = false
    local numLines = st:NumLines() or 0
    local name = st:GetName()
    for i = 1, numLines do
        local line = (name and _G[name .. "TextLeft" .. i]) or _G["GameTooltipTextLeft" .. i]
        if line and line.GetText then
            local text = line:GetText()
            if text and (text:find("Cooldown remaining") or text:find("Cooldown:")) then found = true; break end
        end
    end
    if not found and st.GetNumChildren and st.GetChild then
        for i = 1, (st:GetNumChildren() or 0) do
            local child = st:GetChild(i)
            if child and child.GetText then
                local text = child:GetText()
                if text and (text:find("Cooldown remaining") or text:find("Cooldown:")) then found = true; break end
            end
        end
    end
    st:Hide()
    return found
end

local _scanCounts = {}
--- Scan all bags into flat item list (for diff/snapshot).
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

    -- Safety check: if host is missing or hidden, we fallback to the owner (last resort)
    if not host or not host:GetRight() or host:GetRight() == 0 then return end
    
    -- 2. CLICK-SHIELD: If we just sold/used an item (last 0.15s), freeze the tooltip anchor POSITION.
    -- RELAXED: If the frame reference changed (recycling) or tooltip is hidden, we MUST update.
    local isShieldActive = A.gphTooltipShield and (GetTime() < A.gphTooltipShield)
    if isShieldActive and GameTooltip:IsShown() and GameTooltip:GetOwner() == ownerFrame then
        return 
    end

    -- 3. SIDE NEGOTIATION
    local screenWidth = GetScreenWidth() * (GetCVar("uiScale") or 1)
    local gap = TOOLTIP_FRAME_GAP or 5
    local side = preferredSide or "RIGHT"

    -- DUAL MODE SEAL: If both are open, force Bank=LEFT, Inventory=RIGHT. No Math.
    -- Verification: Ensure 'inv' is valid even if found via variant name.
    if bank and bank:IsShown() and inv and inv:IsShown() then
        if host == bank then side = "LEFT" else side = "RIGHT" end
    else
        -- Solo Mode: Space-based flip (using 330px as buffer)
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


--- Save frame position/size to DB (for restore).
local function SaveFrameLayout(frame, shownKey, pointKey)
    if not frame then return end
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
        SV[pointKey] = SV[pointKey] or {}
        SV[pointKey].point = "TOPLEFT"
        SV[pointKey].relativePoint = "BOTTOMLEFT"
        SV[pointKey].x = left
        SV[pointKey].y = top
        SV[pointKey].w = frame:GetWidth()
        SV[pointKey].h = frame:GetHeight()
    end
    if shownKey then SV[shownKey] = frame:IsShown() end
    if pointKey == "gphPoint" and frame.GetScale then
        SV.gphScale15 = (frame:GetScale() or 1) >= 1.4
    end
end

--- Restore frame position/size from DB.
local function RestoreFrameLayout(frame, shownKey, pointKey)
    if not frame then return end
    local SV = _G.FugaziBAGSDB
    if not SV then return end
    local pt = SV[pointKey]
    if pt and pt.point and pt.relativePoint and pt.x and pt.y then
        frame:ClearAllPoints()
        frame:SetPoint(pt.point, UIParent, pt.relativePoint, pt.x, pt.y)
    end
    if pt and pt.w then frame:SetWidth(pt.w) end
    if pt and pt.h then frame:SetHeight(pt.h) end
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

--- Collapse frame to title bar (like minimap collapse).
local function GetBagSlotForItemId(itemId)
    if not itemId then return nil end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                if link then
                    local id = tonumber(link:match("item:(%d+)"))
                    if id == itemId then return bag, slot end
                end
            end
        end
    end
    return nil
end

local function GetBagSlotWithAtLeast(itemId, minCount)
    if not itemId or not minCount or minCount < 1 then return nil end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local id = GetContainerItemID and GetContainerItemID(bag, slot)
                if not id and GetContainerItemLink then
                    local link = GetContainerItemLink(bag, slot)
                    if link then id = tonumber(link:match("item:(%d+)")) end
                end
                if id == itemId then
                    local stackCount = GetContainerItemInfo and select(2, GetContainerItemInfo(bag, slot))
                    stackCount = (stackCount and stackCount > 0) and stackCount or 1
                    if stackCount >= minCount then return bag, slot, stackCount end
                end
            end
        end
    end
    return nil
end

local function GetAllBagSlotsForItem(itemId, knownBag, knownSlot)
    itemId = tonumber(itemId) or itemId
    if not itemId then return {} end
    local list = {}
    local function addSlot(bag, slot, count)
        if not count or count < 1 then count = 1 end
        list[#list + 1] = { bag = bag, slot = slot, count = count }
    end
    local function getCount(bag, slot)
        if not GetContainerItemInfo then return 1 end
        return 1
    end
    
    if knownBag ~= nil and knownSlot ~= nil then
        local texture = GetContainerItemInfo and select(1, GetContainerItemInfo(knownBag, knownSlot))
        if texture then addSlot(knownBag, knownSlot, getCount(knownBag, knownSlot)) end
    end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                if knownBag == bag and knownSlot == slot then
                    
                else
                    local texture = GetContainerItemInfo and select(1, GetContainerItemInfo(bag, slot))
                    if texture then
                        local id = nil
                        if GetContainerItemID then id = GetContainerItemID(bag, slot) end
                        if not id and GetContainerItemLink then
                            local link = GetContainerItemLink(bag, slot)
                            if link then id = tonumber(link:match("item:(%d+)")) end
                        end
                        if id and tonumber(id) == tonumber(itemId) then
                            addSlot(bag, slot, getCount(bag, slot))
                        end
                    end
                end
            end
        end
    end
    return list
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



--- Calculate total row height based on icon size and base line height
local function ComputeItemDetailsRowHeight(baseHeight)
    local SV = _G.FugaziBAGSDB
    -- We must respect icon size even if custom formatting is off to prevent overlaps
    local iconSize = 16
    if SV then
        iconSize = (SV.gphItemDetailsIconSize and SV.gphItemDetailsIconSize >= 12 and SV.gphItemDetailsIconSize <= 28) and SV.gphItemDetailsIconSize or 16
    end
    return math.max(baseHeight or 18, iconSize + 2)
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

    local step = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphScrollStep) or 600
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


--- Red flash: row marked for destroy (double Ctrl+RMB to confirm).
function A.MarkRowDeletePulse(rowBtn)
    if not rowBtn or not rowBtn.nameFs then return end
    local fs = rowBtn.nameFs
    
    local plainName = rowBtn._plainName or (fs:GetText() and fs:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) or ""
    if plainName == "" then return end
    rowBtn._normalNameText = rowBtn._normalNameText or fs:GetText()
    
    local r1, g1, b1 = 1, 1, 1
    fs:SetText(plainName)
    fs:SetTextColor(1, 0, 0)
    if not rowBtn._delPulseFrame then
        rowBtn._delPulseFrame = CreateFrame("Frame")
    end
    rowBtn._delPulseElapsed = 0
    rowBtn._delPulseFrame:SetScript("OnUpdate", function(f, el)
        local elapsed = (rowBtn._delPulseElapsed or 0) + el
        rowBtn._delPulseElapsed = elapsed
        local duration = 1.0
        local t = elapsed / duration
        if t >= 1.0 then
            fs:SetText(rowBtn._normalNameText or plainName)
            f:SetScript("OnUpdate", nil)
        else
            local r = 1 * (1 - t) + r1 * t
            local g = 0 * (1 - t) + g1 * t
            local b = 0 * (1 - t) + b1 * t
            fs:SetText(plainName)
            fs:SetTextColor(r, g, b)
        end
    end)
end

--- Clear the "marked for destroy" red flash.
function A.StopRowDeletePulse(rowBtn)
    if not rowBtn or not rowBtn.nameFs then return end
    if rowBtn._delPulseFrame then
        rowBtn._delPulseFrame:SetScript("OnUpdate", nil)
    end
    local fs = rowBtn.nameFs
    if rowBtn._normalNameText then
        fs:SetText(rowBtn._normalNameText)
    end
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

--- Save setting for this character.
local function SetPerChar(key, value)
    local SV = _G.FugaziBAGSDB
    if not SV then SV = {}; _G.FugaziBAGSDB = SV end
    if not SV.gphPerChar then SV.gphPerChar = {} end
    local k = A.GetGphCharKey and A.GetGphCharKey() or ""
    if not SV.gphPerChar[k] then SV.gphPerChar[k] = {} end
    SV.gphPerChar[k][key] = value
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
    
    -- In the new flattened system, we apply the alpha directly via the Skin logic
    if f.ApplySkin then
        f.ApplySkin()
    elseif _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyGPHFrameSkin then
        _G.__FugaziBAGS_Skins.ApplyGPHFrameSkin(f)
    end
    
    f:SetAlpha(1)
    
    local itemAlpha = 0.8 + (fa - 0.1) * (0.2 / 0.9)
    if fa < 0.1 then itemAlpha = 0.8 end
    if fa > 0.98 then itemAlpha = 1 end
    
    if f.scrollFrame then f.scrollFrame:SetAlpha(itemAlpha) end
    if f.gphGridContent then f.gphGridContent:SetAlpha(itemAlpha) end
    local chrome = { f.gphTitleBar, f.titleBar, f.gphSep, f.sep, f.gphHeader, f.bankHeader, f.gphBottomBar }
    for _, r in ipairs(chrome) do if r then r:SetAlpha(fa > 0.98 and 1 or fa) end end
end

--- Refresh skin on inventory + bank frames (reapply theme).
function A.ApplyTestSkin()
    if A.Inventory and A.Inventory.ApplySkin then A.Inventory.ApplySkin() end
    if A.Bank and A.Bank.ApplySkin then A.Bank.ApplySkin() end
    if A.Bank and A.Bank.ApplySkin then A.Bank.ApplySkin() end
    if A.Inventory and A.Inventory.ApplySkin then A.Inventory.ApplySkin() end
end
_G.ApplyTestSkin = A.ApplyTestSkin

-- (Exports moved to the bottom of the file to ensure correct execution order)
local function DebugClick(msg)
    local SV = _G.FugaziBAGSDB
    if not (SV and SV.debugClicks) then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFugaziBAGS:|r " .. tostring(msg))
    end
end

local function DebugPrint(msg)
    local SV = _G.FugaziBAGSDB
    if not (SV and SV.debugEnabled) then return end
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFugaziBAGS:|r " .. tostring(msg))
    end
end

--- Shared Visual Update for Rarity Buttons (Inventory + Bank).
local function UpdateRarityBtnVisual(f, btn, q, filterVal)
    if not btn or not btn.bg then return end
    local info = (A.QUALITY_COLORS and A.QUALITY_COLORS[q]) or { r = 0.5, g = 0.5, b = 0.5 }
    local r, g, b = info.r or 0.5, info.g or 0.5, info.b or 0.5
    if q == 0 then r, g, b = 0.58, 0.58, 0.58 elseif q == 1 then r, g, b = 0.96, 0.96, 0.96 end
    local alpha = 0.35
    
    -- PROTECTION FLAGS (MARKING)
    local rarityFlags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
    local isProtected = not btn.noProtection and (rarityFlags and rarityFlags[q])
    
    -- BURST/CONTINUOUS DELETE COLOR OVERRIDES (Inventory Only)
    local contStage = A.continuousDelStage and A.continuousDelStage[q]
    local delStage = A.rarityDelStage and A.rarityDelStage[q]
    local isContinuous = A.continuousDelActive and A.continuousDelActive[q]
    local isPending = A.pendingQuality and A.pendingQuality[q]

    if isContinuous or (contStage and (contStage.clicks or 0) >= 1) or (delStage and (delStage.clicks or delStage.stage or 0) >= 1) or isPending then
        -- Let the OnUpdate script handle the fading/pulsing colors!
        -- We return early from color setting here or use a subtle tinted base.
        r, g, b = 0.8, 0.4, 0.4 -- Tinted red base
        alpha = 0.6
    end

    if filterVal == q then
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
        local isSelected = (filterVal == q)
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
        GameTooltip:AddLine("LMB: Filter quality", 1, 1, 1)
        
        -- Only show Alt-Click protection if not disabled
        if not self.noProtection then
            GameTooltip:AddLine("Alt+LMB: Protect Rarity", 1, 1, 1)
        end

        -- Check context for Mail/Bank/GuildBank
        local atBank = (A.Bank and A.Bank:IsShown()) or (_G.GuildBankFrame and _G.GuildBankFrame:IsShown())
        local atMail = _G.MailFrame and _G.MailFrame:IsShown()
        
        if atBank or atMail then
            local location = (atBank and (_G.GuildBankFrame and _G.GuildBankFrame:IsShown() and "Guild/Realm Bank" or "Bank")) or "Mailbox"
            GameTooltip:AddLine("Shift+RMB: Move rarity to " .. location, 0.6, 1, 0.6)
        end

        -- Only show deletion tools if not disabled
        if not self.noProtection then
            GameTooltip:AddLine("Ctrl+LMB (3x): Toggle Continuous Auto-Delete", 0.75, 0.45, 0.45)
            GameTooltip:AddLine("Ctrl+RMB (3x): Burst Delete all from bags", 0.75, 0.45, 0.45)
        end
    end
    GameTooltip:Show()
    if self.labelFs then self.labelFs:SetAlpha(1) end

    -- Skip protection/mouseDown logic if explicitly disabled (e.g. Bank)
    if self.noProtection then return end
    
    if A._rarityDragInitiated and IsAltKeyDown() and not IsControlKeyDown() and IsMouseButtonDown("LeftButton") then
        local flags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
        if flags and flags[self.quality] ~= A._rarityDragValue then
            if A.GPH_SetRarityProtection then A.GPH_SetRarityProtection(self.quality, A._rarityDragValue) end
            if _G.RefreshGPHUI then _G.RefreshGPHUI() end
            -- Only refresh bank if this button belongs to the bank
            if self.isBankBtn and _G.RefreshBankUI then _G.RefreshBankUI() end
        end
    end
end

function A.GPHQualBtn_OnMouseDown(self, button)
    if self.noProtection then return end
    if button == "LeftButton" and IsAltKeyDown() and not IsControlKeyDown() then
        A._rarityDragInitiated = true
        A._rarityDragValue = not (A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()[self.quality])
        if A.GPH_SetRarityProtection then A.GPH_SetRarityProtection(self.quality, A._rarityDragValue) end
        if _G.RefreshGPHUI then _G.RefreshGPHUI() end
        if self.isBankBtn and _G.RefreshBankUI then _G.RefreshBankUI() end
    end
end

function A.GPHQualBtn_OnLeave(self)
    self._isHovered = false
    local f = self:GetParent():GetParent()
    local filter = f.gphFilterQuality or f.bankRarityFilter
    A.UpdateRarityBtnVisual(f, self, self.quality, filter)
    GameTooltip:Hide()
    -- Only hide the label if no special stage is active
    local q = self.quality
    local active = A.continuousDelActive and A.continuousDelActive[q]
    local stage = A.continuousDelStage and A.continuousDelStage[q]
    local burst = A.rarityDelStage and A.rarityDelStage[q]
    if not (active or stage or burst) then
        if self.labelFs then self.labelFs:SetAlpha(0) end
    end
end

-- Visual logic functions (UpdateRarityButtonState, UpdateAllRarityVisuals) moved to Frames.lua

-- Tooltip Anchoring
A.AnchorTooltipRight = A.AnchorTooltipSmart


--- Trigger a quick visual pulse/flash on a row (feedback for click).
--- This is now in Utils so it can be shared by Inventory and Bank.
local function TriggerRowPulse(btn)
    if not btn or not btn.pulseTex then return end
    btn.pulseTex:Show()
    btn.pulseTex:SetAlpha(0.7)
    if _G.UIFrameFadeOut then
        _G.UIFrameFadeOut(btn.pulseTex, 0.2, 0.7, 0)
    else
        btn.pulseTex:Hide()
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
                GameTooltip:AddLine("Ctrl+LMB: Manage Bags & Keys (Grid Mode).", 0.6, 0.6, 0.6)
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
A.DebugClick = DebugClick
A.DebugPrint = DebugPrint
A.AddonPrint = AddonPrint
A.GetActiveSkinBorderColor = GetActiveSkinBorderColor

A.FormatDateTime = FormatDateTime
A.ColorText = ColorText
A.FormatQualityCounts = FormatQualityCounts
A.AnchorTooltipRight = AnchorTooltipRight
A.GetGphCharKey = GetGphCharKey
A.GetGphCharKey_Utils = GetGphCharKey
A.SaveFrameLayout = SaveFrameLayout
A.RestoreFrameLayout = RestoreFrameLayout
A.GetBagSlotForItemId = GetBagSlotForItemId
A.GetBagSlotWithAtLeast = GetBagSlotWithAtLeast
A.GetAllBagSlotsForItem = GetAllBagSlotsForItem
A.HideBlizzardBags = BlizzardBagAPI and BlizzardBagAPI.Hide
A.ShowBlizzardBags = BlizzardBagAPI and BlizzardBagAPI.Show
A.ComputeItemDetailsRowHeight = ComputeItemDetailsRowHeight
A.GetCategoryHeaderFontAndSize = GetCategoryHeaderFontAndSize
A.IsEbonhold = IsEbonhold
A.IsAscension = IsAscension
A.FormatTime = FormatTime
A.FormatTimeMedium = FormatTimeMedium
A.FormatGold = FormatGold
A.FormatGoldPlain = FormatGoldPlain
A.GetPerChar = GetPerChar
A.SetPerChar = SetPerChar
--- (Assignments moved to SecurePathsHandler.lua)
A.SafeSetText = SafeSetText
A.SafeSetTexture = SafeSetTexture
A.GetItemNameHex = GetItemNameHex
A.GetCachedBagLink = GetCachedBagLink
A.ClearBagLinkCache = ClearBagLinkCache
A.GetItemIdToBagSlot = GetItemIdToBagSlot
A.ItemIdHasCooldown = ItemIdHasCooldown
A.ItemLinkHasCooldownRemaining = ItemLinkHasCooldownRemaining
A.ScanBags = ScanBags
A.GetEquippedItemIds = GetEquippedItemIds
A.UpdateRarityBtnVisual = UpdateRarityBtnVisual
A.GPHQualBtn_OnEnter = A.GPHQualBtn_OnEnter
A.GPHQualBtn_OnLeave = A.GPHQualBtn_OnLeave
A.GPHQualBtn_OnUpdate = A.GPHQualBtn_OnUpdate
A.GPHQualBtn_OnMouseDown = A.GPHQualBtn_OnMouseDown
A.TriggerRowPulse = TriggerRowPulse
A.MarkRowDeletePulse = MarkRowDeletePulse
A.StopRowDeletePulse = StopRowDeletePulse




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

A.LayoutRarityBar = A.LayoutRarityBar


--- Play click sound (bag slot / button).
function A.PlayClickSound()
    local SV = _G.FugaziBAGSDB
    if not SV or SV.gphClickSound == false then return end
    local now = GetTime and GetTime() or 0
    local last = A._gphClickSoundLast or 0
    if now - last < 0.25 then return end
    A._gphClickSoundLast = now
    PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\click.ogg")
end

--- Play swoosh sound (item autodelete / removal).
function A.PlaySwooshSound()
    local SV = _G.FugaziBAGSDB
    if not SV or SV.gphClickSound == false then return end
    if PlaySoundFile then PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\Swoosh2.ogg", "Master") end
end


--- Play hover sound (rarity bar etc).
function A.PlayHoverSound()
    local SV = _G.FugaziBAGSDB
    if not SV or SV.gphClickSound == false then return end
    local now = (GetTime and GetTime()) or 0
    if (A._gphClickSoundLast or 0) > 0 and (now - A._gphClickSoundLast) < 0.15 then return end
    A._gphClickSoundLast = now
    PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\hover.ogg")
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
                if (bf and bf:IsShown()) or (gbf and gbf:IsShown()) or (mf and mf:IsShown()) then
                    local mode = (gbf and gbf:IsShown()) and "bags_to_guildbank" or ((bf and bf:IsShown()) and "bags_to_bank" or "bags_to_mail")
                    A.RarityMoveJob = { mode = mode, category = self.categoryName }
                    if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
                    return
                end
            end
            if clickHandler then clickHandler(self) end
        end)
        
        div:SetScript("OnEnter", function(self)
            if A.PlayHoverSound then A.PlayHoverSound() end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Click to collapse/expand")
            local atBank = (A.Bank and A.Bank:IsShown()) or (_G.GuildBankFrame and _G.GuildBankFrame:IsShown())
            local atMail = _G.MailFrame and _G.MailFrame:IsShown()
            if atBank or atMail then
                local loc = (atBank and (_G.GuildBankFrame and _G.GuildBankFrame:IsShown() and "Guild/Realm Bank" or "Bank")) or "Mailbox"
                GameTooltip:AddLine("Shift+RMB: Move category to " .. loc, 0.6, 1, 0.6)
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
    div:ClearAllPoints()
    div:SetPoint("TOPLEFT", content, "TOPLEFT", f.isBankFrame and 4 or 0, -yOff)
    div:SetPoint("TOPRIGHT", content, "TOPRIGHT", f.isBankFrame and -4 or 0, -yOff)
    div:SetHeight(16)
    
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
local _gphAggregatedPool = {}
local _gphAggregatedPoolUsed = 0
local _gphItemListPool = {}
local _gphItemListPoolUsed = 0

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

function A.ResetGPHDataPools()
    _inventoryItemPoolUsed = 0
end

function A.ResetBankDataPools()
    _bankItemPoolUsed = 0
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
        slotBg:SetTexture("Interface\\Icons\\inv_misc_bag_satchelofcenarius")
        slotBg:SetVertexColor(0.5, 0.5, 0.55, 0.1)
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


local _inventoryDataCache = {}
--- Performs a unified scan of specified bags and returns aggregated item data.
--- @param bagList table Array of bag IDs to scan.
--- @return table aggregated (itemID -> data), number usedSlots, number totalSlots
function A.GetInventoryData(bagList)
    local cacheKey = table.concat(bagList, ",")
    if not A._gphBagSpaceDirty and _inventoryDataCache[cacheKey] then
        local c = _inventoryDataCache[cacheKey]
        return c.agg, c.used, c.total
    end

    local aggregated = {}
    local usedSlots, totalSlots = 0, 0
    local SV = _G.FugaziBAGSDB or {}
    local typeCache = SV.gphItemTypeCache or {}
    SV.gphItemTypeCache = typeCache
    
    for _, bag in ipairs(bagList) do
        local nSlots = (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        totalSlots = totalSlots + nSlots
        for slot = 1, nSlots do
            local link = A.GetCachedBagLink and A.GetCachedBagLink(bag, slot) or (GetContainerItemLink and GetContainerItemLink(bag, slot))
            local texture, count = nil, 0
            if GetContainerItemInfo then
                local t1, t2, t3, t4, t5 = GetContainerItemInfo(bag, slot)
                texture = t1
                if type(t2) == "number" and t2 > 0 then count = t2
                elseif type(t3) == "number" and t3 > 0 then count = t3
                elseif type(t4) == "number" and t4 > 0 then count = t4
                elseif type(t5) == "number" and t5 > 0 then count = t5
                end
            end
            if link and (count == 0 or not count) then
                count = (GetContainerItemInfo and select(2, GetContainerItemInfo(bag, slot))) or 1
            end
            count = (count and count > 0) and count or 0
            
            if link then
                usedSlots = usedSlots + 1
                local itemId = tonumber(link:match("item:(%d+)"))
                if itemId then
                    if not aggregated[itemId] then
                        local name, _, quality, iLevel, _, itemType, itemSubType, _, _, tex, sellPrice = A.GetCachedItemInfo(link)
                        quality = quality or 0
                        
                        -- Categorization logic (Centralized from RefreshGPHUI/RefreshBankUI)
                        local isProtected = (A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, quality)) or false
                        if itemId == A.HEARTHSTONE_ID then
                            itemType = "HIDDEN_FIRST"
                        elseif isProtected then
                            itemType = "BAG_PROTECTED"
                        else
                            -- Check if it's a quest item via Blizzard's quest API
                            local isQuest = false
                            if GetContainerItemQuestInfo and bag and slot then
                                local isQ = GetContainerItemQuestInfo(bag, slot)
                                if isQ then isQuest = true end
                            end
                            
                            if isQuest then
                                itemType = "Quest"
                            elseif quality == 0 then
                                itemType = "Miscellaneous"
                            elseif itemSubType == "Reagent" then
                                itemType = "Trade Goods"
                            else
                                if not typeCache[itemId] then
                                    -- Only write to type cache if the item details have loaded (name is valid)
                                    if name and name ~= "" and name ~= "Unknown" then
                                        itemType = (itemType and itemType ~= "" and itemType) or "Other"
                                        typeCache[itemId] = itemType
                                    else
                                        -- Item details not loaded yet, temporarily use itemType or Other without caching
                                        itemType = (itemType and itemType ~= "" and itemType) or "Other"
                                    end
                                else
                                    itemType = typeCache[itemId]
                                end
                            end
                        end

                        local agg = {} -- No recycling for cached inventory data entries
                        agg.totalCount = 0
                        agg.firstBag = bag
                        agg.firstSlot = slot
                        agg.link = link
                        agg.texture = tex or texture
                        agg.name = name or "Unknown"
                        agg.quality = quality
                        agg.itemId = itemId
                        agg.sellPrice = sellPrice or 0
                        agg.itemLevel = iLevel or 0
                        agg.itemType = itemType
                        aggregated[itemId] = agg
                    end
                    aggregated[itemId].totalCount = aggregated[itemId].totalCount + count
                end
            end
        end
    end
    
    _inventoryDataCache[cacheKey] = { agg = aggregated, used = usedSlots, total = totalSlots }
    A._gphBagSpaceDirty = false -- Reset dirty flag after successful aggregation
    return aggregated, usedSlots, totalSlots
end

--- Updates consistent visual state for rarity filter buttons across all views.
function A.GPH_UpdateRarityBarCounts(f, counts)
    if not (f and f.qualityButtons) then return end
    local qFlagFunc = A.GetGphProtectedRarityFlags
    local filterQ = f.gphFilterQuality or f.bankRarityFilter
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
            
            if btn.labelFs then
                if filterQ == q or isProtected then
                    btn.labelFs:SetAlpha(1)
                else
                    btn.labelFs:SetAlpha(0)
                end
                
                if customHeader then
                    btn.labelFs:SetFont(fontPath, 10, "")
                else
                    btn.labelFs:SetFont(fontPath, 8, "")
                end
                A.SafeSetText(btn.labelFs, count > 0 and count or "")
            end
            
            if A.UpdateRarityBtnVisual then
                A.UpdateRarityBtnVisual(f, btn, q, filterQ)
            end
        end
    end
end

A.LayoutRarityBar = LayoutRarityBar

function A.WipeBagLinkCache(bag)
    if not bag then
        wipe(_bagLinkCache)
        A._gphBagSpaceDirty = true
        wipe(_inventoryDataCache)
    else
        for i = 0, 100 do
            _bagLinkCache[(bag * 100) + i] = nil
        end
        A._gphBagSpaceDirty = true
        wipe(_inventoryDataCache)
    end
end
