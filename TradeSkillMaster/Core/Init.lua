-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@class TSM
_G.TSMAddon = TSM -- expose core table to optional toggleable sub-addons (e.g. TradeSkillMaster_Mailing)
local Lifecycle = TSM.LibTSMWoW:Include("Util.Lifecycle")
local AddonSettings = TSM.LibTSMApp:Include("Service.AddonSettings")
local SlashCommands = TSM.LibTSMApp:Include("Service.SlashCommands")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local private = {
	startSystemTime = GetTimePreciseSec(),
	startTime = time(),
}
local TIME_WARNING_THRESHOLD = 0.02



-- ============================================================================
-- Initialization Code
-- ============================================================================

do
	-- Configure LibTSMCore
	TSM.LibTSMCore.SetTimeFunction(function()
		return private.startTime + GetTimePreciseSec() - private.startSystemTime
	end)

	Lifecycle.RegisterCallback(function(event, maxTime)
		if event == Lifecycle.EVENT.LOADED then
			-- Apply the saved addon language before any module initializes so that
			-- strings captured during OnInitialize (e.g. the settings page names
			-- shown in the left navigation) use the selected language instead of
			-- the game client's default locale.
			TSM.Locale.ApplySavedLanguage()
			TSM.LibTSMCore.LoadAll()
			for _, component, path, moduleLoadTime in TSM.LibTSMCore.ModuleInfoIterator() do
				if moduleLoadTime > TIME_WARNING_THRESHOLD then
					Log.Warn("Loading %s->%s took %0.5fs", component, path, moduleLoadTime)
				end
			end
			AddonSettings.LoadDB()
		elseif event == Lifecycle.EVENT.LOGOUT then
			if not TSM.LibTSMCore.UnloadAll(maxTime) then
				return false
			end
			for _, component, path, moduleUnloadTime in TSM.LibTSMCore.ModuleInfoIterator() do
				if moduleUnloadTime > TIME_WARNING_THRESHOLD then
					Log.Warn("Unloading %s->%s took %0.5fs", component, path, moduleUnloadTime)
				end
			end
		end
		return true
	end)

	-- Register a debug slash command to test logging out
	SlashCommands.RegisterDebug("logout", function()
		Lifecycle.TestEvent(Lifecycle.EVENT.LOGOUT)
	end)
end
