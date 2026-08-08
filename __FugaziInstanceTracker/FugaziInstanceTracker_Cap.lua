local addonName, L = ...

----------------------------------------------------------------------
-- Soft-pause while ghost / corpse running.
-- Releasing spirit zones you out of the instance on 3.3.5a; we keep the
-- open run (timer continues from original enterTime) until you are alive
-- outside, or enter a different instance.
----------------------------------------------------------------------
function L.IsPlayerGhost()
    return (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) and true or false
end

function L.ClearSoftPause()
    L.runSoftPaused = false
    if InstanceTrackerDB then InstanceTrackerDB.runSoftPaused = false end
end

----------------------------------------------------------------------
-- Manastorm gate (Ascension) — keep this small.
-- GetInstanceInfo looks like a normal dungeon; real signals are:
--   chat "You have entered a level N Manastorm!"  (primary)
--   ManastormObjectiveTracker:IsShown()           (secondary)
-- Sticky flag only applies for the current visit; cleared on leave.
----------------------------------------------------------------------
L.manastormActive = false

--- Live UI check only (no sticky). Prior MS visit must not block normal dungeons.
--- IsShown only (not IsVisible) — avoids parent-chain false positives.
function L.DetectManastormNow()
    local f = _G.ManastormObjectiveTracker
    return f and f.IsShown and f:IsShown() and true or false
end

--- Drop open run without writing Ledger history.
function L.AbortRunNoHistory(reason)
    if not L.currentRun then return end
    local name = L.currentRun.name or "?"
    local A = _G.FugaziBAGS
    if A and type(A.EndLootIgnoreTracking) == "function" then
        pcall(A.EndLootIgnoreTracking)
    end
    L.currentRun = nil
    L.ClearSoftPause()
    if InstanceTrackerDB then
        InstanceTrackerDB.currentRun = nil
        InstanceTrackerDB.bagBaseline = nil
        InstanceTrackerDB.itemsGained = nil
        InstanceTrackerDB.startingGold = nil
        InstanceTrackerDB.runSoftPaused = false
    end
    L.bagBaseline = nil
    L.itemsGained = nil
    L.startingGold = nil
    if reason then
        L.AddonPrint(
            L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
            .. tostring(reason)
            .. (name ~= "?" and (" (" .. L.ColorText(name, 1, 1, 0.6) .. ")") or "")
            .. "."
        )
    end
    if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
        L.RefreshStatsUI()
    end
end

local function RemoveRecentInstanceNamed(name, maxAgeSec)
    if not name or not InstanceTrackerDB or type(InstanceTrackerDB.recentInstances) ~= "table" then
        return
    end
    maxAgeSec = maxAgeSec or 120
    local now = time()
    local list = InstanceTrackerDB.recentInstances
    for i = #list, 1, -1 do
        local e = list[i]
        if e and e.name == name and (not e.time or (now - e.time) <= maxAgeSec) then
            table.remove(list, i)
            return true
        end
    end
end

local function SkipManastorm(zoneName, announce)
    local hadRun = L.currentRun ~= nil
    local was = L.manastormActive
    local Loc = L.Loc
    local msgIgnored = (Loc and Loc.MSG_MANASTORM_IGNORED) or "Manastorm ignored — not saved to Ledger"
    local msgDetected = (Loc and Loc.MSG_MANASTORM_DETECTED) or "Manastorm detected — not tracked in Ledger"
    L.manastormActive = true
    if hadRun then
        L.AbortRunNoHistory(msgIgnored)
    elseif announce and not was then
        L.AddonPrint(
            L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
            .. msgDetected
            .. (zoneName and (" (" .. L.ColorText(zoneName, 1, 1, 0.6) .. ")") or "")
            .. "."
        )
    end
    if zoneName then RemoveRecentInstanceNamed(zoneName, 180) end
    L.isInInstance = true
    L.currentZone = zoneName or L.currentZone or ""
    if InstanceTrackerDB then
        InstanceTrackerDB.isInInstance = true
        InstanceTrackerDB.currentZone = L.currentZone
        InstanceTrackerDB.currentRun = nil
    end
end

-- Short delayed check: PEW can beat the system message / tracker show.
local msRecheck = CreateFrame("Frame")
msRecheck:Hide()
msRecheck.t, msRecheck.n, msRecheck.zone = 0, 0, nil
msRecheck:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t < 0.35 then return end
    self.t = 0
    self.n = self.n + 1
    -- Live UI only (chat sets sticky + SkipManastorm itself).
    if L.DetectManastormNow() then
        SkipManastorm(self.zone, true)
        self:Hide()
        return
    end
    if L.manastormActive and L.currentRun then
        -- Chat already fired while a false-start run was open.
        SkipManastorm(self.zone, false)
        self:Hide()
        return
    end
    if self.n >= 6 then self:Hide() end
end)

local function ScheduleManastormRecheck(zoneName)
    msRecheck.zone, msRecheck.t, msRecheck.n = zoneName, 0, 0
    msRecheck:Show()
end

--- Keep currentRun open after ghost-zoning out. Does not write history.
function L.SoftPauseRun()
    if not L.currentRun then return end
    local name = L.currentRun.name or "?"
    -- So "has been reset" while corpse-running still marks this zone don't-restore.
    lastExitedZoneName = name
    L.runSoftPaused = true
    L.isInInstance = false
    L.currentZone = ""
    if InstanceTrackerDB then
        InstanceTrackerDB.runSoftPaused = true
        InstanceTrackerDB.isInInstance = false
        InstanceTrackerDB.currentZone = ""
        InstanceTrackerDB.currentRun = L.currentRun
    end
    L.AddonPrint(
        L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
        .. "Run paused (ghost): " .. L.ColorText(name, 1, 1, 0.6)
        .. " — timer still running."
    )
    if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
        L.RefreshStatsUI()
    end
end

--- Alive + outside + open run → real finalize (end of corpse run without re-enter, hearth, etc.).
function L.MaybeFinalizeAliveOutside()
    if not L.currentRun then return end
    if L.isInInstance then return end
    if L.IsPlayerGhost and L.IsPlayerGhost() then return end
    if L.manastormActive then
        L.AbortRunNoHistory((L.Loc and L.Loc.MSG_MANASTORM_IGNORED) or "Manastorm ignored — not saved to Ledger")
        L.manastormActive = false
        return
    end
    L.ClearSoftPause()
    if type(L.FinalizeRun) == "function" then
        L.FinalizeRun()
    end
end

