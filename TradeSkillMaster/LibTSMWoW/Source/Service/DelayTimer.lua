-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local DelayTimer = LibTSMWoW:DefineClassType("DelayTimer")
local Log = LibTSMWoW:From("LibTSMUtil"):Include("Util.Log")
local private = {
	activeTimers = {},
	frameNumber = 0,
	frame = nil,
}
local MIN_TIME_DURATION = 0.0001
local MIN_FRAMES = 1
local TIME_WARNING_THRESHOLD = 0.05



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new timer.
---@param label string A label which is used for debugging purposes
---@param callback fun() The function to call when the timer expires
---@return DelayTimer
function DelayTimer.__static.New(label, callback)
	assert(type(label) == "string" and type(callback) == "function")
	return DelayTimer(label, callback)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function DelayTimer.__private:__init(name, callback)
	private.CreateFrame()
	self._name = name
	self._callback = callback
	self._endTime = nil
	self._endFrame = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Runs for the specified amount of time (ignored if the timer is already running).
---@param seconds number The amount of time to run in seconds
function DelayTimer:RunForTime(seconds)
	if self._endTime then
		-- Already running
		return
	end
	assert(not self._endFrame)
	self._endTime = GetTime() + max(seconds, MIN_TIME_DURATION)
	assert(not private.activeTimers[self])
	private.activeTimers[self] = true
end

---Runs for the specified number of frames (ignored if the timer is already running).
---@param frames number The amount of time to run in frames
function DelayTimer:RunForFrames(frames)
	if self._endFrame then
		-- Already running
		return
	end
	assert(not self._endTime)
	self._endFrame = private.frameNumber + max(frames, MIN_FRAMES)
	assert(not private.activeTimers[self])
	private.activeTimers[self] = true
end

---Cancels the timer.
function DelayTimer:Cancel()
	if not self._endTime and not self._endFrame then
		-- Not running
		return
	end
	assert(private.activeTimers[self])
	private.activeTimers[self] = nil
	self._endTime = nil
	self._endFrame = nil
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
function DelayTimer:_CheckIfDone()
	assert(private.activeTimers[self])
	if (self._endTime or math.huge) <= GetTime() or (self._endFrame or math.huge) <= private.frameNumber then
		self._endTime = nil
		self._endFrame = nil
		private.activeTimers[self] = nil
		local startTime = LibTSMWoW.GetTime()
		self._callback()
		local timeTaken = LibTSMWoW.GetTime() - startTime
		if timeTaken > TIME_WARNING_THRESHOLD then
			Log.Warn("Delay callback (%s) took %0.5fs", self._name, timeTaken)
		end
		return true
	end
	return false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CreateFrame()
	if private.frame then
		return
	end
	private.frame = CreateFrame("Frame")
	private.frame:SetScript("OnUpdate", private.ProcessDelays)
	private.frame:Show()
end

function private.ProcessDelays()
	private.frameNumber = private.frameNumber + 1
	-- The active timers can change as we complete them, so only do one per loop and keep looping until they're all processed
	local hadDoneTimer = true
	while hadDoneTimer do
		hadDoneTimer = false
		for timer in pairs(private.activeTimers) do
			if timer:_CheckIfDone() then
				hadDoneTimer = true
				break
			end
		end
	end
end
