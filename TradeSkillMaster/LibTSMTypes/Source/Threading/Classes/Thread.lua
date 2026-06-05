-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Thread = LibTSMTypes:DefineClassType("Thread")
local EventWaiter = LibTSMTypes:IncludeClassType("EventWaiter")
local FunctionWaiter = LibTSMTypes:IncludeClassType("FunctionWaiter")
local FutureWaiter = LibTSMTypes:IncludeClassType("FutureWaiter")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local DebugStack = LibTSMTypes:From("LibTSMUtil"):Include("Lua.DebugStack")
local Math = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Vararg")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local private = {
	errorHandler = nil,
	runningThread = nil,
}
local STATE = EnumType.New("THREAD_STATE", {
	READY = EnumType.NewValue(),
	RUNNING = EnumType.NewValue(),
	SLEEPING = EnumType.NewValue(),
	WAITING_FOR_MSG = EnumType.NewValue(),
	WAITING_FOR_WAITER = EnumType.NewValue(),
	FORCED_YIELD = EnumType.NewValue(),
	SENDING_SYNC_MESSAGE = EnumType.NewValue(),
	DEAD = EnumType.NewValue(),
})
local YIELD_TYPE = EnumType.New("YIELD_TYPE", {
	COOPERATIVE = EnumType.NewValue(),
	COOPERATIVE_WAITING_FOR_MSG = EnumType.NewValue(),
	NOT_READY = EnumType.NewValue(),
	FORCED = EnumType.NewValue(),
})
local SEND_MSG_SYNC_TIMEOUT = 3
local YIELD_VALUE_START = {}
local YIELD_VALUE = {}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Configures the thread module.
---@param errorHandler fun(msg: string, co: thread) The error handler
function Thread.__static.Configure(errorHandler)
	Log.SetCurrentThreadNameFunction(function()
		return private.runningThread and private.runningThread._name or nil
	end)
	private.errorHandler = errorHandler
end

---Creates a new thread.
---@param name string The name of the thread (useful for debugging)
---@param func fun(...): ... The main function for the thread
---@return Thread
function Thread.__static.New(name, func)
	assert(type(name) == "string" and type(func) == "function")
	assert(name and func)
	return Thread(name, func)
end

---Gets the currently-running thread or nil if not in a thread context.
---@return Thread?
function Thread.__static.GetRunningThread()
	return private.runningThread
end

---Send a message to a thread and block until the message is delievered (must be in a thread context).
---
---NOTE: The msg value must not evalulate as equal with any other messages sent to the thread.
---@param thread Thread The thread to send to
---@param msg any The message
function Thread.__static.SendSyncMessage(thread, msg)
	assert(thread and msg ~= nil)
	if private.runningThread then
		-- Can't run other threads synchronously from a thread context, so yield the current thread first
		private.runningThread:_SendSyncMessage(thread, msg)
	else
		local errMsg = thread:_HandleSyncMessage(msg)
		if errMsg then
			error(errMsg)
		end
	end
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function Thread.__private:__init(name, func)
	-- Core fields
	self._func = func
	self._co = nil
	self._state = STATE.DEAD
	self._endTime = nil
	self._sleepEnd = nil
	self._eventWaiter = EventWaiter.New()
	self._functionWaiter = FunctionWaiter.New()
	self._futureWaiter = FutureWaiter.New(self:__closure("_OnFutureDone"))
	self._waitingWaiter = nil
	self._syncMessage = nil
	self._syncMessageDest = nil ---@type Thread|nil
	self._messages = {}
	self._callback = nil
	self._returnValue = {}
	self._wasNormalExit = false
	self._guardedQueries = {}

	-- Debug fields
	self._startTime = 0
	self._cpuTimeUsed = 0
	self._realTimeUsed = 0
	self._name = name or tostring(self)
	self._createCaller = DebugStack.GetLocation(3) or "?"
	self._startCaller = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Starts the thread.
