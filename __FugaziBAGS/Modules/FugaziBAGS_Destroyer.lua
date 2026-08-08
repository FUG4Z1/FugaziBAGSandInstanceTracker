local addonName, Addon = ...
-- Always write APIs onto the same table Frames/Core use (_G.FugaziBAGS).
if Addon and _G.FugaziBAGS and Addon ~= _G.FugaziBAGS then
    for k, v in pairs(_G.FugaziBAGS) do
        if Addon[k] == nil then Addon[k] = v end
    end
    _G.FugaziBAGS = Addon
end
local A = _G.FugaziBAGS or Addon
A.DB = _G.FugaziBAGSDB
local DB = A.DB
A.destroyQueue = A.destroyQueue or {}
A.destroyerThrottle = A.destroyerThrottle or 0
A.GPH_DESTROY_DELAY = 0.4
A.destroyerFrame = A.destroyerFrame or nil
A.pendingQuality = A.pendingQuality or {}
A.GPH_SPELL_IDS = { Disenchant = 13262, Prospecting = 31252, Milling = 51005 }


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

--- True if destroy list has at least one entry (avoids full bag scans when unused).
function A.DestroyListHasEntries(list)
    list = list or (A.GetGphDestroyList and A.GetGphDestroyList())
    if not list then return false end
    for _ in pairs(list) do return true end
    return false
end

--- Shared gate for burst / continuous / list autodelete.
--- Always respects full protection (manual, worn ledger, rarity-wide), hearth, quest.
--- Never pass ignoreRarity=true here — that is bank UI only.
--- @return boolean skip true = do not delete
function A.ShouldSkipAutoDelete(itemId, quality, link)
    if not itemId then return true end
    itemId = tonumber(itemId)
    if not itemId then return true end
    if itemId == A.HEARTHSTONE_ID then return true end

    local q = quality
    if q == nil and link and A.GetCachedItemInfo then
        local _, _, qq = A.GetCachedItemInfo(link)
        q = qq
    end

    -- Full protect: ignoreRarity must stay false/nil so rarity flags apply.
    if A.IsItemProtectedAPI and A.IsItemProtectedAPI(itemId, q, false) then
        return true
    end
    if A.RarityIsProtected and not A.IsItemProtectedAPI and A.RarityIsProtected(itemId, q) then
        return true
    end
    if link and A.IsQuestItem and A.IsQuestItem(link) then
        return true
    end
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
                
                if match and not A.ShouldSkipAutoDelete(itemId, itemQ, link) then
                    local _, itemCount = GetContainerItemInfo(bag, slot)
                    itemCount = itemCount or 1
                    local vPrice = select(11, A.GetCachedItemInfo(link)) or 0
                    count = count + itemCount
                    value = value + (vPrice * itemCount)
                end
            end
        end
    end
    return count, value
end

--- True while continuous delete is armed for any quality.
function A.IsContinuousDeleteActive()
    local t = A.continuousDelActive
    if not t then return false end
    for _, v in pairs(t) do if v then return true end end
    return false
end

--- Bag contents changed: wake continuous worker (event-driven, not 0.5s poll).
function A.NotifyContinuousDeleteBagsDirty()
    if not A.IsContinuousDeleteActive or not A.IsContinuousDeleteActive() then return end
    local w = A.ContinuousDeleteWorker
    if not w then return end
    w._bagsDirty = true
    w:Show()
end

--- Find one deletable slot matching active continuous qualities (or fixed quality).
--- Called only when bags are dirty / continuous is draining — not on a timer.
local function FindNextQualityDeleteSlot(qualityOrNil)
    for bag = 0, 4 do
        for slot = 1, (GetContainerNumSlots(bag) or 0) do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                local _, _, itemQ = A.GetCachedItemInfo(link)
                local match = false
                if qualityOrNil ~= nil then
                    match = (itemQ == qualityOrNil) or (qualityOrNil == 4 and itemQ and itemQ >= 4)
                else
                    local activeTable = A.continuousDelActive or {}
                    for qTarget, isActive in pairs(activeTable) do
                        if isActive and ((qTarget == 4 and itemQ and itemQ >= 4) or (itemQ == qTarget)) then
                            match = true
                            break
                        end
                    end
                end
                if match and itemId and not A.ShouldSkipAutoDelete(itemId, itemQ, link) then
                    return bag, slot, itemId, itemQ, link
                end
            end
        end
    end
    return nil
end

local function DeleteSlotNow(bag, slot, itemId, link)
    local count = 1
    if GetContainerItemInfo then
        local _, itemCount = GetContainerItemInfo(bag, slot)
        if itemCount and itemCount > 0 then count = itemCount end
    end
    local vendorCopper = 0
    local sellPrice = select(11, A.GetCachedItemInfo(link or itemId))
    if sellPrice and sellPrice > 0 then vendorCopper = sellPrice * count end
    PickupContainerItem(bag, slot)
    if CursorHasItem and CursorHasItem() then
        A.RecordAutodeleteForFIT(itemId, count, vendorCopper)
        DeleteCursorItem()
        return count
    end
    return 0
