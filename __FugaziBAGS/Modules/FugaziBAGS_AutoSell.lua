local addonName, Addon = ...
local A = _G.FugaziBAGS
local DB = _G.FugaziBAGSDB or {}
_G.FugaziBAGSDB = DB

-- CONSTANTS (names from locale; IDs are locale-stable)
local GREEDY_PET_ID = 600135
local GOBLIN_MERCHANT_ID = 600126
local GPH_SUMMON_DELAY = 1.5

local function GoblinMerchantName()
    local L = A.L
    return (L and L.NPC_GOBLIN_MERCHANT) or "Goblin Merchant"
end

local function GreedyPetName()
    local L = A.L
    return (L and L.PET_GREEDY_SCAVENGER) or "Greedy scavenger"
end

-- COMPANION UTILITIES
local function GphCompanionNameIsGreedy(name)
    local L = A.L
    local tokens = (L and L.PET_GREEDY_NAME_TOKENS) or { "greedy", "scavenger" }
    if A.LocaleNameHasAllTokens then
        return A.LocaleNameHasAllTokens(name, tokens)
    end
    if not name or type(name) ~= "string" then return false end
    local l = name:lower()
    return l:find("greedy") and l:find("scavenger")
end

local function GphCompanionNameIsGoblin(name)
    local L = A.L
    local tokens = (L and L.PET_GOBLIN_NAME_TOKENS) or { "goblin", "merchant" }
    if A.LocaleNameHasAllTokens then
        return A.LocaleNameHasAllTokens(name, tokens)
    end
    if not name or type(name) ~= "string" then return false end
    local l = name:lower()
    return l:find("goblin") and l:find("merchant")
end

local function GphIsGreedySummoned()
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    for i = 1, num do
        local cid, cname, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
        if isSummoned and (cid == GREEDY_PET_ID or GphCompanionNameIsGreedy(cname)) then return true end
    end
    return false
end

local function GphIsGoblinMerchantSummoned()
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    for i = 1, num do
        local cid, cname, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
        if isSummoned and (cid == GOBLIN_MERCHANT_ID or GphCompanionNameIsGoblin(cname)) then return true end
    end
    return false
end

local function GphPlayerHasGreedyCompanion()
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    for i = 1, num do
        local cid, cname = GetCompanionInfo("CRITTER", i)
        if cid == GREEDY_PET_ID or (cname and GphCompanionNameIsGreedy(cname)) then return true end
    end
    return false
end

-- SUMMON LOGIC
local function QueueGphSummonGreedy()
    if not A.IsEbonhold() then return end
    local t = (DB.gphSummonDelayTimers or {})
    DB.gphSummonDelayTimers = t
    t[#t + 1] = { left = GPH_SUMMON_DELAY, func = function()
        local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
        for i = 1, num do
            local cid, cname, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
            if not isSummoned and (cid == GREEDY_PET_ID or GphCompanionNameIsGreedy(cname)) then
                CallCompanion("CRITTER", i)
                return
            end
        end
    end }
end

local function DoGphSummonGreedyNow()
    if not A.IsEbonhold() then return end
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    for i = 1, num do
        local cid, cname, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
        if not isSummoned and (cid == GREEDY_PET_ID or GphCompanionNameIsGreedy(cname)) then
            CallCompanion("CRITTER", i)
            return
        end
    end
end

local function DoGphSummonGoblinMerchantNow()
    if not A.IsEbonhold() then return end
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    for i = 1, num do
        local cid, cname, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
        if not isSummoned and (cid == GOBLIN_MERCHANT_ID or GphCompanionNameIsGoblin(cname)) then
            CallCompanion("CRITTER", i)
            return
        end
    end
end

local function GphDismissCurrentCompanion()
    local num = GetNumCompanions and GetNumCompanions("CRITTER") or 0
    for i = 1, num do
        local cid, cname, spellID, icon, isSummoned = GetCompanionInfo("CRITTER", i)
        if isSummoned and (cid == GREEDY_PET_ID or cid == GOBLIN_MERCHANT_ID or GphCompanionNameIsGreedy(cname) or GphCompanionNameIsGoblin(cname)) then
            CallCompanion("CRITTER", i)
            return true
        end
    end
    return false
end

local gphSummonDelayFrame = CreateFrame("Frame")
gphSummonDelayFrame:SetScript("OnUpdate", function(self, elapsed)
    local t = DB.gphSummonDelayTimers
    if not t or #t == 0 then return end
    for i = #t, 1, -1 do
        local item = t[i]
        item.left = item.left - elapsed
        if item.left <= 0 then
            table.remove(t, i)
            if type(item.func) == "function" then pcall(item.func) end
        end
    end
end)

