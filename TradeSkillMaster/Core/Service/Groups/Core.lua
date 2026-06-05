-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Groups = TSM:NewPackage("Groups") ---@type AddonPackage
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local private = {
	settings = nil,
}



-- ============================================================================
-- New Modules Functions
-- ============================================================================

function Groups.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("profile", "userData", "groups")
		:AddKey("profile", "userData", "items")
	GroupOperation.Configure()
	Groups.ReloadSettings()
end

function Groups.ReloadSettings()
	GroupOperation.Load(private.settings.groups, private.settings.items)
end