end

--- Continuous: delete matching quality as loot lands (event-driven bag dirty, not idle poll).
function A.StartContinuousDelete(q)
    if A.pendingQuality then A.pendingQuality[q] = nil end
    if A.continuousDelStage then A.continuousDelStage[q] = nil end
    A.continuousDelActive = A.continuousDelActive or {}
    A.continuousDelActive[q] = true

    local w = A.ContinuousDeleteWorker
    if not w then
        w = CreateFrame("Frame")
        w:Hide()
        w._t = 0
        w._bagsDirty = false
        w:SetScript("OnUpdate", function(self, elapsed)
            if not A.IsContinuousDeleteActive or not A.IsContinuousDeleteActive() then
                self:Hide()
                return
            end
            if CursorHasItem and CursorHasItem() then return end
            -- Idle: no bag change since last pass → sleep (no full bag walk).
            if not self._bagsDirty then return end

            self._t = (self._t or 0) + elapsed
            if self._t < 0.15 then return end
            self._t = 0
            self._bagsDirty = false

            local bag, slot, itemId, _, link = FindNextQualityDeleteSlot(nil)
            if bag then
                if DeleteSlotNow(bag, slot, itemId, link) > 0 then
                    -- Next BAG_UPDATE will re-arm; also nudge in case event is late.
                    self._bagsDirty = true
                end
            end
            -- No match: stay shown but quiet until next NotifyContinuousDeleteBagsDirty.
        end)
        A.ContinuousDeleteWorker = w
    end

    w._t = 0
    w._bagsDirty = true -- one immediate pass on enable
    w:Show()

    local inv = A.Inventory
    if inv then inv._refreshImmediate = true end
    if RefreshGPHUI then RefreshGPHUI() end
end

