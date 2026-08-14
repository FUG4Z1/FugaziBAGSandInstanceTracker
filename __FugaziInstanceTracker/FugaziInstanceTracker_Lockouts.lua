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

L.EXPANSION_ORDER = { "world", "classic", "tbc", "wotlk" }
L.EXPANSION_LABELS = {
    world   = "|cffff6600World Bosses|r",
    classic = "|cffffcc00Classic|r",
    tbc     = "|cff1eff00The Burning Crusade|r",
    wotlk   = "|cff0070ddWrath of the Lich King|r",
}

-- Exact names only (after stripping a trailing (PvE)/(PvP)). Do not substring-match the dungeon table.
L.WORLD_BOSSES = {
    ["Azuregos"] = true,
    ["Lord Kazzak"] = true,
    ["Doom Lord Kazzak"] = true,
    ["Doomwalker"] = true,
    ["Emeriss"] = true,
    ["Lethon"] = true,
    ["Taerar"] = true,
    ["Ysondre"] = true,
    ["Soggoth"] = true,
    ["Atal'zull"] = true,
    ["Atal'Zull"] = true,
    ["Highlord Kruul"] = true,
}

function L.StripInstanceFactionTag(name)
    if not name then return name end
    return (tostring(name):gsub("%s*%([Pp][Vv][EePp]%)%s*$", ""))
end

function L.GetExpansion(instanceName)
    if not instanceName then return nil end
    local stripped = L.StripInstanceFactionTag(instanceName)
    local direct = L.INSTANCE_EXPANSION[instanceName] or (stripped and L.INSTANCE_EXPANSION[stripped])
    if direct then return direct end
    if L.WORLD_BOSSES[instanceName] or (stripped and L.WORLD_BOSSES[stripped]) then
        return "world"
    end
    if stripped and stripped ~= instanceName then
        return "world"
    end
    return nil
end

----------------------------------------------------------------------
-- Lockout cache = GetSavedInstanceInfo (ID still saved) union Raid Info
-- button rows (boss loot lockouts after an ID reset).
-- Bosses: that row's .lockout, else GetLootLockouts(mapID) filtered by MapID.
-- Never GetLootLockouts("player"), never fake OnEnter, never scrape tooltips.
----------------------------------------------------------------------

local function StripColors(s)
    if not s then return "" end
    return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t.-|t", ""))
end

local function NameKey(name)
    if not name then return nil end
    return L.StripInstanceFactionTag(name) or name
end

-- Normal and Heroic of the same boss are two lockouts (two IDs). Never key by name only.
local function DiffKey(difficultyName, diff)
    local s = difficultyName and string.lower(tostring(difficultyName)) or ""
    if s:find("mythic", 1, true) then return "mythic" end
    if s:find("heroic", 1, true) then return "heroic" end
    if s:find("normal", 1, true) then return "normal" end
    if s ~= "" then return s end
    if diff ~= nil then return "d" .. tostring(diff) end
    return ""
end

local function RowKey(name, difficultyName, diff)
    local n = NameKey(name)
    if not n then return nil end
    return n .. "|" .. DiffKey(difficultyName, diff)
end

local function DiffIdHint(difficultyName)
    local k = DiffKey(difficultyName, nil)
    if k == "heroic" then return 2 end
    if k == "mythic" then return 3 end
    if k == "normal" then return 1 end
    return nil
end

local function FormatLockSeconds(sec)
    sec = tonumber(sec)
    if not sec or sec <= 0 then return nil end
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    if d > 0 then
        return d .. (d == 1 and " day " or " days ") .. h .. " hr"
    end
    if h > 0 then return h .. " hr" end
    local m = math.floor((sec % 3600) / 60)
    if m > 0 then return m .. " min" end
    return nil
end

local function EncounterName(id)
    if type(_G.GetEncounterInfo) ~= "function" or not id then return nil end
    local ok, a = pcall(_G.GetEncounterInfo, id)
    if ok and type(a) == "string" and a ~= "" then return a end
    return nil
end

local function IsEncounterRecord(v)
    return type(v) == "table" and (v.TimeRemaining ~= nil or v.OrderIndex ~= nil or v.SpellIconID ~= nil)
end

local function HarvestRecords(src, dest, depth)
    if type(src) ~= "table" or depth > 4 then return end
    if IsEncounterRecord(src) then return end
    for k, v in pairs(src) do
        if IsEncounterRecord(v) and type(k) == "number" then
            dest[k] = v
        elseif type(v) == "table" then
            HarvestRecords(v, dest, depth + 1)
        end
    end
