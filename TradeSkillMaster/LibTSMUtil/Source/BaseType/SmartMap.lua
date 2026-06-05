-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local SmartMap = LibTSMUtil:DefineClassType("SmartMap")
local private = {
	readerContext = {}, ---@type table<SmartMapReader,SmartMapReaderContext>
}
local VALID_KEY_TYPES = { ---@type table<SmartMapKeyType,true>
	string = true,
	number = true,
}
local VALID_VALUE_TYPES = { ---@type table<SmartMapValueType,true>
	string = true,
	number = true,
	boolean = true,
}

---@class SmartMapReaderContext
---@field map SmartMapReader
---@field callback? fun(reader: SmartMapReader, pendingChanges: table)
---@field pendingChanges table<SmartMapKeyType,SmartMapValueType>

---@alias SmartMapKeyType
---|'"string"'
---|'"number"'

---@alias SmartMapValueType
---|'"string"'
---|'"number"'
---|'"boolean"'



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Create a new smart map object.
---@generic K, V
---@param keyType SmartMapKeyType The type of the keys
---@param valueType SmartMapValueType The type of the values
---@param lookupFunc fun(key: K): V A function which looks up the value for a specific key
---@return SmartMap
function SmartMap.__static.New(keyType, valueType, lookupFunc)
	assert(VALID_KEY_TYPES[keyType] and VALID_VALUE_TYPES[valueType])
	return SmartMap(keyType, valueType, lookupFunc)
end



-- ============================================================================
-- SmartMapReader Metatable
-- ============================================================================

---@class SmartMapReader

local READER_MT = {
	__index = function(self, key)
		-- check if the map already has the value for this key cached
		local readerContext = private.readerContext[self]
		local value = readerContext.map:_Get(key)
		-- Cache the value on this reader
		rawset(self, key, value)
		return value
	end,
	__call = function(self, key)
		return self[key]
	end,
	__newindex = function()
		error("Reader is read-only", 2)
	end,
	__tostring = function(self)
		return "SmartMapReader:"..strmatch(tostring(private.readerContext[self]), "table:[^0-9a-fA-F]*([0-9a-fA-F]+)")
	end,
	__metatable = false,
}



-- ============================================================================
-- SmartMap Class Meta Methods
-- ============================================================================

function SmartMap.__private:__init(keyType, valueType, lookupFunc)
	self._keyType = keyType
	self._valueType = valueType
	self._func = lookupFunc
	self._data = {}
	self._readers = {} ---@type SmartMapReader[]
	self._callbacksPaused = 0
	self._hasReaderCallback = false
end



-- ============================================================================
-- SmartMap Public Class Methods
-- ============================================================================

---Called when the value has changed for a given key to fetch the new one and notify the readers.
---@param key SmartMapKeyType The key which changed
function SmartMap:ValueChanged(key)
	local oldValue = self._data[key]
	if oldValue == nil then
		-- nobody cares about this value
		return
	end

	if not self._hasReaderCallback then
		-- no reader has registered a callback, so just clear the value
		self._data[key] = nil
		for _, reader in ipairs(self._readers) do
			rawset(reader, key, nil)
		end
		return
	end

	-- get the new value
	local newValue = self._func(key)
	if type(newValue) ~= self._valueType then
		error(format("Invalid type (got %s, expected %s)", type(newValue), self._valueType))
	end
	if oldValue == newValue then
		-- the value didn't change
		return
	end

	-- update the data
	self._data[key] = newValue

	for _, reader in ipairs(self._readers) do
		local readerContext = private.readerContext[reader]
		local prevValue = rawget(reader, key)
		if prevValue ~= nil then
			rawset(reader, key, newValue)
			if readerContext.callback then
				readerContext.pendingChanges[key] = prevValue
				if self._callbacksPaused == 0 then
					readerContext.callback(reader, readerContext.pendingChanges)
					wipe(readerContext.pendingChanges)
				end
			end
		end
	end
end

---Pausese or unpauses reader callbacks.
---@param paused boolean Whether or not callbacks are paused
function SmartMap:SetCallbacksPaused(paused)
	if paused then
		self._callbacksPaused = self._callbacksPaused + 1
	else
		self._callbacksPaused = self._callbacksPaused - 1
		assert(self._callbacksPaused >= 0)
		if self._callbacksPaused == 0 then
			for _, reader in ipairs(self._readers) do
				local readerContext = private.readerContext[reader]
				if readerContext.callback and next(readerContext.pendingChanges) then
					readerContext.callback(reader, readerContext.pendingChanges)
					wipe(readerContext.pendingChanges)
				end
			end
		end
	end
end

---Creates a new reader.
---@param callback? fun(reader: SmartMapReader, pendingChanges: table) The function to call when a value within the map changes
---@return SmartMapReader
function SmartMap:CreateReader(callback)
	assert(callback == nil or type(callback) == "function")
	local reader = setmetatable({}, READER_MT)
	tinsert(self._readers, reader)
	self._hasReaderCallback = self._hasReaderCallback or (callback and true or false)
	private.readerContext[reader] = {
		map = self,
		callback = callback,
		pendingChanges = {},
	}
	return reader
end

---Gets the type of the smart map's keys.
---@return SmartMapKeyType
function SmartMap:GetKeyType()
	return self._keyType
end

---Gets the type of the smart map's values.
---@return SmartMapValueType
function SmartMap:GetValueType()
	return self._valueType
end

---Iterates over all data in the smart map.
---@return fun(): SmartMapKeyType, SmartMapValueType @An iterator with fields: `key`, `value`
function SmartMap:Iterator()
	return pairs(self._data)
end

---Invalidates all data in the smart map.
function SmartMap:Invalidate()
	self:SetCallbacksPaused(true)
	for key in pairs(self._data) do
		self:ValueChanged(key)
	end
	self:SetCallbacksPaused(false)
end



-- ============================================================================
-- SmartMap Private Class Methods
-- ============================================================================

function SmartMap:_Get(key)
	local value = self._data[key]
	if value ~= nil then
		return value
	end

	-- Use the function to get the value for this key
	value = self._func(key)
	if value == nil then
		error(format("No value for key (%s)", tostring(key)))
	elseif type(value) ~= self._valueType then
		error(format("Invalid type of value (got %s, expected %s): %s", type(value), self._valueType, tostring(value)))
	end

	-- Cache the value on the map
	self._data[key] = value
	return value
end
