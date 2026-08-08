local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon

-- Fetch DB dynamically inside functions to avoid stale reference issues with SavedVariables.

local MAIN_BANK_SLOTS = 28
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 6
local BANK_LIST_WIDTH = 296
local BANK_HEADER_HEIGHT = 18


-- Forward declarations for local functions
local GetBankMainContainer, ResetBankDataPools

local function FB_GetPurchasedBankBags() return A.FB_GetPurchasedBankBags() end
local function FB_GetNextBankSlotCost() return A.FB_GetNextBankSlotCost() end

--- Build bank frame (list/grid of bank slots, like default bank UI).
function CreateBankFrame(invFrame)
	local existing = A.Bank
	if existing and existing.content then
		return existing
	end
	A.Bank = nil

	local backdrop = {
		bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile     = true, tileSize = 32, edgeSize = 24,
		insets   = { left = 2, right = 6, top = 6, bottom = 6 },
	}
	
	
	local f = CreateFrame("Frame", "BankMainFrame", UIParent)
	A.Bank = f
	f._isBankFrame = true
	f:SetWidth(340)
	f:SetHeight(520)
	f:Hide()
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(f, "Main")
    else
        f:SetBackdrop(backdrop)
        f:SetBackdropColor(0.08, 0.08, 0.12, 0.92)
        f:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
    end
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(false)  -- OFF: avoids scale+clamp grab teleport; SoftClampFrameToScreen on drag stop instead
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function()
		if f._isDragging then return end
		f._isDragging = true
		if A.RaiseBagFrame then A.RaiseBagFrame(f) end
		if InCombatLockdown and InCombatLockdown() then
			f:SetClampedToScreen(true)
		end
		f:StartMoving()
	end)
	f:SetScript("OnDragStop", function()
		if not f._isDragging then return end
		f:StopMovingOrSizing()
		f._isDragging = nil
		f:SetClampedToScreen(false)
		if A.SoftClampFrameToScreen then A.SoftClampFrameToScreen(f) end
		local inv = A.Inventory
		local DB = _G.FugaziBAGSDB
		-- Free-float OFF: allow temporary drag; re-dock only on open/B, not drag stop.
		if DB and not DB.gphBankFreeFloat then
			-- leave session position until next open
		else
			if inv and inv.NegotiateSizes then inv:NegotiateSizes() end
			if A.SaveFrameLayout then A.SaveFrameLayout(f, "frameShown", "framePoint") end
		end
	end)
    f:SetScript("OnHide", function()
        local inv = A.Inventory
        local freeFloat = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphBankFreeFloat
        if inv and not freeFloat and inv._gphPreBankAnchor then
            local p, r, rp, x, y = unpack(inv._gphPreBankAnchor)
            if p and rp and x and y then
                inv:ClearAllPoints()
                inv:SetPoint(p, r or UIParent, rp, x, y)
            end
            inv._gphPreBankAnchor = nil
            inv._gphRestoredFromBankOnHide = true
        end
    end)
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(20)

    
    
    

	local function placeCursorInFirstFreeBankSlot()
		local mainBank = (GetBankMainContainer and GetBankMainContainer()) or -1
		if mainBank == nil then return false end
		for slot = 1, (GetContainerNumSlots(mainBank) or 28) do
			if not (GetContainerItemLink and GetContainerItemLink(mainBank, slot)) then
				if PickupContainerItem then PickupContainerItem(mainBank, slot) end
				if RefreshBankUI then RefreshBankUI() end
				return true
			end
		end
		for i = 1, (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6) do
			local bagID = (NUM_BAG_SLOTS or 4) + i
			local numSlots = GetContainerNumSlots and GetContainerNumSlots(bagID) or 0
			for slot = 1, numSlots do
				if not (GetContainerItemLink and GetContainerItemLink(bagID, slot)) then
					if PickupContainerItem then PickupContainerItem(bagID, slot) end
					if RefreshBankUI then RefreshBankUI() end
					return true
				end
			end
		end
		return false
	end

	
	local bankMenu = CreateFrame("Frame", "FugaziBAGS_BankMenu", f, "UIDropDownMenuTemplate")
	local function BankTitleMenu_Initialize(self, level)
		local info = UIDropDownMenu_CreateInfo()
		local SV = _G.FugaziBAGSDB
		if not level or level == 1 then
            
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cffff4444Close Bank|r"
            info.func = function()
                if A.Bank and A.Bank:IsShown() then
                    A.Bank:Hide()
                    if CloseBank then CloseBank() end
                end
                CloseDropDownMenus()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)

             info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)
             
             info = UIDropDownMenu_CreateInfo()
             info.text = "|cff00aaffClean up Bank|r"
             info.func = function()
                 if A.GPH_BagSort_Run and GetBankMainContainer then
                     local mainBank = GetBankMainContainer()
                     local list = { mainBank }
                     for i = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6) do 
                         list[#list + 1] = i 
                     end
                     A.GPH_BagSort_Run(function()
                         if RefreshBankUI then RefreshBankUI() end
                         local cg = _G.FugaziBAGS_CombatGrid
                         if cg and cg.BankLayoutGrid then cg.BankLayoutGrid() end
                     end, "bank", list)
                 end
                 CloseDropDownMenus()
             end
             info.notCheckable = true
             UIDropDownMenu_AddButton(info)

             info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)

             if not f.gphGridMode then
                 info = UIDropDownMenu_CreateInfo()
                 info.text = "Sort"
                 info.hasArrow = true
                 info.value = "SORT_BANK"
                 info.notCheckable = true
                 UIDropDownMenu_AddButton(info)
             end

             info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)

             local bankGridMode = A.GetPerChar("gphBankGridMode", true)
             info = UIDropDownMenu_CreateInfo()
             info.text = (not f.gphGridMode) and "|cff00ff00List View|r" or "List View"
             info.checked = not f.gphGridMode
             info.func = function()
                 A.SetPerChar("gphBankGridMode", false)
                 f.gphGridMode = false
                 local cg = _G.FugaziBAGS_CombatGrid
                 if cg and cg.HideInBankFrame then cg.HideInBankFrame(f) end
                 if RefreshBankUI then RefreshBankUI() end
                 if f.NegotiateSizes then f:NegotiateSizes() end
                 CloseDropDownMenus()
             end
             UIDropDownMenu_AddButton(info)
             
             info = UIDropDownMenu_CreateInfo()
             info.text = f.gphGridMode and "|cff00ff00Grid View|r" or "Grid View"
             info.checked = f.gphGridMode
             info.func = function()
                 A.SetPerChar("gphBankGridMode", true)
                 f.gphGridMode = true
                 local cg = _G.FugaziBAGS_CombatGrid
                 if cg and cg.ShowInBankFrame then cg.ShowInBankFrame(f) end
                 if RefreshBankUI then RefreshBankUI() end
                 if f.NegotiateSizes then f:NegotiateSizes() end
                 CloseDropDownMenus()
             end
             UIDropDownMenu_AddButton(info)

		elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "SORT_BANK" then
			local modes = {}
			local isAsc = A.IsAscension and A.IsAscension()
			table.insert(modes, { val = "rarity", text = "Rarity" })
			if not isAsc then
				table.insert(modes, { val = "vendor", text = "Vendorprice" })
				table.insert(modes, { val = "itemlevel", text = "ItemLvl" })
			end
			table.insert(modes, { val = "category", text = "Category" })

			local curSV = _G.FugaziBAGSDB or {}
			for _, m in ipairs(modes) do
				info = UIDropDownMenu_CreateInfo()
				info.text = m.text
				info.checked = (curSV.gphSortMode == m.val)
				info.func = function()
					_G.FugaziBAGSDB = _G.FugaziBAGSDB or {}
					_G.FugaziBAGSDB.gphSortMode = m.val
					if f.UpdateBankSortIcon then f:UpdateBankSortIcon() end
					if RefreshBankUI then RefreshBankUI() end
					CloseDropDownMenus()
				end
				UIDropDownMenu_AddButton(info, level)
			end
		end
	end

	
	local titleBar = CreateFrame("Button", nil, f)
	titleBar:SetHeight(30)
	titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
	titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(titleBar, "Header")
    else
        titleBar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        titleBar:SetBackdropColor(0.35, 0.28, 0.1, 0.7)
    end
	titleBar:RegisterForClicks("RightButtonUp")
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function()
        if f._isDragging then return end
        f._isDragging = true
        if A.RaiseBagFrame then A.RaiseBagFrame(f) end
        if InCombatLockdown and InCombatLockdown() then
            f:SetClampedToScreen(true)
        end
        f:StartMoving()
    end)
	titleBar:SetScript("OnDragStop", function()
        if not f._isDragging then return end
		f:StopMovingOrSizing()
		f._isDragging = nil
		f:SetClampedToScreen(false)
		if A.SoftClampFrameToScreen then A.SoftClampFrameToScreen(f) end
		local inv = A.Inventory
		local DB = _G.FugaziBAGSDB
		-- Free-float OFF: temp drag OK; re-dock only on open/B.
		if DB and not DB.gphBankFreeFloat then
			-- leave session position
		else
			if inv and inv.NegotiateSizes then inv:NegotiateSizes() end
			A.SaveFrameLayout(f, "frameShown", "framePoint")
		end
	end)
	titleBar:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			UIDropDownMenu_Initialize(bankMenu, BankTitleMenu_Initialize, "MENU")
			ToggleDropDownMenu(1, nil, bankMenu, "cursor", 0, 0)
		end
	end)
	f.titleBar = titleBar
	local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
	title:SetText((UnitName and UnitName("target")) or "Bank")
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(title, "Text", "Header")
    else
	    title:SetTextColor(1, 0.85, 0.4, 1)
    end
	f.bankTitleText = title

	
	local titleFrameLevel = f:GetFrameLevel() + 25

	local sep = f:CreateTexture(nil, "ARTWORK")
	sep:SetHeight(1)
	sep:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -6)
	sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -6)
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(sep, "Divider")
    else
        sep:SetTexture(1, 1, 1, 0.15)
    end
	f.sep = sep


	
	local bagRow = CreateFrame("Frame", nil, f)
    -- Relocated to Bottom Left per User Request (Matches Inventory style)
	bagRow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
	bagRow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
	bagRow:SetHeight(0)
	bagRow:SetFrameLevel(f:GetFrameLevel() + 5)
	bagRow:EnableMouse(false)  
	f.bagRow = bagRow
	f.bagRowVisible = false
	bagRow:SetAlpha(0)
	bagRow:Hide()
	f.bagSlots = {}
	for i = 1, NUM_BANK_BAGS do
		local bagID = (NUM_BAG_SLOTS or 4) + i
		local btn = A.CreateBagBarButton(bagRow, ("TestBankBag%d"):format(i), bagID, function(self, button)
			if A.PlayClickSound then A.PlayClickSound() end
			local cursorType = GetCursorInfo and GetCursorInfo()
			if (not cursorType or cursorType == "") and button == "LeftButton" then
				local purchased = FB_GetPurchasedBankBags()
				if i == purchased + 1 then
					StaticPopup_Show("FUGAZI_BUY_BANK_SLOT")
					return
				end
			end

			if cursorType == "item" and PutItemInBag and ContainerIDToInventoryID and self.bagID then
				local invID = ContainerIDToInventoryID(self.bagID)
				if invID and invID > 0 then PutItemInBag(invID) end
			elseif not cursorType or cursorType == "" then
				local invID = self.bagID and ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
				if invID and invID > 0 and PickupInventoryItem then
					PickupInventoryItem(invID)
				end
			end
			if RefreshBankUI then RefreshBankUI() end
		end)
		btn:SetPoint("LEFT", bagRow, "LEFT", (i - 1) * 24, 0)
		btn:SetScript("OnDragStart", function(self)
			local cursorType = GetCursorInfo and GetCursorInfo()
			if not cursorType or cursorType == "" then
				local invID = self.bagID and ContainerIDToInventoryID and ContainerIDToInventoryID(self.bagID)
				if invID and invID > 0 and PickupInventoryItem then
					PickupInventoryItem(invID)
				end
			end
		end)
		btn:SetScript("OnReceiveDrag", function(self)
			local cursorType = GetCursorInfo and GetCursorInfo()
			if cursorType == "item" and PutItemInBag and ContainerIDToInventoryID and self.bagID then
				local invID = ContainerIDToInventoryID(self.bagID)
				if invID and invID > 0 then PutItemInBag(invID) end
			end
		end)
		btn:SetScript("OnEnter", function(self)
			if A.PlayHoverSound then A.PlayHoverSound() end
			local numSlots = GetContainerNumSlots and GetContainerNumSlots(self.bagID) or 0
			local purchased = FB_GetPurchasedBankBags()
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			if i <= purchased then
				GameTooltip:SetText("Bank bag " .. i .. " (" .. numSlots .. " slots)")
			elseif i == purchased + 1 then
				local cost = select(1, FB_GetNextBankSlotCost())
				GameTooltip:SetText("Bank bag " .. i .. " (not purchased)")
				if cost and cost > 0 and SetTooltipMoney then
					SetTooltipMoney(GameTooltip, cost)
				end
			else
				GameTooltip:SetText("Bank bag " .. i .. " (locked)")
			end
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.bagSlots[i] = btn
	end

	
	
	f.bankRarityFilter = nil
	local BANK_HEADER_Y_OFF = -(6 + 20 + 4)  
	local bankHeader = CreateFrame("Frame", nil, f)
	bankHeader:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 6, BANK_HEADER_Y_OFF)
	bankHeader:SetPoint("TOPRIGHT", sep, "TOPRIGHT", -6, BANK_HEADER_Y_OFF)
	bankHeader:SetHeight(18)
	f.bankHeader = bankHeader
	local bankSpaceBtn = A.CreateBagSpaceIndicator(f, bankHeader, true)
    
	bankSpaceBtn:SetPoint("BOTTOMLEFT", bankHeader, "BOTTOMLEFT", 0, 8)
    bankSpaceBtn:SetScript("OnClick", function(self, button)
		if A.PlayClickSound then A.PlayClickSound() end
		
		if IsControlKeyDown() and not IsAltKeyDown() then
			if f.bagRow then
				f.bagRowVisible = not f.bagRowVisible
				local BANK_BAG_ROW_H = 20
				if f.bagRowVisible then
					f.bagRow:SetHeight(BANK_BAG_ROW_H)
					f.bagRow:SetAlpha(1)
					f.bagRow:Show()
					-- Pushes the list up to make room
					if f.scrollFrame then
						f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 38)
					end
				else
					f.bagRow:SetHeight(0)
					f.bagRow:SetAlpha(0)
					f.bagRow:Hide()
					-- Restore list to bottom
					if f.scrollFrame then
						f.scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 6)
					end
				end
				if RefreshBankUI then RefreshBankUI() end
			end
			return
		end

		
		if GetCursorInfo and GetCursorInfo() == "item" then
			placeCursorInFirstFreeBankSlot()
			return
		end
	end)
	local bankSpaceFs = bankSpaceBtn.fs
	local bankSpaceGlow = bankSpaceBtn.glow
	

	
	local function getFirstFreeBankSlot()
		local mainBank = GetBankMainContainer()
		if not mainBank then return nil, nil end
		for slot = 1, MAIN_BANK_SLOTS do
			local _, _, locked = GetContainerItemInfo(mainBank, slot)
			if not (GetContainerItemLink and GetContainerItemLink(mainBank, slot)) and not locked then
				return mainBank, slot
			end
		end
		for i = 1, NUM_BANK_BAGS do
			local bagID = (NUM_BAG_SLOTS or 4) + i
			local numSlots = GetContainerNumSlots and GetContainerNumSlots(bagID) or 0
			for slot = 1, numSlots do
				local _, _, locked = GetContainerItemInfo(bagID, slot)
				if not (GetContainerItemLink and GetContainerItemLink(bagID, slot)) and not locked then
					return bagID, slot
				end
			end
		end
		return nil, nil
	end
	
	local function getFirstFreeBagSlot()
		for bag = 0, 4 do
			local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
			if numSlots then
				for slot = 1, numSlots do
					local _, _, locked = GetContainerItemInfo(bag, slot)
					if not (GetContainerItemLink and GetContainerItemLink(bag, slot)) and not locked then
						return bag, slot
					end
				end
			end
		end
		return nil, nil
	end
	

	f.PlaceCursorInFirstFreeBankSlot = placeCursorInFirstFreeBankSlot
	f.GetFirstFreeBankSlot = getFirstFreeBankSlot
	f.GetFirstFreeBagSlot = getFirstFreeBagSlot

	bankSpaceBtn:SetScript("OnReceiveDrag", function() placeCursorInFirstFreeBankSlot() end)
	f.bankSpaceFs = bankSpaceFs
	f.bankSpaceBtn = bankSpaceBtn
	

	f.UpdateBankQualBtnVisual = function(bf, btn, q)
		local filter = A.GetFilterQualities and A.GetFilterQualities(bf) or bf.bankRarityFilter
		A.UpdateRarityBtnVisual(bf, btn, q, filter)
	end

	f.noProtection = true -- Safe Harbor: No marking or deletion in the Bank!
	f.isBankFrame = true -- Isolated refresh for Bank only
	
	-- Bank-Specific Click Handler (Safe Zone)
	-- Plain LMB filter is on MouseDown (+ drag multi-filter); RMB clears; Shift+RMB moves.
	local qualBtnOnClickHandler = function(self, button)
		if A.PlayClickSound then A.PlayClickSound() end
		local shift = IsShiftKeyDown and IsShiftKeyDown()
		local ctrl = IsControlKeyDown and IsControlKeyDown()
		local alt = IsAltKeyDown and IsAltKeyDown()
		if shift and button == "RightButton" then
			if A.StartRarityMoveJob then
				A.StartRarityMoveJob("bank_to_bags", self.quality, nil)
			else
				A.RarityMoveJob = { mode = "bank_to_bags", rarity = self.quality }
				if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
			end
			return
		end
		if button == "LeftButton" and not shift and not ctrl and not alt then
			-- Filter already applied on MouseDown; avoid double-toggle.
			return
		end
		if button == "RightButton" and not shift and not ctrl and not alt then
			if A.ClearQualityFilters then
				A.ClearQualityFilters(f)
			else
				f.bankRarityFilter = nil
				f.gphFilterQuality = nil
				f.gphFilterQualities = nil
			end
			f._bankForceFull = true
			if f.gphGridMode then f._bankGridForceFull = true end
			if _G.RefreshBankUI then _G.RefreshBankUI() end
		end
	end

	-- Bank-Specific Tooltip Handler
	f.qualityOnEnter = function(self)
		self.helpLines = {
			{ "LMB: Filter quality (drag to multi-filter)", 1, 1, 1 },
			{ "Shift+RMB: Move rarity to Bags", 0.6, 1.0, 0.6 }
		}
		A.GPHQualBtn_OnEnter(self)
	end

	-- Shared Rarity Bar Layout (Bank)
	A.LayoutRarityBar(f, bankHeader, qualBtnOnClickHandler)

	-- Register resize hook
	if not bankHeader._fugaziBankLayoutHooked then
		bankHeader._fugaziBankLayoutHooked = true
		bankHeader:HookScript("OnSizeChanged", function() 
			A.LayoutRarityBar(f, bankHeader, qualBtnOnClickHandler)
            if RefreshBankUI then RefreshBankUI() end
		end)
	end

	
	f.bankScrollOffset = 0
	local scroll = CreateFrame("ScrollFrame", "FugaziBAGS_BankScrollFrameGPH", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", bankHeader, "BOTTOMLEFT", 0, -14) 
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 20)
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.SkinScrollBar then
        _G.__FugaziBAGS_Skins.SkinScrollBar(scroll)
    end
	local scrollBar = scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"] or nil

	if scrollBar then
		scrollBar:SetScript("OnValueChanged", function(_, value)
			f.bankScrollOffset = value
			local content = scroll:GetScrollChild()
			if content then
				content:ClearAllPoints()
				content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, value)
			end
		end)
	end
	local content = CreateFrame("Frame", nil, scroll)
	content:SetWidth(BANK_LIST_WIDTH)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	content:ClearAllPoints()
	content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
	f.content = content
	f.scrollFrame = scroll
	f.scrollBar = scrollBar
	if scrollBar then
		hooksecurefunc(content, "SetHeight", function()
			local viewH = scroll:GetHeight()
			local contentH = content:GetHeight()
			scrollBar:SetMinMaxValues(0, math.max(0, contentH - viewH))
		end)
	end
	local function doScrollWheel(delta)
		A.HandleMouseWheel(scroll, delta, f, "bankScrollOffset", nil, nil)
	end
	content:SetScript("OnMouseWheel", function(self, delta) doScrollWheel(delta) end)
	scroll:SetScript("OnMouseWheel", function(self, delta) doScrollWheel(delta) end)
	scroll.BankOnMouseWheel = function(delta) doScrollWheel(delta) end
	A.Bank = f
	if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(f) end
	f.ApplySkin = function() if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(f) end end
	return f
