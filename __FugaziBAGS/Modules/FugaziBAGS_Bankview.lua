local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon

local function FugaziBankRow_OnUpdateCooldown(self, elapsed)
	self._cdTimer = (self._cdTimer or 0) + elapsed
	if self._cdTimer >= 0.1 then
		self._cdTimer = 0
		if A.FugaziBAGS_CheckRowCooldown then
			local map = self:GetParent():GetParent()._gphIdToSlotMap
			if not A.FugaziBAGS_CheckRowCooldown(self, self.cachedItem, map) then
				self:SetScript("OnUpdate", nil)
			end
		end
	end
end
-- Fetch DB dynamically inside functions to avoid stale reference issues with SavedVariables.

local MAIN_BANK_SLOTS = 28
local NUM_BANK_BAGS = NUM_BANKBAGSLOTS or 6
local BANK_LIST_WIDTH = 296
local BANK_HEADER_HEIGHT = 18

local BANK_DEBUG = false  
local function BankDebug(msg) if BANK_DEBUG and A.AddonPrint then A.AddonPrint("[Bank] " .. msg) end end
A.BankDebug = BankDebug

-- Forward declarations for local functions
local GetBankMainContainer, GetBankRow, ResetBankRowPool, ResetBankDataPools, GetBankAggTable, GetBankItemTable
    
local function GetPerChar(key, default) return A.GetPerChar(key, default) end
local function SetPerChar(key, value) A.SetPerChar(key, value) end

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
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function()
		if f._isDragging then return end
		f._isDragging = true
		f:StartMoving()
	end)
	f:SetScript("OnDragStop", function()
		if not f._isDragging then return end
		f._isDragging = nil
		f:StopMovingOrSizing()
		local inv = A.Inventory
		if inv and inv.NegotiateSizes then inv:NegotiateSizes() end
	end)
    f:SetScript("OnHide", function()
        local inv = A.Inventory
        if inv and inv._gphPreBankAnchor then
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
	f:SetFrameLevel(10)
    
    
    

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

             local bankGridMode = A.GetPerChar("gphBankGridMode", false)
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
        f:StartMoving()
    end)
	titleBar:SetScript("OnDragStop", function()
        if not f._isDragging then return end
        f._isDragging = nil
		f:StopMovingOrSizing()
		local inv = A.Inventory
		if inv and inv.NegotiateSizes then inv:NegotiateSizes() end
		A.SaveFrameLayout(f, "frameShown", "framePoint")
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
	bagRow:SetFrameLevel(f:GetFrameLevel() + 30)
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
	bankHeader:SetHeight(BANK_HEADER_HEIGHT)
	f.bankHeader = bankHeader
	local bankSpaceBtn = A.CreateBagSpaceIndicator(f, bankHeader, true)
    
    bankSpaceBtn:SetScript("OnClick", function(self, button)
		if button ~= "LeftButton" then return end
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
	
	local function getAllBankSlotsForItem(itemId, knownBankBag, knownBankSlot)
		itemId = tonumber(itemId) or itemId
		if not itemId then return {} end
		local list = {}
		local function addSlot(bagID, slotID, count)
			list[#list + 1] = { bag = bagID, slot = slotID, count = (count and count > 0) and count or 1 }
		end
		local function getCount(bagID, slotID)
			if not GetContainerItemInfo then return 1 end
			local t1, t2, t3, t4, t5 = GetContainerItemInfo(bagID, slotID)
			if type(t2) == "number" and t2 > 0 then return t2 end
			if type(t3) == "number" and t3 > 0 then return t3 end
			if type(t4) == "number" and t4 > 0 then return t4 end
			if type(t5) == "number" and t5 > 0 then return t5 end
			return 1
		end
		if knownBankBag ~= nil and knownBankSlot ~= nil then
			local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(knownBankBag, knownBankSlot))
			if tex then addSlot(knownBankBag, knownBankSlot, getCount(knownBankBag, knownBankSlot)) end
		end
		local mainBank = GetBankMainContainer()
		if mainBank then
			for slot = 1, MAIN_BANK_SLOTS do
				if knownBankBag == mainBank and knownBankSlot == slot then else
					local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(mainBank, slot))
					if tex then
						local id = (GetContainerItemID and GetContainerItemID(mainBank, slot)) or nil
						if not id and GetContainerItemLink then
							local link = GetContainerItemLink(mainBank, slot)
							if link then id = tonumber(link:match("item:(%d+)")) end
						end
						if id and tonumber(id) == tonumber(itemId) then addSlot(mainBank, slot, getCount(mainBank, slot)) end
					end
				end
			end
		end
		for i = 1, NUM_BANK_BAGS do
			local bagID = (NUM_BAG_SLOTS or 4) + i
			local numSlots = GetContainerNumSlots and GetContainerNumSlots(bagID) or 0
			for slot = 1, numSlots do
				if knownBankBag == bagID and knownBankSlot == slot then else
					local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(bagID, slot))
					if tex then
						local id = (GetContainerItemID and GetContainerItemID(bagID, slot)) or nil
						if not id and GetContainerItemLink then
							local link = GetContainerItemLink(bagID, slot)
							if link then id = tonumber(link:match("item:(%d+)")) end
						end
						if id and tonumber(id) == tonumber(itemId) then addSlot(bagID, slot, getCount(bagID, slot)) end
					end
				end
			end
		end
		return list
	end
	f.PlaceCursorInFirstFreeBankSlot = placeCursorInFirstFreeBankSlot
	f.GetFirstFreeBankSlot = getFirstFreeBankSlot
	f.GetFirstFreeBagSlot = getFirstFreeBagSlot
	f.GetAllBankSlotsForItem = getAllBankSlotsForItem
	bankSpaceBtn:SetScript("OnReceiveDrag", function() placeCursorInFirstFreeBankSlot() end)
	f.bankSpaceFs = bankSpaceFs
	f.bankSpaceBtn = bankSpaceBtn
	
	local bankChildReuse = {}
	local function fillChildReuse(t, ...)
		for i = 1, select("#", ...) do t[i] = select(i, ...) end
		return select("#", ...)
	end
	local function SyncModifierOverlaysForContent(content, altDown)
		if not content or not content.GetChildren then return end
		wipe(bankChildReuse)
		fillChildReuse(bankChildReuse, content:GetChildren())
		for i = 1, #bankChildReuse do
			local row = bankChildReuse[i]
			local ca = row and row.clickArea
			local modOv = ca and ca._fugaziModifierOverlay
			if modOv and modOv.Show and modOv.Hide and modOv.EnableMouse then
				if altDown and not IsControlKeyDown() then modOv:Show(); modOv:EnableMouse(true) else modOv:Hide(); modOv:EnableMouse(false) end
			end
		end
	end
	local defaultBankSpaceColor = { 1, 0.85, 0.4, 1 }
	f:SetScript("OnUpdate", function(self, elapsed)
		if not self:IsShown() then return end
		
		self._throttleT = (self._throttleT or 0) + elapsed
		if self._throttleT >= 0.1 then
			self._throttleT = 0
			pcall(SyncModifierOverlaysForContent, self.content, IsAltKeyDown() and not IsControlKeyDown())
		
			if self.bankSpaceBtn then
				local hasItem = (GetCursorInfo and GetCursorInfo() == "item")
				if self.bankSpaceBtn.glow then
					if hasItem then self.bankSpaceBtn.glow:Show() else self.bankSpaceBtn.glow:Hide() end
				end
				if self.bankSpaceBtn.fs then
					if hasItem then
						self.bankSpaceBtn.fs:SetTextColor(1, 1, 1, 1)
					else
						local c = self.bankSpaceTextColor or defaultBankSpaceColor
						self.bankSpaceBtn.fs:SetTextColor(c[1], c[2], c[3], c[4])
					end
				end
			end
		end
	end)
	
	f.UpdateBankQualBtnVisual = function(bf, btn, q)
		A.UpdateRarityBtnVisual(bf, btn, q, bf.bankRarityFilter)
	end

	f.noProtection = true -- Safe Harbor: No marking or deletion in the Bank!
	f.isBankFrame = true -- Isolated refresh for Bank only
	
	-- Bank-Specific Click Handler (Safe Zone)
	local qualBtnOnClickHandler = function(self, button)
		if A.PlayClickSound then A.PlayClickSound() end
		local shift = IsShiftKeyDown and IsShiftKeyDown()
		if shift and button == "RightButton" then
			A.RarityMoveJob = { mode = "bank_to_bags", rarity = self.quality }
			if A.RarityMoveWorker then A.RarityMoveWorker._t = 0; A.RarityMoveWorker:Show() end
			return
		end
		if button == "LeftButton" then
			if f.bankRarityFilter == self.quality then f.bankRarityFilter = nil; f.gphFilterQuality = nil
			else f.bankRarityFilter = self.quality; f.gphFilterQuality = self.quality end
			if _G.RefreshBankUI then _G.RefreshBankUI() end
		elseif button == "RightButton" then
			f.bankRarityFilter = nil; f.gphFilterQuality = nil
			if _G.RefreshBankUI then _G.RefreshBankUI() end
		end
	end

	-- Bank-Specific Tooltip Handler
	f.qualityOnEnter = function(self)
		self.helpLines = {
			{ "LMB: Filter quality in Bank", 1, 1, 1 },
			{ "Shift+RMB: Move rarity to Bags", 1, 1, 1 }
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
		end)
	end

	
	f.bankScrollOffset = 0
	local scroll = CreateFrame("ScrollFrame", "TestBankScrollFrame", f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", bankHeader, "BOTTOMLEFT", 0, -14) 
	scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 6)
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
				content:SetWidth(BANK_LIST_WIDTH)
				content:SetHeight(content:GetHeight() or 1)
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
		A.HandleMouseWheel(scroll, delta, f, "bankScrollOffset", nil, BANK_LIST_WIDTH)
	end
	content:SetScript("OnMouseWheel", function(self, delta) doScrollWheel(delta) end)
	scroll:SetScript("OnMouseWheel", function(self, delta) doScrollWheel(delta) end)
	scroll.BankOnMouseWheel = function(delta) doScrollWheel(delta) end
	BankDebug("CreateBankFrame: scroll/content created (UIPanelScrollFrameTemplate)")

	A.Bank = f
	if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(f) end
	f.ApplySkin = function() if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(f) end end
	BankDebug("CreateBankFrame: about to RETURN f, f.content=" .. tostring(f.content) .. " A.Bank==f? " .. tostring(A.Bank == f))
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


