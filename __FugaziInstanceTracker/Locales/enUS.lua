--[[
  FugaziInstanceTracker English (enUS) locale — functional + light UI strings.

  Note: FIT uses `L` as the addon namespace (not the locale table).
  Active strings live on L.Loc after Locales/Locale.lua runs.

  Chat/lockout phrases must be copied from a live client of the target language.
]]

local _, ns = ...
ns._localeTables = ns._localeTables or {}

local Loc = {}

----------------------------------------------------------------------
-- SYSTEM CHAT (CHAT_MSG_SYSTEM)
-- Used by: Cap.lua instance enter / hourly cap / reset detection
----------------------------------------------------------------------
-- Ascension: "You have entered a level 1 Manastorm!"
Loc.CHAT_MANASTORM_ENTERED = "entered a level"
Loc.CHAT_MANASTORM_NAME = "manastorm"
Loc.CHAT_TOO_MANY_INSTANCES = "too many instances"
Loc.CHAT_HAS_BEEN_RESET = "has been reset"

----------------------------------------------------------------------
-- DIFFICULTY NAME SCAN (GetSavedInstanceInfo difficultyName)
-- Used by: Cap.lua DiffLabel short labels
----------------------------------------------------------------------
Loc.DIFF_FIND_MYTHIC = "mythic"
Loc.DIFF_FIND_HEROIC = "heroic"
Loc.DIFF_FIND_NORMAL = "normal"
Loc.DIFF_LABEL_MYTHIC = "Mythic"
Loc.DIFF_LABEL_HEROIC = "Heroic"
Loc.DIFF_LABEL_NORMAL = "Normal"

----------------------------------------------------------------------
-- LOCKOUT TOOLTIP BOSS STATUS (right column text)
-- Used by: Lockouts.lua boss row scrape
-- "locked" = boss killed; "undefeated" = still up
----------------------------------------------------------------------
Loc.LOCKOUT_UNDEFEATED = "undefeated"
Loc.LOCKOUT_LOCKED = "locked"

----------------------------------------------------------------------
-- LIGHT UI / MESSAGES (sample pattern; more UI can move here later)
----------------------------------------------------------------------
Loc.MSG_MANASTORM_IGNORED = "Manastorm ignored — not saved to Ledger"
Loc.MSG_MANASTORM_DETECTED = "Manastorm detected — not tracked in Ledger"

ns._localeTables.enUS = Loc
ns._localeTables.enGB = ns._localeTables.enGB or Loc
