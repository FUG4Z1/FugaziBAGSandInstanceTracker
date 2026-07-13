local addonName, Addon = ...; Addon = Addon or _G.FugaziBAGS
local A = Addon
A.DB = _G.FugaziBAGSDB
local DB = A.DB
A.deleteClickTime = A.deleteClickTime or {}
A.destroyClickTime = A.destroyClickTime or {}
A.destroyQueue = A.destroyQueue or {}
A.destroyerThrottle = A.destroyerThrottle or 0
A.GPH_DESTROY_DELAY = 0.4
A.destroyerFrame = A.destroyerFrame or nil
A.pendingQuality = A.pendingQuality or {}
A.GPH_SPELL_IDS = { Disenchant = 13262, Prospecting = 31252 }


--- Is spell known by name? (Greedy/Goblin summon.)
function A.IsSpellKnownByName(spellName)
    if not spellName or spellName == "" then return false end
    
    local localizedName = spellName
    local sid = A.GPH_SPELL_IDS[spellName]
    if sid and GetSpellInfo then
        local n = GetSpellInfo(sid)
        if n then localizedName = n end
    end

    local bookType = BOOKTYPE_SPELL or "spell"
    local getNumTabs = GetNumSpellTabs or function() return 0 end
    local getTabInfo = GetSpellTabInfo or function() return nil, nil, 0, 0 end
    local getSpellName = GetSpellBookItemName or GetSpellName

    if not getSpellName then return false end

    local numTabs = getNumTabs()
    for i = 1, numTabs do
        local _, _, offset, numSpells = getTabInfo(i)
        if offset and numSpells then
            for j = 1, numSpells do
                local name = getSpellName(offset + j, bookType)
                if name and (name == localizedName or name:find(localizedName, 1, true)) then return true end
            end
        end
    end
    return false
end


--- Check if an item is a quest item via tooltip scanning.
function A.IsQuestItem(link)
    if not link then return false end
    local tt = A.GetScanTooltip and A.GetScanTooltip()
    if not tt then return false end
    
    tt:SetOwner(UIParent, "ANCHOR_NONE")
    tt:ClearLines()
    tt:SetHyperlink(link)
    
    for i = 1, tt:NumLines() do
        local left = _G[tt:GetName() .. "TextLeft" .. i]
        local text = left and left:GetText()
        if text == "Quest Item" or (ITEM_BIND_QUEST and text == ITEM_BIND_QUEST) then
            tt:Hide()
            return true
        end
    end
    tt:Hide()
    return false
end

--- Calculate total count and vendor value for items of a certain rarity in bags.
--- Respects all safety checks (Protection, Hearthstone, Quest items).
function A.GetRarityDeleteInfo(quality)
    local count, value = 0, 0
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                local _, _, itemQ = A.GetCachedItemInfo(link)
                
                -- Support bucket-style matching if quality targets 4 (Epic+)
                local match = (itemQ == quality) or (quality == 4 and itemQ and itemQ >= 4)
                
                if match then
                    local isProtected = (A.RarityIsProtected and A.RarityIsProtected(itemId, itemQ)) or A.IsQuestItem(link)
                    if not isProtected then
                        local _, itemCount = GetContainerItemInfo(bag, slot)
                        itemCount = itemCount or 1
                        local vPrice = select(11, A.GetCachedItemInfo(link)) or 0
                        count = count + itemCount
                        value = value + (vPrice * itemCount)
                    end
                end
            end
        end
    end
    return count, value
end


--- Cancel "delete all of this quality" flow (like Esc).
function A.CancelRarityDel(q)
    A.rarityDelStage = A.rarityDelStage or {}
    A.pendingQuality = A.pendingQuality or {}
    A.rarityDelStage[q] = nil
    A.pendingQuality[q] = nil
    local gf = A.Inventory
    if gf and gf.gphEscCatcher then
        gf.gphEscCatcher:ClearFocus()
        gf.gphEscCatcher:Hide()
    end
end



