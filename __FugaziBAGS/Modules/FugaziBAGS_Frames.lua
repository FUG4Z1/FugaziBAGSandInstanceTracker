local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

-- Cache common globals for performance and reliability
local Skins = _G.__FugaziBAGS_Skins
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerItemCooldown = _G.GetContainerItemCooldown
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown

local SCROLL_CONTENT_WIDTH = 296

local sessionStartGold, sessionEarned, sessionSpent, lastGold
local function UpdateSessionGold()
    local cur = GetMoney() or 0
    if not sessionStartGold then
        sessionStartGold = cur
        lastGold = cur
        sessionEarned = 0
        sessionSpent = 0
        return
    end
    local delta = cur - lastGold
    if delta > 0 then
        sessionEarned = (sessionEarned or 0) + delta
    elseif delta < 0 then
        sessionSpent = (sessionSpent or 0) - delta
    end
    lastGold = cur
end

local goldTrackerFrame = CreateFrame("Frame")
goldTrackerFrame:RegisterEvent("PLAYER_MONEY")
goldTrackerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
goldTrackerFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        local cur = GetMoney() or 0
        sessionStartGold = cur
        lastGold = cur
        sessionEarned = 0
        sessionSpent = 0
        
        -- Save current character class to FugaziBAGSDB
        local _, myClass = UnitClass("player")
        if myClass and _G.FugaziBAGSDB then
            _G.FugaziBAGSDB.charClasses = _G.FugaziBAGSDB.charClasses or {}
            local myKey = ((GetRealmName and GetRealmName()) or "") .. "#" .. ((UnitName and UnitName("player")) or "")
            _G.FugaziBAGSDB.charClasses[myKey] = myClass
        end
    elseif event == "PLAYER_MONEY" then
        UpdateSessionGold()
    end
end)


-------------------------------------------------------------------------------
-- UI Utilities & Layout Helpers
-------------------------------------------------------------------------------

--- Update button visibility on the Inventory frame (Profession/Mail buttons).
function A.UpdateGPHButtonVisibility(f)
    if not f then return end
    if f.UpdateGPHProfessionButtons then f:UpdateGPHProfessionButtons() end
end


--- Layout refresh for the Inventory frame (resizing, hiding/showing elements).
function A.RefreshBagLayout(f)
    if not f or not f.scrollFrame then return end
    if not f.gphGridMode then
        local wantW = f.gphGridFrameW or f:GetWidth() or 340
        local wantH = f.gphGridFrameH or f.EXPANDED_HEIGHT or 520
        f.gphForceHeight = wantH
        f.gphForceHeightFrames = 8
        local p = f:GetParent()
        local r, t = f:GetRight(), f:GetTop()
        if not InCombatLockdown() then
            f:ClearAllPoints()
            f:SetPoint("TOPRIGHT", p, "BOTTOMLEFT", r, t)
            f:SetSize(wantW, wantH)
        end
    end
    if f.statusText then f.statusText:Show() end
    if f.gphSep then f.gphSep:Show() end
    if f.gphSearchBtn then f.gphSearchBtn:Show() end
    if f.gphSearchEditBox then
        if f.gphSearchBarVisible then f.gphSearchEditBox:Show() else f.gphSearchEditBox:Hide() end
    end
    if f.gphHeader then f.gphHeader:Show() end
    if f.gphGridMode and f.gphGridContent then
        if not InCombatLockdown() then
            f.scrollFrame:Hide()
            if f.gphScrollBar then f.gphScrollBar:Hide() end
            f.gphGridContent:Show()
        end
        local cg = _G.FugaziBAGS_CombatGrid
        if cg and cg.LayoutGrid then cg.LayoutGrid() end
    else
        if not InCombatLockdown() then f.scrollFrame:Show() end
    end
    if f.gphBottomBar then
        f.gphBottomBar:ClearAllPoints()
        f.gphBottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        f.gphBottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end
    if f.gphCloseBtn then f.gphCloseBtn:Show() end
    if f.UpdateGPHButtonVisibility then f:UpdateGPHButtonVisibility() end
end


--- Negotiate sizes between Inventory and Bank frames (ensuring they dock correctly).
function A.NegotiateSizes(f)
    if not f then return end
    local DB = _G.FugaziBAGSDB
    if not DB then return end
    
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    local bW, bH, iW, iH
    
    local cg = _G.FugaziBAGS_CombatGrid
    
    if f.gphGridMode then
        iW = f.gphGridFrameW or f:GetWidth()
        iH = f.gphGridFrameH or f:GetHeight()
    elseif cg and cg.ComputeFrameSize then
        iW, iH = cg.ComputeFrameSize(false)
        -- Ensure listview doesn't shrink below a reasonable minimum (default 520)
        local minH = (DB.gphMinHeight or f.EXPANDED_HEIGHT or 520)
        iH = math.max(iH or 0, minH)
    else
        iW = 340
        iH = f.EXPANDED_HEIGHT or 520
    end
    
    -- Fallback to last saved height if current is somehow still zero or extremely small
    local savedPoint = DB.gphPoint
    if (not iH or iH < 100) and savedPoint and savedPoint.h then
        iH = savedPoint.h
    end
    
    local finalW, finalH = iW, iH
    
    local bank = A.Bank
    if bank and bank:IsShown() then
        if bank.gphGridMode then
            bW = bank.gphGridFrameW or bank:GetWidth()
            bH = bank.gphGridFrameH or bank:GetHeight()
        elseif cg and cg.ComputeFrameSize then
            bW, bH = cg.ComputeFrameSize(true)
        else
            bW = 340
            bH = 520
        end
        local _math_max = _G.math and _G.math.max or math.max
        finalW = _math_max(bW or 0, iW or 0)
        finalH = _math_max(bH or 0, iH or 0)
        
        if bank:GetWidth() ~= finalW then bank:SetWidth(finalW) end
        if bank:GetHeight() ~= finalH then bank:SetHeight(finalH) end
    end
    
    if f:GetWidth() ~= finalW then f:SetWidth(finalW) end
    if f:GetHeight() ~= finalH then f:SetHeight(finalH) end
    
    if f.content then
        local scrollW = finalW - 14
        f.content:SetWidth(scrollW)
        f.gphDynContentWidth = scrollW
    end
end


