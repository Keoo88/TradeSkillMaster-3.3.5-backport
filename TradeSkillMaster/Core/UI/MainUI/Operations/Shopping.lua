-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Shopping = TSM.MainUI.Operations:NewPackage("Shopping")
local Operation = TSM.LibTSMTypes:Include("Operation")
local ShoppingOperation = TSM.LibTSMSystem:Include("ShoppingOperation")
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	currentOperationName = nil,
}
local RESTOCK_SOURCES = { L["Alts"], L["Auctions"], BANK, GUILD }
local RESTOCK_SOURCES_KEYS = { "alts", "auctions", "bank", "guild" }
local MAX_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local MAX_PRICE_VALIDATE_CONTEXT = {
	badSources = {
		shoppingopmax = true,
	}
}
local SETTING_TOOLTIPS = {
	maxPrice = L["The max price to show in the shopping results."],
	showAboveMaxPrice = L["If enabled, auctions above the defined max price will be shown in shopping results."],
	restockQuantity = L["The maximum number of items to have in your inventory."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Shopping.OnInitialize()
	MAX_QUANTITY_VALIDATE_CONTEXT.minValue, MAX_QUANTITY_VALIDATE_CONTEXT.maxValue = ShoppingOperation.GetRestockRange()
	TSM.MainUI.Operations.RegisterModule("Shopping", private.GetShoppingOperationSettings)
end



-- ============================================================================
-- Shopping Operation Settings UI
-- ============================================================================

function private.GetShoppingOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "shopping")
	private.currentOperationName = operationName
	local operation = Operation.GetSettings("Shopping", private.currentOperationName)
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetBackgroundColor("PRIMARY_BG")
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Shopping", "generalOptions", L["General Options"], L["Set what items are shown during a Shopping scan."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("maxPrice", L["Maximum auction price"], MAX_PRICE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.maxPrice))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("showAboveMaxPrice", L["Show auctions above max price"])
				:SetMargin(0, 0, 12, 12)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetSettingInfo(operation, "showAboveMaxPrice")
					:SetDisabled(Operation.HasRelationship("Shopping", private.currentOperationName, "showAboveMaxPrice"))
					:SetTooltip(SETTING_TOOLTIPS.showAboveMaxPrice)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockQuantity", L["Maximum restock quantity"], MAX_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.restockQuantity)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockSources", L["Sources to include for restock"])
				:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
					:SetHeight(24)
					:SetItems(RESTOCK_SOURCES, RESTOCK_SOURCES_KEYS)
					:SetSettingInfo(operation, "restockSources")
					:SetSelectionText(L["No Sources"], L["%d Sources"], L["All Sources"])
					:SetDisabled(Operation.HasRelationship("Shopping", private.currentOperationName, "restockSources"))
					:SetTooltip(SETTING_TOOLTIPS.restockSources)
				)
			)
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Shopping", private.currentOperationName))
end
