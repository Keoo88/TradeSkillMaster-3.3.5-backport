-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Event = LibTSMWoW:Init("Service.Event")
local TempTable = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.TempTable")
local Reactive = LibTSMWoW:From("LibTSMUtil"):Include("Reactive")
local Log = LibTSMWoW:From("LibTSMUtil"):Include("Util.Log")
local private = {
	registry = {
		event = {},
		callback = {},
	},
	registeredEventCount = {},
	eventFrame = nil,
	allEventsFrame = nil,
	temp = {},
	eventQueue = {},
	processingEvent = false,
	stream = nil,
	publisherEvent = {},
	allEventsCallbacks = {},
}
local TIME_WARNING_THRESHOLD = 0.02



-- ============================================================================
-- Module Loading
-- ============================================================================

Event:OnModuleLoad(function()
	private.eventFrame = CreateFrame("Frame")
	private.eventFrame:SetScript("OnEvent", private.EventHandler)
	private.eventFrame:Show()
	private.allEventsFrame = CreateFrame("Frame")
	private.allEventsFrame:SetScript("OnEvent", private.AllEventsHandler)
	private.allEventsFrame:Show()

	private.stream = Reactive.CreateStream()
	private.stream:SetScript("OnPublisherCancelled", function(_, publisher)
		local event = private.publisherEvent[publisher]
		private.publisherEvent[publisher] = nil
		assert(event)
		private.UnregisterHelper(event)
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers an event callback.
---@param event string The WoW event to register for (i.e. BAG_UPDATE)
---@param callback function The function to be called from the event handler
function Event.Register(event, callback)
	assert(type(event) == "string" and event == strupper(event) and type(callback) == "function")
	-- make sure this event/callback isn't already registered
	for i = 1, #private.registry.event do
		assert(private.registry.event[i] ~= event or private.registry.callback[i] ~= callback)
	end
	tinsert(private.registry.event, event)
	tinsert(private.registry.callback, callback)
	private.RegisterHelper(event)
end

---Unregisters an event callback.
---@param event string The WoW event which the callback was registered for
---@param callback function The function which was passed to @{Event.Register} for this event
function Event.Unregister(event, callback)
	assert(type(event) == "string" and event == strupper(event) and type(callback) == "function")
	local index = nil
	for i = 1, #private.registry.event do
		if private.registry.event[i] == event and private.registry.callback[i] == callback then
			assert(not index)
			index = i
		end
	end
	assert(index)
	private.UnregisterHelper(event)
	tremove(private.registry.event, index)
	tremove(private.registry.callback, index)
end

---Gets a publisher for the specified event.
---@param event string The WoW event
---@return ReactivePublisher The publisher
function Event.GetPublisher(event)
	private.RegisterHelper(event)
	local publisher = private.stream:Publisher()
		:IgnoreIfKeyNotEquals(1, event)
	assert(not private.publisherEvent[publisher])
	private.publisherEvent[publisher] = event
	return publisher
end

---Registers a callback for all events (should be used with great care).
---@param callback fun(event: string, ...) The function to be called from the event handler
function Event.RegisterAllEvents(callback)
	if #private.allEventsCallbacks == 0 then
		private.allEventsFrame:RegisterAllEvents()
	end
	tinsert(private.allEventsCallbacks, callback)
end

---Unregisters a callback for all events.
---@param callback function The function which was passed to @{Event.RegisterAllEvents}
function Event.UnregisterAllEvents(callback)
	local index = nil
	for i = 1, #private.allEventsCallbacks do
		if private.allEventsCallbacks[i] == callback then
			assert(not index)
			index = i
		end
	end
	assert(index)
	tremove(private.allEventsCallbacks, index)
	if #private.allEventsCallbacks == 0 then
		private.allEventsFrame:UnregisterAllEvents()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RegisterHelper(event)
	private.registeredEventCount[event] = private.registeredEventCount[event] or 0
	if private.registeredEventCount[event] == 0 then
		private.eventFrame:RegisterEvent(event)
	end
	private.registeredEventCount[event] = private.registeredEventCount[event] + 1
end

function private.UnregisterHelper(event)
	private.registeredEventCount[event] = private.registeredEventCount[event] - 1
	assert(private.registeredEventCount[event] >= 0)
	if private.registeredEventCount[event] == 0 then
		private.eventFrame:UnregisterEvent(event)
		private.registeredEventCount[event] = nil
	end
end

function private.ProcessEvent(context)
	local event = context[1]
	assert(type(event) == "string")
	-- NOTE: The registered events may change within the callback, so copy them to a temp table
	wipe(private.temp)
	for i = 1, #private.registry.event do
		if private.registry.event[i] == event then
			tinsert(private.temp, private.registry.callback[i])
		end
	end
	for _, callback in ipairs(private.temp) do
		local startTime = LibTSMWoW.GetTime()
		callback(unpack(context))
		local timeTaken = LibTSMWoW.GetTime() - startTime
		if timeTaken > TIME_WARNING_THRESHOLD then
			Log.Warn("Event (%s) callback took %0.5fs", event, timeTaken)
		end
	end
	private.stream:Send(context)
end

function private.EventHandler(_, event, ...)
	local context = TempTable.Acquire(event, ...)
	if private.processingEvent then
		-- We are already in the middle of processing another event, so queue this one up
		if #private.eventQueue < 50 then
			tinsert(private.eventQueue, context)
		end
		return
	end
	private.processingEvent = true
	private.ProcessEvent(context)
	TempTable.Release(context)
	-- Process queued events
	while #private.eventQueue > 0 do
		local queuedContext = tremove(private.eventQueue, 1)
		private.ProcessEvent(queuedContext)
		TempTable.Release(queuedContext)
	end
	private.processingEvent = false
end

function private.AllEventsHandler(_, event, ...)
	for _, func in ipairs(private.allEventsCallbacks) do
		func(event, ...)
	end
end
