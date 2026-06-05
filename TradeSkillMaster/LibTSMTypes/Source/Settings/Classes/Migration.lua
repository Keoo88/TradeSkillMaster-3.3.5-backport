-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local SettingsMigration = LibTSMTypes:DefineClassType("SettingsMigration")
local Types = LibTSMTypes:Include("Settings.Types")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")

---@alias RemovedSettingKey string



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new migration object.
---@param prevVersion number The previous DB version
---@param removedSettings table<string, any> Removed setting values
---@return SettingsMigration
function SettingsMigration.__static.New(prevVersion, removedSettings)
	return SettingsMigration(prevVersion, removedSettings)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function SettingsMigration.__private:__init(prevVersion, removedSettings)
	self._prevVersion = prevVersion
	self._removedSettings = removedSettings
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the previous version.
---@return number
function SettingsMigration:GetPrevVersion()
	return self._prevVersion
end

---Iterates over the removed settings
---@param filterScopeType> ScopeName The scope type filter
---@param filterScopeKey? string The scope key filter
---@param filterNamespace? string The namespace filter
---@param filterSettingKey? string The setting key filter
---@return fun(): number, RemovedSettingKey, any @Iterator with fields: `index`, `key`, `value`
function SettingsMigration:RemovedSettingIterator(filterScopeType, filterScopeKey, filterNamespace, filterSettingKey)
	assert(not filterScopeType or Types.SCOPES[filterScopeType])
	filterScopeType = filterScopeType and Types.SCOPES[filterScopeType] or ".+"
	filterScopeKey = filterScopeKey and String.Escape(filterScopeKey) or ".+"
	filterNamespace = filterNamespace and String.Escape(filterNamespace) or ".+"
	filterSettingKey = filterSettingKey and String.Escape(filterSettingKey) or ".+"
	local keyFilter = "^"..strjoin(Types.KEY_SEP, filterScopeType, filterScopeKey, filterNamespace, filterSettingKey).."$"
	local result = TempTable.Acquire()
	for key, value in pairs(self._removedSettings) do
		if strmatch(key, keyFilter) then
			tinsert(result, key)
			tinsert(result, value)
		end
	end
	return TempTable.Iterator(result, 2)
end

---Gets info on a removed setting key.
---@param key RemovedSettingKey The removed setting key
---@return ScopeName scopeType
---@return string scopeKey
---@return string namespace
---@return string settingKey
function SettingsMigration:GetKeyInfo(key)
	local scopeType, scopeKey, namespace, settingKey, extraPart = strsplit(Types.KEY_SEP, key)
	assert(settingKey and not extraPart)
	scopeType = Types.SCOPES_LOOKUP[scopeType]
	return scopeType, scopeKey, namespace, settingKey
end

---Gets the scope key from a removed setting key.
---@param key RemovedSettingKey The removed setting key
---@return string
function SettingsMigration:GetScopeKey(key)
	local scopeKey = strmatch(key, "^.+@(.+)@.+@.+$")
	assert(scopeKey)
	return scopeKey
end