---@param ... any Arguments to pass to the thread function
function Thread:Start(...)
	assert(self._state == STATE.DEAD)
	self._co = coroutine.create(self:__closure("_Main"))
	self._state = STATE.READY
	self._endTime = 0
	self._sleepEnd = nil
	self._eventWaiter:Reset()
	self._functionWaiter:Reset()
	self._futureWaiter:Reset()
	self._waitingWaiter = nil
	self._syncMessage = nil
	self._syncMessageDest = nil
	assert(#self._messages == 0)
	assert(not next(self._guardedQueries))
	self._startTime = 0
	self._cpuTimeUsed = 0
	self._realTimeUsed = 0
	self._startCaller = self._startCaller or DebugStack.GetLocation(3)

	-- Run the thread once (will yield right away) to pass in the arguments
	local noErr, retValue = coroutine.resume(self._co, ...)
	assert(noErr and retValue == YIELD_VALUE_START)
end

-- The callback is called when a thread finishes running and is passed all values returned by the thread's main function.
---@param threadId string The thread id
---@param callback function The callback function

---Sets the thread callback which is called when the thread finishes running.
---@param callback fun(...: any) The function to call which gets passed all values returned by the thread function
function Thread:SetCallback(callback)
	self._callback = callback
end

---Returns whether or not the thread is alive.
---@return boolean
function Thread:IsAlive()
	return self._state ~= STATE.DEAD
end

---Returns whether or not the thread can run.
---@return booleanm
function Thread:CanRun()
	return self._state == STATE.READY
end

---Runs the thread and returns the elapsed time.
---@param quantum number The time in seconds the thread should run for
---@return number
function Thread:Run(quantum)
	assert(private.runningThread == nil)
	if not self:CanRun() then
		return 0
	end

	self._state = STATE.RUNNING
	local startTime = LibTSMTypes.GetTime()
	self._endTime = startTime + quantum
	private.runningThread = self
	local noErr, returnVal = coroutine.resume(self._co)
	private.runningThread = nil
	local elapsedTime = LibTSMTypes.GetTime() - startTime

	assert(not noErr or returnVal == YIELD_VALUE)
	if noErr and self._state == STATE.SENDING_SYNC_MESSAGE then
		-- Yielded to send a sync message to another thread
		local msg = self._syncMessage
		local destThread = self._syncMessageDest
		self._syncMessage = nil
		self._syncMessageDest = nil
		local errMsg = destThread:_HandleSyncMessage(msg)
		if errMsg then
			noErr = false
			returnVal = errMsg
		elseif self._state == STATE.SENDING_SYNC_MESSAGE then
			self._state = STATE.READY
		end
	end
	if not noErr then
		returnVal = returnVal or "UNKNOWN ERROR"
		private.errorHandler(returnVal, self._co)
		self._state = STATE.DEAD
	end
	if self._state == STATE.DEAD then
		self:_Cleanup()
		if self._callback and self._wasNormalExit then
			self._wasNormalExit = false
			self._callback(Table.UnpackAndWipe(self._returnValue))
		else
			self._wasNormalExit = false
			wipe(self._returnValue)
		end
	end
	return elapsedTime
end

---Updates the thread's state.
function Thread:UpdateState()
	-- Check what the thread state is
	if self._state == STATE.SLEEPING then
		if self._sleepEnd <= LibTSMTypes.GetTime() then
			self._sleepEnd = nil
			self._state = STATE.READY
		end
	elseif self._state == STATE.WAITING_FOR_MSG then
		if #self._messages > 0 then
			self._state = STATE.READY
		end
	elseif self._state == STATE.WAITING_FOR_WAITER then
		if self._waitingWaiter:IsDone() then
			self._waitingWaiter = nil
			self._state = STATE.READY
		end
	elseif self._state == STATE.FORCED_YIELD then
		self._state = STATE.READY
	elseif self._state == STATE.RUNNING then
		-- This shouldn't happen, so just kill this thread
		self:_Exit()
	elseif self._state == STATE.DEAD then
		-- Pass
	elseif self._state == STATE.READY then
		-- Pass
	else
		error("Invalid thread state: "..tostring(self._state))
	end
end

---Causes the thread to yield if it has used up its elapsed time (must be on the thread context).
---@param force boolean Whether or not to force a yield
function Thread:Yield(force)
	self:_Yield(force and YIELD_TYPE.FORCED or YIELD_TYPE.COOPERATIVE)
end

---Causes the thread to sleep (must be on the thread context).
---@param seconds number The time to sleep for in seconds
function Thread:Sleep(seconds)
	self._state = STATE.SLEEPING
	self._sleepEnd = LibTSMTypes.GetTime() + seconds
	self:_Yield(YIELD_TYPE.NOT_READY)
end

---Handles an event.
---@param name WowEvent The event name
---@param ... any The event arguments
function Thread:HandleEvent(name, ...)
	if self._state ~= STATE.WAITING_FOR_WAITER or self._waitingWaiter ~= self._eventWaiter then
		return
	end
	self._eventWaiter:HandleEvent(name, ...)
end

---Queues a message to be received next time the thread runs.
---@param msg any The message
function Thread:QueueMessage(msg)
	assert(msg ~= nil)
	assert(self:IsAlive())
	tinsert(self._messages, msg)
end

---Check if the thread has any pending messages (must be on the thread context).
---@return boolean
function Thread:HasPendingMessage()
	return #self._messages > 0
end

---Receive the next message (must be on the thread context).
---@return ...
function Thread:ReceiveMessage()
	if #self._messages == 0 then
		-- Change the state if there's no messages ready
		self._state = STATE.WAITING_FOR_MSG
		self:_Yield(YIELD_TYPE.NOT_READY)
	else
		-- If we end up yielding due to running out of time, make sure we do so in the WAITING_FOR_MSG
		-- state to allow sync messages to be sent to us.
		self:_Yield(YIELD_TYPE.COOPERATIVE_WAITING_FOR_MSG)
	end
	return tremove(self._messages, 1)
end

---Wait for an event and return the event name and its arguments (must be on the thread context).
---@param ... WowEvent The events to wait for
---@return string
---@return ...
function Thread:WaitForEvent(...)
	self._eventWaiter:Start(...)
	return self:_YieldForWaiter(self._eventWaiter)
end

---Wait for a function to return a truthy value and return its result (must be on the thread context).
---@param func function The function to wait for
---@param ... any Additional arguments to pass to the function
---@return ...
function Thread:WaitForFunction(func, ...)
	self._functionWaiter:Start(func, ...)
	return self:_YieldForWaiter(self._functionWaiter)
end

---Wait for a future to complete and return its result (must be on the thread context).
---@param future Future The future to wait for
---@return any
function Thread:WaitForFuture(future)
	self._futureWaiter:Start(future)
	return self:_YieldForWaiter(self._futureWaiter)
end

---Kills the thread.
function Thread:Kill()
	if self:IsAlive() then
		self:_Exit()
	end
end

---Acquire a temp table which is owned by the thread.
---
---Any time a thread needs to maintain a temp table across a potential yield, it should use this API.
---This API will release the temp tables in the case that the thread gets killed.
---@param ... any Values to insert into the temp table
---@return table
function Thread:AcquireSafeTempTable(...)
	return TempTable.AcquireWithOwner(self, ...)
end

---Assign ownership of a database query to the thread so that if the thread is killed it'll get released safely.
---@param query DatabaseQuery The query object
function Thread:GuardDatabaseQuery(query)
	assert(not self._guardedQueries[query])
	self._guardedQueries[query] = true
end

---Removes ownership of a database query from the thread.
---@param query DatabaseQuery The query object
function Thread:UnguardDatabaseQuery(query)
	assert(self._guardedQueries[query])
	self._guardedQueries[query] = nil
end

---Gets debug info for the thread.
---@return string name
---@return string stateStr
---@return string timeStr
---@return string createStr
---@return string startStr
---@return table backtrace
function Thread:GetDebugInfo()
	local stateStr = nil
	if self._state == STATE.SLEEPING then
		stateStr = format("Sleeping for %d seconds", Math.Round(self._sleepEnd - LibTSMTypes.GetTime(), 0.001))
	elseif self._state == STATE.WAITING_FOR_MSG then
		stateStr = #self._messages > 0 and "Got message" or "Waiting for message"
	elseif self._state == STATE.WAITING_FOR_WAITER then
		stateStr = self._waitingWaiter:GetDebugStr()
	elseif self._state == STATE.FORCED_YIELD then
		stateStr = "Forced yield"
	elseif self._state == STATE.SENDING_SYNC_MESSAGE then
		stateStr = format("Sending sync message to %s", self._syncMessageDest and self._syncMessageDest._name or "?")
	elseif self._state == STATE.RUNNING then
		stateStr = "Running"
	elseif self._state == STATE.DEAD then
		stateStr = "Dead"
	elseif self._state == STATE.READY then
		stateStr = "Ready"
	else
		error("Invalid thread state: "..tostring(self._state))
	end
	if #self._messages > 0 then
		stateStr = format("%s (%d messages)", stateStr, #self._messages)
	end

	local timeStr = "<Not Started>"
	if self._startTime then
		local wallTime = LibTSMTypes.GetTime() - self._startTime
		local cpuTime = self._cpuTimeUsed
		timeStr = format("Running for %.1f seconds (CPU: %dms, %.2f%%)", wallTime, cpuTime, (cpuTime / wallTime) * 100)
	end

	local createStr = "Created @"..self._createCaller
	local startStr = "Started @"..(self._startCaller or "<Not Started>")

	local backtrace = {}
	local level = 2
	local line = DebugStack.GetLocation(level, self._co)
	while line do
		tinsert(backtrace, line)
		level = level + 1
		line = DebugStack.GetLocation(level, self._co)
	end

	return self._name, stateStr, timeStr, createStr, startStr, backtrace
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Thread.__private:_Main(...)
	self._startTime = LibTSMTypes.GetTime()
	coroutine.yield(YIELD_VALUE_START)
	Vararg.IntoTable(self._returnValue, self._func(...))
	self._wasNormalExit = true
	self:_Exit()
end

function Thread.__private:_Exit()
	assert(self:IsAlive())
	self._state = STATE.DEAD
	self:_Cleanup()
	if self._startTime then
		self._realTimeUsed = LibTSMTypes.GetTime() - self._startTime
		local pctStr = format("%.1f%%", Math.Round(self._cpuTimeUsed / self._realTimeUsed, 0.001) * 100)
		Log.Info("Thread finished: %s [%s]", self._name, pctStr)
	else
		Log.Info("Thread finished: %s", self._name)
	end
	if self == private.runningThread then
		coroutine.yield(YIELD_VALUE)
		error("Shouldn't get here")
	else
		wipe(self._returnValue)
		self._wasNormalExit = false
	end
end

function Thread.__private:_Cleanup()
	wipe(self._messages)
	TempTable.ReleaseAllOwned(self)
	for query in pairs(self._guardedQueries) do
		query:Release(true)
	end
	wipe(self._guardedQueries)
	self._eventWaiter:Reset()
	self._functionWaiter:Reset()
	self._futureWaiter:Reset()
	self._waitingWaiter = nil
	self._syncMessage = nil
	self._syncMessageDest = nil
end

function Thread.__private:_Yield(yieldType, force, yieldState)
	if yieldType == YIELD_TYPE.COOPERATIVE or yieldType == YIELD_TYPE.COOPERATIVE_WAITING_FOR_MSG then
		if self._state ~= STATE.RUNNING then
			error("Invalid state: "..tostring(self._state))
		end
		-- Check if we're out of time
		if LibTSMTypes.GetTime() > self._endTime then
			if yieldType == YIELD_TYPE.COOPERATIVE_WAITING_FOR_MSG then
				-- Yield in the WAITING_FOR_MSG state to allow sync messages to be sent to us.
				self._state = STATE.WAITING_FOR_MSG
			else
				self._state = STATE.READY
			end
			coroutine.yield(YIELD_VALUE)
		end
	elseif yieldType == YIELD_TYPE.FORCED then
		self._state = STATE.FORCED_YIELD
		coroutine.yield(YIELD_VALUE)
	elseif yieldType == YIELD_TYPE.NOT_READY then
		if self._state == STATE.RUNNING then
			error("Invalid usage")
		end
		coroutine.yield(YIELD_VALUE)
	else
		error("Invalid yield type: "..tostring(yieldType))
	end
end

---Handles a sync message and returns an error message if one occurs.
---@param msg2 any The message
---@return string?
function Thread.__private:_HandleSyncMessage(msg)
	assert(msg ~= nil)
	assert(self:IsAlive())
	assert(private.runningThread == nil)
	tinsert(self._messages, 1, msg) -- This message should be received first
	-- Run the thread for up to 3 seconds to get it to process the sync message
	local startTime = LibTSMTypes.GetTime()
	while self._messages[1] == msg do
		if LibTSMTypes.GetTime() - startTime > SEND_MSG_SYNC_TIMEOUT or not self:IsAlive() then
			-- Want to error from the sending context, so just return the error
			return format("ERROR: A sync message was not able to be delivered! (%s)", self._name)
		end
		if self._state == STATE.WAITING_FOR_MSG then
			self._state = STATE.READY
		elseif self._state == STATE.SENDING_SYNC_MESSAGE then
			error("Circular sync message detected")
		end
		self:Run(0)
	end
end

function Thread.__private:_SendSyncMessage(destThread, msg)
	assert(self:IsAlive())
	assert(destThread ~= self)
	-- Yield the current thread to allow the other thread to run
	self._state = STATE.SENDING_SYNC_MESSAGE
	self._syncMessage = msg
	self._syncMessageDest = destThread
	self:_Yield(YIELD_TYPE.NOT_READY)
end

function Thread.__private:_YieldForWaiter(waiter)
	-- Check the waiter once before yielding
	if waiter:IsDone() then
		return waiter:GetResult()
	end
	self._waitingWaiter = waiter
	self._state = STATE.WAITING_FOR_WAITER
	self:_Yield(YIELD_TYPE.NOT_READY)
	return waiter:GetResult()
end

function Thread.__private:_OnFutureDone()
	if self._state ~= STATE.WAITING_FOR_WAITER or self._waitingWaiter ~= self._futureWaiter then
		return
	end
	-- Run the thread to allow the future result to be captured synchronously
	self:UpdateState()
	self:Run(0)
end
