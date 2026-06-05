-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	selectedTemp = {},
}
local COL_INFO = {
	selected = {
		titleIcon = "iconPack.14x14/Checkmark/Default",
		justifyH = "CENTER",
		font = "ITEM_BODY3",
		disableHiding = true,
	},
	name = {
		title = L["Operation"],
		justifyH = "LEFT",
		font = "TABLE_TABLE1",
		hasTooltip = true,
		disableHiding = true,
		sortField = "operationName",
	},
	groups = {
		title = L["Groups Using"],
		justifyH = "LEFT",
		font = "TABLE_TABLE1",
		sortField = "numGroups",
	},
	items = {
		title = L["Items Using"],
		justifyH = "LEFT",
		font = "TABLE_TABLE1",
		hasTooltip = true,
		sortField = "numItems",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationSummaryScrollTable = UIElements.Define("OperationSummaryScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationSummaryScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._data.slotId = {}
	self._query = nil
	self._selectedOperations = {}
	self._onSelectionChangedHandler = nil
	self._onOperationConfigure = nil
end

function OperationSummaryScrollTable:Release()
	local query = self._query
	self._query = nil
	wipe(self._selectedOperations)
	self._onSelectionChangedHandler = nil
	self._onOperationConfigure = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return OperationSummaryScrollTable
function OperationSummaryScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self._settings[self._settingsKey]
	query
		:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_DrawSortFlag()
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Iterates over the selected operations.
---@return fun(): string @Iterator with fields: `operationName`
function OperationSummaryScrollTable:SelectedOperationsIterator()
	return Table.KeyIterator(self._selectedOperations)
end

---Gets the selection state.
---@return boolean allSelected
---@return boolean noneSelected
function OperationSummaryScrollTable:GetSelectionState()
	local allSelected, noneSelected = true, true
	for _, row in self._query:Iterator() do
		local selected = self._selectedOperations[row:GetField("operationName")]
		allSelected = allSelected and selected
		noneSelected = noneSelected and not selected
	end
	return allSelected, noneSelected
end

---Sets the selection state.
---@param allSelected boolean Whether to set the selection to all or none
---@return OperationSummaryScrollTable
function OperationSummaryScrollTable:SetSelectionState(allSelected)
	local changed = false
	if allSelected then
		for _, row in self._query:Iterator() do
			local operationName = row:GetField("operationName")
			if not self._selectedOperations[operationName] then
				self._selectedOperations[operationName] = true
				changed = true
			end
		end
	else
		changed = next(self._selectedOperations) and true or false
		wipe(self._selectedOperations)
	end
	if not changed then
		return self
	end

	self:_HandleQueryUpdate()
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler()
	end
	return self
end

---Registers a script handler.
---@param script "OnSelectionChanged"|"OnOperationConfigure" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return OperationSummaryScrollTable
function OperationSummaryScrollTable:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChangedHandler = handler
	elseif script == "OnOperationConfigure" then
		self._onOperationConfigure = handler
	else
		error("Unknown OperationSummaryScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function OperationSummaryScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(not next(private.selectedTemp))
	for _, row in self._query:Iterator() do
		local operationName, numGroups, numItems = row:GetFields("operationName", "numGroups", "numItems")
		local selected = self._selectedOperations[operationName]
		private.selectedTemp[operationName] = selected
		tinsert(self._data.selected, selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or "")
		tinsert(self._data.name, operationName)
		tinsert(self._data.groups, numGroups)
		if numItems == floor(numItems) then
			tinsert(self._data.items, numItems)
			tinsert(self._data.items_tooltip, false)
		else
			tinsert(self._data.items, floor(numItems).."*")
			tinsert(self._data.items_tooltip, L["This operation is applied to the base group which includes every item not in another group."])
		end
	end
	wipe(self._selectedOperations)
	for operationName in pairs(private.selectedTemp) do
		self._selectedOperations[operationName] = true
	end
	wipe(private.selectedTemp)
	self:_SetNumRows(#self._data.name)
	self:Draw()
end

---@param row ListRow
function OperationSummaryScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	local configureIcon = row:AddTexture("configureIcon")
	configureIcon:TSMSetTextureAndSize("iconPack.12x12/Popout")
	configureIcon:SetPoint("RIGHT", row:GetText("name"))
	configureIcon:Hide()
end

---@param row ListRow
function OperationSummaryScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local operationName = self._query:GetNthResult(dataIndex):GetField("operationName")
	if mouseButton == "LeftButton" then
		local selected = not self._selectedOperations[operationName] or nil
		self._selectedOperations[operationName] = selected
		self._data.selected[dataIndex] = selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or ""
		self:_HandleRowDraw(row)
		if self._onSelectionChangedHandler then
			self:_onSelectionChangedHandler()
		end
	elseif mouseButton == "RightButton" then
		if self._onOperationConfigure then
			self:_onOperationConfigure(operationName)
		end
	end
end

function OperationSummaryScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	local id = Table.GetDistinctKey(self._header.cells, button)
	if not COL_INFO[id].sortField then
		-- Don't allow sorting by this row
		return
	elseif not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
