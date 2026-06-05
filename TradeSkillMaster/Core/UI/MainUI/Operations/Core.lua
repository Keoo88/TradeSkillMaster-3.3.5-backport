-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Operations = TSM.MainUI:NewPackage("Operations") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Theme = TSM.LibTSMService:Include("UI.Theme")
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Operation = TSM.LibTSMTypes:Include("Operation")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local private = {
	manager = nil, ---@type UIManager
	settingsDB = nil,
	settings = nil,
	moduleNames = {},
	moduleCollapsed = {},
	moduleCallbacks = {},
	currentModule = nil,
	currentOperationName = nil,
	playerList = {},
	factionrealmList = {},
	numGroupsCache = {},
	numItemsCache = {},
}
local DEFAULT_PRICE_INPUT_VALIDATE_CONTEXT = {}
local STATE_SCHEMA = Reactive.CreateStateSchema("OPERATIONS_UI_STATE")
	:AddOptionalTableField("frame")
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Operations.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "operationsDividedContainer")
		:AddKey("global", "mainUIContext", "operationsSummaryScrollingTable")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("OPERATIONS_UI", state, private.ActionHandler)
		:SuppressActionLog("ACTION_HANDLE_NAME_INPUT_CHANGED")

	TSM.MainUI.RegisterTopLevelPage(L["Operations"], private.GetOperationsFrame)
end

function Operations.RegisterModule(name, callback)
	tinsert(private.moduleNames, name)
	private.moduleCallbacks[name] = callback
end

function Operations.ShowOperationSettings(baseFrame, moduleName, operationName)
	baseFrame:SetSelectedNavButton(L["Operations"], true)
	baseFrame:GetElement("content.operations.selection.operationTree"):SetSelectedOperation(moduleName, operationName)
end

function Operations.GetOperationManagementElements(moduleName, operationName)
	local operation = Operation.GetSettings(private.currentModule, private.currentOperationName)
	wipe(private.factionrealmList)
	wipe(private.playerList)
	for _, factionrealm in private.settingsDB:ScopeKeyIterator("factionrealm") do
		tinsert(private.factionrealmList, factionrealm)
		for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm) do
			tinsert(private.playerList, character.." - "..factionrealm)
		end
	end
	return UIElements.New("Frame", "management")
		:SetLayout("VERTICAL")
		:AddChild(Operations.CreateExpandableSection(moduleName, "managementOptions", L["Management Options"], L["Below you can ignore this operation on certain characters or realms."])
			:AddChild(UIElements.New("Frame", "ignoreFactionRealms")
				:SetLayout("VERTICAL")
				:SetHeight(48)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(24)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetTextColor("TEXT")
					:SetText(L["Ignore operation on faction-realms"])
				)
				:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
					:SetHeight(24)
					:SetItems(private.factionrealmList, private.factionrealmList)
					:SetSelectionText(L["No Faction-Realms"], L["%d Faction-Realms"], L["All Faction-Realms"])
					:SetSettingInfo(operation, "ignoreFactionrealm")
					:SetScript("OnSelectionChanged", GroupOperation.RebuildDB)
					:SetTooltip(L["This operation will be ignored on any of the selected faction-realms."])
				)
			)
			:AddChild(UIElements.New("Frame", "ignoreCharacters")
				:SetLayout("VERTICAL")
				:SetHeight(48)
				:SetMargin(0, 0, 0, 4)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(24)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetTextColor("TEXT")
					:SetText(L["Ignore operation on characters"])
				)
				:AddChild(UIElements.New("MultiselectionDropdown", "dropdown")
					:SetHeight(24)
					:SetItems(private.playerList, private.playerList)
					:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
					:SetSettingInfo(operation, "ignorePlayer")
					:SetScript("OnSelectionChanged", GroupOperation.RebuildDB)
					:SetTooltip(L["This operation will be ignored on any of the selected characters."])
				)
			)
		)
		:AddChild(Operations.CreateExpandableSection(moduleName, "groupManagement", L["Group Management"], L["Here you can add/remove what groups this operation is attached to."])
			:AddChild(UIElements.New("Frame", "applyNewGroup")
				:SetLayout("VERTICAL")
				:SetHeight(48)
				:SetMargin(0, 0, 0, 4)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(24)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetTextColor("TEXT")
					:SetText(L["Apply operation to group"])
				)
				:AddChild(UIElements.New("GroupSelector", "group")
					:SetHeight(24)
					:SetHintText(L["Add operation to groups"])
					:SetScript("OnSelectionChanged", private.GroupSelectionChanged)
				)
			)
			:AddChildrenWithFunction(private.AddOperationGroups)
		)
