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
		disableTooltipLinking = true,
		disableHiding = true,
		sortField = "name",
	},
	vendorSell = {
		title = L["Vendor Sell"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "vendorSell",
	},
	potential = {
		title = L["Potential"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "potentialValue",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorSellScrollTable = UIElements.Define("VendorSellScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorSellScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._queryResetFiltersFunc = nil
	self._onIgnoreItem = nil
	self._onSellItem = nil
end

function VendorSellScrollTable:Release()
	self._query = nil
	self._queryResetFiltersFunc = nil
	self._onIgnoreItem = nil
	self._onSellItem = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@param resetFiltersFunc fun(query: DatabaseQuery) Function to reset the filters on the query
---@return VendorSellScrollTable
function VendorSellScrollTable:SetQuery(query, resetFiltersFunc)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	self._queryResetFiltersFunc = resetFiltersFunc
	local settingsValue = self._settings[self._settingsKey]
	resetFiltersFunc(query)
	query:ResetOrderBy()
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
---@return VendorSellScrollTable
function VendorSellScrollTable:SetFilters(name)
	self._queryResetFiltersFunc(self._query)
	if name then
		self._query:Matches("name", name)
	end
	self:_HandleQueryUpdate()
	return self
end

---Registers a script handler.
---@param script "OnIgnoreItem"|"OnSellItem" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return VendorSellScrollTable
function VendorSellScrollTable:SetScript(script, handler)
	if script == "OnIgnoreItem" then
		self._onIgnoreItem = handler
	elseif script == "OnSellItem" then
		self._onSellItem = handler
	else
		error("Unknown VendorSellScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function VendorSellScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		local itemString, vendorSell, potentialValue = row:GetFields("itemString", "vendorSell", "potentialValue")
		local texture = ItemInfo.GetTexture(itemString) or "Interface\\Icons\\INV_Misc_QuestionMark"
		local displayName = UIUtils.GetDisplayItemName(itemString) or "?"
		tinsert(self._data.item, Theme.GetItemIconLink(texture).." "..displayName)
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.vendorSell, vendorSell > 0 and Money.ToStringForUI(vendorSell) or "")
		tinsert(self._data.potential, Money.ToStringForUI(potentialValue))
		self._createGroupsData[itemString] = L["Vendoring"].." - "..L["Sell"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function VendorSellScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local itemString = self._query:GetNthResult(dataIndex):GetField("itemString")
	if mouseButton == "RightButton" then
		if self._onSellItem then
			self:_onSellItem(itemString)
		end
	else
		if self._onIgnoreItem then
			self:_onIgnoreItem(itemString, IsShiftKeyDown())
		end
	end
end

function VendorSellScrollTable.__protected:_HandleRowEnter()
	SetCursor("BUY_CURSOR")
end

function VendorSellScrollTable.__protected:_HandleRowLeave()
	SetCursor(nil)
end

function VendorSellScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
