-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Utils = LibTSMTypes:Init("CustomString.Utils")
local MoneyFormatter = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local private = {
	sanitizeCache = {},
}

---Sanitizes custom string text.
---@param text string The custom string text
---@return string
function Utils.SanitizeCustomString(text)
	assert(text)
	local result = private.sanitizeCache[text]
	if not result then
		result = strlower(strtrim(tostring(text)))
		result = MoneyFormatter.FromString(result) and gsub(result, String.Escape(MoneyFormatter.GetLargeNumberSeperator()), "") or result
		private.sanitizeCache[text] = result
	end
	return result
end
