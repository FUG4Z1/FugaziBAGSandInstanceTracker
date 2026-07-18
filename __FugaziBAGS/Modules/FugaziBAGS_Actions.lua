local addonName, Addon = ...; Addon = Addon or _G.FugaziBAGS
local A = Addon
A.gphTooltipDebug = true -- Global Debug: Always on for session tracking

--[[
  FugaziBAGS_Actions: Unified handler for bag slot actions.
  Centralizes item protection, destruction (Modifier+Click), and bag events.
]]

-- FugaziBAGS Actions module
local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}


StaticPopupDialogs["GPH_DELETE_QUALITY"] = {
    text = "Delete all %d %s",
    button1 = "|cffff0000DELETE ALL|r",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data and data.quality then A.DeleteAllOfQuality(data.quality) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["GPH_CONTINUOUS_DELETE"] = {
    text = "Continuously delete all new |cffffff00%s|r items you pick up?",
    button1 = "|cff00ff00START|r",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data and data.quality then A.StartContinuousDelete(data.quality) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

--- Get Slot ID and Bag ID from a frame (e.g. clickArea or button).
--- Handles both Listview (bagID/slotID properties) and Gridview (GetID/GetParent:GetID).
function A.GetBagSlotFromFrame(frame)
    if not frame then return nil, nil end
    local bag, slot = nil, nil
    
    -- 1. RECURSIVE SEARCH: Look for identity properties on the frame or any of its parents (depth 4).
    -- This handles hovers on child elements like Icons or Overlays that steal focus.
    local curr = frame
    for i = 1, 4 do
        if not curr then break end
        bag = curr.bagID or curr.bag or curr._bankIdx or curr._bankBag
        slot = curr.slotID or curr.slot or curr._bankSlot
        if bag ~= nil and slot ~= nil then break end
        
        -- Fallback to cached item object if searching up
        local it = curr.cachedItem
        if it then
            bag = it.bag or it.bagID or it.firstBag
            slot = it.slot or it.slotID or it.firstSlot
            if bag ~= nil and slot ~= nil then break end
        end
        curr = curr:GetParent()
    end
    
    -- 2. Special case for Bank items (-1 or 5-11)
    if (bag == nil) and (frame._isBank) then
        bag = -1 
    end

    return bag, slot
end

--- Unified OnEnter handler for bag slots.
function A.HandleBagSlotEnter(frame, silent, hostWindow)
    local parent = frame.GetParent and frame:GetParent()
    local bag, slot = A.GetBagSlotFromFrame(frame)
    local it = frame.cachedItem or (parent and parent.cachedItem)
    
    local function getParentWindow(f)
        local curr = f
        for i=1,10 do
            if not curr then break end
            local name = curr:GetName() or ""
            if name == "InventoryMainFrame" or name == "BankMainFrame" then return curr end
            if curr == A.Inventory or curr == A.Bank then return curr end
            curr = curr:GetParent()
        end
        return nil
    end

    local bagA, slotA = tostring(frame.GetAttribute and frame:GetAttribute("bag") or "nil"), tostring(frame.GetAttribute and frame:GetAttribute("slot") or "nil")
    local bagP, slotP = tostring(frame.bagID or frame.bag or "nil"), tostring(frame.slotID or frame.slot or "nil")
    
    if bag == nil or slot == nil then return end 
    
    -- SSOT: Find the "Canonical Owner" (The clickArea) to prevent flickering between layers.
    local canonical = frame.clickArea or frame._clickArea or (parent and (parent.clickArea or parent._clickArea)) or frame
    
    -- Ensure canonical is actually visible/valid
    if not (canonical:GetRight() and canonical:GetRight() > 0) then canonical = frame end

    local isBank = (bag == -1 or bag >= 5) 
    
    -- AUTO-DETECT HOST: Find the window by climbing, fallback to global pointers.
    local host = hostWindow or getParentWindow(frame) or (isBank and A.Bank) or A.Inventory

    -- 1. STABLE POSITIONING: Anchor the tooltip to the canonical clickArea.
    A.AnchorTooltipSmart(canonical, isBank and "LEFT" or "RIGHT", host)

    -- 2. VISUALS (Highlight & Sounds)
    local wasHighlighted = canonical.bagHighlight and canonical.bagHighlight:IsShown()
    if canonical.bagHighlight then canonical.bagHighlight:Show() end
    if not silent and not wasHighlighted and A.PlayHoverSound then A.PlayHoverSound() end

    -- 2.1 MERCHANT CURSOR
    if _G.MerchantFrame and _G.MerchantFrame:IsShown() and not isBank then
        local fn = _G.ShowContainerSellCursor or (_G.C_Container and _G.C_Container.ShowContainerSellCursor)
        if fn then
            fn(bag, slot)
        end
    end

    -- 3. CONTENT UPDATE (Safe to call repeatedly, the shield handles the anchoring)
    if bag == -1 then
        local invSlot = (BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(slot)) or (38 + slot)
        GameTooltip:SetInventoryItem("player", invSlot)
    else
        GameTooltip:SetBagItem(bag, slot)
    end

    -- 4. PROTECTION INFO
    local link = GetContainerItemLink(bag, slot)
    local itemId = link and tonumber(link:match("item:(%d+)"))
    if itemId then
        local _, _, q = A.GetCachedItemInfo(link)
        q = q or 0
        local prot = A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, q)
        local isPrev = A.IsItemWorn and A.IsItemWorn(itemId) or false

        -- DYNAMIC SECURE VENDOR PROTECTION:
        -- Update the secure button's click bindings on the fly when we hover.
        -- If we are at a vendor and the item is protected, we securely disable RightButtonUp!
        local btn = canonical._fugaziSecBtn
        if btn and not InCombatLockdown() then
            if prot and _G.MerchantFrame and _G.MerchantFrame:IsShown() then
                btn:RegisterForClicks("LeftButtonUp")
            else
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end
        end

        if isPrev then
            GameTooltip:AddLine("Previously worn gear", 0.40, 0.80, 0.40)
            GameTooltip:AddLine("Alt+LMB: Unprotect", 0.80, 0.80, 0.80)
        elseif prot then
            GameTooltip:AddLine("Protected", 0.40, 0.80, 0.40)
            GameTooltip:AddLine("Alt+LMB: Unprotect", 0.80, 0.80, 0.80)
        else
            GameTooltip:AddLine("Unprotected", 1.00, 0.25, 0.25)
            GameTooltip:AddLine("Alt+LMB: Protect", 0.80, 0.80, 0.80)
        end
        GameTooltip:AddLine("Ctrl+RMB: Autodelete", 0.90, 0.60, 0.60)
        
        -- 4.1. Dynamic Modifier Overlay Activation (Harmonize with List Mode)
        local modOv = canonical._fugaziModifierOverlay
        local altDown = IsAltKeyDown()
        local ctrlDown = IsControlKeyDown()
        if modOv then
            if (altDown or ctrlDown) and not (altDown and ctrlDown) then
                modOv:Show()
                modOv:EnableMouse(true)
            else
                modOv:Hide()
                modOv:EnableMouse(false)
            end
        end
    end
    
    A._gphLastHoveredRow = canonical
    GameTooltip:Show()
end

function A.HandleBagSlotLeave(frame)
    if frame.bagHighlight then frame.bagHighlight:Hide() end
    
    if _G.MerchantFrame and _G.MerchantFrame:IsShown() and _G.ResetCursor then
        _G.ResetCursor()
    end
    
    -- CLEANING GUARD: If the factory is currently recycling frames, ignore the OnLeave hide.
    -- This prevents the tooltip from flickering out when its owner frame is hidden/moved.
    local isShielded = A.gphTooltipShield and (GetTime() < A.gphTooltipShield)
    local isCleaning = A._gphIsCleaning or frame._isGPHCleaning or (A._gphIsCleaningBuffer and (GetTime() < A._gphIsCleaningBuffer + 0.15))
    if isShielded or isCleaning then return end

    local focus = GetMouseFocus and GetMouseFocus()
    local canonical = frame.clickArea or frame._clickArea or frame
    local modOv = canonical._fugaziModifierOverlay
    
    if focus and modOv and focus == modOv then
        return 
    end
    
    if modOv then
        modOv:Hide()
        modOv:EnableMouse(false)
    end
    
    A._gphLastHoveredRow = nil
    GameTooltip:Hide()
end

-- Global Listener for Live-Toggling Modifiers
local _gphModifierMonitor = CreateFrame("Frame")
_gphModifierMonitor:RegisterEvent("MODIFIER_STATE_CHANGED")
_gphModifierMonitor:SetScript("OnEvent", function(self, event)
    local focus = A._gphLastHoveredRow
    if focus and focus:IsShown() then
        -- Re-run Enter logic to update overlay visibility on the fly
        A.HandleBagSlotEnter(focus, true)
    end
end)

--- Unified OnClick handler for bag slots.
function A.HandleBagSlotClick(frame, button, down)
    -- TRIGGER CLICK SHIELD: Freeze tooltip anchoring/moving for 150ms to survive the BAG_UPDATE flurry.
    -- (The actual item click, pickup, and modifiers are securely handled by ContainerFrameItemButtonTemplate and modOverlay)
    A.gphTooltipShield = GetTime() + 0.15
end

--- Handle specialized modifier actions (Alt+LMB for Protection, Ctrl+RMB for Autodelete).
function A.HandleModifierAction(frame, button, bag, slot, altDown, ctrlDown, shiftDown)
    local link = GetContainerItemLink(bag, slot)
    if not link then return end
    local itemId = tonumber(link:match("item:(%d+)"))
    if not itemId then return end

    local function playClick() if A.PlayClickSound then A.PlayClickSound() end end

    -- Alt+LMB: Toggle Item Protection
    if altDown and not ctrlDown and button == "LeftButton" then
        playClick()
        if A.ToggleItemProtection then
            A.ToggleItemProtection(itemId, link, frame)
        end
        
        -- Refresh UI
        A.RefreshBagUIs(bag)
        
        -- To prevent item being "picked up" effectively, we clear cursor
        if ClearCursor then ClearCursor() end
        PickupContainerItem(bag, slot)
        if ClearCursor then ClearCursor() end

    -- Ctrl+RMB: Add to Auto-Destroy List (Requires double-click logic similar to Gridview)
    elseif ctrlDown and not altDown and button == "RightButton" then
        -- Skip Bank slots for autodelete context if desired
        -- if bag == -1 or (bag >= 5 and bag <= 11) then return end
        
        if itemId == A.HEARTHSTONE_ID then return end -- Hearthstone safety
        
        -- Check if protected
        local _, _, q = A.GetCachedItemInfo(link)
        if A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, q) then
            A.AddonPrint("|cffff3333Cannot autodelete protected item.|r")
            return
        end

        local list = A.GetGphDestroyList and A.GetGphDestroyList()
        if not list then return end
        if list[itemId] then
            A.AddonPrint("|cffffff00" .. (A.GetCachedItemInfo(link) or itemId) .. "|r is already on the destroy list.")
            return
        end

        A.actionClickTime = A.actionClickTime or {}
        local now = GetTime()
        local prev = A.actionClickTime[itemId]

        if prev and (now - prev) <= 1.0 then
            A.actionClickTime[itemId] = nil
            
            local function addAndQueue()
                local name, _, _, _, _, _, _, _, _, texture = A.GetCachedItemInfo(itemId)
                list[itemId] = {
                    name = name or ("Item " .. itemId),
                    texture = texture,
                    addedTime = time(),
                }
                if A.QueueDestroySlotsForItemId then
                    A.QueueDestroySlotsForItemId(itemId)
                end
                A.RefreshBagUIs(bag)
            end

            -- Confirm dialog if setting enabled
            local SV = _G.FugaziBAGSDB
            if SV and SV.gridConfirmAutoDel ~= false then
                local itemName = A.GetCachedItemInfo(itemId) or (link or "this item")
                StaticPopupDialogs["FUGAZIGRID_DESTROY_CONFIRM"].OnAccept = function()
                    addAndQueue()
                end
                StaticPopup_Show("FUGAZIGRID_DESTROY_CONFIRM", itemName)
            else
                addAndQueue()
            end
        else
            A.actionClickTime[itemId] = now
            playClick()
            A.RefreshBagUIs(bag)
            -- Visual feedback for the first click
            if frame.autoDelOverlay or frame.autoDelText or frame.rowHighlight or (frame.GetParent and frame:GetParent().rowHighlight) then
                A.HandleBagSlotPulse(frame, nil, 1, 0, 0, 1) -- Pass nil to handle all elements
            end
        end
    end