end

function Operations.CreateExpandableSection(moduleName, id, text, description)
	return UIElements.New("OperationCollapsibleContainer", id)
		:SetMargin(0, 0, 0, 8)
		:SetContextTable(private.moduleCollapsed, moduleName..text)
		:SetHeadingDescription(text, description)
end

function Operations.CreateLinkedSettingLine(settingKey, labelText, disabled, alternateName)
	return UIElements.New("OperationLinkedSettingLine", alternateName or settingKey)
		:SetLayout("VERTICAL")
		:SetHeight(48)
		:SetMargin(0, 0, 0, 4)
		:SetOperationSetting(private.currentModule, private.currentOperationName, settingKey)
		:SetLabel(labelText)
		:SetDisabled(disabled and true or false)
		:SetManager(private.manager)
		:SetAction("OnRelationshipChanged", "ACTION_RELOAD_CURRENT_SETTINGS")
end

function Operations.CreateLinkedPriceInput(settingKey, label, validateContext, defaultValue, isDisabled, tooltip)
	-- Make sure the context is the right shape
	validateContext = validateContext or DEFAULT_PRICE_INPUT_VALIDATE_CONTEXT
	for key in pairs(validateContext) do
		assert(key == "isNumber" or key == "isUndercut" or key == "badSources" or key == "minValue" or key == "maxValue")
	end
	assert(not validateContext.isNumber or not validateContext.isUndercut)
	if validateContext.minValue or validateContext.maxValue then
		assert(validateContext.isNumber)
		assert(validateContext.minValue < validateContext.maxValue)
		assert(not validateContext.isUndercut and not validateContext.badSources)
	end
	assert(not validateContext.isNumber or not validateContext.badSources)

	-- Get information on the opeartion
	local shouldDisable = isDisabled or Operation.HasRelationship(private.currentModule, private.currentOperationName, settingKey)
	local operation = Operation.GetSettings(private.currentModule, private.currentOperationName)
	local value = operation[settingKey]
	if defaultValue ~= nil and (not value or value == "") then
		isDisabled = true
		value = defaultValue
	end

	local rangeTooltip = not shouldDisable and validateContext.minValue and format(L["This supported value range is from %d to %d."], validateContext.minValue, validateContext.maxValue) or nil
	if tooltip and rangeTooltip then
		tooltip = tooltip.." "..rangeTooltip
	else
		tooltip = tooltip or rangeTooltip
	end
	return UIElements.New("OperationLinkedSettingLine", settingKey)
		:SetLayout("VERTICAL")
		:SetHeight(48)
		:SetMargin(0, 0, 0, 4)
		:SetOperationSetting(private.currentModule, private.currentOperationName, settingKey)
		:SetLabel(label)
		:SetDisabled(isDisabled and true or false)
		:SetManager(private.manager)
		:AddChild(UIElements.New("CustomStringSingleLineInput", "input")
			:SetHeight(24)
			:SetBackgroundColor("PRIMARY_BG")
			:SetDisabled(shouldDisable)
			:SetValidateFunc(validateContext.isUndercut and "UNDERCUT" or "CUSTOM_STRING", validateContext.badSources)
			:SetSettingInfo(operation, settingKey)
			:SetIsNumber(validateContext.isNumber)
			:SetPopoutTitle(label)
			:SetTooltip(tooltip, "__parent")
		)
		:SetAction("OnRelationshipChanged", "ACTION_RELOAD_CURRENT_SETTINGS")
