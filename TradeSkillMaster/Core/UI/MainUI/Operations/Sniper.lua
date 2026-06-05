-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Sniper = TSM.MainUI.Operations:NewPackage("Sniper")
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	currentOperationName = nil,
}
local MAX_PRICE_VALIDATE_CONTEXT = {
	badSources = {
		sniperopmax = true,
	}
}
local SETTING_TOOLTIPS = {
	belowPrice = L["The maximum price of an auction to be included in the sniper results."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sniper.OnInitialize()
	TSM.MainUI.Operations.RegisterModule("Sniper", private.GetSniperOperationSettings)
end



-- ============================================================================
-- Sniper Operation Settings UI
-- ============================================================================

function private.GetSniperOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "sniper")
	private.currentOperationName = operationName
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetBackgroundColor("PRIMARY_BG")
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Sniper", "settings", L["General Options"], L["Set what items are shown during a Sniper scan."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("belowPrice", L["Maximum price"], MAX_PRICE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.belowPrice))
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Sniper", private.currentOperationName))
end
