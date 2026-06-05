-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GroupItemDB = LibTSMTypes:DefineClassType("GroupItemDB")
local GroupItemMap = LibTSMTypes:IncludeClassType("GroupItemMap")
local Path = LibTSMTypes:Include("Group.Path")
local Database = LibTSMTypes:From("LibTSMUtil"):Include("Database")
local private = {}




-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new group item DB.
---@param name string The DB name
---@return GroupItemDB
function GroupItemDB.__static.New(name)
	return GroupItemDB(name)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function GroupItemDB.__private:__init(name)
	self._numItems = {}
	self._db = Database.NewSchema(name)
		:AddUniqueStringField("itemString")
		:AddStringField("groupPath")
		:AddSmartMapField("baseItemString", GroupItemMap.GetBaseItemMap(), "itemString")
		:AddIndex("groupPath")
		:AddIndex("baseItemString")
		:Commit()
	self._baseItemQuery = self._db:NewQuery()
		:Select("itemString", "groupPath")
		:Equal("baseItemString", Database.BoundQueryParam())
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupItemDB:Load(items)
	self._db:TruncateAndBulkInsertStart()
	for itemString, groupPath in pairs(items) do
		self._db:BulkInsertNewRow(itemString, groupPath)
		self:_IncrementNumItems(groupPath, 1)
	end
	self._db:BulkInsertEnd()
end

---Returns the underlying DB table for joining.
---@return DatabaseTable
function GroupItemDB:GetForJoin()
	return self._db
end

---Creates an query.
---@param groupPathFilter? GroupPathValue The group path to filter on
---@param includeSubGroups? boolean Whether or not to include subgroups
---@return DatabaseQuery
function GroupItemDB:CreateQuery(groupPathFilter, includeSubGroups)
	assert(groupPathFilter == nil or not Path.IsRoot(groupPathFilter))
	if not groupPathFilter then
		assert(not includeSubGroups)
		return self._db:NewQuery()
	elseif includeSubGroups then
		return self._db:NewQuery()
			:StartsWith("groupPath", groupPathFilter)
			:Custom(private.ItemInGroupQueryFilter, groupPathFilter)
	else
		return self._db:NewQuery()
			:Equal("groupPath", groupPathFilter)
	end
end

---Iterates over items in a group.
---@param groupPathFilter GroupPathValue The group path to filter on
---@param includeSubGroups boolean Whether or not to include subgroups
---@return fun(): number, string, string @Iterator with fields: `index`, `itemString`, `groupPath`
function GroupItemDB:Iterator(groupPathFilter, includeSubGroups)
	if groupPathFilter then
		return self:CreateQuery(groupPathFilter, includeSubGroups)
			:Select("itemString", "groupPath")
			:IteratorAndRelease()
	else
		return self._db:NewQuery()
			:Select("itemString", "groupPath")
			:IteratorAndRelease()
	end
end

---Iterates over items in a group by their base item string.
---@param baseItemString any
---@return fun(): number, string, string @Iterator with fields: `index`, `itemString`, `groupPath`
function GroupItemDB:IteratorByBaseItem(baseItemString)
	return self._baseItemQuery:BindParams(baseItemString):Iterator()
end

---Gets the number of items in a group.
---@param groupPath GroupPathValue The group path
---@return number
function GroupItemDB:GetNumItems(groupPath)
	return self._numItems[groupPath] or 0
end

---Sets whether or not query updates are paused.
---@param paused boolean
function GroupItemDB:SetQueryUpdatesPaused(paused)
	self._db:SetQueryUpdatesPaused(paused)
end

---Returns whether or not an item is in a group.
---@param itemString string The item string
---@return boolean
function GroupItemDB:HasItem(itemString)
	return self._db:HasUniqueRow("itemString", itemString)
end

---Gets the group path for an item.
---@param itemString string The item string
---@return GroupPathValue
function GroupItemDB:GetGroup(itemString)
	return self._db:GetUniqueRowField("itemString", itemString, "groupPath") or Path.GetRoot()
end

---Sets the group an item is in.
---@param itemString string The item string
---@param groupPath? GroupPathValue The group path to put the item in, or nil to remove it from its group
function GroupItemDB:SetGroup(itemString, groupPath)
	local prevGroupPath = self._db:GetUniqueRowField("itemString", itemString, "groupPath")
	if prevGroupPath then
		self:_DecrementNumItems(prevGroupPath, 1)
	end
	if groupPath then
		self:_IncrementNumItems(groupPath, 1)
	end
	if prevGroupPath and groupPath then
		-- Move the item
		self._db:SetUniqueRowField("itemString", itemString, "groupPath", groupPath)
	elseif prevGroupPath then
		-- Remove the item
		self._db:DeleteRowByUniqueField("itemString", itemString)
	elseif groupPath then
		-- Add the item
		self._db:NewRow()
			:SetField("itemString", itemString)
			:SetField("groupPath", groupPath)
			:Create()
	end
end

---Moves items from one group to another.
---@param oldPath GroupPathValue The old group path
---@param newPath GroupPathValue The new group path
---@param itemsMoved string[] A table to store the list of items moved
function GroupItemDB:Move(oldPath, newPath, itemsMoved)
	self._db:SetQueryUpdatesPaused(true)
	local query = self._db:NewQuery()
		:Select("itemString")
		:Equal("groupPath", oldPath)
	for _, itemString in query:Iterator() do
		tinsert(itemsMoved, itemString)
		self._db:SetUniqueRowField("itemString", itemString, "groupPath", newPath)
	end
	self:_DecrementNumItems(oldPath, #itemsMoved)
	self:_IncrementNumItems(newPath, #itemsMoved)
	self._db:SetQueryUpdatesPaused(false)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function GroupItemDB.__private:_IncrementNumItems(groupPath, amount)
	if amount == 0 then
		return
	end
	self._numItems[groupPath] = (self._numItems[groupPath] or 0) + amount
end

function GroupItemDB.__private:_DecrementNumItems(groupPath, amount)
	if amount == 0 then
		return
	end
	local numItems = self._numItems[groupPath] - amount
	assert(numItems >= 0)
	self._numItems[groupPath] = numItems > 0 and numItems or nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemInGroupQueryFilter(row, groupPathFilter)
	local groupPath = row:GetField("groupPath")
	return groupPath == groupPathFilter or Path.IsChild(groupPath, groupPathFilter)
end
