local addonName, Addon = ...
local A = Addon
local DB = _G.FugaziBAGSDB or {}

--- Like /dump but only when debugClicks is on.
local function DebugClick(msg)
    local SV = _G.FugaziBAGSDB
    if not (SV and SV.debugClicks) then return end
end
A.DebugClick = DebugClick

local _secBtnCounter = 0
A._gphSelectionDeferFrame = CreateFrame("Frame", nil, UIParent)
A._gphSelectionDeferFrame:Hide()

local function deferSecureNextFrame(clickArea, scriptName)
    if not clickArea:GetScript(scriptName) then return end
    A._gphSecureDeferQueue = A._gphSecureDeferQueue or {}
    table.insert(A._gphSecureDeferQueue, { 
        clickArea = clickArea, 
        scriptName = scriptName,
        isCleaning = A._gphIsCleaning -- Capture the guard state at the exact moment of the event
    })
    if not A._gphSecureDeferFrame then A._gphSecureDeferFrame = CreateFrame("Frame") end
    local d = A._gphSecureDeferFrame
    d:SetScript("OnUpdate", function(self)
        local q = A._gphSecureDeferQueue
        if not q or #q == 0 then self:SetScript("OnUpdate", nil); self:Hide(); return end
        for i = 1, #q do
            local e = q[i]
            if e and e.clickArea and e.scriptName then
                -- Synchronize the cleaning guard for the deferred script execution
                if e.isCleaning then e.clickArea._isGPHCleaning = true end
                
                local f = e.clickArea:GetScript(e.scriptName)
                if f then f(e.clickArea) end
                
                if e.isCleaning then e.clickArea._isGPHCleaning = nil end
            end
        end
        wipe(q)
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end)
    d:Show()
end

