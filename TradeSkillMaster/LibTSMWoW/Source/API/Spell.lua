-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Spell = LibTSMWoW:Init("API.Spell")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets info on a spell.
---@param spellId number The spell ID
---@return string? name
---@return number? icon
---@return number? castTime
function Spell.GetInfo(spellId)
	local info = C_Spell.GetSpellInfo(spellId)
	if not info then
		return nil, nil, nil
	end
	return info.name, info.originalIconID, info.castTime
end
