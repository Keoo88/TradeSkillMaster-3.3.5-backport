-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GroupOperation = LibTSMTypes:Init("GroupOperation")
local Group = LibTSMTypes:Include("Group")
local Operation = LibTSMTypes:Include("Operation")
local Database = LibTSMTypes:From("LibTSMUtil"):Include("Database")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local private = {
	groups = nil,
	db = nil,
	groupListCache = {},
	groupsTemp = {},
}
local DEFAULT_OPERATION_NAME = "#Default"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not a group name is valid.
---@param name string The name
---@return boolean
function GroupOperation.Configure()
	assert(not private.db)
	local schema = Database.NewSchema("GROUP_OPERATION")
		:AddUniqueStringField("groupPath")
		:AddStringField("orderStr")
		:AddIndex("groupPath")
		:AddIndex("orderStr")
	local hasOperationTypes = false
	for _, typeName in Operation.TypeIterator() do
		hasOperationTypes = true
		schema:AddBooleanField("has"..typeName.."Operation")
		schema:AddBooleanField("hasAny"..typeName.."Operation")
	end
	assert(hasOperationTypes)
	private.db = schema:Commit()
end

---Loads group settings and refreshes the group operation DB.
---@param groups table<GroupPathValue,table>
---@param items table<string,GroupPathValue>
function GroupOperation.Load(groups, items)
	private.groups = groups
	private.SanitizeGroups()
	Group.Load(groups, items)
	GroupOperation.RebuildDB()
end

---Rebuilds the group operation DB.
function GroupOperation.RebuildDB()
	private.db:TruncateAndBulkInsertStart()
	wipe(private.groupListCache)
	local rowTemp = TempTable.Acquire()
	for groupPath in pairs(private.groups) do
		local orderStr = Group.GetSortableString(groupPath)
		assert(not next(rowTemp))
		for _, typeName in Operation.TypeIterator() do
			local has, hasAny = private.HasOperation(groupPath, typeName)
			tinsert(rowTemp, has)
			tinsert(rowTemp, hasAny)
		end
		private.db:BulkInsertNewRow(groupPath, orderStr, unpack(rowTemp))
		wipe(rowTemp)
	end
	TempTable.Release(rowTemp)
	private.db:BulkInsertEnd()
end

---Creates a group operation DB query.
---@return DatabaseQuery
function GroupOperation.CreateQuery()
	return private.db:NewQuery()
		:OrderBy("orderStr", true)
end

---Iterates over operations assigned to a group.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@return fun(): number, string @Iterator with fields: `index`, `operationName`
function GroupOperation.Iterator(groupPath, typeName)
	return ipairs(private.groups[groupPath][typeName])
end

---Iterates over all groups.
---@return fun(): number, string @Iterator with fields: `index`, `groupPath`
function GroupOperation.GroupIterator()
	if #private.groupListCache == 0 then
		GroupOperation.CreateQuery()
			:Select("groupPath")
			:NotEqual("groupPath", Group.GetRootPath())
			:AsTable(private.groupListCache)
			:Release()
	end
	return ipairs(private.groupListCache)
end

---Iterates over groups with the operation assigned.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param overrideOnly? boolean Only include groups with override set
---@return fun(): number, string @Iterator with fields: `index`, `groupPath`
function GroupOperation.GroupIteratorByOperation(typeName, operationName, overrideOnly)
	local result = TempTable.Acquire()
	assert(not next(private.groupsTemp))
	local sortValue = private.groupsTemp
	for groupPath in pairs(private.groups) do
		if (not overrideOnly or GroupOperation.HasOverride(groupPath, typeName)) and GroupOperation.HasOperation(groupPath, typeName, operationName) then
			tinsert(result, groupPath)
			sortValue[groupPath] = Group.GetSortableString(groupPath)
		end
	end
	Table.SortWithValueLookup(result, sortValue)
	wipe(sortValue)
	return TempTable.Iterator(result)
end

---Returns whether or a specific operation is applied to the group.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@return boolean
function GroupOperation.HasOperation(groupPath, typeName, operationName)
	return tContains(private.groups[groupPath][typeName], operationName) and true or false