--- Clear one bank slot (pickup + clear).
local function DeleteBankSlot(bagID, slotID)
	if bagID == nil or slotID == nil then return end
	if PickupContainerItem and DeleteCursorItem then
		PickupContainerItem(bagID, slotID)
		DeleteCursorItem()
	end
end


local BANK_ROW_POOL, BANK_ROW_POOL_USED = {}, 0

--- Return all bank list rows to pool (reuse).
ResetBankRowPool = function()
	BANK_ROW_POOL_USED = 0
end

function CleanupBankRowPool()
    if not BANK_ROW_POOL then return end
    A._gphIsCleaning = true -- START GUARD
    for i = BANK_ROW_POOL_USED + 1, #BANK_ROW_POOL do
        if BANK_ROW_POOL[i] then BANK_ROW_POOL[i]:Hide() end
    end
    A._gphIsCleaning = false -- END GUARD
end


A.ResetBankDataPools = A.ResetGPHDataPools
ResetBankDataPools = A.ResetBankDataPools
local BANK_DELETE_X_WIDTH = 16

--- Get or create one bank list row (icon, name, count).
GetBankRow = function(parent)
	BANK_ROW_POOL_USED = BANK_ROW_POOL_USED + 1
	local row = BANK_ROW_POOL[BANK_ROW_POOL_USED]
	if not row then
		row = CreateFrame("Frame", "BankRow_" .. BANK_ROW_POOL_USED, parent)
		row:SetWidth(BANK_LIST_WIDTH)
		row:SetHeight(BANK_ROW_HEIGHT)
		row:EnableMouse(true)
		row.deleteBtn = nil
		local clickArea = CreateFrame("Button", nil, row)
		clickArea:SetPoint("LEFT", row, "LEFT", 0, 0)
		clickArea:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		clickArea:SetHeight(BANK_ROW_HEIGHT)
		clickArea:EnableMouse(true)
		clickArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		clickArea:RegisterForDrag("LeftButton")
		clickArea:SetHitRectInsets(0, 0, 0, 0)
		clickArea:SetText("")
		row.clickArea = clickArea
		local icon = clickArea:CreateTexture(nil, "ARTWORK")
		icon:SetSize(16, 16)
		icon:SetPoint("LEFT", clickArea, "LEFT", 0, 0)
		row.icon = icon
		
		local protectedOverlay = clickArea:CreateTexture(nil, "OVERLAY")
		protectedOverlay:SetAllPoints(clickArea)
		protectedOverlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		protectedOverlay:SetVertexColor(0, 0, 0, 0.38)
		protectedOverlay:Hide()
		row.protectedOverlay = protectedOverlay
		local countFs = clickArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		countFs:SetPoint("RIGHT", clickArea, "RIGHT", -2, 0)
		countFs:SetJustifyH("RIGHT")
		row.countFs = countFs
		local nameFs = clickArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		nameFs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
		nameFs:SetPoint("RIGHT", clickArea, "RIGHT", -40, 0)
		nameFs:SetJustifyH("LEFT")
		row.nameFs = nameFs
		local rowHighlight = clickArea:CreateTexture(nil, "BACKGROUND")
		rowHighlight:SetAllPoints()
		rowHighlight:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		rowHighlight:SetVertexColor(1, 1, 1, 0.06)
		rowHighlight:Hide()
		row.rowHighlight = rowHighlight

		local cooldownOverlay = clickArea:CreateTexture(nil, "OVERLAY")
		cooldownOverlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		cooldownOverlay:SetPoint("TOPLEFT", clickArea, "TOPLEFT", 0, 0)
		cooldownOverlay:SetPoint("BOTTOMLEFT", clickArea, "BOTTOMLEFT", 0, 0)
		cooldownOverlay:SetWidth(0.01)
		cooldownOverlay:Hide()
		row.cooldownOverlay = cooldownOverlay

		local pulse = CreateFrame("Frame", nil, clickArea)
		pulse:SetAllPoints()
		pulse:SetFrameLevel(clickArea:GetFrameLevel() + 5)
		local pTex = pulse:CreateTexture(nil, "OVERLAY")
		pTex:SetAllPoints()
		pTex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
		pTex:SetVertexColor(1, 1, 1, 0.7)
		pulse:Hide()
		row.pulseTex = pulse

		BANK_ROW_POOL[BANK_ROW_POOL_USED] = row
	end
	
	if row.deleteBtn then
		row.deleteBtn:Hide()
		row.deleteBtn:SetParent(nil)
		row.deleteBtn = nil
	end
	row:SetParent(parent)
	
	local bf = A.Bank
	if bf and bf._bankListW then row:SetWidth(bf._bankListW) end
	row:Show()
	row.clickArea:Show()
	if row.pulseTex then row.pulseTex:Hide() end
	return row
