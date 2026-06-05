-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local DragContext = LibTSMUI:Init("Util.DragContext")
local private = {
	context = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the current drag context.
---@return any
function DragContext.Get()
	return private.context
end

---Sets the drag context.
---@param context any The context
function DragContext.Set(context)
	private.context = context
end

---Clears the drag context.
function DragContext.Clear()
	private.context = nil
end