--- Secure bag-slot button (works in combat, Alt/Ctrl clicks).
local function EnsureSecureRowBtn(clickArea, bag, slot)
    local par = clickArea._fugaziSecPar
    local btn = clickArea._fugaziSecBtn
    local modOverlay = clickArea._fugaziModifierOverlay

    -- 1. If we already have the frames, just update them and RETURN
    if par and btn then
        par:SetID(bag)
        btn:SetID(slot)
        
        -- Identity mirroring (for tooltips/hovers)
        par.bag = bag; par.slot = slot
        btn.bag = bag; btn.slot = slot
        if modOverlay then modOverlay.bag = bag; modOverlay.slot = slot end
        
        -- Update visibility/state if needed
        par:Show()
        btn:Show()
        
        -- Ensure children are synced if they exist
        if modOverlay then modOverlay:SetParent(par); modOverlay:SetAllPoints(par) end
        
        local isAtVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
        local isProt = false
        if isAtVendor and A.IsItemProtectedAPI then
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            if itemId and A.IsItemProtectedAPI(itemId) then
                isProt = true
            end
        end
        if not InCombatLockdown() then
            if isAtVendor and isProt then
                btn:RegisterForClicks("LeftButtonUp")
            else
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end
        end

        return
    end

    -- 2. First-time creation only
    if InCombatLockdown and InCombatLockdown() then return end

    par = CreateFrame("Frame", nil, clickArea)
    par:SetID(bag)
    par:SetAllPoints(clickArea)
    par:SetFrameLevel((clickArea:GetFrameLevel() or 1) + 1)
    
    btn = CreateFrame("Button", nil, par, "ContainerFrameItemButtonTemplate")
    btn:SetID(slot)
    btn:SetAlpha(0)
    btn:SetAllPoints(par)
    
    -- Identity mirroring
    par.bag = bag; par.slot = slot
    btn.bag = bag; btn.slot = slot
    
    btn:SetFrameLevel((par:GetFrameLevel() or 1) + 1)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if ContainerFrameItemButton_OnLoad then ContainerFrameItemButton_OnLoad(btn) end
    
    if btn.SetPropagateMouseClicks then btn:SetPropagateMouseClicks(false) end
    if par.SetPropagateMouseClicks then par:SetPropagateMouseClicks(false) end

    btn:SetScript("OnEnter", function(self) A.HandleBagSlotEnter(clickArea) end)
    btn:SetScript("OnLeave", function(self) A.HandleBagSlotLeave(clickArea) end)
    btn:HookScript("OnMouseDown", function(self, mouseButton)
        if Addon and A.TriggerRowPulse then A.TriggerRowPulse(clickArea:GetParent()) end
    end)

    local function forwardMouseWheel(_, delta)
    local bf = A.Bank
    local gph = A.Inventory
        if bf and bf:IsShown() and bf.scrollFrame and bf.scrollFrame.BankOnMouseWheel then
            bf.scrollFrame.BankOnMouseWheel(delta)
        elseif gph and gph.scrollFrame and gph.scrollFrame.GPHOnMouseWheel then
            gph.scrollFrame.GPHOnMouseWheel(delta)
        end
    end
    btn:SetScript("OnMouseWheel", forwardMouseWheel)
    
    modOverlay = CreateFrame("Button", nil, par)
    modOverlay:SetAllPoints(par)
    modOverlay:SetFrameStrata(par:GetFrameStrata() or "MEDIUM")
    modOverlay:SetFrameLevel((par:GetFrameLevel() or 1) + 6)
    if modOverlay.SetPropagateMouseClicks then modOverlay:SetPropagateMouseClicks(false) end
    modOverlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    modOverlay:EnableMouse(false)
    modOverlay:Hide()
    modOverlay._gphDebugName = "SecureModifierOverlay"
    modOverlay._clickArea = clickArea
    modOverlay:SetScript("OnMouseWheel", forwardMouseWheel)
    
    modOverlay:SetScript("OnMouseDown", function(self, mouseButton)
        if Addon and A.TriggerRowPulse then A.TriggerRowPulse(clickArea:GetParent()) end
    end)
    modOverlay:SetScript("OnEnter", function(self)
        local ca = self._clickArea
        if ca then A.HandleBagSlotEnter(ca) end
    end)
    modOverlay:SetScript("OnLeave", function(self)
        local ca = self._clickArea
        if ca then A.HandleBagSlotLeave(ca) end
    end)
    modOverlay:SetScript("OnClick", function(self, button)
        local parentPar = self:GetParent()
        local b, s = parentPar:GetID(), (self._clickArea._fugaziSecBtn and self._clickArea._fugaziSecBtn:GetID()) or nil
        if not s and self._clickArea.GetID then s = self._clickArea:GetID() end
        
        -- Fallback for ListMode (Pool frames use properties instead of IDs)
        if (not b or b == 0) and (not s or s == 0) then
            local ca = self._clickArea
            b = ca.bag or ca.bagID or (ca.cachedItem and ca.cachedItem.bag)
            s = ca.slot or ca.slotID or (ca.cachedItem and ca.cachedItem.slot)
        end
        
        local altDown = IsAltKeyDown and IsAltKeyDown()
        local ctrlDown = IsControlKeyDown and IsControlKeyDown()
        local shiftDown = IsShiftKeyDown and IsShiftKeyDown()

        local isProtectClick = (altDown and not ctrlDown and button == "LeftButton")
        local isDestroyClick = (ctrlDown and not altDown and button == "RightButton")

        if isProtectClick or isDestroyClick then
            -- 1. Handle GridView specific logic if in GridMode
            local gf = A.Inventory
            if gf and gf.gphGridMode and _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.HandleModifierClick then
                 _G.FugaziBAGS_CombatGrid.HandleModifierClick(self._clickArea, button, b, s, altDown, ctrlDown)
                 return
            end

            -- 2. Use Unified Action Handler for everything else (Listview/Bank)
            if A.HandleModifierAction then
                A.HandleModifierAction(self._clickArea, button, b, s, altDown, ctrlDown, shiftDown)
            end
        else
            -- Forward default WoW modified click (DressUp/Chat link)
            local link = GetContainerItemLink(b, s)
            if link then
                HandleModifiedItemClick(link)
            end
        end
    end)

    clickArea._fugaziSecBtn = btn
    clickArea._fugaziSecPar = par
    clickArea._fugaziModifierOverlay = modOverlay
    
    local isAtVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
    local isProt = false
    if isAtVendor and A.IsItemProtectedAPI then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        local itemId = link and tonumber(link:match("item:(%d+)"))
        if itemId and A.IsItemProtectedAPI(itemId) then
            isProt = true
        end
    end
    if not InCombatLockdown() then
        if isAtVendor and isProt then
            btn:RegisterForClicks("LeftButtonUp")
        else
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
    end

    par:Show()
    btn:Show()
