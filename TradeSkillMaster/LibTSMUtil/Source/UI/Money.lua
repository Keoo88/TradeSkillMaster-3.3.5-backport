-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Money = LibTSMUtil:Init("UI.Money")
local MoneyFormatter = LibTSMUtil:IncludeClassType("MoneyFormatter")
local private = {
	formatterForAH = nil,
	formatterForUI = nil,
	formatterForUIShort = nil,
	formatterExact = nil,
	formatterForTooltip = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Money:OnModuleLoad(function()
	private.formatterForAH = MoneyFormatter.New()
		:SetCopperHandling(LibTSMUtil.IsRetail() and MoneyFormatter.COPPER_HANDLING.REMOVE or MoneyFormatter.COPPER_HANDLING.KEEP)
		:SetTrimEnabled(false)
	private.formatterForUI = MoneyFormatter.New()
		:SetCopperHandling(LibTSMUtil.IsRetail() and MoneyFormatter.COPPER_HANDLING.ROUND_OVER_1G or MoneyFormatter.COPPER_HANDLING.KEEP)
		:SetFormat(MoneyFormatter.FORMAT.TEXT)
		:SetTrimEnabled(false)
	private.formatterForUIShort = MoneyFormatter.New()
		:SetCopperHandling(LibTSMUtil.IsRetail() and MoneyFormatter.COPPER_HANDLING.ROUND_OVER_1G or MoneyFormatter.COPPER_HANDLING.KEEP)
		:SetFormat(MoneyFormatter.FORMAT.TEXT)
		:SetColor(nil)
		:SetTrimEnabled(true)
	private.formatterExact = MoneyFormatter.New()
		:SetCopperHandling(MoneyFormatter.COPPER_HANDLING.KEEP)
		:SetFormat(MoneyFormatter.FORMAT.TEXT)
		:SetTrimEnabled(false)
	private.formatterForTooltip = MoneyFormatter.New()
		:SetCopperHandling(LibTSMUtil.IsRetail() and MoneyFormatter.COPPER_HANDLING.ROUND_OVER_1G or MoneyFormatter.COPPER_HANDLING.KEEP)
		:SetTrimEnabled(false)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Converts a money value to a string with settings suitable for the auction house.
---@param value number The value in copper
---@param color? string An optional color value
---@param disabled? boolean Optionally use the disabled tokens
---@return string?
function Money.ToStringForAH(value, color, disabled)
	return private.formatterForAH
		:SetFormat(disabled and MoneyFormatter.FORMAT.TEXT_DISABLED or MoneyFormatter.FORMAT.TEXT)
		:SetColor(color)
		:ToString(value)
end

---Converts a money value to a string with settings suitable for the UI.
---@param value number The value in copper
---@param color? string An optional color value
---@param disabled? boolean Optionally use the disabled tokens
---@return string?
function Money.ToStringForUI(value, color)
	return private.formatterForUI
		:SetColor(color)
		:ToString(value)
end

---Converts a money value to as short of a string as possible for display in the UI.
---@param value number The value in copper
---@param color? string An optional color value
---@param disabled? boolean Optionally use the disabled tokens
---@return string?
function Money.ToStringForUIShort(value)
	return private.formatterForUIShort
		:ToString(value)
end

---Converts a money value to a string with maximum precision.
---@param value number The value in copper
---@param color? string An optional color value
---@return string?
function Money.ToStringExact(value, color)
	return private.formatterExact
		:SetColor(color)
		:ToString(value)
end

---Converts a money value to a string with maximum precision.
---@param value number The value in copper
---@param color string|nil The color value
---@param useIcon boolean Use icons instead of text
---@param disabled boolean Use the disabled format
---@return string?
function Money.ToStringForTooltip(value, color, useIcon, disabled)
	if useIcon and disabled then
		private.formatterForTooltip:SetFormat(MoneyFormatter.FORMAT.ICON_DISABLED)
	elseif useIcon then
		private.formatterForTooltip:SetFormat(MoneyFormatter.FORMAT.ICON)
	elseif disabled then
		private.formatterForTooltip:SetFormat(MoneyFormatter.FORMAT.TEXT_DISABLED)
	else
		private.formatterForTooltip:SetFormat(MoneyFormatter.FORMAT.TEXT)
	end
	return private.formatterForTooltip
		:SetColor(color)
		:ToString(value)
end

---Converts a string money value to a number value (in copper).
---The value passed to this function can contain colored text, but must use g/s/c for the denominations and not icons.
---@param value string The money value to be converted as a string
---@return number
function Money.FromString(value)
	return MoneyFormatter.FromString(value)
end