end



-- ============================================================================
-- Operations UI
-- ============================================================================

function private.GetOperationsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "operations")
	local frame = UIElements.New("DividedContainer", "operations")
		:SetSettingsContext(private.settings, "operationsDividedContainer")
		:SetMinWidth(250, 250)
		:SetLeftChild(UIElements.New("Frame", "selection")
			:SetLayout("VERTICAL")
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Input", "search")
				:SetHeight(24)
				:SetMargin(8, 8, 8, 16)
				:SetIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:AllowItemInsert(true)
				:SetHintText(L["Search Operations"])
				:SetScript("OnValueChanged", private.OperationSearchOnValueChanged)
			)
			:AddChild(UIElements.New("OperationTree", "operationTree")
				:SetScript("OnOperationAdded", private.OperationTreeOnOperationAdded)
				:SetScript("OnOperationDeleted", private.OperationTreeOnOperationConfirmDelete)
				:SetScript("OnOperationSelected", private.OperationTreeOnOperationSelected)
			)
		)
		:SetRightChild(UIElements.New("ViewContainer", "content")
			:SetNavCallback(private.GetOperationsContent)
			:AddPath("none", true)
			:AddPath("summary")
			:AddPath("operation")
		)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDDEN"))
	private.manager:ProcessAction("ACTION_HANDLE_FRAME_SHOWN", frame)
	return frame
end

function private.GetOperationsContent(_, path)
	if path == "none" then
		return UIElements.New("Frame", "settings")
			:SetLayout("VERTICAL")
			:SetWidth("EXPAND")
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Frame", "title")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:AddChild(UIElements.New("Texture", "icon")
					:SetMargin(0, 8, 0, 0)
					:SetTextureAndSize(TextureAtlas.GetColoredKey("iconPack.18x18/Operation", "TEXT"))
				)
				:AddChild(UIElements.New("Text", "text")
					:SetFont("BODY_BODY1_BOLD")
					:SetText(L["No Operation Selected"])
				)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
	elseif path == "summary" then
		return UIElements.New("Frame", "settings")
			:SetLayout("VERTICAL")
			:SetWidth("EXPAND")
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Frame", "title")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:AddChild(UIElements.New("Text", "text")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY1_BOLD")
				)
				:AddChild(UIElements.New("Spacer"))
				:AddChild(UIElements.New("Button", "addBtn")
					:SetWidth("AUTO")
					:SetMargin(12, 12, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetIcon("iconPack.14x14/Add/Circle", "LEFT")
					:SetText(L["Create New"])
					:SetScript("OnClick", private.CreateNewOperationOnClick)
				)
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("VERTICAL")
				-- will be filled in by the operation selection callback
			)
	elseif path == "operation" then
		return UIElements.New("Frame", "settings")
			:SetLayout("VERTICAL")
			:SetWidth("EXPAND")
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Frame", "title")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:AddChild(UIElements.New("Texture", "icon")
					:SetMargin(0, 8, 0, 0)
					:SetTextureAndSize(TextureAtlas.GetColoredKey("iconPack.18x18/Operation", "TEXT"))
				)
				:AddChild(UIElements.New("EditableText", "text")
					:AllowItemInsert(true)
					:SetFont("BODY_BODY1_BOLD")
					:SetText(L["No Operation Selected"])
					:SetScript("OnValueChanged", private.OperationNameChanged)
					:SetScript("OnEditingChanged", private.NameOnEditingChanged)
				)
				:AddChild(UIElements.New("Button", "renameBtn")
					:SetWidth("AUTO")
					:SetMargin(12, 12, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetIcon("iconPack.14x14/Edit", "LEFT")
					:SetText(L["Rename"])
					:SetScript("OnClick", private.RenameOperationOnClick)
				)
				:AddChild(UIElements.New("Button", "resetBtn")
					:SetWidth("AUTO")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetIcon("iconPack.14x14/Reset", "LEFT")
					:SetText(L["Reset"])
					:SetScript("OnClick", private.ResetOperationOnClick)
				)
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("VERTICAL")
				-- will be filled in by the operation selection callback
			)
	else
		error("Invalid path: "..tostring(path))
	end
