local addonName, L = ...

----------------------------------------------------------------------
-- Instance database: "which expansion does this dungeon belong to?"
-- Used to group lockouts (Classic / TBC / WotLK) and show the right label.
----------------------------------------------------------------------
L.INSTANCE_EXPANSION = {
    -- ==================== CLASSIC DUNGEONS ====================
    ["Ragefire Chasm"]              = "classic",
    ["Wailing Caverns"]             = "classic",
    ["The Deadmines"]               = "classic",
    ["Deadmines"]                   = "classic",
    ["Shadowfang Keep"]             = "classic",
    ["The Stockade"]                = "classic",
    ["Stockade"]                    = "classic",
    ["Blackfathom Deeps"]           = "classic",
    ["Gnomeregan"]                  = "classic",
    ["Razorfen Kraul"]              = "classic",
    ["The Scarlet Monastery"]       = "classic",
    ["Scarlet Monastery"]           = "classic",
    ["Razorfen Downs"]              = "classic",
    ["Uldaman"]                     = "classic",
    ["Zul'Farrak"]                  = "classic",
    ["Maraudon"]                    = "classic",
    ["Temple of Atal'Hakkar"]       = "classic",
    ["Sunken Temple"]               = "classic",
    ["Blackrock Depths"]            = "classic",
    ["Dire Maul"]                   = "classic",
    ["Dire Maul North"]             = "classic",
    ["Dire Maul East"]              = "classic",
    ["Dire Maul West"]              = "classic",
    ["Stratholme"]                  = "classic",
    ["Scholomance"]                 = "classic",
    ["Lower Blackrock Spire"]       = "classic",
    ["Upper Blackrock Spire"]       = "classic",
    ["Blackrock Spire"]             = "classic",
    -- ==================== CLASSIC RAIDS ====================
    ["Molten Core"]                 = "classic",
    ["Onyxia's Lair"]               = "classic",
    ["Blackwing Lair"]              = "classic",
    ["Zul'Gurub"]                   = "classic",
    ["Ruins of Ahn'Qiraj"]         = "classic",
    ["Temple of Ahn'Qiraj"]        = "classic",
    ["Ahn'Qiraj Temple"]           = "classic",
    ["Ahn'Qiraj"]                  = "classic",
    -- ==================== TBC DUNGEONS ====================
    ["Hellfire Ramparts"]                           = "tbc",
    ["Ramparts"]                                    = "tbc",
    ["Hellfire Citadel: Ramparts"]                  = "tbc",
    ["Hellfire Citadel: Hellfire Ramparts"]          = "tbc",
    ["The Blood Furnace"]                           = "tbc",
    ["Blood Furnace"]                               = "tbc",
    ["Hellfire Citadel: The Blood Furnace"]          = "tbc",
    ["Hellfire Citadel: Blood Furnace"]              = "tbc",
    ["The Shattered Halls"]                         = "tbc",
    ["Shattered Halls"]                             = "tbc",
    ["Hellfire Citadel: The Shattered Halls"]        = "tbc",
    ["Hellfire Citadel: Shattered Halls"]            = "tbc",
    ["The Slave Pens"]                              = "tbc",
    ["Slave Pens"]                                  = "tbc",
    ["Coilfang Reservoir: The Slave Pens"]           = "tbc",
    ["Coilfang Reservoir: Slave Pens"]               = "tbc",
    ["The Underbog"]                                = "tbc",
    ["Underbog"]                                    = "tbc",
    ["Coilfang Reservoir: The Underbog"]             = "tbc",
    ["Coilfang Reservoir: Underbog"]                 = "tbc",
    ["The Steamvault"]                              = "tbc",
    ["Steamvault"]                                  = "tbc",
    ["Coilfang Reservoir: The Steamvault"]           = "tbc",
    ["Coilfang Reservoir: Steamvault"]               = "tbc",
    ["Mana-Tombs"]                                  = "tbc",
    ["Mana Tombs"]                                  = "tbc",
    ["Auchindoun: Mana-Tombs"]                      = "tbc",
    ["Auchindoun: Mana Tombs"]                      = "tbc",
    ["Auchenai Crypts"]                             = "tbc",
    ["Auchindoun: Auchenai Crypts"]                 = "tbc",
    ["Sethekk Halls"]                               = "tbc",
    ["Auchindoun: Sethekk Halls"]                   = "tbc",
    ["Shadow Labyrinth"]                            = "tbc",
    ["Auchindoun: Shadow Labyrinth"]                = "tbc",
    ["Old Hillsbrad Foothills"]                     = "tbc",
    ["Caverns of Time: Old Hillsbrad Foothills"]    = "tbc",
    ["Old Hillsbrad"]                               = "tbc",
    ["The Escape From Durnholde"]                   = "tbc",
    ["Escape From Durnholde"]                       = "tbc",
    ["Durnholde Keep"]                              = "tbc",
    ["The Black Morass"]                            = "tbc",
    ["Black Morass"]                                = "tbc",
    ["Caverns of Time: The Black Morass"]           = "tbc",
    ["Caverns of Time: Black Morass"]               = "tbc",
    ["Opening of the Dark Portal"]                  = "tbc",
    ["The Mechanar"]                                = "tbc",
    ["Mechanar"]                                    = "tbc",
    ["Tempest Keep: The Mechanar"]                  = "tbc",
    ["Tempest Keep: Mechanar"]                      = "tbc",
    ["The Botanica"]                                = "tbc",
    ["Botanica"]                                    = "tbc",
    ["Tempest Keep: The Botanica"]                  = "tbc",
    ["Tempest Keep: Botanica"]                      = "tbc",
    ["The Arcatraz"]                                = "tbc",
    ["Arcatraz"]                                    = "tbc",
    ["Tempest Keep: The Arcatraz"]                  = "tbc",
    ["Tempest Keep: Arcatraz"]                      = "tbc",
    ["Magisters' Terrace"]                          = "tbc",
    ["Magister's Terrace"]                          = "tbc",
    -- ==================== TBC RAIDS ====================
    ["Karazhan"]                                    = "tbc",
    ["Gruul's Lair"]                                = "tbc",
    ["Magtheridon's Lair"]                          = "tbc",
    ["Serpentshrine Cavern"]                        = "tbc",
    ["Coilfang Reservoir: Serpentshrine Cavern"]    = "tbc",
    ["Tempest Keep"]                                = "tbc",
    ["The Eye"]                                     = "tbc",
    ["Tempest Keep: The Eye"]                       = "tbc",
    ["Hyjal Summit"]                                = "tbc",
    ["The Battle for Mount Hyjal"]                  = "tbc",
    ["Battle for Mount Hyjal"]                      = "tbc",
    ["Mount Hyjal"]                                 = "tbc",
    ["Caverns of Time: Hyjal Summit"]               = "tbc",
    ["Caverns of Time: Mount Hyjal"]                = "tbc",
    ["Caverns of Time: The Battle for Mount Hyjal"] = "tbc",
    ["Black Temple"]                                = "tbc",
    ["Zul'Aman"]                                    = "tbc",
    ["Sunwell Plateau"]                             = "tbc",
    -- ==================== WOTLK DUNGEONS ====================
    ["Utgarde Keep"]                                = "wotlk",
    ["Utgarde Pinnacle"]                            = "wotlk",
    ["The Nexus"]                                   = "wotlk",
    ["Nexus"]                                       = "wotlk",
    ["Azjol-Nerub"]                                 = "wotlk",
    ["Ahn'kahet: The Old Kingdom"]                  = "wotlk",
    ["Ahn'kahet"]                                   = "wotlk",
    ["Old Kingdom"]                                 = "wotlk",
    ["The Old Kingdom"]                             = "wotlk",
    ["Drak'Tharon Keep"]                            = "wotlk",
    ["The Violet Hold"]                             = "wotlk",
    ["Violet Hold"]                                 = "wotlk",
    ["Gundrak"]                                     = "wotlk",
    ["Halls of Stone"]                              = "wotlk",
    ["Halls of Lightning"]                          = "wotlk",
    ["The Culling of Stratholme"]                   = "wotlk",
    ["Culling of Stratholme"]                       = "wotlk",
    ["Caverns of Time: The Culling of Stratholme"]  = "wotlk",
    ["Caverns of Time: Culling of Stratholme"]      = "wotlk",
    ["The Oculus"]                                  = "wotlk",
    ["Oculus"]                                      = "wotlk",
    ["Trial of the Champion"]                       = "wotlk",
    ["The Forge of Souls"]                          = "wotlk",
    ["Forge of Souls"]                              = "wotlk",
    ["Pit of Saron"]                                = "wotlk",
    ["Halls of Reflection"]                         = "wotlk",
    -- ==================== WOTLK RAIDS ====================
    ["Naxxramas"]                                   = "wotlk",
    ["The Obsidian Sanctum"]                        = "wotlk",
    ["Obsidian Sanctum"]                            = "wotlk",
    ["The Eye of Eternity"]                         = "wotlk",
    ["Eye of Eternity"]                             = "wotlk",
    ["Vault of Archavon"]                           = "wotlk",
    ["Ulduar"]                                      = "wotlk",
    ["Trial of the Crusader"]                       = "wotlk",
    ["Trial of the Grand Crusader"]                 = "wotlk",
    ["Icecrown Citadel"]                            = "wotlk",
    ["The Ruby Sanctum"]                            = "wotlk",
    ["Ruby Sanctum"]                                = "wotlk",
}

