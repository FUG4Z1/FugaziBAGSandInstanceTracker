local addonName, Addon = ...
_G.FugaziBAGS = _G.FugaziBAGS or Addon or {}
local A = _G.FugaziBAGS

local Search = {}
A.Search = Search

-- Internal Scan Tooltip (Private to this module)
local scanTooltip
local function GetSearchTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "Fugazi_SearchScanner", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTooltip
end

Search.TooltipCache = {}
Search.LearnableRecipeCache = {}

-- Real queries the matcher accepts (valuation, quality, type/subtype, tooltip stats).
-- Shown as a rotating watermark when the search field opens empty.
local HINT_POOL = {
    -- valuation actions
    "auction", "vendor", "disenchant", "prospect", "mill",
    -- quality: type the full label (e.g. Rare). q: still works for partials (q:ep → Epic) but is not hinted.
    "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Heirloom",
    -- item type / subtype fragments
    "herb", "ore", "gem", "cloth", "leather", "mail", "plate",
    "potion", "flask", "food", "recipe", "quest", "weapon", "armor",
    "consumable", "bag", "reagent",
    -- tooltip / stat fragments
    "stamina", "intellect", "strength", "agility", "spirit",
    "hit rating", "critical", "haste", "spell power", "attack power",
    "resilience", "expertise", "armor", "dodge", "parry",
    "unique", "soulbound",
}

local lastHintText = nil

