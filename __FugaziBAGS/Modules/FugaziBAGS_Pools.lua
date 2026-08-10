--[[
  FugaziBAGS_Pools.lua — UI row/text/quality frame pools only.
  Data aggregates / working lists live in Utils + Listview (Phase 5).
  Do not rewrite row identity or secure children for “memory”.
]]
local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

--- Constants
local SCROLL_CONTENT_WIDTH = 296

--- UI Pools
local GPH_ROW_POOL, GPH_ROW_POOL_USED = {}, 0
local GPH_TEXT_POOL, GPH_TEXT_POOL_USED = {}, 0
local GPH_ITEM_POOL, GPH_ITEM_POOL_USED = {}, 0
local GPH_QUAL_POOL, GPH_QUAL_POOL_USED = {}, 0

--- Reset UI pool used-counts (inventory list). Prefer per-kind resets when list
--- refresh resets quality/text/item independently.
function A.ResetGPHPools()
    GPH_ROW_POOL_USED = 0
    GPH_TEXT_POOL_USED = 0
    GPH_ITEM_POOL_USED = 0
    GPH_QUAL_POOL_USED = 0
end

function A.ResetGPHQualityPool()
    GPH_QUAL_POOL_USED = 0
end

function A.ResetGPHTextPool()
    GPH_TEXT_POOL_USED = 0
end

function A.ResetGPHItemPool()
    GPH_ITEM_POOL_USED = 0
end

function A.CleanupGPHPools()
    if not GPH_ROW_POOL then return end
    for i = GPH_ROW_POOL_USED + 1, #GPH_ROW_POOL do
        if GPH_ROW_POOL[i] then GPH_ROW_POOL[i]:Hide() end
    end
    for i = GPH_TEXT_POOL_USED + 1, #GPH_TEXT_POOL do
        if GPH_TEXT_POOL[i] then GPH_TEXT_POOL[i]:Hide() end
    end
    for i = GPH_ITEM_POOL_USED + 1, #GPH_ITEM_POOL do
        if GPH_ITEM_POOL[i] then GPH_ITEM_POOL[i]:Hide() end
    end
    for i = GPH_QUAL_POOL_USED + 1, #GPH_QUAL_POOL do
        if GPH_QUAL_POOL[i] then GPH_QUAL_POOL[i]:Hide() end
    end
end

function A.GetGPHItemPool()
    return GPH_ITEM_POOL, GPH_ITEM_POOL_USED
end

function A.SetGPHItemPoolUsed(count)
    GPH_ITEM_POOL_USED = count or 0
end

--- Get or create a recycled GPH text element (font string).
function A.GetGPHText(parent)
    GPH_TEXT_POOL_USED = GPH_TEXT_POOL_USED + 1
    local fs = GPH_TEXT_POOL[GPH_TEXT_POOL_USED]
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        GPH_TEXT_POOL[GPH_TEXT_POOL_USED] = fs
    end
    fs:SetParent(parent)
    fs:ClearAllPoints()
    fs:Show()
    fs:SetText("")
    return fs
end

