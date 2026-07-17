local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}
_G.FugaziBAGS = A

local SKIN = {
    original = {
        mainBackdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile     = true, tileSize = 32, edgeSize = 24,
            insets   = { left = 2, right = 6, top = 6, bottom = 6 },
        },
        mainBg = { 0.08, 0.08, 0.12, 1 },
        mainBorder = { 0.6, 0.5, 0.2, 0.8 },
        titleBackdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
        titleBg = { 0.35, 0.28, 0.1, 0.7 },
        btnNormal = { 0.1, 0.3, 0.15, 0.7 },
        titleTextColor = { 1, 0.85, 0.4, 1 },
        searchBtnBg = { 0.1, 0.3, 0.15, 0.7 },
        searchBtnHover = { 0.15, 0.4, 0.2, 0.8 },
        scaleBtnDim = { 0.1, 0.3, 0.15, 0.7 },
        scaleBtnBright = { 0.15, 0.4, 0.2, 0.8 },
        collapseBtnDim = { 0.1, 0.3, 0.15, 0.7 },
        collapseBtnBright = { 0.15, 0.4, 0.2, 0.8 },
        statusTextColor = { 1, 0.85, 0.4, 1 },
        bottomBarBg = { 0.08, 0.06, 0.04, 0.9 },
        bottomBarBorder = { 0.6, 0.5, 0.2, 0.6 },
        bottomBarTextColor = { 1, 0.85, 0.4, 1 },
        sepColor = { 1, 1, 1, 0.15 },
        bagSpaceGlow = { 1, 0.85, 0.2, 0.5 },
        -- Registry Expansion:
        slotAlpha = 0.10,
        slotBgTexture = "Interface\\Icons\\inv_misc_bag_satchelofcenarius",
        slotBgColor = { 0.50, 0.50, 0.55, 0.10 },
        dividerAlpha = 0.15,
        iconTint = { 1, 1, 1, 1 },
    },
    elvui = {
        mainBackdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile     = true, tileSize = 16, edgeSize = 1,
            insets   = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.1, 0.1, 0.1, 1 },
        mainBorder = { 0.2, 0.2, 0.2, 1 },
        titleBackdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
        titleBg = { 0.157, 0.239, 0.239, 0.95 },
        -- Ebonhold-style: teal/green buttons (not shared with ElvUI grey).
        btnNormal = { 0.1, 0.3, 0.15, 0.7 },
        titleTextColor = { 0.6, 0.85, 0.85, 1 },
        searchBtnBg = { 0.1, 0.3, 0.15, 0.7 },
        searchBtnHover = { 0.15, 0.4, 0.2, 0.8 },
        scaleBtnDim = { 0.1, 0.3, 0.15, 0.7 },
        scaleBtnBright = { 0.15, 0.4, 0.2, 0.8 },
        collapseBtnDim = { 0.1, 0.3, 0.15, 0.7 },
        collapseBtnBright = { 0.15, 0.4, 0.2, 0.8 },
        statusTextColor = { 0.6, 0.85, 0.85, 1 },
        bottomBarBg = { 0.08, 0.1, 0.12, 0.95 },
        bottomBarBorder = { 0.18, 0.31, 0.31, 0.6 },
        bottomBarTextColor = { 0.6, 0.85, 0.85, 1 },
        sepColor = { 0.18, 0.31, 0.31, 0.4 },
        bagSpaceGlow = { 0.2, 0.5, 0.5, 0.5 },
        -- Registry Expansion:
        slotAlpha = 0.90,
        slotBgTexture = "Interface\\Tooltips\\UI-Tooltip-Background",
        slotBgColor = { 0.06, 0.08, 0.09, 0.90 },
        dividerAlpha = 0.4,
        iconTint = { 1, 1, 1, 1 },
    },
    elvui_real = {
        mainBackdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile     = true, tileSize = 16, edgeSize = 1,
            insets   = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.04, 0.04, 0.04, 1 },
        mainBorder = { 0.10, 0.10, 0.10, 1 },
        titleBackdrop = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = nil, tile = true, tileSize = 16, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
        titleBg = { 0.08, 0.08, 0.08, 1 },
        btnNormal = { 0.18, 0.18, 0.18, 0.9 },
        titleTextColor = { 0.9, 0.9, 0.9, 1 },
        searchBtnBg = { 0.18, 0.18, 0.18, 0.9 },
        searchBtnHover = { 0.26, 0.26, 0.26, 0.95 },
        scaleBtnDim = { 0.18, 0.18, 0.18, 0.9 },
        scaleBtnBright = { 0.30, 0.30, 0.30, 0.95 },
        collapseBtnDim = { 0.18, 0.18, 0.18, 0.9 },
        collapseBtnBright = { 0.30, 0.30, 0.30, 0.95 },
        statusTextColor = { 0.8, 0.8, 0.8, 1 },
        bottomBarBg = { 0.03, 0.03, 0.03, 0.98 },
        bottomBarBorder = { 0.10, 0.10, 0.10, 1 },
        bottomBarTextColor = { 0.8, 0.8, 0.8, 1 },
        sepColor = { 0.25, 0.25, 0.25, 0.5 },
        bagSpaceGlow = { 0.5, 0.5, 0.5, 0.5 },
        -- Registry Expansion:
        slotAlpha = 0.90,
        slotBgTexture = "Interface\\Tooltips\\UI-Tooltip-Background",
        slotBgColor = { 0.06, 0.08, 0.09, 0.90 },
        dividerAlpha = 0.5,
        iconTint = { 1, 1, 1, 1 },
    },
    pimp_purple = {
        mainBackdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile     = true, tileSize = 16, edgeSize = 1,
            insets   = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        mainBg = { 0.30, 0.00, 0.50, 0.58 },
        mainBorder = { 0.75, 0.40, 0.95, 1 },
        titleBackdrop = { bgFile = "Interface\\AddOns\\__FugaziBAGS\\media\\Leopard", edgeFile = nil, tile = true, tileSize = 256, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
        titleBg = { 1, 1, 1, 0.72 },
        btnNormal = { 0.65, 0.45, 0.15, 0.95 },
        titleTextColor = { 1.0, 0.90, 1.0, 1 },
        searchBtnBg = { 0.40, 0.12, 0.60, 0.92 },
        searchBtnHover = { 0.52, 0.20, 0.78, 0.96 },
        scaleBtnDim = { 0.65, 0.45, 0.15, 0.95 },
        scaleBtnBright = { 0.78, 0.58, 0.22, 1 },
        collapseBtnDim = { 0.65, 0.45, 0.15, 0.95 },
        collapseBtnBright = { 0.78, 0.58, 0.22, 1 },
        btnHoverGold = { 0.78, 0.58, 0.22, 1 },
        statusTextColor = { 0.95, 0.85, 1.0, 1 },
        bottomBarBg = { 0.36, 0.26, 0.11, 0.85 },
        bottomBarBorder = { 0.62, 0.45, 0.20, 1 },
        bottomBarTextColor = { 1.0, 0.90, 0.9, 1 },
        sepColor = { 0.70, 0.50, 0.90, 0.5 },
        bagSpaceGlow = { 0.85, 0.50, 0.95, 0.6 },
        -- Registry Expansion:
        slotAlpha = 0.85,
        slotBgTexture = "Interface\\Tooltips\\UI-Tooltip-Background",
        slotBgColor = { 0.20, 0.02, 0.32, 0.85 },
        dividerAlpha = 0.5,
        iconTint = { 1, 1, 1, 1 },
    },
    -- "FUGAZI" skin: based on elvui_real plus your current overrides from gphSkinOverrides.
    fugazi = {
        mainBackdrop = {
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile     = true, tileSize = 16, edgeSize = 1,
            insets   = { left = 0, right = 0, top = 0, bottom = 0 },
        },
        -- From your gphSkinOverrides.mainBg
        mainBg = { 0.10, 0.07, 0.05, 1 },
        mainBorder = { 0.15, 0.12, 0.10, 1 },
        -- Header: washed, scruffy look – custom suede texture tinted dark so it’s unique, not flat ElvUI
        titleBackdrop = { bgFile = "Interface\\AddOns\\__FugaziBAGS\\media\\Suede", edgeFile = nil, tile = true, tileSize = 128, edgeSize = 0, insets = { left = 0, right = 0, top = 0, bottom = 0 } },
        titleBg = { 0.14, 0.11, 0.09, 0.88 },
        btnNormal = { 0.18, 0.18, 0.18, 0.9 },
        -- Use your warm header text colour from gphSkinOverrides.headerTextColor
        titleTextColor = { 1.0, 0.85, 0.65, 1 },
        searchBtnBg = { 0.18, 0.18, 0.18, 0.9 },
        searchBtnHover = { 0.26, 0.26, 0.26, 0.95 },
        scaleBtnDim = { 0.18, 0.18, 0.18, 0.9 },
        scaleBtnBright = { 0.30, 0.30, 0.30, 0.95 },
        collapseBtnDim = { 0.18, 0.18, 0.18, 0.9 },
        collapseBtnBright = { 0.30, 0.30, 0.30, 0.95 },
        statusTextColor = { 1.0, 0.81, 0.58, 1 },
        bottomBarBg = { 0.03, 0.03, 0.03, 0.98 },
        bottomBarBorder = { 0.10, 0.10, 0.10, 1 },
        bottomBarTextColor = { 1.0, 0.81, 0.58, 1 },
        sepColor = { 0.25, 0.25, 0.25, 0.5 },
        bagSpaceGlow = { 0.5, 0.5, 0.5, 0.5 },
        -- Registry Expansion:
        slotAlpha = 0.25,
        slotBgTexture = "Interface\\Buttons\\UI-Quickslot2",
        slotBgColor = { 1, 1, 1, 0.25 },
        dividerAlpha = 0.5,
        iconTint = { 1, 1, 1, 1 },
    },
}

