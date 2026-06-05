-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Debug = LibTSMWoW:Init("Util.Debug")
local private = {
	origErrorHandler = nil,
}
-- Wrap error handler logic in a loadstring to avoid our locals / stack frames showing in other error handlers
local WRAPPER_FUNC_STR = [[
	return select(1, ...)(select(3, ...)) or (select(2, ...) and select(2, ...)((select(3, ...)))) or nil
]]



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the error handler function.
---@param func fun(errMsg): boolean The error handler function
function Debug.SetErrorHandler(func)
	private.origErrorHandler = geterrorhandler()
	local wrapperFunc = assert(loadstring(WRAPPER_FUNC_STR, "=[tsm error check]"))
	seterrorhandler(function(msg)
		return wrapperFunc(func, private.origErrorHandler, msg)
	end)
end

-- Just assign these so we don't add another stack level
Debug.GetLocals = debuglocals
Debug.Stack = debugstack
