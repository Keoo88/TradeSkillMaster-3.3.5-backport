-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Iterator = LibTSMUI:From("LibTSMUtil"):IncludeClassType("Iterator")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ApplicationGroupTree = UIElements.Define("ApplicationGroupTree", "GroupTree")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ApplicationGroupTree:__init()
	self.__super:__init()
	self._keepTopLevelSelected = false
	self._selectedGroupsChangedHandler = nil
	self._selectedIter = Iterator.New()
		:SetFilterFunc(self:__closure("_SelectedIterFilterFunc"))
end

function ApplicationGroupTree:Release()
	self._keepTopLevelSelected = false
	self._selectedGroupsChangedHandler = nil
	self.__super:Release()
end

---Adjusts the selection behavior to always keep the top level group selected.
---@return ApplicationGroupTree
function ApplicationGroupTree:KeepTopLevelGroupSelected()
	self._keepTopLevelSelected = true
	return self
end

---Registers a script handler.
---@param script "OnGroupSelectionChanged" The script to register for (supported scripts: `OnGroupSelectionChanged`)
---@param handler function The script handler which will be called with the item list object followed by any arguments
---@return ApplicationGroupTree
function ApplicationGroupTree:SetScript(script, handler)
	if script == "OnGroupSelectionChanged" then
		self._selectedGroupsChangedHandler = handler
	else
		error("Unknown ApplicationGroupTree script: "..tostring(script))
	end
	return self
end

---Iterates through the selected groups.
---@return fun(): number, GroupPathValue @Iterator with fields: `index`, `groupPath`
function ApplicationGroupTree:SelectedGroupsIterator()
	return self._selectedIter:Execute(ipairs(self._allGroupPaths))
end

---Sets the context table which is used to persist the selected and collapsed state.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `unselected` OR `selected`, `collapsed`)
---@return ApplicationGroupTree
function ApplicationGroupTree:SetContextTable(tbl, defaultTbl)
	if defaultTbl.unselected then
		assert(type(defaultTbl.unselected) == "table" and not defaultTbl.selected)
		tbl.unselected = tbl.unselected or CopyTable(defaultTbl.unselected)
		tbl.selected = nil
	else
		assert(type(defaultTbl.selected) == "table" and not defaultTbl.unselected)
		tbl.selected = tbl.selected or CopyTable(defaultTbl.selected)
		tbl.unselected = nil
	end
	self.__super:SetContextTable(tbl, defaultTbl)
	return self
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to check
---@return boolean
function ApplicationGroupTree:IsGroupSelected(groupPath)
	return self:_IsSelected(groupPath)
end

---Gets whether or not a group is currently selected.
---@param groupPath GroupPathValue The group to set the selected state of
---@param selected boolean Whether or not the group should be selected
---@return ApplicationGroupTree
function ApplicationGroupTree:SetGroupSelected(groupPath, selected)
	self:_SetSelected(groupPath, selected)
	return self
end

---Gets whether or not the selection is cleared.
---@return boolean
function ApplicationGroupTree:IsSelectionCleared()
	for _, groupPath in ipairs(self._searchStr == "" and self._allGroupPaths or self._groupPath) do
		if self:_IsSelected(groupPath) and (not self._keepTopLevelSelected or Group.GetParent(groupPath) ~= Group.GetRootPath()) then
			return false
		end
	end
	return true
end

---Toggle the selection state of the application group tree.
---@return ApplicationGroupTree
function ApplicationGroupTree:ToggleSelectAll()
	local isCleared = self:IsSelectionCleared()
	for _, groupPath in ipairs(self._searchStr == "" and self._allGroupPaths or self._groupPath) do
		self:_SetSelectedCascading(groupPath, isCleared)
	end

	if self._selectedGroupsChangedHandler then
		self:_selectedGroupsChangedHandler()
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ApplicationGroupTree.__protected:_HandleQueryUpdate()
	if not self._contextTable then
		return
	end
	self.__super:_HandleQueryUpdate()
	-- Remove data which is no longer present from _contextTable
	local selectedGroups = TempTable.Acquire()
	for _, groupPath in self:SelectedGroupsIterator() do
		selectedGroups[groupPath] = true
	end
	wipe(self._contextTable.selected or self._contextTable.unselected)
	for _, groupPath in ipairs(self._allGroupPaths) do
		self:_SetSelected(groupPath, selectedGroups[groupPath])
	end
	TempTable.Release(selectedGroups)
end

function ApplicationGroupTree.__protected:_IsSelected(groupPath)
	if self._contextTable.unselected then
		return not self._contextTable.unselected[groupPath]
	else
		return self._contextTable.selected[groupPath] or false
	end
end

function ApplicationGroupTree.__private:_SetSelectedCascading(groupPath, selected)
	self:_SetSelected(groupPath, selected)
	if groupPath == Group.GetRootPath() then
		-- Don't cascade for the base group
		return
	end
	for _, childGroupPath in ipairs(self._allGroupPaths) do
		if Group.IsChild(childGroupPath, groupPath) then
			self:_SetSelected(childGroupPath, selected)
		end
	end
end

function ApplicationGroupTree.__private:_SetSelected(groupPath, selected)
	if self._keepTopLevelSelected and Group.GetParent(groupPath) == Group.GetRootPath() then
		selected = true
	end
	if self._contextTable.unselected then
		self._contextTable.unselected[groupPath] = not selected or nil
	else
		self._contextTable.selected[groupPath] = selected or nil
	end

	local index = Table.KeyByValue(self._groupPath, groupPath)
	local row = index and self:_GetRow(index)
	if row then
		row:SetSelected(selected or false)
		self:_DrawRowFlag(row)
	end
end

---@param row ListRow
function ApplicationGroupTree.__protected:_HandleRowClick(row, mouseButton)
	if self.__super:_HandleRowClick(row, mouseButton) then
		return
	end

	local rowGroupPath = self._groupPath[row:GetDataIndex()]
	local selected = not self:_IsSelected(rowGroupPath)
	self:_SetSelectedCascading(rowGroupPath, selected)
	if self._selectedGroupsChangedHandler then
		self:_selectedGroupsChangedHandler()
	end
end

function ApplicationGroupTree.__private:_SelectedIterFilterFunc(_, _, groupPath)
	return self:_IsSelected(groupPath)
end
