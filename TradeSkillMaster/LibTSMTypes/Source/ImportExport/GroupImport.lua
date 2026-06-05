-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GroupImport = LibTSMTypes:DefineClassType("GroupImport")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local Operation = LibTSMTypes:Include("Operation")
local Group = LibTSMTypes:Include("Group")
local GroupOperation = LibTSMTypes:Include("GroupOperation")
local CustomString = LibTSMTypes:Include("CustomString")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local AceSerializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
local MAGIC_STR = "TSM_EXPORT"
local VERSION = 1



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new group import object.
---@param defaultGroupName string The default group name
---@param customSourceExistsFunc fun(name: string): boolean A function to check if a custom source already exists
---@param ignoredOperationTypes string[] Ignored operation types
---@return GroupImport
function GroupImport.__static.New(defaultGroupName, customSourceExistsFunc, ignoredOperationTypes)
	return GroupImport(defaultGroupName, customSourceExistsFunc, ignoredOperationTypes)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function GroupImport.__private:__init(defaultGroupName, customSourceExistsFunc, ignoredOperationTypes)
	self._defaultGroupName = defaultGroupName
	self._customSourceExistsFunc = customSourceExistsFunc
	self._groupName = nil
	self._items = nil
	self._groups = nil
	self._groupOperations = nil
	self._operations = nil
	self._customSources = nil
	self._numChangedOperations = nil
	self._filteredGroups = {}
	self._ignoredOperationTypes = {}
	for _, typeName in ipairs(ignoredOperationTypes) do
		self._ignoredOperationTypes[typeName] = true
	end
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Processes an import string.
---@param str string The import string
---@return boolean success
---@return number? numInvalidItems
---@return number? numChangedOperations
function GroupImport:Process(str)
	local success, numInvalidItems, numChangedOperations = self:_DecodeNewImport(str, true)
	if not success then
		success, numInvalidItems, numChangedOperations = self:_DecodeOldImport(str, true)
	end
	if not success then
		success, numInvalidItems, numChangedOperations = self:_DecodeOldGroupOrItemListImport(str, true)
	end
	assert(not success or (numInvalidItems and numChangedOperations))
	return success, numInvalidItems, numChangedOperations
end

---Parses a new import string returns the raw results.
---@param str string The import string
---@return string? groupName
---@return table? items
---@return table? groups
---@return table? groupOperations
---@return table? customSources
---@return boolean? isNew
function GroupImport:RawDecode(str)
	local success = self:_DecodeNewImport(str, false)
	local isNew = success
	if not success then
		success = self:_DecodeOldImport(str, false)
	end
	if not success then
		success = self:_DecodeOldGroupOrItemListImport(str, false)
	end
	return self._groupName, self._items, self._groups, self._groupOperations, self._operations, self._customSources, isNew
end

---Gets the totals for the current import string.
---@return number numItems
---@return number numGroups
---@return number numExistingItems
---@return number numOperations
---@return number numExistingOperations
---@return number numExistingCustomSources
function GroupImport:GetTotals()
	local numExistingItems = 0
	for itemString, groupPath in pairs(self._items) do
		if not self._filteredGroups[groupPath] then
			if Group.IsItemInGroup(itemString) then
				numExistingItems = numExistingItems + 1
			end
		end
	end
	wipe(self._customSources)
	local numOperations, numExistingOperations = 0, 0
	for moduleName, moduleOperations in pairs(self._operations) do
		local usedOperations = TempTable.Acquire()
		for groupPath, operations in pairs(self._groupOperations) do
			if not self._filteredGroups[groupPath] then
				for _, operationName in ipairs(operations[moduleName]) do
					usedOperations[operationName] = true
				end
			end
		end
		for operationName, operationSettings in pairs(moduleOperations) do
			if usedOperations[operationName] then
				numOperations = numOperations + 1
				if Operation.Exists(moduleName, operationName) then
					numExistingOperations = numExistingOperations + 1
				end
				for key in Operation.CustomStringSettingKeyIterator(moduleName) do
					self:_GetCustomSources(operationSettings[key], self._customSources)
				end
			end
		end
		TempTable.Release(usedOperations)
	end
	local numExistingCustomSources = 0
	for name in pairs(self._customSources) do
		if self._customSourceExistsFunc(name) then
			numExistingCustomSources = numExistingCustomSources + 1
		end
	end
	local numItems = 0
	for _, groupPath in pairs(self._items) do
		if not self._filteredGroups[groupPath] then
			numItems = numItems + 1
		end
	end
	local numGroups = 0
	for groupPath in pairs(self._groups) do
		if not self._filteredGroups[groupPath] then
			numGroups = numGroups + 1
		end
	end
	return numItems, numGroups, numExistingItems, numOperations, numExistingOperations, numExistingCustomSources
