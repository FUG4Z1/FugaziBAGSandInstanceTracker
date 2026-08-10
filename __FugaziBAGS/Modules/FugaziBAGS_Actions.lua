--[[
  FugaziBAGS_Actions: Unified handler for bag slot actions.
  Centralizes item protection, destruction (Modifier+Click), and bag events.
]]

local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}


StaticPopupDialogs["GPH_DELETE_QUALITY"] = {
    text = "Delete all %d %s",
    button1 = "|cffff0000DELETE ALL|r",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data and data.quality then
            if A.pendingQuality then A.pendingQuality[data.quality] = nil end
            if A.rarityDelStage then A.rarityDelStage[data.quality] = nil end
            A.DeleteAllOfQuality(data.quality)
        end
    end,
    OnCancel = function(self, data)
        if data and data.quality then
            if A.pendingQuality then A.pendingQuality[data.quality] = nil end
            if A.rarityDelStage then A.rarityDelStage[data.quality] = nil end
            if A.RefreshGPHUI then A.RefreshGPHUI() end
        end
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
        if data and data.quality then
            if A.pendingQuality then A.pendingQuality[data.quality] = nil end
            if A.continuousDelStage then A.continuousDelStage[data.quality] = nil end
            A.StartContinuousDelete(data.quality)
        end
    end,
    OnCancel = function(self, data)
        if data and data.quality then
            if A.pendingQuality then A.pendingQuality[data.quality] = nil end
            if A.continuousDelStage then A.continuousDelStage[data.quality] = nil end
            if A.RefreshGPHUI then A.RefreshGPHUI() end
        end
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

-- ---------------------------------------------------------------------------
-- Modifier overlay arming (protect / autodelete)
--
-- 3.3.5a: IsAltKeyDown()/IsControlKeyDown() can stay true after /reload even
-- when the key is not held. Trusting that alone enabled the click-stealing
-- overlay and made bag clicks toggle protect until the user tapped Alt.
--
-- Fix: only treat Alt/Ctrl as active after a real MODIFIER_STATE_CHANGED for
-- that key this session. Stuck API-true with no live event = ignore.
-- ---------------------------------------------------------------------------
local altLive = false
local ctrlLive = false

--- True only when we saw a real Alt key event AND the client still reports Alt down.
function A.IsAltModifierLive()
    if not altLive then return false end
    return (IsAltKeyDown and IsAltKeyDown()) and true or false
end

--- True only when we saw a real Ctrl key event AND the client still reports Ctrl down.
function A.IsCtrlModifierLive()
    if not ctrlLive then return false end
    return (IsControlKeyDown and IsControlKeyDown()) and true or false
end

--- Should the protect/destroy mouse overlay capture clicks?
function A.ShouldShowModifierOverlay()
    local alt = A.IsAltModifierLive()
    local ctrl = A.IsCtrlModifierLive()
    return (alt or ctrl) and not (alt and ctrl)
end

--- Clear live arming (login / reload). Does not inject keys — just forgets false "down" state.
function A.ResetModifierLiveState()
    altLive = false
    ctrlLive = false
end

-- Alt/Ctrl protect-destroy overlay only (no GameTooltip work).
local function SyncModOverlay(canonical)
    local modOv = canonical and canonical._fugaziModifierOverlay
    if not modOv then return end
    if A.ShouldShowModifierOverlay() then
        modOv:Show()
        modOv:EnableMouse(true)
    else
        modOv:Hide()
        modOv:EnableMouse(false)
    end
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

    if bag == nil or slot == nil then return end 
    
    -- SSOT: Find the "Canonical Owner" (The clickArea) to prevent flickering between layers.
    local canonical = frame.clickArea or frame._clickArea or (parent and (parent.clickArea or parent._clickArea)) or frame
    
    -- Ensure canonical is actually visible/valid
    if not (canonical:GetRight() and canonical:GetRight() > 0) then canonical = frame end

    -- Prefer the secure ContainerFrameItemButton as GameTooltip owner when present.
    -- Template OnUpdate only calls UpdateTooltip when GameTooltip:IsOwned(self). Owning
    -- the clickArea meant post-transfer empty slots never refreshed (ghost tooltip).
    local tooltipOwner = canonical._fugaziSecBtn or frame._fugaziSecBtn or canonical

    local isBank = (bag == -1 or bag >= 5) 
    
    -- AUTO-DETECT HOST: Find the window by climbing, fallback to global pointers.
    local host = hostWindow or getParentWindow(frame) or (isBank and A.Bank) or A.Inventory

    -- 1. STABLE POSITIONING: Anchor the tooltip to the interactive owner (secure btn / clickArea).
    A.AnchorTooltipSmart(tooltipOwner, isBank and "LEFT" or "RIGHT", host)

    -- 2. VISUALS (Highlight & Sounds)
    -- Grid: bagHighlight on slot. List: rowHighlight on outer row (parent of clickArea).
    local rowHl = frame.rowHighlight or (parent and parent.rowHighlight)
    if not rowHl and canonical ~= frame then
        local cp = canonical.GetParent and canonical:GetParent()
        rowHl = canonical.rowHighlight or (cp and cp.rowHighlight)
    end
    local wasHighlighted = (canonical.bagHighlight and canonical.bagHighlight:IsShown())
        or (rowHl and rowHl:IsShown())
    if canonical.bagHighlight then canonical.bagHighlight:Show() end
    if rowHl then
        -- Soft wash (~10% white). Set on show so older pooled rows pick it up too.
        rowHl:SetVertexColor(1, 1, 1, 0.10)
        rowHl:Show()
    end
    if not silent and not wasHighlighted and A.PlayHoverSound then A.PlayHoverSound() end

    -- 2.1 MERCHANT CURSOR
    if _G.MerchantFrame and _G.MerchantFrame:IsShown() and not isBank then
        local fn = _G.ShowContainerSellCursor or (_G.C_Container and _G.C_Container.ShowContainerSellCursor)
        if fn then
            fn(bag, slot)
        end
    end

    -- 3. CONTENT UPDATE (must rebuild cleanly — UpdateTooltip re-enters this often).
    -- Ensure owner exists even if AnchorTooltipSmart could not place beside host yet.
    if GameTooltip:GetOwner() ~= tooltipOwner then
        GameTooltip:SetOwner(tooltipOwner, "ANCHOR_RIGHT")
    end

    local link = GetContainerItemLink(bag, slot)
    -- Empty slot under mouse (e.g. RMB bank/inv transfer in grid): drop ghost tooltip.
    if not link then
        local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(bag, slot))
        if not tex then
            A._gphLastHoveredRow = nil
            GameTooltip:Hide()
            return
        end
    end
    local keyringBag = (KEYRING_CONTAINER or -2)

    -- Base item lines. Keyring (-2): SetBagItem often fails to re-clear on UpdateTooltip
    -- re-entry in 3.3.5, so item text stays once while our AddLines stack forever.
    -- SetHyperlink always replaces the whole tooltip → safe for pulse refresh.
    if bag == -1 then
        local invSlot = (BankButtonIDToInvSlotID and BankButtonIDToInvSlotID(slot)) or (38 + slot)
        GameTooltip:SetInventoryItem("player", invSlot)
    elseif bag == keyringBag then
        if link then
            GameTooltip:SetHyperlink(link)
        else
            GameTooltip:ClearLines()
        end
    else
        GameTooltip:SetBagItem(bag, slot)
        local numLines = (GameTooltip.NumLines and GameTooltip:NumLines()) or 0
        if numLines == 0 and link then
            GameTooltip:SetHyperlink(link)
        end
    end

    -- 4. PROTECTION INFO
    -- Guard: if a failed/no-op base refresh left our lines in place, do not AddLine again.
    local function tooltipHasOurLines()
        local Loc = A.L
        local unprotected = (Loc and Loc.TOOLTIP_UNPROTECTED) or "Unprotected"
        local protected = (Loc and Loc.TOOLTIP_PROTECTED) or "Protected"
        local worn = (Loc and Loc.TOOLTIP_PREVIOUSLY_WORN) or "Previously worn gear"
        local markDel = (Loc and Loc.TOOLTIP_MARKER_AUTODELETE) or "Autodelete"
        local markAlt = (Loc and Loc.TOOLTIP_MARKER_ALT_LMB) or "Alt+LMB:"
        local n = (GameTooltip.NumLines and GameTooltip:NumLines()) or 0
        local from = (n > 8) and (n - 7) or 1
        for i = from, n do
            local fs = _G["GameTooltipTextLeft" .. i]
            local t = fs and fs.GetText and fs:GetText()
            if t and (
                t == unprotected or t == protected or t == worn
                or t:find(markDel, 1, true)
                or t:find(markAlt, 1, true)
            ) then
                return true
            end
        end
        return false
    end

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

        if not tooltipHasOurLines() then
            local Loc = A.L
            if isPrev then
                GameTooltip:AddLine((Loc and Loc.TOOLTIP_PREVIOUSLY_WORN) or "Previously worn gear", 0.40, 0.80, 0.40)
                GameTooltip:AddLine((Loc and Loc.TOOLTIP_ALT_LMB_UNPROTECT) or "Alt+LMB: Unprotect", 0.80, 0.80, 0.80)
            elseif prot then
                GameTooltip:AddLine((Loc and Loc.TOOLTIP_PROTECTED) or "Protected", 0.40, 0.80, 0.40)
                GameTooltip:AddLine((Loc and Loc.TOOLTIP_ALT_LMB_UNPROTECT) or "Alt+LMB: Unprotect", 0.80, 0.80, 0.80)
            else
                GameTooltip:AddLine((Loc and Loc.TOOLTIP_UNPROTECTED) or "Unprotected", 1.00, 0.25, 0.25)
                GameTooltip:AddLine((Loc and Loc.TOOLTIP_ALT_LMB_PROTECT) or "Alt+LMB: Protect", 0.80, 0.80, 0.80)
            end
            GameTooltip:AddLine((Loc and Loc.TOOLTIP_CTRL_RMB_AUTODELETE) or "Ctrl+RMB (2x): Autodelete", 0.90, 0.60, 0.60)
        end

        SyncModOverlay(canonical)
    end
    
    A._gphLastHoveredRow = canonical
    GameTooltip:Show()
