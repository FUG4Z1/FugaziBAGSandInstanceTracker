local addonName, AddonTable = ...
_G["FugaziBAGS"] = _G["FugaziBAGS"] or AddonTable or {}
local Addon = _G["FugaziBAGS"]
local A = Addon

-- Looting Variables
A.isLootingMail = false
local lastMailLootTime = 0

function A.SetupGPHMailButton(mailBtn, f)
    if not mailBtn then return end
    _G.FugaziBAGS_MailButton = mailBtn
    
    local mailIcon = mailBtn.icon
    local mailLootWorker = CreateFrame("Frame", nil, f)
    
    mailBtn:EnableMouse(true)
    mailBtn:SetHitRectInsets(0, 0, 0, 0)
    mailBtn:RegisterForClicks("AnyUp")
    mailLootWorker:SetScript("OnUpdate", function(self, elapsed)
        if not A.isLootingMail then return end
        lastMailLootTime = (lastMailLootTime or 0) + elapsed
        if lastMailLootTime < 0.1 then return end
        lastMailLootTime = 0

        -- 1. Check free space
        local free = 0
        for bag = 0, 4 do
            free = free + (GetContainerNumFreeSlots(bag) or 0)
        end
        if free <= 1 then
            print("|cffff0000[FugaziBAGS]|r Mail looting stopped: 1 slot remaining.")
            A.isLootingMail = false
            return
        end

        local num = GetInboxNumItems()
        for i = 1, num do
            local _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
            if (cod or 0) <= 0 then
                if (hasItem and hasItem > 0) then
                    -- attachments logic
                    local attachments = 0
                    local maxAtt = (_G.ATTACHMENTS_MAX_RECEIVE or 12)
                    for ai = 1, maxAtt do
                        if GetInboxItem(i, ai) then attachments = attachments + 1 end
                    end
                    if free - attachments >= 1 then
                        AutoLootMailItem(i)
                        return
                    end
                elseif (money and money > 0) then
                    TakeInboxMoney(i)
                    return
                end
            end
        end
        print("|cff00ff00[FugaziBAGS]|r Finished looting mail.")
        A.isLootingMail = false
    end)

    mailBtn:EnableMouse(true)
    mailBtn:RegisterForClicks("AnyUp")
    mailBtn:SetScript("OnClick", function()
        local isSendTab = (_G.MailFrame and _G.MailFrame.selectedTab == 2)
        -- Fallback if selectedTab is not maintained
        if not isSendTab and SendMailNameEditBox and SendMailNameEditBox:IsVisible() then isSendTab = true end
        
        if isSendTab then
            if A.MailRarityActive then
                A.MailRarityActive = false
                print("|cffff0000[FugaziBAGS]|r Mailing cancelled.")
                return
            end
            
            local recipient = SendMailNameEditBox:GetText()
            if not recipient or recipient == "" then
                print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
                return
            end
            if A.StartSendRarityMail then
                A.StartSendRarityMail(-1)
            else
                StaticPopup_Show("GPH_CONFIRM_MAIL_ALL", recipient)
            end
        else
            if A.isLootingMail then
                A.isLootingMail = false
                print("|cffff0000[FugaziBAGS]|r Mail looting cancelled.")
            else
                A.isLootingMail = true
                lastMailLootTime = 0
                print("|cff00ff00[FugaziBAGS]|r Starting mail loot...")
            end
        end
    end)

    mailBtn:SetScript("OnEnter", function()
        -- High visibility feedback
        mailBtn:SetAlpha(1.0)
        
        local isSendTab = (_G.MailFrame and _G.MailFrame.selectedTab == 2)
        GameTooltip:SetOwner(mailBtn, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        if isSendTab then
            GameTooltip:AddLine("Send All Items", 0.9, 0.8, 0.4)
            GameTooltip:AddLine("Sends every item in your bags to current recipient.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Skips Hearthstone, Quest, and Protected items.", 1, 0.2, 0.2, true)
        else
            GameTooltip:AddLine("Get All Mail", 0.9, 0.8, 0.4)
            GameTooltip:AddLine("Quickly loots attachments and money.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Stops when only 1 bag slot remains.", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
        if f.gphTitleBarBtnHover then mailBtn.bg:SetTexture(unpack(f.gphTitleBarBtnHover)) else mailBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.8) end
    end)

    mailBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if f.gphTitleBarBtnNormal then mailBtn.bg:SetTexture(unpack(f.gphTitleBarBtnNormal)) else mailBtn.bg:SetTexture(0.1, 0.3, 0.15, 0.4) end
        mailIcon:SetAlpha(0.6)
    end)

    A.isLootingMail = false
    A.gphFrame = f