--- Delete every item of one quality from bags. Build queue once, process like list autodelete.
function A.DeleteAllOfQuality(quality)
    if A.pendingQuality then A.pendingQuality[quality] = nil end
    if A.rarityDelStage then A.rarityDelStage[quality] = nil end
    local labels = { [0] = "Grey", [1] = "White", [2] = "Green", [3] = "Blue", [4] = "Epic", [5] = "Legendary" }
    local label = labels[quality] or "Unknown"

    if not A.BurstDeleteWorker then
        A.BurstDeleteWorker = CreateFrame("Frame")
        A.BurstDeleteWorker:Hide()
        A.BurstDeleteWorker.queue = {}
        A.BurstDeleteWorker:SetScript("OnUpdate", function(self, elapsed)
            self._t = (self._t or 0) + elapsed
            if self._t <= 0.1 then return end
            self._t = 0
            if CursorHasItem and CursorHasItem() then return end

            local q = self.queue
            while q and #q > 0 do
                local entry = table.remove(q, 1)
                if entry and entry.bag and entry.slot then
                    local link = GetContainerItemLink(entry.bag, entry.slot)
                    local id = GetContainerItemID and GetContainerItemID(entry.bag, entry.slot)
                    if not id and link then id = tonumber(link:match("item:(%d+)")) end
                    if id and id == entry.itemId and link then
                        local _, _, itemQ = A.GetCachedItemInfo(link)
                        if not A.ShouldSkipAutoDelete(id, itemQ, link) then
                            local n = DeleteSlotNow(entry.bag, entry.slot, id, link)
                            if n > 0 then
                                self.deletedCount = (self.deletedCount or 0) + n
                                return -- one per tick
                            end
                        end
                    end
                end
            end

            -- Queue empty
            self:Hide()
            if A.pendingQuality then A.pendingQuality[self.quality] = nil end
            if (self.deletedCount or 0) > 0 then
                A.AddonPrint("[InstanceTracker] Deleted " .. self.deletedCount .. " " .. (self.label or "Unknown") .. " items.")
            end
            local inv = A.Inventory
            if inv then inv._refreshImmediate = true end
            if A.RefreshGPHUI then A.RefreshGPHUI() end
        end)
    end

    -- One full scan to build the work list (not re-scan every 0.1s).
    local queue = A.BurstDeleteWorker.queue
    wipe(queue)
    for bag = 0, 4 do
        for slot = (GetContainerNumSlots(bag) or 0), 1, -1 do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                local _, _, itemQuality = A.GetCachedItemInfo(link)
                local match = (itemQuality == quality) or (quality == 4 and itemQuality and itemQuality >= 4)
                if match and itemId and not A.ShouldSkipAutoDelete(itemId, itemQuality, link) then
                    queue[#queue + 1] = { bag = bag, slot = slot, itemId = itemId }
                end
            end
        end
    end

    A.BurstDeleteWorker.quality = quality
    A.BurstDeleteWorker.label = label
    A.BurstDeleteWorker.deletedCount = 0
    A.BurstDeleteWorker._t = 0
    A.BurstDeleteWorker:Show()
    
    local inv = A.Inventory
    if inv then inv._refreshImmediate = true end
    if A.RefreshGPHUI then A.RefreshGPHUI() end
end

--- Record auto-deleted item for FIT stats (vendor value) + live GPH session sinks.
--- Without the GPH side, session stamp left itemsAutodeleted / autodeletedVendorCopper at 0
--- and history rows never got autodeletedDuringSession.
function A.RecordAutodeleteForFIT(itemId, count, vendorCopper)
    if not itemId or not count or count <= 0 then return end
    itemId = tonumber(itemId) or itemId
    count = tonumber(count) or 0
    if count <= 0 then return end
    vendorCopper = tonumber(vendorCopper) or 0

    -- GPH session ledger (wallet gold never includes destroyed junk; this is fate tracking only).
    local sess = _G.gphSession
    if sess then
        sess.autodeletedItemCount = sess.autodeletedItemCount or {}
        sess.autodeletedItemCount[itemId] = (sess.autodeletedItemCount[itemId] or 0) + count
        sess.itemsAutodeleted = (sess.itemsAutodeleted or 0) + count
        sess.autodeletedVendorCopper = (sess.autodeletedVendorCopper or 0) + vendorCopper

        -- Ensure a session row exists even if continuous delete beat the bag-delta scan.
        sess.items = sess.items or {}
        local row = sess.items[itemId]
        if type(row) ~= "table" then
            local link = A.itemLinksCache and A.itemLinksCache[itemId]
            local name, quality, itemLevel
            if link then
                name, _, quality, itemLevel = A.GetCachedItemInfo(link)
            else
                name, link, quality, itemLevel = A.GetCachedItemInfo(itemId)
            end
            if not link and GetItemInfo then
                local n, l, q, il = GetItemInfo(itemId)
                name = name or n
                link = l
                quality = quality or q
                itemLevel = itemLevel or il
            end
            quality = quality or 0
            row = {
                link = link,
                id = itemId,
                quality = quality,
                count = count,
                name = name or ("Item " .. tostring(itemId)),
                iLvl = itemLevel,
                remaining = 0,
            }
            sess.items[itemId] = row
            sess.qualityCounts = sess.qualityCounts or {}
            sess.qualityCounts[quality] = (sess.qualityCounts[quality] or 0) + count
        else
            -- Already seen via bag scan: keep cumulative count at least as large as sinks.
            local have = tonumber(row.count) or 0
            local need = (sess.autodeletedItemCount[itemId] or 0)
                + ((sess.vendoredItemCount and sess.vendoredItemCount[itemId]) or 0)
            if have < need then
                local add = need - have
                row.count = have + add
                local q = row.quality or 0
                sess.qualityCounts = sess.qualityCounts or {}
                sess.qualityCounts[q] = (sess.qualityCounts[q] or 0) + add
            end
            row.remaining = 0
        end
        if A.MarkSessionValueDirty then A.MarkSessionValueDirty() end
    end

    if _G.FugaziInstanceTracker_OnAutoDelete then
        _G.FugaziInstanceTracker_OnAutoDelete(itemId, count, vendorCopper)
    end
end

--- Can we destroy this slot? (level, soulbound, protected, no cooldown.)
local function GPHIsDestroyable(bag, slot, link, optHasDE, optHasProspect, optHasMilling)
    if not link then return nil end
    local itemId = tonumber(link:match("item:(%d+)"))
    if itemId == A.HEARTHSTONE_ID then return nil end  

    local hasDE = optHasDE
    if hasDE == nil then
        hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    end
    local hasProspect = optHasProspect
    if hasProspect == nil then
        hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    end
    local hasMilling = optHasMilling
    if hasMilling == nil then
        hasMilling = A.IsSpellKnownByName and A.IsSpellKnownByName("Milling")
    end
    
    local name, _, quality, _, _, itemType, itemSubType = A.GetCachedItemInfo(link)
    if not name then return nil end

    local Loc = A.L
    local clsWeapon = (Loc and Loc.ITEM_CLASS_WEAPON) or "Weapon"
    local clsArmor = (Loc and Loc.ITEM_CLASS_ARMOR) or "Armor"
    local clsTrade = (Loc and Loc.ITEM_CLASS_TRADE_GOODS) or "Trade Goods"
    local subMetal = (Loc and Loc.ITEM_SUBTYPE_METAL_STONE) or "Metal & Stone"
    local subHerb = (Loc and Loc.ITEM_SUBTYPE_HERB) or "Herb"
    local oreWord = (Loc and Loc.ITEM_NAME_ORE) or "Ore"

    if hasDE and bag and slot then
        local okByAPI = (itemType == clsArmor or itemType == clsWeapon) and quality and quality >= 2 and quality <= 4
        if okByAPI then
            return GetSpellInfo(A.GPH_SPELL_IDS and A.GPH_SPELL_IDS.Disenchant or 13262) or "Disenchant"
        end
    end

    if hasProspect and bag and slot then
        if itemType == clsTrade and itemSubType == subMetal and name:find(oreWord, 1, true) then
            return GetSpellInfo(A.GPH_SPELL_IDS and A.GPH_SPELL_IDS.Prospecting or 31252) or "Prospecting"
        end
    end
    
    if hasMilling and bag and slot then
        if itemType == clsTrade and itemSubType == subHerb then
            return GetSpellInfo(A.GPH_SPELL_IDS and A.GPH_SPELL_IDS.Milling or 51005) or "Milling"
        end
    end
    return nil
end
A.GPHIsDestroyable = GPHIsDestroyable

local cachedBagItems = nil
local cachedList = nil
local cacheDirty = true

function A.DirtyDestroyableCache()
    cacheDirty = true
    cachedBagItems = nil
    cachedList = nil
end

local openScanner
local function IsItemLockedLockbox(bag, slot)
    if not openScanner then
        openScanner = CreateFrame("GameTooltip", "FugaziBAGS_OpenScanner", nil, "GameTooltipTemplate")
        openScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    openScanner:ClearLines()
    openScanner:SetBagItem(bag, slot)
    for i = 1, openScanner:NumLines() do
        local line = _G["FugaziBAGS_OpenScannerTextLeft"..i]
        if line then
            local text = line:GetText()
            if text == _G.LOCKED then
                return true
            end
        end
    end
    return false
end



function A.GetCachedBagItems()
    if cacheDirty or not cachedBagItems then
        cachedBagItems = {}
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
            if numSlots then
                for slot = 1, numSlots do
                    local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                    if link then
                        local itemId = tonumber(link:match("item:(%d+)"))
                        if itemId then
                            local name, _, quality, iLevel, reqLevel, _, _, _, _, _, sellPrice = A.GetCachedItemInfo(link)
                            local texture, itemCount, locked, bagQuality, readable, lootable = GetContainerItemInfo(bag, slot)
                            
                            local isOpenable = A.OpenerList and (A.OpenerList[itemId] or (name and A.OpenerList[name]))
                            local requiresKey = false
                            if isOpenable then
                                requiresKey = IsItemLockedLockbox(bag, slot)
                            end
                            
                            quality = quality or 0
                            sellPrice = sellPrice or 0
                            table.insert(cachedBagItems, {
                                bag = bag,
                                slot = slot,
                                link = link,
                                itemId = itemId,
                                name = name,
                                quality = quality,
                                sellPrice = sellPrice,
                                iLevel = iLevel or 0,
                                reqLevel = reqLevel or 0,
                                texture = texture,
                                locked = locked,
                                lootable = (isOpenable and not requiresKey),
                            })
                        end
                    end
                end
            end
        end
        cacheDirty = false
    end
    return cachedBagItems
end

--- First destroyable item in bags for a specific spell.
local function GetFirstDestroyableInBags(targetSpellName)
    local hasDE = A.IsSpellKnownByName and A.IsSpellKnownByName("Disenchant")
    local hasProspect = A.IsSpellKnownByName and A.IsSpellKnownByName("Prospecting")
    local hasMilling = A.IsSpellKnownByName and A.IsSpellKnownByName("Milling")
    
    if cacheDirty or not cachedList then
        cachedList = {}
        local items = A.GetCachedBagItems()
        local inv = A.Inventory
        local invFilter = inv and (A.GetFilterQualities and A.GetFilterQualities(inv) or inv.gphFilterQuality)
        local searchText = inv and inv.gphSearchText
        local searchLower = searchText and searchText ~= "" and string.lower(searchText) or nil
        for i = 1, #items do
            local e = items[i]
            local passFilter = (not invFilter)
                or (A.QualityPassesFilter and A.QualityPassesFilter(invFilter, e.quality))
                or (not A.QualityPassesFilter and e.quality == invFilter)
            if passFilter then
                if not searchLower or (A.Search and A.Search.Matches(e, searchLower)) then
                    local texture, _, locked = GetContainerItemInfo(e.bag, e.slot)
                    if texture and not locked then
                        local spell = GPHIsDestroyable(e.bag, e.slot, e.link, hasDE, hasProspect, hasMilling)
                        if spell then
                            if not (A.IsItemProtectedAPI and A.IsItemProtectedAPI(e.itemId, e.quality)) then
                                table.insert(cachedList, {
                                    bag = e.bag,
                                    slot = e.slot,
                                    spell = spell,
                                    isDE = spell:find("Disenchant", 1, true),
                                    quality = e.quality,
                                    reqLevel = e.reqLevel,
                                    iLevel = e.iLevel,
                                    link = e.link,
                                    itemId = e.itemId,
                                })
                            end
                        end
                    end
                end
            end
        end
        
        table.sort(cachedList, function(a, b)
            local ar, br = a.reqLevel or 0, b.reqLevel or 0
            if ar ~= br then return ar < br end
            local ai, bi = a.iLevel or 0, b.iLevel or 0
            return ai < bi
        end)
    end
    
    if #cachedList == 0 then return nil end
    
    local now = GetTime()
    local lockedSlots = A.lockedDisenchantSlots
    if not lockedSlots then
        lockedSlots = {}
        A.lockedDisenchantSlots = lockedSlots
    end
    -- Short lock window: long enough to cover cast + bag lag, short enough for spam chain.
    -- Empty slots are always skipped (no texture) even if lock expired.
    for key, lockTime in pairs(lockedSlots) do
        if type(lockTime) ~= "number" or (now - lockTime) > 2.0 then
            lockedSlots[key] = nil
        end
    end
    
    for i = 1, #cachedList do
        local e = cachedList[i]
        if e.spell == targetSpellName then
            local key = e.bag .. "_" .. e.slot
            if not lockedSlots[key] then
                local texture, _, locked = GetContainerItemInfo(e.bag, e.slot)
                if texture and not locked then
                    return e.bag, e.slot, e.spell, e.link
                end
            end
        end
    end
    
    return nil
end
A.GetFirstDestroyableInBags = GetFirstDestroyableInBags

--- Expire DE soft-locks (open/learn does not use these).
local function ExpireSlotLockIfStale(lockedSlots, key, now)
    local lockTime = lockedSlots[key]
    if lockTime and type(lockTime) == "number" and (now - lockTime) > 2.0 then
        lockedSlots[key] = nil
        return nil
    end
    return lockTime
end

--- First openable container in bags (clams, lockboxes, caches).
--- Live bag scan only — do NOT use lockedDisenchantSlots or GetContainerItemInfo "locked".
--- Spam/loot leaves slots client-locked; skipping those hid the Open button while boxes
--- were still in bags. Prefer an unlocked slot for /use when one exists.
function A.GetFirstOpenableInBags()
    local list = A.OpenerList
    if not list then return nil end

    local fb, fs, ftex, flink
    for bag = 0, 4 do
        local n = GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
            if link then
                local itemId = tonumber(link:match("item:(%d+)"))
                if itemId and list[itemId] then
                    local tex, _, locked = GetContainerItemInfo(bag, slot)
                    if tex then
                        if not locked then
                            return bag, slot, tex, link
                        elseif fb == nil then
                            fb, fs, ftex, flink = bag, slot, tex, link
                        end
                    end
                end
            end
        end
    end
    if fb ~= nil then
        return fb, fs, ftex, flink
    end
    return nil
end

--- First learnable recipe in bags (skips already-known / red requirements).
function A.GetFirstLearnableInBags()
    local items = A.GetCachedBagItems()
    if not items then return nil end

    local lockedSlots = A.lockedDisenchantSlots or {}
    A.lockedDisenchantSlots = lockedSlots
    local now = GetTime()
    local best = nil
    local recipeClass = (A.L and A.L.ITEM_CLASS_RECIPE) or "Recipe"
    local canLearn = A.Search and A.Search.CanLearnRecipe

    for i = 1, #items do
        local e = items[i]
        if e.link and not e.locked then
            local _, _, _, _, _, iType = GetItemInfo(e.link)
            if iType == recipeClass and IsUsableItem(e.link)
                and canLearn and canLearn(e.link, e.bag, e.slot) then
                local key = e.bag .. "_" .. e.slot
                if not ExpireSlotLockIfStale(lockedSlots, key, now) then
                    if not best then
                        best = e
                    else
                        local qE = e.quality or 0
                        local qBest = best.quality or 0
                        if qE > qBest or (qE == qBest and (e.name or "") < (best.name or "")) then
                            best = e
                        end
                    end
                end
            end
        end
    end

    if best then
        return best.bag, best.slot, best.texture, best.link
    end
    return nil
end



--- Create/reuse destroy worker frame (ticks destroy queue).
function A.EnsureGPHDestroyerFrame()
    if A.destroyerFrame then return end
    A.destroyerFrame = CreateFrame("Frame")
    if A.Inventory then A.Inventory.destroyerFrame = A.destroyerFrame end
    A.destroyerFrame:Hide()
    A.destroyerFrame:SetScript("OnUpdate", function(self, elapsed)
        if A.DB and A.DB.gphPauseAutodelete then self:Hide(); return end
        if #A.destroyQueue == 0 then self:Hide(); return end
        A.destroyerThrottle = A.destroyerThrottle + elapsed
        if A.destroyerThrottle >= A.GPH_DESTROY_DELAY then
            A.destroyerThrottle = 0
            local entry = table.remove(A.destroyQueue, 1)
            if entry and entry.bag and entry.slot then
                local link = GetContainerItemLink and GetContainerItemLink(entry.bag, entry.slot)
                local currentId = GetContainerItemID and GetContainerItemID(entry.bag, entry.slot)
                if not currentId and link then
                    currentId = tonumber(link:match("item:(%d+)"))
                end
                
                -- Only proceed if the item ID still matches the one we queued
                if currentId and currentId == entry.itemId then
                    local itemId = entry.itemId
                    local _, _, q = A.GetCachedItemInfo and A.GetCachedItemInfo(link or itemId)
                    -- Re-check full protection at fire time (list may lag behind Alt-protect / worn / rarity).
                    if A.ShouldSkipAutoDelete and A.ShouldSkipAutoDelete(itemId, q, link) then
                        -- leave on list for UI, but do not delete this slot
                    else
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

--- Add bag slots for item to destroy queue (auto-delete). Skips protected.
function A.QueueDestroySlotsForItemId(itemId)
    if A.DB and A.DB.gphPauseAutodelete then return end
    if not itemId then return end
    itemId = tonumber(itemId)
    if not itemId then return end
    -- Quality from item info if no link yet
    local _, _, q = A.GetCachedItemInfo and A.GetCachedItemInfo(itemId)
    if A.ShouldSkipAutoDelete and A.ShouldSkipAutoDelete(itemId, q, nil) then
        return
    end
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local id = GetContainerItemID and GetContainerItemID(bag, slot)
                local link = nil
                if not id and GetContainerItemLink then
                    link = GetContainerItemLink(bag, slot)
                    if link then id = tonumber(link:match('item:(%d+)')) end
                end
                if id == itemId then
                    if not link and GetContainerItemLink then
                        link = GetContainerItemLink(bag, slot)
                    end
                    local _, _, sq = A.GetCachedItemInfo and A.GetCachedItemInfo(link or itemId)
                    if not (A.ShouldSkipAutoDelete and A.ShouldSkipAutoDelete(itemId, sq, link)) then
                        A.destroyQueue[#A.destroyQueue + 1] = { itemId = itemId, bag = bag, slot = slot }
                    end
                end
            end
        end
    end
    if #A.destroyQueue > 0 then
        if A.EnsureGPHDestroyerFrame then A.EnsureGPHDestroyerFrame() end
        if A.destroyerFrame then A.destroyerFrame:Show() end
    end
end


--- Scan bags for destroy-list items and queue them. No-op if list empty / paused.
--- Prefers dirty inv bags only when queue already has work (partial); full rebuild when queue empty.
function A.ScanBagsForDestruction()
    if A.DB and A.DB.gphPauseAutodelete then
        if A.destroyQueue then wipe(A.destroyQueue) end
        A._gphIsScanningBagsForDestruction = nil
        return
    end
    local list = A.GetGphDestroyList and A.GetGphDestroyList() or {}
    if not A.DestroyListHasEntries(list) then
        if A.destroyQueue then wipe(A.destroyQueue) end
        if A.destroyerFrame then A.destroyerFrame:Hide() end
        A._gphIsScanningBagsForDestruction = nil
        return
    end

    A.destroyQueue = A.destroyQueue or {}
    local queue = A.destroyQueue

    -- Partial: only re-scan bags marked dirty when we already have a non-empty queue.
    local bags = { 0, 1, 2, 3, 4 }
    local partial = false
    if #queue > 0 and A._gphDirtyBags then
        local d = {}
        for b = 0, 4 do
            if A._gphDirtyBags[b] then d[#d + 1] = b end
        end
        if #d > 0 then
            bags = d
            partial = true
            -- Drop stale entries from dirty bags; keep other bags' queued slots.
            for i = #queue, 1, -1 do
                local e = queue[i]
                if e and A._gphDirtyBags[e.bag] then
                    table.remove(queue, i)
                end
            end
        end
    end
    if not partial then
        wipe(queue)
        bags = { 0, 1, 2, 3, 4 }
    end

    -- Avoid duplicate bag+slot in queue when partial-appending.
    local seen = {}
    if partial then
        for _, e in ipairs(queue) do
            if e and e.bag and e.slot then
                seen[e.bag * 100 + e.slot] = true
            end
        end
    end

    for _, bag in ipairs(bags) do
        local numSlots = GetContainerNumSlots and GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
                local id = GetContainerItemID and GetContainerItemID(bag, slot)
                if not id and link then
                    id = tonumber(link:match("item:(%d+)"))
                end
                if id and list[id] then
                    local key = bag * 100 + slot
                    if not seen[key] then
                        local _, _, q = A.GetCachedItemInfo and A.GetCachedItemInfo(link or id)
                        if not (A.ShouldSkipAutoDelete and A.ShouldSkipAutoDelete(id, q, link)) then
                            queue[#queue + 1] = { itemId = id, bag = bag, slot = slot }
                            seen[key] = true
                        end
                    end
                end
            end
        end
    end
    
    if #queue > 0 then
        A.EnsureGPHDestroyerFrame()
        if A.destroyerFrame then A.destroyerFrame:Show() end
    elseif A.destroyerFrame then
        A.destroyerFrame:Hide()
    end
    A._gphIsScanningBagsForDestruction = nil
end

function A.ClearProcessingState()
    -- Drop the "mid-cast" lock so the next DE/open click can chain immediately.
    -- Do NOT wipe all lockedDisenchantSlots — that let spam re-target the same bag/slot
    -- mid-cast/loot and cancel the cast.
    A.isDisenchanting = nil
    -- Auto-loot still works for the pending LOOT_OPENED even after isDisenchanting clears.
    A._gphPendingDestroyLoot = true

    local finishedKey = nil
    local finishedBag, finishedSlot, finishedId, finishedKind
    if A.activeDisenchantSlot and A.activeDisenchantSlot.bag ~= nil then
        finishedBag = A.activeDisenchantSlot.bag
        finishedSlot = A.activeDisenchantSlot.slot
        finishedId = A.activeDisenchantSlot.itemId
        finishedKind = A.activeDisenchantSlot.kind -- "open" / "learn" / nil (DE/prospect/mill)
        finishedKey = finishedBag .. "_" .. finishedSlot
        -- List dim end: open/learn hard-clear; DE eases target. Grid uses StartSpotlightFade.
        if A.FadeRestoreGPHListRows then
            A.FadeRestoreGPHListRows(finishedBag, finishedSlot, finishedId, finishedKind)
        end
    end
    -- Slot lock policy after success:
    --   Stack still in same slot (open one clam of x2, or partial prospect) → UNLOCK so spam can continue.
    --   Open: unlock finished key (empty loot has no LOOT_OPENED; re-lock stuck the button).
    --   Learn + item still there: already known / failed — mark unlearnable and soft-lock so we move on.
    --   DE/prospect/mill slot empty / item gone → short re-lock so we don't re-target lagging bag data.
    if finishedKey then
        A.lockedDisenchantSlots = A.lockedDisenchantSlots or {}
        local stillSame = false
        local stillLink = nil
        if finishedBag and finishedSlot and finishedId then
            stillLink = GetContainerItemLink and GetContainerItemLink(finishedBag, finishedSlot)
            local curId = stillLink and tonumber(stillLink:match("item:(%d+)"))
            local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(finishedBag, finishedSlot))
            if tex and curId == finishedId then
                stillSame = true
            end
        end
        if finishedKind == "learn" and stillSame then
            if A.Search and A.Search.MarkRecipeUnlearnable and stillLink then
                A.Search.MarkRecipeUnlearnable(stillLink)
            end
            A.lockedDisenchantSlots[finishedKey] = GetTime()
        elseif stillSame or finishedKind == "open" or finishedKind == "learn" then
            A.lockedDisenchantSlots[finishedKey] = nil
        else
            A.lockedDisenchantSlots[finishedKey] = GetTime()
        end
    end
    -- Keep activeDisenchantSlot for end-fade paint; fader clears it when done.
    if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.StartSpotlightFade then
        _G.FugaziBAGS_CombatGrid.StartSpotlightFade(true)
    else
        A.activeDisenchantSlot = nil
        if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.RefreshSlots then
            if A.MarkGridFullRefresh then A.MarkGridFullRefresh() end
            _G.FugaziBAGS_CombatGrid.RefreshSlots(true)
        end
    end
    if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
end

--- True while a destroy cast is in flight (blocks chain-click from canceling it).
function A.IsDestroyCastBusy()
    if UnitCastingInfo and UnitCastingInfo("player") then return true end
    -- Cast-start grace: UnitCastingInfo lags a frame or two after PreClick arms the spell.
    if A.isDisenchanting and A.activeDisenchantSlot and A.activeDisenchantSlot.time then
        local kind = A.activeDisenchantSlot.kind
        local age = GetTime() - A.activeDisenchantSlot.time
        -- Open: instant /use. Learn: 5s cast — once casting, UnitCastingInfo covers it;
        -- short grace only for cast-start lag (was treating learn like open and clearing early).
        if kind == "open" then
            return age < 0.15
        end
        if kind == "learn" then
            return age < 0.40
        end
        if age < 0.40 then
            return true
        end
    end
    return false
end

--- Drop a stuck mid-cast flag without wiping per-slot locks (spam-safe).
function A.ForceClearDestroyProcessing(reason)
    A.isDisenchanting = nil
    A._gphPendingDestroyLoot = true
    if A.FadeRestoreGPHListRows then
        local act = A.activeDisenchantSlot
        A.FadeRestoreGPHListRows(act and act.bag, act and act.slot, act and act.itemId, act and act.kind)
    elseif A.ClearAllGPHListRowDims then
        A.ClearAllGPHListRowDims()
    end
    if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
    if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.StartSpotlightFade then
        _G.FugaziBAGS_CombatGrid.StartSpotlightFade(true)
    end
end

local lootTimerFrame = CreateFrame("Frame")
lootTimerFrame:Hide()

local lootHandler = CreateFrame("Frame")
lootHandler:RegisterEvent("LOOT_OPENED")
lootHandler:RegisterEvent("LOOT_CLOSED")
lootHandler:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
lootHandler:RegisterEvent("UNIT_SPELLCAST_FAILED")
lootHandler:RegisterEvent("UNIT_SPELLCAST_STOP")
lootHandler:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
lootHandler:RegisterEvent("BAG_UPDATE")
lootHandler:SetScript("OnEvent", function(self, event, ...)
    if event == "LOOT_OPENED" then
        -- Auto-loot DE/prospect/mill shards even if the next chain-cast already cleared isDisenchanting.
        if A.isDisenchanting or A._gphPendingDestroyLoot then
            if _G.LootFrame then _G.LootFrame:Hide() end
            if _G.ElvLootFrame then _G.ElvLootFrame:Hide() end
            for i = 1, GetNumLootItems() do
                LootSlot(i)
            end
            CloseLoot()
            local elapsed = 0
            lootTimerFrame:Show()
            lootTimerFrame:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed > 0.1 then
                    if _G.LootFrame then _G.LootFrame:Hide() end
                    if _G.ElvLootFrame then _G.ElvLootFrame:Hide() end
                    CloseLoot()
                    self:SetScript("OnUpdate", nil)
                    self:Hide()
                end
            end)
        end
    elseif event == "BAG_UPDATE" then
        if A.activeDisenchantSlot and A.activeDisenchantSlot.itemId then
            local bag = A.activeDisenchantSlot.bag
            local slot = A.activeDisenchantSlot.slot
            local expectedId = A.activeDisenchantSlot.itemId
            local expectedCount = A.activeDisenchantSlot.count
            local kind = A.activeDisenchantSlot.kind
            
            local link = GetContainerItemLink(bag, slot)
            local currentId = link and tonumber(link:match("item:(%d+)"))
            local _, currentCount = GetContainerItemInfo(bag, slot)
            local casting = UnitCastingInfo and UnitCastingInfo("player")
            
            if currentId ~= expectedId or (expectedCount and currentCount and currentCount < expectedCount) then
                -- Slot changed (item used up / moved). For learn: only end after cast, not mid-cast.
                if kind == "learn" and casting then
                    -- keep dim until UNIT_SPELLCAST_STOP / SUCCEEDED
                else
                    A.ClearProcessingState()
                end
            elseif kind == "open" and A.activeDisenchantSlot.time
                and (GetTime() - A.activeDisenchantSlot.time) > 0.35 then
                -- Open only (instant). Never apply this to learn — that killed the dim at 0.35s of a 5s cast.
                A.ClearProcessingState()
            elseif kind == "learn" and A.activeDisenchantSlot.time
                and (GetTime() - A.activeDisenchantSlot.time) > 0.5 and not casting then
                -- Learn armed but cast never started / already finished without bag delta.
                A.ClearProcessingState()
            end
        elseif A.isDisenchanting then
            -- Core may have already nil'd activeDisenchantSlot; still free the mid-cast flag.
            local casting = UnitCastingInfo and UnitCastingInfo("player")
            if not casting then
                if A.ForceClearDestroyProcessing then
                    A.ForceClearDestroyProcessing("bag_update_stale")
                else
                    A.isDisenchanting = nil
                    A._gphPendingDestroyLoot = true
                end
            end
        end
        -- Drop locks for slots that are empty now (finished DE) so they don't stick around.
        if A.lockedDisenchantSlots then
            local now = GetTime()
            for key, lockTime in pairs(A.lockedDisenchantSlots) do
                local bag, slot = key:match("^(%-?%d+)_(%d+)$")
                bag, slot = tonumber(bag), tonumber(slot)
                if bag and slot then
                    local tex = GetContainerItemInfo and select(1, GetContainerItemInfo(bag, slot))
                    if not tex then
                        A.lockedDisenchantSlots[key] = nil
                    elseif type(lockTime) == "number" and (now - lockTime) > 2.0 then
                        A.lockedDisenchantSlots[key] = nil
                    end
                end
            end
        end
        if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
    elseif event == "LOOT_CLOSED" then
        local act = A.activeDisenchantSlot
        A.isDisenchanting = nil
        A._gphPendingDestroyLoot = nil
        if A.FadeRestoreGPHListRows then
            A.FadeRestoreGPHListRows(act and act.bag, act and act.slot, act and act.itemId, act and act.kind)
        elseif A.ClearAllGPHListRowDims then
            A.ClearAllGPHListRowDims()
        end
        -- Do not wipe all slot locks — next chain click still needs them to avoid re-target.
        if _G.FugaziBAGS_CombatGrid and _G.FugaziBAGS_CombatGrid.StartSpotlightFade then
            _G.FugaziBAGS_CombatGrid.StartSpotlightFade(true)
        end
        if A.DirtyDestroyableCache then A.DirtyDestroyableCache() end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        local unit, spellName = ...
        if unit ~= "player" then return end
        local act = A.activeDisenchantSlot
        local kind = act and act.kind
        local de = GetSpellInfo(13262) or "Disenchant"
        local pr = GetSpellInfo(31252) or "Prospecting"
        local ml = GetSpellInfo(51005) or "Milling"
        local isDestroySpell = (spellName == de or spellName == pr or spellName == ml)
        -- Learn is an item use cast (not DE) — end on stop/success while kind=learn.
        local isLearnEnd = (kind == "learn") and (event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_FAILED")
        if isDestroySpell or isLearnEnd or (A.isDisenchanting and isDestroySpell) then
            local retryKey = nil
            if act and act.bag ~= nil then
                retryKey = act.bag .. "_" .. act.slot
            end
            if A.isDisenchanting or isLearnEnd or isDestroySpell then
                A.ClearProcessingState()
                A._gphPendingDestroyLoot = nil
                if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
                    and retryKey and A.lockedDisenchantSlots then
                    A.lockedDisenchantSlots[retryKey] = nil
                end
            end
        end
    end
end)