local GPH_CLASS_COLORS = {
    WARRIOR  = { 0.78, 0.61, 0.43 },
    PALADIN  = { 0.96, 0.55, 0.73 },
    HUNTER   = { 0.67, 0.83, 0.45 },
    ROGUE    = { 1.0,  0.96, 0.41 },
    PRIEST   = { 1.0,  1.0,  1.0  },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    SHAMAN   = { 0.0,  0.44, 0.87 },
    MAGE     = { 0.41, 0.8,  0.94 },
    WARLOCK  = { 0.58, 0.51, 0.79 },
    DRUID    = { 1.0,  0.49, 0.04 },
}

local function GetGphPlayerNameTitleAndColor()
    local name = (UnitName and UnitName("player")) or "Player"
    if not name or name == "" then name = "Player" end
    local _, class = UnitClass and UnitClass("player")
    local darken = 0.68
    local r, g, b = 0.65, 0.6, 0.5
    if class and GPH_CLASS_COLORS[class] then
        local c = GPH_CLASS_COLORS[class]
        r = (c[1] or 0.5) * darken
        g = (c[2] or 0.5) * darken
        b = (c[3] or 0.5) * darken
    end
    return name, r, g, b
end

local function ApplyGphInventoryTitle(fs)
    if not fs then return end
    local name, r, g, b = GetGphPlayerNameTitleAndColor()
    fs:SetText(name)
    if r and g and b then
        fs:SetTextColor(r, g, b, 1)
    end
    if A.ApplyToComponent then
        A.ApplyToComponent(fs, "Text", "Title")
    end
