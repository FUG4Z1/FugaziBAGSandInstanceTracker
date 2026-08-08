local addonName, L = ...

----------------------------------------------------------------------
-- Ledger filter bar (6 orthogonal slots)
-- Sort | Time | Scope | Value lens | Live+history | Reset
-- Run-level only (not item rarity). Baseline = pre-filter Ledger behavior.
----------------------------------------------------------------------

L.FilterBar = L.FilterBar or {}
local FB = L.FilterBar

FB.DEFAULTS = {
    sort  = "newest", -- newest | oldest | longest | shortest | gold | gph
    time  = "all",    -- today | 7d | 30d | all
    scope = "realm",  -- realm | char  (type = Sessions/Dungeons tabs)
    lens  = "est",    -- default Total (raw + vendor + AH + destroy)
    view  = "both",   -- live | history | both
}

-- Cycle order matters (shown left-to-right in tooltips as next steps)
FB.SORT_OPTS  = { "newest", "oldest", "longest", "shortest", "gold", "gph" }
FB.TIME_OPTS  = { "today", "7d", "30d", "all" }
FB.SCOPE_OPTS = { "realm", "char" }
-- Click cycle: GPH → Total → Raw → Vendor → Auction → Destroy
FB.LENS_OPTS  = { "gph", "est", "raw", "vendor", "ah", "destroy" }
FB.VIEW_OPTS  = { "live", "history", "both" }

-- Short labels that fit ~50px glass slots
FB.SORT_LABEL  = {
    newest = "New", oldest = "Old", longest = "Long", shortest = "Short",
    gold = "Gold", gph = "GPH",
}
FB.TIME_LABEL  = { today = "1d", ["7d"] = "7d", ["30d"] = "30d", all = "All" }
FB.SCOPE_LABEL = { realm = "Realm", char = "Char" }
FB.LENS_LABEL  = {
    raw = "Raw", est = "Total", vendor = "Vend", ah = "AH", destroy = "Dest", gph = "GPH",
}
FB.VIEW_LABEL  = { live = "Live", history = "Hist", both = "Both" }

FB.SORT_TIP  = {
    newest   = "Newest first",
    oldest   = "Oldest first",
    longest  = "Longest duration first",
    shortest = "Shortest duration first",
    gold     = "Best value first (uses Value lens)",
    gph      = "Best value/hour first (uses Value lens)",
}
FB.TIME_TIP  = {
    today = "Today only",
    ["7d"] = "Last 7 days",
    ["30d"] = "Last 30 days",
    all = "All time",
}
FB.SCOPE_TIP = {
    realm = "This realm (all characters)",
    char  = "This character only",
}
FB.LENS_TIP  = {
    raw     = "Raw gold earned",
    est     = "Total = raw + vendor + AH + destroy (stamped at run end)",
    vendor  = "Vendor value of kept loot",
    ah      = "Auction value of kept loot",
    destroy = "Destroy value stamped on the run (DE/prospect/mill per BAGS rules at save time)",
    gph     = "Value per hour (from Total)",
}
FB.VIEW_TIP  = {
    live    = "Current run only",
    history = "History list only",
    both    = "Current run + history (default)",
}

-- Legacy saved values -> current keys
local SORT_LEGACY  = { items = "newest", long = "longest", short = "shortest" }
local SCOPE_LEGACY = { account = "realm", dungeons = "realm", sessions = "realm", dung = "realm", sess = "realm" }
local VIEW_LEGACY  = { stats = "both", stat = "both", meta = "both" }
local LENS_LEGACY  = { total = "est", tot = "est" }

local SLOT_KEYS = { "sort", "time", "scope", "lens", "view", "reset" }

local function IsGPHRun(run)
    return run and run.name and run.name:find("^GPH")
end

local function PlayerName()
    return (UnitName and UnitName("player")) or ""
end

local function RealmName()
    return (GetRealmName and GetRealmName()) or ""
end

local function IndexOf(list, value)
    for i = 1, #list do
        if list[i] == value then return i end
    end
    return 1
end

local function CycleValue(list, current, reverse)
    local i = IndexOf(list, current)
    if reverse then
        i = i - 1
        if i < 1 then i = #list end
    else
        i = i + 1
        if i > #list then i = 1 end
    end
    return list[i]
end

