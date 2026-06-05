-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local SettingsDB = LibTSMTypes:DefineClassType("SettingsDB")
local Types = LibTSMTypes:Include("Settings.Types")
local Util = LibTSMTypes:Include("Settings.Util")
local View = LibTSMTypes:Include("Settings.View")
local SettingsMigration = LibTSMTypes:IncludeClassType("SettingsMigration")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local private = {
	protectedAccessAllowed = {},
}
local DEFAULT_DB = {
	_version = -math.huge, -- DB version
	_currentProfile = {}, -- lookup table of the current profile name by character
	_syncAccountKey = {}, -- lookup table of the sync account key by factionrealm
	_syncOwner = {}, -- lookup table of the owner sync account key by character
	_hash = 0,
	_scopeKeys = {
		profile = {},
		realm = {},
		factionrealm = {},
		char = {},
		sync = {},
	},
	_lastModifiedVersion = {},
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Validates and loads a raw settings table and creates a DB object.
---@param name string The name of the global table
---@param schema SettingsSchema The schema
---@param realmName string The current realm name
---@param factionName string The current faction name
---@param characterName string The current character name
---@param connectedRealms? string[] Connected realm names
---@param accessibleFactions string[] Accessible faction names
---@return SettingsDB
---@return SettingsMigration
function SettingsDB.__static.New(name, schema, realmName, factionName, characterName, connectedRealms, accessibleFactions)
	assert(type(name) == "string")
	local currentScopeKeys = {
		global = Types.GLOBAL_SCOPE_KEY,
		profile = nil, -- Set later
		realm = realmName,
		factionrealm = strjoin(Types.SCOPE_KEY_SEP, factionName, realmName),
		char = strjoin(Types.SCOPE_KEY_SEP, characterName, realmName),
		sync = strjoin(Types.SCOPE_KEY_SEP, characterName, factionName, realmName),
	}

	-- Get (and create if necessary) the global table
	local tbl = _G[name]
	if not tbl then
		tbl = {}
		_G[name] = tbl
	end

	-- Check if the table is valid
	local isValid, userError = true, false
	if not next(tbl) then
		-- Brand new
		isValid = false
	elseif not private.ValidateTable(tbl, schema:GetMinimumVersion()) then
		-- Corrupted
		assert(not LibTSMTypes.IsDevVersion() and not LibTSMTypes.IsTestVersion(), "DB is not valid!")
		isValid = false
	elseif tbl._version == schema:GetVersion() and tbl._hash ~= schema:GetHash() then
		-- The hash didn't match
		assert(not LibTSMTypes.IsDevVersion() and not LibTSMTypes.IsTestVersion(), "Invalid settings hash! Did you forget to increase the version?")
		isValid = false
	elseif tbl._syncOwner and tbl._syncOwner[currentScopeKeys.sync] and tbl._syncOwner[currentScopeKeys.sync] ~= tbl._syncAccountKey[currentScopeKeys.factionrealm] then
		-- We aren't the owner of this character, so wipe the DB and show a manual error
		userError = true
		assert(not LibTSMTypes.IsDevVersion() and not LibTSMTypes.IsTestVersion(), "Settings are corrupted due to manual copying of saved variables file")
		isValid = false
	end
	if not isValid then
		-- Wipe the table and start over
		wipe(tbl)
		for key, value in pairs(DEFAULT_DB) do
			tbl[key] = Util.CopyValue(value)
		end
	end
	tbl._hash = schema:GetHash()

	if not tbl._syncOwner then
		-- We just upgraded to the first version with the sync scope
		tbl._syncOwner = {}
		tbl._syncAccountKey = {}
		tbl._scopeKeys.sync = {}
	end

	-- Make sure we have sync account keys for every factionrealm
	for _, factionrealm in ipairs(tbl._scopeKeys.factionrealm) do
		tbl._syncAccountKey[factionrealm] = tbl._syncAccountKey[factionrealm] or strjoin(Types.SCOPE_KEY_SEP, factionrealm, random(1000000000))
	end

	-- Create the sync account key for this factionrealm if necessary
	tbl._syncAccountKey[currentScopeKeys.factionrealm] = tbl._syncAccountKey[currentScopeKeys.factionrealm] or strjoin(Types.SCOPE_KEY_SEP, currentScopeKeys.factionrealm, random(1000000000))
	-- Set the sync owner of the current sync scope key to this account
	tbl._syncOwner[currentScopeKeys.sync] = tbl._syncOwner[currentScopeKeys.sync] or tbl._syncAccountKey[currentScopeKeys.factionrealm]

	-- Setup current scope keys and set defaults for new keys
	tbl._currentProfile[currentScopeKeys.char] = tbl._currentProfile[currentScopeKeys.char] or Types.DEFAULT_PROFILE_NAME
	currentScopeKeys.profile = tbl._currentProfile[currentScopeKeys.char]
	for scopeType, scopeKey in pairs(currentScopeKeys) do
		if scopeType ~= "global" and not tContains(tbl._scopeKeys[scopeType], scopeKey) then
			tinsert(tbl._scopeKeys[scopeType], scopeKey)
			private.SetScopeDefaults(tbl, schema, strjoin(Types.KEY_SEP, Types.SCOPES[scopeType], String.Escape(scopeKey), ".+", ".+"))
		end
	end

	-- Set any values which are nil to their default value
	tbl._scopeKeys = tbl._scopeKeys or {
		profile = {},
		realm = {},
		factionrealm = {},
		char = {},
		sync = {},
	}
	for path, scopeKey, namespace, key in schema:Iterator() do
		local scopeKeyValues = scopeKey == Types.SCOPES.global and Types.GLOBAL_SCOPE_KEY_VALUES or tbl._scopeKeys[Types.SCOPES_LOOKUP[scopeKey]]
		for _, scopeKeyValue in ipairs(scopeKeyValues) do
			local dbKey = strjoin(Types.KEY_SEP, scopeKey, scopeKeyValue, namespace, key)
			if tbl[dbKey] == nil then
				tbl[dbKey] = Util.CopyValue(schema:GetDefaultValue(path))
			end
		end
	end

	-- Do any necessary upgrading or downgrading if the version changed
	tbl._lastModifiedVersion = tbl._lastModifiedVersion or {}
	local removedSettings, prevVersion = nil, nil
	if schema:GetVersion() ~= tbl._version then
		-- clear any settings which no longer exist, and set new/updated settings to their default values
		removedSettings = {}
		for key in pairs(tbl) do
			-- ignore metadata (keys starting with "_")
			if strsub(key, 1, 1) ~= "_" then
				local scopeKey, namespace, settingKey = strmatch(key, "^(.+)"..Types.KEY_SEP..".+"..Types.KEY_SEP.."(.+)"..Types.KEY_SEP.."(.+)$")
				local settingLastModifiedVersion = scopeKey and tbl._lastModifiedVersion[strjoin(Types.KEY_SEP, scopeKey, namespace, settingKey)]
				local path = schema:CreatePath(scopeKey, namespace, settingKey)
				if not schema:Contains(path) then
					-- this setting was removed so remove it from the tbl
					removedSettings[key] = tbl[key]
					tbl[key] = nil
				elseif schema:GetLastModifiedVersion(path) > tbl._version then
					-- this setting was updated, so we'll reset it to the default value
					removedSettings[key] = tbl[key]
				elseif not settingLastModifiedVersion and schema:GetVersion() < tbl._version then
					-- we don't have lastModifiedVersion info for this setting and the DB is getting downgraded, so we'll reset it to the default value
					removedSettings[key] = tbl[key]
				elseif (settingLastModifiedVersion or 0) > schema:GetVersion() then
					-- this setting is being downgraded, so we'll reset it to the default value
					removedSettings[key] = tbl[key]
				end
			end
		end
		for path, scopeKey, namespace, settingKey in schema:Iterator() do
			local settingLastModifiedVersion = tbl._lastModifiedVersion[strjoin(Types.KEY_SEP, scopeKey, namespace, settingKey)]
			local schemaLastModifiedVersion = schema:GetLastModifiedVersion(path)
			if schemaLastModifiedVersion > tbl._version or (not settingLastModifiedVersion and schema:GetVersion() < tbl._version) or (settingLastModifiedVersion or 0) > schema:GetVersion() then
				-- this is either a new setting or was changed or this is a downgrade - either way set it to the default value
				private.SetScopeDefaults(tbl, schema, strjoin(Types.KEY_SEP, scopeKey, ".+", namespace, settingKey))
			end
		end
		if schema:GetVersion() > tbl._version then
			prevVersion = tbl._version
		else
			removedSettings = nil
		end
		tbl._version = schema:GetVersion()
	end

	-- Populate the new lastModifiedVersion info
	wipe(tbl._lastModifiedVersion)
	for path, scopeKey, namespace, key in schema:Iterator() do
		tbl._lastModifiedVersion[strjoin(Types.KEY_SEP, scopeKey, namespace, key)] = schema:GetLastModifiedVersion(path)
	end

	local dbObj = SettingsDB(schema, tbl, currentScopeKeys, userError, connectedRealms, accessibleFactions)
	if not removedSettings then
		return dbObj
	end
	assert(prevVersion)
	return dbObj, SettingsMigration.New(prevVersion, removedSettings)
end



-- ============================================================================
-- Protected Metatable
-- ============================================================================

local PROTECTED_TABLE_MT = {
	__newindex = function(self, key, value)
		assert(private.protectedAccessAllowed[self], "Attempting to modify a protected table")
		rawset(self, key, value)
	end,
	__metatable = false
}



-- ============================================================================
-- Public Class Methods - General Info / Access
-- ============================================================================

function SettingsDB:__init(schema, tbl, currentScopeKeys, userError, connectedRealms, accessibleFactions)
	self._schema = schema ---@type SettingsSchema
	self._tbl = tbl
	self._currentScopeKeys = currentScopeKeys ---@type table<ScopeName, string>
	self._views = {} --- @type SettingsView[]
	self._userError = userError
	self._connectedRealms = connectedRealms
	self._accessibleFactions = accessibleFactions
	self._cachedConnectedRealms = nil

	-- Make the db table protected
	setmetatable(tbl, PROTECTED_TABLE_MT)
end

---Creates a new view.
---@return SettingsView
function SettingsDB:NewView()
	local view = View.New(self, self._accessibleFactions)
	tinsert(self._views, view)
	return view
end

---Returns whether or not the DB was wiped on load due to a user error.
---@return boolean
function SettingsDB:WipedFromUserError()
	return self._userError
end

---Returns whether or not a setting key exists in the schema.
---@param scope ScopeName The scope name
---@param namespace string The namespace
---@param key string The setting key
---@return boolean
function SettingsDB:HasKey(scope, namespace, key)
	return self._schema:Contains(self._schema:CreatePath(Types.SCOPES[scope], namespace, key))
end

---Gets a setting value.
---@param scope ScopeName The scope name
---@param scopeValue string The scope value
---@param namespace string The namespace
---@param key string The setting key
---@return any
function SettingsDB:Get(scope, scopeValue, namespace, key)
	local scopeKey = Types.SCOPES[scope]
	assert(self._schema:Contains(self._schema:CreatePath(scopeKey, namespace, key)))
	scopeValue = scopeValue or self._currentScopeKeys[scope]
	return self._tbl[strjoin(Types.KEY_SEP, scopeKey, scopeValue, namespace, key)]
end

---Sets a setting value.
---@param scope ScopeName The scope name
---@param scopeValue string The scope value
---@param namespace string The namespace
---@param key string The setting key
---@param value any The value to set
function SettingsDB:Set(scope, scopeValue, namespace, key, value)
	local scopeKey = Types.SCOPES[scope]
	assert(value == nil or type(value) == self._schema:GetType(self._schema:CreatePath(scopeKey, namespace, key)), "Value is of wrong type.")
	scopeValue = scopeValue or self._currentScopeKeys[scope]
	self:_SetDBKeyValue(strjoin(Types.KEY_SEP, scopeKey, scopeValue, namespace, key), value)
end

---Iterates over all the sync settings.
---@return fun(): number, string, string @Iterator with fields: `index`, `namespace`, `key`
function SettingsDB:SyncSettingIterator()
	local result = TempTable.Acquire()
	for _, namespace, key in self._schema:IteratorForScope(Types.SCOPES.sync) do
		Table.InsertMultiple(result, namespace, key)
	end
	return TempTable.Iterator(result, 2)
end



-- ============================================================================
-- Public Class Methods - Syncing
-- ============================================================================

---Gets the sync scope value for a given character.
---@param character string The character name
---@param factionrealm? string The factionrealm which the character belongs to (defaults to the current factionrealm)
---@return string
function SettingsDB:GetSyncScopeKeyByCharacter(character, factionrealm)
	return character..Types.SCOPE_KEY_SEP..(factionrealm or self._currentScopeKeys.factionrealm)
end

---Iterate over the known sync accounts for the current factionrealm.
---@return fun(): number, string @Iterator with fields: `index`, `accountKey`
function SettingsDB:SyncAccountIterator()
	local result = TempTable.Acquire()
	local used = TempTable.Acquire()
	for _, syncOwner in pairs(self._tbl._syncOwner) do
		if strmatch(syncOwner, "^"..String.Escape(self._currentScopeKeys.factionrealm..Types.SCOPE_KEY_SEP).."(%d+)$") and not used[syncOwner] and syncOwner ~= self:GetLocalSyncAccountKey() then
			used[syncOwner] = true
			tinsert(result, syncOwner)
		end
	end
	TempTable.Release(used)
	return TempTable.Iterator(result)
end

---Gets the local account's sync account key for a factionrealm.
---@param factionrealm? string The factionrealm (defaults to the current factionrealm)
---@return string
function SettingsDB:GetLocalSyncAccountKey(factionrealm)
	factionrealm = factionrealm or self._currentScopeKeys.factionrealm
	return self._tbl._syncAccountKey[factionrealm]
end

---Gets the sync account key for the account which owns a given character.
---@param character string The name of the character
---@param factionrealm? string The factionrealm (defaults to the current factionrealm)
---@return string
function SettingsDB:GetOwnerSyncAccountKey(character, factionrealm)
	return self._tbl._syncOwner[self:GetSyncScopeKeyByCharacter(character, factionrealm)]
end

---Adds a new sync character.
---@param accountKey string The account key
---@param character string The name of the character
---@param factionrealm? string The factionrealm (defaults to the current factionrealm)
function SettingsDB:NewSyncCharacter(accountKey, character, factionrealm)
	factionrealm = factionrealm or self._currentScopeKeys.factionrealm
	assert(strmatch(accountKey, "^"..String.Escape(factionrealm..Types.SCOPE_KEY_SEP).."(%d+)$"))
	local scopeKey = self:GetSyncScopeKeyByCharacter(character, factionrealm)
	self._tbl._syncOwner[scopeKey] = accountKey
	if not tContains(self._tbl._scopeKeys.sync, scopeKey) then
		tinsert(self._tbl._scopeKeys.sync, scopeKey)
	end
	self:_SetScopeDefaults(strjoin(Types.KEY_SEP, Types.SCOPES.sync, String.Escape(scopeKey), ".+", ".+"))
end

---Removes a sync account character.
---@param character string The name of the character
---@param factionrealm The factionrealm (defaults to the current factionrealm)
function SettingsDB:RemoveSyncCharacter(character, factionrealm)
	local scopeKey = self:GetSyncScopeKeyByCharacter(character, factionrealm)
	self:_DeleteScope("sync", scopeKey)
	self._tbl._syncOwner[scopeKey] = nil
end

---Removes a sync account.
---@param accountKey string The account key
function SettingsDB:RemoveSyncAccount(accountKey)
	assert(accountKey ~= self:GetLocalSyncAccountKey())
	local scopeKeysToRemove = TempTable.Acquire()
	for scopeKey, ownerAccountKey in pairs(self._tbl._syncOwner) do
		if ownerAccountKey == accountKey then
			tinsert(scopeKeysToRemove, scopeKey)
		end
	end
	for _, scopeKey in ipairs(scopeKeysToRemove) do
		self:_DeleteScope("sync", scopeKey)
		self._tbl._syncOwner[scopeKey] = nil
	end
	TempTable.Release(scopeKeysToRemove)
end



-- ============================================================================
-- Public Class Methods - Scope Management
-- ============================================================================

---Iterate over the scope values.
---@param scopeName ScopeName The scope name
---@return fun(): number, string @Iterator with fields `index`, `value`
function SettingsDB:ScopeKeyIterator(scopeName)
	return ipairs(self._tbl._scopeKeys[scopeName])
end

---Gets the name of the current profile.
---@return string
function SettingsDB:GetCurrentProfile()
	return self._currentScopeKeys.profile
end

---Returns whether or not the specified profile exists.
---@param profileName string The profile name
---@return boolean
function SettingsDB:ProfileExists(profileName)
	return tContains(self._tbl._scopeKeys.profile, profileName) and true or false
end

---Returns whether or not the specified profile name is valid.
---@param profileName string The profile name
---@return boolean
function SettingsDB:IsValidProfileName(profileName)
	return type(profileName) == "string" and profileName ~= "" and not strfind(profileName, Types.KEY_SEP)
end

---Sets the active profile for the current character.
---@param profileName string The profile name
---@param noCallback? boolean Skip any setting change callbacks (defaults to false)
function SettingsDB:SetProfile(profileName, noCallback)
	assert(self:IsValidProfileName(profileName))
	if profileName == self._currentScopeKeys.profile then
		return
	end

	-- Change the current profile for this character
	self._tbl._currentProfile[self._currentScopeKeys.char] = profileName
	self._currentScopeKeys.profile = profileName

	if not self:ProfileExists(profileName) then
		self:CreateProfile(profileName)
	end

	if not noCallback then
		-- Notify all the views that the profile settings have changed
		for _, namespace, key in self._schema:IteratorForScope(Types.SCOPES.profile) do
			for _, view in ipairs(self._views) do
				view:_HandleSettingChanged("profile", namespace, key)
			end
		end
	end
end

---Creates a new profile (without switching to it).
---@param profileName string The profile name
function SettingsDB:CreateProfile(profileName)
	assert(self:IsValidProfileName(profileName) and not self:ProfileExists(profileName))

	-- Add the profile
	tinsert(self._tbl._scopeKeys.profile, profileName)

	-- Set all the settings to their default values
	self:_SetScopeDefaults(strjoin(Types.KEY_SEP, Types.SCOPES.profile, String.Escape(profileName), ".+", ".+"))
end

---Resets the current profile.
function SettingsDB:ResetProfile()
	self:_SetScopeDefaults(strjoin(Types.KEY_SEP, Types.SCOPES.profile, String.Escape(self._currentScopeKeys.profile), ".+", ".+"))
end

---Copies settings from the specified profile into the current one.
---@param sourceProfileName string The source profile name
function SettingsDB:CopyProfile(sourceProfileName)
	assert(type(sourceProfileName) == "string")
	assert(not strfind(sourceProfileName, Types.KEY_SEP))
	assert(sourceProfileName ~= self._currentScopeKeys.profile)

	-- Copy all the settings from the source profile to the current one
	for _, namespace, key in self._schema:IteratorForScope(Types.SCOPES.profile) do
		local srcKey = strjoin(Types.KEY_SEP, Types.SCOPES.profile, sourceProfileName, namespace, key)
		local destKey = strjoin(Types.KEY_SEP, Types.SCOPES.profile, self._currentScopeKeys.profile, namespace, key)
		self:_SetDBKeyValue(destKey, Util.CopyValue(self._tbl[srcKey]))
	end
end

---Deletes a profile.
---@param profileName string The profile to delete
---@param defaultNewProfileName string The new profile to move characters to
function SettingsDB:DeleteProfile(profileName, defaultNewProfileName)
	self:_DeleteScope("profile", profileName)
	assert(defaultNewProfileName and self:ProfileExists(defaultNewProfileName))
	for character, currentProfileName in pairs(self._tbl._currentProfile) do
		if currentProfileName == profileName then
			assert(character ~= self._currentScopeKeys.char)
			self._tbl._currentProfile[character] = defaultNewProfileName
		end
	end
end



-- ============================================================================
-- Public Class Methods - Accessible Realm / Character Iterators
-- ============================================================================

---Iterates over the accessible known factionrealms / realms.
---@param scopeName "factionrealm"|"realm" The scope name
---@param connectedOnly? boolean Only return connected realms
---@return fun(): string, boolean @Iterator with fields: `index`, `value`, `isConnected`
function SettingsDB:AccessibleRealmIterator(scopeName, connectedOnly)
	assert(scopeName == "factionrealm" or scopeName == "realm")
	self:_PopulateConnectedRealmCache()
	local result = TempTable.Acquire()
	Table.InsertMultiple(result, scopeName == "factionrealm" and self._currentScopeKeys.factionrealm or self._currentScopeKeys.realm, true)
	for _, realm in ipairs(self._cachedConnectedRealms) do
		local scopeKeyValue = nil
		if scopeName == "factionrealm" then
			scopeKeyValue = gsub(self._currentScopeKeys.factionrealm, String.Escape(self._currentScopeKeys.realm), realm)
		else
			scopeKeyValue = realm
		end
		local isConnected = self._cachedConnectedRealms[realm] or false
		if not connectedOnly or isConnected then
			Table.InsertMultiple(result, scopeKeyValue, isConnected)
		end
	end
	return TempTable.Iterator(result, 2)
end

---Iterates over the accessible charcters.
---@param accountFilter? string The sync account key to filter on (defaults to the local sync account)
---@param factionrealm? string The factionrealm (defaults to the current factionrealm)
---@param altsOnly? boolean Only returns alts (not the current character)
---@return fun(): number, string @Iterator with fields: `index`, `character`
function SettingsDB:AccessibleCharacterIterator(accountFilter, factionrealm, altsOnly)
	factionrealm = factionrealm or self._currentScopeKeys.factionrealm
	return self:_AccessibleCharacterIteratorHelper(accountFilter, factionrealm, altsOnly)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SettingsDB:_GetDefaultReadOnly(scope, namespace, key)
	local scopeKey = Types.SCOPES[scope]
	return self._schema:GetDefaultValue(self._schema:CreatePath(scopeKey, namespace, key))
end

function SettingsDB:_SetDBKeyValue(key, value, noCallback)
	private.protectedAccessAllowed[self._tbl] = true
	self._tbl[key] = value
	private.protectedAccessAllowed[self._tbl] = nil
	local scopeKey, _, namespace, settingKey = strsplit(Types.KEY_SEP, key)
	if not settingKey or noCallback then
		return
	end
	local scopeName = Types.SCOPES_LOOKUP[scopeKey]
	for _, view in ipairs(self._views) do
		view:_HandleSettingChanged(scopeName, namespace, settingKey)
	end
end

function SettingsDB:_SetScopeDefaults(searchPattern)
	-- Remove any existing entries for matching keys
	for key in pairs(self._tbl) do
		if strmatch(key, searchPattern) then
			self:_SetDBKeyValue(key, nil, true)
		end
	end

	-- Set any matching keys to their default values
	local scopeKey = strsub(searchPattern, 1, 1)
	local scopeKeyValues = scopeKey == Types.SCOPES.global and Types.GLOBAL_SCOPE_KEY_VALUES or self._tbl._scopeKeys[Types.SCOPES_LOOKUP[scopeKey]]
	for path, namespace, key in self._schema:IteratorForScope(scopeKey) do
		for _, scopeKeyValue in ipairs(scopeKeyValues) do
			local dbKey = strjoin(Types.KEY_SEP, scopeKey, scopeKeyValue, namespace, key)
			if strmatch(dbKey, searchPattern) then
				local value = self._schema:GetDefaultValue(path)
				if type(value) == "table" then
					value = CopyTable(value)
				end
				self:_SetDBKeyValue(dbKey, value)
			end
		end
	end
end

function SettingsDB:_DeleteScope(scopeType, scopeKey)
	assert(Types.SCOPES[scopeType])
	assert(type(scopeKey) == "string")
	assert(scopeKey ~= self._currentScopeKeys[scopeType])

	-- Remove all settings for the specified profile
	local searchPattern = strjoin(Types.KEY_SEP, Types.SCOPES[scopeType], String.Escape(scopeKey), ".+", ".+")
	for key in pairs(self._tbl) do
		if strmatch(key, searchPattern) then
			self:_SetDBKeyValue(key, nil)
		end
	end

	-- Remove the scope key from the list
	Table.RemoveByValue(self._tbl._scopeKeys[scopeType], scopeKey)
end

function SettingsDB.__private:_AccessibleCharacterIteratorHelper(accountFilter, factionrealm, altsOnly)
	local realm = strmatch(factionrealm, "^.+"..String.Escape(Types.SCOPE_KEY_SEP).."(.+)$")
	assert(realm)
	local result = TempTable.Acquire()
	for scopeKey, ownerAccount in pairs(self._tbl._syncOwner) do
		if not accountFilter or ownerAccount == accountFilter then
			local character = strmatch(scopeKey, "^(.+)"..String.Escape(Types.SCOPE_KEY_SEP..factionrealm))
			if character and (not altsOnly or factionrealm ~= self._currentScopeKeys.factionrealm or strjoin(Types.SCOPE_KEY_SEP, character, realm) ~= self._currentScopeKeys.char) then
				tinsert(result, character)
			end
		end
	end
	return TempTable.Iterator(result)
end

function SettingsDB:_PopulateConnectedRealmCache()
	if self._cachedConnectedRealms then
		return
	end
	self._cachedConnectedRealms = {}
	if self._connectedRealms then
		for _, realm in self:ScopeKeyIterator("realm") do
			if realm ~= self._currentScopeKeys.realm then
				tinsert(self._cachedConnectedRealms, realm)
			end
		end
		for _, connectedRealmName in ipairs(self._connectedRealms) do
			self._cachedConnectedRealms[connectedRealmName] = true
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateTable(tbl, minVersion)
	if #tbl > 0 then
		return false
	elseif type(tbl._version) ~= "number" then
		return false
	elseif tbl._version < minVersion then
		return false
	elseif type(tbl._hash) ~= "number" then
		return false
	elseif tbl._lastModifiedVersion ~= nil and type(tbl._lastModifiedVersion) ~= "table" then
		return false
	elseif type(tbl._scopeKeys) ~= "table" then
		return false
	end
	for scopeType, keys in pairs(tbl._scopeKeys) do
		if not Types.SCOPES[scopeType] then
			return false
		end
		for i, name in pairs(keys) do
			if type(i) ~= "number" or i > #keys or i <= 0 or type(name) ~= "string" then
				return false
			end
		end
	end
	if type(tbl._currentProfile) ~= "table" then
		return false
	end
	for key, value in pairs(tbl._currentProfile) do
		if type(key) ~= "string" or type(value) ~= "string" then
			return false
		end
	end
	return true
end

function private.SetScopeDefaults(tbl, schema, searchPattern)
	-- Remove any existing entries for matching keys
	for key in pairs(tbl) do
		if strmatch(key, searchPattern) then
			tbl[key] = nil
		end
	end

	-- Set any matching keys to their default values
	local scopeKey = strsub(searchPattern, 1, 1)
	local scopeKeyValues = scopeKey == Types.SCOPES.global and Types.GLOBAL_SCOPE_KEY_VALUES or tbl._scopeKeys[Types.SCOPES_LOOKUP[scopeKey]]
	for path, namespace, key in schema:IteratorForScope(scopeKey) do
		for _, scopeKeyValue in ipairs(scopeKeyValues) do
			local dbKey = strjoin(Types.KEY_SEP, scopeKey, scopeKeyValue, namespace, key)
			if strmatch(dbKey, searchPattern) then
				tbl[dbKey] = Util.CopyValue(schema:GetDefaultValue(path))
			end
		end
	end
end