end
_G.FugaziBAGS_EnsureSecureRowBtn = EnsureSecureRowBtn
A.EnsureSecureRowBtn = EnsureSecureRowBtn

--- Window Toggling (Centralized)
function A.ToggleGPHFrame()
    local gphFrame = A.Inventory
    if not gphFrame then gphFrame = A.CreateGPHFrame() end
    local container = (gphFrame and gphFrame.gphInventoryContainer) or (A.Inventory and A.Inventory.gphInventoryContainer)
    if container then
        if container:IsShown() then
            if gphFrame:IsShown() then A.SaveFrameLayout(gphFrame, "gphShown", "gphPoint") end
            gphFrame.gphSelectedRowBtn = nil
            gphFrame.gphSelectedItemId = nil
            gphFrame.gphSelectedItemLink = nil
            container:Hide()
        else
            local SV = _G.FugaziBAGSDB
            if not (SV and SV.gphPoint and SV.gphPoint.point) then
                gphFrame:ClearAllPoints()
                gphFrame:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
            end
            local base = (SV and SV.gphScale15) and 1.5 or 1
            local extra = (SV and SV.gphFrameScale) or 1
            gphFrame:SetScale(base * extra)
            if gphFrame.gphDestroyBtn then gphFrame.gphDestroyBtn:SetScale(base * extra) end
            A.ApplyFrameAlpha(gphFrame)
            if gphFrame.ApplySkin then gphFrame.ApplySkin() end
            gphFrame.gphSelectedItemId = nil
            gphFrame.gphSelectedIndex = nil
            gphFrame.gphSelectedRowBtn = nil
            gphFrame.gphSelectedItemLink = nil
            gphFrame.gphScrollToDefaultOnNextRefresh = true
            container:Show()
            if gphFrame then gphFrame._refreshImmediate = true end
            if A.RefreshGPHUI then A.RefreshGPHUI() end
            if gphFrame and gphFrame.RefreshBagLayout and not gphFrame.gphGridMode then gphFrame:RefreshBagLayout() end
            if gphFrame:IsShown() then A.SaveFrameLayout(gphFrame, "gphShown", "gphPoint") end
        end
    else
        if gphFrame:IsShown() then
            A.SaveFrameLayout(gphFrame, "gphShown", "gphPoint")
            gphFrame:Hide()
            gphFrame.gphSelectedRowBtn = nil
            gphFrame.gphSelectedItemId = nil
            gphFrame.gphSelectedItemLink = nil
        else
            local SV = _G.FugaziBAGSDB
            if not (SV and SV.gphPoint and SV.gphPoint.point) then
                gphFrame:ClearAllPoints()
                gphFrame:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
            end
            local base = (SV and SV.gphScale15) and 1.5 or 1
            local extra = (SV and SV.gphFrameScale) or 1
            gphFrame:SetScale(base * extra)
            if gphFrame.gphDestroyBtn then gphFrame.gphDestroyBtn:SetScale(base * extra) end
            A.ApplyFrameAlpha(gphFrame)
            if gphFrame.ApplySkin then gphFrame.ApplySkin() end
            gphFrame.gphSelectedItemId = nil
            gphFrame.gphSelectedIndex = nil
            gphFrame.gphSelectedRowBtn = nil
            gphFrame.gphSelectedItemLink = nil
            gphFrame:Show()
            if gphFrame then gphFrame._refreshImmediate = true end 
            if A.RefreshGPHUI then A.RefreshGPHUI() end
            A.SaveFrameLayout(gphFrame, "gphShown", "gphPoint")
        end
    end