if not A.StartContinuousDelete then
    A.StartContinuousDelete = function(q)
        A.continuousDelActive = A.continuousDelActive or {}
        A.continuousDelActive[q] = true

        -- 1. Get the worker (from the briefcase or make a new one)
        local w = A.ContinuousDeleteWorker
        if not w then
            w = CreateFrame("Frame")
            w:Hide()
            w._t = 0
            w:SetScript("OnUpdate", function(self, elapsed)
                self._t = self._t + elapsed
                if self._t >= 0.5 then
                    self._t = 0
                    local activeTable = A.continuousDelActive or {}
                    local hasActive = false
                    for k, v in pairs(activeTable) do if v then hasActive = true; break end end
                    if not hasActive then self:Hide(); return end
                    
                    local deletedOne = false
                    for bag = 0, 4 do
                        for slot = 1, (GetContainerNumSlots(bag) or 0) do
                            local link = GetContainerItemLink(bag, slot)
                            if link then
                                local _, _, itemQ = A.GetCachedItemInfo(link)
                                local match = false
                                for qTarget, isActive in pairs(activeTable) do
                                    if isActive and ((qTarget == 4 and itemQ and itemQ >= 4) or (itemQ == qTarget)) then
                                        match = true
                                        break
                                    end
                                end
                                if match then
                                    local itemId = tonumber(link:match("item:(%d+)"))
                                    if itemId then
                                        -- ADDED 'A.' HERE TO FIX RED TEXT
                                        local isProtected = (A.RarityIsProtected and A.RarityIsProtected(itemId, itemQ)) or A.IsQuestItem(link)
                                        if not isProtected then
                                            local count = 1
                                            if GetContainerItemInfo then
                                                local _, itemCount = GetContainerItemInfo(bag, slot)
                                                if itemCount and itemCount > 0 then count = itemCount end
                                            end
                                            local vendorCopper = 0
                                            if GetItemInfo then
                                                local sellPrice = select(11, A.GetCachedItemInfo(link or itemId))
                                                if sellPrice and sellPrice > 0 then vendorCopper = sellPrice * count end
                                            end

                                            PickupContainerItem(bag, slot)
                                            if CursorHasItem() then
                                                if _G.FugaziInstanceTracker_OnAutoDelete then
                                                    _G.FugaziInstanceTracker_OnAutoDelete(itemId, count, vendorCopper)
                                                end
                                                DeleteCursorItem()
                                                deletedOne = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        if deletedOne then break end
                    end
                end
            end)
            A.ContinuousDeleteWorker = w
        end

        -- 2. Start the worker
        w._t = 0
        w:Show()

        local inv = A.Inventory
        if inv then inv._refreshImmediate = true end
        if RefreshGPHUI then RefreshGPHUI() end
    end
end

--- Delete every item of one quality from bags (e.g. all grey).
function A.DeleteAllOfQuality(quality)
    local deletedCount = 0
    local labels = { [0] = "Grey", [1] = "White", [2] = "Green", [3] = "Blue", [4] = "Epic", [5] = "Legendary" }
    local label = labels[quality] or "Unknown"

    for bag = 0, 4 do
        for slot = GetContainerNumSlots(bag), 1, -1 do  
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                local _, _, itemQuality = A.GetCachedItemInfo(link)
                if itemQuality == quality then
                    
                    local skip = (itemId and A.GetGphProtectedSet and A.GetGphProtectedSet()[itemId]) or false

                    
                    if quality == 1 then
                        local skipThis = (itemId == A.HEARTHSTONE_ID) or A.IsQuestItem(link)
                        if skipThis then skip = true end
                    end

                    if not skip then
                        local _, stackCount = GetContainerItemInfo(bag, slot)
                        stackCount = stackCount or 1
                        local vendorCopper = 0
                        if GetItemInfo then
                            local v = select(11, A.GetCachedItemInfo(link))
                            if v and v > 0 then vendorCopper = v * stackCount end
                        end
                        PickupContainerItem(bag, slot)
                        if CursorHasItem and CursorHasItem() then
                            A.RecordAutodeleteForFIT(itemId, stackCount, vendorCopper)
                            DeleteCursorItem()
                        end
                        deletedCount = deletedCount + stackCount
                    end
                end
            end
        end
    end

    if deletedCount > 0 then
        A.AddonPrint(
            "[InstanceTracker] Deleted " .. deletedCount .. " " .. label .. " items."
        )
    end
