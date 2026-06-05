-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local TooltipBuilder = LibTSMService:DefineClassType("TooltipBuilder")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Theme = LibTSMService:Include("UI.Theme")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMService:From("LibTSMUtil"):Include("UI.Money")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local ModifierKey = LibTSMService:From("LibTSMWoW"):Include("Service.ModifierKey")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {
	inCombatText = nil,
	moneyUseIcon = nil,
}
local TOOLTIP_CACHE_TIME = 5
local LINE_PART_SEP = "\t"
local DISABLED_TINT = -30



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Sets the placeholder text to show while in combat.
---@param inCombatText string The localized string to display while in combat
function TooltipBuilder.__static.SetInCombatPlaceholder(inCombatText)
	assert(inCombatText and not private.inCombatText)
	private.inCombatText = inCombatText
end

---Sets whether or not to use icons for money text.
---@param useIcon boolean
function TooltipBuilder.__static.SetMoneyUseIcon(useIcon)
	private.moneyUseIcon = useIcon
end

---Creates a new tooltip builder.
---@return TooltipBuilder
function TooltipBuilder.__static.New()
	assert(private.inCombatText)
	return TooltipBuilder()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function TooltipBuilder.__private:__init()
	self._lines = {}
	self._lineColors = {}
	self._level = 0
	self._levelNumLines = {}
	self._levelHasHeading = {}
	self._lastUpdate = 0
	self._inCombat = false
	self._itemString = nil
	self._quantity = nil
	self._disabled = nil
	ModifierKey.RegisterCallback(self:__closure("_InvalidateLastUpdate"))
	Event.Register("BAG_UPDATE_DELAYED", self:__closure("_InvalidateLastUpdate"))
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Colors value text for display in the tooltip.
---@param text string The text to color
---@return string
function TooltipBuilder:ApplyValueColor(text)
	local color = Theme.GetColor("TEXT")
	if self._disabled then
		color = color:GetTint(DISABLED_TINT)
	end
	return color:ColorText(text)
end

---Formats money for display in the tooltip.
---@param value number The money value
---@param color? Color The color
---@return string
function TooltipBuilder:FormatMoney(value, color)
	color = color or Theme.GetColor("TEXT")
	if self._disabled then
		color = color:GetTint(DISABLED_TINT)
	end
	if not value then
		return self:ApplyValueColor("---")
	end
	return Money.ToStringForTooltip(value, color:GetTextColorPrefix(), private.moneyUseIcon, self._disabled)
end

---Adds a line to the tooltip.
---@param lineLeft string The left text
---@param lineRight string The right text
function TooltipBuilder:AddLine(lineLeft, lineRight)
	if lineRight then
		lineLeft = strjoin(LINE_PART_SEP, lineLeft, lineRight)
	end
	local line = strrep("  ", self._level)..lineLeft
	local color = "INDICATOR_ALT"
	if self._disabled then
		color = color.."+DISABLED"
	end
	assert(not self._lineColors[line] or self._lineColors[line] == color)
	self._lineColors[line] = color
	tinsert(self._lines, line)
	self._levelNumLines[self._level] = self._levelNumLines[self._level] + 1
end

---Adds a line with a label on the left and text on the right to the tooltip.
---@param label string The label text
---@param text string The contents text
---@param ... string Additional text components to add in parans
function TooltipBuilder:AddTextLine(label, text, ...)
	if select("#", ...) == 0 then
		self:AddLine(label, self:ApplyValueColor(text))
	else
		self:AddLine(label, self:ApplyValueColor(text).." ("..self:_TextsToStr(...)..")")
	end
end

---Adds an item value line to the tooltip.
---@param label string The label text
---@param value number The value
---@param prefixText? string Prefix text to add before the formated value
function TooltipBuilder:AddItemValueLine(label, value, prefixText)
	if self._quantity > 1 then
		label = label.." x"..self._quantity
		value = value * self._quantity
	end
	local text = self:FormatMoney(value)
	if prefixText then
		text = prefixText.." "..text
	end
	self:AddLine(label, text)
end

---Adds a line with multiple item values to the tooltip.
---@param label string The label text
---@param ... number The values
function TooltipBuilder:AddItemValuesLine(label, ...)
	if self._quantity > 1 then
		label = label.." x"..self._quantity
	end
	self:AddLine(label, self:_ValuesToStr(self._quantity, ...))
end

---Adds a quantity value line to the tooltip.
---@param label string The label text
---@param quantity number The quantity value
---@param ... number Additinoal quantity values
function TooltipBuilder:AddQuantityValueLine(label, quantity, ...)
	self:AddLine(label, self:ApplyValueColor(quantity).." ("..self:_ValuesToStr(1, ...)..")")
end

