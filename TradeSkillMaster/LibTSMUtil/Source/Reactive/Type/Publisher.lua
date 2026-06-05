-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local ReactivePublisher = LibTSMUtil:DefineClassType("ReactivePublisher")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local ObjectPool = LibTSMUtil:IncludeClassType("ObjectPool")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local private = {
	publisherObjectPool = ObjectPool.New("PUBLISHER", ReactivePublisher, 1),
	freeStepTempTables = {},
}
local STATE = EnumType.New("PUBLISHER_STATE", {
	INIT = EnumType.NewValue(),
	ACQUIRED = EnumType.NewValue(),
	STEPS = EnumType.NewValue(),
	HANDLED = EnumType.NewValue(),
	STORED = EnumType.NewValue(),
})
local STEP = EnumType.New("PUBLISHER_STEP", {
	MAP_WITH_FUNCTION = EnumType.NewValue(),
	MAP_WITH_METHOD = EnumType.NewValue(),
	MAP_WITH_OBJECT_METHOD = EnumType.NewValue(),
	MAP_WITH_KEY = EnumType.NewValue(),
	MAP_WITH_KEY_COALESCED = EnumType.NewValue(),
	MAP_WITH_LOOKUP_TABLE = EnumType.NewValue(),
	MAP_BOOLEAN_WITH_VALUES = EnumType.NewValue(),
	MAP_BOOLEAN_EQUALS = EnumType.NewValue(),
	MAP_BOOLEAN_NOT_EQUALS = EnumType.NewValue(),
	MAP_BOOLEAN_GREATER_THAN_OR_EQUALS = EnumType.NewValue(),
	MAP_TO_BOOLEAN = EnumType.NewValue(),
	MAP_TO_VALUE = EnumType.NewValue(),
	MAP_NIL_TO_VALUE = EnumType.NewValue(),
	MAP_NON_NIL_WITH_FUNCTION = EnumType.NewValue(),
	MAP_NON_NIL_WITH_METHOD = EnumType.NewValue(),
	INVERT_BOOLEAN = EnumType.NewValue(),
	IGNORE_IF_KEY_EQUALS = EnumType.NewValue(),
	IGNORE_IF_KEY_NOT_EQUALS = EnumType.NewValue(),
	IGNORE_IF_NOT_KEY_IN_TABLE = EnumType.NewValue(),
	IGNORE_IF_NOT_EQUALS = EnumType.NewValue(),
	IGNORE_NIL = EnumType.NewValue(),
	IGNORE_WITH_FUNCTION = EnumType.NewValue(),
	IGNORE_DUPLICATES = EnumType.NewValue(),
	IGNORE_DUPLICATES_WITH_KEYS = EnumType.NewValue(),
	IGNORE_DUPLICATES_WITH_METHOD = EnumType.NewValue(),
	MAP_LATEST_TO_PUBLISHER = EnumType.NewValue(),
	PRINT = EnumType.NewValue(),
	START_PROFILING = EnumType.NewValue(),
	SHARE = EnumType.NewValue(),
	CALL_METHOD = EnumType.NewValue(),
	CALL_METHOD_IF_NOT_NIL = EnumType.NewValue(),
	CALL_METHOD_FOR_EACH_LIST_VALUE = EnumType.NewValue(),
	CALL_FUNCTION = EnumType.NewValue(),
	UNPACK_AND_CALL_FUNCTION = EnumType.NewValue(),
	UNPACK_AND_CALL_METHOD = EnumType.NewValue(),
	ASSIGN_TO_TABLE_KEY = EnumType.NewValue(),
	SET_SINGLE_TABLE_KEY = EnumType.NewValue(),
	SEND_TO_PUBLISHER = EnumType.NewValue(),
})
local STEP_RESULTING_STATE = {
	[STEP.MAP_WITH_FUNCTION] = STATE.STEPS,
	[STEP.MAP_WITH_METHOD] = STATE.STEPS,
	[STEP.MAP_WITH_OBJECT_METHOD] = STATE.STEPS,
	[STEP.MAP_WITH_KEY] = STATE.STEPS,
	[STEP.MAP_WITH_KEY_COALESCED] = STATE.STEPS,
	[STEP.MAP_WITH_LOOKUP_TABLE] = STATE.STEPS,
	[STEP.MAP_BOOLEAN_WITH_VALUES] = STATE.STEPS,
	[STEP.MAP_BOOLEAN_EQUALS] = STATE.STEPS,
	[STEP.MAP_BOOLEAN_NOT_EQUALS] = STATE.STEPS,
	[STEP.MAP_BOOLEAN_GREATER_THAN_OR_EQUALS] = STATE.STEPS,
	[STEP.MAP_TO_BOOLEAN] = STATE.STEPS,
	[STEP.MAP_TO_VALUE] = STATE.STEPS,
	[STEP.MAP_NIL_TO_VALUE] = STATE.STEPS,
	[STEP.MAP_NON_NIL_WITH_FUNCTION] = STATE.STEPS,
	[STEP.MAP_NON_NIL_WITH_METHOD] = STATE.STEPS,
	[STEP.INVERT_BOOLEAN] = STATE.STEPS,
	[STEP.IGNORE_IF_KEY_EQUALS] = STATE.STEPS,
	[STEP.IGNORE_IF_KEY_NOT_EQUALS] = STATE.STEPS,
	[STEP.IGNORE_IF_NOT_KEY_IN_TABLE] = STATE.STEPS,
	[STEP.IGNORE_IF_NOT_EQUALS] = STATE.STEPS,
	[STEP.IGNORE_NIL] = STATE.STEPS,
	[STEP.IGNORE_WITH_FUNCTION] = STATE.STEPS,
	[STEP.IGNORE_DUPLICATES] = STATE.STEPS,
	[STEP.IGNORE_DUPLICATES_WITH_KEYS] = STATE.STEPS,
	[STEP.IGNORE_DUPLICATES_WITH_METHOD] = STATE.STEPS,
	[STEP.MAP_LATEST_TO_PUBLISHER] = STATE.STEPS,
	[STEP.PRINT] = STATE.STEPS,
	[STEP.START_PROFILING] = STATE.STEPS,
	[STEP.SHARE] = STATE.STEPS,
	[STEP.CALL_METHOD] = STATE.HANDLED,
	[STEP.CALL_METHOD_IF_NOT_NIL] = STATE.HANDLED,
	[STEP.CALL_METHOD_FOR_EACH_LIST_VALUE] = STATE.HANDLED,
	[STEP.CALL_FUNCTION] = STATE.HANDLED,
	[STEP.UNPACK_AND_CALL_FUNCTION] = STATE.HANDLED,
	[STEP.UNPACK_AND_CALL_METHOD] = STATE.HANDLED,
	[STEP.ASSIGN_TO_TABLE_KEY] = STATE.HANDLED,
	[STEP.SET_SINGLE_TABLE_KEY] = STATE.HANDLED,
	[STEP.SEND_TO_PUBLISHER] = STATE.HANDLED,
}
local UNOPTIMIZABLE_STEPS = {
	[STEP.MAP_WITH_FUNCTION] = true,
	[STEP.MAP_WITH_METHOD] = true,
	[STEP.MAP_WITH_OBJECT_METHOD] = true,
	[STEP.MAP_BOOLEAN_WITH_VALUES] = true,
	[STEP.MAP_BOOLEAN_EQUALS] = true,
	[STEP.MAP_BOOLEAN_NOT_EQUALS] = true,
	[STEP.MAP_BOOLEAN_GREATER_THAN_OR_EQUALS] = true,
	[STEP.IGNORE_IF_NOT_KEY_IN_TABLE] = true,
	[STEP.IGNORE_IF_NOT_EQUALS] = true,
	[STEP.IGNORE_WITH_FUNCTION] = true,
	[STEP.MAP_WITH_LOOKUP_TABLE] = true,
	[STEP.MAP_LATEST_TO_PUBLISHER] = true,
	[STEP.MAP_NON_NIL_WITH_FUNCTION] = true,
	[STEP.MAP_NON_NIL_WITH_METHOD] = true,
}
local OPTIMIZATION_IGNORED_STEPS = {
	[STEP.IGNORE_NIL] = true,
	[STEP.PRINT] = true,
	[STEP.START_PROFILING] = true,
	[STEP.MAP_TO_BOOLEAN] = true,
	[STEP.INVERT_BOOLEAN] = true,
	[STEP.SHARE] = true,
}
local ON_HANDLED_IGNORED_FOR_STEP = {
	[STEP.SEND_TO_PUBLISHER] = true,
}
local STEP_DATA_SIZE = 3
local INITIAL_IGNORE_VALUE = newproxy()



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a publisher object.
---@param subject ReactiveStream|ReactiveState The subject which is publishing values
---@return ReactivePublisher
function ReactivePublisher.__static.Get(subject)
	local publisher = private.publisherObjectPool:Get()
	publisher:_Acquire(subject)
	return publisher
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function ReactivePublisher.__private:__init()
	self._subject = nil
	self._state = STATE.INIT
	self._shareStep = nil
	self._stepData = {}
	self._numSteps = 0
	self._hasOptimizeKeys = false
	self._optimizeKeys = {}
	self._stepTempTables = {}
