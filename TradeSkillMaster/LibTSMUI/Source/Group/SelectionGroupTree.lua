-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SelectionGroupTree = UIElements.Define("SelectionGroupTree", "GroupTree")
SelectionGroupTree:_ExtendStateSchema()
	:AddOptionalStringField("selectedGroup")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SelectionGroupTree:__init()
	self.__super:__init()
	self._selectedGroupChangedHandler = nil
	self._firstDraw = true
end

function SelectionGroupTree:Release()
	self._selectedGroupChangedHandler = nil
	self._firstDraw = true
	self.__super:Release()
end

---Sets the selected group path.
---@param groupPath GroupPathValue The group path to select
---@return SelectionGroupTree
function SelectionGroupTree:SetSelection(groupPath)
	assert(groupPath)
	self._state.selectedGroup = groupPath
	self:_ScrollToRow(Table.KeyByValue(self._groupPath, groupPath))
	return self
end

---Gets the selected group path.
---@return GroupPathValue
function SelectionGroupTree:GetSelection()
	return self._state.selectedGroup
end

---Sets the context table which is used to persist the selected and collapsed state.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `selected`, `collapsed`)
---@return SelectionGroupTree
function SelectionGroupTree:SetContextTable(tbl, defaultTbl)
	assert(not self._contextTable)
	assert(type(defaultTbl.selected) == "table")
	if not tbl.selected or Table.Count(tbl.selected) > 1 then
		tbl.selected = CopyTable(defaultTbl.selected)
	end
	self.__super:SetContextTable(tbl, defaultTbl)
	local selection = next(tbl.selected)
	if selection then
		self._state.selectedGroup = selection
	end
	self._state:PublisherForKeyChange("selectedGroup")
		:IgnoreNil()
		:SetSingleTableKey(tbl.selected)
	return self
end

---Sets the query used to populate the group tree.
---@param query DatabaseQuery The database query object
---@return GroupTree
function SelectionGroupTree:SetQuery(query)
	self.__super:SetQuery(query)
	return self
end

---Registers a script handler.
---@param script "OnGroupSelectionChanged" The script to register for (supported scripts: `OnGroupSelectionChanged`)
---@param handler function The script handler which will be called with the item list object followed by any arguments
---@return SelectionGroupTree
function SelectionGroupTree:SetScript(script, handler)
	if script == "OnGroupSelectionChanged" then
		self._selectedGroupChangedHandler = handler
	else
		error("Unknown SelectionGroupTree script: "..tostring(script))
	end
	return self
end

function SelectionGroupTree:Draw()
	self.__super:Draw()
	if self._state.selectedGroup then
		self:_ScrollToRow(Table.KeyByValue(self._groupPath, self._state.selectedGroup))
	end
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function SelectionGroupTree.__protected:_HandleRowClick(row, mouseButton)
	if self.__super:_HandleRowClick(row, mouseButton) then
		return
	end

	local groupPath = self._groupPath[row:GetDataIndex()]
	if self._selectedGroup == groupPath then
		return
	end
	local prevSelectedGroup = self._state.selectedGroup
	self._state.selectedGroup = groupPath

	self:_DrawSelectedState(row)
	if prevSelectedGroup then
		local prevRow = self:_GetRowForGroupPath(prevSelectedGroup)
		if prevRow then
			self:_DrawSelectedState(prevRow)
		end
	end

	if self._selectedGroupChangedHandler then
		self:_selectedGroupChangedHandler(groupPath)
	end
end

function SelectionGroupTree.__protected:_IsSelected(groupPath)
	return groupPath == self._state.selectedGroup
end