-- AUTOSELL LOGIC
local GPH_AUTOSELL_DELAY_MIN_MS = 30
local GPH_AUTOSELL_DELAY_MAX_MS = 1500

local function GetGphAutosellDelaySeconds()
    local SV = _G.FugaziBAGSDB
    local ms = (SV and SV.gphAutosellPingMs ~= nil) and tonumber(SV.gphAutosellPingMs) or nil
    if not ms or ms <= 0 then ms = GPH_AUTOSELL_DELAY_MIN_MS end
    ms = math.max(GPH_AUTOSELL_DELAY_MIN_MS, math.min(GPH_AUTOSELL_DELAY_MAX_MS, ms))
    return ms / 1000
end

local gphVendorQueue = {}
local gphVendorQueueIndex = 1
local gphVendorRunning = false
local gphVendorSessionOverride = false
local gphVendorWorker = CreateFrame("Frame")
gphVendorWorker:Hide()

local function BuildGphVendorQueue()
    wipe(gphVendorQueue)
    gphVendorQueueIndex = 1
    local items = A.GetCachedBagItems and A.GetCachedBagItems()
    if not items then return end
    
    local maxQualityAllowed = (A.GetPerChar and A.GetPerChar("gphAutosellEverything", false) == true) and 3 or 0
    
    for i = 1, #items do
        local entry = items[i]
        if entry.sellPrice > 0 then
            if not (A.IsItemProtectedAPI and A.IsItemProtectedAPI(entry.itemId, entry.quality)) then
                local shouldSell = false
                
                local SV = _G.FugaziBAGSDB
                if SV and SV.enableFilteredAutoSell and A.GetItemValuationAndAction then
                    -- GetCachedBagItems uses iLevel (not itemLevel) and has no itemType —
                    -- resolve class + pass bag/slot so alwaysVendorSoulboundGear can fire.
                    local iLvl = entry.itemLevel or entry.iLevel
                    local itemClass = entry.itemType
                    if not itemClass and entry.link then
                        itemClass = select(6, GetItemInfo(entry.link))
                    end
                    local _, action = A.GetItemValuationAndAction(
                        entry.link, entry.itemId, entry.quality, iLvl, itemClass, entry.bag, entry.slot
                    )
                    if action == "VENDOR" then
                        shouldSell = true
                    end
                else
                    if entry.quality <= maxQualityAllowed then
                        shouldSell = true
                    end
                end
                
                if shouldSell then
                    -- STRICT SAFETY NET: NEVER autosell Epics/Legendaries or Soulbound Rares
                    if entry.quality >= 4 then
                        shouldSell = false
                    elseif entry.quality == 3 and A.IsBagItemSoulbound and A.IsBagItemSoulbound(entry.bag, entry.slot) then
                        shouldSell = false
                    end
                end
                
                if shouldSell then
                    local texture, itemCount, locked = GetContainerItemInfo(entry.bag, entry.slot)
                    if itemCount and itemCount > 0 and not locked then
                        gphVendorQueue[#gphVendorQueue + 1] = {
                            type = "sell",
                            bag = entry.bag,
                            slot = entry.slot,
                            itemID = entry.itemId
                        }
                    end
                end
            end
        end
    end
end

local function FinishGphVendorRun()
    gphVendorRunning = false
    A.isAutoSelling = nil
    local wasOverride = gphVendorSessionOverride
    gphVendorSessionOverride = false
    gphVendorWorker:Hide()
    local wantGreedy = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSummonGreedy ~= false
    if not wasOverride and wantGreedy then
        QueueGphSummonGreedy()
    end
    if _G.RefreshGPHUI then _G.RefreshGPHUI() end
end

