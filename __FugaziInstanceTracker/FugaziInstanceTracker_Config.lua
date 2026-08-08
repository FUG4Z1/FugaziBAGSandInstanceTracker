local addonName, L = ...

L.ADDON_NAME = "InstanceTracker"
-- How many instance IDs you can "save" per real-world hour (soft cap; like dungeon finder).
L.MAX_INSTANCES_PER_HOUR = 5
L.HOUR_SECONDS = 3600
-- Max Ledger entries we keep (oldest dropped when full; like a fixed-size logbook).
L.MAX_RUN_HISTORY = 999
-- If you die and re-enter the same instance within this time, we restore the same run instead of starting a new one.
L.MAX_RESTORE_AGE_SECONDS = 5 * 60  -- 5 minutes
-- Width in pixels for scrollable list content (Ledger, item list, etc.); no gap left of scrollbar.
L.SCROLL_CONTENT_WIDTH = 296
-- Max visible chars for stat lines so text doesn't run under the scrollbar; truncate with "..." + tooltip
L.LEDGER_STAT_MAX_CHARS = 38
-- Flush left padding for content (avoids "syntax" indentation); used in Ledger, Run details, main window
L.CONTENT_LEFT_PAD = 4

--- Strip WoW color codes from a string. Prefer BAGS helper when present.
function L.StripColorCodes(str)
    if str == nil then return "" end
    if type(str) ~= "string" then str = tostring(str) end
    if _G.FugaziBAGS and type(_G.FugaziBAGS.StripColorCodes) == "function" then
        local ok, out = pcall(_G.FugaziBAGS.StripColorCodes, str)
        if ok and type(out) == "string" then return out end
    end
    -- Local fallback (3.3.5a): |cAARRGGBB … |r and || escapes
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    str = str:gsub("|r", "")
    str = str:gsub("|T.-|t", "")
    str = str:gsub("|H.-|h(.-)|h", "%1")
    str = str:gsub("||", "|")
    return str
end

----------------------------------------------------------------------
-- UI feedback sounds (reuse __FugaziBAGS media + toggles when present)
-- Separate short throttles per kind so hover never blocks the next click.
----------------------------------------------------------------------
local IT_SOUND_CLICK = "Interface\\AddOns\\__FugaziBAGS\\media\\click.ogg"
local IT_SOUND_HOVER = "Interface\\AddOns\\__FugaziBAGS\\media\\hover.ogg"
local IT_SOUND_SWOOSH = "Interface\\AddOns\\__FugaziBAGS\\media\\Swoosh2.ogg"
local IT_CLICK_GAP = 0.04
local IT_HOVER_GAP = 0.05

local function IT_SoundsEnabled()
    local SV = _G.FugaziBAGSDB
    if SV and SV.gphClickSound == false then return false end
    return true
end

--- Click feedback (rows, buttons, Prev/Next).
function L.PlayUIClickSound()
    if not IT_SoundsEnabled() or not PlaySoundFile then return end
    local FB = _G.FugaziBAGS
    if FB and FB.PlayClickSound then
        FB.PlayClickSound()
        return
    end
    local now = (GetTime and GetTime()) or 0
    if (L._uiClickSoundLast or 0) > 0 and (now - L._uiClickSoundLast) < IT_CLICK_GAP then return end
    L._uiClickSoundLast = now
    PlaySoundFile(IT_SOUND_CLICK)
end

--- Hover feedback (row enter). Does not share throttle with click.
function L.PlayUIHoverSound()
    if not IT_SoundsEnabled() or not PlaySoundFile then return end
    local FB = _G.FugaziBAGS
    if FB and FB.PlayHoverSound then
        FB.PlayHoverSound()
        return
    end
    local now = (GetTime and GetTime()) or 0
    if (L._uiHoverSoundLast or 0) > 0 and (now - L._uiHoverSoundLast) < IT_HOVER_GAP then return end
    L._uiHoverSoundLast = now
    PlaySoundFile(IT_SOUND_HOVER)
end

--- Confirm-delete / removal swoosh (Swoosh2.ogg).
function L.PlayUISwooshSound()
    if not IT_SoundsEnabled() then return end
    local FB = _G.FugaziBAGS
    if FB and FB.PlaySwooshSound then
        FB.PlaySwooshSound()
        return
    end
    if PlaySoundFile then PlaySoundFile(IT_SOUND_SWOOSH, "Master") end
end

--- Wire a BAGS-style full-row clickArea: onClick(row, button), optional onEnter/onLeave(row).
function L.BindRowClickArea(row, onClick, onEnter, onLeave)
    if not row or not row.clickArea then return end
    local ca = row.clickArea
    ca:ClearAllPoints()
    ca:SetAllPoints(row)
    ca:SetFrameLevel((row:GetFrameLevel() or 1) + 5)
    ca:Show()
    ca:EnableMouse(true)
    ca:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ca:SetScript("OnClick", function(self, button)
        local r = self:GetParent()
        if r and onClick then onClick(r, button) end
    end)
    ca:SetScript("OnEnter", function(self)
        local r = self:GetParent()
        if L.PlayUIHoverSound then L.PlayUIHoverSound() end
        if r and onEnter then onEnter(r) end
    end)
    ca:SetScript("OnLeave", function(self)
        local r = self:GetParent()
        if r and onLeave then onLeave(r) else GameTooltip:Hide() end
    end)
end

--- Truncate a WoW-colored string to maxVisibleChars visible characters, preserving color codes so gold amounts stay formatted.
function L.TruncateWithColors(str, maxVisibleChars)
    if not str or str == "" or maxVisibleChars <= 0 then return str or "" end
    local result, i, visible, len = "", 1, 0, #str
    while i <= len do
        if str:sub(i, i + 9):match("^|c%x%x%x%x%x%x%x%x") then
            result = result .. str:sub(i, i + 9)
            i = i + 10
        elseif str:sub(i, i + 1) == "|r" then
            result = result .. "|r"
            i = i + 2
        else
            visible = visible + 1
            if visible > maxVisibleChars - 3 then
                return result .. "..."
            end
            result = result .. str:sub(i, i)
            i = i + 1
        end
    end
    return result
end

