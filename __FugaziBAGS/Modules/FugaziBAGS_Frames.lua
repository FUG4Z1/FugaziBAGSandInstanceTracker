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
    -- Don't re-anchor/resize while the user is dragging.
    if f._isDragging then return end
    if not f.gphGridMode then
        local wantW = f.gphGridFrameW or 340
        local wantH = f.gphGridFrameH or f.EXPANDED_HEIGHT or 420
        f.gphForceHeight = wantH
        f.gphForceHeightFrames = 8
        if not InCombatLockdown() then
            if A.PinFrameBottomLeft then A.PinFrameBottomLeft(f) end
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


-- List floors: never stick to a backpack-only ComputeFrameSize from pre-bag login.
local LIST_MIN_W, LIST_MIN_H = 320, 400

--- Preferred outer size for inventory or bank (list slider / grid content).
--- Auto ON  → grid bag-capacity footprint owns size; list matches it.
--- Auto OFF → fixed list width/height sliders own size for BOTH list and grid
--- (so combat grid switch keeps the tall frame; no post-combat snap-to-compact).
--- Login race: early ComputeFrameSize can be tiny (slots not ready) → floor + last-good
--- + OnShow retries (do not hardcode 340x420 forever; that broke auto).
local function GPH_PreferredFrameSize(frame, isBank, DB, cg)
    local autoW = (DB.gphListViewWidthAuto ~= false)
    local autoH = (DB.gphListViewHeightAuto ~= false)
    local w, h

    if frame and frame.gphGridMode then
        -- Grid content footprint (cols/rows) — used when auto is ON for that axis.
        w, h = frame.gphGridFrameW, frame.gphGridFrameH
        if (not w or not h or w < 50 or h < 50) and cg and cg.ComputeFrameSize then
            w, h = cg.ComputeFrameSize(isBank)
            frame.gphGridFrameW, frame.gphGridFrameH = w, h
        end
        if not w or not h then
            w, h = frame:GetWidth(), frame:GetHeight()
        end

        -- Fixed list sliders also lock the outer frame in grid mode (no shrink on Negotiate).
        if not autoW and DB.gphListViewWidth and DB.gphListViewWidth > 0 then
            w = DB.gphListViewWidth
        end
        if not autoH and DB.gphListViewHeight and DB.gphListViewHeight > 0 then
            h = DB.gphListViewHeight
        end
    else
        if not autoW and DB.gphListViewWidth and DB.gphListViewWidth > 0 then
            w = DB.gphListViewWidth
        end
        if not autoH and DB.gphListViewHeight and DB.gphListViewHeight > 0 then
            h = DB.gphListViewHeight
        end

        -- Auto (default): match grid bag-capacity footprint.
        if (autoW or autoH) and cg and cg.ComputeFrameSize then
            local gw, gh = cg.ComputeFrameSize(isBank)
            if autoW then w = gw end
            if autoH then
                local minH = DB.gphMinHeight or (frame and frame.EXPANDED_HEIGHT) or 420
                h = math.max(gh or 0, minH)
            end
        end

        -- Fallbacks if still missing.
        if not w then w = 340 end
        if not h then h = DB.gphMinHeight or (frame and frame.EXPANDED_HEIGHT) or 420 end

        -- Floor + last-good: early login ComputeFrameSize can be backpack-only tiny.
        if frame then
            if autoW then
                if w < LIST_MIN_W then
                    w = frame._gphLastGoodListW or LIST_MIN_W
                end
                if w >= LIST_MIN_W then frame._gphLastGoodListW = w end
            end
            if autoH then
                if h < LIST_MIN_H then
                    h = frame._gphLastGoodListH or math.max(LIST_MIN_H, DB.gphMinHeight or 420)
                end
                if h >= LIST_MIN_H then frame._gphLastGoodListH = h end
            end
        end
    end
    return w, h
end

--- Negotiate sizes between Inventory and Bank frames (ensuring they dock correctly).
--- When bank is open, both windows always share max(preferred inv, preferred bank)
--- so free-float / docked look the same height. Free float only affects position, not size.
--- Grid layout must NOT SetSize the outer frame (that caused tall→short→tall flicker).
function A.NegotiateSizes(f)
    if not f then return end
    -- Resizing mid-drag fights the cursor and looks like a jump.
    if f._isDragging then return end
    local bank = A.Bank
    if bank and bank._isDragging then return end
    local DB = _G.FugaziBAGSDB
    if not DB then return end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local cg = _G.FugaziBAGS_CombatGrid
    local iW, iH = GPH_PreferredFrameSize(f, false, DB, cg)
    
    -- Fallback to last saved height if current is somehow still zero or extremely small
    local savedPoint = DB.gphPoint
    if (not iH or iH < 100) and savedPoint and savedPoint.h and savedPoint.h >= LIST_MIN_H then
        iH = savedPoint.h
    end
    if (not iW or iW < 100) and savedPoint and savedPoint.w and savedPoint.w >= LIST_MIN_W then
        iW = savedPoint.w
    end
    
    local inv = A.Inventory or f
    -- Prefer preferred size from the inventory frame when bank called NegotiateSizes.
    if f._isBankFrame and A.Inventory then
        inv = A.Inventory
        iW, iH = GPH_PreferredFrameSize(inv, false, DB, cg)
        if (not iH or iH < 100) and savedPoint and savedPoint.h and savedPoint.h >= LIST_MIN_H then
            iH = savedPoint.h
        end
        if (not iW or iW < 100) and savedPoint and savedPoint.w and savedPoint.w >= LIST_MIN_W then
            iW = savedPoint.w
        end
    end

    local finalW, finalH = iW, iH
    local bankShown = bank and (bank:IsShown() or f == bank)
    local freeFloat = DB.gphBankFreeFloat and true or false

    if bankShown and bank then
        local bW, bH = GPH_PreferredFrameSize(bank, true, DB, cg)
        local _math_max = _G.math and _G.math.max or math.max
        finalW = _math_max(bW or 0, iW or 0)
        finalH = _math_max(bH or 0, iH or 0)
    end

    -- True while bank is still sibling-docked to inv (default free-float OFF open).
    -- After the user drags, anchors become independent BOTTOMLEFT — temporary move.
    -- NEVER re-center here: only DockInventoryBankCentered (bank open / B) may snap to middle.
    local function IsBankSiblingDocked()
        if not bank or not inv or freeFloat then return false end
        if not bank.GetPoint then return false end
        local n = bank.GetNumPoints and bank:GetNumPoints() or 1
        for i = 1, n do
            local _, rel = bank:GetPoint(i)
            if rel == inv then return true end
        end
        return false
    end

    local function ResizeFrameInPlace(frame, w, h)
        if not frame then return end
        local needW = frame:GetWidth() ~= w
        local needH = frame:GetHeight() ~= h
        if not needW and not needH then return end
        -- Sibling TOP* dock: SetSize without reanchor (tops stay aligned, grow downward).
        -- Independent / free-float: pin BOTTOMLEFT first so RIGHT anchors don't teleport.
        local sibling = (not freeFloat) and IsBankSiblingDocked()
            and (frame == inv or frame == bank)
        if not sibling then
            -- Free-float / independent: pin bottom-left so SetSize doesn't shift the window.
            if A.PinFrameBottomLeft and not A.PinFrameBottomLeft(frame) then
                return
            end
        end
        if needW then frame:SetWidth(w) end
        if needH then frame:SetHeight(h) end
    end

    if bankShown and bank and not freeFloat and inv and IsBankSiblingDocked() then
        -- Equalize size only; leave wherever DockInventoryBankCentered or the user put them.
        ResizeFrameInPlace(inv, finalW, finalH)
        ResizeFrameInPlace(bank, finalW, finalH)
    else
        if bankShown and bank and f ~= bank then
            ResizeFrameInPlace(bank, finalW, finalH)
        end
        ResizeFrameInPlace(f, finalW, finalH)
    end
    
    -- Match scroll viewport (list/bank paint use frameW-44). Old -14 overflow clipped
    -- right-edge stack counts after MasterUpdate NegotiateSizes.
    local function fixContentWidth(frame, width)
        if not frame or not frame.content then return end
        local scrollW
        local sf = frame.scrollFrame
        if sf and sf.GetWidth then
            local sw = sf:GetWidth()
            if sw and sw > 50 then scrollW = sw end
        end
        if not scrollW then
            scrollW = (width or frame:GetWidth() or 340) - 44
        end
        if frame.content:GetWidth() ~= scrollW then
            frame.content:SetWidth(scrollW)
        end
        frame.gphDynContentWidth = scrollW
    end
    if bankShown and bank and not freeFloat and inv and IsBankSiblingDocked() then
        fixContentWidth(inv, finalW)
        fixContentWidth(bank, finalW)
    else
        fixContentWidth(f, finalW)
    end
