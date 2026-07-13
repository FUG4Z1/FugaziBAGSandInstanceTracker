local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

--[[
  FugaziBAGS_Tooltips: The "Iron Anchor" and shared tooltip logic.
  Extracted from Utils.lua to decouple UI positioning from data.
]]

local TOOLTIP_FRAME_GAP = 5

function A.AnchorTooltipSmart(ownerFrame, preferredSide, anchorFrame)
    if not ownerFrame then return end
    
    local bank = A.Bank
    local inv = A.Inventory
    local host = anchorFrame
    
    if not host then
        local isBankOwner = ownerFrame._isBank or ownerFrame._isBankBtn or (ownerFrame.bagID and ownerFrame.bagID >= 5) or (ownerFrame.bagID == -1)
        host = isBankOwner and bank or inv
    end

    if not host or not host:GetRight() or host:GetRight() == 0 then return end
    
    local isShieldActive = A.gphTooltipShield and (GetTime() < A.gphTooltipShield)
    if isShieldActive and GameTooltip:IsShown() and GameTooltip:GetOwner() == ownerFrame then
        return 
    end

    local screenWidth = GetScreenWidth() * (GetCVar("uiScale") or 1)
    local gap = TOOLTIP_FRAME_GAP or 5
    local side = preferredSide or "RIGHT"

    if bank and bank:IsShown() and inv and inv:IsShown() then
        if host == bank then side = "LEFT" else side = "RIGHT" end
    else
        local hRight = host:GetRight() or 0
        local hLeft = host:GetLeft() or 0
        if side == "RIGHT" and (hRight + 330) > screenWidth then
            side = "LEFT"
        elseif side == "LEFT" and hLeft < 330 then
            side = "RIGHT"
        end
    end

    GameTooltip:SetOwner(ownerFrame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    if side == "RIGHT" then
        GameTooltip:SetPoint("TOPLEFT", host, "TOPRIGHT", gap, 0)
    else
        GameTooltip:SetPoint("TOPRIGHT", host, "TOPLEFT", -gap, 0)
    end
end

-- Hook GameTooltip OnUpdate to prevent stuck tooltips when owner frame is hidden.
GameTooltip:HookScript("OnUpdate", function(self)
    local owner = self:GetOwner()
    if owner and owner.IsVisible and not owner:IsVisible() then
        self:Hide()
    end
end)
