-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local ItemFilterPart = LibTSMService:DefineClassType("ItemFilterPart")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local TYPE = EnumType.New("ITEM_FILTER_PART_TYPE", {
	KEY = EnumType.NewValue(),
	NUMBER = EnumType.NewValue(),
	FUNCTION = EnumType.NewValue(),
})
ItemFilterPart.TYPE = TYPE
---@alias ItemFilterValue string|number|boolean



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new ItemFilterPart which looks for a matching key.
---@param key string The key
---@param exclusiveKey? string A key that this key is exclusive with
---@return ItemFilterPart
function ItemFilterPart.__static.NewKeyMatch(key, exclusiveKey)
	local part = ItemFilterPart(TYPE.KEY, key) ---@type ItemFilterPart
	assert(strlower(key) == key)
	if exclusiveKey then
		part:_SetExclusiveKey(exclusiveKey)
	end
	part:_Commit()
	return part
end

---Creates a new ItemFilterPart which looks for a matching number.
---@param key1 string The key to store the value in
---@param key2? string The key to store a second value in
---@param matchStr? string The pattern string to use
---@return ItemFilterPart
function ItemFilterPart.__static.NewNumberMatch(key1, key2, matchStr)
	local part = ItemFilterPart(TYPE.NUMBER, key1, matchStr) ---@type ItemFilterPart
	if key2 then
		part:_SetKey2(key2)
	end
	part:_Commit()
	return part
end

---Creates a new ItemFilterPart which uses a function to evalulate matches.
---@param key1 string The key to store the value in
---@param key2? string The key to store a second value in
---@param func fun(part: string, arg: any?): ItemFilterValue? The function which evalulates matches
---@param funcArgKey? string A key which must be set before this one and is passed into the function
---@return ItemFilterPart
function ItemFilterPart.__static.NewFunctionMatch(key1, key2, func, funcArgKey, evalFunc)
	local part = ItemFilterPart(TYPE.FUNCTION, key1, func, funcArgKey) ---@type ItemFilterPart
	if key2 then
		part:_SetKey2(key2)
	end
	part:_Commit()
	return part
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ItemFilterPart.__private:__init(partType, key1, ...)
	assert(type(key1) == "string" and key1 ~= "")
	local matchStr, func, funcArgKey = nil, nil, nil
	if partType == TYPE.KEY then
		assert(select("#", ...) == 0)
	elseif partType == TYPE.NUMBER then
		assert(select("#", ...) == 1)
		matchStr = ...
	elseif partType == TYPE.FUNCTION then
		assert(select("#", ...) == 1 or select("#", ...) == 2)
		func, funcArgKey = ...
	else
		error("Invalid type: "..tostring(partType))
	end
	self._type = partType
	self._key1 = key1
	self._key2 = nil
	self._exclusiveKey = nil
	self._matchStr = matchStr
	self._func = func
	self._funcArgKey = funcArgKey
	self._evalFunc = nil
	self._committed = false
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the function which evalulates the filter part.
---@param func fun(item: string, value1: ItemFilterValue, value2?: ItemFilterValue): boolean Function which evalulates the filter part
---@return ItemFilterPart
function ItemFilterPart:SetEvalFunc(func)
	assert(self._committed and not self._evalFunc and func)
	self._evalFunc = func
	return self
end

---Returns whether or not the part has the specified key.
---@param key string The key
---@return boolean
function ItemFilterPart:HasKey(key)
	assert(self._committed)
	return self._key1 == key or self._key2 == key
end

---Handles a symbol for the part and returns whether or not it was valid or nil if it wasn't handled.
---@param symbol string The symbol
---@param data table<string,ItemFilterValue> The data table
---@return boolean?
function ItemFilterPart:HandleSymbol(symbol, data)
	assert(self._committed)
	local value = nil
	if self._type == TYPE.KEY then
		value = strlower(symbol) == self._key1
	elseif self._type == TYPE.NUMBER then
		value = tonumber(strmatch(symbol, self._matchStr))
	elseif self._type == TYPE.FUNCTION then
		if not self._funcArgKey then
			value = self._func(symbol)
		elseif data[self._funcArgKey] then
			value = self._func(symbol, data[self._funcArgKey])
		end
	else
		error("Invalid type: "..tostring(self._type))
	end
	if not value then
		return nil
	elseif self._exclusiveKey and data[self._exclusiveKey] then
		return false
	end
	if not data[self._key1] then
		data[self._key1] = value
	elseif self._key2 and not data[self._key2] then
		data[self._key2] = value
	else
		return false
	end
	return true
end

---Returns whether or not the filter part matches for an item.
---@param item string The item to check
---@param data table<string,ItemFilterValue> The data table
---@param ... any Additional data to pass through to the eval func
---@return boolean
function ItemFilterPart:Matches(item, data, ...)
	assert(self._committed)
	if not self._evalFunc then
		return true
	end
	local val1 = data[self._key1]
	if val1 == nil then
		return true
	end
	return self._evalFunc(item, val1, data[self._key2], ...)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ItemFilterPart:_SetKey2(key2)
	assert(type(key2) == "string" and key2 ~= "")
	assert(not self._committed)
	assert(self._type ~= TYPE.KEY)
	self._key2 = key2
end

function ItemFilterPart:_SetExclusiveKey(exclusiveKey)
	assert(type(exclusiveKey) == "string" and exclusiveKey ~= "")
	assert(not self._committed)
	self._exclusiveKey = exclusiveKey
end

function ItemFilterPart:_Commit()
	self._committed = true
end
