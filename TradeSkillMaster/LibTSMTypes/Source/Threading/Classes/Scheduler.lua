-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Scheduler = LibTSMTypes:Init("Threading.Scheduler")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local DebugStack = LibTSMTypes:From("LibTSMUtil"):Include("Lua.DebugStack")
local private = {
	shouldRunFunc = nil,
	threads = {}, ---@type table<string,Thread>
	queue = {}, ---@type Thread[]
}
local EXCESSIVE_TIME_USED_RATIO = 1.2
local EXCESSIVE_TIME_LOG_THRESHOLD = 0.1



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the scheduler.
---@param shouldRunFunc fun(shouldRun: boolean) The function to call when the scheduler should be started or stopped
function Scheduler.Configure(shouldRunFunc)
	private.shouldRunFunc = shouldRunFunc
end

---Adds a thread to the scheduler.
---@param threadId string The thread ID
---@param thread Thread The thread
function Scheduler.AddThread(threadId, thread)
	private.threads[threadId] = thread
end

---Start a thread.
---
-- The thread will not actually be run until the next run of the scheduler.
---@param threadId string The thread id
---@param ... any Arguments to pass to the thread's main function
function Scheduler.StartThread(threadId, ...)
	private.threads[threadId]:Start(...)
	private.shouldRunFunc(true)
end

---Gets a thread by its ID.
---@param threadId string The thread ID
---@return Thread
function Scheduler.GetThread(threadId)
	return private.threads[threadId]
end

---Runs the scheduler.
---@param totalTime number The amount of time to run for
function Scheduler.Run(totalTime)
	local numReadyThreads = 0
	wipe(private.queue)

	-- Go through all the threads, update their state, and add the ready ones into the queue
	for _, thread in pairs(private.threads) do
		thread:UpdateState()
		if thread:CanRun() then
			numReadyThreads = numReadyThreads + 1
			tinsert(private.queue, thread)
		end
	end

	-- Keep running threads until we use up all the available time
	local remainingTime = totalTime
	local ranThread = true
	while ranThread and remainingTime > 0.00001 do
		ranThread = false
		for i = #private.queue, 1, -1 do
			local thread = private.queue[i]
			if thread:CanRun() then
				local quantum = remainingTime / numReadyThreads
				local elapsedTime = thread:Run(quantum)
				thread._cpuTimeUsed = thread._cpuTimeUsed + elapsedTime
				remainingTime = remainingTime - min(elapsedTime, quantum)
				-- Any thread which ran excessively long should be ignored for future loops
				if elapsedTime > EXCESSIVE_TIME_USED_RATIO * quantum and elapsedTime > quantum + 1 then
					if elapsedTime > EXCESSIVE_TIME_LOG_THRESHOLD then
						local line = DebugStack.GetLocation(2, thread._co)
						Log.Warn("Thread %s ran too long (%.4f/%.4f): %s", thread._name, elapsedTime, quantum, line or "?")
					end
					tremove(private.queue, i)
				end
				ranThread = true
			end
		end
	end

	if not Scheduler.HasAliveThread() then
		private.shouldRunFunc(false)
	end
end

---Returns whether or not the scheduler as at least one alive thread.
---@return boolean
function Scheduler.HasAliveThread()
	for _, thread in pairs(private.threads) do
		if thread:IsAlive() then
			return true
		end
	end
	return false
end

---Processes a WoW event.
---@param name WowEvent The event name
---@param ... any The event arguments
function Scheduler.HandleEvent(event, ...)
	for _, thread in pairs(private.threads) do
		thread:HandleEvent(event, ...)
	end
end

---Gets a debug string which represents the state of all threads managed by the scheduler.
---@return string
function Scheduler.GetDebugStr()
	local lines = {}
	for _, thread in pairs(private.threads) do
		if thread:IsAlive() then
			local name, stateStr, timeStr, createStr, startStr, backtrace = thread:GetDebugInfo()
			tinsert(lines, name)
			tinsert(lines, "  "..stateStr)
			tinsert(lines, "  "..timeStr)
			tinsert(lines, "  "..createStr)
			tinsert(lines, "  "..startStr)
			if #backtrace > 0 then
				tinsert(lines, "  Backtrace:")
				for _, line in ipairs(backtrace) do
					tinsert(lines, "    "..line)
				end
			end
		end
	end
	return table.concat(lines, "\n")
end