end

---Returns whether or not a group is overriding operations of a given type.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@return boolean
function GroupOperation.HasOverride(groupPath, typeName)
	return private.groups[groupPath][typeName].override and true or false
end

---Sets whether or not a group is overriding operations.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@param override boolean Whether or not to override
function GroupOperation.SetOverride(groupPath, typeName, override)
	private.SetOperationOverride(groupPath, typeName, override)
	GroupOperation.RebuildDB()
end

---Iterates over the operations of a group.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@return fun(): number, string, OperationSettings @Iterator with fields: `index`, `operationName`, `operationSettings`
function GroupOperation.OperationIterator(groupPath, typeName)
	local result = TempTable.Acquire()
	for _, operationName in GroupOperation.Iterator(groupPath, typeName) do
		Operation.UpdateFromRelationships(typeName, operationName)
		if not Operation.IsIgnored(typeName, operationName) then
			tinsert(result, operationName)
			tinsert(result, Operation.GetSettings(typeName, operationName))
		end
	end
	return TempTable.Iterator(result, 2)
end

---Adds an operation to a group and returns the operation that was removed to make room if applicable.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@return string?
function GroupOperation.Add(groupPath, typeName, operationName)
	if groupPath ~= Group.GetRootPath() then
		private.SetOperationOverride(groupPath, typeName, true)
	end
	local numOperations = 0
	local removedOperationName = nil
	for _, groupOperationName in GroupOperation.Iterator(groupPath, typeName) do
		removedOperationName = groupOperationName
		numOperations = numOperations + 1
	end
	if numOperations == Operation.GetMaxNumber(typeName) then
		-- Replace the last operation since we're already at the max number of operations
		private.RemoveOperation(groupPath, typeName, numOperations)
		assert(removedOperationName)
	else
		removedOperationName = nil
	end
	private.AppendOperation(groupPath, typeName, operationName)
	GroupOperation.RebuildDB()
	return removedOperationName
end

---Appens an operation to the group.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@param operation number|string Either the index or name of the operation to remove
function GroupOperation.Append(groupPath, typeName, operationName)
	private.AppendOperation(groupPath, typeName, operationName)
	GroupOperation.RebuildDB()
end


---Swaps the position of operations assigned to a group.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@param index1 number The first index to swap
---@param index2 number The second index to swap
function GroupOperation.Swap(groupPath, typeName, index1, index2)
	local groupOperations = private.groups[groupPath][typeName]
	groupOperations[index1], groupOperations[index2] = groupOperations[index2], groupOperations[index1]
	private.UpdateChildGroupOperations(groupPath, typeName)
end

---Removes an operation from a group.
---@param groupPath GroupPathValue The group path
---@param typeName string The type of the operation
---@param operation number|string Either the index or name of the operation to remove
function GroupOperation.Remove(groupPath, typeName, operation)
	private.RemoveOperation(groupPath, typeName, operation)
	GroupOperation.RebuildDB()
end

---Creates a new group.
---@param groupPath GroupPathValue The group path
function GroupOperation.CreateGroup(groupPath)
	private.CreateGroup(groupPath)
	GroupOperation.RebuildDB()
end

---Moves a group to a new path.
---@param oldGroupPath GroupPathValue The old group path
---@param newGroupPath GroupPathValue The new group path
function GroupOperation.MoveGroup(oldGroupPath, newGroupPath)
	assert(oldGroupPath ~= Group.GetRootPath())
	assert(Group.Exists(oldGroupPath) and not Group.Exists(newGroupPath))
	local newParentPath = Group.GetParent(newGroupPath)
	assert(newParentPath and Group.Exists(newParentPath))
	Group.SetItemDBQueriesPaused(true)

	-- Get a list of group path changes for this group and all its subgroups
	local changes = TempTable.Acquire()
	local gsubEscapedNewGroupPath = gsub(newGroupPath, "%%", "%%%%")
	for path in pairs(private.groups) do
		if path == oldGroupPath or Group.IsChild(path, oldGroupPath) then
			changes[path] = gsub(path, "^"..String.Escape(oldGroupPath), gsubEscapedNewGroupPath)
		end
	end

	-- Make the changes
	for oldPath, newPath in pairs(changes) do
		assert(Group.Exists(oldPath) and not Group.Exists(newPath))
		private.groups[newPath] = private.groups[oldPath]
		private.groups[oldPath] = nil
	end
	Group.HandleGroupMoved(changes)
	TempTable.Release(changes)

	for _, typeName in Operation.TypeIterator() do
		if not private.HasOperationOverride(newGroupPath, typeName) then
			private.InheritParentOperations(newGroupPath, typeName)
			private.UpdateChildGroupOperations(oldGroupPath, typeName)
		end
	end
	GroupOperation.RebuildDB()
	Group.SetItemDBQueriesPaused(false)