end

--- Unified UI refresh for both views.
function A.RefreshBagUIs(bag)
    -- List view refresh
    if _G.RefreshGPHUI then 
        local inv = A.Inventory
        if inv then inv._refreshImmediate = true end
        _G.RefreshGPHUI() 
    end
    
    -- Grid view refresh
    if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then 
        _G.FugaziBAGS_CombatGrid.RefreshSlots() 
    end

    -- Bank refresh if applicable
    if bag and (bag == -1 or (bag >= 5 and bag <= 11)) and _G.FugaziBAGS_ScheduleRefreshBankUI then
        _G.FugaziBAGS_ScheduleRefreshBankUI()
    end
end

function A.HandleBagSlotPulse(frame, elementKey, r, g, b, duration)
    local elements = {}
    if elementKey then
        table.insert(elements, elementKey)
    else
        -- If no specific element, pulse all known indicator elements (check parent too for Listview)
        local p = frame:GetParent()
        if frame.autoDelOverlay or (p and p.autoDelOverlay) then table.insert(elements, "autoDelOverlay") end
        if frame.autoDelText or (p and p.autoDelText) then table.insert(elements, "autoDelText") end
        if frame.rowHighlight or (p and p.rowHighlight) then table.insert(elements, "rowHighlight") end
        if frame.nameFs or (p and p.nameFs) then table.insert(elements, "nameFs") end
    end
    
    if #elements == 0 then return end
    
    local elData = {}
    for _, key in ipairs(elements) do
        local el = frame[key] or (frame:GetParent() and frame:GetParent()[key])
        if el then
            local isTexture = (el.GetObjectType and el:GetObjectType() == "Texture")
            local startA = 1
            if isTexture then
                local rC, gC, bC, aC = el:GetVertexColor()
                startA = aC or 1
                if startA < 0.4 then startA = 0.6 end
                el:SetVertexColor(r, g, b, startA)
            else
                el:SetTextColor(r, g, b)
            end
            el:Show()
            table.insert(elData, { el = el, isTex = isTexture, startA = startA, key = key })
        end
    end
    
    if #elData == 0 then return end
    
    if not frame._pulseFrame then frame._pulseFrame = CreateFrame("Frame") end
    frame._pulseElapsed = 0
    duration = duration or 1.0
    
    frame._pulseFrame:SetScript("OnUpdate", function(f, elapsed)
        frame._pulseElapsed = frame._pulseElapsed + elapsed
        local t = frame._pulseElapsed / duration
        if t >= 1.0 then
            f:SetScript("OnUpdate", nil)
            for _, data in ipairs(elData) do
                local el = data.el
                if data.isTex then
                    el:SetVertexColor(1, 1, 1, 0)
                else
                    el:SetTextColor(1, 1, 1)
                    if data.key == "autoDelText" then
                        -- Keep shown if still on list, but reset color
                        local Addon = _G.FugaziBAGS
                        local list = Addon and A.GetGphDestroyList and A.GetGphDestroyList()
                        local id = frame.cachedItemId
                        if not (list and id and list[id]) then el:Hide() end
                    end
                end
            end
        else
            local nr = r + (1-r)*t
            local ng = g + (1-g)*t
            local nb = b + (1-b)*t
            for _, data in ipairs(elData) do
                local el = data.el
                if data.isTex then
                    el:SetVertexColor(nr, ng, nb, data.startA * (1-t))
                else
                    el:SetTextColor(nr, ng, nb)
                end
            end
        end
    end)
