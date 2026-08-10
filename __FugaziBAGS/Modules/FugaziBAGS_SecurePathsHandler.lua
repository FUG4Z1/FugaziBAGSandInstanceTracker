local addonName, Addon = ...
local A = Addon
local DB = _G.FugaziBAGSDB or {}

local _secBtnCounter = 0
A._gphSelectionDeferFrame = CreateFrame("Frame", nil, UIParent)
A._gphSelectionDeferFrame:Hide()

local function deferSecureNextFrame(clickArea, scriptName)
    if not clickArea:GetScript(scriptName) then return end
    A._gphSecureDeferQueue = A._gphSecureDeferQueue or {}
    table.insert(A._gphSecureDeferQueue, { clickArea = clickArea, scriptName = scriptName })
    if not A._gphSecureDeferFrame then A._gphSecureDeferFrame = CreateFrame("Frame") end
    local d = A._gphSecureDeferFrame
    d:SetScript("OnUpdate", function(self)
        local q = A._gphSecureDeferQueue
        if not q or #q == 0 then self:SetScript("OnUpdate", nil); self:Hide(); return end
        for i = 1, #q do
            local e = q[i]
            if e and e.clickArea and e.scriptName then
                local f = e.clickArea:GetScript(e.scriptName)
                if f then f(e.clickArea) end
            end
        end
        wipe(q)
        self:SetScript("OnUpdate", nil)
        self:Hide()
    end)
    d:Show()
end

--- Expected item for this secure click: list row cache first, else live bag/slot id.
local function SyncSecureExpectedItemId(btn, clickArea, bag, slot)
    if not btn then return end
    local row = clickArea and clickArea.GetParent and clickArea:GetParent()
    local fromRow = row and row.cachedItemId
    if fromRow then
        btn._expectedItemId = fromRow
    elseif GetContainerItemID and bag ~= nil and slot ~= nil then
        btn._expectedItemId = GetContainerItemID(bag, slot)
    else
        btn._expectedItemId = nil
    end
end