local capEventFrame = CreateFrame("Frame")
capEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
capEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
capEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
capEventFrame:RegisterEvent("PLAYER_UNGHOST")
capEventFrame:RegisterEvent("PLAYER_ALIVE")
capEventFrame:SetScript("OnEvent", function(self, event, ...)

    if event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
        -- Rez outside after a corpse run: close the run for real.
        L.MaybeFinalizeAliveOutside()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local inInstance, instanceType = IsInInstance()
        local zoneName = GetInstanceInfo and select(1, GetInstanceInfo()) or GetRealZoneText()
        if inInstance and (instanceType == "party" or instanceType == "raid") then
            -- Live tracker only. Sticky alone never blocks a new dungeon enter.
            if L.DetectManastormNow() then
                SkipManastorm(zoneName, true)
                return
            end

            if not L.isInInstance or L.currentZone ~= zoneName then
                if L.currentRun and L.currentRun.name ~= zoneName then
                    L.ClearSoftPause()
                    if L.manastormActive then
                        L.AbortRunNoHistory(nil)
                    else
                        L.FinalizeRun()
                    end
                end
                -- Soft-paused run for a zone that was reset: close it, start fresh (no restore).
                if L.currentRun and L.currentRun.name == zoneName and lastResetZoneName and lastResetZoneName == zoneName then
                    lastResetZoneName = nil
                    L.ClearSoftPause()
                    L.FinalizeRun()
                end
                local wasSoftPaused = L.runSoftPaused and L.currentRun and L.currentRun.name == zoneName
                L.ClearSoftPause()
                L.manastormActive = false
                L.isInInstance = true
                L.currentZone = zoneName
                L.RecordInstance(zoneName)
                local dIdx, dName, mapId
                if GetInstanceInfo then
                    -- name, type, difficultyIndex, difficultyName, maxPlayers, dynDiff, isDyn, [mapID on some clients]
                    dIdx = select(3, GetInstanceInfo())
                    dName = select(4, GetInstanceInfo())
                    mapId = select(8, GetInstanceInfo())
                end
                if L.CapData and L.CapData.RememberResettable then
                    L.CapData.RememberResettable(zoneName, {
                        source = "enter",
                        isRaid = (instanceType == "raid"),
                        diff = dIdx,
                        difficultyName = dName,
                        mapId = mapId,
                    })
                end
                RequestRaidInfo()
                -- Soft-paused run still on L.currentRun: just continue (no history restore).
                if not L.currentRun or L.currentRun.name ~= zoneName then
                    L.RestoreRunFromHistory(zoneName)
                end
                if not L.currentRun or L.currentRun.name ~= zoneName then
                    L.StartRun(zoneName)
                elseif wasSoftPaused then
                    L.AddonPrint(
                        L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
                        .. "Run resumed: " .. L.ColorText(L.currentRun.name, 1, 1, 0.6) .. "."
                    )
                    if L.statsFrame and L.statsFrame:IsShown() and type(L.RefreshStatsUI) == "function" then
                        L.RefreshStatsUI()
                    end
                end
                -- Keep reset/API fields on the live run for Reset ID.
                if L.currentRun and L.currentRun.name == zoneName then
                    L.currentRun.diff = dIdx or L.currentRun.diff
                    L.currentRun.difficultyName = dName or L.currentRun.difficultyName
                    L.currentRun.mapId = mapId or L.currentRun.mapId
                    L.currentRun.isRaid = (instanceType == "raid")
                    if InstanceTrackerDB then InstanceTrackerDB.currentRun = L.currentRun end
                end
                -- Chat/UI may confirm Manastorm a beat after PEW → abort then.
                ScheduleManastormRecheck(zoneName)
                -- Switch Ledger to Dungeons tab when entering a dungeon
                if L.statsFrame and L.statsFrame:IsShown() and L.statsFrame.UpdateStatsTabs and L.currentRun then
                    L.statsFrame.selectedTab = 3
                    L.statsFrame:UpdateStatsTabs()
                end
            elseif L.manastormActive and not L.currentRun then
                -- Same MS visit after chat skip; stay quiet.
                L.isInInstance = true
                L.currentZone = zoneName
            end
        else
            msRecheck:Hide()
            local wasMS = L.manastormActive
            L.manastormActive = false
            if L.isInInstance and L.currentRun then
                if wasMS then
                    L.AbortRunNoHistory((L.Loc and L.Loc.MSG_MANASTORM_IGNORED) or "Manastorm ignored — not saved to Ledger")
                    L.isInInstance = false
                    L.currentZone = ""
                elseif L.IsPlayerGhost and L.IsPlayerGhost() then
                    -- Corpse run / release spirit: pause, do not finalize.
                    L.SoftPauseRun()
                else
                    L.ClearSoftPause()
                    -- Track for Reset ID menu / list (GetSavedInstanceInfo often omits normal IDs on Ascension).
                    if L.currentRun and L.currentRun.name and L.CapData and L.CapData.RememberResettable then
                        L.CapData.RememberResettable(L.currentRun.name, { source = "exit" })
                    end
                    L.FinalizeRun()
                    L.isInInstance = false
                    L.currentZone = ""
                end
            else
                L.isInInstance = false
                L.currentZone = ""
                -- Soft-paused and now alive outside (e.g. zone tick after rez).
                L.MaybeFinalizeAliveOutside()
            end
        end

    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        if not msg then return end
        local lower = msg:lower()
        local Loc = L.Loc
        local entered = (Loc and Loc.CHAT_MANASTORM_ENTERED) or "entered a level"
        local msName = (Loc and Loc.CHAT_MANASTORM_NAME) or "manastorm"
        local tooMany = (Loc and Loc.CHAT_TOO_MANY_INSTANCES) or "too many instances"
        local beenReset = (Loc and Loc.CHAT_HAS_BEEN_RESET) or "has been reset"
        -- Ascension: "You have entered a level 1 Manastorm!"
        if lower:find(entered, 1, true) and lower:find(msName, 1, true) then
            local zoneName = (GetInstanceInfo and select(1, GetInstanceInfo())) or GetRealZoneText() or L.currentZone
            SkipManastorm(zoneName, true)
            return
        end
        -- Items destroyed: client typically doesn't print a system message, so we don't parse chat for it
        if msg:find(tooMany, 1, true) then
            -- Hourly cap warning (classic only; Ascension has no hourly cap).
            if L.IsHourlyCapEnabled and L.IsHourlyCapEnabled() then
                L.AddonPrint(
                    L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1)
                    .. L.ColorText("WARNING: ", 1, 0.2, 0.2) .. "You've hit the hourly instance cap!"
                )
                if not InstanceTrackerDB.mainFrameUserClosed and L.frame and not L.frame:IsShown() then
                    L.frame:Show()
                    L.SaveFrameLayout(L.frame, "frameShown", "framePoint")
                    L.RefreshUI()
                end
            end
        elseif lastExitedZoneName and lower:find(beenReset, 1, true) then
            -- Instance/dungeon reset: keep the run in history (so it stays in the list) but don't restore it on re-enter.
            lastResetZoneName = lastExitedZoneName
            lastExitedZoneName = nil
        end
    end
