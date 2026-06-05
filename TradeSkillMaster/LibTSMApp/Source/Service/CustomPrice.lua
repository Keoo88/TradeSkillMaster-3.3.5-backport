-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local CustomPrice = LibTSMApp:Init("Service.CustomPrice")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local CustomStringFormat = LibTSMApp:From("LibTSMUI"):Include("Util.CustomStringFormat")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local private = {
	settings = nil,
	lastLoopError = nil,
}
local ERR_STR_LOOKUP = {
	[CustomString.ERROR_TYPE.INVALID_TOKEN] = L["Unexpected word ('%s') in custom string."],
	[CustomString.ERROR_TYPE.UNBALANCED_PARENS] = L["There are unbalanced parentheses in this custom string."],
	[CustomString.ERROR_TYPE.INVALID_NUM_ARGS] = L["The '%s' function has an invalid number of arguments."],
	[CustomString.ERROR_TYPE.TOO_MANY_VARS] = L["This custom string is too complex for WoW to handle; use custom sources to simplify it."],
	[CustomString.ERROR_TYPE.INVALID_ITEM_STRING] = L["'%s' is not a valid item argument."],
	[CustomString.ERROR_TYPE.INVALID_CONVERT_ARG] = L["'%s' is not a valid argument for convert()."],
	[CustomString.ERROR_TYPE.NO_ITEM_PARAM_PARENT] = L["The '%s' item parameter was used outside of a custom source."],
	[CustomString.ERROR_TYPE.EMPTY_STRING] = L["Empty custom string."],
	[CustomString.ERROR_TYPE.INVALID_SOURCE] = L["'%s' is not a valid source."],
	[CustomString.ERROR_TYPE.NO_VALUE] = L["No value was returned by the custom price for the specified item."],
	[CustomString.ERROR_TYPE.INVALID_CHARACTER] = L["Custom string names can only contain lowercase letters."],
	[CustomString.ERROR_TYPE.ALREADY_EXISTS] = L["Custom string name '%s' already exists."],
	[CustomString.ERROR_TYPE.RESERVED_WORD] = L["Custom string name '%s' is a reserved word which cannot be used."],
}



-- ============================================================================
-- Module Loading
-- ============================================================================

CustomPrice:OnModuleLoad(function()
	CustomString.SetLoopHandler(private.LoopHandler)
	CustomString.SetFrameTimeFunc(ClientInfo.GetFrameNumber)
	AddonSettings.RegisterOnLoad("Service.CustomPrice", function(db)
		private.settings = db:NewView()
			:AddKey("global", "userData", "customPriceSources")
			:AddKey("global", "userData", "customPriceSourceFormat")
		local removedKeys = TempTable.Acquire()
		CustomString.LoadCustomSources(private.settings.customPriceSources, removedKeys)
		for _, key in ipairs(removedKeys) do
			ChatMessage.PrintfUser(L["Removed custom price source (%s) which has an invalid name."], key)
		end
		TempTable.Release(removedKeys)

		-- Clean up the custom price source formats
		for name in pairs(private.settings.customPriceSourceFormat) do
			if not private.settings.customPriceSources[name] then
				private.settings.customPriceSourceFormat[name] = nil
			end
		end
		for name in pairs(private.settings.customPriceSources) do
			private.settings.customPriceSourceFormat[name] = private.settings.customPriceSourceFormat[name] or "gold"
		end

		-- Configure the format code
		CustomStringFormat.Configure(private.settings.customPriceSourceFormat)
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Validate a custom price name.
---@param name string The custom price name
---@return boolean result
---@return string? errStr
function CustomPrice.ValidateCustomSourceName(name)
	local isValid, errType, errTokenStr = CustomString.ValidateCustomSourceName(name)
	if isValid then
		return true, nil
	else
		return false, format(ERR_STR_LOOKUP[errType], errTokenStr)
	end
end

---Validate a custom price string.
---@param str string The custom price string
---@param badPriceSources? table A table of price sources (as keys) which aren't allowed to be used
---@return boolean result
---@return string? errStr
function CustomPrice.Validate(text, badPriceSources)
	local isValid, errType, errTokenStr = CustomString.Validate(text)
	if not isValid then
		return false, format(ERR_STR_LOOKUP[errType], errTokenStr)
	end
	if badPriceSources then
		for source in pairs(badPriceSources) do
			if CustomString.DependsOnSource(text, source) then
				return false, format(L["You cannot use '%s' as part of this custom string."], source)
			end
		end
	end
	return true, nil
end

---Evaulates a custom string for an item.
---@param str string The custom string
---@param itemString string The item to evaluate the custom string for
---@param allowZero boolean If true, allows the result to be 0
---@return number? value
---@return string? errStr
function CustomPrice.GetValue(str, itemString, allowZero)
	local value, errType, errArg = CustomString.GetValue(str, itemString, allowZero)
	if value then
		return value
	else
		return nil, format(ERR_STR_LOOKUP[errType], errArg)
	end
end



-- ============================================================================
-- Helper Functions
-- ============================================================================

function private.LoopHandler(str)
	if (private.lastLoopError or 0) + 1 < LibTSMApp.GetTime() then
		private.lastLoopError = LibTSMApp.GetTime()
		ChatMessage.PrintUser(L["Loop detected in the following custom price:"].." "..ChatMessage.ColorUserAccentText(str))
	end
end