gphVendorWorker:SetScript("OnUpdate", function(self, elapsed)
    self._t = (self._t or 0) + elapsed
    local delay = GetGphAutosellDelaySeconds()
    if self._t < delay then return end
    self._t = 0
    if not MerchantFrame or not MerchantFrame:IsShown() then
        gphVendorRunning = false
        A.isAutoSelling = nil
        self:Hide()
        return
    end
    if gphVendorSessionOverride then return end
    local action = gphVendorQueue[gphVendorQueueIndex]
    if not action then
        FinishGphVendorRun()
        return
    end
    if action.type == "sell" then
        local link = GetContainerItemLink and GetContainerItemLink(action.bag, action.slot)
        local _, _, quality
        if link then _, _, quality = A.GetCachedItemInfo(link) end
        if quality == nil then _, _, quality = A.GetCachedItemInfo(action.itemID) end
        local neverSell = false
        local SV = _G.FugaziBAGSDB
        if SV and SV.enableFilteredAutoSell then
            neverSell = (quality >= 4) or (quality == 3 and A.IsBagItemSoulbound and A.IsBagItemSoulbound(action.bag, action.slot))
        else
            local maxQualityAllowed = (A.GetPerChar and A.GetPerChar("gphAutosellEverything", false) == true) and 3 or 0
            neverSell = (quality > maxQualityAllowed)
        end
        local count = 1
        if GetContainerItemInfo then
            local _, itemCount = GetContainerItemInfo(action.bag, action.slot)
            if itemCount and itemCount > 0 then count = itemCount end
        end
        local vendorCopper = 0
        if GetItemInfo then
            local sellPrice = select(11, A.GetCachedItemInfo(link or action.itemID))
            if sellPrice and sellPrice > 0 then
                vendorCopper = sellPrice * count
            end
        end
        if not neverSell and not A.IsItemProtectedAPI(action.itemID, quality) then
            UseContainerItem(action.bag, action.slot)
            if _G.gphSession then
                _G.gphSession.vendoredItemCount = _G.gphSession.vendoredItemCount or {}
                _G.gphSession.vendoredItemCount[action.itemID] = (_G.gphSession.vendoredItemCount[action.itemID] or 0) + count
            end
            if _G.FugaziInstanceTracker_OnAutoVendor then
                _G.FugaziInstanceTracker_OnAutoVendor(action.itemID, count, vendorCopper)
            end
        end
    end
    gphVendorQueueIndex = gphVendorQueueIndex + 1
end)

local function StartGphVendorRun()
    if A.IsEbonhold() then
        if not UnitExists("target") or UnitName("target") ~= GoblinMerchantName() then return end
    end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if gphVendorRunning then return end
    local shift = _G.IsShiftKeyDown and _G.IsShiftKeyDown()
    gphVendorSessionOverride = shift
    if gphVendorSessionOverride then return end
    gphVendorRunning = true
    A.isAutoSelling = true
    BuildGphVendorQueue()
    if #gphVendorQueue == 0 then
        gphVendorRunning = false
        A.isAutoSelling = nil
        local wantGreedy = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSummonGreedy ~= false
        if UnitExists("target") and UnitName("target") == GoblinMerchantName() and MerchantFrame and MerchantFrame:IsShown() and wantGreedy then
            QueueGphSummonGreedy()
        end
        return
    end
    gphVendorWorker._t = 0
    gphVendorWorker:Show()
end

-- CHAT FILTER & MUTE
local gphGreedyMuteInstalled = false
local function GphGreedyChatFilter(self, event, msg, author, ...)
    if type(author) ~= "string" then return false end
    local Loc = A.L
    local greedyName = GreedyPetName():lower()
    local clean = author:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):lower()
    if clean == greedyName then return true end
    if type(msg) == "string" then
        local lower = msg:lower()
        local phrase = (Loc and Loc.CHAT_GREEDY_PHRASE) or "greedy scavenger"
        local markers = (Loc and Loc.CHAT_SPEECH_MARKERS) or { " says", " yells", " whispers" }
        if lower:find(phrase, 1, true) then
            if A.LocaleTextMatches and A.LocaleTextMatches(lower, markers, true) then
                return true
            end
            -- Fallback if helper missing
            for i = 1, #markers do
                if lower:find(markers[i], 1, true) then return true end
            end
        end
    end
    return false
end

local function GphIsVendorOut()
    return (MerchantFrame and MerchantFrame:IsShown()) and (UnitExists("target") and UnitName("target") == GoblinMerchantName())
end

local function InstallGphGreedyMuteOnce()
    if gphGreedyMuteInstalled then return end
    gphGreedyMuteInstalled = true
    local events = { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_PARTY", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_EMOTE", "CHAT_MSG_SYSTEM" }
    for _, ev in ipairs(events) do
        if ChatFrame_AddMessageEventFilter then ChatFrame_AddMessageEventFilter(ev, GphGreedyChatFilter) end
    end
end

-- EXPOSURE
A.GphIsGreedySummoned = GphIsGreedySummoned
A.GphIsGoblinMerchantSummoned = GphIsGoblinMerchantSummoned
A.GphPlayerHasGreedyCompanion = GphPlayerHasGreedyCompanion
A.QueueGphSummonGreedy = QueueGphSummonGreedy
A.DoGphSummonGreedyNow = DoGphSummonGreedyNow
A.DoGphSummonGoblinMerchantNow = DoGphSummonGoblinMerchantNow
A.GphDismissCurrentCompanion = GphDismissCurrentCompanion
A.StartGphVendorRun = StartGphVendorRun
A.FinishGphVendorRun = FinishGphVendorRun
A.GphIsVendorOut = GphIsVendorOut
A.InstallGphGreedyMuteOnce = InstallGphGreedyMuteOnce
A.GphGreedyChatFilter = GphGreedyChatFilter