--- Update the icon and appearance of the Disenchant/Prospect button.
function A.UpdateDestroyButtonAppearance(f)
    if not f or not f.gphDestroyBtn then return end
    local DB = _G.FugaziBAGSDB
    local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    
    local preferProspect = DB and DB.gphDestroyPreferProspect and hasProspect and hasDE
    local iconPath
    
    if (hasProspect and not hasDE) or preferProspect then
        iconPath = "Interface\\Icons\\inv_misc_gem_bloodgem_01"
    else
        iconPath = "Interface\\Icons\\inv_enchant_disenchant"
    end

    local dBtn = f.gphDestroyBtn
    local dIcon = dBtn.icon
    if iconPath and dIcon then
        dIcon:SetTexture(iconPath)
        dIcon:Show()
        dBtn:Show()
        dBtn:SetAlpha(0.6)
        
        if not hasDE and not hasProspect then
            if dIcon.SetDesaturated then dIcon:SetDesaturated(true) end
            dIcon:SetVertexColor(0.8, 0.8, 0.8, 0.8)
        else
            if dIcon.SetDesaturated then dIcon:SetDesaturated(false) end
            dIcon:SetVertexColor(1, 1, 1, 1)
        end
    elseif dIcon then
        dIcon:Hide()
        dBtn:Hide()
    end
end


--- Drag start handler for the Inventory frame.
function A.GPHOnDragStart(f)
    if not f or f._isDragging then return end
    if IsAltKeyDown and IsAltKeyDown() then return end
    f._isDragging = true
    if f.gphSelectedItemId then
        f.gphSelectedItemId = nil
        f.gphSelectedIndex = nil
        f.gphSelectedRowBtn = nil
        f.gphSelectedItemLink = nil
        if f.HideGPHUseOverlay then f.HideGPHUseOverlay(f) end
    end
    f:StartMoving()
end


--- Drag stop handler for the Inventory frame.
function A.GPHOnDragStop(f)
    if not f or not f._isDragging then return end
    f._isDragging = nil
    f:StopMovingOrSizing()
    if f.NegotiateSizes then f:NegotiateSizes() end
    local DB = _G.FugaziBAGSDB
    if DB then DB.gphDockedToMain = false end
    if A.SaveFrameLayout then A.SaveFrameLayout(f, "gphShown", "gphPoint") end
    
    -- Maintain scroll offset visuals
    local sf = f.scrollFrame
    local c = sf and sf:GetScrollChild()
    if c and sf then
        local v = f.gphScrollOffset or 0
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, v)
        local contentWidth = f.gphDynContentWidth or sf:GetWidth() or 296
        c:SetWidth(contentWidth)
        if c.SetHeight then c:SetHeight(c:GetHeight() or 1) end
    end
end


-------------------------------------------------------------------------------
-- Window Management
-------------------------------------------------------------------------------

--- Show/hide inventory (B key target).
--- (ToggleGPHFrame moved to SecurePathsHandler.lua)


