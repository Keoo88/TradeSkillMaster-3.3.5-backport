-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local CharacterInfo = LibTSMWoW:Init("Util.CharacterInfo")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the level of the current charcter.
---@return number
function CharacterInfo.GetLevel()
	return UnitLevel("player")
end

---Gets the specialization ID for the current character (or nil if none).
---@return number?
function CharacterInfo.GetSpecializationId()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.CHARACTER_SPECIALIZATION) then
		return nil
	end
	local spec = GetSpecialization()
	return spec and GetSpecializationInfo(spec) or nil
end

---Gets the max player level.
---@return number
function CharacterInfo.GetMaxLevel()
	if ClientInfo.IsPandaClassic() then
		return 90
	elseif ClientInfo.IsWrathClassic() then
		return 80
	elseif ClientInfo.IsBCClassic() then
		return 70
	elseif ClientInfo.IsVanillaClassic() then
		return 60
	elseif ClientInfo.IsRetail() then
		return 80
	else
		error("Invalid game version")
	end
end

---Ambiguates a character name.
---@param name string
---@return string
function CharacterInfo.Ambiguate(name)
	return Ambiguate(name, "none")
end
