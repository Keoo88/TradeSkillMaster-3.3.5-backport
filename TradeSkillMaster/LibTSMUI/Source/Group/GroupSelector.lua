-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Analytics = LibTSMUI:From("LibTSMUtil"):Include("Util.Analytics")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local private = {}
local TEXT_MARGIN = 8
local ICON_WIDTH = 18
local ICON_MARGIN = 4
local CORNER_RADIUS = 4
local DEFAULT_CONTEXT = { selected = {}, collapsed = {} }



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupSelector = UIElements.Define("GroupSelector", "Element")
GroupSelector:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupSelector:__init()
	local frame = self:_CreateButton()
	self.__super:__init(frame)
	frame:TSMSetScript("OnClick", self:__closure("_HandleClick"))

	frame.text = self:_CreateFontString()
	frame.text:TSMSetFont("BODY_BODY2")
	frame.text:SetPoint("TOPLEFT", TEXT_MARGIN, 0)
	frame.text:SetPoint("BOTTOMRIGHT", -ICON_MARGIN - ICON_WIDTH - TEXT_MARGIN, 0)
	frame.text:SetJustifyH("LEFT")
	frame.text:SetJustifyV("MIDDLE")

	frame.icon = self:_CreateTexture()
	frame.icon:SetPoint("RIGHT", -ICON_MARGIN, 0)

	frame.iconBtn = self:_CreateButton()
	frame.iconBtn:SetAllPoints(frame.icon)
	frame.iconBtn:TSMSetScript("OnClick", self:__closure("_HandleIconClick"))

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)

	self._groupTreeContext = CopyTable(DEFAULT_CONTEXT)
	self._hintText = ""
	self._selectedText = L["%d groups"]
	self._singleSelection = nil
	self._onSelectionChanged = nil
	self._customQueryFunc = nil
	self._showCreateNew = false
end

function GroupSelector:Acquire()
	self.__super:Acquire()
	self._backgroundTexture:SubscribeColor("ACTIVE_BG")
end

function GroupSelector:Release()
	wipe(self._groupTreeContext.collapsed)
	wipe(self._groupTreeContext.selected)
	self._hintText = ""
	self._selectedText = L["%d groups"]
	self._singleSelection = nil
	self._onSelectionChanged = nil
	self._customQueryFunc = nil
	self._showCreateNew = false
	self.__super:Release()
end

---Sets the hint text.
---@param text string The hint text
---@return GroupSelector
function GroupSelector:SetHintText(text)
	assert(type(text) == "string")
	self._hintText = text
	return self
end

---Sets the selected text.
---@param text string The selected text (with a %d formatter for the number of groups)
---@return GroupSelector
function GroupSelector:SetSelectedText(text)
	assert(type(text) == "string" and strmatch(text, "%%d"))
	self._selectedText = text
	return self
end

---Registers a script handler.
---@param script string The script to register for (supported scripts: `OnSelectionChanged`)
---@param handler function The script handler which will be called with the group selector object followed by any arguments to the script
---@return GroupSelector
function GroupSelector:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChanged = handler
	else
		error("Unknown GroupSelector script: "..tostring(script))
	end
	return self
end

---Sets a custom function to generate a query to use for the group tree.
---@param func function A function to call to create the query (gets auto-released by the GroupTree)
---@return GroupSelector
function GroupSelector:SetCustomQueryFunc(func)
	self._customQueryFunc = func
	return self
end

---Adds the "Create New Group" option to the group tree.
---@return GroupSelector
function GroupSelector:AddCreateNew()
	self._showCreateNew = true
	return self
end

---Sets the selection to only handle single selection.
---@param enabled boolean The state of the single selection
---@return GroupSelector
function GroupSelector:SetSingleSelection(enabled)
	self._singleSelection = enabled
	return self
end

---Returns the single selected group path.
function GroupSelector:GetSelection()
	assert(self._singleSelection)
	return next(self._groupTreeContext.selected)
end

---Sets the single selected group path.
---@param selection string|table The selected group(s) or nil if nothing should be selected
---@return GroupSelector
function GroupSelector:SetSelection(selection)
	wipe(self._groupTreeContext.selected)
	if not selection then
		return self
	end
	if self._singleSelection then
		self._groupTreeContext.selected[selection] = true
	else
		for groupPath in pairs(selection) do
			self._groupTreeContext.selected[groupPath] = true
		end
	end
	return self
end

---Returns an iterator for all selected groups.
---@return iter Iterator @An iterator which iterates over the selected groups and has the following values: `groupPath`
function GroupSelector:SelectedGroupIterator()
	return pairs(self._groupTreeContext.selected)
end

---Clears all selected groups.
---@param silent boolean Don't call the selection changed callback
---@return GroupSelector
function GroupSelector:ClearSelectedGroups(silent)
	wipe(self._groupTreeContext.selected)
	if not silent then
		self:_SendActionScript("OnSelectionChanged")
		if self._onSelectionChanged then
			self:_onSelectionChanged()
		end
	end
	return self
end

