-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Threading = LibTSMTypes:Init("Threading")
local Thread = LibTSMTypes:IncludeClassType("Thread")
local EventWaiter = LibTSMTypes:IncludeClassType("EventWaiter")
local Scheduler = LibTSMTypes:Include("Threading.Scheduler")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local TIME_WARNING_THRESHOLD = 0.1



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the threading module.
---@param errorHandler fun(msg: string, co: thread) The error handler
---@param eventRegisterFunc fun(event: string) The function to register for events
---@param shouldSchedulerRunFunc fun(shouldRun: boolean) The function to call when the scheduler should be started or stopped
function Threading.Configure(errorHandler, eventRegisterFunc, shouldSchedulerRunFunc)
	Thread.Configure(errorHandler)
	EventWaiter.SetEventRegisterFunc(eventRegisterFunc)
	Scheduler.Configure(shouldSchedulerRunFunc)
end

---Create a new thread.
---@param name string The name of the thread (for debugging purposes)
---@param func function The thread's main function
---@return string
function Threading.New(name, func)
	local thread = Thread.New(name, func)
	local threadId = name.."-"..tostring(func)
	Scheduler.AddThread(threadId, thread)
	return threadId
end

---Set the callback for a thread.
-- The callback is called when a thread finishes running and is passed all values returned by the thread's main function.
---@param threadId string The thread id
---@param callback function The callback function
function Threading.SetCallback(threadId, callback)
	Scheduler.GetThread(threadId):SetCallback(callback)
end

---Start a thread.
---
-- The thread will not actually be run until the next run of the scheduler.
---@param threadId string The thread id
---@param ... any Arguments to pass to the thread's main function
function Threading.Start(threadId, ...)
	Scheduler.StartThread(threadId, ...)
end

---Send a message to a thread.
---@param threadId string The thread id
---@param msg any The message
function Threading.SendMessage(threadId, msg)
	Scheduler.GetThread(threadId):QueueMessage(msg)
end

---Send a synchronous message to a thread and blocks until the message is delivered.
---
---NOTE: The msg value must not evalulate as equal with any other messages sent to the thread.
---@param threadId string The thread ID to send to
---@param msg any The message
function Threading.SendSyncMessage(threadId, msg)
	Thread.SendSyncMessage(Scheduler.GetThread(threadId), msg)
end

---Kills the specified thread.
---@param thread Thread
function Threading.Kill(threadId)
	Scheduler.GetThread(threadId):Kill()
end

---Returns whether or not we're currently in a thread context.
---@return boolean
function Threading.IsThreadContext()
	return Thread.GetRunningThread() ~= nil
end

---Check if the current thread has any pending messages (must be in a thread context).
---@return boolean
function Threading.HasPendingMessage()
	return Thread.GetRunningThread():HasPendingMessage()
end

---Receive the next message (must be in a thread context).
---@return any
function Threading.ReceiveMessage()
	return Thread.GetRunningThread():ReceiveMessage()
end

---Allows yielding from a thread if it has used up its elapsed time (must be in a thread context).
---
---This should be called regularly to allow threads to yield when they've used up their allotted time.
---@param force boolean Whether or not to force a yield
function Threading.Yield(force)
	Thread.GetRunningThread():Yield(force)
end

---Causes the current thread to sleep (must be in a thread context).
---@param seconds number The time to sleep for in seconds
function Threading.Sleep(seconds)
	Thread.GetRunningThread():Sleep(seconds)
end

---Wait for an event and return the event name and its arguments (must be in a thread context).
---@param ... WowEvent The events to wait for
---@return string
---@return ...
function Threading.WaitForEvent(...)
	return Thread.GetRunningThread():WaitForEvent(...)
end

---Wait for a function to return a truthy value and return its result (must be in a thread context).
---@param func function The function to wait for
---@param ... any Additional arguments to pass to the function
---@return ...
function Threading.WaitForFunction(func, ...)
	return Thread.GetRunningThread():WaitForFunction(func, ...)
end

---Wait for a future to complete and return its result (must be in a thread context).
---@param future Future The future to wait for
---@return any
function Threading.WaitForFuture(future)
	return Thread.GetRunningThread():WaitForFuture(future)
end

---Acquire a temp table which is owned by the current thread (must be in a thread context).
---
---Any time a thread needs to maintain a temp table across a potential yield, it should use this API.
---This API will release the temp tables in the case that the thread gets killed.
---@param ... any Values to insert into the temp table
---@return table
function Threading.AcquireSafeTempTable(...)
	return Thread.GetRunningThread():AcquireSafeTempTable(...)
end

---Assign ownership of a database query to the thread so that if the thread is killed it'll get released safely (must be in a thread context).
---@param query DatabaseQuery The query object
function Threading.GuardDatabaseQuery(query)
	Thread.GetRunningThread():GuardDatabaseQuery(query)
end

---Removes ownership of a database query from the thread (must be in a thread context).
---@param query DatabaseQuery The query object
function Threading.UnguardDatabaseQuery(query)
	Thread.GetRunningThread():UnguardDatabaseQuery(query)
end

---Runs the scheduler.
---@param totalTime number The amount of time to run for
function Threading.RunScheduler(totalTime)
	local startTime = LibTSMTypes.GetTime()
	Scheduler.Run(totalTime)
	local timeTaken = LibTSMTypes.GetTime() - startTime
	if timeTaken > TIME_WARNING_THRESHOLD then
		Log.Warn("Scheduler took %.5fs", timeTaken)
	end
end

---Notifies all threads of a WoW event.
---@param name WowEvent The event name
---@param ... any The event arguments
function Threading.HandleEvent(event, ...)
	local startTime = LibTSMTypes.GetTime()
	Scheduler.HandleEvent(event, ...)
	local timeTaken = LibTSMTypes.GetTime() - startTime
	if timeTaken > TIME_WARNING_THRESHOLD then
		Log.Warn("Scheduler took %.5fs to process %s", timeTaken, tostring(event))
	end

end

---Returns whether or not the scheduler as at least one alive thread.
---@return boolean
function Threading.HasAliveThread()
	return Scheduler.HasAliveThread()
end

---Gets a debug string which represents the state of all threads.
---@return string
function Threading.GetDebugStr()
	return Scheduler.GetDebugStr()
end
