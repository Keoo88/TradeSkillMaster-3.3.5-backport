-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local SettingsSchema = LibTSMTypes:DefineClassType("SettingsSchema")
local Types = LibTSMTypes:Include("Settings.Types")
local Hash = LibTSMTypes:From("LibTSMUtil"):Include("Util.Hash")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local private = {}
local PATH_SEP = "/"



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new schema object.
---@param version number The current version
---@param minVersion number The minimum version
---@return SettingsSchema
function SettingsSchema.__static.New(version, minVersion)
	assert(type(version) == "number" and type(minVersion) == "number" and minVersion >= 1 and version >= minVersion)
	return SettingsSchema(version, minVersion)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function SettingsSchema.__private:__init(version, minVersion)
	self._version = version
	self._minVersion = minVersion
	self._scope = nil
	self._namespace = nil
	self._condition = nil
	self._type = {}
	self._defaultValue = {}
	self._lastModifiedVersion = {}
	self._committedHash = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Enters a new scope.
---@param scopeName ScopeName The name of the scope
function SettingsSchema:EnterScope(scopeName)
	assert(not self._committedHash)
	assert(not self._scope and not self._namespace)
	assert(Types.SCOPES[scopeName])
	self._scope = Types.SCOPES[scopeName]
	return self
end

---Enters a new namespace.
---@param namespace string The name of the namespace
---@return SettingsSchema
function SettingsSchema:EnterNamespace(namespace)
	assert(not self._committedHash)
	assert(self._scope and not self._namespace)
	assert(type(namespace) == "string" and strmatch(namespace, "^[A-Za-z0-9]+$"))
	self._namespace = namespace
	return self
end

---Leaves the current namespace.
---@return SettingsSchema
function SettingsSchema:LeaveNamespace()
	assert(not self._committedHash)
	assert(self._namespace and self._condition == nil)
	self._namespace = nil
	return self
end

---Leaves the current scope.
---@return SettingsSchema
function SettingsSchema:LeaveScope()
	assert(not self._committedHash)
	assert(self._scope and not self._namespace and self._condition == nil)
	self._scope = nil
	return self
end

---Adds a boolean setting to the current scope and namespace.
---@param key string The setting key
---@param defaultValue boolean The default value
---@param lastModifiedVersion number The last modified version
---@return SettingsSchema
function SettingsSchema:AddBoolean(key, defaultValue, lastModifiedVersion)
	self:_AddKey("boolean", key, defaultValue, lastModifiedVersion)
	return self
end

---Adds a string setting to the current scope and namespace.
---@param key string The setting key
---@param defaultValue string The default value
---@param lastModifiedVersion number The last modified version
---@return SettingsSchema
function SettingsSchema:AddString(key, defaultValue, lastModifiedVersion)
	self:_AddKey("string", key, defaultValue, lastModifiedVersion)
	return self
end

---Adds a number setting to the current scope and namespace.
---@param key string The setting key
---@param defaultValue number The default value
---@param lastModifiedVersion number The last modified version
---@return SettingsSchema
function SettingsSchema:AddNumber(key, defaultValue, lastModifiedVersion)
	self:_AddKey("number", key, defaultValue, lastModifiedVersion)
	return self
end

---Adds a table setting to the current scope and namespace.
---@param key string The setting key
---@param defaultValue table The default value
---@param lastModifiedVersion number The last modified version
---@return SettingsSchema
function SettingsSchema:AddTable(key, defaultValue, lastModifiedVersion)
	private.CheckDefaultTable(defaultValue)
	self:_AddKey("table", key, defaultValue, lastModifiedVersion)
	return self
end

---Adds a if condition to the following setting keys being added.
---@param condition boolean The condition
---@return SettingsSchema
function SettingsSchema:If(condition)
	assert(type(condition) == "boolean")
	assert(self._scope and self._namespace)
	self._condition = condition
	return self
end

---Ends the current condition.
---@return SettingsSchema
function SettingsSchema:EndIf()
	assert(self._condition ~= nil)
	self._condition = nil
	return self
end