end
-- Keep a stable reference: Bankview used to overwrite A.NegotiateSizes with a duplicate.
A._NegotiateSizesImpl = A.NegotiateSizes


--- Update the icon and appearance of the Disenchant/Prospect button.



--- SetFrameLevel that never touches protected frames in combat (3.3.5 lockdown).
--- SecureActionButton / ContainerFrameItemButton raise 'AddOn prevented … SetFrameLevel()'.
function A.SafeSetFrameLevel(frame, level)
    if not frame or not frame.SetFrameLevel or level == nil then return end
    if InCombatLockdown and InCombatLockdown() then
        if frame.IsProtected and frame:IsProtected() then return end
    end
    frame:SetFrameLevel(level)
end

--- Keep chrome/buttons just above their host frame.
--- WoW 3.3.5 frame levels are absolute within a strata: a bag-space button at host+20
--- can paint over the other window after RaiseBagFrame lifts bank/inv by only +10.
function A.SyncFrameChromeLevels(f)
    if not f or not f.GetFrameLevel then return end
    local base = f:GetFrameLevel() or 20
    local safe = A.SafeSetFrameLevel
    local function pin(child, delta)
        if child then safe(child, base + (delta or 2)) end
    end
    pin(f.gphTitleBar, 2)
    pin(f.titleBar, 2)
    pin(f.gphHeader, 3)
    pin(f.bankHeader, 3)
    pin(f.gphBagSpaceBtn, 4)
    pin(f.bankSpaceBtn, 4)
    pin(f.bagRow, 5)
    -- Profession / open / learn are SecureActionButtonTemplate — skip in combat via SafeSetFrameLevel.
    pin(f.gphDisenchantBtn, 6)
    pin(f.gphProspectBtn, 6)
    pin(f.gphMillingBtn, 6)
    pin(f.gphOpenBtn, 6)
    pin(f.gphLearnBtn, 6)
    pin(f.gphMailBtn, 6)
    pin(f.bankSortBtn, 6)
end

--- Raise frame above sibling DIALOG frames (bank/inv card-stack fix).
function A.RaiseBagFrame(f)
    if not f then return end
    -- In combat: do nothing. Raise()/SetFrameLevel on a host that owns SecureActionButton
    -- children (DE/Open/etc.) is blocked as a secure call → BugGrabber spam, no gameplay gain.
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    -- Keep strata shared; lift level so the dragged window is fully on top.
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    local bank = A.Bank
    local inv = A.Inventory
    local other = (f == inv) and bank or inv
    local base = 20
    if other and other:IsShown() then
        local ol = other:GetFrameLevel() or 10
        if ol >= base then base = ol + 10 end
    end
    f:SetFrameLevel(base)
    if f.Raise then f:Raise() end
    if A.SyncFrameChromeLevels then A.SyncFrameChromeLevels(f) end
    -- Keep the other window's chrome re-tethered so old inflated levels do not stick above us.
    if other and other:IsShown() and A.SyncFrameChromeLevels then
        A.SyncFrameChromeLevels(other)
    end
end

--- Center-dock inventory + bank when Free Float Bank is OFF.
--- Only call on bank open / B toggle — NOT on drag stop or layout ticks.
--- forceBank: dock bank even if not yet IsShown (bank-open path before :Show).
--- User may drag either window temporarily; next open snaps here again.
function A.DockInventoryBankCentered(forceBank)
    local inv = A.Inventory
    local bank = A.Bank
    if not inv then return end
    if inv._isDragging or (bank and bank._isDragging) then return end
    local DB = _G.FugaziBAGSDB
    if DB and DB.gphBankFreeFloat then return end
    if InCombatLockdown and InCombatLockdown() then return end

    inv:ClearAllPoints()
    inv:SetPoint("TOPLEFT", UIParent, "TOP", 2, -80)
    local dockBank = bank and (forceBank or bank:IsShown())
    if dockBank then
        -- Sibling of inv (not child) so frame levels / overlap draw cleanly.
        if bank:GetParent() ~= UIParent then
            bank:SetParent(UIParent)
            local base = (DB and DB.gphScale15) and 1.5 or 1
            local extra = (DB and DB.gphFrameScale) or 1
            bank:SetScale(base * extra)
        end
        bank:ClearAllPoints()
        bank:SetPoint("TOPRIGHT", inv, "TOPLEFT", -4, 0)
        bank:SetFrameStrata("DIALOG")
        inv:SetFrameStrata("DIALOG")
        inv:SetFrameLevel(20)
        bank:SetFrameLevel(20)
        if A.SyncFrameChromeLevels then
            A.SyncFrameChromeLevels(inv)
            A.SyncFrameChromeLevels(bank)
        end
    end
    -- Equalize size only (NegotiateSizes must not re-center — drag is temporary).
    if inv.NegotiateSizes then
        inv:NegotiateSizes()
    elseif A.NegotiateSizes then
        A.NegotiateSizes(inv)
    end
end

--- Inventory drag.
--- Engine free-move always. SetClampedToScreen is OFF to avoid scale+clamp grab
--- teleports; SoftClampFrameToScreen runs on drag stop instead.
function A.GPHOnDragStart(f)
    if not f or f._isDragging then return end
    -- Block frame drag only when Alt-paint is actively in progress.
    -- Bare IsAltKeyDown() can stick after /reload on 3.3.5a, freezing the window.
    if IsAltKeyDown and IsAltKeyDown()
        and (A._rarityDragInitiated or A._filterDragInitiated) then
        return
    end

    -- Flag first so concurrent layout bails.
    f._isDragging = true

    if f.gphSelectedItemId then
        f.gphSelectedItemId = nil
        f.gphSelectedIndex = nil
        f.gphSelectedRowBtn = nil
        f.gphSelectedItemLink = nil
        if f.HideGPHUseOverlay then f.HideGPHUseOverlay(f) end
    end
    if A.RaiseBagFrame then A.RaiseBagFrame(f) end

    if InCombatLockdown and InCombatLockdown() then
        f:SetClampedToScreen(true)
    end

    if f.StartMoving then f:StartMoving() end