end

---Deletes a group.
---@param groupPath GroupPathValue The group path
function GroupOperation.DeleteGroup(groupPath)
	Group.SetItemDBQueriesPaused(true)
	assert(groupPath ~= Group.GetRootPath() and private.groups[groupPath])
	-- Delete this group and all subgroups
	for path in pairs(private.groups) do
		if path == groupPath or Group.IsChild(path, groupPath) then
			-- Delete this group
			private.groups[path] = nil
		end
	end
	Group.HandleGroupDeleted(groupPath)
	GroupOperation.RebuildDB()
	Group.SetItemDBQueriesPaused(false)
end

---Renames an operation.
---@param typeName string The type of the operation
---@param oldOperationName string The old operation name
---@param newOperationName string The new operation name
function GroupOperation.RenameOperation(typeName, oldOperationName, newOperationName)
	Operation.Rename(typeName, oldOperationName, newOperationName)
	-- Just blindly rename in all groups - no need to check for override
	for _, groupOperations in pairs(private.groups) do
		for i = 1, #groupOperations[typeName] do
			if groupOperations[typeName][i] == oldOperationName then
				groupOperations[typeName][i] = newOperationName
			end
		end
	end
end

---Deletes an operation.
---@param typeName string The type of the operation
---@param operationName string The operation name
function GroupOperation.DeleteOperation(typeName, operationName)
	Operation.Delete(typeName, operationName)
	private.HandleOperationDeleted(typeName, operationName)
	GroupOperation.RebuildDB()
end

---Deletes a list of operations.
---@param typeName string The type of the operation
---@param operationNames string[] The operation names
function GroupOperation.DeleteOperations(typeName, operationNames)
	Operation.Delete(typeName, operationNames)
	for _, operationName in ipairs(operationNames) do
		private.HandleOperationDeleted(typeName, operationName)
	end
	GroupOperation.RebuildDB()
end

