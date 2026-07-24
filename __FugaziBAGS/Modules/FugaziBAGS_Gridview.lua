






























local addonName, Addon = ...
_G.FugaziBAGS = _G.FugaziBAGS or Addon or {}
local A = _G.FugaziBAGS
Addon = A

--[[
  FugaziBAGS_CombatGrid: bag grid view (works in combat). Slot grid + bag bar for inv and bank.
]]

local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetItemInfo = _G.GetItemInfo
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetContainerItemCooldown = _G.GetContainerItemCooldown
local SetItemButtonTexture = _G.SetItemButtonTexture
local SetItemButtonCount = _G.SetItemButtonCount
local SetItemButtonDesaturated = _G.SetItemButtonDesaturated
local tonumber = _G.tonumber
local ipairs = _G.ipairs
local pairs = _G.pairs


local DEFAULTS = {
    gridCols = 11, gridSlotSize = 36, gridSpacing = 4,
    gridBorderSize = 3, gridGlowAlpha = 0.80,
    gridProtDesat = 0.35, gridConfirmAutoDel = true,
    gridProtectedKeyAlpha = 0.20,
}

local BAG_IDS         = { 0, 1, 2, 3, 4, -2 }
local MAX_SLOTS       = 36   
local BACKPACK_SLOTS  = 16   
local BAG_BAR_BTN_SZ  = 22   
local BAG_BAR_GAP     = 3
local BAG_BAR_PAD     = 6


local GPH_TOP_TO_GRID  = 93
local GPH_BOTTOM_BAR   = 20
local GPH_LEFT_MARGIN  = 12
local GPH_RIGHT_MARGIN = 8


local gridContent, gphRef, eventFrame
local bagFrames   = {}
local slotButtons = {}
local slotsReady  = false
local bagBar, bagBarBtns = nil, {}
local autoDelSlots = {}   


local lastSearchText = ""


local BANK_BAG_IDS    = { -1, 5, 6, 7, 8, 9, 10, 11 }  
local BANK_MAX_SLOTS  = 36
local bankGridContent, bankGphRef, bankEventFrame, bankDeferFrame
local bankBagFrames   = {}
local bankSlotButtons = {}
local bankSlotsReady  = false
local bankBagBar, bankBagBarBtns = nil, {}
local bankAutoDelSlots = {}




StaticPopupDialogs["FUGAZIGRID_DESTROY_CONFIRM"] = StaticPopupDialogs["FUGAZIGRID_DESTROY_CONFIRM"] or {
    text = "Add %s to auto-destroy list? It will be deleted from your bags while marked.",
    button1 = "Add to list",
    button2 = "Cancel",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}





--- Get grid setting from DB or default (slot size, cols, etc).
local function S(key)
    local DB = _G.FugaziBAGSDB
    local v = (DB and DB[key] ~= nil) and DB[key] or DEFAULTS[key]
    if key == "gridBorderSize" and (not v or v < 1) then v = 2 end
    return v
end


--- Number of slots in bag (keyring -2 handled).
local function NumSlots(bag)
    if bag == -2 then
        if not gphRef or not gphRef._keyringForcedShown then
            return 0
        end
        local KEY_BAG = KEYRING_CONTAINER or -2
        local total = (GetContainerNumSlots and GetContainerNumSlots(KEY_BAG)) or 0
        if total == 0 then return 0 end
        local highest = 0
        for s = 1, total do
            if GetContainerItemInfo(KEY_BAG, s) then highest = s end
        end
        return math.min(total, highest + 1)
    end
    local n = GetContainerNumSlots and GetContainerNumSlots(bag)
    if n and n > 0 then return n end
    if bag == 0 then return BACKPACK_SLOTS end
    return 0
end


--- Number of slots in bank bag.
local function BankNumSlots(bag)
    local n = GetContainerNumSlots and GetContainerNumSlots(bag)
    if n and n > 0 then return n end
    if bag == -1 then return 28 end
    return 0
end


--- Get item quality (0–6) for bag slot.
local function ItemQuality(bag, slot)
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not link then return nil end
    local _, _, q = A.GetCachedItemInfo(link)
    return q
end


--- Rarity color (r,g,b) for quality (grey=0.5, green=0.2,1,0.2, …).
local function QualityRGB(q)
    if not q then return nil end
    local A = _G.FugaziBAGS
    if A and A.QUALITY_COLORS and A.QUALITY_COLORS[q] then
        local c = A.QUALITY_COLORS[q]
        return c.r, c.g, c.b
    end
    if GetItemQualityColor then
        local r, g, b = GetItemQualityColor(q)
        if r then return r, g, b end
    end
    return nil
end


--- Is slot protected (soulbound-to-vendor)? Uses main addon API.
local function IsItemProtected(bag, slot)
    local Addon = _G.FugaziBAGS
    if not Addon then return false end
    local isBank = (bag == -1 or (bag >= 5 and bag <= 11))
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not link then return false end
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId then return false end
    local _, _, q = A.GetCachedItemInfo(link)
    q = q or 0
    if A.IsItemProtectedAPI then
        -- Pass isBank as the ignoreRarity flag so the bank ignores rarity protection but keeps manual protection
        return A.IsItemProtectedAPI(itemId, q, isBank)
    end
    return false
end


--- Unique key for bag+slot (for tables).
local function SlotKey(bag, slot) return bag * 100 + slot end