end)

----------------------------------------------------------------------
-- CAP AND LOCKOUTS DATA LAYER
-- Classic 3.3.5a: hourly cap + lockouts + reset.
-- Ascension: no hourly cap; lockouts + instance ID + boss rows (tooltip scrape).
----------------------------------------------------------------------
L.CapData = {}
local _lockoutBuckets = { classic = {}, tbc = {}, wotlk = {}, unknown = {} }

function L.CapData.GetHourlyStats()
    local now = time()
    local recent = _G.InstanceTrackerDB and _G.InstanceTrackerDB.recentInstances or {}
    local count = #recent
    local maxCap = L.MAX_INSTANCES_PER_HOUR or 5
    local isEnabled = (not L.IsHourlyCapEnabled) or L.IsHourlyCapEnabled()
    
    local stats = {
        enabled = isEnabled,
        count = count,
        remaining = maxCap - count,
        max = maxCap,
        nextSlotTimer = 0,
        instances = {}
    }
    
    if count >= maxCap and recent[1] then
        stats.nextSlotTimer = (recent[1].time + L.HOUR_SECONDS) - now
    end
    
    for i, entry in ipairs(recent) do
        local timeLeft = L.HOUR_SECONDS - (now - entry.time)
        table.insert(stats.instances, {
            index = i,
            name = entry.name or "Unknown",
            timeLeft = timeLeft
        })
    end
    
    return stats
end

function L.CapData.GetLockouts()
    -- Always refresh on Ascension (boss cache / IDs matter); classic every 5s.
    local isAsc = L.IsAscensionRealm and L.IsAscensionRealm()
    local age = L.lockoutQueryTime and (time() - L.lockoutQueryTime) or 999
    if isAsc or age > 5 then
        if L.UpdateLockoutCache then L.UpdateLockoutCache() end
    end
    
    wipe(_lockoutBuckets.classic)
    wipe(_lockoutBuckets.tbc)
    wipe(_lockoutBuckets.wotlk)
    wipe(_lockoutBuckets.unknown)
    
    local now = time()
    local queryTime = L.lockoutQueryTime or now
    
    for _, info in ipairs(L.lockoutCache or {}) do
        local exp = L.GetExpansion and L.GetExpansion(info.name) or nil
        local target = exp and _lockoutBuckets[exp] or _lockoutBuckets.unknown
        
        -- Difficulty label: do NOT wrap difficultyName in extra ().
        -- Ascension often returns "Normal (10-25 Players)" already — outer parens looked like (Normal (10-25)).
        local diffTag = ""
        if info.difficultyName and info.difficultyName ~= "" then
            diffTag = " |cff888888" .. info.difficultyName .. "|r"
        elseif info.isRaid then
            if info.diff == 1 then diffTag = " |cff88888810N|r"
            elseif info.diff == 2 then diffTag = " |cff88888825N|r"
            elseif info.diff == 3 then diffTag = " |cff88888810H|r"
            elseif info.diff == 4 then diffTag = " |cff88888825H|r" end
        else
            if info.diff == 1 then diffTag = " |cff888888Normal|r"
            elseif info.diff == 2 then diffTag = " |cff888888Heroic|r" end
        end
        
        local rawReset = tonumber(info.resetAtQuery) or 0
        local current_reset = rawReset - (now - queryTime)
        -- Ascension sometimes returns negative reset while still locked (UI timer is correct).
        local isLocked = info.locked and true or false
        local timeLeft = current_reset
        local timeUnknown = false
        if isLocked and current_reset <= 0 then
            timeUnknown = true
            timeLeft = 0
        elseif (not isLocked) and current_reset <= 0 then
            isLocked = false
            timeLeft = 0
        end
        
        -- Boss list: cache entry or live on info
        local bosses = info.bosses
        if (not bosses or #bosses == 0) and info.id and L.lockoutBossCache and L.lockoutBossCache[info.id] then
            bosses = L.lockoutBossCache[info.id].bosses
        end
        
        table.insert(target, {
            name = info.name,
            id = info.id,
            diff = info.diff,
            diffTag = diffTag,
            difficultyName = info.difficultyName,
            isRaid = info.isRaid,
            isLocked = isLocked,
            extended = info.extended,
            timeLeft = timeLeft,
            timeUnknown = timeUnknown,
            bosses = bosses,
        })
    end
    
    return _lockoutBuckets
end

----------------------------------------------------------------------
-- Instance ID reset (Ascension uses COMFIRM_RESET_SPECIFIC_INSTANCE +
-- ResetInstanceDifficult — note the COMFIRM typo and Difficult spelling).
----------------------------------------------------------------------

local function CapPrint(msg)
    if L.AddonPrint then
        L.AddonPrint(L.ColorText("[InstanceTracker] ", 0.4, 0.8, 1) .. msg)
    end
end

local function ScheduleLockoutRefresh(delay)
    delay = delay or 0.8
    if not L._resetRefreshFrame then
        L._resetRefreshFrame = CreateFrame("Frame")
    end
    local f = L._resetRefreshFrame
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed < delay then return end
        self:SetScript("OnUpdate", nil)
        if RequestRaidInfo then RequestRaidInfo() end
        if L.UpdateLockoutCache then L.UpdateLockoutCache() end
        if L.frame and L.frame:IsShown() and L.RefreshUI then L.RefreshUI(true) end
    end)
end

local RESETTABLE_MAX_AGE = 6 * 3600

local function DiffLabel(info)
    if not info then return "Normal" end
    if info.difficultyName and info.difficultyName ~= "" then
        -- Portrait uses short labels like "Normal", not "Normal (10-25 Players)"
        local dn = info.difficultyName
        local low = dn:lower()
        local Loc = L.Loc
        local findM = (Loc and Loc.DIFF_FIND_MYTHIC) or "mythic"
        local findH = (Loc and Loc.DIFF_FIND_HEROIC) or "heroic"
        local findN = (Loc and Loc.DIFF_FIND_NORMAL) or "normal"
        if low:find(findM, 1, true) then return (Loc and Loc.DIFF_LABEL_MYTHIC) or "Mythic" end
        if low:find(findH, 1, true) then return (Loc and Loc.DIFF_LABEL_HEROIC) or "Heroic" end
        if low:find(findN, 1, true) then return (Loc and Loc.DIFF_LABEL_NORMAL) or "Normal" end
        return dn
    end
    local d = tonumber(info.diff)
    if info.isRaid then
        if d == 1 then return "10N" elseif d == 2 then return "25N"
        elseif d == 3 then return "10H" elseif d == 4 then return "25H" end
    else
        if d == 1 then return "Normal" elseif d == 2 then return "Heroic"
        elseif d == 3 then return "Mythic" end
    end
    return "Normal"
