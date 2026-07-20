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
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	index = {
		titleIcon = "iconPack.14x14/Attention",
		justifyH = "CENTER",
		font = "BODY_BODY3",
		sortField = "index",
	},
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	buyout = {
		title = L["Your Buyout"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "buyout",
	},
	operation = {
		title = L["Operation"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "operation",
	},
	seller = {
		title = L["Seller"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "seller",
	},
	info = {
		title = INFO or "Info",
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "reasonStr",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningLogScrollTable = UIElements.Define("AuctioningLogScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningLogScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._data.rawIndex = {}
	self._selectedIndex = nil
end

function AuctioningLogScrollTable:Release()
	local query = self._query
	self._query = nil
	self._selectedIndex = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return AuctioningLogScrollTable
function AuctioningLogScrollTable:SetQuery(query)
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

---Sets the selected row.
---@param index? number The index to select
---@return AuctioningLogScrollTable
function AuctioningLogScrollTable:SetSelectedIndex(index)
	local dataIndex = index and Table.KeyByValue(self._data.rawIndex, index) or nil
	local prevDataIndex = self._selectedIndex and Table.KeyByValue(self._data.rawIndex, self._selectedIndex) or nil
	if index == nil and self._selectedIndex == nil then
		return
	elseif index == self._selectedIndex and dataIndex then
		self:_ScrollToRow(dataIndex)
		return
	end
	-- NOTE: We explicitly allow setting a selected index which isn't yet part of our data
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	self._selectedIndex = index
	if dataIndex then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			newRow:SetSelected(true)
		end
		self:_ScrollToRow(dataIndex)
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function AuctioningLogScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, row in self._query:Iterator() do
		local indexIcon, itemString, buyout, operation, seller, infoStr, index = row:GetFields("indexIcon", "itemString", "buyout", "operation", "seller", "infoStr", "index")
		tinsert(self._data.index, TextureAtlas.GetTextureLink(indexIcon))
		tinsert(self._data.item, Theme.GetItemIconLink(ItemInfo.GetTexture(itemString) or "Interface\\Icons\\INV_Misc_QuestionMark").." "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.buyout, buyout == 0 and "-" or Money.ToStringForAH(buyout))
		tinsert(self._data.operation, operation)
		tinsert(self._data.seller, seller)
		tinsert(self._data.info, infoStr)
		tinsert(self._data.rawIndex, index)
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function AuctioningLogScrollTable.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	self.__super:_HandleRowDraw(row)
	row:SetSelected(self._data.rawIndex[dataIndex] == self._selectedIndex)
end

function AuctioningLogScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
