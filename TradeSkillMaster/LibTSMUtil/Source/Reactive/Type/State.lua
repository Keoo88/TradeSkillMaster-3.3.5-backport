-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local State = LibTSMUtil:Init("Reactive.Type.State")
local Expression = LibTSMUtil:Include("Reactive.Type.Expression")
local ReactivePublisher = LibTSMUtil:IncludeClassType("ReactivePublisher")
local Table = LibTSMUtil:Include("Lua.Table")
local Vararg = LibTSMUtil:Include("Lua.Vararg")
local private = {
	nextPublisherId = 1,
	stateContext = {}, ---@type table<ReactiveState,StateContext>
	debugLinesTemp = {},
	keysTemp = {},
}

---@class StateContext
---@field schema ReactiveStateSchema
---@field data table<string,any>
---@field publishers table<ReactivePublisher,number>|ReactivePublisher[]
---@field autoStore table?
---@field autoStorePaused boolean
---@field handlingDataChange boolean
---@field dataChangeQueue string[]
---@field dataChangeTemp ReactivePublisher[]



-- ============================================================================
-- State Methods
-- ============================================================================

local STATE_METHODS = {} ---@class ReactiveState

---Creates a new publisher which gets published values from the state.
---@return ReactivePublisher
function STATE_METHODS:Publisher()
	local context = private.stateContext[self]
	local publisher = ReactivePublisher.Get(self)
	assert(not context.publishers[publisher])
	context.publishers[publisher] = private.nextPublisherId
	private.nextPublisherId = private.nextPublisherId + 1
	tinsert(context.publishers, publisher)
	return publisher
end

---Creates a new publisher for a specific key of the state.
---@param key string The key to create a publisher for (ignoring duplicate values)
---@return ReactivePublisher
function STATE_METHODS:PublisherForKeyChange(key)
	local context = private.stateContext[self]
	assert(context.schema:_HasKey(key))
	return self:Publisher()
		:MapWithKey(key)
		:IgnoreDuplicates()
end

---Creates a new publisher which publishes the state when any of the specified keys change.
---@param ... string The key to ignore duplicates for
---@return ReactivePublisher
function STATE_METHODS:PublisherForKeys(...)
	local context = private.stateContext[self]
	for _, key in Vararg.Iterator(...) do
		assert(context.schema:_HasKey(key))
	end
	return self:Publisher()
		:IgnoreDuplicatesWithKeys(...)
end

---Creates a publisher for an expression which operates on state fields.
---@param expression string A valid lua expression which can only access fields of the state (as globals)
---@return ReactivePublisher
function STATE_METHODS:PublisherForExpression(expression)
	local context = private.stateContext[self]
	local func, keys, funcArg = Expression.Create(expression, context.schema)
	if type(keys) == "string" then
		return self:PublisherForKeyChange(keys)
			:MapWithFunction(func, funcArg)
			:IgnoreDuplicates()
	else
		assert(not next(private.keysTemp))
		for key in pairs(keys) do
			tinsert(private.keysTemp, key)
		end
		return self:PublisherForKeys(Table.UnpackAndWipe(private.keysTemp))
			:MapWithFunction(func, funcArg)
			:IgnoreDuplicates()
	end
end

---Resets the state to its default value.
function STATE_METHODS:ResetToDefault()
	local context = private.stateContext[self]
	wipe(context.data)
	context.schema:_ApplyDefaults(context.data)
	self:_HandleDataChanged()
end

---Automatically stores any new publishers in the specified table.
---@param tbl table The table to store new publishers in
---@return ReactiveState
function STATE_METHODS:SetAutoStore(tbl)
	local context = private.stateContext[self]
	context.autoStore = tbl
	return self
end

---Sets whether automatic storing of new publisher is paused.
---@param paused boolean Pause or unpause automatic storing of publishers
function STATE_METHODS:SetAutoStorePaused(paused)
	local context = private.stateContext[self]
	assert(type(paused) == "boolean" and paused ~= context.autoStorePaused)
	context.autoStorePaused = paused
end

---@private
function STATE_METHODS:_GetData()
	return private.stateContext[self].data
end

