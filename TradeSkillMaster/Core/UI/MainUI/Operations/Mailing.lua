-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Mailing = TSM.MainUI.Operations:NewPackage("Mailing")
local MailingOperation = TSM.LibTSMSystem:Include("MailingOperation")
local Operation = TSM.LibTSMTypes:Include("Operation")
local L = TSM.Locale.GetTable()
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local private = {
	settings = nil,
	manager = nil, ---@type UIManager
	currentOperationName = nil,
}
local RESTOCK_SOURCES_ITEMS = {
	BANK,
	GUILD,
}
local RESTOCK_SOURCES_KEYS = {
	"bank",
	"guild",
}
local KEEP_QTY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local MAX_QTY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local SETTING_TOOLTIPS = {
	target = L["The name of the character to send items to. If the character is on another connected realm, you can use the format Name-Realm."],
	keepQty = L["The amount of items to keep in your bag, or the minimum number of items to have before TSM will send items with this operation."],
	maxQtyEnabled = L["Eanbles the max quantity setting for specifying the quantity of items to mail to the target character."],
	maxQty = L["Each time the mailing operation is executed, this number of items will be sent."],
	restockEnabled = L["When enables, the maximum quantity indicates the maximum number of items the target character should have in their inventory."],
	restockSources = L["Select the inventory sources you would like to include when calculating how many of an item a character already has for restocking."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("MAILING_OPERATIONS_UI_STATE")
	:AddOptionalTableField("frame")
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Mailing.OnInitialize(settingsDB)
	KEEP_QTY_VALIDATE_CONTEXT.minValue, KEEP_QTY_VALIDATE_CONTEXT.maxValue = MailingOperation.GetMinMaxValues("keepQty")
	MAX_QTY_VALIDATE_CONTEXT.minValue, MAX_QTY_VALIDATE_CONTEXT.maxValue = MailingOperation.GetMinMaxValues("maxQty")

	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "regionWide")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MAILING_OPERATIONS_UI", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_NAME_INPUT_CHANGED")

	TSM.MainUI.Operations.RegisterModule("Mailing", private.GetMailingOperationSettings)
end



-- ============================================================================
-- Mailing Operation Settings UI
-- ============================================================================

