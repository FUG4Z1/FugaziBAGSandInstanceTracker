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

function Search.ClearTooltipCache()
    wipe(Search.TooltipCache)
end

--- Scans item tooltip for a specific string (case-insensitive).
function Search.TooltipContains(link, queryLower)
    if not link or not queryLower or queryLower == "" then return false end
    
    local cachedStr = Search.TooltipCache[link]
    if not cachedStr then
        local st = GetSearchTooltip()
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

    -- 4. Tooltip/Stat Scanning (The "Power Search")
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

    -- Trigger Refreshes
    if _G.RefreshGPHUI then _G.RefreshGPHUI() end
    if _G.RefreshBankUI then _G.RefreshBankUI() end
    
    -- Sync with Grid Mode
    if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.ApplySearch then
        _G.FugaziBAGS_CombatGrid.ApplySearch(text)
    end
end

-- Export to global for easy access from XML if needed
_G.FugaziBAGS_Search = Search
