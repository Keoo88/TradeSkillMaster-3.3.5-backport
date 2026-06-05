-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ClientInfo = LibTSMWoW:Init("Util.ClientInfo")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
ClientInfo.FEATURES = EnumType.New("FEATURES", {
	REAGENT_BAG = EnumType.NewValue(),
	CONNECTED_FACTION_AH = EnumType.NewValue(),
	SUB_PROFESSION_NAMES = EnumType.NewValue(),
	AH_COPPER = EnumType.NewValue(),
	AH_STACKS = EnumType.NewValue(),
	AH_UNCOLLECTED_FILTER = EnumType.NewValue(),
	AH_UPGRADES_FILTER = EnumType.NewValue(),
	AH_LIFO = EnumType.NewValue(),
	AH_SELLERS = EnumType.NewValue(),
	BATTLE_PETS = EnumType.NewValue(),
	GARRISON = EnumType.NewValue(),
	GUILD_BANK = EnumType.NewValue(),
	C_AUCTION_HOUSE = EnumType.NewValue(),
	COMMODITY_ITEMS = EnumType.NewValue(),
	CRAFTING_QUALITY = EnumType.NewValue(),
	C_TRADE_SKILL_UI = EnumType.NewValue(),
	TRADE_SKILL_FILTERS = EnumType.NewValue(),
	C_TOOLTIP_INFO = EnumType.NewValue(),
	C_MERCHANTFRAME = EnumType.NewValue(),
	BLACK_MARKET_AH = EnumType.NewValue(),
	REGION_WIDE_TRADING = EnumType.NewValue(),
	CRAFTING_ORDERS = EnumType.NewValue(),
	CHARACTER_SPECIALIZATION = EnumType.NewValue(),
	WARBAND_BANK = EnumType.NewValue(),
})
local private = {
	features = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ClientInfo:OnModuleLoad(function()
	private.features = {
		[ClientInfo.FEATURES.REAGENT_BAG] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.CONNECTED_FACTION_AH] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.SUB_PROFESSION_NAMES] = not LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.AH_COPPER] = not LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.AH_STACKS] = LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.AH_UNCOLLECTED_FILTER] = not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() and not LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.AH_UPGRADES_FILTER] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.AH_LIFO] = not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() and not LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.AH_SELLERS] = LibTSMWoW.IsVanillaClassic() or LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.BATTLE_PETS] = LibTSMWoW.IsRetail() or LibTSMWoW.IsPandaClassic(),
		[ClientInfo.FEATURES.GARRISON] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.GUILD_BANK] = not LibTSMWoW.IsVanillaClassic(),
		[ClientInfo.FEATURES.C_AUCTION_HOUSE] = not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() and not LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.COMMODITY_ITEMS] = not LibTSMWoW.IsVanillaClassic() and not LibTSMWoW.IsBCClassic() and not LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.CRAFTING_QUALITY] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.C_TRADE_SKILL_UI] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.TRADE_SKILL_FILTERS] = LibTSMWoW.IsPandaClassic() or LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic(),
		[ClientInfo.FEATURES.C_TOOLTIP_INFO] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.C_MERCHANTFRAME] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.BLACK_MARKET_AH] = LibTSMWoW.IsRetail() or LibTSMWoW.IsPandaClassic(),
		[ClientInfo.FEATURES.REGION_WIDE_TRADING] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.CRAFTING_ORDERS] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.CHARACTER_SPECIALIZATION] = LibTSMWoW.IsRetail(),
		[ClientInfo.FEATURES.WARBAND_BANK] = LibTSMWoW.IsRetail(),
	}
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not we're running within the retail version of the game.
---@return boolean
function ClientInfo.IsRetail()
	return LibTSMWoW.IsRetail()
end

---Returns whether or not we're running within the Panda Classic version of the game.
---@return boolean
function ClientInfo.IsPandaClassic()
	return LibTSMWoW.IsPandaClassic()
end

---Returns whether or not we're running within the Burning Crusade Classic version of the game.
---@return boolean
function ClientInfo.IsBCClassic()
	return LibTSMWoW.IsBCClassic()
end

---Returns whether or not we're running within the Wrath of the Lich King Classic version of the game.
---@return boolean
function ClientInfo.IsWrathClassic()
	return LibTSMWoW.IsWrathClassic()
end

---Returns whether or not we're running within the Vanilla Classic version of the game.
---@return boolean
function ClientInfo.IsVanillaClassic()
	return LibTSMWoW.IsVanillaClassic()
end

---Checks whether or not a features is available in the current game version.
---@param feature table A value of ClientInfo.FEATURES
---@return boolean
function ClientInfo.HasFeature(feature)
	local result = private.features[feature]
	assert(type(result) == "boolean")
	return result
end

---Gets info on the current client build.
---@return string buildVersion
---@return string buildNum
function ClientInfo.GetBuildInfo()
	local buildVersion, buildNum = GetBuildInfo()
	return buildVersion, buildNum
end

---Gets the current client locale.
---@return string
function ClientInfo.GetLocale()
	return GetLocale()
end

---Returns whether or not the client is locked down for combat.
---@return boolean
function ClientInfo.IsInCombat()
	return InCombatLockdown()
end

---Gets the current frame rate.
---@return number
function ClientInfo.GetFrameRate()
	return GetFramerate()
end

---Gets a unique number for the current frame.
---@return number
function ClientInfo.GetFrameNumber()
	return GetTime()
end
