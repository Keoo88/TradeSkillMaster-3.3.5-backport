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
		title = CHARACTER,
		justifyH = "RIGHT",
		font = "BODY_BODY3",
		sortField = "player",
	},
	stackSize = {
		title = L["Stack"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "stackSize",
	},
	quantity = {
		title = L["Auctions"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "auctions",
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

local LedgerAuctionsScrollTable = UIElements.Define("LedgerAuctionsScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerAuctionsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._createdGroupName = nil
	self._onItemRowClick = nil
end

function LedgerAuctionsScrollTable:Release()
	self._query = nil
	self._createdGroupName = nil
	self._onItemRowClick = nil
	self.__super:Release()
end

---Sets the name to assign to the group created from this table.
---@param name string The group name
---@return LedgerTransactionsScrollTable
function LedgerAuctionsScrollTable:SetCreatedGroupName(name)
	assert(name)
	self._createdGroupName = name
	return self
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return LedgerAuctionsScrollTable
function LedgerAuctionsScrollTable:SetQuery(query)
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
---@param recordType string Record type
---@param name? string Name filter
---@param quality? table Quality filter
---@param player? table Player filter
---@param timeFilter? number Time filter
---@param group? table Group filter
---@return LedgerAuctionsScrollTable
function LedgerAuctionsScrollTable:SetFilters(recordType, name, quality, player, timeFilter, group)
	self._query:ResetFilters()
		:Equal("type", recordType)
	if name then
		self._query:Matches("name", name)
	end
	if quality then
		self._query:InTable("quality", quality)
	end
	if player then
		self._query:InTable("player", player)
	end
	if timeFilter then
		self._query:GreaterThanOrEqual("time", LibTSMUI.GetTime() - timeFilter)
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
---@return LedgerAuctionsScrollTable
function LedgerAuctionsScrollTable:SetScript(script, handler)
	if script == "OnItemRowClick" then
		self._onItemRowClick = handler
	else
		error("Unknown LedgerAuctionsScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerAuctionsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	assert(self._createdGroupName)
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		local itemString, player, stackSize, auctions, recordTime = row:GetFields("filteredItemString", "player", "stackSize", "auctions", "time")
		tinsert(self._data.item, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.player, player)
		tinsert(self._data.stackSize, stackSize)
		tinsert(self._data.quantity, auctions)
		tinsert(self._data.time, SecondsToTime(LibTSMUI.GetTime() - recordTime))
		self._createGroupsData[itemString] = self._createdGroupName
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function LedgerAuctionsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local dbRow = self._query:GetNthResult(dataIndex)
	if self._onItemRowClick then
		self:_onItemRowClick(dbRow:GetField("filteredItemString"))
	end
end

function LedgerAuctionsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