--- Build a short "a · b · c · d" string of real search examples (rotates each call).
function Search.PickHintText(count)
    count = count or 4
    local n = #HINT_POOL
    if n == 0 then return "" end
    if count > n then count = n end

    local order = {}
    for i = 1, n do order[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        order[i], order[j] = order[j], order[i]
    end

    local function build()
        local parts = {}
        for i = 1, count do
            parts[i] = HINT_POOL[order[i]]
        end
        return table.concat(parts, " · ")
    end

    local text = build()
    -- Avoid repeating the exact same quartet when the pool is large enough.
    if text == lastHintText and n > count then
        -- rotate order by one and rebuild
        local first = order[1]
        for i = 1, n - 1 do order[i] = order[i + 1] end
        order[n] = first
        text = build()
    end
    lastHintText = text
    return text
end

--- Ensure edit box has a watermark FontString; refresh text when empty.
function Search.RefreshPlaceholder(editBox)
    if not editBox then return end
    local hint = editBox.searchHint
    if not hint then
        hint = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("LEFT", editBox, "LEFT", 6, 0)
        hint:SetPoint("RIGHT", editBox, "RIGHT", -4, 0)
        hint:SetJustifyH("LEFT")
        if hint.SetWordWrap then hint:SetWordWrap(false) end
        if hint.SetNonSpaceWrap then hint:SetNonSpaceWrap(false) end
        editBox.searchHint = hint
    end
    -- Soft watermark: low alpha so it feels like a hint, not typed text.
    hint:SetTextColor(0.62, 0.56, 0.45, 0.45)
    hint:SetText("e.g.  " .. Search.PickHintText(4))
    local t = editBox:GetText() or ""
    if t == "" then
        hint:Show()
    else
        hint:Hide()
    end
end

--- Show/hide watermark from current edit-box text (call from OnTextChanged).
function Search.UpdatePlaceholderVisibility(editBox)
    if not editBox or not editBox.searchHint then return end
    local t = editBox:GetText() or ""
    if t == "" then
        editBox.searchHint:Show()
    else
        editBox.searchHint:Hide()
    end
end

function Search.ClearTooltipCache()
    wipe(Search.TooltipCache)
    wipe(Search.LearnableRecipeCache)
end

--- Scans item tooltip for a specific string (case-insensitive).
function Search.TooltipContains(link, queryLower)
    if not link or not queryLower or queryLower == "" then return false end
    
    local cachedStr = Search.TooltipCache[link]
    if not cachedStr then
        local st = GetSearchTooltip()
        st:SetOwner(UIParent, "ANCHOR_NONE")
        st:ClearLines()
        st:SetHyperlink(link)
        
        local parts = {}
        local name = st:GetName()
        for i = 1, st:NumLines() do
            local line = _G[name .. "TextLeft" .. i]
            if line then
                local text = line:GetText()
                if text then
                    table.insert(parts, text:lower())
                end
            end
        end
        cachedStr = table.concat(parts, " ")
        Search.TooltipCache[link] = cachedStr
    end
    
    if cachedStr:find(queryLower, 1, true) then
        return true
    end
    return false
end

--- True if this bag recipe is still learnable.
--- Prefer bag+slot (SetBagItem): SetHyperlink often omits "Already known" on Ascension,
--- which made Learn re-target the same known pattern forever.
function Search.CanLearnRecipe(link, bag, slot)
    if not link then return false end

    local cacheKey = (bag ~= nil and slot ~= nil) and (bag .. ":" .. slot .. ":" .. link) or link
    if Search.LearnableRecipeCache[cacheKey] ~= nil then
        return Search.LearnableRecipeCache[cacheKey]
    end
    -- Link-only negative cache (failed learn / known phrase).
    if Search.LearnableRecipeCache[link] == false then
        return false
    end

    local st = GetSearchTooltip()
    st:SetOwner(UIParent, "ANCHOR_NONE")
    st:ClearLines()
    if bag ~= nil and slot ~= nil and st.SetBagItem then
        st:SetBagItem(bag, slot)
    else
        st:SetHyperlink(link)
    end

    local n = st:NumLines() or 0
    if n == 0 then
        return false -- incomplete scan; do not cache as learnable
    end

    local Loc = A.L
    local knownPhrase = ((Loc and Loc.TOOLTIP_ALREADY_KNOWN) or "already known"):lower()
    local name = st:GetName()
    for i = 1, n do
        local line = _G[name .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text ~= "" then
                if text:lower():find(knownPhrase, 1, true) then
                    Search.LearnableRecipeCache[cacheKey] = false
                    Search.LearnableRecipeCache[link] = false
                    return false
                end
                -- Red requirement / already-known lines.
                local r, g, b = line:GetTextColor()
                if r and r > 0.9 and g < 0.2 and b < 0.2 then
                    Search.LearnableRecipeCache[cacheKey] = false
                    Search.LearnableRecipeCache[link] = false
                    return false
                end
            end
        end
    end

    Search.LearnableRecipeCache[cacheKey] = true
    return true
end

-- Back-compat alias (bag/slot optional).
function Search.IsRecipeLearnable(link, bag, slot)
    return Search.CanLearnRecipe(link, bag, slot)
end

--- Call when a learn /use left the same item in the slot (already known / failed).
function Search.MarkRecipeUnlearnable(link)
    if not link then return end
    Search.LearnableRecipeCache[link] = false
end

--- Main matching function. Use this for all views.
function Search.Matches(item, queryLower)
    if not queryLower or queryLower == "" then return true end
    if not item then return false end
    
    local link = item.link
    local name = item.name or ""
    local quality = item.quality or 0
    
    -- 1. Exact Quality Match (Fixes "o" matching "Common")
    -- We only match quality if the query is an exact match for the label
    -- OR if it's prefixed with "q:"
    local isQualityQuery = false
    local targetQ = nil
    
    if queryLower:sub(1,2) == "q:" then
        isQualityQuery = true
        local qName = queryLower:sub(3)
        for q = 0, 7 do
            local info = A.QUALITY_COLORS[q]
            if info and info.label:lower():find(qName, 1, true) then
                targetQ = q
                break
            end
        end
    else
        -- Check if query is an EXACT match for a quality label
        for q = 0, 7 do
            local info = A.QUALITY_COLORS[q]
            if info and info.label:lower() == queryLower then
                targetQ = q
                isQualityQuery = true
                break
            end
        end
    end
    
    if isQualityQuery then
        return quality == targetQ
    end

    -- 2. Basic Name Match
    if name:lower():find(queryLower, 1, true) then return true end
    
    -- 3. Item Type / SubType Match
    -- item.itemType/subType are usually available in the record or can be fetched
    local _, _, _, _, _, iType, iSubType = GetItemInfo(link or item.itemId or 0)
    if iType and iType:lower():find(queryLower, 1, true) then return true end
    if iSubType and iSubType:lower():find(queryLower, 1, true) then return true end

    -- 4. Valuation Engine integration
    if queryLower == "disenchant" or queryLower == "prospect" or queryLower == "mill" or queryLower == "auction" or queryLower == "vendor" then
        if A.GetItemValuationAndAction then
            local _, _, _, _, _, itemClass = GetItemInfo(link or item.itemId or 0)
            local _, action = A.GetItemValuationAndAction(
                link, item.itemId, quality, item.itemLevel, itemClass, item.bag, item.slot
            )
            if queryLower == "disenchant" and action == "DE" then return true end
            if queryLower == "prospect" and action == "PROSPECT" then return true end
            if queryLower == "mill" and action == "MILL" then return true end
            if queryLower == "auction" and action == "AH" then return true end
            if queryLower == "vendor" and action == "VENDOR" then return true end
        end
    end

    -- 5. Tooltip/Stat Scanning (The "Power Search")
    if Search.TooltipContains(link, queryLower) then return true end

    return false
end

--- Synchronize search state across all active views.
function Search.Sync(text, sourceFrame)
    text = (text or ""):match("^%s*(.-)%s*$") -- Trim
    
    -- Update Global State in frames
    if A.Inventory then A.Inventory.gphSearchText = text end
    if A.Bank then A.Bank.gphSearchText = text end
    
    -- Update EditBoxes if visible
    if A.Inventory and A.Inventory.gphSearchEditBox then 
        if A.Inventory.gphSearchEditBox:GetText() ~= text then
            A.Inventory.gphSearchEditBox:SetText(text)
        end
    end
    if A.Bank and A.Bank.gphSearchEditBox then 
        if A.Bank.gphSearchEditBox:GetText() ~= text then
            A.Bank.gphSearchEditBox:SetText(text)
        end
    end

    -- Search is chrome, not bag content: force full list rebuild (no smart/NOOP skip).
    if A.Inventory then A.Inventory._refreshImmediate = true end
    if A.Bank then
        A.Bank._bankForceFull = true
        A.Bank._bankGridForceFull = true
    end

    -- Trigger Refreshes
    if _G.RefreshGPHUI then _G.RefreshGPHUI() end
    if _G.RefreshBankUI then _G.RefreshBankUI(true) end
    
    -- Sync with Grid Mode
    if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.ApplySearch then
        _G.FugaziBAGS_CombatGrid.ApplySearch(text)
    end
end

local function ForSearchFrames(fn)
    if A.Inventory then fn(A.Inventory) end
    if A.Bank then fn(A.Bank) end
end

--- True when a non-empty inventory search filter is applied.
function Search.IsActive()
    local t = A.Inventory and A.Inventory.gphSearchText
    return type(t) == "string" and t ~= ""
end

--- Refresh Search button look for set vs idle. Size/position stay fixed (36×18, left-anchored);
--- long queries are truncated — full string is on the tooltip.
function Search.UpdateChrome()
    local text = (A.Inventory and A.Inventory.gphSearchText) or ""
    local active = text ~= ""
    -- Fixed-width button: keep label short so it never pushes layout.
    local short = "Search"
    if active then
        if #text <= 6 then
            short = text
        else
            short = text:sub(1, 5) .. ".."
        end
    end

    local Skins = _G.__FugaziBAGS_Skins
    ForSearchFrames(function(f)
        if not f then return end
        f.gphSearchSet = active and true or false
        local btn = f.gphSearchBtn
        local label = f.gphSearchLabel
        if label then
            label:SetText(short)
        end
        if btn then
            -- Never SetWidth/SetHeight/ClearPoints — left anchor + 36×18 stay put.
            if active then
                if btn.bg then
                    btn.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
                    btn.bg:SetVertexColor(0.22, 0.82, 0.38, 1)
                end
                if label then
                    -- Dark text on green fill.
                    label:SetTextColor(0.08, 0.22, 0.10, 1)
                end
            else
                -- Restore skin idle look (no green).
                if Skins and Skins.ApplyToComponent then
                    Skins.ApplyToComponent(btn, "Button", "Search")
                    if label then Skins.ApplyToComponent(label, "Text", "Search") end
                else
                    if btn.bg then
                        btn.bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
                        btn.bg:SetVertexColor(0.1, 0.3, 0.15, 0.7)
                    end
                    if label then
                        label:SetTextColor(0.92, 0.82, 0.55, 1)
                    end
                end
                if label then label:SetText("Search") end
            end
        end
    end)
end

--- Commit filter for farming: keep gphSearchText, hide the edit box (stop waiting for input).
function Search.Set(text, sourceFrame)
    text = (text or ""):match("^%s*(.-)%s*$") or ""
    if text == "" then
        return Search.Clear(sourceFrame)
    end

    Search.Sync(text, sourceFrame)

    ForSearchFrames(function(f)
        f.gphSearchBarVisible = false
        f.gphSearchSet = true
        local eb = f.gphSearchEditBox
        if eb then
            eb:ClearFocus()
            eb:Hide()
        end
    end)

    Search.UpdateChrome()
end

--- Drop filter and return Search chrome to idle (Search button / Escape only — not bag close).
function Search.Clear(sourceFrame)
    local hadFilter = Search.IsActive()

    -- Collapse chrome first (before Sync SetText) so focus-lost does not re-Set.
    ForSearchFrames(function(f)
        f.gphSearchBarVisible = false
        f.gphSearchSet = false
        local eb = f.gphSearchEditBox
        if eb then
            eb:ClearFocus()
            eb:Hide()
        end
    end)

    if hadFilter then
        -- Sync clears gphSearchText, edit boxes, and rebuilds lists once.
        Search.Sync("", sourceFrame)
    else
        ForSearchFrames(function(f)
            if f then f.gphSearchText = "" end
            local eb = f and f.gphSearchEditBox
            if eb and eb:GetText() ~= "" then
                eb:SetText("")
            end
        end)
    end

    Search.UpdateChrome()
end

-- Export to global for easy access from XML if needed
_G.FugaziBAGS_Search = Search