L.EXPANSION_ORDER = { "classic", "tbc", "wotlk" }
local EXPANSION_LABELS = {
    classic = "|cffffcc00Classic|r",
    tbc     = "|cff1eff00The Burning Crusade|r",
    wotlk   = "|cff0070ddWrath of the Lich King|r",
}

function L.GetExpansion(instanceName)
    if not instanceName then return nil end
    local direct = L.INSTANCE_EXPANSION[instanceName]
    if direct then return direct end
    for knownName, exp in pairs(L.INSTANCE_EXPANSION) do
        if instanceName:find(knownName, 1, true) or knownName:find(instanceName, 1, true) then
            L.INSTANCE_EXPANSION[instanceName] = exp
            return exp
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Lockout cache + Raid Info tooltip boss scrape (Ascension has no
-- GetSavedInstanceEncounterInfo; boss list lives on RaidInfo tooltips).
----------------------------------------------------------------------

local function StripColors(s)
    if not s then return "" end
    return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t.-|t", ""))
end

--- Parse GameTooltip double-lines: boss name (left) + Locked/Undefeated (right).
function L.ParseRaidInfoTooltipBosses(tip)
    tip = tip or GameTooltip
    local bosses = {}
    if not tip or not tip.NumLines then return bosses end
    local tipName = tip:GetName() or "GameTooltip"
    local n = tip:NumLines() or 0
    for i = 1, n do
        local leftFS = _G[tipName .. "TextLeft" .. i]
        local rightFS = _G[tipName .. "TextRight" .. i]
        local lt = leftFS and leftFS:GetText()
        local rt = rightFS and rightFS:GetText()
        if lt and rt and rt ~= "" then
            local low = string.lower(StripColors(rt))
            local Loc = L.Loc
            local undefeated = (Loc and Loc.LOCKOUT_UNDEFEATED) or "undefeated"
            local locked = (Loc and Loc.LOCKOUT_LOCKED) or "locked"
            if low:find(undefeated, 1, true) or low:find(locked, 1, true) then
                local timeText = nil
                -- "locked (2 days)" style remaining time
                local lockedSec = low:match(locked .. "%s*%((.+)%)")
                if lockedSec then timeText = lockedSec end
                table.insert(bosses, {
                    name = StripColors(lt),
                    status = StripColors(rt),
                    killed = low:find(locked, 1, true) ~= nil,
                    timeText = timeText,
                })
            end
        end
    end
    return bosses