----------------------------------------------------------------------
-- Left/right row layout: right = gold/status (full), left truncates with "..."
-- before overlapping. Char budget from font size (scale-aware, no GetStringWidth
-- binary search — that was wrong on 3.3.5a and over-truncated to 1 letter).
----------------------------------------------------------------------
L.ROW_TEXT_GAP = 8

--- Max visible chars for left side given row width, font size, and right-side text.
function L.LeftMaxChars(row, rightText, leftPad, fontSize)
    local rowW = (row and row:GetWidth()) or L.SCROLL_CONTENT_WIDTH or 296
    if rowW < 50 then rowW = L.SCROLL_CONTENT_WIDTH or 296 end
    leftPad = leftPad or 4
    fontSize = fontSize or 12
    local rightPlain = L.StripColorCodes(rightText or "") or ""
    -- Reserve space for right text (~0.55*size per char) + gap + pad
    local rightReserve = 0
    if rightPlain ~= "" then
        rightReserve = math.min(150, math.max(36, math.ceil(#rightPlain * fontSize * 0.55) + 10))
    end
    local budgetPx = rowW - leftPad - 4 - rightReserve - (L.ROW_TEXT_GAP or 8)
    local maxChars = math.floor(budgetPx / math.max(5, fontSize * 0.52))
    if maxChars < 8 then maxChars = 8 end
    if maxChars > 80 then maxChars = 80 end
    return maxChars
end

--- Anchor left/right, set texts, truncate left only if needed. Returns truncated.
--- opts: leftPad, rightPad, vPoint ("TOP"|"BOTTOM"), vOffset, storeKey
function L.LayoutLeftRightTexts(row, leftFS, rightFS, fullLeft, fullRight, opts)
    if not row or not leftFS or not rightFS then return false end
    opts = opts or {}
    local leftPad = opts.leftPad
    if leftPad == nil then leftPad = 4 end
    local rightPad = opts.rightPad or 4
    local vPoint, vOff = opts.vPoint, opts.vOffset
    if vOff == nil then
        vOff = (vPoint == "TOP" and -2) or (vPoint == "BOTTOM" and 2) or 0
    end
    fullLeft, fullRight = fullLeft or "", fullRight or ""

    rightFS:ClearAllPoints()
    leftFS:ClearAllPoints()
    rightFS:SetJustifyH("RIGHT")
    leftFS:SetJustifyH("LEFT")
    if leftFS.SetWordWrap then leftFS:SetWordWrap(false) end
    if rightFS.SetWordWrap then rightFS:SetWordWrap(false) end

    rightFS:SetText(fullRight)
    if vPoint == "TOP" then
        rightFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -rightPad, vOff)
        leftFS:SetPoint("TOPLEFT", row, "TOPLEFT", leftPad, vOff)
        leftFS:SetPoint("TOPRIGHT", rightFS, "TOPLEFT", -(L.ROW_TEXT_GAP or 8), 0)
    elseif vPoint == "BOTTOM" then
        rightFS:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -rightPad, vOff)
        leftFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", leftPad, vOff)
        leftFS:SetPoint("BOTTOMRIGHT", rightFS, "BOTTOMLEFT", -(L.ROW_TEXT_GAP or 8), 0)
    else
        rightFS:SetPoint("RIGHT", row, "RIGHT", -rightPad, 0)
        leftFS:SetPoint("LEFT", row, "LEFT", leftPad, 0)
        leftFS:SetPoint("RIGHT", rightFS, "LEFT", -(L.ROW_TEXT_GAP or 8), 0)
    end

    local _, fontSize = leftFS:GetFont()
    fontSize = fontSize or 12
    local maxChars = L.LeftMaxChars(row, fullRight, leftPad, fontSize)
    local plain = L.StripColorCodes(fullLeft) or fullLeft
    local truncated = #plain > maxChars
    if truncated then
        leftFS:SetText(L.TruncateWithColors(fullLeft, maxChars))
    else
        leftFS:SetText(fullLeft)
    end
    if opts.storeKey then
        row[opts.storeKey] = truncated and plain or nil
    end
    return truncated
end

--- One- or two-line Cap/Ledger pool row.
function L.LayoutStatsRowTexts(row, leftText, rightText, subLeftText, subRightText)
    if not row or not row.left or not row.right then return false end
    local leftPad = (row.deleteBtn and row.deleteBtn:IsShown()) and 16 or 4
    row._fullLeftText, row._fullRightText = leftText or "", rightText or ""
    row._fullSubLeftText, row._fullSubRightText = subLeftText or "", subRightText or ""
    local trunc = false
    if row.subLeft and row.subLeft:IsShown() then
        if L.LayoutLeftRightTexts(row, row.left, row.right, leftText or "", rightText or "", {
            leftPad = leftPad, vPoint = "TOP", storeKey = "_fullLeftPlain"
        }) then trunc = true end
        if L.LayoutLeftRightTexts(row, row.subLeft, row.subRight, subLeftText or "", subRightText or "", {
            leftPad = leftPad, vPoint = "BOTTOM", storeKey = "_fullSubLeftPlain"
        }) then trunc = true end
    else
        if L.LayoutLeftRightTexts(row, row.left, row.right, leftText or "", rightText or "", {
            leftPad = leftPad, storeKey = "_fullLeftPlain"
        }) then trunc = true end
    end
    return trunc
end

function L.LayoutMainRowTexts(row, leftText, rightText, leftPad)
    if not row or not row.left or not row.right then return false end
    if leftPad == nil then leftPad = (row.deleteBtn and row.deleteBtn:IsShown()) and 16 or 0 end
    row._fullLeftText, row._fullRightText = leftText or "", rightText or ""
    return L.LayoutLeftRightTexts(row, row.left, row.right, leftText or "", rightText or "", {
        leftPad = leftPad, storeKey = "_fullLeftPlain"
    })
end
----------------------------------------------------------------------
-- Skins: no FIT-owned skin system. With __FugaziBAGS we use its skin (gphSkin etc).
-- Standalone: default look only.
----------------------------------------------------------------------

--- Applies skin to a L.frame: BAGS skin when __FugaziBAGS is loaded, else default.
function L.ApplyInstanceTrackerSkin(f)
    if not f then return end

    -- 1. Try FugaziBAGS skinning system first (Primary Source)
    local BSkins = _G.__FugaziBAGS_Skins
    if BSkins and BSkins.ApplyGPHFrameSkin then
        -- Map our specific IT elements to GPH names so BSkins can find them
        if f.itTitleBar and not f.gphTitleBar then f.gphTitleBar = f.itTitleBar end
        if f.itSep and not f.sep then f.sep = f.itSep end
        if f.itHourlyText and not f.statusText then f.statusText = f.itHourlyText end
        
        -- Store our title so it doesn't get replaced by player name
        local savedTitle = f.itTitleText and f.itTitleText:GetText()

        -- Apply the BAGS skin (handles all backdrops, colors, and overrides)
        BSkins.ApplyGPHFrameSkin(f)

        -- Restore title and ensure our specific buttons are skinned
        if savedTitle and f.itTitleText then f.itTitleText:SetText(savedTitle) end
        
        -- Standardize button backgrounds to match BAGS buttons
        local skinName = "original"
        local SV0 = _G.FugaziBAGSDB
        if SV0 and SV0.gphSkin then
            local val = SV0.gphSkin
            if val == "elvui_real" or val == "elvui" or val == "pimp_purple" or val == "fugazi" then skinName = val end
        end
        local btnColor = (BSkins.SKIN and BSkins.SKIN[skinName] and BSkins.SKIN[skinName].btnNormal) or { 0.1, 0.3, 0.15, 0.7 }
        local setBtn = function(btn) 
            if btn and btn.bg then 
                btn.bg:SetTexture(unpack(btnColor)) 
                if BSkins.AddBorder then BSkins.AddBorder(btn, btnColor) end
            end 
        end
        setBtn(f.statsBtn); setBtn(f.resetBtn); setBtn(f.gphBtn); setBtn(f.clearBtn)
        
        -- Skin scrollbars if they exist
        if f.scrollFrame and BSkins.SkinScrollBar then
            BSkins.SkinScrollBar(f.scrollFrame)
        end

    else
        -- Standalone: default look only (no skin choices)
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true, tileSize = 32, edgeSize = 24,
            insets   = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        f:SetBackdropColor(0.08, 0.08, 0.12, 0.92)
        f:SetBackdropBorderColor(0.6, 0.5, 0.2, 0.8)
    end

    -- 4. Font/color matching: same BAGS source as inventory (GetFugaziFontSettings).
    -- Prefer skin-applied accent when present so title tracks headerTextColor live.
    local fs = L.GetFugaziFontSettings and L.GetFugaziFontSettings() or nil
    if f.itTitleText and fs then
        f.itTitleText:SetFont(fs.fontPath or "Fonts\\FRIZQT__.TTF", fs.titleSize or 12, "")
        local c = f.gphAccentTextColor or fs.accentColor
        if c and type(c) == "table" and #c >= 3 then
            f.itTitleText:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        end
    elseif f.itTitleText and f.gphAccentTextColor then
        local c = f.gphAccentTextColor
        f.itTitleText:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end

    -- 5. Frame opacity (match FugaziBAGS "Frame Opacity" slider: whole window uses gphFrameAlpha)
    -- Frame opacity is handled by the skinning system (ApplyToComponent) via setBackdropColor
    -- Setting f:SetAlpha(fa) would dim everything (text, icons), which is WRONG.
    f:SetAlpha(1)
end



----------------------------------------------------------------------
-- SavedVariables: persisted across /reload and logout (like keybinds).
-- InstanceTrackerDB holds all user settings and run history.
----------------------------------------------------------------------
InstanceTrackerDB = InstanceTrackerDB or {}
-- valuationMode / fitMute removed (Tier A/B).
-- BAGS-owned keys (do NOT init on InstanceTrackerDB):
--   gphInvKeybind, gphAutoVendor, gphScale15, gphDestroyList*, gphProtected*, gphPreviouslyWorn*,
--   gphItemTypeCache, gphDockedToMain, skin/options — live in FugaziBAGSDB via __FugaziBAGS.
-- [ADVANCED STATS] Lifetime across all characters/sessions. NEVER reset or replace this table (only add missing keys).
if InstanceTrackerDB.lifetimeStats == nil then
    InstanceTrackerDB.lifetimeStats = {
        totalGoldCopper = 0,
        totalRuns = 0,
        rarityBreakdown = {},
        bestGPH = 0,
        zoneEfficiency = {},
        vendorCopper = 0,
        vendorItemCount = 0,
        repairCopper = 0,
        repairCount = 0,
        instanceDeaths = 0,
        deletedItemCount = 0,
    }
end
L.LS = InstanceTrackerDB.lifetimeStats

function L.EnsureAutoStatTables()
    local realm = (GetRealmName and GetRealmName()) or "Default"
    if realm == "" then realm = "Default" end

    InstanceTrackerDB.autoDeleteStatsByRealm = InstanceTrackerDB.autoDeleteStatsByRealm or {}
    InstanceTrackerDB.autoVendorStatsByRealm = InstanceTrackerDB.autoVendorStatsByRealm or {}

    -- Migrate legacy flat tables if they exist and haven't been migrated yet
    if InstanceTrackerDB.autoDeleteStats then
        local oldRealm = nil
        for key in pairs(InstanceTrackerDB.accountGold or {}) do
            local r = key:match("^(.-)#")
            if r and r ~= realm then
                oldRealm = r
                break
            end
        end
        if not oldRealm then oldRealm = realm end

        if not InstanceTrackerDB.autoDeleteStatsByRealm[oldRealm] then
            InstanceTrackerDB.autoDeleteStatsByRealm[oldRealm] = InstanceTrackerDB.autoDeleteStats
        end
        InstanceTrackerDB.autoDeleteStats = nil
    end

    if InstanceTrackerDB.autoVendorStats then
        local oldRealm = nil
        for key in pairs(InstanceTrackerDB.accountGold or {}) do
            local r = key:match("^(.-)#")
            if r and r ~= realm then
                oldRealm = r
                break
            end
        end
        if not oldRealm then oldRealm = realm end

        if not InstanceTrackerDB.autoVendorStatsByRealm[oldRealm] then
            InstanceTrackerDB.autoVendorStatsByRealm[oldRealm] = InstanceTrackerDB.autoVendorStats
        end
        InstanceTrackerDB.autoVendorStats = nil
    end

    if not InstanceTrackerDB.autoDeleteStatsByRealm[realm] then
        InstanceTrackerDB.autoDeleteStatsByRealm[realm] = { items = {}, totalCount = 0, totalVendorCopper = 0 }
    end
    if not InstanceTrackerDB.autoVendorStatsByRealm[realm] then
        InstanceTrackerDB.autoVendorStatsByRealm[realm] = { items = {}, totalCount = 0, totalVendorCopper = 0 }
    end

    L.autoDeleteStats = InstanceTrackerDB.autoDeleteStatsByRealm[realm]
    L.autoVendorStats = InstanceTrackerDB.autoVendorStatsByRealm[realm]
end

function L.InitializeLifetimeStats()
    local realm = (GetRealmName and GetRealmName()) or "Default"
    if realm == "" then realm = "Default" end

    InstanceTrackerDB.lifetimeStatsByRealm = InstanceTrackerDB.lifetimeStatsByRealm or {}

    -- Migrate old lifetimeStats if they exist and we haven't migrated them yet
    if InstanceTrackerDB.lifetimeStats then
        local oldRealm = nil
        for key in pairs(InstanceTrackerDB.accountGold or {}) do
            local r = key:match("^(.-)#")
            if r and r ~= realm then
                oldRealm = r
                break
            end
        end
        if not oldRealm then
            oldRealm = realm
        end

        if not InstanceTrackerDB.lifetimeStatsByRealm[oldRealm] then
            InstanceTrackerDB.lifetimeStatsByRealm[oldRealm] = InstanceTrackerDB.lifetimeStats
        end
        InstanceTrackerDB.lifetimeStats = nil
    end

    -- Ensure current realm exists
    if not InstanceTrackerDB.lifetimeStatsByRealm[realm] then
        InstanceTrackerDB.lifetimeStatsByRealm[realm] = {
            totalGoldCopper = 0,
            totalRuns = 0,
            rarityBreakdown = {},
            bestGPH = 0,
            zoneEfficiency = {},
            vendorCopper = 0,
            vendorItemCount = 0,
            repairCopper = 0,
            repairCount = 0,
            instanceDeaths = 0,
            deletedItemCount = 0,
        }
    end

    -- Ensure all keys are filled
    local LS = InstanceTrackerDB.lifetimeStatsByRealm[realm]
    if LS.vendorCopper == nil then LS.vendorCopper = 0 end
    if LS.vendorItemCount == nil then LS.vendorItemCount = 0 end
    if LS.repairCopper == nil then LS.repairCopper = 0 end
    if LS.repairCount == nil then LS.repairCount = 0 end
    if LS.instanceDeaths == nil then LS.instanceDeaths = 0 end
    if LS.deletedItemCount == nil then LS.deletedItemCount = 0 end
    if LS.totalGoldCopper == nil then LS.totalGoldCopper = 0 end
    if LS.totalRuns == nil then LS.totalRuns = 0 end
    if LS.bestGPH == nil then LS.bestGPH = 0 end
    if LS.rarityBreakdown == nil then LS.rarityBreakdown = {} end
    if LS.zoneEfficiency == nil then LS.zoneEfficiency = {} end

    L.LS = LS
end

function L.MigrateOldRuns()
    local currentRealm = (GetRealmName and GetRealmName()) or ""
    local history = InstanceTrackerDB.runHistory or {}

    local function getRealmsForChar(charName)
        if not charName or charName == "" then return {} end
        local realms = {}
        local suffix = "#" .. charName
        for key in pairs(InstanceTrackerDB.accountGold or {}) do
            if key:sub(-#suffix) == suffix then
                realms[key:sub(1, #key - #suffix)] = true
            end
        end
        for key in pairs(InstanceTrackerDB.lifetimeGoldGained or {}) do
            if key:sub(-#suffix) == suffix then
                realms[key:sub(1, #key - #suffix)] = true
            end
        end
        local list = {}
        for r in pairs(realms) do
            table.insert(list, r)
        end
        return list
    end

    -- 1st pass: migrate runs with characterName
    for _, run in ipairs(history) do
        if not run.realmName and run.characterName then
            local realms = getRealmsForChar(run.characterName)
            if #realms == 1 then
                run.realmName = realms[1]
            elseif #realms > 1 then
                local assigned = nil
                for _, r in ipairs(realms) do
                    if r ~= currentRealm then
                        assigned = r
                        break
                    end
                end
                run.realmName = assigned or realms[1]
            end
        end
    end

    -- 2nd pass: migrate runs with no characterName (old GPH runs) using adjacency
    for i, run in ipairs(history) do
        if not run.realmName then
            local adjacentRealm = nil
            for j = i - 1, 1, -1 do
                if history[j] and history[j].realmName then
                    adjacentRealm = history[j].realmName
                    break
                end
            end
            if not adjacentRealm then
                for j = i + 1, #history do
                    if history[j] and history[j].realmName then
                        adjacentRealm = history[j].realmName
                        break
                    end
                end
            end
            if adjacentRealm then
                run.realmName = adjacentRealm
            else
                local fallback = nil
                for key in pairs(InstanceTrackerDB.accountGold or {}) do
                    local r = key:match("^(.-)#")
                    if r and r ~= currentRealm then
                        fallback = r
                        break
                    end
                end
                run.realmName = fallback or currentRealm
            end
        end
    end
end

-- Account-wide gold snapshot: [realm#char] = copper (updated on PLAYER_MONEY / login)
InstanceTrackerDB.accountGold = InstanceTrackerDB.accountGold or {}
-- Total gold ever gained (any source) per character; Lifetime tab shows sum, mouseover per char
InstanceTrackerDB.lifetimeGoldGained = InstanceTrackerDB.lifetimeGoldGained or {}
InstanceTrackerDB.lastKnownMoney = InstanceTrackerDB.lastKnownMoney or {}
-- All deaths ever (not just in instance) per character; Lifetime tab shows sum, mouseover per char
InstanceTrackerDB.lifetimeDeaths = InstanceTrackerDB.lifetimeDeaths or {}

L.autoDeleteStats = { items = {}, totalCount = 0, totalVendorCopper = 0 }
L.autoVendorStats  = { items = {}, totalCount = 0, totalVendorCopper = 0 }


--- Realm#Name key for per-toon FIT stats (accountGold, lifetimeDeaths, etc.).
--- Not used for BAGS protect/destroy — those use FugaziBAGS.GetGphCharKey / GetCharKey.
function L.GetGphCharKey()
    local r = (GetRealmName and GetRealmName()) or ""
    local c = (UnitName and UnitName("player")) or ""
    return (r or "") .. "#" .. (c or "")
end

-- Protection single-source (Tier C3): __FugaziBAGS Protection.lua + FugaziBAGSDB only.
-- Do NOT define L.GetGphProtectedSet / IsItemProtectedAPI here (wrong DB + overwrote BAGS global).
-- _G.FugaziInstanceTracker_IsItemProtected is set by BAGS; FIT does not reassign it.

--- Called by __FugaziBAGS when autodelete destroys items. Safe no-op if FIT DB missing.
--- Signature: (itemId|link, count, vendorCopper)
_G.FugaziInstanceTracker_OnAutoDelete = function(itemId, count, vendorCopper)
    if not InstanceTrackerDB or itemId == nil then return end
    if type(itemId) == "string" and itemId:match("item:%d+") then
        itemId = tonumber(itemId:match("item:(%d+)")) or itemId
    else
        itemId = tonumber(itemId) or itemId
    end
    if type(L.EnsureAutoStatTables) == "function" then L.EnsureAutoStatTables() end
    count = tonumber(count) or 1
    vendorCopper = tonumber(vendorCopper) or 0

    local LS2 = L.LS
    if LS2 then
        LS2.deletedItemCount = (LS2.deletedItemCount or 0) + count
    end
    if L.currentRun then
        L.currentRun.itemsAutodeleted = (L.currentRun.itemsAutodeleted or 0) + count
        L.currentRun.autodeletedVendorCopper = (L.currentRun.autodeletedVendorCopper or 0) + vendorCopper
        L.currentRun.autodeletedItems = L.currentRun.autodeletedItems or {}
        L.currentRun.autodeletedItems[itemId] = (L.currentRun.autodeletedItems[itemId] or 0) + count

        -- Ensure loot map has a row even if continuous delete beat DiffBags (same race as GPH).
        L.currentRun.items = L.currentRun.items or {}
        local row = L.currentRun.items[itemId]
        if type(row) ~= "table" then
            local link = L.itemLinksCache and L.itemLinksCache[itemId]
            local name, quality, iLvl
            if link and GetItemInfo then
                name, _, quality, iLvl = GetItemInfo(link)
            elseif GetItemInfo then
                name, link, quality, iLvl = GetItemInfo(itemId)
            end
            quality = quality or 0
            row = {
                link = link,
                itemId = itemId,
                quality = quality,
                count = count,
                name = name or ("Item " .. tostring(itemId)),
                iLvl = iLvl,
            }
            L.currentRun.items[itemId] = row
            L.currentRun.qualityCounts = L.currentRun.qualityCounts or {}
            L.currentRun.qualityCounts[quality] = (L.currentRun.qualityCounts[quality] or 0) + count
        else
            local have = tonumber(row.count) or 0
            local deleted = L.currentRun.autodeletedItems[itemId] or 0
            if have < deleted then
                local add = deleted - have
                row.count = have + add
                local q = row.quality or 0
                L.currentRun.qualityCounts = L.currentRun.qualityCounts or {}
                L.currentRun.qualityCounts[q] = (L.currentRun.qualityCounts[q] or 0) + add
            end
        end
        if InstanceTrackerDB then
            InstanceTrackerDB.currentRun = L.currentRun
        end
        if type(L.RefreshItemDetailLive) == "function" then
            L.RefreshItemDetailLive()
        end
    end

    local stats = L.autoDeleteStats
    if not stats then return end
    stats.totalCount = (stats.totalCount or 0) + count
    stats.totalVendorCopper = (stats.totalVendorCopper or 0) + vendorCopper
    stats.items = stats.items or {}
    local entry = stats.items[itemId]
    if not entry then
        entry = { count = 0, vendorCopper = 0 }
        stats.items[itemId] = entry
    end
    entry.count = entry.count + count
    entry.vendorCopper = entry.vendorCopper + vendorCopper
end

--- Called by __FugaziBAGS when autosell sells items. Safe no-op if FIT DB missing.
--- Signature: (itemId, count, vendorCopper)
_G.FugaziInstanceTracker_OnAutoVendor = function(itemId, count, vendorCopper)
    if not InstanceTrackerDB or itemId == nil then return end
    if type(L.EnsureAutoStatTables) == "function" then L.EnsureAutoStatTables() end
    count = tonumber(count) or 1
    vendorCopper = tonumber(vendorCopper) or 0

    local stats = L.autoVendorStats
    if not stats then return end
    stats.totalCount = (stats.totalCount or 0) + count
    stats.totalVendorCopper = (stats.totalVendorCopper or 0) + vendorCopper
    stats.items = stats.items or {}
    local entry = stats.items[itemId]
    if not entry then
        entry = { count = 0, vendorCopper = 0 }
        stats.items[itemId] = entry
    end
    entry.count = entry.count + count
    entry.vendorCopper = entry.vendorCopper + vendorCopper
end

-- Merchant open state (FIT records repairs / vendor gold into the active dungeon run).
L.gphNpcDialogTime = nil
L.merchantGoldAtOpen = nil
L.merchantRepairCostAtOpen = nil


--- Saves a window's position (and optionally "was it open?") so after /reload we can put it back. Like the game remembering where you dragged the spellbook.
function L.SaveFrameLayout(frame, shownKey, pointKey)
    if not frame then return end
    if pointKey == "itemDetailPoint" then
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            InstanceTrackerDB[pointKey] = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = left, y = top }
        end
    elseif pointKey == "statsPoint" then
        -- Always save Ledger in screen coords (origin bottom-left) so /ledger can open it alone in the right place.
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            InstanceTrackerDB[pointKey] = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = left, y = top }
        end
    else
        local p, _, rp, x, y = frame:GetPoint(1)
        if p and rp and x and y then
            InstanceTrackerDB[pointKey] = { point = p, relativePoint = rp, x = x, y = y }
        end
    end
    if shownKey then InstanceTrackerDB[shownKey] = frame:IsShown() end
    -- gphPoint / gphScale15 are BAGS-owned (FugaziBAGSDB); FIT never persists inventory layout.
end

--- Restores a window's position (and show/hide) from saved data after /reload.
function L.RestoreFrameLayout(frame, shownKey, pointKey)
    if not frame then return end
    local pt = InstanceTrackerDB[pointKey]
    if pt and pt.point and pt.relativePoint and pt.x and pt.y then
        frame:ClearAllPoints()
        frame:SetPoint(pt.point, UIParent, pt.relativePoint, pt.x, pt.y)
    end
    if shownKey then
        if InstanceTrackerDB[shownKey] then
            frame:Show()
            return true
        else
            frame:Hide()
        end
    end
    return false
end

--- Returns the label for a run in the Ledger: custom name if you renamed it, otherwise the zone name (e.g. "Utgarde Keep").
function L.GetRunDisplayName(run)
    if not run then return "?" end
    if run.customName and run.customName:match("%S") then return run.customName end
    return run.name or "?"
end

--- Prints a message to chat (yellow addon text).
function L.AddonPrint(msg)
    if msg and msg ~= "" then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

----------------------------------------------------------------------
-- Runtime state: what the addon "remembers" while you play (not saved).
-- Frames = the actual UI windows; the rest = data for current session.
----------------------------------------------------------------------
L.frame = nil              -- Main tracker window (lockouts + hourly cap)
L.statsFrame = nil          -- Ledger window (run history list)
L.ledgerDetailFrame = nil   -- Second window: one run per "page", Prev/Next flick through runs
local itemDetailFrame = nil     -- Popup that shows "items from this run"
L.isInInstance = false
L.currentZone = ""
L.runSoftPaused = false  -- ghost/corpse-run: currentRun kept open, timer keeps ticking

-- Lockout snapshot: when we last asked the game for saved lockouts (to avoid spamming).
L.lockoutQueryTime = 0
L.lockoutCache = {}
-- instanceId -> { { name, status, killed, timeText }, ... } from Raid Info tooltip scrape
L.lockoutBossCache = L.lockoutBossCache or {}

-- Current run: the dungeon/raid you're in right now (saved to Ledger when you leave).
L.currentRun = nil
local lastExitedZoneName = nil  -- Zone we just left; used so "has been reset" can mark it as don't-restore
local lastResetZoneName = nil   -- Zone that was just reset; we skip restoring this zone on re-enter but keep run in history

-- Bag tracking for "items gained this run": we take a snapshot when you enter, then only count increases (like a diff).
L.bagBaseline = {}         -- Snapshot on enter: itemId -> count
L.itemsGained = {}         -- Only goes up; used for "loot this run"
L.itemLinksCache = {}      -- itemId -> full item link (so we can show names without calling GetItemInfo every time)
L.lastEquippedItemIds = {} -- Items that were in equipment slots; if they appear in bags we treat as "unequipped" not "looted"

L.startingGold = 0          -- Gold when you entered the instance (to show "earned this run")

-- Item quality colors (WoW rarity index → display color).
L.QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62, hex = "9d9d9d", label = "Trash" },
    [1] = { r = 1.00, g = 1.00, b = 1.00, hex = "ffffff", label = "White" },
    [2] = { r = 0.12, g = 1.00, b = 0.00, hex = "1eff00", label = "Green" },
    [3] = { r = 0.00, g = 0.44, b = 0.87, hex = "0070dd", label = "Blue" },
    [4] = { r = 0.64, g = 0.21, b = 0.93, hex = "a335ee", label = "Purple" },
    [5] = { r = 1.00, g = 0.50, b = 0.00, hex = "ff8000", label = "Orange" },
}

-- Shared helpers for value/row formatting.
-- Run vendor/AH/destroy/estimated are stamped at record time (BAGS GPH stop / dungeon
-- FinalizeRun via GetItemValuationAndAction). FIT does not re-value history.

-- Row height that tracks FugaziBAGS "Row Icon Size" slider when available, so Ledger rows
-- feel like the inventory list. Falls back to a simple base height when bags aren't loaded.
function L.GetFugaziRowHeight(baseHeight)
    local SV = _G.FugaziBAGSDB
    -- 18 is the standard "premium" height for the list mode; match BAGS row icon size slider everywhere
    local rowStep = baseHeight or 18
    if SV and type(SV.gphItemDetailsIconSize) == "number" then
        rowStep = math.max(16, math.min(48, SV.gphItemDetailsIconSize + 6))
    end
    return rowStep
end

--- Reads FugaziBAGS font/color customization and returns settings for IT to match.
--- Returns: { fontPath, titleSize, headerSize, rowSize, rowIconSize, accentColor, skinName }
--- Cached so we don't allocate a new table every second when Ledger/main window L.OnUpdate runs (was causing memory climb).
L._fontSettingsCache, L._fontSettingsCacheKey = nil, nil
local function ColorCacheToken(c)
    if type(c) ~= "table" then return "0" end
    -- Include actual RGBA so live color-picker changes bust the cache (presence-only was wrong).
    return string.format("%.3f,%.3f,%.3f,%.3f", tonumber(c[1]) or 0, tonumber(c[2]) or 0, tonumber(c[3]) or 0, tonumber(c[4]) or 1)
end

function L.GetFugaziFontSettings()
    local SV = _G.FugaziBAGSDB
    local key = "n"
    if SV then
        local ov = SV.gphSkinOverrides
        key = (SV.gphSkin or "") .. "|" .. (SV.gphCategoryHeaderFontCustom and "1" or "0") .. (SV.gphCategoryHeaderFont or "") .. "|" .. tostring(SV.gphCategoryHeaderFontSize or "")
            .. "|" .. (SV.gphItemDetailsCustom and "1" or "0") .. (SV.gphItemDetailsFont or "") .. "|" .. tostring(SV.gphItemDetailsFontSize or "") .. "|" .. tostring(SV.gphItemDetailsIconSize or "")
            .. "|h" .. ColorCacheToken(ov and ov.headerTextColor)
            .. "|r" .. ColorCacheToken(ov and ov.fitRowColor)
            .. "|bg" .. ColorCacheToken(ov and ov.mainBg)
    end
    if L._fontSettingsCacheKey == key and L._fontSettingsCache then return L._fontSettingsCache end

    local result = {
        fontPath = "Fonts\\FRIZQT__.TTF",
        titleSize = 12,
        headerSize = 10,
        rowSize = 11,
        rowFontPath = "Fonts\\FRIZQT__.TTF",
        rowIconSize = 16,
        accentColor = nil, -- nil = use skin default
        -- Default FIT row label color (light blue); can be overridden via FugaziBAGS \"FIT row label text\" color.
        rowLabelColor = { 0.5, 0.8, 1.0, 1 },
        skinName = "original",
    }
    if not SV then L._fontSettingsCacheKey = key; L._fontSettingsCache = result; return result end

    -- Resolve skin name
    local val = SV.gphSkin or "original"
    if val == "elvui_real" or val == "elvui" or val == "pimp_purple" or val == "fugazi" then result.skinName = val end

    -- Custom font settings (mirrors BAGS' ApplyCustomizeToFrame logic)
    if SV.gphCategoryHeaderFontCustom then
        local path = (SV.gphCategoryHeaderFont and SV.gphCategoryHeaderFont ~= "") and SV.gphCategoryHeaderFont or "Fonts\\FRIZQT__.TTF"
        local fontSize = (type(SV.gphCategoryHeaderFontSize) == "number") and math.min(20, math.max(8, SV.gphCategoryHeaderFontSize)) or 12
        result.fontPath = path
        -- Match inventory behaviour: title slightly larger than category header,
        -- and re-use the category header size for sub-headers inside FIT windows.
        result.titleSize = math.min(20, fontSize + 1)
        result.headerSize = fontSize
    end

    -- Row font settings (mirrors BAGS' ApplyItemDetailsToRow logic)
    if SV.gphItemDetailsCustom then
        local rowPath = (SV.gphItemDetailsFont and SV.gphItemDetailsFont ~= "") and SV.gphItemDetailsFont or "Fonts\\FRIZQT__.TTF"
        local rowFontSize = (type(SV.gphItemDetailsFontSize) == "number") and math.min(16, math.max(8, SV.gphItemDetailsFontSize)) or 11
        result.rowSize = rowFontSize
        result.rowFontPath = rowPath
        result.rowIconSize = (type(SV.gphItemDetailsIconSize) == "number") and math.min(28, math.max(12, SV.gphItemDetailsIconSize)) or 16
    end

    -- Header/category text color: override when set, else skin title color (same as BAGS gphAccentTextColor).
    if SV.gphSkinOverrides and SV.gphSkinOverrides.headerTextColor then
        local c = SV.gphSkinOverrides.headerTextColor
        if c and type(c) == "table" and #c >= 3 then
            result.accentColor = { c[1], c[2], c[3], c[4] or 1 }
        end
    else
        local BSkins = _G.__FugaziBAGS_Skins
        local sk = BSkins and BSkins.SKIN and BSkins.SKIN[result.skinName]
        local tc = sk and (sk.headerTextColor or sk.titleTextColor)
        if tc and type(tc) == "table" and #tc >= 3 then
            result.accentColor = { tc[1], tc[2], tc[3], tc[4] or 1 }
        end
    end

    -- FIT row label color override (independent of header customization toggle).
    if SV.gphSkinOverrides and SV.gphSkinOverrides.fitRowColor then
        local c = SV.gphSkinOverrides.fitRowColor
        if c and type(c) == "table" and #c >= 3 then
            result.rowLabelColor = { c[1], c[2], c[3], c[4] or 1 }
        end
    end

    L._fontSettingsCacheKey = key
    L._fontSettingsCache = result
    return result
end

--- Applies BAGS-matching fonts and colors to an Instance Tracker L.frame's title and key elements.
function L.ApplyFugaziFontsToFrame(f)
    if not f then return end
    local fs = L.GetFugaziFontSettings()

    -- Title text: match BAGS title font/color
    if f.itTitleText then
        f.itTitleText:SetFont(fs.fontPath, fs.titleSize, "")
        local c = f.gphAccentTextColor or fs.accentColor
        if c and type(c) == "table" and #c >= 3 then
            f.itTitleText:SetTextColor(c[1], c[2], c[3], c[4] or 1)
        end
    end
end

--- Colors a label using the configured FIT row label color from FugaziBAGS.
function L.ColorizeFugaziRowLabel(text)
    local settings = L.GetFugaziFontSettings()
    local c = settings.rowLabelColor or { 0.5, 0.8, 1.0, 1 }
    local r = tonumber(c[1]) or 0.5
    local g = tonumber(c[2]) or 0.8
    local b = tonumber(c[3]) or 1.0
    local hex = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    return "|cff" .. hex .. tostring(text) .. "|r"
end

--- Styles a section header font string ("--- Current ---", "--- History ---", etc.)
--- Uses BAGS header/title font at header size, distinct from row text.
function L.StyleFugaziHeader(fs)
    if not fs then return end
    local settings = L.GetFugaziFontSettings()
    fs:SetFont(settings.fontPath, settings.headerSize, "")
    local c = settings.accentColor
    if c and type(c) == "table" and #c >= 3 then
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    else
        -- Soft teal/blue similar to original Fugazi header tint
        fs:SetTextColor(0.5, 0.8, 1.0, 1)
    end
end

----------------------------------------------------------------------
-- Slash surface is intentionally tiny:
--   /fit     — toggle Instance Tracker main window
--   /ledger  — open Ledger (run history)
-- Bags/inventory (/gph), skins, options: all owned by __FugaziBAGS.
----------------------------------------------------------------------
SLASH_INSTANCETRACKER1 = "/fit"
SLASH_INSTANCETRACKER_LEDGER1 = "/ledger"

SlashCmdList["INSTANCETRACKER_LEDGER"] = function()
    if not L.statsFrame then L.statsFrame = L.CreateStatsFrame() end
    if L.statsFrame:IsShown() then
        L.RefreshStatsUI()
        return
    end
    L.statsFrame:ClearAllPoints()
    local pt = InstanceTrackerDB.statsPoint
    if pt and pt.point and pt.relativePoint and pt.x and pt.y then
        L.statsFrame:SetPoint(pt.point, UIParent, pt.relativePoint, pt.x, pt.y)
    else
        L.statsFrame:SetPoint("TOP", UIParent, "CENTER", 0, 100)
    end
    L.statsFrame:Show()
    L.SaveFrameLayout(L.statsFrame, "statsShown", "statsPoint")
    L.RefreshStatsUI()
end

-- Toggle main tracker: classic hourly+lockouts; Ascension lockouts (+ boss scrape).
SlashCmdList["INSTANCETRACKER"] = function()
    if L.IsMainTrackerUIEnabled and not L.IsMainTrackerUIEnabled() then
        return
    end
    if not L.frame then
        L.frame = L.CreateMainFrame()
        L.frame:SetScript("OnHide", function() L.frame:SetScript("OnUpdate", nil) end)
        L.frame:SetScript("OnShow", function() L.frame:SetScript("OnUpdate", L.OnUpdate) end)
    end
    if L.frame:IsShown() then
        L.frame:Hide()
        L.SaveFrameLayout(L.frame, "frameShown", "framePoint")
        InstanceTrackerDB.mainFrameUserClosed = true
    else
        InstanceTrackerDB.mainFrameUserClosed = false
        if RequestRaidInfo then RequestRaidInfo() end
        if L.UpdateLockoutCache then L.UpdateLockoutCache() end
        -- Best-effort boss fill when RaidInfo buttons already exist this session
        if L.IsAscensionRealm and L.IsAscensionRealm() and L.RefreshLockoutBossCache then
            L.RefreshLockoutBossCache()
        end
        L.frame:Show()
        L.SaveFrameLayout(L.frame, "frameShown", "framePoint")
        L.RefreshUI(true)
    end
end

----------------------------------------------------------------------
-- Skin consumer API (single entry). FIT never owns theme/skin DB.
-- BAGS Options → RefreshAllUI → FugaziInstanceTracker_RefreshSkinFromBAGS.
----------------------------------------------------------------------
local function RefreshAllFITSkinsFromBAGS()
    L._fontSettingsCacheKey = nil
    if _G.InstanceTrackerFrame then L.frame = _G.InstanceTrackerFrame end
    if _G.InstanceTrackerStatsFrame then L.statsFrame = _G.InstanceTrackerStatsFrame end
    if _G.InstanceTrackerLedgerDetailFrame then L.ledgerDetailFrame = _G.InstanceTrackerLedgerDetailFrame end

    if _G.InstanceTrackerFrame and L.IsMainTrackerUIEnabled and L.IsMainTrackerUIEnabled() then
        L.ApplyInstanceTrackerSkin(_G.InstanceTrackerFrame)
        if type(L.RefreshUI) == "function" then L.RefreshUI(true) end
    end
    if _G.InstanceTrackerStatsFrame then
        L.ApplyInstanceTrackerSkin(_G.InstanceTrackerStatsFrame)
        if type(L.RefreshStatsUI) == "function" then L.RefreshStatsUI(true) end
    end
    if _G.InstanceTrackerLedgerDetailFrame then
        L.ApplyInstanceTrackerSkin(_G.InstanceTrackerLedgerDetailFrame)
        if type(L.RefreshLedgerDetailUI) == "function" then L.RefreshLedgerDetailUI(true) end
    end
    if _G.InstanceTrackerItemDetailFrame then
        L.ApplyInstanceTrackerSkin(_G.InstanceTrackerItemDetailFrame)
        if _G.InstanceTrackerItemDetailFrame.RefreshItemDetailList then
            _G.InstanceTrackerItemDetailFrame:RefreshItemDetailList()
        end
    end
end

--- Public skin bridge (BAGS calls this).
_G.FugaziInstanceTracker_RefreshSkinFromBAGS = RefreshAllFITSkinsFromBAGS

----------------------------------------------------------------------
-- No FIT options panel. Menu inject: BAGS Options title menu calls
-- Addon.GPHTitleMenu_InjectSession / InjectTrackerStats if present.
----------------------------------------------------------------------
local configEventFrame = CreateFrame("Frame")
configEventFrame:RegisterEvent("PLAYER_LOGIN")
configEventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        local function InjectBagsMenu()
            local Addon = _G.FugaziBAGS
            if not Addon then return end

            -- Session Start/Stop (BAGS title menu, above Notepad)
            Addon.GPHTitleMenu_InjectSession = function(self, level)
                if level ~= 1 then return end
                local info = UIDropDownMenu_CreateInfo()

                if _G.gphSession then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "|cff00ff00Session Active|r"
                    info.isTitle = true
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info)
                end

                info = UIDropDownMenu_CreateInfo()
                info.text = _G.gphSession and "Stop Session" or "Start Session"
                info.func = function()
                    if _G.gphSession then
                        if Addon.StopGPHSession then Addon.StopGPHSession() end
                    else
                        if Addon.StartGPHSession then Addon.StartGPHSession() end
                        if _G.RefreshGPHUI then _G.RefreshGPHUI() end
                    end
                    CloseDropDownMenus()
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info)

                if _G.gphSession then
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "|cffff8844Reset GPH Session|r"
                    info.func = function()
                        if Addon and type(Addon.ResetGPHSession) == "function" then
                            Addon.ResetGPHSession()
                        end
                        CloseDropDownMenus()
                    end
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info)
                end
            end

            -- Tracker / Ledger openers (BAGS title menu, below Notepad)
            Addon.GPHTitleMenu_InjectTrackerStats = function(self, level)
                if level ~= 1 then return end
                local info = UIDropDownMenu_CreateInfo()
                local showMainTracker = true
                if L.IsMainTrackerUIEnabled then
                    showMainTracker = L.IsMainTrackerUIEnabled()
                end

                if showMainTracker then
                    info = UIDropDownMenu_CreateInfo()
                    local isAsc = L.IsAscensionRealm and L.IsAscensionRealm()
                    info.text = isAsc and "Lockouts" or "Instance Tracker"
                    info.func = function()
                        if SlashCmdList["INSTANCETRACKER"] then SlashCmdList["INSTANCETRACKER"]("") end
                        CloseDropDownMenus()
                    end
                    info.notCheckable = true
                    UIDropDownMenu_AddButton(info)
                end

                info = UIDropDownMenu_CreateInfo()
                info.text = "Ledger"
                info.func = function()
                    if SlashCmdList["INSTANCETRACKER_LEDGER"] then
                        SlashCmdList["INSTANCETRACKER_LEDGER"]("")
                    end
                    CloseDropDownMenus()
                end
                info.notCheckable = true
                UIDropDownMenu_AddButton(info)
            end
        end
        InjectBagsMenu()
    end
end)
