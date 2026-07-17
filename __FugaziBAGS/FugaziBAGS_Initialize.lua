--[[
  FugaziBAGS_Initialize: Addon Bootloader and Framework Hub
  Initializes the primary database (FugaziBAGSDB), establishes the global namespace,
  and manages the shared logic bridge between decoupled modules.
]]

local addonName, Addon = ...
_G.FugaziBAGS = _G.FugaziBAGS or Addon or {}
local A = _G.FugaziBAGS

-- 1. DATABASE & CONFIGURATION
_G.FugaziBAGSDB = _G.FugaziBAGSDB or {}
A.DB = _G.FugaziBAGSDB
local DB = _G.FugaziBAGSDB
A.HEARTHSTONE_ID = 6948

-- Merge Defaults into the DB (Config will handle the logic, but we ensure keys exist)
if A._ConfigDefaults then
    for key, val in pairs(A._ConfigDefaults) do
        if DB[key] == nil then DB[key] = val end
    end
end

-- Data Storage Architecture (ensure existence)
DB.gphPerChar = DB.gphPerChar or {}
DB.gphPreviouslyWornItemIds = DB.gphPreviouslyWornItemIds or {}
DB.gphProtectedItemIdsPerChar = DB.gphProtectedItemIdsPerChar or {}
DB.gphProtectedRarityPerChar = DB.gphProtectedRarityPerChar or {}
DB.gphPreviouslyWornOnlyPerChar = DB.gphPreviouslyWornOnlyPerChar or {}
DB.gphDestroyListPerChar = DB.gphDestroyListPerChar or {}
DB.gphItemTypeCache = DB.gphItemTypeCache or {}
DB._manualUnprotected = DB._manualUnprotected or {}

-- 1.1 CHARACTER KEY CACHE (prevents excessive string concatenation)
-- Logic moved to Config.lua; accessible via A.GetCharKey()
local CharKey = A.GetCharKey and A.GetCharKey()

-- Initialization Hooks
if DB.gphSkin == "fugazi" then
    DB._applyFugaziPresetOnLoad = true
end

-- Core Engine Shared State
A.gphFrame = nil
A.itemLinksCache = A.itemLinksCache or {}
A.gphDestroyQueue = A.gphDestroyQueue or {}
A.gphPendingQuality = A.gphPendingQuality or {}

-- 2. MASTER LOGIC BRIDGE (Modular Exports)
-- UI Engine (Forward Declarations / Defaults)
A.RefreshGPHUI = A.RefreshGPHUI or function(...) end
A.ResetGPHPools = A.ResetGPHPools or function(...) end
A.ResetGPHDataPools = A.ResetGPHDataPools or function(...) end
A.UpdateGphHeaderLayout = A.UpdateGphHeaderLayout or function(...) end

-- Factory Systems
A.GetRecycledAggTable = A.GetRecycledAggTable or function(...) end
A.GetRecycledItemTable = A.GetRecycledItemTable or function(...) end
A.GetGPHRow = A.GetGPHRow or function(...) end
A.GetGPHText = A.GetGPHText or function(...) end
A.GetGPHItemBtn = A.GetGPHItemBtn or function(...) end

-- Interaction Handlers (Destroyer / Combat)
A.DeleteGPHSlot = function(...) if A.DeleteGPHSlot then return A.DeleteGPHSlot(...) end end
A.DeleteGPHItem = function(...) if A.DeleteGPHItem then return A.DeleteGPHItem(...) end end
A.QueueDestroySlotsForItemId = function(...) if A.QueueDestroySlotsForItemId then return A.QueueDestroySlotsForItemId(...) end end
A.IsSpellKnownByName = function(...) if A.IsSpellKnownByName then return A.IsSpellKnownByName(...) end end



--- (BagKeyHandler and InstallBagHook moved to SecurePathsHandler.lua)

local addonLoaderDone = false

