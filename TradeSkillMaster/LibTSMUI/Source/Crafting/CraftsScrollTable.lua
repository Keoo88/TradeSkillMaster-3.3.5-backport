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
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	queued = {
		titleIcon = "iconPack.18x18/Queue",
		justifyH = "CENTER",
		font = "TABLE_TABLE1",
		sortField = "num",
	},
	craftName = {
		title = NAME,
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "itemName",
	},
	operation = {
		title = L["Operation"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "firstOperation",
	},
	bags = {
		title = L["Bag"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "bagQuantity",
	},
	ah = {
		title = L["AH"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "auctionQuantity",
	},
	craftingCost = {
		title = L["Crafting Cost"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "craftingCost",
	},
	itemValue = {
		title = L["Item Value"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "itemValue",
	},
	profit = {
		title = L["Profit"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "profit",
	},
	profitPct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "profitPct",
	},
	saleRate = {
		titleIcon = "iconPack.18x18/SaleRate",
		justifyH = "CENTER",
		font = "TABLE_TABLE1",
		sortField = "saleRate",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftsScrollTable = UIElements.Define("CraftsScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "craftName_tooltip"
	self._query = nil
	self._onCraftQueueChangeHandler = nil
end

function CraftsScrollTable:Release()
	local query = self._query
	self._query = nil
	self._onCraftQueueChangeHandler = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return CraftsScrollTable
function CraftsScrollTable:SetQuery(query)
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
---@param name? string Item name filter
---@param profession? string Profession filter (must be passed along with `player`)
---@param player? string Player filter (must be passed along with `profession`)
---@param craftableFilterFunc? fun(craftString: string): boolean Craftable filter function
function CraftsScrollTable:SetFilters(name, profession, player, craftableFilterFunc)
	self._query:ResetFilters()
	if name then
		self._query:Matches("itemName", name)
	end
	if profession then
		assert(player)
		self._query:Equal("profession", profession)
		self._query:ListContains("players", player)
	else
		assert(not player)
	end
	if craftableFilterFunc then
		self._query:Function("craftString", craftableFilterFunc)
	end
	self:_HandleQueryUpdate()
end

---Registers a script handler.
---@param script "OnCraftQueueChange" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return CraftsScrollTable
function CraftsScrollTable:SetScript(script, handler)
	if script == "OnCraftQueueChange" then
		self._onCraftQueueChangeHandler = handler
	else
		error("Unknown CraftsScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function CraftsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		local num, itemString, name, firstOperation, bagQuantity, auctionQuantity, profession = row:GetFields("num", "itemString", "name", "firstOperation", "bagQuantity", "auctionQuantity", "profession")
		tinsert(self._data.queued, num)
		-- 3.3.5: ItemInfo.GetTexture может быть nil (async cache); GetItemIcon синхронный fallback
		local texture = ItemInfo.GetTexture(itemString)
		if not texture then
			local itemId = tonumber(strmatch(itemString or "", "i:(%d+)"))
			if itemId and _G.GetItemIcon then
				texture = _G.GetItemIcon(itemId)
			end
		end
		tinsert(self._data.craftName, "|T"..(texture or "Interface\\Icons\\INV_Misc_QuestionMark")..":0|t "..(UIUtils.GetDisplayItemName(itemString) or name))
		tinsert(self._data.craftName_tooltip, itemString)
		tinsert(self._data.operation, firstOperation)
		tinsert(self._data.bags, bagQuantity or "0")
		tinsert(self._data.ah, auctionQuantity or "0")
		tinsert(self._data.craftingCost, self.DEFERRED_DATA)
		tinsert(self._data.itemValue, self.DEFERRED_DATA)
		tinsert(self._data.profit, self.DEFERRED_DATA)
		tinsert(self._data.profitPct, self.DEFERRED_DATA)
		tinsert(self._data.saleRate, self.DEFERRED_DATA)
		self._createGroupsData[itemString] = Group.JoinPath(L["Crafted Items"], profession)
	end
	self:_SetNumRows(#self._data.queued)
	self:Draw()
end

function CraftsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local craftingCost, itemValue, profit, profitPct, saleRate = self._query:GetNthResult(dataIndex):GetFields("craftingCost", "itemValue", "profit", "profitPct", "saleRate")
	self._data.craftingCost[dataIndex] = Math.IsNan(craftingCost) and "" or Money.ToStringForUI(craftingCost)
	self._data.itemValue[dataIndex] = Math.IsNan(itemValue) and "" or Money.ToStringForUI(itemValue)
	self._data.profit[dataIndex] = Math.IsNan(profit) and "" or Money.ToStringForUI(profit, Theme.GetColor(profit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"):GetTextColorPrefix())
	self._data.profitPct[dataIndex] = Math.IsNan(profitPct) and "" or Theme.GetColor(profitPct >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"):ColorText(profitPct.."%")
	self._data.saleRate[dataIndex] = Math.IsNan(saleRate) and "" or format("%0.2f", saleRate)
end

---@param row ListRow
function CraftsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if not self._onCraftQueueChangeHandler then
		return
	end
	local dataIndex = row:GetDataIndex()
	local craftString = self._query:GetNthResult(dataIndex):GetField("craftString")
	if mouseButton == "LeftButton" then
		self:_onCraftQueueChangeHandler(craftString, 1)
	elseif mouseButton == "RightButton" then
		self:_onCraftQueueChangeHandler(craftString, -1)
	end
end

function CraftsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
