-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ApplicationGroupTreeWithControls = UIElements.Define("ApplicationGroupTreeWithControls", "Frame")
ApplicationGroupTreeWithControls:_AddActionScripts("OnGroupSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ApplicationGroupTreeWithControls:__init(frame)
	self.__super:__init(frame)
	self._filterText = ""
	self._keepTopLevelSelected = false
end

function ApplicationGroupTreeWithControls:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(8)
		:AddChild(UIElements.New("Input", "input")
			:SetMargin(0, 8, 0, 0)
			:AllowItemInsert(true)
			:SetIconTexture("iconPack.18x18/Search")
			:SetClearButtonEnabled(true)
			:SetHintText(L["Search Groups"])
			:SetScript("OnValueChanged", self:__closure("_HandleFilterValueChanged"))
		)
		:AddChild(UIElements.New("Button", "expandAllBtn")
			:SetSize(24, 24)
			:SetBackground("iconPack.18x18/Expand All")
			:SetScript("OnClick", self:__closure("_HandleExpandAllClick"))
			:SetTooltip(L["Expand / Collapse All Groups"])
		)
		:AddChild(UIElements.New("Button", "selectAllBtn")
			:SetSize(24, 24)
			:SetMargin(4, 0, 0, 0)
			:SetBackground("iconPack.18x18/Select All")
			:SetScript("OnClick", self:__closure("_HandleSelectAllClick"))
			:SetTooltip(L["Select / Deselect All Groups"])
		)
	)
	self:AddChild(UIElements.New("HorizontalLine", "line"))
	self:AddChild(UIElements.New("ApplicationGroupTree", "groupTree")
		:SetScript("OnGroupSelectionChanged", self:__closure("_HandleGroupSelectionChanged"))
	)
end

function ApplicationGroupTreeWithControls:Release()
	self._keepTopLevelSelected = false
	self._filterText = ""
	self.__super:Release()
end

---Adjusts the selection behavior to always keep the top level group selected.
---@return ApplicationGroupTreeWithControls
function ApplicationGroupTreeWithControls:KeepTopLevelGroupSelected()
	self:GetElement("groupTree"):KeepTopLevelGroupSelected()
	return self
end

---Sets the group tree operation type.
---@param operationType string The operation type
---@return ApplicationGroupTreeWithControls
function ApplicationGroupTreeWithControls:SetOperationType(operationType)
	self:GetElement("groupTree"):SetQuery(GroupOperation.CreateQuery(), operationType)
	return self
end

---Sets the query used to populate the group tree.
---@param query DatabaseQuery The database query object
---@param operationType? string The operation type to filter groups by
---@return ApplicationGroupTreeWithControls
function ApplicationGroupTreeWithControls:SetQuery(query, operationType)
	self:GetElement("groupTree"):SetQuery(query, operationType)
	return self
end

---Sets the context table which is used to persist the selected and collapsed state.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `unselected` OR `selected`, `collapsed`)
---@return ApplicationGroupTreeWithControls
function ApplicationGroupTreeWithControls:SetContextTable(tbl, defaultTbl)
	self:GetElement("groupTree"):SetContextTable(tbl, defaultTbl)
	return self
end

---Sets the group tree context table from a settings object.
---@param settings Settings The settings object
---@param key string The setting key
---@return ApplicationGroupTreeWithControls
function ApplicationGroupTreeWithControls:SetSettingsContext(settings, key)
	self:GetElement("groupTree"):SetSettingsContext(settings, key)
	return self
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to check
---@return boolean
function ApplicationGroupTreeWithControls:IsGroupSelected(groupPath)
	return self:GetElement("groupTree"):IsGroupSelected(groupPath)
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to set the selected state of
---@param selected boolean Whether or not the group should be selected
---@return ApplicationGroupTreeWithControls
function ApplicationGroupTreeWithControls:SetGroupSelected(groupPath, selected)
	self:GetElement("groupTree"):SetGroupSelected(groupPath, selected)
	return self
end

---Gets whether or not the group tree selection is cleared.
---@return boolean
function ApplicationGroupTreeWithControls:IsSelectionCleared()
	return self:GetElement("groupTree"):IsSelectionCleared()
end

---Iterates through the selected groups.
---@return fun(): number, GroupPathValue @Iterator with fields: `index`, `groupPath`
function ApplicationGroupTreeWithControls:SelectedGroupsIterator()
	return self:GetElement("groupTree"):SelectedGroupsIterator()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ApplicationGroupTreeWithControls.__private:_CloseDialog()
	self:GetBaseElement():HideDialog()
end

function ApplicationGroupTreeWithControls.__private:_HandleFilterValueChanged()
	local input = self:GetElement("header.input")
	local text = strlower(input:GetValue())
	if text == self._filterText then
		return
	end
	self._filterText = text
	self:GetElement("groupTree"):SetSearchString(self._filterText)
end

function ApplicationGroupTreeWithControls.__private:_HandleGroupSelectionChanged()
	self:_SendActionScript("OnGroupSelectionChanged")
end

function ApplicationGroupTreeWithControls.__private:_HandleExpandAllClick()
	self:GetElement("groupTree"):ToggleExpandAll()
end

function ApplicationGroupTreeWithControls.__private:_HandleSelectAllClick()
	self:GetElement("groupTree"):ToggleSelectAll()
end