--- Get or create a recycled structural GPH item button (icon, name, count).
function A.CreateItemBtnStruct(parent, name)
    local btn = CreateFrame("Frame", name, parent)
    btn:SetHeight(18)
    btn:EnableMouse(true)
    
    btn.deleteBtn = nil

    local clickArea = CreateFrame("Button", nil, btn)
    clickArea:SetPoint("LEFT", btn, "LEFT", 0, 0)
    clickArea:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    clickArea:SetHeight(18)
    clickArea:EnableMouse(true)
    clickArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    clickArea:SetFrameLevel(btn:GetFrameLevel() + 2)
    btn.clickArea = clickArea

    -- Idle row fill on clickArea (not parent): parent BACKGROUND sits under the full-size
    -- Button and often never reads. 1px bottom inset = panel gap between stacked rows.
    local bg = clickArea:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", clickArea, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", clickArea, "BOTTOMRIGHT", 0, 1)
    -- Glassy idle wash; skinned later (theme + Row opacity slider).
    bg:SetTexture(0.70, 0.70, 0.72, 0.06)
    btn.bg = bg

    -- Selection / hover above idle fill (BORDER > BACKGROUND on 3.3.5).
    local sel = clickArea:CreateTexture(nil, "BORDER")
    sel:SetPoint("TOPLEFT", clickArea, "TOPLEFT", 0, 0)
    sel:SetPoint("BOTTOMRIGHT", clickArea, "BOTTOMRIGHT", 0, 1)
    sel:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    sel:SetVertexColor(0.1, 0.3, 0.15, 0.7)
    sel:Hide()
    btn.selectedTex = sel

    local icon = clickArea:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(16)
    icon:SetHeight(16)
    icon:SetPoint("LEFT", clickArea, "LEFT", 0, 0)
    btn.icon = icon
    -- Stack count on its own layer above clickArea/secure overlay (not under name).
    local countLayer = CreateFrame("Frame", nil, btn)
    countLayer:SetFrameLevel((btn:GetFrameLevel() or 1) + 30)
    countLayer:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    countLayer:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    countLayer:SetWidth(48)
    countLayer:EnableMouse(false)
    btn._countLayer = countLayer
    local countFs = countLayer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countFs:SetPoint("RIGHT", countLayer, "RIGHT", -4, 0)
    countFs:SetJustifyH("RIGHT")
    btn.countFs = countFs
    local nameFs = clickArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameFs:SetPoint("RIGHT", clickArea, "RIGHT", -48, 0)
    nameFs:SetJustifyH("LEFT")
    btn.nameFs = nameFs
    -- Subtle list-row hover wash (shown/hidden only in HandleBagSlotEnter/Leave — no OnUpdate).
    local rowHighlight = clickArea:CreateTexture(nil, "BORDER")
    rowHighlight:SetPoint("TOPLEFT", clickArea, "TOPLEFT", 0, 0)
    rowHighlight:SetPoint("BOTTOMRIGHT", clickArea, "BOTTOMRIGHT", 0, 1)
    rowHighlight:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    rowHighlight:SetVertexColor(1, 1, 1, 0.14)
    rowHighlight:Hide()
    btn.rowHighlight = rowHighlight
    
    local cooldownOverlay = clickArea:CreateTexture(nil, "OVERLAY")
    cooldownOverlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    cooldownOverlay:SetPoint("TOPLEFT", clickArea, "TOPLEFT", 0, 0)
    cooldownOverlay:SetPoint("BOTTOMLEFT", clickArea, "BOTTOMLEFT", 0, 0)
    cooldownOverlay:SetWidth(0.01)
    cooldownOverlay:Hide()
    btn.cooldownOverlay = cooldownOverlay
    
    local destroyOverlay = clickArea:CreateTexture(nil, "OVERLAY")
    destroyOverlay:SetAllPoints()
    destroyOverlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    destroyOverlay:SetVertexColor(0.5, 0.05, 0.05)
    destroyOverlay:SetAlpha(0.85)
    destroyOverlay:Hide()
    btn.destroyOverlay = destroyOverlay
    
    local protectedOverlay = clickArea:CreateTexture(nil, "OVERLAY")
    protectedOverlay:SetAllPoints()
    protectedOverlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    protectedOverlay:SetVertexColor(0, 0, 0)
    protectedOverlay:SetAlpha(0.38)
    protectedOverlay:Hide()
    btn.protectedOverlay = protectedOverlay
    
    local protectedKeyIcon = clickArea:CreateTexture(nil, "OVERLAY")
    protectedKeyIcon:SetSize(14, 14)
    protectedKeyIcon:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    protectedKeyIcon:SetTexture("Interface\\Icons\\INV_Misc_Key_13")
    protectedKeyIcon:Hide()
    btn.protectedKeyIcon = protectedKeyIcon
    
    local prevWornIcon = clickArea:CreateTexture(nil, "OVERLAY")
    prevWornIcon:SetWidth(14)
    prevWornIcon:SetHeight(14)
    prevWornIcon:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    prevWornIcon:Hide()
    btn.prevWornIcon = prevWornIcon

    local pulse = CreateFrame("Frame", nil, clickArea)
    pulse:SetAllPoints()
    pulse:SetFrameLevel(clickArea:GetFrameLevel() + 5)
    local pulseTex = pulse:CreateTexture(nil, "OVERLAY")
    pulseTex:SetAllPoints()
    pulseTex:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    pulseTex:SetVertexColor(1, 1, 1, 0.7)
    pulse:Hide()
    btn.pulseTex = pulse
    btn._pulseColorTex = pulseTex -- Frame host + color tex (denied flash / click pulse)
    
    return btn
end