end

function private.GetSummaryContent()
	wipe(private.numGroupsCache)
	wipe(private.numItemsCache)
	local query = Operation.NewQuery()
		:Equal("moduleName", private.currentModule)
		:VirtualField("numGroups", "number", private.NumGroupsVirtualField, "operationName")
		:VirtualField("numItems", "number", private.NumItemsVirtualField, "operationName")
	local mostGroupsName, mostGroupsValue = "---", -math.huge
	local leastGroupsName, leastGroupsValue = "---", math.huge
	local mostItemsName, mostItemsValue = "---", -math.huge
	local leastItemsName, leastItemsValue = "---", math.huge
	for _, row in query:Iterator() do
		local operationName, numGroups, numItems = row:GetFields("operationName", "numGroups", "numItems")
		if numGroups > mostGroupsValue then
			mostGroupsValue = numGroups
			mostGroupsName = operationName
		end
		if numGroups < leastGroupsValue then
			leastGroupsValue = numGroups
			leastGroupsName = operationName
		end
		if numItems > mostItemsValue then
			mostItemsValue = numItems
			mostItemsName = operationName
		end
		if numItems < leastItemsValue then
			leastItemsValue = numItems
			leastItemsName = operationName
		end
	end
	return UIElements.New("Frame", "summary")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("PRIMARY_BG")
		:AddChild(UIElements.New("Frame", "summary")
			:SetLayout("HORIZONTAL")
			:SetHeight(48)
			:SetMargin(8, 8, 0, 16)
			:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Frame", "groups")
				:SetLayout("VERTICAL")
				:SetPadding(8, 8, 2, 2)
				:AddChild(UIElements.New("Frame", "most")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 4)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetTextColor("ACTIVE_BG_ALT")
						:SetText(L["MOST GROUPS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetJustifyH("RIGHT")
						:SetText(mostGroupsName)
					)
				)
				:AddChild(UIElements.New("Frame", "least")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetTextColor("ACTIVE_BG_ALT")
						:SetText(L["LEAST GROUPS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetJustifyH("RIGHT")
						:SetText(leastGroupsName)
					)
				)
			)
			:AddChild(UIElements.New("VerticalLine", "line1")
				:SetWidth(1)
			)
			:AddChild(UIElements.New("Frame", "items")
				:SetLayout("VERTICAL")
				:SetPadding(8, 8, 2, 2)
				:AddChild(UIElements.New("Frame", "most")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 4)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetTextColor("ACTIVE_BG_ALT")
						:SetText(L["MOST ITEMS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetJustifyH("RIGHT")
						:SetText(mostItemsName)
					)
				)
				:AddChild(UIElements.New("Frame", "least")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetTextColor("ACTIVE_BG_ALT")
						:SetText(L["LEAST ITEMS"])
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "value")
						:SetWidth("AUTO")
						:SetFont("TABLE_TABLE1")
						:SetJustifyH("RIGHT")
						:SetText(leastItemsName)
					)
				)
			)
		)
		:AddChild(UIElements.New("OperationSummaryScrollTable", "list")
			:SetSettings(private.settings, "operationsSummaryScrollingTable")
			:SetQuery(query)
			:SetScript("OnSelectionChanged", private.OperationListOnSelectionChanged)
			:SetScript("OnOperationConfigure", private.OperationListOnOperationConfigure)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "deleteSelected")
				:SetHeight(24)
				:SetMargin(0, 8, 0, 0)
				:SetDisabled(true)
				:SetText(L["Delete Operations"])
				:SetScript("OnClick", private.DeleteSelectedOnClick)
			)
			:AddChild(UIElements.New("Button", "selectAll")
				:SetSize("AUTO", 20)
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_BODY3_MEDIUM")
				:SetText(L["Select All"])
				:SetScript("OnClick", private.SelectAllOnClick)
			)
			:AddChild(UIElements.New("VerticalLine", "line")
				:SetHeight(2, 20)
				:SetMargin(0, 8, 0, 0)
			)
			:AddChild(UIElements.New("Button", "clearAll")
				:SetSize("AUTO", 20)
				:SetFont("BODY_BODY3_MEDIUM")
				:SetText(L["Clear All"])
				:SetDisabled(true)
				:SetScript("OnClick", private.ClearAllOnClick)
			)
		)
