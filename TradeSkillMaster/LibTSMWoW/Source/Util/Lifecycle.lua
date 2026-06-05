-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_NAME = ...
local LibTSMWoW = select(2, ...).LibTSMWoW
local Lifecycle = LibTSMWoW:Init("Util.Lifecycle")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local Analytics = LibTSMWoW:From("LibTSMUtil"):Include("Util.Analytics")
local private = {
	eventFrames = {},
	callbacks = {},
	callbackHandled = {},
	totalTime = {},
	isDone = {},
}
local EVENT = EnumType.New("LIFECYCLE_EVENT", {
	LOADED = EnumType.NewValue(),
	LOGIN = EnumType.NewValue(),
	LOGOUT = EnumType.NewValue(),
})
Lifecycle.EVENT = EVENT
-- We split the event handling across multiple frames to avoid tripping the 19 second per-script timeout
local NUM_EVENT_FRAMES = 10
local MAX_TIME_PER_EVENT = 12
local ANALYTICS_ACTION_LOOKUP = {
	[EVENT.LOADED] = "ADDON_INITIALIZE",
	[EVENT.LOGIN] = "ADDON_ENABLE",
	[EVENT.LOGOUT] = "ADDON_DISABLE",
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Lifecycle:OnModuleLoad(function()
	for _ = 1, NUM_EVENT_FRAMES do
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("ADDON_LOADED")
		frame:RegisterEvent("PLAYER_LOGIN")
		frame:RegisterEvent("PLAYER_LOGOUT")
		frame:SetScript("OnEvent", private.OnEvent)
		tinsert(private.eventFrames, frame)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback for lifecycle events.
---@param func fun(event: EnumValue, maxTime: number): boolean The callback function (called multiple times until it returns true)
---@param eventFilter? EnumValue An event filter (or nil to receive all events)
function Lifecycle.RegisterCallback(func, eventFilter)
	assert(func and not private.callbacks[func])
	tinsert(private.callbacks, func)
	assert(eventFilter == nil or EnumType.IsValue(eventFilter, EVENT))
	private.callbacks[func] = eventFilter or true
end

---Processes a lifecycle event for test purposes.
---@param event EnumValue The event to process
function Lifecycle.TestEvent(event)
	assert(EnumType.IsValue(event, EVENT))
	assert(private.DoCallbacks(event, math.huge))
	wipe(private.callbackHandled[event])
	private.totalTime[event] = nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnEvent(frame, event, arg)
	local isLastFrame = frame == private.eventFrames[#private.eventFrames]
	local lifecycleEvent = nil
	if event == "ADDON_LOADED" and arg == ADDON_NAME then
		assert(not private.isDone[EVENT.LOGIN] and not private.isDone[EVENT.LOGOUT])
		lifecycleEvent = EVENT.LOADED
	elseif event == "PLAYER_LOGIN" then
		assert(private.isDone[EVENT.LOADED] and not private.isDone[EVENT.LOGOUT])
		lifecycleEvent = EVENT.LOGIN
	elseif event == "PLAYER_LOGOUT" then
		assert(private.isDone[EVENT.LOADED])
		lifecycleEvent = EVENT.LOGOUT
		if not private.isDone[EVENT.LOGIN] then
			-- This can happen if the player exits the game during the loading screen, in which case we just ignore it
			private.isDone[lifecycleEvent] = true
		end
	end
	if not lifecycleEvent or private.isDone[lifecycleEvent] then
		return
	end
	if private.DoCallbacks(lifecycleEvent, LibTSMWoW.GetTime() + MAX_TIME_PER_EVENT) then
		private.isDone[lifecycleEvent] = true
		Analytics.Action(ANALYTICS_ACTION_LOOKUP[lifecycleEvent], floor(private.totalTime[lifecycleEvent]))
	elseif isLastFrame then
		error("Ran out of event frames for "..tostring(lifecycleEvent))
	end
end

function private.DoCallbacks(event, maxTime)
	local done = true
	local startTime = LibTSMWoW.GetTime()
	private.callbackHandled[event] = private.callbackHandled[event] or {}
	for _, callback in ipairs(private.callbacks) do
		local filter = private.callbacks[callback]
		if not private.callbackHandled[event][callback] and (filter == true or filter == event) then
			if LibTSMWoW.GetTime() >= maxTime then
				done = false
				break
			end
			if callback(event, maxTime) then
				private.callbackHandled[event][callback] = true
			else
				done = false
			end
		end
	end
	private.totalTime[event] = (private.totalTime[event] or 0) + LibTSMWoW.GetTime() - startTime
	return done
end
