--[[
    FugaziBAGS_Core.lua
    The Master Entry Point & Event Router for the FugaziBAGS A.
    - Handles Database initialization and defaults.
    - Manages the master event router (eventFrame).
    - Coordinates frame toggling and layout persistence.
]]

--------------------------------------------------------------------------------
-- 1. NAMESPACE & API MAPPINGS
--------------------------------------------------------------------------------
local ADDON_NAME = "FugaziBAGS"
_G["FugaziBAGS"] = _G["FugaziBAGS"] or {}
local Addon = _G["FugaziBAGS"]
local A = Addon
A.DB = _G.FugaziBAGSDB

-- WoW API Mappings (Performance & Taint reduction)
local GetMoney, GetTime = _G.GetMoney, _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsControlKeyDown, IsAltKeyDown = _G.IsControlKeyDown, _G.IsAltKeyDown
local UIFrameFadeIn, UIFrameFadeOut = _G.UIFrameFadeIn, _G.UIFrameFadeOut


--------------------------------------------------------------------------------
-- 2. UTILITIES & COORDINATION
--------------------------------------------------------------------------------
local function GetPerChar(key, default) return A.GetPerChar(key, default) end
local function SetPerChar(key, value) A.SetPerChar(key, value) end

local function RunAddonLoader() return A.RunAddonLoader() end
local function CreateGPHFrame(...) return A.CreateGPHFrame(...) end
local function RefreshGPHUI() if _G.RefreshGPHUI then _G.RefreshGPHUI() end end
local function RefreshBankUI() if _G.RefreshBankUI then _G.RefreshBankUI() end end

--------------------------------------------------------------------------------
-- 4. MASTER EVENT ROUTER
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
A.Inventory = nil
A.Bank = nil

-- Master refresh flags
local isRefreshPending = false
local isBankRefreshPending = false
local isCooldownOnly = false -- New flag for lightweight updates
local isDestroyerScanPending = false

A.RegisteredUpdaters = A.RegisteredUpdaters or {} -- Table for external modules to register their OnUpdate logic

eventFrame.throttle = 0
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    
    -- 1. Throttled UI Refreshes & Destroyer Scans (Debouncing events)
    if isRefreshPending or isBankRefreshPending or isDestroyerScanPending then
        self.throttle = (self.throttle or 0) + elapsed
        if self.throttle >= 0.15 then
            self.throttle = 0
            
            -- Skip UI redraws while Auto-Sell is actively processing items
            if A.isAutoSelling then
                return
            end
            
            -- If it was ONLY a cooldown update, we can skip the expensive list layout
            -- if the list view is active (which handles cooldowns via its own OnUpdate).
            local skipFullForList = isCooldownOnly
            
            if isRefreshPending then
                isRefreshPending = false
                local inv = A.Inventory
                if inv and inv:IsShown() then
                    if skipFullForList and not inv.gphGridMode then
                        -- List view handles row cooldowns via internal OnUpdate, skip full refresh
                    else
                        RefreshGPHUI()
                    end
                end
            end
            
            if isBankRefreshPending then
                isBankRefreshPending = false
                local bank = A.Bank
                if bank and bank:IsShown() then
                    if skipFullForList and not bank.gphGridMode then
                        -- Bank list handles row cooldowns via internal OnUpdate
                    else
                        RefreshBankUI()
                    end
                end
            end
            
            isCooldownOnly = false -- Reset flag
            
            if isDestroyerScanPending then
                isDestroyerScanPending = false
                if A.ScanBagsForDestruction then 
                    -- A.AddonPrint("Triggering ScanBagsForDestruction from Core...")
                    A.ScanBagsForDestruction() 
                end
            end
        end
    end

    -- 2. Master Clock (Pulse & Animations)
    -- We tick the master clock at full speed for animations, but modules
    -- can handle their own sub-throttling internally.
    for name, func in pairs(A.RegisteredUpdaters) do
        local ok, err = pcall(func, now, elapsed)
        if not ok then
            print("|cffff0000[FugaziBAGS]|r Clock Error ("..name.."): "..tostring(err))
            A.RegisteredUpdaters[name] = nil -- Remove failing updaters to prevent spam
        end
    end
end)