end

local function EnsureRaidInfoUpdated()
    if type(RequestRaidInfo) == "function" then
        pcall(RequestRaidInfo)
    end
    if type(RaidInfoFrame_Update) == "function" then
        pcall(RaidInfoFrame_Update)
    end
end

--- Try to fill tooltip for saved-instance index i (1-based) and parse bosses.
--- Works best after Raid Info has been opened once this session (buttons exist).
function L.ScrapeRaidInfoBosses(instanceIndex)
    if not instanceIndex or instanceIndex < 1 then return nil end
    EnsureRaidInfoUpdated()

    local btn = _G["RaidInfoScrollFrameButton" .. instanceIndex]
    if not btn then return nil end

    local onEnter = btn.GetScript and btn:GetScript("OnEnter")
    if type(RaidInfoInstance_OnEnter) == "function" then
        onEnter = RaidInfoInstance_OnEnter
    end
    if type(onEnter) ~= "function" then return nil end

    -- Avoid stealing a user-owned tooltip mid-hover when possible
    local prevOwner = GameTooltip:GetOwner()
    pcall(onEnter, btn)
    local bosses = L.ParseRaidInfoTooltipBosses(GameTooltip)
    GameTooltip:Hide()
    if prevOwner and prevOwner ~= btn then
        -- leave hidden; user can re-hover
    end
    if bosses and #bosses > 0 then
        return bosses
    end
    return nil
end