end

function private.AddOperationGroups(frame)
	for _, groupPath in GroupOperation.GroupIteratorByOperation(private.currentModule, private.currentOperationName, true) do
		frame:AddChild(private.CreateGroupOperationLine(groupPath))
	end
end

function private.CreateGroupOperationLine(groupPath)
	return UIElements.New("OperationGroupLine", "group")
		:SetHeight(20)
		:SetMargin(2, 0, 0, 0)
		:SetGroupAndOperation(groupPath, private.currentModule, private.currentOperationName)
		:SetManager(private.manager)
		:SetAction("OnViewGroup", "ACTION_VIEW_GROUP")
		:SetAction("OnRemoved", "ACTION_REMOVE_GROUP_LINE")
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state OperationsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_FRAME_SHOWN" then
		local frame = ...
		assert(frame)
		state.frame = frame
	elseif action == "ACTION_HANDLE_FRAME_HIDDEN" then
		state.frame = nil
	elseif action == "ACTION_RELOAD_CURRENT_SETTINGS" then
		Operations.ShowOperationSettings(state.frame:GetBaseElement(), private.currentModule, private.currentOperationName)
	elseif action == "ACTION_VIEW_GROUP" then
		local groupPath = ...
		TSM.MainUI.Groups.ShowGroupSettings(state.frame:GetBaseElement(), groupPath)
	elseif action == "ACTION_REMOVE_GROUP_LINE" then
		local line = ...
		local parent = line:GetParentElement()
		parent:RemoveChild(line)
		parent:GetParentElement():GetParentElement():GetParentElement():Draw()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.OperationSearchOnValueChanged(input)
	local filter = strlower(input:GetValue())
	input:GetElement("__parent.operationTree"):SetOperationNameFilter(filter)
end

function private.OperationTreeOnOperationAdded(operationTree, moduleName, operationName, copyOperationName)
	-- clear the filter
	operationTree:GetElement("__parent.search")
		:SetValue("")
		:Draw()
	operationTree:SetOperationNameFilter("")
	Operation.Create(moduleName, operationName)
	if copyOperationName then
		Operation.Copy(moduleName, operationName, copyOperationName)
	end
end

function private.OperationTreeOnOperationConfirmDelete(self, moduleName, operationName)
	self:GetBaseElement():ShowConfirmationDialog(L["Delete Operation?"], L["Are you sure you want to delete this operation?"], private.OperationTreeOnOperationDeleted, self, moduleName, operationName)
end

function private.OperationTreeOnOperationDeleted(self, moduleName, operationName)
	GroupOperation.DeleteOperation(moduleName, operationName)
	self:GetElement("__parent.operationTree"):SetSelectedOperation(moduleName, nil)
end

