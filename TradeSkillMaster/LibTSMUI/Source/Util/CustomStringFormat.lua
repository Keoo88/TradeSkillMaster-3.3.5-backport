-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local CustomStringFormat = LibTSMUI:Init("Util.CustomStringFormat")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local EnumType = LibTSMUI:From("LibTSMUtil"):Include("BaseType.EnumType")
local private = {
	customSourceSettings = nil,
	sourceFormats = {},
}
local FORMAT = EnumType.New("CUSTOM_STRING_FORMAT", {
	GOLD = EnumType.NewValue(),
	NUMBER = EnumType.NewValue(),
	PCT = EnumType.NewValue(),
})
CustomStringFormat.FORMAT = FORMAT



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the custom string format code.
---@param customSourceSettings table<string,string> A table for looking up the format of a custom source
function CustomStringFormat.Configure(customSourceSettings)
	private.customSourceSettings = customSourceSettings
end

---Sets the format for a source.
---@param key string The source key
---@param sourceFormat EnumValue The format
function CustomStringFormat.SetFormat(key, sourceFormat)
	assert(EnumType.IsValue(sourceFormat, FORMAT))
	key = strlower(key)
	private.sourceFormats[key] = sourceFormat
end

---Formats the value of a custom source.
---@param key string The custom source key
---@param value number The value to format
---@return string
function CustomStringFormat.Get(key, value)
	key = strlower(key)
	local customSourceFormat = private.customSourceSettings[key]
	local sourceFormat = nil
	if customSourceFormat then
		if customSourceFormat == "gold" then
			sourceFormat = FORMAT.GOLD
		elseif customSourceFormat == "number" then
			sourceFormat = FORMAT.NUMBER
		elseif customSourceFormat == "pct" then
			sourceFormat = FORMAT.PCT
		else
			error("Invalid custom source format: "..tostring(customSourceFormat))
		end
	else
		sourceFormat = private.sourceFormats[key] or FORMAT.GOLD
	end
	if sourceFormat == FORMAT.GOLD then
		return Money.ToStringForUI(value)
	elseif sourceFormat == FORMAT.NUMBER then
		return floor(value) ~= value and format("%.3f", value) or FormatLargeNumber(value)
	elseif sourceFormat == FORMAT.PCT then
		return Theme.GetAuctionPercentColor(value):ColorText(FormatLargeNumber(value).."%")
	else
		error("Invalid format: "..tostring(sourceFormat))
	end
end
