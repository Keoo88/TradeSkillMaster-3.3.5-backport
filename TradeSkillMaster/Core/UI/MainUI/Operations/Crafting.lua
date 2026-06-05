-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Crafting = TSM.MainUI.Operations:NewPackage("Crafting") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Operation = TSM.LibTSMTypes:Include("Operation")
local CraftingOperation = TSM.LibTSMSystem:Include("CraftingOperation")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	currentOperationName = nil,
}
local CRAFT_VALUE_VALIDATE_CONTEXT = {
	badSources = {
		crafting = true,
	},
}
local RESTOCK_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local SETTING_TOOLTIPS = {
	minRestock = L["This is the minimum number of items to add to your Crafting queue before any items are added to your Crafting queue. For example, if this is set to 10 and the operation would only add 3 items to the crafting queue, the items would not be added."],
	maxRestock = L["This is the maximum number of items you want to have in stock. If you already have more than this number, no more will be added to your Crafting queue."],
	minProfitToggle = L["If enabled, items would need to satisfy a minimum profit before being added to your crafting queue."],
	minProfitValue = L["If enabled, items would need to satisfy a minimum profit before being added to your crafting queue."],
	craftPriceMethodToggle = L["Enabling this allows overriding the default craft value method used to calculate profit of items associated with this operation."],
	craftPriceMethodValue = L["The craft value method to use for this operation."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Crafting.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
	RESTOCK_QUANTITY_VALIDATE_CONTEXT.minValue, RESTOCK_QUANTITY_VALIDATE_CONTEXT.maxValue = CraftingOperation.GetRestockRange()
	TSM.MainUI.Operations.RegisterModule("Crafting", private.GetCraftingOperationSettings)
end



-- ============================================================================
-- Crafting Operation Settings UI
-- ============================================================================

function private.GetCraftingOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "crafting")
	private.currentOperationName = operationName
	local operation = Operation.GetSettings("Crafting", private.currentOperationName)
	local frame = UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Crafting", "restockQuantity", L["Restock Options"], L["Adjust how crafted items are restocked."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("minRestock", L["Minimum restock quantity"], RESTOCK_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.minRestock)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("maxRestock", L["Maximum restock quantity"], RESTOCK_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.maxRestock)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("minProfit", L["Set min profit"], nil, "minProfitToggle")
				:SetHeight(42)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetValue(operation.minProfit ~= "")
					:SetDisabled(Operation.HasRelationship("Crafting", private.currentOperationName, "minProfit"))
					:SetScript("OnValueChanged", private.MinProfitToggleOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.minProfitToggle)
				)
			)
		)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Crafting", "priceSettings", L["Crafting Value"], L["Adjust how TSM values crafted items when calculating profit."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("craftPriceMethod", L["Override default craft value"], nil, "craftPriceMethodToggle")
				:SetHeight(42)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetValue(operation.craftPriceMethod ~= "")
					:SetDisabled(Operation.HasRelationship("Crafting", private.currentOperationName, "craftPriceMethod"))
					:SetScript("OnValueChanged", private.CraftPriceToggleOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.craftPriceMethodToggle)
				)
			)
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Crafting", private.currentOperationName))

	if operation.minProfit ~= "" then
		frame:GetElement("restockQuantity.content.minProfitToggle"):SetMargin(0, 0, 0, 12)
		frame:GetElement("restockQuantity"):AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("minProfit", L["Min profit amount"], nil, nil, nil, SETTING_TOOLTIPS.minProfitValue))
	end
	if operation.craftPriceMethod ~= "" then
		frame:GetElement("priceSettings.content.craftPriceMethodToggle"):SetMargin(0, 0, 0, 12)
		frame:GetElement("priceSettings"):AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("craftPriceMethod", L["Craft Value"], CRAFT_VALUE_VALIDATE_CONTEXT, private.settings.defaultCraftPriceMethod, nil, SETTING_TOOLTIPS.craftPriceMethodValue))
	end

	return frame
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.MinProfitToggleOnValueChanged(toggle, value)
	local operation = Operation.GetSettings("Crafting", private.currentOperationName)
	if value then
		Operation.Reset("Crafting", private.currentOperationName, "minProfit")
	else
		operation.minProfit = ""
	end
	local settingsFrame = toggle:GetParentElement():GetParentElement()
	if value then
		settingsFrame:GetElement("minProfitToggle"):SetMargin(0, 0, 0, 12)
		settingsFrame:GetParentElement():AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("minProfit", L["Min profit amount"], nil, nil, nil, SETTING_TOOLTIPS.minProfitValue))
	else
		settingsFrame:GetElement("minProfitToggle"):SetMargin(0, 0, 0, 0)
		settingsFrame:RemoveChild(settingsFrame:GetElement("minProfit"))
	end
	settingsFrame:GetParentElement():GetParentElement():Draw()
end

function private.CraftPriceToggleOnValueChanged(toggle, value)
	local operation = Operation.GetSettings("Crafting", private.currentOperationName)
	operation.craftPriceMethod = value and private.settings.defaultCraftPriceMethod or ""
	local settingsFrame = toggle:GetParentElement():GetParentElement()
	if value then
		settingsFrame:GetElement("craftPriceMethodToggle"):SetMargin(0, 0, 0, 12)
		settingsFrame:GetParentElement():AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("craftPriceMethod", L["Craft Value"], CRAFT_VALUE_VALIDATE_CONTEXT, private.settings.defaultCraftPriceMethod, nil, SETTING_TOOLTIPS.craftPriceMethodValue))
	else
		settingsFrame:GetElement("craftPriceMethodToggle"):SetMargin(0, 0, 0, 0)
		settingsFrame:RemoveChild(settingsFrame:GetElement("craftPriceMethod"))
	end
	settingsFrame:GetParentElement():GetParentElement():Draw()
end
