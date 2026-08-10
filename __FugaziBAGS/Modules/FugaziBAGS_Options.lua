--[[
  FugaziBAGS_Options.lua
  All Interface > AddOns option panels: Main, Scale & Layout, Skins, Valuation, Instructions.
  Preferences are per-character (see FugaziBAGS_Config hydrate/snapshot/copy).
]]

_G.FugaziBAGS = _G.FugaziBAGS or {}
local Addon = _G.FugaziBAGS
local A = Addon
local DB = _G.FugaziBAGSDB
local Skins = _G.__FugaziBAGS_Skins or {}
local RefreshGPHUI = _G.RefreshGPHUI
-- Prefer live global at call time (Bankview may assign after first read in odd load orders).
local function RefreshBankUI(force)
    local fn = _G.RefreshBankUI
    if fn then
        return fn(force)
    end
end

--- Options chrome that changes row/list appearance must force bank list rebuild
--- (smart NOOP path skips paint when bag contents are unchanged).
local function ForceRefreshBankUI()
    local bf = A.Bank
    if bf then
        bf._bankForceFull = true
    end
    RefreshBankUI(true)
end

local gphCopySourceKey
-- Forward-declared so copy buttons can refresh the list before the function body is assigned.
local RefreshDelListPanel

local function SetFugaziControlEnabled(frame, enabled)
    if not frame then
        return
    end
    local a = enabled and 1.0 or 0.3

    -- Special handling for Dropdowns to avoid the "Ghosting" of original blizzard textures
    -- we only dim the custom Proxy and the Text.
    if frame.proxy then
        frame:SetAlpha(0) -- Always hide the original
        frame.proxy:SetAlpha(a)
        frame.proxy:EnableMouse(enabled)
        if frame.proxy.text then
            frame.proxy.text:SetAlpha(a)
        end
    else
        frame:SetAlpha(a)
    end

    if frame.Enable then
        if enabled then
            frame:Enable()
        else
            frame:Disable()
        end
    end
    if frame.EnableMouse then
        frame:EnableMouse(enabled)
    end

    -- Handle child elements (Sliders and Checkboxes)
    if frame._valText then
        frame._valText:SetAlpha(a)
    end
    local fName = (frame.GetName and frame:GetName())
    if fName then
        if _G[fName .. "Text"] then
            _G[fName .. "Text"]:SetAlpha(a)
        end
        if _G[fName .. "Low"] then
            _G[fName .. "Low"]:SetAlpha(a)
        end
        if _G[fName .. "High"] then
            _G[fName .. "High"]:SetAlpha(a)
        end
    end
    if frame._swatch then
        frame._swatch:SetVertexColor(1, 1, 1, a)
    end
end

local function SkinSlider(s)
    if not s then
        return
    end
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    s:SetBackdropColor(0, 0, 0, 0.65)
    s:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)

    local name = s:GetName()
    if _G[name .. "Low"] then
        _G[name .. "Low"]:SetTextColor(0.5, 0.5, 0.5)
    end
    if _G[name .. "High"] then
        _G[name .. "High"]:SetTextColor(0.5, 0.5, 0.5)
    end

    local thumb = s:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(10, 14)
        thumb:SetVertexColor(0.9, 0.1, 0.1, 1)
    end
end

local function SkinButton(btn)
    if not btn then
        return
    end
    btn:SetNormalTexture("")
    btn:SetPushedTexture("")
    btn:SetHighlightTexture("")
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    btn:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8)
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    end)
    if btn:GetFontString() then
        btn:GetFontString():SetTextColor(1, 0.8, 0.4)
    end
end

local function SkinCheckBox(cb)
    if not cb then
        return
    end
    cb:SetNormalTexture("")
    cb:SetPushedTexture("")
    cb:SetHighlightTexture("")
    cb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    cb:SetBackdropColor(0, 0, 0, 0.5)
    cb:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    local check = cb:GetCheckedTexture()
    if check then
        check:SetTexture("Interface\\Buttons\\WHITE8X8")
        check:SetVertexColor(0.8, 0.2, 0.2, 0.8)
        check:SetPoint("TOPLEFT", 4, -4)
        check:SetPoint("BOTTOMRIGHT", -4, 4)
    end
end

local function CreateSectionBg(parent, x, y, w, h)
    local bg = CreateFrame("Frame", nil, parent)
    bg:SetFrameLevel(parent:GetFrameLevel() - 1)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    bg:SetSize(w, h)
    bg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bg:SetBackdropColor(0.15, 0.15, 0.15, 0.25)
    bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.15)
    return bg
end

local function RefreshAllUI()
    -- Options/sliders: bypass inv 0.15s throttle so inv keeps up with bank (bank has none).
    local inv = A.Inventory
    if inv then
        inv._refreshImmediate = true
        inv._refreshLevel = 3
    end
    -- Skin first, then rebuild rows so icon/font/alpha pick up the new values in one pass.
    if _G.ApplyTestSkin then
        _G.ApplyTestSkin()
    end
    if RefreshGPHUI then
        RefreshGPHUI(3)
    end
    -- Force bank: smart list NOOP would skip row chrome (icon/font/alpha) when contents unchanged.
    ForceRefreshBankUI()
    local cg = _G.FugaziBAGS_CombatGrid
    if cg then
        if cg.IsShown and cg.IsShown() and cg.LayoutGrid then
            cg.LayoutGrid()
        end
        if cg.IsBankShown and cg.IsBankShown() and cg.BankLayoutGrid then
            cg.BankLayoutGrid()
        end
        if cg.RefreshSlots then
            cg.RefreshSlots(true)
        end
        if cg.BankRefreshSlots then
            cg.BankRefreshSlots(true)
        end
    end
    if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then
        _G.FugaziInstanceTracker_RefreshSkinFromBAGS()
    end
end

local function CreateFugaziSlider(parent, name, label, min, max, step, key, default, x, y, isFloat, tooltipText)
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    s:SetWidth(130)

    local displayMin = isFloat and min or math.floor(min)
    local displayMax = isFloat and max or math.floor(max)

    if isFloat then
        s:SetMinMaxValues(min * 100, max * 100)
        s:SetValueStep(step * 100)
    else
        s:SetMinMaxValues(min, max)
        s:SetValueStep(step)
    end

    if s.SetObeyStepOnDrag then
        s:SetObeyStepOnDrag(true)
    end
    SkinSlider(s)

    local titleFs = _G[name .. "Text"]
    titleFs:SetJustifyH("CENTER")
    titleFs:SetPoint("BOTTOM", s, "TOP", 0, 2)
    titleFs:SetText(label)

    local lowFs = _G[name .. "Low"]
    lowFs:SetText(tostring(displayMin))
    lowFs:ClearAllPoints()
    lowFs:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -2)

    local highFs = _G[name .. "High"]
    highFs:SetText(tostring(displayMax))
    highFs:ClearAllPoints()
    highFs:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", 0, -2)

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    val:SetPoint("TOP", s, "BOTTOM", 0, -2)
    s._valText = val

    s:SetScript("OnValueChanged", function(self, v)
        if self._isRefreshing then
            return
        end
        local value
        if isFloat then
            value = math.floor(v + 0.5) / 100
            self._valText:SetText(("%.2f"):format(value))
        else
            value = math.floor(v + 0.5)
            self._valText:SetText(tostring(value))
        end

        -- Use the new Centralized Config API (Triggers listeners automatically)
        A.SetOption(key, value)

        -- Frame opacity: only re-apply alpha (full RefreshAllUI every tick = header flicker + churn).
        if key == "gphFrameAlpha" then
            if A.ApplyFrameAlpha then
                if A.Inventory then
                    A.ApplyFrameAlpha(A.Inventory)
                end
                if A.Bank then
                    A.ApplyFrameAlpha(A.Bank)
                end
            end
            return
        end
        -- Header font size: TEXT ONLY — never full ApplyGPHFrameSkin / L3 chrome.
        -- Full chrome re-skinned search, bag-space, and rarity buttons every slider tick (flicker).
        if key == "gphCategoryHeaderFontSize" then
            local Skins = _G.__FugaziBAGS_Skins
            local applyText = function(fs, subType)
                if fs and Skins and Skins.ApplyToComponent then
                    Skins.ApplyToComponent(fs, "Text", subType)
                end
            end
            if A.Inventory then
                -- Force bag-space fit code to re-read the new base size.
                A.Inventory._bagSpaceFontBase = nil
                if Skins and Skins.ApplyGphInventoryTitle and A.Inventory.gphTitle then
                    Skins.ApplyGphInventoryTitle(A.Inventory.gphTitle)
                end
                applyText(A.Inventory.gphTitle, "Title")
                applyText(A.Inventory.gphSearchLabel, "Search")
                if A.Inventory.gphBagSpaceBtn and A.Inventory.gphBagSpaceBtn.fs then
                    applyText(A.Inventory.gphBagSpaceBtn.fs, "BagSpace")
                end
            end
            if A.Bank then
                A.Bank._bagSpaceFontBase = nil
                applyText(A.Bank.bankTitleText, "Title")
                if A.Bank.bankSpaceBtn and A.Bank.bankSpaceBtn.fs then
                    applyText(A.Bank.bankSpaceBtn.fs, "BagSpace")
                elseif A.Bank.bankSpaceFs then
                    applyText(A.Bank.bankSpaceFs, "BagSpace")
                end
            end
            -- L1 list paint only: category divider labels pick up size; no rarity re-layout.
            if A.Inventory then
                A.Inventory._refreshImmediate = true
                if A.PromoteGPHRefreshLevel then
                    A.PromoteGPHRefreshLevel(1)
                end
            end
            if RefreshGPHUI then
                RefreshGPHUI(1)
            end
            ForceRefreshBankUI()
            return
        end
        -- Row icon/font/alpha: list content only (no L3 skin/negotiate every slider tick).
        if key == "gphItemDetailsIconSize" or key == "gphItemDetailsFontSize" or key == "gphItemDetailsAlpha" then
            local inv = A.Inventory
            if inv then
                inv._refreshImmediate = true
                if A.PromoteGPHRefreshLevel then
                    A.PromoteGPHRefreshLevel(1)
                end
            end
            if RefreshGPHUI then
                RefreshGPHUI(1)
            end
            ForceRefreshBankUI()
            return
        end
        -- Safety: Call RefreshAllUI for any setting that doesn't have a listener yet.
        if RefreshAllUI then
            RefreshAllUI()
        end
    end)

    if tooltipText then
        s:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 0.8, 0)
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local init = default
    if A.GetOption then
        local v = A.GetOption(key)
        if v ~= nil then
            init = v
        end
    else
        local SV = _G.FugaziBAGSDB
        if SV and SV[key] ~= nil then
            init = SV[key]
        end
    end
    s._isRefreshing = true
    if isFloat then
        s:SetValue(init * 100)
        s._valText:SetText(("%.2f"):format(init))
    else
        s:SetValue(init)
        s._valText:SetText(tostring(init))
    end
    s._isRefreshing = false

    s._key = key
    s._default = default
    return s
end

local function SkinEditBox(eb)
    if not eb then
        return
    end
    eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    eb:SetBackdropColor(0, 0, 0, 0.5)
    eb:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    local name = eb:GetName()
    if name then
        if _G[name .. "Left"] then
            _G[name .. "Left"]:Hide()
        end
        if _G[name .. "Middle"] then
            _G[name .. "Middle"]:Hide()
        end
        if _G[name .. "Right"] then
            _G[name .. "Right"]:Hide()
        end
    end
    eb:SetTextInsets(6, 6, 0, 0)
end

local function SkinDropDown(dd)
    if not dd then
        return
    end
    local name = dd:GetName()
    if not name then
        return
    end

    dd:SetAlpha(0)
    dd:SetSize(1, 1)

    if not dd.proxy then
        local proxy = CreateFrame("Button", name .. "Proxy", dd:GetParent())
        proxy:SetSize(dd:GetWidth() > 20 and dd:GetWidth() or 180, 22)
        proxy:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        proxy:SetBackdropColor(0.06, 0.06, 0.06, 1)
        proxy:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        local text = proxy:CreateFontString(nil, "OVERLAY")
        text:SetFont("Fonts\\ARIALN.TTF", 12)
        text:SetPoint("LEFT", 6, 0)
        text:SetPoint("RIGHT", -24, 0)
        text:SetJustifyH("LEFT")
        text:SetTextColor(1, 1, 1)
        proxy.text = text

        local arrow = proxy:CreateFontString(nil, "OVERLAY")
        arrow:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        arrow:SetText("▼")
        arrow:SetPoint("RIGHT", -6, 0)
        arrow:SetTextColor(0.8, 0.8, 0.8)

        proxy:SetScript("OnClick", function(self)
            _G.ToggleDropDownMenu(1, nil, dd, self, 0, 0)
        end)

        hooksecurefunc("UIDropDownMenu_SetText", function(frame, value)
            if frame == dd then
                proxy.text:SetText(value)
            end
        end)

        local originalText = _G[name .. "Text"]
        if originalText then
            proxy.text:SetText(originalText:GetText() or "")
        end

        dd.proxy = proxy
    end

    dd.proxy:ClearAllPoints()
    dd.proxy:SetPoint("TOPLEFT", dd, "TOPLEFT", 6, -2)
    dd.proxy:Show()
end

local function SkinScrollBar(sb)
    if not sb then
        return
    end
    local name = sb:GetName()
    if not name then
        return
    end

    if _G[name .. "BG"] then
        _G[name .. "BG"]:Hide()
    end
    if _G[name .. "Top"] then
        _G[name .. "Top"]:Hide()
    end
    if _G[name .. "Bottom"] then
        _G[name .. "Bottom"]:Hide()
    end
    if _G[name .. "Middle"] then
        _G[name .. "Middle"]:Hide()
    end

    local up = _G[name .. "ScrollUpButton"]
    local down = _G[name .. "ScrollDownButton"]
    if up then
        up:Hide()
    end
    if down then
        down:Hide()
    end

    local thumb = sb:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(8, 32)
        thumb:SetVertexColor(0.8, 0.2, 0.2, 0.8)
    end
end

