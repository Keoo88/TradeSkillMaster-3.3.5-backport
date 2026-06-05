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
	player = {
		title = PLAYER,
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "otherPlayer",
	},
	type = {
		title = TYPE,
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "source",
	},
	stack = {
		title = L["Stack"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "stackSize",
	},
	auctions = {
		title = L["Auctions"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "auctions",
	},
	perItem = {
		title = L["Per Item"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "price",
	},
	total = {
		title = L["Total"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "total",
	},
	time = {
		title = L["Time Frame"],
		justifyH = "RIGHT",
		font = "BODY_BODY3",
		sortField = "time",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerTransactionsScrollTable = UIElements.Define("LedgerTransactionsScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerTransactionsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._createdGroupName = nil
	self._onItemRowClick = nil
end

function LedgerTransactionsScrollTable:Release()
	self._query = nil
	self._createdGroupName = nil
	self._onItemRowClick = nil
	self.__super:Release()
end

---Sets the name to assign to the group created from this table.
---@param name string The group name
---@return LedgerTransactionsScrollTable
function LedgerTransactionsScrollTable:SetCreatedGroupName(name)
	assert(name)
	self._createdGroupName = name
	return self
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return LedgerTransactionsScrollTable
function LedgerTransactionsScrollTable:SetQuery(query)
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
---@param type string Type filter
---@param name? string Item name filter
---@param source? string[] Source filter
---@param quality? string[] Quality filter
---@param player? string[] Player filter
---@param minTimeFrame? number Minimum time frame
---@param group? string[] Group filter
---@return LedgerTransactionsScrollTable
function LedgerTransactionsScrollTable:SetFilters(type, name, source, quality, player, minTimeFrame, group)
	self._query:ResetFilters()
		:Equal("type", type)
	if name then
		self._query:Matches("name", name)
	end
	if source then
		self._query:InTable("source", source)
	end
	if quality then
		self._query:InTable("quality", quality)
	end
	if player then
		self._query:InTable("player", player)
	end
	if minTimeFrame then
		self._query:GreaterThan("time", LibTSMUI.GetTime() - minTimeFrame)
	end
	if group then
		self._query:InTable("groupPath", group)
	end
	self:_HandleQueryUpdate()
	return self
end

---Registers a script handler.
---@param script "OnItemRowClick" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return LedgerTransactionsScrollTable
function LedgerTransactionsScrollTable:SetScript(script, handler)
	if script == "OnItemRowClick" then
		self._onItemRowClick = handler
	else
		error("Unknown LedgerTransactionsScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerTransactionsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(self._createdGroupName)
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		self._createGroupsData[row:GetField("filteredItemString")] = self._createdGroupName
	end
	self:_UpdateDataDeferredLoading(self._query:Count())
end

function LedgerTransactionsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local dbRow = self._query:GetNthResult(dataIndex)
	local itemString, otherPlayer, source, stackSize, auctions, price, total, recordTime = dbRow:GetFields("filteredItemString", "otherPlayer", "source", "stackSize", "auctions", "price", "total", "time")
	self._data.item[dataIndex] = "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?")
	self._data.item_tooltip[dataIndex] = itemString
	self._data.player[dataIndex] = otherPlayer
	self._data.type[dataIndex] = source
	self._data.stack[dataIndex] = stackSize
	self._data.auctions[dataIndex] = auctions
	self._data.perItem[dataIndex] = Money.ToStringForUI(price)
	self._data.total[dataIndex] = Money.ToStringForUI(total)
	self._data.time[dataIndex] = SecondsToTime(LibTSMUI.GetTime() - recordTime)
end

---@param row ListRow
function LedgerTransactionsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local dbRow = self._query:GetNthResult(dataIndex)
	if self._onItemRowClick then
		self:_onItemRowClick(dbRow:GetField("filteredItemString"))
	end
end

function LedgerTransactionsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
