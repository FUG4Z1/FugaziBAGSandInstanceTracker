local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

local Skins = _G.__FugaziBAGS_Skins
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerItemCooldown = _G.GetContainerItemCooldown
local GetItemSpell = _G.GetItemSpell
local GetSpellCooldown = _G.GetSpellCooldown
local GetTime = _G.GetTime
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local PlaySoundFile = _G.PlaySoundFile

--- Fill one list row: icon, name, count, rarity, vendor/AH value (inv or bank).
function A.FillListRowVisuals(row, item, destroyList, isBank)
	local rowItemId = item.itemId
	if not rowItemId and item.link then
		rowItemId = tonumber(item.link:match("item:(%d+)"))
		item.itemId = rowItemId
	end
	
	local hideIcons = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphHideIconsInList
	local customFormatting = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsCustom
	-- Row opacity slider: wash scales 0→1; text only eases 0.7→1.0 (never unreadable at 0).
	local rowOpacitySlider = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsAlpha
	if rowOpacitySlider == nil then rowOpacitySlider = 1.0 end
	rowOpacitySlider = tonumber(rowOpacitySlider) or 1.0
	if rowOpacitySlider < 0 then rowOpacitySlider = 0 elseif rowOpacitySlider > 1 then rowOpacitySlider = 1 end
	local formattingAlpha = rowOpacitySlider -- kept for visual-state early-out key
	local textAlpha = 0.7 + 0.3 * rowOpacitySlider
	local iconSize = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsIconSize or 16
	local fontSize = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsFontSize or 11
    
    local effectiveProtected = item.isProtected
    local effectiveDestroy = isBank and false or item.isDestroy

	-- Visual State Cache check
	local fontPath = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsFont or ""
	local state = row._visualState
	if not state then state = {}; row._visualState = state end
    
    local clicks = Addon and A.actionClickTime
    local lastClickValue = (rowItemId and clicks and clicks[rowItemId]) or 0
    local activeDel = (GetTime() - lastClickValue) <= 1.0
	local isUnlearnedWardrobe = false
	if _G.C_Appearance and _G.C_AppearanceCollection and rowItemId then
        if not A._gphWardrobeCache then A._gphWardrobeCache = {} end
        if A._gphWardrobeCache[rowItemId] == nil then
		    local appID = _G.C_Appearance.GetItemAppearanceID(rowItemId)
		    if appID and not _G.C_AppearanceCollection.IsAppearanceCollected(appID) then
			    A._gphWardrobeCache[rowItemId] = true
            else
                A._gphWardrobeCache[rowItemId] = false
		    end
        end
        isUnlearnedWardrobe = A._gphWardrobeCache[rowItemId]
	end

	local countValue = tonumber(item.count) or tonumber(item.totalCount) or 0
	if countValue < 0 then countValue = 0 end
	-- Stack text before _visualState early-out (count can change without full repaint).
	if row.countFs then
		if state.count ~= countValue or not state._countPainted then
			if countValue > 1 then
				row.countFs:SetText("|cffaaaaaa x" .. countValue .. "|r")
			else
				row.countFs:SetText("")
			end
			state._countPainted = true
		end
	end

	local showValIcons = _G.FugaziBAGSDB and _G.FugaziBAGSDB.showValuationIcons
	if showValIcons == nil then showValIcons = true end
	local alwaysValuate = _G.FugaziBAGSDB and _G.FugaziBAGSDB.alwaysValuateItems
	local isSessionItem = false
	if _G.gphSession and _G.gphSession.items then
		if item.link and _G.gphSession.items[item.link] then isSessionItem = true end
		if item.itemId and _G.gphSession.items[item.itemId] then isSessionItem = true end
	end
	local wantValIcon = showValIcons and not isBank and not item.isDestroy and not effectiveProtected and (alwaysValuate or isSessionItem)

	-- Same row chrome: skip name re-anchor (truncation flicker). Count already updated above.
	if state.id == rowItemId and state.link == item.link and state.prot == effectiveProtected and state.destroy == effectiveDestroy and state.hideIcons == hideIcons and state.customFormatting == customFormatting and state.formattingAlpha == formattingAlpha and state.iconSize == iconSize and state.fontSize == fontSize and state.fontPath == fontPath and state.activeDel == activeDel and state.isUnlearnedWardrobe == isUnlearnedWardrobe and state.wantValIcon == wantValIcon then
		state.count = countValue
		return
	end
	state.id = rowItemId
	state.count = countValue
	state.link = item.link
    state.activeDel = activeDel
	state.prot = effectiveProtected
	state.destroy = effectiveDestroy
	state.hideIcons = hideIcons
	state.customFormatting = customFormatting
	state.formattingAlpha = formattingAlpha
	state.iconSize = iconSize
	state.fontSize = fontSize
	state.fontPath = fontPath
	state.isUnlearnedWardrobe = isUnlearnedWardrobe
	state.wantValIcon = wantValIcon
	
	local isOnDestroyList = rowItemId and destroyList and destroyList[rowItemId]
    if isBank then isOnDestroyList = false end
    
	local hearthId = A.HEARTHSTONE_ID
	local isHearth = (rowItemId == hearthId)
	-- Layout chain: [item icon?] → [prev worn?] → [valuation?] → name
	-- When hideIcons, start at row left so valuation scoots with the name (was stuck under text).
	local leftOfName
	local gap = 4
	if hideIcons then
		if row.icon then row.icon:Hide() end
		if row.prevWornIcon then row.prevWornIcon:Hide() end
		leftOfName = row.clickArea
		gap = 4
	else
		if row.icon then
			local tex = (Addon and A.GetSafeItemTexture) and A.GetSafeItemTexture(item.link or item.itemId, item.texture) or item.texture or "Interface\\Icons\\INV_Misc_QuestionMark"
			A.SafeSetTexture(row.icon, tex)
			row.icon:SetSize(iconSize, iconSize)
			row.icon:Show()
			if isOnDestroyList then
				if row.icon.SetDesaturated then row.icon:SetDesaturated(true) end
				row.icon:SetVertexColor(0.55, 0.55, 0.55)
			elseif isHearth then
				if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
				row.icon:SetVertexColor(1, 1, 1)
			elseif effectiveProtected then
				if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
				row.icon:SetVertexColor(0.65, 0.65, 0.65)
			else
				if row.icon.SetDesaturated then row.icon:SetDesaturated(false) end
				row.icon:SetVertexColor(1, 1, 1)
			end
		end
		leftOfName = row.icon
		gap = 4
		if not isBank and row.prevWornIcon then
			if item.previouslyWorn then
				row.prevWornIcon:SetTexture("Interface\\Icons\\INV_Shield_06")
				row.prevWornIcon:ClearAllPoints()
				row.prevWornIcon:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
				if isOnDestroyList then
					row.prevWornIcon:SetVertexColor(0.55, 0.55, 0.55)
				elseif effectiveProtected then
					row.prevWornIcon:SetVertexColor(0.65, 0.65, 0.65)
				else
					row.prevWornIcon:SetVertexColor(1, 1, 1)
				end
				row.prevWornIcon:SetSize(iconSize * 0.85, iconSize * 0.85)
				row.prevWornIcon:Show()
				leftOfName = row.prevWornIcon
				gap = 2
			else
				row.prevWornIcon:Hide()
			end
		end
	end
	
	if wantValIcon and A.GetItemValuationAndAction then
		if not row.valIcon then
			row.valIcon = row.clickArea:CreateTexture(nil, "OVERLAY")
		end
		
		row.valIcon:SetSize(iconSize * 0.9, iconSize * 0.9)
		row.valIcon:ClearAllPoints()
		if hideIcons and leftOfName == row.clickArea then
			row.valIcon:SetPoint("LEFT", row.clickArea, "LEFT", 4, 0)
		else
			row.valIcon:SetPoint("LEFT", leftOfName, "RIGHT", gap, 0)
		end
		
		local _, _, _, _, _, itemClass = GetItemInfo(item.link or item.itemId)
		-- Pass bag/slot so soulbound BoP gear uses SetBagItem bind (not link-only).
		local price, action = A.GetItemValuationAndAction(
			item.link, item.itemId, item.quality, item.itemLevel, itemClass, item.bag, item.slot
		)
		local texPath = A.GetValuationActionIcon and A.GetValuationActionIcon(action)
		if texPath then
			row.valIcon:SetTexture(texPath)
			row.valIcon:Show()
			leftOfName = row.valIcon
			gap = 2
		else
			row.valIcon:Hide()
		end
	else
		if row.valIcon then row.valIcon:Hide() end
	end
	
	-- Right-side layout (from the row edge inward):
	--   no wardrobe:  [ name .................... ][ stack gutter ~40px ]
	--   wardrobe:     [ name .............. ][mog][ pad ]
	-- Old code pinned the mog badge at RIGHT -34 while name only reserved -48, so
	-- text ran under the icon and left a dead gap before the scrollbar. Unlearned
	-- appearance gear almost never has a stack count, so hug the right edge.
	local COUNT_RESERVE = 40
	local WARDROBE_EDGE = 5   -- padding from row right (near scrollbar)
	local WARDROBE_GAP = 3    -- air between truncated name and badge
	local wardrobeW = 0
	local wardrobeRight = -WARDROBE_EDGE
	if isUnlearnedWardrobe then
		wardrobeW = math.floor((iconSize or 16) * 0.72 + 0.5)
		if wardrobeW < 11 then wardrobeW = 11 end
		if wardrobeW > 16 then wardrobeW = 16 end
		-- Rare: stacked + unlearned — keep badge left of the count gutter.
		local countValueNow = tonumber(item.count) or tonumber(item.totalCount) or 0
		if countValueNow > 1 then
			wardrobeRight = -COUNT_RESERVE
		end
	end
	local nameRight = isUnlearnedWardrobe and (wardrobeRight - wardrobeW - WARDROBE_GAP) or -COUNT_RESERVE

	local qual = (item.quality and item.quality >= 0 and item.quality <= 7) and item.quality or 0
	local qInfo = (Addon and A.QUALITY_COLORS and A.QUALITY_COLORS[qual]) or (Addon and A.QUALITY_COLORS and A.QUALITY_COLORS[1]) or { r = 0.8, g = 0.8, b = 0.8, hex = "cccccc" }
	if row.nameFs then
		row.nameFs:ClearAllPoints()
		if leftOfName == row.clickArea then
			row.nameFs:SetPoint("LEFT", row.clickArea, "LEFT", 4, 0)
		else
			row.nameFs:SetPoint("LEFT", leftOfName, "RIGHT", gap, 0)
		end
		-- Truncate against the wardrobe (or count gutter), never run under the badge.
		row.nameFs:SetPoint("RIGHT", row.clickArea, "RIGHT", nameRight, 0)
		row.nameFs:SetWidth(0)
		if row.nameFs.SetWordWrap then row.nameFs:SetWordWrap(false) end
		if row.nameFs.SetNonSpaceWrap then row.nameFs:SetNonSpaceWrap(false) end
	end
	local nameHex
	if isOnDestroyList then
		nameHex = "888888"
	elseif isHearth then
		nameHex = "d9ebff"
	else
		nameHex = A.GetItemNameHex(qual, effectiveProtected, qInfo)
	end
    local isEquip = item.isEquip
    local ilvlStr = ""
    if isEquip and item.itemLevel and item.itemLevel > 1 then
        ilvlStr = tostring(item.itemLevel)
    end

    if not hideIcons then
        if not row.iconIlvlFs and row.clickArea then
            row.iconIlvlFs = row.clickArea:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            row.iconIlvlFs:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", -1, 1)
            row.iconIlvlFs:SetTextColor(0.5, 1.0, 0.5)
        end
        if row.iconIlvlFs then
            if isEquip and ilvlStr ~= "" then
                row.iconIlvlFs:SetText(ilvlStr)
                row.iconIlvlFs:Show()
            else
                row.iconIlvlFs:Hide()
            end
        end
    else
        if row.iconIlvlFs then row.iconIlvlFs:Hide() end
    end

	local plainName = item.name or "Unknown"
    if hideIcons and isEquip and ilvlStr ~= "" then
        plainName = "(" .. ilvlStr .. ") " .. plainName
    end
	row._plainName = plainName
	row._nameHex = nameHex
	if row.nameFs then
        local displayName = plainName or "Unknown"
        if customFormatting then
            local path = (fontPath and fontPath ~= "") and fontPath or "Fonts\\FRIZQT__.TTF"
            row.nameFs:SetFont(path, fontSize or 11, "")
            -- Text: slider 1 → 1.0, slider 0 → 0.7 (max ~30% fade). Wash uses full slider.
            row.nameFs:SetAlpha(textAlpha)
            
            local rC, gC, bC = qInfo.r or 1, qInfo.g or 1, qInfo.b or 1
            if item.isProtected and not isHearth then
                local mix, grey = 0.28, 0.48
                rC = rC * mix + grey * (1 - mix)
                gC = gC * mix + grey * (1 - mix)
                bC = bC * mix + grey * (1 - mix)
            end
            
            local hex = string.format("%02x%02x%02x", math.floor(rC * 255), math.floor(gC * 255), math.floor(bC * 255))
            if activeDel then
                A.SafeSetText(row.nameFs, displayName)
            else
                A.SafeSetText(row.nameFs, "|cff" .. hex .. displayName .. "|r")
            end
            row.nameFs:SetTextColor(1, 1, 1, textAlpha)
        else
            -- Default behavior
            row.nameFs:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
            row.nameFs:SetAlpha(1)
            if activeDel then
                A.SafeSetText(row.nameFs, displayName)
            else
                A.SafeSetText(row.nameFs, "|cff" .. (nameHex or "cccccc") .. displayName .. "|r")
            end
        end
		row._normalNameText = row.nameFs:GetText()
	end

	-- Wardrobe badge: hug the count gutter (near scrollbar). Name RIGHT already reserved above.
	if not row.wardrobeIcon then
		local wardrobeIcon = row.clickArea:CreateTexture(nil, "OVERLAY")
		row.wardrobeIcon = wardrobeIcon
	end

	if isUnlearnedWardrobe then
		row.wardrobeIcon:SetWidth(wardrobeW)
		row.wardrobeIcon:SetHeight(wardrobeW)
		if row.wardrobeIcon.SetAtlas then
			row.wardrobeIcon:SetAtlas("poi-transmogrifier")
		else
			row.wardrobeIcon:SetTexture("Interface\\Minimap\\TRACKING\\Transmogrifier")
		end
		row.wardrobeIcon:ClearAllPoints()
		row.wardrobeIcon:SetPoint("RIGHT", row.clickArea, "RIGHT", wardrobeRight, 0)
		row.wardrobeIcon:Show()
	else
		row.wardrobeIcon:Hide()
	end
	
    -- isSessionItem calculation moved up to line 133
	-- (stack count painted at top of FillListRowVisuals — always, even on early-out)
	
	if row.protectedOverlay then
		if isBank then
			row.protectedOverlay:Hide()
			if row.protectedKeyIcon then row.protectedKeyIcon:Hide() end
		else
			local capturedId = rowItemId
			local protectedSet = (Addon and A.GetGphProtectedSet) and A.GetGphProtectedSet() or {}
			local isManuallyProtected = (item.itemId and protectedSet[item.itemId]) or (capturedId and protectedSet[capturedId])
			local isPrevWorn = item.previouslyWorn
			local pendingDim = false
			if Addon and A.pendingAltUnprotect and capturedId then
				local t = A.pendingAltUnprotect[capturedId]
				if t then
					local now = (GetTime and GetTime()) or time()
					if (now - t) < 3 then pendingDim = true
					else A.pendingAltUnprotect[capturedId] = nil end
				end
			end

            local rowFormattingEnabled = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsCustom
			if ((item.isProtected and not isHearth) or isManuallyProtected) and not rowFormattingEnabled then
				row.protectedOverlay:Hide()
				if row.protectedKeyIcon then
					row.protectedKeyIcon:Hide()
				end
			else
				row.protectedOverlay:Hide()
				if row.protectedKeyIcon then row.protectedKeyIcon:Hide() end
			end
		end
	end

	-- After applying custom details, handle icon visibility override if needed
	if hideIcons then
		if row.icon then row.icon:Hide() end
		if row.prevWornIcon then row.prevWornIcon:Hide() end
	else
		-- Ensure icons have correct visibility if not hiding
		if row.icon then row.icon:Show() end
		if row.prevWornIcon then
			if item.previouslyWorn then
				row.prevWornIcon:Show()
			else
				row.prevWornIcon:Hide()
			end
		end
	end
