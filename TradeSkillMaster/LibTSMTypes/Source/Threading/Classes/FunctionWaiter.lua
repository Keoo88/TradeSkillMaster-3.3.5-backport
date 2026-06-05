-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local FunctionWaiter = LibTSMTypes:DefineClassType("FunctionWaiter")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Vararg")
local STATE = EnumType.New("FUNCTION_WAITER_STATE", {
	IDLE = EnumType.NewValue(),
	STARTED = EnumType.NewValue(),
	DONE = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new function waiter.
---@return FunctionWaiter
function FunctionWaiter.__static.New()
	return FunctionWaiter()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function FunctionWaiter.__private:__init()
	self._state = STATE.IDLE
	self._func = nil
	self._args = {}
	self._result = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Resets the waiter.
function FunctionWaiter:Reset()
	self._state = STATE.IDLE
	self._func = nil
	wipe(self._args)
	wipe(self._result)
end

---Starts the waiter.
---@param func function The function to wait for
---@param ... any Arguments to pass to the function
function FunctionWaiter:Start(func, ...)
	assert(self._state == STATE.IDLE)
	self._func = func
	Vararg.IntoTable(self._args, ...)
	self._state = STATE.STARTED
end

---Gets the result of the function.
---@return ...
function FunctionWaiter:GetResult()
	assert(self._state == STATE.DONE)
	self._func = nil
	self._state = STATE.IDLE
	return Table.UnpackAndWipe(self._result)
end

---Checks if the waiter is done (will call the function is the waiter is currently running).
---@return boolean
function FunctionWaiter:IsDone()
	assert(self._state ~= STATE.IDLE)
	if self._state == STATE.STARTED then
		self:_HandleFunctionResult(self._func(unpack(self._args)))
	end
	return self._state == STATE.DONE
end

---Gets a debug string representation of the current state.
---@return string
function FunctionWaiter:GetDebugStr()
	if self._state == STATE.STARTED then
		return format("Waiting for %s", self:_GetFunctionDebugName())
	elseif self._state == STATE.DONE then
		return format("Got result from %s", self:_GetFunctionDebugName())
	else
		error("Invalid state: "..tostring(self._state))
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function FunctionWaiter.__private:_HandleFunctionResult(...)
	if not select(1, ...) then
		return
	end
	assert(self._state == STATE.STARTED)
	Vararg.IntoTable(self._result, ...)
	wipe(self._args)
	self._state = STATE.DONE
end

function FunctionWaiter.__private:_GetFunctionDebugName()
	-- Look up to 2 levels deep in the globals table for the name of this function
	for k, v in pairs(_G) do
		if type(v) == "table" then
			for k2, v2 in pairs(v) do
				if v2 == self._func then
					return tostring(k).."."..tostring(k2)
				end
			end
		elseif v == self._func then
			return tostring(k)
		end
	end
	return tostring(self._func)
end
