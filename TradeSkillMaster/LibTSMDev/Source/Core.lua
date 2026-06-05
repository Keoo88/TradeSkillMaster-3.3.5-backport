-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
local LibTSMDev = ADDON_TABLE.LibTSMCore.NewComponent("LibTSMDev")
	:AddDependency("LibTSMApp")
	:AddDependency("LibTSMUI")
	:AddDependency("LibTSMService")
	:AddDependency("LibTSMSystem")
	:AddDependency("LibTSMWoW")
	:AddDependency("LibTSMTypes")
	:AddDependency("LibTSMUtil")
	:AddDependency("LibTSMData")
ADDON_TABLE.LibTSMDev = LibTSMDev

-- Only create the TSMDEV table if we're in a dev or test environment
if not LibTSMDev.IsDevVersion() and not LibTSMDev.IsTestVersion() then
	return
end
TSMDEV = {} ---@class TSMDEV