--- Factory function to create the modern Inventory window.
function A.CreateGPHFrame()
    local DB = _G.FugaziBAGSDB or {}
    local Skins = _G.__FugaziBAGS_Skins
    local f = CreateFrame("Frame", "InventoryMainFrame", UIParent)
    A.Inventory = f
    f._isBankFrame = false
    local cg = _G.FugaziBAGS_CombatGrid
    local initW, initH = 340, 520
    if cg and cg.ComputeFrameSize then
        initW, initH = cg.ComputeFrameSize()
    end
    f:SetWidth(initW)
    f:SetHeight(initH)
    f.gphGridFrameW = initW
    f.gphGridFrameH = initH
    
    f:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) A.GPHOnDragStart(self) end)
    f:SetScript("OnDragStop", function(self) A.GPHOnDragStop(self) end)
    f:SetScript("OnHide", function()
        if f.gphProxyFrame then f.gphProxyFrame:Hide() end
        A.SaveFrameLayout(f, "gphShown", "gphPoint")
        if not f.gphGridMode and f.gphScrollBar then
            f.gphScrollOffset = 0
            f.gphScrollBar:SetMinMaxValues(0, 0)
            f.gphScrollBar:SetValue(0)
        end
    end)
    f._gphSkinAppliedOnFirstShow = nil  
    f:SetScript("OnShow", function()
        if not InCombatLockdown() and f.gphProxyFrame then f.gphProxyFrame:Show() end
        if not f._gphSkinAppliedOnFirstShow and f.ApplySkin then
            f._gphSkinAppliedOnFirstShow = true
            f:ApplySkin()
        end
        if f.ApplySkin then f:ApplySkin() end
        local Skins = _G.__FugaziBAGS_Skins
        if f.gphTitle and Skins and Skins.ApplyGphInventoryTitle then Skins.ApplyGphInventoryTitle(f.gphTitle) end
        
        f.gphScrollToDefaultOnNextRefresh = true
        f._gphHomebaseRetryScheduled = nil
        if RefreshGPHUI then RefreshGPHUI() end
        local df = A._gphSelectionDeferFrame
        if df then
            df:Show()
            df:SetScript("OnUpdate", function(self)
                self:SetScript("OnUpdate", nil)
                self:Hide()
                if f then
                    f.gphScrollToDefaultOnNextRefresh = true
                    f._refreshImmediate = true
                end
                if RefreshGPHUI then RefreshGPHUI() end
            end)
        end
    end)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(10)
    f.EXPANDED_HEIGHT = 520

    local gphEscCatcher = CreateFrame("EditBox", nil, f)
    gphEscCatcher:SetAutoFocus(false)
    gphEscCatcher:SetSize(1, 1)
    gphEscCatcher:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -1000, 0)
    gphEscCatcher:SetAlpha(0)
    gphEscCatcher:EnableMouse(false)
    gphEscCatcher:Hide()
    gphEscCatcher:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:Hide()
        local hadPending = false
        if A.pendingQuality then
            for q in pairs(A.pendingQuality) do
                A.pendingQuality[q] = nil
                hadPending = true
            end
        end
        if A.rarityDelStage then
            for q in pairs(A.rarityDelStage) do
                A.rarityDelStage[q] = nil
                hadPending = true
            end
        end
        if hadPending and A.RefreshGPHUI then A.RefreshGPHUI() end
    end)
    f.gphEscCatcher = gphEscCatcher

    f._delTimeoutAccum = 0
    local gphDelTimeoutFrame = CreateFrame("Frame", nil, f)
    gphDelTimeoutFrame:SetScript("OnUpdate", function(self, elapsed)
        if not (A.rarityDelStage and next(A.rarityDelStage)) then
            self._accum = 0
            return
        end
        self._accum = (self._accum or 0) + elapsed
        if self._accum < 0.5 then return end
        self._accum = 0
        local now = GetTime()
        local changed = false
        for q, st in pairs(A.rarityDelStage) do
            if (now - (st.time or 0)) > 3 then
                A.rarityDelStage[q] = nil
                if A.pendingQuality then A.pendingQuality[q] = nil end
                if f.gphEscCatcher then f.gphEscCatcher:ClearFocus(); f.gphEscCatcher:Hide() end
                changed = true
            end
        end
        if changed and A.RefreshGPHUI then
            f._refreshImmediate = true
            A.RefreshGPHUI()
        end
    end)

    local gphMenu = CreateFrame("Frame", "FugaziBAGS_GPHMenu", f, "UIDropDownMenuTemplate")

    local titleBar = CreateFrame("Button", nil, f)
    titleBar:SetHeight(30)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    titleBar:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    titleBar:SetBackdropColor(0.35, 0.28, 0.1, 0.7)
    titleBar:RegisterForClicks("RightButtonUp")
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function(self) A.GPHOnDragStart(f) end)
    titleBar:SetScript("OnDragStop", function(self) A.GPHOnDragStop(f) end)
    titleBar:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            UIDropDownMenu_Initialize(gphMenu, A.GPHTitleMenu_Initialize, "MENU")
            ToggleDropDownMenu(1, nil, gphMenu, "cursor", 0, 0)
        end
    end)
    f.gphTitleBar = titleBar

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    if Skins and Skins.ApplyGphInventoryTitle then Skins.ApplyGphInventoryTitle(title) end
    f.gphTitle = title

    local keybindOwner = _G.InstanceTrackerKeybindOwner or CreateFrame("Frame", "InstanceTrackerKeybindOwner", UIParent)
    _G.InstanceTrackerKeybindOwner = keybindOwner
    local invKeybindBtn = CreateFrame("Button", "InstanceTrackerGPHInvKeybindBtn", keybindOwner, "SecureActionButtonTemplate")
    invKeybindBtn:SetAttribute("type", "macro")
    invKeybindBtn:SetAttribute("macrotext", "/run ToggleGPHFrame()")
    invKeybindBtn:SetSize(1, 1)
    invKeybindBtn:SetPoint("BOTTOMLEFT", keybindOwner, "BOTTOMLEFT", -10000, -10000)
    invKeybindBtn:SetAlpha(0)
    invKeybindBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    invKeybindBtn:Hide()
    f.gphInvKeybindBtn = invKeybindBtn

    local container = CreateFrame("Frame", "FugaziBAGS_InventoryContainer", keybindOwner)
    container:SetSize(1, 1)
    container:SetPoint("BOTTOMLEFT", keybindOwner, "BOTTOMLEFT", -10000, -10000)
    container:Hide()
    container:SetScript("OnShow", function()
        local wantGrid = A.GetPerChar("gphGridMode", false)
        local cg = _G.FugaziBAGS_CombatGrid
        if not InCombatLockdown() then f:Show() end
        f.gphGridMode = wantGrid
        if f.gphGridMode and cg and cg.ShowInFrame then
            cg.ShowInFrame(f)
        else
            if cg and cg.HideInFrame then cg.HideInFrame(f) end
        end
    end)
    container:SetScript("OnHide", function()
        local cg = _G.FugaziBAGS_CombatGrid
        if cg and cg.HideInFrame then cg.HideInFrame(f) end
        if not InCombatLockdown() then f:Hide() end
    end)
    f.gphInventoryContainer = container

    local proxy = CreateFrame("Frame", nil, UIParent)
    proxy:SetSize(1, 1)
    proxy:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10000, -10000)
    proxy:Hide()
    proxy:SetScript("OnShow", function() if not InCombatLockdown() then container:Show() end end)
    proxy:SetScript("OnHide", function() if not InCombatLockdown() then container:Hide() end end)
    f.gphProxyFrame = proxy

    local secureToggle = CreateFrame("Button", "FugaziBAGS_SecureBagToggle", UIParent, "SecureHandlerClickTemplate")
    secureToggle:SetSize(1, 1)
    secureToggle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -10000, -10000)
    secureToggle:RegisterForClicks("AnyUp")
    secureToggle:Show()
    SecureHandlerSetFrameRef(secureToggle, "gphframe", f)
    secureToggle:SetAttribute("_onclick", [[
        local f = self:GetFrameRef("gphframe")
        if not f then return end
        if f:IsShown() then
            f:Hide()
        else
            f:Show()
        end
    ]])
    f.gphSecureToggle = secureToggle

    local _syncingVisibility = false
    f:HookScript("OnShow", function()
        if _syncingVisibility then return end
        _syncingVisibility = true
        if container and not container:IsShown() then container:Show() end
        _syncingVisibility = false
    end)

    f:HookScript("OnHide", function()
        if _syncingVisibility then return end
        _syncingVisibility = true
        if container and container:IsShown() then container:Hide() end
        _syncingVisibility = false
    end)

    f.ApplyBagKeyOverrides = function() if A.ApplyBagKeyOverrides then A.ApplyBagKeyOverrides(secureToggle) end end
    f.ApplyBagKeyOverrides()

    f.RefreshBagLayout = function(self) A.RefreshBagLayout(self) end
    f.UpdateGPHButtonVisibility = function(self) A.UpdateGPHButtonVisibility(self) end
    if DB.gphDestroyPreferProspect == nil then DB.gphDestroyPreferProspect = false end

    local destroyBtn = CreateFrame("Button", nil, titleBar, "SecureActionButtonTemplate")
    destroyBtn:SetSize(22, 22) 
    destroyBtn:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
    destroyBtn:SetFrameStrata("DIALOG")
    destroyBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    destroyBtn:EnableMouse(true)
    destroyBtn:RegisterForClicks("AnyUp")
    destroyBtn:SetAttribute("type1", "macro")
    destroyBtn:SetAttribute("macrotext1", "")
    local destroyBg = destroyBtn:CreateTexture(nil, "BACKGROUND")
    destroyBg:SetAllPoints()
    destroyBg:SetTexture(0, 0, 0, 0) 
    destroyBtn.bg = destroyBg
    local destroyIcon = destroyBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    destroyIcon:SetAllPoints(destroyBtn)
    destroyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) 
    destroyIcon:SetAlpha(1.0)
    destroyBtn.icon = destroyIcon

    -- Click blocker overlay to swallow spam clicks
    local destroyBlocker = CreateFrame("Button", nil, destroyBtn)
    destroyBlocker:SetAllPoints(destroyBtn)
    destroyBlocker:SetFrameLevel(destroyBtn:GetFrameLevel() + 5)
    destroyBlocker:EnableMouse(true)
    destroyBlocker:RegisterForClicks("AnyUp", "AnyDown")
    destroyBlocker:SetScript("OnClick", function() end) -- Consume the clicks
    destroyBlocker:Hide()
    destroyBtn.blocker = destroyBlocker

    local lastClickTime = 0
    destroyBtn:SetScript("PreClick", function(self, button, down)
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        if button ~= "LeftButton" then
            self:SetAttribute("macrotext1", "")
            return
        end
        
        local now = GetTime()
        if now - lastClickTime < 0.5 then
            self:SetAttribute("macrotext1", "")
            return
        end
        lastClickTime = now

        -- If the spell targeting cursor is stuck, reset the slot locks
        if SpellIsTargeting and SpellIsTargeting() then
            if A.lockedDisenchantSlots then wipe(A.lockedDisenchantSlots) end
            A.activeDisenchantSlot = nil
        end
        
        -- Prevent disenchanting if moving or mounted (failsafe against accidental equips)
        if (GetUnitSpeed and GetUnitSpeed("player") or 0) > 0 or (IsMounted and IsMounted()) then
            self:SetAttribute("macrotext1", "")
            return
        end
        if UnitCastingInfo and UnitCastingInfo("player") then
            self:SetAttribute("macrotext1", "")
            return
        end
        if IsShiftKeyDown() then
            self:SetAttribute("macrotext1", "")
            return
        end
        
        local preferProspect = DB.gphDestroyPreferProspect
        local bag, slot, spellName, itemLink = A.GetFirstDestroyableInBags(preferProspect)
        
        if not spellName or not bag or not slot then
            self:SetAttribute("macrotext1", "")
            return
        end
        
        local link = GetContainerItemLink(bag, slot)
        local itemId = link and tonumber(link:match("item:(%d+)"))
        
        A.isDisenchanting = true
        A.lockedDisenchantSlots = A.lockedDisenchantSlots or {}
        A.lockedDisenchantSlots[bag .. "_" .. slot] = now
        A.activeDisenchantSlot = { bag = bag, slot = slot, itemId = itemId, time = now }
        self:SetAttribute("macrotext1", ("/cast %s;\n/use %d %d"):format(spellName, bag, slot))
        
        -- Show blocker overlay to absorb all subsequent clicks for 0.5 seconds
        if self.blocker then
            self.blocker:Show()
            self.blocker.elapsed = 0
            self.blocker:SetScript("OnUpdate", function(self2, elapsed)
                self2.elapsed = (self2.elapsed or 0) + elapsed
                if self2.elapsed >= 0.5 then
                    self2:SetScript("OnUpdate", nil)
                    self2:Hide()
                end
            end)
        end
    end)
    destroyBtn:SetScript("OnEnter", function()
        if f.gphBtnHover then
            destroyBtn.bg:SetTexture(unpack(f.gphBtnHover))
        else
            destroyBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.9)
        end
        destroyIcon:SetAlpha(1)
        GameTooltip:SetOwner(destroyBtn, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        
        local preferProspect = DB.gphDestroyPreferProspect
        local bag, slot, spellName = A.GetFirstDestroyableInBags(preferProspect)
        local hoverText = "Disenchant"
        if spellName then
            if spellName:find("Prospect") then
                hoverText = "Prospect"
            else
                hoverText = "Disenchant"
            end
        else
            local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
            local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
            if (hasProspect and not hasDE) or (preferProspect and hasProspect and hasDE) then
                hoverText = "Prospect"
            else
                hoverText = "Disenchant"
            end
        end
        
        GameTooltip:AddLine(hoverText, 0.9, 0.8, 0.5)
        GameTooltip:Show()
    end)
    destroyBtn:SetScript("OnLeave", function()
        if f.gphBtnNormal then
            destroyBtn.bg:SetTexture(unpack(f.gphBtnNormal))
        else
            destroyBtn.bg:SetTexture(0.1, 0.3, 0.15, 0.7)
        end
        destroyIcon:SetAlpha(0.8)
        GameTooltip:Hide()
    end)
    destroyBtn:SetScript("PostClick", function()
        if A.PlayClickSound then A.PlayClickSound() end
    end)
    f.gphDestroyBtn = destroyBtn
    f.UpdateDestroyButtonAppearance = function(self) A.UpdateDestroyButtonAppearance(self) end
    f.UpdateDestroyMacro = function() end

    local mailBtn = CreateFrame("Button", nil, titleBar)
    mailBtn:SetSize(22, 22) 
    mailBtn:SetFrameStrata("DIALOG")
    mailBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    mailBtn:EnableMouse(true)
    mailBtn:RegisterForClicks("LeftButtonUp")
    local mailBg = mailBtn:CreateTexture(nil, "BACKGROUND")
    mailBg:SetAllPoints()
    mailBtn.bg = mailBg
    if Skins and Skins.ApplyToComponent then
        Skins.ApplyToComponent(mailBtn, "Button")
    else
        mailBg:SetTexture(0.1, 0.3, 0.15, 0.7)
    end
    local mailIcon = mailBtn:CreateTexture(nil, "ARTWORK")
    mailIcon:SetAllPoints(mailBtn)
    mailIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) 
    mailIcon:SetTexture("Interface\\Icons\\inv_letter_09")
    mailBtn.icon = mailIcon

    local isLootingMail = false
    local lastMailLootTime = 0
    local mailLootWorker = CreateFrame("Frame", nil, f)
    mailLootWorker:SetScript("OnUpdate", function(self, elapsed)
        if not isLootingMail then return end
        lastMailLootTime = (lastMailLootTime or 0) + elapsed
        if lastMailLootTime < 0.1 then return end
        lastMailLootTime = 0
        local free = 0
        for bag = 0, 4 do
            free = free + (GetContainerNumFreeSlots(bag) or 0)
        end
        if free <= 1 then
            print("|cffff0000[FugaziBAGS]|r Mail looting stopped: 1 slot remaining.")
            isLootingMail = false
            return
        end
        local num = GetInboxNumItems()
        for i = 1, num do
            local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
            if (cod or 0) <= 0 then
                if hasItem then
                    local attachments = 0
                    local maxAtt = (_G.ATTACHMENTS_MAX_RECEIVE or 12)
                    for ai = 1, maxAtt do
                        if GetInboxItem(i, ai) then attachments = attachments + 1 end
                    end
                    if free - attachments >= 1 then
                        AutoLootMailItem(i)
                        return
                    end
                elseif money > 0 then
                    TakeInboxMoney(i)
                    return
                end
            end
        end
        print("|cff00ff00[FugaziBAGS]|r Finished looting mail.")
        isLootingMail = false
    end)

    mailBtn:SetScript("OnClick", function()
        local isSendTab = (_G.MailFrame.selectedTab == 2)
        if isSendTab then
            local recipient = _G.SendMailNameEditBox:GetText()
            if not recipient or recipient == "" then
                print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
                return
            end
            StaticPopup_Show("GPH_CONFIRM_MAIL_ALL", recipient)
        else
            if isLootingMail then
                isLootingMail = false
                print("|cffff0000[FugaziBAGS]|r Mail looting cancelled.")
            else
                isLootingMail = true
                lastMailLootTime = 0
                print("|cff00ff00[FugaziBAGS]|r Starting mail loot...")
            end
        end
    end)
    mailBtn:SetScript("OnEnter", function()
        local isSendTab = (_G.MailFrame.selectedTab == 2)
        GameTooltip:SetOwner(mailBtn, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        if isSendTab then
            GameTooltip:AddLine("Send All Items", 0.9, 0.8, 0.4)
            GameTooltip:AddLine("Sends every item in your bags to current recipient.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Skips Hearthstone, Quest, and Protected items.", 1, 0.2, 0.2, true)
        else
            GameTooltip:AddLine("Get All Mail", 0.9, 0.8, 0.4)
            GameTooltip:AddLine("Quickly loots attachments and money.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Stops when only 1 bag slot remains.", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
        if mailBtn.gphBtnHover then mailBtn.bg:SetTexture(unpack(mailBtn.gphBtnHover)) else mailBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.8) end
    end)
    mailBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if mailBtn.gphBtnNormal then mailBtn.bg:SetTexture(unpack(mailBtn.gphBtnNormal)) else mailBtn.bg:SetTexture(0.1, 0.3, 0.15, 0.4) end
        mailIcon:SetAlpha(0.6)
    end)
    f.gphMailBtn = mailBtn
    f.UpdateGPHProfessionButtons = function(self) A.UpdateGPHProfessionButtons(self) end

    if A.CreateGPHStatusBar then A.CreateGPHStatusBar(f) end
    
    local gphSearchBtn = CreateFrame("Button", nil, f)
    gphSearchBtn:EnableMouse(true)
    gphSearchBtn:SetSize(36, 18)
    local gphSearchBtnBg = gphSearchBtn:CreateTexture(nil, "BACKGROUND")
    gphSearchBtnBg:SetAllPoints()
    gphSearchBtn.bg = gphSearchBtnBg
    if Skins and Skins.ApplyToComponent then
        Skins.ApplyToComponent(gphSearchBtn, "Button", "Search")
    else
        gphSearchBtnBg:SetTexture(0.1, 0.3, 0.15, 0.7)
    end
    local gphSearchLabel = gphSearchBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gphSearchLabel:SetPoint("CENTER")
    gphSearchLabel:SetText("Search")
    if Skins and Skins.ApplyToComponent then
        Skins.ApplyToComponent(gphSearchLabel, "Text", "Search")
    else
        gphSearchLabel:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
        gphSearchLabel:SetTextColor(0.92, 0.82, 0.55, 1)
    end
    f.gphSearchBtn = gphSearchBtn
    f.gphSearchLabel = gphSearchLabel
    local gphSearchBtnHighlight = gphSearchBtn:CreateTexture(nil, "HIGHLIGHT")
    gphSearchBtnHighlight:SetAllPoints()
    gphSearchBtnHighlight:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    gphSearchBtnHighlight:SetVertexColor(1, 1, 1, 0.15)
    gphSearchBtnHighlight:SetBlendMode("ADD")
    gphSearchBtn.highlight = gphSearchBtnHighlight

    gphSearchBtn:SetScript("OnClick", function()
        if A.PlayClickSound then A.PlayClickSound() end
        f.gphSearchBarVisible = not f.gphSearchBarVisible
        if f.gphSearchEditBox then
            if f.gphSearchBarVisible then
                f.gphSearchEditBox:Show()
                f.gphSearchEditBox:SetFocus()
            else
                f.gphSearchEditBox:Hide()
                if A.Search and A.Search.Sync then
                    A.Search.Sync("", f)
                else
                    f.gphSearchEditBox:SetText("")
                    f.gphSearchText = ""
                    if RefreshGPHUI then RefreshGPHUI() end
                end
            end
        end
    end)
    gphSearchBtn:SetScript("OnEnter", function(self)
        if A.PlayHoverSound then A.PlayHoverSound() end
    end)
    gphSearchBtn:SetScript("OnLeave", function(self)
    end)
    gphSearchBtn:SetScript("OnHide", function(self)
    end)

    local gphSearchEditBox = CreateFrame("EditBox", nil, f)
    gphSearchEditBox:SetHeight(20)
    gphSearchEditBox:SetPoint("LEFT", gphSearchBtn, "RIGHT", 6, 0)
    gphSearchEditBox:SetPoint("RIGHT", f, "TOPRIGHT", -8, 0) 
    gphSearchEditBox:SetAutoFocus(false)
    gphSearchEditBox:SetFontObject("GameFontHighlightSmall")
    gphSearchEditBox:SetTextInsets(6, 4, 0, 0)
    gphSearchEditBox:Hide()
    local gphSearchBg = gphSearchEditBox:CreateTexture(nil, "BACKGROUND")
    gphSearchBg:SetAllPoints()
    gphSearchBg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    gphSearchBg:SetVertexColor(0.12, 0.1, 0.06)
    gphSearchBg:SetAlpha(0.95)
    gphSearchEditBox:SetScript("OnEnter", function() if A.PlayHoverSound then A.PlayHoverSound() end end)
    gphSearchEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f.gphSearchBarVisible = false
        self:Hide()
        if A.Search and A.Search.Sync then
            A.Search.Sync("", f)
        else
            self:SetText("")
            f.gphSearchText = ""
            if RefreshGPHUI then RefreshGPHUI() end
        end
    end)
    gphSearchEditBox:SetScript("OnChar", function()
        local SV = _G.FugaziBAGSDB
        if SV and SV.gphClickSound ~= false and PlaySoundFile then
            PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\click.ogg")
        end
    end)
    gphSearchEditBox:SetScript("OnTextChanged", function(self, userInput)
        if A.Search and A.Search.Sync then
            A.Search.Sync(self:GetText(), f)
        end
        if userInput then
            local txt = self:GetText()
            local SV = _G.FugaziBAGSDB
            if (f._prevSearchLen or 0) > #txt then
                if SV and SV.gphClickSound ~= false and PlaySoundFile then
                    PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\hover.ogg")
                end
            end
            f._prevSearchLen = #txt
        end
    end)
    f.gphSearchEditBox = gphSearchEditBox
    f.gphSearchBarVisible = false
    f.gphSearchText = ""

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -6)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -6)
    if Skins and Skins.ApplyToComponent then
        Skins.ApplyToComponent(sep, "Divider")
    else
        sep:SetTexture(1, 1, 1, 0.15)
    end
    f.gphSep = sep
    gphSearchBtn:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -4)

    local gphHeader = CreateFrame("Frame", nil, f)
    gphHeader:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -30)
    gphHeader:SetPoint("TOPRIGHT", sep, "BOTTOMRIGHT", 0, -30)
    gphHeader:SetHeight(18)
    f.gphHeader = gphHeader
    
    local gphBagSpaceBtn = A.CreateBagSpaceIndicator(f, gphHeader, false)

    local function placeCursorInFirstFreeSlot()
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag) or 0
            for slot = 1, numSlots do
                if not GetContainerItemLink(bag, slot) then
                    if _G.PickupContainerItem then _G.PickupContainerItem(bag, slot) end
                    f._refreshImmediate = true
                    if RefreshGPHUI then RefreshGPHUI() end
                    return true
                end
            end
        end
        return false
    end
    gphBagSpaceBtn:SetScript("OnReceiveDrag", function() placeCursorInFirstFreeSlot() end)
    gphBagSpaceBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    gphBagSpaceBtn:SetScript("OnClick", function(self, button)
        if IsControlKeyDown() and not IsAltKeyDown() and button == "LeftButton" then
            if f.gphGridMode then
                local cg = _G.FugaziBAGS_CombatGrid
                if cg and cg.ToggleBagBar then cg.ToggleBagBar() end
            else
                -- List Mode Bag Bar Toggle (Match Bank behavior)
                if f.bagRow then
                    f.bagRowVisible = not f.bagRowVisible
                    if f.bagRowVisible then
                        f.bagRow:SetHeight(20)
                        f.bagRow:SetAlpha(1)
                        f.bagRow:Show()
                        if f.scrollFrame then f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 50) end
                    else
                        f.bagRow:SetHeight(0)
                        f.bagRow:SetAlpha(0)
                        f.bagRow:Hide()
                        if f.scrollFrame then f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 20) end
                    end
                    if A.RefreshGPHBagRow then A.RefreshGPHBagRow(f) end
                end
            end
            return
        end
        if button ~= "LeftButton" then return end
        if A.PlayClickSound then A.PlayClickSound() end
        if GetCursorInfo and GetCursorInfo() == "item" then placeCursorInFirstFreeSlot() end
    end)
    f.gphBagSpaceBtn = gphBagSpaceBtn

    local gphBottomBar = CreateFrame("Frame", nil, f)
    gphBottomBar:SetHeight(20)
    gphBottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    gphBottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    gphBottomBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    gphBottomBar:SetBackdropColor(0.08, 0.06, 0.04, 0.9)
    gphBottomBar:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.6)
    local gphBottomLeft = gphBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gphBottomLeft:SetPoint("LEFT", gphBottomBar, "LEFT", 6, 0)
    gphBottomLeft:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    local gphBottomCenter = gphBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gphBottomCenter:SetPoint("CENTER", gphBottomBar, "CENTER", 0, 0)
    gphBottomCenter:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    local gphBottomRight = gphBottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gphBottomRight:SetPoint("RIGHT", gphBottomBar, "RIGHT", -6, 0)
    gphBottomRight:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    f.gphBottomBar = gphBottomBar
    f.gphBottomLeft = gphBottomLeft
    f.gphBottomCenter = gphBottomCenter
    f.gphBottomRight = gphBottomRight

    -- Invisible overlay button for gold hover/tooltip
    local gphGoldButton = CreateFrame("Button", nil, gphBottomBar)
    gphGoldButton:SetPoint("TOPLEFT", gphBottomRight, "TOPLEFT", -6, 4)
    gphGoldButton:SetPoint("BOTTOMRIGHT", gphBottomRight, "BOTTOMRIGHT", 6, -4)
    gphGoldButton:EnableMouse(true)
    gphGoldButton:RegisterForClicks("LeftButtonUp")
    
    local function Gold_OnEnter(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT", 0, 20)
        GameTooltip:ClearLines()
        
        -- 1. Session Info
        GameTooltip:AddLine("Session:", 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Earned:", A.FormatGold(sessionEarned or 0), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Spent:", A.FormatGold(sessionSpent or 0), 1, 1, 1, 1, 1, 1)
        
        local diff = (sessionEarned or 0) - (sessionSpent or 0)
        if diff > 0 then
            GameTooltip:AddDoubleLine("Profit:", A.FormatGold(diff), 0, 1, 0, 1, 1, 1)
        elseif diff < 0 then
            GameTooltip:AddDoubleLine("Deficit:", A.FormatGold(-diff), 1, 0, 0, 1, 1, 1)
        end
        
        -- 2. Character Info (sorted descending by gold amount)
        local db = _G.InstanceTrackerDB
        local currentRealm = (GetRealmName and GetRealmName()) or ""
        local characters = {}
        local serverTotal = 0
        
        local myName = (UnitName and UnitName("player")) or ""
        local myKey = currentRealm .. "#" .. myName
        local _, myClass = UnitClass("player")
        if myClass and _G.FugaziBAGSDB then
            _G.FugaziBAGSDB.charClasses = _G.FugaziBAGSDB.charClasses or {}
            _G.FugaziBAGSDB.charClasses[myKey] = myClass
        end
        
        if db and db.accountGold then
            for key, copper in pairs(db.accountGold) do
                local realm, name = key:match("^(.-)#(.-)$")
                if realm == currentRealm and name then
                    serverTotal = serverTotal + copper
                    local class = _G.FugaziBAGSDB and _G.FugaziBAGSDB.charClasses and _G.FugaziBAGSDB.charClasses[key]
                    if not class and _G.ElvDB and _G.ElvDB.class and _G.ElvDB.class[currentRealm] then
                        class = _G.ElvDB.class[currentRealm][name]
                    end
                    table.insert(characters, {
                        name = name,
                        amount = copper,
                        class = class,
                        isCurrent = (name == myName)
                    })
                end
            end
        else
            local copper = GetMoney() or 0
            serverTotal = copper
            table.insert(characters, {
                name = myName,
                amount = copper,
                class = myClass,
                isCurrent = true
            })
        end
        
        table.sort(characters, function(a, b) return a.amount > b.amount end)
        
        if #characters > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Character:", 1, 0.82, 0)
            
            for _, char in ipairs(characters) do
                local color = char.class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[char.class] or { r = 1, g = 1, b = 1 }
                local nameText = char.name
                if char.isCurrent then
                    nameText = char.name .. " |TInterface\\FriendsFrame\\StatusIcon-Online:14|t"
                end
                GameTooltip:AddDoubleLine(nameText, A.FormatGold(char.amount), color.r, color.g, color.b, 1, 1, 1)
            end
        end
        
        -- 3. Server Info
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Server:", 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Total:", A.FormatGold(serverTotal), 1, 1, 1, 1, 1, 1)
        
        GameTooltip:Show()
    end
    
    gphGoldButton:SetScript("OnEnter", Gold_OnEnter)
    gphGoldButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    gphGoldButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and IsShiftKeyDown() then
            sessionEarned = 0
            sessionSpent = 0
            Gold_OnEnter(self)
            if PlaySound then PlaySound("igMainMenuOption") end
        end
    end)
    f.gphGoldButton = gphGoldButton


    -- New: Bag Row for List Mode (Matching Bank style)
    local bagRow = CreateFrame("Frame", nil, f)
    bagRow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 24)
    bagRow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 24)
    bagRow:SetHeight(0)
    bagRow:SetAlpha(0)
    bagRow:Hide()
    f.bagRow = bagRow
    f.bagRowVisible = false
    f.bagSlots = {}

    local bagIDs = { 0, 1, 2, 3, 4, -2 }
    for i, bagID in ipairs(bagIDs) do
        local btn = A.CreateBagBarButton(bagRow, ("FugaziInvBag%d"):format(i), bagID, function(self, button)
            if A.PlayClickSound then A.PlayClickSound() end
            if self.bagID == -2 then
                if f.ToggleKeyringFrame then f:ToggleKeyringFrame()
                elseif ToggleKeyRing then ToggleKeyRing() end
            else
                local cursorType = GetCursorInfo and GetCursorInfo()
                if cursorType == "item" and PutItemInBag and ContainerIDToInventoryID and self.bagID then
                    local invID = ContainerIDToInventoryID(self.bagID)
                    if invID and invID > 0 then PutItemInBag(invID) end
                elseif not cursorType or cursorType == "" then
                    local invID = self.bagID > 0 and ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
                    if invID and invID > 0 and PickupInventoryItem then
                        PickupInventoryItem(invID)
                    end
                end
            end
            if A.RefreshGPHBagRow then A.RefreshGPHBagRow(f) end
        end)
        btn:SetPoint("LEFT", bagRow, "LEFT", (i - 1) * 24, 0)
        f.bagSlots[i] = btn
    end

    function A.RefreshGPHBagRow(bf)
        if not bf.bagSlots then return end
        for i, btn in ipairs(bf.bagSlots) do
            local bagID = btn.bagID
            if bagID == -2 then
                -- Keyring
                btn.icon:SetTexture("Interface\\ContainerFrame\\KeyRing-AbilityIcon")
                btn.icon:Show()
            else
                local texture = (bagID == 0) and "Interface\\Buttons\\Button-Backpack-Up" or (GetInventoryItemTexture and GetInventoryItemTexture("player", ContainerIDToInventoryID(bagID)))
                if texture then
                    btn.icon:SetTexture(texture)
                    btn.icon:Show()
                else
                    btn.icon:Hide()
                end
            end
        end
    end

    local scrollFrame = CreateFrame("ScrollFrame", "InstanceTrackerGPHScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", gphHeader, "BOTTOMLEFT", 0, -14) 
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 20)
    f.scrollFrame = scrollFrame
    if Skins and Skins.SkinScrollBar then Skins.SkinScrollBar(scrollFrame) end
    f.gphScrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]

    local function gphDoScroll(sf, delta)
        local c = sf:GetScrollChild()
        if not c then return end
        local cur = f.gphScrollOffset or 0
        local viewHeight = sf:GetHeight()
        local contentHeight = c:GetHeight()
        local maxScroll = math.max(0, contentHeight - viewHeight)
        local step = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphScrollStep) or 600
        local newScroll = (delta < 0) and math.min(maxScroll, cur + step) or math.max(0, cur - step)
        f.gphScrollOffset = newScroll
        if f.gphScrollBar then
            f.gphScrollBar:SetMinMaxValues(0, maxScroll)
            f.gphScrollBar:SetValue(newScroll)
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, newScroll)
    end
    scrollFrame:SetScript("OnMouseWheel", function(self, delta) gphDoScroll(self, delta) end)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(SCROLL_CONTENT_WIDTH)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)
    f.content = content
    content:SetScript("OnMouseWheel", function(self, delta) gphDoScroll(self:GetParent(), delta) end)

    f.NegotiateSizes = function(self) A.NegotiateSizes(self) end
    f.MasterUpdate = function(now, elapsed)
        if not f:IsShown() then return end
        f._throttleT = (f._throttleT or 0) + elapsed
        if f._throttleT >= 0.05 then
            f._throttleT = 0
            if not f._isDragging and not InCombatLockdown() then f:NegotiateSizes() end
            if f.gphBagSpaceBtn then
                local hasItem = (GetCursorInfo and GetCursorInfo() == "item")
                if f.gphBagSpaceBtn.glow then if hasItem then f.gphBagSpaceBtn.glow:Show() else f.gphBagSpaceBtn.glow:Hide() end end
            end
        end
        gph_elapsed = (f._gph_elapsed or 0) + elapsed
        if gph_elapsed >= 0.5 then
            f._gph_elapsed = 0
            if f.gphBottomLeft then
                local fps = (GetFramerate and GetFramerate()) or 0
                f.gphBottomLeft:SetText(("%.0f FPS"):format(fps))
                if date then f.gphBottomCenter:SetText(date("%H:%M")) end
                f.gphBottomRight:SetText(GetMoney and A.FormatGold(GetMoney()) or "")
            end
        else
            f._gph_elapsed = gph_elapsed
        end
    end
    if A.RegisteredUpdaters then A.RegisteredUpdaters["ListviewState"] = f.MasterUpdate end
    
    f:UpdateGPHButtonVisibility()
    f:RefreshBagLayout()
    if f.UpdateGPHProfessionButtons then f:UpdateGPHProfessionButtons() end
    
    return f
