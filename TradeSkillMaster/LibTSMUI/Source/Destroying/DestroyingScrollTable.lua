-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local COL_INFO = {
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
	},
	num = {
		title = L["Qty"],
		justifyH = "CENTER",
		font = "TABLE_TABLE1",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local DestroyingScrollTable = UIElements.Define("DestroyingScrollTable", "ScrollTable")
DestroyingScrollTable:_AddActionScripts("OnSelectionChanged", "OnHideIconClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DestroyingScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._data.slotId = {}
	self._query = nil
	self._selectionItemString = nil
	self._selectionSlotId = nil
end

function DestroyingScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
end

function DestroyingScrollTable:Release()
	self._query = nil
	self._selectionItemString = nil
	self._selectionSlotId = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return DestroyingScrollTable
function DestroyingScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Selects the first item in the table.
---@return DestroyingScrollTable
function DestroyingScrollTable:SelectFirstItem()
	self:_SetSelectedSlot(self._data.slotId[1])
	return self
end

---Gets the selected item and slot.
---@return string? itemString
---@return number? slotId
function DestroyingScrollTable:GetSelection()
	return self._selectionItemString, self._selectionSlotId
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function DestroyingScrollTable.__private:_SetSelectedSlot(slotId)
	local dataIndex = slotId and Table.KeyByValue(self._data.slotId, slotId) or nil
	local prevDataIndex = self._selectionSlotId and Table.KeyByValue(self._data.slotId, self._selectionSlotId) or nil
	if slotId == self._selectionSlotId and (not slotId or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	if dataIndex then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			newRow:SetSelected(true)
		end
		self._selectionItemString = self._query:GetNthResult(dataIndex):GetField("itemString")
		self._selectionSlotId = slotId
		self:_ScrollToRow(dataIndex)
	else
		self._selectionItemString = nil
		self._selectionSlotId = nil
	end

	self:_SendActionScript("OnSelectionChanged")
	return self
end

function DestroyingScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	wipe(self._actionIcon)
	local hasExistingSelection, nextSelectionSlotId = false, nil
	for _, row in self._query:Iterator() do
		local itemString, quantity, name, slotId = row:GetFields("itemString", "quantity", "name", "slotId")
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.num, quantity)
		tinsert(self._actionIcon, "iconPack.12x12/Hide")
		tinsert(self._data.slotId, slotId)
		if self._selectionItemString then
			if slotId == self._selectionSlotId and itemString == self._selectionItemString then
				hasExistingSelection = true
			elseif not nextSelectionSlotId then
				local selectionName = ItemInfo.GetName(self._selectionItemString) or "?"
				if name > selectionName or (name == selectionName and slotId > self._selectionSlotId) then
					nextSelectionSlotId = slotId
				end
			end
		end
		self._createGroupsData[itemString] = L["Destroying"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()

	-- Update the selection if necessary
	if not hasExistingSelection then
		self:_SetSelectedSlot(nextSelectionSlotId)
	end
end

---@param row ListRow
function DestroyingScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	row:AddMouseRegion("actionIcon_mouse", row:GetTexture("actionIcon"), self:__closure("_GetActionIconTooltip"), self:__closure("_HandleActionIconClick"))
end

---@param row ListRow
function DestroyingScrollTable.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	self.__super:_HandleRowDraw(row)
	row:SetSelected(self._data.slotId[dataIndex] == self._selectionSlotId)
end

---@param row ListRow
function DestroyingScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	self:_SetSelectedSlot(self._data.slotId[dataIndex])
end

function DestroyingScrollTable.__private:_GetActionIconTooltip()
	return L["Click to hide this item for the current session. Hold shift to hide this item permanently."]
end

function DestroyingScrollTable.__private:_HandleActionIconClick(mouseButton, dataIndex)
	if mouseButton ~= "LeftButton" then
		return
	end
	local itemString = self._query:GetNthResult(dataIndex):GetField("itemString")
	self:_SendActionScript("OnHideIconClick", itemString, IsShiftKeyDown())
end