end

-- Only records for this map (and difficulty when tagged). Drop mixed MapIDs with no match.
local function RecordsForMap(src, mapID, diffID)
    if type(src) ~= "table" then return nil end
    local raw = {}
    HarvestRecords(src, raw, 0)
    local out = {}
    local sawMap = false
    diffID = tonumber(diffID)
    for id, rec in pairs(raw) do
        local recMap = rec.MapID and tonumber(rec.MapID)
        if recMap then sawMap = true end
        local recDiff = rec.DifficultyID and tonumber(rec.DifficultyID)
        if diffID and recDiff and recDiff ~= diffID then
            -- other difficulty of the same map
        elseif mapID then
            if recMap == tonumber(mapID) then
                out[id] = rec
            end
        else
            out[id] = rec
        end
    end
    if mapID and sawMap then return out end
    if mapID and not sawMap then return nil end
    return out
end

local function BossesFromRecords(recs)
    if type(recs) ~= "table" then return nil end
    local bosses = {}
    for id, rec in pairs(recs) do
        local name = EncounterName(id)
        local remain = rec and tonumber(rec.TimeRemaining)
        if name and name ~= "" then
            bosses[#bosses + 1] = {
                name = name,
                killed = remain and remain > 0 or false,
                status = (remain and remain > 0) and "Locked" or "Undefeated",
                timeText = FormatLockSeconds(remain),
                order = rec and tonumber(rec.OrderIndex) or id,
            }
        end
    end
    if #bosses == 0 then return nil end
    table.sort(bosses, function(a, b)
        local oa, ob = a.order or 0, b.order or 0
        if oa ~= ob then return oa < ob end
        return (a.name or "") < (b.name or "")
    end)
    return bosses
end

-- This row only: its button.lockout, then GetLootLockouts(mapID) filtered by MapID.
-- Never GetLootLockouts("player") — that painted every boss under every parent.
local function BossesForRow(mapID, lockoutField, difficultyName)
    local diffID = DiffIdHint(difficultyName)
    local recs = RecordsForMap(lockoutField, mapID, diffID)
    if (not recs or not next(recs)) and mapID and type(_G.GetLootLockouts) == "function" then
        local ok, t = pcall(_G.GetLootLockouts, mapID)
        if ok then recs = RecordsForMap(t, mapID, diffID) end
        if (not recs or not next(recs)) then
            ok, t = pcall(_G.GetLootLockouts, mapID, diffID or 2)
            if ok then recs = RecordsForMap(t, mapID, diffID) end
        end
    end
    return BossesFromRecords(recs)
end

local RAIDINFO_CHROME = {
    ["extended"] = true,
    ["extend raid lock"] = true,
    ["unextend raid lock"] = true,
    ["close"] = true,
    ["instance"] = true,
    ["lock expire"] = true,
    ["raid information"] = true,
}

local function IsRaidInfoChrome(s)
    if not s or s == "" then return true end
    return RAIDINFO_CHROME[string.lower(s)] == true
end

local function FontStringText(fs)
    if not fs or not fs.GetText then return nil end
    local t = StripColors(fs:GetText())
    if t == "" then return nil end
    return t
end

-- Same widget only: name/difficulty/mapID/lockout on that button. Never button:GetID().
local function ReadButtonRow(btn)
    if not btn then return nil end
    local name = FontStringText(btn.name)
    if not name or IsRaidInfoChrome(name) then return nil end
    local mapID = tonumber(btn.mapID)
    if mapID and mapID <= 0 then mapID = nil end
    return {
        name = name,
        difficultyName = FontStringText(btn.difficulty),
        mapID = mapID,
        lockout = btn.lockout,
    }
end

local function CollectRaidInfoRows()
    local rows, seen = {}, {}
    for i = 1, 20 do
        local btn = _G["RaidInfoScrollFrameButton" .. i]
        if not btn then break end
        local row = ReadButtonRow(btn)
        if row then
            local key = RowKey(row.name, row.difficultyName)
            if seen[key] then
                local existing = rows[seen[key]]
                if row.difficultyName and (not existing.difficultyName or existing.difficultyName == "") then
                    existing.difficultyName = row.difficultyName
                end
                if row.mapID and not existing.mapID then existing.mapID = row.mapID end
                if row.lockout and not existing.lockout then existing.lockout = row.lockout end
            else
                seen[key] = #rows + 1
                rows[#rows + 1] = row
            end
        end
    end
    return rows
end

local _raidInfoMergePending = false
local function ScheduleRaidInfoMerge()
    if _raidInfoMergePending then return end
    if not (L.frame and L.frame:IsShown()) then return end
    _raidInfoMergePending = true
    if not L._raidInfoMergeFrame then
        L._raidInfoMergeFrame = CreateFrame("Frame")
    end
    L._raidInfoMergeFrame:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        _raidInfoMergePending = false
        if L.UpdateLockoutCache then L.UpdateLockoutCache() end
        if L.frame and L.frame:IsShown() and L.RefreshUI then
            L.RefreshUI(true)
        end
    end)
