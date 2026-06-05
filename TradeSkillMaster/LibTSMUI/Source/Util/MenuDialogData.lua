-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local MenuDialogData = LibTSMUI:DefineClassType("MenuDialogData")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local ObjectPool = LibTSMUI:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Reactive = LibTSMUI:From("LibTSMUtil"):Include("Reactive")
local private = {
	objectPool = ObjectPool.New("MENU_DIALOG_DATA", MenuDialogData, 1),
	removeTemp = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a MenuDialogData object.
---@return MenuDialogData
function MenuDialogData.__static.Get()
	return private.objectPool:Get()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function MenuDialogData:__init()
	self._ids = {}
	self._parentId = {}
	self._label = {}
	self._enableDelete = {}
	self._updateStream = Reactive.CreateStream()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Release the data object.
function MenuDialogData:Release()
	assert(self._updateStream:GetNumPublishers() == 0)
	wipe(self._ids)
	wipe(self._parentId)
	wipe(self._label)
	wipe(self._enableDelete)
	private.objectPool:Recycle(self)
end

---Gets a publisher for data changes.
---@return ReactivePublisher
function MenuDialogData:Publisher()
	return self._updateStream:PublisherWithInitialValue(nil)
end

---Adds a menu entry.
---@param id string The id of the entry
---@param parentId string The id of the parent entry (or an empty string to indicate no parent)
---@param label string The text to display
---@param beforeId? string The id of an existing entry to add this new entry before
function MenuDialogData:AddEntry(id, parentId, label, beforeId)
	assert(id and parentId and label)
	local insertIndex = nil
	if beforeId then
		insertIndex = Table.KeyByValue(self._ids, beforeId)
		-- We currently only support inserting after other siblings
		assert(insertIndex and insertIndex > 1 and self._parentId[self._ids[insertIndex - 1]] == parentId)
	else
		-- Find the last sibling to insert after
		for i, entryId in ipairs(self._ids) do
			if entryId == parentId or self:_IsDescendent(entryId, parentId) then
				insertIndex = i + 1
			end
		end
		insertIndex = insertIndex or (#self._ids + 1)
	end
	tinsert(self._ids, insertIndex, id)
	self._parentId[id] = parentId
	self._label[id] = label
	self._updateStream:Send(nil)
end

---Updates the label of an entry.
---@param id string The id of the entry
---@param label string The new label
function MenuDialogData:UpdateEntry(id, label)
	assert(self._label[id])
	self._label[id] = label
	self._updateStream:Send(nil)
end

---Removes an entry.
---@param id string The id of the entry
function MenuDialogData:RemoveEntry(id)
	local found = false
	assert(#private.removeTemp == 0)
	for i, entryId in ipairs(self._ids) do
		if entryId == id then
			found = true
			tinsert(private.removeTemp, i)
		elseif self:_IsDescendent(entryId, id) then
			tinsert(private.removeTemp, i)
		end
	end
	assert(found)
	sort(private.removeTemp)
	for _, index in Table.ReverseIPairs(private.removeTemp) do
		local removedId = tremove(self._ids, index)
		self._parentId[removedId] = nil
		self._label[removedId] = nil
	end
	wipe(private.removeTemp)
	self._updateStream:Send(nil)
end

---Enables a deletion of an entry.
---@param id string The id of the entry or the parent id of a set of entries to enable deletion for
function MenuDialogData:EnableDeletion(id)
	self._enableDelete[id] = true
	self._updateStream:Send(nil)
end

---Gets the number of rows which match the filter.
---@param filterParentId string The parent id to filter on
---@return number
function MenuDialogData:GetNumRows(filterParentId)
	local numRows = 0
	for _, parentId in pairs(self._parentId) do
		if parentId == filterParentId then
			numRows = numRows + 1
		end
	end
	return numRows
end

---Iterates over the data entries which match the specified filter.
---@param parentId string The parent id to filter on
---@return fun(): number, string, string, boolean @Iterator with fields: `index`, `id`, `label`, `hasChildren`
function MenuDialogData:Iterator(parentId)
	local result = TempTable.Acquire()
	for i, id in ipairs(self._ids) do
		if self._parentId[id] == parentId then
			local hasChildren = i < #self._ids and self._parentId[self._ids[i + 1]] == id
			Table.InsertMultiple(result, id, self._label[id], hasChildren)
		end
	end
	return TempTable.Iterator(result, 3)
end

---Returns whether or not an entry can be deleted.
---@param id string The id of the entry
---@return boolean
function MenuDialogData:CanDelete(id)
	for parentId in pairs(self._enableDelete) do
		if self:_IsDescendent(id, parentId) then
			return true
		end
	end
	return false
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MenuDialogData.__private:_IsDescendent(id, parentId)
	while id ~= "" do
		id = self._parentId[id]
		if id == parentId then
			return true
		end
	end
	return false
end