end

local function ResolveSkinName()
    local SV = _G.FugaziBAGSDB
    local val = SV and SV.gphSkin or "elvui_real"
    if val == "fugazi" then return "fugazi" end
    if val == "elvui_real" then return "elvui_real" end
    if val == "elvui" then return "elvui" end
    if val == "pimp_purple" then return "pimp_purple" end
    return "elvui_real"
end

--- Adds a 1px border around a button using the given color (used for Search, bag space, and bank bag space so they match).
local function AddBorder(btn, color)
    if not btn then return end
    if not btn._borderTop then
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetHeight(1); t:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); t:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        btn._borderTop = t
        t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetHeight(1); t:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn._borderBottom = t
        t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetWidth(1); t:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); t:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        btn._borderLeft = t
        t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetWidth(1); t:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0); t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn._borderRight = t
    end
    local r, g, b, a = unpack(color or {1,1,1,1})
    local br, bg, bb = r * 1.5, g * 1.5, b * 1.5
    if br > 1 then br = 1 end; if bg > 1 then bg = 1 end; if bb > 1 then bb = 1 end
    btn._borderTop:SetVertexColor(br, bg, bb, 0.8)
    btn._borderBottom:SetVertexColor(br, bg, bb, 0.8)
    btn._borderLeft:SetVertexColor(br, bg, bb, 0.8)
    btn._borderRight:SetVertexColor(br, bg, bb, 0.8)
end

-- Shared Skinning Helpers
local function ResolveColor(key, allOverrides, defaultTbl)
    local ov = allOverrides[key]
    if ov and type(ov) == "table" and #ov >= 3 then
        return ov[1], ov[2], ov[3], ov[4] or 1
    end
    if defaultTbl then return unpack(defaultTbl) end
    return 1, 1, 1, 1
end

local function SetSkinButton(btn, sType)
    if btn and _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyToComponent then
        _G.__FugaziBAGS_Skins.ApplyToComponent(btn, "Button", sType)
    end
end

