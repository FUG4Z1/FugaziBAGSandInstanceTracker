--[[
    FugaziBAGS_Core.lua
    Master entry + non-UI bag duties for FugaziBAGS.

    Ownership (Phase 6.5 — one pipeline per concern):
      Listview  — inv UI: BAG_UPDATE/DELAYED → Wipe + L1/L3 RefreshGPHUI
      Bankview  — bank UI refresh + bank bag dirty
      Core      — DE lock cleanup, destroyer scan, item-info/transmog dirty,
                  0.3s backup refresh ONLY for events Listview does not own
                  (GET_ITEM_INFO_RECEIVED, TRANSMOG_COLLECTION_UPDATED).
      Grid      — inv/bank slot paint (not the bag-event bus owner)

    Do not re-add isRefreshPending for pure BAG_UPDATE — that was dual UI thrash.
]]

--------------------------------------------------------------------------------
-- 1. NAMESPACE & API MAPPINGS
--------------------------------------------------------------------------------
local ADDON_NAME = "FugaziBAGS"
-- Stay on the unified TOC/global table (set by Locales + Initialize). Do not create a second {}.
local _, ns = ...
if ns then
    if _G.FugaziBAGS and _G.FugaziBAGS ~= ns then
        for k, v in pairs(_G.FugaziBAGS) do
            if ns[k] == nil then ns[k] = v end
        end
    end
    _G.FugaziBAGS = ns
else
    _G.FugaziBAGS = _G.FugaziBAGS or {}
end
local Addon = _G.FugaziBAGS
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
local function RunAddonLoader() return A.RunAddonLoader() end
local function CreateGPHFrame(...) return A.CreateGPHFrame(...) end
-- Backup inv refresh for non-Listview events only (item info / transmog). Always L1.
local function RefreshGPHUI()
    if A.PromoteGPHRefreshLevel then A.PromoteGPHRefreshLevel(1) end
    if _G.RefreshGPHUI then _G.RefreshGPHUI() end
end

--------------------------------------------------------------------------------
-- 4. MASTER EVENT ROUTER
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
A.Inventory = nil
A.Bank = nil

-- Pending work for Core-owned duties (not Listview/Bankview bag UI).
local isRefreshPending = false   -- item-info / transmog / profession fallback
local isDestroyerScanPending = false

A.RegisteredUpdaters = A.RegisteredUpdaters or {} -- external OnUpdate (rarity pulse, etc.)