----------------------------------------------------------------------
-- Persistence (per character)
----------------------------------------------------------------------

local function IsKnownOpt(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

local function SanitizeState(st)
    if not st then return end
    if SORT_LEGACY[st.sort] then st.sort = SORT_LEGACY[st.sort] end
    if SCOPE_LEGACY[st.scope] then st.scope = SCOPE_LEGACY[st.scope] end
    if VIEW_LEGACY[st.view] then st.view = VIEW_LEGACY[st.view] end
    if LENS_LEGACY[st.lens] then st.lens = LENS_LEGACY[st.lens] end
    if not IsKnownOpt(FB.SORT_OPTS, st.sort) then st.sort = FB.DEFAULTS.sort end
    if not IsKnownOpt(FB.TIME_OPTS, st.time) then st.time = FB.DEFAULTS.time end
    if not IsKnownOpt(FB.SCOPE_OPTS, st.scope) then st.scope = FB.DEFAULTS.scope end
    if not IsKnownOpt(FB.LENS_OPTS, st.lens) then st.lens = FB.DEFAULTS.lens end
    if not IsKnownOpt(FB.VIEW_OPTS, st.view) then st.view = FB.DEFAULTS.view end
end

function FB.EnsureDB()
    if not _G.InstanceTrackerDB then _G.InstanceTrackerDB = {} end
    local db = _G.InstanceTrackerDB
    db.ledgerFiltersPerChar = db.ledgerFiltersPerChar or {}
    local key = (L.GetGphCharKey and L.GetGphCharKey()) or (RealmName() .. "#" .. PlayerName())
    local st = db.ledgerFiltersPerChar[key]
    if type(st) ~= "table" then
        st = {}
        db.ledgerFiltersPerChar[key] = st
    end
    for k, v in pairs(FB.DEFAULTS) do
        if st[k] == nil then st[k] = v end
    end
    -- Migrate legacy shared table once
    if type(db.ledgerFilters) == "table" then
        for k, v in pairs(FB.DEFAULTS) do
            if db.ledgerFilters[k] ~= nil and st[k] == FB.DEFAULTS[k] then
                st[k] = db.ledgerFilters[k]
            end
        end
        db.ledgerFilters = nil
    end
    SanitizeState(st)
    return st
end

function FB.Get()
    return FB.EnsureDB()
end

function FB.GetField(key)
    local st = FB.EnsureDB()
    return st[key] or FB.DEFAULTS[key]
end

function FB.SetField(key, value)
    local st = FB.EnsureDB()
    if FB.DEFAULTS[key] == nil then return end
    st[key] = value
end

function FB.Reset()
    local st = FB.EnsureDB()
    for k, v in pairs(FB.DEFAULTS) do
        st[k] = v
    end
end

function FB.IsDirty()
    local st = FB.EnsureDB()
    for k, v in pairs(FB.DEFAULTS) do
        if st[k] ~= v then return true end
    end
    return false
end

function FB.IsFieldDirty(key)
    return FB.GetField(key) ~= FB.DEFAULTS[key]
end

----------------------------------------------------------------------
-- Run metrics (value lens + helpers)
----------------------------------------------------------------------

function FB.GetItemCount(run)
    if not run then return 0 end
    local n = 0
    if run.qualityCounts then
        for _, c in pairs(run.qualityCounts) do
            n = n + (c or 0)
        end
        if n > 0 then return n end
    end
    local items = run.items
    if not items then return 0 end
    if #items > 0 then
        for i = 1, #items do
            n = n + (items[i].count or 1)
        end
    else
        for _, it in pairs(items) do
            n = n + (it.count or 1)
        end
    end
    return n
end

--- Copper value for display / Best-value sort under the current (or given) lens.
function FB.GetRunValue(run, lens)
    if not run then return 0 end
    lens = lens or FB.GetField("lens")
    if lens == "raw" then
        return run.goldCopper or 0
    elseif lens == "vendor" then
        return run.vendorValue or 0
    elseif lens == "ah" then
        return run.ahValue or 0
    elseif lens == "destroy" then
        return run.destroyValue or 0
    elseif lens == "est" then
        if run.estimatedValueCopper then return run.estimatedValueCopper end
        return (run.goldCopper or 0) + (run.vendorValue or 0) + (run.ahValue or 0) + (run.destroyValue or 0)
    elseif lens == "gph" then
        if run.estimatedGPHCopper then return run.estimatedGPHCopper end
        local est = FB.GetRunValue(run, "est")
        local dur = run.duration or 0
        if dur > 0 then return est / (dur / 3600) end
        return 0
    end
    return run.goldCopper or 0
end

function FB.FormatRunValue(run, lens)
    lens = lens or FB.GetField("lens")
    local v = FB.GetRunValue(run, lens)
    local s = (L.FormatGold and L.FormatGold(v)) or tostring(math.floor(v + 0.5))
    if lens == "gph" then
        s = s .. " |cffffd700/h|r"
    end
    return s
end

function FB.LensLabel(lens)
    lens = lens or FB.GetField("lens")
    return FB.LENS_TIP[lens] or "Value"
end

--- Short label for UI titles (Vend / AH / Dest).
function FB.LensShort(lens)
    lens = lens or FB.GetField("lens")
    return FB.LENS_LABEL[lens] or lens or "Value"
end

-- Value lens → which BAGS valuation actions belong in Item Details.
-- raw / est / gph show all items; vendor / ah / destroy filter the list.
local LENS_ACTIONS = {
    vendor  = { VENDOR = true },
    ah      = { AH = true },
    destroy = { DE = true, DESTROY = true, PROSPECT = true, MILL = true },
}

--- BAGS action string for one loot row (VENDOR / AH / DE / …).
function FB.GetItemAction(item)
    if not item then return "VENDOR" end
    local Addon = _G.FugaziBAGS
    if not Addon or not Addon.GetItemValuationAndAction then return "VENDOR" end
    local link = item.link
    local id = item.itemId
    if not id and link then id = tonumber(link:match("item:(%d+)")) end
    local _, _, _, _, _, itemClass = GetItemInfo(link or id)
    local _, action = Addon.GetItemValuationAndAction(link, id, item.quality, item.iLvl or item.itemLevel or 0, itemClass)
    return action or "VENDOR"
end

--- true if this item should appear under the current (or given) value lens.
function FB.ItemMatchesLens(item, lens)
    lens = lens or FB.GetField("lens")
    local want = LENS_ACTIONS[lens]
    if not want then return true end -- raw / est / gph = all items
    return want[FB.GetItemAction(item)] and true or false
end

--- Filter an item array by value lens; rebuild quality counts. Returns items, qc.
function FB.FilterItemsByLens(items, lens)
    lens = lens or FB.GetField("lens")
    if not items or not LENS_ACTIONS[lens] then
        local qc = {}
        for _, it in ipairs(items or {}) do
            local q = it.quality or 0
            qc[q] = (qc[q] or 0) + (it.count or 0)
        end
        return items or {}, qc
    end
    local out, qc = {}, {}
    for _, it in ipairs(items) do
        if FB.ItemMatchesLens(it, lens) then
            out[#out + 1] = it
            local q = it.quality or 0
            qc[q] = (qc[q] or 0) + (it.count or 0)
        end
    end
    return out, qc
end

--- true when lens should green-highlight this run-detail key (raw/vendor/ah/destroy/est/gph).
function FB.LensHighlights(key, lens)
    lens = lens or FB.GetField("lens")
    if not key then return false end
    -- Exact match only (GPH must not also light Total).
    return lens == key
end

----------------------------------------------------------------------
-- Predicates
----------------------------------------------------------------------

function FB.PassesTime(run, timeMode)
    timeMode = timeMode or FB.GetField("time")
    if timeMode == "all" or not timeMode then return true end
    local enter = run and run.enterTime or 0
    if enter <= 0 then return true end
    local now = time()
    if timeMode == "7d" then
        return enter >= (now - 7 * 86400)
    elseif timeMode == "30d" then
        return enter >= (now - 30 * 86400)
    elseif timeMode == "today" then
        local tEnter = date("*t", enter)
        local tNow = date("*t", now)
        return tEnter.year == tNow.year and tEnter.yday == tNow.yday
    end
    return true
end

--- Identity + optional type force from scope.
--- Returns passesIdentity, forceType ("gph"|"dungeon"|nil)
function FB.ScopeInfo(scope)
    scope = scope or FB.GetField("scope")
    if scope == "dungeons" then
        return true, "dungeon"
    elseif scope == "sessions" then
        return true, "gph"
    end
    return true, nil
end

function FB.PassesScope(run, scope)
    scope = scope or FB.GetField("scope")
    if not run then return false end
    local realm = RealmName()
    local player = PlayerName()

    -- Identity only. Run type (dungeon vs GPH session) is the Sessions/Dungeons tab.
    if scope == "char" then
        if run.realmName and run.realmName ~= "" and run.realmName ~= realm then return false end
        if run.characterName and run.characterName ~= "" and run.characterName ~= player then return false end
        return true
    end
    -- realm (default): all chars on this realm
    if run.realmName and run.realmName ~= "" and run.realmName ~= realm then return false end
    return true
end

function FB.PassesTab(run, tabIndex, scope)
    local isGPH = IsGPHRun(run)
    if tabIndex == 1 then return true end
    if tabIndex == 2 then return isGPH end
    if tabIndex == 3 then return not isGPH end
    return true
end

----------------------------------------------------------------------
-- Sort
----------------------------------------------------------------------

function FB.SortResults(results, sortMode, lens)
    sortMode = sortMode or FB.GetField("sort")
    lens = lens or FB.GetField("lens")
    if not results or #results < 2 then return results end

    if sortMode == "newest" then
        table.sort(results, function(a, b)
            local ta = (a.run and a.run.enterTime) or 0
            local tb = (b.run and b.run.enterTime) or 0
            if ta ~= tb then return ta > tb end
            return (a.index or 0) < (b.index or 0)
        end)
    elseif sortMode == "oldest" then
        table.sort(results, function(a, b)
            local ta = (a.run and a.run.enterTime) or 0
            local tb = (b.run and b.run.enterTime) or 0
            if ta ~= tb then return ta < tb end
            return (a.index or 0) > (b.index or 0)
        end)
    elseif sortMode == "gold" then
        table.sort(results, function(a, b)
            local va = FB.GetRunValue(a.run, lens)
            local vb = FB.GetRunValue(b.run, lens)
            if va ~= vb then return va > vb end
            return (a.index or 0) < (b.index or 0)
        end)
    elseif sortMode == "gph" then
        table.sort(results, function(a, b)
            local function gph(run)
                local dur = run and run.duration or 0
                if dur <= 0 then return 0 end
                -- When lens is already gph, value is already /h
                if lens == "gph" then return FB.GetRunValue(run, "gph") end
                return FB.GetRunValue(run, lens) / (dur / 3600)
            end
            local va, vb = gph(a.run), gph(b.run)
            if va ~= vb then return va > vb end
            return (a.index or 0) < (b.index or 0)
        end)
    elseif sortMode == "longest" then
        table.sort(results, function(a, b)
            local va = (a.run and a.run.duration) or 0
            local vb = (b.run and b.run.duration) or 0
            if va ~= vb then return va > vb end
            return (a.index or 0) < (b.index or 0)
        end)
    elseif sortMode == "shortest" then
        table.sort(results, function(a, b)
            local va = (a.run and a.run.duration) or 0
            local vb = (b.run and b.run.duration) or 0
            -- Prefer real durations; unknown/zero durations sink to the bottom
            local aOk = va > 0
            local bOk = vb > 0
            if aOk ~= bOk then return aOk end
            if va ~= vb then return va < vb end
            return (a.index or 0) < (b.index or 0)
        end)
    end
    return results
end

----------------------------------------------------------------------
-- Filtered run list (shared by Ledger UI)
----------------------------------------------------------------------

--- Returns { { index = historyIndex, run = run }, ... }
function FB.GetFilteredRuns(tabIndex, searchText)
    local history = _G.InstanceTrackerDB and _G.InstanceTrackerDB.runHistory or {}
    local st = FB.EnsureDB()
    local results = {}
    local searchLower = searchText and searchText:lower() or ""

    for i, run in ipairs(history) do
        if FB.PassesScope(run, st.scope)
            and FB.PassesTime(run, st.time)
            and FB.PassesTab(run, tabIndex, st.scope)
        then
            local passesSearch = true
            if searchLower ~= "" then
                local runNameLower = (run.name or ""):lower()
                local customLower = (run.customName or ""):lower()
                local runMatches = runNameLower:find(searchLower, 1, true)
                    or (customLower ~= "" and customLower:find(searchLower, 1, true))
                if not runMatches then
                    local itemMatches = false
                    for _, item in ipairs(run.items or {}) do
                        local itemNameLower = (item.name or ""):lower()
                        if itemNameLower:find(searchLower, 1, true) then
                            itemMatches = true
                            break
                        end
                    end
                    if not itemMatches then passesSearch = false end
                end
            end
            if passesSearch then
                results[#results + 1] = { index = i, run = run }
            end
        end
    end

    FB.SortResults(results, st.sort, st.lens)
    return results
end

--- True when membership filters reduced the set (time / scope). Sort+lens only re-rank/display.
function FB.IsHistoryFiltered()
    local st = FB.EnsureDB()
    return st.time ~= FB.DEFAULTS.time or st.scope ~= FB.DEFAULTS.scope
end

----------------------------------------------------------------------
-- View mode helpers (Sessions / Dungeons content)
----------------------------------------------------------------------

function FB.ShowLiveSection(tabIndex)
    local view = FB.GetField("view")
    if tabIndex == 1 then return false end
    if view == "history" then return false end
    return true -- live | both
end

function FB.ShowHistorySection(tabIndex)
    local view = FB.GetField("view")
    if tabIndex == 1 then return false end
    if view == "live" then return false end
    return true -- history | both
end

function FB.ShowStatsSection(tabIndex)
    local view = FB.GetField("view")
    if tabIndex ~= 3 then return false end -- rarity / best zones live on Dungeons
    if view == "live" or view == "history" then return false end
    return true -- both (and any future combined modes)
end

--- Lifetime: sort/view not meaningful; time/scope/lens can still be dirty
function FB.SlotEnabled(slotKey, tabIndex)
    tabIndex = tabIndex or 1
    if slotKey == "reset" then return true end
    if tabIndex == 1 then
        if slotKey == "sort" or slotKey == "view" then return false end
        return true
    end
    return true
end

----------------------------------------------------------------------
-- Glow / button paint
----------------------------------------------------------------------

local GOLD_IDLE = { 0.88, 0.68, 0.25, 0.38 }
local GOLD_ACTIVE = { 1.0, 0.85, 0.35, 0.72 }
local GOLD_RESET_DIRTY = { 0.45, 0.95, 0.45, 0.75 }
local GOLD_DISABLED = { 0.35, 0.35, 0.35, 0.35 }
local BORDER_IDLE = { 0.3, 0.3, 0.3, 0.5 }
local BORDER_ACTIVE = { 1.0, 0.9, 0.4, 0.95 }
local BORDER_RESET = { 0.4, 1.0, 0.45, 0.95 }

local function SetBorderColor(btn, r, g, b, a)
    if not btn or not btn.border then return end
    for _, t in pairs(btn.border) do
        t:SetVertexColor(r, g, b, a)
    end
end

function FB.PaintButton(btn, mode)
    -- mode: "idle" | "active" | "reset_dirty" | "disabled"
    if not btn or not btn.bg then return end
    if mode == "active" then
        btn.bg:SetVertexColor(GOLD_ACTIVE[1], GOLD_ACTIVE[2], GOLD_ACTIVE[3], GOLD_ACTIVE[4])
        SetBorderColor(btn, BORDER_ACTIVE[1], BORDER_ACTIVE[2], BORDER_ACTIVE[3], BORDER_ACTIVE[4])
        if btn.fs then btn.fs:SetTextColor(1, 0.95, 0.7, 1); btn.fs:SetAlpha(1) end
    elseif mode == "reset_dirty" then
        btn.bg:SetVertexColor(GOLD_RESET_DIRTY[1], GOLD_RESET_DIRTY[2], GOLD_RESET_DIRTY[3], GOLD_RESET_DIRTY[4])
        SetBorderColor(btn, BORDER_RESET[1], BORDER_RESET[2], BORDER_RESET[3], BORDER_RESET[4])
        if btn.fs then btn.fs:SetTextColor(0.7, 1, 0.7, 1); btn.fs:SetAlpha(1) end
    elseif mode == "disabled" then
        btn.bg:SetVertexColor(GOLD_DISABLED[1], GOLD_DISABLED[2], GOLD_DISABLED[3], GOLD_DISABLED[4])
        SetBorderColor(btn, BORDER_IDLE[1], BORDER_IDLE[2], BORDER_IDLE[3], 0.35)
        if btn.fs then btn.fs:SetTextColor(0.55, 0.55, 0.55, 1); btn.fs:SetAlpha(0.7) end
    else
        btn.bg:SetVertexColor(GOLD_IDLE[1], GOLD_IDLE[2], GOLD_IDLE[3], GOLD_IDLE[4])
        SetBorderColor(btn, BORDER_IDLE[1], BORDER_IDLE[2], BORDER_IDLE[3], BORDER_IDLE[4])
        if btn.fs then btn.fs:SetTextColor(0.95, 0.9, 0.75, 1); btn.fs:SetAlpha(0.9) end
    end
end

function FB.GetSlotLabel(slotKey)
    -- Reset: blank at baseline; "Reset" only when something is dirty (green).
    if slotKey == "reset" then
        return FB.IsDirty() and "Reset" or ""
    end
    local v = FB.GetField(slotKey)
    if slotKey == "sort" then return FB.SORT_LABEL[v] or "?" end
    if slotKey == "time" then return FB.TIME_LABEL[v] or "?" end
    if slotKey == "scope" then return FB.SCOPE_LABEL[v] or "?" end
    if slotKey == "lens" then return FB.LENS_LABEL[v] or "?" end
    if slotKey == "view" then return FB.VIEW_LABEL[v] or "?" end
    return "?"
end

function FB.GetSlotTitle(slotKey)
    if slotKey == "sort" then return "Sort" end
    if slotKey == "time" then return "Time" end
    if slotKey == "scope" then return "Scope" end
    if slotKey == "lens" then return "Value lens" end
    if slotKey == "view" then return "View" end
    if slotKey == "reset" then return "Reset filters" end
    return slotKey
end

function FB.GetSlotTipBody(slotKey)
    if slotKey == "reset" then
        if FB.IsDirty() then
            return "Click to restore baseline\n(New / All / Realm / Raw / Both)"
        end
        return "Filters are at baseline"
    end
    local v = FB.GetField(slotKey)
    local tipMap = {
        sort = FB.SORT_TIP, time = FB.TIME_TIP, scope = FB.SCOPE_TIP,
        lens = FB.LENS_TIP, view = FB.VIEW_TIP,
    }
    local map = tipMap[slotKey]
    local cur = map and map[v] or tostring(v)
    local extra = ""
    if slotKey == "scope" then
        extra = "\nRun type is the Sessions / Dungeons tab."
    elseif slotKey == "lens" then
        extra = "\nLifetime: revalues totals only."
            .. "\nSessions/Dungeons: sorts best-first and opens that run."
    end
    return "Current: " .. cur .. extra .. "\nLeft-click: next  |  Right-click: previous"
end

----------------------------------------------------------------------
-- Tooltips: prefer LEFT of Ledger (Details/Items usually on the right),
-- flip to RIGHT near the screen edge. Refreshable while hovered.
----------------------------------------------------------------------

local TOOLTIP_GAP = 5
local TOOLTIP_WIDTH_BUDGET = 280

function FB.AnchorTooltip(ownerFrame, host)
    host = host or _G.InstanceTrackerStatsFrame or L.statsFrame
    if not ownerFrame then return end
    if not host or not host.GetLeft then
        GameTooltip:SetOwner(ownerFrame, "ANCHOR_LEFT")
        return
    end

    local screenWidth = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or (GetScreenWidth and GetScreenWidth()) or 1024
    local hLeft = host:GetLeft() or 0
    local hRight = host:GetRight() or 0
    -- Prefer left of Ledger so docked Details/Items on the right stay clear.
    local side = "LEFT"
    if hLeft < TOOLTIP_WIDTH_BUDGET then
        side = "RIGHT"
    end
    -- If right is also tight (Ledger near right edge), force left when possible.
    if side == "RIGHT" and (screenWidth - hRight) < TOOLTIP_WIDTH_BUDGET and hLeft >= TOOLTIP_WIDTH_BUDGET then
        side = "LEFT"
    end

    GameTooltip:SetOwner(ownerFrame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    if side == "LEFT" then
        GameTooltip:SetPoint("TOPRIGHT", host, "TOPLEFT", -TOOLTIP_GAP, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", host, "TOPRIGHT", TOOLTIP_GAP, 0)
    end
end

function FB.ShowSlotTooltip(btn, statsFrame)
    if not btn or not btn.slotKey then return end
    local host = statsFrame or btn:GetParent() and btn:GetParent():GetParent() or _G.InstanceTrackerStatsFrame
    FB.AnchorTooltip(btn, host)
    GameTooltip:ClearLines()
    GameTooltip:AddLine(FB.GetSlotTitle(btn.slotKey), 1, 0.85, 0.4)
    GameTooltip:AddLine(FB.GetSlotTipBody(btn.slotKey), 0.85, 0.85, 0.85, true)
    local tab = (statsFrame and statsFrame.selectedTab) or 1
    if not FB.SlotEnabled(btn.slotKey, tab) then
        GameTooltip:AddLine("Not used on Lifetime tab", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

function FB.UpdateGlows(statsFrame)
    local f = statsFrame or L.statsFrame or _G.InstanceTrackerStatsFrame
    if not f or not f.ledgerBarButtons then return end
    local tab = f.selectedTab or 1
    for i = 0, 5 do
        local btn = f.ledgerBarButtons[i]
        if btn and btn.slotKey then
            local key = btn.slotKey
            local enabled = FB.SlotEnabled(key, tab)
            local label = FB.GetSlotLabel(key)
            if btn.fs then btn.fs:SetText(label) end
            if not enabled then
                FB.PaintButton(btn, "disabled")
            elseif key == "reset" then
                FB.PaintButton(btn, FB.IsDirty() and "reset_dirty" or "idle")
            elseif FB.IsFieldDirty(key) then
                FB.PaintButton(btn, "active")
            else
                FB.PaintButton(btn, "idle")
            end
        end
    end
end

----------------------------------------------------------------------
-- Input
----------------------------------------------------------------------

function FB.CycleSlot(slotKey, reverse)
    if slotKey == "reset" then
        if FB.IsDirty() then
            FB.Reset()
            if L.PlayUISwooshSound then L.PlayUISwooshSound()
            elseif L.PlayUIClickSound then L.PlayUIClickSound() end
            return true
        end
        return false
    end
    local opts =
        (slotKey == "sort" and FB.SORT_OPTS) or
        (slotKey == "time" and FB.TIME_OPTS) or
        (slotKey == "scope" and FB.SCOPE_OPTS) or
        (slotKey == "lens" and FB.LENS_OPTS) or
        (slotKey == "view" and FB.VIEW_OPTS)
    if not opts then return false end
    local cur = FB.GetField(slotKey)
    FB.SetField(slotKey, CycleValue(opts, cur, reverse))
    if L.PlayUIClickSound then L.PlayUIClickSound() end
    return true
end

function FB.OnSlotClick(btn, mouseButton)
    local slotKey = btn and btn.slotKey
    if not slotKey then return end
    local f = L.statsFrame or _G.InstanceTrackerStatsFrame
    local tab = (f and f.selectedTab) or 1
    if not FB.SlotEnabled(slotKey, tab) then
        if L.PlayUIHoverSound then L.PlayUIHoverSound() end
        -- Still refresh tip so "not used" stays accurate
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == btn then
            FB.ShowSlotTooltip(btn, f)
        end
        return
    end
    local reverse = (mouseButton == "RightButton")
    if FB.CycleSlot(slotKey, reverse) then
        -- Value lens on Sessions/Dungeons: rank history by best value under this lens
        -- (sort "gold" already uses GetRunValue for the active lens, incl. GPH).
        if slotKey == "lens" and tab ~= 1 then
            if FB.GetField("sort") ~= "gold" then
                FB.SetField("sort", "gold")
            end
        end

        FB.UpdateGlows(f)
        if type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI(true) end

        if slotKey == "lens" then
            if tab == 1 then
                -- Lifetime: lens only revalues the aggregate preview. No run to "win".
                if L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown()
                    and type(L.RefreshLedgerDetailUI) == "function" then
                    L.RefreshLedgerDetailUI(true)
                end
            elseif type(_G.ShowLedgerDetail) == "function" then
                -- Open / retarget details to the top ranked run for this lens.
                local search = ""
                if f and f.ledgerSearchEditBox then
                    search = (f.ledgerSearchEditBox:GetText() or ""):match("^%s*(.-)%s*$") or ""
                end
                local filtered = FB.GetFilteredRuns(tab, search)
                local top = filtered and filtered[1]
                if top and top.index then
                    _G.ShowLedgerDetail(top.index)
                end
            end
        elseif L.ledgerDetailFrame and L.ledgerDetailFrame:IsShown() and type(L.RefreshLedgerDetailUI) == "function" then
            L.RefreshLedgerDetailUI(true)
        end

        -- Refresh Items only if already open (lens filter); don't force-open it
        local itemFrame = _G.InstanceTrackerItemDetailFrame
        if itemFrame and itemFrame:IsShown() and itemFrame.RefreshItemDetailList then
            itemFrame:RefreshItemDetailList()
        end

        -- Keep tooltip open and up to date without re-entering the button
        if (btn.IsMouseOver and btn:IsMouseOver()) or (MouseIsOver and MouseIsOver(btn)) then
            FB.ShowSlotTooltip(btn, f)
        end
    end
end

----------------------------------------------------------------------
-- Build / attach UI onto existing ledgerBar frame
----------------------------------------------------------------------

local function MakeGlassButton(parent, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    bg:SetVertexColor(GOLD_IDLE[1], GOLD_IDLE[2], GOLD_IDLE[3], GOLD_IDLE[4])
    btn.bg = bg

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    hl:SetVertexColor(1, 1, 1, 0.30)
    btn.hl = hl

    local glass = btn:CreateTexture(nil, "ARTWORK")
    glass:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    glass:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    glass:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 0)
    glass:SetVertexColor(1, 1, 1, 0)
    btn.glass = glass

    local border = {
        top    = btn:CreateTexture(nil, "OVERLAY"),
        bottom = btn:CreateTexture(nil, "OVERLAY"),
        left   = btn:CreateTexture(nil, "OVERLAY"),
        right  = btn:CreateTexture(nil, "OVERLAY"),
    }
    for _, t in pairs(border) do
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetVertexColor(BORDER_IDLE[1], BORDER_IDLE[2], BORDER_IDLE[3], BORDER_IDLE[4])
    end
    border.top:SetHeight(1)
    border.top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    border.bottom:SetHeight(1)
    border.bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    border.left:SetWidth(1)
    border.left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    border.right:SetWidth(1)
    border.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.border = border

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetTextColor(0.95, 0.9, 0.75, 1)
    fs:SetAlpha(0.9)
    btn.fs = fs

    return btn
end

--- Attach 6 filter slots to stats frame's ledgerBar. Replaces rarity placeholders.
function FB.Attach(statsFrame, ledgerBar)
    if not statsFrame or not ledgerBar then return end
    FB.EnsureDB()

    -- Clear any pre-built children from older CreateStatsFrame loops
    if statsFrame.ledgerBarButtons then
        for _, b in pairs(statsFrame.ledgerBarButtons) do
            if b and b.Hide then b:Hide(); b:SetParent(nil) end
        end
    end

    local totalWidth = ledgerBar:GetWidth()
    if not totalWidth or totalWidth < 50 then totalWidth = 328 end
    local spacing = 4
    local numBtns = 6
    local slotWidth = math.floor((totalWidth - spacing * (numBtns - 1)) / numBtns)
    if slotWidth < 16 then slotWidth = 16 end

    local qBtns = {}
    for i = 0, 5 do
        local slotKey = SLOT_KEYS[i + 1]
        local btn = MakeGlassButton(ledgerBar, slotWidth, 18)
        local x = (slotWidth + spacing) * i
        btn:SetPoint("LEFT", ledgerBar, "LEFT", x, 0)
        btn.slotKey = slotKey
        btn.slotIndex = i
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:SetScript("OnClick", function(self, button)
            FB.OnSlotClick(self, button)
        end)
        btn:SetScript("OnEnter", function(self)
            self.glass:SetVertexColor(1, 1, 1, 0.32)
            if L.PlayUIHoverSound then L.PlayUIHoverSound() end
            FB.ShowSlotTooltip(self, statsFrame)
        end)
        btn:SetScript("OnLeave", function(self)
            self.glass:SetVertexColor(1, 1, 1, 0)
            GameTooltip:Hide()
        end)
        qBtns[i] = btn
    end
    statsFrame.ledgerBarButtons = qBtns
    statsFrame.filterBarAttached = true
    FB.UpdateGlows(statsFrame)
end
