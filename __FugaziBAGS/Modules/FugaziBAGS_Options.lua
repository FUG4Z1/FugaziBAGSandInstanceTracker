--[[
  FugaziBAGS_Options.lua
  All Interface > AddOns option panels: Main, Scale, Skins, Instructions.
  MOVED FROM FugaziBAGS.lua - no logic changes except A. prefixes for
  GetPerChar / SetPerChar (previously local to FugaziBAGS.lua).
]]

_G.FugaziBAGS = _G.FugaziBAGS or {}
local Addon  = _G.FugaziBAGS
local A      = Addon
local DB     = _G.FugaziBAGSDB
local Skins  = _G.__FugaziBAGS_Skins or {}
local RefreshGPHUI  = _G.RefreshGPHUI
local RefreshBankUI = _G.RefreshBankUI

local gphDestroyCopySourceKey

local function SetFugaziControlEnabled(frame, enabled)
    if not frame then return end
    local a = enabled and 1.0 or 0.3
    
    -- Special handling for Dropdowns to avoid the "Ghosting" of original blizzard textures
    -- we only dim the custom Proxy and the Text.
    if frame.proxy then
        frame:SetAlpha(0) -- Always hide the original
        frame.proxy:SetAlpha(a)
        frame.proxy:EnableMouse(enabled)
        if frame.proxy.text then frame.proxy.text:SetAlpha(a) end
    else
        frame:SetAlpha(a)
    end
    
    if frame.Enable then
        if enabled then frame:Enable() else frame:Disable() end
    end
    if frame.EnableMouse then frame:EnableMouse(enabled) end

    -- Handle child elements (Sliders and Checkboxes)
    if frame._valText then frame._valText:SetAlpha(a) end
    local fName = (frame.GetName and frame:GetName())
    if fName then
        if _G[fName .. "Text"] then _G[fName .. "Text"]:SetAlpha(a) end
        if _G[fName .. "Low"] then _G[fName .. "Low"]:SetAlpha(a) end
        if _G[fName .. "High"] then _G[fName .. "High"]:SetAlpha(a) end
    end
    if frame._swatch then frame._swatch:SetVertexColor(1, 1, 1, a) end
end

local function SkinSlider(s)
    if not s then return end
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    s:SetBackdropColor(0, 0, 0, 0.65)
    s:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    
    local name = s:GetName()
    if _G[name.."Low"] then _G[name.."Low"]:SetTextColor(0.5, 0.5, 0.5) end
    if _G[name.."High"] then _G[name.."High"]:SetTextColor(0.5, 0.5, 0.5) end

    local thumb = s:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(10, 14)
        thumb:SetVertexColor(0.9, 0.1, 0.1, 1)
    end
end

local function SkinButton(btn)
    if not btn then return end
    btn:SetNormalTexture(""); btn:SetPushedTexture(""); btn:SetHighlightTexture("")
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    btn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(0.8, 0.2, 0.2, 0.8) end)
    btn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6) end)
    if btn:GetFontString() then btn:GetFontString():SetTextColor(1, 0.8, 0.4) end
end

local function SkinCheckBox(cb)
    if not cb then return end
    cb:SetNormalTexture(""); cb:SetPushedTexture(""); cb:SetHighlightTexture("")
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
        check:SetPoint("TOPLEFT", 4, -4); check:SetPoint("BOTTOMRIGHT", -4, 4)
    end
end

local function SkinEditBox(eb)
    if not eb then return end
    eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    eb:SetBackdropColor(0, 0, 0, 0.5)
    eb:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    local name = eb:GetName()
    if name then
        if _G[name.."Left"] then _G[name.."Left"]:Hide() end
        if _G[name.."Middle"] then _G[name.."Middle"]:Hide() end
        if _G[name.."Right"] then _G[name.."Right"]:Hide() end
    end
    eb:SetTextInsets(6, 6, 0, 0)
end