---Imports a set of groups, operations, and items and returns the number of items added.
---@param groupName GroupPathValue The top-level group name to import into
---@param groups table<GroupPathValue,any> The groups to import
---@param items table<string,GroupPathValue> The items and their relative group paths
---@param moveExisting boolean Whether or not to move items which are already in a group
---@param groupOperations table<GroupPathValue,table> The operations to import to the group
---@return number
function GroupOperation.Import(groupName, groups, items, moveExistingItems, groupOperations)
	Group.SetItemDBQueriesPaused(true)

	-- Create the groups
	assert(not Group.Exists(groupName) and groups[""])
	local groupPaths = TempTable.Acquire()
	for relGroupPath in pairs(groups) do
		tinsert(groupPaths, relGroupPath == "" and groupName or Group.JoinPath(groupName, relGroupPath))
	end
	Group.SortPaths(groupPaths)
	for _, groupPath in ipairs(groupPaths) do
		assert(not Group.Exists(groupPath))
		private.CreateGroup(groupPath)
	end
	TempTable.Release(groupPaths)

	-- Import the items
	local numItems = Group.ImportItems(groupName, items, moveExistingItems)

	-- Improt the operations
	for relGroupPath, moduleOperations in pairs(groupOperations) do
		local groupPath = relGroupPath == "" and groupName or Group.JoinPath(groupName, relGroupPath)
		for moduleName, operations in pairs(moduleOperations) do
			if operations.override then
				private.groups[groupPath][moduleName] = operations
				private.UpdateChildGroupOperations(groupPath, moduleName)
			end
		end
	end

	GroupOperation.RebuildDB()
	Group.SetItemDBQueriesPaused(false)
	return numItems
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizeGroups()
	for groupPath, groupInfo in pairs(private.groups) do
		-- Remove operations which no longer exist
		for typeName, operations in pairs(groupInfo) do
			for i = #operations, 1, -1 do
				if not Operation.Exists(typeName, operations[i]) then
					Log.Err("Removing invalid operation from group (%s): %s, %s", groupPath, typeName, tostring(operations[i]))
					tremove(operations, i)
				end
			end
		end

		-- Clear ignoreRandomEnchants and ignoreItemVariations
		groupInfo.ignoreItemVariations = nil
		groupInfo.ignoreRandomEnchants = nil

		if type(groupPath) == "string" and Group.IsValidPath(groupPath) then
			-- Check the contents of groupInfo
			for _, typeName in Operation.TypeIterator() do
				groupInfo[typeName] = groupInfo[typeName] or {}
				if groupPath == Group.GetRootPath() then
					-- Root group should have override flag set
					groupInfo[typeName].override = true
				end
			end
			for key in pairs(groupInfo) do
				if Operation.TypeExists(key) then
					-- This is a set of module operations
					local operations = groupInfo[key]
					while #operations > Operation.GetMaxNumber(key) do
						-- Remove extra operations
						tremove(operations)
					end
					for key2 in pairs(operations) do
						if key2 == "override" then
							-- Ensure the override field is either true or nil
							operations.override = operations.override and true or nil
						elseif type(key2) ~= "number" or key2 <= 0 or key2 > #operations then
							-- This is an invalid key
							Log.Err("Removing invalid operations key (%s, %s): %s", groupPath, key, tostring(key2))
							operations[key2] = nil
						end
					end
					for i = #operations, 1, -1 do
						-- Clean up invalid operations
						if type(operations[i]) ~= "string" or operations[i] == "" then
							tremove(operations, i)
						end
					end
				else
					-- Invalid key
					Log.Err("Removing invalid groupInfo key (%s): %s", groupPath, tostring(key))
					groupInfo[key] = nil
				end
			end
		else
			-- Remove invalid group paths
			Log.Err("Removing invalid group path: %s", tostring(groupPath))
			private.groups[groupPath] = nil
		end
	end

	-- Create the root group if it doesn't exist
	if not private.groups[Group.GetRootPath()] then
		-- Set the override flag for all top-level groups
		for groupPath, groupOperations in pairs(private.groups) do
			if Group.GetParent(groupPath) == Group.GetRootPath() then
				for _, typeName in Operation.TypeIterator() do
					groupOperations[typeName].override = true
				end
			end
		end
		-- Create the root group with default operations applied
		local groupOperations = {}
		private.groups[Group.GetRootPath()] = groupOperations
		for _, typeName in Operation.TypeIterator() do
			groupOperations[typeName] = { DEFAULT_OPERATION_NAME, override = true }
		end
	end

	local orderedGroupPaths = TempTable.Acquire()
	for groupPath in pairs(private.groups) do
		if groupPath ~= Group.GetRootPath() then
			tinsert(orderedGroupPaths, groupPath)
		end
	end
	Group.SortPaths(orderedGroupPaths)
	for _, groupPath in TempTable.Iterator(orderedGroupPaths) do
		if not private.groups[Group.GetParent(groupPath)] then
			-- The parent group doesn't exist, so remove this group
			Log.Err("Removing group with non-existent parent: %s", tostring(groupPath))
			private.groups[groupPath] = nil
		else
			-- Clean up operation inheritence
			for _, typeName in Operation.TypeIterator() do
				if not private.HasOperationOverride(groupPath, typeName) then
					private.InheritParentOperations(groupPath, typeName)
				end
			end
		end
	end
end