end


--- Update visibility of top bar buttons (Destroy/Mail).
function A.UpdateGPHProfessionButtons(f)
    if not f then return end
    local titleBar = f.gphTitleBar
    if not titleBar then return end
    local hideDestroy = A.GetPerChar("gphHideDestroyBtn", false)
    local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    local isAtMail = (_G.MailFrame and _G.MailFrame:IsShown())
    local canDestroy = (hasDE or hasProspect)
    if InCombatLockdown() then return end
    local lastBtn = nil
    local anchorToLeft = true
    if f.gphDestroyBtn then
        if not hideDestroy and canDestroy then
            f.gphDestroyBtn:ClearAllPoints()
            f.gphDestroyBtn:SetPoint("LEFT", titleBar, "LEFT", 4, 0)
            f.gphDestroyBtn:Show()
            lastBtn = f.gphDestroyBtn
            anchorToLeft = false
            if f.UpdateDestroyButtonAppearance then f:UpdateDestroyButtonAppearance() end
        else
            f.gphDestroyBtn:Hide()
            anchorToLeft = true
        end
    end
    if f.gphMailBtn then
        if isAtMail then
            f.gphMailBtn:ClearAllPoints()
            if anchorToLeft then f.gphMailBtn:SetPoint("LEFT", titleBar, "LEFT", 4, 0) 
            else f.gphMailBtn:SetPoint("LEFT", lastBtn, "RIGHT", 4, 0) end
            f.gphMailBtn:SetAlpha(1)
            f.gphMailBtn:Show()
        else
            f.gphMailBtn:Hide()
        end
    end
