-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Util = LibTSMTypes:Init("Operation.Util")

---@alias OperationSettings table<string,number|string|boolean|table>



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not an operation name is valid.
---@param name string The operation name
---@return boolean
function Util.IsValidOperationName(name)
	return name == strtrim(name) and name ~= ""
end