end

function A.HandleBagSlotLeave(frame)
    if frame.bagHighlight then frame.bagHighlight:Hide() end
    -- List-row hover wash (created on outer row; enter often fires on clickArea).
    local rowHl = frame.rowHighlight
    if not rowHl and frame.GetParent then
        local p = frame:GetParent()
        rowHl = p and p.rowHighlight
    end
    if rowHl then rowHl:Hide() end

    if _G.MerchantFrame and _G.MerchantFrame:IsShown() and _G.ResetCursor then
        _G.ResetCursor()
    end

    local focus = GetMouseFocus and GetMouseFocus()
    local canonical = frame.clickArea or frame._clickArea or frame
    local modOv = canonical._fugaziModifierOverlay

    -- Leaving into the alt/ctrl overlay is still "on" this slot — keep the tip.
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

-- Alt/Ctrl only: flip protect/destroy overlay. Never rebuild GameTooltip (Shift was
-- re-showing bag item compare after bags closed via full HandleBagSlotEnter).
-- Also the only place we arm altLive/ctrlLive (real key events, not sticky API).
local _gphModifierMonitor = CreateFrame("Frame")
_gphModifierMonitor:RegisterEvent("MODIFIER_STATE_CHANGED")
_gphModifierMonitor:RegisterEvent("PLAYER_LOGIN")
_gphModifierMonitor:RegisterEvent("PLAYER_ENTERING_WORLD")
_gphModifierMonitor:SetScript("OnEvent", function(_, event, key)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- After reload, drop any latched "armed" state so sticky IsAltKeyDown is ignored.
        A.ResetModifierLiveState()
        local row = A._gphLastHoveredRow
        if row and row:IsVisible() then
            SyncModOverlay(row)
        end
        return
    end

    -- MODIFIER_STATE_CHANGED: key is e.g. "LALT","RALT","LCTRL","RCTRL" (3.3.5).
    if type(key) == "string" then
        if key == "LALT" or key == "RALT" then
            altLive = (IsAltKeyDown and IsAltKeyDown()) and true or false
        elseif key == "LCTRL" or key == "RCTRL" then
            ctrlLive = (IsControlKeyDown and IsControlKeyDown()) and true or false
        end
    end

    local row = A._gphLastHoveredRow
    if row and row:IsVisible() then
        SyncModOverlay(row)
    end
end)