eventFrame.throttle = 0
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    
    -- 1. Debounced: Core backup inv UI (non-bag events) + destroyer scan
    if isRefreshPending or isDestroyerScanPending then
        self.throttle = (self.throttle or 0) + elapsed
        if self.throttle >= 0.3 then
            self.throttle = 0
            
            if A.isAutoSelling then
                return
            end
            
            if isRefreshPending then
                isRefreshPending = false
                local inv = A.Inventory
                if inv and inv:IsShown() then
                    -- Skip if Listview already painted recently (shared refresh stamp).
                    local alreadyHandled = inv._lastRefreshGPHUI and (now - inv._lastRefreshGPHUI) < 0.3
                    if not alreadyHandled then
                        RefreshGPHUI()
                    end
                end
            end
            
            if isDestroyerScanPending then
                isDestroyerScanPending = false
                if A.ScanBagsForDestruction then
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
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED",
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
            -- SV is available here (not at module file load). Restore open GPH farm session.
            if A.SyncGPHSessionFromDB then
                A.SyncGPHSessionFromDB()
            end
        end

    elseif event == "PLAYER_LOGOUT" then
        -- Persist live top-level prefs into this character's profile before SV is written.
        if A.SnapshotCharSettings then
            A.SnapshotCharSettings()
        end
        -- Ensure open GPH session (+ bag baseline) is on the SV root before write.
        if A.SyncGPHSessionToDB then
            A.SyncGPHSessionToDB()
        end

    elseif event == "PLAYER_LOGIN" then
        -- Always hydrate on login (player name is reliable here). ADDON_LOADED may have
        -- run the loader earlier without a character key.
        if A.HydrateCharSettings then
            A.HydrateCharSettings()
        end
        RunAddonLoader()
        -- Second chance: restore GPH if ADDON_LOADED path missed it.
        if A.SyncGPHSessionFromDB then
            A.SyncGPHSessionFromDB()
        end

        -- Initialize main frame
        A.Inventory = CreateGPHFrame()
        local gphFrame = A.Inventory
        -- Safety: Mail.lua loads after Frames in .toc; wire Get All/cleanup if chrome path skipped it.
        if A.SetupGPHMailButton and gphFrame and gphFrame.gphMailBtn then
            A.SetupGPHMailButton(gphFrame.gphMailBtn, gphFrame)
        end

        -- Global Toggling hook
        if not _G.ToggleGPHFrame then _G.ToggleGPHFrame = A.ToggleGPHFrame end
        if A.InstallGPHInvHook then A.InstallGPHInvHook() end
        if A.StealthHideElvUIBank then A.StealthHideElvUIBank() end
        
        -- Scale first, then position (restore-then-scale teleports under gphScale15).
        local SV = _G.FugaziBAGSDB
        local base = (SV and SV.gphScale15) and 1.5 or 1
        local extra = (SV and SV.gphFrameScale) or 1
        gphFrame:SetScale(base * extra)

        local hasPt = SV and SV.gphPoint and SV.gphPoint.x ~= nil and SV.gphPoint.y ~= nil
        if hasPt then
            A.RestoreFrameLayout(gphFrame, nil, "gphPoint")
        else
            gphFrame:ClearAllPoints()
            gphFrame:SetPoint("RIGHT", UIParent, "RIGHT", -444, -4)
        end
        
        -- Pre-size once at login (out of combat). NegotiateSizes is blocked in combat (taint).
        -- List preferred size uses options, not grid ComputeFrameSize (see Frames.GPH_PreferredFrameSize).
        -- NegotiateSizes re-pins BOTTOMLEFT before SetSize so position stays put.
        if A.NegotiateSizes then A.NegotiateSizes(gphFrame) end

        -- Register Master Updaters
        if A.RegisteredUpdaters then
            A.RegisteredUpdaters["RarityPulse"] = A.UpdateAllRarityVisuals
        end

    elseif event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" or event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
            if A.ClearProcessingState then
                A.ClearProcessingState()
            else
                if A.lockedDisenchantSlots then wipe(A.lockedDisenchantSlots) end
                A.activeDisenchantSlot = nil
                A.isDisenchanting = nil
            end
        end
        local forceDisabled = (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_DEAD")
        if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then forceDisabled = false end
        if A.Inventory and A.Inventory.UpdateGPHProfessionButtons then
            A.Inventory:UpdateGPHProfessionButtons(forceDisabled)
        else
            isRefreshPending = true
        end
        
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" or event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" or event == "TRANSMOG_COLLECTION_UPDATED" then
        local bagID = ...
        local isCd = (event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN")
        if isCd then
            if event == "BAG_UPDATE_COOLDOWN" and A.UpdateAllRowCooldowns then 
                A.UpdateAllRowCooldowns() 
            end
            return
        end
        
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            -- Dirty flags + DE lock cleanup only. Inv UI refresh is Listview's job
            -- (Wipe is same-frame deduped inside WipeBagLinkCache if both fire).
            -- Bare/nil BAG_UPDATE: soft-dirty (client idle ~20s pulse) — only wipe bags
            -- whose live contents differ from memory. Hard wipe-all was L1 thrash forever.
            local anyBagDirty = true
            if bagID ~= nil then
                -- Soft-dirty one bag: idle DELAYED(bag) must not force wipe every 20s.
                -- Bank bags still soft-check (no-op if never scanned / unchanged).
                if A.DirtyBagsIfContentsChanged then
                    anyBagDirty = A.DirtyBagsIfContentsChanged({ bagID })
                elseif A.WipeBagLinkCache then
                    A.WipeBagLinkCache(bagID)
                else
                    A.ClearBagLinkCache(bagID)
                    A._gphDirtyBags = A._gphDirtyBags or {}
                    A._gphDirtyBags[bagID] = true
                end
            else
                if A.DirtyBagsIfContentsChanged then
                    anyBagDirty = A.DirtyBagsIfContentsChanged({ 0, 1, 2, 3, 4 })
                elseif A.WipeBagLinkCache then
                    for b = 0, 4 do A.WipeBagLinkCache(b) end
                end
            end
            if anyBagDirty and A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            if A.lockedDisenchantSlots then
                local now = GetTime()
                for key, lockTime in pairs(A.lockedDisenchantSlots) do
                    if type(lockTime) == "number" and (now - lockTime > 4.5) then
                        A.lockedDisenchantSlots[key] = nil
                    else
                        local bag, slot = key:match("^(%-?%d+)_(%d+)$")
                        if bag and slot then
                            bag, slot = tonumber(bag), tonumber(slot)
                            if bagID == nil or bag == bagID then
                                local currentID = GetContainerItemID and GetContainerItemID(bag, slot)
                                if not currentID then
                                    A.lockedDisenchantSlots[key] = nil
                                end
                            end
                        end
                    end
                end
            end
            if A.activeDisenchantSlot and (bagID == nil or A.activeDisenchantSlot.bag == bagID) then
                local currentID = GetContainerItemID and GetContainerItemID(A.activeDisenchantSlot.bag, A.activeDisenchantSlot.slot)
                if not currentID or currentID ~= A.activeDisenchantSlot.itemId then
                    A.activeDisenchantSlot = nil
                end
            end
            -- Autodelete / continuous: only when bags actually changed (soft-dirty).
            if anyBagDirty then
                if A.NotifyContinuousDeleteBagsDirty then
                    A.NotifyContinuousDeleteBagsDirty()
                end
                if A.DestroyListHasEntries and A.DestroyListHasEntries() then
                    isDestroyerScanPending = true
                elseif not A.DestroyListHasEntries then
                    local list = A.GetGphDestroyList and A.GetGphDestroyList()
                    if list then
                        for _ in pairs(list) do isDestroyerScanPending = true; break end
                    end
                end
            end
            -- No isRefreshPending / isBankRefreshPending: Listview + Bankview own UI.

        elseif event == "GET_ITEM_INFO_RECEIVED" then
            -- arg is itemId, not bagId. Never _gphBagSpaceDirty here (mail/loot FULL thrash).
            if A.ClearItemInfoCache then A.ClearItemInfoCache(bagID) end
            if A.InvalidateInventoryDataCache then
                A.InvalidateInventoryDataCache()
            end
            A._gphDirtyBags = A._gphDirtyBags or {}
            for b = 0, 4 do A._gphDirtyBags[b] = true end
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            local inv = A.Inventory
            if inv and inv:IsShown() then
                isRefreshPending = true
            end

        elseif event == "TRANSMOG_COLLECTION_UPDATED" then
            if A._gphWardrobeCache then wipe(A._gphWardrobeCache) end
            if A.WipeBagLinkCache then
                A.WipeBagLinkCache(nil)
            else
                A.ClearBagLinkCache(nil)
                A._gphBagSpaceDirty = true
            end
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            local inv = A.Inventory
            if inv and inv:IsShown() then
                isRefreshPending = true
            end

        elseif event == "PLAYERBANKSLOTS_CHANGED" then
            -- Bankview owns UI; Core only keeps destroyable/DE consistency for bank main.
            if A.WipeBagLinkCache then
                A.WipeBagLinkCache(-1)
            else
                A.ClearBagLinkCache(-1)
                A._gphDirtyBags = A._gphDirtyBags or {}
                A._gphDirtyBags[-1] = true
            end
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            if A.lockedDisenchantSlots then
                local now = GetTime()
                for key, lockTime in pairs(A.lockedDisenchantSlots) do
                    if type(lockTime) == "number" and (now - lockTime > 4.5) then
                        A.lockedDisenchantSlots[key] = nil
                    else
                        local bag, slot = key:match("^(%-?%d+)_(%d+)$")
                        if bag and slot then
                            bag, slot = tonumber(bag), tonumber(slot)
                            local currentID = GetContainerItemID and GetContainerItemID(bag, slot)
                            if not currentID then
                                A.lockedDisenchantSlots[key] = nil
                            end
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
            -- Bankview schedules RefreshBankUI; no Core isBankRefreshPending dual path.

        elseif event == "PLAYERBANKBAGSLOTS_CHANGED" then
            if A.WipeBagLinkCache then
                A.WipeBagLinkCache(-1)
                for b = 5, 11 do A.WipeBagLinkCache(b) end
            else
                A.ClearBagLinkCache(nil)
            end
            A._gphBagSpaceDirty = true
            if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
            -- Capacity change: Bankview owns bank UI refresh.
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