local function CreateOptionsPanel()
    if _G.FugaziBAGSOptionsPanel then
        return
    end
    local panel = CreateFrame("Frame", "FugaziBAGSOptionsPanel", UIParent)
    panel.name = "_FugaziBAGS"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end
    panel.refresh = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("_FugaziBAGS")

    local function AttachSimpleTip(widget, titleText, bodyText)
        widget:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(titleText, 1, 0.8, 0)
            GameTooltip:AddLine(bodyText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        widget:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    local cbDel = CreateFrame("CheckButton", "FugaziBAGSConfirmDelCheck", panel, "OptionsCheckButtonTemplate")
    cbDel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -24)
    SkinCheckBox(cbDel)
    _G["FugaziBAGSConfirmDelCheckText"]:SetText("Confirm Auto Delete")
    cbDel:SetScript("OnClick", function(self)
        if A.SetOption then
            A.SetOption("gridConfirmAutoDel", self:GetChecked() == 1 or self:GetChecked() == true)
        end
    end)
    AttachSimpleTip(
        cbDel,
        "Confirm Auto Delete",
        "Ask for confirmation before adding items to your auto-delete list when you delete them from bags."
    )

    local cbAutosell =
        CreateFrame("CheckButton", "FugaziBAGSAutosellEverythingCheck", panel, "OptionsCheckButtonTemplate")
    cbAutosell:SetPoint("LEFT", cbDel, "RIGHT", 180, 0)
    SkinCheckBox(cbAutosell)
    _G["FugaziBAGSAutosellEverythingCheckText"]:SetText("Autosell EVERYTHING!")
    cbAutosell:SetScript("OnClick", function(self)
        if self:GetChecked() then
            self:SetChecked(false)
            StaticPopup_Show("GPH_AUTOSELL_EVERYTHING_WARN")
        else
            if A.SetPerChar then
                A.SetPerChar("gphAutosellEverything", false)
            elseif A.SetOption then
                A.SetOption("gphAutosellEverything", false)
            end
        end
    end)
    AttachSimpleTip(
        cbAutosell,
        "Autosell EVERYTHING!",
        "At vendors, automatically sell every unprotected item of Rare quality or lower (gear, mats, consumables — not just greys). Dangerous; use with Protect Previously Worn."
    )

    local cbProtectWorn = CreateFrame("CheckButton", "FugaziBAGSProtectWornCheck", panel, "OptionsCheckButtonTemplate")
    cbProtectWorn:SetPoint("LEFT", cbAutosell, "RIGHT", 180, 0)
    SkinCheckBox(cbProtectWorn)
    _G["FugaziBAGSProtectWornCheckText"]:SetText("Protect Previously Worn")
    cbProtectWorn:SetScript("OnClick", function(self)
        if A.SetPerChar then
            A.SetPerChar("gphProtectPreviouslyWorn", self:GetChecked() == 1 or self:GetChecked() == true)
        elseif A.SetOption then
            A.SetOption("gphProtectPreviouslyWorn", self:GetChecked() == 1 or self:GetChecked() == true)
        end
        if _G.RefreshGPHUI then
            _G.RefreshGPHUI()
        end
        if _G.RefreshBankUI then
            _G.RefreshBankUI()
        end
    end)
    AttachSimpleTip(
        cbProtectWorn,
        "Protect Previously Worn",
        "Keeps gear this character has worn safe from vendoring, disenchanting, and deleting."
    )

    local cbAutoConfirmBOP =
        CreateFrame("CheckButton", "FugaziBAGSAutoConfirmBOPCheck", panel, "OptionsCheckButtonTemplate")
    cbAutoConfirmBOP:SetPoint("TOPLEFT", cbProtectWorn, "BOTTOMLEFT", 0, -8)
    SkinCheckBox(cbAutoConfirmBOP)
    _G["FugaziBAGSAutoConfirmBOPCheckText"]:SetText("Auto Confirm BoP")
    cbAutoConfirmBOP:SetScript("OnClick", function(self)
        if A.SetOption then
            A.SetOption("gphAutoConfirmBOP", self:GetChecked() == 1 or self:GetChecked() == true)
        end
    end)
    AttachSimpleTip(
        cbAutoConfirmBOP,
        "Auto Confirm BoP",
        "Automatically accept Bind-on-Pickup confirmation popups when looting or rolling on BoP items."
    )

    local cbAutoQuest =
        CreateFrame("CheckButton", "FugaziBAGSAutoQuestGossipCheck", panel, "OptionsCheckButtonTemplate")
    cbAutoQuest:SetPoint("TOPLEFT", cbAutosell, "BOTTOMLEFT", 0, -8)
    SkinCheckBox(cbAutoQuest)
    _G["FugaziBAGSAutoQuestGossipCheckText"]:SetText("Auto Quest / Gossip")
    cbAutoQuest:SetScript("OnClick", function(self)
        if A.SetOption then
            A.SetOption("gphAutoQuestGossip", self:GetChecked() == 1 or self:GetChecked() == true)
        end
    end)
    AttachSimpleTip(
        cbAutoQuest,
        "Auto Quest / Gossip",
        "Automatically accept and turn in quests, and skip normal NPC gossip text."
    )

    local cbSound = CreateFrame("CheckButton", "FugaziBAGSClickSoundCheck", panel, "OptionsCheckButtonTemplate")
    cbSound:SetPoint("TOPLEFT", cbDel, "BOTTOMLEFT", 0, -8)
    SkinCheckBox(cbSound)
    _G["FugaziBAGSClickSoundCheckText"]:SetText("Play sounds")
    cbSound:SetScript("OnClick", function(self)
        if A.SetOption then
            A.SetOption("gphClickSound", self:GetChecked() == 1 or self:GetChecked() == true)
        end
    end)
    AttachSimpleTip(cbSound, "Play sounds", "Play click / UI sounds when using this addon.")

    -- Character Copy Section (auto-delete list + full settings)
    local copyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    copyLabel:SetPoint("TOPLEFT", cbSound, "BOTTOMLEFT", 0, -18)
    copyLabel:SetText("Copy from character:")

    local copyHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    copyHint:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", 0, -2)
    copyHint:SetText("Pick a character, then copy their auto-delete list and/or all settings to this one.")

    local destroyDropdown = CreateFrame("Frame", "FugaziBAGSOptionsDestroyDropdown", panel, "UIDropDownMenuTemplate")
    destroyDropdown:SetPoint("TOPLEFT", copyHint, "BOTTOMLEFT", -2, -8)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(destroyDropdown, 200)
    end
    SkinDropDown(destroyDropdown)

    local function CharDisplayName(key)
        local realm, char = tostring(key or ""):match("^(.-)#(.*)$")
        if char and char ~= "" then
            return char
        end
        return key or "?"
    end

    local function CollectCopySourceKeys()
        local SV = _G.FugaziBAGSDB
        local seen, keys = {}, {}
        if not SV then
            return keys
        end
        local function add(key)
            if key and key ~= "" and not seen[key] then
                seen[key] = true
                table.insert(keys, key)
            end
        end
        if SV.gphDestroyListPerChar then
            for key, list in pairs(SV.gphDestroyListPerChar) do
                if list and next(list) ~= nil then
                    add(key)
                end
            end
        end
        if SV.gphPerChar then
            for key, store in pairs(SV.gphPerChar) do
                if type(store) == "table" and next(store) ~= nil then
                    add(key)
                end
            end
        end
        table.sort(keys, function(a, b)
            return CharDisplayName(a) < CharDisplayName(b)
        end)
        return keys
    end

    local function DestroyMenu_Initialize(_, level)
        for _, key in ipairs(CollectCopySourceKeys()) do
            local text = CharDisplayName(key)
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = text
                info.value = key
                info.func = function()
                    gphCopySourceKey = key
                    if UIDropDownMenu_SetSelectedValue then
                        UIDropDownMenu_SetSelectedValue(destroyDropdown, key)
                    end
                    if UIDropDownMenu_SetText then
                        UIDropDownMenu_SetText(destroyDropdown, text)
                    end
                end
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end

    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(destroyDropdown, DestroyMenu_Initialize)
    end

    local copyStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    copyStatus:SetPoint("TOPLEFT", destroyDropdown, "BOTTOMLEFT", 20, -4)
    copyStatus:SetText("")
    local copyStatusHideAt = 0
    local copyStatusTicker = CreateFrame("Frame", nil, panel)
    copyStatusTicker:SetScript("OnUpdate", function(self, elapsed)
        if copyStatusHideAt <= 0 then
            return
        end
        copyStatusHideAt = copyStatusHideAt - elapsed
        if copyStatusHideAt <= 0 then
            copyStatus:SetText("")
        end
    end)
    local function FlashCopyStatus(msg, r, g, b)
        copyStatus:SetText(msg or "")
        copyStatus:SetTextColor(r or 0.4, g or 1, b or 0.4)
        copyStatusHideAt = 3
    end

    local copyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyBtn:SetSize(130, 22)
    copyBtn:SetPoint("LEFT", destroyDropdown.proxy or destroyDropdown, "RIGHT", 8, 0)
    copyBtn:SetText("Copy auto-delete")
    SkinButton(copyBtn)
    AttachSimpleTip(
        copyBtn,
        "Copy auto-delete list",
        "Replace this character's auto-delete list with the selected character's list. Updates the list below immediately."
    )

    copyBtn:SetScript("OnClick", function()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        if not gphCopySourceKey then
            FlashCopyStatus("Select a character first.", 1, 0.4, 0.3)
            return
        end
        SV.gphDestroyListPerChar = SV.gphDestroyListPerChar or {}
        local src = SV.gphDestroyListPerChar[gphCopySourceKey]
        if not src or next(src) == nil then
            FlashCopyStatus("That character has no auto-delete list.", 1, 0.7, 0.3)
            return
        end

        local curKey = A.GetCharKey and A.GetCharKey()
        if not curKey or curKey == "" then
            return
        end
        if gphCopySourceKey == curKey then
            FlashCopyStatus("Already this character.", 1, 0.8, 0.3)
            return
        end

        local dst = SV.gphDestroyListPerChar[curKey]
        if not dst then
            dst = {}
            SV.gphDestroyListPerChar[curKey] = dst
        end

        if wipe then
            wipe(dst)
        else
            for k in pairs(dst) do
                dst[k] = nil
            end
        end
        local count = 0
        for id, v in pairs(src) do
            if type(v) == "table" then
                dst[id] = { name = v.name, texture = v.texture, addedTime = v.addedTime }
            else
                dst[id] = v
            end
            count = count + 1
        end

        if RefreshDelListPanel then
            RefreshDelListPanel()
        end
        if RefreshGPHUI then
            RefreshGPHUI()
        end
        FlashCopyStatus(string.format("Copied %d auto-delete item%s.", count, count == 1 and "" or "s"))
    end)

    local copySettingsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copySettingsBtn:SetSize(120, 22)
    copySettingsBtn:SetPoint("LEFT", copyBtn, "RIGHT", 6, 0)
    copySettingsBtn:SetText("Copy settings")
    SkinButton(copySettingsBtn)
    AttachSimpleTip(
        copySettingsBtn,
        "Copy settings",
        "Copy this character's full setup from the selected character: skins, scale/layout, valuation, and main options.\n\nDoes not copy auto-delete lists, protected items, or worn-gear history."
    )
    copySettingsBtn:SetScript("OnClick", function()
        if not gphCopySourceKey then
            FlashCopyStatus("Select a character first.", 1, 0.4, 0.3)
            return
        end
        if not A.CopyCharSettings then
            FlashCopyStatus("Copy not available.", 1, 0.4, 0.3)
            return
        end
        -- Snapshot source from live DB if source is somehow current; usually source is another toon.
        if A.SnapshotCharSettings then
            A.SnapshotCharSettings()
        end
        local ok, msg = A.CopyCharSettings(gphCopySourceKey)
        if not ok then
            FlashCopyStatus(msg or "Copy failed.", 1, 0.5, 0.3)
            return
        end
        -- Refresh every options panel so controls match the newly loaded profile.
        if panel.refresh then
            panel.refresh()
        end
        if _G.FugaziGridviewOptionsPanel and _G.FugaziGridviewOptionsPanel.refresh then
            _G.FugaziGridviewOptionsPanel.refresh()
        end
        if _G.FugaziBAGSSkinsPanel and _G.FugaziBAGSSkinsPanel.refresh then
            _G.FugaziBAGSSkinsPanel.refresh()
        end
        if _G.FugaziBAGSValuationOptionsPanel and _G.FugaziBAGSValuationOptionsPanel.refresh then
            _G.FugaziBAGSValuationOptionsPanel.refresh()
        end
        if RefreshAllUI then
            RefreshAllUI()
        end
        FlashCopyStatus("Settings copied to this character.")
    end)

    local delListLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    delListLabel:SetPoint("TOPLEFT", destroyDropdown, "BOTTOMLEFT", 6, -22)
    delListLabel:SetText("Auto-delete list (this character):")

    -- Autosell Section (Moved to Bottom)
    local autosellPingLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    autosellPingLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 24, 28)
    autosellPingLabel:SetText("Autosell delay (estimated ping ms):")

    local autosellPingEdit = CreateFrame("EditBox", "FugaziBAGSAutosellPingEdit", panel, "InputBoxTemplate")
    autosellPingEdit:SetAutoFocus(false)
    autosellPingEdit:SetWidth(80)
    autosellPingEdit:SetHeight(22)
    autosellPingEdit:SetMaxLetters(5)
    autosellPingEdit:SetNumeric(true)
    autosellPingEdit:SetPoint("LEFT", autosellPingLabel, "RIGHT", 8, 0)
    SkinEditBox(autosellPingEdit)
    autosellPingEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local autosellPingOk = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    autosellPingOk:SetSize(46, 22)
    autosellPingOk:SetPoint("LEFT", autosellPingEdit, "RIGHT", 6, 0)
    autosellPingOk:SetText("OK")
    SkinButton(autosellPingOk)

    local autosellPingCheck = autosellPingOk:CreateTexture(nil, "OVERLAY")
    autosellPingCheck:SetPoint("LEFT", autosellPingOk, "RIGHT", 6, 0)
    autosellPingCheck:SetSize(16, 16)
    autosellPingCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    autosellPingCheck:SetVertexColor(0, 1, 0)
    autosellPingCheck:Hide()

    autosellPingOk:SetScript("OnClick", function()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        local raw = autosellPingEdit:GetText() and autosellPingEdit:GetText():match("^%s*(.-)%s*$")
        local num = (raw == "" or raw == nil) and nil or tonumber(raw)
        if num ~= nil then
            num = math.floor(math.max(0, math.min(9999, num)))
        end
        if A.SetOption then
            A.SetOption("gphAutosellPingMs", num)
        else
            SV.gphAutosellPingMs = num
        end
        autosellPingEdit:ClearFocus()
        autosellPingCheck:Show()
        local t = 0
        autosellPingOk._checkHideFrame = autosellPingOk._checkHideFrame or CreateFrame("Frame")
        local f = autosellPingOk._checkHideFrame
        f:SetScript("OnUpdate", function(_, elapsed)
            t = t + elapsed
            if t >= 2 then
                f:SetScript("OnUpdate", nil)
                if autosellPingCheck then
                    autosellPingCheck:Hide()
                end
            end
        end)
        f:Show()
    end)

    -- Scrollspeed Section (Right of Autosell)
    local scrollStepLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scrollStepLabel:SetPoint("LEFT", autosellPingOk, "RIGHT", 40, 0)
    scrollStepLabel:SetText("Scrollspeed (px per tick):")

    local scrollStepEdit = CreateFrame("EditBox", "FugaziBAGSScrollStepEdit", panel, "InputBoxTemplate")
    scrollStepEdit:SetAutoFocus(false)
    scrollStepEdit:SetWidth(50)
    scrollStepEdit:SetHeight(22)
    scrollStepEdit:SetMaxLetters(3)
    scrollStepEdit:SetNumeric(true)
    scrollStepEdit:SetPoint("LEFT", scrollStepLabel, "RIGHT", 8, 0)
    SkinEditBox(scrollStepEdit)
    scrollStepEdit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local scrollStepOk = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    scrollStepOk:SetSize(46, 22)
    scrollStepOk:SetPoint("LEFT", scrollStepEdit, "RIGHT", 6, 0)
    scrollStepOk:SetText("OK")
    SkinButton(scrollStepOk)

    local scrollStepCheck = scrollStepOk:CreateTexture(nil, "OVERLAY")
    scrollStepCheck:SetPoint("LEFT", scrollStepOk, "RIGHT", 6, 0)
    scrollStepCheck:SetSize(16, 16)
    scrollStepCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    scrollStepCheck:SetVertexColor(0, 1, 0)
    scrollStepCheck:Hide()

    scrollStepOk:SetScript("OnClick", function()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        local raw = scrollStepEdit:GetText() and scrollStepEdit:GetText():match("^%s*(.-)%s*$")
        local num = (raw == "" or raw == nil) and 200 or tonumber(raw)
        if num ~= nil then
            num = math.floor(math.max(1, math.min(600, num)))
        end
        if A.SetOption then
            A.SetOption("gphScrollStep", num)
        else
            SV.gphScrollStep = num
        end
        scrollStepEdit:SetText(tostring(num))
        scrollStepEdit:ClearFocus()
        scrollStepCheck:Show()
        local t2 = 0
        scrollStepOk._checkHideFrame = scrollStepOk._checkHideFrame or CreateFrame("Frame")
        local f2 = scrollStepOk._checkHideFrame
        f2:SetScript("OnUpdate", function(_, elapsed)
            t2 = t2 + elapsed
            if t2 >= 2 then
                f2:SetScript("OnUpdate", nil)
                if scrollStepCheck then
                    scrollStepCheck:Hide()
                end
            end
        end)
        f2:Show()
        if RefreshGPHUI then
            RefreshGPHUI()
        end
        if RefreshBankUI then
            RefreshBankUI()
        end
    end)

    local delListScroll = CreateFrame("ScrollFrame", "FugaziBAGSDelListScroll", panel, "UIPanelScrollFrameTemplate")
    delListScroll:SetPoint("TOPLEFT", delListLabel, "BOTTOMLEFT", 0, -14)
    delListScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -40, 64)
    SkinScrollBar(_G["FugaziBAGSDelListScrollScrollBar"])

    delListScroll:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    delListScroll:SetBackdropColor(0.04, 0.04, 0.04, 0.8)
    delListScroll:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local delListContent = CreateFrame("Frame", nil, delListScroll)
    delListContent:SetWidth(550)
    delListContent:SetHeight(1)
    delListScroll:SetScrollChild(delListContent)

    local delListRows = {}
    RefreshDelListPanel = function()
        for _, r in pairs(delListRows) do
            r:Hide()
        end
        local A = _G.FugaziBAGS
        local list = (A and A.GetGphDestroyList) and A.GetGphDestroyList() or {}
        local sorted = {}

        local searchEdit = _G.FugaziBAGSDelListSearch
        local rawText = (searchEdit and searchEdit:GetText() or "")
        local searchText = rawText:lower():gsub("^%s*(.-)%s*$", "%1")

        for id, info in pairs(list) do
            local name = type(info) == "table" and info.name or (A.GetCachedItemInfo(id))
            if not name or name == "" then
                name = "Item " .. tostring(id)
            end

            local match = true
            if searchText ~= "" then
                if not name:lower():find(searchText, 1, true) then
                    match = false
                end
            end

            if match then
                local tex = type(info) == "table" and info.texture or (select(10, A.GetCachedItemInfo(id)))
                local at = (type(info) == "table" and info.addedTime) or 0
                table.insert(sorted, { id = id, name = name, texture = tex, addedTime = at })
            end
        end

        table.sort(sorted, function(a, b)
            local atA = a.addedTime or 0
            local atB = b.addedTime or 0
            if atA ~= atB then
                return atA > atB
            end
            return (a.name or "") < (b.name or "")
        end)

        local yOff = 0
        for i, entry in ipairs(sorted) do
            local row = delListRows[i]
            if not row then
                row = CreateFrame("Frame", nil, delListContent)
                row:SetHeight(18)
                local ico = row:CreateTexture(nil, "ARTWORK")
                ico:SetSize(14, 14)
                ico:SetPoint("LEFT", row, "LEFT", 2, 0)
                row.icon = ico
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("LEFT", ico, "RIGHT", 4, 0)
                fs:SetPoint("RIGHT", row, "RIGHT", -22, 0)
                fs:SetJustifyH("LEFT")
                row.nameFs = fs
                local rmBtn = CreateFrame("Button", nil, row)
                rmBtn:SetSize(14, 14)
                rmBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                rmBtn:SetNormalFontObject(GameFontNormalSmall)
                rmBtn:SetHighlightFontObject(GameFontHighlightSmall)
                rmBtn:SetText("|cffff4444x|r")
                rmBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                row.rmBtn = rmBtn
                delListRows[i] = row
            end
            row:SetParent(delListContent)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", delListContent, "TOPLEFT", 0, -yOff)
            row:SetPoint("TOPRIGHT", delListContent, "TOPRIGHT", 0, -yOff)
            if row.icon then
                row.icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            end
            row.nameFs:SetText(entry.name)
            row.rmBtn:SetScript("OnClick", function()
                local bf = A.Bank
                local gphFrame = A.Inventory
                local dlist = (A and A.GetGphDestroyList) and A.GetGphDestroyList()
                if dlist then
                    dlist[entry.id] = nil
                end
                RefreshDelListPanel()
                if _G.RefreshGPHUI then
                    _G.RefreshGPHUI()
                end
                if A.PlaySwooshSound then
                    A.PlaySwooshSound()
                end
            end)
            row:Show()
            yOff = yOff + 18
        end
        delListContent:SetHeight(math.max(1, yOff))
        if #sorted == 0 then
            if not delListContent.emptyFs then
                local efs = delListContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                efs:SetPoint("TOPLEFT", delListContent, "TOPLEFT", 4, -4)
                efs:SetText("(no matches)")
                delListContent.emptyFs = efs
            end
            delListContent.emptyFs:Show()
            if searchText == "" then
                delListContent.emptyFs:SetText("(empty)")
            else
                delListContent.emptyFs:SetText("(no matches)")
            end
        elseif delListContent.emptyFs then
            delListContent.emptyFs:Hide()
        end
    end

    local delListSearch = CreateFrame("EditBox", "FugaziBAGSDelListSearch", panel, "InputBoxTemplate")
    delListSearch:SetSize(180, 22)
    delListSearch:SetPoint("LEFT", delListLabel, "RIGHT", 12, 0)
    SkinEditBox(delListSearch)
    delListSearch:SetAutoFocus(false)
    delListSearch:EnableMouse(true)
    delListSearch:SetFrameLevel(panel:GetFrameLevel() + 10)
    delListSearch:SetScript("OnTextChanged", function(self)
        RefreshDelListPanel()
    end)
    delListSearch:SetScript("OnKeyUp", function(self, key)
        if key == "ENTER" then
            self:ClearFocus()
        end
        RefreshDelListPanel()
    end)
    delListSearch:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    panel.refresh = function()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        local function opt(key, default)
            if A.GetOption then
                local v = A.GetOption(key)
                if v == nil then
                    return default
                end
                return v
            end
            if SV[key] == nil then
                return default
            end
            return SV[key]
        end
        cbDel:SetChecked(opt("gridConfirmAutoDel", true) ~= false)
        if autosellPingEdit then
            local ping = opt("gphAutosellPingMs", nil)
            if ping ~= nil and ping ~= "" then
                autosellPingEdit:SetText(tostring(ping))
            else
                autosellPingEdit:SetText("")
            end
        end
        if _G.FugaziBAGSScrollStepEdit then
            local step = opt("gphScrollStep", 100) or 100
            _G.FugaziBAGSScrollStepEdit:SetText(tostring(step))
        end
        if cbSound then
            cbSound:SetChecked(opt("gphClickSound", true) ~= false)
        end
        if cbAutosell then
            cbAutosell:SetChecked(A.GetPerChar and A.GetPerChar("gphAutosellEverything", false) == true)
        end
        if cbProtectWorn then
            cbProtectWorn:SetChecked(A.GetPerChar and A.GetPerChar("gphProtectPreviouslyWorn", true) ~= false)
        end
        if cbAutoConfirmBOP then
            cbAutoConfirmBOP:SetChecked(opt("gphAutoConfirmBOP", false) == true)
        end
        if cbAutoQuest then
            cbAutoQuest:SetChecked(opt("gphAutoQuestGossip", true) ~= false)
        end
        if FugaziBAGSDelListSearch then
            FugaziBAGSDelListSearch:SetText("")
        end
        if RefreshDelListPanel then
            RefreshDelListPanel()
        end
    end

    panel.okay = function()
        if _G.ApplyTestSkin then
            _G.ApplyTestSkin()
        end
    end

    panel:SetScript("OnShow", function()
        RefreshDelListPanel()
    end)

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

