-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Util = LibTSMTypes:Init("Settings.Util")



-- ============================================================================
-- Module Functions
-- ============================================================================

function Util.CopyValue(data)
	if type(data) == "table" then
		return CopyTable(data)
	end
	return data
end