end

local function DisplayNameForReset(info)
    local name = (info and info.name) or "?"
    if name:find("%(") then return name end
    return name .. " (" .. DiffLabel(info) .. ")"
end

--- Enrich mapId/diff for instances that already have a real lockout (GetSavedInstanceInfo).
--- Does NOT create phantom "IDs" from mere dungeon visits (LFG/RDF leaves no resettable ID).
function L.CapData.RememberResettable(name, extra)
    if not name or name == "" or not InstanceTrackerDB then return end
    extra = extra or {}
    -- Only keep enrichment for visits that already look like a real lockout (have id),
    -- or that we will match later against GetSavedInstanceInfo by name.
    -- RDF / random finder: no portrait ID → we still store mapId briefly, but
    -- GetResettableList will not surface it unless lockoutCache confirms.
    InstanceTrackerDB.resettableInstances = InstanceTrackerDB.resettableInstances or {}
    local list = InstanceTrackerDB.resettableInstances
    local now = time()
    local found
    for i = #list, 1, -1 do
        local e = list[i]
        if not e or not e.name or (now - (e.time or 0)) > RESETTABLE_MAX_AGE then
            table.remove(list, i)
        elseif e.name == name then
            found = e
        end
    end
    if found then
        found.time = now
        found.diff = extra.diff or found.diff
        found.difficultyName = extra.difficultyName or found.difficultyName
        found.isRaid = extra.isRaid or found.isRaid
        found.id = extra.id or found.id
        found.mapId = extra.mapId or found.mapId
        found.source = extra.source or found.source or "fit"
    else
        table.insert(list, 1, {
            name = name,
            time = now,
            diff = extra.diff,
            difficultyName = extra.difficultyName,
            isRaid = extra.isRaid,
            id = extra.id,
            mapId = extra.mapId,
            source = extra.source or "fit",
        })
    end
    while #list > 20 do table.remove(list) end
end

--- Instances you can actually reset = portrait "Reset Instances" list
--- (GetSavedInstanceInfo / lockoutCache). Mere FIT enter tracking is not an ID.
function L.CapData.GetResettableList()
    local out, seenByName = {}, {}
    local function add(info)
        if not info or not info.name then return end
        local existing = seenByName[info.name]
        if existing then
            if not existing.mapId and info.mapId then existing.mapId = info.mapId end
            if not existing.diff and info.diff then existing.diff = info.diff end
            if not existing.difficultyName and info.difficultyName then
                existing.difficultyName = info.difficultyName
            end
            if not existing.id and info.id then existing.id = info.id end
            if not existing.index and info.index then existing.index = info.index end
            if info.isRaid ~= nil and existing.isRaid == nil then existing.isRaid = info.isRaid end
            return
        end
        seenByName[info.name] = info
        out[#out + 1] = info
    end

    -- Enrichment lookup (mapId/diff from FIT visits) — never a standalone ID source.
    local enrichByName = {}
    local now = time()
    for _, e in ipairs(InstanceTrackerDB and InstanceTrackerDB.resettableInstances or {}) do
        if e and e.name and (now - (e.time or 0)) <= RESETTABLE_MAX_AGE then
            enrichByName[e.name] = e
        end
    end

    if L.UpdateLockoutCache then L.UpdateLockoutCache() end
    for _, info in ipairs(L.lockoutCache or {}) do
        if info and info.name then
            local en = enrichByName[info.name]
            add({
                name = info.name,
                id = info.id,
                diff = info.diff or (en and en.diff),
                difficultyName = info.difficultyName or (en and en.difficultyName),
                isRaid = info.isRaid,
                locked = info.locked,
                source = "saved",
                index = info.index,
                mapId = en and en.mapId,
            })
        end
    end

    -- Prune FIT-only memories that never became real lockouts (RDF, failed enter, etc.).
    local list = InstanceTrackerDB and InstanceTrackerDB.resettableInstances
    if list then
        for i = #list, 1, -1 do
            local e = list[i]
            if e and e.name and not seenByName[e.name] then
                -- Keep very fresh entries briefly (lockout API may lag after a real lock).
                if not e.time or (now - e.time) > 180 then
                    table.remove(list, i)
                end
            end
        end
    end

    return out
end

--- Ascension API name is ResetInstanceDifficult (not …Difficulty).
local function ResetInstanceFn()
    return _G.ResetInstanceDifficult or _G.ResetInstanceDifficulty
end

local function ForgetResettable(name)
    local list = InstanceTrackerDB and InstanceTrackerDB.resettableInstances
    if not list or not name then return end
    for i = #list, 1, -1 do
        if list[i] and list[i].name == name then table.remove(list, i) end
    end
end

--- Call Ascension/classic reset APIs for one instance (after confirm).
function L.CapData.DoResetOne(info)
    if not info then return false end
    local name = info.name or "?"
    local fn = ResetInstanceFn()
    local okAny = false

    local function try(arg1, arg2)
        if not fn then return false end
        if arg1 == nil then return false end
        local ok
        if arg2 ~= nil then
            ok = pcall(fn, arg1, arg2)
        else
            ok = pcall(fn, arg1)
        end
        if ok then okAny = true end
        return ok
    end

    -- Prefer mapId + difficulty (what portrait-style specific reset usually needs)
    try(info.mapId, info.diff)
    try(info.mapId)
    try(info.diff)
    try(info.id)
    try(info.index)
    try(name, info.diff)
    try(name)
    try(DisplayNameForReset(info))

    -- Classic bulk fallback only if nothing else accepted the call
    if not okAny and type(ResetInstances) == "function" and not info.isRaid then
        if pcall(ResetInstances) then okAny = true end
    end

    if RequestRaidInfo then RequestRaidInfo() end
    ScheduleLockoutRefresh(0.8)

    if okAny then
        CapPrint("Reset requested for " .. L.ColorText(DisplayNameForReset(info), 1, 1, 0.6) .. ".")
        ForgetResettable(name)
    else
        CapPrint("Could not reset " .. L.ColorText(name, 1, 1, 0.6)
            .. " — portrait → Reset Instances still works if this fails.")
    end
    return okAny
end

--- Use Ascension's real confirm dialog (COMFIRM_… typo). FIT only supplies the target.
local function SpecificResetPopupName()
    if StaticPopupDialogs and StaticPopupDialogs["COMFIRM_RESET_SPECIFIC_INSTANCE"] then
        return "COMFIRM_RESET_SPECIFIC_INSTANCE"
    end
    if StaticPopupDialogs and StaticPopupDialogs["CONFIRM_RESET_SPECIFIC_INSTANCE"] then
        return "CONFIRM_RESET_SPECIFIC_INSTANCE"
    end
    return nil
end

local function EnsureSpecificResetHook()
    local which = SpecificResetPopupName()
    if not which then return end
    local d = StaticPopupDialogs[which]
    if not d or d._fugaziResetHooked then return end
    d._fugaziResetHooked = true
    local orig = d.OnAccept
    d.OnAccept = function(self, data)
        -- FIT path: we set _fitResetPending before StaticPopup_Show
        local pending = L._fitResetPending
        if pending then
            L._fitResetPending = nil
            -- 1) Let Ascension's own handler try with the data we passed to Show
            if orig then pcall(orig, self, data) end
            -- 2) Also drive ResetInstanceDifficult ourselves (portrait data shape is opaque)
            if L.CapData and L.CapData.DoResetOne then
                L.CapData.DoResetOne(pending)
            end
            return
        end
        -- Portrait / other UI: keep original behaviour only
        if orig then
            return orig(self, data)
        end
    end