StaticPopupDialogs["GPH_AUTOSELL_CONFIRM"] = {
    text = "Enable autoselling?\nUnprotected items will be sold automatically when you open the merchant.",
    button1 = "Yes, enable",
    button2 = "Cancel",
    OnAccept = function()
        local SV = _G.FugaziBAGSDB
        if SV then SV.gphAutoVendor = true end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- EVENT HANDLERS
function A.OnMerchantShow()
    if _G.gphSession then
        A.gphMerchantGoldAtOpen = GetMoney()
        A.gphMerchantRepairCostAtOpen = (GetRepairAllCost and GetRepairAllCost()) or 0
    end
    A.InstallGphGreedyMuteOnce()
    local defer = CreateFrame("Frame")
    defer:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        if _G.ElvUI_MerchantMerchantButton then
            _G.ElvUI_MerchantMerchantButton:Hide()
        end
        if _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphAutoVendor then
            -- Uncheck Ascension built-in auto sell if it is checked
            if _G.MerchantFrameSellJunkFrameAutoSellCheck and _G.MerchantFrameSellJunkFrameAutoSellCheck:GetChecked() then
                _G.MerchantFrameSellJunkFrameAutoSellCheck:SetChecked(false)
                local clickScript = _G.MerchantFrameSellJunkFrameAutoSellCheck:GetScript("OnClick")
                if clickScript then
                    clickScript(_G.MerchantFrameSellJunkFrameAutoSellCheck)
                end
            end
            if A.StartGphVendorRun then A.StartGphVendorRun() end
        end
    end)
    local gphFrame = A.Inventory
    if gphFrame and gphFrame.UpdateGphSummonBtn then gphFrame.UpdateGphSummonBtn() end

end

function A.OnMerchantClosed()
    if _G.gphSession and A.gphMerchantGoldAtOpen then
        local nowGold = GetMoney()
        local delta = nowGold - A.gphMerchantGoldAtOpen
        if delta > 0 then
            _G.gphSession.vendorGold = (_G.gphSession.vendorGold or 0) + delta
        end
        if GetRepairAllCost then
            local repairNow = GetRepairAllCost()
            local repairWas = A.gphMerchantRepairCostAtOpen or 0
            if repairWas > repairNow then
                local spent = repairWas - repairNow
                _G.gphSession.repairCopper = (_G.gphSession.repairCopper or 0) + spent
                _G.gphSession.repairCount = (_G.gphSession.repairCount or 0) + 1
            end
        end
    end
    A.gphMerchantGoldAtOpen = nil
    A.gphMerchantRepairCostAtOpen = nil
    _G.gphNpcDialogTime = nil
    if A.FinishGphVendorRun then A.FinishGphVendorRun() end
    local gphFrame = A.Inventory
    if gphFrame and gphFrame.UpdateGphSummonBtn then gphFrame.UpdateGphSummonBtn() end
    
    if RefreshGPHUI then
        local d = CreateFrame("Frame")
        d:SetScript("OnUpdate", function(self) self:SetScript("OnUpdate", nil); RefreshGPHUI() end)
    end
end

StaticPopupDialogs["GPH_AUTOSELL_EVERYTHING_WARN"] = {
    text = "WARNING: Enabling this will autosell ALL UNPROTECTED ITEMS regardless of quality, and it WILL vendor valuable items (like common, uncommon, or rare gear/materials)!\n\nAre you sure you want to enable this?",
    button1 = "Enable",
    button2 = "Cancel",
    OnAccept = function()
        if A.SetPerChar then A.SetPerChar("gphAutosellEverything", true) end
        if _G.FugaziBAGSAutosellEverythingCheck then
            _G.FugaziBAGSAutosellEverythingCheck:SetChecked(true)
        end
        if _G.FugaziBAGSDB then _G.FugaziBAGSDB.enableFilteredAutoSell = false end
        if _G.FugaziBAGSEnableFilteredAutoSell then
            _G.FugaziBAGSEnableFilteredAutoSell:SetChecked(false)
        end
    end,
    OnCancel = function()
        if A.SetPerChar then A.SetPerChar("gphAutosellEverything", false) end
        if _G.FugaziBAGSAutosellEverythingCheck then
            _G.FugaziBAGSAutosellEverythingCheck:SetChecked(false)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
