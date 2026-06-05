-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local ErrorConfig = LibTSMApp:Init("Config.ErrorConfig")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local ErrorHandler = LibTSMApp:From("LibTSMService"):Include("Debug.ErrorHandler")
local ErrorFrame = LibTSMApp:From("LibTSMUI"):IncludeClassType("ErrorFrame")
local private = {
	errorFrame = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

ErrorConfig:OnModuleLoad(function()
	ErrorHandler.ConfigureUI(private.ShowUI, private.HideUI)
	SlashCommands.RegisterDebug("error", ErrorHandler.ShowManual)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ShowUI(errorStr, errorInfo, fullErrorInfo, isManual)
	private.errorFrame = private.errorFrame or ErrorFrame.Create()
	private.errorFrame:Show(errorStr, errorInfo, fullErrorInfo, isManual)
end

function private.HideUI()
	if not private.errorFrame then
		return
	end
	private.errorFrame:Hide()
end