end

--- Get main bank container (reagent bank etc).
GetBankMainContainer = function()
	if BANK_CONTAINER ~= nil then
		local n = GetContainerNumSlots and GetContainerNumSlots(BANK_CONTAINER)
		if n and n > 0 then return BANK_CONTAINER end
	end
	for _, id in ipairs({ -1, -2, 5 }) do
		local n = GetContainerNumSlots and GetContainerNumSlots(id)
		if n and n > 0 then return id end
	end
	if A.Bank and A.Bank:IsShown() then
		return (BANK_CONTAINER ~= nil) and BANK_CONTAINER or 5
	end
	return nil
end
A.GetBankMainContainer = GetBankMainContainer
_G.GetBankMainContainer = GetBankMainContainer -- Some logic still calls it globally
    

local BANK_ROW_HEIGHT = 18





-- Must reset the BANK entry pool, not the inventory one (was aliased to ResetGPHDataPools).
ResetBankDataPools = A.ResetBankDataPools
local BANK_DELETE_X_WIDTH = 16

-- Phase 8: bank list smart count-patch (same idea as inv list Phase 9).
local _bankSmartAggCounts = {}
local _bankSmartAggN = 0
local _bankSmartValid = false
local BANK_BAGS_SOFT = { -1, 5, 6, 7, 8, 9, 10, 11 }
local BANK_BURST_QUIET = 0.10
local BANK_BURST_MAX = 0.22

