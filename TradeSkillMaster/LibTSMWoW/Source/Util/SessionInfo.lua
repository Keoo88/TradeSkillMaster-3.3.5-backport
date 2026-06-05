-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local SessionInfo = LibTSMWoW:Init("Util.SessionInfo")
local PLAYER_SEP = " - "
local CHARACTER = UnitName("player")
local FACTION = UnitFactionGroup("player")
local REALM = GetRealmName()
local FACTIONREALM = FACTION..PLAYER_SEP..REALM
local CHARACTER_WITH_REALM = gsub(CHARACTER.."-"..GetRealmName(), "%s+", "")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Get the name of the current character.
---@return string
function SessionInfo.GetCharacterName()
	return CHARACTER
end

---Gets the disambiguated character name (with the realm).
---@return string
function SessionInfo.GetDisambiguatedCharacterName()
	return CHARACTER_WITH_REALM
end

---Get the name of the current faction.
---@return string
function SessionInfo.GetFactionName()
	return FACTION
end

---Get the name of the current realm.
---@return string
function SessionInfo.GetRealmName()
	return REALM
end

---Get the name of the current factionrealm.
---@return string
function SessionInfo.GetFactionrealmName()
	return FACTIONREALM
end

---Check if the specified character (and optionally factionrealm) is the current character.
---@param character string The name of the character to check
---@param factionrealm? string The name of the factionrealm which the character belongs to
---@return boolean
function SessionInfo.IsPlayer(character, factionrealm)
	return character == CHARACTER and (factionrealm == nil or factionrealm == FACTIONREALM)
end

---Formats a character name for display.
---@param character string The name of the character
---@param factionrealm string The factionrealm for the character
---@param full? boolean Use the full factionrealm even if it's the current factionrealm
function SessionInfo.FormatCharacterName(character, factionrealm, full)
	if full then
		return strjoin(PLAYER_SEP, character, factionrealm)
	elseif factionrealm == FACTIONREALM then
		return character
	else
		local faction, realm = strmatch(factionrealm, "^([^ ]+) %- (.+)$")
		return strjoin(PLAYER_SEP, character, realm == REALM and faction or factionrealm)
	end
end

---Gets the region from the C-var.
---@return string
function SessionInfo.GetRegion()
	return GetCVar("Portal")
end

---Checks if we're on a hardcore realm.
---@return boolean
function SessionInfo.IsHardcore()
	return C_Seasons and C_Seasons.HasActiveSeason() and C_Seasons.GetActiveSeason() == Enum.SeasonID.Hardcore or false
end

---Checks if we're on a season of discovery realm.
---@return boolean
function SessionInfo.IsSeasonOfDiscovery()
	return C_Seasons and C_Seasons.HasActiveSeason() and C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery or false
end

---Checks if we're on a fresh realm.
---@return boolean
function SessionInfo.IsFresh()
	if LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic() then
		return true
	end
	if not C_Seasons or not C_Seasons.HasActiveSeason() then
		return false
	end
	local season = C_Seasons.GetActiveSeason()
	return season == Enum.SeasonID.Fresh or season == Enum.SeasonID.FreshHardcore
end