--- Border for original-skin rarity buttons: when edgeFile/edgeSize given, uses same textured border as main frame; else 2px solid.
--- For the textured border we draw it on a separate frame 2px larger than the button, behind the button (lower frame level),
--- so the button's highlight/click effects don't overlap the border and cause distortion.
local function AddRarityBorder(btn, borderColor, edgeFile, edgeSize)
    if not btn then return end
    if edgeFile and edgeSize then
        -- Don't put backdrop on the button; use a sibling frame so border sits outside and behind.
        if not btn._rarityBorderFrame then
            local parent = btn:GetParent()
            if not parent then return end
            local bf = CreateFrame("Frame", nil, parent)
            bf:SetFrameStrata(btn:GetFrameStrata() or "MEDIUM")
            -- Draw the rarity border slightly ABOVE the button so it isn't hidden behind
            -- the button background, but still separate from the button's own highlight.
            bf:SetFrameLevel((btn:GetFrameLevel() or 1) + 1)
            bf:EnableMouse(false)
            btn._rarityBorderFrame = bf
        end
        local bf = btn._rarityBorderFrame
        bf:ClearAllPoints()
        bf:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
        bf:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
        bf:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = edgeFile,
            tile = true,
            tileSize = 16,
            edgeSize = edgeSize,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        bf:SetBackdropColor(0, 0, 0, 0)
        bf:SetBackdropBorderColor(unpack(borderColor or {0.6, 0.5, 0.2, 0.8}))
        bf:Show()
        if btn._rarityBorderTop then btn._rarityBorderTop:Hide() end
        if btn._rarityBorderBottom then btn._rarityBorderBottom:Hide() end
        if btn._rarityBorderLeft then btn._rarityBorderLeft:Hide() end
        if btn._rarityBorderRight then btn._rarityBorderRight:Hide() end
        return
    end
    -- When switching away from textured border, hide the outer frame so it doesn't linger.
    if btn._rarityBorderFrame then
        btn._rarityBorderFrame:Hide()
        btn._rarityBorderFrame:SetBackdrop(nil)
    end
    local w = 2
    if not btn._rarityBorderTop then
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetHeight(w); t:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); t:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        btn._rarityBorderTop = t
        t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetHeight(w); t:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn._rarityBorderBottom = t
        t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetWidth(w); t:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); t:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        btn._rarityBorderLeft = t
        t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        t:SetWidth(w); t:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0); t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        btn._rarityBorderRight = t
    end
    local r, g, b, a = unpack(borderColor or {0.6, 0.5, 0.2, 0.8})
    btn._rarityBorderTop:SetVertexColor(r, g, b, a)
    btn._rarityBorderBottom:SetVertexColor(r, g, b, a)
    btn._rarityBorderLeft:SetVertexColor(r, g, b, a)
    btn._rarityBorderRight:SetVertexColor(r, g, b, a)
end

