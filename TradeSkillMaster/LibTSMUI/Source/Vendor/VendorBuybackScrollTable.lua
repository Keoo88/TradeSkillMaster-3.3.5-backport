
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
	qty = {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "quantity",
	},
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableTooltipLinking = true,
		disableHiding = true,
		sortField = "name",
	},
	cost = {
		title = L["Cost"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "price",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorBuybackScrollTable = UIElements.Define("VendorBuybackScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorBuybackScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._onBuyback = nil
end

function VendorBuybackScrollTable:Release()
	local query = self._query
	self._query = nil
	self._onBuyback = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return VendorBuybackScrollTable
function VendorBuybackScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self._settings[self._settingsKey]
	query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_DrawSortFlag()
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Registers a script handler.
---@param script "OnBuyback" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return VendorBuybackScrollTable
function VendorBuybackScrollTable:SetScript(script, handler)
	if script == "OnBuyback" then
		self._onBuyback = handler
	else
		error("Unknown VendorBuybackScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function VendorBuybackScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		local quantity, itemString, price = row:GetFields("quantity", "itemString", "price")
		tinsert(self._data.qty, quantity)
		tinsert(self._data.item, "|T"..ItemInfo.GetTexture(itemString)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.cost, Money.ToStringForUI(price))
		self._createGroupsData[itemString] = L["Vendoring"].." - "..L["Buyback"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function VendorBuybackScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local index = self._query:GetNthResult(dataIndex):GetField("index")
	if self._onBuyback then
		self:_onBuyback(index)
	end
end

function VendorBuybackScrollTable.__protected:_HandleRowEnter()
	SetCursor("BUY_CURSOR")
end

function VendorBuybackScrollTable.__protected:_HandleRowLeave()
	SetCursor(nil)
end

function VendorBuybackScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
