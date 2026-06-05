-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local MenuDialogData = LibTSMUI:IncludeClassType("MenuDialogData")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MenuDialog = UIElements.Define("MenuDialog", "Frame")
MenuDialog:_AddActionScripts("OnRowClick", "OnRowDelete")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MenuDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("MENU_DIALOG", self._state, self:__closure("_ActionHandler"))
		:SuppressActionLog(true)
	self._data = nil
	self._currentId = nil
end

function MenuDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetWidth(250)
	self:SetPadding(2)
	self:SetBackgroundColor("PRIMARY_BG_ALT")
	self:SetBorderColor("ACTIVE_BG_ALT")
	self:AddChild(UIElements.New("MenuDialogList", "list")
		:SetManager(self._childManager)
		:SetAction("OnRowsChanged", "ACTION_UPDATE_HEIGHT")
		:SetAction("OnRowEnter", "ACTION_HANDLE_ROW_ENTER")
		:SetAction("OnRowClick", "ACTION_HANDLE_ROW_CLICK")
		:SetAction("OnRowDelete", "ACTION_HANDLE_ROW_DELETE")
	)
end

function MenuDialog:Release()
	-- Need to explicitly remove the sub menu first since it has a reference to the data
	if self:HasChildById("subMenu") then
		self:RemoveChild(self:GetElement("subMenu"))
	end
	self._data = nil
	self._currentId = nil
	self.__super:Release()
end

---Sets the data.
---@param parentId string The parentId for this menu dialog
---@param data? MenuDialogData The data
---@return MenuDialog
function MenuDialog:Configure(parentId, data)
	assert(not self._data)
	data = data or MenuDialogData.Get()
	self._data = data
	self:GetElement("list"):Configure(parentId, data)
	return self
end

---Sets whether or not data updates are paused.
---@param paused boolean Whether or not to pause data updates
---@return MenuDialog
function MenuDialog:SetDataUpdatesPaused(paused)
	self:GetElement("list"):SetDataUpdatesPaused(paused)
	return self
end

---Adds a menu row.
---@param id string The id of the row
---@param parentId string The id of the parent row (or an empty string to indicate no parent)
---@param label string The text to display
---@param beforeId? string The id of an existing row to add this new row before
---@return MenuDialog
function MenuDialog:AddRow(id, parentId, label, beforeId)
	self._data:AddEntry(id, parentId, label, beforeId)
	return self
end

---Updates the label of a row.
---@param id string The id of the row
---@param label string The text to display
function MenuDialog:UpdateRow(id, label)
	self._data:UpdateEntry(id, label)
end

---Removes a row.
---@param id string The id of the row
function MenuDialog:RemoveRow(id)
	self._data:RemoveEntry(id)
end

---Enables a delete icon for a row.
---@param id string The id of the row or the parentId of a set of rows to enable deletion for
---@return MenuDialog
function MenuDialog:EnableDeletion(id)
	self._data:EnableDeletion(id)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager
function MenuDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_HEIGHT" then
		local listMaxHeight = ...
		self:SetHeight(min(4 + listMaxHeight, 255))
		self:Draw()
	elseif action == "ACTION_HANDLE_ROW_ENTER" then
		local id, hasChildren = ...
		if id == self._currentId then
			return
		end
		manager:ProcessAction("ACTION_SET_CURRENT_ID", id)
		if hasChildren then
			manager:ProcessAction("ACTION_SHOW_SUB_MENU")
		end
	elseif action == "ACTION_SET_CURRENT_ID" then
		local id = ...
		if self._currentId == id then
			return
		end
		if self:HasChildById("subMenu") then
			self:RemoveChild(self:GetElement("subMenu"))
			self:Draw()
		end
		self:GetElement("list"):SetSelection(id)
		self._currentId = id
	elseif action == "ACTION_SHOW_SUB_MENU" then
		assert(self._currentId and self._currentId ~= "")
		local subMenu = UIElements.New("MenuDialog", "subMenu")
			:AddAnchor("TOPLEFT", self, "TOPRIGHT", 4, -self:GetElement("list"):GetVerticalOffset(self._currentId))
			:Configure(self._currentId, self._data)
			:SetManager(manager)
			:SetAction("OnRowClick", "ACTION_HANDLE_SUB_MENU_ROW_CLICK")
			:SetAction("OnRowDelete", "ACTION_HANDLE_SUB_MENU_ROW_DELETE")
		self:AddChildNoLayout(subMenu)
		subMenu:Draw()
	elseif action == "ACTION_HANDLE_ROW_CLICK" then
		local id = ...
		self:_SendActionScript("OnRowClick", self, id)
	elseif action == "ACTION_HANDLE_ROW_DELETE" then
		local id = ...
		self:_SendActionScript("OnRowDelete", self, id)
	elseif action == "ACTION_HANDLE_SUB_MENU_ROW_CLICK" then
		assert(self._currentId)
		self:_SendActionScript("OnRowClick", self, self._currentId, select(2, ...))
	elseif action == "ACTION_HANDLE_SUB_MENU_ROW_DELETE" then
		assert(self._currentId)
		self:_SendActionScript("OnRowDelete", self, self._currentId, select(2, ...))
	else
		error("Unknown action: "..tostring(action))
	end
end
