-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Vendoring = TSM.MainUI.Operations:NewPackage("Vendoring")
local Operation = TSM.LibTSMTypes:Include("Operation")
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local VendoringOperation = TSM.LibTSMSystem:Include("VendoringOperation")
local private = {
	currentOperationName = nil,
}
local RESTOCK_SOURCES = { BANK, GUILD, L["Alts"], L["Alts AH"], L["AH"], L["Mail"] }
local RESTOCK_SOURCES_KEYS = { "bank", "guild", "alts", "alts_ah", "ah", "mail" }
local SETTING_INFO = {
	restockQty = "INPUT_POPOUT",
	restockSources = "DROPDOWN",
	keepQty = "INPUT_POPOUT",
	sellAfterExpired = "INPUT_POPOUT",
	vsMarketValue = "INPUT_POPOUT",
	vsMaxMarketValue = "INPUT_POPOUT",
	vsDestroyValue = "INPUT_POPOUT",
	vsMaxDestroyValue = "INPUT_POPOUT",
	sellSoulbound = "TOGGLE",
}
local SELL_AFTER_EXPIRED_QTY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local KEEP_QTY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local RESTOCK_QTY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local SETTING_TOOLTIPS = {
	enableBuy = L["If enabled, items in the selected group will be purchased from the targeted vendor."],
	restockQty = L["The maximum number of items to have in your inventory when purchasing items from the targeted vendor. A value of 0 indicates no maximum restock quantity."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
	enableSell = L["If enabled, items in the selected group will be sold to the targeted vendor."],
	keepQty = L["The number of items to keep on hand before selling to the vendor."],
	sellAfterExpired = L["The minimum number times an item has expired from previously posted auctions before being eligible to be sold to a vendor."],
	vsMarketValue = L["A custom string to define the market value TSM references when determining whether to vendor an item based on the threshold defined in 'Max market value' field."],
	vsMaxMarketValue = L["A custom string to define the threshold of the 'Market value' to consider items for vendoring. Set this to '0c' to disable this condition."],
	vsDestroyValue = L["A custom string to define the destroy value TSM references when determining whether to vendor an item based on the threshold defined in 'Max destroy value' field."],
	vsMaxDestroyValue = L["A custom string to define the threshold of the 'Destroy value' to consider items for vendoring. Set this to '0c' to disable this condition."],
	sellSoulbound = L["If enabled, items that are soulbound will be sold to the targeted vendor."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Vendoring.OnInitialize()
	SELL_AFTER_EXPIRED_QTY_VALIDATE_CONTEXT.minValue, SELL_AFTER_EXPIRED_QTY_VALIDATE_CONTEXT.maxValue = VendoringOperation.GetMinMaxValues("sellAfterExpired")
	KEEP_QTY_VALIDATE_CONTEXT.minValue, KEEP_QTY_VALIDATE_CONTEXT.maxValue = VendoringOperation.GetMinMaxValues("keepQty")
	RESTOCK_QTY_VALIDATE_CONTEXT.minValue, RESTOCK_QTY_VALIDATE_CONTEXT.maxValue = VendoringOperation.GetMinMaxValues("restockQty")
	TSM.MainUI.Operations.RegisterModule("Vendoring", private.GetVendoringOperationSettings)
end



-- ============================================================================
-- Vendoring Operation Settings UI
-- ============================================================================

function private.GetVendoringOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "vendoring")
	private.currentOperationName = operationName

	local operation = Operation.GetSettings("Vendoring", private.currentOperationName)
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Vendoring", "buyOptionsHeading", L["Buy Options"], L["Set what is bought from a vendor."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("enableBuy", L["Enable buying"])
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetSettingInfo(operation, "enableBuy")
					:SetDisabled(Operation.HasRelationship("Vendoring", private.currentOperationName, "enableBuy"))
					:SetScript("OnValueChanged", private.EnableBuyingToggleOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.enableBuy)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("restockQty", L["Restock quantity"], RESTOCK_QTY_VALIDATE_CONTEXT, nil, not operation.enableBuy, nil, SETTING_TOOLTIPS.restockQty)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockSources", L["Sources to include for restock"], not operation.enableBuy)
				:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
					:SetHeight(24)
					:SetItems(RESTOCK_SOURCES, RESTOCK_SOURCES_KEYS)
					:SetSettingInfo(operation, "restockSources")
					:SetSelectionText(L["No Sources"], L["%d Sources"], L["All Sources"])
					:SetDisabled(Operation.HasRelationship("Vendoring", private.currentOperationName, "restockSources") or not operation.enableBuy)
					:SetTooltip(SETTING_TOOLTIPS.restockSources)
				)
			)
		)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Vendoring", "sellOptionsHeading", L["Sell Options"], L["Set what is sold to a vendor."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("enableSell", L["Enable selling"])
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetSettingInfo(operation, "enableSell")
					:SetScript("OnValueChanged", private.EnableSellingToggleOnValueChanged)
					:SetDisabled(Operation.HasRelationship("Vendoring", private.currentOperationName, "enableSell"))
					:SetTooltip(SETTING_TOOLTIPS.enableSell)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("keepQty", L["Keep quantity"], KEEP_QTY_VALIDATE_CONTEXT, nil, not operation.enableSell, SETTING_TOOLTIPS.keepQty)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("sellAfterExpired", L["Min number of expires"], SELL_AFTER_EXPIRED_QTY_VALIDATE_CONTEXT, nil, not operation.enableSell, SETTING_TOOLTIPS.sellAfterExpired)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("vsMarketValue", L["Market value"], nil, nil, not operation.enableSell, SETTING_TOOLTIPS.vsMarketValue)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("vsMaxMarketValue", L["Max market value (Enter '0c' to disable)"], nil, nil, not operation.enableSell, SETTING_TOOLTIPS.vsMaxMarketValue)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("vsDestroyValue", L["Destroy value"], nil, nil, not operation.enableSell, SETTING_TOOLTIPS.vsDestroyValue)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("vsMaxDestroyValue", L["Max destroy value (Enter '0c' to disable)"], nil, nil, not operation.enableSell, SETTING_TOOLTIPS.vsMaxDestroyValue)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("sellSoulbound", L["Sell soulbound items"], not operation.enableSell)
				:SetMargin(0, 0, 0, 0)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetSettingInfo(operation, "sellSoulbound")
					:SetDisabled(Operation.HasRelationship("Vendoring", private.currentOperationName, "sellSoulbound") or not operation.enableSell)
					:SetTooltip(SETTING_TOOLTIPS.sellSoulbound)
				)
			)
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Vendoring", private.currentOperationName))
end




