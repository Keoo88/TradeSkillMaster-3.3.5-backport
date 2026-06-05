-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local ROW_HEIGHT = 20



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationsList = UIElements.Define("OperationsList", "List")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function OperationsList:__init()
	self.__super:__init()
	self._query = nil
	self._operationType = nil
	self._filterText = nil
	self._name = {}
	self._selected = nil
	self._onOperationSelected = nil
end

function OperationsList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function OperationsList:Release()
	local query = self._query
	self._query = nil
	self._operationType = nil
	self._filterText = nil
	wipe(self._name)
	self._selected = nil
	self._onOperationSelected = nil
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the operation type for the list.
---@param operationType string The operation type
---@return OperationsList
function OperationsList:SetOperationType(operationType)
	assert(not self._operationType and not self._query)
	self._operationType = operationType
	self._query = Operation.NewQuery()
		:Equal("moduleName", operationType)
		:OrderBy("operationName", true)
	self:AddCancellable(self._query:Publisher()
		:MapToValue(self._query)
		:CallFunction(self:__closure("_HandleQueryUpdate"))
	)
	return self
end

---Sets the module name filter.
---@param text string The module name filter
---@return OperationsList
function OperationsList:SetFilter(filter)
	if filter == self._filterText then
		return
	end
	self._filterText = filter
	self._query:ResetFilters()
		:Equal("moduleName", self._operationType)
		:Contains("operationName", filter)
	self:_HandleQueryUpdate()
	return self
end

---Gets the selected operation.
---@return string?
function OperationsList:GetSelectedOperation()
	return self._selected
end

---Registers a script handler.
---@param script "OnOperationSelected" The script to register for
---@param handler fun(list: OperationsList, ...) The script handler which will be passed any arguments to the script
---@return OperationsList
function OperationsList:SetScript(script, handler)
	if script == "OnOperationSelected" then
		self._onOperationSelected = handler
	else
		error("Unknown OperationsList script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function OperationsList.__private:_HandleQueryUpdate()
	-- TODO: Optimize this using diffs
	wipe(self._name)
	for _, row in self._query:Iterator() do
		tinsert(self._name, row:GetField("operationName"))
	end
	self:_SetNumRows(#self._name)
	self:Draw()
end

---@param row ListRow
function OperationsList.__protected:_HandleRowAcquired(row)
	local colSpacing = Theme.GetColSpacing()
	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("BODY_BODY2_MEDIUM")
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", colSpacing / 2, 0)
	text:SetPoint("RIGHT", -colSpacing, 0)
end

---@param row ListRow
function OperationsList.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	local name = self._name[dataIndex]
	row:GetText("text"):SetText(name)
	row:SetSelected(name == self._selected)
end

---@param row ListRow
function OperationsList.__protected:_HandleRowClick(row)
	local dataIndex = row:GetDataIndex()
	local prevDataIndex = self._selected and Table.KeyByValue(self._name, self._selected) or nil
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		prevRow:SetSelected(false)
	end
	self._selected = self._name[dataIndex]
	row:SetSelected(true)
	if self._onOperationSelected then
		self:_onOperationSelected()
	end
end