end





--- Bank row: mouse down (drag start).
local function BankRow_clickArea_OnMouseDown(self, mouseButton)
    local row = self:GetParent()
    if A.TriggerRowPulse then A.TriggerRowPulse(row) end
    if not row.bagID or not row.slotID then return end

    -- Store row/scroll so after move (bank->bags) refresh keeps list under cursor like bags do.
    local bf = A.Bank
    if bf and bf:IsShown() and row.entryIndex and row._bankRowY then
        local capturedId = row.itemId or (row.link and tonumber(row.link:match("item:(%d+)")))
        bf.gphSelectedItemId = capturedId
        bf.gphSelectedBag = row.bagID
        bf.gphSelectedSlot = row.slotID
        bf.gphSelectedIndex = row.entryIndex
        bf.gphSelectedRowY = row._bankRowY
        bf.gphScrollOffsetAtClick = bf.bankScrollOffset or 0
    end
    if mouseButton == "LeftButton" and IsShiftKeyDown() then
        local link = GetContainerItemLink and GetContainerItemLink(r.bagID, r.slotID)
        local totalCount = r.totalCount or (GetContainerItemInfo and select(2, GetContainerItemInfo(r.bagID, r.slotID))) or 1
        if link and totalCount and totalCount > 1 and A.ShowGPHStackSplit then
            local itemId = tonumber(link:match("item:(%d+)"))
            if itemId then A.ShowGPHStackSplit(r.bagID, r.slotID, totalCount, self, itemId, true) end
            return
        end
    end
end
--- Bank row: click (pickup, swap, modifier actions).
local function BankRow_clickArea_OnClick(self, button)
    if A.PlayClickSound then A.PlayClickSound() end
    local r = self:GetParent()
    if not r.bagID or not r.slotID then return end

    
    if button == "LeftButton" and IsAltKeyDown() and not IsControlKeyDown() then
        local link = GetContainerItemLink and GetContainerItemLink(r.bagID, r.slotID)
            A.ToggleItemProtection(itemId, link, r)
        local gf = gphFrame or A.Inventory
        if gf then gf._refreshImmediate = true end
        if RefreshGPHUI then RefreshGPHUI() end
        if _G.FugaziBAGS_ScheduleRefreshBankUI then _G.FugaziBAGS_ScheduleRefreshBankUI() end
        return
    end

    
    if button == "RightButton" and IsShiftKeyDown() then
        local link = GetContainerItemLink and GetContainerItemLink(r.bagID, r.slotID)
        if link then
            if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end
            local chatBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
            if not chatBox then
                if ChatEdit_ActivateChat and ChatFrame1EditBox then
                    ChatEdit_ActivateChat(ChatFrame1EditBox)
                    chatBox = ChatFrame1EditBox
                else
                    for ci = 1, NUM_CHAT_WINDOWS do
                        local eb = _G["ChatFrame" .. ci .. "EditBox"]
                        if eb then chatBox = eb; break end
                    end
                end
            end
            if chatBox then
                chatBox:Insert(link)
                if chatBox.SetFocus then chatBox:SetFocus() end
            end
        end
        return
    elseif button == "RightButton" and not IsShiftKeyDown() then
        if r.bagID ~= nil and r.slotID ~= nil and UseContainerItem then
            UseContainerItem(r.bagID, r.slotID)
            local bf = A.Bank
            if bf and bf:IsShown() and r.entryIndex and r._bankRowY then
                local capturedId = r.itemId or (r.link and tonumber(r.link:match("item:(%d+)")))
                bf.gphSelectedItemId = capturedId
                bf.gphSelectedBag = r.bagID
                bf.gphSelectedSlot = r.slotID
                bf.gphSelectedIndex = r.entryIndex
                bf.gphSelectedRowY = r._bankRowY
                bf.gphScrollOffsetAtClick = bf.bankScrollOffset or 0
            end
            if RefreshBankUI then RefreshBankUI() end
            if RefreshGPHUI then RefreshGPHUI() end
        end
        if r.pulseTex then
            r.pulseTex:SetVertexColor(1, 1, 1, 0.65)
            r.pulseTex:Show()
            if not r._pulseAnimFrame then
                r._pulseAnimFrame = CreateFrame("Frame")
            end
            r._pulseAnimFrame._t = 0
            r._pulseAnimFrame:SetScript("OnUpdate", function(f, el)
                f._t = f._t + el
                if f._t > 0.3 then r.pulseTex:Hide(); f:SetScript("OnUpdate", nil)
                else r.pulseTex:SetAlpha(0.65 * (1 - f._t/0.3)) end
            end)
        end
        return
    end
end
--- Bank row: accept item drag.
local function BankRow_clickArea_OnReceiveDrag(self)
    local r = self:GetParent()
    if GetCursorInfo and GetCursorInfo() == "item" and PickupContainerItem and r.bagID and r.slotID then
        PickupContainerItem(r.bagID, r.slotID)
    end
end
--- Bank row: mouse up (drop).
local function BankRow_clickArea_OnMouseUp(self, button)
    if button ~= "LeftButton" then return end
    if IsAltKeyDown() and not IsControlKeyDown() then return end
    local r = self:GetParent()
    if not r.bagID or not r.slotID or not PickupContainerItem then return end
    if GetCursorInfo and GetCursorInfo() == "item" then
        PickupContainerItem(r.bagID, r.slotID)
    end
end

