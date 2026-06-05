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
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local SECONDS_PER_MIN = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MIN
local COL_INFO = {
	item = {
		title = L["Item Name"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		sortField = "itemName",
	},
	stackSize = {
		title = L["Qty"],
		justifyH = "CENTER",
		font = "TABLE_TABLE1",
		sortField = "stackSize",
	},
	timeLeft = {
		titleIcon = "iconPack.14x14/Clock",
		justifyH = "CENTER",
		font = "BODY_BODY3",
		sortField = "duration",
	},
	highBidder = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and {
		title = HIGH_BIDDER,
		justifyH = "LEFT",
		font = "BODY_BODY3",
	} or nil,
	group = {
		title = GROUP,
		justifyH = "LEFT",
		font = "BODY_BODY3",
		sortField = "group",
	},
	currentBid = {
		title = BID,
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "currentBid",
	},
	buyout = {
		title = BUYOUT,
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
		sortField = "buyout",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local MyAuctionsScrollTable = UIElements.Define("MyAuctionsScrollTable", "ScrollTable")
MyAuctionsScrollTable:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MyAuctionsScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._customSourceItemStringDataCol = "item_tooltip"
	self._query = nil
	self._data.auctionId = {}
	self._selectionSortValue = nil
	self._selectionAuctionId = nil
end

function MyAuctionsScrollTable:Release()
	local query = self._query
	self._query = nil
	self._selectionSortValue = nil
	self._selectionAuctionId = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets whether or not sorting is disabled.
---@param disabled boolean
---@return MyAuctionsScrollTable
function MyAuctionsScrollTable:SetSortingDisabled(disabled)
	assert(not self._query and not self._settings)
	assert(type(disabled) == "boolean")
	self._sortDisabled = disabled
	return self
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return MyAuctionsScrollTable
function MyAuctionsScrollTable:SetQuery(query)
	assert(self._settings)
	assert(query and not self._query)
	self._query = query
	query:ResetFilters()
	if not self._sortDisabled then
		query:ResetOrderBy()
			:OrderBy("isSold", false)
			:OrderBy(self:_GetSortField(), self:_GetSettingsValue().sortAscending)
			:OrderBy("auctionId", true)
		self:_DrawSortFlag()
	end
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Sets the filters.
---@param name? string Item name filter
---@param duration? number Duration filter
---@param groups table Group filter
---@param hasBid? boolean Show only auctions with or without a bid (nil to disable)
---@param soldOnly? boolean Show only sold auctions (false/nil to disable)
function MyAuctionsScrollTable:SetFilters(name, duration, groups, hasBid, soldOnly)
	self._query:ResetFilters()
	if name then
		self._query:Matches("itemName", name)
	end
	if duration then
		if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
			self._query:Equal("duration", duration)
		else
			if duration == 1 then
				self._query:LessThan("duration", LibTSMUI.GetTime() + (30 * SECONDS_PER_MIN))
			elseif duration == 2 then
				self._query:LessThan("duration", LibTSMUI.GetTime() + (2 * SECONDS_PER_HOUR))
			elseif duration == 3 then
				self._query:LessThanOrEqual("duration", LibTSMUI.GetTime() + (12 * SECONDS_PER_HOUR))
			else
				self._query:GreaterThan("duration", LibTSMUI.GetTime() + (12 * SECONDS_PER_HOUR))
			end
		end
	end
	if next(groups) then
		self._query:InTable("group", groups)
	end
	if hasBid ~= nil then
		if hasBid then
			self._query:NotEqual("highBidder", "")
		else
			self._query:Equal("highBidder", "")
		end
	end
	if soldOnly then
		self._query:Equal("isSold", true)
	end
	self:_HandleQueryUpdate()
end

---Sets the selected row.
---@param auctionId? number The auction ID of the row to select
---@return MyAuctionsScrollTable
function MyAuctionsScrollTable:SetSelectedAuction(auctionId)
	local dataIndex = auctionId and Table.KeyByValue(self._data.auctionId, auctionId) or nil
	local prevDataIndex = self._selectionAuctionId and Table.KeyByValue(self._data.auctionId, self._selectionAuctionId) or nil
	if auctionId == self._selectionAuctionId and (not auctionId or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	local dbRow = dataIndex and self._query:GetNthResult(dataIndex) or nil
	if dbRow and not dbRow:GetField("isSold") then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			newRow:SetSelected(true)
		end
		self._selectionSortValue = self:_GetSortValue(dbRow)
		self._selectionAuctionId = self._data.auctionId[dataIndex]
		self:_ScrollToRow(dataIndex)
	else
		self._selectionSortValue = nil
		self._selectionAuctionId = nil
	end

	self:_SendActionScript("OnSelectionChanged")
	return self
end

---Gets the selected row.
---@return number?
function MyAuctionsScrollTable:GetSelectedAuction()
	return self._selectionAuctionId
end

---Selects the next row.
---@return MyAuctionsScrollTable
function MyAuctionsScrollTable:SelectNextRow()
	local auctionId = nil
	local dataIndex = self._selectionAuctionId and Table.KeyByValue(self._data.auctionId, self._selectionAuctionId) or 0
	for i = dataIndex + 1, #self._data.auctionId do
		if not self._query:GetNthResult(i):GetField("isSold") then
			auctionId = self._data.auctionId[i]
			break
		end
	end
	self:SetSelectedAuction(auctionId)
	return self
end

---Gets the totals for the visible rows.
---@return number numPosted
---@return number numSold
---@return number postedGold
---@return number soldGold
function MyAuctionsScrollTable:GetTotals()
	local numPosted, numSold, postedGold, soldGold = 0, 0, 0, 0
	for _, row in self._query:Iterator() do
		local itemString, isSold, buyout, currentBid, stackSize = row:GetFields("itemString", "isSold", "buyout", "currentBid", "stackSize")
		if isSold then
			numSold = numSold + 1
			-- If somebody did a buyout, then bid will be equal to buyout, otherwise it'll be the winning bid
			soldGold = soldGold + currentBid
		else
			numPosted = numPosted + 1
			if ItemInfo.IsCommodity(itemString) then
				postedGold = postedGold + (buyout * stackSize)
			else
				postedGold = postedGold + buyout
			end
		end
	end
	return numPosted, numSold, postedGold, soldGold
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MyAuctionsScrollTable.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	wipe(self._createGroupsData)
	wipe(self._actionIcon)
	local sortAscending = self:_GetSettingsValue().sortAscending
	local hasExistingSelection, nextSelectionAuctionId = false, nil
	for _, row in self._query:Iterator() do
		local isSold, itemName, itemQuality, itemString, stackSize, duration, isPending, group, currentBid, highBidder, buyout, auctionId = row:GetFields("isSold", "itemName", "itemQuality", "itemString", "stackSize", "duration", "isPending", "group", "currentBid", "highBidder", "buyout", "auctionId")
		local itemTexturePrefix = "|T"..(ItemInfo.GetTexture(itemString) or "Interface\\Icons\\INV_Misc_QuestionMark")..":0|t "
		if isSold then
			local color = Theme.GetColor("INDICATOR")
			tinsert(self._data.item, itemTexturePrefix..color:ColorText(itemName))
			tinsert(self._data.stackSize, color:ColorText(stackSize))
			tinsert(self._data.currentBid, color:ColorText(L["Sold"]))
			tinsert(self._data.buyout, Money.ToStringForAH(currentBid))
		else
			tinsert(self._data.item, itemTexturePrefix..UIUtils.GetQualityColoredText(itemName, itemQuality))
			tinsert(self._data.stackSize, stackSize)
			local bidColor = (not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and highBidder ~= "" and Theme.GetColor("INDICATOR"):GetTextColorPrefix() or nil
			tinsert(self._data.currentBid, Money.ToStringForAH(currentBid, bidColor))
			tinsert(self._data.buyout, Money.ToStringForAH(buyout))
		end
		tinsert(self._actionIcon, isSold and "iconPack.12x12/Bid" or false)
		if self._data.highBidder then
			tinsert(self._data.highBidder, isSold and Theme.GetColor("INDICATOR"):ColorText(highBidder) or highBidder)
		end
		tinsert(self._data.item_tooltip, itemString)
		if not isSold and isPending then
			tinsert(self._data.timeLeft, "...")
		elseif isSold or (not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) then
			local timeLeft = floor(duration - LibTSMUI.GetTime())
			local timeLeftStr = nil
			if timeLeft < SECONDS_PER_MIN then
				timeLeftStr = format(L["%ds"], timeLeft)
			elseif timeLeft < SECONDS_PER_HOUR then
				timeLeftStr = format(L["%dm"], floor(timeLeft / SECONDS_PER_MIN))
			else
				timeLeftStr = format(L["%dh"], floor(timeLeft / SECONDS_PER_HOUR))
			end
			local timeLeftColor = nil
			if isSold then
				timeLeftColor = "INDICATOR"
			elseif timeLeft <= 2 * SECONDS_PER_HOUR then
				timeLeftColor = "FEEDBACK_RED"
			elseif timeLeft <= ((LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and 8 or 24) * SECONDS_PER_HOUR then
				timeLeftColor = "FEEDBACK_YELLOW"
			else
				timeLeftColor = "FEEDBACK_GREEN"
			end
			tinsert(self._data.timeLeft, Theme.GetColor(timeLeftColor):ColorText(timeLeftStr))
		else
			tinsert(self._data.timeLeft, UIUtils.GetTimeLeftString(duration))
		end
		local groupName = Group.GetName(group)
		tinsert(self._data.group, Theme.GetGroupColor(Group.GetLevel(group)):ColorText(groupName))
		tinsert(self._data.auctionId, auctionId)
		if self._selectionAuctionId and not isSold then
			if auctionId == self._selectionAuctionId then
				hasExistingSelection = true
			elseif not nextSelectionAuctionId then
				local sortValue = self:_GetSortValue(row)
				if not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic() and sortValue == self._selectionSortValue and auctionId > self._selectionAuctionId then
					nextSelectionAuctionId = auctionId
				elseif sortAscending then
					nextSelectionAuctionId = sortValue > self._selectionSortValue and auctionId or nil
				else
					nextSelectionAuctionId = sortValue < self._selectionSortValue and auctionId or nil
				end
			end
		end
		self._createGroupsData[itemString] = L["My Auctions"]
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()

	-- Update the selection if necessary
	if not hasExistingSelection then
		self:SetSelectedAuction(nextSelectionAuctionId)
	end
end

---@param row ListRow
function MyAuctionsScrollTable.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	self.__super:_HandleRowDraw(row)
	row:SetSelected(self._data.auctionId[dataIndex] == self._selectionAuctionId)
end

---@param row ListRow
function MyAuctionsScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local dataIndex = row:GetDataIndex()
	if self._query:GetNthResult(dataIndex):GetField("isSold") then
		return
	end
	self:SetSelectedAuction(self._data.auctionId[dataIndex])
end

function MyAuctionsScrollTable.__private:_GetSortField()
	if self._sortDisabled then
		return "index"
	end
	local field = COL_INFO[self:_GetSettingsValue().sortCol].sortField
	assert(field)
	return field
end

function MyAuctionsScrollTable.__private:_GetSortValue(dbRow)
	local value = dbRow:GetField(self:_GetSortField())
	if type(value) == "string" then
		value = strlower(value)
	end
	return value
end

function MyAuctionsScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if not self.__super:_HandleHeaderCellClick(button, mouseButton) then
		return
	end
	if self._selectionAuctionId then
		local selectionDataIndex = self._selectionAuctionId and Table.KeyByValue(self._data.auctionId, self._selectionAuctionId) or nil
		local dbRow = self._query:GetNthResult(selectionDataIndex)
		assert(not dbRow:GetField("isSold"))
		self._selectionSortValue = self:_GetSortValue(dbRow)
	end
	self._query:ResetOrderBy()
		:OrderBy("isSold", false)
		:OrderBy(self:_GetSortField(), self:_GetSettingsValue().sortAscending)
		:OrderBy("auctionId", true)
	self:_HandleQueryUpdate()
end
