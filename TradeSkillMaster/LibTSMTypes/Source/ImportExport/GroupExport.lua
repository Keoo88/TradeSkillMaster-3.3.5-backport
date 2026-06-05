-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GroupExport = LibTSMTypes:DefineClassType("GroupExport")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Operation = LibTSMTypes:Include("Operation")
local Group = LibTSMTypes:Include("Group")
local GroupOperation = LibTSMTypes:Include("GroupOperation")
local CustomString = LibTSMTypes:Include("CustomString")
local LibDeflate = LibStub("LibDeflate")
local LibSerialize = LibStub("LibSerialize")
local private = {
	isOperationSettingsTable = {},
	commonSettingKeys = {},
}
local MAGIC_STR = "TSM_EXPORT"
local VERSION = 1
local SERIALIZE_OPTIONS = {
	stable = true,
	filter = function(tbl, key)
		return not private.isOperationSettingsTable[tbl] or not private.commonSettingKeys[key]
	end,
}
local EMPTY_OPERATIONS = {}
local EMPTY_GROUP_OPERATIONS = {}
local EMPTY_CUSTOM_SOURCES = {}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new group export object.
---@param ignoredOperationTypes string[] A list of operation types to exlucde from the export
---@return GroupExport
function GroupExport.__static.New(ignoredOperationTypes)
	if not next(private.commonSettingKeys) then
		for key in Operation.CommonSettingKeyIterator() do
			private.commonSettingKeys[key] = true
		end
	end
	local obj = GroupExport()
	obj:_Configure(ignoredOperationTypes)
	obj:Reset()
	return obj
end

---Generates a group export string.
---@param groupName name The name of the group
---@param items table<string,GroupPathValue> The items
---@param groups table<GroupPathValue,boolean> The groups
---@param groupOperations? table<GroupPathValue,table> The group operations
---@param operations? table<string,table<string,OperationSettings>> The operations and their settings
---@param customSources? table<string,string> The custom sources
---@return string
function GroupExport.__static.GenerateString(groupName, items, groups, groupOperations, operations, customSources)
	groupOperations = groupOperations or EMPTY_GROUP_OPERATIONS
	operations = operations or EMPTY_OPERATIONS
	customSources = customSources or EMPTY_CUSTOM_SOURCES
	assert(not next(private.isOperationSettingsTable))
	for _, moduleOperations in pairs(operations) do
		for _, operationSettings in pairs(moduleOperations) do
			private.isOperationSettingsTable[operationSettings] = true
		end
	end
	local serialized = LibSerialize:SerializeEx(SERIALIZE_OPTIONS, MAGIC_STR, VERSION, groupName, items, groups, groupOperations, operations, customSources)
	wipe(private.isOperationSettingsTable)
	local str = LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
	collectgarbage()
	return str
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function GroupExport.__private:__init()
	self._ignoredOperationTypes = nil
	self._groupPath = nil
	self._includedSubGroups = {}
	self._includeOperations = false
	self._includeCustomSources = false
	self._exportValid = false
	self._groups = {}
	self._items = {}
	self._operations = {}
	self._groupOperations = {}
	self._customSources = {}
	self._str = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Resets the export context.
function GroupExport:Reset()
	assert(self._ignoredOperationTypes)
	self._groupPath = nil
	wipe(self._includedSubGroups)
	self._includeOperations = false
	self._includeCustomSources = false
	self._exportValid = false
	for typeName in pairs(self._operations) do
		if not Operation.TypeExists(typeName) or self._ignoredOperationTypes[typeName] then
			self._operations[typeName] = nil
		end
	end
	for _, typeName in Operation.TypeIterator() do
		if not self._ignoredOperationTypes[typeName] then
			self._operations[typeName] = self._operations[typeName] or {}
			wipe(self._operations[typeName])
		end
	end
	wipe(self._groupOperations)
	wipe(self._customSources)
	self._str = nil
	collectgarbage()
end

---Sets the group path.
---@param groupPath GroupPathValue The group path to export
function GroupExport:SetPath(groupPath)
	assert(self._ignoredOperationTypes)
	assert(Group.Exists(groupPath) and groupPath ~= Group.GetRootPath())
	if groupPath == self._groupPath then
		return
	end
	self._groupPath = groupPath
	self._exportValid = false
end

---Sets the subgroups to include in the export.
---@param subGroups table<GroupPathValue, true> Relative group paths to include as keys
function GroupExport:SetSubGroupsIncluded(subGroups)
	assert(self._ignoredOperationTypes and self._groupPath)
	if Table.Equal(self._includedSubGroups, subGroups) then
		return
	end
	wipe(self._includedSubGroups)
	for relativeGroupPath in pairs(subGroups) do
		assert(Group.Exists(Group.JoinPath(self._groupPath, relativeGroupPath)))
		self._includedSubGroups[relativeGroupPath] = true
	end
	self._exportValid = false
end

