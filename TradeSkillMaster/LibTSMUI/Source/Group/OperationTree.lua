-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local ROW_HEIGHT = 28
local DATA_SEP = "\001"
local EXPANDER_TEXTURE_EXPANDED = "iconPack.14x14/Caret/Down"
local EXPANDER_TEXTURE_COLLAPSED = "iconPack.14x14/Caret/Right"
local DUPLICATE_TEXTURE = "iconPack.14x14/Duplicate"
local ADD_TEXTURE = "iconPack.14x14/Add/Circle"
local DELETE_TEXTURE = "iconPack.14x14/Delete"
local ICON_SPACING = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationTree = UIElements.Define("OperationTree", "List")
OperationTree:_ExtendStateSchema()
	:UpdateFieldDefault("backgroundColor", "PRIMARY_BG_ALT")
	:Commit()


-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationTree:__init()
	self.__super:__init()

	self._data = {}
	self._operationNameFilter = ""
	self._selected = nil
	self._expandedModule = nil
	self._selectedOperation = nil
	self._prevSelectedOperation = nil
	self._onOperationSelectedHandler = nil
	self._onOperationAddedHandler = nil
	self._onOperationDeletedHandler = nil
end

function OperationTree:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
	self:_UpdateData()
end

function OperationTree:Release()
	wipe(self._data)
	self._selected = nil
	self._operationNameFilter = ""
	self._expandedModule = nil
	self._selectedOperation = nil
	self._prevSelectedOperation = nil
	self._onOperationSelectedHandler = nil
	self._onOperationAddedHandler = nil
	self._onOperationDeletedHandler = nil
	self.__super:Release()
end

