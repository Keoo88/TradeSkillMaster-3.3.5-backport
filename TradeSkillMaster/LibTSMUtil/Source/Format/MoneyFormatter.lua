-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local MoneyFormatter = LibTSMUtil:DefineClassType("MoneyFormatter")
local Math = LibTSMUtil:Include("Lua.Math")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local String = LibTSMUtil:Include("Lua.String")
MoneyFormatter.FORMAT = EnumType.New("MONEY_FORMAT", {
	TEXT = EnumType.NewValue(),
	TEXT_DISABLED = EnumType.NewValue(),
	ICON = EnumType.NewValue(),
	ICON_DISABLED = EnumType.NewValue(),
})
MoneyFormatter.COPPER_HANDLING = EnumType.New("MONEY_COPPER_HANDLING", {
	KEEP = EnumType.NewValue(),
	ROUND_OVER_1G = EnumType.NewValue(),
	REMOVE = EnumType.NewValue(),
})
local private = {
	largeNumberSeperator = ","
}
---@class MoneyFormatTokens
---@field gold string
---@field silver string
---@field copper string
---@type table<EnumValue,MoneyFormatTokens>
local TOKENS = {
	[MoneyFormatter.FORMAT.TEXT] = {
		gold = "|cffffd70ag|r",
		silver = "|cffc7c7cfs|r",
		copper = "|cffeda55fc|r",
	},
	[MoneyFormatter.FORMAT.TEXT_DISABLED] = {
		gold = "|cff5d5222g|r",
		silver = "|cff464646s|r",
		copper = "|cff402d22c|r",
	},
	[MoneyFormatter.FORMAT.ICON] = {
		gold = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t",
		silver = "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t",
		copper = "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t",
	},
	[MoneyFormatter.FORMAT.ICON_DISABLED] = {
		gold = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:0:0:1:1:0:1:0:1:100:100:100|t",
		silver = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:0:0:1:1:0:1:0:1:100:100:100|t",
		copper = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:0:0:1:1:0:1:0:1:100:100:100|t",
	},
}
local COPPER_PER_SILVER = 100
local COPPER_PER_GOLD = 100 * COPPER_PER_SILVER



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new money formatter.
---@return MoneyFormatter
function MoneyFormatter.__static.New()
	return MoneyFormatter()
end

---Sets the large number seperator.
---@param value string The string value
function MoneyFormatter.__static.SetLargeNumberSeperator(value)
	private.largeNumberSeperator = value
end

---Gets the large number seperator.
---@return string
function MoneyFormatter.__static.GetLargeNumberSeperator()
	return private.largeNumberSeperator
end

---Returns the colored copper indicator text.
---@return string
function MoneyFormatter.__static.GetCopperText()
	return TOKENS[MoneyFormatter.FORMAT.TEXT].copper
end

---Returns the colored silver indicator text.
---@return string
function MoneyFormatter.__static.GetSilverText()
	return TOKENS[MoneyFormatter.FORMAT.TEXT].silver
end

---Returns the colored gold indicator text.
---@return string
function MoneyFormatter.__static.GetGoldText()
	return TOKENS[MoneyFormatter.FORMAT.TEXT].gold
end

---Converts a string money value to a number value (in copper).
---
---The value passed to this function can contain colored text, but must use text and not icon tokens.
---@param value string The money value to be converted
---@return number?
function MoneyFormatter.__static.FromString(value)
	-- Remove any colors
	value = gsub(gsub(strtrim(value), "|c[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]", ""), "|r", "")

	-- Remove any separators
	value = gsub(value, String.Escape(private.largeNumberSeperator), "")

	-- Extract gold/silver/copper values
	local gold = tonumber(strmatch(value, "([0-9]+)g"))
	local silver = tonumber(strmatch(value, "([0-9]+)s"))
	local copper = tonumber(strmatch(value, "([0-9]+)c"))
	if not gold and not silver and not copper then
		return
	end
	gold = gold or 0
	silver = silver or 0
	copper = copper or 0

	-- Test that there are no extra characters (other than spaces)
	local testValue = value
	testValue = gsub(testValue, "[0-9]+g", "", 1)
	testValue = gsub(testValue, "[0-9]+s", "", 1)
	testValue = gsub(testValue, "[0-9]+c", "", 1)
	if strtrim(testValue) ~= "" then
		return
	end

	return gold * COPPER_PER_GOLD + silver * COPPER_PER_SILVER + copper
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function MoneyFormatter.__private:__init()
	self._copperHandling = MoneyFormatter.COPPER_HANDLING.KEEP
	self._trim = false
	self._tokens = TOKENS[MoneyFormatter.FORMAT.TEXT]
	self._color = nil
	self._partsTemp = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the format.