function private.GetMailingOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "mailing")
	private.currentOperationName = operationName
	local operation = Operation.GetSettings("Mailing", private.currentOperationName)
	local frame = UIElements.New("ScrollFrame", "content")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Mailing", "generalOptions", L["General Options"], L["Adjust how items are mailed."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("target", L["Target character"])
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Frame", "content")
					:SetLayout("HORIZONTAL")
					:SetManager(private.manager)
					:AddChild(UIElements.New("Input", "input")
						:SetHeight(24)
						:SetMargin(0, 8, 0, 0)
						:SetHintText(L["Enter player name"])
						:SetAutoComplete(PlayerInfo.GetConnectedAlts())
						:SetClearButtonEnabled(true)
						:SetDisabled(Operation.HasRelationship("Mailing", private.currentOperationName, "target"))
						:SetSettingInfo(operation, "target")
						:SetTooltip(SETTING_TOOLTIPS.target, "__parent")
					)
					:AddChild(UIElements.New("ActionButton", "contacts")
						:SetSize(152, 24)
						:SetFont("BODY_BODY2_MEDIUM")
						:SetText(L["Contacts"])
						:SetAction("OnClick", "ACTION_SHOW_CONTACTS_DIALOG")
					)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("keepQty", L["Keep this amount"], KEEP_QTY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.keepQty)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("maxQtyEnabled", L["Set max quantity"])
				:SetHeight(42)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetSettingInfo(operation, "maxQtyEnabled")
					:SetDisabled(Operation.HasRelationship("Mailing", private.currentOperationName, "maxQtyEnabled"))
					:SetScript("OnValueChanged", private.MaxQuantityToggleOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.maxQtyEnabled)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("maxQty", L["Max quantity"], MAX_QTY_VALIDATE_CONTEXT, nil, not operation.maxQtyEnabled, SETTING_TOOLTIPS.maxQty)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restock", L["Restock target to max quantity"], not operation.maxQtyEnabled)
				:SetHeight(42)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("ToggleYesNo", "toggle")
					:SetHeight(18)
					:SetSettingInfo(operation, "restock")
					:SetDisabled(Operation.HasRelationship("Mailing", private.currentOperationName, "restock") or not operation.maxQtyEnabled)
					:SetScript("OnValueChanged", private.RestockToggleOnValueChanged)
					:SetTooltip(SETTING_TOOLTIPS.restockEnabled)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockSources", L["Sources to include for restock"], not operation.restock or not operation.maxQtyEnabled)
				:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
					:SetHeight(24)
					:SetItems(RESTOCK_SOURCES_ITEMS, RESTOCK_SOURCES_KEYS)
					:SetSettingInfo(operation, "restockSources")
					:SetSelectionText(L["No Sources"], L["%d Sources"], L["All Sources"])
					:SetDisabled(Operation.HasRelationship("Mailing", private.currentOperationName, "restockSources") or not operation.restock or not operation.maxQtyEnabled)
					:SetTooltip(SETTING_TOOLTIPS.restockSources)
				)
			)
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Mailing", private.currentOperationName))
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDDEN"))
	private.manager:ProcessAction("ACTION_HANDLE_FRAME_SHOWN", frame)
	return frame
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state MailingOperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_FRAME_SHOWN" then
		local frame = ...
		assert(frame)
		state.frame = frame
	elseif action == "ACTION_HANDLE_FRAME_HIDDEN" then
		state.frame = nil
	elseif action == "ACTION_SHOW_CONTACTS_DIALOG" then
		state.frame:GetElement("generalOptions.content.target.content.input")
			:SetFocused(false)
			:Draw()
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("MailContactsDialog", "dialog")
			:AddAnchor("TOP", state.frame:GetElement("generalOptions.content.target.content.contacts"), "BOTTOM", 0, -6)
			:Configure(private.settings.regionWide)
			:SetManager(manager)
			:SetAction("OnRowClick", "ACTION_CONTACT_SELECTED")
		)
	elseif action == "ACTION_CONTACT_SELECTED" then
		local character = ...
		state.frame:GetElement("generalOptions.content.target.content.input")
			:SetValue(character)
			:Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.MaxQuantityToggleOnValueChanged(toggle, value)
	local settingsFrame = toggle:GetElement("__parent.__parent")
	local restockValue = settingsFrame:GetElement("restock.toggle"):GetValue()
	local relationshipSet, linkTexture, textColor = TSM.Operations.GetRelationshipColors("Mailing", private.currentOperationName, "maxQty", value)
	settingsFrame:GetElement("maxQty.line.linkBtn")
		:SetBackground(linkTexture)
		:SetDisabled(not value)
	settingsFrame:GetElement("maxQty.line.label")
		:SetTextColor(textColor)
	settingsFrame:GetElement("maxQty.input")
		:SetDisabled(relationshipSet or not value)

	relationshipSet, linkTexture, textColor = TSM.Operations.GetRelationshipColors("Mailing", private.currentOperationName, "restock", value)
	settingsFrame:GetElement("restock.line.linkBtn")
		:SetBackground(linkTexture)
		:SetDisabled(not value)
	settingsFrame:GetElement("restock.line.label")
		:SetTextColor(textColor)
	settingsFrame:GetElement("restock.toggle")
		:SetDisabled(relationshipSet or not value)

	relationshipSet = Operation.HasRelationship("Mailing", private.currentOperationName, "restockSources")
	if relationshipSet and value and restockValue then
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "INDICATOR")
	elseif (relationshipSet and not value and restockValue) or (relationshipSet and value and not restockValue) or (relationshipSet and not value and not restockValue) then
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "INDICATOR_DISABLED")
	elseif (value and not restockValue) or (not value and restockValue) or (not value and not restockValue) then
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "TEXT_DISABLED")
	else
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "TEXT")
	end
	settingsFrame:GetElement("restockSources.line.linkBtn")
		:SetBackground(linkTexture)
		:SetDisabled(not value)
	settingsFrame:GetElement("restockSources.line.label")
		:SetTextColor(relationshipSet and "TEXT_DISABLED" or ((value and restockValue) and "TEXT" or "TEXT_DISABLED"))
	settingsFrame:GetElement("restockSources.dropdown")
		:SetDisabled(relationshipSet or not value or not restockValue)
	settingsFrame:Draw()
end

function private.RestockToggleOnValueChanged(toggle, value)
	local settingsFrame = toggle:GetElement("__parent.__parent")
	local maxQtyEnabled = settingsFrame:GetElement("maxQtyEnabled.toggle"):GetValue()
	local relationshipSet = Operation.HasRelationship("Mailing", private.currentOperationName, "restockSources")
	local linkTexture = nil
	if relationshipSet and value and maxQtyEnabled then
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "INDICATOR")
	elseif (relationshipSet and not value and maxQtyEnabled) or (relationshipSet and value and not maxQtyEnabled) or (relationshipSet and not value and not maxQtyEnabled) then
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "INDICATOR_DISABLED")
	elseif (value and not maxQtyEnabled) or (not value and maxQtyEnabled) or (not value and not maxQtyEnabled) then
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "TEXT_DISABLED")
	else
		linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", "TEXT")
	end
	settingsFrame:GetElement("restockSources.line.linkBtn")
		:SetBackground(linkTexture)
		:SetDisabled(not value)
	settingsFrame:GetElement("restockSources.line.label")
		:SetTextColor(relationshipSet and "TEXT_DISABLED" or ((value and maxQtyEnabled) and "TEXT" or "TEXT_DISABLED"))
	settingsFrame:GetElement("restockSources.dropdown")
		:SetDisabled(relationshipSet or not value or not maxQtyEnabled)
	settingsFrame:Draw()
end
