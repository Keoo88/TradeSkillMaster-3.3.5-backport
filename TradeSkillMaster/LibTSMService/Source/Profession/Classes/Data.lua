-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Data = LibTSMService:Init("Profession.Data")
local EnchantData = LibTSMService:From("LibTSMData"):Include("Enchant")
local SalvageData = LibTSMService:From("LibTSMData"):Include("Salvage")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the result of an indirect craft.
---@param spellId number The recipe spell ID
---@return string|string[]|nil
function Data.GetIndirectCraftResult(spellId)
	return EnchantData.Recipes[spellId] or SalvageData.MassMill[spellId] or EnchantData.QualityRecipes[spellId] or nil
end
