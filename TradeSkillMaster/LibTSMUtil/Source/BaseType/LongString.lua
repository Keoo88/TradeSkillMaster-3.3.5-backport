-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local LongString = LibTSMUtil:Init("BaseType.LongString")
local String = LibTSMUtil:Include("Lua.String")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Encodes a long list of values into a string or array of strings as needed.
---@param values string[] The values to encode
---@param sep string The separator to use
---@param maxValues number The maximum values to encode into a single array entry
---@return string|string[]
function LongString.Encode(values, sep, maxValues)
	assert(type(values) == "table" and #sep == 1)
	if #values == 0 then
		return nil
	elseif #values <= maxValues then
		return table.concat(values, sep)
	else
		local result = {}
		for i = 1, #values, maxValues do
			local endIndex = min(i + maxValues - 1, #values)
			tinsert(result, table.concat(values, sep, i, endIndex))
		end
		return result
	end
end

---Decodes a previously-encoded string or array of strings into the raw values.
---@param value string|string[] The encoded values
---@param sep string The separator to use
---@return string[]
function LongString.Decode(value, sep)
	local result = {}
	if type(value) == "string" then
		String.SafeSplit(value, sep, result)
	elseif type(value) == "table" then
		for _, part in ipairs(value) do
			String.SafeSplit(part, sep, result)
		end
	else
		assert(value == nil)
	end
	return result
end