local function SkinDropDown(dd)
    if not dd then return end
    local name = dd:GetName()
    if not name then return end
    
    dd:SetAlpha(0)
    dd:SetSize(1, 1)

    if not dd.proxy then
        local proxy = CreateFrame("Button", name.."Proxy", dd:GetParent())
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
        
        local originalText = _G[name.."Text"]
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
    if not sb then return end
    local name = sb:GetName()
    if not name then return end
    
    if _G[name.."BG"] then _G[name.."BG"]:Hide() end
    if _G[name.."Top"] then _G[name.."Top"]:Hide() end
    if _G[name.."Bottom"] then _G[name.."Bottom"]:Hide() end
    if _G[name.."Middle"] then _G[name.."Middle"]:Hide() end

    local up = _G[name.."ScrollUpButton"]
    local down = _G[name.."ScrollDownButton"]
    if up then up:Hide() end
    if down then down:Hide() end

    local thumb = sb:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(8, 32)
        thumb:SetVertexColor(0.8, 0.2, 0.2, 0.8)
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
    if RefreshGPHUI then RefreshGPHUI() end
    if RefreshBankUI then RefreshBankUI() end
    local cg = _G.FugaziBAGS_CombatGrid
    if cg then
        if cg.IsShown and cg.IsShown() and cg.LayoutGrid then cg.LayoutGrid() end
        if cg.IsBankShown and cg.IsBankShown() and cg.BankLayoutGrid then cg.BankLayoutGrid() end
        if cg.RefreshSlots then cg.RefreshSlots() end
        if cg.BankRefreshSlots then cg.BankRefreshSlots() end
    end
    if _G.ApplyTestSkin then _G.ApplyTestSkin() end
    if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then _G.FugaziInstanceTracker_RefreshSkinFromBAGS() end
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
    
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
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
        if self._isRefreshing then return end
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
        
        -- Safety: Call RefreshAllUI for any setting that doesn't have a listener yet.
        if RefreshAllUI then RefreshAllUI() end
    end)
    
    if tooltipText then
        s:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 0.8, 0)
            GameTooltip:AddLine(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    local SV = _G.FugaziBAGSDB
    local init = (SV and SV[key]) or default
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
    if not eb then return end
    eb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    eb:SetBackdropColor(0, 0, 0, 0.5)
    eb:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
    local name = eb:GetName()
    if name then
        if _G[name.."Left"] then _G[name.."Left"]:Hide() end
        if _G[name.."Middle"] then _G[name.."Middle"]:Hide() end
        if _G[name.."Right"] then _G[name.."Right"]:Hide() end
    end
    eb:SetTextInsets(6, 6, 0, 0)
end

local function SkinDropDown(dd)
    if not dd then return end
    local name = dd:GetName()
    if not name then return end
    
    dd:SetAlpha(0)
    dd:SetSize(1, 1)

    if not dd.proxy then
        local proxy = CreateFrame("Button", name.."Proxy", dd:GetParent())
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
        
        local originalText = _G[name.."Text"]
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
    if not sb then return end
    local name = sb:GetName()
    if not name then return end
    
    if _G[name.."BG"] then _G[name.."BG"]:Hide() end
    if _G[name.."Top"] then _G[name.."Top"]:Hide() end
    if _G[name.."Bottom"] then _G[name.."Bottom"]:Hide() end
    if _G[name.."Middle"] then _G[name.."Middle"]:Hide() end

    local up = _G[name.."ScrollUpButton"]
    local down = _G[name.."ScrollDownButton"]
    if up then up:Hide() end
    if down then down:Hide() end

    local thumb = sb:GetThumbTexture()
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(8, 32)
        thumb:SetVertexColor(0.8, 0.2, 0.2, 0.8)
    end
end


local function CreateOptionsPanel()
    if _G.FugaziBAGSOptionsPanel then return end
    local panel = CreateFrame("Frame", "FugaziBAGSOptionsPanel", UIParent)
    panel.name = "_FugaziBAGS"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end
    panel.refresh = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("_FugaziBAGS")

    

    
    local cbDel = CreateFrame("CheckButton", "FugaziBAGSConfirmDelCheck", panel, "OptionsCheckButtonTemplate")
    cbDel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 4, -24)
    SkinCheckBox(cbDel)
    _G["FugaziBAGSConfirmDelCheckText"]:SetText("Confirm Auto Delete")
    cbDel:SetScript("OnClick", function(self)
        local SV = _G.FugaziBAGSDB
        if SV then SV.gridConfirmAutoDel = (self:GetChecked() == 1 or self:GetChecked() == true) end
    end)

    local cbAutosell = CreateFrame("CheckButton", "FugaziBAGSAutosellEverythingCheck", panel, "OptionsCheckButtonTemplate")
    cbAutosell:SetPoint("LEFT", cbDel, "RIGHT", 180, 0)
    SkinCheckBox(cbAutosell)
    _G["FugaziBAGSAutosellEverythingCheckText"]:SetText("Autosell EVERYTHING!")
    cbAutosell:SetScript("OnClick", function(self)
        local SV = _G.FugaziBAGSDB
        if not SV then return end
        if self:GetChecked() then
            self:SetChecked(false)
            StaticPopup_Show("GPH_AUTOSELL_EVERYTHING_WARN")
        else
            SV.gphAutosellEverything = false
        end
    end)

    local cbSound = CreateFrame("CheckButton", "FugaziBAGSClickSoundCheck", panel, "OptionsCheckButtonTemplate")
    cbSound:SetPoint("TOPLEFT", cbDel, "BOTTOMLEFT", 0, -8)
    SkinCheckBox(cbSound)
    _G["FugaziBAGSClickSoundCheckText"]:SetText("Play sounds")
    cbSound:SetScript("OnClick", function(self)
        local SV = _G.FugaziBAGSDB
        if SV then SV.gphClickSound = (self:GetChecked() == 1 or self:GetChecked() == true) end
    end)

    -- Character Copy Section
    local copyLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    copyLabel:SetPoint("TOPLEFT", cbSound, "BOTTOMLEFT", 0, -18)
    copyLabel:SetText("Copy auto-destroy list from character:")





    local destroyDropdown = CreateFrame("Frame", "FugaziBAGSOptionsDestroyDropdown", panel, "UIDropDownMenuTemplate")
    destroyDropdown:SetPoint("TOPLEFT", copyLabel, "BOTTOMLEFT", -2, -10)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(destroyDropdown, 220) end
    SkinDropDown(destroyDropdown)



    

    local function DestroyMenu_Initialize(_, level)
        local SV = _G.FugaziBAGSDB
        if not SV or not SV.gphDestroyListPerChar then return end
        for key, list in pairs(SV.gphDestroyListPerChar) do
            if list and next(list) ~= nil then
                local realm, char = key:match("^(.-)#(.*)$")
                local text = (char and char ~= "" and char) or key
                local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
                if info then
                    info.text = text
                    info.value = key
                    info.func = function()
                        gphDestroyCopySourceKey = key
                        if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(destroyDropdown, key) end
                        if UIDropDownMenu_SetText then UIDropDownMenu_SetText(destroyDropdown, text) end
                    end
                    UIDropDownMenu_AddButton(info, level or 1)
                end
            end
        end
    end

    if UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(destroyDropdown, DestroyMenu_Initialize) end

    local copyBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copyBtn:SetSize(110, 22)
    copyBtn:SetPoint("LEFT", destroyDropdown.proxy or destroyDropdown, "RIGHT", 14, 0)
    copyBtn:SetText("Copy")
    SkinButton(copyBtn)


    copyBtn:SetScript("OnClick", function()
        
        print("|cff00aaff[__FugaziBAGS]|r Copy button clicked.")

        local SV = _G.FugaziBAGSDB
        if not SV then
            print("|cff00aaff[__FugaziBAGS]|r No FugaziBAGSDB found; cannot copy auto-destroy list.")
            return
        end
        if not SV.gphDestroyListPerChar then
            print("|cff00aaff[__FugaziBAGS]|r No gphDestroyListPerChar table; nothing to copy from.")
            return
        end
        if not gphDestroyCopySourceKey then
            print("|cff00aaff[__FugaziBAGS]|r No source character selected in dropdown.")
            return
        end
        local src = SV.gphDestroyListPerChar[gphDestroyCopySourceKey]
        if not src or next(src) == nil then
            print("|cff00aaff[__FugaziBAGS]|r Selected source has an empty auto-destroy list.")
            return
        end
        
        if not SV.gphDestroyListPerChar then SV.gphDestroyListPerChar = {} end
        local curKey = A.GetCharKey and A.GetCharKey()
        if not curKey or curKey == "" then
            print("|cff00aaff[__FugaziBAGS]|r Could not resolve current character key; aborting copy.")
            return
        end
        local dst = SV.gphDestroyListPerChar[curKey]
        if not dst then
            dst = {}
            SV.gphDestroyListPerChar[curKey] = dst
        end

        
        if wipe then wipe(dst) else for k in pairs(dst) do dst[k] = nil end end
        local count = 0
        for id, v in pairs(src) do
            dst[id] = { name = v.name, texture = v.texture, addedTime = v.addedTime }
            count = count + 1
        end

        
        if _G.FugaziBAGS and _G.FugaziBAGS.GetGphDestroyList then
            _G.FugaziBAGS.GetGphDestroyList()
        end
        if RefreshGPHUI then
            RefreshGPHUI()
        end
        print("|cff00aaff[__FugaziBAGS]|r Copied |cffffff00" .. tostring(count) .. "|r auto-destroy entries from |cffffff00" .. tostring(gphDestroyCopySourceKey) .. "|r to this character.")
    end)

    
    local delListLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    delListLabel:SetPoint("TOPLEFT", destroyDropdown, "BOTTOMLEFT", 6, -18)
    delListLabel:SetText("Auto-delete list (current character):")



    local RefreshDelListPanel  
    
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
    autosellPingEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

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
        if not SV then return end
        local raw = autosellPingEdit:GetText() and autosellPingEdit:GetText():match("^%s*(.-)%s*$")
        local num = (raw == "" or raw == nil) and nil or tonumber(raw)
        if num ~= nil then
            num = math.floor(math.max(0, math.min(9999, num)))
        end
        SV.gphAutosellPingMs = num
        autosellPingEdit:ClearFocus()
        autosellPingCheck:Show()
        local t = 0
        autosellPingOk._checkHideFrame = autosellPingOk._checkHideFrame or CreateFrame("Frame")
        local f = autosellPingOk._checkHideFrame
        f:SetScript("OnUpdate", function(_, elapsed)
            t = t + elapsed
            if t >= 2 then
                f:SetScript("OnUpdate", nil)
                if autosellPingCheck then autosellPingCheck:Hide() end
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
    scrollStepEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

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
        if not SV then return end
        local raw = scrollStepEdit:GetText() and scrollStepEdit:GetText():match("^%s*(.-)%s*$")
        local num = (raw == "" or raw == nil) and 200 or tonumber(raw)
        if num ~= nil then
            num = math.floor(math.max(1, math.min(600, num)))
        end
        SV.gphScrollStep = num
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
                if scrollStepCheck then scrollStepCheck:Hide() end
            end
        end)
        f2:Show()
        if RefreshGPHUI then RefreshGPHUI() end
        if RefreshBankUI then RefreshBankUI() end
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
        
        for _, r in pairs(delListRows) do r:Hide() end
        local A = _G.FugaziBAGS
        local list = (A and A.GetGphDestroyList) and A.GetGphDestroyList() or {}
        local sorted = {}
        
        
        local searchEdit = _G.FugaziBAGSDelListSearch
        local rawText = (searchEdit and searchEdit:GetText() or "")
        local searchText = rawText:lower():gsub("^%s*(.-)%s*$", "%1")
        
        for id, info in pairs(list) do
            local name = type(info) == "table" and info.name or (A.GetCachedItemInfo(id))
            if not name or name == "" then name = "Item " .. tostring(id) end
            
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
            if atA ~= atB then return atA > atB end
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
            if row.icon then row.icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark") end
            row.nameFs:SetText(entry.name)
            row.rmBtn:SetScript("OnClick", function()
                local bf = A.Bank
                local gphFrame = A.Inventory
                local dlist = (A and A.GetGphDestroyList) and A.GetGphDestroyList()
                if dlist then dlist[entry.id] = nil end
                RefreshDelListPanel()
                if _G.RefreshGPHUI then _G.RefreshGPHUI() end
                if A.PlaySwooshSound then A.PlaySwooshSound() end
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
            if searchText == "" then delListContent.emptyFs:SetText("(empty)") else delListContent.emptyFs:SetText("(no matches)") end
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
        if key == "ENTER" then self:ClearFocus() end
        RefreshDelListPanel()
    end)
    delListSearch:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    panel.refresh = function()
        local SV = _G.FugaziBAGSDB
        if not SV then return end
        cbDel:SetChecked(SV.gridConfirmAutoDel ~= false)
        if autosellPingEdit then
            if SV.gphAutosellPingMs ~= nil and SV.gphAutosellPingMs ~= "" then
                autosellPingEdit:SetText(tostring(SV.gphAutosellPingMs))
            else
                autosellPingEdit:SetText("")
            end
        end
        if _G.FugaziBAGSScrollStepEdit then
            local step = SV.gphScrollStep or 200
            _G.FugaziBAGSScrollStepEdit:SetText(tostring(step))
        end
        if cbSound then cbSound:SetChecked(SV.gphClickSound ~= false) end
        if cbAutosell then cbAutosell:SetChecked(SV.gphAutosellEverything == true) end
        if FugaziBAGSDelListSearch then FugaziBAGSDelListSearch:SetText("") end
        RefreshDelListPanel()
    end



    panel.okay = function()
        if _G.ApplyTestSkin then _G.ApplyTestSkin() end
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
    if _G.FugaziGridviewOptionsPanel then return end
    local panel = CreateFrame("Frame", "FugaziGridviewOptionsPanel", UIParent)
    panel.name = "Scale Settings"
    panel.parent = "_FugaziBAGS"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Scale Settings")

    local col1X, col2X, col3X = 30, 220, 410
    local curY = -80

    -- Visual backgrounds for columns
    CreateSectionBg(panel, col1X - 10, curY + 30, 180, 185)
    CreateSectionBg(panel, col2X - 10, curY + 30, 180, 185)
    CreateSectionBg(panel, col3X - 10, curY + 30, 180, 185)

    local s1 = CreateFugaziSlider(panel, "FugaziGridCols", "Slots per Row", 6, 16, 1, "gridCols", 10, col1X, curY, false, "Set how many item slots are displayed horizontally in each row.")
    local s2 = CreateFugaziSlider(panel, "FugaziGridSlotSize", "Slot Size", 20, 45, 1, "gridSlotSize", 30, col2X, curY, false, "Adjust the size of each individual item slot.")
    local s7 = CreateFugaziSlider(panel, "FugaziGridFrameScale", "Frame Scale", 0.75, 1.25, 0.05, "gphFrameScale", 1.00, col3X, curY, true, "Globally scale the entire inventory and bank window.")

    curY = -130
    local s3 = CreateFugaziSlider(panel, "FugaziGridSpacing", "Slot Spacing", 1, 10, 1, "gridSpacing", 4, col1X, curY, false, "Change the gap distance between item slots.")
    local s4 = CreateFugaziSlider(panel, "FugaziGridBorderSize", "Border Thickness", 1, 4, 1, "gridBorderSize", 2, col2X, curY, false, "Set the thickness of the borders around item slots.")
    local s8 = CreateFugaziSlider(panel, "FugaziGridFrameAlpha", "Frame Opacity", 0.10, 1.00, 0.05, "gphFrameAlpha", 1.00, col3X, curY, true, "Set the transparency of the inventory and bank background.")

    curY = -180
    local s5 = CreateFugaziSlider(panel, "FugaziGridGlowAlpha", "Glow Intensity", 0.0, 1.0, 0.05, "gridGlowAlpha", 0.35, col1X, curY, true, "Adjust the brightness of item rarity glows.")
    local s6 = CreateFugaziSlider(panel, "FugaziGridProtDesat", "Protected Desaturation", 0.0, 1.0, 0.05, "gridProtDesat", 0.80, col2X, curY, true, "How much to grey-out items that are marked as Protected.")
    local s6b = CreateFugaziSlider(panel, "FugaziGridProtectedKeyAlpha", "Protected Overlay Visibility", 0.10, 0.50, 0.05, "gridProtectedKeyAlpha", 0.20, col3X, curY, true, "Set the opacity of the secondary protected overlay icon.")


    

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
        if bv < 1 then bv = 1 elseif bv > 4 then bv = 4 end
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
    end

    local function ResetScaleDefaults()
        local SV = _G.FugaziBAGSDB
        if not SV then return end
        SV.gridCols = 10
        SV.gridSlotSize = 30
        SV.gphFrameScale = 1.00
        SV.gridSpacing = 4
        SV.gridBorderSize = 2
        SV.gridGlowAlpha = 0.35
        SV.gridProtDesat = 0.80
        SV.gridProtectedKeyAlpha = 0.20
        SV.gphFrameAlpha = 0.95
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

    if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel)     end