end

--- Record auto-deleted item for FIT stats (vendor value).
function A.RecordAutodeleteForFIT(itemId, count, vendorCopper)
    if not itemId or not count or count <= 0 then return end
    vendorCopper = vendorCopper or 0
    if _G.FugaziInstanceTracker_OnAutoDelete then
        _G.FugaziInstanceTracker_OnAutoDelete(itemId, count, vendorCopper)
    end
end

--- Delete up to amount of itemId from bags.
function A.DeleteGPHItem(itemId, amount)
    if not itemId or amount <= 0 then return end
    local remaining = amount
    for bag = 0, 4 do
        if remaining <= 0 then break end
        for slot = 1, GetContainerNumSlots(bag) do
            if remaining <= 0 then break end
            local currentId = GetContainerItemID(bag, slot)
            if currentId == itemId then
                local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                local _, stackCount = GetContainerItemInfo(bag, slot)
                if stackCount and stackCount > 0 then
                    local deleteAmt = math.min(stackCount, remaining)
                    local vendorCopper = 0
                    if GetItemInfo then
                        local v = select(11, A.GetCachedItemInfo(link or itemId))
                        if v and v > 0 then vendorCopper = v * deleteAmt end
                    end
                    PickupContainerItem(bag, slot)
                    if deleteAmt < stackCount and SplitContainerItem then
                        SplitContainerItem(bag, slot, stackCount - deleteAmt)
                    end
                    if CursorHasItem and CursorHasItem() then
                        A.RecordAutodeleteForFIT(itemId, deleteAmt, vendorCopper)
                        DeleteCursorItem()
                    end
                    remaining = remaining - deleteAmt
                end
            end
        end
    end
end

--- Delete one bag slot (pickup + delete item).
function A.DeleteGPHSlot(bag, slot)
    if bag == nil or slot == nil then return end
    if not (PickupContainerItem and DeleteCursorItem) then return end
    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
    local itemId = link and tonumber(link:match("item:(%d+)"))
    local count = 1
    if GetContainerItemInfo then
        local _, c = GetContainerItemInfo(bag, slot)
        if c and c > 0 then count = c end
    end
    local vendorCopper = 0
    if link then
        local v = select(11, A.GetCachedItemInfo(link))
        if v and v > 0 then vendorCopper = v * count end
    end
    PickupContainerItem(bag, slot)
    if CursorHasItem and CursorHasItem() then
        A.RecordAutodeleteForFIT(itemId, count, vendorCopper)
        DeleteCursorItem()
    end
end


--- Get required level + item level for destroy check (tooltip scan).
local function GetRequiredAndItemLevelForDestroy(bag, slot)
    local tt = A.GetScanTooltip and A.GetScanTooltip()
    if not tt then return 0, 0 end
    tt:ClearLines()
    tt:SetBagItem(bag, slot)
    local reqLevel, itemLevel = 0, 0
    local n = tt:NumLines() or 0
    local name = tt:GetName()
    for i = 1, n do
        local left = _G[name .. "TextLeft" .. i]
        local text = left and left:GetText()
        if text then
            local r = text:match("Requires Level%s+(%d+)")
            if r then reqLevel = tonumber(r) or reqLevel end
            local l = text:match("Item Level%s+(%d+)")
            if l then itemLevel = tonumber(l) or itemLevel end
        end
    end
    return reqLevel, itemLevel
end
A.GetRequiredAndItemLevelForDestroy = GetRequiredAndItemLevelForDestroy

--- Can we destroy this slot? (level, soulbound, protected, no cooldown.)
local function GPHIsDestroyable(bag, slot, link)
    if not link then return nil end
    local itemId = tonumber(link:match("item:(%d+)"))
    if itemId == A.HEARTHSTONE_ID then return nil end  

    local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    
    local name, _, quality, _, _, itemType, itemSubType = A.GetCachedItemInfo(link)
    if not name then return nil end

    if hasDE and bag and slot then
        local okByAPI = (itemType == "Armor" or itemType == "Weapon") and quality and quality >= 2 and quality <= 4
        if okByAPI then
            return GetSpellInfo(A.GPH_SPELL_IDS and A.GPH_SPELL_IDS.Disenchant or 13262) or "Disenchant"
        end
    end

    if hasProspect and bag and slot then
        if itemType == "Trade Goods" and itemSubType == "Metal & Stone" and name:find("Ore") then
            return GetSpellInfo(A.GPH_SPELL_IDS and A.GPH_SPELL_IDS.Prospecting or 5149) or "Prospecting"
        end
    end
    return nil
