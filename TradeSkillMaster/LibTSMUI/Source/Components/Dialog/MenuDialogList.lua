-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local ROW_HEIGHT = 20



-- ============================================================================
-- Element Definition
-- ============================================================================

local MenuDialogList = UIElements.Define("MenuDialogList", "List")
MenuDialogList:_AddActionScripts("OnRowEnter", "OnRowClick", "OnRowsChanged", "OnRowDelete")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MenuDialogList:__init()
	self.__super:__init()
	self._ids = {}
	self._labels = {}
	self._hasChildren = {}
	self._data = nil
	self._parentId = nil
	self._dataUpdatePaused = 0
	self._queuedDataUpdate = false
	self._selection = nil
end

function MenuDialogList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function MenuDialogList:Release()
	wipe(self._ids)
	wipe(self._labels)
	wipe(self._hasChildren)
	local dataToRelease = self._parentId == "" and self._data or nil
	self._data = nil
	self._parentId = nil
	self._dataUpdatePaused = 0
	self._queuedDataUpdate = false
	self._selection = nil
	self.__super:Release()
	if dataToRelease then
		dataToRelease:Release()
	end
end

---Configures the list.
---@param parentId string The parentId to filter the data with
---@param data MenuDialogData The data
---@return MenuDialogList
function MenuDialogList:Configure(parentId, data)
	assert(not self._parentId and not self._data)
	self._parentId = parentId
	self._data = data
	self:AddCancellable(data:Publisher()
		:CallFunction(self:__closure("_HandleDataChanged"))
	)
end

---Sets whether or not data updates re paused
---@param paused any
---@return MenuDialogList
function MenuDialogList:SetDataUpdatesPaused(paused)
	self._dataUpdatePaused = self._dataUpdatePaused + (paused and 1 or -1)
	assert(self._dataUpdatePaused >= 0)
	if self._dataUpdatePaused == 0 and self._queuedDataUpdate then
		self:_HandleDataChanged()
	end
	return self
end

---Sets the selected row.
---@param id string The id of the selected row
function MenuDialogList:SetSelection(id)
	local prevSelection = self._selection
	self._selection = id
	local prevRow = prevSelection and self:_GetRow(Table.KeyByValue(self._ids, prevSelection))
	if prevRow then
		prevRow:SetSelected(false)
	end
	local row = self:_GetRow(Table.KeyByValue(self._ids, id))
	if row then
		row:SetSelected(true)
	end
end

---Gets the vertical offset of a given row.
---@param id string The id of the row
---@return number
function MenuDialogList:GetVerticalOffset(id)
	return self:_GetRowVerticalOffset(Table.KeyByValue(self._ids, id))
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function MenuDialogList.__private:_HandleDataChanged()
	if self._dataUpdatePaused > 0 then
		self._queuedDataUpdate = true
		return
	end
	assert(self._parentId)
	wipe(self._ids)
	wipe(self._labels)
	wipe(self._hasChildren)
	local hasSelection = false
	for _, id, label, hasChildren in self._data:Iterator(self._parentId) do
		hasSelection = hasSelection or id == self._selection
		tinsert(self._ids, id)
		tinsert(self._labels, label)
		tinsert(self._hasChildren, hasChildren)
	end
	if not hasSelection then
		self._selection = nil
	end
	self:_SetNumRows(#self._ids)
	self:Draw()
	self:_SendActionScript("OnRowsChanged", #self._ids * ROW_HEIGHT)
end

---@param row ListRow
function MenuDialogList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()

	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("BODY_BODY3_MEDIUM")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)

	local childrenIcon = row:AddTexture("children")
	childrenIcon:TSMSetTextureAndSize("iconPack.12x12/Chevron/Right")
	childrenIcon:SetPoint("RIGHT", -colSpacing, 0)

	local deleteIcon = row:AddTexture("delete")
	deleteIcon:TSMSetTextureAndSize("iconPack.14x14/Delete")
	deleteIcon:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function MenuDialogList.__protected:_HandleRowEnter(row)
	local dataIndex = row:GetDataIndex()
	local id = self._ids[dataIndex]
	local hasChildren = self._hasChildren[dataIndex]
	self:_SendActionScript("OnRowEnter", id, hasChildren)
	if not hasChildren and self._data:CanDelete(id) then
		local deleteIcon = row:GetTexture("delete")
		deleteIcon:Show()
		local text = row:GetText("text")
		text:SetPoint("RIGHT", deleteIcon, "LEFT", -Theme.GetColSpacing(), 0)
	end
end

---@param row ListRow
function MenuDialogList.__protected:_HandleRowLeave(row)
	row:GetTexture("delete"):Hide()
end

---@param row ListRow
function MenuDialogList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local id = self._ids[dataIndex]
	row:SetSelected(self._selection == id)
	local text = row:GetText("text")
	text:SetText(self._labels[dataIndex])
	local childrenIcon = row:GetTexture("children")
	local deleteIcon = row:GetTexture("delete")
	if self._hasChildren[dataIndex] then
		childrenIcon:Show()
		deleteIcon:Hide()
		text:SetPoint("RIGHT", childrenIcon, "LEFT", -Theme.GetColSpacing(), 0)
	elseif row:IsHovering() and self._data:CanDelete(id) then
		childrenIcon:Hide()
		deleteIcon:Show()
		text:SetPoint("RIGHT", deleteIcon, "LEFT", -Theme.GetColSpacing(), 0)
	else
		childrenIcon:Hide()
		deleteIcon:Hide()
		text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	end
end

---@param row ListRow
function MenuDialogList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	if self._hasChildren[dataIndex] then
		return
	end
	local delete = row:GetTexture("delete")
	if delete:IsVisible() and delete:IsMouseOver() then
		self:_SendActionScript("OnRowDelete", self._ids[dataIndex])
	else
		self:_SendActionScript("OnRowClick", self._ids[dataIndex])
	end
end
