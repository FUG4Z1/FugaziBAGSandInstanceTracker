local addonName, Addon = ...
local A = _G.FugaziBAGS or Addon or {}

--[[
  FugaziBAGS_Tooltips: shared tooltip hygiene.
  AnchorTooltipSmart lives in Utils.lua (canonical free-float logic).
]]

-- Owner hidden (bags closed while still "hovering"): drop tip + sticky last-hover.
GameTooltip:HookScript("OnUpdate", function(self)
    local owner = self:GetOwner()
    if owner and owner.IsVisible and not owner:IsVisible() then
        A._gphLastHoveredRow = nil
        self:Hide()
    end
end)
