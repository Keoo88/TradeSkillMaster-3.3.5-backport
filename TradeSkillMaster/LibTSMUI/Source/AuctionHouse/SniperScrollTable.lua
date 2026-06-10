-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local INDENT_WIDTH = 8
local ICON_SPACING = 4
local EXPANDER_TEXTURE_EXPANDED = "iconPack.12x12/Caret/Down"
local EXPANDER_TEXTURE_COLLAPSED = "iconPack.12x12/Caret/Right"
local RECENT_TEXTURE = "iconPack.14x14/Attention"
local REMOVE_TEXTURE = "iconPack.14x14/Close/Default"
local COL_INFO = {
	icon = {
		titleIcon = RECENT_TEXTURE,
		justifyH = "CENTER",
		font = "BODY_BODY3",
		disableHiding = true,
		disableReordering = true,
	},
	item = {
		title = L["Item"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		hasTooltip = true,
		disableHiding = true,
		disableReordering = true,
	},
	ilvl = {
		title = L["ilvl"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	qty = (not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and {
		title = L["Qty"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	} or nil,
	posts = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and {
		title = L["Posts"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	} or nil,
	stack = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and {
		title = L["Stack"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	} or nil,
	seller = {
		title = L["Seller"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
	},
	itemBid = {
		title = L["Bid (item)"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	bid = {
		title = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and L["Bid (total)"] or L["Bid (stack)"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	itemBuyout = {
		title = L["Buyout (item)"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	buyout = {
		title = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and L["Buyout (total)"] or L["Buyout (stack)"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	bidPct = {
		title = BID.." %",
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	pct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local SniperScrollTable = UIElements.Define("SniperScrollTable", "AuctionScrollTable")
SniperScrollTable:_AddActionScripts("OnRowRemoved")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SniperScrollTable:__init()
	self.__super:__init(COL_INFO)
	-- Store data for the timeLeft even though we don't have this column to reuse AuctionScrollTable code
	self._data.timeLeft = {}
	self._highestBrowseId = 0
end

function SniperScrollTable:Acquire()
	self.__super:Acquire()
	if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
		self._sortCol = "icon"
		self._sortAscending = true
	end
end

function SniperScrollTable:Release()
	self._highestBrowseId = 0
	self.__super:Release()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SniperScrollTable.__protected:_UpdateData(updatedScan, updatedQuery, updatedRow)
	self._highestBrowseId = 0
	if updatedRow then
		for _, subRow in updatedRow:SubRowIterator() do
			local _, _, browseId = subRow:GetListingInfo()
			self._highestBrowseId = max(self._highestBrowseId, browseId or 0)
		end
	else
		for _, query in self._auctionScan:QueryIterator() do
			for _, row in query:BrowseResultsIterator() do
				for _, subRow in row:SubRowIterator() do
					local _, _, browseId = subRow:GetListingInfo()
					self._highestBrowseId = max(self._highestBrowseId, browseId or 0)
				end
			end
		end
	end
	self.__super:_UpdateData(updatedScan, updatedQuery, updatedRow)
end

function SniperScrollTable.__protected:_SetDataForRow(index, row, isFirstSubRow)
	self.__super:_SetDataForRow(index, row, isFirstSubRow)
	local isRecent = true
	if row:IsSubRow() then
		local _, _, browseId = row:GetListingInfo()
		isRecent = self._highestBrowseId == browseId
	end
	self._data.icon[index] = TextureAtlas.GetTextureLink(isRecent and RECENT_TEXTURE or REMOVE_TEXTURE)
end

function SniperScrollTable.__protected:_GetSortValue(row, id, isAscending)
	if id == "icon" then
		if not row:IsSubRow() then
			return 0
		end
		local _, _, browseId = row:GetListingInfo()
		-- 3.3.5: browseId может быть nil (как в _UpdateData/_SetDataForRow) — без guard здесь был arithmetic-on-nil краш сортировки.
		return -(browseId or 0)
	else
		return self.__super:_GetSortValue(row, id, isAscending)
	end
end

---@param row ListRow
function SniperScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	local expander = row:GetTexture("expander")
	expander:TSMSetSize(EXPANDER_TEXTURE_EXPANDED)
	expander:ClearAllPoints()
	expander:SetPoint("LEFT", row:GetText("icon"), "RIGHT", Theme.GetColSpacing(), 0)
end

---@param row ListRow
function SniperScrollTable.__protected:_HandleRowDraw(row)
	self.__super.__super:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local data = self._rawData[dataIndex]
	local baseItemString = data:GetBaseItemString()
	local numSubRows = data:IsSubRow() and data:GetResultRow():GetNumSubRows() or 0
	local isExpanded = self._expanded[baseItemString]
	local itemWidthReduction = 0
	local itemText = row:GetText("item")
	local expander = row:GetTexture("expander")
	local badge = row:GetText("badge")
	local colSpacing = Theme.GetColSpacing()

	if isExpanded and not self:_IsFirstSubRow(dataIndex) then
		expander:Hide()
		itemText:SetPoint("LEFT", row:GetText("icon"), "RIGHT", colSpacing + expander:GetWidth() + ICON_SPACING + INDENT_WIDTH, 0)
		itemWidthReduction = itemWidthReduction + expander:GetWidth() + ICON_SPACING + INDENT_WIDTH
	else
		if numSubRows > 1 then
			expander:Show()
			expander:TSMSetTexture(isExpanded and EXPANDER_TEXTURE_EXPANDED or EXPANDER_TEXTURE_COLLAPSED)
			itemText:SetPoint("LEFT", expander, "RIGHT", ICON_SPACING, 0)
			itemWidthReduction = itemWidthReduction + expander:GetWidth() + ICON_SPACING
		else
			expander:Hide()
			itemText:SetPoint("LEFT", row:GetText("icon"), "RIGHT", colSpacing, 0)
		end
	end

	self:_DrawRunningIcon(row)

	if not isExpanded and numSubRows > 1 then
		badge:Show()
		badge:SetText(numSubRows > 999 and "(999+)" or "("..numSubRows..")")
		badge:SetPoint("LEFT", itemText, "RIGHT", ICON_SPACING, 0)
		local width = badge:TSMGetUnboundedStringWidth()
		badge:SetWidth(width)
		itemWidthReduction = itemWidthReduction + width + ICON_SPACING
		for _, colSettings in ipairs(self:_GetSettingsValue().cols) do
			local id = colSettings.id
			if id ~= "item" and id ~= "icon" and not colSettings.hidden then
				row:GetText(id):SetPoint("LEFT", badge, "RIGHT", colSpacing, 0)
				break
			end
		end
	else
		badge:Hide()
	end

	if itemWidthReduction > 0 then
		itemText:SetWidth(itemText:GetWidth() - itemWidthReduction)
	end

	row:SetSelected(data == self._selection)
end

---@param row ListRow
function SniperScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local data = self._rawData[row:GetDataIndex()]
	if row:GetText("icon"):IsMouseOver() then
		self:_SendActionScript("OnRowRemoved", data)
	else
		self.__super:_HandleRowClick(row, mouseButton)
	end
end

---@param row ListRow
function SniperScrollTable.__protected:_HandleRowDoubleClick(row, mouseButton)
	if row:GetText("icon"):IsMouseOver() then
		return
	end
	self.__super:_HandleRowDoubleClick(row, mouseButton)
end

---@param row ListRow
function SniperScrollTable.__protected:_HandleRowEnter(row)
	row:GetText("icon"):SetText(TextureAtlas.GetTextureLink(REMOVE_TEXTURE))
end

---@param row ListRow
function SniperScrollTable.__protected:_HandleRowLeave(row)
	local iconText = self._data.icon[row:GetDataIndex()]
	if not iconText then
		return
	end
	row:GetText("icon"):SetText(iconText)
end