--- Row cooldown tick (update spiral).
local function FugaziBankRow_OnUpdateCooldown(self, elapsed)
    self._cdTimer = (self._cdTimer or 0) + elapsed
    if self.cachedItem and self._cdTimer > 0.25 then
        self._cdTimer = 0
        if not A.FugaziBAGS_CheckRowCooldown(self, self.cachedItem) then
            self:SetScript("OnUpdate", nil)
        end
    end
end
--- Bank row: tooltip + secure button on enter.
local function BankRow_clickArea_OnEnter(self)
    local r = self:GetParent()
    if r.rowHighlight then r.rowHighlight:Show() end
    
    if r.clickArea and r.clickArea._fugaziModifierOverlay and IsAltKeyDown() and not IsControlKeyDown() then
        local modOv = r.clickArea._fugaziModifierOverlay
        modOv:Show()
        modOv:EnableMouse(true)
    end
    
    if A.HandleBagSlotEnter then
        A.HandleBagSlotEnter(self)
    end
end
--- Bank row: hide tooltip on leave.
local function BankRow_clickArea_OnLeave(self)
    local r = self:GetParent()
    if r.rowHighlight then r.rowHighlight:Hide() end
    if A.HandleBagSlotLeave then
        A.HandleBagSlotLeave(self)
    else
        GameTooltip:Hide()
    end
end
--- Bank row: mouse wheel scrolls bank list.
local function BankRow_clickArea_OnMouseWheel(self,  delta)
    local bf = A.Bank
    if bf and bf.scrollFrame and bf.scrollFrame.BankOnMouseWheel then
        bf.scrollFrame.BankOnMouseWheel(delta)
    end
end


