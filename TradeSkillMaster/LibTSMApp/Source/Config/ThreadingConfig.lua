-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local ThreadingConfig = LibTSMApp:Init("Config.ThreadingConfig")
local ErrorHandler = LibTSMApp:From("LibTSMService"):Include("Debug.ErrorHandler")
local Threading = LibTSMApp:From("LibTSMTypes"):Include("Threading")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local private = {
	schedulerFrame = nil,
}
local MAX_TIME_USAGE_RATIO = 0.25
local MAX_QUANTUM = 0.01



-- ============================================================================
-- Module Loading
-- ============================================================================

ThreadingConfig:OnModuleLoad(function()
	-- Create the scheduler frame
	private.schedulerFrame = CreateFrame("Frame")
	private.schedulerFrame:Hide()
	private.schedulerFrame:SetScript("OnUpdate", function(_, elapsed)
		-- Don't run the scheduler while in combat
		if ClientInfo.IsInCombat() then
			return
		end
		Threading.RunScheduler(min(elapsed * MAX_TIME_USAGE_RATIO, MAX_QUANTUM))
	end)
	private.schedulerFrame:SetScript("OnEvent", function(_, event, ...)
		Threading.HandleEvent(event, ...)
	end)

	-- Configure the threading code
	local function EventRegisterFunc(eventName)
		private.schedulerFrame:RegisterEvent(eventName)
	end
	local function SchedulerShouldRunFunc(shouldRun)
		local running = private.schedulerFrame:IsVisible() and true or false
		if running == shouldRun then
			return
		elseif shouldRun then
			private.schedulerFrame:Show()
			Log.Info("Starting the scheduler")
		else
			private.schedulerFrame:Hide()
			Log.Info("Stopped the scheduler")
		end
	end
	Threading.Configure(ErrorHandler.ShowForThread, EventRegisterFunc, SchedulerShouldRunFunc)
end)