end

function L.CapData.ResetOneID(info)
    if not info or not info.name then return false end
    EnsureSpecificResetHook()
    local which = SpecificResetPopupName()

    if which then
        L._fitResetPending = info
        -- Ascension text: "Are you sure you want to reset %s (%s)?"
        -- → arg1 = instance name, arg2 = difficulty label (e.g. Normal). Not one combined string.
        local baseName = info.name or "?"
        -- If name already has a trailing "(Diff)", strip it so we don't double-wrap.
        local stripped = baseName:match("^(.-)%s*%([^%)]+%)%s*$")
        if stripped and stripped ~= "" then baseName = stripped end
        local diffText = DiffLabel(info)
        -- data: mapId preferred for Ascension's OnAccept / ResetInstanceDifficult
        local data = info.mapId or info.diff or info.id or info.name
        local dialog = StaticPopup_Show(which, baseName, diffText, data)
        if dialog then
            ScheduleLockoutRefresh(1.2)
            return true
        end
        L._fitResetPending = nil
    end

    -- No stock popup: confirm-less last resort
    return L.CapData.DoResetOne(info)
end

function L.CapData.ResetAllIDs()
    if L.IsAscensionRealm and L.IsAscensionRealm() then
        -- Ascension bulk: real dialogs if present
        if StaticPopupDialogs and StaticPopupDialogs["CONFIRM_RESET_DUNGEONS"] then
            StaticPopup_Show("CONFIRM_RESET_DUNGEONS")
            ScheduleLockoutRefresh(1.0)
            return true
        end
        CapPrint("On Ascension, pick a named instance from the Reset ID menu.")
        return false
    end
    if StaticPopupDialogs and StaticPopupDialogs["CONFIRM_RESET_INSTANCES"] then
        StaticPopup_Show("CONFIRM_RESET_INSTANCES")
        ScheduleLockoutRefresh(1.0)
        return true
    end
    if type(ResetInstances) == "function" then
        pcall(ResetInstances)
        ScheduleLockoutRefresh(0.8)
        return true
    end
    return false
end

function L.CapData.OpenResetMenu(anchor)
    if type(UIDropDownMenu_Initialize) ~= "function" or type(ToggleDropDownMenu) ~= "function" then
        CapPrint("Dropdown UI missing — right-click a row instead.")
        return
    end
    if RequestRaidInfo then RequestRaidInfo() end
    if L.UpdateLockoutCache then L.UpdateLockoutCache() end
    EnsureSpecificResetHook()

    if not L._resetMenuFrame then
        L._resetMenuFrame = CreateFrame("Frame", "FugaziIT_ResetMenu", UIParent, "UIDropDownMenuTemplate")
    end
    local menu = L._resetMenuFrame
    local entries = L.CapData.GetResettableList()
    local isAsc = L.IsAscensionRealm and L.IsAscensionRealm()

    UIDropDownMenu_Initialize(menu, function(self, level)
        if level ~= 1 then return end
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Reset Instances"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        if #entries == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cff888888No instances listed|r"
            info.notCheckable = true
            info.disabled = true
            UIDropDownMenu_AddButton(info)
        else
            for _, e in ipairs(entries) do
                info = UIDropDownMenu_CreateInfo()
                info.text = DisplayNameForReset(e)
                info.notCheckable = true
                info.func = function()
                    L.CapData.ResetOneID(e)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info)
            end
        end

        if not isAsc then
            info = UIDropDownMenu_CreateInfo()
            info.text = " "
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cffff8844Reset all|r"
            info.notCheckable = true
            info.func = function()
                L.CapData.ResetAllIDs()
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info)
        end
    end, "MENU")

    ToggleDropDownMenu(1, nil, menu, anchor or "cursor", 0, 0)
end

