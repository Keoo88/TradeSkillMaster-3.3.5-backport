-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local FSM = LibTSMUtil:Init("FSM")
local Object = LibTSMUtil:IncludeClassType("FSMObject")
local State = LibTSMUtil:IncludeClassType("FSMState")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Create a new FSM.
---@param name string The name of the FSM (for debugging purposes)
---@return FSMObject
function FSM.New(name)
	return Object.New(name)
end

---Create a new FSM state.
---@param state string The name of the state
---@return FSMState
function FSM.NewState(state)
	return State.New(state)
end