--- Unified OnClick handler for bag slots.
function A.HandleBagSlotClick(frame, button, down)
    -- TRIGGER CLICK SHIELD: Freeze tooltip anchoring/moving for 150ms to survive the BAG_UPDATE flurry.
    -- (The actual item click, pickup, and modifiers are securely handled by ContainerFrameItemButtonTemplate and modOverlay)
    A.gphTooltipShield = GetTime() + 0.15
    A._gphLastItemUseTime = GetTime()

    -- RMB transfer (bank ↔ bags) often empties the slot without OnLeave. Secure-button
    -- OnUpdate may not re-fire until mouse moves; clear or rebuild tooltip next frame.
    if button == "RightButton" and frame then
        A._gphPostClickTipFrame = A._gphPostClickTipFrame or CreateFrame("Frame")
        local f = A._gphPostClickTipFrame
        f._target = frame
        f._t = 0
        f:SetScript("OnUpdate", function(self, elapsed)
            self._t = (self._t or 0) + elapsed
            if self._t < 0.05 then return end
            self:SetScript("OnUpdate", nil)
            self:Hide()
            local fr = self._target
            self._target = nil
            if not fr then return end
            local bag, slot = A.GetBagSlotFromFrame(fr)
            if bag == nil or slot == nil then return end
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            if not link then
                local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(bag, slot))
                if not tex then
                    GameTooltip:Hide()
                    return
                end
            end
            -- Partial stack / failed move: rebuild tooltip for whatever remains.
            if A.HandleBagSlotEnter then
                A.HandleBagSlotEnter(fr, true)
            end
        end)
        f:Show()
    end
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
        
        -- Refresh UI (protected items re-sort to top — pulse only after rebind)
        A.RefreshBagUIs(bag)
        if A.PulseListRowByItemId then
            A.PulseListRowByItemId(itemId)
        end

    -- Ctrl+RMB: Add to Auto-Destroy List (Requires double-click logic similar to Gridview)
    elseif ctrlDown and not altDown and button == "RightButton" then
        -- Skip Bank slots for autodelete context
        if bag == -1 or (bag >= 5 and bag <= 11) then
            return
        end
        
        if itemId == A.HEARTHSTONE_ID then return end -- Hearthstone safety
        
        -- Full protection (manual / worn / rarity / hearth / quest)
        local _, _, q = A.GetCachedItemInfo(link)
        if (A.ShouldSkipAutoDelete and A.ShouldSkipAutoDelete(itemId, q, link))
            or (A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, q, false)) then
            A.AddonPrint((A.L and A.L.MSG_CANNOT_AUTODELETE_PROTECTED) or "|cffff3333Cannot autodelete protected item.|r")
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
    
    -- Grid view refresh (protect/vendor overlays may change without bag content deltas)
    if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then
        if A.MarkGridFullRefresh then A.MarkGridFullRefresh() end
        _G.FugaziBAGS_CombatGrid.RefreshSlots(true)
    end

    -- Bank: protect/unprotect does not change counts, so the Phase 8 list smart/NOOP path
    -- and grid dirty-skip would leave chrome stale until re-open. Force full paint now.
    local isBankBag = bag and (bag == -1 or (bag >= 5 and bag <= 11))
    local bf = A.Bank
    local bankOpen = bf and bf.IsShown and bf:IsShown()
    if (isBankBag or bankOpen) and bankOpen then
        bf._bankForceFull = true
        if bf.gphGridMode then
            bf._bankGridForceFull = true
        end
        if _G.RefreshBankUI then
            _G.RefreshBankUI(true)
        elseif _G.FugaziBAGS_ScheduleRefreshBankUI then
            _G.FugaziBAGS_ScheduleRefreshBankUI()
        end
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