function private.OperationTreeOnOperationSelected(self, moduleName, operationName)
	private.currentModule = moduleName
	private.currentOperationName = operationName

	local viewContainer = self:GetParentElement():GetParentElement():GetElement("content")
	if moduleName and operationName then
		Operation.UpdateFromRelationships(moduleName, operationName)
		viewContainer:SetPath("operation")
		viewContainer:GetElement("settings.title.text"):SetText(operationName)
		local contentFrame = viewContainer:GetElement("settings.content")
		contentFrame:ReleaseAllChildren()
		contentFrame:AddChild(private.moduleCallbacks[moduleName](operationName))
	elseif moduleName then
		local numOperations = 0
		for _ in Operation.Iterator(moduleName) do
			numOperations = numOperations + 1
		end
		UIUtils.AnalyticsRecordPathChange("main", "operations", "summary")
		viewContainer:SetPath("summary")
		viewContainer:GetElement("settings.title.text"):SetText(format(L["%s %s Operations"], Theme.GetColor("INDICATOR"):ColorText(numOperations), moduleName))
		local contentFrame = viewContainer:GetElement("settings.content")
		contentFrame:ReleaseAllChildren()
		contentFrame:AddChild(private.GetSummaryContent())
	else
		UIUtils.AnalyticsRecordPathChange("main", "operations", "none")
		viewContainer:SetPath("none")
		viewContainer:GetElement("settings.title.text"):SetText(L["No Operation Selected"])
	end
	viewContainer:Draw()
end

function private.CreateNewOperationOnClick(button)
	local operationName = Operation.GetDeduplicatedName(private.currentModule, L["New Operation"])
	Operation.Create(private.currentModule, operationName)
	button:GetElement("__parent.__parent.__parent.__parent.selection.operationTree")
		:SetSelectedOperation(private.currentModule, operationName)
end

function private.OperationNameChanged(text, newValue)
	newValue = strtrim(newValue)
	if newValue == private.currentOperationName then
		-- didn't change
		text:Draw()
	elseif newValue == "" then
		ChatMessage.PrintUser(L["Invalid operation name."])
		text:Draw()
	elseif Operation.Exists(private.currentModule, newValue) then
		ChatMessage.PrintUser(L["Group already exists."])
		text:Draw()
	else
		GroupOperation.RenameOperation(private.currentModule, private.currentOperationName, newValue)
		text:GetElement("__parent.__parent.__parent.__parent.selection.operationTree")
			:SetSelectedOperation(private.currentModule, newValue)
	end
end

function private.NameOnEditingChanged(text, editing)
	if editing then
		text:GetElement("__parent.renameBtn"):Hide()
	else
		text:GetElement("__parent.renameBtn"):Show()
	end
end

function private.RenameOperationOnClick(button)
	button:GetElement("__parent.text"):SetEditing(true)
end

function private.ResetOperationOnClick(button)
	button:GetBaseElement():ShowConfirmationDialog(L["Reset Operation?"], L["Resetting the operation will return all inputs back to default and cannot be unddone. Click confirm to reset."], private.ConfirmResetOnClick, button)
end

function private.ConfirmResetOnClick(button)
	Operation.Reset(private.currentModule, private.currentOperationName)
	local settingsFrame = button:GetBaseElement():GetElement("content.operations.content.settings")
	local contentFrame = settingsFrame:GetElement("content")
	contentFrame:ReleaseAllChildren()
	Operation.UpdateFromRelationships(private.currentModule, private.currentOperationName)
	contentFrame:AddChild(private.moduleCallbacks[private.currentModule](private.currentOperationName))
	button:GetBaseElement():HideDialog()
	settingsFrame:Draw()
	ChatMessage.PrintfUser(L["%s - %s has been reset to default values."], private.currentModule, Theme.GetColor("INDICATOR_ALT"):ColorText(private.currentOperationName))
end

