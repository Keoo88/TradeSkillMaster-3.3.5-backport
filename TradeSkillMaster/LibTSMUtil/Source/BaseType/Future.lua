-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Future = LibTSMUtil:DefineClassType("Future")
local EnumType = LibTSMUtil:Include("BaseType.EnumType")
local STATE = EnumType.New("FUTURE_STATE", {
	RESET = EnumType.NewValue(),
	STARTED = EnumType.NewValue(),
	DONE = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Create a new future.
---@param name string The name of the future for debugging purposes
---@return Future
function Future.__static.New(name)
	return Future(name)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function Future.__private:__init(name)
	self._name = name
	self._state = STATE.RESET
	self._value = nil
	self._onDone = nil
	self._onCleanup = nil
end

function Future:__tostring()
	return "Future:"..self._name
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the name for debugging purposes.
---@return string
function Future:GetName()
	return self._name
end

---Registers a script handler.
---@param script FutureScript The script to register for
---@param handler function The script handler
function Future:SetScript(script, handler)
	assert(type(handler) == "function")
	if script == "OnDone" then
		assert(self._state ~= STATE.DONE)
		assert(not self._onDone)
		self._onDone = handler
	elseif script == "OnCleanup" then
		assert(not self._onCleanup)
		self._onCleanup = handler
	else
		error("Unknown script: "..tostring(script))
	end
end

---Marks the future as started.
function Future:Start()
	assert(self._state == STATE.RESET)
	self._state = STATE.STARTED
end

---Marks the future as cancelled and cleans it up.
function Future:Cancel()
	assert(self._state ~= STATE.RESET)
	self:_Reset()
end

---Marks the future as done with the specified result value.
---@param value any The reuslt value
function Future:Done(value)
	assert(self._state == STATE.STARTED)
	self._state = STATE.DONE
	self._value = value
	if self._onDone then
		self._onDone(self)
	end
end

---Returns whether or not the future is done.
---@return boolean
function Future:IsDone()
	assert(self._state ~= STATE.RESET)
	return self._state == STATE.DONE
end

---Returns whether the future is in RESET state and a fresh `Start()` is safe.
---@return boolean
function Future:IsReady()
	return self._state == STATE.RESET
end

---Gets the result value from a future in the done state.
---@return any
function Future:GetValue()
	assert(self._state == STATE.DONE)
	local value = self._value
	self:_Reset()
	return value
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Future.__private:_Reset()
	self._state = STATE.RESET
	self._value = nil
	self._onDone = nil
	if self._onCleanup then
		self._onCleanup()
	end
end