end

--- Show item cooldown spiral on row (like bag slot cooldown).
function A.FugaziBAGS_CheckRowCooldown(btn, item, idToSlot)
    if not btn or not btn.cooldownOverlay then return false end
    local capturedId = item and (item.itemId or (item.link and tonumber(item.link:match("item:(%d+)"))))
    local onCooldown, isGCD = false, false
    local frac = nil

    -- 1. Check item-specific cooldown (Direct Bag/Slot or Map Search)
    local bag, slot = item.bag, item.slot
    -- bag 0 is backpack — not bag is true for 0 in Lua
    if bag == nil or slot == nil then
        local map, p = idToSlot, btn
        for _ = 1, 4 do
            p = p and p.GetParent and p:GetParent()
            if not p then break end
            if p._gphIdToSlotMap then map = p._gphIdToSlotMap; break end
        end
        local t = map and capturedId and map[capturedId]
        if t then bag, slot = t.bag, t.slot end
    end

    if bag ~= nil and slot ~= nil and GetContainerItemCooldown then
        local cStart, cDur = GetContainerItemCooldown(bag, slot)
        if cDur and cDur > 0 then
            -- Ignore GCDs triggered by spells (not clicked in bag)
            local isRecentBagClick = A._gphLastItemUseTime and (GetTime() - A._gphLastItemUseTime) <= 2.0
            if cDur > 1.5 or isRecentBagClick then
                local now = GetTime()
                local ends = (cStart or 0) + cDur
                if ends > now then
                    onCooldown = true
                    local remain = ends - now
                    frac = math.min(1, math.max(0, remain / cDur))
                end
            end
        end
    end

    if onCooldown then
        local r, g, b, a = 0.75, 0.85, 1.0, 0.2
        local SV = _G.FugaziBAGSDB
        local hc = SV and SV.gphSkinOverrides and SV.gphSkinOverrides.headerTextColor
        if hc and #hc >= 3 then
            r, g, b = hc[1], hc[2], hc[3]
            a = (hc[4] or 0.7) * 0.4
        elseif btn:GetParent() and btn:GetParent().gphAccentTextColor then
            local c = btn:GetParent().gphAccentTextColor
            r, g, b = c[1] or r, c[2] or g, c[3] or b
        end
        if btn.rarityBorderTop then
            local borderAlpha = isGCD and 0.05 or 0.4 -- Subtle borders for GCD
            btn.rarityBorderTop:SetVertexColor(1, 1, 1, borderAlpha)
            btn.rarityBorderBottom:SetVertexColor(1, 1, 1, borderAlpha)
            btn.rarityBorderLeft:SetVertexColor(1, 1, 1, borderAlpha)
            btn.rarityBorderRight:SetVertexColor(1, 1, 1, borderAlpha)
        end
        if isGCD then a = a * 0.35 end
        btn.cooldownOverlay:SetVertexColor(r, g, b, a)

        local ca = btn.clickArea or btn
        local rowW = ca:GetWidth() or 0
        btn.cooldownOverlay:ClearAllPoints()
        btn.cooldownOverlay:SetPoint("TOPLEFT", ca, "TOPLEFT", 0, 0)
        btn.cooldownOverlay:SetPoint("BOTTOMLEFT", ca, "BOTTOMLEFT", 0, 0)

        if frac and rowW and rowW > 4 then
            btn.cooldownOverlay:SetWidth(rowW * frac)
        else
            btn.cooldownOverlay:SetWidth(rowW > 0 and rowW or 0.01)
        end

        btn.cooldownOverlay:Show()
    else
        btn.cooldownOverlay:Hide()
    end
    return onCooldown
