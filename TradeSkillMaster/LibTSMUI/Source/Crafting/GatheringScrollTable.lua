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
	name = {
		title = NAME,
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "name",
	},
	sources = {
		title = L["Sources"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "sourcesStr",
	},
	have = {
		title = L["Have"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "numHave",
	},
	need = {
		title = NEED,
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "numNeed",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local GatheringScrollTable = UIElements.Define("GatheringScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GatheringScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "name_tooltip"
	self._query = nil
end

function GatheringScrollTable:Release()
	local query = self._query
	self._query = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return GatheringScrollTable
function GatheringScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	local settingsValue = self._settings[self._settingsKey]
	query
		:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_DrawSortFlag()
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function GatheringScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, row in self._query:Iterator() do
		local itemString, name, sourcesDisplayStr, numHave, numNeed = row:GetFields("itemString", "name", "sourcesDisplayStr", "numHave", "numNeed")
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
		tinsert(self._data.sources, sourcesDisplayStr)
		tinsert(self._data.have, numHave)
		tinsert(self._data.need, numNeed)
	end
	self:_SetNumRows(#self._data.name)
	self:Draw()
end

function GatheringScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
