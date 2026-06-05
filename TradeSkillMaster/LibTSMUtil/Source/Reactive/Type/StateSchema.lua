-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactiveStateSchema = LibTSMUtil:DefineClassType("ReactiveStateSchema")
local State = LibTSMUtil:Include("Reactive.Type.State")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new state schema object.
---@param name string The name for debugging purposes
---@return ReactiveStateSchema
function ReactiveStateSchema.__static.Create(name)
	return ReactiveStateSchema(name)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function ReactiveStateSchema.__private:__init(name)
	assert(name)
	self._name = name
	self._committed = false
	self._fieldType = {}
	self._isEnum = {}
	self._default = {}
	self._isOptional = {}
	self._validateFunc = {}
end

function ReactiveStateSchema:__tostring()
	return "ReactiveStateSchema:"..self._name
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Defines a string field as part of the schema.
---@param key string The key of the new field
---@param default string The default value of the field
---@param validateFunc? fun(value: string): boolean A function used to validate values
---@return ReactiveStateSchema
function ReactiveStateSchema:AddStringField(key, default, validateFunc)
	return self:_AddField(key, "string", default, false, validateFunc)
end

---Defines a string field as part of the schema which can be nil (and is by default).
---@param key string The key of the new field
---@param validateFunc? fun(value: string): boolean A function used to validate values
---@return ReactiveStateSchema
function ReactiveStateSchema:AddOptionalStringField(key, validateFunc)
	return self:_AddField(key, "string", nil, true, validateFunc)
end

---Defines a number field as part of the schema.
---@param key string The key of the new field
---@param default number The default value of the field
---@param validateFunc? fun(value: string): boolean A function used to validate values
---@return ReactiveStateSchema
function ReactiveStateSchema:AddNumberField(key, default, validateFunc)
	return self:_AddField(key, "number", default, false, validateFunc)
end

---Defines a number field as part of the schema which can be nil (and is by default).
---@param key string The key of the new field
---@param validateFunc? fun(value: string): boolean A function used to validate values
---@return ReactiveStateSchema
function ReactiveStateSchema:AddOptionalNumberField(key, validateFunc)
	return self:_AddField(key, "number", nil, true, validateFunc)
end

---Defines a boolean field as part of the schema.
---@param key string The key of the new field
---@param default boolean The default value of the field
---@return ReactiveStateSchema
function ReactiveStateSchema:AddBooleanField(key, default)
	return self:_AddField(key, "boolean", default, false)
end

---Defines a boolean field as part of the schema which can be nil (and is by default).
---@param key string The key of the new field
---@return ReactiveStateSchema
function ReactiveStateSchema:AddOptionalBooleanField(key)
	return self:_AddField(key, "boolean", nil, true)
end

---Defines a table field as part of the schema which can be nil (and is by default).
---@param key string The key of the new field
---@param validateFunc? fun(value: string): boolean A function used to validate values
---@return ReactiveStateSchema
function ReactiveStateSchema:AddOptionalTableField(key, validateFunc)
	return self:_AddField(key, "table", nil, true, validateFunc)
end

---Defines an enum field field as part of the schema.
---@param key string The key of the new field
---@param enumType EnumObject The enum type
---@param default EnumValue The default value of the field
---@return ReactiveStateSchema
function ReactiveStateSchema:AddEnumField(key, enumType, default)
	assert(EnumType.IsType(enumType))
	return self:_AddField(key, enumType, default, false)
end

---Defines an enum field field as part of the schema which can be nil (and is by default).
---@param key string The key of the new field
---@param enumType EnumObject The enum type
---@return ReactiveStateSchema
function ReactiveStateSchema:AddOptionalEnumField(key, enumType)
	assert(EnumType.IsType(enumType))
	return self:_AddField(key, enumType, nil, true)
end

---Updates the default value of an existing field.
---@param key string The key of the field
---@param default? boolean The default value of the field
---@return ReactiveStateSchema
function ReactiveStateSchema:UpdateFieldDefault(key, default)
	assert(not self._committed)
	self:_ValidateValueForKey(key, default, true)
	self._default[key] = default
	return self
end

---Commits the schema and prevents further changes.
---@return ReactiveStateSchema
function ReactiveStateSchema:Commit()
	self._committed = true
	return self
end

---Creates a state object based on the schema.
---@return ReactiveState
function ReactiveStateSchema:CreateState()
	assert(self._committed)
	return State.Create(self)
end

---Returns a new state schema which extends the existing one
---@param name string The name of the extended schema
---@return ReactiveStateSchema
function ReactiveStateSchema:Extend(name)
	assert(self._committed)
	local newSchema = ReactiveStateSchema(name)
	for key, fieldType in self:_FieldIterator() do
		newSchema:_AddField(key, fieldType, self._default[key], self._isOptional[key], self._validateFunc[key])
	end
	return newSchema
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ReactiveStateSchema.__private:_AddField(key, fieldType, default, isOptional, validateFunc)
	assert(not self._committed)
	assert(not self._fieldType[key])
	assert(validateFunc == nil or type(validateFunc) == "function")
	self._fieldType[key] = fieldType
	self._isEnum[key] = type(fieldType) == "table"
	self._default[key] = default
	self._isOptional[key] = isOptional
	self._validateFunc[key] = validateFunc
	self:_ValidateValueForKey(key, default, true)
	return self
end

---@private
function ReactiveStateSchema:_ApplyDefaults(data)
	for key in self:_FieldIterator() do
		data[key] = self._default[key]
	end
end

---@private
function ReactiveStateSchema:_ValidateValueForKey(key, value, skipValidateFunc)
	local fieldType = self._fieldType[key]
	local validateFunc = self._validateFunc[key]
	if not fieldType then
		error("Invalid state key: "..tostring(key))
	end
	-- Check the value type
	local isEnum = self._isEnum[key]
	if value == nil and self._isOptional[key] then
		-- Pass
	elseif (not isEnum and type(value) ~= fieldType) or (isEnum and not EnumType.IsValue(value, fieldType)) then
		-- For boolean fields, coerce truthy/falsy values instead of erroring
		if fieldType == "boolean" and value ~= nil then
			value = value and true or false
		else
			error("Invalid type for state key ("..tostring(key).."): "..tostring(value))
		end
	end
	-- Validate the value
	if not skipValidateFunc and value ~= nil and validateFunc and not validateFunc(value) then
		error("Invalid value for state key ("..tostring(key).."): "..tostring(value))
	end
end

---@private
function ReactiveStateSchema:_HasKey(key)
	return self._fieldType[key] ~= nil
end

---@private
function ReactiveStateSchema:_IsBoolean(key)
	return self._fieldType[key] == "boolean"
end

---@private
function ReactiveStateSchema:_GetFieldType(key)
	return self._fieldType[key]
end

---@private
function ReactiveStateSchema:_FieldIterator()
	return pairs(self._fieldType)
end