end

---Iterates over the pending groups.
---@return fun(): GroupPathValue, table @Iterator with fields: `relativeGroupPath`, `group`
function GroupImport:PendingGroupIterator()
	assert(self._groupName)
	return pairs(self._groups)
end

---Iterates over the pending items (itemString -> groupPath).
function GroupImport:PendingItemIterator()
	assert(self._items)
	return pairs(self._items)
end

---Gets the pending group name.
---@return string
function GroupImport:GetPendingGroupName()
	assert(self._groupName)
	return self._groupName
end

---Sets whether or not a group should be filtered out of the import.
---@param groupPath GroupPathValue The group path
---@param isFiltered boolean Whether or not to filter out the group
function GroupImport:SetGroupFiltered(groupPath, isFiltered)
	self._filteredGroups[groupPath] = isFiltered or nil
end

---Commits the import.
---@param moveExistingItems boolean Move existing items to the imported groups
---@param includeOperations boolean Include operations
---@param replaceOperations boolean Replace existing operations as needed
---@return string groupName
---@return number numItems
---@return number numOperations
---@return number numCustomSources
function GroupImport:Commit(moveExistingItems, includeOperations, replaceOperations)
	assert(self._groupName)
	local numOperations, numCustomSources = 0, 0
	if includeOperations and next(self._operations) then
		-- Remove filtered operations
		for moduleName, moduleOperations in pairs(self._operations) do
			local usedOperations = TempTable.Acquire()
			for groupPath, operations in pairs(self._groupOperations) do
				if not self._filteredGroups[groupPath] then
					for _, operationName in ipairs(operations[moduleName]) do
						usedOperations[operationName] = true
					end
				end
			end
			for operationName in pairs(moduleOperations) do
				if not usedOperations[operationName] then
					moduleOperations[operationName] = nil
				end
			end
			TempTable.Release(usedOperations)
		end
		if not replaceOperations then
			-- Remove existing operations and custom sources from the import context
			for moduleName, moduleOperations in pairs(self._operations) do
				for operationName in pairs(moduleOperations) do
					if Operation.Exists(moduleName, operationName) then
						moduleOperations[operationName] = nil
					end
				end
				if not next(moduleOperations) then
					self._operations[moduleName] = nil
				end
			end
			for name in pairs(self._customSources) do
				if self._customSourceExistsFunc(name) then
					self._customSources[name] = nil
				end
			end
		end
		if next(self._customSources) then
			-- Regenerate the list of custom sources in case some operations were filtered out
			wipe(self._customSources)
			for moduleName, moduleOperations in pairs(self._operations) do
				for _, operationSettings in pairs(moduleOperations) do
					for key in Operation.CustomStringSettingKeyIterator(moduleName) do
						self:_GetCustomSources(operationSettings[key], self._customSources)
					end
				end
			end
			-- Create the custom sources
			numCustomSources = Table.Count(self._customSources)
			if not replaceOperations then
				for name in pairs(self._customSources) do
					assert(not CustomString.IsCustomSourceRegistered(name))
				end
			end
			CustomString.ImportCustomSources(self._customSources)
		end
		-- Create the operations
		for _, moduleOperations in pairs(self._operations) do
			numOperations = numOperations + Table.Count(moduleOperations)
		end
		Operation.Import(self._operations, replaceOperations)
	end
	if not includeOperations then
		wipe(self._groupOperations)
	end

	-- Filter the groups
	for groupPath in pairs(self._filteredGroups) do
		self._groups[groupPath] = nil
		self._groupOperations[groupPath] = nil
	end
	for itemString, groupPath in pairs(self._items) do
		if self._filteredGroups[groupPath] then
			self._items[itemString] = nil
		end
	end

	-- Create the groups
	local numItems = GroupOperation.Import(self._groupName, self._groups, self._items, moveExistingItems, self._groupOperations)

	-- Reset the import object and return the result
	local groupName = self._groupName
	self:Reset()
	return groupName, numItems, numOperations, numCustomSources