end

-------------------------------------------------------------------------------
-- Rarity Visuals & Pulsing
-------------------------------------------------------------------------------

--- Shared Visual Update for Rarity Buttons (Inventory + Bank).
function A.UpdateRarityButtonState(btn, now, elapsed)
    if not btn then return end
    local q = btn.quality
    
    local active = A.continuousDelActive and A.continuousDelActive[q]
    local contStage = A.continuousDelStage and A.continuousDelStage[q]
    local burstStage = A.rarityDelStage and A.rarityDelStage[q]
    local isPending = A.pendingQuality and A.pendingQuality[q]
    local isProtected = not btn.noProtection and A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()[q]

    if active then
        -- FULL PULSE (Deleting...)
        local pulse = 0.5 + 0.5 * math.sin(now * 5)
        if btn.labelFs then
            local path, size = A.GetCategoryHeaderFontAndSize()
            btn.labelFs:SetFont(path or "Fonts\\FRIZQT__.TTF", (size or 11) - 2, "")
            btn.labelFs:SetText("|cffb27272Deleting...|r")
            btn.labelFs:SetAlpha(pulse)
        end
        if btn.bg then btn.bg:SetVertexColor(1, 0, 0, 0.8) end
    elseif (contStage and (contStage.clicks or 0) >= 1) or (burstStage and (burstStage.clicks or burstStage.stage or 0) >= 1) or isPending then
        -- FLASH & FADE (Stage 1 & 2)
        local stageObj = contStage or burstStage
        local clicks = stageObj and (stageObj.clicks or stageObj.stage) or 1
        local startTime = stageObj and stageObj.time or 0
        local e = now - startTime
        local duration = 1.0 
        
        if e < duration then
            local intensity = (1 - (e / duration))
            if btn.bg then
                if clicks == 1 then
                    btn.bg:SetVertexColor(1, 1, 1, 0.45 + (0.5 * intensity))
                elseif clicks == 2 then
                    local r, g, b = 1, 0.5 * (1-intensity), 0.5 * (1-intensity)
                    btn.bg:SetVertexColor(r, g, b, 0.35 + (0.6 * intensity))
                else
                    btn.bg:SetVertexColor(1, 0, 0, 0.35 + (0.65 * intensity))
                end
            end
            if btn.labelFs then
                local path, size = A.GetCategoryHeaderFontAndSize()
                btn.labelFs:SetFont(path or "Fonts\\FRIZQT__.TTF", (size or 11) - 2, "")
                btn.labelFs:SetText("|cffb27272DEL|r")
                btn.labelFs:SetAlpha(1)
            end
        else
            -- Cleanup timed out stages
            if contStage and (now - contStage.time) > 1.2 then A.continuousDelStage[q] = nil end
            if burstStage and (now - burstStage.time) > 1.2 then A.rarityDelStage[q] = nil end
            local f = btn:GetParent():GetParent()
            local filter = f and (f.gphFilterQuality or f.bankRarityFilter)
            A.UpdateRarityBtnVisual(f, btn, q, filter)
        end
    else
        -- Standard States (Restore font/color)
        if btn.labelFs then
            btn.labelFs:SetFont("Fonts\\FRIZQT__.TTF", 8, "") 
        end
        -- Standard States (Show on hover, filter, or protect)
        local f = btn:GetParent():GetParent()
        local filter = f and (f.gphFilterQuality or f.bankRarityFilter)
        local isHovered = btn._isHovered
        if btn.labelFs then
            if isHovered or (filter == q) or isProtected then
                btn.labelFs:SetAlpha(1)
            else
                btn.labelFs:SetAlpha(0)
            end
        end
        -- Protection Border & Background Pulse
        if isProtected then
            local pulse = 0.45 + 0.35 * math.sin(now * 4) 
            local bPulse = 0.2 + 0.5 * math.sin(now * 4) 
            
            if btn.bg then
                local info = (A.QUALITY_COLORS and A.QUALITY_COLORS[q]) or { r = 0.5, g = 0.5, b = 0.5 }
                local r, g, b = info.r or 0.5, info.g or 0.5, info.b or 0.5
                if q == 0 then r, g, b = 0.58, 0.58, 0.58 elseif q == 1 then r, g, b = 1, 1, 1 end
                
                if filter == q then
                    r, g, b = math.min(1, r * 1.6), math.min(1, g * 1.6), math.min(1, b * 1.6)
                    pulse = pulse + 0.15
                end
                btn.bg:SetVertexColor(r, g, b, pulse)
            end

            if btn.rarityBorderTop then
                btn.rarityBorderTop:SetVertexColor(1, 1, 1, bPulse)
                btn.rarityBorderBottom:SetVertexColor(1, 1, 1, bPulse)
                btn.rarityBorderLeft:SetVertexColor(1, 1, 1, bPulse)
                btn.rarityBorderRight:SetVertexColor(1, 1, 1, bPulse)
            end
        elseif btn.rarityBorderTop then
            btn.rarityBorderTop:SetVertexColor(1, 1, 1, 0.4)
            btn.rarityBorderBottom:SetVertexColor(1, 1, 1, 0.4)
            btn.rarityBorderLeft:SetVertexColor(1, 1, 1, 0.4)
            btn.rarityBorderRight:SetVertexColor(1, 1, 1, 0.4)
            if btn.bg then
                local info = (A.QUALITY_COLORS and A.QUALITY_COLORS[q]) or { r = 0.5, g = 0.5, b = 0.5 }
                btn.bg:SetVertexColor(info.r or 0.5, info.g or 0.5, info.b or 0.5, 0.4)
            end
        end
        
        -- Restore original text if label visible
        if btn.labelFs and btn.labelFs:GetAlpha() > 0 then
            local count = btn.currentCount or 0
            btn.labelFs:SetText(count > 0 and count or "")
        end
    end

    if A._rarityDragInitiated and IsAltKeyDown() and not IsControlKeyDown() and IsMouseButtonDown("LeftButton") and MouseIsOver(btn) then
        local flags = A.GetGphProtectedRarityFlags and A.GetGphProtectedRarityFlags()
        if flags and flags[btn.quality] ~= A._rarityDragValue then
            if A.GPH_SetRarityProtection then A.GPH_SetRarityProtection(btn.quality, A._rarityDragValue) end
            if _G.RefreshGPHUI then _G.RefreshGPHUI() end
            if btn.isBankBtn and _G.RefreshBankUI then _G.RefreshBankUI() end
        end
    end
    if A._rarityDragInitiated and (not IsAltKeyDown() or not IsMouseButtonDown("LeftButton")) then A._rarityDragInitiated = nil end
end

--- Update all rarity buttons in both Inventory and Bank frames.
function A.UpdateAllRarityVisuals(now, elapsed)
    local gph = A.Inventory
    if gph and gph:IsShown() and gph.qualityButtons then
        for q, btn in pairs(gph.qualityButtons) do
            A.UpdateRarityButtonState(btn, now, elapsed)
        end
    end
    local bank = A.Bank
    if bank and bank:IsShown() and bank.qualityButtons then
        for q, btn in pairs(bank.qualityButtons) do
            A.UpdateRarityButtonState(btn, now, elapsed)
        end
    end
end

-- Register Master Updater
A.RegisteredUpdaters = A.RegisteredUpdaters or {}
A.RegisteredUpdaters["RarityPulse"] = A.UpdateAllRarityVisuals