--- Refresh one grid slot: icon, count, border, protected/destroy state.
local function RefreshSlot(bag, slot, match, searchMatch)
    local btn = slotButtons[bag] and slotButtons[bag][slot]
    if not btn then return end
    local tex, cnt, locked = GetContainerItemInfo(bag, slot)
    
    local ilvlStr = nil
    if tex then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        if link then
            local _, _, _, itemLevel, _, _, _, _, itemEquipLoc = A.GetCachedItemInfo(link, bag, slot)
            if not itemEquipLoc then
                _, _, _, itemLevel, _, _, _, _, itemEquipLoc = GetItemInfo(link)
            end
            if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" and itemEquipLoc ~= "INVTYPE_TABARD" and itemEquipLoc ~= "INVTYPE_BODY" then
                if itemLevel and itemLevel > 1 then
                    ilvlStr = tostring(itemLevel)
                end
            end
        end
    end

    SetItemButtonTexture(btn, tex)
    
    local countText = btn.Count or (btn.GetName and _G[btn:GetName().."Count"])
    if ilvlStr and (not cnt or cnt <= 1) then
        SetItemButtonCount(btn, 0) -- Hide default count
        if countText then 
            countText:SetText(ilvlStr)
            countText:Show()
            countText:SetTextColor(0.5, 1, 0.5) 
        end
    else
        SetItemButtonCount(btn, cnt)
        if countText then countText:SetTextColor(1, 1, 1) end
    end
    
    if match == nil then match = true end
    local q = tex and ItemQuality(bag, slot)
    SetItemButtonDesaturated(btn, locked or not match or (q == 0))
    btn:SetAlpha(match and 1 or 0.2)
    if btn.bagHighlight then btn.bagHighlight:Hide() end

    if btn.searchHighlight then
        if searchMatch then
            btn.searchHighlight:Show()
        else
            btn.searchHighlight:Hide()
        end
    end

    local subType = (bag == -2) and "Keyring" or nil
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Slot", subType)
    else
        btn.slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        btn.slotBg:SetVertexColor(1, 1, 1, 0.25)
    end

    local iconTex = btn.icon or (btn.GetName and _G[btn:GetName() .. "IconTexture"])
    if iconTex then
        iconTex:ClearAllPoints()
        iconTex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        iconTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    if tex then
        local s, d, e = GetContainerItemCooldown(bag, slot)
        local cd = btn.cooldown
        if cd and CooldownFrame_SetTimer then CooldownFrame_SetTimer(cd, s, d, e) end
    else
        if btn.cooldown then btn.cooldown:Hide() end
    end

    local prot = tex and IsItemProtected(bag, slot)
    if btn.protOverlay then
        if prot then
            btn.protOverlay:SetTexture(0, 0, 0, S("gridProtDesat"))
            btn.protOverlay:Show()
        else
            btn.protOverlay:Hide()
        end
    end

    if btn._vendorProtectOverlay then
        local atVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
        if atVendor and prot then btn._vendorProtectOverlay:Show() else btn._vendorProtectOverlay:Hide() end
    end

    if btn.protectedKeyIcon then
        if prot then
            btn.protectedKeyIcon:Show()
            local atVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
            if atVendor then
                btn.protectedKeyIcon:SetAlpha(0.75)
                if btn.protectedKeyIcon.SetDesaturated then btn.protectedKeyIcon:SetDesaturated(0) end
            else
                btn.protectedKeyIcon:SetAlpha(S("gridProtectedKeyAlpha") or 0.2)
                if btn.protectedKeyIcon.SetDesaturated then btn.protectedKeyIcon:SetDesaturated(1) end
            end
        else
            btn.protectedKeyIcon:Hide()
        end
    end

    if btn.wornIcon then
        if tex and Addon and A.IsItemWorn then
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            if itemId and A.IsItemWorn(itemId) then
                btn.wornIcon:Show()
            else
                btn.wornIcon:Hide()
            end
        else
            btn.wornIcon:Hide()
        end
    end

    if btn.wardrobeIcon then
        if tex and _G.C_Appearance and _G.C_AppearanceCollection then
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            local appID = itemId and _G.C_Appearance.GetItemAppearanceID(itemId)
            if appID and not _G.C_AppearanceCollection.IsAppearanceCollected(appID) then
                btn.wardrobeIcon:Show()
            else
                btn.wardrobeIcon:Hide()
            end
        else
            btn.wardrobeIcon:Hide()
        end
    end

    if btn.rarityBorder then
        local r, g, b = QualityRGB(q)
        local bsz = S("gridBorderSize")
        local ga  = S("gridGlowAlpha") or 0
        if q and q > 1 and r and ga > 0 then
            local rb = btn.rarityBorder
            rb[1]:SetHeight(bsz); rb[2]:SetHeight(bsz)
            rb[3]:SetWidth(bsz);  rb[4]:SetWidth(bsz)
            for _, t in ipairs(rb) do t:SetTexture(r, g, b, ga); t:Show() end
        else
            for _, t in ipairs(btn.rarityBorder) do t:Hide() end
        end
    end

    if not InCombatLockdown() and _G.FugaziBAGS_EnsureSecureRowBtn then
        _G.FugaziBAGS_EnsureSecureRowBtn(btn, bag, slot)
        local modOv = btn._fugaziModifierOverlay
        if modOv then
            local altDown = IsAltKeyDown and IsAltKeyDown()
            local ctrlDown = IsControlKeyDown and IsControlKeyDown()
            if (altDown or ctrlDown) and not (altDown and ctrlDown) then
                modOv:Show(); modOv:EnableMouse(true)
            else
                modOv:Hide(); modOv:EnableMouse(false)
            end
        end
    end

    -- DATA-DRIVEN INDICATORS (LAST: Winner over skinning)
    if btn.autoDelOverlay or btn.autoDelText then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        local clicks = Addon and A.actionClickTime
        local activeDel = id and clicks and clicks[id] and ((GetTime() - clicks[id]) <= 1.0)
        
        if activeDel and tex then
            if btn.autoDelOverlay then
                btn.autoDelOverlay:Show()
                btn.autoDelOverlay:SetVertexColor(1, 0, 0, 1)
            end
            if btn.autoDelText then 
                btn.autoDelText:Show()
                btn.autoDelText:SetTextColor(1, 1, 1, 1)
            end
        elseif btn.autoDelOverlay then
            -- Check permanent autodelete list
            local list = Addon and A.GetGphDestroyList and A.GetGphDestroyList()
            if list and id and list[id] then
                btn.autoDelOverlay:Show(); btn.autoDelOverlay:SetVertexColor(0.7, 0.1, 0.1, 0.6)
            else
                btn.autoDelOverlay:Hide()
            end
            if btn.autoDelText then btn.autoDelText:Hide() end
        end
    end
end


--- Does slot match current search text?
local function SearchMatch(bag, slot, q)
    if not q or q == "" then return true end
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not link then return false end
    if A.Search and A.Search.Matches then
        local name, _, quality = A.GetCachedItemInfo(link)
        local tempItem = { link = link, name = name, quality = quality or 0, bag = bag, slot = slot }
        return A.Search.Matches(tempItem, q)
    end
    local name = A.GetCachedItemInfo(link)
    return name and name:lower():find(q, 1, true) ~= nil
end


--- Does slot match quality filter (e.g. show only grey)?
local function RarityMatch(bag, slot, filterQ)
    if filterQ == nil then return true end
    local q = ItemQuality(bag, slot)
    if q == nil then return false end
    if q == filterQ then return true end
    if filterQ == 4 and (q == 5 or q == 6) then return true end
    return false
