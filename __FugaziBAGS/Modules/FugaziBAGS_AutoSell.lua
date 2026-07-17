local addonName, Addon = ...
local A = _G.FugaziBAGS
local DB = _G.FugaziBAGSDB or {}
_G.FugaziBAGSDB = DB

-- CONSTANTS
local GOBLIN_MERCHANT_NAME = "Goblin Merchant"
local GREEDY_PET_NAME = "Greedy scavenger"
local GREEDY_PET_ID = 600135
local GOBLIN_MERCHANT_ID = 600126
local GPH_SUMMON_DELAY = 1.5

-- COMPANION UTILITIES
local function GphCompanionNameIsGreedy(name)
    if not name or type(name) ~= "string" then return false end
    local l = name:lower()
    return l:find("greedy") and l:find("scavenger")
end

local function GphCompanionNameIsGoblin(name)
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
    for bag = 0, 4 do
        local slots = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
            if itemID then
                local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                local _, _, quality
                if link then _, _, quality = A.GetCachedItemInfo(link) end
                if quality == nil then _, _, quality = A.GetCachedItemInfo(itemID) end
                if not A.IsItemProtectedAPI(itemID, quality) then
                    local texture, itemCount, locked = GetContainerItemInfo(bag, slot)
                    if itemCount and itemCount > 0 and not locked then
                        local sellPrice = select(11, A.GetCachedItemInfo(link or itemID))
                        local maxQualityAllowed = (A.GetPerChar and A.GetPerChar("gphAutosellEverything", false) == true) and 3 or 0
                        if sellPrice and sellPrice > 0 and quality <= maxQualityAllowed then
                            gphVendorQueue[#gphVendorQueue + 1] = { type = "sell", bag = bag, slot = slot, itemID = itemID }
                        end
                    end
                end
            end
        end
    end
end

local function FinishGphVendorRun()
    gphVendorRunning = false
    local wasOverride = gphVendorSessionOverride
    gphVendorSessionOverride = false
    gphVendorWorker:Hide()
    local wantGreedy = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSummonGreedy ~= false
    if not wasOverride and wantGreedy then
        QueueGphSummonGreedy()
    end
end

gphVendorWorker:SetScript("OnUpdate", function(self, elapsed)
    self._t = (self._t or 0) + elapsed
    local delay = GetGphAutosellDelaySeconds()
    if self._t < delay then return end
    self._t = 0
    if not MerchantFrame or not MerchantFrame:IsShown() then
        gphVendorRunning = false
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
        local maxQualityAllowed = (A.GetPerChar and A.GetPerChar("gphAutosellEverything", false) == true) and 3 or 0
        local neverSell = (quality > maxQualityAllowed)
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
        if not UnitExists("target") or UnitName("target") ~= GOBLIN_MERCHANT_NAME then return end
    end
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if gphVendorRunning then return end
    local shift = _G.IsShiftKeyDown and _G.IsShiftKeyDown()
    gphVendorSessionOverride = shift
    if gphVendorSessionOverride then return end
    gphVendorRunning = true
    BuildGphVendorQueue()
    if #gphVendorQueue == 0 then
        gphVendorRunning = false
        local wantGreedy = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSummonGreedy ~= false
        if UnitExists("target") and UnitName("target") == GOBLIN_MERCHANT_NAME and MerchantFrame and MerchantFrame:IsShown() and wantGreedy then
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
    local clean = author:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):lower()
    if clean == GREEDY_PET_NAME:lower() then return true end
    if type(msg) == "string" and msg:lower():find("greedy scavenger", 1, true) then
        if msg:lower():find(" says", 1, true) or msg:lower():find(" yells", 1, true) or msg:lower():find(" whispers", 1, true) then
            return true
        end
    end
    return false
end

local function GphIsVendorOut()
    return (MerchantFrame and MerchantFrame:IsShown()) and (UnitExists("target") and UnitName("target") == GOBLIN_MERCHANT_NAME)
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
    
    if RefreshGPHUI then
        local d = CreateFrame("Frame")
        d:SetScript("OnUpdate", function(self) self:SetScript("OnUpdate", nil); RefreshGPHUI() end)
    end
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
