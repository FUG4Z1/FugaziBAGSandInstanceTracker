local addonName, AddonPrivate = ...
local Addon = _G.FugaziBAGS or AddonPrivate
local A = Addon

-- Phase 5: reuse rarity count bucket table (caller consumes immediately).
local _rarityCountsScratch = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }

--- Aggregates total item counts grouped by UI-standard quality buckets (0-4).
function A.GPH_CalculateRarityCounts(itemList)
    local counts = _rarityCountsScratch
    counts[0], counts[1], counts[2], counts[3], counts[4] = 0, 0, 0, 0, 0
    if not itemList then return counts end
    
    for _, item in pairs(itemList) do
        local q = (item.quality ~= nil and item.quality >= 0 and item.quality <= 7) and item.quality or 0
        -- Map rare+ qualities (4-7) to the epic bucket (4) for the filter buttons
        local bucket = (q >= 4) and 4 or q
        local count = item.totalCount or item.count or 1
        counts[bucket] = (counts[bucket] or 0) + count
    end
    return counts
end

--- Unified entry point to update rarity bar visuals from an item list.
function A.GPH_SyncRarityBar(itemList, frame)
    if not (frame and frame.qualityButtons) then return end
    local counts = A.GPH_CalculateRarityCounts(itemList)
    if A.GPH_UpdateRarityBarCounts then
        A.GPH_UpdateRarityBarCounts(frame, counts)
    end
end

