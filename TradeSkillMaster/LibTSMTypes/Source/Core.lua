-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMTypes = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMTypes")
	:AddDependency("LibTSMUtil")
	:AddDependency("LibTSMData")