end


--- Refresh all inventory grid slots (after bag update).
local function RefreshAllSlots()
    local searchQ
    local src = (gphRef and gphRef.gphSearchText and gphRef.gphSearchText ~= "") and gphRef.gphSearchText or (lastSearchText and lastSearchText ~= "" and lastSearchText)
    if src then
        searchQ = src:match("^%s*(.-)%s*$"):lower()
    end
    local filterQ = gphRef and gphRef.gphFilterQuality
    A._gphIsCleaning = true
    for _, bag in ipairs(BAG_IDS) do
        local n = NumSlots(bag)
        if slotButtons[bag] then
            for s = 1, MAX_SLOTS do
                if s <= n then
                    local sm = SearchMatch(bag, s, searchQ)
                    local rm = RarityMatch(bag, s, filterQ)
                    RefreshSlot(bag, s, sm and rm, (searchQ ~= nil and searchQ ~= "" and sm) or false)
                    slotButtons[bag][s]:Show()
                elseif slotButtons[bag][s] then
                    slotButtons[bag][s]:Hide()
                end
            end
        end
    end
    A._gphIsCleaning = false
    
    -- Sync Rarity Bar (Unified Shared Logic)
    local aggInv, used, total = A.GetInventoryData(BAG_IDS)
    if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(aggInv, gphRef) end
end


do
    local timeoutFrame = CreateFrame("Frame")
    timeoutFrame._accum = 0
    timeoutFrame:SetScript("OnUpdate", function(self, elapsed)
        self._accum = (self._accum or 0) + elapsed
        if self._accum < 0.2 then return end  
        self._accum = 0
        local Addon = _G.FugaziBAGS
        local clicks = Addon and A.actionClickTime
        if not clicks or not next(clicks) then return end
        local now = (GetTime and GetTime()) or (time and time()) or 0
        local anyCleared = false
        for itemId, t in pairs(clicks) do
            if (now - (t or 0)) > 1.0 then
                clicks[itemId] = nil
                anyCleared = true
            end
        end
        if anyCleared then
            RefreshAllSlots()
        end
    end)
end


--- Remove overlay textures from slot (clean for reuse).
local function StripSlotTextures(btn)
    local nt = btn:GetNormalTexture()
    if nt then nt:SetTexture(nil) end
    for _, m in pairs({"GetPushedTexture", "GetHighlightTexture"}) do
        if btn[m] then
            local t = btn[m](btn)
            if t then t:ClearAllPoints(); t:SetAllPoints(btn) end
        end
    end
end


--- Run auto-delete on slot if on destroy list.
local function DoAutoDelete(bag, slot)
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    if not link then return end
    if IsItemProtected(bag, slot) then return end
    PickupContainerItem(bag, slot)
    if CursorHasItem and CursorHasItem() then DeleteCursorItem() end
end


--- Grid slot: Alt=protect, Ctrl+RMB=add to destroy list (double to confirm).
-- HandleModifierClick removed, moved to FugaziBAGS_Actions.lua