-- Setup standard WoW event registrations
local events = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD",
    "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "PLAYERBANKSLOTS_CHANGED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "GOSSIP_SHOW", "QUEST_GREETING",
    "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE"
}
for _, ev in ipairs(events) do eventFrame:RegisterEvent(ev) end
if _G.C_Appearance then eventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED") end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "__FugaziBAGS" then
            A.DB = _G.FugaziBAGSDB
            RunAddonLoader()
        end

    elseif event == "PLAYER_LOGIN" then
        RunAddonLoader()

        -- Initialize main frame
        A.Inventory = CreateGPHFrame()
        local gphFrame = A.Inventory
        
        -- Global Toggling hook
        if not _G.ToggleGPHFrame then _G.ToggleGPHFrame = A.ToggleGPHFrame end
        if A.InstallGPHInvHook then A.InstallGPHInvHook() end
        if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
        
        -- Restore visual state
        A.RestoreFrameLayout(gphFrame, nil, "gphPoint")
        local SV = _G.FugaziBAGSDB
        if not (SV and SV.gphPoint and SV.gphPoint.point) then
            gphFrame:ClearAllPoints()
            gphFrame:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
        end
        
        -- Apply Scale & Skin
        local base = (SV and SV.gphScale15) and 1.5 or 1
        local extra = (SV and SV.gphFrameScale) or 1
        gphFrame:SetScale(base * extra)
        if gphFrame.ApplySkin then gphFrame.ApplySkin() end
        
        -- Register Master Updaters
        if A.RegisteredUpdaters then
            A.RegisteredUpdaters["RarityPulse"] = A.UpdateAllRarityVisuals
        end
        
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" or event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "TRANSMOG_COLLECTION_UPDATED" then
        local bagID = ...
        local isCd = (event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN")
        
        if event == "BAG_UPDATE" then
            A.ClearBagLinkCache(bagID) 
            A._gphBagSpaceDirty = true
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            if A.lockedDisenchantSlots then
                for key, lockTime in pairs(A.lockedDisenchantSlots) do
                    local bag, slot = key:match("^(%d+)_(%d+)$")
                    if bag and slot then
                        bag, slot = tonumber(bag), tonumber(slot)
                        if bag == bagID then
                            local currentID = GetContainerItemID and GetContainerItemID(bag, slot)
                            if not currentID then
                                A.lockedDisenchantSlots[key] = nil
                            end
                        end
                    end
                end
            end
            if A.activeDisenchantSlot and A.activeDisenchantSlot.bag == bagID then
                local currentID = GetContainerItemID and GetContainerItemID(A.activeDisenchantSlot.bag, A.activeDisenchantSlot.slot)
                if not currentID or currentID ~= A.activeDisenchantSlot.itemId then
                    A.activeDisenchantSlot = nil
                end
            end
        else
            A.ClearBagLinkCache(nil) -- Clear all for bank/delayed events
            A._gphBagSpaceDirty = true
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            if A.lockedDisenchantSlots then
                for key, lockTime in pairs(A.lockedDisenchantSlots) do
                    local bag, slot = key:match("^(%d+)_(%d+)$")
                    if bag and slot then
                        bag, slot = tonumber(bag), tonumber(slot)
                        local currentID = GetContainerItemID and GetContainerItemID(bag, slot)
                        if not currentID then
                            A.lockedDisenchantSlots[key] = nil
                        end
                    end
                end
            end
            if A.activeDisenchantSlot then
                local currentID = GetContainerItemID and GetContainerItemID(A.activeDisenchantSlot.bag, A.activeDisenchantSlot.slot)
                if not currentID or currentID ~= A.activeDisenchantSlot.itemId then
                    A.activeDisenchantSlot = nil
                end
            end
        end
        
        -- Use debouncing to prevent excessive updates durante looting/banking
        if gphFrame and gphFrame:IsShown() then
            isRefreshPending = true
            if isCd then isCooldownOnly = true end
        end
        if A.Bank and A.Bank:IsShown() then
            isBankRefreshPending = true
            if isCd then isCooldownOnly = true end
        end

        -- Always scan for autodelete if bags change, even if UI is hidden
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            isDestroyerScanPending = true
        end

    elseif event == "BANKFRAME_OPENED" or event == "BANKFRAME_CLOSED" then
        if A.ClearBagLinkCache then A.ClearBagLinkCache(nil) end -- Clear all on transition
    elseif event == "MERCHANT_SHOW" or event == "MAIL_SHOW" then
        -- Hide Blizzard bags and handle automation (Utils)
        if A.HideBlizzardBags then A.HideBlizzardBags() end
        if event == "MERCHANT_SHOW" and A.OnMerchantShow then A.OnMerchantShow() end
        
    elseif event == "MERCHANT_CLOSED" then
        if A.OnMerchantClosed then A.OnMerchantClosed() end
    end
end)

--------------------------------------------------------------------------------
-- 5. SLASH COMMANDS
--------------------------------------------------------------------------------
SLASH_FUGAZIGPH1 = "/gph"
SlashCmdList["FUGAZIGPH"] = function() 
    if _G.ToggleGPHFrame then _G.ToggleGPHFrame() end 
end
