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
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	bought = {
		title = L["Bought"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "bought",
	},
	avgBuyPrice = {
		title = L["Avg Buy Price"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "avgBuyPrice",
	},
	sold = {
		title = L["Sold"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "sold",
	},
	avgSellPrice = {
		title = L["Avg Sell Price"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "avgSellPrice",
	},
	avgProfit = {
		title = L["Avg Profit"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "avgProfit",
	},
	totalProfit = {
		title = L["Total Profit"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "totalProfit",
	},
	profitPct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "profitPct",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerResaleScrollTable = UIElements.Define("LedgerResaleScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerResaleScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._onItemRowClick = nil
end

function LedgerResaleScrollTable:Release()
	self._query = nil
	self._onItemRowClick = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return LedgerResaleScrollTable
function LedgerResaleScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self._settings[self._settingsKey]
	query
		:ResetFilters()
		:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_DrawSortFlag()
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Sets the filters.
---@param quality? string[] Quality filter
---@return LedgerResaleScrollTable
function LedgerResaleScrollTable:SetFilters(quality)
	self._query:ResetFilters()
	if quality then
		self._query:InTable("quality", quality)
	end
	self:_HandleQueryUpdate()
	return self
end

---Registers a script handler.
---@param script "OnItemRowClick" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return LedgerResaleScrollTable
function LedgerResaleScrollTable:SetScript(script, handler)
	if script == "OnItemRowClick" then
		self._onItemRowClick = handler
	else
		error("Unknown DestroyingScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerResaleScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		self._createGroupsData[row:GetField("itemString")] = L["Ledger"].." - "..L["Resale"]
	end
	self:_UpdateDataDeferredLoading(self._query:Count())
end

function LedgerResaleScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local dbRow = self._query:GetNthResult(dataIndex)
	local itemString, bought, avgBuyPrice, sold, avgSellPrice, avgProfit, totalProfit, profitPct = dbRow:GetFields("itemString", "bought", "avgBuyPrice", "sold", "avgSellPrice", "avgProfit", "totalProfit", "profitPct")
	self._data.item[dataIndex] = "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?")
	self._data.item_tooltip[dataIndex] = itemString
	self._data.bought[dataIndex] = bought
	self._data.avgBuyPrice[dataIndex] = Money.ToStringForUI(avgBuyPrice)
	self._data.sold[dataIndex] = sold
	self._data.avgSellPrice[dataIndex] = Money.ToStringForUI(avgSellPrice)
	local profitColor = Theme.GetColor(avgProfit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED")
	self._data.avgProfit[dataIndex] = Money.ToStringForUI(avgProfit, profitColor:GetTextColorPrefix())
	self._data.totalProfit[dataIndex] = Money.ToStringForUI(totalProfit, profitColor:GetTextColorPrefix())
	self._data.profitPct[dataIndex] = profitColor:ColorText(profitPct.."%")
end

---@param row ListRow
function LedgerResaleScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local dbRow = self._query:GetNthResult(dataIndex)
	if self._onItemRowClick then
		self:_onItemRowClick(dbRow:GetField("itemString"))
	end
end

function LedgerResaleScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