local function BankPatchListCountsFromAgg(list, aggregated)
    if not list or not aggregated then return end
    for _, item in ipairs(list) do
        if item and item.itemId and not item.divider then
            local agg = aggregated[item.itemId]
            if agg then
                local stackTotal = tonumber(agg.totalCount) or 0
                if stackTotal < 1 then stackTotal = 1 end
                item.count = stackTotal
                item.totalCount = stackTotal
                item.bagID = agg.firstBag
                item.slotID = agg.firstSlot
                item.firstBag = agg.firstBag
                item.bag = agg.firstBag
                item.slot = agg.firstSlot
                if agg.link then item.link = agg.link end
                if agg.texture then item.texture = agg.texture end
            end
        end
    end
end

local function BankSnapshotSmartAgg(aggregated)
    wipe(_bankSmartAggCounts)
    local n = 0
    if aggregated then
        for itemId, agg in pairs(aggregated) do
            local c = tonumber(agg.totalCount) or 0
            if c < 1 then c = 1 end
            _bankSmartAggCounts[itemId] = c
            n = n + 1
        end
    end
    _bankSmartAggN = n
    _bankSmartValid = true
end

local function BankCanSmartListPatch(aggregated, slotList)
    if not _bankSmartValid or not aggregated or not slotList or #slotList == 0 then return false end
    local n = 0
    for itemId, _ in pairs(aggregated) do
        n = n + 1
        if _bankSmartAggCounts[itemId] == nil then return false end
    end
    if n ~= _bankSmartAggN then return false end
    return true
end

local function BankUpdateSpaceAndBagSlots(bf, usedBankSlots, totalBankSlots)
    if bf.bankSpaceFs then
        A.SafeSetText(bf.bankSpaceFs, (usedBankSlots or 0) .. "/" .. (totalBankSlots or 0))
    end
    bf._bankUsedSlots = usedBankSlots
    if bf.bankSpaceFs then
        local fs = bf.bankSpaceFs
        local font, _, flags = fs:GetFont()
        local path, headerSize
        if A.GetCategoryHeaderFontAndSize then
            path, headerSize = A.GetCategoryHeaderFontAndSize()
        end
        font = path or font or "Fonts\\FRIZQT__.TTF"
        -- Match skins.lua BagSpace: header size - 1, clamped 6..12 (grow back after slider down)
        local baseSize = math.min(12, math.max(6, (headerSize or 11) - 1))
        fs:SetFont(font, baseSize, flags or "")
        local wantedSize = baseSize
        while wantedSize > 6 and fs:GetStringWidth() > 36 do
            wantedSize = wantedSize - 1
            fs:SetFont(font, wantedSize, flags or "")
        end
    end
    local purchased = A.FB_GetPurchasedBankBags and A.FB_GetPurchasedBankBags() or 0
    for i = 1, NUM_BANK_BAGS do
        local btn = bf.bagSlots and bf.bagSlots[i]
        if btn then
            local bagID = (NUM_BAG_SLOTS or 4) + i
            if i <= purchased then
                local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
                local bagTexture = invID and GetInventoryItemTexture and GetInventoryItemTexture("player", invID)
                if bagTexture then
                    btn.icon:SetTexture(bagTexture)
                    if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
                    btn.icon:SetVertexColor(1, 1, 1, 1)
                else
                    btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
                    if btn.icon.SetDesaturated then btn.icon:SetDesaturated(true) end
                    btn.icon:SetVertexColor(0.5, 0.5, 0.5, 0.6)
                end
                btn:Show()
            elseif i == purchased + 1 then
                btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
                if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
                btn.icon:SetVertexColor(1, 1, 1, 1)
                btn:Show()
            else
                btn:Hide()
            end
        end
    end
end

