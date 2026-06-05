-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
ADDON_TABLE.LibTSMApp = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMApp")
	:AddDependency("LibTSMUI")
	:AddDependency("LibTSMService")
	:AddDependency("LibTSMSystem")
	:AddDependency("LibTSMWoW")
	:AddDependency("LibTSMTypes")
	:AddDependency("LibTSMUtil")
	:AddDependency("LibTSMData")
assert(ADDON_TABLE.Locale)
ADDON_TABLE.LibTSMApp.Locale = ADDON_TABLE.Locale
