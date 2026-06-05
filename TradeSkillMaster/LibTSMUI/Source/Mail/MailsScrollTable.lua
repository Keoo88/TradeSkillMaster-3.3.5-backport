
-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local Inbox = LibTSMUI:From("LibTSMWoW"):Include("API.Inbox")
local Mail = LibTSMUI:From("LibTSMService"):Include("Mail")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Database = LibTSMUI:From("LibTSMUtil"):Include("Database")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local AUCTION_SOLD_PATTERN_STR = String.FormatToMatchPattern(AUCTION_SOLD_MAIL_SUBJECT)
local COL_INFO = {
	items = {
		title = L["Items"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableTooltipLinking = true,
		disableHiding = true,
	},
	sender = {
		title = L["Sender"],
		justifyH = "LEFT",
		font = "BODY_BODY3",
	},
	expires = {
		title = L["Expires"],
		justifyH = "RIGHT",
		font = "BODY_BODY3_MEDIUM",
	},
	money = {
		title = L["Gold"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailsScrollTable = UIElements.Define("MailsScrollTable", "ScrollTable")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MailsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "items_tooltip"
	self._query = nil
	self._filter = nil
	self._onRowClick = nil
end

function MailsScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
	self._itemsQuery = Mail.NewItemQuery()
		:Equal("index", Database.BoundQueryParam())
		:GreaterThan("itemIndex", 0)
		:OrderBy("itemIndex", true)
end

function MailsScrollTable:Release()
	self._query = nil
	self._filter = nil
	self._itemsQuery:Release()
	self._itemsQuery = nil
	self._onRowClick = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return MailsScrollTable
function MailsScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	query:ResetFilters()
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Sets the filters.
---@param text? string Text filter
---@return MailsScrollTable
function MailsScrollTable:SetFilters(text)
	if text == self._filter then
		return self
	end
	self._query:ResetFilters()
	if text then
		self._query
			:Or()
				:Matches("itemList", text)
				:Matches("subject", text)
			:End()
	end
	self._filter = text
	self:_HandleQueryUpdate()
	return self
end

---Registers a script handler.
---@param script "OnRowClick" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return MailsScrollTable
function MailsScrollTable:SetScript(script, handler)
	if script == "OnRowClick" then
		self._onRowClick = handler
	else
		error("Unknown MailsScrollTable script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MailsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._actionIcon)
	for _, row in self._query:Iterator() do
		local itemString, sender, mailType = row:GetFields("itemString", "sender", "type")
		tinsert(self._data.items, self.DEFERRED_DATA)
		tinsert(self._data.items_tooltip, itemString)
		tinsert(self._data.sender, sender == "" and UNKNOWN or sender)
		tinsert(self._data.expires, self.DEFERRED_DATA)
		tinsert(self._data.money, self.DEFERRED_DATA)
		if mailType == Inbox.MAIL_TYPE.SALE then
			tinsert(self._actionIcon, "iconPack.12x12/Bid")
		elseif mailType == Inbox.MAIL_TYPE.BUY then
			tinsert(self._actionIcon, "iconPack.12x12/Shopping")
		elseif mailType == Inbox.MAIL_TYPE.CANCEL then
			tinsert(self._actionIcon, "iconPack.12x12/Close/Circle")
		elseif mailType == Inbox.MAIL_TYPE.EXPIRE then
			tinsert(self._actionIcon, "iconPack.12x12/Clock")
		elseif mailType == Inbox.MAIL_TYPE.OTHER then
			tinsert(self._actionIcon, "iconPack.12x12/Mailing")
		else
			tinsert(self._actionIcon, false)
		end
	end
	self:_SetNumRows(#self._data.items)
	self:Draw()
end

function MailsScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local dbRow = self._query:GetNthResult(dataIndex)
	local index, subject, expires, money, cost = dbRow:GetFields("index", "subject", "expires", "money", "cost")
	self._data.items[dataIndex] = self:_GetItemsText(index, subject)
	if expires >= 1 then
		self._data.expires[dataIndex] = Theme.GetColor(expires <= 5 and "FEEDBACK_YELLOW" or "FEEDBACK_GREEN"):ColorText(floor(expires).." "..DAYS)
	else
		local hoursLeft = expires * 24
		if hoursLeft >= 1 then
			expires = floor(hoursLeft).." "..HOURS
		else
			expires = floor(hoursLeft / 60).." "..MINUTES
		end
		self._data.expires[dataIndex] = Theme.GetColor("FEEDBACK_RED"):ColorText(expires)
	end
	local gold = nil
	if cost > 0 then
		gold = Money.ToStringForUI(cost, Theme.GetColor("FEEDBACK_RED"):GetTextColorPrefix())
	elseif money > 0 then
		gold = Money.ToStringForUI(money, Theme.GetColor("FEEDBACK_GREEN"):GetTextColorPrefix())
	end
	self._data.money[dataIndex] = gold or "---"
end

function MailsScrollTable.__protected:_GetItemsText(index, subject)
	local items = ""
	local item = nil
	local same = true
	local qty = 0
	self._itemsQuery:BindParams(index)
	for _, itemsRow in self._itemsQuery:Iterator() do
		local coloredItem = UIUtils.GetDisplayItemName(itemsRow:GetField("itemLink")) or ""
		local quantity = itemsRow:GetField("quantity")

		if not item then
			item = coloredItem
		end

		if quantity > 1 then
			items = items..coloredItem..Theme.GetColor("FEEDBACK_YELLOW"):ColorText(" (x"..quantity..")")..", "
		else
			items = items..coloredItem..", "
		end

		if item == coloredItem then
			qty = qty + quantity
		else
			same = false
		end
	end
	items = strtrim(items, ", ")

	if same and item then
		if qty > 1 then
			items = item..Theme.GetColor("FEEDBACK_YELLOW"):ColorText(" (x"..qty..")")
		else
			items = item
		end
	end

	if not items or items == "" then
		if subject ~= "" then
			local soldItem = strmatch(subject, AUCTION_SOLD_PATTERN_STR)
			items = soldItem or subject
		else
			items = Inbox.GetHeaderInfo(index) or UNKNOWN
		end
	end

	return items
end

---@param row ListRow
function MailsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local index = self._query:GetNthResult(dataIndex):GetField("index")
	if self._onRowClick then
		self:_onRowClick(index)
	end
end