end

function ReactivePublisher.__private:_Acquire(subject)
	self._subject = subject
	self._state = STATE.ACQUIRED
end

function ReactivePublisher.__private:_Release()
	assert(self._state == STATE.STORED)
	self._state = STATE.INIT
	self._subject = nil
	self._numSteps = 0
	self._shareStep = nil
	self._hasOptimizeKeys = false
	wipe(self._stepData)
	wipe(self._optimizeKeys)
	for _, tbl in ipairs(self._stepTempTables) do
		wipe(tbl)
		tinsert(private.freeStepTempTables, tbl)
	end
	wipe(self._stepTempTables)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Map published values to another value using a function.
---@param func fun(value: any, arg: any): any The mapping function which takes the published values and returns the results
---@param arg any An additional argument to pass to the function
---@return ReactivePublisher
function ReactivePublisher:MapWithFunction(func, arg)
	assert(type(func) == "function")
	return self:_AddStepHelper(STEP.MAP_WITH_FUNCTION, func, arg)
end

---Maps published values by calling a method on it.
---@param method string The name of the method to call on the published values
---@param arg any An additional argument to pass to the method
---@return ReactivePublisher
function ReactivePublisher:MapWithMethod(method, arg)
	assert(type(method) == "string")
	return self:_AddStepHelper(STEP.MAP_WITH_METHOD, method, arg)