local function BankBuildBagsList(mainBank)
    A._bankBagsList = A._bankBagsList or {}
    wipe(A._bankBagsList)
    local bankBags = A._bankBagsList
    bankBags[1] = mainBank
    for i = 1, NUM_BANK_BAGS do
        bankBags[#bankBags + 1] = (NUM_BAG_SLOTS or 4) + i
    end
    return bankBags
end

RefreshBankUI = function(forceFull)
    if ResetBankDataPools then ResetBankDataPools() end
	local bf = A.Bank
	if not bf then return end
	if not bf:IsShown() then return end

    local force = forceFull or bf._bankForceFull
    bf._bankForceFull = nil

    -- Search / rarity filter are chrome, not bag content — must never take smart/NOOP path.
    local searchSrc = bf.gphSearchText or (A.Inventory and A.Inventory.gphSearchText) or ""
    local fqKey = (A.FilterQualitiesKey and A.FilterQualitiesKey(bf)) or tostring(bf.bankRarityFilter)
    local filterKey = fqKey .. "|" .. tostring(searchSrc)
    if bf._bankListFilterKey ~= filterKey then
        force = true
        bf._bankListFilterKey = filterKey
        _bankSmartValid = false
    end
    
    local selectedStillExists = false
    local hadSelectedItemId = bf.gphSelectedItemId
    local selectedRowIdx = bf.gphSelectedIndex
    
    local inv = A.Inventory
    if inv and inv.NegotiateSizes then inv:NegotiateSizes() end
	
	if bf.LayoutBankQualityButtons then 
        bf:LayoutBankQualityButtons() 
    end
	
	if bf.bankSortBtn and bf.bankSortBtn.icon then
        if bf.gphGridMode then
            bf.bankSortBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_01")
        else
            local mode = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSortMode) or "category"
            if mode == "vendor" then bf.bankSortBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
            elseif mode == "itemlevel" then bf.bankSortBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_EngGizmos_19")
            elseif mode == "category" then bf.bankSortBtn.icon:SetTexture("Interface\\Icons\\INV_Chest_Chain_04")
            else bf.bankSortBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_01") end
        end
	end
	if not bf.content then
		return
	end
	local mainBank = GetBankMainContainer()
	if not mainBank then
		return
	end
    local bankBags = BankBuildBagsList(mainBank)

    -- ---------------------------------------------------------------------
    -- Phase 8 grid path: dirty/full slot paint only — never rebuild list rows.
    -- ---------------------------------------------------------------------
    if bf.gphGridMode and _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.BankRefreshSlots then
        local agg, usedBankSlots, totalBankSlots = _G.FugaziBAGS_CombatGrid.BankRefreshSlots(force and true or false)
        if not agg and A.GetInventoryData then
            agg, usedBankSlots, totalBankSlots = A.GetInventoryData(bankBags)
            if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(agg, bf) end
        end
        BankUpdateSpaceAndBagSlots(bf, usedBankSlots, totalBankSlots)
        local needSkin = (not A.FrameNeedsSkinApply) or A.FrameNeedsSkinApply(bf)
        if needSkin and bf.ApplySkin then
            bf:ApplySkin()
            if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(bf) end
        end
        if _G.ApplyBankCustomize then _G.ApplyBankCustomize(bf) end
        return
    end

    ResetBankDataPools()
	
	local bankListW = bf:GetWidth() - 44
    if bf.scrollFrame then
        local sfW = bf.scrollFrame:GetWidth()
        if sfW and sfW > 50 then bankListW = sfW end
    end
    if not bankListW or bankListW < 50 then bankListW = 340 end
	bf._bankListW = bankListW
	local content = bf.content
	if content then 
        content:SetWidth(bankListW) 
    end

    A._bankSlotList = A._bankSlotList or {}
	local slotList = A._bankSlotList
    
    A._bankQCounts = A._bankQCounts or { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    wipe(A._bankQCounts)
    for i=0,4 do A._bankQCounts[i]=0 end
	local qCounts = A._bankQCounts

	local aggregated, usedBankSlots, totalBankSlots = A.GetInventoryData(bankBags)
    bf._gphIdToSlotMap = A.GetItemIdToBagSlot and A.GetItemIdToBagSlot(bankBags) or {}
    local smartList = false
    -- Phase 8 list smart: same itemId set → patch counts, skip sort/filter/category.
    if not force and BankCanSmartListPatch(aggregated, slotList) then
        local countsChanged = false
        for itemId, agg in pairs(aggregated) do
            local c = tonumber(agg.totalCount) or 0
            if c < 1 then c = 1 end
            if _bankSmartAggCounts[itemId] ~= c then
                countsChanged = true
                break
            end
        end
        if not countsChanged then
            BankUpdateSpaceAndBagSlots(bf, usedBankSlots, totalBankSlots)
            if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(aggregated, bf) end
            return
        end
        BankPatchListCountsFromAgg(slotList, aggregated)
        if bf.gphCategoryDrawList then BankPatchListCountsFromAgg(bf.gphCategoryDrawList, aggregated) end
        if bf.gphCategoryItemList then BankPatchListCountsFromAgg(bf.gphCategoryItemList, aggregated) end
        if bf._bankLastPaintList and bf._bankLastPaintList ~= slotList and bf._bankLastPaintList ~= bf.gphCategoryDrawList then
            BankPatchListCountsFromAgg(bf._bankLastPaintList, aggregated)
        end
        BankSnapshotSmartAgg(aggregated)
        if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(aggregated, bf) end
        BankUpdateSpaceAndBagSlots(bf, usedBankSlots, totalBankSlots)
        smartList = true
    end

    if not smartList then
    wipe(slotList)
	for _, agg in pairs(aggregated) do
        -- Bank is a safe space: ignore rarity-wide protection, but respect manual/previouslyWorn protection
        local isProtected = (agg.itemId and A.IsItemProtectedAPI(agg.itemId, agg.quality, true)) or false
        local isWorn = agg.itemId and A.IsItemWorn(agg.itemId)
        
        local entry = A.GetRecycledBankTable()
        entry.bagID = agg.firstBag
        entry.slotID = agg.firstSlot
        entry.firstBag = agg.firstBag
        entry.link = agg.link
        entry.name = agg.name
        entry.quality = agg.quality
        entry.sellPrice = agg.sellPrice
        entry.itemLevel = agg.itemLevel
        local stackTotal = tonumber(agg.totalCount) or 0
        if stackTotal < 1 then stackTotal = 1 end
        entry.count = stackTotal
        entry.totalCount = stackTotal
        entry.texture = agg.texture
        entry.itemType = agg.itemType or "Other"
        entry.isEquip = agg.isEquip
        entry.isProtected = isProtected and true or nil
        entry.previouslyWorn = isWorn and true or nil
        entry.itemId = agg.itemId
		slotList[#slotList + 1] = entry
	end
	
	-- Update rarity bar counts from the fresh slot list (Unified in Sort.lua)
	if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(slotList, bf) end
	
	BankUpdateSpaceAndBagSlots(bf, usedBankSlots, totalBankSlots)
	
    -- Phase 5: skip bank skin when unchanged
    local needSkin = (not A.FrameNeedsSkinApply) or A.FrameNeedsSkinApply(bf)
    if needSkin and bf.ApplySkin then
        bf:ApplySkin()
        if A.NoteFrameSkinApplied then A.NoteFrameSkinApplied(bf) end
    end
    if _G.ApplyBankCustomize then _G.ApplyBankCustomize(bf) end
	
	local SV = _G.FugaziBAGSDB or {}
	local sortMode = SV.gphSortMode or "category"
	if sortMode == "vendor" then
		table.sort(slotList, A.GPH_Sort_Vendor)
	elseif sortMode == "itemlevel" then
		table.sort(slotList, A.GPH_Sort_ItemLevel)
	elseif sortMode == "category" then
		table.sort(slotList, A.GPH_Sort_CategoryPass)
	else
		table.sort(slotList, A.GPH_Sort_Rarity)
	end
	local filterSet = A.GetFilterQualities and A.GetFilterQualities(bf) or bf.bankRarityFilter
	if filterSet ~= nil then
		if not A._bankFilteredList then A._bankFilteredList = {} end
        wipe(A._bankFilteredList)
		local filtered = A._bankFilteredList
		for _, info in ipairs(slotList) do
			local q = info.quality or 0
			if A.QualityPassesFilter and A.QualityPassesFilter(filterSet, q) then
				filtered[#filtered + 1] = info
			elseif not A.QualityPassesFilter then
				if type(filterSet) == "table" then
					if filterSet[q] or (filterSet[4] and q >= 4) then filtered[#filtered + 1] = info end
				elseif q == filterSet or (filterSet == 4 and q >= 4) then
					filtered[#filtered + 1] = info
				end
			end
		end
		slotList = filtered
	end
	
	local searchLower = bf.gphSearchText or (A.Inventory and A.Inventory.gphSearchText)
	if searchLower and searchLower ~= "" then
		searchLower = searchLower:lower():match("^%s*(.-)%s*$")
		if not A._bankSearchList then A._bankSearchList = {} end
		wipe(A._bankSearchList)
		local filtered = A._bankSearchList
		for _, item in ipairs(slotList) do
			if A.Search and A.Search.Matches then
				if A.Search.Matches(item, searchLower) then filtered[#filtered + 1] = item end
			else
				if item.name and item.name:lower():find(searchLower, 1, true) then filtered[#filtered + 1] = item end
			end
		end
		slotList = filtered
	end
	
	-- Categorization Logic (Centralized in Sort Module)
	A.OrganizeBagCategories(slotList, bf, sortMode, SV, A.GetRecycledBankTable)
	-- Remember display list (may be filtered/search-sliced) so smart path does not repaint full bank.
	bf._bankLastPaintList = (sortMode == "category" and bf.gphCategoryDrawList) or slotList
	BankSnapshotSmartAgg(aggregated)
	end -- not smartList

	local SV = _G.FugaziBAGSDB or {}
	local sortMode = SV.gphSortMode or "category"
	
	bf.bankDefaultScrollY = nil
	bf._bankDeleteClickTime = bf._bankDeleteClickTime or {}
	
	local yOff = 0
	local listToUse = (sortMode == "category" and bf.gphCategoryDrawList) or bf._bankLastPaintList or slotList
	
	

	local bankDividerIndex = 0
	bf.bankItemIndexToY = bf.bankItemIndexToY or {}
	wipe(bf.bankItemIndexToY)
	
	local QUALITY_COLORS = Addon and A.QUALITY_COLORS or {}
	if bf.gphCategoryDividerPool then for _, d in ipairs(bf.gphCategoryDividerPool) do d:Hide() end end
    local dividerClickHandler = function(self)
        if not bf.gphCategoryCollapsed then bf.gphCategoryCollapsed = {} end
        local cat = self.categoryName
        local isCollapsed = (cat == "DELETE") and (bf.gphCategoryCollapsed["DELETE"] ~= false) or bf.gphCategoryCollapsed[cat]
        bf.gphCategoryCollapsed[cat] = not isCollapsed
        bf._bankForceFull = true
        if RefreshBankUI then RefreshBankUI() end
    end

    bf._gphDivIdx = 0
    A.GPH_BANK_POOL_USED = 0
	for idx, entry in ipairs(listToUse) do
        local newY, isDiv = A.GPH_RenderCategoryDivider(bf, content, entry, yOff, dividerClickHandler)
        if isDiv then
            yOff = newY
        elseif entry.divider then
            -- Skip hidden headings
        else
			local row = A.GetBankItemBtn(content)
			if firstRow == nil then firstRow = row end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -yOff)
			row.entryIndex = idx
			row._bankRowY = yOff
			bf.bankItemIndexToY[idx] = yOff
            
            local capturedId = entry.itemId or (entry.link and tonumber(entry.link:match("item:(%d+)")))
            local isSelected = (
                (entry.bagID ~= nil and entry.slotID ~= nil and bf.gphSelectedBag == entry.bagID and bf.gphSelectedSlot == entry.slotID)
                or (capturedId and bf.gphSelectedItemId and capturedId == bf.gphSelectedItemId)
                or (bf.gphSelectedIndex and bf.gphSelectedIndex == idx)
            )
            
            if isSelected then
                selectedStillExists = true
                bf.gphSelectedIndex = idx
                bf.gphSelectedRowY = yOff
                bf.gphSelectedBag = entry.bagID
                bf.gphSelectedSlot = entry.slotID
            end
			local info = entry
			local bagID, slotID = info.bagID, info.slotID

			if not info.isProtected and bf.bankDefaultScrollY == nil then
				bf.bankDefaultScrollY = yOff
			end

			
			
			local rowStep = A.ComputeItemDetailsRowHeight(BANK_ROW_HEIGHT)
			row:SetHeight(rowStep)
			if row.clickArea and row.clickArea.SetHeight then row.clickArea:SetHeight(rowStep) end
 			row.bagID = bagID
 			row.slotID = slotID
 			row.clickArea.bagID = bagID
 			row.clickArea.slotID = slotID

            if not row._scriptsBound then
                row._scriptsBound = true
                if A.HandleBagSlotClick then row.clickArea:SetScript("OnClick", function(self, button) A.HandleBagSlotClick(self, button) end) end
                if A.HandleBagSlotDrag then row.clickArea:SetScript("OnDragStart", function(self) A.HandleBagSlotDrag(self) end) end
                if A.HandleBagSlotReceiveDrag then row.clickArea:SetScript("OnReceiveDrag", function(self) A.HandleBagSlotReceiveDrag(self) end) end
                if A.HandleBagSlotEnter then row.clickArea:SetScript("OnEnter", function(self) A.HandleBagSlotEnter(self) end) end
                if A.HandleBagSlotLeave then row.clickArea:SetScript("OnLeave", function(self) A.HandleBagSlotLeave(self) end) end
                row.clickArea:SetScript("OnMouseWheel", function(self, delta) local bf = A.Bank; if bf and bf.scrollFrame and bf.scrollFrame.BankOnMouseWheel then bf.scrollFrame.BankOnMouseWheel(delta) end end)
            end

            -- Alias for UpdateGPHRowVisuals
            entry.bag = bagID
            entry.slot = slotID

            local rowOk, rowErr = pcall(A.UpdateGPHRowVisuals, row, entry, A.GPH_BANK_POOL_USED, yOff, false, nil, bf, bf._gphIdToSlotMap, true)
            if not rowOk then A.AddonPrint("[Fugazi] Bank GPH row error: " .. tostring(rowErr)) end

            yOff = yOff + rowStep
		end
	end

    for i = A.GPH_BANK_POOL_USED + 1, #(A.GPH_BANK_POOL or {}) do
        if A.GPH_BANK_POOL[i] then A.GPH_BANK_POOL[i]:Hide() end
    end

    if bf.gphCategoryDividerPool then
        for i = bf._gphDivIdx + 1, #bf.gphCategoryDividerPool do
            if bf.gphCategoryDividerPool[i] then bf.gphCategoryDividerPool[i]:Hide() end
        end
    end

	content:SetHeight(math.max(yOff, 1))
	
	local aggN = 0
	for _ in pairs(aggregated) do aggN = aggN + 1 end
	-- Empty-poison single defer (list path). Retry frame handles further attempts on open.
	if aggN == 0 and totalBankSlots > 0 and not bf._bankDeferRefresh then
		bf._bankDeferRefresh = true
		if not bf._bankRefreshDefer then bf._bankRefreshDefer = CreateFrame("Frame") end
		bf._bankRefreshDefer:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if not bf:IsShown() or not RefreshBankUI then return end
			if (bf._bankUsedSlots or 0) > 0 then return end
			if A.ForceBankDataRescan then A.ForceBankDataRescan() end
			bf._bankForceFull = true
			RefreshBankUI(true)
		end)
	end
	local scroll = bf.scrollFrame
	local scrollBar = bf.scrollBar
	if scroll then
	end
	if scroll and scrollBar then
		local viewH = scroll:GetHeight()
		local maxScroll = math.max(0, yOff - viewH)
		scrollBar:SetMinMaxValues(0, maxScroll)
		local offset = bf.bankScrollOffset or 0
		
		
		if not bf._bankLastClickedIndex and bf.gphScrollToDefaultOnNextRefresh then
			if bf.bankDefaultScrollY and maxScroll > 0 then
				offset = math.min(bf.bankDefaultScrollY, maxScroll)
				bf.gphScrollToDefaultOnNextRefresh = nil
				bf._pendingBankScrollY = offset
			elseif maxScroll == 0 then
				offset = 0
				bf._pendingBankScrollY = nil
			else
				offset = 0
				bf.gphScrollToDefaultOnNextRefresh = nil
				bf._pendingBankScrollY = nil
			end
		end
		
		if hadSelectedItemId and not selectedStillExists then
			-- Item we clicked is gone (moved to bags/deleted). 
			-- Advance selection to the next item at this index to maintain scroll position.
			local nextIdx = bf.gphSelectedIndex or 1
			local listForAdvance = (sortMode == "category" and bf.gphCategoryDrawList) or slotList
			local nextItem = listForAdvance[nextIdx]
			
			if nextItem then
				local nextId = nextItem.itemId or (nextItem.link and tonumber(nextItem.link:match("item:(%d+)")))
				if nextId then
					bf.gphSelectedItemId = nextId
					bf.gphSelectedIndex = nextIdx
					
					local oldRowY = bf.gphSelectedRowY
					local idxToY = bf.bankItemIndexToY
					local oldScroll = bf.gphScrollOffsetAtClick or bf.bankScrollOffset or 0
					
					if oldRowY and idxToY and idxToY[nextIdx] then
						local newRowY = idxToY[nextIdx]
						local wantScroll = newRowY - oldRowY + oldScroll
						
						-- Jump Guard: If the list shifted too much, don't force a jittery jump
						if math.abs(wantScroll - oldScroll) < 80 then
							offset = math.max(0, math.min(maxScroll, wantScroll))
						end
					end
				end
			end
		elseif bf.gphSelectedRowY and bf.bankItemIndexToY and bf.gphSelectedIndex then
            -- Selection still exists, keep it at the same visual position if it moved
            local oldRowY = bf.gphSelectedRowY
            local newRowY = bf.bankItemIndexToY[bf.gphSelectedIndex]
            local oldScroll = bf.gphScrollOffsetAtClick or bf.bankScrollOffset or 0
            if oldRowY and newRowY then
                local wantScroll = newRowY - oldRowY + oldScroll
                if math.abs(wantScroll - oldScroll) < 80 then
                    offset = math.max(0, math.min(maxScroll, wantScroll))
                end
            end
        end
        
        -- Clean up one-shot selection indicators if needed, but keep persistent ones
        bf.gphScrollOffsetAtClick = nil 

		offset = math.min(offset, maxScroll)
		bf.bankScrollOffset = offset
		scrollBar:SetValue(offset)
		content:ClearAllPoints()
		content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, offset)
	end

	
	if bf._pendingBankScrollY ~= nil and scroll and scrollBar and content and not bf.gphGridMode then
		local wantOffset = bf._pendingBankScrollY
		local df = A._bankScrollToDefaultDeferFrame
		if not df then
			df = CreateFrame("Frame")
			A._bankScrollToDefaultDeferFrame = df
		end
		local runCount = 0
		df:SetScript("OnUpdate", function(self)
			runCount = runCount + 1
			if runCount > 2 then
				self:SetScript("OnUpdate", nil)
				self:Hide()
				if bf._pendingBankScrollY then bf._pendingBankScrollY = nil end
				return
			end
			local b = A.Bank
			if not b or not b:IsShown() or b.gphGridMode or b.scrollFrame ~= scroll then return end
			local vh = scroll:GetHeight()
			local ch = content:GetHeight() or 0
			local maxS = math.max(0, ch - vh)
			local cur = math.min(wantOffset, maxS)
			b.bankScrollOffset = cur
			if b.scrollBar then
				b.scrollBar:SetMinMaxValues(0, maxS)
				b.scrollBar:SetValue(cur)
			end
			content:ClearAllPoints()
			content:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, cur)
		end)
		df:Show()
		bf._pendingBankScrollY = nil
	end
    -- Bag-slot chrome + space (full path already called BankUpdateSpaceAndBagSlots earlier).
    if not smartList then
        BankUpdateSpaceAndBagSlots(bf, usedBankSlots, totalBankSlots)
    end

    -- Tooltip Sync: Ensure tooltips don't stay hidden or stale after a refresh.
    local focus = (GetMouseFocus and GetMouseFocus())
    if focus and focus:IsShown() then
        local isFugazi, p = false, focus
        for i = 1, 6 do -- Verify ownership
            if p == bf or p == bf.content then isFugazi = true; break end
            p = p:GetParent(); if not p then break end
        end
        if isFugazi then
            if A.RefreshTooltipIfHovered then
                A.RefreshTooltipIfHovered(focus, bf)
            else
                local onEnter = focus.GetScript and focus:GetScript("OnEnter")
                if onEnter then pcall(onEnter, focus) end
            end
        end
    end
end
_G.RefreshBankUI = RefreshBankUI
A.RefreshBankUI = RefreshBankUI

local bankRefreshScheduler = CreateFrame("Frame")
bankRefreshScheduler:Hide()
bankRefreshScheduler._t = 0

--- Schedule bank UI refresh with a small buffer to handle server latency.
function FugaziBAGS_ScheduleRefreshBankUI()
    bankRefreshScheduler._t = 0
    if not bankRefreshScheduler:IsShown() then
        bankRefreshScheduler:Show()
        bankRefreshScheduler:SetScript("OnUpdate", function(self, elapsed)
            self._t = self._t + elapsed
            if self._t < 0.15 then return end
            self:SetScript("OnUpdate", nil)
            self:Hide()
            
            local bf = A.Bank
            if not bf or not bf:IsShown() then return end
            -- RefreshBankUI owns grid (dirty paint) and list paths — no second BankRefreshSlots.
            if RefreshBankUI then RefreshBankUI() end
        end)
    end
end
_G.FugaziBAGS_ScheduleRefreshBankUI = FugaziBAGS_ScheduleRefreshBankUI




-- Do not redefine A.NegotiateSizes here (Frames.lua owns it). Older Bankview copies
-- overwrote that function and fought grid layout on every deposit.
if A._NegotiateSizesImpl then
    A.NegotiateSizes = A._NegotiateSizesImpl
end

A.CreateBankFrame = CreateBankFrame




local bankOpenRetryFrame = CreateFrame("Frame")
bankOpenRetryFrame:Hide()
bankOpenRetryFrame._t = 0
bankOpenRetryFrame._retryCount = 0
bankOpenRetryFrame:SetScript("OnUpdate", function(self, elapsed)
    self._t = self._t + elapsed
    if self._t < 0.25 then return end
    self._t = 0
    self._retryCount = self._retryCount + 1
    local bf = A.Bank
    local used = bf and bf._bankUsedSlots or 0
    -- Already populated — stop without another Force+FULL (was the open double-FULL).
    if used > 0 then
        self:Hide()
        return
    end
    -- Empty-poison only: force re-scan so list is not stuck on CACHE HIT used=0.
    if A.ForceBankDataRescan then A.ForceBankDataRescan() end
    if bf then
        bf._bankForceFull = true
        bf._bankGridForceFull = true
    end
    if RefreshBankUI then RefreshBankUI(true) end
    used = bf and bf._bankUsedSlots or 0
    if used > 0 or self._retryCount >= 6 then
        self:Hide()
    end
end)


local function doShowFugaziBank()
    local bf = A.Bank
    if bf and bf:IsShown() and (GetTime() - (bf._lastShowTime or 0)) < 0.1 then return end
    if not Addon then return end
    if not A.HideBlizzardBags then 
        print("|cffff0000[Bank Error]|r FugaziBAGS: A.HideBlizzardBags is missing!")
        return 
    end
    if _G.BankFrame then
        _G.BankFrame:ClearAllPoints()
        _G.BankFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
        _G.BankFrame:SetAlpha(0)
        _G.BankFrame:EnableMouse(false)
    end
    local inv = A.Inventory
    local bf = A.Bank
    if not bf and CreateBankFrame then
        local ok, result = pcall(CreateBankFrame, inv)
        if ok and result then bf = result
        elseif not ok and A.AddonPrint then A.AddonPrint("[Bank] CreateBankFrame error: " .. tostring(result)) end
    end
    if bf then
        A.Bank = bf
        bf._lastShowTime = GetTime()
        bf.gphScrollToDefaultOnNextRefresh = true
        
        local freeFloat = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphBankFreeFloat
        if inv then
            inv:Show()
            if inv.gphInventoryContainer then
                inv.gphInventoryContainer:Show()
            end
            if _G.RefreshGPHUI then _G.RefreshGPHUI() end
            if not freeFloat then
                -- Save free position once before docking; do not overwrite gphPoint with dock coords.
                do
                    local p, r, rp, x, y = inv:GetPoint(1)
                    if p and rp and x and y then
                        inv._gphPreBankAnchor = { p, r, rp, x, y }
                        if not (p == "TOPLEFT" and rp == "TOP" and x == 2 and y == -80) then
                            if A.SaveFrameLayout then
                                A.SaveFrameLayout(inv, nil, "gphPreBankPoint")
                                -- Keep true free position in gphPoint (only if not already docked).
                                A.SaveFrameLayout(inv, "gphShown", "gphPoint")
                            end
                        end
                    end
                end
                -- Sibling under UIParent (not child of inv) so layers don't card-stack.
                bf:SetParent(UIParent)
                local base = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphScale15) and 1.5 or 1
                local extra = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphFrameScale) or 1
                bf:SetScale(base * extra)
                if A.DockInventoryBankCentered then
                    A.DockInventoryBankCentered(true)
                else
                    inv:ClearAllPoints()
                    inv:SetPoint("TOPLEFT", UIParent, "TOP", 2, -80)
                    bf:ClearAllPoints()
                    bf:SetPoint("TOPRIGHT", inv, "TOPLEFT", -4, 0)
                end
            else
                bf:SetParent(UIParent)
                local base = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphScale15) and 1.5 or 1
                local extra = (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphFrameScale) or 1
                bf:SetScale(base * extra)
            end
        else
            bf:SetParent(UIParent)
            bf:SetScale(1)
        end
        
        if freeFloat then
            bf:ClearAllPoints()
            if _G.FugaziBAGSDB and _G.FugaziBAGSDB.framePoint and A.RestoreFrameLayout then
                A.RestoreFrameLayout(bf, "frameShown", "framePoint")
            else
                bf:SetPoint("TOP", UIParent, "CENTER", 200, -100)
            end
        elseif not inv then
            bf:ClearAllPoints()
            bf:SetPoint("TOP", UIParent, "CENTER", 200, -100)
        end
        A.Bank:Show()
        -- Re-dock after Show so NegotiateSizes sees bank visible.
        if not freeFloat and inv and A.DockInventoryBankCentered then
            A.DockInventoryBankCentered(true)
        end
        
        if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then
             _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(bf)
        end
        if bf.bankTitleText then
            bf.bankTitleText:SetText((UnitName and UnitName("target")) or "Bank")
        end

        -- One live bank re-scan + one paint on open (avoid ShowInBankFrame FULL then Refresh FULL).
        if A.ForceBankDataRescan then A.ForceBankDataRescan() end
        bf._bankForceFull = true
        bf._bankGridForceFull = true
        _bankSmartValid = false
        bf._bankDeferRefresh = nil

        local cg = _G.FugaziBAGS_CombatGrid
        if cg then
            -- Must use A.GetPerChar (no bare GetPerChar local in this scope).
            -- Bare GetPerChar was always nil → wantBankGrid false → always list on open.
            local wantBankGrid = A.GetPerChar and A.GetPerChar("gphBankGridMode", true)
            bf.gphGridMode = wantBankGrid and true or false
            if wantBankGrid then
                -- Layout only; RefreshBankUI below does the single full paint.
                if cg.ShowInBankFrame then cg.ShowInBankFrame(bf, true) end
            else
                if cg.HideInBankFrame then cg.HideInBankFrame(bf) end
            end
        end

        if RefreshBankUI then
            RefreshBankUI(true)
            -- Retry only if still empty-with-capacity (poisoned first scan).
            local used = bf._bankUsedSlots or 0
            if used == 0 then
                bankOpenRetryFrame._t = 0
                bankOpenRetryFrame._retryCount = 0
                bankOpenRetryFrame:Show()
            else
                bankOpenRetryFrame:Hide()
            end
        end

        if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
    end