---Adds a sub item value line to the tooltip.
---@param itemString string The item string
---@param value number The value
---@param multiplier number The multiplier for the sub item
---@param matRate number The rate of the sub item
---@param minAmount number The min amount of the range
---@param maxAmount number The max amount of the range
function TooltipBuilder:AddSubItemValueLine(itemString, value, multiplier, matRate, minAmount, maxAmount)
	local name = ItemInfo.GetName(itemString)
	local color = ItemInfo.GetQualityColor(itemString)
	if not name or not color then
		return
	end
	local craftedQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(itemString)
	local craftedQualityIcon = craftedQuality and TradeSkill.GetCraftedQualityChatIcon(craftedQuality, useMidnightIcon)
	if craftedQualityIcon then
		name = name..craftedQualityIcon
	end
	multiplier = Math.Round(multiplier * self._quantity, 0.001)
	matRate = matRate and matRate * 100
	matRate = matRate and matRate.."% " or ""
	local range = (minAmount and maxAmount) and (minAmount ~= maxAmount and "|cffffff00 ["..minAmount.."-"..maxAmount.."]|r" or "|cffffff00 ["..minAmount.."]|r") or ""
	value = value and (value * multiplier) or nil
	self:AddLine(color..matRate..name.." x"..multiplier.."|r"..range, self:FormatMoney(value))
end

---Starts a new tooltip section.
---@param headingTextLeft string The left heading text
---@param headingTextRight string The right heading text
function TooltipBuilder:StartSection(headingTextLeft, headingTextRight)
	if self._level == 0 then
		headingTextLeft = Theme.GetColor("INDICATOR"):ColorText(headingTextLeft)
	end
	if headingTextRight then
		self:AddLine(headingTextLeft, headingTextRight)
	elseif headingTextLeft then
		self:AddLine(headingTextLeft)
	end
	self._level = self._level + 1
	self._levelHasHeading[self._level] = headingTextLeft and true or false
	self._levelNumLines[self._level] = 0
end

---Ends a tooltip section.
function TooltipBuilder:EndSection()
	if self._levelNumLines[self._level] == 0 and self._levelHasHeading[self._level] then
		-- remove the previous heading line
		local headingLine = tremove(self._lines)
		assert(headingLine)
		self._lineColors[headingLine] = nil
		self._levelNumLines[self._level - 1] = self._levelNumLines[self._level - 1] - 1
	end
	self._level = self._level - 1
	assert(self._level >= 0)
end

---Sets the tooltip state to disabled / enabled.
---@param disabled boolean Whether the tooltip should be disabled or not
function TooltipBuilder:SetDisabled(disabled)
	self._disabled = disabled
end

---Gets the number of lines in the tooltip.
---@return number
function TooltipBuilder:GetNumLines()
	return #self._lines
end

---Gets a line of the tooltip.
---@param index number The index of the line
---@return string left
---@return string? right
---@return Color color
function TooltipBuilder:GetLine(index)
	local line = self._lines[index]
	local left, right = strsplit(LINE_PART_SEP, line)
	return left, right, self._lineColors[line]
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function TooltipBuilder.__private:_InvalidateLastUpdate()
	self._lastUpdate = 0
end

function TooltipBuilder.__private:_TextsToStr(...)
	local valueParts = TempTable.Acquire(...)
	for i = 1, #valueParts do
		valueParts[i] = self:ApplyValueColor(valueParts[i])
	end
	local result = table.concat(valueParts, " / ")
	TempTable.Release(valueParts)
	return result
end

function TooltipBuilder.__private:_ValuesToStr(quantity, ...)
	-- can't just build the table with the vararg as there may be nils
	local valueParts = TempTable.Acquire()
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		value = value and value * quantity or nil
		valueParts[i] = self:FormatMoney(value)
	end
	local result = table.concat(valueParts, " / ")
	TempTable.Release(valueParts)
	return result
end

---@private
function TooltipBuilder:_Prepare(itemString, quantity)
	if self:_IsCached(itemString, quantity) then
		-- Have the lines cached already
		return true
	end

	wipe(self._lines)
	wipe(self._lineColors)
	wipe(self._levelNumLines)
	wipe(self._levelHasHeading)
	self._level = 0
	self._levelNumLines[self._level] = 0
	self._lastUpdate = LibTSMService.GetTime()
	self._inCombat = ClientInfo.IsInCombat()
	self._itemString = itemString
	self._quantity = quantity
	self._disabled = false

	if ClientInfo.IsInCombat() and itemString ~= ItemString.GetPlaceholder() then
		self:AddLine(private.inCombatText)
		return true
	else
		return false
	end
end

function TooltipBuilder.__private:_IsCached(itemString, quantity)
	if itemString == ItemString.GetPlaceholder() then
		return false
	end
	if self._itemString ~= itemString or self._quantity ~= quantity then
		return false
	end
	if LibTSMService.GetTime() - self._lastUpdate >= TOOLTIP_CACHE_TIME then
		return false
	end
	if ClientInfo.IsInCombat() ~= self._inCombat then
		return false
	end
	return true
end

---@private
function TooltipBuilder:_IsEmpty()
	assert(self._level == 0)
	return #self._lines == 0
end

---@private
function TooltipBuilder:_LineIterator()
	return private.LineIteratorHelper, self, 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LineIteratorHelper(self, index)
	index = index + 1
	if index > #self._lines then
		return
	end
	return index, self:GetLine(index)
end