--- Central API to apply skinning properties to a component.
--- @param frame table The UI object (Button, Frame, FontString, etc)
--- @param compType string "Header" | "Button" | "Slot" | "Divider" | "Main" | "Text"
--- @param subType string? Optional sub-variant (e.g. "Category", "Search", "Status")
--- @param context string? Additional context (e.g. "Delete")
local function ApplyToComponent(frame, compType, subType, context)
    if not frame then return end
    local skinName = ResolveSkinName()
    local s = SKIN[skinName]
    if not s then return end

    local SV = _G.FugaziBAGSDB
    local allOverrides = (SV and SV.gphSkinOverrides) or {}
    
    local function color(key, defaultTbl)
        return ResolveColor(key, allOverrides, defaultTbl)
    end

    if compType == "Main" then
        local fa = (SV and SV.gphFrameAlpha) or 1
        if fa > 0.99 then fa = 1 end
        frame:SetBackdrop(s.mainBackdrop)
        local r, g, b, a = color("mainBg", s.mainBg)
        frame:SetBackdropColor(r, g, b, a * fa)
        local br, bg, bb, ba = color("mainBorder", s.mainBorder)
        frame:SetBackdropBorderColor(br, bg, bb, (ba or 1) * fa)

        -- Special Pimp Purple background texture
        if skinName == "pimp_purple" then
            if not frame._pimpSuedeTex then
                local tex = frame:CreateTexture(nil, "BACKGROUND")
                tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
                tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                tex:SetTexture("Interface\\AddOns\\__FugaziBAGS\\media\\Suede")
                tex:SetAlpha(0.72 * fa)
                frame._pimpSuedeTex = tex
            end
            frame._pimpSuedeTex:SetAlpha(0.72 * fa)
            frame._pimpSuedeTex:Show()
        else
            if frame._pimpSuedeTex then frame._pimpSuedeTex:Hide() end
        end

    elseif compType == "Header" then
        frame:SetBackdrop(s.titleBackdrop)
        local r, g, b, a = color("titleBg", s.titleBg)
        frame:SetBackdropColor(r, g, b, a)

    elseif compType == "Button" then
        local bg = frame.bg or (frame.GetName and _G[frame:GetName().."bg"])
        if bg then
            local c = s.btnNormal
            if subType == "Search" or subType == "BagSpace" then
                local titleBgFile = (s.titleBackdrop and s.titleBackdrop.bgFile) or "Interface\\Tooltips\\UI-Tooltip-Background"
                bg:SetTexture(titleBgFile)
                c = s.titleBg
            else
                bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            end
            
            if c then
                bg:SetVertexColor(unpack(c))
                AddBorder(frame, c)
            end
        end
        -- Fallback: if no .bg, try to set backdrop if it's a frame
        if not bg and frame.SetBackdrop then
            frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = nil })
            local c = (subType == "Search") and s.titleBg or s.btnNormal
            if c then frame:SetBackdropColor(unpack(c)) end
        end

        -- Set metadata for hover logic
        frame.gphBtnNormal = (subType == "Search") and s.searchBtnBg or (subType == "Rarity" and s.bgFile or s.btnNormal)
        frame.gphBtnHover  = (subType == "Search") and s.searchBtnHover or (subType == "BagSpace" and s.searchBtnHover or (s.btnHoverHighlight or s.searchBtnHover))

        -- Rarity Button specific: handle the special border for original skin
        if subType == "Rarity" then
            if skinName == "original" then
                local bc = s.mainBorder or {0.6, 0.5, 0.2, 0.8}
                AddRarityBorder(frame, bc, s.mainBackdrop.edgeFile, s.mainBackdrop.edgeSize)
            else
                if frame._rarityBorderFrame then frame._rarityBorderFrame:Hide() end
            end
        end

    elseif compType == "Slot" then
        local bg = frame.slotBg
        if bg then
            bg:SetTexture(s.slotBgTexture)
            local r, g, b, a = unpack(s.slotBgColor)
            if subType == "Keyring" and skinName == "original" then
                 bg:SetVertexColor(0.45, 0.52, 0.52, 0.10)
            else
                 bg:SetVertexColor(r, g, b, a)
            end
        end
        if frame.icon then
            local tint = s.iconTint
            if tint then frame.icon:SetVertexColor(unpack(tint)) end
        end

    elseif compType == "Divider" then
        if context == "Delete" then
            frame:SetTexture(0.32, 0.14, 0.14) -- Dark red for delete
            frame:SetAlpha(0.65)
        else
            local r, g, b, a = color("sepColor", s.sepColor)
            frame:SetTexture(r, g, b)
            local alpha = s.dividerAlpha or a or 1
            frame:SetAlpha(alpha)
        end

    elseif compType == "Text" then
        local c = s.statusTextColor
        if subType == "Title" then
            c = s.titleTextColor
        elseif subType == "BottomBar" then
            c = s.bottomBarTextColor
        end
        
        -- Override specific check: Always apply if set, no matter the custom-font toggle
        if subType == "Title" or subType == "Header" or subType == "Search" or subType == "BagSpace" then
            local r, g, b, a = color("headerTextColor", s.titleTextColor)
            if context == "Delete" then 
                -- Autodelete header should ALWAYS be dark red, ignoring customization.
                r, g, b = 0.65, 0.22, 0.22 
                a = a * 0.7 -- Slightly clearer than the default 0.45 wash
            end
            frame:SetTextColor(r, g, b, a)

            -- Apply Header Font
            if A.GetCategoryHeaderFontAndSize then
                local path, size = A.GetCategoryHeaderFontAndSize()
                if subType == "BagSpace" then 
                    size = math.min(12, math.max(6, size - 1))
                elseif subType == "Search" then
                    size = math.min(13, math.max(6, size - 1))
                elseif subType == "Title" then
                    size = size + 1
                end
                frame:SetFont(path, size, "")
            elseif SV and SV.gphCategoryHeaderFontCustom and SV.gphCategoryHeaderFont and SV.gphCategoryHeaderFont ~= "" then
                local path = SV.gphCategoryHeaderFont
                local size = SV.gphCategoryHeaderFontSize or 11
                if subType == "BagSpace" then 
                    size = math.min(12, math.max(6, size - 1))
                elseif subType == "Search" then
                    size = math.min(13, math.max(6, size - 1))
                elseif subType == "Title" then 
                    size = size + 1 
                end
                frame:SetFont(path, size, "")
            end

            -- Fugazi Aesthetic: Washed/Worn look for headers
            if skinName == "fugazi" and not (SV and SV.gphCategoryHeaderFontCustom) then
                frame:SetAlpha(0.85) -- Subtle wash for the thematic feel
            end
        elseif c then
            frame:SetTextColor(unpack(c))
        end
    elseif compType == "Row" then
        if not frame.bg then
            local bg = frame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
            frame.bg = bg
        end
        local r, g, b, a = color("mainBg", s.mainBg)
        if subType == "Item" then
            -- Item rows are slightly lighter or darker than the main background for contrast
            local rowAlpha = (s.slotAlpha or 0.1) * 0.5
            frame.bg:SetVertexColor(r, g, b, rowAlpha)
            if frame.rowHighlight then
                local hr, hg, hb = 1, 1, 1
                if s.btnNormal then hr, hg, hb = s.btnNormal[1], s.btnNormal[2], s.btnNormal[3] end
                frame.rowHighlight:SetVertexColor(hr, hg, hb, 0.12)
            end
        end
    end

    -- Special BagSpace components (glow)
    if subType == "BagSpace" and frame.glow then
        local gc = s.bagSpaceGlow or { 1, 0.85, 0.2, 0.5 }
        frame.glow:SetVertexColor(unpack(gc))
    end
end