end



--- Skin picker panel (themes for inventory/bank).
local function CreateSkinsPanel()
    if _G.FugaziBAGSSkinsPanel then return end
    local panel = CreateFrame("Frame", "FugaziBAGSSkinsPanel", UIParent)
    panel.name = "Skins"
    panel.parent = "_FugaziBAGS"
    panel.okay = function()
        if _G.ApplyTestSkin then _G.ApplyTestSkin() end
        if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then _G.FugaziInstanceTracker_RefreshSkinFromBAGS() end
    end
    panel.cancel = function() end
    panel.default = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Skins")

    
    local scroll = CreateFrame("ScrollFrame", "FugaziBAGSSkinsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -32, 60)
    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetWidth(600)
    scrollChild:SetHeight(900)
    scrollChild:SetScale(0.95)
    scroll:SetScrollChild(scrollChild)
    panel:SetScript("OnShow", function()
        local sh = scroll:GetHeight()
        if sh and sh > 0 and scrollChild:GetHeight() <= sh then
            scrollChild:SetHeight(sh + 600)
        end
    end)

    local LEFT_X, RIGHT_X, ROW, GAP = 16, 310, 26, 32
    local curY = 10

    local function CreateSeparator(y)
        local line = scrollChild:CreateTexture(nil, "ARTWORK")
        line:SetSize(560, 1)
        line:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -y)
        line:SetTexture(1, 1, 1, 0.15)
    end

    local function SkinButtonLocal(btn)
        if not btn then return end
        SkinButton(btn)
    end



    local function SkinCheckBoxLocal(cb)
        if not cb then return end
        SkinCheckBox(cb)
    end


    local function SkinDropDownLocal(dd)
        if not dd then return end
        SkinDropDown(dd)
    end


    local ITEM_DETAILS_FONTS = {
        { value = "Fonts\\ARIALN.TTF",   text = "ARIALN" },
        { value = "Fonts\\FRIZQT__.TTF", text = "FRIZQT" },
        { value = "Fonts\\MORPHEUS.TTF", text = "MORPHEUS" },
        { value = "Fonts\\skurri.ttf",   text = "Skurri" },
        
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TinyIslanders.ttf",        text = "Tiny Islanders" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\OldSchoolAdventures.ttf",  text = "Old School Adventures" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\BreatheFire.ttf",          text = "Breathe Fire" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\EightBitDragon.ttf",       text = "Eight Bit Dragon" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\AncientModernTales.ttf",   text = "Ancient Modern Tales" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\Dragnel.ttf",              text = "Dragnel" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TheWildBreathOfZelda.ttf", text = "Wild Breath of Zelda" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\ModernSignature.ttf",      text = "Modern Signature" },
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
    skinLabel:SetText("Window theme preset:")
    curY = curY + ROW

    local skinDropdown = CreateFrame("Frame", "FugaziBAGSSkinsSkinDropdown", scrollChild, "UIDropDownMenuTemplate")
    skinDropdown:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 2, -12)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(skinDropdown, 160) end
    SkinDropDown(skinDropdown)
    local function SkinMenu_Init(_, level)
        local list = {
            { value = "original",    text = "Original" },
            { value = "elvui",       text = "Elvui (Ebonhold)" },
            { value = "elvui_real",  text = "ElvUI" },
            { value = "pimp_purple", text = "Pimp Purple" },
            { value = "fugazi",      text = "FUGAZI" },
        }
        for _, opt in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.text
                info.value = opt.value
                info.checked = ((_G.FugaziBAGSDB and _G.FugaziBAGSDB.gphSkin) or "original") == opt.value
                info.func = function()
                    local SV = _G.FugaziBAGSDB
                    if SV then
                        SV.gphSkin = opt.value
                        if opt.value == "fugazi" and _G.ApplyFugaziPreset then
                            _G.ApplyFugaziPreset()
                        else
                            SV.gphCategoryHeaderFontCustom = false
                            SV.gphItemDetailsCustom = false
                            SV.gphSkinOverrides = {}
                            -- Reset FUGAZI-specific visibility toggles
                            SV.gphHideIconsInList = false
                            SV.gphHideTopButtons = false
                            SV.gphBankHideTopButtons = false
                            SV.gphFrameAlpha = 1.0
                        end
                    end
                    if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(skinDropdown, opt.value) end
                    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(skinDropdown, opt.text) end
                    if _G.ApplyTestSkin then _G.ApplyTestSkin() end
                    if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
                    
                    if RefreshGPHUI then RefreshGPHUI() end
                    if RefreshBankUI then RefreshBankUI() end
                    
                end
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(skinDropdown, SkinMenu_Init) end
    curY = curY + 60
    CreateSeparator(curY)
    curY = curY + 20

    local headerSectionY = curY
    local fontLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", LEFT_X, -curY)
    fontLabel:SetText("Header & Category Appearance:")
    curY = curY + ROW

    local cbCatFont = CreateFrame("CheckButton", "FugaziBAGSSkinsCategoryFontCheck", scrollChild, "OptionsCheckButtonTemplate")
    cbCatFont:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 8, -4)
    SkinCheckBox(cbCatFont)
    _G["FugaziBAGSSkinsCategoryFontCheckText"]:SetText("Enable Header Customization")
    cbCatFont:SetScript("OnClick", function(self)
        local SV = _G.FugaziBAGSDB
        if SV then SV.gphCategoryHeaderFontCustom = (self:GetChecked() == 1 or self:GetChecked() == true) end
        if _G.ApplyTestSkin then _G.ApplyTestSkin() end
        if RefreshGPHUI then RefreshGPHUI() end
        if RefreshBankUI then RefreshBankUI() end
        if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
    end)
    curY = curY + 32

    local CAT_HEADER_FONTS = {
        { value = "Fonts\\ARIALN.TTF",   text = "ARIALN" },
        { value = "Fonts\\FRIZQT__.TTF", text = "FRIZQT" },
        { value = "Fonts\\MORPHEUS.TTF", text = "MORPHEUS" },
        { value = "Fonts\\skurri.ttf",   text = "Skurri" },
        
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TinyIslanders.ttf",        text = "Tiny Islanders" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\OldSchoolAdventures.ttf",  text = "Old School Adventures" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\BreatheFire.ttf",          text = "Breathe Fire" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\EightBitDragon.ttf",       text = "Eight Bit Dragon" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\AncientModernTales.ttf",   text = "Ancient Modern Tales" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\Dragnel.ttf",              text = "Dragnel" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\TheWildBreathOfZelda.ttf", text = "Wild Breath of Zelda" },
        { value = "Interface\\AddOns\\__FugaziBAGS\\media\\Fonts\\ModernSignature.ttf",      text = "Modern Signature" },
    }
    local catFontDropdown = CreateFrame("Frame", "FugaziBAGSSkinsCategoryFontDropdown", scrollChild, "UIDropDownMenuTemplate")
    catFontDropdown:SetPoint("TOPLEFT", cbCatFont, "BOTTOMLEFT", -6, -12)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(catFontDropdown, 144) end
    SkinDropDown(catFontDropdown)
    local function CatFontMenu_Init(frame, level)
        for _, opt in ipairs(CAT_HEADER_FONTS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.text
                info.func = function()
                    local SV = _G.FugaziBAGSDB
                    if SV then SV.gphCategoryHeaderFont = opt.value end
                    if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(frame, opt.value) end
                    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(frame, opt.text) end
                    if _G.ApplyTestSkin then _G.ApplyTestSkin() end
                    if RefreshGPHUI then RefreshGPHUI() end
                    if RefreshBankUI then RefreshBankUI() end
                    
                end
                info.checked = (frame.selectedValue == opt.value)
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(catFontDropdown, CatFontMenu_Init) end
    
    curY = curY + 40

    local catFontSizeSlider = CreateFugaziSlider(scrollChild, "FugaziBAGSSkinsCategoryFontSize", "Header Font Size", 6, 24, 1, "gphCategoryHeaderFontSize", 11, LEFT_X + 6, -curY, false, "Set the font size for category headers (e.g. 'Armor', 'Consumables').")
    curY = curY + 40
    -- Section: Custom Colors (Right Column)
    local colorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    colorLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", RIGHT_X, -headerSectionY)
    colorLabel:SetText("Custom Global Colors:")

    local COLOR_OVERRIDES = {
        { key = "headerTextColor",   label = "Header & category text" },
        { key = "mainBg",            label = "Frame background" },
        { key = "fitRowColor",       label = "FIT row label text" },
    }
    local function GetSkinDefaultColor(skinName, key)
        local sk = _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.SKIN and _G.__FugaziBAGS_Skins.SKIN[skinName or "original"]
        if sk and sk[key] then return unpack(sk[key]) end
        if key == "mainBg" then return 0.08, 0.08, 0.12, 0.92 end
        if key == "headerTextColor" and sk and sk.titleTextColor then return unpack(sk.titleTextColor) end
        if key == "fitRowColor" then return 0.5, 0.8, 1.0, 1 end 
        return 1, 0.85, 0.4, 1
    end
    local function OpenColorPicker(overrideKey, labelText)
        local SV = _G.FugaziBAGSDB
        if not SV then return end
        if not SV.gphSkinOverrides then SV.gphSkinOverrides = {} end
        local cur = SV.gphSkinOverrides[overrideKey]
        local skinName = SV.gphSkin or "original"
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
        if not _G.ColorPickerFrame then return end
        _G.ColorPickerFrame.previousValues = { r, g, b, a }
        _G.ColorPickerFrame.func = function()
            local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
            local SV2 = _G.FugaziBAGSDB
            if not SV2.gphSkinOverrides then SV2.gphSkinOverrides = {} end
            local skinNameNow = SV2.gphSkin or "original"
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
            if na and na < 0 then na = 0 end
            if na and na > 1 then na = 1 end
            SV2.gphSkinOverrides[overrideKey] = { nr, ng, nb, na }
            

            if Skins and Skins.SKIN and Skins.SKIN[skinNameNow] and Skins.SKIN[skinNameNow][overrideKey] then
                Skins.SKIN[skinNameNow][overrideKey] = { nr, ng, nb, na }
            end
            if _G.ApplyTestSkin then _G.ApplyTestSkin() end
            if RefreshGPHUI then RefreshGPHUI() end
            if RefreshBankUI then RefreshBankUI() end
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
            
        end
        _G.ColorPickerFrame:SetColorRGB(r, g, b)
        
        _G.ColorPickerFrame.hasOpacity = (overrideKey == "mainBg")
        _G.ColorPickerFrame.opacity = 1 - a
        if _G.OpacitySliderFrame then
            if _G.OpacitySliderFrame.SetValue then _G.OpacitySliderFrame:SetValue(1 - a) end
            if _G.ColorPickerFrame.hasOpacity then _G.OpacitySliderFrame:Show() else _G.OpacitySliderFrame:Hide() end
        end
        if _G.ColorPickerFrame.SetOpacity then _G.ColorPickerFrame:SetOpacity(1 - a) end
        _G.ColorPickerFrame:Show()
    end

    local function OpenRarityColorPicker()
        local SV = _G.FugaziBAGSDB
        if not SV then return end
        
        
        local dd = _G.FugaziBAGSSkinsRaritySelectDropdown
        local rq = (dd and dd.selectedQuality) or 1
        if not SV.gphSkinOverrides then SV.gphSkinOverrides = {} end
        if not SV.gphSkinOverrides.itemDetailsRarityColors then SV.gphSkinOverrides.itemDetailsRarityColors = {} end
        local curr = SV.gphSkinOverrides.itemDetailsRarityColors[rq]
        if not curr then
            local def = (A.QUALITY_COLORS and A.QUALITY_COLORS[rq]) or { r = 1, g = 1, b = 1 }
            curr = { def.r or 1, def.g or 1, def.b or 1 }
        end
        if not _G.ColorPickerFrame then return end
        _G.ColorPickerFrame.func = function()
            local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
            local SV2 = _G.FugaziBAGSDB
            if not SV2.gphSkinOverrides then SV2.gphSkinOverrides = {} end
            if not SV2.gphSkinOverrides.itemDetailsRarityColors then SV2.gphSkinOverrides.itemDetailsRarityColors = {} end
            SV2.gphSkinOverrides.itemDetailsRarityColors[rq] = { nr, ng, nb }
            if RefreshGPHUI then RefreshGPHUI() end
            if RefreshBankUI then RefreshBankUI() end
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
            if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then _G.FugaziInstanceTracker_RefreshSkinFromBAGS() end
        end
        _G.ColorPickerFrame:SetColorRGB(unpack(curr))
        _G.ColorPickerFrame.hasOpacity = false
        _G.ColorPickerFrame:Show()
    end

    local colorBtns = {}
    for i, row in ipairs(COLOR_OVERRIDES) do
        local btn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        btn:SetSize(180, 22)
        btn:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 8, -2 - ((i-1)*26))
        btn:SetText(row.label)
        if btn:GetFontString() then btn:GetFontString():SetTextColor(1, 1, 1) end -- Use white text to match dropdowns
        local swatch = btn:CreateTexture(nil, "OVERLAY")
        swatch:SetSize(16, 16)
        swatch:SetPoint("LEFT", btn, "RIGHT", 6, 0)
        swatch:SetTexture(1, 1, 1, 1)
        btn._swatch = swatch
        btn._key = row.key
        btn:SetScript("OnClick", function(self) OpenColorPicker(self._key, row.label) end)
        SkinButton(btn)
        colorBtns[row.key] = btn
    end

    curY = headerSectionY + 160 -- Move past the header section
    CreateSeparator(curY)
    curY = curY + 20

    
    local rowSectionY = curY
    local itemDetailsLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    itemDetailsLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", LEFT_X, -curY)
    itemDetailsLabel:SetText("Inventory List Row Details:")
    curY = curY + ROW

    local cbItemDetails = CreateFrame("CheckButton", "FugaziBAGSSkinsItemDetailsCheck", scrollChild, "OptionsCheckButtonTemplate")
    cbItemDetails:SetPoint("TOPLEFT", itemDetailsLabel, "BOTTOMLEFT", 8, -4)
    SkinCheckBox(cbItemDetails)
    _G["FugaziBAGSSkinsItemDetailsCheckText"]:SetText("Enable Row Formatting")
    cbItemDetails:SetScript("OnClick", function(self)
        local SV = _G.FugaziBAGSDB
        if SV then SV.gphItemDetailsCustom = (self:GetChecked() == 1 or self:GetChecked() == true) end
        if _G.ApplyTestSkin then _G.ApplyTestSkin() end
        if RefreshGPHUI then RefreshGPHUI() end
        if RefreshBankUI then RefreshBankUI() end
        if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then _G.FugaziInstanceTracker_RefreshSkinFromBAGS() end
        if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
    end)
    curY = curY + 32

    local cbHideIcons = CreateFrame("CheckButton", "FugaziBAGSSkinsHideIconsCheck", scrollChild, "OptionsCheckButtonTemplate")
    cbHideIcons:SetPoint("TOPLEFT", cbItemDetails, "BOTTOMLEFT", 0, -4)
    SkinCheckBox(cbHideIcons)
    _G["FugaziBAGSSkinsHideIconsCheckText"]:SetText("Hide Category Icons")
    cbHideIcons:SetScript("OnClick", function(self)
        local SV = _G.FugaziBAGSDB
        if SV then SV.gphHideIconsInList = (self:GetChecked() == 1 or self:GetChecked() == true) end
        if RefreshGPHUI then RefreshGPHUI() end
        if RefreshBankUI then RefreshBankUI() end
        if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then _G.FugaziInstanceTracker_RefreshSkinFromBAGS() end
    end)
    curY = curY + 32

    local itemDetailsFontDropdown = CreateFrame("Frame", "FugaziBAGSSkinsItemDetailsFontDropdown", scrollChild, "UIDropDownMenuTemplate")
    itemDetailsFontDropdown:SetPoint("TOPLEFT", cbHideIcons, "BOTTOMLEFT", -6, -12)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(itemDetailsFontDropdown, 144) end
    SkinDropDown(itemDetailsFontDropdown)
    local function ItemDetailsFontMenu_Init(frame, level)
        for _, opt in ipairs(ITEM_DETAILS_FONTS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.text
                info.func = function()
                    local SV = _G.FugaziBAGSDB
                    if SV then SV.gphItemDetailsFont = opt.value end
                    if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(frame, opt.value) end
                    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(frame, opt.text) end
                    if RefreshGPHUI then RefreshGPHUI() end
                    if RefreshBankUI then RefreshBankUI() end
                    if _G.FugaziInstanceTracker_RefreshSkinFromBAGS then _G.FugaziInstanceTracker_RefreshSkinFromBAGS() end
                end
                info.checked = (frame.selectedValue == opt.value)
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(itemDetailsFontDropdown, ItemDetailsFontMenu_Init) end
    curY = curY + 40

    curY = curY + 40

    local itemDetailsIconSizeSlider = CreateFugaziSlider(scrollChild, "FugaziBAGSSkinsItemDetailsIconSize", "Row Icon Size", 12, 28, 1, "gphItemDetailsIconSize", 16, LEFT_X + 6, -curY, false, "Icon size used in the list view.")
    curY = curY + 60

    local itemDetailsFontSizeSlider = CreateFugaziSlider(scrollChild, "FugaziBAGSSkinsItemDetailsFontSize", "Row Font Size", 8, 24, 1, "gphItemDetailsFontSize", 11, LEFT_X + 6, -curY, false, "Font size used for item names in the list view.")
    curY = curY + 60

    local itemDetailsAlphaSlider = CreateFugaziSlider(scrollChild, "FugaziBAGSSkinsItemDetailsAlpha", "Row Opacity", 0.0, 1.0, 0.05, "gphItemDetailsAlpha", 1.0, LEFT_X + 6, -curY, true, "Adjust transparency for inventory list rows.")
    curY = curY + 60
    
    -- Section: Custom Row Colors (Right Column)
    local rarityColorLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    rarityColorLabel:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", RIGHT_X, -rowSectionY)
    rarityColorLabel:SetText("Custom Colors by Quality:")

    local raritySelectDropdown = CreateFrame("Frame", "FugaziBAGSSkinsRaritySelectDropdown", scrollChild, "UIDropDownMenuTemplate")
    raritySelectDropdown:SetPoint("TOPLEFT", rarityColorLabel, "BOTTOMLEFT", 2, -12)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(raritySelectDropdown, 160) end
    SkinDropDown(raritySelectDropdown)
    raritySelectDropdown.selectedQuality = 1
    local function RaritySelectMenu_Init(frame, level)
        for _, opt in ipairs(RARITY_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo()
            if info then
                info.text = opt.label
                info.func = function()
                    frame.selectedQuality = opt.q
                    if UIDropDownMenu_SetSelectedValue then UIDropDownMenu_SetSelectedValue(frame, opt.q) end
                    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(frame, opt.label) end
                    if UIDropDownMenu_Refresh then UIDropDownMenu_Refresh(frame, nil, 1) end
                    if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
                end
                info.checked = (frame.selectedQuality == opt.q)
                UIDropDownMenu_AddButton(info, level or 1)
            end
        end
    end
    if UIDropDownMenu_Initialize then UIDropDownMenu_Initialize(raritySelectDropdown, RaritySelectMenu_Init) end

    local rarityColorBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    rarityColorBtn:SetSize(180, 22)
    rarityColorBtn:SetPoint("TOPLEFT", raritySelectDropdown, "BOTTOMLEFT", 6, -6)
    rarityColorBtn:SetText("Set Color for Quality")
    local rs0 = rarityColorBtn:CreateTexture(nil, "OVERLAY")
    rs0:SetSize(16, 16)
    rs0:SetPoint("LEFT", rarityColorBtn, "RIGHT", 6, 0)
    rs0:SetTexture(1, 1, 1, 1)
    rarityColorBtn._swatch = rs0
    rarityColorBtn:SetScript("OnClick", OpenRarityColorPicker)
    SkinButton(rarityColorBtn)

    local iconColorBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    iconColorBtn:SetSize(180, 22)
    iconColorBtn:SetPoint("TOPLEFT", rarityColorBtn, "BOTTOMLEFT", 0, -12)
    iconColorBtn:SetText("Row Icon Global Tint")
    local is0 = iconColorBtn:CreateTexture(nil, "OVERLAY")
    is0:SetSize(16, 16)
    is0:SetPoint("LEFT", iconColorBtn, "RIGHT", 6, 0)
    is0:SetTexture(1, 1, 1, 1)
    iconColorBtn._swatch = is0
    iconColorBtn:SetScript("OnClick", function()
        local SV = _G.FugaziBAGSDB
        if not SV then return end
        if not SV.gphSkinOverrides then SV.gphSkinOverrides = {} end
        local curr = SV.gphSkinOverrides.itemDetailsIconColor or {1, 1, 1}
        if not _G.ColorPickerFrame then return end
        _G.ColorPickerFrame.func = function()
            local nr, ng, nb = _G.ColorPickerFrame:GetColorRGB()
            local SV2 = _G.FugaziBAGSDB
            if not SV2.gphSkinOverrides then SV2.gphSkinOverrides = {} end
            SV2.gphSkinOverrides.itemDetailsIconColor = { nr, ng, nb }
            if RefreshGPHUI then RefreshGPHUI() end
            if RefreshBankUI then RefreshBankUI() end
            if FugaziBAGSSkinsPanel and FugaziBAGSSkinsPanel.refresh then FugaziBAGSSkinsPanel.refresh() end
        end
        _G.ColorPickerFrame:SetColorRGB(unpack(curr))
        _G.ColorPickerFrame.hasOpacity = false
        _G.ColorPickerFrame:Show()
    end)
    SkinButton(iconColorBtn)

    curY = curY + 20
    scrollChild:SetHeight(curY + 100)

    panel.refresh = function()
        local SV = _G.FugaziBAGSDB or {}
        local sk = SV.gphSkin or "original"
        local skText = (sk == "elvui" and "Elvui (Ebonhold)") or (sk == "elvui_real" and "ElvUI") or (sk == "pimp_purple" and "Pimp Purple") or (sk == "fugazi" and "FUGAZI") or "Original"
        UIDropDownMenu_SetSelectedValue(skinDropdown, sk)
        UIDropDownMenu_SetText(skinDropdown, skText)

        cbCatFont:SetChecked(SV.gphCategoryHeaderFontCustom)
        local hFont = SV.gphCategoryHeaderFont or "Fonts\\ARIALN.TTF"
        UIDropDownMenu_SetSelectedValue(catFontDropdown, hFont)
        for _, o in ipairs(CAT_HEADER_FONTS) do if o.value == hFont then UIDropDownMenu_SetText(catFontDropdown, o.text) break end end
        catFontSizeSlider._isRefreshing = true
        catFontSizeSlider:SetValue(SV.gphCategoryHeaderFontSize or 11)
        catFontSizeSlider._isRefreshing = false

        
        for key, btn in pairs(colorBtns) do
            local r, g, b = GetSkinDefaultColor(sk, key)
            local cur = SV.gphSkinOverrides and SV.gphSkinOverrides[key]
            if cur then r, g, b = unpack(cur) end
            btn._swatch:SetVertexColor(r, g, b)
        end

        cbItemDetails:SetChecked(SV.gphItemDetailsCustom)
        cbHideIcons:SetChecked(SV.gphHideIconsInList)
        local iFont = SV.gphItemDetailsFont or "Fonts\\FRIZQT__.TTF"
        UIDropDownMenu_SetSelectedValue(itemDetailsFontDropdown, iFont)
        for _, o in ipairs(ITEM_DETAILS_FONTS) do if o.value == iFont then UIDropDownMenu_SetText(itemDetailsFontDropdown, o.text) break end end
        itemDetailsFontSizeSlider._isRefreshing = true
        itemDetailsFontSizeSlider:SetValue(SV.gphItemDetailsFontSize or 11)
        itemDetailsFontSizeSlider._isRefreshing = false

        itemDetailsIconSizeSlider._isRefreshing = true
        itemDetailsIconSizeSlider:SetValue(SV.gphItemDetailsIconSize or 16)
        itemDetailsIconSizeSlider._isRefreshing = false

        itemDetailsAlphaSlider._isRefreshing = true
        itemDetailsAlphaSlider:SetValue((SV.gphItemDetailsAlpha or 1.0) * 100)
        itemDetailsAlphaSlider._isRefreshing = false

        
        local iCol = SV.gphSkinOverrides and SV.gphSkinOverrides.itemDetailsIconColor or {1, 1, 1}
        iconColorBtn._swatch:SetVertexColor(unpack(iCol))

        local rq = raritySelectDropdown.selectedQuality or 1
        UIDropDownMenu_SetSelectedValue(raritySelectDropdown, rq)
        for _, o in ipairs(RARITY_OPTIONS) do if o.q == rq then UIDropDownMenu_SetText(raritySelectDropdown, o.label) break end end
        local rCol = SV.gphSkinOverrides and SV.gphSkinOverrides.itemDetailsRarityColors and SV.gphSkinOverrides.itemDetailsRarityColors[rq]
        if rCol then rarityColorBtn._swatch:SetVertexColor(unpack(rCol))
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
        
        if rarityColorLabel then rarityColorLabel:SetAlpha(showRows and 1.0 or 0.3) end
        
        -- Icons should always be visible and move together
        SetFugaziControlEnabled(itemDetailsIconSizeSlider, true)
        if itemDetailsIconSizeSlider then itemDetailsIconSizeSlider:Show() end
    end

    local function ResetSkinDefaults()
        if _G.ApplyFugaziPreset then _G.ApplyFugaziPreset() end
        panel.refresh()
        if _G.ApplyTestSkin then _G.ApplyTestSkin() end
        RefreshAllUI()
    end

    panel.default = ResetSkinDefaults

    local resetBtnSkins = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtnSkins:SetSize(120, 22)
    resetBtnSkins:SetPoint("BOTTOMLEFT", 16, 16)
    resetBtnSkins:SetText("Reset Defaults")
    SkinButton(resetBtnSkins)
    resetBtnSkins:SetScript("OnClick", ResetSkinDefaults)

    if InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
end


--- Instructions / help panel in options.
local function CreateInstructionsPanel()
    if _G.FugaziBAGSInstructionsOptionsPanel then return end

    local panel = CreateFrame("Frame", "FugaziBAGSInstructionsOptionsPanel", UIParent)
    panel.name = "Instructions"
    panel.parent = "_FugaziBAGS"
    panel.okay = function() end
    panel.cancel = function() end
    panel.default = function() end
    panel.refresh = function() end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff40c040_FugaziBAGS Instructions|r")

    local scrollFrame = CreateFrame("ScrollFrame", "FugaziBAGSInstructionsOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 16)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 0, 0)
    
    text:SetWidth(380)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetTextColor(1, 1, 1)

    text:SetText(table.concat({
        "|cffffe070Bags and frames:|r",
        " - |cff40c0ffB key|r: Open/close |cff40c0ffFugaziBAGS|r instead of Blizzard bags.",
        " - |cff40c0ffRight-Click the Inventory Header|r to open the |cff40c0ffFugaziBAGS|r menu.",
        " - The |cffff6060Autodeleted list|r is per character. You can copy it from another toon in the FugaziBAGS options.",
        " - Items can be removed from the |cffff6060autodelete list|r via |cff40c0fflist view|r in inventory or the Escape Menu.",
        "",
        "|cffffe070Item protection:|r",
        " - |cff40c0ffAlt+Left-Click|r an item (list or grid): Toggle |cff40c0ffProtected|r status on that item.",
        "   Protected items are skipped by: vendor, autosell, mass-mail, mass-disenchant, and |cffff6060auto-destroy|r. Protected Items move above the Hearthstone to the top of the List in |cff40c0fflist view|r. In grid view they get an overlay.",
        "",
        "|cffffe070Auto-delete (destroy list):|r",
        " - |cffff6060Ctrl+Right-Click|r an item: Toggle that exact item ID on the |cffff6060auto-destroy list|r.",
        " - The |cffff6060'Confirm Auto Delete'|r option decides if you see a warning popup first.",
        "",
        "|cffffe070Mailing:|r",
        " - |cff40c0ffGet All Mail|r: Pulls attachments and gold from your mailbox, stopping when 1 free bag slot remains.",
        " - |cff40c0ffSend All Items|r (Send tab): Sends all unprotected, non-quest items in your bags to the current recipient.",
        "",
        "|cffffe070Rarity buttons (top of the frame):|r",
        " - |cff40c0ffLeft-Click|r: Filter your bags by that item quality.",
        " - |cff40c0ffAlt+Left-Click|r: Protect all items of that quality for this character.",
        "",
        " - You can |cff40c0ffhold Alt|r and drag across the rarity buttons to quickly protect multiple qualities. Manually unprotecting single items in your bags overrides the rarity protection for those items.",
        " - |cff40c0ffCtrl+Left-Click|r a rarity button multiple times: cycle |cffff6060continuous auto-delete mode|r for that quality.",
        " - In continuous mode, all new unprotected items of that quality are automatically |cffff6060deleted|r as they enter your bags.",
        "",
        "|cffffe070GPH timer (Gold per hour):|r",
        " - |cff40c0ff'Start timer' button|r in Inventory Menu: Begin a |cff40c0ffGPH session|r.",
        " - |cffffe050While running|r, the top bar shows: |cffffe050Gold earned, Timer, and GPH|r values.",
        "   |cffffe050GPH|r treats your run as if you vendor all poor (grey) drops and sell all non-soulbound common+ drops at 85% of their auction value. if you vendor them instead, then the vendor value is used instead.",
        " - Soulbound items and '|cff40c0ff'Previously worn gear'|r' are ignored in the GPH value because you cannot realistically tell apart your equipment vs what you would want to sell.",
        "",
        "|cffffe070Previously worn gear:|r",
        " - Items you have worn earlier on this character are remembered.",
        " - Their tooltip shows |cff40c0ff'Previously worn gear'|r and they behave as Protected by default.",
    }, "\n"))

    local h = text:GetStringHeight() or 0
    content:SetHeight(h)

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
            if A.ToggleGPHFrame then A.ToggleGPHFrame() end
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

        info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "|cff00ccffClean up Inventory|r"
        info.func = function()
           if A.GPH_BagSort_Run then A.GPH_BagSort_Run(_G.RefreshGPHUI) end
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
                                local itemID = (_G.GetContainerItemID and _G.GetContainerItemID(b, s)) or (GetContainerItemID and GetContainerItemID(b, s))
                                if itemID then
                                    local appID = _G.C_Appearance and _G.C_Appearance.GetItemAppearanceID(itemID)
                                    if appID and not c.IsAppearanceCollected(appID) then
                                        local guid = (_G.GetContainerItemGUID and _G.GetContainerItemGUID(b, s)) or (GetContainerItemGUID and GetContainerItemGUID(b, s))
                                        if guid then
                                            c.CollectItemAppearance(guid)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                CloseDropDownMenus()
            end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
        end

        -- Group: Session (Injected by FIT)
        if A.GPHTitleMenu_InjectSession then
            info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)
            A.GPHTitleMenu_InjectSession(self, level)
            info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)
        end


        -- Group: Tools (Notepad + Tracker/Ledger)
        info = UIDropDownMenu_CreateInfo()
        info.text = "Notepad"
        info.func = function()
            if A.ToggleGPHNotepad then A.ToggleGPHNotepad() end
            CloseDropDownMenus()
        end
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        if A.GPHTitleMenu_InjectTrackerStats then
            A.GPHTitleMenu_InjectTrackerStats(self, level)
        end

        info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)

        
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
            info = UIDropDownMenu_CreateInfo()
            info.text = "Autosummon Greedy scavenger"
            info.isNotRadio = true
            info.checked = (SV.gphSummonGreedy ~= false)
            info.func = function()
                SV.gphSummonGreedy = not SV.gphSummonGreedy
                
            end
            UIDropDownMenu_AddButton(info)

            
            info = UIDropDownMenu_CreateInfo()
            info.text = "Summon Greedy scavenger"
            info.func = function() A.DoGphSummonGreedyNow() end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)

            info = UIDropDownMenu_CreateInfo()
            info.text = "Summon Goblin Merchant"
            info.func = function() A.DoGphSummonGoblinMerchantNow() end
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)

            info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)
        end

        
        local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
        local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
        if hasDE or hasProspect then
            info = UIDropDownMenu_CreateInfo()
            info.text = "Destroy"
            info.isNotRadio = true
            info.checked = not A.GetPerChar("gphHideDestroyBtn", false)
            info.func = function()
                A.SetPerChar("gphHideDestroyBtn", not A.GetPerChar("gphHideDestroyBtn", false))
                if f.UpdateGPHProfessionButtons then f:UpdateGPHProfessionButtons() end
            end
            UIDropDownMenu_AddButton(info)
        end

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

        
            info = UIDropDownMenu_CreateInfo(); info.text = ""; info.isTitle = true; info.notCheckable = true; UIDropDownMenu_AddButton(info)
            local gridMode = A.GetPerChar("gphGridMode", false)
            info = UIDropDownMenu_CreateInfo()
            info.text = (not gridMode) and "|cff00ff00List View|r" or "List View"
            info.checked = not gridMode
            info.func = function()
                A.SetPerChar("gphGridMode", false)
                f.gphGridMode = false
                local cg = _G.FugaziBAGS_CombatGrid
                if cg and cg.HideInFrame then cg.HideInFrame(f) end
                if _G.RefreshGPHUI then f._refreshImmediate = true; _G.RefreshGPHUI() end
                if f.RefreshBagLayout then f:RefreshBagLayout() end
                if f.NegotiateSizes then f:NegotiateSizes() end
                if A.Bank and A.Bank:IsShown() and _G.RefreshBankUI then _G.RefreshBankUI() end
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
                if cg and cg.ShowInFrame then cg.ShowInFrame(f) end
                if _G.RefreshGPHUI then _G.RefreshGPHUI() end
                if f.NegotiateSizes then f:NegotiateSizes() end
                if A.Bank and A.Bank:IsShown() and _G.RefreshBankUI then _G.RefreshBankUI() end
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
                if _G.RefreshGPHUI then f._refreshImmediate = true; _G.RefreshGPHUI() end
                if _G.RefreshBankUI then _G.RefreshBankUI() end
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

-- Expose panel creators so FugaziBAGS_Initialize.lua RunAddonLoader can call them via A.
A.CreateOptionsPanel          = CreateOptionsPanel
A.CreateGridviewOptionsPanel  = CreateGridviewOptionsPanel
A.CreateSkinsPanel            = CreateSkinsPanel
A.CreateInstructionsPanel     = CreateInstructionsPanel
