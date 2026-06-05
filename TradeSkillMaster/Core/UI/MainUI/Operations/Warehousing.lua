-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Warehousing = TSM.MainUI.Operations:NewPackage("Warehousing")
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local WarehousingOperation = TSM.LibTSMSystem:Include("WarehousingOperation")
local private = {
	currentOperationName = nil,
}
local MOVE_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local STACK_SIZE_VALIDATE_CONTEXT = {
	isNumber = true,
}
local KEEP_BAG_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local KEEP_BANK_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local RESTOCK_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local RESTOCK_STACK_SIZE_VALIDATE_CONTEXT = {
	isNumber = true,
}
local RESTOCK_KEEP_BANK_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local SETTING_TOOLTIPS = {
	moveQuantity = L["The number of items to move in or out of the bank via the Bank UI."],
	stackSize = L["Moves items in or out of the bank in the defined stack size. Set to 0 to disable."],
	keepBagQuantity = L["The number of items to keep in the character's bags when moving items to the bank."],
	keepBankQuantity = L["The number of items to keep in the bank when moving items to the character's bags."],
	restockQuantity = L["The maximum number of items to restock to a character's bags. Set this to 0 in order to always move the set 'Move quantity' value."],
	restockStackSize = L["Only move items in the defined stack size i.e stack of 5 for destroying. Set to 0 to disable."],
	restockKeepBankQuantity = L["The number of items to keep in the bank when moving items to the characters bags."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Warehousing.OnInitialize()
	MOVE_QUANTITY_VALIDATE_CONTEXT.minValue, MOVE_QUANTITY_VALIDATE_CONTEXT.maxValue = WarehousingOperation.GetMinMaxValues("moveQuantity")
	STACK_SIZE_VALIDATE_CONTEXT.minValue, STACK_SIZE_VALIDATE_CONTEXT.maxValue = WarehousingOperation.GetMinMaxValues("stackSize")
	KEEP_BAG_QUANTITY_VALIDATE_CONTEXT.minValue, KEEP_BAG_QUANTITY_VALIDATE_CONTEXT.maxValue = WarehousingOperation.GetMinMaxValues("keepBagQuantity")
	KEEP_BANK_QUANTITY_VALIDATE_CONTEXT.minValue, KEEP_BANK_QUANTITY_VALIDATE_CONTEXT.maxValue = WarehousingOperation.GetMinMaxValues("keepBankQuantity")
	TSM.MainUI.Operations.RegisterModule("Warehousing", private.GetWarehousingOperationSettings)
end



-- ============================================================================
-- Warehousing Operation Settings UI
-- ============================================================================

function private.GetWarehousingOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "warehousing")
	private.currentOperationName = operationName
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Warehousing", "moveSettings", L["Move Quantity Options"], L["Set how items are moved out of the bank."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("moveQuantity", L["Quantity to move"], MOVE_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.moveQuantity)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("stackSize", L["Stack size multiple"], STACK_SIZE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.stackSize)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("keepBagQuantity", L["Keep in bags quantity"], KEEP_BAG_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.keepBagQuantity)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("keepBankQuantity", L["Keep in bank quantity"], KEEP_BANK_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.keepBankQuantity)
				:SetMargin(0, 0, 0, 4)
			)
		)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Warehousing", "restockSettings", L["Restock Options"], L["Set how items are restocked from the bank."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockQuantity", L["Restock quantity"], RESTOCK_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.restockQuantity)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockStackSize", L["Stack size multiple"], RESTOCK_STACK_SIZE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.restockStackSize)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockKeepBankQuantity", L["Keep in bank quantity"], RESTOCK_KEEP_BANK_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.restockKeepBankQuantity)
				:SetMargin(0, 0, 0, 4)
			)
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Warehousing", private.currentOperationName))
end
