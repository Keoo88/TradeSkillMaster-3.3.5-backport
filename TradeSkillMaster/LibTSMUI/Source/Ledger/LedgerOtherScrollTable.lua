-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	type = {
		title = TYPE,
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "type",
	},
	character = {
		title = CHARACTER,
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "player",
	},
	otherCharacter = {
		title = L["Other Character"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "otherPlayer",
	},
	amount = {
		title = L["Amount"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "amount",
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

local LedgerOtherScrollTable = UIElements.Define("LedgerOtherScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerOtherScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil
end

function LedgerOtherScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return LedgerOtherScrollTable
function LedgerOtherScrollTable:SetQuery(query)
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
---@param typeFilter? table Type filter
---@param player? table Player filter
---@param timeFilter? number Time filter
---@return LedgerOtherScrollTable
function LedgerOtherScrollTable:SetFilters(recordType, typeFilter, player, timeFilter)
	self._query:ResetFilters()
		:Equal("recordType", recordType)
	if typeFilter then
		self._query:InTable("type", typeFilter)
	end
	if player then
		self._query:InTable("player", player)
	end
	if timeFilter then
		self._query:GreaterThan("time", LibTSMUI.GetTime() - timeFilter)
	end
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerOtherScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, row in self._query:Iterator() do
		local typeStr, player, otherPlayer, amount, recordTime = row:GetFields("typeStr", "player", "otherPlayer", "amount", "time")
		tinsert(self._data.type, typeStr)
		tinsert(self._data.character, player)
		tinsert(self._data.otherCharacter, otherPlayer)
		tinsert(self._data.amount, Money.ToStringForUI(amount))
		tinsert(self._data.time, SecondsToTime(LibTSMUI.GetTime() - recordTime))
	end
	self:_SetNumRows(#self._data.type)
	self:Draw()
end

function LedgerOtherScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
