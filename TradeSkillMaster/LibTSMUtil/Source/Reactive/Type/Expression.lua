-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Expression = LibTSMUtil:Init("Reactive.Type.Expression")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local Table = LibTSMUtil:Include("Lua.Table")
local private = {
	cache = {},
	currentSchema = nil,
	currentContext = nil,
	localsTemp = {},
}



-- ============================================================================
-- Expression Environment
-- ============================================================================

local EXPRESSION_ENV = setmetatable({}, {
	__index = function(_, key)
		error("Attempt to access global from expression: "..tostring(key), 2)
	end,
	__newindex = function(_, key)
		error("Attempt to set global from expression: "..tostring(key), 2)
	end,
	__metatable = false,
})



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates an expression.
---@param expression string A valid lua expression which can only access fields of the state (as globals)
---@param schema ReactiveStateSchema The state schema
---@return fun(state: table, funcArg: any): any func
---@return table<string,true>|string keys
---@return any funcArg
function Expression.Create(expression, schema)
	private.cache[schema] = private.cache[schema] or {}
	if not private.cache[schema][expression] then
		private.Compile(expression, schema)
	end
	local info = private.cache[schema][expression]
	return info.func, info.keys, info.funcArg
end




-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param schema ReactiveStateSchema
function private.Compile(expression, schema)
	local origExpression = expression
	assert(not strmatch(expression, "__state") and not strmatch(expression, "__context"))
	-- Replace EnumEquals()/GlobalString() function calls
	local context = {}
	private.currentSchema = schema
	private.currentContext = context
	expression = gsub(expression, "EnumEquals%(([^%)]+),([^%)]+)%)", private.EnumEqualsSub)
	expression = gsub(expression, "GlobalString%(([^%)]+)%)", private.GlobalStringSub)
	private.currentSchema = nil
	private.currentContext = nil
	local keys = {}
	assert(not next(private.localsTemp))
	for key in gmatch(expression, "\"?[a-zA-Z0-9_%.]+\"?") do
		if strsub(key, 1, 1) == "\"" and strsub(key, -1) == "\"" then
			-- This is a string literal
		elseif tonumber(key) then
			-- This is just a number constant
		elseif key == "or" or key == "and" or key == "not" or key == "false" or key == "true" or key == "nil" then
			-- Valid lua keyword
		else
			local contextKey = strmatch(key, "^[^%.]+")
			if context[contextKey] then
				-- Context key
				assert(not schema:_HasKey(contextKey))
				if not private.localsTemp[contextKey] then
					tinsert(private.localsTemp, "local "..contextKey.." = __context."..contextKey)
					private.localsTemp[contextKey] = true
				end
			else
				-- State key
				keys[key] = true
			end
		end
	end
	local numKeys = Table.Count(keys)
	assert(numKeys > 0)
	if numKeys == 1 then
		keys = next(keys)
		assert(not private.localsTemp[keys])
		expression = "local "..keys..", __context = ...\n"..table.concat(private.localsTemp, "\n").."\nreturn "..expression
	else
		for key in pairs(keys) do
			assert(not private.localsTemp[key])
			tinsert(private.localsTemp, "local "..key.." = __state."..key)
			private.localsTemp[key] = true
		end
		expression = "local __state, __context = ...\n"..table.concat(private.localsTemp, "\n").."\nreturn "..expression
	end
	wipe(private.localsTemp)
	local func = assert(loadstring(expression, origExpression))
	setfenv(func, EXPRESSION_ENV)
	private.cache[schema][origExpression] = {
		func = func,
		keys = keys,
		funcArg = context,
	}
end

function private.EnumEqualsSub(stateKey, valueKey)
	stateKey = strtrim(stateKey)
	valueKey = strtrim(valueKey)
	local enumType = private.currentSchema:_GetFieldType(stateKey)
	assert(enumType and EnumType.IsType(enumType))
	local enumValue = enumType[valueKey]
	assert(enumValue)
	local enumName = tostring(enumType)
	assert(not private.currentContext[enumName] or private.currentContext[enumName] == enumType)
	private.currentContext[enumName] = enumType
	return format("(%s == %s.%s)", stateKey, enumName, valueKey)
end

function private.GlobalStringSub(globalKey)
	globalKey = strtrim(globalKey)
	local value = _G[globalKey]
	assert(type(value) == "string")
	assert(not private.currentContext[globalKey] or private.currentContext[globalKey] == value)
	private.currentContext[globalKey] = value
	return globalKey
end