local function SkinScrollBar(self)
    if not self then return end
    local name = self:GetName()
    if not name then return end

    local scrollbar = _G[name.."ScrollBar"]
    if not scrollbar then return end

    -- Aggressively hide standard Blizzard buttons (up/down arrows)
    local up = _G[name.."ScrollBarScrollUpButton"]
    local down = _G[name.."ScrollBarScrollDownButton"]
    if up then 
        up:Hide(); up:SetAlpha(0); up:EnableMouse(false) 
        if up:GetNormalTexture() then up:GetNormalTexture():SetTexture(nil) end
        if up:GetPushedTexture() then up:GetPushedTexture():SetTexture(nil) end
    end
    if down then 
        down:Hide(); down:SetAlpha(0); down:EnableMouse(false) 
        if down:GetNormalTexture() then down:GetNormalTexture():SetTexture(nil) end
        if down:GetPushedTexture() then down:GetPushedTexture():SetTexture(nil) end
    end

    -- Clear all legacy textures from the scrollbar frame itself
    for i = 1, scrollbar:GetNumRegions() do
        local region = select(i, scrollbar:GetRegions())
        if region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
        end
    end

    -- Add flat vertical rail (the groove)
    if not scrollbar.bg then
        local bg = scrollbar:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", scrollbar, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", scrollbar, "BOTTOMRIGHT", 0, 0)
        bg:SetTexture(0, 0, 0, 0.4) -- Semi-transparent dark rail
        scrollbar.bg = bg
    end

    -- Add sleek flat thumb
    local thumb = scrollbar:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
        thumb:SetWidth(12)
        -- Color it dynamically based on the header text color settings
        local skinName = ResolveSkinName()
        local s = SKIN[skinName]
        local SV = _G.FugaziBAGSDB
        local overrides = (SV and SV.gphSkinOverrides) or {}
        local ov = overrides.headerTextColor

        local r, g, b, a = 0.2, 0.6, 0.5, 0.8 -- Default fallback
        if ov and type(ov) == "table" and #ov >= 3 then
            r, g, b, a = ov[1], ov[2], ov[3], (ov[4] or 1) * 0.8
        elseif s and s.titleTextColor then
            local c = s.titleTextColor
            r, g, b, a = c[1], c[2], c[3], (c[4] or 1) * 0.8
        end
        thumb:SetVertexColor(r, g, b, a)
    end
end

