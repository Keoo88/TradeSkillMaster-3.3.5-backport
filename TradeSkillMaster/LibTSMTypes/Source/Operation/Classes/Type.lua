-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local OperationType = LibTSMTypes:DefineClassType("OperationType")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local COMMON_SETTING_KEYS = {
	ignorePlayer = true,
	ignoreFactionrealm = true,
	relationships = true,
}
local EXTRA_TYPE_INFO = EnumType.New("OPERATION_TYPE_EXTRA_TYPE_INFO", {
	CUSTOM_STRING = EnumType.NewValue(),
})



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new operation type.
---@param name string The internal name
---@param localizedName string The localized name
---@param maxOperations number The maximum operations of this type which can be added to a group
---@return OperationType
function OperationType.__static.New(name, localizedName, maxOperations)
	return OperationType(name, localizedName, maxOperations)
		:AddTableSetting("ignorePlayer")
		:AddTableSetting("ignoreFactionrealm")
		:AddTableSetting("relationships")
end

---Iterates over the common setting keys.
---@return fun(): string @Iterator with fields: `settingKey`
function OperationType.__static.CommonSettingKeyIterator()
	return Table.KeyIterator(COMMON_SETTING_KEYS)
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function OperationType.__private:__init(name, localizedName, maxOperations)
	assert(name and localizedName and maxOperations)
	self._name = name ---@type string
	self._localizedName = localizedName ---@type string
	self._maxOperations = maxOperations ---@type number
	self._sanitizeFunc = nil
	self._settingType = {}
	self._settingDefault = {}
	self._settingSanitizeFunc = {}
	self._settingExtraTypeInfo = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets a custom function called to sanitize operation settings.
---@param func fun(settings: OperationSettings) A function which sanitizes the operation settings
---@return OperationType
function OperationType:SetCustomSanitizeFunc(func)
	self._sanitizeFunc = func
	return self
end

---Adds a number setting.
---@param key string The setting key
---@param defaultValue? number The default value (defaults to 0)
---@param sanitizeFunc? fun(val: number): number A custom function called to sanitize the value
---@return OperationType
function OperationType:AddNumberSetting(key, defaultValue, sanitizeFunc)
	self:_AddSetting(key, "number", defaultValue or 0, sanitizeFunc)
	return self
end

---Adds a string setting.
---@param key string The setting key
---@param defaultValue? string The default value (defaults to "")
---@param sanitizeFunc? fun(val: string): string A custom function called to sanitize the value
---@return OperationType
function OperationType:AddStringSetting(key, defaultValue, sanitizeFunc)
	self:_AddSetting(key, "string", defaultValue or "", sanitizeFunc)
	return self
end

---Adds a custom string setting.
---@param key string The setting key
---@param defaultValue string The default value
---@param sanitizeFunc? fun(val: string): string A custom function called to sanitize the value
---@return OperationType
function OperationType:AddCustomStringSetting(key, defaultValue, sanitizeFunc)
	self:_AddSetting(key, "string", defaultValue, sanitizeFunc, EXTRA_TYPE_INFO.CUSTOM_STRING)
	return self
end

---Adds a boolean setting.
---@param key string The setting key
---@param defaultValue? boolean The default value (defaults to false)
---@param sanitizeFunc? fun(val: boolean): boolean A custom function called to sanitize the value
---@return OperationType
function OperationType:AddBooleanSetting(key, defaultValue, sanitizeFunc)
	self:_AddSetting(key, "boolean", defaultValue or false, sanitizeFunc)
	return self
end

---Adds a table setting.
---@param key string The setting key
---@param defaultValue? table The default value (defaults to `{}`)
---@param sanitizeFunc? fun(val: table): table A custom function called to sanitize the value
---@return OperationType
function OperationType:AddTableSetting(key, defaultValue, sanitizeFunc)
	self:_AddSetting(key, "table", defaultValue or {}, sanitizeFunc)
	return self
end



-- ============================================================================
-- Internal Class Methods
-- ============================================================================

---Gets the name.
---@return string
function OperationType:GetName()
	return self._name
end

---Gets the localized name.
---@return string
function OperationType:GetLocalizedName()
	return self._localizedName
end

---Gets the maximum number of operations.
---@return string
function OperationType:GetMaxNumber()
	return self._maxOperations
end

---Returns whether or not a setting key exists.
---@param key string The setting key
---@return boolean
function OperationType:HasSetting(key)
	return self._settingType[key] and true or false
end

---Iterates over the setting keys,
---@return fun(): string @An iterator with fields: `key`
function OperationType:SettingIterator()
	return Table.KeyIterator(self._settingType)
end

---Gets the default value of a setting.
---@param key string The setting key
---@return string|number|boolean|table
function OperationType:GetDefault(key)
	assert(self:HasSetting(key))
	return self._settingType[key] == "table" and CopyTable(self._settingDefault[key]) or self._settingDefault[key]
end

---Sanitizes an operation's settings (returns if settings were reset).
---@param name string The name of the operation for logging purposes
---@param settings OperationSettings The operation setttings
---@param silentMissingCommonKeys boolean Don't log missing common keys
---@return boolean
function OperationType:SanitizeOperation(name, settings, silentMissingCommonKeys)
	local didReset = false
	if self._sanitizeFunc then
		self._sanitizeFunc(settings)
	end
	for key, value in pairs(settings) do
		if not self:HasSetting(key) then
			settings[key] = nil
		else
			local settingType = self._settingType[key]
			if type(value) ~= settingType then
				if settingType == "string" and type(value) == "number" then
					-- Some custom price settings were potentially stored as numbers previously, so just convert them
					settings[key] = tostring(value)
				else
					didReset = true
					Log.Err("Resetting operation setting %s,%s,%s (%s)", self._name, name, tostring(key), tostring(value))
					settings[key] = self:GetDefault(key)
				end
			elseif self._settingSanitizeFunc[key] then
				settings[key] = self._settingSanitizeFunc[key](value)
			end
		end
	end
	for key in self:SettingIterator() do
		local settingType = self._settingType[key]
		if settings[key] == nil then
			-- This key was missing
			if settingType == "boolean" then
				-- We previously stored booleans as nil instead of false
				settings[key] = false
			else
				if not silentMissingCommonKeys or not COMMON_SETTING_KEYS[key] then
					didReset = true
					Log.Err("Resetting missing operation setting %s,%s,%s", self._name, name, tostring(key))
				end
				settings[key] = self:GetDefault(key)
			end
		end
	end
	return didReset
end

---Returns whether or not a setting is a custom string.
---@param key string The setting key
---@return boolean
function OperationType:IsCustomString(key)
	assert(self:HasSetting(key))
	return self._settingExtraTypeInfo[key] == EXTRA_TYPE_INFO.CUSTOM_STRING
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationType.__private:_AddSetting(key, settingType, defaultValue, sanitizeFunc, extraTypeInfo)
	assert(type(key) == "string")
	assert(type(defaultValue) == settingType)
	assert(sanitizeFunc == nil or type(sanitizeFunc) == "function")
	assert(not self:HasSetting(key))
	self._settingType[key] = settingType
	self._settingDefault[key] = defaultValue
	self._settingSanitizeFunc[key] = sanitizeFunc
	self._settingExtraTypeInfo[key] = extraTypeInfo
end