end

---Maps published values by calling a method on an object with it.
---@param obj table The object to call the method on
---@param method string The name of the method to call with the published values
---@return ReactivePublisher
function ReactivePublisher:MapWithObjectMethod(obj, method)
	assert(type(obj) == "tabble" and type(method) == "string")
	return self:_AddStepHelper(STEP.MAP_WITH_OBJECT_METHOD, method)
end

---Maps published values by indexing it with the specified key.
---@param key string|number The key to index the published values with
---@return ReactivePublisher
function ReactivePublisher:MapWithKey(key)
	assert(type(key) == "string" or type(key) == "number")
	return self:_AddStepHelper(STEP.MAP_WITH_KEY, key)
end

---Map published values by indexing it with two keys, keeping the first value one which is non-nil.
---@param key1 string The first key to index the published values with
---@param key2 string The second key to index the published values with
---@return ReactivePublisher
function ReactivePublisher:MapWithKeyCoalesced(key1, key2)
	return self:_AddStepHelper(STEP.MAP_WITH_KEY_COALESCED, key1, key2)
end

---Maps published values by using them as a key to a lookup table.
---@param tbl table The lookup table
---@return ReactivePublisher
function ReactivePublisher:MapWithLookupTable(tbl)
	assert(type(tbl) == "table")
	return self:_AddStepHelper(STEP.MAP_WITH_LOOKUP_TABLE, tbl)
end

---Map published boolean values to the specified true / false values.
---@param trueValue any The value to map to if true
---@param falseValue any The value to map to if false
---@return ReactivePublisher
function ReactivePublisher:MapBooleanWithValues(trueValue, falseValue)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_WITH_VALUES, trueValue, falseValue)
end

---Map published values to a boolean based on whether or not it equals the specified value.
---@param value any The value to compare with
---@return ReactivePublisher
function ReactivePublisher:MapBooleanEquals(value)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_EQUALS, value)
end

---Map published values to a boolean based on whether or not it equals the specified value.
---@param value any The value to compare with
---@return ReactivePublisher
function ReactivePublisher:MapBooleanNotEquals(value)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_NOT_EQUALS, value)
end

---Map published values to a boolean based on whether or not it is greater than or equal to the specified value.
---@param value any The value to compare with
---@return ReactivePublisher
function ReactivePublisher:MapBooleanGreaterThanOrEquals(value)
	return self:_AddStepHelper(STEP.MAP_BOOLEAN_GREATER_THAN_OR_EQUALS, value)
end

---Map published values to a boolean based on whether or not it's truthy.
---@return ReactivePublisher
function ReactivePublisher:MapToBoolean()
	return self:_AddStepHelper(STEP.MAP_TO_BOOLEAN)
end

---Map published values to a specific value.
---@param value any The value to map to
---@return ReactivePublisher
function ReactivePublisher:MapToValue(value)
	return self:_AddStepHelper(STEP.MAP_TO_VALUE, value)
end

---Map nil published values to a specific value.
---@param value any The value to map to
---@return ReactivePublisher
function ReactivePublisher:MapNilToValue(value)
	return self:_AddStepHelper(STEP.MAP_NIL_TO_VALUE, value)
