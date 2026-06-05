-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local EnumType = LibTSMUtil:Init("BaseType.EnumType")
local private = {
	typeStr = {},
	valueStr = {},
	valueTypeMap = {},
}
local TEMP_VALUE = newproxy(false)
---@class EnumObject
---@class EnumValue



-- ============================================================================
-- Metatables
-- ============================================================================

local TYPE_MT = {
	__newindex = function()
		error("Enum is read-only")
	end,
	__index = function(_, key)
		error("Unknown enum value: "..tostring(key))
	end,
	__tostring = function(self)
		return private.typeStr[self]
	end,
	__metatable = newproxy(false),
}
local VALUE_MT = {
	__newindex = function()
		error("Enum value is read-only")
	end,
	__index = function(_, key)
		-- Wow's table inspector checks for this key - so just silently ignore it
		if key == "GetDebugName" then
			return nil
		end
		error("Unknown enum value: "..tostring(key))
	end,
	__tostring = function(self)
		local str = private.valueStr[self]
		if not str then
			error("Invalid enum value")
		end
		return str
	end,
	__metatable = newproxy(false)
}
local EQ_METHOD = function(obj1, obj2)
	-- Make sure they are both enum values
	if not private.valueStr[obj1] or not private.valueStr[obj2] then
		return false
	end
	-- Check if one is a parent of the other
	local type1 = private.valueTypeMap[obj1]
	local type2 = private.valueTypeMap[obj2]
	while type1 or type2 do
		if (type1 and rawequal(type1, obj2)) or (type2 and rawequal(type2, obj1)) then
			return true
		end
		type1 = type1 and private.valueTypeMap[type1]
		type2 = type2 and private.valueTypeMap[type2]
	end
	return false
end
local NESTED_TYPE_MT = CopyTable(TYPE_MT)
NESTED_TYPE_MT.__eq = EQ_METHOD
local NESTED_VALUE_MT = CopyTable(VALUE_MT)
NESTED_VALUE_MT.__eq = EQ_METHOD



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates an enum object.
---@generic T
---@param name string
---@param values T
---@return T
function EnumType.New(name, values)
	private.CreateType(name, values, false)
	for key in pairs(values) do
		private.TrackValue(values, key, false)
	end
	return values
end

---Creates an enum object which allows for nested values (performance will be worse).
---@generic T
---@param name string
---@param values T
---@return T
function EnumType.NewNested(name, values)
	private.CreateType(name, values, true)
	for key in pairs(values) do
		private.TrackValue(values, key, true)
	end
	return values
end

---Creates a new enum value for use while defining a new type.
---@return EnumValue
function EnumType.NewValue()
	return TEMP_VALUE
end

---Returns whether or not the passed value is an enum type.
---@param value EnumObject|any The value to check
---@return boolean
function EnumType.IsType(value)
	return private.typeStr[value] and not private.valueTypeMap[value] and type(value) == "table" and getmetatable(value) == TYPE_MT.__metatable
end

---Check if the value belongs to the specified enum type.
---@param value EnumValue|any The enum value
---@param enumType EnumObject The enum type
function EnumType.IsValue(value, enumType)
	assert(EnumType.IsType(enumType))
	-- Walk up the tree to handle nested enums
	local checkType = private.valueTypeMap[value]
	while checkType do
		if checkType == enumType then
			return true
		end
		checkType = private.valueTypeMap[checkType]
	end
	return false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CreateType(name, values, isNested)
	assert(type(name) == "string" and type(values) == "table")
	assert(not private.typeStr[values] and not private.valueTypeMap[values])
	private.typeStr[values] = name
	setmetatable(values, isNested and NESTED_TYPE_MT or TYPE_MT)
end

function private.TrackValue(parentType, key, isNested)
	local value = parentType[key]
	if type(value) == "table" then
		-- Recurse for a nested type
		assert(isNested and next(value))
		local name = tostring(parentType).."."..key
		private.CreateType(name, value, isNested)
		private.valueStr[value] = name
		private.valueTypeMap[value] = parentType
		for key2 in pairs(value) do
			private.TrackValue(value, key2, isNested)
		end
	else
		assert(type(key) == "string" and value == TEMP_VALUE)
		value = setmetatable({}, isNested and NESTED_VALUE_MT or VALUE_MT)
		parentType[key] = value
		assert(not private.valueStr[value] and not private.valueTypeMap[value])
		private.valueStr[value] = tostring(parentType).."."..key
		private.valueTypeMap[value] = parentType
	end
end
