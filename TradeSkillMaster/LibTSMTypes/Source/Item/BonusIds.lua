-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local BonusIds = LibTSMTypes:Init("Item.BonusIds")
local LibBonusId = LibStub("LibBonusId")
local private = {
	bonusIdCache = {},
	bonusIdTemp = {},
}
local BONUS_ID_TO_CRAFTING_STAT_MODIFIER = {
	[6647] = 32,
	[6649] = 36,
	[6650] = 40,
	[6648] = 49,
}
local DROP_LEVEL_MODIFIER_TYPE = 9



-- ============================================================================
-- Module Functions
-- ============================================================================

---Filters a bonus string to only those that have any effective impact on the item.
---@param bonusIds string Colon-separated bonus IDs
---@return string
function BonusIds.Filter(bonusIds)
	private.bonusIdCache[bonusIds] = private.bonusIdCache[bonusIds] or {}
	local cache = private.bonusIdCache[bonusIds]
	if not cache.num then
		assert(not next(private.bonusIdTemp))
		for idStr in gmatch(bonusIds, "%d+") do
			local id = tonumber(idStr)
			if id then
				tinsert(private.bonusIdTemp, id)
			end
		end
		LibBonusId.FilterEffectiveBonusIds(private.bonusIdTemp)
		sort(private.bonusIdTemp)
		cache.num = #private.bonusIdTemp
		if cache.num == 0 then
			cache.value = ""
		else
			local str = table.concat(private.bonusIdTemp, ":")
			cache.value = strjoin(":", cache.num, str)
		end
		wipe(private.bonusIdTemp)
	end
	return cache.value
end

---Removes TREE_BONUS_ID from the list if the item has no tree bonuses.
---@param bonusIds number[] The bonus IDs
---@param itemId number The item ID
function BonusIds.FilterTreeBonusId(bonusIds, itemId)
	LibBonusId.FilterTreeBonusId(bonusIds, itemId)
end

---Calculates the item level from an itemString's bonus IDs.
---@param itemString string The item string
---@return number?
function BonusIds.GetItemLevel(itemString)
	return private.GetItemLevelHelper(strsplit(":", itemString))
end

---Returns a bonus string that produces the given item level.
---@param itemLevel number The target item level
---@return string?
function BonusIds.GetBonusStringForLevel(itemLevel)
	return LibBonusId.GetBonusStringForLevel(itemLevel)
end

---Returns the crafting stat modifier value for a bonus ID, if applicable.
---@param bonusId number The bonus ID
---@return number?
function BonusIds.GetCraftingStatModifier(bonusId)
	return BONUS_ID_TO_CRAFTING_STAT_MODIFIER[bonusId]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetItemLevelHelper(itemType, itemId, rand, numBonusIds, ...)
	itemId = tonumber(itemId)
	numBonusIds = tonumber(numBonusIds) or 0
	if not itemId or numBonusIds == 0 then
		return nil
	end
	assert(not next(private.bonusIdTemp))
	for i = 1, numBonusIds do
		local bonusId = select(i, ...)
		bonusId = tonumber(bonusId)
		if bonusId then
			tinsert(private.bonusIdTemp, bonusId)
		end
	end
	local modifierDropLevel = private.GetDropLevelModifier(select(numBonusIds + 1, ...))
	local itemLevel = LibBonusId.CalculateItemLevelFromItemInfo(itemId, private.bonusIdTemp, modifierDropLevel)
	wipe(private.bonusIdTemp)
	return itemLevel
end

function private.GetDropLevelModifier(numModifiers, ...)
	numModifiers = tonumber(numModifiers) or 0
	for i = 1, numModifiers * 2, 2 do
		local modType, modValue = select(i, ...)
		modType = tonumber(modType)
		modValue = tonumber(modValue)
		if modType == DROP_LEVEL_MODIFIER_TYPE then
			return modValue
		end
	end
	return nil
end