end
A.GPHIsDestroyable = GPHIsDestroyable

--- First destroyable item in bags (for continuous delete; optional prospect priority).
local function GetFirstDestroyableInBags(preferProspect)
    local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    local list = {}
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                if link then
                    local spell = GPHIsDestroyable(bag, slot, link)
                    if spell then
                        local itemId = tonumber(link:match("item:(%d+)"))
                        local name, _, quality, iLevel, reqLevel = A.GetCachedItemInfo(link)
                        quality = quality or 0
                        if itemId and A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, quality) then
                        else
                            table.insert(list, {
                                bag = bag,
                                slot = slot,
                                spell = spell,
                                isDE = spell:find("Disenchant", 1, true),
                                quality = quality,
                                reqLevel = reqLevel or 0,
                                iLevel = iLevel or 0,
                                link = link,
                            })
                        end
                    end
                end
            end
        end
    end
    if #list == 0 then return nil end
    
    table.sort(list, function(a, b)
        local ar, br = a.reqLevel or 0, b.reqLevel or 0
        if ar ~= br then return ar < br end
        local ai, bi = a.iLevel or 0, b.iLevel or 0
        return ai < bi
    end)
    local function pick(deFirst)
        for i = 1, #list do
            local e = list[i]
            if deFirst and e.isDE then return e.bag, e.slot, e.spell, e.link end
            if not deFirst and not e.isDE then return e.bag, e.slot, e.spell, e.link end
        end
        return nil
    end
    if preferProspect and hasProspect then
        local b, s, sp, link = pick(false)
        if b then return b, s, sp, link end
    end
    if hasDE then
        local b, s, sp, link = pick(true)
        if b then return b, s, sp, link end
    end
    if hasProspect and not preferProspect then
        local b, s, sp, link = pick(false)
        if b then return b, s, sp, link end
    end
    return nil
end
A.GetFirstDestroyableInBags = GetFirstDestroyableInBags



--- Create/reuse destroy worker frame (ticks destroy queue).
function A.EnsureGPHDestroyerFrame()
    if A.destroyerFrame then return end
    A.destroyerFrame = CreateFrame("Frame")
    if A.Inventory then A.Inventory.destroyerFrame = A.destroyerFrame end
    A.destroyerFrame:Hide()
    A.destroyerFrame:SetScript("OnUpdate", function(self, elapsed)
        if #A.destroyQueue == 0 then self:Hide(); return end
        A.destroyerThrottle = A.destroyerThrottle + elapsed
        if A.destroyerThrottle >= A.GPH_DESTROY_DELAY then
            A.destroyerThrottle = 0
            local entry = table.remove(A.destroyQueue, 1)
            -- if entry and entry.itemId then
            --    A.AddonPrint("Destroyer: Processing itemId " .. tostring(entry.itemId) .. " at " .. tostring(entry.bag) .. "," .. tostring(entry.slot))
            -- end
            if entry and entry.bag and entry.slot then
                local currentId = GetContainerItemID and GetContainerItemID(entry.bag, entry.slot)
                if not currentId and GetContainerItemLink then
                    local link = GetContainerItemLink(entry.bag, entry.slot)
                    currentId = link and tonumber(link:match("item:(%d+)"))
                end
                
                -- Only proceed if the item ID still matches the one we queued
                if currentId and currentId == entry.itemId then
                    local link = GetContainerItemLink and GetContainerItemLink(entry.bag, entry.slot)
                    local itemId = entry.itemId
                    local count = 1
                    if GetContainerItemInfo then
                        local _, c = GetContainerItemInfo(entry.bag, entry.slot)
                        if c and c > 0 then count = c end
                    end
                    local vendorCopper = 0
                    if link then
                        local v = select(11, A.GetCachedItemInfo(link))
                        if v and v > 0 then vendorCopper = v * count end
                    end
                    PickupContainerItem(entry.bag, entry.slot)
                    if CursorHasItem and CursorHasItem() then
                        A.RecordAutodeleteForFIT(itemId, count, vendorCopper)
                        if DeleteCursorItem then DeleteCursorItem() end
                        if A.PlaySwooshSound then A.PlaySwooshSound() end
                    end
                elseif currentId then
                    -- Item moved or slot changed, re-scan to find it
                    if A.ScanBagsForDestruction then A.ScanBagsForDestruction() end
                end
            end
            if #A.destroyQueue == 0 then self:Hide() end
        end
    end)
