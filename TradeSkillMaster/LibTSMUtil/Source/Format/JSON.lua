-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local JSON = LibTSMUtil:Init("Format.JSON")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Encodes a value as a JSON string.
---@param value string|number|boolean|table The value to encode
---@return string
function JSON.Encode(value)
	if type(value) == "string" then
		return "\""..private.SanitizeString(value).."\""
	elseif type(value) == "number" or type(value) == "boolean" then
		return tostring(value)
	elseif type(value) == "table" then
		local absCount = 0
		for _ in pairs(value) do
			absCount = absCount + 1
		end
		local tblParts = {}
		if #value == absCount then
			for _, v in ipairs(value) do
				tinsert(tblParts, JSON.Encode(v))
			end
			return "["..table.concat(tblParts, ",").."]"
		else
			for k, v in pairs(value) do
				tinsert(tblParts, "\""..private.SanitizeString(k).."\":"..JSON.Encode(v))
			end
			return "{"..table.concat(tblParts, ",").."}"
		end
	else
		error("Invalid type: "..type(value))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizeString(str)
	str = gsub(str, "\124cff[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]([^\124]+)\124r", "%1")
	str = gsub(str, "[\\]+", "/")
	str = gsub(str, "\"", "'")
	return str
end
