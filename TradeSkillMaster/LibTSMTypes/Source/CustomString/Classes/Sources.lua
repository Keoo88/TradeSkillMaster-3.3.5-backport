-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Sources = LibTSMTypes:Init("CustomString.Sources")
local Types = LibTSMTypes:Include("CustomString.Types")
local Utils = LibTSMTypes:Include("CustomString.Utils")
local private = {
	frameTimeFunc = nil,
	customSources = nil, ---@type table<string,string>
	keys = {},
	info = {},
	lastRegisteredSourceChange = 0,
	objectValidated = {},
}



-- ============================================================================
-- Module Methods
-- ============================================================================

---Sets the function to call to get the current frame time for caching.
---@param frameTimeFunc fun(): number Function to call
function Sources.SetFrameTimeFunc(frameTimeFunc)
	private.frameTimeFunc = frameTimeFunc
end

---Loads custom sources and returns the previously-registered sources.
---@param customSources table<string,string> The custom sources
---@param removedKeys string[] The keys that were removed due to being invalid
---@return table<string,string>
function Sources.LoadCustomSources(customSources, removedKeys)
	local prevCustomSources = private.customSources
	private.customSources = customSources
	for key, text in pairs(private.customSources) do
		if Sources.IsValidKey(key, true) then
			private.customSources[key] = Utils.SanitizeCustomString(text)
		else
			private.customSources[key] = nil
			tinsert(removedKeys, key)
		end
	end
	private.lastRegisteredSourceChange = private.GetFrameTime()
	return prevCustomSources
end

---Register a source.
---@param moduleName string The name of the module which provides this source
---@param key string The key for this source
---@param label string The label which describes this source for display to the user
---@param callback fun(itemString: string): number? The source callback
---@param sourceType Types.SOURCE_TYPE The type of the source
function Sources.Register(moduleName, key, label, callback, sourceType)
	local keyLower = strlower(key)
	tinsert(private.keys, keyLower)
	private.info[keyLower] = {
		moduleName = moduleName,
		key = key,
		label = label,
		callback = callback,
		sourceType = sourceType,
		cache = {},
	}
	private.lastRegisteredSourceChange = private.GetFrameTime()
end

---Gets a source's value for a given item.
---@param key string The source key
---@param itemString string The item string to get the value for
---@return number?
function Sources.GetValue(key, itemString)
	key = strlower(key)
	local info = private.info[key]
	if not itemString or not info then
		return nil
	end
	if info.sourceType == Types.SOURCE_TYPE.VOLATILE then
		local frameTime = private.GetFrameTime()
		if (info.cache.frameTime or frameTime) ~= frameTime then
			wipe(info.cache)
		end
		info.cache.frameTime = frameTime
	end
	local cachedValue = info.cache[itemString]
	if cachedValue ~= nil then
		return cachedValue or nil
	end
	local value = info.callback(itemString)
	value = type(value) == "number" and value or nil
	info.cache[itemString] = value or false
	return value
end

---Returns whether or not a key exists as a registered source.
---@param key string The source key
---@return boolean
function Sources.IsRegistered(key)
	return private.info[strlower(key)] and true or false
end

---Returns whether or not a key exists as a registered custom source.
---@param key string The source key
---@return boolean
function Sources.IsCustomRegistered(key)
	return private.customSources[key] and true or false
end

---Gets info for a specified source.
---@param key string The source key
---@return string? displayKey
---@return string? label
---@return string? moduleName
---@return Types.SOURCE_TYPE? sourceType
function Sources.GetInfo(key)
	key = strlower(key)
	local info = private.info[key]
	if not info then
		return nil, nil, nil, nil
	end
	return info.key, info.label, info.moduleName, info.sourceType
end

---Iterate over the registered sources.
---@return any @An iterator which provides the following fields: `index`, `key`, `label`, `module`
function Sources.Iterator()
	return private.IteratorHelper, nil, 0
end

---Iterate over the registered custom sources.
---@return fun(): string, string @An iterator which provides the following fields: `key`, `text`
function Sources.CustomIterator()
	return pairs(private.customSources)
