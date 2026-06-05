-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMSystem = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMSystem")
	:AddDependency("LibTSMTypes")
	:AddDependency("LibTSMUtil")
	:AddDependency("LibTSMData")
