-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local String = LibTSMUtil:Init("Lua.String")
local MAGIC_CHARACTERS = {
	["["] = true,
	["]"] = true,
	["("] = true,
	[")"] = true,
	["."] = true,
	["+"] = true,
	["-"] = true,
	["*"] = true,
	["?"] = true,
	["^"] = true,
	["$"] = true,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Splits a string in a way which won't cause stack overflows for large inputs.
---
---The lua strsplit function causes a stack overflow if passed large inputs. This API fixes that issue and also supports
---separators which are more than one character in length.
---@param str string The string to be split
---@param sep string The separator to use to split the string
---@param resultTbl? table An optional table to store the result in
---@return string[]
function String.SafeSplit(str, sep, resultTbl)
	resultTbl = resultTbl or {}
	local s = 1
	local sepLength = #sep
	if sepLength == 0 then
		tinsert(resultTbl, str)
		return resultTbl
	end
	local resultLength = #resultTbl
	while true do
		local e = strfind(str, sep, s, true)
		if not e then
			resultTbl[resultLength+1] = strsub(str, s)
			resultLength = resultLength + 1
			break
		end
		resultTbl[resultLength+1] = strsub(str, s, e - 1)
		resultLength = resultLength + 1
		s = e + sepLength
	end
	assert(#resultTbl == resultLength)
	return resultTbl
end

---Escapes any magic characters used by lua's pattern matching.
---@param str string The string to be escaped
---@return string
function String.Escape(str)
	assert(not strmatch(str, "\001"), "Input string must not contain '\\001' characters")
	str = gsub(str, "%%", "\001")
	for char in pairs(MAGIC_CHARACTERS) do
		str = gsub(str, "%"..char, "%%"..char)
	end
	str = gsub(str, "\001", "%%%%")
	return str
end

---Check if a string which contains multiple values separated by a specific string contains the value.
---@param str string The string to be searched
---@param sep string The separating string
---@param value string The value to search for
---@return boolean
function String.SeparatedContains(str, sep, value)
	return str == value or strmatch(str, "^"..value..sep) or strmatch(str, sep..value..sep) or strmatch(str, sep..value.."$")
end

---Iterates over the parts of a string which are separated by a character.
---@param str string The string to be split
---@param sep string The separator to use to split the string
---@param allowEmpty? boolean Allow empty string parts
---@return fun(): string @An iterator with fields: `part`
function String.SplitIterator(str, sep, allowEmpty)
	assert(#sep == 1)
	if MAGIC_CHARACTERS[sep] then
		sep = "%"..sep
	end
	return gmatch(str, "([^"..sep.."]"..(allowEmpty and "*" or "+")..")")
end

---Generates a pattern matching string from a format string.
---@param str string The format string
---@return string
function String.FormatToMatchPattern(str)
	assert(not strmatch(str, "\001"))
	assert(not strmatch(str, "%%s%%s") and not strmatch(str, "%%s%%d") and not strmatch(str, "%%d%%s"))
	str = gsub(str, "%%%%", "\001")
	str = gsub(str, "%%s", "(.*)")
	str = gsub(str, "%%d", "([0-9]*)")
	assert(not strmatch(str, "%%"))
	str = gsub(str, "\001", "%%")
	return str
end
