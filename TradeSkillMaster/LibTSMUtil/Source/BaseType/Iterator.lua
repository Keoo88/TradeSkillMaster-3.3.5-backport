-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Iterator = LibTSMUtil:DefineClassType("Iterator")
local private = {}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new Iterator object.
---@return Iterator
function Iterator.__static.New()
	return Iterator()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function Iterator.__private:__init()
	self._filterFunc = nil
	self._mapFunc = nil
	self._contextTables = {}
end



-- ============================================================================
-- Public Class Methods Functions
-- ============================================================================

---Sets a function to filter iterator values (happens before mapping).
---@param filterFunc fun(context: any, key: any, ...): boolean Function which returns if a value should be provided by the iterator
---@return Iterator
function Iterator:SetFilterFunc(filterFunc)
	assert(filterFunc and not self._filterFunc)
	self._filterFunc = filterFunc
	return self
end

---Sets a function to map iterator values (happens after filtering).
---@param mapFunc fun(context: any, key: any, ...): ... Function used to map iterator values (the key cannot be mapped and shouldn't be returned)
---@return Iterator
function Iterator:SetMapFunc(mapFunc)
	assert(mapFunc and not self._mapFunc)
	self._mapFunc = mapFunc
	return self
end

---Executes the iterator (applying any configured filtering / mapping).
---
---**NOTE:** This iterator must be run to completion and not be interrupted (i.e. with a `break` or `return`).
---@param func fun(): ... Iterator function
---@param context any Iterator context
---@param key any Initial iterator key
---@return fun(): ... @Iterator with the same fields as `func`
function Iterator:Execute(func, context, key)
	return self:ExecuteWithContext(nil, func, context, key)
end

---Executes the iterator (applying any configured filtering / mapping) with extra context.
---
---**NOTE:** This iterator must be run to completion and not be interrupted (i.e. with a `break` or `return`).
---@param funcContext any Context to pass as the first argument to the filter and map functions
---@param func fun(): ... Iterator function
---@param context any Iterator context
---@param key any Initial iterator key
---@return fun(): ... @Iterator with the same fields as `func`
function Iterator:ExecuteWithContext(funcContext, func, context, key)
	local iterContext = self:_GetContext(funcContext, func, context, key)
	return private.Iterator, iterContext
end

---Gets the first value from an iterator (applying any configured filtering / mapping).
---@param func fun(): ... Iterator function
---@param context any Iterator context
---@param key any Initial iterator key
---@return ...
function Iterator:GetFirstValue(func, context, key)
	return self:GetFirstValueWithContext(nil, func, context, key)
end

---Gets the first value from an iterator (applying any configured filtering / mapping) with extra context.
---@param funcContext any Context to pass as the first argument to the filter and map functions
---@param func fun(): ... Iterator function
---@param context any Iterator context
---@param key any Initial iterator key
---@return ...
function Iterator:GetFirstValueWithContext(funcContext, func, context, key)
	local iterContext = self:_GetContext(funcContext, func, context, key)
	iterContext.firstOnly = true
	return private.PassThroughAndRelease(iterContext, private.Iterator(iterContext))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Iterator.__private:_GetContext(funcContext, func, context, key)
	assert(func)
	local iterContext = tremove(self._contextTables) or {}
	assert(not next(iterContext))
	iterContext.iter = self
	iterContext.funcContext = funcContext
	iterContext.func = func
	iterContext.context = context
	iterContext.key = key
	return iterContext
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Iterator(iterContext)
	return private.HandleValue(iterContext, iterContext.func(iterContext.context, iterContext.key))
end

function private.HandleValue(iterContext, key, ...)
	if key == nil then
		if iterContext.firstOnly then
			-- The context will be released by the caller
			return
		end
		return private.PassThroughAndRelease(iterContext)
	end
	iterContext.key = key
	local iter = iterContext.iter ---@type Iterator
	if not iter._filterFunc or iter._filterFunc(iterContext.funcContext, key, ...) then
		if iter._mapFunc then
			return key, iter._mapFunc(iterContext.funcContext, key, ...)
		else
			return key, ...
		end
	else
		return private.Iterator(iterContext)
	end
end

function private.PassThroughAndRelease(iterContext, ...)
	local iter = iterContext.iter
	wipe(iterContext)
	tinsert(iter._contextTables, iterContext)
	return ...
end