end

--- Add bag slots for item to destroy queue (auto-delete).
function A.QueueDestroySlotsForItemId(itemId)
    if not itemId then return end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local id = GetContainerItemID and GetContainerItemID(bag, slot)
                if not id and GetContainerItemLink then
                    local link = GetContainerItemLink(bag, slot)
                    if link then id = tonumber(link:match('item:(%d+)')) end
                end
                if id == itemId then
                    A.destroyQueue[#A.destroyQueue + 1] = { itemId = itemId, bag = bag, slot = slot }
                end
            end
        end
    end
    if #A.destroyQueue > 0 then
        if A.EnsureGPHDestroyerFrame then A.EnsureGPHDestroyerFrame() end
        if A.destroyerFrame then A.destroyerFrame:Show() end
    end
end


StaticPopupDialogs['FUGAZI_DISENCHANT_EPIC'] = {
    text = 'Disenchant Epic/Legendary item?',
    button1 = 'Disenchant',
    button2 = 'Cancel',
    OnAccept = function(self)
        local bag, slot = self.data and self.data.bag, self.data and self.data.slot
        if bag and slot then
            CastSpellByName('Disenchant')
            if SpellTargetItem then SpellTargetItem(bag, slot) end
            local inv = A.Inventory
            if inv and _G.RefreshGPHUI then _G.RefreshGPHUI() end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

--- Scan all bags for items on the autodelete list and queue them for destruction.
function A.ScanBagsForDestruction()
    local list = A.GetGphDestroyList and A.GetGphDestroyList() or {}
    if not list then return end
    
    wipe(A.destroyQueue)
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local id = GetContainerItemID and GetContainerItemID(bag, slot)
                if not id and GetContainerItemLink then
                    local link = GetContainerItemLink(bag, slot)
                    if link then id = tonumber(link:match("item:(%d+)")) end
                end
                if id and list[id] then
                    -- A.AddonPrint("Autodelete MATCH: item " .. tostring(id) .. " at " .. tostring(bag) .. "," .. tostring(slot))
                    A.destroyQueue[#A.destroyQueue + 1] = { itemId = id, bag = bag, slot = slot }
                end
            end
        end
    end
    
    if #A.destroyQueue > 0 then
        -- A.AddonPrint("ScanBagsForDestruction: Queued " .. #A.destroyQueue .. " items.")
        A.EnsureGPHDestroyerFrame()
        if A.destroyerFrame then A.destroyerFrame:Show() end
    end
end

local lootHandler = CreateFrame("Frame")
lootHandler:RegisterEvent("LOOT_OPENED")
lootHandler:RegisterEvent("LOOT_CLOSED")
lootHandler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
lootHandler:RegisterEvent("UNIT_SPELLCAST_FAILED")
lootHandler:SetScript("OnEvent", function(self, event, ...)
    if event == "LOOT_OPENED" then
        if A.isDisenchanting then
            if _G.LootFrame then _G.LootFrame:Hide() end
            for i = 1, GetNumLootItems() do
                LootSlot(i)
            end
            CloseLoot()
        end
    elseif event == "LOOT_CLOSED" then
        A.isDisenchanting = nil
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local unit, spellName = ...
        if unit == "player" then
            local de = GetSpellInfo(13262) or "Disenchant"
            local pr = GetSpellInfo(31252) or "Prospecting"
            if spellName == de or spellName == pr then
                A.isDisenchanting = nil
            end
        end
    end
end)
