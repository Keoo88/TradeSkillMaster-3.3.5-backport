-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local CustomSources = TSM.MainUI.Settings:NewPackage("CustomSources") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local CustomPrice = TSM.LibTSMApp:Include("Service.CustomPrice")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local private = {
	settings = nil,
	editOldName = nil,
	editNewName = nil,
}
local TABLE_FORMAT_TEXT = {
	gold = L["Gold"],
	number = L["Number"],
	pct = L["Percent"],
}
local FORMAT_LIST_KEYS = {
	"gold",
	"number",
	"pct",
}
local FORMAT_LIST = {
	format(L["Gold (%s)"], Money.ToStringForTooltip(12345678)),
	format(L["Number (%s)"], FormatLargeNumber(1234)),
	format(L["Percent (%s)"], Theme.GetAuctionPercentColor(89):ColorText("89%")),
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function CustomSources.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "userData", "customPriceSources")
		:AddKey("global", "userData", "customPriceSourceFormat")
	TSM.MainUI.Settings.RegisterSettingPage(L["Custom Sources"], "middle", private.GetCustomSourcesSettingsFrame)
end



-- ============================================================================
-- Custom Sources Settings UI
-- ============================================================================

function private.GetCustomSourcesSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "custom_sources")
	return UIElements.New("ScrollFrame", "content")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Custom Price", "general", L["Custom Sources"], format(L["Custom sources allow you to create more advanced prices for use throughout the addon. You'll be able to use these new variables in the same way you can use the built-in price sources such as %s and %s."], Theme.GetColor("INDICATOR"):ColorText("vendorsell"), Theme.GetColor("INDICATOR"):ColorText("vendorbuy")), 60)
			:AddChild(UIElements.New("Frame", "tableHeading")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Text", "nameCol")
					:SetWidth(140)
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY3_MEDIUM")
					:SetText(L["Name"])
				)
				:AddChild(UIElements.New("Text", "formatCol")
					:SetWidth(100)
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY3_MEDIUM")
					:SetText(L["Display Format"])
				)
				:AddChild(UIElements.New("Text", "stringCol")
					:SetFont("BODY_BODY3_MEDIUM")
					:SetText(L["String"])
				)
			)
			:AddChild(UIElements.New("HorizontalLine", "line1")
				:SetHeight(1)
			)
			:AddChildrenWithFunction(private.AddCustomPriceRows)
			:AddChild(UIElements.New("ActionButton", "addNewBtn")
				:SetHeight(24)
				:SetMargin(0, 0, 32, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Add a new custom source"])
				:SetScript("OnClick", private.AddNewButtonOnClick)
			)
		)
end

function private.CreateCustomPriceRow(name)
	local priceString = private.settings.customPriceSources[name]
	local row = UIElements.New("Frame", "row_"..name)
		:SetLayout("HORIZONTAL")
		:SetHeight(28)
		:SetMargin(-12, -12, 0, 0)
		:SetPadding(12, 12, 0, 0)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:SetContext(name)
		:SetScript("OnEnter", private.CustomPriceRowOnEnter)
		:SetScript("OnLeave", private.CustomPriceRowOnLeave)
		:AddChild(UIElements.New("Text", "nameText")
			:SetWidth(140)
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY3_MEDIUM")
			:SetText(name)
		)
		:AddChild(UIElements.New("Text", "formatText")
			:SetWidth(100)
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY3")
			:SetText(TABLE_FORMAT_TEXT[private.settings.customPriceSourceFormat[name]])
		)
		:AddChild(UIElements.New("Text", "valueText")
			:SetFont("BODY_BODY3")
			:SetText(priceString)
		)
		:AddChild(UIElements.New("Button", "editBtn")
			:SetMargin(4, 0, 0, 0)
			:SetBackgroundAndSize("iconPack.18x18/Edit")
			:SetScript("OnClick", private.EditCustomPriceOnClick)
			:PropagateScript("OnEnter")
			:PropagateScript("OnLeave")
		)
		:AddChild(UIElements.New("Button", "deleteBtn")
			:SetMargin(4, 0, 0, 0)
			:SetBackgroundAndSize("iconPack.18x18/Delete")
			:SetScript("OnClick", private.DeleteCustomPriceOnClick)
			:PropagateScript("OnEnter")
			:PropagateScript("OnLeave")
		)
	row:GetElement("editBtn"):Hide()
	row:GetElement("deleteBtn"):Hide()
	return row
end

function private.AddCustomPriceRows(frame)
	local names = TempTable.Acquire()
	for name in pairs(private.settings.customPriceSources) do
		tinsert(names, name)
	end
	sort(names)
	for _, name in ipairs(names) do
		frame:AddChild(private.CreateCustomPriceRow(name))
	end
	TempTable.Release(names)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.CustomPriceRowOnEnter(frame)
	frame:SetBackgroundColor("FRAME_BG")
	frame:GetElement("editBtn"):Show()
	frame:GetElement("deleteBtn"):Show()
	frame:Draw()
end

function private.CustomPriceRowOnLeave(frame)
	frame:SetBackgroundColor("PRIMARY_BG_ALT")
	frame:GetElement("editBtn"):Hide()
	frame:GetElement("deleteBtn"):Hide()
	frame:Draw()
