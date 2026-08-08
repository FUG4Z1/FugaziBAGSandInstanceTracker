local addonName, Addon = ...; Addon = Addon or _G.FugaziBAGS
local A = Addon

-- =======================================================================
-- NOTEPAD FEATURE
-- =======================================================================

StaticPopupDialogs["FUGAZI_NOTEPAD_RENAME"] = {
    text = "Enter new tab name:",
    button1 = "Accept",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self, data)
        local text = self.editBox:GetText()
        if text and text ~= "" and data.f and data.idx then
            local SV = _G.FugaziBAGSDB or {}
            SV.notepadTabs[data.idx].name = text
            data.f:RefreshTabs()
        end
    end,
    EditBoxOnEnterPressed = function(self, data)
        local text = self:GetParent().editBox:GetText()
        if text and text ~= "" and data.f and data.idx then
            local SV = _G.FugaziBAGSDB or {}
            SV.notepadTabs[data.idx].name = text
            data.f:RefreshTabs()
        end
        self:GetParent():Hide()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["FUGAZI_NOTEPAD_DELETE"] = {
    text = "Delete this tab?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function(self, data)
        if data.f and data.idx then
            local SV = _G.FugaziBAGSDB or {}
            if #SV.notepadTabs > 1 then
                table.remove(SV.notepadTabs, data.idx)
                if SV.activeNotepadTab > #SV.notepadTabs then
                    SV.activeNotepadTab = #SV.notepadTabs
                elseif SV.activeNotepadTab == data.idx then
                    SV.activeNotepadTab = math.max(1, SV.activeNotepadTab)
                elseif SV.activeNotepadTab > data.idx then
                    SV.activeNotepadTab = SV.activeNotepadTab - 1
                end
                data.f:RefreshTabs()
                data.f.editBox:SetText(SV.notepadTabs[SV.activeNotepadTab].content or "")
            end
        end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}