end

---Resets the import object.
function GroupImport:Reset()
	self._groupName = nil
	self._items = nil
	self._groups = nil
	self._groupOperations = nil
	self._operations = nil
	self._customSources = nil
	wipe(self._filteredGroups)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function GroupImport.__private:_GetCustomSources(str, result)
	for _, name, customSourceStr in CustomString.DependantCustomSourceIterator(str) do
		if not result[name] then
			result[name] = customSourceStr
			self:_GetCustomSources(customSourceStr, result)
		end
	end
end

function GroupImport.__private:_DecodeNewImport(str, dedupGroup)
	-- Decode and decompress (if it's not a new import, the decode should fail)
	str = LibDeflate:DecodeForPrint(str)
	if not str then
		Log.Info("Not a valid new import string")
		return false
	end
	local numExtraBytes = nil
	str, numExtraBytes = LibDeflate:DecompressDeflate(str)
	if not str then
		Log.Err("Failed to decompress new import string")
		return false
	elseif numExtraBytes > 0 then
		Log.Err("Import string had extra bytes")
		return false
	end

	-- deserialize and validate the data
	local success, magicStr, version, groupName, items, groups, groupOperations, operations, customSources = LibSerialize:Deserialize(str)
	if not success then
		Log.Err("Failed to deserialize new import string")
		return false
	elseif magicStr ~= MAGIC_STR then
		Log.Err("Invalid magic string: "..tostring(magicStr))
		return false
	elseif version ~= VERSION then
		Log.Err("Invalid version: "..tostring(version))
		return false
	elseif type(groupName) ~= "string" or groupName == Group.GetRootPath() or Group.GetParent(groupName) ~= Group.GetRootPath() then
		Log.Err("Invalid groupName: "..tostring(groupName))
		return false
	elseif type(items) ~= "table" then
		Log.Err("Invalid items type: "..tostring(items))
		return false
	elseif type(groups) ~= "table" then
		Log.Err("Invalid groups type: "..tostring(groups))
		return false
	elseif type(groupOperations) ~= "table" then
		Log.Err("Invalid groupOperations type: "..tostring(groupOperations))
		return false
	elseif type(operations) ~= "table" then
		Log.Err("Invalid operations type: "..tostring(operations))
		return false
	elseif type(customSources) ~= "table" then
		Log.Err("Invalid customSources type: "..tostring(customSources))
		return false
	end

	-- validate the groups table
	for groupPath, trueValue in pairs(groups) do
		if not self:_IsValidGroupPath(groupPath) then
			Log.Err("Invalid groupPath (%s)", tostring(groupPath))
			return false
		elseif trueValue ~= true then
			Log.Err("Invalid true value (%s)", tostring(trueValue))
			return false
		end
	end
	for groupPath in pairs(groups) do
		local parentPath = Group.SplitPath(groupPath)
		while parentPath do
			if not groups[parentPath] then
				Log.Err("Orphaned group (%s)", groupPath)
				return false
			end
			parentPath = Group.SplitPath(parentPath)
		end
	end

	-- validate the items table
	local numInvalidItems = 0
	for itemString, groupPath in pairs(items) do
		if not self:_IsValidGroupPath(groupPath) then
			Log.Err("Invalid groupPath (%s, %s)", tostring(itemString), tostring(groupPath))
			return false
		elseif not groups[groupPath] then
			Log.Err("Invalid item group (%s, %s)", itemString, groupPath)
			return false
		end
		local newItemString = type(itemString) == "string" and ItemString.Get(itemString) or nil
		if itemString ~= newItemString then
			-- just remove this one item and continue
			Log.Warn("Invalid itemString (%s, %s)", tostring(itemString), tostring(newItemString))
			items[itemString] = nil
			numInvalidItems = numInvalidItems + 1
		end
	end
	if not next(items) and numInvalidItems > 0 then
		Log.Err("All items were invalid")
		return false
	end

	-- validate the customSources table
	for name, customSourceStr in pairs(customSources) do
		if type(name) ~= "string" or name == "" or gsub(name, "([a-z]+)", "") ~= "" then
			Log.Err("Invalid name (%s)", tostring(name))
			return false
		elseif type(str) ~= "string" then
			Log.Err("Invalid str (%s)", tostring(customSourceStr))
			return false
		end
	end

	-- validate the operations table
	local numChangedOperations = self:_ValidateOperationsTable(operations, true)
	if not numChangedOperations then
		return false
	end

	-- validate the groupOperations table
	if not self:_ValidateGroupOperationsTable(groupOperations, groups, operations, true) then
		return false
	end

	Log.Info("Decoded new import string")
	if dedupGroup then
		self._groupName = self:_DedupImportGroupName(groupName)
	else
		self._groupName = groupName
	end
	self._items = items
	self._groups = groups
	self._groupOperations = groupOperations
	self._operations = operations
	self._customSources = customSources
	return true, numInvalidItems, numChangedOperations
end

function GroupImport.__private:_DecodeOldImport(str, dedupGroup)
	if strsub(str, 1, 1) ~= "^" then
		Log.Info("Not an old import string")
		return false
	end

	local isValid, data = AceSerializer:Deserialize(str)
	if not isValid then
		Log.Err("Failed to deserialize")
		return false
	elseif type(data) ~= "table" then
		Log.Err("Invalid data type (%s)", tostring(data))
		return false
	elseif data.operations ~= nil and type(data.operations) ~= "table" then
		Log.Err("Invalid operations type (%s)", tostring(data.operations))
		return false
	elseif data.groupExport ~= nil and type(data.groupExport) ~= "string" then
		Log.Err("Invalid groupExport type (%s)", tostring(data.groupExport))
		return false
	elseif data.groupOperations ~= nil and type(data.groupOperations) ~= "table" then
		Log.Err("Invalid groupOperations type (%s)", tostring(data.groupOperations))
		return false
	elseif not data.operations and not data.groupExport then
		Log.Err("Doesn't contain operations or groupExport")
		return false
	end
	local operations, numChangedOperations = nil, 0
	if data.operations then
		numChangedOperations = self:_ValidateOperationsTable(data.operations, false)
		if not numChangedOperations then
			return false
		end
		operations = data.operations
	else
		operations = {}
	end
	local items, groups, numInvalidItems = nil, nil, nil
	if data.groupExport then
		items, groups, numInvalidItems = self:_DecodeGroupExportHelper(data.groupExport)
		if not items then
			Log.Err("No items found")
			return false
		end
	else
		items = {}
		groups = {}
		numInvalidItems = 0
	end
	local groupOperations = nil
	if data.groupOperations then
		Log.Info("Parsing group operations")
		local changeGroupPaths = TempTable.Acquire()
		for groupPath in pairs(data.groupOperations) do
			-- We export a "," in a group path as "``"
			local newGroupPath = type(groupPath) == "string" and gsub(groupPath, "``", ",")
			if newGroupPath and newGroupPath ~= groupPath then
				changeGroupPaths[groupPath] = newGroupPath
				if data.groupOperations[newGroupPath] then
					Log.Err("Duplicated group operations (%s, %s)", tostring(groupPath), tostring(newGroupPath))
					return false
				end
			end
		end
		for groupPath, newGroupPath in pairs(changeGroupPaths) do
			data.groupOperations[newGroupPath] = data.groupOperations[groupPath]
			data.groupOperations[groupPath] = nil
		end
		TempTable.Release(changeGroupPaths)
		if not self:_ValidateGroupOperationsTable(data.groupOperations, groups, operations, false) then
			Log.Err("Invalid group operations")
			return false
		end
		groupOperations = data.groupOperations
	else
		groupOperations = {}
	end

	-- check if there's a common top-level group within the import
	local commonTopLevelGroup = self:_GetCommonTopLevelGroup(items, groups, groupOperations)
	if commonTopLevelGroup then
		self:_UpdateTopLevelGroup(commonTopLevelGroup, items, groups, groupOperations)
	end

	Log.Info("Decoded old import string")
	if dedupGroup then
		self._groupName = self:_DedupImportGroupName(commonTopLevelGroup or self._defaultGroupName)
	else
		self._groupName = commonTopLevelGroup or self._defaultGroupName
	end
	self._items = items
	self._groups = groups
	self._groupOperations = groupOperations
	self._operations = operations
	self._customSources = {}
	return true, numInvalidItems, numChangedOperations
end

function GroupImport.__private:_DecodeOldGroupOrItemListImport(str, dedupGroup)
	local items, groups, numInvalidItems = self:_DecodeGroupExportHelper(str)
	if not items then
		Log.Err("No items found")
		return false
	end
	local groupOperations = {}

	-- check if there's a common top-level group within the import
	local commonTopLevelGroup = self:_GetCommonTopLevelGroup(items, groups, groupOperations)
	if commonTopLevelGroup then
		self:_UpdateTopLevelGroup(commonTopLevelGroup, items, groups, groupOperations)
	end

	Log.Info("Decoded old group or item list")
	if dedupGroup then
		self._groupName = self:_DedupImportGroupName(commonTopLevelGroup or self._defaultGroupName)
	else
		self._groupName = commonTopLevelGroup or self._defaultGroupName
	end
	self._items = items
	self._groups = groups
	self._groupOperations = groupOperations
	self._operations = {}
	self._customSources = {}
	return true, numInvalidItems, 0
end

function GroupImport.__private:_DecodeGroupExportHelper(str)
	local items, groups, numInvalidItems = nil, nil, 0
	if strmatch(str, "^[ip0-9%-:;]+$") then
		-- This is likely a list of itemStrings separated by semicolons instead of commas, so attempt to fix it
		str = gsub(str, ";", ",")
	end
	if strmatch(str, "^[0-9, ]+$") then
		-- This is likely a list of itemIds separated by commas, so attempt to fix it
		str = gsub(str, "[0-9]+", "i:%1")
	end
	local relativePath = Group.GetRootPath()
	for part in String.SplitIterator(str, ",") do
		part = strtrim(part)
		local groupPath = strmatch(part, "^group:(.+)$")
		local itemString = strmatch(part, "^[ip]?:?[0-9%-:]+$")
		local newItemString = itemString and ItemString.Get(itemString) or nil
		if newItemString and newItemString ~= itemString then
			itemString = newItemString
			numInvalidItems = numInvalidItems + 1
		end
		assert(not groupPath or not itemString)
		if groupPath then
			-- We export a "," in a group path as "``"
			groupPath = gsub(groupPath, "``", ",")
			if not self:_IsValidGroupPath(groupPath) then
				Log.Err("Invalid groupPath (%s)", tostring(groupPath))
				return
			end
			relativePath = groupPath
			groups = groups or {}
			-- Create the groups all the way up to the root
			while groupPath do
				groups[groupPath] = true
				groupPath = Group.GetParent(groupPath)
			end
		elseif itemString then
			items = items or {}
			groups = groups or {}
			groups[relativePath] = true
			items[itemString] = relativePath
		else
			Log.Err("Unknown part: %s", part)
			return
		end
	end
	return items, groups, numInvalidItems
end

function GroupImport.__private:_ValidateOperationsTable(operations, strict)
	local numChangedOperations = 0
	for moduleName, moduleOperations in pairs(operations) do
		if not self:_IsValidOperationType(moduleName) then
			Log.Err("Invalid module name")
			return nil
		elseif self._ignoredOperationTypes[moduleName] then
			if strict then
				Log.Err("Invalid moduleName (%s)", tostring(moduleName))
				return nil
			else
				Log.Warn("Ignoring module (%s)", moduleName)
				operations[moduleName] = nil
				wipe(moduleOperations)
			end
		elseif type(moduleOperations) ~= "table" then
			Log.Err("Invalid moduleOperations type (%s)", tostring(moduleOperations))
			return nil
		end
		for operationName, operationSettings in pairs(moduleOperations) do
			if type(operationName) ~= "string" or not Operation.IsValidName(operationName) then
				Log.Err("Invalid operationName (%s)", tostring(operationName))
				return nil
			elseif type(operationSettings) ~= "table" then
				Log.Err("Invalid operationSettings type (%s)", tostring(operationSettings))
				return nil
			end
			-- Sanitize the operation settings
			if Operation.SanitizeSettings(moduleName, operationName, operationSettings, true, true) then
				numChangedOperations = numChangedOperations + 1
			end
		end
	end
	return numChangedOperations
end

function GroupImport.__private:_ValidateGroupOperationsTable(groupOperations, groups, operations, strict)
	for groupPath, groupsOperationsTable in pairs(groupOperations) do
		if not self:_IsValidGroupPath(groupPath) then
			Log.Err("Invalid groupPath (%s)", tostring(groupPath))
			return false
		elseif not groups[groupPath] then
			if strict then
				Log.Err("Invalid group (%s)", groupPath)
				return false
			else
				Log.Info("Creating group with operations (%s)", groupPath)
				groups[groupPath] = true
			end
		end
		-- remove legacy fields
		groupsOperationsTable.ignoreItemVariations = nil
		for moduleName, moduleOperations in pairs(groupsOperationsTable) do
			if not self:_IsValidOperationType(moduleName) then
				Log.Err("Invalid module name")
				return false
			elseif self._ignoredOperationTypes[moduleName] then
				if strict then
					Log.Err("Invalid operation type (%s)", tostring(moduleName))
					return false
				else
					Log.Warn("Ignoring module (%s)", moduleName)
					groupsOperationsTable[moduleName] = nil
					wipe(moduleOperations)
				end
			elseif type(moduleOperations) ~= "table" then
				Log.Err("Invalid moduleOperations type (%s)", tostring(moduleOperations))
				return false
			elseif moduleOperations.override ~= nil and moduleOperations.override ~= true then
				Log.Err("Invalid moduleOperations override type (%s)", tostring(moduleOperations.override))
				return false
			elseif groupPath == Group.GetRootPath() and not moduleOperations.override then
				if strict then
					Log.Err("Top-level group does not have override set")
					return false
				else
					Log.Info("Setting override for top-level group")
					moduleOperations.override = true
				end
			end
			local numOperations = #moduleOperations
			if numOperations > Operation.GetMaxNumber(moduleName) then
				Log.Err("Too many operations (%s, %s, %d)", groupPath, moduleName, numOperations)
				return false
			end
			for k, v in pairs(moduleOperations) do
				if k == "override" then
					-- pass
				elseif type(k) ~= "number" or k < 1 or k > numOperations then
					Log.Err("Unknown key (%s, %s, %s, %s)", groupPath, moduleName, tostring(k), tostring(v))
					return false
				elseif type(v) ~= "string" then
					Log.Err("Invalid value (%s, %s, %s, %s)", groupPath, moduleName, k, tostring(v))
					return false
				end
			end
			-- some old imports had "" operations attached to groups, so remove them
			for i = #moduleOperations, 1, -1 do
				if moduleOperations[i] == "" then
					tremove(moduleOperations, i)
				end
			end
			for _, operationName in ipairs(moduleOperations) do
				if type(operationName) ~= "string" or not Operation.IsValidName(operationName) then
					Log.Err("Invalid operationName (%s)", tostring(operationName))
					return false
				elseif not operations[moduleName][operationName] then
					Log.Err("Unknown operation (%s)", operationName)
					return false
				end
			end
		end
	end
	return true
end

function GroupImport.__private:_DedupImportGroupName(groupName)
	if Group.Exists(groupName) then
		local num = 1
		while Group.Exists(groupName.." "..num) do
			num = num + 1
		end
		groupName = groupName.." "..num
	end
	return groupName
end

function GroupImport.__private:_IsValidGroupPath(groupPath)
	return type(groupPath) == "string" and not strmatch(groupPath, "^`") and not strmatch(groupPath, "`$") and not strmatch(groupPath, "``")
end

function GroupImport.__private:_IsValidOperationType(operationType)
	if type(operationType) ~= "string" or not Operation.TypeExists(operationType) then
		Log.Err("Invalid operationType (%s)", tostring(operationType))
		return false
	end
	return true
end

function GroupImport.__private:_GetCommonTopLevelGroup(items, groups, groupOperations)
	local commonTopLevelGroup = nil

	-- check the items
	for _, groupPath in pairs(items) do
		if groupPath == Group.GetRootPath() then
			return nil
		end
		local topLevelGroup = Group.GetTopLevel(groupPath)
		if not commonTopLevelGroup then
			commonTopLevelGroup = topLevelGroup
		elseif topLevelGroup ~= commonTopLevelGroup then
			return nil
		end
	end

	-- check the groups
	for groupPath in pairs(groups) do
		if groupPath ~= Group.GetRootPath() then
			local topLevelGroup = Group.GetTopLevel(groupPath)
			if not commonTopLevelGroup then
				commonTopLevelGroup = topLevelGroup
			elseif topLevelGroup ~= commonTopLevelGroup then
				return nil
			end
		end
	end

	-- check the groupOperations
	for groupPath in pairs(groupOperations) do
		if groupPath == Group.GetRootPath() then
			return nil
		end
		local topLevelGroup = Group.GetTopLevel(groupPath)
		if not commonTopLevelGroup then
			commonTopLevelGroup = topLevelGroup
		elseif topLevelGroup ~= commonTopLevelGroup then
			return nil
		end
	end

	return commonTopLevelGroup
end

function GroupImport.__private:_UpdateTopLevelGroup(topLevelGroup, items, groups, groupOperations)
	-- update items
	for itemString, groupPath in pairs(items) do
		items[itemString] = Group.GetRelativePath(groupPath, topLevelGroup)
	end

	-- update groups
	local newGroups = TempTable.Acquire()
	groups[Group.GetRootPath()] = nil
	for groupPath in pairs(groups) do
		newGroups[Group.GetRelativePath(groupPath, topLevelGroup)] = true
	end
	wipe(groups)
	for groupPath in pairs(newGroups) do
		groups[groupPath] = true
	end
	TempTable.Release(newGroups)

	-- update groupOperations
	local newGroupOperations = TempTable.Acquire()
	for groupPath, groupOperationsTable in pairs(groupOperations) do
		newGroupOperations[Group.GetRelativePath(groupPath, topLevelGroup)] = groupOperationsTable
	end
	wipe(groupOperations)
	for groupPath, groupOperationsTable in pairs(newGroupOperations) do
		groupOperations[groupPath] = groupOperationsTable
	end
	TempTable.Release(newGroupOperations)

	-- set override on new top-level group
	if groupOperations[Group.GetRootPath()] then
		for _, moduleOperations in pairs(groupOperations[Group.GetRootPath()]) do
			moduleOperations.override = true
		end
	end
end
