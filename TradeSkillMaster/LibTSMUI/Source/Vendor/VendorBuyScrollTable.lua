-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local VendorUIUtils = LibTSMUI:Include("Vendor.VendorUIUtils")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Vendor = LibTSMUI:From("LibTSMService"):Include("Vendor")
local COL_INFO = {
	qty = {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "stackSize",
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
	ilvl = {
		title = L["ilvl"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "itemLevel",
	},
	cost = {
		title = L["Cost"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		hasTooltip = true,
		disableTooltipLinking = true,
		sortField = "price",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorBuyScrollTable = UIElements.Define("VendorBuyScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorBuyScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
end

function VendorBuyScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return VendorBuyScrollTable
function VendorBuyScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self._settings[self._settingsKey]
	query
		:ResetFilters()
		:NotEqual("numAvailable", 0)
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
---@return VendorBuyScrollTable
function VendorBuyScrollTable:SetFilters(name)
	self._query:ResetFilters()
		:NotEqual("numAvailable", 0)
	if name then
		self._query:Matches("name", name)
	end
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function VendorBuyScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		local stackSize, itemString, numAvailable, itemLevel, index = row:GetFields("stackSize", "itemString", "numAvailable", "itemLevel", "index")
		tinsert(self._data.qty, stackSize)
		-- 3.3.5: ItemInfo cache часто пуст для свежих vendor предметов (GetItemInfo async).
		-- Fallback: _G.GetItemIcon(itemId) возвращает icon path синхронно даже если предмет
		-- ещё не закеширован клиентом.
		local texture = ItemInfo.GetTexture(itemString)
		if not texture then
			local itemId = tonumber(strmatch(itemString or "", "i:(%d+)"))
			if itemId and _G.GetItemIcon then
				texture = _G.GetItemIcon(itemId)
			end
		end
		texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
		local itemText = Theme.GetItemIconLink(texture).." "..(UIUtils.GetDisplayItemName(itemString) or "?")
		if numAvailable > 0 then
			itemText = itemText..Theme.GetColor("FEEDBACK_RED"):ColorText(" ("..numAvailable..")")
		elseif numAvailable ~= -1 then
			error("Invalid numAvailable: "..numAvailable)
		end
		tinsert(self._data.item, itemText)
		tinsert(self._data.item_tooltip, itemString)
		tinsert(self._data.ilvl, itemLevel == -1 and "" or itemLevel)
		tinsert(self._data.cost, VendorUIUtils.GetAltCostText(index, 1))
		tinsert(self._data.cost_tooltip, row:GetField("costItems") or false)
		self._createGroupsData[itemString] = L["Vendoring"].." - "..L["Buy"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

---@param row ListRow
function VendorBuyScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local dbRow = self._query:GetNthResult(dataIndex)
	if IsShiftKeyDown() then
		local itemString, index = dbRow:GetFields("itemString", "index")
		local firstCostItem = dbRow:GetField("costItems")
		local dialogFrame = UIElements.New("VendorQuantityDialog", "dialog")
			:Configure(index, itemString, firstCostItem)
		self:GetBaseElement():ShowDialogFrame(dialogFrame)
		dialogFrame:GetElement("qty.input"):SetFocused(true)
	elseif mouseButton == "RightButton" then
		Vendor.BuyIndex(dbRow:GetFields("index", "stackSize", "itemString"))
	else
		return
	end
end

function VendorBuyScrollTable.__protected:_HandleRowEnter()
	SetCursor("BUY_CURSOR")
end

function VendorBuyScrollTable.__protected:_HandleRowLeave()
	SetCursor(nil)
end

function VendorBuyScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