--- Refresh boss lists for all saved instances into lockoutBossCache (by instance id).
function L.RefreshLockoutBossCache()
    L.lockoutBossCache = L.lockoutBossCache or {}
    local num = GetNumSavedInstances and GetNumSavedInstances() or 0
    if num <= 0 then return end

    EnsureRaidInfoUpdated()

    for i = 1, num do
        local instName, instID = GetSavedInstanceInfo(i)
        if instID then
            local bosses = L.ScrapeRaidInfoBosses(i)
            if bosses and #bosses > 0 then
                L.lockoutBossCache[instID] = {
                    t = time(),
                    name = instName,
                    bosses = bosses,
                }
            end
        end
    end
end

-- When player opens Raid Info and hovers a row, cache bosses (reliable path).
local function HookRaidInfoTooltipScrape()
    if L._raidInfoBossHooked then return end
    if type(hooksecurefunc) ~= "function" then return end
    if type(RaidInfoInstance_OnEnter) ~= "function" then return end
    L._raidInfoBossHooked = true
    hooksecurefunc("RaidInfoInstance_OnEnter", function(self)
        if not self then return end
        local bosses = L.ParseRaidInfoTooltipBosses(GameTooltip)
        if not bosses or #bosses == 0 then return end
        local idx = self.GetID and self:GetID() or nil
        local instID, instName
        if idx and idx > 0 and GetSavedInstanceInfo then
            instName, instID = GetSavedInstanceInfo(idx)
        end
        -- Fallback: match by instance name on left of tooltip
        if not instID then
            local tipName = GameTooltip:GetName() or "GameTooltip"
            local l1 = _G[tipName .. "TextLeft1"]
            local header = l1 and StripColors(l1:GetText()) or nil
            local num = GetNumSavedInstances and GetNumSavedInstances() or 0
            for i = 1, num do
                local n, id = GetSavedInstanceInfo(i)
                if n and header and (header == n or header:find(n, 1, true)) then
                    instName, instID = n, id
                    break
                end
            end
        end
        if instID then
            L.lockoutBossCache = L.lockoutBossCache or {}
            L.lockoutBossCache[instID] = {
                t = time(),
                name = instName,
                bosses = bosses,
            }
            if L.frame and L.frame:IsShown() and L.RefreshUI then
                L.RefreshUI(true)
            end
        end
    end)
end

function L.UpdateLockoutCache()
    L.lockoutQueryTime = time()
    HookRaidInfoTooltipScrape()

    local numSaved = GetNumSavedInstances()
    for i = 1, numSaved do
        -- Classic order + optional maxPlayers / difficultyName (Ascension / later clients)
        local instName, instID, instReset, instDiff, locked, extended, mostsig, isRaid, maxPlayers, difficultyName =
            GetSavedInstanceInfo(i)
        if instName then
            local info = L.lockoutCache[i]
            if not info then
                info = {}
                L.lockoutCache[i] = info
            end
            info.name = instName
            info.id = instID
            info.resetAtQuery = instReset
            info.diff = instDiff
            info.locked = locked
            info.extended = extended
            info.isRaid = isRaid
            info.maxPlayers = maxPlayers
            info.difficultyName = difficultyName
            info.index = i

            -- Prefer encounter API if present (classic offline / other cores)
            info.bosses = nil
            if type(GetSavedInstanceEncounterInfo) == "function" then
                local nEnc = select(11, GetSavedInstanceInfo(i))
                if type(nEnc) == "number" and nEnc > 0 then
                    info.bosses = {}
                    for j = 1, nEnc do
                        local bName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
                        if bName then
                            table.insert(info.bosses, {
                                name = bName,
                                killed = isKilled and true or false,
                                status = isKilled and "Locked" or "Undefeated",
                            })
                        end
                    end
                end
            end

            -- Tooltip cache (Ascension)
            if (not info.bosses or #info.bosses == 0) and instID and L.lockoutBossCache and L.lockoutBossCache[instID] then
                info.bosses = L.lockoutBossCache[instID].bosses
            end
        else
            L.lockoutCache[i] = nil
        end
    end
    for i = numSaved + 1, #L.lockoutCache do
        L.lockoutCache[i] = nil
    end

    -- Opportunistic scrape if RaidInfo buttons exist (no need for user hover)
    if L.IsAscensionRealm and L.IsAscensionRealm() then
        for i = 1, numSaved do
            local info = L.lockoutCache[i]
            if info and info.id and (not info.bosses or #info.bosses == 0) then
                local bosses = L.ScrapeRaidInfoBosses(i)
                if bosses and #bosses > 0 then
                    info.bosses = bosses
                    L.lockoutBossCache[info.id] = { t = time(), name = info.name, bosses = bosses }
                end
            end
        end
    end
end