--- Create one grid slot button (icon, count, cooldown, click).
local function MakeSlot(bag, slot, parent)
    local bname = (bag == -2) and "K" or tostring(bag)
    local name = ("FugaziGrid_B%s_S%d"):format(bname, slot)
    
    -- LITE MIGRATION: No secure templates to avoid moving-audit lag
    local btn = CreateFrame("Button", name, parent)
    btn:SetID(slot)
    btn:SetSize(30, 30) -- Default size, LayoutGrid will fix it
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Manual sub-elements for Lite button
    local icon = btn:CreateTexture(name .. "IconTexture", "ARTWORK")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetAllPoints()
    btn.icon = icon

    local count = btn:CreateFontString(name .. "Count", "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.count = count

    local cooldown = CreateFrame("Cooldown", name .. "Cooldown", btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    btn.cooldown = cooldown

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.slotBg = bg

    local rb  = {}
    local bsz = S("gridBorderSize")
    local top = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(bsz); top:Hide()
    rb[1] = top
    local bot = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(bsz); bot:Hide()
    rb[2] = bot
    local lft = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    lft:SetPoint("TOPLEFT", top, "BOTTOMLEFT"); lft:SetPoint("BOTTOMLEFT", bot, "TOPLEFT"); lft:SetWidth(bsz); lft:Hide()
    rb[3] = lft
    local rgt = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    rgt:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT"); rgt:SetPoint("BOTTOMRIGHT", bot, "TOPRIGHT"); rgt:SetWidth(bsz); rgt:Hide()
    rb[4] = rgt
    btn.rarityBorder = rb
    btn.clickArea = btn

    local po = btn:CreateTexture(nil, "OVERLAY", nil, 3)
    po:SetPoint("TOPLEFT", 1, -1); po:SetPoint("BOTTOMRIGHT", -1, 1)
    po:SetTexture(0, 0, 0, S("gridProtDesat")); po:Hide()
    btn.protOverlay = po

    local wornIcon = btn:CreateTexture(nil, "OVERLAY", nil, 5)
    wornIcon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    wornIcon:SetSize(12, 12)
    wornIcon:SetTexture("Interface\\Icons\\INV_shield_06")
    wornIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    wornIcon:Hide()
    btn.wornIcon = wornIcon

    local wardrobeIcon = btn:CreateTexture(nil, "OVERLAY", nil, 5)
    wardrobeIcon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    wardrobeIcon:SetSize(12, 12)
    if wardrobeIcon.SetAtlas then
        wardrobeIcon:SetAtlas("poi-transmogrifier")
    else
        wardrobeIcon:SetTexture("Interface\\Minimap\\TRACKING\\Transmogrifier")
    end
    wardrobeIcon:Hide()
    btn.wardrobeIcon = wardrobeIcon

    local protectedKeyIcon = btn:CreateTexture(nil, "OVERLAY", nil, 5)
    protectedKeyIcon:SetAllPoints(btn)
    protectedKeyIcon:SetTexture("Interface\\Icons\\INV_Misc_Key_13")
    protectedKeyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    protectedKeyIcon:Hide()
    btn.protectedKeyIcon = protectedKeyIcon

    local adOv = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    adOv:SetPoint("TOPLEFT", 1, -1); adOv:SetPoint("BOTTOMRIGHT", -1, 1)
    adOv:SetTexture(0.7, 0.1, 0.1, 0.6); adOv:Hide()
    btn.autoDelOverlay = adOv

    local sh = btn:CreateTexture(nil, "OVERLAY", nil, 2)
    sh:SetAllPoints()
    sh:SetTexture(1, 1, 1, 0.20)
    sh:SetBlendMode("ADD")
    sh:Hide()
    btn.searchHighlight = sh

    local adFs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    adFs:SetPoint("CENTER"); adFs:SetText("|cffff3333DEL|r")
    adFs:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE"); adFs:Hide()
    btn.autoDelText = adFs

    local hl = btn:CreateTexture(nil, "OVERLAY", nil, 4)
    hl:SetAllPoints(); hl:SetTexture(1, 1, 1, 0.2); hl:SetBlendMode("ADD"); hl:Hide()
    btn.bagHighlight = hl

    local vendorProtectOverlay = CreateFrame("Button", nil, btn)
    vendorProtectOverlay:SetAllPoints(btn)
    vendorProtectOverlay:SetFrameLevel((btn:GetFrameLevel() or 1) + 5)
    vendorProtectOverlay:EnableMouse(true)
    vendorProtectOverlay:RegisterForClicks("RightButtonUp")
    vendorProtectOverlay:SetScript("OnClick", function() end)
    vendorProtectOverlay:Hide()
    vendorProtectOverlay._gphDebugName = "GridVendorOverlay"
    btn._vendorProtectOverlay = vendorProtectOverlay

    btn:SetScript("OnClick", function(self, button)
        A.HandleBagSlotClick(self, button)
    end)

    btn:SetScript("OnDragStart", function(self)
        A.HandleBagSlotDrag(self)
    end)
    btn:SetScript("OnReceiveDrag", function(self)
        A.HandleBagSlotReceiveDrag(self)
    end)
    btn:SetScript("OnEnter", function(self)
        A.HandleBagSlotEnter(self)
    end)
    btn.UpdateTooltip = btn:GetScript("OnEnter")
    btn:SetScript("OnLeave", function(self)
        A.HandleBagSlotLeave(self)
    end)

    -- Explicit IDs for GetBagSlotFromFrame
    btn.bagID = bag
    btn.slotID = slot

    -- Apply Skinning (Unified with Bank and Listview)
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Slot", "Item")
    end

    return btn
end


--- Create all inventory grid slots (or reuse); layout on next frame.
local function EnsureSlots()
    if slotsReady or not gridContent then return end
    slotsReady = true
    for _, bag in ipairs(BAG_IDS) do
        local bname = (bag == -2) and "K" or tostring(bag)
        local bf = CreateFrame("Frame", ("FugaziGrid_Bag%s"):format(bname), gridContent)
        bf:SetID(bag); bf:SetAllPoints(gridContent)
        bagFrames[bag] = bf
        slotButtons[bag] = {}
        for s = 1, MAX_SLOTS do slotButtons[bag][s] = MakeSlot(bag, s, bf) end
    end
end




--- Reskin all slots (inventory/bank) to current skin.
local function ReskinAllSlots()
    if not _G.__FugaziBAGS_Skins or not _G.__FugaziBAGS_Skins.ApplyToComponent then return end
    for _, bag in ipairs(BAG_IDS) do
        if slotButtons[bag] then
            for _, btn in pairs(slotButtons[bag]) do
                _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Slot", "Item")
            end
        end
    end
    if bankSlotButtons then
        for _, bag in ipairs(BANK_BAG_IDS) do
            if bankSlotButtons[bag] then
                for _, btn in pairs(bankSlotButtons[bag]) do
                    _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Slot", "Item")
                end
            end
        end
    end
end


--- Clear highlight from all bag bar buttons.
local function ClearAllBagHighlights()
    for _, bag in ipairs(BAG_IDS) do
        if slotButtons[bag] then
            for _, btn in pairs(slotButtons[bag]) do
                if btn.bagHighlight then btn.bagHighlight:Hide() end
            end
        end
    end
    if bankSlotButtons then
        for _, bag in ipairs(BANK_BAG_IDS) do
            if bankSlotButtons[bag] then
                for _, btn in pairs(bankSlotButtons[bag]) do
                    if btn.bagHighlight then btn.bagHighlight:Hide() end
                end
            end
        end
    end
end


--- Highlight one bag bar button (filter by bag).
local function HighlightBag(bagID)
    ClearAllBagHighlights()
    local slots = slotButtons[bagID] or (bankSlotButtons and bankSlotButtons[bagID])
    if slots then
        for s, btn in pairs(slots) do
            if btn:IsShown() and btn.bagHighlight then btn.bagHighlight:Show() end
        end
    end
end

--- Refresh bag bar (which bags shown, highlight).
local function RefreshBagBar()
    if not bagBar then return end
    for _, bb in ipairs(bagBarBtns) do
        if bb.bagID == 0 then
            bb.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
        elseif bb.bagID == -2 then
            bb.icon:SetTexture("Interface\\ContainerFrame\\KeyRing-Bag-Icon")
            if gphRef and gphRef._keyringForcedShown then
                bb.icon:SetVertexColor(1, 1, 1)
            else
                bb.icon:SetVertexColor(0.4, 0.4, 0.4)
            end
        elseif bb.bagID == -3 then
            bb.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        else
            local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(bb.bagID)
            local tex = invID and GetInventoryItemTexture and GetInventoryItemTexture("player", invID)
            
            if not tex then
                if isBank then
                    tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag" 
                else
                    tex = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
                end
            end
            bb.icon:SetTexture(tex)
        end
    end
end


--- Create bag bar (backpack + bag 1–4 buttons).
local function CreateBagBar(parent)
    if bagBar then return bagBar end
    bagBar = CreateFrame("Frame", "FugaziGrid_"..(isBank and "Bank" or "").."BagBar", parent)
    bagBar:SetHeight(BAG_BAR_BTN_SZ + BAG_BAR_PAD); bagBar:Hide()
    
    local ids
    if isBank then
        ids = { -3, 5, 6, 7, 8, 9, 10, 11 }
    else
        ids = { 0, 1, 2, 3, 4, -2 }
    end
    
    for i, bagID in ipairs(ids) do
        local bb = A.CreateBagBarButton(bagBar, ("FugaziGrid_"..(isBank and "Bank" or "").."BagBtn%d"):format(i), bagID, function(self)
            if A.PlayClickSound then A.PlayClickSound() end
            if self.bagID == -2 then
                if gphRef and gphRef.ToggleKeyringFrame then gphRef:ToggleKeyringFrame()
                elseif ToggleKeyRing then ToggleKeyRing() end
            elseif self.bagID == -3 then
                PlaySound("igMainMenuOption")
                StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
            elseif self.bagID == 0 then
            else
                local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
                if invID then
                    if CursorHasItem and CursorHasItem() then PutItemInBag(invID)
                    else PickupBagFromSlot(invID) end
                end
            end
        end)
        bb:SetSize(20, 20) -- Use consistent 20px
        bb:SetPoint("LEFT", bagBar, "LEFT", 10 + (i - 1) * (20 + (BAG_BAR_GAP or 4)), 0)
        
        bb:SetScript("OnDragStart", function(self)
            if self.bagID > 0 then
                local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
                if invID then PickupBagFromSlot(invID) end
            end
        end)
        bb:SetScript("OnReceiveDrag", function(self)
            if self.bagID > 0 then
                local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
                if invID then PutItemInBag(invID) end
            end
        end)
        bb:SetScript("OnEnter", function(self)
            if self.bagID >= 0 or self.bagID == -2 then HighlightBag(self.bagID) end
            if A.PlayHoverSound then A.PlayHoverSound() end
            
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.bagID == -2 then
                GameTooltip:SetText("Keyring")
            elseif self.bagID == -3 then
                GameTooltip:SetText("Purchase Bank Bag Slot")
                local cost = GetBankSlotCost and GetBankSlotCost()
                if cost and cost > 0 then
                    SetTooltipMoney(GameTooltip, cost)
                end
            elseif self.bagID == 0 then
                GameTooltip:SetText("Backpack (16 slots)")
            else
                local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
                local link = invID and GetInventoryItemLink and GetInventoryItemLink("player", invID)
                if link then GameTooltip:SetHyperlink(link)
                else GameTooltip:SetText(string.format((isBank and "Bank " or "").."Bag %d (empty slot)", self.bagID)) end
            end
            local n = NumSlots and NumSlots(self.bagID) or 0
            if self.bagID >= 0 and n > 0 then GameTooltip:AddLine(n .. " slots", 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)
        bb:SetScript("OnLeave", function(self)
            ClearAllBagHighlights()
            GameTooltip:Hide()
        end)
        bagBarBtns[i] = bb
    end
    return bagBar
end


--- Layout inventory grid (cols, slot size, position slots).
local function LayoutGrid()
    if not gridContent or not gphRef then return end
    local cols    = S("gridCols")
    local size    = S("gridSlotSize")
    local spacing = S("gridSpacing")

    local total = 0
    for _, bag in ipairs(BAG_IDS) do total = total + NumSlots(bag) end
    if total <= 0 then total = BACKPACK_SLOTS end

    local rows  = math.ceil(total / cols)
    local gridW = cols * size + (cols - 1) * spacing
    local gridH = rows * size + (rows - 1) * spacing
    local pad   = 10
    local contentW = gridW + pad * 2
    local contentH = gridH + pad * 2
    gridContent:SetSize(contentW, contentH)

    local bbH = 0
    if bagBar and bagBar:IsShown() then
        bbH = BAG_BAR_BTN_SZ + BAG_BAR_PAD
        bagBar:ClearAllPoints()
        bagBar:SetPoint("TOPLEFT", gridContent, "BOTTOMLEFT", 0, 0)
        bagBar:SetWidth(contentW)
        RefreshBagBar()
    end

    local frameW = GPH_LEFT_MARGIN + contentW + GPH_RIGHT_MARGIN
    local frameH = GPH_TOP_TO_GRID + contentH + bbH + 6 + GPH_BOTTOM_BAR
    gphRef.gphGridFrameW = frameW
    gphRef.gphGridFrameH = frameH
    
    if not InCombatLockdown() then
        gphRef:SetSize(frameW, frameH)
    end
    gphRef._gridNeedsHeaderRefresh = true

    local idx = 0
    for _, bag in ipairs(BAG_IDS) do
        local n = NumSlots(bag)
        for s = 1, MAX_SLOTS do
            local btn = slotButtons[bag] and slotButtons[bag][s]
            if s <= n and btn then
                local r = math.floor(idx / cols)
                local c = idx % cols
                btn:SetSize(size, size)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", gridContent, "TOPLEFT",
                    pad + c * (size + spacing),
                    -(pad + r * (size + spacing)))
                btn:Show()
                idx = idx + 1
            elseif btn then
                btn:Hide()
            end
        end
    end
    RefreshAllSlots()
end




--- Show/hide bag bar.
local function ToggleBagBar()
    if not gridContent or not gphRef then return end
    if not bagBar then CreateBagBar(gridContent) end
    if bagBar:GetParent() ~= gridContent then bagBar:SetParent(gridContent) end
    if bagBar:IsShown() then bagBar:Hide() else bagBar:Show(); RefreshBagBar() end
    LayoutGrid()
end


--- Compute frame size for grid (from cols, rows, margins).
local function ComputeFrameSize(isBank)
    local cols    = S("gridCols")
    local size    = S("gridSlotSize")
    local spacing = S("gridSpacing")
    local total = 0
    local ids = isBank and BANK_BAG_IDS or BAG_IDS
    for _, bag in ipairs(ids) do
        if isBank then total = total + BankNumSlots(bag)
        else total = total + NumSlots(bag) end
    end
    if total <= 0 then total = isBank and 28 or BACKPACK_SLOTS end
    local rows  = math.ceil(total / cols)
    local gridW = cols * size + (cols - 1) * spacing
    local gridH = rows * size + (rows - 1) * spacing
    local pad   = 10
    local contentW = gridW + pad * 2
    local contentH = gridH + pad * 2
    local frameW = GPH_LEFT_MARGIN + contentW + GPH_RIGHT_MARGIN
    local frameH = GPH_TOP_TO_GRID + contentH + 6 + GPH_BOTTOM_BAR
    return frameW, frameH
end





--- Show grid in inventory frame (replace list view).
local function ShowInFrame(f)
    if not f then return end
    if not f.gphHeader and not f._isBankFrame then return end
    gphRef = f
    if not gridContent then
        gridContent = CreateFrame("Frame", nil, f)
        gridContent:Hide(); EnsureSlots()
    end
    
    ClearAllBagHighlights()
    
    if gridContent:GetParent() ~= f then
        gridContent:SetParent(f)
        gridContent:ClearAllPoints()
    end
    
    -- UNIFIED ALIGNMENT: Anchor to the frame directly, matching the Bank layout.
    -- This fixes the "offset to the right" issue on the Fugazi skin.
    gridContent:ClearAllPoints()
    gridContent:SetPoint("TOPLEFT", f, "TOPLEFT", GPH_LEFT_MARGIN, -GPH_TOP_TO_GRID)
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("BAG_UPDATE")
        local deferFrame = CreateFrame("Frame"); deferFrame:Hide()
        deferFrame:SetScript("OnUpdate", function(self)
            self:Hide()
            if A.DiffBagsGPH then A.DiffBagsGPH() end
            if gridContent and gridContent:IsShown() then LayoutGrid() end
        end)
        eventFrame:SetScript("OnEvent", function(_, ev)
            if gridContent and gridContent:IsShown() then
                deferFrame:Show()
                if ev == "BAG_UPDATE" and bagBar and bagBar:IsShown() then
                    RefreshBagBar()
                end
            end
        end)
    end
    if not gridContent._hasModHandler then
        gridContent._hasModHandler = true
        local t = 0
        gridContent:SetScript("OnUpdate", function(self, el)
            t = t + el
            if t < 0.15 then return end
            t = 0
            if not self:IsShown() then return end
            local alt = IsAltKeyDown and IsAltKeyDown()
            local ctrl = IsControlKeyDown and IsControlKeyDown()
            local active = (alt or ctrl) and not (alt and ctrl)
            local bags = (self == gridContent) and BAG_IDS or BANK_BAG_IDS
            local slots = (self == gridContent) and slotButtons or bankSlotButtons
            local mx = (self == gridContent) and MAX_SLOTS or BANK_MAX_SLOTS
            for _, bagID in ipairs(bags) do
                if slots[bagID] then
                    for s = 1, mx do
                        local b = slots[bagID][s]
                        local m = b and b:IsShown() and b._fugaziModifierOverlay
                        if m then
                            local wasShown = m:IsShown()
                            if active then
                                if not wasShown then 
                                    m:Show(); m:EnableMouse(true)
                                    -- Fix: If mouse is over this button, refresh tooltip so it doesn't disappear
                                    if GetMouseFocus() == m then 
                                        A.HandleBagSlotEnter(b, true) -- SILENT
                                    end
                                end
                            else
                                if wasShown then 
                                    m:Hide(); m:EnableMouse(false)
                                    -- Fix: Restore tooltip to the actual slot button
                                    if GetMouseFocus() == b then
                                        A.HandleBagSlotEnter(b, true) -- SILENT
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
    f.gphGridContent = gridContent; f.gphGridMode = true
    f.LayoutGrid = LayoutGrid
    f.ComputeFrameSize = ComputeFrameSize
    if f.scrollFrame then f.scrollFrame:Hide() end
    if f.gphScrollBar then f.gphScrollBar:Hide() end
    if f.bagRow and f.bagRow:IsShown() then f.bagRow:Hide() end
    gridContent:Show(); LayoutGrid()
end




local function HideInFrame(f)
    ClearAllBagHighlights()
    if gridContent then 
        gridContent:Hide()
        gridContent:SetParent(nil)
        gridContent:ClearAllPoints()
    end
    if bagBar then 
        bagBar:Hide()
        bagBar:SetParent(nil)
        bagBar:ClearAllPoints()
    end
    table.wipe(autoDelSlots)
    if f then
        f.gphGridMode = false
        f.gphGridContent = nil
        if f.scrollFrame then f.scrollFrame:Show() end
        if f.gphScrollBar then f.gphScrollBar:Show() end
        if f.bagRowVisible and f.bagRow then f.bagRow:Show() end
    end
    gphRef = nil
end






--- Create all bank grid slots (or reuse).
local function BankEnsureSlots()
    if bankSlotsReady or not bankGridContent then return end
    bankSlotsReady = true
    for _, bag in ipairs(BANK_BAG_IDS) do
        local bf = CreateFrame("Frame", ("FugaziBankGrid_Bag%d"):format(bag < 0 and 99 or bag), bankGridContent)
        bf:SetID(bag); bf:SetAllPoints(bankGridContent)
        bankBagFrames[bag] = bf
        bankSlotButtons[bag] = {}
        for s = 1, BANK_MAX_SLOTS do bankSlotButtons[bag][s] = MakeSlot(bag, s, bf) end
    end
end



--- Refresh one bank grid slot.
local function BankRefreshSlot(bag, slot, match, searchMatch)
    local btn = bankSlotButtons[bag] and bankSlotButtons[bag][slot]
    if not btn then return end
    local tex, cnt, locked = GetContainerItemInfo(bag, slot)
    
    local ilvlStr = nil
    if tex then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        if link then
            local _, _, _, itemLevel, _, _, _, _, itemEquipLoc = A.GetCachedItemInfo(link, bag, slot)
            if not itemEquipLoc then
                _, _, _, itemLevel, _, _, _, _, itemEquipLoc = GetItemInfo(link)
            end
            if itemEquipLoc and itemEquipLoc ~= "" and itemEquipLoc ~= "INVTYPE_BAG" and itemEquipLoc ~= "INVTYPE_TABARD" and itemEquipLoc ~= "INVTYPE_BODY" then
                if itemLevel and itemLevel > 1 then
                    ilvlStr = tostring(itemLevel)
                end
            end
        end
    end

    SetItemButtonTexture(btn, tex)
    
    local countText = btn.Count or (btn.GetName and _G[btn:GetName().."Count"])
    if ilvlStr and (not cnt or cnt <= 1) then
        SetItemButtonCount(btn, 0) -- Hide default count
        if countText then 
            countText:SetText(ilvlStr)
            countText:Show()
            countText:SetTextColor(0.5, 1, 0.5) 
        end
    else
        SetItemButtonCount(btn, cnt)
        if countText then countText:SetTextColor(1, 1, 1) end
    end
    if match == nil then match = true end
    local q = tex and ItemQuality(bag, slot)
    SetItemButtonDesaturated(btn, locked or not match or (q == 0))
    btn:SetAlpha(match and 1 or 0.2)
    if btn.bagHighlight then btn.bagHighlight:Hide() end

    if btn.searchHighlight then
        if searchMatch then
            btn.searchHighlight:Show()
        else
            btn.searchHighlight:Hide()
        end
    end

    
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Slot", "Item")
    else
        btn.slotBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        btn.slotBg:SetVertexColor(1, 1, 1, 0.25)
    end

    local iconTex = btn.icon or (btn.GetName and _G[btn:GetName() .. "IconTexture"])
    if iconTex then
        iconTex:ClearAllPoints()
        iconTex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        iconTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    if tex then
        local s, d, e = GetContainerItemCooldown(bag, slot)
        local cd = btn.cooldown
        if cd and CooldownFrame_SetTimer then CooldownFrame_SetTimer(cd, s, d, e) end
    else
        if btn.cooldown then btn.cooldown:Hide() end
    end

    local prot = tex and IsItemProtected(bag, slot)
    if btn.protOverlay then
        if prot then
            btn.protOverlay:SetTexture(0, 0, 0, S("gridProtDesat"))
            btn.protOverlay:Show()
        else
            btn.protOverlay:Hide()
        end
    end
    if btn._vendorProtectOverlay then
        local atVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
        if atVendor and prot then btn._vendorProtectOverlay:Show() else btn._vendorProtectOverlay:Hide() end
    end
    if btn.protectedKeyIcon then
        if prot then
            btn.protectedKeyIcon:Show()
            local atVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
            if atVendor then
                btn.protectedKeyIcon:SetAlpha(0.5)
                if btn.protectedKeyIcon.SetDesaturated then btn.protectedKeyIcon:SetDesaturated(0) end
            else
                btn.protectedKeyIcon:SetAlpha(S("gridProtectedKeyAlpha") or 0.2)
                if btn.protectedKeyIcon.SetDesaturated then btn.protectedKeyIcon:SetDesaturated(1) end
            end
        else
            btn.protectedKeyIcon:Hide()
        end
    end

    if btn.wornIcon then
        if tex and Addon and A.IsItemWorn then
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            if itemId and A.IsItemWorn(itemId) then
                btn.wornIcon:Show()
            else
                btn.wornIcon:Hide()
            end
        else
            btn.wornIcon:Hide()
        end
    end

    if btn.rarityBorder then
        local q = tex and ItemQuality(bag, slot)
        local r, g, b = QualityRGB(q)
        local bsz = S("gridBorderSize")
        local ga  = S("gridGlowAlpha") or 0
        if q and q > 1 and r and ga > 0 then
            local rb = btn.rarityBorder
            rb[1]:SetHeight(bsz); rb[2]:SetHeight(bsz)
            rb[3]:SetWidth(bsz);  rb[4]:SetWidth(bsz)
            for _, t in ipairs(rb) do t:SetTexture(r, g, b, ga); t:Show() end
        else
            for _, t in ipairs(btn.rarityBorder) do t:Hide() end
        end
    end

    if not InCombatLockdown() and _G.FugaziBAGS_EnsureSecureRowBtn then
        _G.FugaziBAGS_EnsureSecureRowBtn(btn, bag, slot)
        local modOv = btn._fugaziModifierOverlay
        if modOv then
            local altDown = IsAltKeyDown and IsAltKeyDown()
            local ctrlDown = IsControlKeyDown and IsControlKeyDown()
            if (altDown or ctrlDown) and not (altDown and ctrlDown) then
                modOv:Show(); modOv:EnableMouse(true)
            else
                modOv:Hide(); modOv:EnableMouse(false)
            end
        end
    end

    -- DATA-DRIVEN INDICATORS (LAST: Winner over skinning)
    if btn.autoDelOverlay or btn.autoDelText then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        local id = link and tonumber(link:match("item:(%d+)"))
        local clicks = Addon and A.actionClickTime
        local activeDel = id and clicks and clicks[id] and ((GetTime() - clicks[id]) <= 1.0)
        
        if activeDel and tex then
            if btn.autoDelOverlay then
                btn.autoDelOverlay:Show()
                btn.autoDelOverlay:SetVertexColor(1, 0, 0, 1)
            end
            if btn.autoDelText then 
                btn.autoDelText:Show()
                btn.autoDelText:SetTextColor(1, 1, 1, 1)
            end
        elseif btn.autoDelOverlay then
            -- Check permanent autodelete list
            local list = Addon and A.GetGphDestroyList and A.GetGphDestroyList()
            if list and id and list[id] then
                btn.autoDelOverlay:Show(); btn.autoDelOverlay:SetVertexColor(0.7, 0.1, 0.1, 0.6)
            else
                btn.autoDelOverlay:Hide()
            end
            if btn.autoDelText then btn.autoDelText:Hide() end
        end
    end
end


--- Refresh all bank grid slots.
local function BankRefreshAllSlots()
    ReskinAllSlots()
    local searchQ
    local searchSrc = (bankGphRef and bankGphRef.gphSearchText and bankGphRef.gphSearchText ~= "") and bankGphRef.gphSearchText or (gphRef and gphRef.gphSearchText and gphRef.gphSearchText ~= "") and gphRef.gphSearchText or (lastSearchText and lastSearchText ~= "" and lastSearchText)
    if searchSrc then
        searchQ = searchSrc:match("^%s*(.-)%s*$"):lower()
    end
    local filterQ = bankGphRef and bankGphRef.gphFilterQuality
    A._gphIsCleaning = true
    for _, bag in ipairs(BANK_BAG_IDS) do
        local n = BankNumSlots(bag)
        if bankSlotButtons[bag] then
            for s = 1, BANK_MAX_SLOTS do
                if s <= n then
                    local sm = SearchMatch(bag, s, searchQ)
                    local rm = RarityMatch(bag, s, filterQ)
                    BankRefreshSlot(bag, s, sm and rm, (searchQ ~= nil and searchQ ~= "" and sm) or false)
                    bankSlotButtons[bag][s]:Show()
                elseif bankSlotButtons[bag][s] then
                    bankSlotButtons[bag][s]:Hide()
                end
            end
        end
    end
    A._gphIsCleaning = false
    
    -- Sync Rarity Bar (Unified Shared Logic)
    local aggInv, used, total = A.GetInventoryData(BANK_BAG_IDS)
    if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(aggInv, bankGphRef) end
end


--- Layout bank grid (cols, slot size).
local function BankLayoutGrid()
    if not bankGridContent or not bankGphRef then return end
    local cols    = S("gridCols")
    local size    = S("gridSlotSize")
    local spacing = S("gridSpacing")

    local total = 0
    for _, bag in ipairs(BANK_BAG_IDS) do total = total + BankNumSlots(bag) end
    if total <= 0 then total = 28 end

    local rows  = math.ceil(total / cols)
    local gridW = cols * size + (cols - 1) * spacing
    local gridH = rows * size + (rows - 1) * spacing
    local pad   = 10
    local contentW = gridW + pad * 2
    local contentH = gridH + pad * 2
    bankGridContent:SetSize(contentW, contentH)

    local frameW = GPH_LEFT_MARGIN + contentW + GPH_RIGHT_MARGIN
    local frameH = GPH_TOP_TO_GRID + contentH + 6 + GPH_BOTTOM_BAR
    bankGphRef.gphGridFrameW = frameW
    bankGphRef.gphGridFrameH = frameH
    if not InCombatLockdown() then
        bankGphRef:SetSize(frameW, frameH)
    end

    local idx = 0
    for _, bag in ipairs(BANK_BAG_IDS) do
        local n = BankNumSlots(bag)
        for s = 1, BANK_MAX_SLOTS do
            local btn = bankSlotButtons[bag] and bankSlotButtons[bag][s]
            if s <= n and btn then
                local r = math.floor(idx / cols)
                local c = idx % cols
                btn:SetSize(size, size)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", bankGridContent, "TOPLEFT",
                    pad + c * (size + spacing),
                    -(pad + r * (size + spacing)))
                btn:Show()
                idx = idx + 1
            elseif btn then
                btn:Hide()
            end
        end
    end
    BankRefreshAllSlots()
end


--- Show grid in bank frame (replace bank list).
local function ShowInBankFrame(f)
    if not f then return end
    bankGphRef = f
    f._isBankFrame = true
    if not bankGridContent then
        bankGridContent = CreateFrame("Frame", nil, f)
        bankGridContent:Hide()
        BankEnsureSlots()
    end
    
    ClearAllBagHighlights()
    
    if bankGridContent:GetParent() ~= f then
        bankGridContent:SetParent(f)
        bankGridContent:ClearAllPoints()
    end
    
    bankGridContent:SetPoint("TOPLEFT", f, "TOPLEFT", GPH_LEFT_MARGIN, -GPH_TOP_TO_GRID)
    if not bankEventFrame then
        bankEventFrame = CreateFrame("Frame")
        bankEventFrame:RegisterEvent("BAG_UPDATE")
        bankEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
        bankEventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
        
        bankDeferFrame = CreateFrame("Frame"); bankDeferFrame:Hide()
        bankDeferFrame:SetScript("OnUpdate", function(self)
            self:Hide()
            if bankGridContent and bankGridContent:IsShown() then BankRefreshAllSlots() end
        end)

        bankEventFrame:SetScript("OnEvent", function(self, event, ...)
            local arg1 = ...
            if event == "BAG_UPDATE" then
                if A.WipeBagLinkCache then A.WipeBagLinkCache(arg1) end
            elseif event == "PLAYERBANKSLOTS_CHANGED" then
                if A.WipeBagLinkCache then A.WipeBagLinkCache(-1) end
            end
            if bankGridContent and bankGridContent:IsShown() and bankDeferFrame then
                bankDeferFrame:Show()
            end
        end)
    end
    if not bankGridContent._hasModHandler then
        bankGridContent._hasModHandler = true
        local t = 0
        local bankChildReuse = {}
        local function fillChildReuse(t, ...)
            for i = 1, select("#", ...) do t[i] = select(i, ...) end
            return select("#", ...)
        end
        bankGridContent:SetScript("OnUpdate", function(self, el)
            t = t + el
            if t < 0.15 then return end
            t = 0
            if not self:IsShown() then return end
            local alt = IsAltKeyDown and IsAltKeyDown()
            local ctrl = IsControlKeyDown and IsControlKeyDown()
            local active = (alt or ctrl) and not (alt and ctrl)
            
            wipe(bankChildReuse)
            fillChildReuse(bankChildReuse, self:GetChildren())
            
            for i = 1, #bankChildReuse do
                local b = bankChildReuse[i]
                local m = b and b._fugaziModifierOverlay
                if m then
                    local wasShown = m:IsShown()
                    if active then
                        if not wasShown then 
                            m:Show(); m:EnableMouse(true)
                            -- Fix: Silent tooltip refresh
                            if GetMouseFocus() == m then 
                                A.HandleBagSlotEnter(b, true) 
                            end
                        end
                    else
                        if wasShown then 
                            m:Hide(); m:EnableMouse(false)
                            -- Fix: Restore tooltip to the actual slot button
                            if GetMouseFocus() == b then
                                A.HandleBagSlotEnter(b)
                            end
                        end
                    end
                end
            end
        end)
    end
    f.gphGridContent = bankGridContent; f.gphGridMode = true
    if f.scrollFrame then f.scrollFrame:Hide() end
    if f.gphScrollBar then f.gphScrollBar:Hide() end
    bankGridContent:Show(); BankLayoutGrid()
end


--- Hide grid in bank frame (back to list).
local function HideInBankFrame(f)
    ClearAllBagHighlights()
    if bankGridContent then bankGridContent:Hide() end
    if f then
        f.gphGridMode = false
        f.gphGridContent = nil
        if f.scrollFrame then f.scrollFrame:Show() end
        if f.gphScrollBar then f.gphScrollBar:Show() end
    end
    bankGphRef = nil
end

    
_G.FugaziBAGS_CombatGrid = {
    ShowInFrame      = ShowInFrame,
    HideInFrame      = HideInFrame,
    ShowInBankFrame  = ShowInBankFrame,
    HideInBankFrame  = HideInBankFrame,
    ApplySearch      = function(t)
        lastSearchText = (t and t ~= "" and t:match("^%s*(.-)%s*$")) or ""
        if gphRef then gphRef.gphSearchText = t end
        if bankGphRef then bankGphRef.gphSearchText = t end
        RefreshAllSlots()
        if bankGridContent and bankGridContent:IsShown() then BankRefreshAllSlots() end
    end,
    RefreshSlots     = RefreshAllSlots,
    LayoutGrid       = LayoutGrid,
    ToggleBagBar     = ToggleBagBar,
    IsBagBarShown    = function() return bagBar and bagBar:IsShown() end,
    IsShown          = function() return gridContent and gridContent:IsShown() end,
    ComputeFrameSize = ComputeFrameSize,
    BankRefreshSlots = BankRefreshAllSlots,
    BankLayoutGrid   = BankLayoutGrid,
    IsBankShown      = function() return bankGridContent and bankGridContent:IsShown() end,
    HandleModifierClick = HandleModifierClick,
}


local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(_, _, addon)
    if addon and addon:lower():find("fugazibags") then
        if not gridContent then
            gridContent = CreateFrame("Frame", nil, UIParent)
            gridContent:SetSize(1, 1)
            gridContent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10000, -10000)
            gridContent:Hide(); EnsureSlots()
        end
    end
end)