end


--- Drag stop: engine move → soft-clamp → save.
function A.GPHOnDragStop(f)
    if not f or not f._isDragging then return end

    if f.StopMovingOrSizing then
        f:StopMovingOrSizing()
    end
    f._isDragging = nil
    f:SetClampedToScreen(false)

    -- Engine clamp is off; nudge back on-screen after release (skips combat).
    local softClamped = A.SoftClampFrameToScreen and A.SoftClampFrameToScreen(f)

    local DB = _G.FugaziBAGSDB
    if DB then DB.gphDockedToMain = false end
    -- Free-float OFF + bank open: leave where user put it until next open/B (no re-center here).
    if DB and not DB.gphBankFreeFloat and A.Bank and A.Bank:IsShown() then
        -- skip save into gphPoint while bank-paired (dock owns placement)
    elseif A.SaveFrameLayout then
        A.SaveFrameLayout(f, "gphShown", "gphPoint")
    end

    if f.NegotiateSizes then f:NegotiateSizes() end

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

    -- Soft-clamp repositioned the frame: child GetWidth/GetHeight return stale
    -- values until the next render frame. Defer NegotiateSizes + full repaint
    -- by one frame so layout values have settled.
    if softClamped then
        if not f._gphSoftClampRepaint then
            f._gphSoftClampRepaint = CreateFrame("Frame", nil, f)
        end
        f._gphSoftClampRepaint:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            if f.NegotiateSizes then f:NegotiateSizes() end
            if A.RefreshGPHUI then
                f._refreshImmediate = true
                A.RefreshGPHUI(3)
            end
        end)
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
    -- Prefer last good layout; ignore tiny saved sizes (poisoned by bad auto path).
    local initW, initH = 340, 520
    if cg and cg.ComputeFrameSize then
        local gw, gh = cg.ComputeFrameSize()
        f.gphGridFrameW, f.gphGridFrameH = gw, gh
        if DB.gphListViewWidthAuto ~= false and gw and gw >= LIST_MIN_W then initW = gw end
        if DB.gphListViewHeightAuto ~= false and gh and gh >= LIST_MIN_H then
            initH = math.max(gh, DB.gphMinHeight or 420)
        end
    end
    if DB and DB.gphPoint and DB.gphPoint.w and DB.gphPoint.h
        and DB.gphPoint.w >= LIST_MIN_W and DB.gphPoint.h >= LIST_MIN_H then
        initW, initH = DB.gphPoint.w, DB.gphPoint.h
    end
    if DB.gphListViewWidthAuto == false and DB.gphListViewWidth and DB.gphListViewWidth > 0 then
        initW = DB.gphListViewWidth
    end
    if DB.gphListViewHeightAuto == false and DB.gphListViewHeight and DB.gphListViewHeight > 0 then
        initH = DB.gphListViewHeight
    end
    f:SetWidth(initW)
    f:SetHeight(initH)
    f._gphLastGoodListW, f._gphLastGoodListH = initW, initH
    if not f.gphGridFrameW then
        f.gphGridFrameW, f.gphGridFrameH = initW, initH
    end
    
    f:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
    f:Hide()
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(false)  -- OFF: avoids scale+clamp grab teleport; SoftClampFrameToScreen on drag stop instead

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) A.GPHOnDragStart(self) end)
    f:SetScript("OnDragStop", function(self) A.GPHOnDragStop(self) end)
    f:SetScript("OnHide", function()
        if not InCombatLockdown() then
            if f.gphDisenchantBtn then f.gphDisenchantBtn:Hide() end
            if f.gphProspectBtn then f.gphProspectBtn:Hide() end
            if f.gphMillingBtn then f.gphMillingBtn:Hide() end
            if f.gphOpenBtn then f.gphOpenBtn:Hide() end
        end
        if f.gphProxyFrame then f.gphProxyFrame:Hide() end
        -- Sticky search survives bag close/open; only Search button / Escape clears it.
        -- Just collapse the edit box so we don't reopen mid-type next show.
        f.gphSearchBarVisible = false
        if f.gphSearchEditBox then
            f.gphSearchEditBox:ClearFocus()
            f.gphSearchEditBox:Hide()
        end
        A.SaveFrameLayout(f, "gphShown", "gphPoint")
        if not f.gphGridMode and f.gphScrollBar then
            f.gphScrollOffset = 0
            f.gphScrollBar:SetMinMaxValues(0, 0)
            f.gphScrollBar:SetValue(0)
        end
    end)
    f._gphSkinAppliedOnFirstShow = nil  
    f:SetScript("OnShow", function()
        -- Critical chrome first (before heavy L3): levels + bottom bar text so the frame
        -- is interactive immediately after reload, not after MasterUpdate's 1s tick.
        if A.SyncFrameChromeLevels then A.SyncFrameChromeLevels(f) end
        if f.gphBottomLeft then
            local fps = math.floor(((GetFramerate and GetFramerate()) or 0) + 0.5)
            f._gphFpsShown = fps
            f.gphBottomLeft:SetText(("%d FPS"):format(fps))
            if date and f.gphBottomCenter then f.gphBottomCenter:SetText(date("%H:%M")) end
            if f.gphBottomRight then
                f.gphBottomRight:SetText(GetMoney and A.FormatGold and A.FormatGold(GetMoney()) or "")
            end
            f._gph_elapsed = 0
        end

        if not InCombatLockdown() then
            if f.gphDisenchantBtn then f.gphDisenchantBtn:SetScale(f:GetScale()) end
            if f.gphProspectBtn then f.gphProspectBtn:SetScale(f:GetScale()) end
            if f.gphMillingBtn then f.gphMillingBtn:SetScale(f:GetScale()) end
            if f.gphOpenBtn then f.gphOpenBtn:SetScale(f:GetScale()) end
        end
        if not InCombatLockdown() and f.gphProxyFrame then f.gphProxyFrame:Show() end
        -- One skin path (frame.ApplySkin OR skins module). L3 also skips when gen unchanged.
        -- First show after reload always needs skin (no _gphLastAppliedSkin yet).
        local Skins = _G.__FugaziBAGS_Skins
        local needSkin = (not A.FrameNeedsSkinApply) or A.FrameNeedsSkinApply(f)
        if needSkin then
            if f.ApplySkin then
                f:ApplySkin()
            elseif Skins and Skins.ApplyGPHFrameSkin then
                Skins.ApplyGPHFrameSkin(f)
            end
            if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(f) end
        end
        f._gphSkinAppliedOnFirstShow = true
        if f.UpdateGPHProfessionButtons then f:UpdateGPHProfessionButtons() end
        if needSkin and f.gphTitle and Skins and Skins.ApplyGphInventoryTitle then
            Skins.ApplyGphInventoryTitle(f.gphTitle)
        end

        f.gphScrollToDefaultOnNextRefresh = true
        f._gphHomebaseRetryScheduled = nil
        -- Always L3 chrome on open (size/layout). Pending bag-event L1 must not win here —
        -- that caused see-through/unskinned first open after reload.
        f._refreshLevel = 3
        if A.RefreshGPHUI then A.RefreshGPHUI(3)
        elseif RefreshGPHUI then RefreshGPHUI() end
        -- Sticky search chrome after skin/refresh (green btn / truncated label; size stays fixed).
        if A.Search and A.Search.UpdateChrome then
            A.Search.UpdateChrome()
        end
        -- Re-sync chrome after L3 (bag space / header levels can be reassigned there).
        if A.SyncFrameChromeLevels then A.SyncFrameChromeLevels(f) end
        -- Size retries: bag slot counts often incomplete on very early open after reload.
        -- Re-negotiate a few times so list auto grows to full footprint (not stuck tiny).
        -- Skip while dragging so retries never yank the frame mid-move.
        if not InCombatLockdown() then
            if not f._gphSizeRetry then
                f._gphSizeRetry = CreateFrame("Frame", nil, f)
                f._gphSizeRetry:Hide()
                f._gphSizeRetry:SetScript("OnUpdate", function(self, elapsed)
                    self._t = (self._t or 0) + elapsed
                    self._n = self._n or 0
                    -- fire at ~0, 0.15s, 0.5s, 1.0s
                    local need = (self._n == 0)
                        or (self._n == 1 and self._t >= 0.15)
                        or (self._n == 2 and self._t >= 0.5)
                        or (self._n == 3 and self._t >= 1.0)
                    if not need then return end
                    self._n = self._n + 1
                    if f:IsShown() and not f._isDragging
                        and not (InCombatLockdown and InCombatLockdown()) then
                        if f.NegotiateSizes then f:NegotiateSizes()
                        elseif A.NegotiateSizes then A.NegotiateSizes(f) end
                    end
                    if self._n >= 4 then
                        self:Hide()
                        self._t, self._n = 0, 0
                    end
                end)
            end
            f._gphSizeRetry._t, f._gphSizeRetry._n = 0, 0
            f._gphSizeRetry:Show()
        end
    end)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(20)
    f.EXPANDED_HEIGHT = 420

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
        if not (A.rarityDelStage and next(A.rarityDelStage)) and not (A.pendingQuality and next(A.pendingQuality)) and not (A.continuousDelStage and next(A.continuousDelStage)) then
            self._accum = 0
            return
        end
        self._accum = (self._accum or 0) + elapsed
        if self._accum < 0.5 then return end
        self._accum = 0
        local now = GetTime()
        local changed = false
        if A.rarityDelStage then
            for q, st in pairs(A.rarityDelStage) do
                if (now - (st.time or 0)) > 3 then
                    A.rarityDelStage[q] = nil
                    if A.pendingQuality then A.pendingQuality[q] = nil end
                    changed = true
                end
            end
        end
        if A.continuousDelStage then
            for q, st in pairs(A.continuousDelStage) do
                if (now - (st.time or 0)) > 3 then
                    A.continuousDelStage[q] = nil
                    if A.pendingQuality then A.pendingQuality[q] = nil end
                    changed = true
                end
            end
        end
        if A.pendingQuality then
            for q, t in pairs(A.pendingQuality) do
                if type(t) == "number" and (now - t) > 5 then
                    A.pendingQuality[q] = nil
                    changed = true
                end
            end
        end
        if changed then
            if f.gphEscCatcher then f.gphEscCatcher:ClearFocus(); f.gphEscCatcher:Hide() end
            f._refreshImmediate = true
            if A.RefreshGPHUI then A.RefreshGPHUI() end
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
        local wantGrid = A.GetPerChar("gphGridMode", true)
        local cg = _G.FugaziBAGS_CombatGrid
        -- Set mode BEFORE f:Show so OnShow → RefreshGPHUI(L3) paints the correct view
        -- and grid gphRef exists before the user can Ctrl+click bag-space.
        f.gphGridMode = wantGrid
        if not InCombatLockdown() then f:Show() end
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

    local function CreateProfessionButton(f, titleBar, btnName, iconPath, targetSpellName)
        local destroyBtn = CreateFrame("Button", btnName, f, "SecureActionButtonTemplate")
        destroyBtn:SetSize(22, 22) 
        destroyBtn:SetFrameLevel((f:GetFrameLevel() or 20) + 6)
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
        destroyIcon:SetTexture(iconPath)
        destroyIcon:SetAlpha(1.0)
        destroyBtn.icon = destroyIcon
        destroyBtn.targetSpellName = targetSpellName
        
        -- Clear secure attrs to a safe no-op (never leave a stale /use that can equip gear).
        local function ClearDestroySecure(self)
            self:SetAttribute("type1", "spell")
            self:SetAttribute("spell1", nil)
            self:SetAttribute("target-bag", nil)
            self:SetAttribute("target-slot", nil)
            self:SetAttribute("macrotext1", nil)
            self:SetAttribute("type1", "macro")
            self:SetAttribute("macrotext1", "")
        end

        local lastClickTime = 0
        destroyBtn:SetScript("PreClick", function(self, button, down)
            if InCombatLockdown and InCombatLockdown() then return end
            if A.IsPlayerDeadOrGhost and A.IsPlayerDeadOrGhost() then ClearDestroySecure(self); return end
            if button ~= "LeftButton" then ClearDestroySecure(self); return end

            -- Never fire a new cast while a destroy cast is in flight — that cancels/breaks
            -- the current DE. Spam clicks during cast = secure no-op.
            if A.IsDestroyCastBusy and A.IsDestroyCastBusy() then
                ClearDestroySecure(self); return
            end
            if UnitCastingInfo and UnitCastingInfo("player") then
                ClearDestroySecure(self); return
            end

            -- Chain-cast ready: previous cast finished (or stuck flag). Do NOT wipe all
            -- slot locks — only skip still-locked bag/slots so we never re-target the
            -- item currently being destroyed / just finished.
            if A.isDisenchanting then
                A.isDisenchanting = nil
                if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            end
            
            local now = GetTime()
            -- Snappy chain spam (was 0.5s — felt sticky when mashing the button).
            if now - lastClickTime < 0.12 then ClearDestroySecure(self); return end

            if SpellIsTargeting and SpellIsTargeting() then
                -- Abort leftover targeting without starting a new cast on this click.
                if SpellStopTargeting then SpellStopTargeting() end
                A.isDisenchanting = nil
                ClearDestroySecure(self); return
            end
            
            if (GetUnitSpeed and GetUnitSpeed("player") or 0) > 0 then ClearDestroySecure(self); return end
            if IsShiftKeyDown() then ClearDestroySecure(self); return end
            
            local bag, slot, spellName, itemLink = A.GetFirstDestroyableInBags(targetSpellName)
            -- bag 0 is backpack — must use == nil (not bag is true for 0 in Lua)
            if not spellName or bag == nil or slot == nil then ClearDestroySecure(self); return end
            
            local link = GetContainerItemLink(bag, slot)
            local itemId = link and tonumber(link:match("item:(%d+)"))
            
            lastClickTime = now
            A.isDisenchanting = true
            A._gphPendingDestroyLoot = true
            A.lockedDisenchantSlots = A.lockedDisenchantSlots or {}
            A.lockedDisenchantSlots[bag .. "_" .. slot] = now
            A.activeDisenchantSlot = { bag = bag, slot = slot, itemId = itemId, time = now }
            if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.StartSpotlightFade then
                _G.FugaziBAGS_CombatGrid.StartSpotlightFade(false)
            end
            -- Spell-on-bag-slot: NEVER /use the item. "/cast DE; /use bag slot" equips
            -- gear when the cast fails to start (spam on GCD) — BoE equip risk / DE gear.
            self:SetAttribute("macrotext1", nil)
            self:SetAttribute("type1", "spell")
            self:SetAttribute("spell1", spellName)
            self:SetAttribute("target-bag", bag)
            self:SetAttribute("target-slot", slot)

            if A.DimGPHListRow then A.DimGPHListRow(bag, slot, itemId) end
        end)
        
        destroyBtn:SetScript("OnEnter", function()
            if destroyBtn:GetAlpha() < 0.1 or (InCombatLockdown and InCombatLockdown()) or (A.IsPlayerDeadOrGhost and A.IsPlayerDeadOrGhost()) then return end
            if f.gphBtnHover then
                destroyBtn.bg:SetTexture(unpack(f.gphBtnHover))
            else
                destroyBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.9)
            end
            destroyIcon:SetAlpha(1)
            GameTooltip:SetOwner(destroyBtn, "ANCHOR_CURSOR")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(targetSpellName, 0.9, 0.8, 0.5)
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
        
        destroyBtn:SetScript("PostClick", function(self)
            -- Sound if we armed a spell target (not a no-op clear).
            if self:GetAttribute("spell1") and self:GetAttribute("target-bag") ~= nil then
                if A.PlayClickSound then A.PlayClickSound() end
            elseif self:GetAttribute("macrotext1") and self:GetAttribute("macrotext1") ~= "" then
                if A.PlayClickSound then A.PlayClickSound() end
            end
        end)
        
        return destroyBtn
    end
    -- Open/Learn MUST use SecureActionButtonTemplate.
    -- On Ascension, UseContainerItem is a protected call. Calling it from addon OnClick
    -- taints and BugGrabber reports "tainted the call of the secure function 'UNKNOWN()'".
    -- Sound/spotlight still run (insecure-safe); the actual open is blocked.
    -- Correct path (same as pre-Aug design): PreClick only SETS secure attributes; the
    -- button's secure handler then runs /use or type=item as part of the hardware click.
    -- Inventory rows work because they use ContainerFrameItemButtonTemplate (Blizzard secure),
    -- not addon Lua UseContainerItem.
    local function ClearOpenLearnSecure(self)
        self:SetAttribute("type1", "macro")
        self:SetAttribute("item1", nil)
        self:SetAttribute("macrotext1", "")
    end

    --- PreClick: set secure /use only. No soft-locks, no row dim, no UseContainerItem.
    local function ArmOpenLearnSecure(self, button, kind, finder, lastClickTimeRef)
        ClearOpenLearnSecure(self)
        if InCombatLockdown and InCombatLockdown() then return false end
        if A.IsPlayerDeadOrGhost and A.IsPlayerDeadOrGhost() then return false end
        if button ~= "LeftButton" then return false end

        if A.IsDestroyCastBusy and A.IsDestroyCastBusy() then return false end
        if UnitCastingInfo and UnitCastingInfo("player") then return false end
        if A.isDisenchanting then
            A.isDisenchanting = nil
        end

        local now = GetTime()
        if now - (lastClickTimeRef[1] or 0) < 0.12 then return false end

        if SpellIsTargeting and SpellIsTargeting() then
            if SpellStopTargeting then SpellStopTargeting() end
            A.isDisenchanting = nil
            return false
        end
        if IsShiftKeyDown() then return false end

        if not finder then return false end
        local bag, slot, texture = finder()
        -- backpack is bag 0 — use == nil, never `not bag`
        if bag == nil or slot == nil then return false end

        local tex, count = GetContainerItemInfo(bag, slot)
        tex = tex or texture
        if not tex then return false end
        -- Do not abort on client "locked" (true during loot spam) — that hid Open and
        -- blocked /use while boxes remained. Secure /use handles the slot.
        local link = GetContainerItemLink(bag, slot)
        local itemId = link and tonumber(link:match("item:(%d+)"))

        lastClickTimeRef[1] = now
        A.isDisenchanting = true
        A._gphPendingDestroyLoot = true
        -- No lockedDisenchantSlots for open/learn (DE only). Soft-locks made the button
        -- vanish while openables were still in bags.
        A.activeDisenchantSlot = { bag = bag, slot = slot, itemId = itemId, time = now, count = count, kind = kind }
        if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.StartSpotlightFade then
            _G.FugaziBAGS_CombatGrid.StartSpotlightFade(false)
        end
        -- Same list dim as DE (learn/open previously skipped this).
        if A.DimGPHListRow then A.DimGPHListRow(bag, slot, itemId) end

        self:SetAttribute("type1", "macro")
        self:SetAttribute("item1", nil)
        self:SetAttribute("macrotext1", ("/use %d %d"):format(bag, slot))
        return true
    end

    local function CreateOpenButton(f, titleBar)
        local openBtn = CreateFrame("Button", "FugaziBAGS_OpenBtn", f, "SecureActionButtonTemplate")
        openBtn:SetSize(22, 22)
        openBtn:SetFrameLevel((f:GetFrameLevel() or 20) + 6)
        openBtn:EnableMouse(true)
        openBtn:RegisterForClicks("AnyUp")
        openBtn:SetAttribute("type1", "macro")
        openBtn:SetAttribute("macrotext1", "")

        local openBg = openBtn:CreateTexture(nil, "BACKGROUND")
        openBg:SetAllPoints()
        openBg:SetTexture(0, 0, 0, 0)
        openBtn.bg = openBg

        local openIcon = openBtn:CreateTexture(nil, "OVERLAY", nil, 7)
        openIcon:SetAllPoints(openBtn)
        openIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        openIcon:SetTexture("Interface\\Icons\\inv_box_02")
        openIcon:SetAlpha(1.0)
        openBtn.icon = openIcon

        local lastClickTime = { 0 }
        openBtn:SetScript("PreClick", function(self, button, down)
            ArmOpenLearnSecure(self, button, "open", A.GetFirstOpenableInBags, lastClickTime)
        end)

        openBtn:SetScript("OnEnter", function()
            if openBtn:GetAlpha() < 0.1 or (InCombatLockdown and InCombatLockdown()) or (A.IsPlayerDeadOrGhost and A.IsPlayerDeadOrGhost()) then return end
            if f.gphBtnHover then
                openBtn.bg:SetTexture(unpack(f.gphBtnHover))
            else
                openBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.9)
            end
            openIcon:SetAlpha(1)
            GameTooltip:SetOwner(openBtn, "ANCHOR_CURSOR")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Open", 0.9, 0.8, 0.5)
            GameTooltip:Show()
        end)

        openBtn:SetScript("OnLeave", function()
            if f.gphBtnNormal then
                openBtn.bg:SetTexture(unpack(f.gphBtnNormal))
            else
                openBtn.bg:SetTexture(0.1, 0.3, 0.15, 0.7)
            end
            openIcon:SetAlpha(0.8)
            GameTooltip:Hide()
        end)

        openBtn:SetScript("PostClick", function(self)
            -- Armed if item1 or non-empty macro was set in PreClick.
            if (self:GetAttribute("item1") and self:GetAttribute("item1") ~= "")
                or (self:GetAttribute("macrotext1") and self:GetAttribute("macrotext1") ~= "") then
                if A.PlayClickSound then A.PlayClickSound() end
            end
        end)

        return openBtn
    end

    local function CreateLearnButton(f, titleBar)
        local learnBtn = CreateFrame("Button", "FugaziBAGS_LearnBtn", f, "SecureActionButtonTemplate")
        learnBtn:SetSize(22, 22)
        learnBtn:SetFrameLevel((f:GetFrameLevel() or 20) + 6)
        learnBtn:EnableMouse(true)
        learnBtn:RegisterForClicks("AnyUp")
        learnBtn:SetAttribute("type1", "macro")
        learnBtn:SetAttribute("macrotext1", "")

        local learnBg = learnBtn:CreateTexture(nil, "BACKGROUND")
        learnBg:SetAllPoints()
        learnBg:SetTexture(0, 0, 0, 0)
        learnBtn.bg = learnBg

        local learnIcon = learnBtn:CreateTexture(nil, "OVERLAY", nil, 7)
        learnIcon:SetAllPoints(learnBtn)
        learnIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        learnIcon:SetTexture("Interface\\Icons\\inv_scroll_03")
        learnIcon:SetAlpha(1.0)
        learnBtn.icon = learnIcon

        local lastClickTime = { 0 }
        learnBtn:SetScript("PreClick", function(self, button, down)
            ArmOpenLearnSecure(self, button, "learn", A.GetFirstLearnableInBags, lastClickTime)
        end)

        learnBtn:SetScript("OnEnter", function()
            if learnBtn:GetAlpha() < 0.1 or (InCombatLockdown and InCombatLockdown()) or (A.IsPlayerDeadOrGhost and A.IsPlayerDeadOrGhost()) then return end
            if f.gphBtnHover then
                learnBtn.bg:SetTexture(unpack(f.gphBtnHover))
            else
                learnBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.9)
            end
            learnIcon:SetAlpha(1)
            GameTooltip:SetOwner(learnBtn, "ANCHOR_CURSOR")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Learn", 0.9, 0.8, 0.5)
            GameTooltip:Show()
        end)

        learnBtn:SetScript("OnLeave", function()
            if f.gphBtnNormal then
                learnBtn.bg:SetTexture(unpack(f.gphBtnNormal))
            else
                learnBtn.bg:SetTexture(0.1, 0.3, 0.15, 0.7)
            end
            learnIcon:SetAlpha(0.8)
            GameTooltip:Hide()
        end)

        learnBtn:SetScript("PostClick", function(self)
            if (self:GetAttribute("item1") and self:GetAttribute("item1") ~= "")
                or (self:GetAttribute("macrotext1") and self:GetAttribute("macrotext1") ~= "") then
                if A.PlayClickSound then A.PlayClickSound() end
            end
        end)

        return learnBtn
    end

    f.gphDisenchantBtn = CreateProfessionButton(f, titleBar, "FugaziBAGS_DisenchantBtn", "Interface\\Icons\\inv_enchant_disenchant", "Disenchant")
    f.gphProspectBtn = CreateProfessionButton(f, titleBar, "FugaziBAGS_ProspectBtn", "Interface\\Icons\\inv_misc_gem_bloodgem_01", "Prospecting")
    f.gphMillingBtn = CreateProfessionButton(f, titleBar, "FugaziBAGS_MillingBtn", "Interface\\Icons\\ability_miling", "Milling")
    f.gphOpenBtn = CreateOpenButton(f, titleBar)
    f.gphLearnBtn = CreateLearnButton(f, titleBar)
    
    f.UpdateDestroyMacro = function() end

    local mailBtn = CreateFrame("Button", nil, titleBar)
    mailBtn:SetSize(22, 22) 
    mailBtn:SetFrameLevel((f:GetFrameLevel() or 20) + 6)
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

    f.gphMailBtn = mailBtn
    -- Behavior (Get All + husk cleanup, Send All confirm, tooltips) lives in Mail.lua.
    -- Frames only owns chrome; Setup is safe if Mail.lua loads after this file (toc order).
    if A.SetupGPHMailButton then
        A.SetupGPHMailButton(mailBtn, f)
    end
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
        -- Active filter or open bar → clear. Idle → open for typing.
        local hasFilter = A.Search and A.Search.IsActive and A.Search.IsActive()
        if hasFilter or f.gphSearchBarVisible then
            if A.Search and A.Search.Clear then
                A.Search.Clear(f)
            else
                f.gphSearchBarVisible = false
                f.gphSearchText = ""
                if f.gphSearchEditBox then
                    f.gphSearchEditBox:SetText("")
                    f.gphSearchEditBox:Hide()
                end
                if RefreshGPHUI then RefreshGPHUI() end
            end
            return
        end
        f.gphSearchBarVisible = true
        if f.gphSearchEditBox then
            f.gphSearchEditBox:Show()
            if A.Search and A.Search.RefreshPlaceholder then
                A.Search.RefreshPlaceholder(f.gphSearchEditBox)
            end
            f.gphSearchEditBox:SetFocus()
        end
    end)
    gphSearchBtn:SetScript("OnEnter", function(self)
        if A.PlayHoverSound then A.PlayHoverSound() end
        local q = f.gphSearchText
        if q and q ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Search filter active", 1, 0.82, 0)
            GameTooltip:AddLine("\"" .. q .. "\"", 0.45, 1, 0.55, true)
            GameTooltip:AddLine("Click Search to clear. Survives bag close/open.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        else
            -- Keep idle tip minimal; examples live as a watermark in the field.
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Search", 1, 0.82, 0)
            GameTooltip:Show()
        end
    end)
    gphSearchBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
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
    -- Enter = SET filter for farming (keep list filter, close the input).
    gphSearchEditBox:SetScript("OnEnterPressed", function(self)
        if A.Search and A.Search.Set then
            A.Search.Set(self:GetText(), f)
        else
            self:ClearFocus()
        end
    end)
    gphSearchEditBox:SetScript("OnEscapePressed", function(self)
        if A.Search and A.Search.Clear then
            A.Search.Clear(f)
        else
            self:ClearFocus()
            f.gphSearchBarVisible = false
            self:Hide()
            self:SetText("")
            f.gphSearchText = ""
            if RefreshGPHUI then RefreshGPHUI() end
        end
    end)
    -- Clicking away with text also SETs (stops the blinking caret / "waiting for input").
    gphSearchEditBox:SetScript("OnEditFocusLost", function(self)
        if not f.gphSearchBarVisible then return end
        local t = (self:GetText() or ""):match("^%s*(.-)%s*$") or ""
        if t ~= "" and A.Search and A.Search.Set then
            A.Search.Set(t, f)
        end
    end)
    gphSearchEditBox:SetScript("OnChar", function()
        local SV = _G.FugaziBAGSDB
        if SV and SV.gphClickSound ~= false and PlaySoundFile then
            PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\click.ogg")
        end
    end)
    gphSearchEditBox:SetScript("OnTextChanged", function(self, userInput)
        if A.Search and A.Search.UpdatePlaceholderVisibility then
            A.Search.UpdatePlaceholderVisibility(self)
        end
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
    f.gphSearchSet = false

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
    -- Forward plain drag on bag-space to the host frame (RegisterForDrag without a
    -- handler was eating LMB press path for drag on some post-reload frames).
    gphBagSpaceBtn:SetScript("OnDragStart", function()
        if IsControlKeyDown and IsControlKeyDown() then return end
        if A.GPHOnDragStart then A.GPHOnDragStart(f) end
    end)
    gphBagSpaceBtn:SetScript("OnDragStop", function()
        if A.GPHOnDragStop then A.GPHOnDragStop(f) end
    end)
    gphBagSpaceBtn:SetScript("OnClick", function(self, button)
        if IsControlKeyDown() and not IsAltKeyDown() and button == "LeftButton" then
            if A.PlayClickSound then A.PlayClickSound() end
            if f.gphGridMode then
                local cg = _G.FugaziBAGS_CombatGrid
                if cg and cg.ToggleBagBar then
                    cg.ToggleBagBar()
                elseif f.ToggleKeyringFrame then
                    -- Last-resort: at least open keyring if bag bar API not ready yet.
                    f:ToggleKeyringFrame()
                end
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
    f.ToggleKeyringFrame = function(self)
        self._keyringForcedShown = not self._keyringForcedShown
        if A.RefreshGPHUI then A.RefreshGPHUI() end
        if self.gphGridMode and self.LayoutGrid then
            self:LayoutGrid()
        end
    end

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
                btn.icon:SetTexture("Interface\\ContainerFrame\\KeyRing-Bag-Icon")
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
        local step = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphScrollStep) or 100
        local newScroll = (delta < 0) and math.min(maxScroll, cur + step) or math.max(0, cur - step)
        f.gphScrollOffset = newScroll
        if f.gphScrollBar then
            f.gphScrollBar:SetMinMaxValues(0, maxScroll)
            f.gphScrollBar:SetValue(newScroll)
            f._gphScrollMax = maxScroll
            f._gphScrollBarCur = newScroll
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, newScroll)
        f._scrollChildOffset = newScroll
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
            -- Do NOT NegotiateSizes every tick. That fought Listview content width
            -- (sf width vs frameW-44) and made stack counts / truncation jitter L/R.
            -- Size is owned by L3 RefreshGPHUI, options sliders, bank dock show/hide.
            if f.gphBagSpaceBtn then
                local hasItem = (GetCursorInfo and GetCursorInfo() == "item")
                if f.gphBagSpaceBtn.glow then if hasItem then f.gphBagSpaceBtn.glow:Show() else f.gphBagSpaceBtn.glow:Hide() end end
            end
        end
        gph_elapsed = (f._gph_elapsed or 0) + elapsed
        -- Match ElvUI System datatext: sample once per second, show raw GetFramerate.
        -- First paint is forced on OnShow so chrome is not blank for ~1s after reload.
        if gph_elapsed >= 1.0 then
            f._gph_elapsed = 0
            if f.gphBottomLeft then
                local fps = math.floor(((GetFramerate and GetFramerate()) or 0) + 0.5)
                if f._gphFpsShown ~= fps then
                    f._gphFpsShown = fps
                    f.gphBottomLeft:SetText(("%d FPS"):format(fps))
                end
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


function A.FadeButton(btn, targetAlpha, duration)
    if not btn then return end
    duration = duration or 0.15
    local currentAlpha = btn:GetAlpha()
    if math.abs(currentAlpha - targetAlpha) < 0.01 then
        btn:SetAlpha(targetAlpha)
        return
    end
    if btn._isFading and btn._currentTarget == targetAlpha then return end
    
    btn._isFading = true
    btn._currentTarget = targetAlpha
    local elapsed = 0
    local startAlpha = currentAlpha
    
    if not btn._fadeTimer then
        btn._fadeTimer = CreateFrame("Frame")
    end
    btn._fadeTimer:Show()
    btn._fadeTimer:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local progress = math.min(1, elapsed / duration)
        local alpha = startAlpha + (targetAlpha - startAlpha) * progress
        btn:SetAlpha(alpha)
        if progress >= 1 then
            btn:SetAlpha(targetAlpha)
            btn._isFading = false
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
end

-- List-view processing dim (DE / open / learn). Grid uses spotlight.
local LIST_ROW_DIM = 0.3
local LIST_ROW_RESTORE_DUR = 0.45

local function ListContent()
    local inv = A.Inventory
    local sf = inv and inv.scrollFrame
    return sf and sf:GetScrollChild() or nil
end

local function RowMatchesListDim(child, bag, slot, itemId)
    if not child or not child:IsShown() then return false end
    local cBag = child.bag or child.bagID
    local cSlot = child.slot or child.slotID
    local it = child.cachedItem
    if cBag == nil and it then
        cBag = it.bag or it.firstBag
        cSlot = it.slot or it.firstSlot
    end
    if bag ~= nil and slot ~= nil and cBag ~= nil and cSlot ~= nil and cBag == bag and cSlot == slot then
        return true
    end
    if itemId then
        local rowId = child.cachedItemId or child.itemId
            or (it and it.itemId)
            or (child.itemLink and tonumber(child.itemLink:match("item:(%d+)")))
            or (it and it.link and tonumber(it.link:match("item:(%d+)")))
        if rowId == itemId then return true end
    end
    return false
end

local function StopListRowFade(child)
    if child and child._listDimTimer then
        child._listDimTimer:SetScript("OnUpdate", nil)
        child._listDimTimer:Hide()
    end
    if child then child._listDimFading = nil end
end

function A.ClearAllGPHListRowDims()
    local content = ListContent()
    if not content then return end
    for i = 1, content:GetNumChildren() do
        local child = select(i, content:GetChildren())
        if child and child.SetAlpha then
            StopListRowFade(child)
            child._listDimActive = nil
            child:SetAlpha(1)
        end
    end
end

--- Dim target row for the whole cast/use. One dim only (clears previous first).
function A.DimGPHListRow(bag, slot, itemId)
    A.ClearAllGPHListRowDims()
    local content = ListContent()
    if not content then return end
    for i = 1, content:GetNumChildren() do
        local child = select(i, content:GetChildren())
        if RowMatchesListDim(child, bag, slot, itemId) then
            child._listDimActive = true
            child:SetAlpha(LIST_ROW_DIM)
            return
        end
    end
end

--- Ease target row back up; hard-clear every other row. Used for DE + learn + open.
function A.FadeRestoreGPHListRows(bag, slot, itemId, kind)
    local content = ListContent()
    if not content then return end
    local target
    for i = 1, content:GetNumChildren() do
        local child = select(i, content:GetChildren())
        if child and child.SetAlpha then
            if RowMatchesListDim(child, bag, slot, itemId) then
                target = child
            else
                StopListRowFade(child)
                child._listDimActive = nil
                child:SetAlpha(1)
            end
        end
    end
    if not target then
        A.ClearAllGPHListRowDims()
        return
    end
    StopListRowFade(target)
    target._listDimActive = nil
    local startA = target:GetAlpha() or LIST_ROW_DIM
    if startA >= 0.99 then
        target:SetAlpha(1)
        return
    end
    target._listDimFading = true
    if not target._listDimTimer then
        target._listDimTimer = CreateFrame("Frame")
    end
    local elapsed = 0
    local timer = target._listDimTimer
    timer:Show()
    timer:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local p = math.min(1, elapsed / LIST_ROW_RESTORE_DUR)
        target:SetAlpha(startA + (1 - startA) * p)
        if p >= 1 then
            target:SetAlpha(1)
            target._listDimFading = nil
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
end

--- Update visibility of top bar buttons (Destroy/Mail/Open/Learn).
function A.UpdateGPHProfessionButtons(f, forceDisabled)
    if not f then return end
    local titleBar = f.gphTitleBar
    if not titleBar then return end

    local isDead = (A.IsPlayerDeadOrGhost and A.IsPlayerDeadOrGhost()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
    local inCombat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))
    if forceDisabled ~= nil then
        if forceDisabled then
            inCombat = true
        else
            inCombat = false
            isDead = false
        end
    end
    local isDisabled = isDead or inCombat

    local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    local hasMilling = A.IsSpellKnownByName and A.IsSpellKnownByName("Milling")
    local isAtMail = (_G.MailFrame and _G.MailFrame:IsShown())

    -- Open/learn visibility needs a fresh bag scan. Listview L1 can run before Core
    -- dirties the destroyable cache → open button stayed hidden until close/open bags.
    if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end

    -- Destroyer may not be present yet if namespace/load order is wrong; never hard-error chrome.
    local bag, slot, texture
    if A.GetFirstOpenableInBags then
        bag, slot, texture = A.GetFirstOpenableInBags()
    end
    local hasOpenable = (bag ~= nil)
    
    if hasOpenable and f.gphOpenBtn and f.gphOpenBtn.icon then
        f.gphOpenBtn.icon:SetTexture(texture)
    end

    local lbag, lslot, ltexture
    if A.GetFirstLearnableInBags then
        lbag, lslot, ltexture = A.GetFirstLearnableInBags()
    end
    local hasLearnable = (lbag ~= nil)
    
    if hasLearnable and f.gphLearnBtn and f.gphLearnBtn.icon then
        f.gphLearnBtn.icon:SetTexture(ltexture)
    end

    local lastBtn = nil
    local anchorToLeft = true
    
    local function anchorBtn(btn, condition)
        if not btn then return end
        if condition then
            if not inCombat then
                btn:ClearAllPoints()
                if anchorToLeft then
                    btn:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
                    anchorToLeft = false
                else
                    btn:SetPoint("LEFT", lastBtn, "RIGHT", 8, 0)
                end
                btn:Show()
            end
            lastBtn = btn
            if isDisabled then
                A.FadeButton(btn, 0, 0.15)
            else
                A.FadeButton(btn, 1.0, 0.15)
            end
        else
            if not inCombat then
                btn:Hide()
            else
                A.FadeButton(btn, 0, 0.15)
            end
        end
    end
    
    anchorBtn(f.gphDisenchantBtn, hasDE)
    anchorBtn(f.gphProspectBtn, hasProspect)
    anchorBtn(f.gphMillingBtn, hasMilling)
    anchorBtn(f.gphOpenBtn, hasOpenable)
    anchorBtn(f.gphLearnBtn, hasLearnable)
    
    if f.gphMailBtn then
        if isAtMail then
            if not inCombat then
                f.gphMailBtn:ClearAllPoints()
                if anchorToLeft then f.gphMailBtn:SetPoint("LEFT", titleBar, "LEFT", 8, 0) 
                else f.gphMailBtn:SetPoint("LEFT", lastBtn, "RIGHT", 8, 0) end
                f.gphMailBtn:Show()
            end
            if isDisabled then
                A.FadeButton(f.gphMailBtn, 0, 0.15)
            else
                A.FadeButton(f.gphMailBtn, 1.0, 0.15)
            end
            if A.UpdateGPHMailButtonIcon then A.UpdateGPHMailButtonIcon() end
        else
            if not inCombat then f.gphMailBtn:Hide() else A.FadeButton(f.gphMailBtn, 0, 0.15) end
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
    
    local active = not btn.isBankBtn and A.continuousDelActive and A.continuousDelActive[q]
    local contStage = not btn.isBankBtn and A.continuousDelStage and A.continuousDelStage[q]
    local burstStage = not btn.isBankBtn and A.rarityDelStage and A.rarityDelStage[q]
    local isPending = not btn.isBankBtn and A.pendingQuality and A.pendingQuality[q]
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
            if isPending and type(isPending) == "number" and (now - isPending) > 5.0 then A.pendingQuality[q] = nil end
            local f = A.GetRarityBtnHostFrame and A.GetRarityBtnHostFrame(btn) or btn:GetParent()
            local filter = A.GetFilterQualities and A.GetFilterQualities(f) or nil
            A.UpdateRarityBtnVisual(f, btn, q, filter)
        end
    else
        -- Standard States (Restore font/color)
        if btn.labelFs then
            btn.labelFs:SetFont("Fonts\\FRIZQT__.TTF", 8, "") 
        end
        local f = A.GetRarityBtnHostFrame and A.GetRarityBtnHostFrame(btn) or btn:GetParent()
        local isFiltered = A.IsQualityFilterSelected and A.IsQualityFilterSelected(f, q)
        local isHovered = btn._isHovered
        if btn.labelFs then
            if isHovered or isFiltered or isProtected then
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
                
                if isFiltered then
                    r, g, b = math.min(1, r * 1.6), math.min(1, g * 1.6), math.min(1, b * 1.6)
                    pulse = pulse + 0.15
                end
                btn.bg:SetVertexColor(r, g, b, pulse)
            end

            if btn.rarityBorderTop then
                btn.rarityBorderTop:Show()
                btn.rarityBorderBottom:Show()
                btn.rarityBorderLeft:Show()
                btn.rarityBorderRight:Show()
                btn.rarityBorderTop:SetVertexColor(1, 1, 1, bPulse)
                btn.rarityBorderBottom:SetVertexColor(1, 1, 1, bPulse)
                btn.rarityBorderLeft:SetVertexColor(1, 1, 1, bPulse)
                btn.rarityBorderRight:SetVertexColor(1, 1, 1, bPulse)
            end
        else
            -- Borders may still exist after unprotect — hide so filter glow can work.
            if btn.rarityBorderTop then
                btn.rarityBorderTop:Hide()
                btn.rarityBorderBottom:Hide()
                btn.rarityBorderLeft:Hide()
                btn.rarityBorderRight:Hide()
            end
            if btn.bg then
                local info = (A.QUALITY_COLORS and A.QUALITY_COLORS[q]) or { r = 0.5, g = 0.5, b = 0.5 }
                local r, g, b = info.r or 0.5, info.g or 0.5, info.b or 0.5
                if q == 0 then r, g, b = 0.58, 0.58, 0.58 elseif q == 1 then r, g, b = 0.96, 0.96, 0.96 end
                local alpha = 0.35
                if isFiltered then
                    r = math.min(1, r * 2.2)
                    g = math.min(1, g * 2.2)
                    b = math.min(1, b * 2.2)
                    alpha = 0.95
                end
                btn.bg:SetVertexColor(r, g, b, alpha)
            end
        end
        
        -- Restore original text if label visible
        if btn.labelFs and btn.labelFs:GetAlpha() > 0 then
            local count = btn.currentCount or 0
            btn.labelFs:SetText(count > 0 and count or "")
        end
    end

    local f = A.GetRarityBtnHostFrame and A.GetRarityBtnHostFrame(btn)
    local isBank = btn.isBankBtn or (f and (f.isBankFrame or f._isBankFrame))

    -- Filter drag-paint across buttons
    if A._filterDragInitiated and not IsAltKeyDown() and not IsControlKeyDown()
        and IsMouseButtonDown and IsMouseButtonDown("LeftButton") and MouseIsOver(btn) then
        if A.IsQualityFilterSelected(f, btn.quality) ~= A._filterDragValue then
            A.SetQualityFilter(f, btn.quality, A._filterDragValue)
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
    if A._filterDragInitiated and (not IsMouseButtonDown("LeftButton") or IsAltKeyDown() or IsControlKeyDown()) then
        A._filterDragInitiated = nil
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
A.RegisteredUpdaters["RarityPulse"] = A.UpdateAllRarityVisuals