RefreshBankUI = function()
    if ResetBankDataPools then ResetBankDataPools() end
    BankDebug("RefreshBankUI called")

	local bf = A.Bank
	if not bf then BankDebug("RefreshBankUI: A.Bank is NIL") return end
	if not bf:IsShown() then BankDebug("RefreshBankUI: bf:IsShown() is FALSE") return end
    
    local selectedStillExists = false
    local hadSelectedItemId = bf.gphSelectedItemId
    local selectedRowIdx = bf.gphSelectedIndex
    
    local inv = A.Inventory
    if inv and inv.NegotiateSizes then inv:NegotiateSizes() end
	
	if bf.LayoutBankQualityButtons then 
        BankDebug("Step 1: LayoutBankQualityButtons")
        bf:LayoutBankQualityButtons() 
    end

    if bf.gphGridMode and _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.BankRefreshSlots then
        _G.FugaziBAGS_CombatGrid.BankRefreshSlots()
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
        BankDebug("Step 2: sort icon iconTexture set")
	end
	if not bf.content then
		return
	end
	local mainBank = GetBankMainContainer()
	if not mainBank then
        BankDebug("Step 3 FAIL: GetBankMainContainer is NIL")
		return
	end
    BankDebug("Step 3: mainBank=" .. tostring(mainBank))

	ResetBankRowPool()
    ResetBankDataPools()
	
	local bankListW = BANK_LIST_WIDTH
	if bf.scrollFrame then
		local sw = bf.scrollFrame:GetWidth()
		if sw and sw > 50 then bankListW = sw - 4 end  
	end
	bf._bankListW = bankListW
	local content = bf.content
	if content then 
        BankDebug("Step 4: content:SetWidth")
        content:SetWidth(bankListW) 
    end
	


    A._bankSlotList = A._bankSlotList or {}
    wipe(A._bankSlotList)
	local slotList = A._bankSlotList
    BankDebug("Step 5: slotList wiped")
    
	local totalBankSlots, usedBankSlots = 0, 0
    
    A._bankQCounts = A._bankQCounts or { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    wipe(A._bankQCounts)
    for i=0,4 do A._bankQCounts[i]=0 end
	local qCounts = A._bankQCounts
    
	
    A._bankAggregated = A._bankAggregated or {}
    wipe(A._bankAggregated)
	local aggregated = A._bankAggregated
    
	local bankBags = { mainBank }
	for i = 1, NUM_BANK_BAGS do table.insert(bankBags, (NUM_BAG_SLOTS or 4) + i) end
	local aggregated, usedBankSlots, totalBankSlots = A.GetInventoryData(bankBags)
    bf._gphIdToSlotMap = A.GetItemIdToBagSlot and A.GetItemIdToBagSlot(bankBags) or {}
    BankDebug("Step 6: GetInventoryData finished, used=" .. tostring(usedBankSlots))

	for _, agg in pairs(aggregated) do
        local isProtected = (agg.itemId and A.IsItemProtectedAPI(agg.itemId, agg.quality)) or false
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
        entry.count = agg.totalCount
        entry.texture = agg.texture
        entry.itemType = agg.itemType or "Other"
        entry.isProtected = isProtected and true or nil
        entry.previouslyWorn = isWorn and true or nil
		slotList[#slotList + 1] = entry
	end
	
	-- Update rarity bar counts from the fresh slot list (Unified in Sort.lua)
	if A.GPH_SyncRarityBar then A.GPH_SyncRarityBar(slotList, bf) end
	
	BankDebug("Step 7: entry aggregation finished, count=" .. tostring(#slotList))
	
	if bf.bankSpaceFs then A.SafeSetText(bf.bankSpaceFs, usedBankSlots .. "/" .. totalBankSlots) end
	bf._bankUsedSlots = usedBankSlots
	
    -- Apply Skin then Customizations
    if bf.ApplySkin then bf:ApplySkin() end
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
    BankDebug("Step 8: sort finished")
	
	local filterQ = bf.bankRarityFilter
	if filterQ ~= nil then
		if not A._bankFilteredList then A._bankFilteredList = {} end
        wipe(A._bankFilteredList)
		local filtered = A._bankFilteredList
		for _, info in ipairs(slotList) do
			local q = info.quality or 0
			if q == filterQ or (filterQ == 4 and (q == 5 or q == 6 or q == 7)) then filtered[#filtered + 1] = info end
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
	
	bf.bankDefaultScrollY = nil
	bf._bankDeleteClickTime = bf._bankDeleteClickTime or {}
	
	local yOff = 0
	local listToUse = (sortMode == "category" and bf.gphCategoryDrawList) or slotList
	
	-- Fallback for Autodelete divider when NOT in category mode
	if sortMode ~= "category" then
		local destroyed = {}
		local normal = {}
		local destroyList = A.GetGphDestroyList and A.GetGphDestroyList() or {}
		for _, item in ipairs(slotList) do
			if item.itemId and destroyList[item.itemId] then
				table.insert(destroyed, item)
			else
				table.insert(normal, item)
			end
		end
		
		if #destroyed > 0 then
			local defCollapsed = (bf.bankCategoryCollapsed and bf.bankCategoryCollapsed["DELETE"] ~= false)
			if not bf._bankInternalDrawList then bf._bankInternalDrawList = {} end
			local draw = bf._bankInternalDrawList; wipe(draw)
			for _, item in ipairs(normal) do table.insert(draw, item) end
			local delDiv = A.GetRecycledBankTable()
			delDiv.divider = "DELETE"
			delDiv.collapsed = defCollapsed
			table.insert(draw, delDiv)
			if not defCollapsed then 
				for _, item in ipairs(destroyed) do table.insert(draw, item) end 
			end
			listToUse = draw
		end
	end
	local bankDividerIndex = 0
	bf.bankItemIndexToY = bf.bankItemIndexToY or {}
	wipe(bf.bankItemIndexToY)
	
	local QUALITY_COLORS = Addon and A.QUALITY_COLORS or {}
	if bf.gphCategoryDividerPool then for _, d in ipairs(bf.gphCategoryDividerPool) do d:Hide() end end
    local dividerClickHandler = function(self)
        if not bf.bankCategoryCollapsed then bf.bankCategoryCollapsed = {} end
        local cat = self.categoryName
        local isCollapsed = (cat == "DELETE") and (bf.bankCategoryCollapsed["DELETE"] ~= false) or bf.bankCategoryCollapsed[cat]
        bf.bankCategoryCollapsed[cat] = not isCollapsed
        if RefreshBankUI then RefreshBankUI() end
    end

    bf._gphDivIdx = 0
	for idx, entry in ipairs(listToUse) do
        local newY, isDiv = A.GPH_RenderCategoryDivider(bf, content, entry, yOff, dividerClickHandler)
        if isDiv then
            yOff = newY
        elseif entry.divider then
            -- Skip hidden headings
        else
			local row = GetBankRow(content)
			if firstRow == nil then firstRow = row end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
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
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
			row:SetHeight(rowStep)
			if row.clickArea and row.clickArea.SetHeight then row.clickArea:SetHeight(rowStep) end
 			row.bagID = bagID
 			row.slotID = slotID
 			row.clickArea.bagID = bagID
 			row.clickArea.slotID = slotID

            if not row._scriptsBound then
                row._scriptsBound = true
                row.clickArea:SetScript("OnMouseDown", BankRow_clickArea_OnMouseDown)
                row.clickArea:SetScript("OnClick", BankRow_clickArea_OnClick)
                row.clickArea:SetScript("OnReceiveDrag", BankRow_clickArea_OnReceiveDrag)
                row.clickArea:SetScript("OnMouseUp", BankRow_clickArea_OnMouseUp)
                row.clickArea:SetScript("OnEnter", BankRow_clickArea_OnEnter)
                row.clickArea:SetScript("OnLeave", BankRow_clickArea_OnLeave)
                row.clickArea:SetScript("OnMouseWheel", BankRow_clickArea_OnMouseWheel)
            end

			-- local link = info.link or (GetContainerItemLink and GetContainerItemLink(bagID, slotID)) -- info.link should be sufficient
			if idx == 1 and BANK_DEBUG then
				BankDebug("Step 5: first row parent=" .. tostring(row:GetParent()) .. " content=" .. tostring(content) .. " row:IsShown()=" .. tostring(row:IsShown()) .. " content:GetParent()=" .. tostring(content:GetParent()))
			end
			-- Removed redundant local bagID, slotID = info.bagID, info.slotID

			-- Identity Cache Check
			local quality = info.quality or 0
			local name = info.name or (info.link and A.GetCachedItemInfo(info.link)) or "Empty"
			local count = info.count or 0
				local fSize = SV and SV.gphItemDetailsFontSize or 11
				local fPath = SV and SV.gphItemDetailsFont or ""
				local fAlpha = SV and SV.gphItemDetailsAlpha or 1.0
				local fIconSize = SV and SV.gphItemDetailsIconSize or 16
				local hideIconsBank = SV and SV.gphHideIconsInList
				local rowFormattingEnabled = SV and SV.gphItemDetailsCustom

				local state = row._visualState
				if not state then state = {}; row._visualState = state end
				if state.bag == bagID and state.slot == slotID and state.id == info.itemId and state.count == count and state.prot == info.isProtected and state.worn == info.previouslyWorn and state.hideIcons == hideIconsBank and state.customFormatting == rowFormattingEnabled and state.fontSize == fSize and state.fontPath == fPath and state.formattingAlpha == fAlpha and state.iconSize == fIconSize then
					-- Skip details, but still show the row
					row:Show()
				else
					state.bag = bagID; state.slot = slotID; state.id = info.itemId; state.count = count; state.prot = info.isProtected; state.worn = info.previouslyWorn; state.hideIcons = hideIconsBank; state.customFormatting = rowFormattingEnabled; state.fontSize = fSize; state.fontPath = fPath; state.formattingAlpha = fAlpha; state.iconSize = fIconSize
				
					if hideIconsBank then
						row.icon:Hide()
						if row.protectedOverlay then row.protectedOverlay:Hide() end
						row.nameFs:ClearAllPoints()
						row.nameFs:SetPoint("LEFT", row.clickArea, "LEFT", 4, 0)
						row.nameFs:SetPoint("RIGHT", row.clickArea, "RIGHT", -40, 0)
					else
					row.icon:Show()
					row.icon:SetSize(fIconSize, fIconSize)
					local texture = info.texture or (GetContainerItemInfo and GetContainerItemInfo(bagID, slotID))
					row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
					row.nameFs:ClearAllPoints()
					row.nameFs:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
					row.nameFs:SetPoint("RIGHT", row.clickArea, "RIGHT", -40, 0)
				end
				
				if not hideIconsBank then
					if info.isProtected then
						if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
						row.icon:SetVertexColor(0.65, 0.65, 0.65)
					else
						if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
						row.icon:SetVertexColor(1, 1, 1)
					end
				end

				local rowFormattingEnabled = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsCustom
				if row.nameFs then
					local displayName = name or "Unknown"
					if rowFormattingEnabled then
						local fontPath, fontSize = A.GetCategoryHeaderFontAndSize()
						local path = (SV and SV.gphItemDetailsFont and SV.gphItemDetailsFont ~= "") and SV.gphItemDetailsFont or fontPath or "Fonts\\FRIZQT__.TTF"
						fSize = (SV and SV.gphItemDetailsFontSize and SV.gphItemDetailsFontSize >= 8) and SV.gphItemDetailsFontSize or 11
						row.nameFs:SetFont(path, fSize, "")
						
						local qInfo = (A.QUALITY_COLORS and A.QUALITY_COLORS[quality]) or { r = 1, g = 1, b = 1 }
						local rC, gC, bC = qInfo.r or 1, qInfo.g or 1, qInfo.b or 1
						if info.isProtected and name ~= "Hearthstone" then
							local mix, grey = 0.28, 0.48
							rC = rC * mix + grey * (1 - mix)
							gC = gC * mix + grey * (1 - mix)
							bC = bC * mix + grey * (1 - mix)
						end
						local hex = string.format("%02x%02x%02x", math.floor(rC * 255), math.floor(gC * 255), math.floor(bC * 255))
						A.SafeSetText(row.nameFs, "|cff" .. hex .. displayName .. "|r")
						row.nameFs:SetTextColor(1, 1, 1, fAlpha or 1)
					else
						row.nameFs:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
						local qInfo = QUALITY_COLORS[quality] or { r = 0.8, g = 0.8, b = 0.8, hex = "cccccc" }
						local nameHex = A.GetItemNameHex(quality, info.isProtected, qInfo)
						A.SafeSetText(row.nameFs, "|cff" .. (nameHex or "cccccc") .. displayName .. "|r")
					end
				end

				if (info.isProtected or info.previouslyWorn) and not rowFormattingEnabled then
					if row.protectedOverlay then row.protectedOverlay:Show() end
				else
					if row.protectedOverlay then row.protectedOverlay:Hide() end
				end
				
				A.SafeSetText(row.countFs, (count and count > 1) and ("|cffaaaaaa x" .. tostring(count) .. "|r") or "")
				row.totalCount = count
				
				if row.clickArea and bagID ~= nil and slotID ~= nil and _G.FugaziBAGS_EnsureSecureRowBtn then
					_G.FugaziBAGS_EnsureSecureRowBtn(row.clickArea, bagID, slotID)
				end
				-- Handled outside cache block below

			end -- END VISUAL CACHE BLOCK
				-- [CONSOLIDATED] ApplyItemDetailsToRow call removed.
				-- A.ApplyItemDetailsToRow(row, name, quality, info.isProtected, info.itemId)

				row.cachedItem = info
				if row.cooldownOverlay then
					local map = bf._gphIdToSlotMap
					if A.FugaziBAGS_CheckRowCooldown and A.FugaziBAGS_CheckRowCooldown(row, info, map) then
						row:SetScript("OnUpdate", FugaziBankRow_OnUpdateCooldown)
					else
						row:SetScript("OnUpdate", nil)
					end
				end

            yOff = yOff + rowStep
		end
	end

	content:SetHeight(math.max(yOff, 1))
	
	local aggN = 0
	for _ in pairs(aggregated) do aggN = aggN + 1 end
	if aggN == 0 and totalBankSlots > 0 and not bf._bankDeferRefresh then
		bf._bankDeferRefresh = true
		if not bf._bankRefreshDefer then bf._bankRefreshDefer = CreateFrame("Frame") end
		bf._bankRefreshDefer:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if bf:IsShown() and RefreshBankUI then RefreshBankUI() end
		end)
	end
	BankDebug("Step 6: yOff=" .. tostring(yOff) .. " content:GetHeight()=" .. tostring(content:GetHeight()) .. " content:GetParent()=" .. tostring(content:GetParent()) .. " content:IsShown()=" .. tostring(content:IsShown()))
	local scroll = bf.scrollFrame
	local scrollBar = bf.scrollBar
	BankDebug("Step 7: scroll=" .. tostring(scroll) .. " scrollBar=" .. tostring(scrollBar))
	if scroll then
		BankDebug("Step 7b: scroll:GetWidth()=" .. tostring(scroll:GetWidth()) .. " scroll:GetHeight()=" .. tostring(scroll:GetHeight()) .. " scroll:GetParent()=" .. tostring(scroll:GetParent()))
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
		BankDebug("Step 8: viewH=" .. tostring(viewH) .. " maxScroll=" .. tostring(maxScroll) .. " offset=" .. tostring(offset))
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
	if BANK_DEBUG and content.GetNumChildren then
		BankDebug("Step 9: content:GetNumChildren()=" .. tostring(content:GetNumChildren()))
	end
    BankDebug("RefreshBankUI FINISHED. bf:IsShown()=" .. tostring(bf:IsShown() and "TRUE" or "FALSE") .. " bf:IsVisible()=" .. tostring(bf:IsVisible() and "TRUE" or "FALSE") .. " bf:GetAlpha()=" .. tostring(bf:GetAlpha()))
    
    -- Sync modular rarity buttons (now handled in OrganizeBagCategories)
	
	local purchased = A.FB_GetPurchasedBankBags and A.FB_GetPurchasedBankBags() or 0
	for i = 1, NUM_BANK_BAGS do
		local btn = bf.bagSlots and bf.bagSlots[i]
		if btn then
			local bagID = (NUM_BAG_SLOTS or 4) + i
			if i <= purchased then
				local invID = ContainerIDToInventoryID and ContainerIDToInventoryID(bagID)
				local bagTexture = invID and GetInventoryItemTexture and GetInventoryItemTexture("player", invID)
				
				if bagTexture then
					-- BAG EQUIPPED: Show bag icon in full color
					btn.icon:SetTexture(bagTexture)
					if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
					btn.icon:SetVertexColor(1, 1, 1, 1)
				else
					-- EMPTY BOUGHT SLOT: Show default icon greyed out
					btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
					if btn.icon.SetDesaturated then btn.icon:SetDesaturated(true) end
					btn.icon:SetVertexColor(0.5, 0.5, 0.5, 0.6)
				end
				btn:Show()
			elseif i == purchased + 1 then
				-- NEXT UNBOUGHT SLOT: Show in full color (Actionable)
				btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
				if btn.icon.SetDesaturated then btn.icon:SetDesaturated(false) end
				btn.icon:SetVertexColor(1, 1, 1, 1)
				btn:Show()
			else
				-- LOCKED
				btn:Hide()
			end
		end
	end

    if CleanupBankRowPool then CleanupBankRowPool() end

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
            if RefreshBankUI then RefreshBankUI() end
            
            if bf.gphGridMode and _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.BankRefreshSlots then
                _G.FugaziBAGS_CombatGrid.BankRefreshSlots()
            end
        end)
    end
end
_G.FugaziBAGS_ScheduleRefreshBankUI = FugaziBAGS_ScheduleRefreshBankUI




function A.NegotiateSizes(self)
    if not _G.FugaziBAGSDB then return end
    
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    local bW, bH, iW, iH
    
    local cg = _G.FugaziBAGS_CombatGrid
    
    
    local inv = self or A.Inventory
    if not inv then return end

    local DB = _G.FugaziBAGSDB
    if inv.gphGridMode then
        iW = inv.gphGridFrameW or inv:GetWidth()
        iH = inv.gphGridFrameH or inv:GetHeight()
    elseif cg and cg.ComputeFrameSize then
        iW, iH = cg.ComputeFrameSize(false)
        -- Ensure minimum height for list mode (default 520)
        local minH = (DB.gphMinHeight or inv.EXPANDED_HEIGHT or 520)
        iH = math.max(iH or 0, minH)
    else
        iW = 340
        iH = inv.EXPANDED_HEIGHT or 520
    end
    
    -- Fallback to last saved height
    local savedPoint = DB and DB.gphPoint
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
        finalW = math.max(bW or 0, iW or 0)
        finalH = math.max(bH or 0, iH or 0)
        
        if bank:GetWidth() ~= finalW then bank:SetWidth(finalW) end
        if bank:GetHeight() ~= finalH then bank:SetHeight(finalH) end
    end
    
    if inv:GetWidth() ~= finalW then inv:SetWidth(finalW) end
    if inv:GetHeight() ~= finalH then inv:SetHeight(finalH) end
end

A.CreateBankFrame = CreateBankFrame


local function StealthHideElvUIBank()
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.GetModule then
        local B = E:GetModule("Bags")
        if B then
            if B.BankFrame then
                local f = B.BankFrame
                f:ClearAllPoints()
                f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
                f:SetAlpha(0)
                f:EnableMouse(false)
                  if not f._TestStealthHook and hooksecurefunc then
                    f._TestStealthHook = true
                    hooksecurefunc(f, "Show", function()
                        if f and f.ClearAllPoints then
                            f:ClearAllPoints()
                            f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
                            f:SetAlpha(0)
                            f:EnableMouse(false)
                        end
                        if _G.FugaziBAGS_AddonEnabled ~= false then
                            local bf_gph = A.Bank
                            if bf_gph and not bf_gph:IsShown() then
                                if A.doShowFugaziBank then A.doShowFugaziBank() end
                            end
                        end
                    end)
                    hooksecurefunc(f, "Hide", function()
                        if _G.FugaziBAGS_AddonEnabled ~= false then
                            local bf_gph = A.Bank
                            if bf_gph and bf_gph:IsShown() then
                                bf_gph:Hide()
                            end
                        end
                    end)
                end
            end
            if B.BagFrame then
                local bf = B.BagFrame
                bf:ClearAllPoints()
                bf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
                bf:SetAlpha(0)
                bf:EnableMouse(false)
                if not bf._TestStealthHook and hooksecurefunc then
                    bf._TestStealthHook = true
                    hooksecurefunc(bf, "Show", function()
                        if bf and bf.ClearAllPoints then
                            bf:ClearAllPoints()
                            bf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
                            bf:SetAlpha(0)
                            bf:EnableMouse(false)
                        end
                        if _G.FugaziBAGS_AddonEnabled ~= false then
                            local gf = A.Inventory
                            local container = gf and gf.gphInventoryContainer
                            if container then
                                if not container:IsShown() then
                                    if A.ToggleGPHFrame then A.ToggleGPHFrame() end
                                end
                            elseif gf and not gf:IsShown() then
                                if A.ToggleGPHFrame then A.ToggleGPHFrame() end
                            end
                        end
                    end)
                    hooksecurefunc(bf, "Hide", function()
                        if _G.FugaziBAGS_AddonEnabled ~= false then
                            local atVendor = _G.MerchantFrame and _G.MerchantFrame:IsShown()
                            local atMailbox = _G.MailFrame and _G.MailFrame:IsShown()
                            local atAH = _G.AuctionFrame and _G.AuctionFrame:IsShown()
                            local atBank = (A.Bank and A.Bank:IsShown()) or (_G.BankFrame and _G.BankFrame:IsShown())
                            if not (atVendor or atMailbox or atAH or atBank) then
                                local gf = A.Inventory
                                local container = gf and gf.gphInventoryContainer
                                if container then
                                    if container:IsShown() then
                                        if A.ToggleGPHFrame then A.ToggleGPHFrame() end
                                    end
                                elseif gf and gf:IsShown() then
                                    if A.ToggleGPHFrame then A.ToggleGPHFrame() end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
    local evBank = _G.ElvUI_BankContainerFrame
    if evBank and evBank.ClearAllPoints then
        evBank:ClearAllPoints()
        evBank:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
        evBank:SetAlpha(0)
        evBank:EnableMouse(false)
    end
    local evBags = _G.ElvUI_ContainerFrame
    if evBags and evBags.ClearAllPoints then
        evBags:ClearAllPoints()
        evBags:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
        evBags:SetAlpha(0)
        evBags:EnableMouse(false)
    end
end
A.StealthHideElvUIBank = StealthHideElvUIBank


local bankOpenRetryFrame = CreateFrame("Frame")
bankOpenRetryFrame:Hide()
bankOpenRetryFrame._t = 0
bankOpenRetryFrame._retryCount = 0
bankOpenRetryFrame:SetScript("OnUpdate", function(self, elapsed)
    self._t = self._t + elapsed
    if self._t < 0.2 then return end
    self._t = 0
    self._retryCount = self._retryCount + 1
    if RefreshBankUI then RefreshBankUI() end
    
    local used = A.Bank and A.Bank._bankUsedSlots or 0
    if used > 0 or self._retryCount >= 5 then
        self:Hide()
    end
end)


local function doShowFugaziBank()
    local bf = A.Bank
    if bf and bf:IsShown() and (GetTime() - (bf._lastShowTime or 0)) < 0.1 then return end
    BankDebug("doShowFugaziBank called")
    if not Addon then BankDebug("doShowFugaziBank: Addon is NIL") return end
    if not A.HideBlizzardBags then 
        BankDebug("doShowFugaziBank: A.HideBlizzardBags is NIL")
        print("|cffff0000[Bank Error]|r FugaziBAGS: A.HideBlizzardBags is missing!")
        return 
    end
    -- Redundant: moved to login/initialization check to avoid event loops
    -- A.HideBlizzardBags(true)
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
        
        if inv then
            bf:SetParent(inv)
            bf:SetScale(1)
            inv:Show()
            if inv.gphInventoryContainer then
                inv.gphInventoryContainer:Show()
            end
            if _G.RefreshGPHUI then _G.RefreshGPHUI() end
            do
                local p, r, rp, x, y = inv:GetPoint(1)
                if p and rp and x and y then
                    inv._gphPreBankAnchor = { p, r, rp, x, y }
                    if not (p == "TOPLEFT" and rp == "TOP" and x == 2 and y == -80) then
                        if A.SaveFrameLayout then
                            A.SaveFrameLayout(inv, nil, "gphPreBankPoint")
                            A.SaveFrameLayout(inv, "gphShown", "gphPoint")
                        end
                    end
                end
            end
            inv:ClearAllPoints()
            inv:SetPoint("TOPLEFT", UIParent, "TOP", 2, -80)
        else
            bf:SetParent(UIParent)
            bf:SetScale(1)
        end
        bf:ClearAllPoints()
        if inv then bf:SetPoint("TOPRIGHT", inv, "TOPLEFT", -4, 0)
        else bf:SetPoint("TOP", UIParent, "CENTER", 200, -100) end
        A.Bank:Show()
        
        if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyBankFrameSkin then
             _G.__FugaziBAGS_Skins.ApplyBankFrameSkin(bf)
        end
        if bf.bankTitleText then
            bf.bankTitleText:SetText((UnitName and UnitName("target")) or "Bank")
        end

        if RefreshBankUI then 
            RefreshBankUI() 
            
            bankOpenRetryFrame._t = 0
            bankOpenRetryFrame._retryCount = 0
            bankOpenRetryFrame:Show()
        end
        
        
        local cg = _G.FugaziBAGS_CombatGrid
        if cg then
            local wantBankGrid = GetPerChar and A.GetPerChar("gphBankGridMode", false)
            bf.gphGridMode = wantBankGrid
            if wantBankGrid then
                if cg.ShowInBankFrame then cg.ShowInBankFrame(bf) end
            else
                if cg.HideInBankFrame then cg.HideInBankFrame(bf) end
            end
        end
        if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
        BankDebug("Step 10: doShowFugaziBank logic completed. bf:IsVisible()=" .. tostring(bf:IsVisible() and "TRUE" or "FALSE"))
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
            BankDebug("Hooking BankFrame.Show (Direct Overwrite)")
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
bankEventFrame:RegisterEvent("BAG_UPDATE")

bankEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "BAG_UPDATE" then
        if A.Bank and A.Bank:IsShown() and RefreshBankUI then
            if not A.bankUpdateDeferFrame then A.bankUpdateDeferFrame = CreateFrame("Frame") end
            local bdef = A.bankUpdateDeferFrame
            if not bdef._bankScheduled then
                bdef._bankScheduled = true
                bdef._accum = 0
                bdef:SetScript("OnUpdate", function(self2, elapsed)
                    self2._accum = (self2._accum or 0) + elapsed
                    if self2._accum < 0.2 then return end
                    self2:SetScript("OnUpdate", nil)
                    self2._bankScheduled = nil
                    if A.Bank and A.Bank:IsShown() and RefreshBankUI then RefreshBankUI() end
                end)
            end
        end
    elseif event == "BANKFRAME_OPENED" then
        BankDebug("EVENT: BANKFRAME_OPENED")
        if InCombatLockdown and InCombatLockdown() then BankDebug("BANKFRAME_OPENED: InCombatLockdown!") return end
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
        BankDebug("EVENT: BANKFRAME_CLOSED")
        if A.Bank then
            local now = GetTime()
            if now - (A.Bank._lastShowTime or 0) < 0.5 then
                BankDebug("BANKFRAME_CLOSED: Ghost Close detected! IGNORING hide.")
                return
            end
            BankDebug("BANKFRAME_CLOSED: Hiding Fugazi_Bank")
            A.Bank:Hide()
            A.Bank._bankDeferRefresh = nil
            A.Bank._bankCountDebugDone = nil
        end
        local inv = A.Inventory
        if inv then
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
            inv._gphRestoredFromBankOnHide = nil
        end
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if _G.FugaziBAGS_ScheduleRefreshBankUI then
            _G.FugaziBAGS_ScheduleRefreshBankUI()
        end
    end
end)



--- Next item of given quality in bank.
local function FindNextFromBank(rarity)
    local function qualityMatches(r, q)
        if q == r then return true end
        if r == 4 and q >= 4 then return true end
        return false
    end
    local function scanBag(bagID)
        if not bagID then return nil, nil end
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bagID) or 0
        if not numSlots or numSlots <= 0 then return nil, nil end
        for slot = 1, numSlots do
            local _, _, locked = GetContainerItemInfo(bagID, slot)
            local itemId = GetContainerItemID and GetContainerItemID(bagID, slot)
            if itemId and not locked then
                local _, _, q = A.GetCachedItemInfo(itemId)
                q = q or 0
                if qualityMatches(rarity, q) and not A.RarityIsProtected(itemId, q) then
                    return bagID, slot
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
local function FindNextFromBags(rarity, categoryName)
    local items = A.GetCachedBagItems and A.GetCachedBagItems()
    if not items then return nil, nil end
    for i = 1, #items do
        local e = items[i]
        local _, _, locked = GetContainerItemInfo(e.bag, e.slot)
        if not locked and not (A.IsItemProtectedAPI and A.IsItemProtectedAPI(e.itemId, e.quality)) then
            if categoryName then
                local itemCat = "Other"
                if e.itemId == A.HEARTHSTONE_ID then itemCat = "HIDDEN_FIRST"
                elseif A.IsQuestItem and A.IsQuestItem(e.link) then itemCat = "Quest"
                elseif e.quality == 0 then itemCat = "Miscellaneous"
                else
                    local name, _, quality, _, _, giType, giSubType = A.GetCachedItemInfo(e.link)
                    if giSubType == "Reagent" then itemCat = "Trade Goods"
                    else itemCat = (giType and giType ~= "" and giType) or "Other" end
                end
                if itemCat == categoryName then
                    return e.bag, e.slot
                end
            elseif rarity then
                local q = e.quality or 0
                if q == rarity or (rarity == 4 and q >= 4) then
                    return e.bag, e.slot
                end
            end
        end
    end
    return nil, nil
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

    if job.mode == "bags_to_guildbank" then
        if not _G.GuildBankFrame or not _G.GuildBankFrame:IsShown() then
            A.RarityMoveJob = nil
            ClearCursor()
            self:Hide()
            return
        end
        local srcBag, srcSlot = FindNextFromBags(job.rarity, job.category)
        if not srcBag or not srcSlot then
            A.RarityMoveJob = nil
            self:Hide()
            return
        end
        UseContainerItem(srcBag, srcSlot)
        return
    end

    if job.mode == "bags_to_mail" then
        if not _G.MailFrame or not _G.MailFrame:IsShown() then
            A.RarityMoveJob = nil
            ClearCursor()
            self:Hide()
            return
        end
        local srcBag, srcSlot = FindNextFromBags(job.rarity, job.category)
        if not srcBag or not srcSlot then
            A.RarityMoveJob = nil
            self:Hide()
            return
        end
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

    local srcBag, srcSlot
    if job.mode == "bags_to_bank" then
        srcBag, srcSlot = FindNextFromBags(job.rarity, job.category)
    else
        srcBag, srcSlot = A.FindNextFromBank(job.rarity)
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

    ClearCursor()
    if PickupContainerItem then
        PickupContainerItem(srcBag, srcSlot)
        PickupContainerItem(destBag, destSlot)
    end

    if RefreshBankUI then RefreshBankUI() end
    if RefreshGPHUI then RefreshGPHUI() end
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
    return A.GetPerChar("gphBankGridMode", false)
end

function A.SetBankGridMode(enabled)
    A.SetPerChar("gphBankGridMode", enabled)
    if _G.RefreshBankUI then _G.RefreshBankUI() end
end


--- Modular tooltip registration for rarity buttons.
-- This allows the Bank to add 'Send to Bank' when open.
local origGetModularRarityTooltip = A.GetModularRarityTooltip
function A.GetModularRarityTooltip(rarity, tt)
    -- Chain to existing modular tooltips if any (like from Mail)
    if origGetModularRarityTooltip then 
        origGetModularRarityTooltip(rarity, tt) 
    end

    -- Add Bank-specific action if bank is open
    local f = A.Bank
    if f and f:IsShown() then
        tt:AddLine("Shift+RMB: Send Rarity to Bank", 0.6, 0.6, 0.6)
    end
end
    
