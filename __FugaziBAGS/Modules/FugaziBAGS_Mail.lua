local addonName, AddonTable = ...
_G["FugaziBAGS"] = _G["FugaziBAGS"] or AddonTable or {}
local Addon = _G["FugaziBAGS"]
local A = Addon

-- Looting Variables
A.isLootingMail = false
local lastMailLootTime = 0
-- "loot" = take attachments/money; "cleanup" = delete emptied mails
local mailLootPhase = "loot"

local MAIL_ICON_INBOX = "Interface\\Icons\\inv_letter_09"
local MAIL_ICON_SEND = "Interface\\Icons\\inv_letter_19"

--- True when mailbox Send tab is active (3.3.5 selectedTab / SendMailFrame fallbacks).
local function IsMailSendTabActive()
    local mf = _G.MailFrame
    if not mf or not mf:IsShown() then return false end
    if mf.selectedTab == 2 then return true end
    -- Fallbacks when selectedTab is stale mid-switch
    if _G.SendMailFrame and _G.SendMailFrame:IsShown() and (not _G.InboxFrame or not _G.InboxFrame:IsShown()) then
        return true
    end
    if _G.SendMailNameEditBox and _G.SendMailNameEditBox:IsVisible() then
        return true
    end
    return false
end

--- Inbox = letter_09, Send = letter_19 (matches historical chrome).
function A.UpdateGPHMailButtonIcon()
    local inv = A.Inventory
    local mailBtn = (inv and inv.gphMailBtn) or _G.FugaziBAGS_MailButton
    if not mailBtn or not mailBtn.icon then return end
    local tex = IsMailSendTabActive() and MAIL_ICON_SEND or MAIL_ICON_INBOX
    if mailBtn._fbagsMailIconTex ~= tex then
        mailBtn._fbagsMailIconTex = tex
        mailBtn.icon:SetTexture(tex)
    end
end

local function HookMailFrameTabsOnce()
    if A._fbagsMailTabsHooked then return end
    A._fbagsMailTabsHooked = true
    local function onTab()
        if A.UpdateGPHMailButtonIcon then A.UpdateGPHMailButtonIcon() end
    end
    for _, name in ipairs({ "MailFrameTab1", "MailFrameTab2" }) do
        local tab = _G[name]
        if tab and tab.HookScript and not tab._fbagsMailIconHook then
            tab._fbagsMailIconHook = true
            tab:HookScript("OnClick", onTab)
        end
    end
    if hooksecurefunc and _G.PanelTemplates_SetTab then
        hooksecurefunc("PanelTemplates_SetTab", function(frame, id)
            if frame == _G.MailFrame then onTab() end
        end)
    end
end