---@private
function STATE_METHODS:_HandlePublisherEvent(publisher, event, arg)
	local context = private.stateContext[self]
	if event == "OnHandled" then
		if context.autoStore and not context.autoStorePaused then
			publisher:StoreIn(context.autoStore)
		end
	elseif event == "OnCommit" then
		assert(arg, "State publishers must be optimized")
		-- Send the initial value
		publisher:_HandleData(context.data)
	elseif event == "OnCancel" then
		assert(context.publishers[publisher])
		context.publishers[publisher] = nil
		assert(Table.RemoveByValue(context.publishers, publisher) == 1)
	else
		error("Unknown event: "..tostring(event))
	end
end

---@private
function STATE_METHODS:_HandleDataChanged(key)
	local context = private.stateContext[self]
	if context.handlingDataChange then
		-- We are already in the middle of processing another event, so queue this one up
		if #context.dataChangeQueue < 50 then
			tinsert(context.dataChangeQueue, key)
		end
		return
	end
	context.handlingDataChange = true
	self:_CallPublishersHandleData(key)
	-- Process queued keys
	while #context.dataChangeQueue > 0 do
		local queuedKey = tremove(context.dataChangeQueue, 1)
		self:_CallPublishersHandleData(queuedKey)
	end
	context.handlingDataChange = false
end

---@private
function STATE_METHODS:_CallPublishersHandleData(key)
	local context = private.stateContext[self]
	-- The list of publishers can change as a result of calling _HandleData() so copy them to a
	-- temp table and verify they are still subscribed before calling them.
	if #context.dataChangeTemp ~= 0 then
		error("Temp table is not empty")
	end
	local maxId = 0
	for i = 1, #context.publishers do
		local publisher = context.publishers[i]
		context.dataChangeTemp[i] = publisher
		local id = context.publishers[publisher]
		maxId = id > maxId and id or maxId
	end
	local data = context.data
	for i = 1, #context.dataChangeTemp do
		local publisher = context.dataChangeTemp[i]
		local id = context.publishers[publisher]
		if id and id <= maxId then
			publisher:_HandleData(data, key)
		end
	end
	wipe(context.dataChangeTemp)
end



-- ============================================================================
-- State Metatable
-- ============================================================================

local STATE_MT = {
	__index = function(self, key)
		if STATE_METHODS[key] then
			return STATE_METHODS[key]
		end
		local context = private.stateContext[self]
		if not context.schema:_HasKey(key) then
			error("Invalid key: "..tostring(key))
		end
		return context.data[key]
	end,
	__newindex = function(self, key, value)
		local context = private.stateContext[self]
		local data = context.data
		-- Coerce to boolean if field expects boolean (handles truthy/falsy from publisher pipelines)
		if type(value) ~= "boolean" and context.schema:_IsBoolean(key) then
			value = value and true or false
		end
		if data[key] == value then
			return
		end
		context.schema:_ValidateValueForKey(key, value)
		data[key] = value
		self:_HandleDataChanged(key)
	end,
	__tostring = function(self)
		local context = private.stateContext[self]
		local schemaName = strmatch(tostring(context.schema), "ReactiveStateSchema:(.+)") or "???"
		return schemaName..":"..strsub(strmatch(tostring(context), "table:[^0-9a-fA-F]*([0-9a-fA-F]+)"), -8)
	end,
	__metatable = false,
}



-- ============================================================================
-- Module Methods
-- ============================================================================

---Creates a new state object.
---@return ReactiveState
function State.Create(schema)
	local state = setmetatable({}, STATE_MT)
	local data = {}
	schema:_ApplyDefaults(data)
	private.stateContext[state] = {
		schema = schema,
		data = data,
		publishers = {},
		autoStore = nil,
		autoStorePaused = false,
		handlingDataChange = false,
		dataChangeQueue = {},
		dataChangeTemp = {},
	}
	return state
end

---Gets a debug representation of the state object.
---@param state ReactiveState
---@return string
function State.GetDebugInfo(state)
	local context = private.stateContext[state]
	if not context then
		return nil
	end
	assert(not next(private.debugLinesTemp))
	for key, fieldType in context.schema:_FieldIterator() do
		local value = context.data[key]
		if value ~= nil then
			if fieldType == "string" then
				tinsert(private.debugLinesTemp, format("%s = \"%s\"", key, value))
			else
				tinsert(private.debugLinesTemp, format("%s = %s", key, tostring(value)))
			end
		end
	end
	local result = table.concat(private.debugLinesTemp, "\n")
	wipe(private.debugLinesTemp)
	return result
end

---Gets state debug data.
---@return table<string,table>
function State.GetDebugData()
	local result = {}
	for state, context in pairs(private.stateContext) do
		result[tostring(state)] = context.data
	end
	return result
end
