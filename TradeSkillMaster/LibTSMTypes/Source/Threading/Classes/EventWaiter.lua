-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local EventWaiter = LibTSMTypes:DefineClassType("EventWaiter")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Vararg")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local private = {
	eventRegisterFunc = nil,
	eventListTemp = {},
}
local STATE = EnumType.New("EVENT_WAITER_STATE", {
	IDLE = EnumType.NewValue(),
	STARTED = EnumType.NewValue(),
	DONE = EnumType.NewValue(),
})
local LOG_ELAPSED_TIME_THRESHOLD = 5



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new event waiter.
---@return EventWaiter
function EventWaiter.__static.New()
	return EventWaiter()
end

---Sets the function to call to register for an event.
---@param func fun(event: string) The function
function EventWaiter.__static.SetEventRegisterFunc(func)
	private.eventRegisterFunc = func
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function EventWaiter.__private:__init()
	self._state = STATE.IDLE
	self._events = {}
	self._result = {}
	self._startTime = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Resets the waiter.
function EventWaiter:Reset()
	self._state = STATE.IDLE
	wipe(self._events)
	wipe(self._result)
	self._startTime = nil
end

---Starts the waiter.
---@param ... WowEvent Events to wait for
function EventWaiter:Start(...)
	assert(self._state == STATE.IDLE)
	for _, name in Vararg.Iterator(...) do
		self._events[name] = true
		private.eventRegisterFunc(name)
	end
	self._startTime = LibTSMTypes.GetTime()
	self._state = STATE.STARTED
end

---Handles an event.
---@param name WowEvent The event name
---@param ... any The event args
function EventWaiter:HandleEvent(name, ...)
	if self._state ~= STATE.STARTED or not self._events[name] then
		return
	end
	assert(type(name) == "string")
	Vararg.IntoTable(self._result, name, ...)
	self._state = STATE.DONE
end

---Gets the result of the event (name followed by args).
---@return string
---@return ...
function EventWaiter:GetResult()
	assert(self._state == STATE.DONE)
	wipe(self._events)
	local elapsedTime = LibTSMTypes.GetTime() - self._startTime
	self._startTime = nil
	if elapsedTime > LOG_ELAPSED_TIME_THRESHOLD then
		Log.Warn("Waited %d seconds for %s", elapsedTime, self._result[1])
	end
	self._state = STATE.IDLE
	return Table.UnpackAndWipe(self._result)
end

---Checks if the waiter is done.
---@return boolean
function EventWaiter:IsDone()
	return self._state == STATE.DONE
end

---Gets a debug string representation of the current state.
---@return string
function EventWaiter:GetDebugStr()
	if self._state == STATE.STARTED then
		assert(#private.eventListTemp == 0)
		for event in pairs(self._events) do
			tinsert(private.eventListTemp, event)
		end
		local result = format("Waiting for %s", table.concat(private.eventListTemp, "|"))
		wipe(private.eventListTemp)
		return result
	elseif self._state == STATE.DONE then
		return format("Got %s", self._result[1])
	else
		error("Invalid state: "..tostring(self._state))
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function EventWaiter.__private:_GetResultHelper(...)
	wipe(self._result)
	return ...
end