end

---Map non-nil published values to another value using a function and passes nil values straight through.
---@param func fun(value: any): any The mapping function which takes the published values and returns the results
---@param arg any An additional argument to pass to the method
---@return ReactivePublisher
function ReactivePublisher:MapNonNilWithFunction(func, arg)
	assert(type(func) == "function")
	return self:_AddStepHelper(STEP.MAP_NON_NIL_WITH_FUNCTION, func, arg)
end

---Map non-nil published values to another value by calling a method on them and passes nil values straight through.
---@param method string The name of the method to call on the published values
---@param arg any An additional argument to pass to the method
---@return ReactivePublisher
function ReactivePublisher:MapNonNilWithMethod(method, arg)
	assert(type(method) == "string")
	return self:_AddStepHelper(STEP.MAP_NON_NIL_WITH_METHOD, method, arg)
end

---Invert published boolean values.
---@return ReactivePublisher
function ReactivePublisher:InvertBoolean()
	return self:_AddStepHelper(STEP.INVERT_BOOLEAN)
end

---Ignores published values where a specified key equals the specified value.
---@param key string The key to compare at
---@param value any The value to compare with
---@return ReactivePublisher
function ReactivePublisher:IgnoreIfKeyEquals(key, value)
	assert(type(key) == "string" or type(key) == "number")
	return self:_AddStepHelper(STEP.IGNORE_IF_KEY_EQUALS, key, value)
end

---Ignores published values where a specified key does not equal the specified value.
---@param key string The key to compare at
---@param value any The value to compare with
---@return ReactivePublisher
function ReactivePublisher:IgnoreIfKeyNotEquals(key, value)
	assert(type(key) == "string" or type(key) == "number")
	return self:_AddStepHelper(STEP.IGNORE_IF_KEY_NOT_EQUALS, key, value)
end

---Ignores published values which don't exist as a key within the specified table.
---@param tbl table The table to check within
---@return ReactivePublisher
function ReactivePublisher:IgnoreIfNotKeyInTable(tbl)
	assert(type(tbl) == "table")
	return self:_AddStepHelper(STEP.IGNORE_IF_NOT_KEY_IN_TABLE, tbl)
end

---Ignores published values which don't equal the specified value.
---@param value any The value to compare against
---@return ReactivePublisher
function ReactivePublisher:IgnoreIfNotEquals(value)
	return self:_AddStepHelper(STEP.IGNORE_IF_NOT_EQUALS, value)
end

---Ignores published values if it's nil.
---@return ReactivePublisher
function ReactivePublisher:IgnoreNil()
	return self:_AddStepHelper(STEP.IGNORE_NIL)
end

---Ignores published values if the specified function doesn't return true.
---@param func fun(value: any): boolean The function which takes the published values and returns true/false
---@return ReactivePublisher
function ReactivePublisher:IgnoreWithFunction(func)
	assert(type(func) == "function")
	return self:_AddStepHelper(STEP.IGNORE_WITH_FUNCTION, func)
end

---Ignores duplicate published values.
---@return ReactivePublisher
function ReactivePublisher:IgnoreDuplicates()
	return self:_AddStepHelper(STEP.IGNORE_DUPLICATES, INITIAL_IGNORE_VALUE)
end