----------------------------------------------------------------------
-- CAP UI LAYER
----------------------------------------------------------------------
function L.CreateMainFrame()
    local backdrop = {
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 24,
        insets   = { left = 6, right = 6, top = 6, bottom = 6 },
    }
    local f = CreateFrame("Frame", "InstanceTrackerFrame", UIParent)
    f:SetWidth(340)
    f:SetHeight(400)
    f:SetPoint("TOP", UIParent, "CENTER", 0, 200)
    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.92)
    f:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        if L.SaveFrameLayout then L.SaveFrameLayout(f, "frameShown", "framePoint") end
    end)
    f:SetFrameStrata("DIALOG")

    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    titleBar:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    titleBar:SetBackdropColor(0.35, 0.28, 0.1, 0.7)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    if L.IsAscensionRealm and L.IsAscensionRealm() then
        title:SetText("|cffff0000Fugazi|r Lockouts")
    else
        title:SetText("|cffff0000Fugazi|r Instance Tracker")
    end
    title:SetTextColor(1, 0.85, 0.4, 1)

    f.itTitleBar = titleBar
    f.itTitleText = title

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        if L.SaveFrameLayout then L.SaveFrameLayout(f, "frameShown", "framePoint") end
        if _G.InstanceTrackerDB then _G.InstanceTrackerDB.mainFrameUserClosed = true end
    end)

    local statsBtn = CreateFrame("Button", nil, f)
    statsBtn:EnableMouse(true)
    statsBtn:SetHitRectInsets(0, 0, 0, 0)
    statsBtn:SetWidth(42)
    statsBtn:SetHeight(18)
    statsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    local statsBg = statsBtn:CreateTexture(nil, "BACKGROUND")
    statsBg:SetAllPoints()
    statsBg:SetTexture(0.1, 0.25, 0.15, 0.7)
    statsBtn.bg = statsBg
    local statsText = statsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statsText:SetPoint("CENTER")
    statsText:SetText("|cff66dd88Stats|r")
    statsBtn.label = statsText
    f.statsBtn = statsBtn

    statsBtn:SetScript("OnClick", function()
        if _G.InstanceTrackerStatsFrame then L.statsFrame = _G.InstanceTrackerStatsFrame end
        if not L.statsFrame and L.CreateStatsFrame then L.statsFrame = L.CreateStatsFrame() end
        if L.statsFrame:IsShown() then
            if L.SaveFrameLayout then L.SaveFrameLayout(L.statsFrame, "statsShown", "statsPoint") end
            L.statsFrame:Hide()
        else
            L.statsFrame:Show()
            if L.SaveFrameLayout then L.SaveFrameLayout(L.statsFrame, "statsShown", "statsPoint") end
            if L.RefreshStatsUI then L.RefreshStatsUI() end
        end
    end)
    statsBtn:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.15, 0.4, 0.2, 0.8)
        self.label:SetText("|cff88ffaaStats|r")
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("View Ledger", 0.4, 0.9, 0.5)
        GameTooltip:Show()
    end)
    statsBtn:SetScript("OnLeave", function(self)
        self.bg:SetTexture(0.1, 0.25, 0.15, 0.7)
        self.label:SetText("|cff66dd88Stats|r")
        GameTooltip:Hide()
    end)

    local resetBtn = CreateFrame("Button", nil, f)
    resetBtn:EnableMouse(true)
    resetBtn:SetHitRectInsets(0, 0, 0, 0)
    resetBtn:SetWidth(45)
    resetBtn:SetHeight(18)
    resetBtn:SetPoint("RIGHT", statsBtn, "LEFT", -2, 0)
    local resetBg = resetBtn:CreateTexture(nil, "BACKGROUND")
    resetBg:SetAllPoints()
    resetBg:SetTexture(0.3, 0.15, 0.1, 0.7)
    resetBtn.bg = resetBg
    local resetText = resetBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resetText:SetPoint("CENTER")
    resetText:SetText("|cffff8844Reset ID|r")
    resetBtn.label = resetText
    f.resetBtn = resetBtn

    resetBtn:SetScript("OnClick", function(self)
        if L.PlayUIClickSound then L.PlayUIClickSound() end
        if L.CapData and L.CapData.OpenResetMenu then
            L.CapData.OpenResetMenu(self)
        elseif L.CapData and L.CapData.ResetAllIDs then
            L.CapData.ResetAllIDs()
        elseif type(ResetInstances) == "function" then
            ResetInstances()
        end
    end)
    resetBtn:SetScript("OnEnter", function(self)
        self.bg:SetTexture(0.5, 0.25, 0.1, 0.8)
        self.label:SetText("|cffffaa66Reset ID|r")
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Reset Instances", 1, 0.6, 0.2)
        GameTooltip:AddLine("Pick an instance, then confirm (same dialog as the portrait menu).", 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Right-click a row to reset that one.", 0.6, 0.8, 1, true)
        GameTooltip:Show()
    end)
    resetBtn:SetScript("OnLeave", function(self)
        self.bg:SetTexture(0.3, 0.15, 0.1, 0.7)
        self.label:SetText("|cffff8844Reset ID|r")
        GameTooltip:Hide()
    end)

    local hourlyText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hourlyText:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 4, -8)
    hourlyText:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -4, -8)
    hourlyText:SetJustifyH("LEFT")
    f.hourlyText = hourlyText
    f.itHourlyText = hourlyText

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", hourlyText, "BOTTOMLEFT", 0, -6)
    sep:SetPoint("TOPRIGHT", hourlyText, "BOTTOMRIGHT", 0, -6)
    sep:SetTexture(1, 1, 1, 0.15)
    f.itSep = sep

    local scrollFrame = CreateFrame("ScrollFrame", "InstanceTrackerScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(L.SCROLL_CONTENT_WIDTH or 290)
    content:SetHeight(1)
    content:EnableMouse(true)
    scrollFrame:SetScrollChild(content)
    f.content = content
    f.scrollFrame = scrollFrame
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.SkinScrollBar then
        _G.__FugaziBAGS_Skins.SkinScrollBar(scrollFrame)
    end

    f.ApplySkin = function()
        if L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(f) end
        if _G.InstanceTrackerStatsFrame and L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerStatsFrame) end
        if _G.InstanceTrackerLedgerDetailFrame and L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerLedgerDetailFrame) end
        if _G.InstanceTrackerItemDetailFrame and L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(_G.InstanceTrackerItemDetailFrame) end
    end

    if L.ApplyInstanceTrackerSkin then L.ApplyInstanceTrackerSkin(f) end

    return f
end