end
_G.ToggleGPHFrame = A.ToggleGPHFrame

function A.ToggleBankFrame()
    if _G.BankFrame and _G.BankFrame:IsShown() then
        _G.CloseBankFrame()
    else
        _G.ToggleBag(0) -- Triggers BANK_FRAME_OPENED
    end
end
_G.ToggleBankFrame = A.ToggleBankFrame

function A.ToggleGridFrame()
    local gph = A.Inventory
    if not gph then return end
    gph.gphGridMode = not gph.gphGridMode
    A.SetPerChar("gphGridMode", gph.gphGridMode)
    if A.RefreshGPHUI then A.RefreshGPHUI() end
end
_G.ToggleGridFrame = A.ToggleGridFrame

--- Register a secure frame toggle (standardized attributes)
function A.RegisterSecureFrameToggle(btn, targetFrame)
    if not btn or not targetFrame then return end
    btn:Execute(string.format([[
        local f = self:GetFrameRef("target")
        if f then f:SetAttribute("state", "toggle") end
    ]]))
    btn:SetFrameRef("target", targetFrame)
end

--- Bag Key Overrides & Hooks
function A.ApplyBagKeyOverrides(secureToggle)
    if InCombatLockdown() then return end
    if not secureToggle then return end
    ClearOverrideBindings(secureToggle)
    local key1, key2 = GetBindingKey("TOGGLEBACKPACK")
    if key1 then SetOverrideBindingClick(secureToggle, false, key1, secureToggle:GetName()) end
    if key2 then SetOverrideBindingClick(secureToggle, false, key2, secureToggle:GetName()) end
    
    local ok1, ok2 = GetBindingKey("OPENALLBAGS")
    if ok1 then SetOverrideBindingClick(secureToggle, false, ok1, secureToggle:GetName()) end
    if ok2 then SetOverrideBindingClick(secureToggle, false, ok2, secureToggle:GetName()) end
end

local origToggleBackpack, origOpenAllBags

local function GPHInvBagKeyHandler()
    local atVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
    local atMailbox = _G.MailFrame and _G.MailFrame:IsShown()
    local npcTime = _G.gphNpcDialogTime
    local atNpcRecently = npcTime and (GetTime() - npcTime) < 1.5
    
    if atVendor or atMailbox or atNpcRecently then
        if CloseAllBags then CloseAllBags() end
        local gf = A.Inventory
        if gf and not gf:IsShown() then
            gf:Show()
            if A.SaveFrameLayout then A.SaveFrameLayout(gf, "gphShown", "gphPoint") end
            if _G.RefreshGPHUI then _G.RefreshGPHUI() end
        end
        return
    end
    if A.ToggleGPHFrame then A.ToggleGPHFrame() end
    if CloseAllBags then CloseAllBags() end
end

function A.InstallGPHInvHook()
    local DB = _G.FugaziBAGSDB
    if not DB or not DB.gphInvKeybind then return end
    if not origToggleBackpack and _G.ToggleBackpack then origToggleBackpack = _G.ToggleBackpack end
    if not origOpenAllBags and _G.OpenAllBags then origOpenAllBags = _G.OpenAllBags end
    if origToggleBackpack then _G.ToggleBackpack = GPHInvBagKeyHandler end
    if origOpenAllBags then _G.OpenAllBags = GPHInvBagKeyHandler end
end

function A.RemoveGPHInvHook()
    if origToggleBackpack then _G.ToggleBackpack = origToggleBackpack end
    if origOpenAllBags then _G.OpenAllBags = origOpenAllBags end
end
