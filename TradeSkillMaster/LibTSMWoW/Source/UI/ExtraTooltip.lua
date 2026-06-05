-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ExtraTooltip = LibTSMWoW:DefineClassType("ExtraTooltip")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local private = {
	numExtraTooltips = 0,
}
local LINE_METATABLE = {
	__index = function(t, k)
		local v = _G[t.name..k]
		rawset(t, k, v)
		return v
	end,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new extra tooltip frame.
---@param tooltip GameTooltip
---@return ExtraTooltip
function ExtraTooltip.__static.New(tooltip)
	return ExtraTooltip(tooltip)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function ExtraTooltip.__private:__init(tooltip)
	private.numExtraTooltips = private.numExtraTooltips + 1
	local name = "TSMExtraTooltip"..private.numExtraTooltips
	self._frame = CreateFrame("GameTooltip", name, tooltip, "GameTooltipTemplate")
	self._frame:SetClampedToScreen(true)

	self._left = setmetatable({ name = name.."TextLeft" }, LINE_METATABLE)
	self._right = setmetatable({ name = name.."TextRight" }, LINE_METATABLE)

	self._anchorFrame = nil
	self._isTop = false
	self._changedLines = nil
end



-- ============================================================================
-- Extra Tip Methods
-- ============================================================================

---Shows the extra tooltip.
function ExtraTooltip:Show()
	self._anchorFrame = nil
	GameTooltip.Show(self._frame)
	local bottom = self._frame:GetBottom()
	if bottom and (not ClientInfo.IsRetail() or not issecretvalue(bottom)) and self._frame:GetParent():IsShown() then
		self._isTop = bottom <= 0
	end
	self:_OnUpdate()
	local numLines = self._frame:NumLines()
	local changedLines = self._changedLines or 0
	if changedLines >= numLines then return end
	for i = changedLines + 1, numLines do
		local left, right = self._left[i], self._right[i]
		local font = i == 1 and GameTooltipHeader or GameFontNormal

		local r, g, b, a = left:GetTextColor()
		left:SetFontObject(font)
		left:SetTextColor(r, g, b, a)

		r, g, b, a = right:GetTextColor()
		right:SetFontObject(font)
		right:SetTextColor(r, g, b, a)
	end
	self._changedLines = numLines
	GameTooltip.Show(self._frame)
	self:_OnUpdate()
end

---Hides the extra tooltip.
function ExtraTooltip:Hide()
	self._frame:Hide()
	self._isTop = false
end

---Attaches to a tooltip frame.
---@param tooltip GameTooltip The tooltip frame
function ExtraTooltip:Attach(tooltip)
	self._frame:SetOwner(tooltip, "ANCHOR_PRESERVE")
	self._anchorFrame = nil
	self:_OnUpdate()
end

---Adds a line to the extra tooltip.
---@param text string The text
---@param r? number The red color value
---@param g? number The green color value
---@param b? blue The blue color value
function ExtraTooltip:AddLine(text, r, g, b)
	self._frame:AddLine(text, r, g, b)
end

---Adds a double line to the extra tooltip.
---@param left string The left text
---@param right string The right text
---@param r? number The red color value
---@param g? number The green color value
---@param b? blue The blue color value
function ExtraTooltip:AddDoubleLine(left, right, r, g, b)
	self._frame:AddDoubleLine(left, right, r, g, b, r, g, b)
end




-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ExtraTooltip.__private:_OnUpdate()
	local tooltip = self._frame:GetParent()
	local anchorFrame = private.GetExtraTooltipFrame(tooltip, tooltip:GetChildren()) or tooltip
	if anchorFrame ~= self._anchorFrame then
		self._frame:ClearAllPoints()
		if self._isTop then
			self._frame:SetPoint("BOTTOM", anchorFrame, "TOP")
		else
			self._frame:SetPoint("TOP", anchorFrame, "BOTTOM")
		end
		self._anchorFrame = anchorFrame
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetExtraTooltipFrame(tooltip, ...)
	for i = 1, select('#', ...) do
		local frame = select(i, ...)
		if frame.InitLines and frame:GetParent() == tooltip and frame:IsVisible() then
			return frame
		end
	end
end
