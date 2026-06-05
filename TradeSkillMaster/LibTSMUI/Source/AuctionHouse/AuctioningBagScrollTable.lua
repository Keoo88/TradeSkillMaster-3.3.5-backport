-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
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
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	operation = {
		title = L["Auctioning Operation"],
		justifyH = "LEFT",
		font = "BODY_BODY3_MEDIUM",
		sortField = "firstOperation",
	},
	group = {
		title = L["Group"],
		justifyH = "LEFT",
		font = "BODY_BODY3_MEDIUM",
		sortField = "groupPath",
	},
}




-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningBagScrollTable = UIElements.Define("AuctioningBagScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningBagScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._data.slotId = {}
	self._query = nil
	self._selectedItems = {}
	self._onSelectionChangedHandler = nil
end

function AuctioningBagScrollTable:Release()
	local query = self._query
	self._query = nil
	wipe(self._selectedItems)
	self._onSelectionChangedHandler = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return AuctioningBagScrollTable
function AuctioningBagScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self:_GetSettingsValue()
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

---Iterates over the selected items.
---@return fun(): string @Iterator with fields: `autoBaseItemString`
function AuctioningBagScrollTable:SelectedItemsIterator()
	return Table.KeyIterator(self._selectedItems)
end

---Gets the selection state.
---@return boolean allSelected
---@return boolean noneSelected
function AuctioningBagScrollTable:GetSelectionState()
	local allSelected, noneSelected = true, true
	for _, row in self._query:Iterator() do
		local firstOperation = row:GetField("firstOperation")
		if firstOperation then
			local selected = self._selectedItems[row:GetField("autoBaseItemString")]
			allSelected = allSelected and selected
			noneSelected = noneSelected and not selected
		end
	end
	return allSelected, noneSelected
end

---Sets the selection state.
---@param allSelected boolean Whether to set the selection to all or none
---@return AuctioningBagScrollTable
function AuctioningBagScrollTable:SetSelectionState(allSelected)
	local changed = false
	if allSelected then
		for _, row in self._query:Iterator() do
			local autoBaseItemString, firstOperation = row:GetFields("autoBaseItemString", "firstOperation")
			if firstOperation and not self._selectedItems[autoBaseItemString] then
				self._selectedItems[autoBaseItemString] = true
				changed = true
			end
		end
	else
		changed = next(self._selectedItems) and true or false
		wipe(self._selectedItems)
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
---@param script "OnSelectionChanged" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return AuctioningBagScrollTable
function AuctioningBagScrollTable:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChangedHandler = handler
	else
		error("Unknown AuctioningBagScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function AuctioningBagScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(not next(private.selectedTemp))
	for _, row in self._query:Iterator() do
		local autoBaseItemString, itemTexture, firstOperation, groupPath = row:GetFields("autoBaseItemString", "itemTexture", "firstOperation", "groupPath")
		local selected = self._selectedItems[autoBaseItemString]
		private.selectedTemp[autoBaseItemString] = selected
		tinsert(self._data.selected, selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or "")
		tinsert(self._data.item, "|T"..itemTexture..":0|t "..(UIUtils.GetDisplayItemName(autoBaseItemString) or "?"))
		tinsert(self._data.operation, firstOperation or Theme.GetColor("FEEDBACK_RED"):ColorText(L["Skipped: No assigned operation"]))
		tinsert(self._data.group, Group.FormatPath(groupPath) or "")
		tinsert(self._data.item_tooltip, autoBaseItemString)
	end
	wipe(self._selectedItems)
	for autoBaseItemString in pairs(private.selectedTemp) do
		self._selectedItems[autoBaseItemString] = true
	end
	wipe(private.selectedTemp)
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function AuctioningBagScrollTable.__protected:_HandleRowEnter(row)
	if IsMouseButtonDown("RightButton") then
		self:_HandleRowClick(row, "LeftButton")
	end
end

---@param row ListRow
function AuctioningBagScrollTable.__protected:_HandleRowMouseDown(row, mouseButton)
	if mouseButton == "RightButton" then
		self:_HandleRowClick(row, "LeftButton")
	end
end

---@param row ListRow
function AuctioningBagScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton == "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local autoBaseItemString, firstOperation = self._query:GetNthResult(dataIndex):GetFields("autoBaseItemString", "firstOperation")
	if not firstOperation then
		return
	end
	local selected = not self._selectedItems[autoBaseItemString]
	self._selectedItems[autoBaseItemString] = selected or nil
	self._data.selected[dataIndex] = selected and TextureAtlas.GetTextureLink("iconPack.14x14/Checkmark/Default") or ""
	self:_HandleRowDraw(row)
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler()
	end
end

function AuctioningBagScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	local id = Table.GetDistinctKey(self._header.cells, button)
	if not COL_INFO[id] or not COL_INFO[id].sortField then
		-- Don't allow sorting by this row
		return
	end
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self:_GetSettingsValue()
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
