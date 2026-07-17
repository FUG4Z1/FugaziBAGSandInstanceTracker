local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}
_G.FugaziBAGS = A

--[[
  FugaziBAGS_Config: The Central "Source of Truth" for all user settings.
  Moves toward an "A-Grade" architecture by decoupling UI from Data.
]]

local DEFAULTS = {
    -- General
    gphInvKeybind = true,
    gphAutoVendor = false,
    gphAutosellEverything = false,
    gphClickSound = true,
    gridConfirmAutoDel = true,
    gphAutosellPingMs = 200,
    gphScrollStep = 600,
    
    -- Rendering / Layout
    gphFrameScale = 1.0,
    gphFrameAlpha = 0.95,
    gphScale15 = false, -- Legacy toggle for 1.5 multiplier
    gphSortMode = "category", -- "rarity", "vendor", "itemlevel", "category"
    gphSkin = "elvui_real",
    
    -- Grid/List specific
    gphGridMode = true,
    gridCols = 11,
    gridSlotSize = 36,
    gridSpacing = 4,
    gridBorderSize = 3,
    gridGlowAlpha = 0.80,
    gridProtDesat = 0.35,
    gridProtectedKeyAlpha = 0.20,
    
    -- Sorting / Protection
    gphItemTypeCache = {},
    gphDestroyListPerChar = {}, -- Keyed by "Realm#Name"
    _manualUnprotected = {},

    -- Tweaks
    gphAutoQuestGossip = false,
    gphProtectPreviouslyWorn = true,
}

-- Registry for option change listeners
local listeners = {}

--- Centralized Getter for all settings.
-- @param key (string) The setting key.
-- @return The current value (or default).
function A.GetOption(key)
    local SV = _G.FugaziBAGSDB
    if not SV then return DEFAULTS[key] end
    
    local val = SV[key]
    if val == nil then return DEFAULTS[key] end
    return val
end

--- Centralized Setter for all settings.
-- @param key (string) The setting key.
-- @param value (any) The new value.
-- @param silent (boolean) If true, skips triggering listeners.
function A.SetOption(key, value, silent)
    local SV = _G.FugaziBAGSDB
    if not SV then return end
    
    local oldVal = SV[key]
    if oldVal == value then return end
    
    SV[key] = value
    
    if not silent and listeners[key] then
        for _, callback in ipairs(listeners[key]) do
            local ok, err = pcall(callback, value, oldVal)
            if not ok then
                print("|cffff3333[FugaziBAGS Config Error]|r on listener " .. tostring(key) .. ": " .. tostring(err))
            end
        end
    end
end

--- Register a callback for when a specific option changes.
-- @param key (string) The setting key.
-- @param callback (function) The function to call. Signature: (newValue, oldValue)
function A.OnOptionChanged(key, callback)
    if not key or not callback then return end
    listeners[key] = listeners[key] or {}
    table.insert(listeners[key], callback)
end

--- Character-specific key generator (consistent across modules).
function A.GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then return nil end
    return realm .. "#" .. name
end

--- Helper to get character-specific destroy list.
function A.GetGphDestroyList()
    local key = A.GetCharKey()
    if not key then return {} end
    
    local SV = _G.FugaziBAGSDB
    if not SV then return {} end
    
    SV.gphDestroyListPerChar = SV.gphDestroyListPerChar or {}
    SV.gphDestroyListPerChar[key] = SV.gphDestroyListPerChar[key] or {}
    return SV.gphDestroyListPerChar[key]
end

-- Export DEFAULTS for initialization logic if needed
A._ConfigDefaults = DEFAULTS