--- Secure bag-slot button (works in combat, Alt/Ctrl clicks).
local function EnsureSecureRowBtn(clickArea, bag, slot)
    local par = clickArea._fugaziSecPar
    local btn = clickArea._fugaziSecBtn
    local modOverlay = clickArea._fugaziModifierOverlay
    local inCombat = InCombatLockdown and InCombatLockdown()

    -- 1. If we already have the frames, just update them and RETURN
    if par and btn then
        -- SetID / Show / Hide on ContainerFrameItemButton are protected in combat.
        if not inCombat then
            if par:GetID() ~= bag then par:SetID(bag) end
            if btn:GetID() ~= slot then btn:SetID(slot) end
            if not par:IsShown() then par:Show() end
            if not btn:IsShown() then btn:Show() end
            -- Restore after a stale-click no-op (equip spam race).
            if btn._idRestore then
                btn:SetID(btn._idRestore)
                btn._idRestore = nil
            end
        end

        -- Identity mirroring (for tooltips/hovers) — always safe.
        par.bag = bag; par.slot = slot
        btn.bag = bag; btn.slot = slot
        if modOverlay then modOverlay.bag = bag; modOverlay.slot = slot end
        SyncSecureExpectedItemId(btn, clickArea, bag, slot)

        return
    end

    -- 2. First-time creation only
    if inCombat then return end

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
    SyncSecureExpectedItemId(btn, clickArea, bag, slot)
    
    btn:SetFrameLevel((par:GetFrameLevel() or 1) + 1)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if ContainerFrameItemButton_OnLoad then ContainerFrameItemButton_OnLoad(btn) end
    -- Template Count/Icon can flash one frame under the name before alpha sticks.
    if btn.Count then btn.Count:SetText(""); btn.Count:Hide() end
    if btn.IconTexture then btn.IconTexture:SetTexture(nil) end
    
    if btn.SetPropagateMouseClicks then btn:SetPropagateMouseClicks(false) end
    if par.SetPropagateMouseClicks then par:SetPropagateMouseClicks(false) end

    btn:SetScript("OnEnter", function(self) A.HandleBagSlotEnter(clickArea, false) end)
    -- Template OnUpdate may call UpdateTooltip; silent rebuild only.
    -- Keyring: no pulse (see Gridview MakeSlot — stacks protect lines otherwise).
    -- Owner is this secure button (see HandleBagSlotEnter) so IsOwned(self) stays true
    -- and empty-after-transfer slots re-hide the ghost tooltip.
    btn.UpdateTooltip = function(self)
        local bag = clickArea.bagID or clickArea.bag
        if bag == nil and A.GetBagSlotFromFrame then
            bag = A.GetBagSlotFromFrame(clickArea)
        end
        if bag == -2 or bag == (KEYRING_CONTAINER or -2) then
            return
        end
        A.HandleBagSlotEnter(clickArea, true)
    end
    btn:SetScript("OnLeave", function(self) A.HandleBagSlotLeave(clickArea) end)
    -- Equip spam race: click equips row item → old gear lands in same bag/slot →
    -- second click before row rebuild equips the old piece. Block when live id ≠ expected.
    btn:HookScript("PreClick", function(self, button)
        if InCombatLockdown and InCombatLockdown() then return end
        -- Live Alt/Ctrl only; sticky post-reload IsAltKeyDown must not skip equip guard forever.
        local alt = A.IsAltModifierLive and A.IsAltModifierLive()
        local ctrl = A.IsCtrlModifierLive and A.IsCtrlModifierLive()
        if alt or ctrl or (IsShiftKeyDown and IsShiftKeyDown()) then
            return
        end
        local expected = self._expectedItemId
        if not expected then
            local row = clickArea.GetParent and clickArea:GetParent()
            expected = (row and row.cachedItemId) or clickArea.cachedItemId
        end
        if not expected then return end
        local b = self:GetParent() and self:GetParent():GetID()
        local s = self:GetID()
        if b == nil or s == nil then return end
        local cur = GetContainerItemID and GetContainerItemID(b, s)
        if cur and cur ~= expected then
            -- Slot 0 is invalid (1-based) → template UseContainerItem becomes a no-op.
            self._idRestore = s
            self:SetID(0)
        end
    end)
    btn:HookScript("PostClick", function(self)
        if not self._idRestore then return end
        if not (InCombatLockdown and InCombatLockdown()) then
            self:SetID(self._idRestore)
        end
        self._idRestore = nil
    end)
    btn:HookScript("OnMouseDown", function(self, mouseButton)
        -- Skip on Alt/Ctrl: protect/destroy re-sorts list rows; pre-refresh pulse sticks to
        -- the wrong pool frame (shows on the item above after protect moves this one up).
        local alt = A.IsAltModifierLive and A.IsAltModifierLive()
        local ctrl = A.IsCtrlModifierLive and A.IsCtrlModifierLive()
        if alt or ctrl then
            return
        end
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
        
        -- Live modifiers only (see Actions.IsAltModifierLive) — ignore sticky IsAltKeyDown after /reload.
        local altDown = (A.IsAltModifierLive and A.IsAltModifierLive())
            or (not A.IsAltModifierLive and IsAltKeyDown and IsAltKeyDown())
        local ctrlDown = (A.IsCtrlModifierLive and A.IsCtrlModifierLive())
            or (not A.IsCtrlModifierLive and IsControlKeyDown and IsControlKeyDown())
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
    
    btn:HookScript("OnClick", function(self, button, down)
        if A.HandleBagSlotClick then
            A.HandleBagSlotClick(clickArea, button, down)
        end
    end)

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
    local SV = _G.FugaziBAGSDB
    local freeFloat = SV and SV.gphBankFreeFloat
    local bankOpen = A.Bank and A.Bank:IsShown()

    local function prepareShow()
        -- Scale BEFORE position restore (restore-then-scale teleports under gphScale15).
        local base = (SV and SV.gphScale15) and 1.5 or 1
        local extra = (SV and SV.gphFrameScale) or 1
        gphFrame:SetScale(base * extra)
        if gphFrame.gphDisenchantBtn then gphFrame.gphDisenchantBtn:SetScale(base * extra) end
        if gphFrame.gphProspectBtn then gphFrame.gphProspectBtn:SetScale(base * extra) end
        if gphFrame.gphMillingBtn then gphFrame.gphMillingBtn:SetScale(base * extra) end
        if gphFrame.gphOpenBtn then gphFrame.gphOpenBtn:SetScale(base * extra) end
        -- Restore free position; docked bank pair re-centers after show.
        local hasPt = SV and SV.gphPoint and (SV.gphPoint.x ~= nil and SV.gphPoint.y ~= nil)
        if A.RestoreFrameLayout and hasPt then
            A.RestoreFrameLayout(gphFrame, nil, "gphPoint")
        elseif not hasPt then
            gphFrame:ClearAllPoints()
            gphFrame:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
        end
        -- Alpha only if changed (no full skin bump every B).
        if A.ApplyFrameAlpha then A.ApplyFrameAlpha(gphFrame) end
        gphFrame.gphSelectedItemId = nil
        gphFrame.gphSelectedIndex = nil
        gphFrame.gphSelectedRowBtn = nil
        gphFrame.gphSelectedItemLink = nil
        gphFrame.gphScrollToDefaultOnNextRefresh = true
        gphFrame._refreshImmediate = true
    end

    local function afterShow()
        if not freeFloat and A.Bank and A.Bank:IsShown() and A.DockInventoryBankCentered then
            A.DockInventoryBankCentered()
        end
        -- Don't write dock coords into gphPoint while bank docked.
        if freeFloat or not (A.Bank and A.Bank:IsShown()) then
            if gphFrame:IsShown() and A.SaveFrameLayout then
                A.SaveFrameLayout(gphFrame, "gphShown", "gphPoint")
            end
        end
    end

    local function prepareHide()
        -- Save free position only when not temporarily docked for bank.
        if freeFloat or not bankOpen then
            if gphFrame:IsShown() and A.SaveFrameLayout then
                A.SaveFrameLayout(gphFrame, "gphShown", "gphPoint")
            end
        end
        gphFrame.gphSelectedRowBtn = nil
        gphFrame.gphSelectedItemId = nil
        gphFrame.gphSelectedItemLink = nil
    end

    if container then
        if container:IsShown() then
            prepareHide()
            container:Hide()
            if A.Bank and A.Bank:IsShown() then
                _G.CloseBankFrame()
            end
        else
            prepareShow()
            container:Show()
            if gphFrame and gphFrame.RefreshBagLayout and not gphFrame.gphGridMode then gphFrame:RefreshBagLayout() end
            afterShow()
        end
    else
        if gphFrame:IsShown() then
            prepareHide()
            gphFrame:Hide()
            if A.Bank and A.Bank:IsShown() then
                _G.CloseBankFrame()
            end
        else
            prepareShow()
            gphFrame:Show()
            afterShow()
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
