-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local View = LibTSMTypes:Init("Settings.View")
local Types = LibTSMTypes:Include("Settings.Types")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Vararg = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Vararg")
local Reactive = LibTSMTypes:From("LibTSMUtil"):Include("Reactive")
local private = {
	context = {}, ---@type table<SettingsView, ViewContext>
}
-- Make the keys weak so we clean up our context if the view is GC'd
setmetatable(private.context, { __mode = "k" })

---@class ViewContext
---@field settingsDB SettingsDB
---@field scopeLookup table<string, ScopeName>
---@field namespaceLookup table<string, string>
---@field callbacks table<string, function>
---@field accessibleFactions string[]



-- ============================================================================
-- Metatable
-- ============================================================================

---@class SettingsView
local VIEW_METHODS = {}

local VIEW_MT = {
	__index = function(self, key)
		if VIEW_METHODS[key] then
			return VIEW_METHODS[key]
		end
		local context = private.context[self]
		return context.settingsDB:Get(context.scopeLookup[key], nil, context.namespaceLookup[key], key)
	end,
	__newindex = function(self, key, value)
		local context = private.context[self]
		context.settingsDB:Set(context.scopeLookup[key], nil, context.namespaceLookup[key], key, value)
	end,
	__metatable = false,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new view.
---@param db SettingsDB
---@return SettingsView
function View.New(db, accessibleFactions)
	local view = setmetatable({}, VIEW_MT)
	private.context[view] = {
		settingsDB = db,
		scopeLookup = {},
		namespaceLookup = {},
		callbacks = {},
		accessibleFactions = accessibleFactions,
	}
	return view
end



-- ============================================================================
-- Setting View Class
-- ============================================================================

---Adds a key to the view.
---@param scopeName ScopeName The scope name
---@param namespace string The namespace
---@param key string The setting key
---@return SettingsView
function VIEW_METHODS:AddKey(scopeName, namespace, key)
	assert(scopeName and namespace and key)
	local context = private.context[self]
	assert(context and not context.scopeLookup[key] and context.settingsDB:HasKey(scopeName, namespace, key))
	context.scopeLookup[key] = scopeName
	context.namespaceLookup[key] = namespace
	return self
end

---Registers a callback for when a key changes.
---@param key string The setting key
---@param callback fun() The callback function
---@return SettingsView
function VIEW_METHODS:RegisterCallback(key, callback)
	local context = private.context[self]
	assert(callback and not context.callbacks[key] and context.scopeLookup[key])
	context.callbacks[key] = callback
	return self
end

---Gets a publisher for when a key changes.
---@param key string The setting key
---@return ReactivePublisher
function VIEW_METHODS:PublisherForKey(key)
	local context = private.context[self]
	assert(context.scopeLookup[key])
	context.stream = context.stream or Reactive.CreateStream()
	return context.stream:PublisherWithInitialValue(self)
		:IgnoreDuplicatesWithKeys(key)
		:MapWithKey(key)
		:IgnoreDuplicates()
end

---Gets a publisher for when any of a list of keys changes.
---@param key string The setting key
---@return ReactivePublisher
function VIEW_METHODS:PublisherForKeys(...)
	local context = private.context[self]
	for _, key in Vararg.Iterator(...) do
		assert(context.scopeLookup[key])
	end
	context.stream = context.stream or Reactive.CreateStream()
	return context.stream:PublisherWithInitialValue(self)
		:IgnoreDuplicatesWithKeys(...)
end

---Gets the read-only default for a key.
---@param key string The setting key
---@return unknown
function VIEW_METHODS:GetDefaultReadOnly(key)
	local context = private.context[self]
	return context.settingsDB:_GetDefaultReadOnly(context.scopeLookup[key], context.namespaceLookup[key], key)
end

---Resets the key to its default value.
---@param key string The setting key
function VIEW_METHODS:ResetToDefault(key)
	local context = private.context[self]
	local value = self:GetDefaultReadOnly(key)
	if type(value) == "table" then
		value = CopyTable(value)
	end
	context.settingsDB:Set(context.scopeLookup[key], nil, context.namespaceLookup[key], key, value)
end

---Returns an iterator over all accessible values for a key (must have a `regionWide` key).
---@param key string The setting key
---@return fun():number, ...unknown
function VIEW_METHODS:AccessibleValueIterator(key)
	local context = private.context[self]
	local connectedOnly = not self.regionWide
	local scopeType = context.scopeLookup[key]
	local namespace = context.namespaceLookup[key]
	local result = TempTable.Acquire()
	for _, realm in context.settingsDB:AccessibleRealmIterator("realm", connectedOnly) do
		if scopeType == "realm" then
			local value = context.settingsDB:Get(scopeType, realm, namespace, key)
			if value ~= nil then
				Table.InsertMultiple(result, value, realm)
			end
		else
			for _, faction in ipairs(context.accessibleFactions) do
				local factionrealm = strjoin(Types.SCOPE_KEY_SEP, faction, realm)
				if scopeType == "sync" then
					for scopeKey in pairs(context.settingsDB._tbl._syncOwner) do
						local character = strmatch(scopeKey, "^(.+)"..String.Escape(Types.SCOPE_KEY_SEP..factionrealm))
						if character then
							local value = context.settingsDB:Get(scopeType, scopeKey, namespace, key)
							if value ~= nil then
								Table.InsertMultiple(result, value, character, factionrealm)
							end
						end
					end
				elseif scopeType == "factionrealm" then
					local value = context.settingsDB:Get(scopeType, factionrealm, namespace, key)
					if value ~= nil then
						Table.InsertMultiple(result, value, factionrealm)
					end
				else
					error("Invalid scopeType: "..tostring(scopeType))
				end
			end
		end
	end
	if scopeType == "sync" then
		return TempTable.Iterator(result, 3)
	elseif scopeType == "factionrealm" then
		return TempTable.Iterator(result, 2)
	elseif scopeType == "realm" then
		return TempTable.Iterator(result, 2)
	else
		error("Invalid scopeType: "..tostring(scopeType))
	end
end

---Get the setting value for a given scope key.
---@param key string The setting key
---@param ... string The character followed by the factionrealm for sync scope keys or just the single scope key otherwise
---@return unknown
function VIEW_METHODS:GetForScopeKey(key, ...)
	local context = private.context[self]
	local scopeType = context.scopeLookup[key]
	local scopeKey = nil
	if scopeType == "sync" then
		assert(select("#", ...) == 2)
		scopeKey = context.settingsDB:GetSyncScopeKeyByCharacter(...)
	elseif scopeType == "factionrealm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "realm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "profile" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	else
		error("Invalid scopeType: "..tostring(scopeType))
	end
	return context.settingsDB:Get(context.scopeLookup[key], scopeKey, context.namespaceLookup[key], key)
end

---Set the setting value for a given scope key.
---@param key string The setting key
---@param value any The value to set
---@param ... string The character followed by the factionrealm for sync scope keys or just the single scope key otherwise
---@return unknown
function VIEW_METHODS:SetForScopeKey(key, value, ...)
	local context = private.context[self]
	local scopeType = context.scopeLookup[key]
	local scopeKey = nil
	if scopeType == "sync" then
		assert(select("#", ...) == 2)
		scopeKey = context.settingsDB:GetSyncScopeKeyByCharacter(...)
	elseif scopeType == "factionrealm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "realm" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	elseif scopeType == "profile" then
		assert(select("#", ...) == 1)
		scopeKey = ...
	else
		error("Invalid scopeType: "..tostring(scopeType))
	end
	return context.settingsDB:Set(context.scopeLookup[key], scopeKey, context.namespaceLookup[key], key, value)
end


function VIEW_METHODS:_HandleSettingChanged(scopeName, namespace, key)
	local context = private.context[self]
	if context.scopeLookup[key] == scopeName and context.namespaceLookup[key] == namespace then
		if context.callbacks[key] then
			context.callbacks[key]()
		end
		if context.stream then
			context.stream:Send(self)
		end
	end
end