---Ignores duplicate published values by checking the specified keys.
---@param ... string Keys to compare to detect duplicate published values
---@return ReactivePublisher
function ReactivePublisher:IgnoreDuplicatesWithKeys(...)
	local keys = self:_GetStepTempTable()
	Vararg.IntoTable(keys, ...)
	assert(#keys > 0)
	for _, key in ipairs(keys) do
		assert(type(key) == "string" and keys[key] == nil)
		keys[key] = INITIAL_IGNORE_VALUE
	end
	return self:_AddStepHelper(STEP.IGNORE_DUPLICATES_WITH_KEYS, keys)
end

---Ignores duplicate published values by calling the specified method.
---@param method string The method to call on the published values
---@return ReactivePublisher
function ReactivePublisher:IgnoreDuplicatesWithMethod(method)
	assert(type(method) == "string")
	return self:_AddStepHelper(STEP.IGNORE_DUPLICATES_WITH_METHOD, method)
end

---Maps values to another publisher by calling the specified function.
---@param func fun(value: any): ReactivePublisher The function which takes the published values and returns a new publisher
function ReactivePublisher:MapToPublisherWithFunction(func)
	assert(type(func) == "function")
	return self:_AddStepHelper(STEP.MAP_LATEST_TO_PUBLISHER, func)
end

---Prints published values and passes them through for debugging purposes.
---@param tag? string An optional tag to add to the prints
---@return ReactivePublisher
function ReactivePublisher:Print(tag)
	return self:_AddStepHelper(STEP.PRINT, tag)
end

---Wraps all following steps in profiling nodes.
---@param prefix string A prefix to use for the profiling nodes
---@return ReactivePublisher
function ReactivePublisher:StartProfiling(prefix)
	return self:_AddStepHelper(STEP.START_PROFILING, prefix)
end

---Shares the result of the publisher at the current point in the chain.
---@param numPublishers number The number of child publisher chains to share with
---@return ReactivePublisher
function ReactivePublisher:Share(numPublishers)
	assert(not self._shareStep and numPublishers > 1)
	self:_AddStepHelper(STEP.SHARE, numPublishers)
	self._shareStep = self._numSteps
	return self
end

---Calls a method with the published values.
---@param obj table The object to call the method on
---@param method string The name of the method to call with the published values
---@return ReactivePublisher
function ReactivePublisher:CallMethod(obj, method)
	assert(type(obj) == "table" and type(method) == "string")
	return self:_AddStepHelper(STEP.CALL_METHOD, obj, method)
end

---Calls a method with the published values if it's non-nil.
---@param obj table The object to call the method on
---@param method string The name of the method to call with the published values
---@return ReactivePublisher
function ReactivePublisher:CallMethodIfNotNil(obj, method)
	assert(type(obj) == "table" and type(method) == "string")
	return self:_AddStepHelper(STEP.CALL_METHOD_IF_NOT_NIL, obj, method)
end

---Calls a method with the published values on each value in a list.
---@param list table The list of objects to call the method on
---@param method string The name of the method to call with the published values
---@return ReactivePublisher
function ReactivePublisher:CallMethodForEachListValue(list, method)
	assert(type(list) == "table" and type(method) == "string")
	return self:_AddStepHelper(STEP.CALL_METHOD_FOR_EACH_LIST_VALUE, list, method)
end

---Calls a function with the published values.
---@param func fun(value: any) The function to call with the published values
---@return ReactivePublisher
function ReactivePublisher:CallFunction(func)
	assert(type(func) == "function")
	return self:_AddStepHelper(STEP.CALL_FUNCTION, func)
end

---Unpacks published values and then calls a function with the result.
---@param func fun(value: any) The function to call with the unpacked published values
---@return ReactivePublisher
function ReactivePublisher:UnpackAndCallFunction(func)
	assert(type(func) == "function")
	return self:_AddStepHelper(STEP.UNPACK_AND_CALL_FUNCTION, func)
end

---Unpacks published values and then calls a method with the result.
---@param obj table The object to call the method on
---@param method string The name of the method to call with the unpacked published values
---@return ReactivePublisher
function ReactivePublisher:UnpackAndCallMethod(obj, method)
	assert(type(obj) == "table" and type(method) == "string")
	return self:_AddStepHelper(STEP.UNPACK_AND_CALL_METHOD, obj, method)
end

---Assigns published values to the specified key in the table.
---@param tbl table The table to assign the published values into
---@param key string The key to assign the published values at
---@return ReactivePublisher
function ReactivePublisher:AssignToTableKey(tbl, key)
	assert(type(tbl) == "table" and type(key) == "string")
	return self:_AddStepHelper(STEP.ASSIGN_TO_TABLE_KEY, tbl, key)
end

---Sets published values as the singular key within a table (with a value of `true`).
---@param tbl table The table to store the published values in
---@return ReactivePublisher
function ReactivePublisher:SetSingleTableKey(tbl)
	assert(type(tbl) == "table")
	return self:_AddStepHelper(STEP.SET_SINGLE_TABLE_KEY, tbl)
end

---Stores the publisher in a table for later cancelling.
---@param tbl table The table to assign the published values in (as a list)
function ReactivePublisher:StoreIn(tbl)
	assert(type(tbl) == "table")
	tinsert(tbl, self)
	self:_Commit()
end

---Marks a publisher as stored manually by the caller.
---@return ReactivePublisher
function ReactivePublisher:Stored()
	self:_Commit()
	return self
end

---Cancels and releases a publisher.
function ReactivePublisher:Cancel()
	assert(self._state == STATE.STORED)
	for step = 1, self._numSteps do
		local stepType, _, arg2 = unpack(self._stepData, (step - 1) * STEP_DATA_SIZE + 1, step * STEP_DATA_SIZE)
		if stepType == STEP.MAP_LATEST_TO_PUBLISHER and arg2 then
			arg2:Cancel()
		end
	end
	self._subject:_HandlePublisherEvent(self, "OnCancel")
	self:_Release()
	private.publisherObjectPool:Recycle(self)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@return ReactivePublisher
function ReactivePublisher:_SendToPublisher(publisher, step)
	return self:_AddStepHelper(STEP.SEND_TO_PUBLISHER, publisher, step)
		:Stored()
end

function ReactivePublisher.__private:_AddStepHelper(stepType, arg1, arg2)
	local newState = STEP_RESULTING_STATE[stepType]
	assert(newState == STATE.STEPS or newState == STATE.HANDLED)
	assert(self._state == STATE.ACQUIRED or self._state == STATE.STEPS)
	if newState == STATE.HANDLED and self._shareStep then
		-- The first arg of the share step contains the number of publishers we're sharing with
		local numPublishersIndex = (self._shareStep - 1) * STEP_DATA_SIZE + 2
		self._stepData[numPublishersIndex] = self._stepData[numPublishersIndex] - 1
		assert(self._stepData[numPublishersIndex] >= 0)
		if self._stepData[numPublishersIndex] > 0 then
			-- There are still more handlers to be added
			newState = STATE.STEPS
		end
	end
	self._state = newState
	assert(STEP_DATA_SIZE == 3)
	self._stepData[self._numSteps * STEP_DATA_SIZE + 1] = stepType
	self._stepData[self._numSteps * STEP_DATA_SIZE + 2] = arg1
	self._stepData[self._numSteps * STEP_DATA_SIZE + 3] = arg2
	self._numSteps = self._numSteps + 1
	if self._state == STATE.HANDLED and not ON_HANDLED_IGNORED_FOR_STEP[stepType] then
		self._subject:_HandlePublisherEvent(self, "OnHandled")
	end
	return self
end

function ReactivePublisher.__private:_GetStepTempTable()
	local tbl = tremove(private.freeStepTempTables) or {}
	assert(not next(tbl))
	tinsert(self._stepTempTables, tbl)
	return tbl
end

function ReactivePublisher.__private:_Commit()
	assert(self._state == STATE.HANDLED)
	self._state = STATE.STORED

	-- Perform optimizations
	assert(not next(self._optimizeKeys) and not self._hasOptimizeKeys)
	local didOptimize = false

	for step = 1, self._numSteps do
		local stepType, arg1, arg2 = unpack(self._stepData, (step - 1) * STEP_DATA_SIZE + 1, step * STEP_DATA_SIZE)
		if stepType == STEP.MAP_WITH_KEY or stepType == STEP.IGNORE_IF_KEY_EQUALS or stepType == STEP.IGNORE_IF_KEY_NOT_EQUALS then
			self._optimizeKeys[arg1] = true
		elseif stepType == STEP.MAP_WITH_KEY_COALESCED then
			self._optimizeKeys[arg1] = true
			self._optimizeKeys[arg2] = true
		elseif stepType == STEP.IGNORE_DUPLICATES or stepType == STEP.MAP_TO_VALUE or stepType == STEP.IGNORE_DUPLICATES_WITH_METHOD then
			didOptimize = true
			break
		elseif stepType == STEP.IGNORE_DUPLICATES_WITH_KEYS then
			for _, key in ipairs(arg1) do
				self._optimizeKeys[key] = true
			end
			didOptimize = true
			break
		elseif STEP_RESULTING_STATE[stepType] == STATE.HANDLED or OPTIMIZATION_IGNORED_STEPS[stepType] then
			-- Ignore these steps for optimizations
		elseif UNOPTIMIZABLE_STEPS[stepType] then
			-- Not able to optimize
			didOptimize = false
			break
		else
			error("Invalid stepType: "..tostring(stepType))
		end
	end
	if didOptimize then
		self._hasOptimizeKeys = next(self._optimizeKeys) and true or false
	else
		wipe(self._optimizeKeys)
	end

	self._subject:_HandlePublisherEvent(self, "OnCommit", didOptimize)
end

---@private
function ReactivePublisher:_HandleData(data, optimizeKey, step)
	if self._state ~= STATE.STORED then
		error("Invalid publisher state: "..tostring(self._state))
	end
	if optimizeKey and self._hasOptimizeKeys and not self._optimizeKeys[optimizeKey] then
		return
	end
	local profilingPrefix = nil
	step = step or 1
	while true do
		if step > self._numSteps then
			error("Publisher did not terminate")
		end
		local stepDataIndex = (step - 1) * STEP_DATA_SIZE + 1
		local stepType = self._stepData[stepDataIndex]
		local arg1 = self._stepData[stepDataIndex + 1]
		local stepProfilingNode = profilingPrefix and profilingPrefix.."_"..tostring(stepType) or nil
		if stepProfilingNode then
			TSMDEV.Profiling.StartNode(stepProfilingNode)
		end
		local ignoreValue = false
		if stepType == STEP.MAP_WITH_FUNCTION then
			local arg2 = self._stepData[stepDataIndex + 2]
			data = arg1(data, arg2)
		elseif stepType == STEP.MAP_WITH_METHOD then
			local arg2 = self._stepData[stepDataIndex + 2]
			data = data[arg1](data, arg2)
		elseif stepType == STEP.MAP_WITH_OBJECT_METHOD then
			local arg2 = self._stepData[stepDataIndex + 2]
			data = arg1[arg2](arg1, data)
		elseif stepType == STEP.MAP_WITH_KEY then
			data = data[arg1]
		elseif stepType == STEP.MAP_WITH_KEY_COALESCED then
			local newData = data[arg1]
			if newData == nil then
				local arg2 = self._stepData[stepDataIndex + 2]
				newData = data[arg2]
			end
			data = newData
		elseif stepType == STEP.MAP_WITH_LOOKUP_TABLE then
			data = arg1[data]
		elseif stepType == STEP.MAP_BOOLEAN_WITH_VALUES then
			if data then
				data = arg1
			else
				data = self._stepData[stepDataIndex + 2]
			end
		elseif stepType == STEP.MAP_BOOLEAN_EQUALS then
			data = data == arg1
		elseif stepType == STEP.MAP_BOOLEAN_NOT_EQUALS then
			data = data ~= arg1
		elseif stepType == STEP.MAP_BOOLEAN_GREATER_THAN_OR_EQUALS then
			data = data >= arg1
		elseif stepType == STEP.MAP_TO_BOOLEAN then
			data = data and true or false
		elseif stepType == STEP.MAP_TO_VALUE then
			data = arg1
		elseif stepType == STEP.MAP_NIL_TO_VALUE then
			if data == nil then
				data = arg1
			end
		elseif stepType == STEP.MAP_NON_NIL_WITH_FUNCTION then
			if data ~= nil then
				local arg2 = self._stepData[stepDataIndex + 2]
				data = arg1(data, arg2)
			end
		elseif stepType == STEP.MAP_NON_NIL_WITH_METHOD then
			if data ~= nil then
				local func = data[arg1]
				if not func then
					error(format("Method (%s) does not exist on object (%s)"), tostring(arg1), tostring(data))
				end
				local arg2 = self._stepData[stepDataIndex + 2]
				data = func(data, arg2)
			end
		elseif stepType == STEP.INVERT_BOOLEAN then
			if type(data) ~= "boolean" then
				error("Invalid data type: "..tostring(data))
			end
			data = not data
		elseif stepType == STEP.IGNORE_IF_KEY_EQUALS then
			local arg2 = self._stepData[stepDataIndex + 2]
			if data[arg1] == arg2 then
				ignoreValue = true
			end
		elseif stepType == STEP.IGNORE_IF_KEY_NOT_EQUALS then
			local arg2 = self._stepData[stepDataIndex + 2]
			if data[arg1] ~= arg2 then
				ignoreValue = true
			end
		elseif stepType == STEP.IGNORE_IF_NOT_KEY_IN_TABLE then
			if arg1[data] == nil then
				ignoreValue = true
			end
		elseif stepType == STEP.IGNORE_IF_NOT_EQUALS then
			if data ~= arg1 then
				ignoreValue = true
			end
		elseif stepType == STEP.IGNORE_NIL then
			if data == nil then
				ignoreValue = true
			end
		elseif stepType == STEP.IGNORE_WITH_FUNCTION then
			local result = arg1(data)
			if result == false then
				ignoreValue = true
			elseif result ~= true then
				error("Invalid IgnoreWithFunction result: "..tostring(result))
			end
		elseif stepType == STEP.IGNORE_DUPLICATES then
			-- We use arg1 to store the previous value
			if data == arg1 then
				ignoreValue = true
			else
				self._stepData[stepDataIndex + 1] = data
			end
		elseif stepType == STEP.IGNORE_DUPLICATES_WITH_KEYS then
			-- The first argument (arg1) stores both the list of keys and their prior values
			local isEqual = true
			for i = 1, #arg1 do
				local key = arg1[i]
				local value = data[key]
				isEqual = isEqual and value == arg1[key]
				arg1[key] = value
			end
			if isEqual then
				ignoreValue = true
			end
		elseif stepType == STEP.IGNORE_DUPLICATES_WITH_METHOD then
			local hash = data[arg1](data)
			-- We use arg2 to store the previous hash
			local arg2DataIndex = stepDataIndex + 2
			local arg2 = self._stepData[arg2DataIndex]
			if hash == arg2 then
				ignoreValue = true
			else
				self._stepData[arg2DataIndex] = hash
			end
		elseif stepType == STEP.MAP_LATEST_TO_PUBLISHER then
			local publisher = arg1(data)
			-- We use arg2 to store this publisher - cancel any previous one
			local arg2DataIndex = stepDataIndex + 2
			local arg2 = self._stepData[arg2DataIndex]
			if arg2 then
				arg2:Cancel()
			end
			self._stepData[arg2DataIndex] = publisher:_SendToPublisher(self, step + 1)
			-- The other publisher will pick up from here, so ignore the value for the purposes of this invocation
			ignoreValue = true
		elseif stepType == STEP.PRINT then
			if arg1 then
				print(format("Published value (%s): %s", tostring(arg1), tostring(data)))
			else
				print(format("Published value: %s", tostring(data)))
			end
			TSMDEV.Dump(data)
		elseif stepType == STEP.START_PROFILING then
			assert(not profilingPrefix)
			profilingPrefix = arg1
			TSMDEV.Profiling.StartNode(profilingPrefix)
		elseif stepType == STEP.SHARE then
			if step ~= self._shareStep then
				error("Invalid share step")
			end
			-- Store the shared value in arg2
			self._stepData[stepDataIndex + 2] = data
		elseif stepType == STEP.CALL_METHOD then
			local arg2 = self._stepData[stepDataIndex + 2]
			local func = arg1[arg2]
			if not func then
				error(format("Method (%s) does not exist on object (%s)"), tostring(arg2), tostring(arg1))
			end
			func(arg1, data)
		elseif stepType == STEP.CALL_METHOD_IF_NOT_NIL then
			local arg2 = self._stepData[stepDataIndex + 2]
			local func = arg1[arg2]
			if func ~= nil then
				func(arg1, data)
			end
		elseif stepType == STEP.CALL_METHOD_FOR_EACH_LIST_VALUE then
			local arg2 = self._stepData[stepDataIndex + 2]
			for j = 1, #arg1 do
				local obj = arg1[j]
				obj[arg2](obj, data)
			end
		elseif stepType == STEP.CALL_FUNCTION then
			arg1(data)
		elseif stepType == STEP.UNPACK_AND_CALL_FUNCTION then
			arg1(unpack(data))
		elseif stepType == STEP.UNPACK_AND_CALL_METHOD then
			local arg2 = self._stepData[stepDataIndex + 2]
			arg1[arg2](arg1, unpack(data))
		elseif stepType == STEP.ASSIGN_TO_TABLE_KEY then
			local arg2 = self._stepData[stepDataIndex + 2]
			arg1[arg2] = data
		elseif stepType == STEP.SET_SINGLE_TABLE_KEY then
			wipe(arg1)
			arg1[data] = true
		elseif stepType == STEP.SEND_TO_PUBLISHER then
			local arg2 = self._stepData[stepDataIndex + 2]
			arg1:_HandleData(data, nil, arg2)
		else
			error("Invalid stepType: "..tostring(stepType))
		end
		if stepProfilingNode then
			TSMDEV.Profiling.EndNode(stepProfilingNode)
		end
		if ignoreValue then
			if self._shareStep and step < self._shareStep then
				-- Ignoring before the share step, so we're done
				break
			elseif self._shareStep then
				-- Advance past the current handler to the next child publisher chain with the shared value
				while true do
					local newStepType = self._stepData[step * STEP_DATA_SIZE + 1]
					step = step + 1
					if not newStepType then
						error("Could not find handling step")
					elseif STEP_RESULTING_STATE[newStepType] == STATE.HANDLED then
						break
					end
				end
				if step >= self._numSteps then
					-- No more child publisher chains, so we're done
					break
				end
				data = self._stepData[self._shareStep * STEP_DATA_SIZE]
			else
				break
			end
		elseif STEP_RESULTING_STATE[stepType] == STATE.HANDLED then
			if step == self._numSteps then
				-- We're done
				break
			elseif self._shareStep then
				-- Replace the current data with the shared value and continue
				data = self._stepData[self._shareStep * STEP_DATA_SIZE]
			else
				error("Extra steps")
			end
		end
		step = step + 1
	end
	if profilingPrefix then
		TSMDEV.Profiling.EndNode(profilingPrefix)
	end
end