function A.SetupGPHMailButton(mailBtn, f)
    if not mailBtn then return end
    -- Idempotent: Frames creates the chrome; this owns click/loot behavior once.
    if mailBtn._fbagsMailSetup then return end
    mailBtn._fbagsMailSetup = true

    _G.FugaziBAGS_MailButton = mailBtn
    A.gphFrame = f

    local mailIcon = mailBtn.icon
    local mailLootWorker = CreateFrame("Frame", nil, f)
    HookMailFrameTabsOnce()
    if A.UpdateGPHMailButtonIcon then A.UpdateGPHMailButtonIcon() end

    -- 3.3.5: packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem
    local function InboxHeaderMoneyCodHasItem(i)
        local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
        money = money or 0
        cod = cod or 0
        if hasItem == true then
            hasItem = 1
        elseif not hasItem then
            hasItem = 0
        end
        return money, cod, hasItem
    end

    mailBtn:EnableMouse(true)
    mailBtn:SetHitRectInsets(0, 0, 0, 0)
    mailBtn:RegisterForClicks("AnyUp")
    mailLootWorker:SetScript("OnUpdate", function(self, elapsed)
        if not A.isLootingMail then return end
        lastMailLootTime = (lastMailLootTime or 0) + elapsed
        if lastMailLootTime < 0.1 then return end
        lastMailLootTime = 0

        -- Cleanup phase: delete emptied leftover mails (no items, no money, not COD).
        if mailLootPhase == "cleanup" then
            local num = GetInboxNumItems() or 0
            -- Walk high→low so indices stay stable after one delete per tick.
            for i = num, 1, -1 do
                local money, cod, hasItem = InboxHeaderMoneyCodHasItem(i)
                if cod <= 0 and money <= 0 and hasItem <= 0 then
                    if DeleteInboxItem then
                        DeleteInboxItem(i)
                        return
                    end
                end
            end
            print("|cff00ff00[FugaziBAGS]|r Finished looting mail (empties cleaned).")
            A.isLootingMail = false
            mailLootPhase = "loot"
            return
        end

        -- 1. Check free space
        local free = 0
        for bag = 0, 4 do
            free = free + (GetContainerNumFreeSlots(bag) or 0)
        end
        if free <= 1 then
            print("|cffff0000[FugaziBAGS]|r Mail looting stopped: 1 slot remaining.")
            -- Still try to clean empties so the box is not full of husks.
            mailLootPhase = "cleanup"
            return
        end

        local num = GetInboxNumItems()
        for i = 1, num do
            local money, cod, hasItem = InboxHeaderMoneyCodHasItem(i)
            if cod <= 0 then
                if hasItem > 0 then
                    local attachments = 0
                    local maxAtt = (_G.ATTACHMENTS_MAX_RECEIVE or 12)
                    for ai = 1, maxAtt do
                        if GetInboxItem(i, ai) then attachments = attachments + 1 end
                    end
                    if free - attachments >= 1 then
                        AutoLootMailItem(i)
                        return
                    end
                elseif money > 0 then
                    TakeInboxMoney(i)
                    return
                end
            end
        end
        -- Nothing left to take → delete emptied mails.
        mailLootPhase = "cleanup"
    end)

    mailBtn:SetScript("OnClick", function()
        local isSendTab = IsMailSendTabActive()

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
            -- Always confirm Send All; pass search/filter so OnAccept stays filter-aware.
            local searchLower, filterQ = nil, nil
            if A.SnapshotMoveJobFilters then
                searchLower, filterQ = A.SnapshotMoveJobFilters()
            end
            StaticPopup_Show("GPH_CONFIRM_MAIL_ALL", recipient, nil, {
                searchLower = searchLower,
                filterQuality = filterQ,
            })
        else
            if A.isLootingMail then
                A.isLootingMail = false
                mailLootPhase = "loot"
                print("|cffff0000[FugaziBAGS]|r Mail looting cancelled.")
            else
                A.isLootingMail = true
                mailLootPhase = "loot"
                lastMailLootTime = 0
                print("|cff00ff00[FugaziBAGS]|r Starting mail loot...")
            end
        end
    end)

    mailBtn:SetScript("OnEnter", function()
        mailBtn:SetAlpha(1.0)

        local isSendTab = IsMailSendTabActive()
        GameTooltip:SetOwner(mailBtn, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        if isSendTab then
            GameTooltip:AddLine("Send All Items", 0.9, 0.8, 0.4)
            GameTooltip:AddLine("Sends every item in your bags to current recipient.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Skips Hearthstone, Quest, and Protected items.", 1, 0.2, 0.2, true)
            local inv = A.Inventory
            if inv and inv.gphSearchText and inv.gphSearchText ~= "" then
                GameTooltip:AddLine("Respects active search filter", 0.5, 0.85, 1.0, true)
            end
        else
            GameTooltip:AddLine("Get All Mail", 0.9, 0.8, 0.4)
            GameTooltip:AddLine("Quickly loots attachments and money.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Then deletes emptied leftover mails.", 0.6, 0.6, 0.6, true)
            GameTooltip:AddLine("Stops when only 1 bag slot remains.", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
        if mailBtn.gphBtnHover then
            mailBtn.bg:SetTexture(unpack(mailBtn.gphBtnHover))
        elseif f and f.gphBtnHover then
            mailBtn.bg:SetTexture(unpack(f.gphBtnHover))
        else
            mailBtn.bg:SetTexture(0.15, 0.4, 0.2, 0.8)
        end
    end)

    mailBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if mailBtn.gphBtnNormal then
            mailBtn.bg:SetTexture(unpack(mailBtn.gphBtnNormal))
        elseif f and f.gphBtnNormal then
            mailBtn.bg:SetTexture(unpack(f.gphBtnNormal))
        else
            mailBtn.bg:SetTexture(0.1, 0.3, 0.15, 0.4)
        end
        if mailIcon then mailIcon:SetAlpha(0.6) end
    end)

    A.isLootingMail = false
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

    local function countMailAttachments()
        local n = 0
        for i = 1, 12 do
            if GetSendMailItem(i) then n = n + 1 end
        end
        return n
    end

    local attached = 0
    local failedAttach = {}
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
            
            -- Queue was pre-filtered (rarity/category/search); only re-check protect + live quality if job locked a rarity.
            local qualityMatch = (targetRarity == nil) or (targetRarity == -1) or (q == targetRarity)
                or (targetRarity == 4 and q >= 4)

            -- Soulbound / cannot-mail: skip + red flash (list/grid).
            local bound = (A.IsBagItemCurrentlyBound and A.IsBagItemCurrentlyBound(item.bag, item.slot))
                or false
            if bound then
                A.MailRarityIndex = nextIndex
                table.insert(failedAttach, { bag = item.bag, slot = item.slot })
            elseif qualityMatch and not A.RarityIsProtected(itemId, q) then
                A.MailRarityIndex = nextIndex
                local before = countMailAttachments()
                UseContainerItem(item.bag, item.slot)
                local after = countMailAttachments()
                if after > before then
                    attached = attached + 1
                else
                    -- Soulbound / unique / blocked — client refused the attach.
                    table.insert(failedAttach, { bag = item.bag, slot = item.slot })
                end
            else
                -- Not a match/protected: permanently skip it
                A.MailRarityIndex = nextIndex
            end
        else
            -- Item gone: permanently skip it
            A.MailRarityIndex = nextIndex
        end
    end

    if #failedAttach > 0 then
        if A.FlashBagSlotsDenied then
            A.FlashBagSlotsDenied(failedAttach, 3)
        end
        local n = #failedAttach
        local Loc = A.L
        local prefix = (Loc and Loc.ADDON_PRINT_PREFIX) or "|cffff6666[FugaziBAGS]|r "
        local fmt = (Loc and Loc.MSG_SKIPPED_CANNOT_MAIL)
            or "Skipped %d item%s that cannot be mailed (soulbound or blocked)."
        print(prefix .. fmt:format(n, (n == 1 and "" or "s")))
    end

    -- --- PHYSICAL VERIFICATION ---
    local physicallyAttached = countMailAttachments()

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
        if #failedAttach == 0 then
            print("|cff00ff00[FugaziBAGS]|r Mailing finished (No more matches).")
        else
            print("|cff00ff00[FugaziBAGS]|r Mailing finished.")
        end
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


--- Start mailing items by rarity and/or category, respecting search/filter when set.
-- @param rarity number|nil  quality id, -1 = all rarities, nil = category-only / search-only
-- @param opts table|nil     { category, searchLower, filterQuality }
function A.StartSendRarityMail(rarity, opts)
    local recipient = SendMailNameEditBox:GetText()
    if not recipient or recipient == "" then
        print("|cffff0000[FugaziBAGS]|r Please enter a recipient first.")
        return
    end

    opts = opts or {}
    local category = opts.category
    local searchLower = opts.searchLower
    local filterQuality = opts.filterQuality
    if searchLower == nil and A.SnapshotMoveJobFilters then
        local s, f = A.SnapshotMoveJobFilters()
        searchLower = s
        if filterQuality == nil then filterQuality = f end
    elseif searchLower == nil then
        local inv = A.Inventory
        local raw = inv and inv.gphSearchText
        if raw and raw ~= "" then
            searchLower = tostring(raw):lower():match("^%s*(.-)%s*$")
            if searchLower == "" then searchLower = nil end
        end
        if filterQuality == nil and inv then
            filterQuality = A.GetFilterQualities and A.GetFilterQualities(inv) or inv.gphFilterQuality
        end
    end

    -- -1 means "all rarities"; nil means no rarity constraint (category/search job).
    if rarity == nil and not category then
        rarity = -1
    end

    local function qualityOk(q)
        if filterQuality ~= nil then
            if A.QualityPassesFilter then
                return A.QualityPassesFilter(filterQuality, q)
            end
            if type(filterQuality) == "table" then
                if not next(filterQuality) then return true end
                if filterQuality[q] then return true end
                if filterQuality[4] and q >= 4 then return true end
                return false
            end
            if q == filterQuality then return true end
            if filterQuality == 4 and q >= 4 then return true end
            return false
        end
        if rarity == nil or rarity == -1 then return true end
        if q == rarity then return true end
        if rarity == 4 and q >= 4 then return true end
        return false
    end

    wipe(A.MailRarityQueue)
    local skippedBound = {}
    local function isCurrentlyBound(bag, slot)
        if A.IsBagItemCurrentlyBound then
            return A.IsBagItemCurrentlyBound(bag, slot)
        end
        -- Fallback: only treat true soulbound lines (not mere BoE text).
        return A.IsBagItemSoulbound and A.IsBagItemSoulbound(bag, slot)
    end

    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                local name, _, q = A.GetCachedItemInfo(link)
                q = q or 0

                if qualityOk(q) and not A.RarityIsProtected(itemId, q) then
                    local e = {
                        bag = bag,
                        slot = slot,
                        itemId = itemId,
                        link = link,
                        quality = q,
                        name = name or (link:match("%[(.-)%]") or ""),
                    }
                    local catOk = true
                    if category then
                        catOk = (A.GetItemMoveCategory and A.GetItemMoveCategory(itemId, link, q) == category)
                            or (not A.GetItemMoveCategory)
                    end
                    local searchOk = true
                    if searchLower and searchLower ~= "" then
                        if A.Search and A.Search.Matches then
                            searchOk = A.Search.Matches(e, searchLower)
                        else
                            searchOk = (e.name or ""):lower():find(searchLower, 1, true) ~= nil
                        end
                    end
                    if catOk and searchOk then
                        if isCurrentlyBound(bag, slot) then
                            table.insert(skippedBound, { bag = bag, slot = slot })
                        else
                            table.insert(A.MailRarityQueue, { bag = bag, slot = slot })
                        end
                    end
                end
            end
        end
    end

    -- Soulbound matches: red triple-flash on list + grid (no DEL overlay).
    if #skippedBound > 0 then
        if A.FlashBagSlotsDenied then
            A.FlashBagSlotsDenied(skippedBound, 3)
        end
        local n = #skippedBound
        local Loc = A.L
        local prefix = (Loc and Loc.ADDON_PRINT_PREFIX) or "|cffff6666[FugaziBAGS]|r "
        local fmt = (Loc and Loc.MSG_SKIPPED_SOULBOUND_MAIL)
            or "Skipped %d soulbound item%s (cannot mail)."
        print(prefix .. fmt:format(n, (n == 1 and "" or "s")))
    end

    if #A.MailRarityQueue == 0 then
        if #skippedBound > 0 then
            -- Already flashed + explained; nothing mailable left.
            return
        end
        local Loc = A.L
        local msg = (Loc and Loc.MSG_NO_MATCHING_UNPROTECTED) or "No matching unprotected items found."
        if searchLower and searchLower ~= "" then
            local fmt = (Loc and Loc.MSG_NO_MATCHING_SEARCH) or "No matching items for search \"%s\"."
            msg = fmt:format(searchLower)
        elseif category then
            local fmt = (Loc and Loc.MSG_NO_UNPROTECTED_CATEGORY) or "No unprotected items in category \"%s\"."
            msg = fmt:format(tostring(category))
        elseif rarity == -1 then
            msg = "No unprotected items found."
        else
            msg = "No unprotected items of this rarity found."
        end
        print("|cffff0000[FugaziBAGS]|r " .. msg)
        return
    end

    local label = #A.MailRarityQueue .. " items"
    if searchLower and searchLower ~= "" then
        label = label .. " (search)"
    elseif category then
        label = label .. " (" .. tostring(category) .. ")"
    elseif rarity == -1 then
        label = "ALL items (" .. #A.MailRarityQueue .. ")"
    end
    print("|cff00ff00[FugaziBAGS]|r Sending " .. label .. " to " .. recipient)

    A.MailRarityActive = true
    A.MailRarityIndex = 0
    A.MailRarityJobQuality = rarity -- may be nil for category jobs; batch re-checks live slots
    A.MailRarityJobCategory = category
    A.MailRarityJobSearch = searchLower
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
            A.StartSendRarityMail(data.rarity, {
                searchLower = data.searchLower,
                filterQuality = data.filterQuality,
                category = data.category,
            })
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["GPH_CONFIRM_MAIL_ALL"] = {
    text = "Are you sure you want to mail ALL unprotected items to %s?\n\n(Skips Hearthstone, Quest items, and Protected gear. Respects active search.)",
    button1 = "Accept",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if Addon and A.StartSendRarityMail then
            A.StartSendRarityMail(-1, data)
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
    if event == "MAIL_SHOW" then
        HookMailFrameTabsOnce()
        if A.UpdateGPHMailButtonIcon then A.UpdateGPHMailButtonIcon() end
    elseif event == "MAIL_CLOSED" then
        A.isLootingMail = false
        mailLootPhase = "loot"
        if gphFrame and gphFrame.gphMailBtn then
            gphFrame.gphMailBtn:Hide()
            -- Reset to inbox icon for next open
            if gphFrame.gphMailBtn.icon then
                gphFrame.gphMailBtn._fbagsMailIconTex = MAIL_ICON_INBOX
                gphFrame.gphMailBtn.icon:SetTexture(MAIL_ICON_INBOX)
            end
        end
    end
    if gphFrame and gphFrame.UpdateGPHProfessionButtons then
        gphFrame:UpdateGPHProfessionButtons()
    end
    if event ~= "MAIL_CLOSED" and A.UpdateGPHMailButtonIcon then
        A.UpdateGPHMailButtonIcon()
    end
end)

