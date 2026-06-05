-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MultiselectionDropdown = UIElements.Define("MultiselectionDropdown", "BaseDropdown")
MultiselectionDropdown:_ExtendStateSchema()
	:AddNumberField("numSelected", 0)
	:AddNumberField("numItems", 0)
	:AddStringField("noneSelectionText", L["None Selected"])
	:AddStringField("partialSelectionText", L["%d Selected"])
	:AddStringField("allSelectionText", L["All Selected"])
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function MultiselectionDropdown:__init()
	self.__super:__init()
	self._itemKeyLookup = {}
	self._itemIsSelected = {}
	self._settingTableDirect = nil
end

function MultiselectionDropdown:Acquire()
	self.__super:Acquire()
	self._state:PublisherForKeys("numSelected", "numItems", "noneSelectionText", "partialSelectionText", "allSelectionText")
		:MapWithFunction(private.StateToCurrentSelectionStr)
		:AssignToTableKey(self._state, "currentSelectionStr")
end

function MultiselectionDropdown:Release()
	wipe(self._itemKeyLookup)
	wipe(self._itemIsSelected)
	self._settingTableDirect = nil
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Set the items to show in the dropdown dialog list.
---@param items string[] A list of items to be shown in the dropdown list
---@param itemKeys string[] A list of keys which go with the item at the corresponding index in the items list
---@return MultiselectionDropdown
function MultiselectionDropdown:SetItems(items, itemKeys)
	wipe(self._items)
	wipe(self._itemKeyLookup)
	assert(not itemKeys or #itemKeys == #items)
	for i, item in ipairs(items) do
		tinsert(self._items, item)
		self._itemKeyLookup[item] = itemKeys and itemKeys[i] or i
	end
	self._state.numItems = #items
	return self
end

---Set whether the item is selected.
---@param item string The item
---@param selected boolean Whether or not the item should be selected
---@return MultiselectionDropdown
function MultiselectionDropdown:SetItemSelected(item, selected)
	local wasSelected = self:ItemIsSelected(item)
	self:_SetItemSelectedHelper(item, selected)
	if selected and not wasSelected then
		self._state.numSelected = self._state.numSelected + 1
	elseif not selected and wasSelected then
		self._state.numSelected = self._state.numSelected - 1
	end
	self:_SendActionScript("OnSelectionChanged")
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler()
	end
	return self
end

---Set whether the item is selected by key.
---@param itemKey string The key for the item
---@param selected boolean Whether or not the item should be selected
---@return MultiselectionDropdown
function MultiselectionDropdown:SetItemSelectedByKey(itemKey, selected)
	self:SetItemSelected(Table.GetDistinctKey(self._itemKeyLookup, itemKey), selected)
	return self
end

---Set the selected items.
---@param selected table A table where the keys are the items to be selected
---@return MultiselectionDropdown
function MultiselectionDropdown:SetSelectedItems(selected)
	wipe(self._itemIsSelected)
	if self._settingTableDirect then
		wipe(self._settingTableDirect)
	end
	local numSelected = 0
	for _, item in ipairs(self._items) do
		local isSelected = selected[item]
		if isSelected then
			numSelected = numSelected + 1
		end
		self:_SetItemSelectedHelper(item, isSelected)
	end
	self._state.numSelected = numSelected
	self:_SendActionScript("OnSelectionChanged")
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler()
	end
	return self
end

---Set the selected items.
---@param selected table A table where the keys are the items to be selected
---@return MultiselectionDropdown
function MultiselectionDropdown:SetSelectedItemKeys(selected)
	wipe(self._itemIsSelected)
	if self._settingTableDirect then
		wipe(self._settingTableDirect)
	end
	local numSelected = 0
	for _, item in ipairs(self._items) do
		local isSelected = selected[self._itemKeyLookup[item]]
		if isSelected then
			numSelected = numSelected + 1
		end
		self:_SetItemSelectedHelper(item, isSelected)
	end
	self._state.numSelected = numSelected
	self:_SendActionScript("OnSelectionChanged")
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler()
	end
	return self
end

---Set the unselected items.
---@param unselected table A table where the keys are the items which aren't selected
---@return MultiselectionDropdown
function MultiselectionDropdown:SetUnselectedItemKeys(unselected)
	wipe(self._itemIsSelected)
	if self._settingTableDirect then
		wipe(self._settingTableDirect)
	end
	local numSelected = 0
	for _, item in ipairs(self._items) do
		local isSelected = not unselected[self._itemKeyLookup[item]]
		if isSelected then
			numSelected = numSelected + 1
		end
		self:_SetItemSelectedHelper(item, isSelected)
	end
	self._state.numSelected = numSelected
	self:_SendActionScript("OnSelectionChanged")
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler()
	end
	return self
end

---Get the currently selected item.
---@param item string The item
---@return boolean
function MultiselectionDropdown:ItemIsSelected(item)
	return self._itemIsSelected[item] or false
end

---Get the currently selected item.
---@param itemKey string|number The key for the item
---@return boolean
function MultiselectionDropdown:ItemIsSelectedByKey(itemKey)
	return self:ItemIsSelected(Table.GetDistinctKey(self._itemKeyLookup, itemKey))
end

---Sets the setting info.
-- This method is used to have the selected keys of the dropdown automatically correspond with the value of a field in a
-- table. This is useful for dropdowns which are tied directly to settings.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the dropdown state
---@return MultiselectionDropdown
function MultiselectionDropdown:SetSettingInfo(tbl, key)
	local directTbl = tbl[key]
	assert(type(directTbl) == "table")
	-- this function wipes our settingTable, so set the selected items first
	self:SetSelectedItemKeys(directTbl)
	self._settingTableDirect = directTbl
	return self
end

---Populate the specified table with a list of selected items
---@param resultTbl table The table to populate
function MultiselectionDropdown:GetSelectedItems(resultTbl)
	for _, item in ipairs(self._items) do
		if self:ItemIsSelected(item) then
			tinsert(resultTbl, item)
		end
	end
end

---Sets the selection text which is shown to summarize the current value.
---@param noneText string The selection text string when none are selected
---@param partialText string The selection text string for a partial selection
---@param allText string The selection text string when all are selected
---@return BaseDropdown
function MultiselectionDropdown:SetSelectionText(noneText, partialText, allText)
	assert(type(partialText) == "string" and type(partialText) == "string" and type(allText) == "string")
	self._state.noneSelectionText = noneText
	self._state.partialSelectionText = partialText
	self._state.allSelectionText = allText
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MultiselectionDropdown.__protected:_CreateDialog()
	return self.__super:_CreateDialog()
		:SetMultiselect(true)
		:SetItems(self._items, self._itemIsSelected)
		:SetScript("OnSelectionChanged", self:__closure("SetSelectedItems"))
end

function MultiselectionDropdown.__protected:_GetDialogSize()
	local width, height = self.__super:_GetDialogSize()
	width = max(width + 12, 200) -- check icon, and big enough for select all / deselect all buttons
	height = height + 26 -- header + line
	return width, height
end

function MultiselectionDropdown.__private:_SetItemSelectedHelper(item, selected)
	self._itemIsSelected[item] = selected and true or nil
	if self._settingTableDirect then
		self._settingTableDirect[self._itemKeyLookup[item]] = self._itemIsSelected[item]
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToCurrentSelectionStr(state)
	if state.numSelected == 0 then
		return state.hintText ~= "" and state.hintText or state.noneSelectionText
	elseif state.numSelected == state.numItems then
		return state.allSelectionText.." ("..state.numSelected..")"
	else
		return format(state.partialSelectionText, state.numSelected)
	end
end