function private.HasOperation(groupPath, typeName)
	local hasNonIgnored, hasAny = false, false
	for _, operationName in GroupOperation.Iterator(groupPath, typeName) do
		if not Operation.IsIgnored(typeName, operationName) then
			hasNonIgnored = true
			hasAny = true
			break
		else
			hasAny = true
		end
	end
	return hasNonIgnored, hasAny
end

function private.SetOperationOverride(groupPath, typeName, override)
	if override == GroupOperation.HasOverride(groupPath, typeName) then
		return
	end
	assert(groupPath ~= Group.GetRootPath())
	local groupOperations = private.groups[groupPath][typeName]
	if override then
		wipe(groupOperations)
		groupOperations.override = true
		private.UpdateChildGroupOperations(groupPath, typeName)
	else
		groupOperations.override = nil
		private.InheritParentOperations(groupPath, typeName)
		private.UpdateChildGroupOperations(groupPath, typeName)
	end
end

function private.AppendOperation(groupPath, typeName, operationName)
	assert(Operation.Exists(typeName, operationName))
	assert(#private.groups[groupPath][typeName] < Operation.GetMaxNumber(typeName))
	local groupOperations = private.groups[groupPath][typeName]
	assert(groupOperations.override)
	tinsert(groupOperations, operationName)
	private.UpdateChildGroupOperations(groupPath, typeName)
end

function private.RemoveOperation(groupPath, typeName, operation)
	local groupOperations = private.groups[groupPath][typeName]
	assert(groupOperations.override)
	if type(operation) == "number" then
		assert(groupOperations[operation])
		tremove(groupOperations, operation)
	elseif type(operation) == "string" then
		assert(Table.RemoveByValue(groupOperations, operation) > 0)
	else
		error("Invalid operation: "..tostring(operation))
	end
	private.UpdateChildGroupOperations(groupPath, typeName)
end

function private.HandleOperationDeleted(typeName, operationName)
	-- Just blindly remove from all groups - no need to check for override
	for _, groupOperations in pairs(private.groups) do
		Table.RemoveByValue(groupOperations[typeName], operationName)
	end
end

function private.InheritParentOperations(groupPath, typeName)
	local parentGroupPath = Group.GetParent(groupPath)
	local groupOperations = private.groups[groupPath][typeName]
	local override = groupOperations.override
	wipe(groupOperations)
	groupOperations.override = override
	for _, operationName in ipairs(private.groups[parentGroupPath][typeName]) do
		tinsert(groupOperations, operationName)
	end
end

function private.UpdateChildGroupOperations(groupPath, typeName)
	for childGroupPath in pairs(private.groups) do
		if Group.IsChild(childGroupPath, groupPath) and not private.HasOperationOverride(childGroupPath, typeName) then
			private.InheritParentOperations(childGroupPath, typeName)
		end
	end
end

function private.CreateGroup(groupPath)
	assert(not next(private.groupsTemp))
	tinsert(private.groupsTemp, groupPath)
	local parentPath = Group.GetParent(groupPath)
	assert(parentPath)
	-- Traverse up the tree and get all the parent groups that don't yet exists
	while parentPath ~= Group.GetRootPath() and not Group.Exists(parentPath) do
		tinsert(private.groupsTemp, parentPath)
		parentPath = Group.GetParent(parentPath)
	end
	-- Create from the top of the tree down
	Table.Reverse(private.groupsTemp)
	for _, childGroupPath in ipairs(private.groupsTemp) do
		assert(not Group.Exists(childGroupPath))
		local childParentGroupPath = Group.GetParent(childGroupPath)
		assert(childParentGroupPath and (childParentGroupPath == Group.GetRootPath() or Group.Exists(childParentGroupPath)))
		private.groups[childGroupPath] = {}
		for _, typeName in Operation.TypeIterator() do
			private.groups[childGroupPath][typeName] = {}
			private.InheritParentOperations(childGroupPath, typeName)
		end
		Group.HandleGroupCreated(childGroupPath)
	end
	wipe(private.groupsTemp)
end

function private.HasOperationOverride(groupPath, typeName)
	return private.groups[groupPath][typeName].override and true or false
end
