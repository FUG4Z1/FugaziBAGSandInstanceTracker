--[[
  FugaziBAGS_Initialize: Addon Bootloader and Framework Hub
  Initializes the primary database (FugaziBAGSDB), establishes the global namespace,
  and manages the shared logic bridge between decoupled modules.
]]

local addonName, Addon = ...
-- Unify TOC private table and global (locales may have set global first).
if Addon then
    if _G.FugaziBAGS and _G.FugaziBAGS ~= Addon then
        for k, v in pairs(_G.FugaziBAGS) do
            if Addon[k] == nil then Addon[k] = v end
        end
    end
    _G.FugaziBAGS = Addon
else
    _G.FugaziBAGS = _G.FugaziBAGS or {}
end
local A = _G.FugaziBAGS

-- 1. DATABASE & CONFIGURATION
_G.FugaziBAGSDB = _G.FugaziBAGSDB or {}
A.DB = _G.FugaziBAGSDB
local DB = _G.FugaziBAGSDB
A.HEARTHSTONE_ID = 6948

-- Merge Defaults into the DB (never share table refs with DEFAULTS — in-place edits
-- would mutate the template and break next-login seeding / other chars).
if A._ConfigDefaults then
    for key, val in pairs(A._ConfigDefaults) do
        if DB[key] == nil then
            if type(val) == "table" and A.DeepCopy then
                DB[key] = A.DeepCopy(val)
            elseif type(val) == "table" then
                -- Fallback shallow-ish copy if DeepCopy not loaded yet (should not happen: Config before this).
                local t = {}
                for k, v in pairs(val) do t[k] = v end
                DB[key] = t
            else
                DB[key] = val
            end
        end
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
-- Safe no-op defaults until later TOC modules overwrite them.
-- Real impls: Listview (RefreshGPHUI), Pools (row pools), Utils (data pools),
-- Destroyer (QueueDestroy / IsSpellKnown). Data-table pools only — no row identity rewrite.
A.RefreshGPHUI = A.RefreshGPHUI or function(...) end
A.ResetGPHPools = A.ResetGPHPools or function(...) end
A.ResetGPHDataPools = A.ResetGPHDataPools or function(...) end
A.UpdateGphHeaderLayout = A.UpdateGphHeaderLayout or function(...) end

A.GetGPHRow = A.GetGPHRow or function(...) end
A.GetGPHText = A.GetGPHText or function(...) end
A.GetGPHItemBtn = A.GetGPHItemBtn or function(...) end

-- Interaction (Destroyer overwrites). Use `or` so a real impl is never replaced with a stub.
A.QueueDestroySlotsForItemId = A.QueueDestroySlotsForItemId or function(...) end
A.IsSpellKnownByName = A.IsSpellKnownByName or function(...) return false end



--- (BagKeyHandler and InstallBagHook moved to SecurePathsHandler.lua)

local addonLoaderDone = false
local instructionsChecked = false

--- Load addon UI after PLAYER_LOGIN (create frames, hooks).
function A.RunAddonLoader()
    -- Preferences are per-character: always hydrate when possible (player name ready).
    if A.HydrateCharSettings then
        A.HydrateCharSettings()
    end

    if not addonLoaderDone then
        addonLoaderDone = true

        -- Initialize Gear Tracking for Protection Module (Master Key Readiness)
        if A.GetEquippedItemIds then
            A.lastEquippedItemIds = A.lastEquippedItemIds or {}
            local current = A.GetEquippedItemIds()
            for id in pairs(current) do A.lastEquippedItemIds[id] = true end
        end

        if A.CreateOptionsPanel         then A.CreateOptionsPanel()         end
        if A.CreateValuationOptionsPanel then A.CreateValuationOptionsPanel() end
        if A.CreateGridviewOptionsPanel  then A.CreateGridviewOptionsPanel()  end
        if A.CreateSkinsPanel           then A.CreateSkinsPanel()           end
        if A.CreateInstructionsPanel    then A.CreateInstructionsPanel()    end

        print("|cff00aaff[__FugaziBAGS]|r Loaded. Bag key (B) opens inventory.")
    elseif _G.FugaziBAGSValuationOptionsPanel and _G.FugaziBAGSValuationOptionsPanel.refresh then
        -- Second RunAddonLoader (PLAYER_LOGIN): hydrate may have just filled floors.
        _G.FugaziBAGSValuationOptionsPanel.refresh()
    end

    -- First-open help: once per character (not account-wide). Wait until we have a char key.
    if not instructionsChecked and A.GetCharKey and A.GetCharKey() then
        instructionsChecked = true
        local seen = (A.GetOption and A.GetOption("seenInstructions")) or false
        if seen ~= true then
            if A.SetOption then
                A.SetOption("seenInstructions", true)
            else
                local DB = _G.FugaziBAGSDB or {}
                DB.seenInstructions = true
            end
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
    end
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


-- Auto-fill "Delete" and auto-confirm BoP items without tainting StaticPopupDialogs
hooksecurefunc("StaticPopup_Show", function(which)
    if which == "DELETE_GOOD_ITEM" then
        for i = 1, STATICPOPUP_NUMDIALOGS do
            local dialog = _G["StaticPopup"..i]
            if dialog and dialog:IsShown() and dialog.which == "DELETE_GOOD_ITEM" then
                if dialog.editBox then
                    dialog.editBox:SetText(DELETE_ITEM_CONFIRM_STRING or "Delete")
                end
            end
        end
    elseif which and (string.find(which, "LOOT_BIND") or string.find(which, "CONFIRM_LOOT")) then
        local SV = _G.FugaziBAGSDB
        if SV and SV.gphAutoConfirmBOP then
            Timer.After(0.01, function()
                for i = 1, STATICPOPUP_NUMDIALOGS do
                    local dialog = _G["StaticPopup"..i]
                    if dialog and dialog:IsShown() and dialog.which == which and dialog.button1 then
                        dialog.button1:Click()
                        break
                    end
                end
            end)
        end
    end
end)



