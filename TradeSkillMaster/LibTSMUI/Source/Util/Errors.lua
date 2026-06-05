-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Errors = LibTSMUI:Init("Util.Errors")
local L = LibTSMUI.Locale.GetTable()
local CustomString = LibTSMUI:From("LibTSMTypes"):Include("CustomString")
local CUSTOM_STRING_LOOKUP = {
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
-- Module Functions
-- ============================================================================

---Formats a custom string error.
---@param errType EnumValue The error type
---@param errArg? string The error arg
---@return string
function Errors.FormatCustomString(errType, errArg)
	return format(CUSTOM_STRING_LOOKUP[errType], errArg)
end

---Checks custom string dependencies against a list of bad sources.
---@param text string The custom string
---@param badSources table<string,any> A table of price sources (as keys) which aren't allowed to be used
function Errors.CheckCustomStringDependencies(text, badSources)
	for source in pairs(badSources) do
		if CustomString.DependsOnSource(text, source) then
			return format(L["You cannot use '%s' as part of this custom string."], source)
		end
	end
	return nil
end
