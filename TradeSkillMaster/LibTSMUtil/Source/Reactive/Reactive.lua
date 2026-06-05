-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Reactive = LibTSMUtil:Init("Reactive")
local ReactiveStateSchema = LibTSMUtil:IncludeClassType("ReactiveStateSchema")
local ReactiveStream = LibTSMUtil:IncludeClassType("ReactiveStream")



-- ============================================================================
-- Module Methods
-- ============================================================================

---Creates a new state schema object.
---@param name string The name for debugging purposes
---@return ReactiveStateSchema
function Reactive.CreateStateSchema(name)
	return ReactiveStateSchema.Create(name)
end

---Creates a new stream object.
---@return ReactiveStream
function Reactive.CreateStream()
	return ReactiveStream.Create()
end
