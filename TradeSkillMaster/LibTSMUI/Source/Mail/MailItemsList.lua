-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local ROW_HEIGHT = 20



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailItemsList = UIElements.Define("MailItemsList", "List")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function MailItemsList:__init()
	self.__super:__init()
	self._query = nil
	self._text = {}
	self._tooltipData = {}
	self._index = {}
	self._itemIndex = {}
	self._onItemClick = nil
end

function MailItemsList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function MailItemsList:Release()
	self._query = nil
	wipe(self._text)
	wipe(self._tooltipData)
	wipe(self._index)
	wipe(self._itemIndex)
	self._onItemClick = nil
	self.__super:Release()
end

---Sets the query used to populate the list.
---@param query DatabaseQuery The query object
---@return MailItemsList
function MailItemsList:SetQuery(query)
	assert(not self._query)
	self._query = query
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Registers a script handler.
---@param script "OnItemClick" The script to register for
---@param handler fun(list: MailItemsList, ...) The script handler which will be passed any arguments to the script
---@return MailItemsList
function MailItemsList:SetScript(script, handler)
	if script == "OnItemClick" then
		self._onItemClick = handler
	else
		error("Unknown MailItemsList script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MailItemsList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._text)
	wipe(self._tooltipData)
	wipe(self._index)
	wipe(self._itemIndex)
	for _, row in self._query:Iterator() do
		local itemIndex, itemLink, quantity, index = row:GetFields("itemIndex", "itemLink", "quantity", "index")
		if itemIndex == 0 then
			tinsert(self._text, L["Gold"]..": "..Money.ToStringExact(itemLink, Theme.GetColor("FEEDBACK_GREEN"):GetTextColorPrefix()))
			tinsert(self._tooltipData, false)
		else
			local texture = ItemInfo.GetTexture(itemLink) or "Interface\\Icons\\INV_Misc_QuestionMark"
			local coloredItem = "|T"..texture..":0|t "..(UIUtils.GetDisplayItemName(itemLink) or "?")
			if quantity and quantity > 1 then
				coloredItem = coloredItem..Theme.GetColor("FEEDBACK_YELLOW"):ColorText(" (x"..quantity..")")
			end
			tinsert(self._text, coloredItem)
			tinsert(self._tooltipData, itemLink)
		end
		tinsert(self._index, index)
		tinsert(self._itemIndex, itemIndex)
	end
	self:_SetNumRows(#self._text)
	self:Draw()
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("ITEM_BODY3")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("text"):SetText(self._text[dataIndex])
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowEnter(row)
	local data = self._tooltipData[row:GetDataIndex()]
	if not data then
		return
	end
	row:ShowTooltip(data)
end

function MailItemsList.__protected:_HandleRowLeave(row)
	-- The data might not exist anymore, so just hide the tooltip to be safe
	Tooltip.Hide()
end

---@param row ListRow
function MailItemsList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	if self._onItemClick then
		self:_onItemClick(self._index[dataIndex], self._itemIndex[dataIndex])
	end
end