--- Grid view / list view options sub-panel.
local function CreateGridviewOptionsPanel()
    if _G.FugaziGridviewOptionsPanel then
        return
    end
    local panel = CreateFrame("Frame", "FugaziGridviewOptionsPanel", UIParent)
    panel.name = "Scale & Layout"
    panel.parent = "_FugaziBAGS"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Scale & Layout")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Grid view size and spacing, window scale, and list view size.")

    local col1X, col2X, col3X = 30, 220, 410
    local curY = -80

    -- Visual backgrounds for columns
    CreateSectionBg(panel, col1X - 10, curY + 30, 180, 245)
    CreateSectionBg(panel, col2X - 10, curY + 30, 180, 245)
    CreateSectionBg(panel, col3X - 10, curY + 30, 180, 245)

    local s1 = CreateFugaziSlider(
        panel,
        "FugaziGridCols",
        "Slots per row",
        6,
        16,
        1,
        "gridCols",
        10,
        col1X,
        curY,
        false,
        "How many item slots appear in each row of the grid."
    )
    local s2 = CreateFugaziSlider(
        panel,
        "FugaziGridSlotSize",
        "Slot size",
        20,
        45,
        1,
        "gridSlotSize",
        30,
        col2X,
        curY,
        false,
        "Size of each item slot in the grid."
    )
    local s7 = CreateFugaziSlider(
        panel,
        "FugaziGridFrameScale",
        "Window scale",
        0.75,
        1.25,
        0.05,
        "gphFrameScale",
        1.00,
        col3X,
        curY,
        true,
        "Scale the whole inventory and bank window (grid and list)."
    )

    curY = -130
    local s3 = CreateFugaziSlider(
        panel,
        "FugaziGridSpacing",
        "Slot gap",
        1,
        10,
        1,
        "gridSpacing",
        4,
        col1X,
        curY,
        false,
        "Space between item slots in the grid."
    )
    local s4 = CreateFugaziSlider(
        panel,
        "FugaziGridBorderSize",
        "Slot border",
        1,
        4,
        1,
        "gridBorderSize",
        2,
        col2X,
        curY,
        false,
        "Thickness of the border around each grid slot."
    )
    local s8 = CreateFugaziSlider(
        panel,
        "FugaziGridFrameAlpha",
        "Window opacity",
        0.10,
        1.00,
        0.05,
        "gphFrameAlpha",
        1.00,
        col3X,
        curY,
        true,
        "How solid or see-through the inventory and bank background is."
    )

    curY = -180
    local s5 = CreateFugaziSlider(
        panel,
        "FugaziGridGlowAlpha",
        "Rarity glow",
        0.0,
        1.0,
        0.05,
        "gridGlowAlpha",
        0.35,
        col1X,
        curY,
        true,
        "Brightness of the colored glow on grid items (by quality)."
    )
    local s6 = CreateFugaziSlider(
        panel,
        "FugaziGridProtDesat",
        "Protected greying",
        0.0,
        1.0,
        0.05,
        "gridProtDesat",
        0.80,
        col2X,
        curY,
        true,
        "How grey protected items look in the grid so they stand out as safe."
    )
    local s6b = CreateFugaziSlider(
        panel,
        "FugaziGridProtectedKeyAlpha",
        "Lock icon opacity",
        0.10,
        0.50,
        0.05,
        "gridProtectedKeyAlpha",
        0.20,
        col3X,
        curY,
        true,
        "How visible the small lock overlay is on protected items."
    )

    curY = -230
    local s9 = CreateFugaziSlider(
        panel,
        "FugaziListViewHeight",
        "List height",
        200,
        800,
        10,
        "gphListViewHeight",
        520,
        col1X,
        curY,
        false,
        "Fixed outer height for list AND grid when Auto-Adjust Height is off."
    )

    local cbListAuto = CreateFrame("CheckButton", "FugaziBAGSListHeightAuto", panel, "OptionsCheckButtonTemplate")
    cbListAuto:SetPoint("TOPLEFT", s9, "BOTTOMLEFT", -5, -15)
    SkinCheckBox(cbListAuto)

    cbListAuto.text = _G[cbListAuto:GetName() .. "Text"]
    if cbListAuto.text then
        cbListAuto.text:SetText("Auto-adjust height")
        cbListAuto.text:SetFontObject("GameFontNormalSmall")
    end
    cbListAuto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Auto-adjust height", 1, 0.8, 0)
        GameTooltip:AddLine("On: grid bag layout owns height; list matches it.", 1, 1, 1, true)
        GameTooltip:AddLine("Off: fixed List height applies to both list and grid (no post-combat shrink).", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cbListAuto:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    cbListAuto:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked() and true or false
        if A.SetOption then
            A.SetOption("gphListViewHeightAuto", isChecked)
        else
            local SV = _G.FugaziBAGSDB or {}
            SV.gphListViewHeightAuto = isChecked
        end
        if isChecked then
            s9:SetAlpha(0.5)
            s9:EnableMouse(false)
        else
            s9:SetAlpha(1.0)
            s9:EnableMouse(true)
        end
        if _G.RefreshGPHUI then
            _G.RefreshGPHUI()
        end
    end)

    local s10 = CreateFugaziSlider(
        panel,
        "FugaziListViewWidth",
        "List width",
        200,
        800,
        10,
        "gphListViewWidth",
        340,
        col2X,
        curY,
        false,
        "Fixed outer width for list AND grid when Auto-adjust width is off."
    )

    local cbListAutoW = CreateFrame("CheckButton", "FugaziBAGSListWidthAuto", panel, "OptionsCheckButtonTemplate")
    cbListAutoW:SetPoint("TOPLEFT", s10, "BOTTOMLEFT", -5, -15)
    SkinCheckBox(cbListAutoW)

    cbListAutoW.text = _G[cbListAutoW:GetName() .. "Text"]
    if cbListAutoW.text then
        cbListAutoW.text:SetText("Auto-adjust width")
        cbListAutoW.text:SetFontObject("GameFontNormalSmall")
    end
    cbListAutoW:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Auto-adjust width", 1, 0.8, 0)
        GameTooltip:AddLine("On: grid bag layout owns width; list matches it.", 1, 1, 1, true)
        GameTooltip:AddLine("Off: fixed List width applies to both list and grid.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cbListAutoW:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    cbListAutoW:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked() and true or false
        if A.SetOption then
            A.SetOption("gphListViewWidthAuto", isChecked)
        else
            local SV = _G.FugaziBAGSDB or {}
            SV.gphListViewWidthAuto = isChecked
        end
        if isChecked then
            s10:SetAlpha(0.5)
            s10:EnableMouse(false)
        else
            s10:SetAlpha(1.0)
            s10:EnableMouse(true)
        end
        if _G.RefreshGPHUI then
            _G.RefreshGPHUI()
        end
    end)

    s10:HookScript("OnValueChanged", function()
        if not s10._isRefreshing then
            -- Inventory is the frame itself (not .frame).
            if A.Inventory and A.Inventory.NegotiateSizes then
                A.Inventory:NegotiateSizes()
            end
            if A.Bank and A.Bank.NegotiateSizes then
                A.Bank:NegotiateSizes()
            end
        end
    end)

    local cbBankFloat = CreateFrame("CheckButton", "FugaziBAGSBankFloatCheck", panel, "OptionsCheckButtonTemplate")
    cbBankFloat:SetPoint("TOPLEFT", col3X - 5, curY - 35)
    SkinCheckBox(cbBankFloat)

    cbBankFloat.text = _G[cbBankFloat:GetName() .. "Text"]
    if cbBankFloat.text then
        cbBankFloat.text:SetText("Free-float bank")
        cbBankFloat.text:SetFontObject("GameFontNormalSmall")
    end
    cbBankFloat:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Free-float bank", 1, 0.8, 0)
        GameTooltip:AddLine(
            "Let the bank window stay where you drag it instead of snapping next to your bags.",
            1,
            1,
            1,
            true
        )
        GameTooltip:Show()
    end)
    cbBankFloat:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    cbBankFloat:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        if A.SetOption then
            A.SetOption("gphBankFreeFloat", val)
        else
            local SV = _G.FugaziBAGSDB or {}
            SV.gphBankFreeFloat = val
        end
    end)

    s9:HookScript("OnValueChanged", function()
        if not s9._isRefreshing then
            if A.Inventory and A.Inventory.NegotiateSizes then
                A.Inventory:NegotiateSizes()
            end
            if A.Bank and A.Bank.NegotiateSizes then
                A.Bank:NegotiateSizes()
            end
        end
    end)

    panel.refresh = function()
        local SV = _G.FugaziBAGSDB or {}
        s1._isRefreshing = true
        s1:SetValue(SV.gridCols or 10)
        s1._isRefreshing = false

        s2._isRefreshing = true
        s2:SetValue(SV.gridSlotSize or 30)
        s2._isRefreshing = false

        s3._isRefreshing = true
        s3:SetValue(SV.gridSpacing or 4)
        s3._isRefreshing = false

        local bv = (SV.gridBorderSize or 2)
        if bv < 1 then
            bv = 1
        elseif bv > 4 then
            bv = 4
        end
        s4._isRefreshing = true
        s4:SetValue(bv)
        s4._isRefreshing = false
        s4._valText:SetText(tostring(bv))

        s5._isRefreshing = true
        s5:SetValue((SV.gridGlowAlpha or 0.35) * 100)
        s5._isRefreshing = false

        s6._isRefreshing = true
        s6:SetValue((SV.gridProtDesat or 0.80) * 100)
        s6._isRefreshing = false

        if s6b then
            s6b._isRefreshing = true
            s6b:SetValue((SV.gridProtectedKeyAlpha or 0.20) * 100)
            s6b._isRefreshing = false
        end

        s7._isRefreshing = true
        s7:SetValue((SV.gphFrameScale or 1.00) * 100)
        s7._isRefreshing = false

        s8._isRefreshing = true
        s8:SetValue((SV.gphFrameAlpha or 1.00) * 100)
        s8._isRefreshing = false

        local isAuto = SV.gphListViewHeightAuto
        if isAuto == nil then
            isAuto = true
        end
        cbListAuto:SetChecked(isAuto)
        if isAuto then
            s9:SetAlpha(0.5)
            s9:EnableMouse(false)
        else
            s9:SetAlpha(1.0)
            s9:EnableMouse(true)
        end

        s9._isRefreshing = true
        s9:SetValue(SV.gphListViewHeight or 520)
        s9._isRefreshing = false

        local isAutoW = SV.gphListViewWidthAuto
        if isAutoW == nil then
            isAutoW = true
        end
        cbListAutoW:SetChecked(isAutoW)
        if isAutoW then
            s10:SetAlpha(0.5)
            s10:EnableMouse(false)
        else
            s10:SetAlpha(1.0)
            s10:EnableMouse(true)
        end

        s10._isRefreshing = true
        s10:SetValue(SV.gphListViewWidth or 340)
        s10._isRefreshing = false

        local isFloat = SV.gphBankFreeFloat
        if isFloat == nil then
            isFloat = false
        end
        cbBankFloat:SetChecked(isFloat)
    end

    local function ResetScaleDefaults()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        local function set(k, v)
            if A.SetOption then
                A.SetOption(k, v)
            else
                SV[k] = v
            end
        end
        set("gridCols", 11)
        set("gridSlotSize", 36)
        set("gphFrameScale", 1.00)
        set("gridSpacing", 4)
        set("gridBorderSize", 3)
        set("gridGlowAlpha", 0.80)
        set("gridProtDesat", 0.35)
        set("gridProtectedKeyAlpha", 0.20)
        set("gphFrameAlpha", 0.90)
        panel.refresh()
        RefreshAllUI()
    end

    panel.default = ResetScaleDefaults

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 16, 16)
    resetBtn:SetText("Reset Defaults")
    SkinButton(resetBtn)
    resetBtn:SetScript("OnClick", ResetScaleDefaults)

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