local GPH_BagSort_Run
do
	local playerBags = {}
	for i = 0, (NUM_BAG_SLOTS or 4) do playerBags[i + 1] = i end
	local bankBags = {}
	if BANK_CONTAINER ~= nil then
		bankBags[#bankBags + 1] = BANK_CONTAINER
		for i = (NUM_BAG_SLOTS or 4) + 1, (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 6) do bankBags[#bankBags + 1] = i end
	end

	local bagIDs, bagLinks, bagStacks, bagMaxStacks, bagQualities = {}, {}, {}, {}, {}
	local moves, moveTracker = {}, {}
	local bagSorted, initialOrder, bagLocked = {}, {}, {}
	local lastItemID, lockStop, lastDestination, lastMove
	local moveRetries = 0
	local WAIT_TIME = 0.05
	local MAX_MOVE_TIME = 1.25
	local itemTypes, itemSubTypes = {}, {}
	local targetItems, targetSlots, sourceUsed = {}, {}, {}

	local function Encode(bag, slot) return (bag * 100) + slot end
	local function Decode(int) return math.floor(int / 100), int % 100 end
	local function EncodeMove(src, tgt) return (src * 10000) + tgt end
	local function DecodeMove(move)
		local s = math.floor(move / 10000)
		local t = move % 10000
		s = (t > 9000) and (s + 1) or s
		t = (t > 9000) and (t - 10000) or t
		return s, t
	end

	local function GetNumSlots(bag)
		if not GetContainerNumSlots then return 0 end
		return GetContainerNumSlots(bag) or 0
	end

	local function UpdateLocation(from, to)
		if (bagIDs[from] == bagIDs[to]) and (bagStacks[to] and bagMaxStacks[to]) and (bagStacks[to] < bagMaxStacks[to]) then
			local stackSize = bagMaxStacks[to]
			if (bagStacks[to] + (bagStacks[from] or 0)) > stackSize then
				bagStacks[from] = (bagStacks[from] or 0) - (stackSize - bagStacks[to])
				bagStacks[to] = stackSize
			else
				bagStacks[to] = (bagStacks[to] or 0) + (bagStacks[from] or 0)
				bagStacks[from] = nil
				bagIDs[from] = nil
				bagLinks[from] = nil
				bagQualities[from] = nil
				bagMaxStacks[from] = nil
			end
		else
			bagIDs[from], bagIDs[to] = bagIDs[to], bagIDs[from]
			bagLinks[from], bagLinks[to] = bagLinks[to], bagLinks[from]
			bagQualities[from], bagQualities[to] = bagQualities[to], bagQualities[from]
			bagStacks[from], bagStacks[to] = bagStacks[to], bagStacks[from]
			bagMaxStacks[from], bagMaxStacks[to] = bagMaxStacks[to], bagMaxStacks[from]
		end
	end

	local function AddMove(source, destination)
		UpdateLocation(source, destination)
		table.insert(moves, 1, EncodeMove(source, destination))
	end

	
	local function IterFwd(bagList, prev)
		prev = prev + 1
		local step = 0
		for _, bag in ipairs(bagList) do
			local slots = GetNumSlots(bag)
			for slot = 1, slots do
				step = step + 1
				if step == prev then return prev, bag, slot end
			end
		end
		return nil, nil, nil
	end
	local function IterRev(bagList, prev)
		prev = prev + 1
		local total = 0
		for _, bag in ipairs(bagList) do total = total + GetNumSlots(bag) end
		if prev > total then return nil, nil, nil end
		local idx = 0
		for bi = #bagList, 1, -1 do
			local bag = bagList[bi]
			local slots = GetNumSlots(bag)
			for slot = slots, 1, -1 do
				idx = idx + 1
				if idx == prev then return prev, bag, slot end
			end
		end
		return nil, nil, nil
	end
	local function IterateBags(bagList, reverse)
		local bags = bagList or playerBags
		return reverse and IterRev or IterFwd, bags, 0
	end

	
	local currentBagList = playerBags
	local function GPH_BagSort_ScanBags()
		table.wipe(bagIDs)
		table.wipe(bagLinks)
		table.wipe(bagStacks)
		table.wipe(bagMaxStacks)
		table.wipe(bagQualities)
		for _, bag, slot in IterateBags(currentBagList, false) do
			local bagSlot = Encode(bag, slot)
			local itemID = GetContainerItemID and GetContainerItemID(bag, slot)
			local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
			if not itemID then
				if link then itemID = tonumber((link):match("item:(%d+)")) end
			end
			if itemID then
				bagLinks[bagSlot] = link
				local _, _, _, _, _, _, _, maxStack = A.GetCachedItemInfo(link or itemID)
				bagMaxStacks[bagSlot] = (maxStack and maxStack > 0) and maxStack or 1
				bagIDs[bagSlot] = itemID
				local _, count = GetContainerItemInfo(bag, slot)
				bagStacks[bagSlot] = count or 1
				local _, _, quality = A.GetCachedItemInfo(link or itemID)
				bagQualities[bagSlot] = quality
			end
		end
	end

	
	local function Stack()
		for _, bag, slot in IterateBags(currentBagList, false) do
			local bagSlot = Encode(bag, slot)
			local itemID = bagIDs[bagSlot]
			if itemID and (bagStacks[bagSlot] or 0) ~= (bagMaxStacks[bagSlot] or 1) then
				targetItems[itemID] = (targetItems[itemID] or 0) + 1
				table.insert(targetSlots, bagSlot)
			end
		end
		for _, bag, slot in IterateBags(currentBagList, true) do
			local sourceSlot = Encode(bag, slot)
			local itemID = bagIDs[sourceSlot]
			if itemID and targetItems[itemID] then
				for i = #targetSlots, 1, -1 do
					local targetedSlot = targetSlots[i]
					if bagIDs[sourceSlot] and bagIDs[targetedSlot] == itemID and targetedSlot ~= sourceSlot
						and (bagStacks[targetedSlot] or 0) ~= (bagMaxStacks[targetedSlot] or 1) and not sourceUsed[targetedSlot] then
						AddMove(sourceSlot, targetedSlot)
						sourceUsed[sourceSlot] = true
						if (bagStacks[targetedSlot] or 0) == (bagMaxStacks[targetedSlot] or 1) then
							targetItems[itemID] = (targetItems[itemID] or 1) > 1 and (targetItems[itemID] - 1) or nil
						end
						if (bagStacks[sourceSlot] or 0) == 0 then
							targetItems[itemID] = (targetItems[itemID] or 1) > 1 and (targetItems[itemID] - 1) or nil
							break
						end
						if not targetItems[itemID] then break end
					end
				end
			end
		end
		table.wipe(targetItems)
		table.wipe(targetSlots)
		table.wipe(sourceUsed)
	end

	
	local function BuildSortOrder()
		if GetAuctionItemClasses and GetAuctionItemSubClasses then
			local list = {GetAuctionItemClasses()}
			for i, iType in ipairs(list) do
				itemTypes[iType] = i
				itemSubTypes[iType] = {}
				local subList = {GetAuctionItemSubClasses(i)}
				for ii, isType in ipairs(subList) do
					itemSubTypes[iType][isType] = ii
				end
			end
		end
	end

	local function NameTiebreak(a, b)
		local aName = A.GetCachedItemInfo(bagLinks[a] or bagIDs[a])
        local bName = A.GetCachedItemInfo(bagLinks[b] or bagIDs[b])
		if aName and bName and aName ~= bName then return aName < bName end
		return (initialOrder[a] or 0) < (initialOrder[b] or 0)
	end

	
	
	
	local HEARTHSTONE_ID = A.HEARTHSTONE_ID
	local function IsProtectedForSort(itemId, quality)
		local Addon = _G.FugaziBAGS
		if not (Addon and A.IsItemProtectedAPI) then return false end
		return A.IsItemProtectedAPI(itemId, quality)
	end

	local function DefaultSort(a, b)
		local aID, bID = bagIDs[a], bagIDs[b]
        local aLink, bLink = bagLinks[a] or aID, bagLinks[b] or bID
		if (not aID) or (not bID) then return aID ~= nil end
		if aID == bID and aLink == bLink then
			local ac, bc = bagStacks[a] or 0, bagStacks[b] or 0
			if ac == bc then return (initialOrder[a] or 0) < (initialOrder[b] or 0) end
			return ac > bc
		end

		
		if aID == HEARTHSTONE_ID and bID ~= HEARTHSTONE_ID then return true end
		if bID == HEARTHSTONE_ID and aID ~= HEARTHSTONE_ID then return false end

		local DB = _G.FugaziBAGSDB
		local mode = DB and DB.gphSortMode or "category"
		local aRarity, bRarity = bagQualities[a] or 0, bagQualities[b] or 0

		
		local aProt = IsProtectedForSort(aID, aRarity)
		local bProt = IsProtectedForSort(bID, bRarity)
		if aProt ~= bProt then return aProt end

		local aName, _, _, aLvl, _, aType, aSubType, _, _, _, aPrice = A.GetCachedItemInfo(aLink)
		local bName, _, _, bLvl, _, bType, bSubType, _, _, _, bPrice = A.GetCachedItemInfo(bLink)
		
		if mode == "vendor" then
			aPrice = aPrice or 0; bPrice = bPrice or 0
			if aPrice ~= bPrice then return aPrice > bPrice end
			if aRarity ~= bRarity then return aRarity > bRarity end
			return NameTiebreak(a, b)
		elseif mode == "itemlevel" then
			aLvl = aLvl or 0; bLvl = bLvl or 0
			if aLvl ~= bLvl then return aLvl > bLvl end
			if aRarity ~= bRarity then return aRarity > bRarity end
			return NameTiebreak(a, b)
		elseif mode == "category" then
			local at = itemTypes[aType] or 99
			local bt = itemTypes[bType] or 99
			if at ~= bt then return at < bt end
			if aRarity ~= bRarity then return aRarity > bRarity end
            aLvl = aLvl or 0; bLvl = bLvl or 0
            if aLvl ~= bLvl then return aLvl > bLvl end
			local as = (itemSubTypes[aType] and itemSubTypes[aType][aSubType]) or 99
			local bs = (itemSubTypes[bType] and itemSubTypes[bType][bSubType]) or 99
			if as ~= bs then return as < bs end
			return NameTiebreak(a, b)
		end
		
		if aRarity ~= bRarity then return aRarity > bRarity end
		local at = itemTypes[aType] or 99
		local bt = itemTypes[bType] or 99
		if at ~= bt then return at < bt end
		aLvl = aLvl or 0; bLvl = bLvl or 0
		if aLvl ~= bLvl then return aLvl > bLvl end
		local as = (itemSubTypes[aType] and itemSubTypes[aType][aSubType]) or 99
		local bs = (itemSubTypes[bType] and itemSubTypes[bType][bSubType]) or 99
		if as ~= bs then return as < bs end
		return NameTiebreak(a, b)
	end

	local function ShouldMove(source, destination)
		if destination == source then return false end
		if not bagIDs[source] then return false end
		if bagIDs[source] == bagIDs[destination] and bagStacks[source] == bagStacks[destination] then return false end
		return true
	end

	local function UpdateSorted(source, destination)
		for i, bs in pairs(bagSorted) do
			if bs == source then bagSorted[i] = destination
			elseif bs == destination then bagSorted[i] = source end
		end
	end

	
	local function Sort()
		BuildSortOrder()
		table.wipe(initialOrder)
		table.wipe(bagSorted)
		local idx = 0
		for _, bag, slot in IterateBags(currentBagList, false) do
			local bagSlot = Encode(bag, slot)
			if bagIDs[bagSlot] then
				idx = idx + 1
				initialOrder[bagSlot] = idx
				table.insert(bagSorted, bagSlot)
			end
		end
		table.sort(bagSorted, DefaultSort)
		local allSlots = {}
		for _, bag, slot in IterateBags(currentBagList, false) do
			table.insert(allSlots, Encode(bag, slot))
		end
		local passNeeded = true
		while passNeeded do
			passNeeded = false
			for i, source in ipairs(bagSorted) do
				local destination = allSlots[i]
				if destination and source ~= destination then
					if bagIDs[source] then
						if not (bagLocked[source] or bagLocked[destination]) then
							AddMove(source, destination)
							UpdateSorted(source, destination)
							bagLocked[source] = true
							bagLocked[destination] = true
						else
							passNeeded = true
						end
					end
				end
			end
			table.wipe(bagLocked)
		end
		table.wipe(bagSorted)
		table.wipe(initialOrder)
	end

	local function DoMove(move)
		if GetCursorInfo and GetCursorInfo() == "item" then return false, "cursorhasitem" end
		local source, target = DecodeMove(move)
		local sourceBag, sourceSlot = Decode(source)
		local targetBag, targetSlot = Decode(target)
		local _, sourceCount, sourceLocked = GetContainerItemInfo(sourceBag, sourceSlot)
		local _, targetCount, targetLocked = GetContainerItemInfo(targetBag, targetSlot)
		sourceCount = sourceCount or 0
		targetCount = targetCount or 0
		if sourceLocked or targetLocked then return false, "locked" end
		local sourceItemID = GetContainerItemID and GetContainerItemID(sourceBag, sourceSlot)
		if not sourceItemID then
			local link = GetContainerItemLink and GetContainerItemLink(sourceBag, sourceSlot)
			if link then sourceItemID = tonumber((link):match("item:(%d+)")) end
		end
		if not sourceItemID then return false, "noitem" end
		local stackSize = select(8, A.GetCachedItemInfo(sourceItemID)) or 1
		local targetItemID = GetContainerItemID and GetContainerItemID(targetBag, targetSlot)
		if not targetItemID and GetContainerItemLink then
			local link = GetContainerItemLink(targetBag, targetSlot)
			if link then targetItemID = tonumber((link):match("item:(%d+)")) end
		end
		if (sourceItemID == targetItemID) and targetCount and targetCount < stackSize and (targetCount + sourceCount) > stackSize then
			SplitContainerItem(sourceBag, sourceSlot, stackSize - targetCount)
		else
			PickupContainerItem(sourceBag, sourceSlot)
		end
		if GetCursorInfo and GetCursorInfo() == "item" then
			PickupContainerItem(targetBag, targetSlot)
		end
		return true, sourceItemID, source, targetItemID, target
	end

	local onDoneCallback
	local timerFrame = CreateFrame("Frame")
	timerFrame:Hide()
	timerFrame:SetScript("OnUpdate", function(_, elapsed)
		timerFrame._t = (timerFrame._t or 0) + (elapsed or 0.01)
		if timerFrame._t < WAIT_TIME then return end
		timerFrame._t = 0

		if timerFrame._startTime and (GetTime() - timerFrame._startTime > 12) then
			timerFrame:Hide()
			table.wipe(moves)
			table.wipe(moveTracker)
			lastItemID, lockStop, lastDestination, lastMove = nil, nil, nil, nil
			moveRetries = 0
			if onDoneCallback then onDoneCallback() end
			return
		end

		if InCombatLockdown and InCombatLockdown() then
			timerFrame:Hide()
			table.wipe(moves)
			table.wipe(moveTracker)
			if onDoneCallback then onDoneCallback() end
			return
		end

		local cursorType, cursorItemID = GetCursorInfo and GetCursorInfo()
		if cursorType == "item" and cursorItemID then
			if lastItemID ~= cursorItemID then
				timerFrame:Hide()
				table.wipe(moves)
				table.wipe(moveTracker)
				if onDoneCallback then onDoneCallback() end
				return
			end
			if moveRetries < 100 then
				local targetBag, targetSlot = Decode(lastDestination)
				local _, _, targetLocked = GetContainerItemInfo(targetBag, targetSlot)
				if not targetLocked then
					PickupContainerItem(targetBag, targetSlot)
					moveRetries = moveRetries + 1
					return
				end
			end
		end

		if lockStop then
			for slot, itemID in pairs(moveTracker) do
				local sb, ss = Decode(slot)
				local actualID = GetContainerItemID and GetContainerItemID(sb, ss)
				if not actualID and GetContainerItemLink then
					local link = GetContainerItemLink(sb, ss)
					if link then actualID = tonumber((link):match("item:(%d+)")) end
				end
				if actualID ~= itemID then
					if (GetTime() - lockStop) > MAX_MOVE_TIME and lastMove and moveRetries < 100 then
						local ok, moveID, moveSource, targetID, moveTarget = DoMove(lastMove)
						if not ok then
							moveRetries = moveRetries + 1
							return
						end
						moveTracker[moveSource] = targetID
						moveTracker[moveTarget] = moveID
						lastDestination = moveTarget
						lastItemID = moveID
						return
					end
					timerFrame:Hide()
					table.wipe(moves)
					table.wipe(moveTracker)
					lastItemID, lockStop, lastDestination, lastMove = nil, nil, nil, nil
					moveRetries = 0
					if onDoneCallback then onDoneCallback() end
					return
				end
				moveTracker[slot] = nil
			end
		end

		lastItemID, lockStop, lastDestination, lastMove = nil, nil, nil, nil
		table.wipe(moveTracker)

		if #moves > 0 then
			local success, moveID, moveSource, targetID, moveTarget
			local i = #moves
			success, moveID, moveSource, targetID, moveTarget = DoMove(moves[i])
			if not success then
				lockStop = lockStop or GetTime()
				moveRetries = moveRetries + 1
				if (GetTime() - lockStop) > 3.0 or moveRetries > 50 then
					timerFrame:Hide()
					table.wipe(moves)
					table.wipe(moveTracker)
					lastItemID, lockStop, lastDestination, lastMove = nil, nil, nil, nil
					moveRetries = 0
					if onDoneCallback then onDoneCallback() end
				end
				return
			end
			lockStop = nil
			moveRetries = 0
			lastMove = moves[i]
			table.remove(moves, i)
			moveTracker[moveSource] = targetID
			moveTracker[moveTarget] = moveID
			lastDestination = moveTarget
			lastItemID = moveID
			return
		end

		timerFrame:Hide()
		moveRetries = 0
		if onDoneCallback then onDoneCallback() end
	end)

	A.GPH_BagSort_Run = function(callback, bagGroup, optionalBagList)
		if timerFrame:IsShown() then
			if timerFrame._startTime and (GetTime() - timerFrame._startTime < 2.5) then
				return
			end
			timerFrame:Hide()
			table.wipe(moves)
			table.wipe(moveTracker)
			lastItemID, lockStop, lastDestination, lastMove = nil, nil, nil, nil
			moveRetries = 0
		end
		timerFrame._startTime = GetTime()
		if bagGroup == "bank" and optionalBagList and #optionalBagList > 0 then
			currentBagList = optionalBagList
		elseif bagGroup == "bank" and #bankBags > 0 then
			currentBagList = bankBags
		else
			currentBagList = playerBags
		end
		onDoneCallback = callback
		GPH_BagSort_ScanBags()
		Stack()
		Sort()
		lastItemID, lockStop, lastDestination, lastMove = nil, nil, nil, nil
		moveRetries = 0
		table.wipe(moveTracker)
		if #moves > 0 then
			timerFrame._t = 0
			timerFrame:Show()
		else
			if onDoneCallback then onDoneCallback() end
		end
	end
end


--- Sort order for quality (legendary=1, epic=2, ... poor=7).
function A.RaritySortOrder(q)
    if q == 5 then return 7
    elseif q == 7 then return 6
    elseif q == 6 then return 5
    elseif q == 4 then return 4
    else return math.min(q or 0, 3) end
end


--- Sort: empty slots to bottom (like default bag sort).
function A.GPH_EmptyLast(a, b)
    local aEmpty = not a.link
    local bEmpty = not b.link
    if aEmpty ~= bEmpty then return not aEmpty end
    return false
end


--- Sort by quality (legendary > epic > rare > …).
function A.GPH_Sort_Rarity(a, b)
    if A.GPH_EmptyLast(a, b) then return true end
    if A.GPH_EmptyLast(b, a) then return false end
    if (a and a.isProtected) and not (b and b.isProtected) then return true end
    if (b and b.isProtected) and not (a and a.isProtected) then return false end
    local ao, bo = A.RaritySortOrder(a and a.quality), A.RaritySortOrder(b and b.quality)
    if type(ao) == "number" and type(bo) == "number" and ao ~= bo then return ao > bo end
    if a and b and (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
    local an = (a and type(a.name) == "string" and a.name) or ""
    local bn = (b and type(b.name) == "string" and b.name) or ""
    return an < bn
end


--- Sort by vendor price (most gold first).
function A.GPH_Sort_Vendor(a, b)
    if A.GPH_EmptyLast(a, b) then return true end
    if A.GPH_EmptyLast(b, a) then return false end
    if (a and a.isProtected) and not (b and b.isProtected) then return true end
    if (b and b.isProtected) and not (a and a.isProtected) then return false end
    if a and b and a.sellPrice ~= b.sellPrice then return (a.sellPrice or 0) > (b.sellPrice or 0) end
    local ao, bo = A.RaritySortOrder(a and a.quality), A.RaritySortOrder(b and b.quality)
    if type(ao) == "number" and type(bo) == "number" and ao ~= bo then return ao > bo end
    if a and b and (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
    local an = (a and type(a.name) == "string" and a.name) or ""
    local bn = (b and type(b.name) == "string" and b.name) or ""
    return an < bn
end


--- Sort by item level (higher ilvl first).
function A.GPH_Sort_ItemLevel(a, b)
    if A.GPH_EmptyLast(a, b) then return true end
    if A.GPH_EmptyLast(b, a) then return false end
    if (a and a.isProtected) and not (b and b.isProtected) then return true end
    if (b and b.isProtected) and not (a and a.isProtected) then return false end
    if a and b and (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
    local ao, bo = A.RaritySortOrder(a and a.quality), A.RaritySortOrder(b and b.quality)
    if type(ao) == "number" and type(bo) == "number" and ao ~= bo then return ao > bo end
    local an = (a and type(a.name) == "string" and a.name) or ""
    local bn = (b and type(b.name) == "string" and b.name) or ""
    return an < bn
end


--- Sort by category group (destroy list, then protected, then rarity).
function A.GPH_Sort_CategoryGroup(a, b)
    if (a and a.isDestroy) and (b and b.isDestroy) then
        local at, bt = a.addedTime or 0, b.addedTime or 0
        if at ~= bt then return at > bt end
        return (a.name or "") < (b.name or "")
    end
    if (a and a.isProtected) and not (b and b.isProtected) then return true end
    if (b and b.isProtected) and not (a and a.isProtected) then return false end
    local ao, bo = A.RaritySortOrder(a and a.quality), A.RaritySortOrder(b and b.quality)
    if type(ao) == "number" and type(bo) == "number" and ao ~= bo then return ao > bo end
    if a and b and (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
    local an = (a and type(a.name) == "string" and a.name) or ""
    local bn = (b and type(b.name) == "string" and b.name) or ""
    return an < bn
end


local function GetCategoryOrderList()
    if A.GetCategoryOrder then return A.GetCategoryOrder() end
    return { "HIDDEN_FIRST", "Weapon", "Armor", "Container", "Consumable", "Gem", "Trade Goods", "Recipe", "Quest", "Miscellaneous", "Other" }
end

-- Kept for external readers; rebuilt from locale when GetBagProtectedCategoryOrder exists.
local function GetBagProtectedCategoryOrderList()
    if A.GetBagProtectedCategoryOrder then return A.GetBagProtectedCategoryOrder() end
    return { "BAG_PROTECTED", "HIDDEN_FIRST", "Weapon", "Armor", "Container", "Consumable", "Gem", "Trade Goods", "Recipe", "Quest", "Miscellaneous", "Other" }
end
-- Public snapshot (refresh via GetBagProtectedCategoryOrderList when organizing).
A.GPH_BAG_PROTECTED_CATEGORY_ORDER = GetBagProtectedCategoryOrderList()

--- Sort by item type (Weapon, Armor, Consumable, …).
function A.GPH_Sort_CategoryPass(a, b)
    if A.GPH_EmptyLast(a, b) then return true end
    if A.GPH_EmptyLast(b, a) then return false end
    local other = (A.L and A.L.ITEM_CLASS_OTHER) or "Other"
    local at = (a and a.itemType) or other
    local bt = (b and b.itemType) or other
    local order = GetCategoryOrderList()
    local ao, bo = 999, 999
    for i, c in ipairs(order) do if c == at then ao = i; break end end
    for i, c in ipairs(order) do if c == bt then bo = i; break end end
	if ao ~= bo then return ao < bo end
    if a and b and (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
    if a and b and (a.itemLevel or 0) ~= (b.itemLevel or 0) then return (a.itemLevel or 0) > (b.itemLevel or 0) end
    local an = (a and type(a.name) == "string" and a.name) or ""
    local bn = (b and type(b.name) == "string" and b.name) or ""
    return an < bn
end


--- Unified Category Organizer for both Inventory and Bank.
--- poolFunc is kept for API compat but group/divider shells always use the structural
--- pool so item-row tables (with .count) are never wiped while still on the draw list.
function A.OrganizeBagCategories(itemList, frame, sortMode, DB, poolFunc)
    if frame then
        frame.gphCategoryGroups = nil
        frame.gphCategoryItemList = nil
        frame.gphCategoryDrawList = nil
    end
    local isBank = frame and frame._isBankFrame
    local structPool
    if A.GetRecycledStructTable then
        structPool = function() return A.GetRecycledStructTable(isBank) end
    else
        structPool = poolFunc or A.GetRecycledInventoryTable
    end
    local destroyList = A.GetGphDestroyList and A.GetGphDestroyList() or {}
    if sortMode == "category" and #itemList > 0 and GetItemInfo then
        -- Ensure SV type-cache table exists (ResolveItemCategory self-heals stale entries).
        if type(DB.gphItemTypeCache) ~= "table" then
            DB.gphItemTypeCache = {}
        end

        for _, item in ipairs(itemList) do
            local itemId = item.itemId or (item.link and tonumber(item.link:match("item:(%d+)")))
            local isQuest = false
            if A.IsQuestItem and item.link and A.IsQuestItem(item.link) then
                isQuest = true
            end
            if A.ResolveItemCategory then
                -- Do not pass item.itemType: it may already be a section label from a prior scan.
                -- Resolver re-reads live GetItemInfo type and self-heals gphItemTypeCache.
                item.itemType = A.ResolveItemCategory({
                    itemId = itemId,
                    link = item.link,
                    quality = item.quality,
                    bag = item.bag,
                    slot = item.slot,
                    isProtected = item.isProtected,
                    isQuest = isQuest,
                    name = item.name,
                })
            else
                -- Fallback if Utils not loaded (should not happen in normal toc order).
                item.itemType = item.itemType or "Other"
            end
        end
        
        if not A._gphGroups then A._gphGroups = {} end
        wipe(A._gphGroups)
        local groups = A._gphGroups
        for _, item in ipairs(itemList) do
            local t = (item.itemId and destroyList[item.itemId]) and "DELETE" or (item.itemType or "Other")
            if not groups[t] then groups[t] = structPool() end
            table.insert(groups[t], item)
        end
        
        for _, items in pairs(groups) do
            table.sort(items, function(a, b)
                if a.isDestroy and b.isDestroy then
                    local atA = a.addedTime or 0
                    local atB = b.addedTime or 0
                    if atA ~= atB then return atA > atB end
                    return (a.name or "") < (b.name or "")
                end
                return A.GPH_Sort_CategoryGroup(a, b)
            end)
        end
        
        if not A._gphOrderedGroups then A._gphOrderedGroups = {} end
        wipe(A._gphOrderedGroups)
        local orderedGroups = A._gphOrderedGroups
        
        -- 1. Fixed order pass (e.g., Hearthstone always first in its category)
        local bagProtOrder = GetBagProtectedCategoryOrderList()
        A.GPH_BAG_PROTECTED_CATEGORY_ORDER = bagProtOrder
        for _, catName in ipairs(bagProtOrder) do
            if groups[catName] and #groups[catName] > 0 then
                -- Sort within the category to keep specific items first
                table.sort(groups[catName], function(a, b)
                    if a.itemId == A.HEARTHSTONE_ID and b.itemId ~= A.HEARTHSTONE_ID then return true end
                    if b.itemId == A.HEARTHSTONE_ID and a.itemId ~= A.HEARTHSTONE_ID then return false end
                    return A.GPH_Sort_CategoryGroup(a, b)
                end)
                
                local grpEntry = structPool()
                grpEntry.name = catName
                grpEntry.items = groups[catName]
                table.insert(orderedGroups, grpEntry)
            end
        end
        
        -- 2. "Catch-all" pass for unknown/unlisted types
        for catName, items in pairs(groups) do
            if catName ~= "DELETE" then
                local found = false
                for _, c in ipairs(bagProtOrder) do if c == catName then found = true break end end
                if not found then 
                    local grpEntry = structPool()
                    grpEntry.name = catName
                    grpEntry.items = items
                    table.insert(orderedGroups, grpEntry)
                end
            end
        end
        
        -- 3. Delete pass (Always last)
        if groups["DELETE"] and #groups["DELETE"] > 0 then
            local grpEntry = structPool()
            grpEntry.name = "DELETE"
            grpEntry.items = groups["DELETE"]
            table.insert(orderedGroups, grpEntry)
        end
        
        frame.gphCategoryGroups = orderedGroups
        if not frame.gphCategoryCollapsed then frame.gphCategoryCollapsed = {} end
        
        -- Phase 5: per-frame wipe + refill (inv and bank must not share one list)
        frame._catFlatList = frame._catFlatList or {}
        frame._catDrawList = frame._catDrawList or {}
        local flat = frame._catFlatList
        local drawList = frame._catDrawList
        wipe(flat)
        wipe(drawList)
        
        for _, grp in ipairs(orderedGroups) do
            local collapsed = (grp.name == "DELETE") and (frame.gphCategoryCollapsed["DELETE"] ~= false) or frame.gphCategoryCollapsed[grp.name]
            local divEntry = structPool()
            divEntry.divider = grp.name
            divEntry.collapsed = collapsed
            
            -- Hidden labels don't get divider headers
            local isHeaderless = (grp.name == "BAG_PROTECTED" or grp.name == "HIDDEN_FIRST")
            if not isHeaderless then
                table.insert(drawList, divEntry)
            end
            
            if not collapsed or isHeaderless then
                for _, item in ipairs(grp.items) do
                    table.insert(drawList, item)
                    table.insert(flat, item)
                end
            end
        end
        
        frame.gphCategoryItemList = flat
        frame.gphCategoryDrawList = drawList
    end
end