function GroupSelector:Draw()
	self.__super:Draw()
	local frame = self:_GetBaseFrame()

	local numGroups = Table.Count(self._groupTreeContext.selected)
	frame.text:SetText(numGroups == 0 and self._hintText or (self._singleSelection and Group.FormatPath(next(self._groupTreeContext.selected)) or format(self._selectedText, numGroups)))

	frame.icon:TSMSetTextureAndSize(numGroups == 0 and "iconPack.18x18/Add/Default" or "iconPack.18x18/Close/Default")
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function GroupSelector.__private:_HandleClick()
	local query = self._customQueryFunc and self._customQueryFunc() or GroupOperation.CreateQuery()
	if self._singleSelection then
		query:NotEqual("groupPath", Group.GetRootPath())
	end

	self:GetBaseElement():ShowDialogFrame(UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(464, 500)
		:SetPadding(8)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("FRAME_BG")
		:SetMouseEnabled(true)
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 8)
			:AddChild(UIElements.New("Text", "title")
				:SetMargin(32, 8, 0, 0)
				:SetFont("BODY_BODY1_BOLD")
				:SetJustifyH("CENTER")
				:SetText(L["Select Group"])
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetScript("OnClick", private.DialogCloseBtnOnClick)
			)
		)
		:AddChild(UIElements.New("Frame", "container")
			:SetLayout("VERTICAL")
			:SetPadding(2)
			:SetBackgroundColor("PRIMARY_BG")
			:SetBorderColor("ACTIVE_BG")
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(8)
				:AddChild(UIElements.New("Input", "input")
					:AllowItemInsert(true)
					:SetIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:SetHintText(L["Search Groups"])
					:SetScript("OnValueChanged", private.DialogFilterOnValueChanged)
				)
				:AddChild(UIElements.New("Button", "expandAllBtn")
					:SetSize(24, 24)
					:SetMargin(8, 0, 0, 0)
					:SetBackground("iconPack.18x18/Expand All")
					:SetScript("OnClick", private.ExpandAllGroupsOnClick)
					:SetTooltip(L["Expand / Collapse All Groups"])
				)
				:AddChildIf(not self._singleSelection, UIElements.New("Button", "selectAllBtn")
					:SetSize(24, 24)
					:SetMargin(8, 0, 0, 0)
					:SetBackground("iconPack.18x18/Select All")
					:SetScript("OnClick", private.SelectAllGroupsOnClick)
					:SetTooltip(L["Select / Deselect All Groups"])
				)
			)
			:AddChildIf(self._showCreateNew, UIElements.New("Button", "createGroup")
				:SetHeight(24)
				:SetMargin(8, 8, 0, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("LEFT")
				:SetIcon("iconPack.14x14/Add/Circle", "LEFT")
				:SetText(L["Create New Group"])
				:SetScript("OnClick", self:__closure("_HandleCreateGroupClicked"))
			)
			:AddChild(UIElements.New(self._singleSelection and "SelectionGroupTree" or "ApplicationGroupTree", "groupTree")
				:SetContextTable(self._groupTreeContext, DEFAULT_CONTEXT)
				:SetQuery(query)
			)
		)
		:AddChild(UIElements.New("ActionButton", "groupBtn")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 0)
			:SetText(L["Select Group"])
			:SetScript("OnClick", self:__closure("_HandleDialogSelectBtnClick"))
		)
	)
end

function GroupSelector.__private:_HandleIconClick()
	if Table.Count(self._groupTreeContext.selected) > 0 then
		self:ClearSelectedGroups()
		self:Draw()
		self:_SendActionScript("OnSelectionChanged")
		if self._onSelectionChanged then
			self:_onSelectionChanged()
		end
	else
		self:_HandleClick()
	end
end

function GroupSelector.__private:_HandleCreateGroupClicked(button)
	local newGroupPath = L["New Group"]
	if Group.Exists(newGroupPath) then
		local num = 1
		while Group.Exists(newGroupPath.." "..num) do
			num = num + 1
		end
		newGroupPath = newGroupPath.." "..num
	end
	GroupOperation.CreateGroup(newGroupPath)
	Analytics.Action("CREATED_GROUP", newGroupPath)
	button:GetElement("__parent.groupTree")
		:SetSelection(newGroupPath)
		:Draw()
end

function GroupSelector.__private:_HandleDialogSelectBtnClick(button)
	button:GetBaseElement():HideDialog()
	self:Draw()
	self:_SendActionScript("OnSelectionChanged")
	if self._onSelectionChanged then
		self:_onSelectionChanged()
	end
end


-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DialogCloseBtnOnClick(button)
	button:GetBaseElement():HideDialog()
end

function private.DialogFilterOnValueChanged(input)
	input:GetElement("__parent.__parent.groupTree")
		:SetSearchString(strlower(input:GetValue()))
		:Draw()
end

function private.ExpandAllGroupsOnClick(button)
	button:GetElement("__parent.__parent.groupTree")
		:ToggleExpandAll()
end

function private.SelectAllGroupsOnClick(button)
	button:GetElement("__parent.__parent.groupTree")
		:ToggleSelectAll()
end