end

--- Row cooldown tick (update spiral).
function A.FugaziRow_OnUpdateCooldown(self, elapsed)
    self._cdTimer = (self._cdTimer or 0) + elapsed
    if self.cachedItem and self._cdTimer > 0.25 then
        self._cdTimer = 0
        local map, p = nil, self
        for _ = 1, 4 do
            p = p and p.GetParent and p:GetParent()
            if not p then break end
            if p._gphIdToSlotMap then map = p._gphIdToSlotMap; break end
        end
        if not A.FugaziBAGS_CheckRowCooldown(self, self.cachedItem, map) then
            self:SetScript("OnUpdate", nil)
        end
    end
end

--- Update one inventory row: icon, count, name, cooldown, protected/destroy state.
function A.UpdateGPHRowVisuals(btn, item, itemIdx, yOff, rowBelowDivider, destroyList, gphFrame, idToSlot, skipAnchoring)
    if not skipAnchoring then
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", btn:GetParent(), "TOPLEFT", 4, -yOff)
        btn:SetPoint("TOPRIGHT", btn:GetParent(), "TOPRIGHT", -4, -yOff)
    end



    local rowStep = A.ComputeItemDetailsRowHeight(18)
    if btn:GetHeight() ~= rowStep then
        btn:SetHeight(rowStep)
        if btn.clickArea then btn.clickArea:SetHeight(rowStep) end
    end

    -- Skin once per row + when theme / Row opacity slider changes (not every loot).
    local Skins = _G.__FugaziBAGS_Skins
    local skinGen = A._gphSkinGen or 0
    local skinKey = (Skins and Skins.ResolveSkinName and Skins.ResolveSkinName()) or ""
    local rowOp = _G.FugaziBAGSDB and _G.FugaziBAGSDB.gphItemDetailsAlpha
    if rowOp == nil then rowOp = 1 end
    if not btn._rowSkinApplied or btn._rowSkinName ~= skinKey or btn._rowSkinGen ~= skinGen or btn._rowOpacityApplied ~= rowOp then
        btn:SetHitRectInsets(0, 0, 0, 0)
        if btn.clickArea then btn.clickArea:SetHitRectInsets(0, 0, 0, 0) end
        if Skins and Skins.ApplyToComponent then
            Skins.ApplyToComponent(btn, "Row", "Item")
        end
        btn._rowSkinApplied = true
        btn._rowSkinName = skinKey
        btn._rowSkinGen = skinGen
        btn._rowOpacityApplied = rowOp
    end

    btn.itemLink = item.link
    local rowItemId = item.itemId
    if not rowItemId and item.link then
        rowItemId = tonumber(item.link:match("item:(%d+)"))
        item.itemId = rowItemId
    end
    -- Pool rows keep their pulse texture across rebinds. Protect re-sorts the list, so a
    -- flash started on row N would show on whatever item lands on N next (looks like the
    -- row above/below was clicked). Kill the pulse when identity changes.
    if btn.cachedItemId ~= nil and btn.cachedItemId ~= rowItemId then
        if A.ClearRowPulse then A.ClearRowPulse(btn) end
    end
    A.FillListRowVisuals(btn, item, destroyList, gphFrame and gphFrame._isBankFrame)
    local capturedId = rowItemId

    local isSelected = gphFrame and (
        (item.bag ~= nil and item.slot ~= nil and gphFrame.gphSelectedBag == item.bag and gphFrame.gphSelectedSlot == item.slot)
        or (not item.bag and gphFrame.gphSelectedItemId == capturedId and gphFrame.gphSelectedIndex == itemIdx)
    )

    if isSelected then
        if btn.selectedTex then btn.selectedTex:Show() end
    else
        if btn.selectedTex then btn.selectedTex:Hide() end
    end

    if btn.destroyOverlay then
        if item.isDestroy then
            btn.destroyOverlay:SetAlpha(0.72)
            btn.destroyOverlay:Show()
        else
            btn.destroyOverlay:Hide()
        end
    end

    btn.cachedItem = item
    btn.cachedItemId = capturedId
    btn.cachedItemIdx = itemIdx
    
    -- Force direct bag/slot properties for the Item Button (fixes tooltip identity theft)
    local actualBag = item.bag or item.bagID or item.firstBag
    local actualSlot = item.slot or item.slotID or item.firstSlot
    btn.bag, btn.slot = actualBag, actualSlot
    if btn.clickArea then
        btn.clickArea.bag, btn.clickArea.slot = actualBag, actualSlot
        btn.clickArea:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    local isLocked = false
    if A.lockedDisenchantSlots and actualBag ~= nil and actualSlot ~= nil then
        local key = tostring(actualBag) .. "_" .. tostring(actualSlot)
        local lockTime = A.lockedDisenchantSlots[key]
        if lockTime then
            if type(lockTime) == "number" and (GetTime() - lockTime > 2.0) then
                A.lockedDisenchantSlots[key] = nil
            else
                isLocked = true
            end
        end
    end

    -- Don't fight an in-progress DE list restore fade.
    if btn._listDimFading then
        -- leave alpha to FadeRestoreGPHListRows
    else
        local act = A.activeDisenchantSlot
        local isActive = false
        -- Only dim while still processing AND this row is still that bag/slot (not a
        -- rebound pool row after learn removed the recipe).
        if act and A.isDisenchanting and actualBag ~= nil and actualSlot ~= nil
            and act.bag == actualBag and act.slot == actualSlot then
            isActive = true
        end
        if isLocked or isActive then
            btn._listDimActive = true
            btn:SetAlpha(0.3)
        else
            -- Rebind safety: pool row no longer the target → never keep stuck dim.
            if btn._listDimActive then
                btn._listDimActive = nil
            end
            btn:SetAlpha(1.0)
        end
    end

    if not btn._scriptsBound then
        btn._scriptsBound = true
        
        btn.clickArea:RegisterForDrag("LeftButton")
        btn.clickArea:SetScript("OnReceiveDrag", function(self) A.HandleBagSlotReceiveDrag(self) end)
        btn.clickArea:SetScript("OnDragStart", function(self) A.HandleBagSlotDrag(self) end)
        btn.clickArea:SetScript("OnMouseWheel", function(self, delta)
            local p = self:GetParent()
            local it = p.cachedItem
            if it and gphFrame and gphFrame.scrollFrame and gphFrame.scrollFrame.GPHOnMouseWheel then
                gphFrame.scrollFrame.GPHOnMouseWheel(delta)
            end
        end)
        btn.clickArea:SetScript("OnEnter", function(self)
            A.HandleBagSlotEnter(self)
        end)
        btn.clickArea:SetScript("OnLeave", function(self)
            A.HandleBagSlotLeave(self)
        end)
        btn.clickArea:SetScript("OnClick", function(self, button)
             local p = self:GetParent()
             local it = p.cachedItem
             if not it then
                if A.PlayClickSound then A.PlayClickSound() end
                return
             end
             if it.isDestroy then
                if button == "RightButton" and p.cachedItemId then
                    local list = A.GetGphDestroyList and A.GetGphDestroyList()
                    if list then list[p.cachedItemId] = nil end
                    if A.PlaySwooshSound then A.PlaySwooshSound() end
                    if gphFrame then gphFrame._refreshImmediate = true end
                    if A.RefreshGPHUI then A.RefreshGPHUI() end
                else
                    if A.PlayClickSound then A.PlayClickSound() end
                end
                return
             end
             if gphFrame then
                if it.bag ~= nil and it.slot ~= nil then
                    gphFrame.gphSelectedBag, gphFrame.gphSelectedSlot = it.bag, it.slot
                    gphFrame.gphSelectedItemId = p.cachedItemId
                    gphFrame.gphSelectedIndex = p.cachedItemIdx
                else
                    gphFrame.gphSelectedItemId = p.cachedItemId
                    gphFrame.gphSelectedBag, gphFrame.gphSelectedSlot = nil, nil
                    gphFrame.gphSelectedIndex = p.cachedItemIdx
                end
                if Addon and A.RefreshGPHUI then A.RefreshGPHUI() end
             end
             A.HandleBagSlotClick(self, button)
        end)
        btn.clickArea:SetScript("OnMouseDown", function(self, mouseButton)
            -- Alt/Ctrl rebuild/re-sort the list; pulse the correct post-refresh row instead.
            if (IsAltKeyDown and IsAltKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then
                return
            end
            if A.TriggerRowPulse then A.TriggerRowPulse(self:GetParent()) end
        end)
    end

    if item.bag ~= nil and item.slot ~= nil and _G.FugaziBAGS_EnsureSecureRowBtn then
        _G.FugaziBAGS_EnsureSecureRowBtn(btn.clickArea, item.bag, item.slot)
    end
    
    if item.isDestroy or item.bag == nil or item.slot == nil then
        local par = btn.clickArea and btn.clickArea._fugaziSecPar
        -- Hide is protected when a secure ContainerFrameItemButton child exists.
        if par and not (_G.InCombatLockdown and _G.InCombatLockdown()) then par:Hide() end
    end

    -- Keep count above secure overlay; only raise if secure (or parent) outranked it.
    -- SafeSetFrameLevel skips protected frames in combat (3.3.5 lockdown).
    if btn._countLayer and btn.clickArea then
        local want = (btn.clickArea:GetFrameLevel() or 1) + 10
        if (btn._countLayer:GetFrameLevel() or 0) < want then
            if A.SafeSetFrameLevel then
                A.SafeSetFrameLevel(btn._countLayer, want)
            elseif not (_G.InCombatLockdown and _G.InCombatLockdown()) then
                btn._countLayer:SetFrameLevel(want)
            end
        end
        if not btn._countLayer:IsShown() then btn._countLayer:Show() end
    end
    
    if btn.cooldownOverlay then
        if A.FugaziBAGS_CheckRowCooldown(btn, item, idToSlot) then
            btn:SetScript("OnUpdate", A.FugaziRow_OnUpdateCooldown)
        else
            btn:SetScript("OnUpdate", nil)
        end
    end
    
    -- Modifier Overlay is now managed dynamically in Actions.HandleBagSlotEnter
end

function A.UpdateAllRowCooldowns()
    local framesToUpdate = { A.Inventory, A.Bank }
    for _, gphFrame in ipairs(framesToUpdate) do
        if gphFrame and gphFrame:IsShown() and gphFrame.content then
            local idToSlot = gphFrame._gphIdToSlotMap or {}
            local children = { gphFrame.content:GetChildren() }
            for _, btn in ipairs(children) do
                if btn:IsShown() and btn.cachedItem and btn.cooldownOverlay then
                    if A.FugaziBAGS_CheckRowCooldown(btn, btn.cachedItem, idToSlot) then
                        btn:SetScript("OnUpdate", A.FugaziRow_OnUpdateCooldown)
                    else
                        btn:SetScript("OnUpdate", nil)
                        btn.cooldownOverlay:Hide()
                    end
                end
            end
        end
    end
end