end


-- Rarity Mailing Variables
local mailRarityWorker = CreateFrame("Frame")
mailRarityWorker:Hide()
A.MailRarityQueue = {}
A.MailRarityIndex = 0
A.MailRarityActive = false


--- Send next batch of items (by quality) in mail.
function A.SendNextRarityBatch()
    if not A.MailRarityActive then return end
    
    local recipient = SendMailNameEditBox:GetText()
    if not recipient or recipient == "" then
        print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
        A.MailRarityActive = false
        mailRarityWorker:UnregisterEvent("MAIL_SEND_SUCCESS")
        mailRarityWorker:UnregisterEvent("MAIL_FAILED")
        return
    end

    if A.MailRarityIndex >= #A.MailRarityQueue then
        print("|cff00ff00[FugaziBAGS]|r Finished sending items.")
        A.MailRarityActive = false
        mailRarityWorker:UnregisterEvent("MAIL_SEND_SUCCESS")
        mailRarityWorker:UnregisterEvent("MAIL_FAILED")
        return
    end

    
    for i = 1, 12 do
        if GetSendMailItem(i) then
            ClickSendMailItemButton(i, true)
        end
    end

    
    local attached = 0
    local targetRarity = A.MailRarityJobQuality 

    while A.MailRarityIndex < #A.MailRarityQueue and attached < 12 do
        local nextIndex = A.MailRarityIndex + 1
        local item = A.MailRarityQueue[nextIndex]
        
        local link = GetContainerItemLink(item.bag, item.slot)
        if link then
            local _, _, locked = GetContainerItemInfo(item.bag, item.slot)
            
            -- IF LOCKED: Stop this batch attempt and wait for the defer tick (retry)
            -- DO NOT increment MailRarityIndex so we don't 'skip' the item permanently
            if locked then break end
            
            local itemId = tonumber(link:match("item:(%d+)"))
            local _, _, q = A.GetCachedItemInfo(link)
            q = q or 0
            
            local qualityMatch = (A.MailRarityJobQuality == -1) or (q == targetRarity)

            if qualityMatch and not A.RarityIsProtected(itemId, q) then
                -- Move index forward since we are processing it
                A.MailRarityIndex = nextIndex
                UseContainerItem(item.bag, item.slot)
                attached = attached + 1
            else
                -- Not a match/protected: permanently skip it
                A.MailRarityIndex = nextIndex
            end
        else
            -- Item gone: permanently skip it
            A.MailRarityIndex = nextIndex
        end
    end

    -- --- PHYSICAL VERIFICATION ---
    -- Confirm items are actually in the slots before hitting 'Send'
    local physicallyAttached = 0
    for i = 1, 12 do
        if GetSendMailItem(i) then
            physicallyAttached = physicallyAttached + 1
        end
    end

    if physicallyAttached > 0 then
        if SendMailSubjectEditBox:GetText() == "" then
            SendMailSubjectEditBox:SetText("Bulk Send (" .. A.MailRarityIndex .. ")")
        end
        SendMailFrame_SendMail()
    elseif A.MailRarityIndex < #A.MailRarityQueue then
        
        
        A._gphMailDeferFrame = A._gphMailDeferFrame or CreateFrame("Frame")
        local df = A._gphMailDeferFrame
        df._t = 0
        df:Show()
        df:SetScript("OnUpdate", function(self, elapsed)
            self._t = (self._t or 0) + elapsed
            if self._t > 0.5 then
                self:SetScript("OnUpdate", nil)
                self:Hide()
                A.SendNextRarityBatch()
            end
        end)
    else
        print("|cff00ff00[FugaziBAGS]|r Mailing finished (No more matches).")
        A.MailRarityActive = false
        A.MailRarityJobQuality = nil
        mailRarityWorker:UnregisterAllEvents()
        mailRarityWorker:SetScript("OnUpdate", nil)
    end
end


--- Mail progress tick: fill next slot, send when full.
local function mailRarityOnUpdate(self, elapsed)
    if not A.MailRarityActive then 
        self:SetScript("OnUpdate", nil)
        return 
    end
    
    self._timeoutTimer = (self._timeoutTimer or 0) + elapsed
    if self._timeoutTimer >= 1.5 then
        
        print("|cffff0000[FugaziBAGS]|r Mailing timed out (Inactivity). Stopping.")
        A.MailRarityActive = false
        A.MailRarityJobQuality = nil
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
    end
