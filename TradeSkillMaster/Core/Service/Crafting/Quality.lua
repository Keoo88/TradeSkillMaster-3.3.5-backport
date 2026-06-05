-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Quality = TSM.Crafting:NewPackage("Quality")
local Profession = TSM.LibTSMService:Include("Profession")
local ProfessionQuality = TSM.LibTSMService:Include("Profession.Quality")
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local MatString = TSM.LibTSMTypes:Include("Crafting.MatString")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local OptionalMatData = TSM.LibTSMData:Include("OptionalMat")
local Conversion = TSM.LibTSMTypes:Include("Item.Conversion")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local private = {
	tempTables = {{}, {}},
	tempTableInUse = {false, false},
}
local DRAGON_ISLES_SALVAGE_CRAFTSTRINGS = {
	[Conversion.METHOD.MILL] = "c:382981",
	[Conversion.METHOD.PROSPECT] = "c:374627",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Quality.GetOptionalMats(craftString, mats, optionalMats)
	if not TSM.Crafting.IsQualityCraft(craftString) then
		return false
	end
	local recipeDifficulty, recipeQuality, recipeMaxQuality = TSM.Crafting.GetQualityInfo(craftString)
	if not recipeDifficulty then
		return false
	end
	local hasQualityMats = false
	for _ in private.QualityMatIterator(mats) do --luacheck: ignore 512
		hasQualityMats = true
		break
	end
	local targetQuality = CraftString.GetQuality(craftString)
	local rootCategoryId = TSM.Crafting.GetRootCategoryId(craftString)
	local maxMatContribution = ProfessionQuality.GetMaxMatContribution(rootCategoryId)
	local neededSkill, maxAddedSkill, maxQualityMatSkill, concentration = Profession.GetNeededSkill(targetQuality, recipeDifficulty, recipeQuality, recipeMaxQuality, hasQualityMats, maxMatContribution)
	if not neededSkill then
		return false
	end

	-- Handle crafts with no quality mats
	if not hasQualityMats then
		return neededSkill == 0 and concentration == 0
	end

	-- Cache the cost of each quality mat and calculate the total weight
	local totalWeight = 0
	local qualityMatCostTemp = private.AcquireTempTable()
	for matString in private.QualityMatIterator(mats) do
		local quantity = mats[matString]
		local isFirst = true
		local hasValidCost = false
		for matItemString in MatString.ItemIterator(matString) do
			qualityMatCostTemp[matItemString] = CustomString.GetSourceValue("MatPrice", matItemString)
			hasValidCost = hasValidCost or qualityMatCostTemp[matItemString] ~= nil
			if isFirst then
				isFirst = false
				totalWeight = totalWeight + OptionalMatData.QualityWeight[matItemString] * quantity
			end
		end
		if not hasValidCost then
			private.ReleaseTempTable(qualityMatCostTemp)
			return false
		end
		assert(not isFirst)
	end

	-- Get all combinations of quality mats
	local lowestQualityMatCost = math.huge
	for qualities in Profession.MatCombationIterator(mats) do
		-- Calculate the weight and cost for this set of qualities
		local currentMatCost = 0
		local weight = 0
		for matString, quality, matWeight in Profession.MatQualityItemIterator(qualities) do
			local matItemString = MatString.GetQualityItem(matString, quality)
			local quantity = mats[matString]
			weight = weight + matWeight * quantity
			local matCost = qualityMatCostTemp[matItemString]
			if not matCost then
				currentMatCost = math.huge
				break
			end
			currentMatCost = currentMatCost + matCost * quantity
		end
		local bonusSkill = (weight / totalWeight) * maxQualityMatSkill
		if bonusSkill >= neededSkill and bonusSkill <= maxAddedSkill and currentMatCost < lowestQualityMatCost then
			lowestQualityMatCost = currentMatCost
			wipe(optionalMats)
			for matString in private.QualityMatIterator(mats) do
				local quality = qualities[matString]
				local matItemString = MatString.GetQualityItem(matString, quality)
				tinsert(optionalMats, matItemString)
				optionalMats[matItemString] = matString
			end
		end
	end
	private.ReleaseTempTable(qualityMatCostTemp)
	if lowestQualityMatCost == math.huge then
		return false
	end
	Table.SortWithValueLookup(optionalMats, optionalMats)
	return true, concentration
end

function Quality.GetExpectedSalvageResult(method, sourceQuality)
	local craftString = DRAGON_ISLES_SALVAGE_CRAFTSTRINGS[method]
	assert(craftString)
	local baseRecipeDifficulty, baseRecipeQuality = TSM.Crafting.GetQualityInfo(craftString)
	-- Show quality 1 results when Dragon Isles Milling/Prospecting is not learned
	if not baseRecipeDifficulty or not baseRecipeQuality then
		return 1
	end

	local quality = 1
	local rootCategoryId = TSM.Crafting.GetRootCategoryId(craftString)
	local matContribution = ProfessionQuality.GetMatContributionForQuality(rootCategoryId, sourceQuality)
	local sourceMatSkill = baseRecipeDifficulty * matContribution
	for i = 2, 3 do
		local neededSkill, _, _, concentration = Profession.GetNeededSkill(i, baseRecipeDifficulty, baseRecipeQuality, 3, true, 0, matContribution)
		-- TODO: Handle concentration
		if concentration == 0 and neededSkill and neededSkill >= sourceMatSkill then
			quality = i
		end
	end
	return quality
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QualityMatIterator(mats)
	return private.QualityMatIteratorHelper, mats, nil
end

function private.QualityMatIteratorHelper(mats, matString)
	while true do
		matString = next(mats, matString)
		if not matString then
			return
		end
		if MatString.GetType(matString) == MatString.TYPE.QUALITY then
			return matString
		end
	end
end

function private.AcquireTempTable()
	for i = 1, #private.tempTables do
		if not private.tempTableInUse[i] then
			local tbl = private.tempTables[i]
			private.tempTableInUse[i] = true
			wipe(tbl)
			return tbl
		end
	end
	return TempTable.Acquire()
end

function private.ReleaseTempTable(tbl)
	for i = 1, #private.tempTables do
		if tbl == private.tempTables[i] then
			private.tempTableInUse[i] = false
			return
		end
	end
	TempTable.Release(tbl)
end