L.RefreshUI = function(forceRebuild)
    if not L.frame then return end
    if not forceRebuild and not L.frame:IsShown() then return end
    if L.PurgeOld then L.PurgeOld() end
    if L.ResetPools then L.ResetPools() end

    local content = L.frame.content
    local pad = 4
    local yOff = 0

    local fontSettings = L.GetFugaziFontSettings and L.GetFugaziFontSettings() or {}
    local hdrSpacing = (fontSettings.headerSize or 11) + 6
    local rowSpacing = L.GetFugaziRowHeight and L.GetFugaziRowHeight(16) or 16
    local rowFont = fontSettings.rowFontPath or fontSettings.fontPath or "Fonts\\FRIZQT__.TTF"

    -- Truncation hover tooltips (full plain text when left side is ellipsized)
    content._mainHoverFrames = content._mainHoverFrames or {}
    for _, hf in ipairs(content._mainHoverFrames) do if hf then hf:Hide() end end
    local mainHoverIdx = 0
    local function AddMainRowHover(rowY, rowH, fullPlainText)
        if not fullPlainText or fullPlainText == "" then return end
        mainHoverIdx = mainHoverIdx + 1
        local hf = content._mainHoverFrames[mainHoverIdx]
        if not hf then
            hf = CreateFrame("Frame", nil, content)
            hf:EnableMouse(true)
            hf:SetScript("OnEnter", function(self)
                if self._fullText then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(self._fullText, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            hf:SetScript("OnLeave", function() GameTooltip:Hide() end)
            content._mainHoverFrames[mainHoverIdx] = hf
        end
        hf._fullText = fullPlainText
        hf:ClearAllPoints()
        hf:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -rowY)
        hf:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", (L.SCROLL_CONTENT_WIDTH or 290) - pad, -(rowY + rowH))
        hf:Show()
    end

    --- Dynamic left/right layout + hover if truncated (scale/font aware).
    local function SetMainRowTexts(row, leftText, rightText, rowY)
        if not row then return end
        local leftPad = (row.deleteBtn and row.deleteBtn:IsShown()) and 16 or 0
        local truncated
        if L.LayoutMainRowTexts then
            truncated = L.LayoutMainRowTexts(row, leftText, rightText, leftPad)
        else
            row.right:SetText(rightText or "")
            row.left:SetText(leftText or "")
            truncated = false
        end
        if truncated then
            local plain = (L.StripColorCodes and L.StripColorCodes(leftText)) or leftText
            AddMainRowHover(rowY, rowSpacing, plain)
        end
    end

    local capData = L.CapData.GetHourlyStats()
    if capData.enabled then
        local countColor = capData.remaining <= 0 and "|cffff4444" or capData.remaining <= 2 and "|cffff8800" or "|cff44ff44"
        local nextSlot = capData.nextSlotTimer > 0 and ("  |cffcccccc(next slot in " .. (L.FormatTime and L.FormatTime(capData.nextSlotTimer) or capData.nextSlotTimer) .. ")|r") or ""

        L.frame.hourlyText:SetFont(rowFont, fontSettings.rowSize or 12, "")
        L.frame.hourlyText:SetText(
            (L.ColorizeFugaziRowLabel and L.ColorizeFugaziRowLabel("Hourly Cap:") or "Hourly Cap:") .. "  "
            .. countColor .. capData.count .. "/" .. capData.max .. "|r"
            .. "  " .. countColor .. "(" .. capData.remaining .. " left)|r"
            .. nextSlot
        )
        L.frame.hourlyText:Show()

        local header1 = L.GetText and L.GetText(content)
        if header1 then
            header1:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
            header1:SetText("--- Recent Instances ---")
            if L.StyleFugaziHeader then L.StyleFugaziHeader(header1) end
            yOff = yOff + hdrSpacing
        end

        if capData.count == 0 then
            local none = L.GetText and L.GetText(content)
            if none then
                none:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
                none:SetText("|cff888888No recent instances.|r")
            end
            yOff = yOff + rowSpacing
        else
            for _, inst in ipairs(capData.instances) do
                local row = L.GetRow and L.GetRow(content, true)
                if row then
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
                    row.deleteBtn:SetScript("OnClick", function()
                        if L.RemoveInstance then L.RemoveInstance(inst.index); L.RefreshUI() end
                    end)

                    local leftText = "|cff666666" .. inst.index .. ".|r  |cffffffcc" .. inst.name .. "|r"
                    local rightText = inst.timeLeft > 0
                        and ("|cffff8844" .. (L.FormatTime and L.FormatTime(inst.timeLeft) or inst.timeLeft) .. "|r")
                        or "|cff44ff44Expired|r"
                    SetMainRowTexts(row, leftText, rightText, yOff)
                end
                yOff = yOff + rowSpacing
            end
        end
        yOff = yOff + 10
    else
        L.frame.hourlyText:SetFont(rowFont, fontSettings.rowSize or 12, "")
        -- Short label so large UI scale does not clip the title bar line
        L.frame.hourlyText:SetText((L.ColorizeFugaziRowLabel and L.ColorizeFugaziRowLabel("Hourly Cap:") or "Hourly Cap:") .. "  |cff888888N/A (Ascension)|r")
        L.frame.hourlyText:Show()
    end

    local isAsc = L.IsAscensionRealm and L.IsAscensionRealm()

    -- Boss lists collapsed by default; click raid row to expand. Session + SV.
    L.lockoutExpanded = L.lockoutExpanded or (InstanceTrackerDB and InstanceTrackerDB.lockoutExpanded) or {}
    if InstanceTrackerDB and not InstanceTrackerDB.lockoutExpanded then
        InstanceTrackerDB.lockoutExpanded = L.lockoutExpanded
    end

    content._lockoutClicks = content._lockoutClicks or {}
    for _, b in ipairs(content._lockoutClicks) do if b then b:Hide() end end
    local lockoutClickIdx = 0

    local function FormatLockoutStatus(info)
        if not info.isLocked then
            return "|cff44ff44Available|r"
        end
        if info.timeUnknown or not info.timeLeft or info.timeLeft <= 0 then
            return "|cffff8844Locked|r"
        end
        return "|cffff8844" .. (L.FormatTime and L.FormatTime(info.timeLeft) or tostring(info.timeLeft)) .. "|r"
    end

    local function LockoutExpandKey(info)
        if info.id then return tostring(info.id) end
        return tostring(info.name or "?") .. tostring(info.diffTag or "")
    end

    -- Full-row hit button: hover wash + sound (matches Ledger BindRowClickArea feel).
    -- Left: expand/collapse bosses. Right: reset this lockout ID (Ascension).
    local function BindLockoutRowClick(rowY, rowH, key, tipText, canExpand, lockoutInfo)
        lockoutClickIdx = lockoutClickIdx + 1
        local btn = content._lockoutClicks[lockoutClickIdx]
        if not btn then
            btn = CreateFrame("Button", nil, content)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            hl:SetVertexColor(1, 1, 1, 0.12)
            btn.highlight = hl
            content._lockoutClicks[lockoutClickIdx] = btn
        end
        btn._expandKey = key
        btn._tipText = tipText
        btn._canExpand = canExpand and true or false
        btn._lockoutInfo = lockoutInfo
        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if self._lockoutInfo and L.CapData and L.CapData.ResetOneID then
                    if L.PlayUIClickSound then L.PlayUIClickSound() end
                    L.CapData.ResetOneID(self._lockoutInfo)
                end
                return
            end
            if not self._canExpand then return end
            local k = self._expandKey
            if not k then return end
            L.lockoutExpanded = L.lockoutExpanded or {}
            L.lockoutExpanded[k] = not L.lockoutExpanded[k]
            if InstanceTrackerDB then
                InstanceTrackerDB.lockoutExpanded = InstanceTrackerDB.lockoutExpanded or {}
                if L.lockoutExpanded[k] then
                    InstanceTrackerDB.lockoutExpanded[k] = true
                else
                    InstanceTrackerDB.lockoutExpanded[k] = nil
                end
            end
            if L.PlayUIClickSound then L.PlayUIClickSound() end
            L.RefreshUI(true)
        end)
        btn:SetScript("OnEnter", function(self)
            if L.PlayUIHoverSound then L.PlayUIHoverSound() end
            if self._tipText then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(self._tipText, 1, 1, 1, true)
                if self._canExpand then
                    local open = L.lockoutExpanded and L.lockoutExpanded[self._expandKey]
                    GameTooltip:AddLine(open and "Left-click: collapse bosses" or "Left-click: expand bosses", 0.6, 0.8, 1)
                end
                GameTooltip:AddLine("Right-click: reset this instance ID", 1, 0.55, 0.3)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -rowY)
        btn:SetPoint("BOTTOMRIGHT", content, "TOPLEFT", (L.SCROLL_CONTENT_WIDTH or 290) - pad, -(rowY + rowH))
        btn:SetFrameLevel((content:GetFrameLevel() or 1) + 25)
        btn:EnableMouse(true)
        btn:Show()
    end

    -- No FIT-only "phantom ID" list: LFG/RDF visits are not resettable instance IDs.
    -- Truth source is GetSavedInstanceInfo (same as portrait → Reset Instances).
    -- Real lockouts are rendered from CapData.GetLockouts / lockoutCache above.

    local header2 = L.GetText and L.GetText(content)
    if header2 then
        header2:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
        header2:SetText(isAsc and "--- Raid / Instance Lockouts ---" or "--- Saved Lockouts ---")
        if L.StyleFugaziHeader then L.StyleFugaziHeader(header2) end
    end
    yOff = yOff + hdrSpacing

    local buckets = L.CapData.GetLockouts()
    local order = L.EXPANSION_ORDER or { "classic", "tbc", "wotlk" }
    local labels = L.EXPANSION_LABELS or { classic = "Classic", tbc = "TBC", wotlk = "WotLK" }

    local function RenderLockoutEntry(info)
        local row = L.GetRow and L.GetRow(content, false)
        if not row then return end
        row:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
        row:SetWidth(L.SCROLL_CONTENT_WIDTH or 290)
        row:SetHeight(rowSpacing)
        row.left:SetFont(rowFont, fontSettings.rowSize or 12, "")
        row.right:SetFont(rowFont, fontSettings.rowSize or 12, "")

        local bosses = info.bosses
        local hasBosses = bosses and #bosses > 0
        local key = LockoutExpandKey(info)
        local expanded = hasBosses and L.lockoutExpanded[key]

        local killedN, totalN = 0, hasBosses and #bosses or 0
        if hasBosses then
            for _, b in ipairs(bosses) do
                if b.killed then killedN = killedN + 1 end
            end
        end

        -- ASCII only (Frizqt): + collapsed, - expanded. Unicode arrows became "?".
        local chevron = ""
        if hasBosses then
            chevron = expanded and "|cffaaaaaa-|r " or "|cffaaaaaa+|r "
        end
        local extPart = info.extended and " |cff00ff00(Ext)|r" or ""
        local leftText = chevron
            .. (info.isLocked and "|cffff4444" or "|cff44ff44")
            .. (info.name or "Unknown") .. "|r"
            .. (info.diffTag or "")
            .. extPart
        local statusText = FormatLockoutStatus(info)
        if hasBosses and not expanded then
            statusText = statusText .. " |cff888888" .. killedN .. "/" .. totalN .. "|r"
        end

        local tipPlain = (info.name or "Unknown")
            .. (info.difficultyName and (" " .. info.difficultyName) or "")
            .. (info.id and (" #" .. tostring(info.id)) or "")
        local rowY = yOff
        SetMainRowTexts(row, leftText, statusText, rowY)
        -- Hover/sound always; left expand when bosses exist; right-click always can request ID reset
        BindLockoutRowClick(rowY, rowSpacing, key, tipPlain, hasBosses, info)
        yOff = yOff + rowSpacing

        -- Boss rows only when expanded (collapsed by default).
        if hasBosses and expanded then
            for _, boss in ipairs(bosses) do
                local bRow = L.GetRow and L.GetRow(content, false)
                if bRow then
                    bRow:SetPoint("TOPLEFT", content, "TOPLEFT", pad + 10, -yOff)
                    bRow:SetWidth((L.SCROLL_CONTENT_WIDTH or 290) - 10)
                    bRow:SetHeight(rowSpacing)
                    local bName = boss.name or "?"
                    local killed = boss.killed
                    local bLeft = (killed and "|cffff6666" or "|cff66ff66") .. "· " .. bName .. "|r"
                    local bRight
                    if boss.timeText and boss.timeText ~= "" then
                        bRight = "|cffff8844" .. boss.timeText .. "|r"
                    elseif killed then
                        bRight = "|cffff8844Locked|r"
                    else
                        bRight = "|cff66ff66Undefeated|r"
                    end
                    bRow.left:SetFont(rowFont, (fontSettings.rowSize or 12) - 1, "")
                    bRow.right:SetFont(rowFont, (fontSettings.rowSize or 12) - 1, "")
                    local trunc = L.LayoutMainRowTexts and L.LayoutMainRowTexts(bRow, bLeft, bRight, 0)
                    if trunc then
                        local plain = (L.StripColorCodes and L.StripColorCodes(bLeft)) or bLeft
                        if boss.status and boss.status ~= "" then plain = plain .. " — " .. boss.status end
                        AddMainRowHover(yOff, rowSpacing, plain)
                    end
                end
                yOff = yOff + rowSpacing
            end
        end
    end

    local anyLockout = false
    for _, exp in ipairs(order) do
        local bucket = buckets[exp]
        if bucket and #bucket > 0 then
            anyLockout = true
            local expH = L.GetText and L.GetText(content)
            if expH then
                expH:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
                expH:SetText(labels[exp] or exp)
                if L.StyleFugaziHeader then L.StyleFugaziHeader(expH) end
            end
            yOff = yOff + hdrSpacing

            table.sort(bucket, function(a, b) return (a.name or "") < (b.name or "") end)
            for _, info in ipairs(bucket) do
                RenderLockoutEntry(info)
            end
            yOff = yOff + 8
        end
    end

    if buckets.unknown and #buckets.unknown > 0 then
        anyLockout = true
        local expH = L.GetText and L.GetText(content)
        if expH then
            expH:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
            expH:SetText("|cff999999Other|r")
        end
        yOff = yOff + hdrSpacing

        for _, info in ipairs(buckets.unknown) do
            RenderLockoutEntry(info)
        end
        yOff = yOff + 8
    end

    if not anyLockout then
        local none = L.GetText and L.GetText(content)
        if none then
            none:SetPoint("TOPLEFT", content, "TOPLEFT", pad, -yOff)
            none:SetText("|cff888888No saved lockouts.|r")
        end
        yOff = yOff + rowSpacing
    end

    yOff = yOff + 8
    content:SetHeight(math.max(yOff, 1))
    -- Grow a bit when boss lists are long (cap height)
    local targetH = math.min(520, math.max(400, yOff + 80))
    L.frame:SetHeight(targetH)
end