end
mailRarityWorker._onUpdateFunc = mailRarityOnUpdate
mailRarityWorker:SetScript("OnUpdate", mailRarityOnUpdate)

mailRarityWorker:SetScript("OnEvent", function(self, event)
    
    self._timeoutTimer = 0

    if event == "MAIL_SEND_SUCCESS" then
        
        local f = CreateFrame("Frame")
        local elapsed = 0
        f:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.5 then
                self:SetScript("OnUpdate", nil)
                self:Hide()
                A.SendNextRarityBatch()
            end
        end)
    elseif event == "MAIL_FAILED" or event == "MAIL_CLOSED" then
        print("|cffff0000[FugaziBAGS]|r Mailing cancelled or failed.")
        A.MailRarityActive = false
        A.MailRarityJobQuality = nil
        self:UnregisterAllEvents()
        self:SetScript("OnUpdate", nil)
    end
end)


--- Start mailing all items of one quality (e.g. all greys to alt).
function A.StartSendRarityMail(rarity)
    local recipient = SendMailNameEditBox:GetText()
    if not recipient or recipient == "" then
        print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
        return
    end

    wipe(A.MailRarityQueue)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                local _, _, q = A.GetCachedItemInfo(link)
                q = q or 0
                
                local match = (rarity == -1) or (q == rarity)
                if match and not A.RarityIsProtected(itemId, q) then
                    table.insert(A.MailRarityQueue, { bag = bag, slot = slot })
                end
            end
        end
    end

    if #A.MailRarityQueue == 0 then
        local msg = (rarity == -1) and "No unprotected items found." or "No unprotected items of this rarity found."
        print("|cffff0000[FugaziBAGS]|r " .. msg)
        return
    end

    local label = (rarity == -1) and "ALL items" or (#A.MailRarityQueue .. " items")
    print("|cff00ff00[FugaziBAGS]|r Sending " .. label .. " to " .. recipient)

    A.MailRarityActive = true
    A.MailRarityIndex = 0
    A.MailRarityJobQuality = rarity
    mailRarityWorker._timeoutTimer = 0 
    mailRarityWorker:RegisterEvent("MAIL_SEND_SUCCESS")
    mailRarityWorker:RegisterEvent("MAIL_FAILED")
    mailRarityWorker:RegisterEvent("MAIL_CLOSED")
    if mailRarityWorker._onUpdateFunc then
        mailRarityWorker:SetScript("OnUpdate", mailRarityWorker._onUpdateFunc)
    end
    A.SendNextRarityBatch()
end


--- Static Popups (Moved from FugaziBAGS_VAR.lua)
StaticPopupDialogs["GPH_CONFIRM_MAIL_RARITY"] = {
    text = "Are you sure you want to mail all unprotected %s items to %s?",
    button1 = "Accept",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if Addon and A.StartSendRarityMail then
            A.StartSendRarityMail(data.rarity)
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["GPH_CONFIRM_MAIL_ALL"] = {
    text = "Are you sure you want to mail ALL unprotected items to %s?\n\n(Skips Hearthstone, Quest items, and Protected gear)",
    button1 = "Accept",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if Addon and A.StartSendRarityMail then
            A.StartSendRarityMail(-1)
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

-- Mail Specific Event Triggers for UI updates
local mailEventFrame = CreateFrame("Frame")
mailEventFrame:RegisterEvent("MAIL_SHOW")
mailEventFrame:RegisterEvent("MAIL_CLOSED")
mailEventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
mailEventFrame:SetScript("OnEvent", function(self, event)
    local gphFrame = A.Inventory
    if gphFrame and gphFrame.UpdateGPHProfessionButtons then
        -- Force hide if closed
        if event == "MAIL_CLOSED" then
            A.isLootingMail = false
            if gphFrame.gphMailBtn then
                gphFrame.gphMailBtn:Hide()
            end
        end
        gphFrame:UpdateGPHProfessionButtons()
    end
end)


--- Modular tooltip registration for rarity buttons.
-- This allows the Mail module to add 'Send to Mailbox' when open.
local origGetModularRarityTooltip = A.GetModularRarityTooltip
function A.GetModularRarityTooltip(rarity, tt)
    -- Chain to existing modular tooltips if any (like from Bank)
    if origGetModularRarityTooltip then 
        origGetModularRarityTooltip(rarity, tt) 
    end

    -- Add Mail-specific action if Mailbox is open
    local mf = _G.MailFrame
    if mf and mf:IsShown() then
        tt:AddLine("Shift+RMB: Send Rarity to Mailbox", 0.6, 0.6, 0.6)
    end
end
    