--- Skin picker panel (themes for inventory/bank).
local function CreateSkinsPanel()
    if _G.FugaziBAGSSkinsPanel then
        return
    end
    local panel = CreateFrame("Frame", "FugaziBAGSSkinsPanel", UIParent)
    panel.name = "Skins"
    panel.parent = "_FugaziBAGS"
    panel.okay = function()
        if RefreshAllUI then
            RefreshAllUI()
        end
    end
    panel.cancel = function() end
    panel.default = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Skins")

    local skinsSub = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    skinsSub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    skinsSub:SetText("Look of your bags and bank. Changes apply to this character.")

    local scroll = CreateFrame("ScrollFrame", "FugaziBAGSSkinsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", skinsSub, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 60)
    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(600)
    scrollChild:SetHeight(900)
    scroll:SetScrollChild(scrollChild)
    panel:SetScript("OnShow", function()
        local sh = scroll:GetHeight()
        if sh and sh > 0 and scrollChild:GetHeight() <= sh then
            scrollChild:SetHeight(sh + 600)
        end
        if panel.refresh then
            panel.refresh()
        end
    end)

    local LEFT_X, RIGHT_X, ROW = 16, 310, 26
    local curY = 6

    local function SetSkinOpt(key, value)
        if A.SetOption then
            A.SetOption(key, value)
        else
            local SV = _G.FugaziBAGSDB
            if SV then
                SV[key] = value
            end
        end
    end

    local function CreateSeparator(y)
        local line = scrollChild:CreateTexture(nil, "ARTWORK")
        line:SetSize(560, 1)
        line:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -y)
        line:SetTexture(1, 1, 1, 0.15)
    end

    local function SkinButtonLocal(btn)
        if not btn then
            return
        end
        SkinButton(btn)
    end

    local function SkinCheckBoxLocal(cb)
        if not cb then
            return
        end
        SkinCheckBox(cb)
    end

    local function SkinDropDownLocal(dd)
        if not dd then
            return
        end
        SkinDropDown(dd)
    end

    local ITEM_DETAILS_FONTS = {
        { value = "Fonts\\ARIALN.TTF", text = "ARIALN" },
        { value = "Fonts\\FRIZQT__.TTF", text = "FRIZQT" },
        { value = "Fonts\\MORPHEUS.TTF", text = "MORPHEUS" },
        { value = "Fonts\\skurri.ttf", text = "Skurri" },

        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TinyIslanders.ttf", text = "Tiny Islanders" },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\OldSchoolAdventures.ttf",
            text = "Old School Adventures",
        },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\BreatheFire.ttf", text = "Breathe Fire" },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\EightBitDragon.ttf",
            text = "Eight Bit Dragon",
        },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\AncientModernTales.ttf",
            text = "Ancient Modern Tales",
        },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\Dragnel.ttf", text = "Dragnel" },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TheWildBreathOfZelda.ttf",
            text = "Wild Breath of Zelda",
        },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\ModernSignature.ttf",
            text = "Modern Signature",
        },
    }
    local RARITY_OPTIONS = {
        { q = 0, label = "|cff9d9d9dPoor|r" },
        { q = 1, label = "|cffffffffCommon|r" },
        { q = 2, label = "|cff1eff00Uncommon|r" },
        { q = 3, label = "|cff0070ddRare|r" },
        { q = 4, label = "|cffa335eeEpic|r" },
        { q = 5, label = "|cffff8000Legendary|r" },
    }

    local skinLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    skinLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", LEFT_X, -curY)
    skinLabel:SetText("Theme")
    curY = curY + ROW

    local skinDropdown = CreateFrame("Frame", "FugaziBAGSSkinsSkinDropdown", scrollChild, "UIDropDownMenuTemplate")
    skinDropdown:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", -12, -6)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(skinDropdown, 180)
    end
    SkinDropDown(skinDropdown)
    local function SkinMenu_Init(_, level)
        local list = {
            { value = "original", text = "Bagnon" },
            { value = "elvui", text = "ElvUI (Ebonhold)" },
            { value = "elvui_real", text = "ElvUI" },
            { value = "pimp_purple", text = "Pimp Purple" },
            { value = "fugazi", text = "FUGAZI" },
        }
        for _, opt in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.text
                info.value = opt.value
                local curSkin = (A.GetOption and A.GetOption("gphSkin"))
                    or (_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSkin)
                    or "elvui_real"
                info.checked = curSkin == opt.value
                info.func = function()
                    if opt.value == "fugazi" and _G.ApplyFugaziPreset then
                        _G.ApplyFugaziPreset()
                    elseif opt.value == "original" and _G.ApplyBagnonPreset then
                        _G.ApplyBagnonPreset()
                    else
                        -- ElvUI / Ebonhold / Pimp Purple: switch theme only.
                        -- Do NOT force gphFrameAlpha — window opacity is a global preference
                        -- (default 0.90). Forcing 1.0 made ElvUI look like a solid block until
                        -- the user re-touched the opacity slider.
                        SetSkinOpt("gphSkin", opt.value)
                        SetSkinOpt("gphCategoryHeaderFontCustom", false)
                        SetSkinOpt("gphItemDetailsCustom", false)
                        SetSkinOpt("gphSkinOverrides", {})
                        SetSkinOpt("gphHideIconsInList", false)
                        SetSkinOpt("gphHideTopButtons", false)
                        SetSkinOpt("gphBankHideTopButtons", false)
                    end
                    if UIDropDownMenu_SetSelectedValue then
                        UIDropDownMenu_SetSelectedValue(skinDropdown, opt.value)
                    end
                    if UIDropDownMenu_SetText then
                        UIDropDownMenu_SetText(skinDropdown, opt.text)
                    end
                    if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
                        FugaziBAGSSkinsPanel.refresh()
                    end
                    -- One path for bags + bank + FIT (skins/colors must not skip FIT).
                    if RefreshAllUI then
                        RefreshAllUI()
                    end
                    -- Re-apply opacity after skin paint so mainBg * gphFrameAlpha sticks even
                    -- when alpha value itself did not change (skin select used to skip this).
                    if A.ApplyFrameAlpha then
                        if A.Inventory then
                            A.Inventory._gphLastAppliedAlpha = nil
                            A.ApplyFrameAlpha(A.Inventory)
                        end
                        if A.Bank then
                            A.Bank._gphLastAppliedAlpha = nil
                            A.ApplyFrameAlpha(A.Bank)
                        end
                    end
                end
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(skinDropdown, SkinMenu_Init)
    end
    curY = curY + 48
    CreateSeparator(curY)
    curY = curY + 14

    local headerSectionY = curY
    local fontLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", LEFT_X, -curY)
    fontLabel:SetText("Category headers")
    curY = curY + ROW

    local cbCatFont =
        CreateFrame("CheckButton", "FugaziBAGSSkinsCategoryFontCheck", scrollChild, "OptionsCheckButtonTemplate")
    cbCatFont:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -2)
    SkinCheckBox(cbCatFont)
    _G["FugaziBAGSSkinsCategoryFontCheckText"]:SetText("Customize headers")
    cbCatFont:SetScript("OnClick", function(self)
        SetSkinOpt("gphCategoryHeaderFontCustom", self:GetChecked() == 1 or self:GetChecked() == true)
        if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
            FugaziBAGSSkinsPanel.refresh()
        end
        if RefreshAllUI then
            RefreshAllUI()
        end
    end)
    curY = curY + 28

    local CAT_HEADER_FONTS = {
        { value = "Fonts\\ARIALN.TTF", text = "ARIALN" },
        { value = "Fonts\\FRIZQT__.TTF", text = "FRIZQT" },
        { value = "Fonts\\MORPHEUS.TTF", text = "MORPHEUS" },
        { value = "Fonts\\skurri.ttf", text = "Skurri" },

        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TinyIslanders.ttf", text = "Tiny Islanders" },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\OldSchoolAdventures.ttf",
            text = "Old School Adventures",
        },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\BreatheFire.ttf", text = "Breathe Fire" },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\EightBitDragon.ttf",
            text = "Eight Bit Dragon",
        },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\AncientModernTales.ttf",
            text = "Ancient Modern Tales",
        },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\Dragnel.ttf", text = "Dragnel" },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TheWildBreathOfZelda.ttf",
            text = "Wild Breath of Zelda",
        },
        {
            value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\ModernSignature.ttf",
            text = "Modern Signature",
        },
    }
    local catFontDropdown =
        CreateFrame("Frame", "FugaziBAGSSkinsCategoryFontDropdown", scrollChild, "UIDropDownMenuTemplate")
    catFontDropdown:SetPoint("TOPLEFT", cbCatFont, "BOTTOMLEFT", -12, -8)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(catFontDropdown, 160)
    end
    SkinDropDown(catFontDropdown)
    local function CatFontMenu_Init(frame, level)
        for _, opt in ipairs(CAT_HEADER_FONTS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.text
                info.func = function()
                    SetSkinOpt("gphCategoryHeaderFont", opt.value)
                    if UIDropDownMenu_SetSelectedValue then
                        UIDropDownMenu_SetSelectedValue(frame, opt.value)
                    end
                    if UIDropDownMenu_SetText then
                        UIDropDownMenu_SetText(frame, opt.text)
                    end
                    if RefreshAllUI then
                        RefreshAllUI()
                    end
                end
                info.checked = (frame.selectedValue == opt.value)
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(catFontDropdown, CatFontMenu_Init)
    end

    curY = curY + 44

    local catFontSizeSlider = CreateFugaziSlider(
        scrollChild,
        "FugaziBAGSSkinsCategoryFontSize",
        "Header size",
        6,
        24,
        1,
        "gphCategoryHeaderFontSize",
        11,
        LEFT_X + 6,
        -curY,
        false,
        "Size of category titles like Armor, Consumables, etc."
    )
    curY = curY + 50
    -- Section: Colors (Right Column)
    local colorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", RIGHT_X, -headerSectionY)
    colorLabel:SetText("Colors")

    local COLOR_OVERRIDES = {
        { key = "headerTextColor", label = "Header text" },
        { key = "mainBg", label = "Background" },
        { key = "fitRowColor", label = "Tracker labels" },
    }
    local function GetSkinDefaultColor(skinName, key)
        local sk = _G.__FugaziBAGS_Skins
            and _G.__FugaziBAGS_Skins.SKIN
            and _G.__FugaziBAGS_Skins.SKIN[skinName or "elvui_real"]
        if sk and sk[key] then
            return unpack(sk[key])
        end
        if key == "mainBg" then
            return 0.04, 0.04, 0.04, 1
        end
        if key == "headerTextColor" and sk and sk.titleTextColor then
            return unpack(sk.titleTextColor)
        end
        if key == "fitRowColor" then
            return 0.5, 0.8, 1.0, 1
        end
        return 1, 0.85, 0.4, 1
    end
    local function OpenColorPicker(overrideKey, labelText)
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        if not SV.gphSkinOverrides then
            SV.gphSkinOverrides = {}
            SetSkinOpt("gphSkinOverrides", SV.gphSkinOverrides)
        end
        local cur = SV.gphSkinOverrides[overrideKey]
        local skinName = SV.gphSkin or "elvui_real"
        local r, g, b, a
        if cur and #cur >= 4 then
            r, g, b, a = cur[1], cur[2], cur[3], cur[4]

            if overrideKey == "mainBg" and (not a or a < 0.2) then
                local dr, dg, db, da = GetSkinDefaultColor(skinName, overrideKey)
                a = da or 1
                SV.gphSkinOverrides[overrideKey][4] = a
            end
        else
            r, g, b, a = GetSkinDefaultColor(skinName, overrideKey)
            a = a or 1
        end
        if not _G.ColorPickerFrame then
            return
        end
        _G.ColorPickerFrame.previousValues = { r, g, b, a }
        local function ApplyPickedColor()
            local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
            local SV2 = _G.FugaziBAGSDB
            if not SV2 then
                return
            end
            if not SV2.gphSkinOverrides then
                SV2.gphSkinOverrides = {}
            end
            local skinNameNow = SV2.gphSkin or "elvui_real"
            local na
            if overrideKey == "mainBg" then
                if _G.OpacitySliderFrame then
                    na = 1 - _G.OpacitySliderFrame:GetValue()
                else
                    na = 1
                end
            else
                na = 1
            end
            if na and na < 0 then
                na = 0
            end
            if na and na > 1 then
                na = 1
            end
            SV2.gphSkinOverrides[overrideKey] = { nr, ng, nb, na }
            if A.SetOption then
                A.SetOption("gphSkinOverrides", SV2.gphSkinOverrides)
            end

            if Skins and Skins.SKIN and Skins.SKIN[skinNameNow] and Skins.SKIN[skinNameNow][overrideKey] then
                Skins.SKIN[skinNameNow][overrideKey] = { nr, ng, nb, na }
            end
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
                FugaziBAGSSkinsPanel.refresh()
            end
            -- Bags + bank + FIT share one refresh so header/row/frame colors apply live.
            if RefreshAllUI then
                RefreshAllUI()
            end
        end
        _G.ColorPickerFrame.func = ApplyPickedColor
        -- 3.3.5: opacity slider uses opacityFunc, not func.
        _G.ColorPickerFrame.opacityFunc = (overrideKey == "mainBg") and ApplyPickedColor or nil
        _G.ColorPickerFrame.cancelFunc = function(prev)
            local pr, pg, pb, pa = r, g, b, a
            if type(prev) == "table" then
                pr = prev.r or prev[1] or pr
                pg = prev.g or prev[2] or pg
                pb = prev.b or prev[3] or pb
                pa = prev.a or prev[4] or pa
            end
            local SV2 = _G.FugaziBAGSDB
            if SV2 then
                if not SV2.gphSkinOverrides then
                    SV2.gphSkinOverrides = {}
                end
                SV2.gphSkinOverrides[overrideKey] = { pr, pg, pb, pa or 1 }
                local skinNameNow = SV2.gphSkin or "elvui_real"
                if Skins and Skins.SKIN and Skins.SKIN[skinNameNow] and Skins.SKIN[skinNameNow][overrideKey] then
                    Skins.SKIN[skinNameNow][overrideKey] = { pr, pg, pb, pa or 1 }
                end
            end
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
                FugaziBAGSSkinsPanel.refresh()
            end
            if RefreshAllUI then
                RefreshAllUI()
            end
        end
        _G.ColorPickerFrame:SetColorRGB(r, g, b)

        _G.ColorPickerFrame.hasOpacity = (overrideKey == "mainBg")
        _G.ColorPickerFrame.opacity = 1 - a
        if _G.OpacitySliderFrame then
            if _G.OpacitySliderFrame.SetValue then
                _G.OpacitySliderFrame:SetValue(1 - a)
            end
            if _G.ColorPickerFrame.hasOpacity then
                _G.OpacitySliderFrame:Show()
            else
                _G.OpacitySliderFrame:Hide()
            end
        end
        if _G.ColorPickerFrame.SetOpacity then
            _G.ColorPickerFrame:SetOpacity(1 - a)
        end
        _G.ColorPickerFrame:Show()
    end

    local function OpenRarityColorPicker()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end

        local dd = _G.FugaziBAGSSkinsRaritySelectDropdown
        local rq = (dd and dd.selectedQuality) or 1
        if not SV.gphSkinOverrides then
            SV.gphSkinOverrides = {}
        end
        if not SV.gphSkinOverrides.itemDetailsRarityColors then
            SV.gphSkinOverrides.itemDetailsRarityColors = {}
        end
        local curr = SV.gphSkinOverrides.itemDetailsRarityColors[rq]
        if not curr then
            local def = (A.QUALITY_COLORS and A.QUALITY_COLORS[rq]) or { r = 1, g = 1, b = 1 }
            curr = { def.r or 1, def.g or 1, def.b or 1 }
        end
        if not _G.ColorPickerFrame then
            return
        end
        _G.ColorPickerFrame.func = function()
            local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
            local SV2 = _G.FugaziBAGSDB
            if not SV2.gphSkinOverrides then
                SV2.gphSkinOverrides = {}
            end
            if not SV2.gphSkinOverrides.itemDetailsRarityColors then
                SV2.gphSkinOverrides.itemDetailsRarityColors = {}
            end
            SV2.gphSkinOverrides.itemDetailsRarityColors[rq] = { nr, ng, nb }
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
                FugaziBAGSSkinsPanel.refresh()
            end
            if RefreshAllUI then
                RefreshAllUI()
            end
        end
        _G.ColorPickerFrame:SetColorRGB(unpack(curr))
        _G.ColorPickerFrame.hasOpacity = false
        _G.ColorPickerFrame:Show()
    end

    local colorBtns = {}
    for i, row in ipairs(COLOR_OVERRIDES) do
        local btn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        btn:SetSize(180, 22)
        btn:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 8, -2 - ((i - 1) * 26))
        btn:SetText(row.label)
        if btn:GetFontString() then
            btn:GetFontString():SetTextColor(1, 1, 1)
        end -- Use white text to match dropdowns
        local swatch = btn:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(16, 16)
        swatch:SetPoint("LEFT", btn, "RIGHT", 6, 0)
        swatch:SetTexture(1, 1, 1, 1)
        btn._swatch = swatch
        btn._key = row.key
        btn:SetScript("OnClick", function(self)
            OpenColorPicker(self._key, row.label)
        end)
        SkinButton(btn)
        colorBtns[row.key] = btn
    end

    -- Header block height: title + checkbox + font dd + size slider + padding
    curY = math.max(curY, headerSectionY + 150)
    CreateSeparator(curY)
    curY = curY + 14

    local rowSectionY = curY
    local itemDetailsLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemDetailsLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", LEFT_X, -curY)
    itemDetailsLabel:SetText("List view rows")
    curY = curY + ROW

    local cbItemDetails =
        CreateFrame("CheckButton", "FugaziBAGSSkinsItemDetailsCheck", scrollChild, "OptionsCheckButtonTemplate")
    cbItemDetails:SetPoint("TOPLEFT", itemDetailsLabel, "BOTTOMLEFT", 0, -2)
    SkinCheckBox(cbItemDetails)
    _G["FugaziBAGSSkinsItemDetailsCheckText"]:SetText("Customize list rows")
    cbItemDetails:SetScript("OnClick", function(self)
        SetSkinOpt("gphItemDetailsCustom", self:GetChecked() == 1 or self:GetChecked() == true)
        if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
            FugaziBAGSSkinsPanel.refresh()
        end
        if RefreshAllUI then
            RefreshAllUI()
        end
    end)
    curY = curY + 28

    local cbHideIcons =
        CreateFrame("CheckButton", "FugaziBAGSSkinsHideIconsCheck", scrollChild, "OptionsCheckButtonTemplate")
    cbHideIcons:SetPoint("TOPLEFT", cbItemDetails, "BOTTOMLEFT", 0, -2)
    SkinCheckBox(cbHideIcons)
    _G["FugaziBAGSSkinsHideIconsCheckText"]:SetText("Hide category icons")
    cbHideIcons:SetScript("OnClick", function(self)
        SetSkinOpt("gphHideIconsInList", self:GetChecked() == 1 or self:GetChecked() == true)
        if RefreshAllUI then
            RefreshAllUI()
        end
    end)
    curY = curY + 28

    local itemDetailsFontDropdown =
        CreateFrame("Frame", "FugaziBAGSSkinsItemDetailsFontDropdown", scrollChild, "UIDropDownMenuTemplate")
    itemDetailsFontDropdown:SetPoint("TOPLEFT", cbHideIcons, "BOTTOMLEFT", -12, -8)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(itemDetailsFontDropdown, 160)
    end
    SkinDropDown(itemDetailsFontDropdown)
    local function ItemDetailsFontMenu_Init(frame, level)
        for _, opt in ipairs(ITEM_DETAILS_FONTS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.text
                info.func = function()
                    SetSkinOpt("gphItemDetailsFont", opt.value)
                    if UIDropDownMenu_SetSelectedValue then
                        UIDropDownMenu_SetSelectedValue(frame, opt.value)
                    end
                    if UIDropDownMenu_SetText then
                        UIDropDownMenu_SetText(frame, opt.text)
                    end
                    if RefreshAllUI then
                        RefreshAllUI()
                    end
                end
                info.checked = (frame.selectedValue == opt.value)
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(itemDetailsFontDropdown, ItemDetailsFontMenu_Init)
    end
    curY = curY + 48

    local itemDetailsIconSizeSlider = CreateFugaziSlider(
        scrollChild,
        "FugaziBAGSSkinsItemDetailsIconSize",
        "Icon size",
        12,
        28,
        1,
        "gphItemDetailsIconSize",
        16,
        LEFT_X + 6,
        -curY,
        false,
        "Size of the item icon on each list row (bags and bank)."
    )
    curY = curY + 52

    local itemDetailsFontSizeSlider = CreateFugaziSlider(
        scrollChild,
        "FugaziBAGSSkinsItemDetailsFontSize",
        "Name size",
        8,
        24,
        1,
        "gphItemDetailsFontSize",
        11,
        LEFT_X + 6,
        -curY,
        false,
        "Size of the item name text on list rows."
    )
    curY = curY + 52

    local itemDetailsAlphaSlider = CreateFugaziSlider(
        scrollChild,
        "FugaziBAGSSkinsItemDetailsAlpha",
        "Row opacity",
        0.0,
        1.0,
        0.05,
        "gphItemDetailsAlpha",
        1.0,
        LEFT_X + 6,
        -curY,
        true,
        "Row glass wash. 0 = no strip (names stay ~70% opacity); 1 = full wash + full text."
    )
    curY = curY + 52

    -- Section: Quality / icon colors (Right Column)
    local rarityColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rarityColorLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", RIGHT_X, -rowSectionY)
    rarityColorLabel:SetText("Item name colors")

    local raritySelectDropdown =
        CreateFrame("Frame", "FugaziBAGSSkinsRaritySelectDropdown", scrollChild, "UIDropDownMenuTemplate")
    raritySelectDropdown:SetPoint("TOPLEFT", rarityColorLabel, "BOTTOMLEFT", -12, -8)
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(raritySelectDropdown, 160)
    end
    SkinDropDown(raritySelectDropdown)
    raritySelectDropdown.selectedQuality = 1
    local function RaritySelectMenu_Init(frame, level)
        for _, opt in ipairs(RARITY_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.label
                info.func = function()
                    frame.selectedQuality = opt.q
                    if UIDropDownMenu_SetSelectedValue then
                        UIDropDownMenu_SetSelectedValue(frame, opt.q)
                    end
                    if UIDropDownMenu_SetText then
                        UIDropDownMenu_SetText(frame, opt.label)
                    end
                    if UIDropDownMenu_Refresh then
                        UIDropDownMenu_Refresh(frame, nil, 1)
                    end
                    if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
                        FugaziBAGSSkinsPanel.refresh()
                    end
                end
                info.checked = (frame.selectedQuality == opt.q)
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(raritySelectDropdown, RaritySelectMenu_Init)
    end

    local rarityColorBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    rarityColorBtn:SetSize(180, 22)
    rarityColorBtn:SetPoint("TOPLEFT", raritySelectDropdown, "BOTTOMLEFT", 16, -8)
    rarityColorBtn:SetText("Name color")
    local rs0 = rarityColorBtn:CreateTexture(nil, "OVERLAY")
    rs0:SetSize(16, 16)
    rs0:SetPoint("LEFT", rarityColorBtn, "RIGHT", 6, 0)
    rs0:SetTexture(1, 1, 1, 1)
    rarityColorBtn._swatch = rs0
    rarityColorBtn:SetScript("OnClick", OpenRarityColorPicker)
    SkinButton(rarityColorBtn)

    local iconColorBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    iconColorBtn:SetSize(180, 22)
    iconColorBtn:SetPoint("TOPLEFT", rarityColorBtn, "BOTTOMLEFT", 0, -10)
    iconColorBtn:SetText("Icon tint")
    local is0 = iconColorBtn:CreateTexture(nil, "OVERLAY")
    is0:SetSize(16, 16)
    is0:SetPoint("LEFT", iconColorBtn, "RIGHT", 6, 0)
    is0:SetTexture(1, 1, 1, 1)
    iconColorBtn._swatch = is0
    iconColorBtn:SetScript("OnClick", function()
        local SV = _G.FugaziBAGSDB
        if not SV then
            return
        end
        if not SV.gphSkinOverrides then
            SV.gphSkinOverrides = {}
            SetSkinOpt("gphSkinOverrides", SV.gphSkinOverrides)
        end
        local curr = SV.gphSkinOverrides.itemDetailsIconColor or { 1, 1, 1 }
        if not _G.ColorPickerFrame then
            return
        end
        _G.ColorPickerFrame.func = function()
            local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
            local SV2 = _G.FugaziBAGSDB
            if not SV2 then
                return
            end
            if not SV2.gphSkinOverrides then
                SV2.gphSkinOverrides = {}
            end
            SV2.gphSkinOverrides.itemDetailsIconColor = { nr, ng, nb }
            if A.SetOption then
                A.SetOption("gphSkinOverrides", SV2.gphSkinOverrides)
            end
            if RefreshGPHUI then
                RefreshGPHUI()
            end
            ForceRefreshBankUI()
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then
                FugaziBAGSSkinsPanel.refresh()
            end
        end
        _G.ColorPickerFrame:SetColorRGB(unpack(curr))
        _G.ColorPickerFrame.hasOpacity = false
        _G.ColorPickerFrame:Show()
    end)
    SkinButton(iconColorBtn)

    curY = math.max(curY, rowSectionY + 200)
    scrollChild:SetHeight(curY + 80)

    panel.refresh = function()
        local SV = _G.FugaziBAGSDB or {}
        local sk = (A.GetOption and A.GetOption("gphSkin")) or SV.gphSkin or "elvui_real"
        local skText = (sk == "elvui" and "ElvUI (Ebonhold)")
            or (sk == "elvui_real" and "ElvUI")
            or (sk == "pimp_purple" and "Pimp Purple")
            or (sk == "fugazi" and "FUGAZI")
            or (sk == "original" and "Bagnon")
            or "Bagnon"
        UIDropDownMenu_SetSelectedValue(skinDropdown, sk)
        UIDropDownMenu_SetText(skinDropdown, skText)

        cbCatFont:SetChecked(SV.gphCategoryHeaderFontCustom)
        local hFont = SV.gphCategoryHeaderFont or "Fonts\\ARIALN.TTF"
        UIDropDownMenu_SetSelectedValue(catFontDropdown, hFont)
        for _, o in ipairs(CAT_HEADER_FONTS) do
            if o.value == hFont then
                UIDropDownMenu_SetText(catFontDropdown, o.text)
                break
            end
        end
        catFontSizeSlider._isRefreshing = true
        catFontSizeSlider:SetValue(SV.gphCategoryHeaderFontSize or 11)
        catFontSizeSlider._isRefreshing = false

        for key, btn in pairs(colorBtns) do
            local r, g, b = GetSkinDefaultColor(sk, key)
            local cur = SV.gphSkinOverrides and SV.gphSkinOverrides[key]
            if cur then
                r, g, b = unpack(cur)
            end
            btn._swatch:SetVertexColor(r, g, b)
        end

        cbItemDetails:SetChecked(SV.gphItemDetailsCustom)
        cbHideIcons:SetChecked(SV.gphHideIconsInList)
        local iFont = SV.gphItemDetailsFont or "Fonts\\FRIZQT__.TTF"
        UIDropDownMenu_SetSelectedValue(itemDetailsFontDropdown, iFont)
        for _, o in ipairs(ITEM_DETAILS_FONTS) do
            if o.value == iFont then
                UIDropDownMenu_SetText(itemDetailsFontDropdown, o.text)
                break
            end
        end
        itemDetailsFontSizeSlider._isRefreshing = true
        itemDetailsFontSizeSlider:SetValue(SV.gphItemDetailsFontSize or 11)
        itemDetailsFontSizeSlider._isRefreshing = false

        itemDetailsIconSizeSlider._isRefreshing = true
        itemDetailsIconSizeSlider:SetValue(SV.gphItemDetailsIconSize or 16)
        itemDetailsIconSizeSlider._isRefreshing = false

        itemDetailsAlphaSlider._isRefreshing = true
        itemDetailsAlphaSlider:SetValue((SV.gphItemDetailsAlpha or 1.0) * 100)
        itemDetailsAlphaSlider._isRefreshing = false

        local iCol = SV.gphSkinOverrides and SV.gphSkinOverrides.itemDetailsIconColor or { 1, 1, 1 }
        iconColorBtn._swatch:SetVertexColor(unpack(iCol))

        local rq = raritySelectDropdown.selectedQuality or 1
        UIDropDownMenu_SetSelectedValue(raritySelectDropdown, rq)
        for _, o in ipairs(RARITY_OPTIONS) do
            if o.q == rq then
                UIDropDownMenu_SetText(raritySelectDropdown, o.label)
                break
            end
        end
        local rCol = SV.gphSkinOverrides
            and SV.gphSkinOverrides.itemDetailsRarityColors
            and SV.gphSkinOverrides.itemDetailsRarityColors[rq]
        if rCol then
            rarityColorBtn._swatch:SetVertexColor(unpack(rCol))
        else
            local def = A.QUALITY_COLORS and A.QUALITY_COLORS[rq]
            rarityColorBtn._swatch:SetVertexColor(def and def.r or 1, def and def.g or 1, def and def.b or 1)
        end

        -- Toggle Visibility/Enabled State based on master switches
        local showHeader = SV.gphCategoryHeaderFontCustom
        SetFugaziControlEnabled(catFontDropdown, showHeader)
        SetFugaziControlEnabled(catFontSizeSlider, showHeader)
        SetFugaziControlEnabled(colorBtns["headerTextColor"], showHeader)

        local showRows = SV.gphItemDetailsCustom
        SetFugaziControlEnabled(itemDetailsFontDropdown, showRows)
        SetFugaziControlEnabled(cbHideIcons, showRows)
        SetFugaziControlEnabled(itemDetailsFontSizeSlider, showRows)
        SetFugaziControlEnabled(itemDetailsAlphaSlider, showRows)

        SetFugaziControlEnabled(raritySelectDropdown, showRows)
        SetFugaziControlEnabled(rarityColorBtn, showRows)
        SetFugaziControlEnabled(iconColorBtn, showRows)

        if rarityColorLabel then
            rarityColorLabel:SetAlpha(showRows and 1.0 or 0.3)
        end

        -- Icons should always be visible and move together
        SetFugaziControlEnabled(itemDetailsIconSizeSlider, true)
        if itemDetailsIconSizeSlider then
            itemDetailsIconSizeSlider:Show()
        end
    end

    local function ResetSkinDefaults()
        if _G.ApplyFugaziPreset then
            _G.ApplyFugaziPreset()
        end
        panel.refresh()
        if _G.ApplyTestSkin then
            _G.ApplyTestSkin()
        end
        RefreshAllUI()
    end

    panel.default = ResetSkinDefaults

    local resetBtnSkins = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtnSkins:SetSize(120, 22)
    resetBtnSkins:SetPoint("BOTTOMLEFT", 16, 16)
    resetBtnSkins:SetText("Reset Defaults")
    SkinButton(resetBtnSkins)
    resetBtnSkins:SetScript("OnClick", ResetSkinDefaults)

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

--- Instructions / help panel in options.
--- Clean, gamer-friendly rewrite: restrained colors, scannable sections, current feature set.
local function CreateInstructionsPanel()
    if _G.FugaziBAGSInstructionsOptionsPanel then
        return
    end

    local panel = CreateFrame("Frame", "FugaziBAGSInstructionsOptionsPanel", UIParent)
    panel.name = "Instructions"
    panel.parent = "_FugaziBAGS"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end
    panel.refresh = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("FugaziBAGS - Quick Guide")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetTextColor(0.72, 0.72, 0.72)
    subtitle:SetText("What it does, shortcuts, and the tools you'll actually use while farming.")

    local scrollFrame =
        CreateFrame("ScrollFrame", "FugaziBAGSInstructionsOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -52)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(1)
    content:SetHeight(1)
    scrollFrame:SetScrollChild(content)

    -- Layout constants (3.3.5 Interface Options content area is ~600 wide with scrollbar).
    local TEXT_W = 540
    local SECTION_GAP = 12
    local BODY_GAP = 4

    -- Restrained palette: gold headers, cyan shortcuts, soft red only for destructive actions.
    local KEY = "|cff69ccf0" -- keybind / click
    local WARN = "|cffff8888" -- delete / danger
    local MUTED = "|cff999999" -- asides
    local R = "|r"

    local y = 0
    local function addHeader(label)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        fs:SetJustifyH("LEFT")
        fs:SetText(label)
        y = y - (fs:GetStringHeight() or 14) - BODY_GAP
        return fs
    end

    local function addBody(lines)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        fs:SetWidth(TEXT_W)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetTextColor(0.92, 0.92, 0.92)
        fs:SetText(table.concat(lines, "\n"))
        y = y - (fs:GetStringHeight() or 0) - SECTION_GAP
        return fs
    end

    -- ── Overview ──────────────────────────────────────────────────────────
    addHeader("What is FugaziBAGS?")
    addBody({
        "A single inventory window (plus matching bank) that replaces the default bags.",
        "Built for farmers: protect keepers, nuke junk, vendor safely, bulk mail,",
        "and track gold/hour - all from one place.",
        MUTED .. "Optional companion: Fugazi Instance Tracker (lockouts + run ledger)." .. R,
    })

    -- Basics
    addHeader("Opening & basics")
    addBody({
        "-  " .. KEY .. "B" .. R .. "  -  open / close inventory (instead of Blizzard bags)",
        "-  " .. KEY .. "Right-click" .. R .. " the inventory title bar  -  full menu (settings, sort, views, tools)",
        "-  Search box  -  filters by name, type/subtype, tooltip text/stats, quality names,",
        "     and valuation keywords (auction, vendor, disenchant, prospect, mill)",
        "-  Title menu -> List View / Grid View  -  switch layout",
        "-  " .. KEY .. "Ctrl + Left-click" .. R .. " bag-space number  -  show / hide bag + keyring bar",
        "-  Escape -> Interface -> AddOns -> _FugaziBAGS  -  options, scale, skins, valuation",
    })

    -- Shortcuts
    addHeader("Item shortcuts")
    addBody({
        "-  " .. KEY .. "Alt + Left-click" .. R .. " an item  -  protect / unprotect",
        "-  "
            .. KEY
            .. "Ctrl + Right-click twice"
            .. R
            .. " an item  -  add to "
            .. WARN
            .. "auto-delete"
            .. R
            .. " list",
        "     (first click pulses red; second click confirms)",
        "",
        MUTED .. "Protected items are skipped by autosell, mass-mail, mass-DE, and auto-delete." .. R,
        MUTED .. "List view: protected items sort above the Hearthstone at the top of the list." .. R,
        MUTED .. "Grid view: protected items show an overlay." .. R,
    })

    -- Rarity bar (kept short - paint model)
    addHeader("Rarity bar")
    addBody({
        "The colored buttons at the top of inventory (and bank):",
        "",
        "-  " .. KEY .. "Left-click" .. R .. "  -  toggle that quality in the filter",
        "     Drag across buttons to multi-filter (e.g. green + blue together)",
        "-  " .. KEY .. "Right-click" .. R .. "  -  clear all rarity filters",
        "-  " .. KEY .. "Alt + Left-click" .. R .. "  -  protect that whole quality (this character)",
        "     Drag with Alt held to protect (or unprotect) several qualities at once",
        "     Single-item unprotect still overrides rarity protection",
        "-  "
            .. KEY
            .. "Ctrl + Left-click x3"
            .. R
            .. "  -  "
            .. WARN
            .. "continuous auto-delete"
            .. R
            .. " that quality",
        "-  "
            .. KEY
            .. "Ctrl + Right-click x3"
            .. R
            .. "  -  "
            .. WARN
            .. "delete all"
            .. R
            .. " of that quality in bags now",
    })

    -- Move workers (separate section)
    addHeader("Moving items (bank / mail)")
    addBody({
        "With bank, guild bank, or mailbox open:",
        "",
        "-  " .. KEY .. "Shift + Right-click" .. R .. " a rarity button  -  move that quality",
        "     Bags -> bank / guild bank / mail (Send tab + recipient required)",
        "     Bank rarity bar: moves that quality bank -> bags",
        "-  " .. KEY .. "Shift + Right-click" .. R .. " a category header (list view)  -  same move for that category",
        "",
        MUTED .. "Moves respect the search box and active rarity filters." .. R,
    })

    -- Auto-delete
    addHeader("Auto-delete list")
    addBody({
        "Per-character list of item IDs destroyed when they enter your bags.",
        "",
        "-  "
            .. KEY
            .. "Ctrl + Right-click twice"
            .. R
            .. " an item  -  add to "
            .. WARN
            .. "auto-delete"
            .. R
            .. " list",
        "     (first click pulses red; second click confirms)",
        "-  Remove: " .. KEY .. "Right-click" .. R .. " the entry at the bottom of list view,",
        "     or remove it from the list in Escape -> options",
        "-  Copy another character's list or full settings from the main options panel",
        '-  "Confirm Auto Delete"  -  warning popup before adding',
        "-  Title menu -> Autodelete  -  pause / resume without clearing the list",
    })

    -- Protection / worn
    addHeader("Protection & previously worn gear")
    addBody({
        "Mark keepers with " .. KEY .. "Alt + Left-click" .. R .. " or by rarity (see above).",
        'Gear you have worn on this character can show "Previously worn gear" on the tooltip',
        'and stays protected when "Protect Previously Worn" is enabled in options.',
    })

    -- Mail
    addHeader("Mail")
    addBody({
        "Mail icon on the inventory title bar (while the mailbox is open):",
        "",
        "-  Inbox tab  -  " .. KEY .. "Get All Mail" .. R .. ": loot attachments + gold, leave 1 free bag slot,",
        "     then clean emptied leftover mails",
        "-  Send tab  -  " .. KEY .. "Send All Items" .. R .. ": send unprotected, non-quest bag items",
        "     to the current recipient (respects search + rarity filters if active)",
        MUTED .. "Icon switches between receive / send so you can see which mode you're in." .. R,
    })

    -- Tools
    addHeader("Tools on the inventory")
    addBody({
        "-  Profession buttons  -  Disenchant / Prospect / Mill / Open / Learn when something is usable",
        "-  Clean up Inventory  -  title menu: pack bags (sort)",
        "-  Autoselling  -  title menu toggle; greys / junk per your options",
        "-  Autosell EVERYTHING!  -  options (dangerous): sells all unprotected rare-or-lower at vendors",
        "-  Notepad  -  title menu: simple multi-tab notes",
        "-  Ascension: Add all to Wardrobe  -  title menu when available",
    })

    -- GPH
    addHeader("Gold per hour (GPH)")
    addBody({
        "Start a session from the inventory title menu (Session / Start timer).",
        "While running, the top bar shows gold earned, timer, and GPH.",
        "",
        "How session value is estimated:",
        "-  Poor (grey)  -  vendor price",
        "-  Common+ (non-soulbound)  -  85% of auction min buyout (AH tax cut),",
        "     using Auctionator or TSM price data when available",
        "     (if you vendor the item, vendor price is used instead)",
        "-  Soulbound and previously worn gear  -  ignored (can't tell sell from keep)",
        "",
        MUTED .. "You need Auctionator or TSM with price data for AH estimates to be meaningful." .. R,
        MUTED .. "With Instance Tracker installed, runs feed the Ledger for history and loot stamps." .. R,
    })

    -- FIT
    addHeader("Instance Tracker (optional add-on)")
    addBody({
        "Requires FugaziBAGS. Separate folder: __FugaziInstanceTracker.",
        "-  " .. KEY .. "/fit" .. R .. "  -  instance window (hourly cap on classic, lockouts; Ascension-aware)",
        "-  " .. KEY .. "/ledger" .. R .. "  -  run history, loot, repairs, autodelete stats",
        "-  Shares skins and protection/valuation rules with FugaziBAGS",
    })

    -- Options map
    addHeader("Where to configure things")
    addBody({
        "-  Main (_FugaziBAGS)  -  confirm delete, autosell, worn protect, BoP confirm,",
        "     auto quest/gossip, sounds, auto-delete list + copy",
        "-  Scale Settings  -  inventory / bank size and layout",
        "-  Skins  -  look and feel (works with ElvUI-style presets)",
        "-  Valuation Engine  -  min AH value / profit / force-destroy rules by quality",
        "-  This tab  -  the guide you're reading",
    })

    -- Safety
    addHeader("Safety notes")
    addBody({
        "Destructive tools only respect " .. KEY .. "this" .. R .. " add-on's protection.",
        "Other vendor/cleanup add-ons can still sell or delete items you marked safe here.",
        "Leave Confirm Auto Delete on until you're comfortable with your lists.",
        MUTED .. "Use at your own risk - especially continuous delete and Autosell EVERYTHING." .. R,
    })

    content:SetWidth(TEXT_W)
    content:SetHeight(math.max(1, -y + 8))

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

--------------------------------------------------------------------------------
-- 6. CONTEXT MENUS & RARITY INTERACTIONS (Migrated from Listview.lua)
--------------------------------------------------------------------------------

--- Initialize the main right-click context menu (Title bar).
function A.GPHTitleMenu_Initialize(self, level)
    local f = self:GetParent() -- The main window (FugaziBAGS_GPHFrame)
    local info = UIDropDownMenu_CreateInfo()
    local SV = _G.FugaziBAGSDB
    if not level or level == 1 then
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cffff4444Close Inventory|r"
        info.func = function()
            if A.ToggleGPHFrame then
                A.ToggleGPHFrame()
            end
            CloseDropDownMenus()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "|cff888888Settings|r"
        info.func = function()
            if InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory("_FugaziBAGS")
                InterfaceOptionsFrame_OpenToCategory("_FugaziBAGS")
            end

            CloseDropDownMenus()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "|cff00ccffClean up Inventory|r"
        info.func = function()
            if A.GPH_BagSort_Run then
                A.GPH_BagSort_Run(_G.RefreshGPHUI)
            end
            CloseDropDownMenus()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        -- Ascension-only wardrobe scanning
        if A.IsAscension and A.IsAscension() and not A.IsEbonhold() then
            info = UIDropDownMenu_CreateInfo()
            info.text = "|cffff80ffAdd all to Wardrobe|r"
            info.tooltipTitle = "Add all to Wardrobe"
            info.tooltipText = "Scans all bags and collects missing appearances for your Wardrobe."
            info.func = function()
                local c = _G.C_AppearanceCollection
                if c then
                    for b = 0, 4 do
                        local num = GetContainerNumSlots(b)
                        if num and num > 0 then
                            for s = 1, num do
                                local itemID = (_G.GetContainerItemID and _G.GetContainerItemID(b, s))
                                    or (GetContainerItemID and GetContainerItemID(b, s))
                                if itemID then
                                    local appID = _G.C_Appearance and _G.C_Appearance.GetItemAppearanceID(itemID)
                                    if appID and not c.IsAppearanceCollected(appID) then
                                        local guid = (_G.GetContainerItemGUID and _G.GetContainerItemGUID(b, s))
                                            or (GetContainerItemGUID and GetContainerItemGUID(b, s))
                                        if guid then
                                            c.CollectItemAppearance(guid)
                                        end
                                    end
                                end
                            end
                        end
                    end
                    C_Timer.After(0.5, function()
                        local A = _G.FugaziBAGS
                        if A and A._gphWardrobeCache then
                            wipe(A._gphWardrobeCache)
                        end
                        if A then
                            A._gphBagSpaceDirty = true
                        end
                        -- Wardrobe bind-on-collect flips BoE → soulbound; drop sticky DE valuation.
                        if A and A.InvalidateValuationCache then
                            A.InvalidateValuationCache("wardrobe")
                        end
                        if _G.RefreshGPHUI then
                            _G.RefreshGPHUI()
                        end
                    end)
                end
                CloseDropDownMenus()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        -- Group: Session (Injected by FIT)
        if A.GPHTitleMenu_InjectSession then
            info = UIDropDownMenu_CreateInfo()
            info.text = ""
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
            A.GPHTitleMenu_InjectSession(self, level)
            info = UIDropDownMenu_CreateInfo()
            info.text = ""
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        -- Group: Tools (Notepad + Tracker/Ledger)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Notepad"
        info.func = function()
            if A.ToggleGPHNotepad then
                A.ToggleGPHNotepad()
            end
            CloseDropDownMenus()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        if A.GPHTitleMenu_InjectTrackerStats then
            A.GPHTitleMenu_InjectTrackerStats(self, level)
        end

        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Autoselling"
        info.isNotRadio = true
        info.checked = (SV.gphAutoVendor == true)
        info.func = function()
            if not SV.gphAutoVendor then
                StaticPopup_Show("GPH_AUTOSELL_CONFIRM")
            else
                SV.gphAutoVendor = false
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)

        if A.IsEbonhold() then
            local Loc = A.L
            info = UIDropDownMenu_CreateInfo()
            info.text = (Loc and Loc.LABEL_AUTOSUMMON_GREEDY) or "Autosummon Greedy scavenger"
            info.isNotRadio = true
            info.checked = (SV.gphSummonGreedy ~= false)
            info.func = function()
                SV.gphSummonGreedy = not SV.gphSummonGreedy
            end
            UIDropDownMenu_AddButton(info)

            info = UIDropDownMenu_CreateInfo()
            info.text = (Loc and Loc.LABEL_SUMMON_GREEDY_SCAVENGER) or "Summon Greedy scavenger"
            info.func = function()
                A.DoGphSummonGreedyNow()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)

            info = UIDropDownMenu_CreateInfo()
            info.text = (Loc and Loc.LABEL_SUMMON_GOBLIN_MERCHANT) or "Summon Goblin Merchant"
            info.func = function()
                A.DoGphSummonGoblinMerchantNow()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)

            info = UIDropDownMenu_CreateInfo()
            info.text = ""
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        info = UIDropDownMenu_CreateInfo()
        info.text = "Autodelete"
        info.isNotRadio = true
        info.checked = not A.GetPerChar("gphPauseAutodelete", false)
        info.func = function()
            local newState = not A.GetPerChar("gphPauseAutodelete", false)
            A.SetPerChar("gphPauseAutodelete", newState)
            if not newState then
                if A.ScanBagsForDestruction then
                    A.ScanBagsForDestruction()
                end
            else
                if A.destroyQueue then
                    wipe(A.destroyQueue)
                end
            end
        end
        UIDropDownMenu_AddButton(info)

        if MailFrame and MailFrame:IsShown() and f.gphMailBtn then
            info = UIDropDownMenu_CreateInfo()
            info.text = "Get All Mail"
            info.func = function()
                if f.gphMailBtn and f.gphMailBtn:GetScript("OnClick") then
                    f.gphMailBtn:GetScript("OnClick")(f.gphMailBtn)
                end
                CloseDropDownMenus()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        if not f.gphGridMode then
            info = UIDropDownMenu_CreateInfo()
            info.text = "Sort"
            info.hasArrow = true
            info.value = "SORT"
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)
        local gridMode = A.GetPerChar("gphGridMode", false)
        info = UIDropDownMenu_CreateInfo()
        info.text = (not gridMode) and "|cff00ff00List View|r" or "List View"
        info.checked = not gridMode
        info.func = function()
            A.SetPerChar("gphGridMode", false)
            f.gphGridMode = false
            local cg = _G.FugaziBAGS_CombatGrid
            if cg and cg.HideInFrame then
                cg.HideInFrame(f)
            end
            if _G.RefreshGPHUI then
                f._refreshImmediate = true
                _G.RefreshGPHUI()
            end
            if f.RefreshBagLayout then
                f:RefreshBagLayout()
            end
            if f.NegotiateSizes then
                f:NegotiateSizes()
            end
            if A.Bank and A.Bank:IsShown() then
                ForceRefreshBankUI()
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = gridMode and "|cff00ff00Grid View|r" or "Grid View"
        info.checked = gridMode
        info.func = function()
            A.SetPerChar("gphGridMode", true)
            f.gphGridMode = true
            local cg = _G.FugaziBAGS_CombatGrid
            if cg and cg.ShowInFrame then
                cg.ShowInFrame(f)
            end
            if _G.RefreshGPHUI then
                _G.RefreshGPHUI()
            end
            if f.NegotiateSizes then
                f:NegotiateSizes()
            end
            if A.Bank and A.Bank:IsShown() then
                ForceRefreshBankUI()
            end
            CloseDropDownMenus()
        end
        UIDropDownMenu_AddButton(info)
    elseif level == 2 and UIDROPDOWNMENU_MENU_VALUE == "SORT" then
        local isAsc = A.IsAscension and A.IsAscension()
        if isAsc and (SV.gphSortMode == "vendor" or SV.gphSortMode == "itemlevel") then
            SV.gphSortMode = "rarity"
        end
        local modes = {}
        table.insert(modes, { val = "rarity", text = "Rarity" })
        if not isAsc then
            table.insert(modes, { val = "vendor", text = "Vendorprice" })
            table.insert(modes, { val = "itemlevel", text = "ItemLvl" })
        end
        table.insert(modes, { val = "category", text = "Category" })
        for _, m in ipairs(modes) do
            info = UIDropDownMenu_CreateInfo()
            info.text = m.text
            info.checked = (SV.gphSortMode == m.val)
            info.func = function()
                SV.gphSortMode = m.val
                if _G.RefreshGPHUI then
                    f._refreshImmediate = true
                    _G.RefreshGPHUI()
                end
                if A.Bank and A.Bank:IsShown() then
                    ForceRefreshBankUI()
                end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

