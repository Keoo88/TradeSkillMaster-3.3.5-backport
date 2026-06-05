-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local COL_INFO = {
	activityType = {
		title = L["Activity Type"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "type",
	},
	source = {
		title = L["Source"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "source",
	},
	buyerSeller = {
		title = L["Buyer/Seller"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "otherPlayer",
	},
	qty = {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "quantity",
	},
	perItem = {
		title = L["Per Item"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "price",
	},
	totalPrice = {
		title = L["Total Price"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "totalPrice",
	},
	time = {
		title = L["Time Frame"],
		justifyH = "RIGHT",
		font = "BODY_BODY3",
		sortField = "time",
	},
}
local ACTIVITY_TYPE_LOOKUP = {
	sale = L["Sale"],
	buy = L["Buy"],
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local LedgerDetailScrollTable = UIElements.Define("LedgerDetailScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function LedgerDetailScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil
	self._deleteValidateFunc = nil
	self._deleteFunc = nil
end

function LedgerDetailScrollTable:Release()
	local query = self._query
	self._query = nil
	self._deleteValidateFunc = nil
	self._deleteFunc = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return LedgerDetailScrollTable
function LedgerDetailScrollTable:SetQuery(query)
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

---Sets functions to use to delete records.
---@param validateFunc fun(uuid: number): boolean Function to check if a DB entry can be deleted
---@param deleteFunc fun(uuid: number) Function to delete a DB entry
---@return LedgerDetailScrollTable
function LedgerDetailScrollTable:SetDeleteFunctions(validateFunc, deleteFunc)
	self._deleteValidateFunc = validateFunc
	self._deleteFunc = deleteFunc
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LedgerDetailScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, row in self._query:Iterator() do
		local recordType, source, otherPlayer, quantity, price, totalPrice, recordTime = row:GetFields("type", "source", "otherPlayer", "quantity", "price", "totalPrice", "time")
		local activityType = ACTIVITY_TYPE_LOOKUP[recordType]
		assert(activityType)
		tinsert(self._data.activityType, activityType)
		tinsert(self._data.source, source)
		tinsert(self._data.buyerSeller, otherPlayer)
		tinsert(self._data.qty, quantity)
		tinsert(self._data.perItem, Money.ToStringForUI(price))
		tinsert(self._data.totalPrice, Money.ToStringForUI(totalPrice))
		tinsert(self._data.time, SecondsToTime(LibTSMUI.GetTime() - recordTime))
	end
	self:_SetNumRows(#self._data.activityType)
	self:Draw()
end

---@param row ListRow
function LedgerDetailScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end

	local dbRow = self._query:GetNthResult(row:GetDataIndex())
	local uuid = dbRow:GetUUID()
	if not self._deleteValidateFunc(uuid) then
		ChatMessage.PrintUser(L["This record belongs to another account and can only be deleted on that account."])
		return
	end

	local subtitle = nil
	local recordType, itemString, quantity, otherPlayer, price = dbRow:GetFields("type", "itemString", "quantity", "otherPlayer", "price")
	local name = UIUtils.GetDisplayItemName(itemString) or "?"
	local amount = Money.ToStringForUI(price * quantity)
	if recordType == "sale" then
		subtitle = format(L["Sold %d of %s to %s for %s"], quantity, name, otherPlayer, amount)
	elseif recordType == "buy" then
		subtitle = format(L["Bought %d of %s from %s for %s"], quantity, name, otherPlayer, amount)
	else
		error("Unexpected Type: "..tostring(recordType))
	end
	self:GetBaseElement():ShowConfirmationDialog(L["Delete Record?"], subtitle, self._deleteFunc, uuid)
end

function LedgerDetailScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	local settingsValue = self._settings[self._settingsKey]
	self._query:ResetOrderBy()
		:OrderBy(COL_INFO[settingsValue.sortCol].sortField, settingsValue.sortAscending)
	self:_HandleQueryUpdate()
end