--- Resolve list-row pulse texture (btn.pulseTex is a Frame wrapping the color tex).
local function GetListPulseColorTex(row)
    if not row then return nil end
    if row._pulseColorTex then return row._pulseColorTex end
    local host = row.pulseTex
    if host and host.GetRegions then
        local regions = { host:GetRegions() }
        for i = 1, #regions do
            local r = regions[i]
            if r and r.GetObjectType and r:GetObjectType() == "Texture" then
                row._pulseColorTex = r
                return r
            end
        end
    end
    return nil
end

local function FindListRowByBagSlot(bag, slot)
    bag, slot = tonumber(bag), tonumber(slot)
    if bag == nil or slot == nil then return nil end
    local function matchRow(row)
        if not row or not row:IsShown() then return false end
        if tonumber(row.bag) == bag and tonumber(row.slot) == slot then return true end
        local ca = row.clickArea
        if ca and tonumber(ca.bag) == bag and tonumber(ca.slot) == slot then return true end
        return false
    end
    local function scan(pool, used)
        if not pool then return nil end
        local n = used or #pool
        for i = 1, n do
            local row = pool[i]
            if matchRow(row) then return row end
        end
        return nil
    end
    local invPool, invUsed = A.GetGPHItemPool and A.GetGPHItemPool()
    local row = scan(invPool, invUsed)
    if row then return row end
    if A.GPH_BANK_POOL then
        return scan(A.GPH_BANK_POOL, A.GPH_BANK_POOL_USED)
    end
    return nil