-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.UpdateSettingState(settingsFrame, key, operation, value)
	local relationshipSet, linkTexture, textColor = TSM.Operations.GetRelationshipColors("Vendoring", private.currentOperationName, key, value)
	local settingKeyFrame = settingsFrame:GetElement(key)
	settingKeyFrame:GetElement("line.linkBtn")
		:SetBackground(linkTexture)
		:SetDisabled(not value)
	settingKeyFrame:GetElement("line.label")
		:SetTextColor(textColor)
	local settingType = SETTING_INFO[key]
	if settingType == "INPUT_POPOUT" then
		settingKeyFrame:GetElement("input")
			:SetDisabled(relationshipSet or not value)
	elseif settingType == "TOGGLE" then
		settingKeyFrame:GetElement("toggle")
			:SetDisabled(relationshipSet or not value)
	elseif settingType == "DROPDOWN" then
		settingKeyFrame:GetElement("dropdown")
			:SetDisabled(relationshipSet or not value)
	else
		error("Invalid settingType: "..tostring(settingType))
	end
end

function private.EnableBuyingToggleOnValueChanged(toggle, value)
	local operation = Operation.GetSettings("Vendoring", private.currentOperationName)
	local settingsFrame = toggle:GetElement("__parent.__parent")
	private.UpdateSettingState(settingsFrame, "restockQty", operation, value)
	private.UpdateSettingState(settingsFrame, "restockSources", operation, value)
	settingsFrame:Draw()
end

function private.EnableSellingToggleOnValueChanged(toggle, value)
	local operation = Operation.GetSettings("Vendoring", private.currentOperationName)
	local settingsFrame = toggle:GetElement("__parent.__parent")
	for key in pairs(SETTING_INFO) do
		if key ~= "restockQty" and key ~= "restockSources" then
			private.UpdateSettingState(settingsFrame, key, operation, value)
		end
	end
	settingsFrame:Draw()
end