end

function private.EditCustomPriceOnClick(editBtn)
	assert(not private.editOldName)
	private.editOldName = editBtn:GetElement("__parent.nameText"):GetText()
	local value = editBtn:GetElement("__parent.valueText"):GetText()
	local format = private.settings.customPriceSourceFormat[private.editOldName]
	editBtn:GetBaseElement():ShowDialogFrame(UIElements.New("CustomStringDialog", "dialog")
		:Configure(L["Custom Source"], value, private.ValueValidateFunc)
		:SetContext(editBtn)
		:SetScript("OnDoneEditing", private.DialogOnValueChanged)
		:AddChildBeforeById("input", UIElements.New("Frame", "extraFields")
			:SetLayout("VERTICAL")
			:SetMargin(0, 0, 0, 8)
			:SetContext(editBtn)
			:AddChild(UIElements.New("Text", "name")
				:SetHeight(20)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("LEFT")
				:SetText(L["Name"])
			)
			:AddChild(UIElements.New("Input", "nameInput")
				:SetHeight(24)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:SetValue(private.editOldName)
				:SetValidateFunc(private.NameValidateFunc)
				:SetScript("OnValueChanged", private.EditDialogNameOnValueChanged)
			)
			:AddChild(UIElements.New("Text", "format")
				:SetHeight(20)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("LEFT")
				:SetText(L["Display Format"])
			)
			:AddChild(UIElements.New("ListDropdown", "formatDropdown")
				:SetHeight(24)
				:SetItems(FORMAT_LIST)
				:SetSelectedItemByIndex(Table.KeyByValue(FORMAT_LIST_KEYS, format))
			)
			:AddChild(UIElements.New("Text", "string")
				:SetHeight(20)
				:SetMargin(0, 0, 6, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("LEFT")
				:SetText(L["String"])
			)
		)
	)
end

function private.NameValidateFunc(input, value)
	if value == "" then
		return false
	elseif gsub(value, "([a-z]+)", "") ~= "" then
		return false, L["Custom price names can only contain lowercase letters."]
	elseif value ~= input:GetParentElement():GetContext():GetParentElement():GetContext() then
		return CustomPrice.ValidateCustomSourceName(value)
	else
		return true
	end
end

function private.ValueValidateFunc(_, value)
	return CustomPrice.Validate(value)
end

function private.EditDialogNameOnValueChanged(input)
	private.editNewName = input:GetValue()
end

function private.DialogOnValueChanged(dialog, value)
	local button = dialog:GetContext()
	local oldName = private.editOldName
	local newName = private.editNewName or private.editOldName
	private.settings.customPriceSourceFormat[oldName] = FORMAT_LIST_KEYS[dialog:GetElement("extraFields.formatDropdown"):GetSelectedItemIndex()]
	private.editOldName = nil
	private.editNewName = nil
	if oldName ~= newName then
		CustomString.RenameCustomSource(oldName, newName)
		CustomString.UpdateCustomSource(newName, value)
		private.settings.customPriceSourceFormat[newName] = private.settings.customPriceSourceFormat[oldName]
		private.settings.customPriceSourceFormat[oldName] = nil
		local generalContainer = button:GetParentElement():GetParentElement()
		local rowFrame = button:GetParentElement()
		generalContainer:AddChildBeforeById("addNewBtn", private.CreateCustomPriceRow(newName))
		generalContainer:RemoveChild(rowFrame)
		generalContainer:GetElement("__parent.__parent")
			:Draw()
	else
		CustomString.UpdateCustomSource(newName, value)
		button:GetElement("__parent.nameText")
			:SetText(newName)
			:Draw()
		button:GetElement("__parent.formatText")
			:SetText(TABLE_FORMAT_TEXT[private.settings.customPriceSourceFormat[newName]])
			:Draw()
		button:GetElement("__parent.valueText")
			:SetText(value)
			:Draw()
	end
end

function private.DeleteCustomPriceOnClick(button)
	local name = button:GetParentElement():GetContext()
	CustomString.RemoveCustomSource(name)
	private.settings.customPriceSourceFormat[name] = nil
	local rowFrame = button:GetParentElement()
	local parentFrame = rowFrame:GetParentElement()
	parentFrame:RemoveChild(rowFrame)
	parentFrame:GetElement("__parent.__parent")
		:Draw()
end

function private.AddNewButtonOnClick(button)
	-- Generate a placeholder name
	local newName = nil
	local suffix = ""
	while not newName do
		for i = strbyte("a"), strbyte("z") do
			newName = "customprice"..suffix..strchar(i)
			if not private.settings.customPriceSources[newName] then
				break
			end
			newName = nil
		end
		suffix = suffix..strchar(random(strbyte("a"), strbyte("z")))
	end

	CustomString.AddCustomSource(newName, "")
	private.settings.customPriceSourceFormat[newName] = "gold"
	button:GetParentElement()
		:AddChildBeforeById("addNewBtn", private.CreateCustomPriceRow(newName))
	button:GetElement("__parent.__parent.__parent")
		:Draw()
	private.EditCustomPriceOnClick(button:GetElement("__parent.row_"..newName..".editBtn"))
end