function A.ResetItemBtnVisuals(btn, parent)
    btn:SetParent(parent)
    btn:Show()
    if btn.deleteBtn then btn.deleteBtn:Show() end
    btn.clickArea:Show()
    btn.clickArea:EnableMouse(true)
    btn.itemLink = nil
    if A.ClearRowPulse then
        A.ClearRowPulse(btn)
    elseif btn.pulseTex then
        btn.pulseTex:Hide()
    end
    if btn.rowHighlight then btn.rowHighlight:Hide() end
    if btn.selectedTex then btn.selectedTex:Hide() end
    if btn.cooldownOverlay then btn.cooldownOverlay:Hide() end
    if btn.destroyOverlay then btn.destroyOverlay:Hide() end
    if btn.protectedOverlay then btn.protectedOverlay:Hide() end
    if btn.protectedKeyIcon then btn.protectedKeyIcon:Hide() end
    if btn.prevWornIcon then btn.prevWornIcon:Hide() end
    if btn.wardrobeIcon then btn.wardrobeIcon:Hide() end
    if btn.countFs then btn.countFs:SetText("") end
    if btn._countLayer then
        local lvl = (btn:GetFrameLevel() or 1) + 30
        if A.SafeSetFrameLevel then
            A.SafeSetFrameLevel(btn._countLayer, lvl)
        else
            btn._countLayer:SetFrameLevel(lvl)
        end
        btn._countLayer:Show()
    end
    -- Wipe visual cache so next paint is full. Used only on new pool take / hide path —
    -- live list reuse must NOT call this every loot (kills early-out).
    btn._visualState = nil
end

function A.GetGPHItemBtn(parent)
    GPH_ITEM_POOL_USED = GPH_ITEM_POOL_USED + 1
    local btn = GPH_ITEM_POOL[GPH_ITEM_POOL_USED]
    if not btn then
        btn = A.CreateItemBtnStruct(parent, "InvRow_" .. GPH_ITEM_POOL_USED)
        GPH_ITEM_POOL[GPH_ITEM_POOL_USED] = btn
    end
    A.ResetItemBtnVisuals(btn, parent)
    return btn
end

A.GPH_BANK_POOL = {}
A.GPH_BANK_POOL_USED = 0
function A.GetBankItemBtn(parent)
    A.GPH_BANK_POOL_USED = A.GPH_BANK_POOL_USED + 1
    local btn = A.GPH_BANK_POOL[A.GPH_BANK_POOL_USED]
    if not btn then
        btn = A.CreateItemBtnStruct(parent, "BankRow_" .. A.GPH_BANK_POOL_USED)
        A.GPH_BANK_POOL[A.GPH_BANK_POOL_USED] = btn
    end
    A.ResetItemBtnVisuals(btn, parent)
    return btn
end

--- Get or create a recycled GPH quality button (filter buttons).
function A.GetGPHQualityBtn(q, parent)
    GPH_QUAL_POOL_USED = GPH_QUAL_POOL_USED + 1
    local btn = GPH_QUAL_POOL[GPH_QUAL_POOL_USED]
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        GPH_QUAL_POOL[GPH_QUAL_POOL_USED] = btn
        btn:SetSize(36, 14)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        btn.bg = bg
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("CENTER")
        btn.fs = fs
    end
    btn:SetParent(parent)
    btn:Show()
    btn.quality = q
    local info = A.QUALITY_COLORS and A.QUALITY_COLORS[q]
    if info then
        btn.bg:SetTexture(info.r, info.g, info.b, 0.7)
        btn.fs:SetText(info.label or "")
    end
    return btn
end

if _G.C_AppearanceCollection and _G.C_AppearanceCollection.CollectItemAppearance then
    local orig = _G.C_AppearanceCollection.CollectItemAppearance
    _G.C_AppearanceCollection.CollectItemAppearance = function(guid)
        orig(guid)
        if _G.C_Timer and _G.C_Timer.After then
            _G.C_Timer.After(0.4, function()
                local A = _G.FugaziBAGS
                if A and A._gphWardrobeCache then wipe(A._gphWardrobeCache) end
                if A then A._gphBagSpaceDirty = true end
                -- Wardrobe bind-on-collect flips BoE → soulbound; drop sticky DE valuation.
                if A and A.InvalidateValuationCache then
                    A.InvalidateValuationCache("wardrobe")
                end
                if _G.RefreshGPHUI then _G.RefreshGPHUI() end
                if _G.RefreshBankUI then _G.RefreshBankUI() end
                if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then
                    _G.FugaziBAGS_CombatGrid.RefreshSlots()
                end
                if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.BankRefreshSlots then
                    _G.FugaziBAGS_CombatGrid.BankRefreshSlots()
                end
            end)
            _G.C_Timer.After(1.2, function()
                local A = _G.FugaziBAGS
                -- Second pass: bind text can lag a moment after CollectItemAppearance.
                if A and A.InvalidateValuationCache then
                    A.InvalidateValuationCache("wardrobe")
                end
                if _G.RefreshGPHUI then _G.RefreshGPHUI() end
                if _G.RefreshBankUI then _G.RefreshBankUI() end
                if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then
                    _G.FugaziBAGS_CombatGrid.RefreshSlots()
                end
                if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.BankRefreshSlots then
                    _G.FugaziBAGS_CombatGrid.BankRefreshSlots()
                end
            end)
        end
    end
end