--- Load addon UI after PLAYER_LOGIN (create frames, hooks).
function A.RunAddonLoader()
    if addonLoaderDone then return end
    addonLoaderDone = true
    
    -- Initialize Gear Tracking for Protection Module (Master Key Readiness)
    if A.GetEquippedItemIds then
        A.lastEquippedItemIds = A.lastEquippedItemIds or {}
        local current = A.GetEquippedItemIds()
        for id in pairs(current) do A.lastEquippedItemIds[id] = true end
    end
    -- Panels now live in FugaziBAGS_Options.lua; call via A.
    if A.CreateOptionsPanel         then A.CreateOptionsPanel()         end
    if A.CreateGridviewOptionsPanel  then A.CreateGridviewOptionsPanel()  end
    if A.CreateSkinsPanel           then A.CreateSkinsPanel()           end
    if A.CreateInstructionsPanel    then A.CreateInstructionsPanel()    end
    
    local DB = _G.FugaziBAGSDB or {}

    if DB and DB.seenInstructions ~= true then
        DB.seenInstructions = true
        if InterfaceOptionsFrame_OpenToCategory then
            local instrPanel = _G.FugaziBAGSInstructionsOptionsPanel
            if instrPanel then
                InterfaceOptionsFrame_OpenToCategory(instrPanel)
                InterfaceOptionsFrame_OpenToCategory(instrPanel) 
            else
                InterfaceOptionsFrame_OpenToCategory("_FugaziBAGS")
                InterfaceOptionsFrame_OpenToCategory("_FugaziBAGS")
            end
        end
    end

    print("|cff00aaff[__FugaziBAGS]|r Loaded. Bag key (B) opens inventory.")
end


-- 3. BANK PURCHASE & POPUPS
local BANK_SLOT_COSTS = { 1000, 10000, 100000, 250000, 250000, 250000, 250000 }

function A.FB_GetPurchasedBankBags()
	if not GetNumBankSlots then return 0 end
	local num = GetNumBankSlots()
	if type(num) ~= "number" then num = 0 end
	if num < 0 then num = 0 end
	if num > #BANK_SLOT_COSTS then num = #BANK_SLOT_COSTS end
	return num
end

function A.FB_GetNextBankSlotCost()
	local purchased = A.FB_GetPurchasedBankBags()
	if purchased >= #BANK_SLOT_COSTS then
		return nil, true
	end
	return BANK_SLOT_COSTS[purchased + 1], false
end

if not StaticPopupDialogs["FUGAZI_BUY_BANK_SLOT"] then
	StaticPopupDialogs["FUGAZI_BUY_BANK_SLOT"] = {
		text = CONFIRM_BUY_BANK_SLOT,
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			if PurchaseSlot then
				PurchaseSlot()
				-- Force visual update
				if _G.FugaziBAGS_ScheduleRefreshBankUI then
					_G.FugaziBAGS_ScheduleRefreshBankUI()
				end
			end
		end,

		OnShow = function(self)
			local cost = select(1, A.FB_GetNextBankSlotCost())
			if self.moneyFrame and MoneyFrame_Update then
				MoneyFrame_Update(self.moneyFrame, cost or 0)
			end
		end,
		hasMoneyFrame = 1,
		timeout = 0,
		hideOnEscape = 1,
	}
end


-- 4. EXTERNAL INTEGRATIONS (ElvUI, etc)
--- Hide ElvUI bank when we show ours (avoid double bank).
function A.StealthHideElvUIBank()
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


-- Auto-fill "Delete" for item deletion popups
if StaticPopupDialogs["DELETE_GOOD_ITEM"] then
    local oldOnShow = StaticPopupDialogs["DELETE_GOOD_ITEM"].OnShow
    StaticPopupDialogs["DELETE_GOOD_ITEM"].OnShow = function(self, ...)
        if oldOnShow then oldOnShow(self, ...) end
        if self.editBox then
            self.editBox:SetText(DELETE_ITEM_CONFIRM_STRING or "Delete")
        end
    end
end



