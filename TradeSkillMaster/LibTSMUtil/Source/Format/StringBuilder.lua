-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local StringBuilder = LibTSMUtil:DefineClassType("StringBuilder")
local private = {
	argsTemp = {},
	argNamesTemp = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new string builder object.
---@return StringBuilder
function StringBuilder.__static.Create()
	return StringBuilder()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function StringBuilder.__private:__init()
	self._template = nil
	self._args = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the template.
---@param template str The template string to format
---@return StringBuilder
function StringBuilder:SetTemplate(template)
	assert(type(template) == "string")
	assert(not self._template and not next(self._args))
	self._template = template
	return self
end

---Sets the value of a named parameter.
---@param name string The parameter name
---@param value any The parameter value
---@return StringBuilder
function StringBuilder:SetParam(name, value)
	assert(self._template)
	assert(type(name) == "string" and value ~= nil)
	self._args[name] = value
	return self
end

---Commits the string builder and returns the generated string.
---@return string
function StringBuilder:Commit()
	assert(self._template)
	assert(not next(private.argsTemp) and not next(private.argNamesTemp))
	-- This is inspired by http://lua-users.org/wiki/StringInterpolation
	local result = gsub(self._template, "%%%((%a%w*)%)([-0-9%.]*[cdeEfgGiouxXsq])", private.FormatHelper)
	local args = private.argsTemp
	for _, argName in ipairs(private.argNamesTemp) do
		local value = self._args[argName]
		if value == nil then
			error(format("Named parameter '%s' not provided", tostring(argName)))
		end
		tinsert(args, value)
	end
	result = format(result, unpack(args))
	wipe(private.argsTemp)
	wipe(private.argNamesTemp)
	self._template = nil
	wipe(self._args)
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FormatHelper(name, fmtStr)
	tinsert(private.argNamesTemp, name)
	return "%"..fmtStr
end