local function ApplyGPHFrameSkin(f)
    if not f then return end
    local skinName = ResolveSkinName()
    local s = SKIN[skinName]
    if not s then return end

    local SV = _G.FugaziBAGSDB
    local allOverrides = (SV and SV.gphSkinOverrides) or {}
    
    local function color(key, defaultTbl)
        return ResolveColor(key, allOverrides, defaultTbl)
    end

    -- Apply Main Frame Skin
    ApplyToComponent(f, "Main")

    -- Title Bar
    if f.gphTitleBar then
        ApplyToComponent(f.gphTitleBar, "Header")
        if f.gphTitleBar._fugaziEpicOverlay then f.gphTitleBar._fugaziEpicOverlay:Hide() end
    end

    -- Title Text
    if f.gphTitle then
        ApplyGphInventoryTitle(f.gphTitle)
        ApplyToComponent(f.gphTitle, "Text", "Title")
        f.gphTitle:Show()
    end

    -- Standard Buttons
    SetSkinButton(f.gphSortBtn)
    SetSkinButton(f.gphScaleBtn)
    SetSkinButton(f.gphInvBtn)
    SetSkinButton(f.gphSummonBtn)

    -- Profession buttons (Special case: Never have backgrounds)
    local function clearProfBtn(btn)
        if btn then
            if btn.bg then btn.bg:SetTexture(nil); btn.bg:SetAlpha(0) end
            if btn._borderTop then btn._borderTop:Hide() end
            if btn._borderBottom then btn._borderBottom:Hide() end
            if btn._borderLeft then btn._borderLeft:Hide() end
            if btn._borderRight then btn._borderRight:Hide() end
        end
    end
    clearProfBtn(f.gphDestroyBtn)
    clearProfBtn(f.gphMailBtn)

    -- Sync global hover colors for legacy consumers
    f.gphTitleBarBtnNormal = s.btnNormal
    f.gphTitleBarBtnHover  = s.searchBtnHover
    if skinName == "pimp_purple" then
        f.gphTitleBarBtnNormal = { 0.65, 0.45, 0.15, 0.95 } -- goldTop
        f.gphTitleBarBtnHover  = s.btnHoverGold or { 0.78, 0.58, 0.22, 1 }
    end

    -- Scale Button specifically needs brightness state
    f.gphScaleBtnDim = s.scaleBtnDim or { 0.1, 0.3, 0.15, 0.7 }
    f.gphScaleBtnBright = s.scaleBtnBright or { 0.15, 0.4, 0.2, 0.8 }
    if f.gphScaleBtn and f.gphScaleBtn.bg then
        local scale = (SV and SV.gphScale15) and f.gphScaleBtnDim or f.gphScaleBtnBright
        if scale then f.gphScaleBtn.bg:SetTexture(unpack(scale)) end
    end

    -- Search Button
    if f.gphSearchBtn then
        SetSkinButton(f.gphSearchBtn, "Search")
        f.gphSearchBtnNormal = s.titleBg
        f.gphSearchBtnHover = s.searchBtnHover
    end
    if f.gphSearchLabel then ApplyToComponent(f.gphSearchLabel, "Text", "Search") end

    -- Bag Space Button
    if f.gphBagSpaceBtn then
        SetSkinButton(f.gphBagSpaceBtn, "BagSpace")
        if f.gphBagSpaceBtn.fs then ApplyToComponent(f.gphBagSpaceBtn.fs, "Text", "BagSpace") end
    end

    -- Legacy metadata for Rarity System
    f._useOriginalRarityStyle = (skinName == "original")
    f._originalTitleBg = (skinName == "original" and s.titleBg) and s.titleBg or nil
    f._originalMainBorder = (skinName == "original" and s.mainBorder) and s.mainBorder or nil
    local mb = (skinName == "original" and s.mainBackdrop) and s.mainBackdrop or nil
    f._originalEdgeFile = (mb and mb.edgeFile) and mb.edgeFile or nil
    f._originalEdgeSize = (mb and mb.edgeSize) and math.min(12, mb.edgeSize) or 8
    f._gphHeaderBgFile = (s.titleBackdrop and s.titleBackdrop.bgFile) or "Interface\\Tooltips\\UI-Tooltip-Background"

    -- Bottom Bar
    if f.gphBottomBar then
        local defaultBottomBackdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 16, edgeSize = 8,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        }
        if skinName == "pimp_purple" then
            if f._fugaziBottomLeopard then f._fugaziBottomLeopard:Hide() end
            f.gphBottomBar:SetBackdrop(defaultBottomBackdrop)
            if s.bottomBarBg then f.gphBottomBar:SetBackdropColor(unpack(s.bottomBarBg)) end
            if s.bottomBarBorder then f.gphBottomBar:SetBackdropBorderColor(unpack(s.bottomBarBorder)) end
            
            if not f._pimpBottomLeopard then
                local lb = f.gphBottomBar:CreateTexture(nil, "BACKGROUND")
                lb:SetPoint("TOPLEFT", f.gphBottomBar, "TOPLEFT", 0, 0)
                lb:SetPoint("BOTTOMRIGHT", f.gphBottomBar, "BOTTOMRIGHT", 0, 0)
                lb:SetTexture("Interface\\AddOns\\__FugaziBAGS\\media\\Leopard")
                lb:SetTexCoord(0, 1, 0.0, 20.0 / 256.0)
                lb:SetAlpha(0.72)
                f._pimpBottomLeopard = lb
            else
                f._pimpBottomLeopard:SetTexCoord(0, 1, 0.0, 20.0 / 256.0)
                f._pimpBottomLeopard:Show()
            end
        elseif skinName == "fugazi" then
            if f._pimpBottomLeopard then f._pimpBottomLeopard:Hide() end
            f.gphBottomBar:SetBackdrop(s.titleBackdrop)
            f.gphBottomBar:SetBackdropColor(unpack(s.titleBg))
            if s.bottomBarBorder then f.gphBottomBar:SetBackdropBorderColor(unpack(s.bottomBarBorder)) end
        else
            if f._pimpBottomLeopard then f._pimpBottomLeopard:Hide() end
            if f._fugaziBottomLeopard then f._fugaziBottomLeopard:Hide() end
            f.gphBottomBar:SetBackdrop(defaultBottomBackdrop)
            if s.bottomBarBg then f.gphBottomBar:SetBackdropColor(unpack(s.bottomBarBg)) end
            if s.bottomBarBorder then f.gphBottomBar:SetBackdropBorderColor(unpack(s.bottomBarBorder)) end
        end
        if f.gphBottomBar._fugaziEpicOverlay then f.gphBottomBar._fugaziEpicOverlay:Hide() end
    end

    -- Bottom Bar Texts
    if s.bottomBarTextColor then
        if f.gphBottomLeft then f.gphBottomLeft:SetTextColor(unpack(s.bottomBarTextColor)) end
        if f.gphBottomCenter then f.gphBottomCenter:SetTextColor(unpack(s.bottomBarTextColor)) end
        if f.gphBottomRight then f.gphBottomRight:SetTextColor(unpack(s.bottomBarTextColor)) end
    end

    -- Divider
    if f.gphSep then
        ApplyToComponent(f.gphSep, "Divider")
    end

    -- Status Text
    if f.statusText then
        ApplyToComponent(f.statusText, "Text", "Status")
    end

    do local r, g, b, a = color("headerTextColor", s.titleTextColor); f.gphAccentTextColor = { r, g, b, a } end
    if f.updateToggle then f.updateToggle() end
    -- Clean up the old layered background alpha system
    if f._gphAlphaBg then
        f._gphAlphaBg:Hide()
        f._gphAlphaBg:SetAlpha(0)
    end

    -- Refresh scrollbar thumb coloration if it exists
    if f.scrollFrame then
        SkinScrollBar(f.scrollFrame)
    end
end

