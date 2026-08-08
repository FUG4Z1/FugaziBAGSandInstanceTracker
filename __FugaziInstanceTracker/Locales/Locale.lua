--[[
  FIT locale loader.

  Load order (TOC): enUS.lua → Locale.lua → Config / modules.

  Active table: L.Loc  (L is the FIT addon namespace from `local _, L = ...`)
  Prefer L.Loc.KEY in FIT modules so it never clashes with L.frame, L.currentRun, etc.

  Shared bind/bank phrases stay on FugaziBAGS.L (RequiredDeps).
]]

local _, ns = ...
ns._localeTables = ns._localeTables or {}

local function shallowCopy(src)
    local t = {}
    if type(src) ~= "table" then return t end
    for k, v in pairs(src) do
        t[k] = v
    end
    return t
end

local function buildLocale()
    local tables = ns._localeTables
    local base = tables.enUS or {}
    local code = (GetLocale and GetLocale()) or "enUS"
    local over = tables[code]
    if code == "enGB" and over == base then
        over = nil
    end

    local Loc
    if over and over ~= base then
        Loc = shallowCopy(base)
        for k, v in pairs(over) do
            Loc[k] = v
        end
    else
        Loc = shallowCopy(base)
    end

    setmetatable(Loc, {
        __index = function(_, key)
            local v = base[key]
            if v ~= nil then return v end
            if type(key) == "string" then return key end
            return nil
        end,
    })

    ns.Loc = Loc
    ns.localeCode = code
    return Loc
end

buildLocale()

--- Plain substring match helper for FIT chat/tooltip scans.
function ns.LocTextMatches(text, phraseOrList, alreadyLower)
    if not text or text == "" then return false end
    local t = alreadyLower and text or string.lower(text)
    if type(phraseOrList) == "string" then
        return phraseOrList ~= "" and t:find(phraseOrList, 1, true) ~= nil
    end
    if type(phraseOrList) ~= "table" then return false end
    for i = 1, #phraseOrList do
        local p = phraseOrList[i]
        if type(p) == "string" and p ~= "" and t:find(p, 1, true) then
            return true
        end
    end
    return false
end