---Sets the operation name filter.
---@param filter string The filter string (any operations which don't match this are hidden)
function OperationTree:SetOperationNameFilter(filter)
	self._operationNameFilter = filter
	if filter == "" and self._prevSelectedOperation and not self._selectedOperation then
		-- Restore any previous selection if we don't have something selected
		self:SetSelectedOperation(self:_SplitOperationKey(self._prevSelectedOperation))
		self._prevSelectedOperation = nil
	elseif filter ~= "" and self._selectedOperation then
		local _, operationName = self:_SplitOperationKey(self._selectedOperation)
		if not operationName or not strmatch(strlower(operationName), filter) then
			-- Save the current selection to restore after the filter is cleared and then clear the current selection
			self._prevSelectedOperation = self._selectedOperation
			self:SetSelectedOperation(nil, nil)
		end
	end
	self:_UpdateData()
end

---Registers a script handler.
---@param script "OnOperationSelected"|"OnOperationAdded"|"OnOperationDeleted" The script to register for
---@param handler function The script handler which will be called with the operation tree object followed by any arguments
---@return OperationTree
function OperationTree:SetScript(script, handler)
	if script == "OnOperationSelected" then
		self._onOperationSelectedHandler = handler
	elseif script == "OnOperationAdded" then
		self._onOperationAddedHandler = handler
	elseif script == "OnOperationDeleted" then
		self._onOperationDeletedHandler = handler
	else
		error("Unknown OperationTree script: "..tostring(script))
	end
	return self
end

---Sets the selected operation.
---@param moduleName string The name of the module which the operation belongs to
---@param operationName? string The name of the operation
---@return OperationTree
function OperationTree:SetSelectedOperation(moduleName, operationName)
	if moduleName and operationName then
		self._selectedOperation = moduleName..DATA_SEP..operationName
		self._expandedModule = moduleName
	elseif moduleName then
		self._selectedOperation = moduleName
		self._expandedModule = moduleName
	else
		self._selectedOperation = nil
		self._expandedModule = nil
	end
	self:_UpdateData()
	if self._onOperationSelectedHandler then
		self:_onOperationSelectedHandler(moduleName, operationName)
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function OperationTree.__private:_UpdateData()
	wipe(self._data)
	for _, moduleName in Operation.TypeIterator() do
		if not self:_IsDataHidden(moduleName) then
			tinsert(self._data, moduleName)
		end
		for _, operationName in Operation.Iterator(moduleName) do
			local data = moduleName..DATA_SEP..operationName
			if not self:_IsDataHidden(data) then
				tinsert(self._data, data)
			end
		end
	end
	self:_SetNumRows(#self._data)
	self:Draw()
end

function OperationTree.__private:_IsDataHidden(data)
	local moduleName, operationName = self:_SplitOperationKey(data)
	if operationName and not strmatch(strlower(operationName), self._operationNameFilter) then
		return true
	elseif operationName and moduleName ~= self._expandedModule then
		return true
	end
	return false
end

---@param row ListRow
function OperationTree.__protected:_HandleRowAcquired(row)
	-- Expander
	local expander = row:AddTexture("expander")
	expander:SetDrawLayer("ARTWORK", 1)
	expander:TSMSetSize(EXPANDER_TEXTURE_COLLAPSED)

	-- Text
	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("BODY_BODY2_MEDIUM")
	text:SetJustifyH("LEFT")

	-- Add
	local add = row:AddTexture("add")
	add:TSMSetTextureAndSize(ADD_TEXTURE)

	-- Duplicate
	local duplicate = row:AddTexture("duplicate")
	duplicate:TSMSetTextureAndSize(DUPLICATE_TEXTURE)

	-- Delete
	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)

	-- Layout the elements
	expander:SetPoint("LEFT", ICON_SPACING, 0)
	text:SetPoint("LEFT", expander, "RIGHT", ICON_SPACING, 0)
	add:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	delete:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	duplicate:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
	text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
end

---@param row ListRow
function OperationTree.__protected:_HandleRowDraw(row)
	local data = self._data[row:GetDataIndex()]
	local moduleName, operationName = self:_SplitOperationKey(data)
	local isSelected = self._selectedOperation == data
	row:SetSelected(self._selectedOperation == data)

	local add = row:GetTexture("add")
	add:TSMSetShown(not operationName)
	local duplicate = row:GetTexture("duplicate")
	duplicate:TSMSetShown(operationName and isSelected)
	local delete = row:GetTexture("delete")
	delete:TSMSetShown(operationName and isSelected)

	local text = row:GetText("text")
	text:TSMSubscribeTextColor(operationName and "TEXT" or "INDICATOR")
	text:SetText(operationName or format(L["%s Operations"], moduleName))
	if not operationName then
		text:SetPoint("RIGHT", add, "LEFT", -ICON_SPACING, 0)
	elseif isSelected then
		text:SetPoint("RIGHT", duplicate, "LEFT", -ICON_SPACING, 0)
	else
		text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	end

	local expander = row:GetTexture("expander")
	expander:TSMSetTexture(moduleName == self._expandedModule and EXPANDER_TEXTURE_EXPANDED or EXPANDER_TEXTURE_COLLAPSED)
	expander:TSMSetShown(not operationName)
end

---@param row ListRow
function OperationTree.__protected:_HandleRowClick(row, mouseButton)
	local data = self._data[row:GetDataIndex()]
	local moduleName, operationName = self:_SplitOperationKey(data)
	if mouseButton == "RightButton" or (not operationName and row:GetTexture("expander"):IsMouseOver()) then
		if operationName then
			return
		end
		if self._expandedModule then
			self:SetSelectedOperation(nil, nil)
		else
			self:SetSelectedOperation(moduleName, nil)
		end
	elseif not operationName and row:GetTexture("add"):IsMouseOver() then
		operationName = Operation.GetDeduplicatedName(moduleName, L["New Operation"])
		self._expandedModule = moduleName
		self:_onOperationAddedHandler(moduleName, operationName)
		self:SetSelectedOperation(moduleName, operationName)
	elseif self._selectedOperation == data and row:GetTexture("duplicate"):IsMouseOver() then
		local newOperationName = Operation.GetDeduplicatedName(moduleName, operationName)
		self:_onOperationAddedHandler(moduleName, newOperationName, operationName)
		self:SetSelectedOperation(moduleName, newOperationName)
	elseif self._selectedOperation == data and row:GetTexture("delete"):IsMouseOver() then
		self:_onOperationDeletedHandler(moduleName, operationName)
	else
		self:SetSelectedOperation(moduleName, operationName)
	end
end

function OperationTree.__private:_SplitOperationKey(data)
	local moduleName, operationName = strmatch(data, "([^"..DATA_SEP.."]+)"..DATA_SEP.."?(.*)")
	operationName = operationName ~= "" and operationName or nil
	return moduleName, operationName
end