---@param format MoneyFormatter.FORMAT The format to use
---@return MoneyFormatter
function MoneyFormatter:SetFormat(format)
	self._tokens = TOKENS[format]
	assert(self._tokens)
	return self
end

---Changes how copper is handled.
---@param handling MoneyFormatter.COPPER_HANDLING How to handle copper
---@return MoneyFormatter
function MoneyFormatter:SetCopperHandling(handling)
	assert(EnumType.IsValue(handling, MoneyFormatter.COPPER_HANDLING))
	self._copperHandling = handling
	return self
end

---Sets a color prefix to use for the text components.
---@param colorPrefix? string The color prefix string or nil to remove coloring
---@return MoneyFormatter
function MoneyFormatter:SetColor(colorPrefix)
	assert(colorPrefix == nil or (type(colorPrefix) == "string" and #colorPrefix == 10))
	self._color = colorPrefix
	return self
end

---Sets whether or not trailing 0 values should be trimmed.
---@param enabled boolean Whether or not trimming should be enabled
---@return MoneyFormatter
function MoneyFormatter:SetTrimEnabled(enabled)
	assert(type(enabled) == "boolean")
	self._trim = enabled
	return self
end

---Converts a money value to a string.
---@param value number|string The value in copper
---@return string?
function MoneyFormatter:ToString(value)
	value = tonumber(value)
	if not value then
		return nil
	end
	assert(#self._partsTemp == 0)

	-- Shortcut for zero
	if value == 0 then
		return self:_Color("0")..self:_GetLeastSignificantToken()
	end

	local isNegative = value < 0
	value = abs(value)
	if self._copperHandling == MoneyFormatter.COPPER_HANDLING.ROUND_OVER_1G and value >= COPPER_PER_GOLD then
		value = Math.Round(value, COPPER_PER_SILVER)
	end
	local gold = floor(value / COPPER_PER_GOLD)
	local silver = floor((value % COPPER_PER_GOLD) / COPPER_PER_SILVER)
	local copper = floor(value % COPPER_PER_SILVER)
	assert(self._copperHandling ~= MoneyFormatter.COPPER_HANDLING.REMOVE or copper == 0)

	-- Add gold
	if gold > 0 then
		self:_InsertMoneyPart(gold, self._tokens.gold)
	end
	-- Add silver
	if silver > 0 or (not self._trim and gold > 0) then
		self:_InsertMoneyPart(silver, self._tokens.silver)
	end
	-- Add copper
	if copper > 0 or (not self._trim and self._copperHandling == MoneyFormatter.COPPER_HANDLING.KEEP and (gold + silver) > 0) then
		self:_InsertMoneyPart(copper, self._tokens.copper)
	end

	local text = table.concat(self._partsTemp, " ")
	wipe(self._partsTemp)
	if isNegative then
		text = self:_Color("-")..text
	end
	return text
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MoneyFormatter.__private:_InsertMoneyPart(value, token)
	tinsert(self._partsTemp, self:_FormatNumber(value)..token)
end

function MoneyFormatter.__private:_FormatNumber(num)
	if num < 10 and #self._partsTemp > 0 then
		num = "0"..num
	elseif #self._partsTemp == 0 and num >= 1000 then
		num = tostring(num)
		local result = ""
		for i = 4, #num, 3 do
			result = private.largeNumberSeperator..strsub(num, -(i - 1), -(i - 3))..result
		end
		result = strsub(num, 1, (#num % 3 == 0) and 3 or (#num % 3))..result
		num = result
	end
	return self:_Color(num)
end

function MoneyFormatter.__private:_Color(text)
	if self._color then
		return self._color..text.."|r"
	else
		return text
	end
end

function MoneyFormatter.__private:_GetLeastSignificantToken()
	if self._copperHandling == MoneyFormatter.COPPER_HANDLING.REMOVE then
		return self._tokens.silver
	else
		return self._tokens.copper
	end
end
