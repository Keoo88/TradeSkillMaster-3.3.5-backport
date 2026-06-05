-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local CustomStringObject = LibTSMTypes:DefineClassType("CustomStringObject")
local Tokenizer = LibTSMTypes:Include("CustomString.Tokenizer")
local AST = LibTSMTypes:Include("CustomString.AST")
local CodeGen = LibTSMTypes:IncludeClassType("CustomStringCodeGen")
local Types = LibTSMTypes:Include("CustomString.Types")
local Math = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Math")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local Conversion = LibTSMTypes:Include("Item.Conversion")
local private = {
	loopHandler = nil,
	priceFunc = nil,
	recursiveCalls = 0,
	convertCache = {},
}
local DEPENDENCY_SEP = "/"



-- ============================================================================
-- Helpers Object
-- ============================================================================

local HELPERS = {}
HELPERS.INVALID = newproxy()
HELPERS.GetBaseItemString = function(itemString)
	return ItemString.GetBaseFast(itemString)
end
HELPERS.GetPrice = function(itemString, key, convertArg)
	local val = nil
	if key == "convert" then
		private.convertCache[convertArg] = private.convertCache[convertArg] or {}
		if not private.convertCache[convertArg][itemString] then
			local conversions = Conversion.GetSourceItems(itemString)
			if conversions then
				local minPrice = nil
				for sourceItemString, rate in pairs(conversions) do
					local price = private.priceFunc(sourceItemString, convertArg)
					if price and price > 0 then
						price = price / rate
						minPrice = min(minPrice or price, price)
					end
				end
				private.convertCache[convertArg][itemString] = minPrice or -1
			else
				private.convertCache[convertArg][itemString] = -1
			end
		end
		val = private.convertCache[convertArg][itemString]
	else
		val = private.priceFunc(itemString, key)
	end
	if not val or val < 0 then
		return HELPERS.INVALID
	end
	return val
end



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Sets the function to call when a loop is detected in a custom string.
---@param loopHandler fun(str: string) Function to call (gets passed the setring)
function CustomStringObject.__static.SetLoopHandler(loopHandler)
	assert(loopHandler and not private.loopHandler)
	private.loopHandler = loopHandler
end

---Sets the function used to lookup a price value.
---@param priceFunc fun(itemString: string, key: string): number? The function
function CustomStringObject.__static.SetPriceFunc(priceFunc)
	assert(priceFunc and not private.priceFunc)
	private.priceFunc = priceFunc
end

---Invalidates any internal caches for the specified source.
---@param source string The source
function CustomStringObject.__static.InvalidateCache(source)
	if private.convertCache[source] then
		wipe(private.convertCache[source])
	end
end

---Creates a custom string for the specified text.
---@param str string The custom string text
---@return CustomStringObject
function CustomStringObject.__static.Create(str)
	local obj = CustomStringObject()
	obj:_SetString(str)
	return obj
end



-- ============================================================================
-- Class Definition
-- ============================================================================

function CustomStringObject.__private:__init()
	self._str = nil
	self._errType = nil
	self._errTokenIndex = nil
	self._tokenList = Types.CreateTokenList()
	self._tree = Types.CreateNodeTree()
	self._dependencies = {}
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Returns the custom string text.
---@return string
function CustomStringObject:GetString()
	return self._Str
end

---Validates the custom string.
---@return boolean
---@return CustomString.ERROR_TYPE?
---@return string?
function CustomStringObject:Validate()
	if self._errType then
		if self._errTokenIndex == -1 then
			return false, self._errType, nil
		else
			return false, self._errType, self._tokenList:GetRowField(self._errTokenIndex, "str")
		end
	else
		return true, nil, nil
	end
end

---Iterates over the dependant sources.
---@return fun(): string, string?, string? @Iterator with fields: `key`, `source`, `convertArg`
function CustomStringObject:DependantSourceIterator()
	return private.DependantSourceIterator, self._dependencies, nil
end

---Returns whether or not the custom string is dependant on the source.
---@param source string The source
---@return boolean
function CustomStringObject:IsDependantOnSource(source)
	return self._dependencies[source] and true or false
end

---Evalulates the custom string for the specified item.
---@param itemString string The item string
---@return number? @The result
function CustomStringObject:Evaluate(itemString)
	if self._errType then
		error("Evaluating invalid custom string")
	elseif not private.priceFunc then
		error("No price func was set")
	end

	if private.recursiveCalls >= 100 then
		-- We're in a custom string loop
		if private.loopHandler then
			private.loopHandler(self:GetString())
		end
		return nil
	end

	private.recursiveCalls = private.recursiveCalls + 1
	local result = self._func(itemString, HELPERS)
	private.recursiveCalls = private.recursiveCalls - 1

	if result == HELPERS.INVALID or result == math.huge or Math.IsNan(result) then
		return nil
	end
	result = result and floor(result + 0.5)
	return result >= 0 and result or nil
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---Sets the custom string text.
---@param str string
function CustomStringObject.__private:_SetString(str)
	self._str = str
	self._errType = nil
	self._errTokenIndex = nil
	self._tokenList:Wipe()
	self._tree:Wipe()

	if str == "" then
		self:_HandleStepResult(false, Types.ERROR.EMPTY_STRING, -1)
		return
	end

	-- Parse the string into tokens
	Tokenizer.GetTokens(str, self._tokenList)

	-- Generate the AST
	if not self:_HandleStepResult(AST.Generate(self._tokenList, self._tree)) then
		return
	end

	-- Get the dependencies
	for _, source, itemArg, extraArg in AST.DependencyIterator(self._tree) do
		self._dependencies[source] = true
		if source == "convert" then
			assert(extraArg)
			self._dependencies[extraArg] = true
			if itemArg then
				self._dependencies[source..DEPENDENCY_SEP..extraArg..DEPENDENCY_SEP..itemArg] = true
			else
				self._dependencies[source..DEPENDENCY_SEP..extraArg] = true
			end
		else
			assert(not extraArg)
			self._dependencies[source..DEPENDENCY_SEP..(itemArg or "")] = true
		end
	end

	-- Generate the code
	self._code = self:_HandleStepResult(CodeGen.Execute(self._tree))
	if not self._code then
		return
	end

	-- Compile the code
	self._func = assert(loadstring(self._code))()
end

function CustomStringObject.__private:_HandleStepResult(result, errType, errTokenIndex)
	if result then
		assert(errType == nil and errTokenIndex == nil)
	else
		assert(errType ~= nil and errTokenIndex ~= nil)
		self._errType = errType
		self._errTokenIndex = errTokenIndex
	end
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DependantSourceIterator(sources, source)
	while true do
		source = next(sources, source)
		if not source then
			return
		elseif not strmatch(source, DEPENDENCY_SEP) and source ~= "convert" then
			return source, source
		else
			local convertArg = strmatch(source, "^convert"..DEPENDENCY_SEP.."([a-z]+)")
			if convertArg then
				return source, "convert", convertArg
			end
		end
	end
end
