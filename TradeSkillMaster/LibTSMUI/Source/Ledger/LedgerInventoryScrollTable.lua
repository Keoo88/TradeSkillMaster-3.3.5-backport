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
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
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
	totalItems = {
		title = L["Total"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "totalQuantity",
	},
	bags = {
		title = L["Bags"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "bagQuantity",
	},
	banks = {
		title = L["Banks"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "totalBankQuantity",
	},
	mail = {
		title = L["Mail"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "mailQuantity",
	},
	alts = {
		title = L["Alts"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "altQuantity",
	},
	guildVault = {
		title = GUILD,
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "guildQuantity",
	},
	auctionHouse = {
		title = L["AH"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "auctionQuantity",
	},
	totalValue = {
		title = L["Value"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "totalValue",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerInventoryScrollTable = UIElements.Define("LedgerInventoryScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerInventoryScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
end

function LedgerInventoryScrollTable:Release()
	self._query = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return LedgerInventoryScrollTable
function LedgerInventoryScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self._settings[self._settingsKey]
	query
		:ResetFilters()
		:NotEqual("name", "")
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
---@param name? string Name filter
---@param group? string[] Group filter
---@return LedgerInventoryScrollTable
function LedgerInventoryScrollTable:SetFilters(name, group)
	self._query:ResetFilters()
		:NotEqual("name", "")
	if name then
		self._query:Matches("name", name)
	end
	if group then
		self._query:InTable("groupPath", group)
	end
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerInventoryScrollTable.__private:_HandleQueryUpdate()
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		self._createGroupsData[row:GetField("levelItemString")] = L["Ledger"].." - "..L["Inventory"]
	end
	self:_UpdateDataDeferredLoading(self._query:Count())
end

function LedgerInventoryScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local dbRow = self._query:GetNthResult(dataIndex)
	local levelItemString, totalQuantity, bagQuantity, totalBankQuantity, mailQuantity, altQuantity, guildQuantity, auctionQuantity, totalValue = dbRow:GetFields("levelItemString", "totalQuantity", "bagQuantity", "totalBankQuantity", "mailQuantity", "altQuantity", "guildQuantity", "auctionQuantity", "totalValue")
	self._data.item[dataIndex] = Theme.GetItemIconLink(ItemInfo.GetTexture(levelItemString) or "Interface\\Icons\\INV_Misc_QuestionMark").." "..(UIUtils.GetDisplayItemName(levelItemString) or "?")
	self._data.item_tooltip[dataIndex] = levelItemString
	self._data.totalItems[dataIndex] = totalQuantity
	self._data.bags[dataIndex] = bagQuantity
	self._data.banks[dataIndex] = totalBankQuantity
	self._data.mail[dataIndex] = mailQuantity
	self._data.alts[dataIndex] = altQuantity
	self._data.guildVault[dataIndex] = guildQuantity
	self._data.auctionHouse[dataIndex] = auctionQuantity
	self._data.totalValue[dataIndex] = Math.IsNan(totalValue) and "" or Money.ToStringForUI(totalValue)
end

---@param row ListRow
function LedgerInventoryScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local dbRow = self._query:GetNthResult(dataIndex)
	if self._onItemRowClick then
		self:_onItemRowClick(dbRow:GetField("itemString"))
	end
end

function LedgerInventoryScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