-- Expose panel creators so FugaziBAGS_Initialize.lua RunAddonLoader can call them via A.

local function CreateValuationOptionsPanel()
    -- Named CreateFrame sets the global immediately; a mid-build error used to leave a
    -- half-built frame and then early-return forever. Only skip when fully ready.
    if _G.FugaziBAGSValuationOptionsPanel and _G.FugaziBAGSValuationOptionsPanel._fbagsReady then
        return
    end
    local ok, err = pcall(function()
        local panel = _G.FugaziBAGSValuationOptionsPanel
        if not panel then
            panel = CreateFrame("Frame", "FugaziBAGSValuationOptionsPanel", UIParent)
        end
        panel.name = "Valuation Engine"
        panel.parent = "_FugaziBAGS"
        -- Force-commit any dirty valuation text boxes, then snapshot the char profile.
        -- Without this, Okay can run before focus-loss and leave floors only in the editbox.
        panel.okay = function()
            -- Commit only boxes the user actually edited. force=true would re-parse a
            -- blank display glitch as 0 and wipe a saved floor.
            for qId = 1, 4 do
                for _, suf in ipairs({ "_minAhValue", "_minAhProfit", "_forceDestroy" }) do
                    local box = _G["FugaziBAGS_Q" .. qId .. suf]
                    if box and box._fbagsCommit then
                        box:_fbagsCommit(false)
                    end
                end
            end
            if A.SnapshotCharSettings then
                A.SnapshotCharSettings()
            elseif A.PersistPrefTable then
                A.PersistPrefTable("valuationMatrix")
            end
        end
        panel.cancel = function()
            -- Drop uncommitted typing; next OnShow reloads from SV.
            for qId = 1, 4 do
                for _, suf in ipairs({ "_minAhValue", "_minAhProfit", "_forceDestroy" }) do
                    local box = _G["FugaziBAGS_Q" .. qId .. suf]
                    if box then
                        box._fbagsDirty = false
                    end
                end
            end
        end
        panel.default = function() end
        panel._fbagsReady = false

        -- Hide any orphan widgets from a previous failed build (same session /reload edge).
        if panel._fbagsWidgets then
            for _, w in ipairs(panel._fbagsWidgets) do
                if w and w.Hide then
                    w:Hide()
                end
                if w and w.SetParent then
                    w:SetParent(nil)
                end
            end
        end
        panel._fbagsWidgets = {}
        local function track(w)
            if w then
                table.insert(panel._fbagsWidgets, w)
            end
            return w
        end

        local title = track(panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge"))
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Valuation Engine")

        local subtext = track(panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"))
        subtext:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        subtext:SetPoint("RIGHT", panel, "RIGHT", -32, 0)
        subtext:SetJustifyH("LEFT")
        subtext:SetText(
            "Decide what each item is “worth doing”: Auction, Vendor, or Destroy (disenchant / mill / prospect). Used for bag icons, filtered auto-sell, and farming value."
        )

        -- Global Toggles
        local yOff = -65
        local function CreateGlobalCheck(name, label, key, default, offsetX, offsetY, tooltipText)
            -- Reuse existing named check if a failed build already created it.
            local cb = _G[name]
            if not cb then
                cb = CreateFrame("CheckButton", name, panel, "OptionsCheckButtonTemplate")
            else
                cb:SetParent(panel)
                cb:Show()
            end
            track(cb)
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", panel, "TOPLEFT", offsetX, offsetY)

            local fs = _G[cb:GetName() .. "Text"]
            if fs then
                fs:SetText(label)
            end

            local SV = _G.FugaziBAGSDB
            local init = (SV and SV[key])
            if init == nil then
                init = default
            end
            cb:SetChecked(init)

            cb:SetScript("OnClick", function(self)
                local checked = (self:GetChecked() == 1 or self:GetChecked() == true)
                if A.SetOption then
                    A.SetOption(key, checked)
                elseif _G.FugaziBAGSDB then
                    _G.FugaziBAGSDB[key] = checked
                end
                -- Phase 4: valuation toggles must drop cached price/action results
                if key == "evaluateDisenchant" or key == "evaluateProspect" or key == "evaluateMilling" then
                    if A.InvalidateValuationCache then
                        A.InvalidateValuationCache(key)
                    end
                end
                if RefreshAllUI then
                    RefreshAllUI()
                end
            end)

            if tooltipText then
                cb:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(label, 1, 0.82, 0)
                    GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                cb:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            end

            SkinCheckBox(cb)
            return cb
        end

        local cbFiltered = CreateGlobalCheck(
            "FugaziBAGSEnableFilteredAutoSell",
            "Enable Filtered Auto-Sell",
            "enableFilteredAutoSell",
            false,
            16,
            yOff,
            "At a vendor: only auto-sell items this engine marks as Vendor.\n\nIf the best action is Auction or Destroy, that item is NOT sold.\n\nTurns off “Autosell Everything” when enabled.\nDoes not need “Always Valuate Items” — selling still uses the engine in the background."
        )
        cbFiltered:HookScript("OnClick", function(self)
            local checked = (self:GetChecked() == 1 or self:GetChecked() == true)
            if checked and A.SetPerChar then
                A.SetPerChar("gphAutosellEverything", false)
                if _G.FugaziBAGSAutosellEverythingCheck then
                    _G.FugaziBAGSAutosellEverythingCheck:SetChecked(false)
                end
            end
        end)
        CreateGlobalCheck(
            "FugaziBAGSEvaluateDisenchant",
            "Evaluate Disenchanting",
            "evaluateDisenchant",
            false,
            16,
            yOff - 30,
            "Include disenchant value (dust / essences / shards) when comparing options.\n\nUses your AH price source (Auctionator / TSM) when available, otherwise built-in tables.\n\nTurn this on if you want Destroy icons and “force destroy” to work for gear."
        )
        CreateGlobalCheck(
            "FugaziBAGSEvaluateProspect",
            "Evaluate Prospecting",
            "evaluateProspect",
            false,
            16,
            yOff - 60,
            "Include prospecting value (gems from ore) when comparing options.\n\nOnly matters for ores that can be prospected."
        )
        CreateGlobalCheck(
            "FugaziBAGSEvaluateMilling",
            "Evaluate Milling",
            "evaluateMilling",
            false,
            16,
            yOff - 90,
            "Include milling value (pigments / inks from herbs) when comparing options.\n\nOnly matters for herbs that can be milled."
        )

        -- Column 2: valuation icons + always valuate
        local cbShowIcons = CreateGlobalCheck(
            "FugaziBAGSShowValuationIcons",
            "Show Valuation Icons",
            "showValuationIcons",
            true,
            230,
            yOff,
            nil
        )
        -- Icon legend only (textures match bag/list valIcon). FontString tooltips cannot draw icons without |T.
        cbShowIcons:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Show Valuation Icons", 1, 0.82, 0)
            GameTooltip:AddLine("Small corner icons on bag items for the suggested action:", 0.9, 0.9, 0.9, true)
            GameTooltip:AddLine(" ", 1, 1, 1)
            local ic = (_G.FugaziBAGS and _G.FugaziBAGS.VALUATION_ACTION_ICONS) or {}
            local function tipIcon(action, label)
                local path = ic[action] or ""
                if path ~= "" then
                    GameTooltip:AddLine("|T" .. path .. ":18:18|t  " .. label, 1, 1, 1)
                else
                    GameTooltip:AddLine(label, 1, 1, 1)
                end
            end
            tipIcon("AH", "Auction")
            tipIcon("VENDOR", "Vendor")
            tipIcon("DE", "Disenchant")
            tipIcon("PROSPECT", "Prospecting")
            tipIcon("MILL", "Milling")
            GameTooltip:AddLine(" ", 1, 1, 1)
            GameTooltip:AddLine(
                "Which items show icons depends on “Always Valuate Items” (or an active farm session).",
                0.75,
                0.75,
                0.75,
                true
            )
            GameTooltip:Show()
        end)
        cbShowIcons:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        CreateGlobalCheck(
            "FugaziBAGSAlwaysValuateItems",
            "Always Valuate Items",
            "alwaysValuateItems",
            false,
            230,
            yOff - 30,
            "Show valuation icons on everything in your bags, even outside a farm session.\n\nWithout this: icons mainly appear for loot from an active GPH / farming session (so random bag clutter stays quiet).\n\nThis is for your eyes — filtered auto-sell and session gold still work without it.\nMay add a little lag when looting huge piles."
        )

        -- Hide leftover widgets from older panel builds (g/s/c boxes, op buttons, globals).
        do
            local stale = {
                "FugaziBAGSminAuctionCopperGold",
                "FugaziBAGSminAuctionCopperSilver",
                "FugaziBAGSminAuctionCopperCopper",
                "FugaziBAGSminAuctionProfitCopperGold",
                "FugaziBAGSminAuctionProfitCopperSilver",
                "FugaziBAGSminAuctionProfitCopperCopper",
                "FugaziBAGSMinAhProfitPct",
            }
            for qId = 1, 4 do
                for _, suf in ipairs({
                    "_minAuctionCopperG",
                    "_minAuctionCopperS",
                    "_minAuctionCopperC",
                    "_minAuctionProfitCopperG",
                    "_minAuctionProfitCopperS",
                    "_minAuctionProfitCopperC",
                    "_minAuctionProfitPct",
                }) do
                    stale[#stale + 1] = "FugaziBAGS_Q" .. qId .. suf
                end
                for _, key in ipairs({ "destroy", "vendor", "ah" }) do
                    for _, suf in ipairs({ "Min", "Max", "Op" }) do
                        stale[#stale + 1] = "FugaziBAGSMatrix" .. qId .. key .. suf
                    end
                end
            end
            for _, name in ipairs(stale) do
                local f = _G[name]
                if f then
                    f:Hide()
                    f:SetParent(nil)
                end
            end
        end

        -- Helpers shared by each rarity column
        local function GetOrCreateNamed(kind, name, template)
            local f = _G[name]
            if not f then
                -- Omit nil template: some 3.3.5 clients dislike CreateFrame(..., nil).
                if template then
                    f = CreateFrame(kind, name, panel, template)
                else
                    f = CreateFrame(kind, name, panel)
                end
            else
                f:SetParent(panel)
                f:Show()
            end
            track(f)
            return f
        end

        local function EnsureMatrix(qId)
            if not _G.FugaziBAGSDB then
                return nil
            end
            local SV = _G.FugaziBAGSDB
            if type(SV.valuationMatrix) ~= "table" then
                -- Prefer a deep copy of defaults so we never mutate the shared DEFAULTS table.
                local base = A._ConfigDefaults and A._ConfigDefaults.valuationMatrix
                if A.DeepCopy and type(base) == "table" then
                    SV.valuationMatrix = A.DeepCopy(base)
                else
                    SV.valuationMatrix = {}
                end
            end
            local m = SV.valuationMatrix
            if type(m[qId]) ~= "table" then
                -- SavedVariables can rehydrate quality keys as strings ("1") vs numbers (1).
                local alt = m[tostring(qId)]
                if type(alt) == "table" then
                    m[qId] = alt
                    m[tostring(qId)] = nil
                else
                    -- Seed full default row so missing floors aren't nil forever.
                    local base = A._ConfigDefaults and A._ConfigDefaults.valuationMatrix
                    local row = base and (base[qId] or base[tostring(qId)])
                    if A.DeepCopy and type(row) == "table" then
                        m[qId] = A.DeepCopy(row)
                    else
                        m[qId] = {}
                    end
                end
            end
            -- Nested floors (min AH etc.) must live on the character profile for Copy settings.
            if A.SyncPrefTable then
                A.SyncPrefTable("valuationMatrix")
            end
            return m[qId]
        end

        --- lines: array of { text, r, g, b, wrap }  (r/g/b optional, wrap optional)
        local function AttachTip(widget, title, lines)
            widget:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:SetText(title, 1, 0.82, 0)
                if type(lines) == "string" then
                    GameTooltip:AddLine(lines, 1, 1, 1, true)
                elseif type(lines) == "table" then
                    for _, row in ipairs(lines) do
                        if type(row) == "string" then
                            GameTooltip:AddLine(row, 1, 1, 1, true)
                        elseif type(row) == "table" then
                            local t = row[1] or row.text or ""
                            if t == "" then
                                GameTooltip:AddLine(" ")
                            else
                                local r = row[2] or row.r or 1
                                local g = row[3] or row.g or 1
                                local b = row[4] or row.b or 1
                                local wrap = row[5]
                                if wrap == nil then
                                    wrap = row.wrap
                                end
                                if wrap == nil then
                                    wrap = true
                                end
                                GameTooltip:AddLine(t, r, g, b, wrap)
                            end
                        end
                    end
                end
                GameTooltip:Show()
            end)
            widget:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        local function TrimText(s)
            s = tostring(s or "")
            return (s:gsub("^%s+", ""):gsub("%s+$", ""))
        end

        --- True if text contains a % character (plain search — one %).
        local function HasPercentSign(text)
            return text:find("%", 1, true) ~= nil
        end

        --- Parse "2g 25s", "10s", "50c", "2g25s0c", empty/0/off.
        --- Unit letter required (bare "20" is invalid — too ambiguous).
        --- s and c must each be 0-99 (use 5s not 500c).
        --- Returns ok, copper.
        local function ParseMoneyText(text)
            text = TrimText(text):lower():gsub(",", "")
            if text == "" or text == "0" or text == "-" or text == "off" then
                return true, 0
            end
            if HasPercentSign(text) then
                return false, 0
            end

            local g, s, c = 0, 0, 0
            local found = false
            local rest = text

            local mg = rest:match("(%d+)%s*g")
            if mg then
                g = tonumber(mg) or 0
                found = true
                rest = rest:gsub("%d+%s*g", " ", 1)
            end
            local ms = rest:match("(%d+)%s*s")
            if ms then
                s = tonumber(ms) or 0
                found = true
                rest = rest:gsub("%d+%s*s", " ", 1)
            end
            local mc = rest:match("(%d+)%s*c")
            if mc then
                c = tonumber(mc) or 0
                found = true
                rest = rest:gsub("%d+%s*c", " ", 1)
            end

            rest = TrimText(rest)
            -- Leftover text (including bare digits with no unit) = invalid
            if rest ~= "" then
                return false, 0
            end
            if not found then
                return false, 0
            end
            if s > 99 or c > 99 then
                return false, 0
            end
            return true, (g * 10000) + (s * 100) + c
        end

        --- Parse money OR percent (exclusive). Returns ok, kind ("empty"|"money"|"pct"), value.
        local function ParseMoneyOrPctText(text)
            text = TrimText(text):lower():gsub(",", "")
            if text == "" or text == "0" or text == "-" or text == "off" then
                return true, "empty", 0
            end
            if HasPercentSign(text) then
                -- Accept "20%", "20 %", "20.5%"
                local p = text:match("^(%d+%.?%d*)%s*%%$")
                if not p then
                    return false, nil, 0
                end
                p = tonumber(p)
                if not p or p < 0 or p > 9999 then
                    return false, nil, 0
                end
                return true, "pct", math.floor(p)
            end
            local ok, copper = ParseMoneyText(text)
            if not ok then
                return false, nil, 0
            end
            return true, "money", copper
        end

        --- Force-destroy iLvl rule. Returns ok, min, max, op.
        --- Accepts: empty, <30, >50, >=50, =>50, <=55, 50-55, 50, ilvl=50-55, ilvl>50
        local function ParseForceDestroyText(text)
            text = TrimText(text):lower()
            text = text:gsub("^ilvl%s*=%s*", "")
            text = text:gsub("^ilvl%s*", "")
            text = TrimText(text)
            if text == "" or text == "-" or text == "off" or text == "0" then
                return true, 0, 0, "-"
            end

            local n = text:match("^>=%s*(%d+)$") or text:match("^=>%s*(%d+)$")
            if n then
                return true, tonumber(n), 0, "-"
            end -- range min..9999 via max=0
            n = text:match("^>%s*(%d+)$")
            if n then
                return true, 0, tonumber(n), ">"
            end
            n = text:match("^<=%s*(%d+)$")
            if n then
                return true, 0, tonumber(n), "-"
            end
            n = text:match("^<%s*(%d+)$")
            if n then
                return true, 0, tonumber(n), "<"
            end

            local a, b = text:match("^(%d+)%s*%-%s*(%d+)$")
            if a and b then
                a, b = tonumber(a), tonumber(b)
                if a > b then
                    a, b = b, a
                end
                return true, a, b, "-"
            end

            n = text:match("^(%d+)$")
            if n then
                n = tonumber(n)
                return true, n, n, "-"
            end
            return false, 0, 0, "-"
        end

        local function FormatCopperShort(copper)
            copper = math.max(0, math.floor(tonumber(copper) or 0))
            if copper <= 0 then
                return ""
            end
            local g = math.floor(copper / 10000)
            local s = math.floor((copper % 10000) / 100)
            local c = copper % 100
            local parts = {}
            if g > 0 then
                parts[#parts + 1] = g .. "g"
            end
            if s > 0 then
                parts[#parts + 1] = s .. "s"
            end
            if c > 0 or #parts == 0 then
                parts[#parts + 1] = c .. "c"
            end
            return table.concat(parts, " ")
        end

        local function FormatForceDestroy(minV, maxV, op)
            minV = tonumber(minV) or 0
            maxV = tonumber(maxV) or 0
            op = op or "-"
            if minV == 0 and maxV == 0 then
                return ""
            end
            if op == "<" then
                return "<" .. tostring((maxV > 0) and maxV or minV)
            end
            if op == ">" then
                return ">" .. tostring((maxV > 0) and maxV or minV)
            end
            if minV > 0 and maxV > 0 then
                if minV == maxV then
                    return tostring(minV)
                end
                return tostring(minV) .. "-" .. tostring(maxV)
            end
            if minV > 0 and maxV == 0 then
                return ">=" .. tostring(minV)
            end
            if minV == 0 and maxV > 0 then
                return "<=" .. tostring(maxV)
            end
            return ""
        end

        local function SetBoxValid(box, ok)
            -- Green = valid format, red = invalid. Always pass alpha so text stays opaque.
            if ok then
                box:SetTextColor(0.45, 1.0, 0.45, 1)
            else
                box:SetTextColor(1.0, 0.35, 0.35, 1)
            end
        end

        --- Apply text to a valuation editbox without dirtying / wiping SV.
        local function ApplyBoxText(box, t)
            if not box or not box.SetText then
                return
            end
            t = t or ""
            box._fbagsSuppress = true
            box:SetText(t)
            box._fbagsLastGood = t
            box._fbagsDirty = false
            box._fbagsSuppress = false
            -- 3.3.5: nudge caret so unfocused text actually paints after SetText.
            if box.SetCursorPosition then
                box:SetCursorPosition(0)
            end
            SetBoxValid(box, true)
        end

        local function MakeFreeTextBox(name, width)
            -- Bare EditBox (no InputBoxTemplate). Template Left/Middle/Right art is a known
            -- cause of "saved text looks blank when unfocused" on 3.3.5a; scroll/ping work
            -- with the template + SkinEditBox, but free-text valuation boxes still blanked.
            -- Match scroll-step size/skin + always set a font (bare EditBox needs one).
            local box = GetOrCreateNamed("EditBox", name, nil)
            box:SetSize(width, 22)
            box:SetAutoFocus(false)
            box:SetNumeric(false)
            box:SetMaxLetters(24)
            box:EnableMouse(true)
            if box.SetFontObject and ChatFontNormal then
                box:SetFontObject(ChatFontNormal)
            elseif box.SetFont then
                box:SetFont("Fonts\\FRIZQT__.TTF", 13, "")
            end
            if SkinEditBox then
                SkinEditBox(box)
            else
                box:SetTextInsets(6, 6, 0, 0)
            end
            -- If this name was previously an InputBoxTemplate frame, hide leftover art.
            local n = box:GetName()
            if n then
                for _, suf in ipairs({ "Left", "Middle", "Right" }) do
                    local tex = _G[n .. suf]
                    if tex and tex.Hide then
                        tex:Hide()
                    end
                end
            end
            box:SetTextColor(0.45, 1.0, 0.45, 1)
            return box
        end

        --- Validate live; write only on Enter / explicit commit (not every focus-loss).
        local function BindValidatedBox(box, lastGood, onValidParse)
            box._fbagsLastGood = lastGood or ""
            box._fbagsDirty = false
            box._fbagsCommit = function(self, force)
                self = self or box
                if not force and not self._fbagsDirty then
                    return true
                end
                local text = self:GetText() or ""
                local ok = onValidParse(text, true)
                if not ok then
                    self._fbagsSuppress = true
                    self:SetText(self._fbagsLastGood or "")
                    self._fbagsSuppress = false
                    ok = onValidParse(self:GetText() or "", true)
                else
                    self._fbagsLastGood = TrimText(text)
                end
                self._fbagsDirty = false
                SetBoxValid(self, true)
                return ok and true or false
            end
            box:SetScript("OnTextChanged", function(self)
                if self._fbagsSuppress then
                    return
                end
                self._fbagsDirty = true
                local text = self:GetText() or ""
                local ok = onValidParse(text, false)
                SetBoxValid(self, ok)
            end)
            box:SetScript("OnEditFocusLost", function(self)
                -- Save if user edited; restore last good if current text is invalid.
                if self._fbagsDirty then
                    self:_fbagsCommit(true)
                end
            end)
            box:SetScript("OnEscapePressed", function(self)
                self._fbagsSuppress = true
                self:SetText(self._fbagsLastGood or "")
                self._fbagsSuppress = false
                self._fbagsDirty = false
                SetBoxValid(self, true)
                self:ClearFocus()
            end)
            box:SetScript("OnEnterPressed", function(self)
                self:_fbagsCommit(true)
                self:ClearFocus()
            end)
        end

        local function BindMinAhValue(qId, colX, anchorY, tipBody)
            local label = track(panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"))
            label:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, anchorY)
            label:SetText("Min AH value")
            label:SetTextColor(0.9, 0.85, 0.55)

            local box = MakeFreeTextBox("FugaziBAGS_Q" .. qId .. "_minAhValue", 120)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, anchorY - 15)

            local copper = 0
            local SV = _G.FugaziBAGSDB
            local row = SV and SV.valuationMatrix and (SV.valuationMatrix[qId] or SV.valuationMatrix[tostring(qId)])
            if type(row) == "table" then
                copper = tonumber(row.minAuctionCopper) or 0
            end
            local initText = FormatCopperShort(copper)
            ApplyBoxText(box, initText)

            BindValidatedBox(box, initText, function(text, commit)
                local ok, val = ParseMoneyText(text)
                if ok and commit then
                    local m = EnsureMatrix(qId)
                    if m then
                        m.minAuctionCopper = val
                        -- Always persist immediately — do not wait for logout/Okay.
                        if A.PersistPrefTable then
                            A.PersistPrefTable("valuationMatrix")
                        elseif A.SyncPrefTable then
                            A.SyncPrefTable("valuationMatrix")
                        end
                        if A.SnapshotCharSettings then
                            A.SnapshotCharSettings()
                        end
                        if A.InvalidateValuationCache then
                            A.InvalidateValuationCache("minAuctionCopper")
                        end
                    end
                end
                return ok
            end)
            -- Tips only on frames/editboxes — FontStrings cannot SetScript in 3.3.5.
            AttachTip(box, "Min AH value", tipBody)
            box._fbagsValKey = "minAuctionCopper"
            box._fbagsValQ = qId
        end

        local function BindMinAhProfit(qId, colX, anchorY, tipBody)
            local label = track(panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"))
            label:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, anchorY)
            label:SetText("Min AH profit")
            label:SetTextColor(0.9, 0.85, 0.55)

            local box = MakeFreeTextBox("FugaziBAGS_Q" .. qId .. "_minAhProfit", 120)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, anchorY - 15)

            local SV = _G.FugaziBAGSDB
            local m = SV and SV.valuationMatrix and (SV.valuationMatrix[qId] or SV.valuationMatrix[tostring(qId)])
            local copper = tonumber(m and m.minAuctionProfitCopper) or 0
            local pct = tonumber(m and m.minAuctionProfitPct) or 0
            -- Prefer money if both somehow set (legacy).
            if copper > 0 and pct > 0 then
                pct = 0
            end
            local initText = ""
            if pct > 0 then
                initText = tostring(math.floor(pct)) .. "%"
            else
                initText = FormatCopperShort(copper)
            end
            ApplyBoxText(box, initText)

            BindValidatedBox(box, initText, function(text, commit)
                local ok, kind, val = ParseMoneyOrPctText(text)
                if ok and commit then
                    local mat = EnsureMatrix(qId)
                    if mat then
                        if kind == "pct" then
                            mat.minAuctionProfitPct = val
                            mat.minAuctionProfitCopper = 0
                        elseif kind == "money" then
                            mat.minAuctionProfitCopper = val
                            mat.minAuctionProfitPct = 0
                        else
                            mat.minAuctionProfitCopper = 0
                            mat.minAuctionProfitPct = 0
                        end
                        if A.PersistPrefTable then
                            A.PersistPrefTable("valuationMatrix")
                        elseif A.SyncPrefTable then
                            A.SyncPrefTable("valuationMatrix")
                        end
                        if A.SnapshotCharSettings then
                            A.SnapshotCharSettings()
                        end
                        if A.InvalidateValuationCache then
                            A.InvalidateValuationCache("minAuctionProfit")
                        end
                    end
                end
                return ok
            end)
            AttachTip(box, "Min AH profit", tipBody)
            box._fbagsValKey = "minAuctionProfit"
            box._fbagsValQ = qId
        end

        local function BindForceDestroy(qId, colX, anchorY, tipBody, forceWidgets)
            local label = track(panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"))
            label:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, anchorY)
            label:SetText("Force destroy")
            label:SetTextColor(0.9, 0.85, 0.55)
            table.insert(forceWidgets, label)

            local box = MakeFreeTextBox("FugaziBAGS_Q" .. qId .. "_forceDestroy", 120)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, anchorY - 15)
            table.insert(forceWidgets, box)

            local SV = _G.FugaziBAGSDB
            local cMin, cMax, cOp = 0, 0, "-"
            local mRow = SV and SV.valuationMatrix and (SV.valuationMatrix[qId] or SV.valuationMatrix[tostring(qId)])
            if type(mRow) == "table" then
                if mRow.destroyMin ~= nil then
                    cMin = mRow.destroyMin
                end
                if mRow.destroyMax ~= nil then
                    cMax = mRow.destroyMax
                end
                if mRow.destroyOp ~= nil then
                    cOp = mRow.destroyOp
                end
            end
            local initText = FormatForceDestroy(cMin, cMax, cOp)
            ApplyBoxText(box, initText)

            BindValidatedBox(box, initText, function(text, commit)
                local ok, minV, maxV, op = ParseForceDestroyText(text)
                if ok and commit then
                    local mat = EnsureMatrix(qId)
                    if mat then
                        mat.destroyMin = minV
                        mat.destroyMax = maxV
                        mat.destroyOp = op
                        if A.PersistPrefTable then
                            A.PersistPrefTable("valuationMatrix")
                        elseif A.SyncPrefTable then
                            A.SyncPrefTable("valuationMatrix")
                        end
                        if A.SnapshotCharSettings then
                            A.SnapshotCharSettings()
                        end
                        if A.InvalidateValuationCache then
                            A.InvalidateValuationCache("matrix")
                        end
                    end
                end
                return ok
            end)
            AttachTip(box, "Force destroy", tipBody)
            box._fbagsValKey = "forceDestroy"
            box._fbagsValQ = qId
        end

        -- Matrix columns: leave room under global toggles (milling ends ~ -155).
        yOff = -200
        local colWidth = 155
        local xStart = 16

        -- Multi-line tips: { text, r, g, b [, wrap] } — plain player language
        local tipMinAh = {
            { "“Auction only if it’s worth at least this much.”", 1, 1, 1, true },
            { " " },
            { "Works together with Auto Best — does not replace it.", 0.9, 0.9, 0.9, true },
            { "Price is for ONE item (a stack of 20 cloth uses one cloth’s price).", 0.9, 0.9, 0.9, true },
            {
                "If the AH price is below this, Auction is ignored and Vendor/Destroy win instead.",
                0.9,
                0.9,
                0.9,
                true,
            },
            { " " },
            { "Example: set 10s → cloth listing at 8s never gets the Auction icon.", 1, 0.95, 0.7, true },
            { " " },
            { "How to type money:", 1, 0.82, 0 },
            { "  2g 25s", 0.45, 1.0, 0.45 },
            { "  10s", 0.45, 1.0, 0.45 },
            { "  50c", 0.45, 1.0, 0.45 },
            { "  empty / 0  = off", 0.45, 1.0, 0.45 },
            { " " },
            { "Won’t accept:", 1, 0.82, 0 },
            { "  20     (need g, s, or c)", 1.0, 0.35, 0.35 },
            { "  500c   (c is 0–99; use 5s)", 1.0, 0.35, 0.35 },
            { "  20%    (use Min AH profit for %)", 1.0, 0.35, 0.35 },
        }
        local tipMinProfit = {
            { "“Auction only if it beats vendor by enough.”", 1, 1, 1, true },
            { " " },
            { "Works together with Auto Best — does not replace it.", 0.9, 0.9, 0.9, true },
            { "Looks at one item: AH price minus vendor price.", 0.9, 0.9, 0.9, true },
            { "Stack size does not matter.", 0.9, 0.9, 0.9, true },
            { " " },
            { "Type money OR a percent (not both at once):", 1, 0.95, 0.7, true },
            { "  5s  → AH must be at least 5s more than vendor", 0.85, 0.85, 0.85, true },
            { "  20% → AH must beat vendor by 20% of vendor", 0.85, 0.85, 0.85, true },
            { "     (vendor 10s → need AH ≥ 12s)", 0.75, 0.75, 0.75, true },
            { "If it fails → Vendor or Destroy instead.", 0.9, 0.9, 0.9, true },
            { " " },
            { "How to type:", 1, 0.82, 0 },
            { "  2g 25s   5s   50c   20%", 0.45, 1.0, 0.45 },
            { "  empty / 0  = off", 0.45, 1.0, 0.45 },
            { " " },
            { "Won’t accept:", 1, 0.82, 0 },
            { "  20     (need a unit or %)", 1.0, 0.35, 0.35 },
            { "  500c   (c is 0–99; use 5s)", 1.0, 0.35, 0.35 },
        }
        local tipForceDestroy = {
            { "Only works when Auto Best is OFF for this rarity.", 1, 0.45, 0.45, true },
            { "(Field greys out while Auto Best is on.)", 0.85, 0.55, 0.55, true },
            { " " },
            { "Hard rule: in this item-level range, always prefer Destroy", 0.9, 0.9, 0.9, true },
            { "(disenchant / mill / prospect) if a destroy value exists.", 0.9, 0.9, 0.9, true },
            { "Outside the range → normal rules (Auction / Vendor / Destroy by value).", 0.9, 0.9, 0.9, true },
            { " " },
            { "Uses BASE item level (classic Item Level / DE tables),", 1, 0.95, 0.7, true },
            { "NOT Ascension scaled iLvl on the tooltip.", 1, 0.95, 0.7, true },
            { "Example: Greater Eternal Essence band ≈ 46-60 base.", 0.85, 0.85, 0.75, true },
            { "Needs Evaluate Disenchanting (or mill/prospect) turned on.", 0.85, 0.85, 0.75, true },
            { " " },
            { "How to type:", 1, 0.82, 0 },
            { "  46-60   <30   >50   >=50", 0.45, 1.0, 0.45 },
            { "  empty / 0  = off", 0.45, 1.0, 0.45 },
            { " " },
            { "Won’t accept: 20% or 5s (those are money rules).", 1.0, 0.35, 0.35, true },
        }

        local qualities = {
            { id = 1, name = "Common (White)", color = "|cffffffff" },
            { id = 2, name = "Uncommon (Green)", color = "|cff1eff00" },
            { id = 3, name = "Rare (Blue)", color = "|cff0070dd" },
            { id = 4, name = "Epic (Purple)", color = "|cffa335ee" },
        }
        for i, q in ipairs(qualities) do
            local colX = xStart + (i - 1) * colWidth

            local qTitle = track(panel:CreateFontString(nil, "ARTWORK", "GameFontNormal"))
            qTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, yOff)
            qTitle:SetText(q.color .. q.name .. "|r")

            -- Auto Best Value
            local autoName = "FugaziBAGSQualityAutoBest" .. q.id
            local cb = GetOrCreateNamed("CheckButton", autoName, "OptionsCheckButtonTemplate")
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, yOff - 22)

            local fs2 = _G[cb:GetName() .. "Text"]
            if fs2 then
                fs2:SetText("Auto Best Value")
            end

            local SV = _G.FugaziBAGSDB
            local init = true
            if SV and SV.valuationMatrix and SV.valuationMatrix[q.id] then
                init = SV.valuationMatrix[q.id].autoBestValue
            end
            cb:SetChecked(init)

            -- Only Force Destroy greys out when Auto Best is on (AH floors stay active).
            local forceWidgets = {}
            local function UpdateColumnState(isAuto)
                for _, w in ipairs(forceWidgets) do
                    if isAuto then
                        if w.Disable then
                            w:Disable()
                        end
                        if w.SetAlpha then
                            w:SetAlpha(0.35)
                        end
                    else
                        if w.Enable then
                            w:Enable()
                        end
                        if w.SetAlpha then
                            w:SetAlpha(1.0)
                        end
                    end
                end
            end

            cb:SetScript("OnClick", function(self)
                local isChecked = (self:GetChecked() == 1 or self:GetChecked() == true)
                local m = EnsureMatrix(q.id)
                if m then
                    m.autoBestValue = isChecked
                    if A.SyncPrefTable then
                        A.SyncPrefTable("valuationMatrix")
                    end
                end
                UpdateColumnState(isChecked)
                if A.InvalidateValuationCache then
                    A.InvalidateValuationCache("autoBestValue")
                end
            end)
            cb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Auto Best Value", 1, 0.82, 0)
                GameTooltip:AddLine(
                    "ON (recommended): pick whichever makes the most gold — Auction, Vendor, or Destroy.\n\n"
                        .. "Min AH value / Min AH profit still apply: they only say “don’t count Auction if it’s too cheap / not profitable enough.” Then the best of what’s left wins.\n\n"
                        .. "OFF: you can use Force destroy (iLvl band hard-overrides to Destroy). Outside that band, still picks the best money option.\n\n"
                        .. "Force destroy is greyed while this is ON (either use smart pick, or force by iLvl — not both at once).",
                    1,
                    1,
                    1,
                    true
                )
                GameTooltip:Show()
            end)
            cb:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            SkinCheckBox(cb)

            -- No AH for gear
            local gearName = "FugaziBAGSQualityNoGearAH" .. q.id
            local gearCb = GetOrCreateNamed("CheckButton", gearName, "OptionsCheckButtonTemplate")
            gearCb:ClearAllPoints()
            gearCb:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, yOff - 50)
            gearCb:SetScale(1)
            local gearFs = _G[gearCb:GetName() .. "Text"]
            if gearFs then
                gearFs:SetText("No AH for gear")
                gearFs:SetTextColor(0.85, 0.85, 0.75)
            end
            local gearInit = false
            if SV and SV.valuationMatrix and SV.valuationMatrix[q.id] then
                if SV.valuationMatrix[q.id].excludeGearFromAH == nil then
                    gearInit = (q.id == 1 or q.id == 2)
                else
                    gearInit = SV.valuationMatrix[q.id].excludeGearFromAH and true or false
                end
            else
                gearInit = (q.id == 1 or q.id == 2)
            end
            gearCb:SetChecked(gearInit)
            gearCb:SetScript("OnClick", function(self)
                local isChecked = (self:GetChecked() == 1 or self:GetChecked() == true)
                local m = EnsureMatrix(q.id)
                if m then
                    m.excludeGearFromAH = isChecked
                    if A.SyncPrefTable then
                        A.SyncPrefTable("valuationMatrix")
                    end
                end
                if A.InvalidateValuationCache then
                    A.InvalidateValuationCache("excludeGearFromAH")
                end
            end)
            gearCb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("No AH for gear", 1, 0.82, 0)
                GameTooltip:AddLine(
                    "Weapons and armor of this color never count as Auction — only Vendor or Destroy.\n\n"
                        .. "Cloth, mats, junk, etc. can still be Auction.\n\n"
                        .. "Handy for greens/whites that never sell on the AH.\n\n"
                        .. "Force destroy (when Auto Best is off) still wins inside its iLvl range.",
                    1,
                    1,
                    1,
                    true
                )
                GameTooltip:Show()
            end)
            gearCb:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            SkinCheckBox(gearCb)

            -- Always vendor soulbound gear (below No AH for gear)
            local sbName = "FugaziBAGSQualityVendorSoulbound" .. q.id
            local sbCb = GetOrCreateNamed("CheckButton", sbName, "OptionsCheckButtonTemplate")
            sbCb:ClearAllPoints()
            sbCb:SetPoint("TOPLEFT", panel, "TOPLEFT", colX, yOff - 78)
            sbCb:SetScale(1)
            local sbFs = _G[sbCb:GetName() .. "Text"]
            if sbFs then
                sbFs:SetText("Always vendor soulbound")
                sbFs:SetTextColor(0.85, 0.85, 0.75)
            end
            local sbInit = false
            if SV and SV.valuationMatrix and SV.valuationMatrix[q.id] then
                sbInit = SV.valuationMatrix[q.id].alwaysVendorSoulboundGear and true or false
            end
            sbCb:SetChecked(sbInit)
            sbCb:SetScript("OnClick", function(self)
                local isChecked = (self:GetChecked() == 1 or self:GetChecked() == true)
                local m = EnsureMatrix(q.id)
                if m then
                    m.alwaysVendorSoulboundGear = isChecked
                    if A.SyncPrefTable then
                        A.SyncPrefTable("valuationMatrix")
                    end
                end
                if A.InvalidateValuationCache then
                    A.InvalidateValuationCache("alwaysVendorSoulboundGear")
                end
            end)
            sbCb:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Always vendor soulbound", 1, 0.82, 0)
                GameTooltip:AddLine(
                    "Soulbound weapons and armor of this color are always valued as Vendor — never Destroy or Auction.\n\n"
                        .. "For alts without Enchanting: BoP loot stops showing a high disenchant value you can’t use.\n\n"
                        .. "Only equipment (Weapon/Armor). Cloth, herbs, ores, and other mats are unchanged.\n\n"
                        .. "BoE gear that is still unbound uses normal valuation (you can mail it).\n\n"
                        .. "Overrides Auto Best and Force destroy for those soulbound gear pieces.",
                    1,
                    1,
                    1,
                    true
                )
                GameTooltip:Show()
            end)
            sbCb:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            SkinCheckBox(sbCb)

            -- Force destroy (single free-text field; grey when Auto Best on)
            BindForceDestroy(q.id, colX, yOff - 110, tipForceDestroy, forceWidgets)

            -- Per-rarity AH filters (always active with Auto Best — NOT greyed)
            BindMinAhValue(q.id, colX, yOff - 156, tipMinAh)
            BindMinAhProfit(q.id, colX, yOff - 202, tipMinProfit)

            UpdateColumnState(init)
        end

        --- Reload text fields / checkboxes from live SV (after Copy settings, login hydrate, OnShow).
        panel.refresh = function()
            local SV = _G.FugaziBAGSDB
            if not SV then
                return
            end

            -- Global valuation toggles (must refresh after Copy settings / hydrate).
            local globalCbs = {
                { name = "FugaziBAGSEnableFilteredAutoSell", key = "enableFilteredAutoSell", default = false },
                { name = "FugaziBAGSEvaluateDisenchant", key = "evaluateDisenchant", default = false },
                { name = "FugaziBAGSEvaluateProspect", key = "evaluateProspect", default = false },
                { name = "FugaziBAGSEvaluateMilling", key = "evaluateMilling", default = false },
                { name = "FugaziBAGSShowValuationIcons", key = "showValuationIcons", default = true },
                { name = "FugaziBAGSAlwaysValuateItems", key = "alwaysValuateItems", default = false },
            }
            for _, row in ipairs(globalCbs) do
                local cb = _G[row.name]
                if cb and cb.SetChecked then
                    local v = SV[row.key]
                    if v == nil then
                        v = row.default
                    end
                    cb:SetChecked(v and true or false)
                end
            end

            if type(SV.valuationMatrix) ~= "table" then
                return
            end
            for qId = 1, 4 do
                local m = SV.valuationMatrix[qId] or SV.valuationMatrix[tostring(qId)]
                if type(m) ~= "table" then
                    m = {}
                end

                local minAhBox = _G["FugaziBAGS_Q" .. qId .. "_minAhValue"]
                if minAhBox then
                    ApplyBoxText(minAhBox, FormatCopperShort(tonumber(m.minAuctionCopper) or 0))
                end

                local profitBox = _G["FugaziBAGS_Q" .. qId .. "_minAhProfit"]
                if profitBox then
                    local copper = tonumber(m.minAuctionProfitCopper) or 0
                    local pct = tonumber(m.minAuctionProfitPct) or 0
                    if copper > 0 and pct > 0 then
                        pct = 0
                    end
                    local t = ""
                    if pct > 0 then
                        t = tostring(math.floor(pct)) .. "%"
                    else
                        t = FormatCopperShort(copper)
                    end
                    ApplyBoxText(profitBox, t)
                end

                local forceBox = _G["FugaziBAGS_Q" .. qId .. "_forceDestroy"]
                if forceBox then
                    ApplyBoxText(forceBox, FormatForceDestroy(m.destroyMin, m.destroyMax, m.destroyOp))
                end

                local autoCb = _G["FugaziBAGSQualityAutoBest" .. qId]
                if autoCb and autoCb.SetChecked then
                    local init = true
                    if m.autoBestValue ~= nil then
                        init = m.autoBestValue and true or false
                    end
                    autoCb:SetChecked(init)
                end

                local gearCb = _G["FugaziBAGSQualityNoGearAH" .. qId]
                if gearCb and gearCb.SetChecked then
                    local gearInit
                    if m.excludeGearFromAH == nil then
                        gearInit = (qId == 1 or qId == 2)
                    else
                        gearInit = m.excludeGearFromAH and true or false
                    end
                    gearCb:SetChecked(gearInit)
                end

                local sbCb = _G["FugaziBAGSQualityVendorSoulbound" .. qId]
                if sbCb and sbCb.SetChecked then
                    sbCb:SetChecked(m.alwaysVendorSoulboundGear and true or false)
                end
            end
        end

        -- Re-pull floors whenever this category is shown. HookScript so we don't
        -- clobber anything Interface Options may attach later.
        local function refreshValuationPanel()
            if panel.refresh then
                panel.refresh()
            end
        end
        panel:SetScript("OnShow", refreshValuationPanel)
        if panel.HookScript then
            panel:HookScript("OnShow", refreshValuationPanel)
        end

        -- Register category only once (rebuild after failed first attempt).
        if InterfaceOptions_AddCategory and not panel._fbagsCategoryAdded then
            InterfaceOptions_AddCategory(panel)
            panel._fbagsCategoryAdded = true
        end
        panel._fbagsReady = true
        if panel.refresh then
            panel.refresh()
        end
    end)
    if not ok then
        if _G.FugaziBAGSValuationOptionsPanel then
            _G.FugaziBAGSValuationOptionsPanel._fbagsReady = false
        end
        print("|cffff0000[FugaziBAGS] Error in CreateValuationOptionsPanel:|r", err)
    end
end

A.CreateValuationOptionsPanel = CreateValuationOptionsPanel
A.CreateOptionsPanel = CreateOptionsPanel
A.CreateGridviewOptionsPanel = CreateGridviewOptionsPanel
A.CreateSkinsPanel = CreateSkinsPanel
A.CreateInstructionsPanel = CreateInstructionsPanel