end

---Invalides the cache for a given source and optional item.
---@param key string The source key
---@param itemString? string the item string
function Sources.InvalidateCache(key, itemString)
	key = strlower(key)
	local info = private.info[key]
	if not info then
		return
	end
	if info.sourceType == Types.SOURCE_TYPE.PRICE_DB then
		assert(not itemString)
	elseif info.sourceType ~= Types.SOURCE_TYPE.NORMAL then
		error("Source cannot change: "..key)
	end
	if itemString then
		info.cache[itemString] = nil
	else
		wipe(info.cache)
	end
end

---Returns whether or not a source key is valid.
---@param key string The source key
---@param allowExistingCustom boolean Allow existing custom sources
---@return boolean
---@return Types.ERROR?
---@return string?
function Sources.IsValidKey(key, allowExistingCustom)
	if key == "" or gsub(key, "([a-z]+)", "") ~= "" then
		return false, Types.ERROR.INVALID_CHARACTER, key
	elseif not allowExistingCustom and Sources.IsCustomRegistered(key) then
		return false, Types.ERROR.ALREADY_EXISTS, key
	elseif Sources.IsRegistered(key) then
		return false, Types.ERROR.RESERVED_WORD, key
	elseif Types.FUNCTION_INFO[key] or key == "baseitem" then
		return false, Types.ERROR.RESERVED_WORD, key
	else
		return true
	end
end

---Adds a custom source.
---@param key string The source key
---@param text string The custom string text
function Sources.AddCustom(key, text)
	private.CheckNewCustomSourceKey(key)
	private.customSources[key] = text
	private.lastRegisteredSourceChange = private.GetFrameTime()
end

---Changes the key for a custom source.
---@param oldKey string The old source key
---@param newKey string The new source key
function Sources.RenameCustom(oldKey, newKey)
	assert(oldKey ~= newKey)
	private.CheckNewCustomSourceKey(newKey)
	local value = private.customSources[oldKey]
	assert(value)
	private.customSources[newKey] = value
	private.customSources[oldKey] = nil
	private.lastRegisteredSourceChange = private.GetFrameTime()
end

---Removes a custom source.
---@param key string The source key
function Sources.RemoveCustom(key)
	assert(private.customSources[key])
	private.customSources[key] = nil
	private.lastRegisteredSourceChange = private.GetFrameTime()
end

---Updates the text of a custom source.
---@param key string The source key
---@param text string The custom string text
function Sources.UpdateCustom(key, text)
	assert(private.customSources[key])
	private.customSources[key] = text
	private.lastRegisteredSourceChange = private.GetFrameTime()
end

---Validates the sources used by a custom string object.
---@param obj CustomStringObject The custom string object
---@return EnumValue? errType
---@return string? source
function Sources.ValidateObject(obj)
	if (private.objectValidated[obj] or 0) < private.lastRegisteredSourceChange then
		for _, source, convertArg in obj:DependantSourceIterator() do
			if source == "convert" then
				if select(4, Sources.GetInfo(convertArg)) ~= Types.SOURCE_TYPE.PRICE_DB then
					return Types.ERROR.INVALID_CONVERT_ARG, convertArg
				end
			elseif not Sources.IsRegistered(source) and not Sources.IsCustomRegistered(source) then
				return Types.ERROR.INVALID_SOURCE, source
			end
		end
		private.objectValidated[obj] = private.GetFrameTime()
	end
	return nil, nil
end

---Gets the text of a custom source.
---@param key string The source key
---@return string?
function Sources.GetCustomText(key)
	return private.customSources[key]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetFrameTime()
	return private.frameTimeFunc and private.frameTimeFunc() or 0
end

function private.CheckNewCustomSourceKey(key)
	assert(key ~= "")
	assert(gsub(key, "([a-z]+)", "") == "")
	assert(not private.customSources[key])
end

function private.IteratorHelper(_, index)
	index = index + 1
	local key = private.keys[index]
	if not key then
		return
	end
	local info = private.info[key]
	return index, info.key, info.label, info.moduleName
end