---Sets whether or not operations are included in the export.
---@param includeOperations boolean Whether or not to include operations
---@param includeCustomSources boolean Whether or not to include custom sources (requires includeOperations)
function GroupExport:SetOperationsIncluded(includeOperations, includeCustomSources)
	assert(self._ignoredOperationTypes and self._groupPath)
	assert(includeOperations or not includeCustomSources)
	assert(type(includeOperations) == "boolean" and type(includeCustomSources) == "boolean")
	if includeOperations ~= self._includeOperations then
		self._includeOperations = includeOperations
		self._str = nil
	end
	if includeCustomSources ~= self._includeCustomSources then
		self._includeCustomSources = includeCustomSources
		if not self._exportValid or next(self._customSources) then
			self._str = nil
		end
	end
end

---Gets the export string.
---@return string
function GroupExport:GetString()
	self:_Execute()
	return self._str
end

---Gets the number of items included in the export
---@return number
function GroupExport:GetNumItems()
	self:_Execute()
	return Table.Count(self._items)
end

---Gets the number of subgroups included in the export
---@return number
function GroupExport:GetNumSubGroups()
	self:_Execute()
	return Table.Count(self._groups) - 1
end

---Gets the number of operations included in the export
---@return number
function GroupExport:GetNumOperations()
	self:_Execute()
	local num = 0
	for _, moduleOperations in pairs(self._operations) do
		num = num + Table.Count(moduleOperations)
	end
	return num
end

---Gets the number of custom sources included in the export
---@return number
function GroupExport:GetNumCustomSources()
	self:_Execute()
	return Table.Count(self._customSources)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function GroupExport.__private:_Configure(ignoredOperationTypes)
	assert(not self._ignoredOperationTypes)
	self._ignoredOperationTypes = {}
	for _, typeName in ipairs(ignoredOperationTypes) do
		self._ignoredOperationTypes[typeName] = true
	end
end

function GroupExport.__private:_Execute()
	assert(self._groupPath)
	if not self._exportValid then
		self:_Export()
		self._str = nil
	end
	if not self._str then
		self:_UpdateString()
	end
end

function GroupExport.__private:_Export()
	self:_ExportGroups()
	self:_ExportOperations()
	self:_ExportCustomSources()
	self._exportValid = true
end

function GroupExport.__private:_ExportGroups()
	wipe(self._groups)
	wipe(self._items)
	Group.Export(self._groupPath, self._includedSubGroups, self._groups, self._items)
end

function GroupExport.__private:_ExportOperations()
	for _, operations in pairs(self._operations) do
		wipe(operations)
	end
	wipe(self._groupOperations)
	for relGroupPath in pairs(self._groups) do
		local groupPath = relGroupPath == Group.GetRootPath() and self._groupPath or Group.JoinPath(self._groupPath, relGroupPath)
		self._groupOperations[relGroupPath] = {}
		for _, moduleName in Operation.TypeIterator() do
			if not self._ignoredOperationTypes[moduleName] then
				self._groupOperations[relGroupPath][moduleName] = {
					-- Always override at the top-level
					override = GroupOperation.HasOverride(groupPath, moduleName) or groupPath == self._groupPath or nil,
				}
				for _, operationName in GroupOperation.Iterator(groupPath, moduleName) do
					Operation.UpdateFromRelationships(moduleName, operationName)
					if not Operation.IsIgnored(moduleName, operationName) then
						local operationSettings = Operation.GetSettings(moduleName, operationName)
						tinsert(self._groupOperations[relGroupPath][moduleName], operationName)
						self._operations[moduleName][operationName] = operationSettings
					end
				end
			end
		end
	end
	return self._operations, self._groupOperations
end

function GroupExport.__private:_ExportCustomSources()
	wipe(self._customSources)
	for moduleName, moduleOperations in pairs(self._operations) do
		for _, operationSettings in pairs(moduleOperations) do
			for key in Operation.CustomStringSettingKeyIterator(moduleName) do
				self:_GetCustomSources(operationSettings[key])
			end
		end
	end
end

function GroupExport.__private:_GetCustomSources(str)
	for _, name, customSourceStr in CustomString.DependantCustomSourceIterator(str) do
		if not self._customSources[name] then
			self._customSources[name] = customSourceStr
			self:_GetCustomSources(customSourceStr)
		end
	end
end

function GroupExport.__private:_UpdateString()
	if self._includeOperations and self._includeCustomSources then
		self._str = GroupExport.GenerateString(Group.GetName(self._groupPath), self._items, self._groups, self._groupOperations, self._operations, self._customSources)
	elseif self._includeOperations then
		self._str = GroupExport.GenerateString(Group.GetName(self._groupPath), self._items, self._groups, self._groupOperations, self._operations)
	else
		assert(not self._includeCustomSources)
		self._str = GroupExport.GenerateString(Group.GetName(self._groupPath), self._items, self._groups)
	end
end
