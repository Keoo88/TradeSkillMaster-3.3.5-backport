-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Conversions = LibTSMApp:Init("Service.Conversions")
local DisenchantData = LibTSMApp:From("LibTSMData"):Include("Disenchant")
local Conversion = LibTSMApp:From("LibTSMTypes"):Include("Item.Conversion")
local ItemClass = LibTSMApp:From("LibTSMWoW"):Include("Util.ItemClass")
local DISENCHANT_CLASS_ID_LOOKUP = {
	[DisenchantData.ITEM_CLASSES.ARMOR] = ItemClass.GetArmorClassId(),
	[DisenchantData.ITEM_CLASSES.WEAPON] = ItemClass.GetWeaponClassId(),
	[DisenchantData.ITEM_CLASSES.PROFESSION] = ItemClass.GetProfessionClassId(),
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
	local amountOfMats, matRate, minAmount, maxAmount, requiredSkill = nil, nil, nil, nil, nil
	local data = Conversion.GetDisenchantData(targetItemString)
	for _, info in ipairs(data.sourceInfo) do
		local sourceClassId = DISENCHANT_CLASS_ID_LOOKUP[info.class]
		assert(sourceClassId)
		if sourceClassId == classId and info.quality == quality and itemLevel >= info.minItemLevel and itemLevel <= info.maxItemLevel and (not expansion or expansion == data.expansion) then
			amountOfMats = info.amountOfMats
			matRate = info.matRate
			minAmount = info.minAmount
			maxAmount = info.maxAmount
			requiredSkill = info.requiredSkill
		end
	end
	return amountOfMats, matRate, minAmount, maxAmount, requiredSkill
end