end
A.doShowFugaziBank = doShowFugaziBank

local function FB_InstallBankHooks()
    if not hooksecurefunc then return end
    local installer = CreateFrame("Frame")
    installer._t = 0
    installer:SetScript("OnUpdate", function(self, elapsed)
        self._t = self._t + elapsed
        if self._t > 8 then self:SetScript("OnUpdate", nil); self:Hide(); return end
        
        if _G.BankFrame and _G.BankFrame.Show and not _G.FugaziBAGS_BankShowHooked then
            _G.FugaziBAGS_BankShowHooked = true
            local origShow = _G.BankFrame.Show
            _G.BankFrame.Show = function(frame)
                origShow(frame)
                if doShowFugaziBank then doShowFugaziBank() end
            end
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
    _G.FugaziBAGS_DoShowBank = doShowFugaziBank
    A.doShowFugaziBank = doShowFugaziBank
end
    A.FB_InstallBankHooks = FB_InstallBankHooks

FB_InstallBankHooks()


local bankEventFrame = CreateFrame("Frame")
bankEventFrame:RegisterEvent("BANKFRAME_OPENED")
bankEventFrame:RegisterEvent("BANKFRAME_CLOSED")
bankEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
bankEventFrame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
bankEventFrame:RegisterEvent("BAG_UPDATE")

bankEventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    -- Bank UI event bus (Phase 6.5): bank bags (-1, 5–11) only. Inv BAG_UPDATE → Listview.
    local function isBankBagId(bag)
        return type(bag) == "number" and (bag == -1 or (bag >= 5 and bag <= 11))
    end
    local needRefresh = false
    if event == "BAG_UPDATE" then
        local any = true
        if arg1 == nil then
            -- Bare BAG_UPDATE: soft-dirty bank only (idle pulse must not thrash bank cache).
            if A.DirtyBagsIfContentsChanged then
                any = A.DirtyBagsIfContentsChanged(BANK_BAGS_SOFT) and true or false
            elseif A.WipeBagLinkCache then
                A.WipeBagLinkCache(-1)
                for b = 5, 11 do A.WipeBagLinkCache(b) end
                any = true
            end
            if not any then
                return
            end
            needRefresh = true
        elseif isBankBagId(arg1) then
            -- Per-bag soft-dirty (same idle DELAYED/bag-id pulse as inv).
            if A.DirtyBagsIfContentsChanged then
                any = A.DirtyBagsIfContentsChanged({ arg1 }) and true or false
            elseif A.WipeBagLinkCache then
                A.WipeBagLinkCache(arg1)
                any = true
            end
            if not any then
                return
            end
            needRefresh = true
        else
            -- Player inv bag — ignore here (Listview owns inv UI).
            return
        end
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if A.WipeBagLinkCache then A.WipeBagLinkCache(-1) end
        needRefresh = true
    elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
        -- Purchased bank bag slots: capacity change, full bank dirty.
        if A.WipeBagLinkCache then
            A.WipeBagLinkCache(-1)
            for b = 5, 11 do A.WipeBagLinkCache(b) end
        end
        A._gphBagSpaceDirty = true
        if A.Bank then A.Bank._bankForceFull = true end
        needRefresh = true
    end
    if needRefresh and (event == "BAG_UPDATE" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED") then
        if A.Bank and A.Bank:IsShown() and RefreshBankUI then
            if not A.bankUpdateDeferFrame then A.bankUpdateDeferFrame = CreateFrame("Frame") end
            local bdef = A.bankUpdateDeferFrame
            -- Phase 8: trailing quiet + max wait (same idea as inv bag burst).
            local now = (GetTime and GetTime()) or 0
            if not bdef._bankBurstStart then bdef._bankBurstStart = now end
            bdef._bankLastEvent = now
            if not bdef._bankScheduled then
                bdef._bankScheduled = true
                bdef:SetScript("OnUpdate", function(self2, elapsed)
                    local t = (GetTime and GetTime()) or 0
                    local quiet = t - (self2._bankLastEvent or t)
                    local sinceStart = t - (self2._bankBurstStart or t)
                    if quiet < BANK_BURST_QUIET and sinceStart < BANK_BURST_MAX then return end
                    self2:SetScript("OnUpdate", nil)
                    self2._bankScheduled = nil
                    self2._bankBurstStart = nil
                    self2._bankLastEvent = nil
                    if A.Bank and A.Bank:IsShown() and RefreshBankUI then RefreshBankUI() end
                end)
            end
        end
    elseif event == "BANKFRAME_OPENED" then
        if InCombatLockdown and InCombatLockdown() then return end
        -- Backup: if the hook somehow missed it, trigger it manually
        if A.doShowFugaziBank then A.doShowFugaziBank() end
        if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
        local d2 = CreateFrame("Frame")
        d2:SetScript("OnUpdate", function(self2, elapsed)
            self2._t = (self2._t or 0) + elapsed
            if not self2._doneFirst then
                self2._doneFirst = true
                if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
                local d = CreateFrame("Frame")
                d._count = 0
                d:SetScript("OnUpdate", function(self)
                    if A.HideBlizzardBags then A.HideBlizzardBags(true) end
                    self._count = (self._count or 0) + 1
                    if self._count == 1 and A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
                    if self._count >= 8 then self:SetScript("OnUpdate", nil) end
                end)
            end
            if Addon and A.HideBlizzardBags then A.HideBlizzardBags(true) end
            if self2._t >= 0.05 then
                if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
                if Addon and A.HideBlizzardBags then A.HideBlizzardBags(true) end
            end
            if self2._t >= 0.15 and Addon and A.HideBlizzardBags then A.HideBlizzardBags(true) end
            if self2._t >= 0.4 then
                if Addon and A.HideBlizzardBags then A.HideBlizzardBags(true) end
                self2:SetScript("OnUpdate", nil)
            end
        end)
    elseif event == "BANKFRAME_CLOSED" then
        if A.Bank then
            local now = GetTime()
            if now - (A.Bank._lastShowTime or 0) < 0.5 then
                return
            end
            A.Bank:Hide()
            A.Bank._bankDeferRefresh = nil
            A.Bank._bankCountDebugDone = nil
        end
        local inv = A.Inventory
        if inv then
            local freeFloat = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphBankFreeFloat
            if not freeFloat then
                if inv._gphPreBankAnchor then
                    local p, r, rp, x, y = unpack(inv._gphPreBankAnchor)
                    if p and rp and x and y then
                        inv:ClearAllPoints()
                        inv:SetPoint(p, r or UIParent, rp, x, y)
                    end
                    inv._gphPreBankAnchor = nil
                elseif not inv._gphRestoredFromBankOnHide and A.RestoreFrameLayout then
                    A.RestoreFrameLayout(inv, nil, "gphPreBankPoint")
                end
            end
            inv._gphRestoredFromBankOnHide = nil
        end
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if _G.FugaziBAGS_ScheduleRefreshBankUI then
            _G.FugaziBAGS_ScheduleRefreshBankUI()
        end
    end
end)



--------------------------------------------------------------------------------
-- Move worker helpers (search / filter / category / Ascension bank kind)
--------------------------------------------------------------------------------

--- Snapshot active inventory search + rarity filter for bulk-move jobs.
function A.SnapshotMoveJobFilters()
    local inv = A.Inventory
    local searchLower
    local raw = inv and inv.gphSearchText
    if raw and raw ~= "" then
        searchLower = tostring(raw):lower():match("^%s*(.-)%s*$")
        if searchLower == "" then searchLower = nil end
    end
    local filterQ = A.GetFilterQualities and A.GetFilterQualities(inv) or (inv and inv.gphFilterQuality)
    return searchLower, filterQ
end

--- Build a RarityMoveJob table with current search/filter snapshot.
function A.StartRarityMoveJob(mode, rarity, category)
    local searchLower, filterQ = A.SnapshotMoveJobFilters()
    A.RarityMoveJob = {
        mode = mode,
        rarity = rarity,
        category = category,
        searchLower = searchLower,
        filterQuality = filterQ,
        blacklist = {},
        _lastBag = nil,
        _lastSlot = nil,
        _skippedBound = {},
        _skippedBoundSeen = {},
        _boundNotified = false,
    }
    if A.RarityMoveWorker then
        A.RarityMoveWorker._t = 0
        A.RarityMoveWorker._emptyTicks = 0
        A.RarityMoveWorker:Show()
    end
end

--- Category name used by list headers / move worker (Trade Goods, etc.).
--- Delegates to ResolveItemCategory (same rules + self-healing type cache as bag headers).
function A.GetItemMoveCategory(itemId, link, quality)
    if A.ResolveItemCategory then
        return A.ResolveItemCategory({
            itemId = itemId,
            link = link,
            quality = quality,
        })
    end
    -- Fallback if Utils not loaded.
    local Loc = A.L
    quality = quality or 0
    if quality == 0 then return (Loc and Loc.ITEM_CLASS_MISCELLANEOUS) or "Miscellaneous" end
    if link and A.GetCachedItemInfo then
        local _, _, _, _, _, giType, giSubType = A.GetCachedItemInfo(link)
        local reagent = (Loc and Loc.ITEM_CLASS_REAGENT) or "Reagent"
        local trade = (Loc and Loc.ITEM_CLASS_TRADE_GOODS) or "Trade Goods"
        if giSubType == reagent then return trade end
        if giType and giType ~= "" then return giType end
    end
    return (Loc and Loc.ITEM_CLASS_OTHER) or "Other"
end

--- Ascension reuses GuildBankFrame for Personal + Realm banks.
--- Returns: "personal" | "realm" | "guild" | nil (not open)
function A.GetOpenGuildBankKind()
    local gbf = _G.GuildBankFrame
    if not gbf or not gbf:IsShown() then
        return nil
    end

    local function classify(text)
        if A.ClassifyBankTitleText then
            return A.ClassifyBankTitleText(text)
        end
        if not text or text == "" then return nil end
        local t = text:lower()
        if t:find("personal", 1, true) then return "personal" end
        if t:find("realm", 1, true) then return "realm" end
        return nil
    end

    local named = {
        gbf.TitleText, gbf.title, gbf.Title, gbf.BankTitle,
        _G.GuildBankFrameTitleText, _G.GuildBankTabTitle, _G.GuildBankFrameTabTitle,
    }
    for i = 1, #named do
        local fs = named[i]
        if fs and fs.GetText then
            local kind = classify(fs:GetText())
            if kind then return kind end
        end
    end

    -- Region walk (title is often a naked FontString on the frame)
    local n = gbf.GetNumRegions and gbf:GetNumRegions() or 0
    for i = 1, n do
        local r = select(i, gbf:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText then
            local kind = classify(r:GetText())
            if kind then return kind end
        end
    end

    -- One-level children (some Ascension UIs nest the title)
    local kids = { gbf:GetChildren() }
    for ci = 1, #kids do
        local child = kids[ci]
        if child and child.GetNumRegions then
            local cn = child:GetNumRegions() or 0
            for i = 1, cn do
                local r = select(i, child:GetRegions())
                if r and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText then
                    local kind = classify(r:GetText())
                    if kind then return kind end
                end
            end
        end
    end

    return "guild"
end

--- True when destination rejects currently-bound items (realm / classic guild).
--- Personal bank on Ascension allows soulbound; character bank always does.
function A.GuildBankRejectsBoundItems()
    local kind = A.GetOpenGuildBankKind()
    if not kind then return false end
    return kind ~= "personal"
end

--- Human label for tooltips.
function A.GetOpenGuildBankLabel()
    local kind = A.GetOpenGuildBankKind()
    if A.GetBankKindLabel then
        return A.GetBankKindLabel(kind)
    end
    if kind == "personal" then return "Personal Bank" end
    if kind == "realm" then return "Realm Bank" end
    if kind == "guild" then return "Guild Bank" end
    return "Guild Bank"
end

--- Actually bound in the bag slot (not merely "Binds when equipped").
--- Used so unbound BoE still deposits/mails; true soulbound / account-bound is skipped.
--- Do not call tooltip:Show() — scan tooltip Hide wipes lines (false negatives).
local function IsBagItemCurrentlyBound(bag, slot)
    local gt = A.GetScanTooltip and A.GetScanTooltip()
    if gt and gt.SetBagItem then
        gt:Hide()
        gt:SetOwner(UIParent, "ANCHOR_NONE")
        gt:ClearLines()
        gt:SetBagItem(bag, slot)
        local n = (gt.NumLines and gt:NumLines()) or 0
        -- Some clients under-report NumLines; scan a fixed window of left lines.
        if n < 5 then n = 30 end
        for i = 1, n do
            local line = _G["Fugazi_ScanTooltipTextLeft" .. i]
            if line and line.GetText then
                local t = (line:GetText() or ""):lower()
                if t ~= "" then
                    -- Bound now (not BoE alone). Phrases: Locales/enUS BIND_NONTRADEABLE.
                    if A.IsNonTradeableBindText and A.IsNonTradeableBindText(t) then
                        return true
                    end
                end
            end
        end
        return false
    end
    -- Last resort (may treat unbound BoE as bound — prefer tooltip path above).
    if A.IsBagItemSoulbound then
        return A.IsBagItemSoulbound(bag, slot)
    end
    return false
end
A.IsBagItemCurrentlyBound = IsBagItemCurrentlyBound

local function qualityMatches(r, q)
    if r == nil then return true end
    if A.QualityPassesFilter then
        return A.QualityPassesFilter(r, q)
    end
    if type(r) == "table" then
        if not next(r) then return true end
        if r[q] then return true end
        if r[4] and q >= 4 then return true end
        return false
    end
    if q == r then return true end
    if r == 4 and q >= 4 then return true end
    return false
end

local function entryMatchesMoveFilters(e, job)
    if not e then return false end
    if job.blacklist then
        local key = tostring(e.bag) .. ":" .. tostring(e.slot)
        if job.blacklist[key] then return false end
    end
    if job.filterQuality ~= nil and not qualityMatches(job.filterQuality, e.quality or 0) then
        return false
    end
    if job.searchLower and job.searchLower ~= "" then
        if not (A.Search and A.Search.Matches and A.Search.Matches(e, job.searchLower)) then
            return false
        end
    end
    return true
end

--- Next item of given quality in bank.
local function FindNextFromBank(rarity, categoryName, job)
    job = job or A.RarityMoveJob or {}
    local function scanBag(bagID)
        if not bagID then return nil, nil end
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bagID) or 0
        if not numSlots or numSlots <= 0 then return nil, nil end
        for slot = 1, numSlots do
            local _, _, locked = GetContainerItemInfo(bagID, slot)
            local itemId = GetContainerItemID and GetContainerItemID(bagID, slot)
            local link = GetContainerItemLink and GetContainerItemLink(bagID, slot)
            if itemId and link and not locked then
                local _, _, q = A.GetCachedItemInfo(link)
                q = q or 0
                local e = { bag = bagID, slot = slot, itemId = itemId, link = link, quality = q, name = link and link:match("%[(.-)%]") }
                if not A.RarityIsProtected(itemId, q) and entryMatchesMoveFilters(e, job) then
                    if categoryName then
                        if A.GetItemMoveCategory(itemId, link, q) == categoryName then
                            return bagID, slot
                        end
                    elseif qualityMatches(rarity, q) then
                        return bagID, slot
                    end
                end
            end
        end
        return nil, nil
    end

    local mainCandidates = {}
    local main = (GetBankMainContainer and GetBankMainContainer()) or -1
    if main then table.insert(mainCandidates, main) end

    for _, bagID in ipairs(mainCandidates) do
        local bag, slot = scanBag(bagID)
        if bag then return bag, slot end
    end

    local numBankBags = FB_GetPurchasedBankBags and FB_GetPurchasedBankBags() or 0
    local base = (NUM_BAG_SLOTS or 4)
    for i = 1, numBankBags do
        local bagID = base + i
        local bag, slot = scanBag(bagID)
        if bag then return bag, slot end
    end

    return nil, nil
end
A.FindNextFromBank = FindNextFromBank

--- Next item of given quality or category in bags (used by the move worker).
--- job fields: rarity, category, searchLower, filterQuality, blacklist, skipBound
local function FindNextFromBags(rarity, categoryName, job)
    job = job or A.RarityMoveJob or {}
    rarity = rarity or job.rarity
    categoryName = categoryName or job.category
    local items = A.GetCachedBagItems and A.GetCachedBagItems()
    if not items then return nil, nil end
    local skipBound = job.skipBound
    job._skippedBound = job._skippedBound or {}
    local seenBound = job._skippedBoundSeen or {}
    job._skippedBoundSeen = seenBound
    for i = 1, #items do
        local e = items[i]
        local _, _, locked = GetContainerItemInfo(e.bag, e.slot)
        -- Protected items still get a bound flash when the dest rejects soulbound
        -- (mail does bound-before-protect; realm bank used to stay silent on worn BoP).
        local protected = A.IsItemProtectedAPI and A.IsItemProtectedAPI(e.itemId, e.quality)
        if not locked and e then
            if entryMatchesMoveFilters(e, job) then
                local catOk = true
                if categoryName then
                    catOk = (A.GetItemMoveCategory(e.itemId, e.link, e.quality) == categoryName)
                elseif rarity ~= nil then
                    catOk = qualityMatches(rarity, e.quality or 0)
                end
                if catOk then
                    local bound = skipBound and IsBagItemCurrentlyBound(e.bag, e.slot)
                    if bound then
                        local sk = tostring(e.bag) .. ":" .. tostring(e.slot)
                        if not seenBound[sk] then
                            seenBound[sk] = true
                            table.insert(job._skippedBound, { bag = e.bag, slot = e.slot })
                        end
                    elseif not protected then
                        return e.bag, e.slot
                    end
                end
            end
        end
    end
    return nil, nil
end
A.FindNextFromBags = FindNextFromBags

--- One-shot AFTER the move phase: flash + chat for bound bag items the dest rejects.
--- Call only when FindNext has no more movable matches (job finished), not each tick.
--- Bound slots are never returned by FindNextFromBags when job.skipBound.
--- Full bag scan so later slots are not missed; includes protected/worn BoP.
local function NotifySkippedBoundForJob(job, rarity, categoryName)
    if not job or job._boundNotified or not job.skipBound then return end
    job._boundNotified = true
    rarity = rarity or job.rarity
    categoryName = categoryName or job.category

    local skipped = {}
    local seen = {}
    local function addSlot(bag, slot)
        if bag == nil or slot == nil then return end
        -- Only flash if the item is still in that slot and still bound.
        if not IsBagItemCurrentlyBound(bag, slot) then return end
        local sk = tostring(bag) .. ":" .. tostring(slot)
        if seen[sk] then return end
        seen[sk] = true
        table.insert(skipped, { bag = bag, slot = slot })
    end

    -- Anything FindNext classified as bound while walking the category.
    if job._skippedBound then
        for i = 1, #job._skippedBound do
            local e = job._skippedBound[i]
            if e then addSlot(e.bag, e.slot) end
        end
    end

    local items = A.GetCachedBagItems and A.GetCachedBagItems()
    if items then
        for i = 1, #items do
            local e = items[i]
            -- Do NOT exclude protected — worn BoP is the usual realm-bank reject case.
            if e and entryMatchesMoveFilters(e, job) then
                local catOk = true
                if categoryName then
                    catOk = (A.GetItemMoveCategory(e.itemId, e.link, e.quality) == categoryName)
                elseif rarity ~= nil then
                    catOk = qualityMatches(rarity, e.quality or 0)
                end
                if catOk and IsBagItemCurrentlyBound(e.bag, e.slot) then
                    addSlot(e.bag, e.slot)
                end
            end
        end
    end
    if #skipped == 0 then return end

    if A.FlashBagSlotsDenied then
        A.FlashBagSlotsDenied(skipped, 3)
    end
    local Loc = A.L
    local dest = (Loc and Loc.LABEL_DESTINATION) or "destination"
    if job.mode == "bags_to_guildbank" then
        dest = (A.GetOpenGuildBankLabel and A.GetOpenGuildBankLabel())
            or (Loc and Loc.LABEL_GUILD_BANK) or "Guild Bank"
    elseif job.mode == "bags_to_mail" then
        dest = (Loc and Loc.LABEL_MAIL) or "mail"
    end
    local n = #skipped
    local prefix = (Loc and Loc.ADDON_PRINT_PREFIX) or "|cffff6666[FugaziBAGS]|r "
    local fmt = (Loc and Loc.MSG_SKIPPED_SOULBOUND_MOVE)
        or "Skipped %d soulbound item%s (cannot move to %s)."
    print(prefix .. fmt:format(n, (n == 1 and "" or "s"), dest))
end

local rarityMoveWorker = A.RarityMoveWorker or CreateFrame("Frame")
A.RarityMoveWorker = rarityMoveWorker
rarityMoveWorker:Hide()

rarityMoveWorker:SetScript("OnUpdate", function(self, elapsed)
    local job = A.RarityMoveJob
    if not job then
        self._t = nil
        self:Hide()
        return
    end
    self._t = (self._t or 0) + elapsed
    if self._t < 0.1 then return end
    self._t = 0

    -- Blacklist a stuck slot so the worker advances. Do NOT flash here:
    -- UseContainerItem/pickup lag keeps the same slot for several ticks while
    -- unbound mats still move — flashing looked like "everything is denied".
    -- Soulbound feedback is only via NotifySkippedBoundForJob after the move job.
    local function markAttempt(bag, slot)
        if job._lastBag == bag and job._lastSlot == slot then
            job.blacklist = job.blacklist or {}
            local key = tostring(bag) .. ":" .. tostring(slot)
            job.blacklist[key] = true
        end
        job._lastBag, job._lastSlot = bag, slot
    end

    local function finishJobWithBoundFlash()
        NotifySkippedBoundForJob(job, job.rarity, job.category)
        A.RarityMoveJob = nil
        self:Hide()
    end

    if job.mode == "bags_to_guildbank" then
        if not _G.GuildBankFrame or not _G.GuildBankFrame:IsShown() then
            finishJobWithBoundFlash()
            ClearCursor()
            return
        end
        -- Realm / classic guild reject soulbound; Ascension Personal Bank accepts them.
        if A.GuildBankRejectsBoundItems then
            job.skipBound = A.GuildBankRejectsBoundItems()
        else
            job.skipBound = true
        end
        local srcBag, srcSlot = FindNextFromBags(job.rarity, job.category, job)
        if not srcBag or not srcSlot then
            -- Move phase done (or nothing left to move) → flash skipped soulbound once.
            finishJobWithBoundFlash()
            return
        end
        markAttempt(srcBag, srcSlot)
        UseContainerItem(srcBag, srcSlot)
        return
    end

    if job.mode == "bags_to_mail" then
        -- Prefer the real mail send worker (batch + send). Move-worker path is legacy attach-only.
        if A.StartSendRarityMail then
            local rarity = job.rarity
            if rarity == nil and not job.category then rarity = -1 end
            A.StartSendRarityMail(rarity, {
                category = job.category,
                searchLower = job.searchLower,
                filterQuality = job.filterQuality,
            })
            A.RarityMoveJob = nil
            self:Hide()
            return
        end
        if not _G.MailFrame or not _G.MailFrame:IsShown() then
            A.RarityMoveJob = nil
            ClearCursor()
            self:Hide()
            return
        end
        job.skipBound = true
        local srcBag, srcSlot = FindNextFromBags(job.rarity, job.category, job)
        if not srcBag or not srcSlot then
            finishJobWithBoundFlash()
            return
        end
        markAttempt(srcBag, srcSlot)
        UseContainerItem(srcBag, srcSlot)
        return
    end

    local bankFrame = A.Bank

    if not bankFrame or not bankFrame:IsShown() or not bankFrame.GetFirstFreeBankSlot or not bankFrame.GetFirstFreeBagSlot then
        A.RarityMoveJob = nil
        ClearCursor()
        self:Hide()
        return
    end

    -- Character bank accepts soulbound (no skip / no flash).
    job.skipBound = false

    local srcBag, srcSlot
    if job.mode == "bags_to_bank" then
        srcBag, srcSlot = FindNextFromBags(job.rarity, job.category, job)
    else
        srcBag, srcSlot = A.FindNextFromBank(job.rarity, job.category, job)
    end
    if not srcBag or not srcSlot then
        self._emptyTicks = (self._emptyTicks or 0) + 1
        if self._emptyTicks > 10 then
            A.RarityMoveJob = nil
            self._emptyTicks = 0
            self:Hide()
        end
        return
    end
    self._emptyTicks = 0

    local destBag, destSlot
    if job.mode == "bags_to_bank" then
        destBag, destSlot = bankFrame.GetFirstFreeBankSlot()
    else
        destBag, destSlot = bankFrame.GetFirstFreeBagSlot()
    end
    if not destBag or not destSlot then
        A.RarityMoveJob = nil
        self:Hide()
        return
    end

    markAttempt(srcBag, srcSlot)
    ClearCursor()
    if PickupContainerItem then
        PickupContainerItem(srcBag, srcSlot)
        PickupContainerItem(destBag, destSlot)
    end
    -- No per-move full UI refresh — bag events + dirty paths handle paint (perf parity).
end)


--- Bank specific skinning (font sizes and colors for title/space button).
--- [REDUNDANT] ApplyBankCustomize: Standardized to use skins.lua engine.
function ApplyBankCustomize(f)
    if not f then return end
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then
        _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(f)
    end
end
_G.ApplyBankCustomize = ApplyBankCustomize
    

--- Bank-specific Grid Mode settings.
function A.IsBankInGridMode()
    -- Default true to match open-path / title-menu (gphBankGridMode, true).
    return A.GetPerChar("gphBankGridMode", true)
end

function A.SetBankGridMode(enabled)
    A.SetPerChar("gphBankGridMode", enabled)
    if A.Bank then
        A.Bank.gphGridMode = enabled and true or false
        A.Bank._bankForceFull = true
        A.Bank._bankGridForceFull = true
    end
    _bankSmartValid = false
    if _G.RefreshBankUI then _G.RefreshBankUI(true) end
end
