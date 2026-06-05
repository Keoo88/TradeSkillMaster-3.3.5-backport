-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local CustomString = LibTSMTypes:Init("CustomString")
local Object = LibTSMTypes:IncludeClassType("CustomStringObject")
local Sources = LibTSMTypes:Include("CustomString.Sources")
local Types = LibTSMTypes:Include("CustomString.Types")
local Tokenizer = LibTSMTypes:Include("CustomString.Tokenizer")
local SmartMap = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("SmartMap")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local MoneyFormatter = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("MoneyFormatter")
local private = {
	sanitizeMap = nil,
	sanitizeMapReader = nil,
	objects = {}, ---@type table<string,CustomStringObject>
	sanitizeCache = {},
	customSourceCallbacks = {},
}
CustomString.TOKEN_TYPE = Types.TOKEN
CustomString.ERROR_TYPE = Types.ERROR
CustomString.SOURCE_TYPE = Types.SOURCE_TYPE



-- ============================================================================
-- Module Loading
-- ============================================================================

CustomString:OnModuleLoad(function()
	private.sanitizeMap = SmartMap.New("string", "string", function(text) return strlower(strtrim(text)) end)
	private.sanitizeMapReader = private.sanitizeMap:CreateReader()
	Object.SetPriceFunc(private.PriceFunc)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new token list object.
---@return NamedTupleList
function CustomString.CreateTokenList()
	return Types.CreateTokenList()
end

---Populates an empty token list object based on the specified custom string.
---@param tokenList NamedTupleList The token list
---@param str string The custom string
function CustomString.PopulateTokenList(tokenList, str)
	Tokenizer.GetTokens(str, tokenList)
end

---Sets the function to call to get the current frame time for caching.
---@param timeFunc fun(): number Function to call
function CustomString.SetFrameTimeFunc(timeFunc)
	Sources.SetFrameTimeFunc(timeFunc)
end

---Sets the function to call when a loop is detected in a custom string.
---@param loopHandler fun(text: string) Function to call (gets passed the custom string text)
function CustomString.SetLoopHandler(loopHandler)
	Object.SetLoopHandler(loopHandler)
end

---Loads custom sources.
---@param customSources table<string,string> The custom sources
---@param removedKeys string[] A table to store the keys that were removed due to being invalid
function CustomString.LoadCustomSources(customSources, removedKeys)
	local prevSources = Sources.LoadCustomSources(customSources, removedKeys)
	if prevSources then
		for source in pairs(prevSources) do
			CustomString.InvalidateCache(source)
		end
	end
end

---Invalidates any internal caches for the specified source.
---@param source string The source key
---@param itemString? string the item string
function CustomString.InvalidateCache(source, itemString)
	Sources.InvalidateCache(source, itemString)
	Object.InvalidateCache(source)
end

---Validates the sources used by a custom string object.
---@param obj CustomStringObject The custom string object
---@return Types.ERROR? errType
---@return string? source
function CustomString.ValidateObjectSources(obj)
	return Sources.ValidateObject(obj)
end

---Returns whether or not a string is a reserved word.
---@param str string The string (must be lower case)
---@return boolean
function CustomString.IsReservedWord(str)
	return (Types.FUNCTION_INFO[str] or str == "baseitem") and true or false
end

---Register a source.
---@param moduleName string The name of the module which provides this source
---@param key string The key for this source
---@param label string The label which describes this source for display to the user
---@param callback fun(itemString: string): number? The source callback
---@param sourceType Types.SOURCE_TYPE The type of the source
function CustomString.RegisterSource(moduleName, key, label, callback, sourceType)
	Sources.Register(moduleName, key, label, callback, sourceType)
end

---Returns whether or not a key exists as a registered source.
---@param key string The source key
---@return boolean
function CustomString.IsSourceRegistered(key)
	return Sources.IsRegistered(key)
end

---Returns whether or not a key exists as a registered custom source.
---@param key string The source key
---@return boolean
function CustomString.IsCustomSourceRegistered(key)
	return Sources.IsCustomRegistered(key)
end

---Gets info for a specified source.
---@param key string The source key
---@return string? displayKey
---@return string? label
---@return string? moduleName
---@return Types.SOURCE_TYPE? sourceType
function CustomString.GetSourceInfo(key)
	return Sources.GetInfo(key)
end

---Iterate over the registered sources.
---@return fun(): number, string, string, string @An iterator which provides the following fields: `index`, `key`, `label`, `module`
function CustomString.SourceIterator()
	return Sources.Iterator()
end

---Iterate over the registered custom sources.
---@return fun(): string, string @An iterator which provides the following fields: `key`, `value`
function CustomString.CustomSourceIterator()
	return Sources.CustomIterator()
end

---Gets a source's value for a given item.
---@param key string The source key
---@param itemString string The item string to get the value for
---@return number?
function CustomString.GetSourceValue(key, itemString)
	return Sources.GetValue(key, itemString)
end

---Validate a custom source key.
---@param key string The custom source key
---@return boolean result
---@return CustomString.ERROR_TYPE? errType
---@return string? errTokenStr
function CustomString.ValidateCustomSourceName(key)
	return Sources.IsValidKey(key)
end

---Adds a custom source.
---@param key string The source key
---@param text string The custom string text
function CustomString.AddCustomSource(key, text)
	Sources.AddCustom(key, private.Sanitize(text))
	private.CallCustomSourceCallbacks()
end

---Changes the key for a custom source.
---@param oldKey string The old source key
---@param newKey string The new source key
function CustomString.RenameCustomSource(oldKey, newKey)
	Sources.RenameCustom(oldKey, newKey)
	CustomString.InvalidateCache(oldKey)
	CustomString.InvalidateCache(newKey)
	private.CallCustomSourceCallbacks()
end

---Removes a custom source.
---@param key string The source key
function CustomString.RemoveCustomSource(key)
	Sources.RemoveCustom(key)
	CustomString.InvalidateCache(key)
	private.CallCustomSourceCallbacks()
end

---Updates the text of a custom source.
---@param key string The source key
---@param text string The custom string text
function CustomString.UpdateCustomSource(key, text)
	Sources.UpdateCustom(key, private.Sanitize(text))
	CustomString.InvalidateCache(key)
end

---Imports custom sources.
---@param customSources table<string, string> The custom sources to import
function CustomString.ImportCustomSources(customSources)
	local hasNew = false
	for key, text in pairs(customSources) do
		if CustomString.IsCustomSourceRegistered(key) then
			CustomString.UpdateCustomSource(key, text)
		else
			Sources.AddCustom(key, private.Sanitize(text))
			hasNew = true
		end
	end
	if hasNew then
		private.CallCustomSourceCallbacks()
	end
end

---Validate a custom string.
---@param text string The custom string
---@return boolean isValid
---@return CustomString.ERROR_TYPE? errType
---@return string? errTokenStr
function CustomString.Validate(text)
	local obj, errType, errTokenStr = private.GetObject(tostring(text))
	if obj then
		return true, nil, nil
	else
		return false, errType, errTokenStr
	end
end

---Evaulates a custom string for an item.
---@param text string The custom string text
---@param itemString string The item to evaluate the custom string for
---@param allowZero boolean If true, allows the result to be 0
---@return number? value
---@return CustomString.ERROR_TYPE? errType
---@return string? errTokenStr
function CustomString.GetValue(text, itemString, allowZero)
	local obj, errType, errArg = private.GetObject(text)
	if not obj then
		return nil, errType, errArg
	end
	local value = obj:Evaluate(itemString)
	if not value or (not allowZero and value == 0) then
		return nil, Types.ERROR.NO_VALUE
	end
	return value
end

---Iterates over the custom sources which a string depends on.
---@param text string The custom string
---@return fun():number, string, string @An iterator with fields: `index`, `name`, `customSourceStr`
function CustomString.DependantCustomSourceIterator(text)
	local result = TempTable.Acquire()
	local obj = private.GetObject(tostring(text))
	if obj then
		for name, customSourceStr in Sources.CustomIterator() do
			if obj:IsDependantOnSource(name) then
				tinsert(result, name)
				tinsert(result, customSourceStr)
			end
		end
	end
	return TempTable.Iterator(result, 2)
end

---Returns whether or not a custom string depends on the specified source.
---@param text string The custom string
---@param key string The source key
function CustomString.DependsOnSource(text, key)
	local obj = private.GetObject(tostring(text))
	assert(obj)
	return obj:IsDependantOnSource(key)
end

---Register a callback when custom sources change.
---@param callback function The callback function
function CustomString.RegisterCustomSourceCallback(callback)
	tinsert(private.customSourceCallbacks, callback)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Sanitize(text)
	assert(text)
	local result = private.sanitizeCache[text]
	if not result then
		result = strlower(strtrim(tostring(text)))
		result = MoneyFormatter.FromString(result) and gsub(result, String.Escape(MoneyFormatter.GetLargeNumberSeperator()), "") or result
		private.sanitizeCache[text] = result
	end
	return result
end

function private.GetObject(text)
	text = private.sanitizeMapReader[text]
	private.objects[text] = private.objects[text] or Object.Create(text)
	local obj = private.objects[text]
	local isValid, errType, errTokenStr = obj:Validate()
	if not isValid then
		return nil, errType, errTokenStr
	end
	errType, errTokenStr = Sources.ValidateObject(obj)
	if errType then
		return nil, errType, errTokenStr
	end
	return obj, nil, nil
end

function private.PriceFunc(itemString, key)
	local customSourceText = Sources.GetCustomText(key)
	if customSourceText then
		local obj = private.GetObject(customSourceText)
		local value = obj and obj:Evaluate(itemString)
		if not value or value == 0 then
			return nil
		end
		return value
	else
		return Sources.GetValue(key, itemString)
	end
end

function private.CallCustomSourceCallbacks()
	for _, callback in ipairs(private.customSourceCallbacks) do
		callback()
	end
end