end

local function EnsureGridDeniedFlash(btn)
    if not btn then return nil end
    if btn._deniedFlash then return btn._deniedFlash end
    local t = btn:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints(btn)
    t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    t:SetVertexColor(1, 0.12, 0.12, 0.85)
    t:Hide()
    btn._deniedFlash = t
    return t
end

--- Triple red flash on a bag/slot when an action is denied (e.g. soulbound cannot mail).
--- List: row pulse wash (or rowHighlight fallback). Grid: soft red overlay only (no DEL).
-- @param bag number
-- @param slot number
-- @param times number|nil  default 3
function A.FlashBagSlotDenied(bag, slot, times)
    times = times or 3
    if times < 1 then return end

    local listHost, listTex, listHl
    local row = FindListRowByBagSlot(bag, slot)
    if row then
        if A.ClearRowPulse then A.ClearRowPulse(row) end
        listHost = row.pulseTex
        listTex = GetListPulseColorTex(row)
        listHl = row.rowHighlight
    end

    local gridTex
    local cg = _G.FugaziBAGS_CombatGrid
    local gbtn = (cg and cg.GetSlotButton and cg.GetSlotButton(bag, slot)) or nil
    -- Flash grid button even if the grid content frame is hidden-behind list? only when shown.
    if gbtn and (gbtn.IsShown and gbtn:IsShown()) then
        gridTex = EnsureGridDeniedFlash(gbtn)
    end

    if not listHost and not listHl and not gridTex then return end

    local ON, OFF = 0.10, 0.08
    local driver = CreateFrame("Frame")
    local phase, count, acc = 0, 0, 0 -- phase 0=on, 1=off

    local function setOn(on)
        if listHost then
            if on then
                if listTex then listTex:SetVertexColor(1, 0.08, 0.08, 0.95) end
                listHost:SetAlpha(1)
                listHost:Show()
            else
                listHost:SetAlpha(0)
                listHost:Hide()
                if listTex then listTex:SetVertexColor(1, 1, 1, 0.7) end
            end
        end
        if listHl then
            if on then
                listHl:SetVertexColor(1, 0.08, 0.08, 0.55)
                listHl:Show()
            else
                listHl:SetVertexColor(1, 1, 1, 0.10)
                listHl:Hide()
            end
        end
        if gridTex then
            if on then
                gridTex:SetVertexColor(1, 0.08, 0.08, 0.85)
                gridTex:Show()
            else
                gridTex:Hide()
            end
        end
    end

    setOn(true)
    driver:SetScript("OnUpdate", function(self, elapsed)
        acc = acc + elapsed
        local limit = (phase == 0) and ON or OFF
        if acc < limit then return end
        acc = 0
        if phase == 0 then
            setOn(false)
            phase = 1
            count = count + 1
            if count >= times then
                self:SetScript("OnUpdate", nil)
                setOn(false)
            end
        else
            setOn(true)
            phase = 0
        end
    end)