function private.GroupSelectionChanged(groupSelector)
	for groupPath in groupSelector:SelectedGroupIterator() do
		if not GroupOperation.HasOperation(groupPath, private.currentModule, private.currentOperationName) then
			local removedOperationName = GroupOperation.Add(groupPath, private.currentModule, private.currentOperationName)
			if removedOperationName then
				ChatMessage.PrintfUser(L["%s previously had the max number of operations, so removed %s."], ChatMessage.ColorUserAccentText(Group.FormatPath(groupPath)), ChatMessage.ColorUserAccentText(removedOperationName))
			end
			ChatMessage.PrintfUser(L["Added %s to %s."], ChatMessage.ColorUserAccentText(private.currentOperationName), ChatMessage.ColorUserAccentText(groupPath == Group.GetRootPath() and L["Base Group"] or Group.FormatPath(groupPath)))
			groupSelector:GetParentElement():GetParentElement():AddChild(private.CreateGroupOperationLine(groupPath))
		end
	end
	groupSelector:ClearSelectedGroups(true)
	groupSelector:GetParentElement():GetParentElement():GetParentElement():GetParentElement():GetParentElement():GetParentElement():Draw()
end

function private.OperationListOnSelectionChanged(scrollTable)
	local allSelected, noneSelected = scrollTable:GetSelectionState()
	local numSelected = 0
	for _ in scrollTable:SelectedOperationsIterator() do
		numSelected = numSelected + 1
	end
	local footer = scrollTable:GetElement("__parent.footer")
	footer:GetElement("deleteSelected")
		:SetText(numSelected > 0 and format(L["Delete %d Operations"], numSelected) or L["Delete Operations"])
		:SetDisabled(noneSelected)
	footer:GetElement("selectAll")
		:SetDisabled(allSelected)
	footer:GetElement("clearAll")
		:SetDisabled(noneSelected)
	footer:Draw()
end

function private.SelectAllOnClick(button)
	button:GetElement("__parent.__parent.list"):SetSelectionState(true)
end

function private.ClearAllOnClick(button)
	button:GetElement("__parent.__parent.list"):SetSelectionState(false)
end

function private.DeleteSelectedOnClick(button)
	local scrollTable = button:GetElement("__parent.__parent.list")
	button:GetBaseElement():ShowConfirmationDialog(L["Delete Operations?"], L["Are you sure you want to delete the selected operations?"], private.DeleteSelectedOperations, scrollTable)
end

function private.DeleteSelectedOperations(scrollTable)
	local toDelete = TempTable.Acquire()
	for operationName in scrollTable:SelectedOperationsIterator() do
		tinsert(toDelete, operationName)
	end
	GroupOperation.DeleteOperations(private.currentModule, toDelete)
	TempTable.Release(toDelete)
	private.OperationListOnSelectionChanged(scrollTable)
	scrollTable:GetElement("__parent.__parent.__parent.__parent.__parent.selection.operationTree"):SetSelectedOperation(private.currentModule, nil)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NumGroupsVirtualField(operationName)
	if not private.numGroupsCache[operationName] then
		local num = 0
		for _ in GroupOperation.GroupIteratorByOperation(private.currentModule, operationName) do
			num = num + 1
		end
		private.numGroupsCache[operationName] = num
	end
	return private.numGroupsCache[operationName]
end

function private.NumItemsVirtualField(operationName)
	if not private.numItemsCache[operationName] then
		local includesBaseGroup = false
		local num = 0
		for _, groupPath in GroupOperation.GroupIteratorByOperation(private.currentModule, operationName) do
			if groupPath == Group.GetRootPath() then
				includesBaseGroup = true
			else
				num = num + Group.GetNumItems(groupPath)
			end
		end
		if includesBaseGroup then
			num = num + 0.9
		end
		private.numItemsCache[operationName] = num
	end
	return private.numItemsCache[operationName]
end

function private.OperationListOnOperationConfigure(scrollTable, operationName)
	scrollTable:GetElement("__parent.__parent.__parent.__parent.__parent.selection.operationTree")
		:SetSelectedOperation(private.currentModule, operationName)
end
