local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

--[[
  FugaziBAGS_Formatting: Extracted from Utils.lua.
  Handles all currency displays and time-related strings.
]]

function A.GPH_FormatMoney(amount, hideNull)
    if not amount or amount == 0 then
        return hideNull and "" or "|cffffffff0|r|cffffd700g|r"
    end
    
    local gold = math.floor(math.abs(amount) / 10000)
    local silver = math.floor((math.abs(amount) % 10000) / 100)
    local copper = math.abs(amount) % 100
    
    local str = ""
    if gold > 0 then
        str = str .. "|cffffffff" .. gold .. "|r|cffffd700g|r"
    end
    if silver > 0 or gold > 0 then
        str = str .. " |cffffffff" .. silver .. "|r|cffc7c7c7s|r"
    end
    if copper > 0 or (gold == 0 and silver == 0) then
        str = str .. " |cffffffff" .. copper .. "|r|cffeda55fc|r"
    end
    
    if amount < 0 then
        return "|cffff3333-|r" .. str
    end
    return str
end

function A.GPH_GetSessionTime()
    local startTime = A.SessionStartTime or GetTime()
    local elapsed = GetTime() - startTime
    
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = math.floor(elapsed % 60)
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    else
        return string.format("%dm %ds", minutes, seconds)
    end
end
