
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
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 22
local HEADER_LINE_HEIGHT = 2
local HEADER_LINE_WIDTH = 2
local QUANTITY_COL_WIDTH = 60



-- ============================================================================
-- Element Definition
-- ============================================================================

local SendItemsList = UIElements.Define("SendItemsList", "List")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SendItemsList:__init()
	self.__super:__init()

	local header = self:_CreateFrame(self._hContent)
	self._header = header
	header:SetPoint("TOPLEFT", 0, -HEADER_LINE_HEIGHT)
	header:SetPoint("TOPRIGHT", 0, -HEADER_LINE_HEIGHT)
	header:SetHeight(HEADER_HEIGHT)

	local lineTop = self:_CreateTexture(self._hContent)
	self._lineTop = lineTop
	lineTop:SetPoint("BOTTOMLEFT", header, "TOPLEFT")
	lineTop:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT")
	lineTop:SetHeight(HEADER_LINE_HEIGHT)

	local lineBottom = self:_CreateTexture(self._hContent)
	self._lineBottom = lineBottom
	lineBottom:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	lineBottom:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
	lineBottom:SetHeight(HEADER_LINE_HEIGHT)

	self._vScrollFrame:SetPoint("TOPLEFT", lineBottom, "BOTTOMLEFT")
	self._vScrollbar:SetPoint("TOPRIGHT", -Theme.GetScrollbarMargin(), -Theme.GetScrollbarMargin() - HEADER_HEIGHT - HEADER_LINE_HEIGHT * 2)

	local colSpacing = Theme.GetColSpacing()

	local itemCell = self:_CreateHeaderCell(L["Items"])
	local quantityCell = self:_CreateHeaderCell(L["Amount"])
	self._header.item = itemCell
	self._header.quantity = quantityCell
	quantityCell:SetPoint("RIGHT", -colSpacing / 2, 0)
	quantityCell:SetWidth(QUANTITY_COL_WIDTH)
	itemCell:SetPoint("LEFT", colSpacing / 2, 0)
	itemCell:SetPoint("RIGHT", quantityCell, "LEFT", -colSpacing, 0)

	self._data = {
		item = {},
		itemTooltip = {},
		quantity = {},
	}
	self._query = nil
	self._onRemoveItem = nil
end

function SendItemsList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
	self._lineBottom:TSMSubscribeColorTexture("ACTIVE_BG")
	self._lineTop:TSMSubscribeColorTexture("ACTIVE_BG")
	self._header:TSMSubscribeBackdropColor("FRAME_BG")
	self._header.item.sepIcon:TSMSubscribeColorTexture("ACTIVE_BG")
	self._header.quantity.sepIcon:TSMSubscribeColorTexture("ACTIVE_BG")
end

function SendItemsList:Release()
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	self._query = nil
	self._onRemoveItem = nil
	self.__super:Release()
end

---Sets the query used to populate the table.
---@param query DatabaseQuery The query object
---@return SendItemsList
function SendItemsList:SetQuery(query)
	assert(query and not self._query)
	self._query = query
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Registers a script handler.
---@param script "OnRemoveItem" The script to register for
---@param handler function The script handler which will be called with the scrolling table followed by any arguments
---@return SendItemsList
function SendItemsList:SetScript(script, handler)
	if script == "OnRemoveItem" then
		self._onRemoveItem = handler
	else
		error("Unknown SendItemsList script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SendItemsList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	for _, row in self._query:Iterator() do
		local itemString, quantity = row:GetFields("itemString", "quantity")
		tinsert(self._data.item, Theme.GetItemIconLink(ItemInfo.GetTexture(itemString) or "Interface\\Icons\\INV_Misc_QuestionMark").." "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._data.itemTooltip, itemString)
		tinsert(self._data.quantity, quantity)
	end
	self:_SetNumRows(#self._data.item)
	self:Draw()
end

function SendItemsList.__private:_CreateHeaderCell(title)
	local colSpacing = Theme.GetColSpacing()
	local cell = self:_CreateButton(self._header)
	cell:SetHeight(HEADER_HEIGHT)

	local sepIcon = self:_CreateTexture(cell, "BORDER")
	cell.sepIcon = sepIcon
	sepIcon:SetWidth(HEADER_LINE_WIDTH)
	sepIcon:SetPoint("TOP", cell, "TOPRIGHT", colSpacing / 2, 0)
	sepIcon:SetPoint("BOTTOM", cell, "BOTTOMRIGHT", colSpacing / 2, 0)

	local text = self:_CreateFontString(cell)
	cell.titleText = text
	text:SetAllPoints(cell)
	text:TSMSetFont("BODY_BODY3_MEDIUM")
	text:SetJustifyH("LEFT")
	text:SetText(title)

	return cell
end

---@param row ListRow
function SendItemsList.__protected:_HandleRowAcquired(row)
	local item = row:AddText("item")
	item:SetHeight(ROW_HEIGHT)
	item:TSMSetFont("ITEM_BODY3")
	item:SetJustifyH("LEFT")
	row:AddTooltipRegion("itemTooltip", item, self:__closure("_GetRowTooltip"))

	local quantity = row:AddText("quantity")
	quantity:SetHeight(ROW_HEIGHT)
	quantity:TSMSetFont("TABLE_TABLE1")
	quantity:SetJustifyH("RIGHT")

	local colSpacing = Theme.GetColSpacing()
	quantity:SetPoint("RIGHT", -colSpacing / 2, 0)
	quantity:SetWidth(QUANTITY_COL_WIDTH)
	item:SetPoint("LEFT", colSpacing / 2, 0)
	item:SetPoint("RIGHT", quantity, "LEFT", -colSpacing, 0)
end

---@param row ListRow
function SendItemsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("item"):SetText(self._data.item[dataIndex])
	row:GetText("quantity"):SetText(self._data.quantity[dataIndex])
end

function SendItemsList.__private:_GetRowTooltip(dataIndex, key)
	if key ~= "itemTooltip" then
		error("Invalid tooltip key: "..tostring(key))
	end
	return self._data.itemTooltip[dataIndex]
end

---@param row ListRow
function SendItemsList.__protected:_HandleRowClick(row, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local dataIndex = row:GetDataIndex()
	local dbRow = self._query:GetNthResult(dataIndex)
	if self._onRemoveItem then
		self:_onRemoveItem(dbRow)
	end
end
