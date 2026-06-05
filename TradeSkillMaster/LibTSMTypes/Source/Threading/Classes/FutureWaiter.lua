-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local FutureWaiter = LibTSMTypes:DefineClassType("FutureWaiter")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local STATE = EnumType.New("FUTURE_WAITER_STATE", {
	IDLE = EnumType.NewValue(),
	STARTED = EnumType.NewValue(),
	DONE = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new future waiter.
---@return FutureWaiter
---@param onDoneHandler fun() A function to call from the future's OnDone handler
function FutureWaiter.__static.New(onDoneHandler)
	return FutureWaiter(onDoneHandler)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function FutureWaiter.__private:__init(onDoneHandler)
	self._state = STATE.IDLE
	self._future = nil
	self._result = nil
	self._onDoneHandler = onDoneHandler
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Resets the waiter.
function FutureWaiter:Reset()
	if self._state == STATE.STARTED then
		self._future:Cancel()
	end
	self._state = STATE.IDLE
	self._future = nil
	self._result = nil
end

---Starts the waiter.
---@param future Future The future to wait for
function FutureWaiter:Start(future)
	assert(self._state == STATE.IDLE)
	self._future = future
	self._state = STATE.STARTED
	if future:IsDone() then
		self:_OnDone(future)
	else
		future:SetScript("OnDone", self:__closure("_OnDone"))
	end
end

---Gets the result of the future (name followed by args).
---@return string
---@return ...
function FutureWaiter:GetResult()
	assert(self._state == STATE.DONE)
	local result = self._result
	self._result = nil
	self._future = nil
	self._state = STATE.IDLE
	return result
end

---Checks if the waiter is done.
---@return boolean
function FutureWaiter:IsDone()
	return self._state == STATE.DONE
end

---Gets a debug string representation of the current state.
---@return string
function FutureWaiter:GetDebugStr()
	if self._state == STATE.STARTED then
		return format("Waiting for future (%s)", self._future:GetName())
	elseif self._state == STATE.DONE then
		return format("Got result from future (%s)", self._future:GetName())
	else
		error("Invalid state: "..tostring(self._state))
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function FutureWaiter.__private:_OnDone(future)
	if future ~= self._future or self._state ~= STATE.STARTED then
		return
	end
	self._result = future:GetValue()
	self._future = nil
	self._state = STATE.DONE
	self._onDoneHandler()
end
