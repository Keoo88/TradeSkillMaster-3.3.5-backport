-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Operation = LibTSMTypes:Init("Operation")
local Util = LibTSMTypes:Include("Operation.Util")
local OperationType = LibTSMTypes:IncludeClassType("OperationType")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local Database = LibTSMTypes:From("LibTSMUtil"):Include("Database")
local Iterator = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("Iterator")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local private = {
	db = nil,
	customStringSettingIter = nil,
	shouldCreateDefault = nil,
	characterKey = nil,
	factionrealm = nil,
	settings = nil, ---@type table<string,table<string,OperationSettings>>
	types = {}, ---@type table<string,OperationType>|OperationType[]
	relationshipTemp = {},
	uuidsTemp = {},
}
local DEFAULT_OPERATION_NAME = "#Default"



-- ============================================================================
-- Module Loading
-- ============================================================================

Operation:OnModuleLoad(function()
	private.db = Database.NewSchema("OPERATIONS")
		:AddStringField("moduleName")
		:AddStringField("operationName")
		:AddIndex("moduleName")
		:Commit()
	private.customStringSettingIter = Iterator.New()
		:SetFilterFunc(function(operationType, key) return operationType:IsCustomString(key) end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new operation type.
---@param name string The internal name
---@param localizedName string The localized name
---@param maxOperations number The maximum operations of this type which can be added to a group
---@return OperationType
function Operation.NewType(name, localizedName, maxOperations)
	return OperationType.New(name, localizedName, maxOperations)
end

---Returns whether or not an operation name is valid.
---@param name string The operation name
---@return boolean
function Operation.IsValidName(name)
	return Util.IsValidOperationName(name)
end

---Iterates over the common setting keys.
---@return fun(): string @Iterator with fields: `settingKey`
function Operation.CommonSettingKeyIterator()
	return OperationType.CommonSettingKeyIterator()
end

---Iterates over the custom string setting keys.
---@param typeName string The operation type
---@return fun(): string @Iterator with fields: `settingKey`
function Operation.CustomStringSettingKeyIterator(typeName)
	local operationType = private.types[typeName]
	return private.customStringSettingIter:ExecuteWithContext(operationType, operationType:SettingIterator())
end

---Loads operation settings.
---@param settings table<string,OperationSettings>
function Operation.Load(settings)
	local didUpdate = private.settings and true or false
	private.settings = settings
	if didUpdate then
		-- Settings changed, so validate the new settings
		for _, operationType in ipairs(private.types) do
			local typeName = operationType:GetName()
			if private.settings[typeName] then
				private.ValidateOperations(typeName)
			else
				private.settings[typeName] = {}
				-- Create default operation
				Operation.Create(typeName, DEFAULT_OPERATION_NAME)
			end
		end
	end
	private.RebuildDB()
end

---Sets the current player info.
---@param characterKey string The character key
---@param factionrealm string The factionrealm
function Operation.SetPlayerInfo(characterKey, factionrealm)
	private.characterKey = characterKey
	private.factionrealm = factionrealm
end

---Sets whether or not default operations should be created when operation types are registered.
---@param createDefault boolean Whether to create default operations
function Operation.SetShouldCreateDefault(createDefault)
	assert(type(createDefault) == "boolean")
	private.shouldCreateDefault = createDefault
end

---Registers an operation type.
---@param operationType OperationType The operation type
function Operation.RegisterType(operationType)
	assert(type(private.shouldCreateDefault) == "boolean")
	local name = operationType:GetName()
	private.types[name] = operationType
	tinsert(private.types, operationType)

	local shouldCreateDefaultOperations = private.shouldCreateDefault or not private.settings[name]
	private.settings[name] = private.settings[name] or {}

	if shouldCreateDefaultOperations and not private.settings[name][DEFAULT_OPERATION_NAME] then
		-- Create default operation
		Operation.Create(name, DEFAULT_OPERATION_NAME)
	end
	private.ValidateOperations(name)
	private.RebuildDB()
end

---Creates a new DB query.
---@return DatabaseQuery
function Operation.NewQuery()
	return private.db:NewQuery()
end

---Returns whether or not an operation type exists.
---@param typeName string The type of the operation
---@return boolean
function Operation.TypeExists(typeName)
	return private.types[typeName] and true or false
end

---Gets the localized name of an operation type.
---@param typeName string The operation type
---@return string
function Operation.GetLocalizedName(typeName)
	return private.types[typeName]:GetLocalizedName()
end

---Gets the max number of operations of a type.
---@param typeName string The operation type
---@return number
function Operation.GetMaxNumber(typeName)
	return private.types[typeName]:GetMaxNumber()
end

---Iterates over the operation types.
---@return fun(): number, string @Iterator with fields: `index`, `typeName`
function Operation.TypeIterator()
	local result = TempTable.Acquire()
	for _, operationType in ipairs(private.types) do
		tinsert(result, operationType:GetName())
	end
	return TempTable.Iterator(result)
end

---Creates a new operation of the specified type.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
function Operation.Create(typeName, operationName)
	local typeSettings = private.settings[typeName]
	assert(private.types[typeName] and not typeSettings[operationName])
	typeSettings[operationName] = {}
	Operation.Reset(typeName, operationName)
	private.db:NewRow()
		:SetField("moduleName", typeName)
		:SetField("operationName", operationName)
		:Create()
end

---Imports a collection of operations.
---@param operations table<string,table<string,OperationSettings>> The operations to import
---@param replaceExisting boolean Whether or not to replace existing operations with the same name
function Operation.Import(operations, replaceExisting)
	for typeName, moduleOperations in pairs(operations) do
		local typeSettings = private.settings[typeName]
		for operationName, settings in pairs(moduleOperations) do
			assert(replaceExisting or not typeSettings[operationName])
			typeSettings[operationName] = settings
		end
	end
	private.RebuildDB()
end

---Renames an operation.
---@param typeName string The type of the operation
---@param oldName string The current name of the operation
---@param newName string The new name of the operation
function Operation.Rename(typeName, oldName, newName)
	local typeSettings = private.settings[typeName]
	assert(typeSettings[oldName] and not typeSettings[newName])
	typeSettings[newName] = typeSettings[oldName]
	typeSettings[oldName] = nil

	-- Redirect relationships
	for _, settings in pairs(typeSettings) do
		for key, target in pairs(settings.relationships) do
			if target == oldName then
				settings.relationships[key] = newName
			end
		end
	end

	-- Update the DB
	private.db:NewQuery()
		:Equal("moduleName", typeName)
		:Equal("operationName", oldName)
		:GetSingleResultAndRelease()
		:SetField("operationName", newName)
		:Update()
		:Release()
end

---Copies operation settings from one operation to another.
---@param typeName string The type of the operations
---@param operationName string The name of the operation to copy into
---@param sourceOperationName string The name of the operation to copy from
function Operation.Copy(typeName, operationName, sourceOperationName)
	local destinationSettings = private.settings[typeName][operationName]
	local sourceSettings = private.settings[typeName][sourceOperationName]
	assert(destinationSettings and sourceSettings)
	for key in private.types[typeName]:SettingIterator() do
		local sourceValue = sourceSettings[key]
		destinationSettings[key] = type(sourceValue) == "table" and CopyTable(sourceValue) or sourceValue
	end
	-- TODO: Should also check for circular relationships?
	private.RemoveDeadRelationships(typeName)
end

---Deletes an operation or list of operations.
---@param typeName string The type of the operation
---@param operationName string|string[] The name of the operation(s)
function Operation.Delete(typeName, operationNames)
	assert(#private.uuidsTemp == 0)
	if type(operationNames) == "table" then
		for _, operationName in ipairs(operationNames) do
			tinsert(private.uuidsTemp, private.DeleteOperation(typeName, operationName))
		end
	else
		tinsert(private.uuidsTemp, private.DeleteOperation(typeName, operationNames))
	end

	-- Update the DB
	private.db:BulkDelete(private.uuidsTemp)
	wipe(private.uuidsTemp)
end

---Resets operation settings to their default values.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param key string|nil The setting key to reset or nil to reset all settings
function Operation.Reset(typeName, operationName, key)
	local operationType = private.types[typeName]
	local settings = private.settings[typeName][operationName]
	if key then
		assert(operationType:HasSetting(key))
		settings[key] = operationType:GetDefault(key)
	else
		for iterKey in operationType:SettingIterator() do
			settings[iterKey] = operationType:GetDefault(iterKey)
		end
	end
end

---Iterates over the available operations by name.
---@param typeName string The type of the operations to iterate over
---@return fun(): number, string @Iterator with fields: `index`, `operationName`
function Operation.Iterator(typeName)
	local operations = TempTable.Acquire()
	for operationName in pairs(private.settings[typeName]) do
		tinsert(operations, operationName)
	end
	sort(operations)
	return TempTable.Iterator(operations)
end

---Returns whether or not an operation exists.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@return boolean
function Operation.Exists(typeName, operationName)
	return private.settings[typeName][operationName] and true or false
end

---Gets a deduplicated name for a new operation.
---@param typeName string The type of the operation
---@param operationName string The desired name of the operation
---@return string
function Operation.GetDeduplicatedName(typeName, operationName)
	if not Operation.Exists(typeName, operationName) then
		return operationName
	end
	local num = 1
	local testName = operationName.." "..num
	while Operation.Exists(typeName, testName) do
		num = num + 1
		testName = operationName.." "..num
	end
	return testName
end

---Updates the operation settings based on any set relationships.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
function Operation.UpdateFromRelationships(typeName, operationName)
	local operationSettings = private.settings[typeName][operationName]
	for key in pairs(operationSettings.relationships) do
		local sourceSettings = operationSettings
		while operationSettings.relationships[key] do
			local newSettings = private.settings[typeName][sourceSettings.relationships[key]]
			if not newSettings then
				break
			end
			sourceSettings = newSettings
		end
		operationSettings[key] = sourceSettings[key]
	end
end

---Gets the operation settings.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@return OperationSettings
function Operation.GetSettings(typeName, operationName)
	local settings = private.settings[typeName][operationName]
	assert(settings)
	return settings
end

---Sanitizes the operation settings.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param operationSettings OperationSettings The operation settings
---@param silentMissingCommonKeys boolean
---@param noRelationshipCheck boolean
---@return boolean
function Operation.SanitizeSettings(typeName, operationName, operationSettings, silentMissingCommonKeys, noRelationshipCheck)
	local didReset = private.types[typeName]:SanitizeOperation(operationName, operationSettings, silentMissingCommonKeys)
	for key in pairs(operationSettings) do
		if not noRelationshipCheck and Operation.IsCircularRelationship(typeName, operationName, key) then
			Log.Err("Removing circular relationship (%s, %s, %s)", typeName, operationName, key)
			operationSettings.relationships[key] = nil
		end
	end
	return didReset
end

---Returns whether or not a circular relationship exists.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param key string The setting key
---@return boolean
function Operation.IsCircularRelationship(typeName, operationName, key)
	assert(not next(private.relationshipTemp))
	local visited = private.relationshipTemp
	while operationName do
		if visited[operationName] then
			wipe(visited)
			return true
		end
		visited[operationName] = true
		operationName = Operation.GetRelationship(typeName, operationName, key)
	end
	wipe(visited)
	return false
end

---Returns whether or not a relationship can be added between two operations.
---@param typeName string The type of the operation
---@param sourceOperationName string The name of the source operation
---@param targetOperationName string The name of the target operation
---@param key string The setting key
---@return boolean
function Operation.CanAddRelationship(typeName, sourceOperationName, targetOperationName, key)
	if sourceOperationName == targetOperationName then
		return false
	end
	assert(not next(private.relationshipTemp))
	local visited = private.relationshipTemp
	visited[sourceOperationName] = true
	local operationName = targetOperationName
	while operationName do
		if visited[operationName] then
			wipe(visited)
			return false
		end
		visited[operationName] = true
		operationName = Operation.GetRelationship(typeName, operationName, key)
	end
	wipe(visited)
	return true
end

---Returns whether or not a relationship exists.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param key string The setting key
---@return boolean
function Operation.HasRelationship(typeName, operationName, key)
	return Operation.GetRelationship(typeName, operationName, key) and true or false
end

---Set a relationship.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param key string The setting key
---@param targetOperationName string The name of the target operation
function Operation.SetRelationship(typeName, operationName, key, targetOperationName)
	assert(targetOperationName == nil or private.settings[typeName][targetOperationName])
	assert(private.types[typeName]:HasSetting(key))
	local settings = Operation.GetSettings(typeName, operationName)
	settings.relationships[key] = targetOperationName
end

---Get the existing relationship (or nil if none is set).
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@param key string The setting key
---@return string?
function Operation.GetRelationship(typeName, operationName, key)
	assert(private.types[typeName]:HasSetting(key))
	local settings = Operation.GetSettings(typeName, operationName)
	return settings.relationships[key]
end

---Returns whether or not an operation is ignored by the current player.
---@param typeName string The type of the operation
---@param operationName string The name of the operation
---@return boolean
function Operation.IsIgnored(typeName, operationName)
	local operationSettings = Operation.GetSettings(typeName, operationName)
	return operationSettings.ignorePlayer[private.characterKey] or operationSettings.ignoreFactionrealm[private.factionrealm]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RebuildDB()
	private.db:TruncateAndBulkInsertStart()
	for typeName, operations in pairs(private.settings) do
		for operationName in pairs(operations) do
			private.db:BulkInsertNewRow(typeName, operationName)
		end
	end
	private.db:BulkInsertEnd()
end

function private.ValidateOperations(typeName)
	local typeSettings = private.settings[typeName]
	for operationName, settings in pairs(typeSettings) do
		if type(operationName) ~= "string" or not Util.IsValidOperationName(operationName) then
			Log.Err("Removing %s operation with invalid name: %s", typeName, tostring(operationName))
			typeSettings[operationName] = nil
		else
			Operation.SanitizeSettings(typeName, operationName, settings)
		end
	end
	private.RemoveDeadRelationships(typeName)
end

function private.DeleteOperation(typeName, operationName)
	local typeSettings = private.settings[typeName]
	assert(typeSettings[operationName])
	typeSettings[operationName] = nil
	private.RemoveDeadRelationships(typeName)
	local row = private.db:NewQuery()
		:Equal("moduleName", typeName)
		:Equal("operationName", operationName)
		:GetSingleResultAndRelease()
	local uuid = row:GetUUID()
	row:Release()
	return uuid
end

function private.RemoveDeadRelationships(typeName)
	local typeSettings = private.settings[typeName]
	for _, operation in pairs(typeSettings) do
		for key, target in pairs(operation.relationships) do
			if not typeSettings[target] then
				operation.relationships[key] = nil
			end
		end
	end
end