end

local function HookRaidInfoWidgets()
    local sf = _G.RaidInfoScrollFrame
    if sf and not sf._fitScrollHooked and sf.HookScript then
        sf._fitScrollHooked = true
        sf:HookScript("OnVerticalScroll", function()
            ScheduleRaidInfoMerge()
        end)
    end
    if not L._raidInfoUpdateHooked and type(hooksecurefunc) == "function" and type(RaidInfoFrame_Update) == "function" then
        L._raidInfoUpdateHooked = true
        hooksecurefunc("RaidInfoFrame_Update", function()
            ScheduleRaidInfoMerge()
        end)
    end
    local rf = _G.RaidInfoFrame
    if rf and not rf._fitShowHooked and rf.HookScript then
        rf._fitShowHooked = true
        rf:HookScript("OnShow", function()
            ScheduleRaidInfoMerge()
        end)
    end
end

function L.UpdateLockoutCache()
    L.lockoutQueryTime = time()
    HookRaidInfoWidgets()

    local byKey, list = {}, {}
    local function upsert(entry)
        if not entry or not entry.name then return end
        local key = RowKey(entry.name, entry.difficultyName, entry.diff)
        local existing = byKey[key]
        if existing then
            if entry.id and not existing.id then existing.id = entry.id end
            if entry.locked then existing.locked = true end
            if entry.diff and not existing.diff then existing.diff = entry.diff end
            if entry.difficultyName and (not existing.difficultyName or existing.difficultyName == "") then
                existing.difficultyName = entry.difficultyName
            end
            if entry.isRaid ~= nil and existing.isRaid == nil then existing.isRaid = entry.isRaid end
            if entry.resetAtQuery and not existing.resetAtQuery then
                existing.resetAtQuery = entry.resetAtQuery
            end
            if entry.mapID and not existing.mapID then existing.mapID = entry.mapID end
            if entry.bosses and (not existing.bosses or #existing.bosses == 0) then
                existing.bosses = entry.bosses
            end
            return
        end
        byKey[key] = entry
        list[#list + 1] = entry
    end

    local numSaved = GetNumSavedInstances and GetNumSavedInstances() or 0
    for i = 1, numSaved do
        local instName, instID, instReset, instDiff, locked, extended, _, isRaid, maxPlayers, difficultyName =
            GetSavedInstanceInfo(i)
        if instName then
            local bosses
            if type(GetSavedInstanceEncounterInfo) == "function" then
                local nEnc = select(11, GetSavedInstanceInfo(i))
                if type(nEnc) == "number" and nEnc > 0 then
                    bosses = {}
                    for j = 1, nEnc do
                        local bName, _, isKilled = GetSavedInstanceEncounterInfo(i, j)
                        if bName then
                            table.insert(bosses, {
                                name = bName,
                                killed = isKilled and true or false,
                                status = isKilled and "Locked" or "Undefeated",
                            })
                        end
                    end
                end
            end
            upsert({
                name = instName,
                id = instID,
                resetAtQuery = instReset,
                diff = instDiff,
                locked = locked and true or false,
                extended = extended,
                isRaid = isRaid,
                maxPlayers = maxPlayers,
                difficultyName = difficultyName,
                index = i,
                bosses = bosses,
            })
        end
    end

    -- After an ID reset GetSavedInstanceInfo is empty; Raid Info still lists boss lockouts.
    -- Read row names only (never button index, never fake OnEnter).
    local ri = CollectRaidInfoRows()
    if #ri > 0 then
        L._raidInfoNames = ri
    else
        local frame = _G.RaidInfoFrame
        if frame and frame.IsShown and frame:IsShown() then
            L._raidInfoNames = {}
        end
    end
    for _, row in ipairs(L._raidInfoNames or {}) do
        upsert({
            name = row.name,
            difficultyName = row.difficultyName,
            mapID = row.mapID,
            locked = false,
            bosses = BossesForRow(row.mapID, row.lockout, row.difficultyName),
        })
    end

    L.lockoutCache = list
end

HookRaidInfoWidgets()