end

--- Unified OnDragStart handler for bag slots.
function A.HandleBagSlotDrag(frame)
    local bag, slot = A.GetBagSlotFromFrame(frame)
    if bag and slot then
        PickupContainerItem(bag, slot)
    end
end

--- Unified OnReceiveDrag handler for bag slots.
function A.HandleBagSlotReceiveDrag(frame)
    local bag, slot = A.GetBagSlotFromFrame(frame)
    if bag and slot then
        PickupContainerItem(bag, slot)
    end
end

--- Rarity bar button: filter, protect, delete all, mail to bank.
function A.GPHQualBtn_OnClick(self, button)
    if A.PlayClickSound then A.PlayClickSound() end
    if _G.MerchantFrame and _G.MerchantFrame:IsShown() and _G.FugaziVendorProtectUnhookNow then _G.FugaziVendorProtectUnhookNow() end
    local ctrl  = IsControlKeyDown and IsControlKeyDown()
    local alt   = IsAltKeyDown and IsAltKeyDown()
    local shift = IsShiftKeyDown and IsShiftKeyDown()

    local q = self.quality
    if A.continuousDelActive and A.continuousDelActive[q] and not (ctrl or alt or shift) then
        A.continuousDelActive[q] = nil
        local stillActive = false
        for k, v in pairs(A.continuousDelActive) do if v then stillActive = true; break end end
        if not stillActive and A.ContinuousDeleteWorker then A.ContinuousDeleteWorker:Hide() end
        local gphFrame = A.Inventory
        if gphFrame then gphFrame._refreshImmediate = true end
        A.RefreshBagUIs()
        return
    end

    if ctrl and button == "LeftButton" then
        local now = (GetTime and GetTime()) or time()
        local q = self.quality
        A.continuousDelStage = A.continuousDelStage or {}
        local stage = A.continuousDelStage[q]
        if not stage or (now - stage.time) > 1.2 then
            A.continuousDelStage[q] = { clicks = 1, time = now }
        else
            stage.clicks = stage.clicks + 1
            stage.time = now
            if stage.clicks >= 3 then
                A.continuousDelStage[q] = nil
                local SV = _G.FugaziBAGSDB or {}
                if SV.gridConfirmAutoDel == false then
                    A.StartContinuousDelete(q)
                else
                    local info = A.QUALITY_COLORS[q] or {}
                    local qName = info.label or ("Quality " .. q)
                    local hex = info.hex and ("|cff" .. info.hex) or "|cffffffff"
                    StaticPopup_Show("GPH_CONTINUOUS_DELETE", hex .. qName .. "|r", nil, { quality = q })
                end
            end
        end
        local gphFrame = A.Inventory
        if gphFrame then gphFrame._refreshImmediate = true end
        A.RefreshGPHUI()
        return
    end

    if shift and button == "RightButton" and (self.currentCount or 0) > 0 then
        local bf = A.Bank
        local gbf = _G.GuildBankFrame
        local mf = _G.MailFrame
        if (bf and bf:IsShown()) or (gbf and gbf:IsShown()) then
            local mode = (gbf and gbf:IsShown()) and "bags_to_guildbank" or "bags_to_bank"
            A.RarityMoveJob = { mode = mode, rarity = self.quality }
            if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
        elseif mf and mf:IsShown() then
            local recipient = _G.SendMailNameEditBox and _G.SendMailNameEditBox:GetText()
            if not recipient or recipient:match("^%s*$") then
                print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
            else
                local info = A.QUALITY_COLORS[self.quality] or {}
                local qName = info.label or ("Quality " .. tostring(self.quality))
                StaticPopup_Show("GPH_CONFIRM_MAIL_RARITY", qName:lower(), recipient, { rarity = self.quality })
            end
        end
        return
    end

    if alt and not ctrl and button == "LeftButton" and A.GetGphProtectedRarityFlags then
        local gphFrame = A.Inventory
        if gphFrame then gphFrame._refreshImmediate = true end
        A.RefreshGPHUI()
        return -- MODIFIED: Stop here, don't toggle filters on Alt+Click
    end

    if ctrl and button == "RightButton" and (self.currentCount or 0) > 0 then
        local now = (GetTime and GetTime()) or time()
        local q = self.quality
        A.rarityDelStage = A.rarityDelStage or {}
        local stage = A.rarityDelStage[q]
        
        if not stage or (now - stage.time) > 1.2 then
            A.rarityDelStage[q] = { clicks = 1, time = now }
        else
            stage.clicks = stage.clicks + 1
            stage.time = now
            if stage.clicks >= 3 then
                A.rarityDelStage[q] = nil
                local SV = _G.FugaziBAGSDB or {}
                if SV.gridConfirmAutoDel == false then
                    A.DeleteAllOfQuality(q)
                else
                    local info = A.QUALITY_COLORS[q] or {}
                    local qName = info.label or ("Quality " .. q)
                    local hex = info.hex and ("|cff" .. info.hex) or "|cffffffff"
                    local realCount, realValue = A.GetRarityDeleteInfo(q)
                    local worthStr = A.GPH_FormatMoney(realValue)
                    StaticPopup_Show("GPH_DELETE_QUALITY", realCount, (hex .. qName .. "|r items in your bags?\nTotal worth: " .. worthStr), { quality = q })
                end
            end
        end
        local gphFrame = A.Inventory
        if gphFrame then gphFrame._refreshImmediate = true end
        A.RefreshGPHUI()
        return
    end

    local gphFrame = self:GetParent() -- Get header or frame
    if gphFrame and gphFrame:GetName() ~= "InventoryMainFrame" and gphFrame:GetName() ~= "BankMainFrame" then
        -- Button might be inside a sub-header or element, try to find the host frame
        local p = gphFrame:GetParent()
        if p and (p:GetName() == "InventoryMainFrame" or p:GetName() == "BankMainFrame") then
            gphFrame = p
        else
            -- Fallback to global refs if parent hierarchy is complex
            gphFrame = A.Inventory
        end
    end
    
    local isBank = (gphFrame and (gphFrame:GetName() == "BankMainFrame" or gphFrame._isBankFrame))

    if button == "LeftButton" then
        if gphFrame then
            if gphFrame.gphFilterQuality == self.quality then gphFrame.gphFilterQuality = nil
            else gphFrame.gphFilterQuality = self.quality end
            for qKey in pairs(A.pendingQuality or {}) do A.pendingQuality[qKey] = nil end
            if gphFrame.gphEscCatcher then gphFrame.gphEscCatcher:Hide(); gphFrame.gphEscCatcher:ClearFocus() end
            gphFrame._refreshImmediate = true
            gphFrame.gphScrollToDefaultOnNextRefresh = true
        end
        if isBank and _G.RefreshBankUI then _G.RefreshBankUI()
        else A.RefreshGPHUI() end
        return
    end

    if button == "RightButton" then
        if gphFrame then
            gphFrame.gphFilterQuality = nil
            gphFrame._refreshImmediate = true
        end
        for qKey in pairs(A.pendingQuality or {}) do A.pendingQuality[qKey] = nil end
        if isBank and _G.RefreshBankUI then _G.RefreshBankUI()
        else A.RefreshGPHUI() end
        return
    end
end