A.ToggleGPHNotepad = function()
    local SV = _G.FugaziBAGSDB or {}
    
    -- Migration / Init
    if not SV.notepadTabs then
        SV.notepadTabs = { {name = "Main", content = SV.notepadText or ""} }
        SV.activeNotepadTab = 1
    end
    if not SV.activeNotepadTab or not SV.notepadTabs[SV.activeNotepadTab] then
        SV.activeNotepadTab = 1
    end

    if _G.FugaziBAGSNotepad then
        if _G.FugaziBAGSNotepad:IsShown() then
            _G.FugaziBAGSNotepad:Hide()
        else
            _G.FugaziBAGSNotepad:Show()
            _G.FugaziBAGSNotepad:RefreshTabs()
            _G.FugaziBAGSNotepad.editBox:SetText(SV.notepadTabs[SV.activeNotepadTab].content or "")
        end
        return
    end

    local f = CreateFrame("Frame", "FugaziBAGSNotepad", UIParent)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(15)
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:SetMinResize(200, 200)

    local gphRef = A.Inventory
    local np = SV.notepad or {}
    if np.w and np.h then
        f:SetSize(np.w, np.h)
    else
        f:SetSize(gphRef and gphRef:GetWidth() or 340, gphRef and gphRef:GetHeight() or 400)
    end

    if np.p and np.rp and np.x and np.y then
        f:SetPoint(np.p, UIParent, np.rp, np.x, np.y)
    else
        f:SetPoint("CENTER", 0, 0)
    end

    local titleBar = CreateFrame("Button", nil, f)
    titleBar:SetHeight(24)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        f:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local p, _, rp, x, y = f:GetPoint()
        SV.notepad = SV.notepad or {}
        SV.notepad.p, SV.notepad.rp, SV.notepad.x, SV.notepad.y = p, rp, x, y
    end)
    f.gphTitleBar = titleBar

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("Notepad")
    f.gphTitle = titleText

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    closeBtn:SetSize(24, 24)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local tabRow = CreateFrame("Frame", nil, f)
    tabRow:SetHeight(26)
    tabRow:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    tabRow:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    f.tabRow = tabRow

    local sf = CreateFrame("ScrollFrame", "FugaziBAGSNotepadScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", tabRow, "BOTTOMLEFT", 10, -5)
    sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 20)

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlight")
    eb:SetWidth(sf:GetWidth())
    eb:SetHeight(3000)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    f.editBox = eb
    
    eb:SetScript("OnChar", function()
        if SV.gphClickSound ~= false and PlaySoundFile then
            PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\click.ogg")
        end
    end)
    
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            local txt = self:GetText()
            if (f._prevLen or 0) > #txt then
                if SV.gphClickSound ~= false and PlaySoundFile then
                    PlaySoundFile("Interface\\AddOns\\__FugaziBAGS\\media\\hover.ogg")
                end
            end
            f._prevLen = #txt
            if SV.notepadTabs and SV.activeNotepadTab and SV.notepadTabs[SV.activeNotepadTab] then
                SV.notepadTabs[SV.activeNotepadTab].content = txt
            end
        end
    end)
    
    eb:SetScript("OnCursorChanged", function(self, x, y, w, h_edit)
        local vs = sf:GetVerticalScroll()
        local h = sf:GetHeight()
        if not y then return end
        local top = -y
        local bottom = top - 15
        if bottom > vs + h then sf:SetVerticalScroll(bottom - h + 15)
        elseif top < vs then sf:SetVerticalScroll(math.max(top - 15, 0)) end
    end)

    f.RefreshTabs = function(self)
        if not self.tabButtons then self.tabButtons = {} end
        for _, b in ipairs(self.tabButtons) do b:Hide() end
        
        local maxWidth = self:GetWidth() - 24
        local xOffset = 10
        local yOffset = -2
        local rowHeight = 22
        local numRows = 1
        
        for i, tab in ipairs(SV.notepadTabs) do
            local btn = self.tabButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, self.tabRow)
                btn:SetHeight(20)
                btn:SetNormalFontObject("GameFontNormalSmall")
                
                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                btn.bg = bg
                
                btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                btn:SetScript("OnClick", function(s, button)
                    if button == "LeftButton" then
                        if IsShiftKeyDown() then
                            local data = { f = self, idx = i }
                            StaticPopup_Show("FUGAZI_NOTEPAD_RENAME", nil, nil, data)
                        else
                            SV.notepadTabs[SV.activeNotepadTab].content = eb:GetText()
                            SV.activeNotepadTab = i
                            self:RefreshTabs()
                            eb:SetText(SV.notepadTabs[i].content or "")
                            eb:SetCursorPosition(0)
                        end
                    elseif button == "RightButton" then
                        local data = { f = self, idx = i }
                        StaticPopup_Show("FUGAZI_NOTEPAD_DELETE", nil, nil, data)
                    end
                end)
                
                btn:SetScript("OnEnter", function(s)
                    GameTooltip:SetOwner(s, "ANCHOR_TOP")
                    GameTooltip:AddLine(tab.name, 0.8, 0.9, 1.0)
                    GameTooltip:AddLine("Shift-LMB to rename", 1, 1, 1)
                    GameTooltip:AddLine("RMB to delete", 1, 0.2, 0.2)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                self.tabButtons[i] = btn
            end
            
            btn:SetText(tab.name)
            local btnWidth = math.max(40, btn:GetFontString():GetStringWidth() + 16)
            
            if xOffset + btnWidth > maxWidth then
                xOffset = 10
                yOffset = yOffset - rowHeight
                numRows = numRows + 1
            end
            
            btn:SetSize(btnWidth, 20)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.tabRow, "TOPLEFT", xOffset, yOffset)
            
            if i == SV.activeNotepadTab then
                btn.bg:SetTexture(0.3, 0.3, 0.3, 0.9)
                btn:GetFontString():SetTextColor(1, 1, 1)
            else
                btn.bg:SetTexture(0.1, 0.1, 0.1, 0.7)
                btn:GetFontString():SetTextColor(0.6, 0.6, 0.6)
            end
            
            btn:Show()
            xOffset = xOffset + btnWidth + 4
        end
        
        if not self.addBtn then
            local b = CreateFrame("Button", nil, self.tabRow)
            b:SetSize(20, 20)
            b:SetText("+")
            b:SetNormalFontObject("GameFontNormalLarge")
            local tex = b:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints()
            tex:SetTexture(0.2, 0.4, 0.2, 0.6)
            b.bg = tex
            b:SetScript("OnClick", function()
                table.insert(SV.notepadTabs, { name = "Tab " .. (#SV.notepadTabs + 1), content = "" })
                self:RefreshTabs()
            end)
            self.addBtn = b
        end
        
        if xOffset + 22 > maxWidth then
            xOffset = 10
            yOffset = yOffset - rowHeight
            numRows = numRows + 1
        end
        self.addBtn:ClearAllPoints()
        self.addBtn:SetPoint("TOPLEFT", self.tabRow, "TOPLEFT", xOffset, yOffset)
        self.addBtn:Show()
        
        self.tabRow:SetHeight(numRows * rowHeight + 4)
    end

    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetPoint("BOTTOMRIGHT", -4, 4)
    resizeBtn:SetSize(16, 16)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        local w, h = f:GetSize()
        SV.notepad = SV.notepad or {}
        SV.notepad.w, SV.notepad.h = w, h
    end)

    f:SetScript("OnSizeChanged", function(self, wf, hf)
        if sf then eb:SetWidth(sf:GetWidth()) end
        if self.RefreshTabs then self:RefreshTabs() end
    end)

    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.ApplyGPHFrameSkin then
        _G.__FugaziBAGS_Skins.ApplyGPHFrameSkin(f)
    end
    titleText:SetText("Notepad")
    
    if _G.__FugaziBAGS_Skins and _G.__FugaziBAGS_Skins.SkinScrollBar then
        _G.__FugaziBAGS_Skins.SkinScrollBar(sf)
    end

    _G.FugaziBAGSNotepad = f
    f:RefreshTabs()
    eb:SetText(SV.notepadTabs[SV.activeNotepadTab].content or "")
    f._prevLen = #eb:GetText()
    f:Show()
end

if hooksecurefunc then
    hooksecurefunc("ChatEdit_InsertLink", function(text)
        local np = _G.FugaziBAGSNotepad
        if np and np.editBox and np.editBox:HasFocus() then
            np.editBox:Insert(text)
            return true
        end
    end)
end
