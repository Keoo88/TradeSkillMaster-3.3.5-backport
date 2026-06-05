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
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	name = {
		title = NAME,
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	price = {
		title = L["Material Cost"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "matCost",
	},
	professions = {
		title = L["Professions Used In"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "professions",
	},
	num = {
		title = L["Number Owned"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "totalQuantity",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MatsScrollTable = UIElements.Define("MatsScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MatsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "name_tooltip"
	self._query = nil
	self._onRowClickHandler = nil
end

function MatsScrollTable:Release()
	local query = self._query
	self._query = nil
	self._onRowClickHandler = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return MatsScrollTable
function MatsScrollTable:SetQuery(query)
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
---@param profession? string Profession filter
---@param hasCustomValue? boolean Whether or not there is a custom value set
function MatsScrollTable:SetFilters(name, profession, hasCustomValue)
	self._query:ResetFilters()
	if name then
		self._query:Matches("name", name)
	end
	if profession then
		self._query
			:Or()
				:Equal("professions", profession)
				:Matches("professions", "^"..profession..",")
				:Matches("professions", ","..profession..",")
				:Matches("professions", ","..profession.."$")
			:End()
	end
	if hasCustomValue == true then
		self._query:NotEqual("customValue", "")
	elseif hasCustomValue == false then
		self._query:Equal("customValue", "")
	end
	self:_HandleQueryUpdate()
end

---Registers a script handler.
---@param script "OnRowClick" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return MatsScrollTable
function MatsScrollTable:SetScript(script, handler)
	if script == "OnRowClick" then
		self._onRowClickHandler = handler
	else
		error("Unknown MatsScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MatsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	for _, row in self._query:Iterator() do
		local itemString, name, professions, totalQuantity = row:GetFields("itemString", "name", "professions", "totalQuantity")
		-- 3.3.5: ItemInfo.GetTexture nil → GetItemIcon синхронный fallback
		local texture = ItemInfo.GetTexture(itemString)
		if not texture then
			local itemId = tonumber(strmatch(itemString or "", "i:(%d+)"))
			if itemId and _G.GetItemIcon then
				texture = _G.GetItemIcon(itemId)
			end
		end
		tinsert(self._data.name, "|T"..(texture or "Interface\\Icons\\INV_Misc_QuestionMark")..":0|t "..(UIUtils.GetDisplayItemName(itemString) or name))
		tinsert(self._data.name_tooltip, itemString)
		tinsert(self._data.price, self.DEFERRED_DATA)
		tinsert(self._data.professions, professions)
		tinsert(self._data.num, totalQuantity or "0")
		self._createGroupsData[itemString] = L["Materials"]
	end
	self:_SetNumRows(#self._data.name)
	self:Draw()
end

function MatsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local matCost = self._query:GetNthResult(dataIndex):GetField("matCost")
	self._data.price[dataIndex] = Math.IsNan(matCost) and "" or Money.ToStringForUI(matCost)
end

---@param row ListRow
function MatsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	local itemString = self._query:GetNthResult(dataIndex):GetField("itemString")
	if self._onRowClickHandler then
		self:_onRowClickHandler(itemString)
	end
end

function MatsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