end

--- Flash every bag/slot in a list of {bag, slot} entries (soulbound bulk-mail skips, etc.).
function A.FlashBagSlotsDenied(entries, times)
    if not entries then return end
    for i = 1, #entries do
        local e = entries[i]
        if e and e.bag ~= nil and e.slot ~= nil then
            A.FlashBagSlotDenied(e.bag, e.slot, times)
        end
    end
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
    -- Live modifiers only (sticky IsAltKeyDown after /reload must not mass-protect rarities).
    local ctrl  = A.IsCtrlModifierLive and A.IsCtrlModifierLive() or false
    local alt   = A.IsAltModifierLive and A.IsAltModifierLive() or false
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
            if stage.clicks == 3 then
                local SV = _G.FugaziBAGSDB or {}
                if SV.gridConfirmAutoDel == false then
                    A.StartContinuousDelete(q)
                else
                    local info = A.QUALITY_COLORS[q] or {}
                    local qName = info.label or ("Quality " .. q)
                    local hex = info.hex and ("|cff" .. info.hex) or "|cffffffff"
                    A.pendingQuality = A.pendingQuality or {}
                    A.pendingQuality[q] = now
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
            if A.StartRarityMoveJob then
                A.StartRarityMoveJob(mode, self.quality, nil)
            else
                A.RarityMoveJob = { mode = mode, rarity = self.quality }
                if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
            end
        elseif mf and mf:IsShown() then
            local recipient = _G.SendMailNameEditBox and _G.SendMailNameEditBox:GetText()
            if not recipient or recipient:match("^%s*$") then
                print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
            else
                local info = A.QUALITY_COLORS[self.quality] or {}
                local qName = info.label or ("Quality " .. tostring(self.quality))
                local searchLower, filterQ = nil, nil
                if A.SnapshotMoveJobFilters then
                    searchLower, filterQ = A.SnapshotMoveJobFilters()
                end
                StaticPopup_Show("GPH_CONFIRM_MAIL_RARITY", qName:lower(), recipient, {
                    rarity = self.quality,
                    searchLower = searchLower,
                    filterQuality = filterQ,
                })
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
            if stage.clicks == 3 then
                local SV = _G.FugaziBAGSDB or {}
                if SV.gridConfirmAutoDel == false then
                    A.DeleteAllOfQuality(q)
                else
                    local info = A.QUALITY_COLORS[q] or {}
                    local qName = info.label or ("Quality " .. q)
                    local hex = info.hex and ("|cff" .. info.hex) or "|cffffffff"
                    local realCount, realValue = A.GetRarityDeleteInfo(q)
                    local worthStr = A.GPH_FormatMoney(realValue)
                    A.pendingQuality = A.pendingQuality or {}
                    A.pendingQuality[q] = now
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

    -- Plain LMB filter is handled on MouseDown (+ drag-paint). OnClick only clears stages.
    if button == "LeftButton" and not ctrl and not alt and not shift then
        for qKey in pairs(A.pendingQuality or {}) do A.pendingQuality[qKey] = nil end
        if gphFrame and gphFrame.gphEscCatcher then
            gphFrame.gphEscCatcher:Hide()
            gphFrame.gphEscCatcher:ClearFocus()
        end
        return
    end

    -- RMB: clear all rarity filters
    if button == "RightButton" and not ctrl and not alt and not shift then
        if gphFrame then
            if A.ClearQualityFilters then
                A.ClearQualityFilters(gphFrame)
            else
                gphFrame.gphFilterQuality = nil
                gphFrame.gphFilterQualities = nil
                gphFrame.bankRarityFilter = nil
            end
            gphFrame._refreshImmediate = true
            if isBank then
                gphFrame._bankForceFull = true
                if gphFrame.gphGridMode then gphFrame._bankGridForceFull = true end
            end
        end
        for qKey in pairs(A.pendingQuality or {}) do A.pendingQuality[qKey] = nil end
        if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
        if A.MarkGridFullRefresh then A.MarkGridFullRefresh() end
        if isBank and _G.RefreshBankUI then _G.RefreshBankUI()
        else A.RefreshGPHUI() end
        return
    end
end
