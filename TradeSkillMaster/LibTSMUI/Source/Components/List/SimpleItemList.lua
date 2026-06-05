-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ROW_HEIGHT = 20



-- ============================================================================
-- Element Definition
-- ============================================================================

local SimpleItemList = UIElements.Define("SimpleItemList", "List")
SimpleItemList:_AddActionScripts("OnItemClick")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function SimpleItemList:__init()
	self.__super:__init()
	self._query = nil
	self._text = {}
	self._itemString = {}
	self._onItemClick = nil
end

function SimpleItemList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function SimpleItemList:Release()
	local query = self._query
	self._query = nil
	wipe(self._text)
	wipe(self._itemString)
	self._onItemClick = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the query used to populate the list.
---@param query DatabaseQuery The query object
---@return SimpleItemList
function SimpleItemList:SetQuery(query)
	if self._query then
		self._query:Release()
	end
	self._query = query
	self:AddCancellable(query:Publisher()
		:MapToValue(query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Registers a script handler.
---@param script "OnItemClick" The script to register for
---@param handler fun(list: SimpleItemList, ...) The script handler which will be passed any arguments to the script
---@return SimpleItemList
function SimpleItemList:SetScript(script, handler)
	if script == "OnItemClick" then
		self._onItemClick = handler
	else
		error("Unknown SimpleItemList script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function SimpleItemList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._text)
	wipe(self._itemString)
	for _, row in self._query:Iterator() do
		local itemString = row:GetFields("itemString")
		tinsert(self._text, "|T"..(ItemInfo.GetTexture(itemString) or 0)..":0|t "..(UIUtils.GetDisplayItemName(itemString) or "?"))
		tinsert(self._itemString, itemString)
	end
	self:_SetNumRows(#self._text)
	self:Draw()
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("ITEM_BODY3")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	row:GetText("text"):SetText(self._text[dataIndex])
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	if self._onItemClick then
		self:_onItemClick(self._itemString[dataIndex])
	end
	self:_SendActionScript("OnItemClick", self._itemString[dataIndex])
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowEnter(row)
	local dataIndex = row:GetDataIndex()
	row:ShowTooltip(self._itemString[dataIndex])
end

---@param row ListRow
function SimpleItemList.__protected:_HandleRowLeave(row)
	-- TODO: Could this be handled by the ListRow code?
	Tooltip.Hide()
end