---Commits the schema.
---@return SettingsSchema
function SettingsSchema:Commit()
	assert(not self._committedHash)
	assert(not self._scope and not self._namespace and self._condition == nil)
	local hashDataParts = TempTable.Acquire()
	for path, settingType in pairs(self._type) do
		local scope, namespace, key = strsplit(PATH_SEP, path)
		local defaultValue = self._defaultValue[path]
		tinsert(hashDataParts, strjoin(",", key, Table.KeyByValue(Types.SCOPES, scope), namespace, settingType, type(defaultValue) == "table" and "table" or tostring(defaultValue)))
	end
	sort(hashDataParts)
	self._committedHash = Hash.Calculate(table.concat(hashDataParts, ";"))
	TempTable.Release(hashDataParts)
	return self
end

---Gets the version.
---@return number
function SettingsSchema:GetVersion()
	return self._version
end

---Gets the minimum version.
---@return number
function SettingsSchema:GetMinimumVersion()
	return self._minVersion
end

---Gets the hash.
---@return number
function SettingsSchema:GetHash()
	assert(self._committedHash)
	return self._committedHash
end

---Iterates over the registered settings.
---@return fun(): string, ScopeKey, string, string @Iterator with fields `path`, `scopeKey`, `namespace`, `key`
function SettingsSchema:Iterator()
	assert(self._committedHash)
	return private.IteratorHelper, self
end

---Iterates over the registered settings for the specified scope.
---@param scopeKey ScopeKey The scope key
---@return fun(): string, string, string @Iterator with fields `path`, `namespace`, `key`
function SettingsSchema:IteratorForScope(scopeKey)
	assert(self._committedHash)
	return private.IteratorForScopeHelper, self, scopeKey
end

---Creates a path for the specified setting from its components.
---@param scopeKey ScopeKey The scope key
---@param namespace string The namespace
---@param key string The setting key
---@return string
function SettingsSchema:CreatePath(scopeKey, namespace, key)
	return strjoin(PATH_SEP, scopeKey, namespace, key)
end

---Returns whether or not the schema includes a setting.
---@param path string The setting path
---@return boolean
function SettingsSchema:Contains(path)
	assert(self._committedHash)
	return self._type[path] and true or false
end

---Gets the type for a specific setting.
---@param path string The setting path
---@return string
function SettingsSchema:GetType(path)
	assert(self._committedHash and self._type[path])
	return self._type[path]
end

---Gets the last modified version for a specific setting.
---@param path string The setting path
---@return number
function SettingsSchema:GetLastModifiedVersion(path)
	assert(self._committedHash and self._type[path])
	return self._lastModifiedVersion[path]
end

---Gets the default value for a specific setting.
---@param path string The setting path
---@return any
function SettingsSchema:GetDefaultValue(path)
	assert(self._committedHash and self._type[path])
	return self._defaultValue[path]
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SettingsSchema.__private:_AddKey(settingType, key, defaultValue, lastModifiedVersion)
	assert(not self._committedHash)
	assert(self._scope and self._namespace)
	assert(type(defaultValue) == settingType)
	assert(lastModifiedVersion >= self._minVersion and lastModifiedVersion <= self._version)
	if self._condition == false then
		return
	end
	local path = strjoin(PATH_SEP, self._scope, self._namespace, key)
	assert(not self._type[path])
	self._type[path] = settingType
	self._defaultValue[path] = defaultValue
	self._lastModifiedVersion[path] = lastModifiedVersion
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CheckDefaultTable(tbl)
	for k, v in pairs(tbl) do
		assert(type(k) == "string" or type(k) == "number")
		if type(v) == "table" then
			private.CheckDefaultTable(v)
		end
	end
end

function private.IteratorHelper(self, path)
	path = next(self._type, path)
	if not path then
		return
	end
	return path, strsplit(PATH_SEP, path)
end

function private.IteratorForScopeHelper(self, path)
	assert(path)
	local prevScope, prevNamespace = strsplit(PATH_SEP, path)
	if not prevNamespace then
		-- This is the first iteration
		path = nil
	end
	while true do
		path = next(self._type, path)
		if not path then
			return
		end
		local scope, namespace, key = strsplit(PATH_SEP, path)
		if scope == prevScope then
			return path, namespace, key
		end
	end
end
