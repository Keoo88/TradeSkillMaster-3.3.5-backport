-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Group = LibTSMTypes:Init("Group")
local GroupItemMap = LibTSMTypes:IncludeClassType("GroupItemMap")
local GroupItemDB = LibTSMTypes:IncludeClassType("GroupItemDB")
local Path = LibTSMTypes:Include("Group.Path")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local private = {
	itemMap = nil, ---@type GroupItemMap
	itemDB = nil, ---@type GroupItemDB
	groupPaths = {},
	items = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Group:OnModuleLoad(function()
	private.itemMap = GroupItemMap.New(Group.IsItemInGroup)
	private.itemDB = GroupItemDB.New("GROUP_ITEMS")
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not a group name is valid.
---@param name string The name
---@return boolean
function Group.IsValidName(name)
	return Path.IsValidName(name)
end

---Returns whether or not a group path is valid.
---@param groupPath GroupPathValue The path
---@return boolean
function Group.IsValidPath(groupPath)
	return Path.IsValid(groupPath)
end

---Gets the root group path.
---@return GroupPathValue
function Group.GetRootPath()
	return Path.GetRoot()
end

---Gets the name of the group from a group path.
---@param groupPath GroupPathValue The group path
---@return string
function Group.GetName(groupPath)
	return Path.GetName(groupPath)
end

---Gets the parent group path or nil for the given group path.
---@param groupPath GroupPathValue The group path
---@return GroupPathValue?
function Group.GetParent(groupPath)
	return Path.GetParent(groupPath)
end

---Gets the relative path between two group paths.
---@param groupPath GroupPathValue The group path
---@param prefixGroupPath GroupPathValue The base group path component
---@return GroupPathValue
function Group.GetRelativePath(groupPath, prefixGroupPath)
	return Path.GetRelative(groupPath, prefixGroupPath)
end

---Checks whether a group path is the child of another.
---@param groupPath GroupPathValue The group path to check
---@param parentPath GroupPathValue The parent group path to compare with
---@return boolean
function Group.IsChild(groupPath, parentPath)
	return Path.IsChild(groupPath, parentPath)
end

---Gets the top level group for a group path.
---@param groupPath GroupPathValue The group path
---@return GroupPathValue
function Group.GetTopLevel(groupPath)
	return Path.GetTopLevel(groupPath)
end

---Creates a new group path by joining the components.
---@param ... string The components
---@return GroupPathValue
function Group.JoinPath(...)
	return Path.Join(...)
end

---Splits a group path into the parent group path and name.
---@param groupPath GroupPathValue The group path
---@return GroupPathValue?
---@return string
function Group.SplitPath(groupPath)
	return Path.Split(groupPath)
end

---Formats a group path for display to the user.
---@param groupPath GroupPathValue The group path
---@return string
function Group.FormatPath(groupPath)
	return Path.Format(groupPath)
end

---Converts the group path into a sortable representation.
---@param groupPath GroupPathValue The group path
---@return string
function Group.GetSortableString(groupPath)
	return Path.GetSortableString(groupPath)
end

---Sorts a list of group paths.
---@param list GroupPathValue[]
function Group.SortPaths(result)
	Path.SortPaths(result)
end

---Gets the level of a group path (top-level groups are 1)
---@param groupPath GroupPathValue The group path
---@return number
function Group.GetLevel(groupPath)
	return Path.GetLevel(groupPath)
end

---Loads group settings.
---@param groups table<GroupPathValue,any>
---@param items table<string,GroupPathValue>
function Group.Load(groups, items)
	wipe(private.groupPaths)
	for groupPath in pairs(groups) do
		private.groupPaths[groupPath] = true
	end
	private.items = items
	private.SanitizeItems()
	private.itemMap:Invalidate()
	private.itemDB:Load(private.items)
end

---Gets the group item DB for joining.
---@return DatabaseTable
function Group.GetItemDBForJoin()
	return private.itemDB:GetForJoin()
end

---Creates an item DB query.
---@param groupPathFilter? GroupPathValue The group path to filter on
---@param includeSubGroups? boolean Whether or not to include subgroups
---@return DatabaseQuery
function Group.CreateItemsQuery(groupPathFilter, includeSubGroups)
	return private.itemDB:CreateQuery(groupPathFilter, includeSubGroups)
end

---Iterates over items in a group.
---@param groupPathFilter GroupPathValue The group path to filter on
---@param includeSubGroups boolean Whether or not to include subgroups
---@return fun(): number, string, string @Iterator with fields: `index`, `itemString`, `groupPath`
function Group.ItemIterator(groupPathFilter, includeSubGroups)
	return private.itemDB:Iterator(groupPathFilter, includeSubGroups)
end

---Iterates over items in a group by their base item string.
---@param baseItemString any
---@return fun(): number, string, string @Iterator with fields: `index`, `itemString`, `groupPath`
function Group.ItemByBaseItemStringIterator(baseItemString)
	return private.itemDB:IteratorByBaseItem(baseItemString)
end

---Gets the number of items in a group.
---@param groupPath GroupPathValue The group path
---@return number
function Group.GetNumItems(groupPath)
	return private.itemDB:GetNumItems(groupPath)
end

---Sets whether or not item DB query updates are paused.
---@param paused boolean Whether or not query updates are paused
function Group.SetItemDBQueriesPaused(paused)
	private.itemDB:SetQueryUpdatesPaused(paused)
end

---Translates an itemString based on what's grouped.
---@param itemString string The item string
---@return string
function Group.TranslateItemString(itemString)
	return private.itemMap:Translate(itemString)
end

---Returns whether or not a group exists.
---@param groupPath GroupPathValue The group path
---@return boolean
function Group.Exists(groupPath)
	return private.groupPaths[groupPath] or false
end

---Handles a group being created.
---@param groupPath GroupPathValue The group path
function Group.HandleGroupCreated(groupPath)
	private.groupPaths[groupPath] = true
end

---Handle a group being moved.
---@param changes table<GroupPathValue,GroupPathValue> The changes
function Group.HandleGroupMoved(changes)
	Group.SetItemDBQueriesPaused(true)
	local itemsMoved = TempTable.Acquire()
	for oldPath, newPath in pairs(changes) do
		private.groupPaths[oldPath] = nil
		private.groupPaths[newPath] = true
		wipe(itemsMoved)
		private.itemDB:Move(oldPath, newPath, itemsMoved)
		for _, itemString in ipairs(itemsMoved) do
			assert(private.items[itemString])
			private.items[itemString] = newPath
		end
	end
	TempTable.Release(itemsMoved)
	Group.SetItemDBQueriesPaused(false)
end

---Handles a group being deleted.
---@param groupPath GroupPathValue The group path
function Group.HandleGroupDeleted(groupPath)
	-- Remove all items from our DB
	Group.SetItemDBQueriesPaused(true)
	local query = Group.CreateItemsQuery(groupPath, true)
		:Select("itemString")
	local updateMapItems = TempTable.Acquire()
	for _, itemString in query:Iterator() do
		assert(private.items[itemString])
		private.items[itemString] = nil
		private.itemDB:SetGroup(itemString, nil)
		updateMapItems[itemString] = true
	end
	query:Release()
	private.itemMap:ValuesChanged(updateMapItems)
	TempTable.Release(updateMapItems)
	for childGroupPath in pairs(private.groupPaths) do
		if childGroupPath == groupPath or Path.IsChild(childGroupPath, groupPath) then
			private.groupPaths[childGroupPath] = nil
		end
	end
	Group.SetItemDBQueriesPaused(false)
end

---Returns whether or not an item is in a group.
---@param itemString string The item string
---@return boolean
function Group.IsItemInGroup(itemString)
	return private.itemDB:HasItem(itemString)
end

---Gets the group path for an item.
---@param itemString string The item string
---@return GroupPathValue
function Group.GetPathByItem(itemString)
	local groupPath = private.itemDB:GetGroup(Group.TranslateItemString(itemString))
	assert(Group.Exists(groupPath))
	return groupPath
end

---Sets the group an item is in.
---@param itemString string The item string
---@param groupPath GroupPathValue The group path
function Group.SetItemGroup(itemString, groupPath)
	private.SetItemGroup(itemString, groupPath)
end

---Sets the group a list of items are in.
---@param items string[] The item strings
---@param groupPath GroupPathValue The group path
function Group.SetItemsGroup(items, groupPath)
	Group.SetItemDBQueriesPaused(true)
	for _, itemString in ipairs(items) do
		private.SetItemGroup(itemString, groupPath)
	end
	Group.SetItemDBQueriesPaused(false)
end

---Imports a set of items into a group and subgroups and returns the number of items added.
---@param groupName GroupPathValue The top-level group name to import into
---@param items table<string,GroupPathValue> The items and their relative group paths
---@param moveExisting boolean Whether or not to move items which are already in a group
---@return number
function Group.ImportItems(groupName, items, moveExisting)
	assert(not Path.IsRoot(groupName))
	local numItems = 0
	for itemString, relGroupPath in pairs(items) do
		local groupPath = relGroupPath == Path.GetRoot() and groupName or Path.Join(groupName, relGroupPath)
		assert(Group.Exists(groupPath))
		if not Group.IsItemInGroup(itemString) then
			private.items[itemString] = groupPath
			numItems = numItems + 1
		elseif moveExisting then
			private.items[itemString] = groupPath
			numItems = numItems + 1
		end
	end
	Group.SetItemDBQueriesPaused(true)
	private.itemDB:Load(private.items)
	private.itemMap:Invalidate()
	Group.SetItemDBQueriesPaused(false)
	return numItems
end

---Exports a group.
---@param exportGroupPath GroupPathValue The group path to export
---@param includedSubGroups table<GroupPathValue,boolean> Relative subgroup paths to include in the export
---@param resultGroups table<GroupPathValue,boolean> Table to store result groups in
---@param resultItems table<string,GroupPathValue> Table to store result items in
function Group.Export(exportGroupPath, includedSubGroups, resultGroups, resultItems)
	for groupPath in pairs(private.groupPaths) do
		local relGroupPath = nil
		if Group.IsChild(groupPath, exportGroupPath) then
			relGroupPath = Group.GetRelativePath(groupPath, exportGroupPath)
			if not includedSubGroups[relGroupPath] then
				relGroupPath = nil
			end
		elseif groupPath == exportGroupPath then
			relGroupPath = Group.GetRootPath()
		end
		if relGroupPath then
			resultGroups[relGroupPath] = true
			for _, itemString in Group.ItemIterator(groupPath) do
				resultItems[itemString] = relGroupPath
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizeItems()
	-- Fix up any invalid items
	local newPaths = TempTable.Acquire()
	for itemString, groupPath in pairs(private.items) do
		local newItemString = GroupItemMap.SanitizeItemString(itemString)
		if not newItemString then
			-- This itemstring is invalid
			Log.Err("Itemstring (%s) is invalid", tostring(itemString))
			private.items[itemString] = nil
		elseif Path.IsRoot(groupPath) or not Group.Exists(groupPath) then
			-- This group doesn't exist
			Log.Err("Group (%s) doesn't exist, so removing item (%s)", groupPath, itemString)
			private.items[itemString] = nil
		elseif newItemString ~= itemString then
			-- Remove this invalid itemstring from this group
			Log.Err("Itemstring changed (%s -> %s), so removing it from group (%s)", itemString, newItemString, groupPath)
			private.items[itemString] = nil
			-- Add this new item to this group if it's not already in one
			if not private.items[newItemString] then
				newPaths[newItemString] = groupPath
				Log.Err("Adding to group instead (%s)", groupPath)
			end
		end
	end
	for itemString, groupPath in pairs(newPaths) do
		private.items[itemString] = groupPath
	end
	TempTable.Release(newPaths)
end

function private.SetItemGroup(itemString, groupPath)
	assert(not groupPath or (not Path.IsRoot(groupPath) and Group.Exists(groupPath)))
	local hadItem = private.itemDB:HasItem(itemString)
	private.itemDB:SetGroup(itemString, groupPath)
	private.items[itemString] = groupPath
	if not hadItem or not groupPath then
		private.itemMap:ValueChanged(itemString)
	end
end