local function ApplyBankFrameSkin(f)
    if not f then return end
    local skinName = ResolveSkinName()
    local s = SKIN[skinName]
    if not s then return end

    local SV = _G.FugaziBAGSDB
    local allOverrides = (SV and SV.gphSkinOverrides) or {}
    
    local function color(key, defaultTbl)
        return ResolveColor(key, allOverrides, defaultTbl)
    end

    -- Apply Main Frame Skin
    ApplyToComponent(f, "Main")

    -- Title Bar
    if f.titleBar then
        ApplyToComponent(f.titleBar, "Header")
    end

    -- Title Text
    if f.bankTitleText then
        ApplyToComponent(f.bankTitleText, "Text", "Title")
    end

    -- Buttons
    SetSkinButton(f.purchaseBtn)
    SetSkinButton(f.toggleBtn)
    SetSkinButton(f.bankSortBtn)

    -- Divider
    if f.sep then
        ApplyToComponent(f.sep, "Divider")
    end

    -- Rarity Buttons (Bank)
    if f.bankQualityButtons then
        for q, btn in pairs(f.bankQualityButtons) do
            ApplyToComponent(btn, "Button", "Rarity")
        end
    end

    -- Bank Space Button
    if f.bankSpaceBtn then
        SetSkinButton(f.bankSpaceBtn, "BagSpace")
        if f.bankSpaceBtn.fs then 
            ApplyToComponent(f.bankSpaceBtn.fs, "Text", "BagSpace") 
        end
        do 
            local r, g, b, a = color("headerTextColor", s.titleTextColor)
            f.bankSpaceTextColor = { r, g, b, a }
            f.gphAccentTextColor = { r, g, b, a }
        end
    end

    -- Legacy metadata
    f._useOriginalRarityStyle = (skinName == "original")
    f._originalTitleBg = (skinName == "original" and s.titleBg) and s.titleBg or nil
    f._gphHeaderBgFile = (s.titleBackdrop and s.titleBackdrop.bgFile) or "Interface\\Tooltips\\UI-Tooltip-Background"
    f._originalMainBorder = (skinName == "original" and s.mainBorder) and s.mainBorder or nil
    local mb = (skinName == "original" and s.mainBackdrop) and s.mainBackdrop or nil
    f._originalEdgeFile = (mb and mb.edgeFile) and mb.edgeFile or nil
    f._originalEdgeSize = (mb and mb.edgeSize) and math.min(12, mb.edgeSize) or 8

    -- Button Hover metadata
    f.bankBtnNormal = s.btnNormal
    if skinName == "pimp_purple" then
        f.bankBtnNormal = { 0, 0, 0, 0 }
        f.bankBtnHover = { 0, 0, 0, 0 }
    else
        f.bankBtnHover = s.searchBtnHover or s.searchBtnBg
    end

    -- Refresh scrollbar thumb coloration if it exists
    if f.scroll then
        SkinScrollBar(f.scroll)
    end
end




--- Full "FUGAZI" preset: when a user selects the FUGAZI skin, apply these DB options so they get
--- the same look — fonts, font sizes, icon size, hide options, frame opacity, and all colors.
function ApplyFugaziPreset()
    local SV = _G.FugaziBAGSDB
    if not SV then return end
    SV.gphSkin = "fugazi"
    SV.gphFrameAlpha = 0.95
    -- Header / category: font, size, enable customisation
    SV.gphCategoryHeaderFontCustom = true
    SV.gphCategoryHeaderFont = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\AncientModernTales.ttf"
    SV.gphCategoryHeaderFontSize = 12
    -- Row / item details: font (Eight Bit Dragon), font size 15, icon size, opacity 100%, enable customisation
    SV.gphItemDetailsCustom = true
    SV.gphItemDetailsFont = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\EightBitDragon.ttf"
    SV.gphItemDetailsFontSize = 15
    SV.gphItemDetailsIconSize = 14
    SV.gphItemDetailsAlpha = 1
    -- Visibility
    SV.gphHideIconsInList = true
    SV.gphHideTopButtons = true
    SV.gphBankHideTopButtons = true
    -- Colors (header text, FIT row label, item icon tint, frame background)
    SV.gphSkinOverrides = {
        fitRowColor = { 1, 0.945, 0.89, 1 },
        headerTextColor = { 1, 0.808, 0.584, 1 },
        itemDetailsIconColor = { 0.965, 1, 0.953, 1 },
        mainBg = { 0.082, 0.039, 0.004, 1 },
    }
end

-- Expose for FugaziBAGS.lua (AddBorder for Search/bag; AddRarityBorder for original-skin rarity buttons)
_G.__FugaziBAGS_Skins = {
    SKIN = SKIN,
    ApplyGPHFrameSkin = ApplyGPHFrameSkin,
    ApplyBankFrameSkin = ApplyBankFrameSkin,
    ApplyGphInventoryTitle = ApplyGphInventoryTitle,
    SkinScrollBar = SkinScrollBar,
    AddBorder = AddBorder,
    AddRarityBorder = AddRarityBorder,
    ApplyFugaziPreset = ApplyFugaziPreset,
    ApplyToComponent = ApplyToComponent,
}
_G.ApplyFugaziPreset = ApplyFugaziPreset

