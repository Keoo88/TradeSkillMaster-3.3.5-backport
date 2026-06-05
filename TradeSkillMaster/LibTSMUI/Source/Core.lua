-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMUI = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMUI")
	:AddDependency("LibTSMWoW")
	:AddDependency("LibTSMTypes")
	:AddDependency("LibTSMUtil")
	:AddDependency("LibTSMData")
	:AddDependency("LibTSMService")
assert(ADDON_TABLE.Locale)
ADDON_TABLE.LibTSMUI.Locale = ADDON_TABLE.Locale
