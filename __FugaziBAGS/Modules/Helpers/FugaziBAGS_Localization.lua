local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

--[[
  FugaziBAGS_Localization: Central string table.
  Moves toward an "A-Grade" architecture by removing hardcoded strings.
]]

local L = {
    -- Options
    CONFIRM_AUTO_DELETE = "Confirm Auto Delete",
    PLAY_SOUNDS = "Play sounds",
    COPY_FROM_CHAR = "Copy auto-destroy list from character:",
    AUTO_DELETE_LIST = "Auto-delete list (current character):",
    AUTOSELL_DELAY = "Autosell delay (estimated ping ms):",
    SCROLL_SPEED = "Scrollspeed (px per tick):",
    
    -- UI
    SEARCH_PLACEHOLDER = "Search...",
    NO_MATCHES = "(no matches)",
    EMPTY = "(empty)",
    
    -- Messages
    COPIED_ENTRIES = "Copied %d auto-destroy entries from %s to this character.",
}

-- Registry helper
function A.L(key)
    return L[key] or key
end

-- Export for local usage
A.Strings = L
