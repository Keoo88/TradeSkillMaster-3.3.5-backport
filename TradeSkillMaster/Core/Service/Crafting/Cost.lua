-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Cost = TSM.Crafting:NewPackage("Cost") ---@type AddonPackage
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local OptionalMatData = TSM.LibTSMData:Include("OptionalMat")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local RecipeString = TSM.LibTSMTypes:Include("Crafting.RecipeString")
local MatString = TSM.LibTSMTypes:Include("Crafting.MatString")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local Profession = TSM.LibTSMService:Include("Profession")
local CraftingOperation = TSM.LibTSMSystem:Include("CraftingOperation")
local private = {
	settings = nil,
	matsVisited = {},
	matsTemp = {},
	matsTempInUse = false,
	currentMatProfession = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Cost.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("factionrealm", "internalData", "mats")
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
		:AddKey("global", "craftingOptions", "defaultMatCostMethod")
	-- Register the "MatPrice" custom price source. This 3.3.5 backport dropped the
	-- registration, so GetSourceValue("MatPrice", itemString) returned nil for every
	-- reagent, which left the crafting Cost and Profit columns empty.
	if not CustomString.IsSourceRegistered("MatPrice") then
		CustomString.RegisterSource("Crafting", "MatPrice", "Crafting Material Cost", Cost.GetMatCost, CustomString.SOURCE_TYPE.NORMAL)
	end
end

function Cost.GetMatCost(itemString)
	local baseItemString = ItemString.GetBaseFast(itemString)
	-- On this 3.3.5 backport, NORMAL mats are stored in settings.mats keyed by their
	-- raw mat itemString (e.g. "i:18256:0"), while GetBaseFast() strips the trailing
	-- ":0" to "i:18256" (the retail form). Look up by the raw key first, then the base
	-- key, so the mat info is found regardless of which form was stored.
	local matInfo = private.settings.mats[itemString] or (baseItemString and private.settings.mats[baseItemString])
	if not matInfo then
		return
	end
	local priceItemString = baseItemString or itemString
	if private.matsVisited[priceItemString] then
		-- There's a loop in the mat cost, so bail
		return
	end
	private.matsVisited[priceItemString] = true
	local priceStr = matInfo.customValue or private.settings.defaultMatCostMethod
	local result = CustomString.GetValue(priceStr, priceItemString)
	if not result then
		-- 3.3.5 fallback: the default mat cost method ("min(dbmarket, ...)") can fail to
		-- evaluate on this backport even when AuctionDB has data. Fall back to raw sources.
		result = CustomString.GetSourceValue("DBMarket", priceItemString)
		if not result then
			result = CustomString.GetSourceValue("DBMinBuyout", priceItemString)
		end
	end
	private.matsVisited[priceItemString] = nil
	return result
end

function Cost.GetCraftingCostByCraftString(craftString, optionalMats, qualityMats)
	local releaseQualityMats = false
	if not qualityMats then
		qualityMats = TempTable.Acquire()
		releaseQualityMats = true
	end
	local cost, concentration = private.GetCraftingCostHelper(craftString, nil, optionalMats, qualityMats)
	if releaseQualityMats then
		TempTable.Release(qualityMats)
	end
	return cost, concentration
end

function Cost.GetCraftedItemValue(itemString)
	local hasCraftPriceMethod, craftPrice = CraftingOperation.GetCraftedItemValue(itemString)
	if hasCraftPriceMethod then
		return craftPrice
	end
	local value = CustomString.GetValue(private.settings.defaultCraftPriceMethod, itemString)
	if not value then
		-- 3.3.5 fallback: defaultCraftPriceMethod ("first(dbminbuyout, dbmarket)*0.95")
		-- references the "dbminbuyout" word source, which on this backport can make the
		-- whole custom price string fail to evaluate (returning nil) even when AuctionDB
		-- has data for the crafted item. That left the Profit column empty while the
		-- Cost column (which uses defaultMatCostMethod = "min(dbmarket, ...)") still worked.
		-- Fall back to the raw AuctionDB source values, bypassing the price-string parser.
		value = CustomString.GetSourceValue("DBMarket", itemString)
		if not value then
			value = CustomString.GetSourceValue("DBMinBuyout", itemString)
		end
	end
	return value
end

function Cost.GetProfitByCraftString(craftString)
	local _, _, profit = Cost.GetCostsByCraftString(craftString)
	return profit
end

function Cost.GetProfitByRecipeString(recipeString)
	local _, _, profit = Cost.GetCostsByRecipeString(recipeString)
	return profit
end

function Cost.GetCostsByCraftString(craftString)
	local craftingCost, concentration = Cost.GetCraftingCostByCraftString(craftString)
	local itemString = TSM.Crafting.GetItemString(craftString)
	local craftedItemValue = itemString and Cost.GetCraftedItemValue(itemString) or nil
	return craftingCost, craftedItemValue, craftingCost and craftedItemValue and (craftedItemValue - craftingCost) or nil, concentration
end

function Cost.GetCostsByRecipeString(recipeString)
	local craftString = CraftString.FromRecipeString(recipeString)
	local craftingCost = private.GetCraftingCostHelper(craftString, recipeString)
	local itemString = Cost.GetLevelItemString(recipeString)
	local craftedItemValue = itemString and Cost.GetCraftedItemValue(itemString) or nil
	return craftingCost, craftedItemValue, craftingCost and craftedItemValue and (craftedItemValue - craftingCost) or nil
end

function Cost.GetLevelItemString(recipeString)
	local itemString = TSM.Crafting.GetItemString(CraftString.FromRecipeString(recipeString))
	if not itemString then
		return nil
	end
	return Profession.GenerateResultItemString(recipeString, itemString)
end

function Cost.GetSaleRateByCraftString(craftString)
	local itemString = TSM.Crafting.GetItemString(craftString)
	return itemString and CustomString.GetSourceValue("DBRegionSaleRate", itemString) or nil
end

function Cost.GetLowestCostByItem(itemString, optionalMats, qualityMats)
	local levelItemString = ItemString.ToLevel(itemString)
	local shouldReleaseOptionalMats = false
	if not optionalMats then
		shouldReleaseOptionalMats = true
		optionalMats = TempTable.Acquire()
	end
	private.GetOptionalMats(itemString, optionalMats)
	local lowestCost, lowestCraftString, lowestConcentration = nil, nil, nil
	local cdCost, cdSpellId, cdConcentration = nil, nil, nil
	local numSpells = 0
	local singleCraftString = nil
	local tempQualityMats = TempTable.Acquire()
	for _, craftString, hasCD, profession in TSM.Crafting.GetCraftStringByItem(levelItemString) do
		if not private.currentMatProfession or not OptionalMatData.Info[levelItemString] or private.currentMatProfession == profession then
			if not CraftString.GetLevel(craftString) then
				if not hasCD then
					if singleCraftString == nil then
						singleCraftString = craftString
					elseif singleCraftString then
						singleCraftString = 0
					end
				end
				numSpells = numSpells + 1
				wipe(tempQualityMats)
				local cost, concentration = Cost.GetCraftingCostByCraftString(craftString, optionalMats, tempQualityMats)
				if cost and (not lowestCost or cost < lowestCost) then
					-- Exclude spells with cooldown if option to ignore is enabled and there is more than one way to craft
					if hasCD then
						cdCost = cost
						cdSpellId = craftString
						cdConcentration = concentration
					else
						if qualityMats then
							wipe(qualityMats)
							for k, v in pairs(tempQualityMats) do
								qualityMats[k] = v
							end
						end
						lowestCost = cost
						lowestCraftString = craftString
						lowestConcentration = concentration
					end
				end
			end
		end
	end
	TempTable.Release(tempQualityMats)
	if shouldReleaseOptionalMats then
		TempTable.Release(optionalMats)
	end
	if singleCraftString == 0 then
		singleCraftString = nil
	end
	if numSpells == 1 and not lowestCost and cdCost then
		-- Only way to craft it is with a CD craft, so use that
		if qualityMats then
			-- TODO: This path isn't currently supported
			wipe(qualityMats)
		end
		lowestCost = cdCost
		lowestCraftString = cdSpellId
		lowestConcentration = cdConcentration
	end
	return lowestCost, lowestCraftString or singleCraftString, lowestConcentration
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetOptionalMats(itemString, resultTbl)
	ItemString.GetStatModifiers(itemString, true, resultTbl)
	for i = #resultTbl, 1, -1 do
		local statOptionalMat = nil
		for optionalMatItemString, info in pairs(OptionalMatData.Info) do
			if info.statModifier == resultTbl[i] then
				statOptionalMat = optionalMatItemString
				break
			end
		end
		if statOptionalMat then
			resultTbl[i] = statOptionalMat
		else
			tremove(resultTbl, i)
		end
	end
	local itemLevel = ItemString.GetItemLevel(itemString)
	if itemLevel then
		for optionalMatItemString, info in pairs(OptionalMatData.Info) do
			if info.absItemLevel == itemLevel then
				tinsert(resultTbl, optionalMatItemString)
				break
			end
		end
	end
end

function private.GetCraftingCostHelper(craftString, recipeString, optionalMats, qualityMats)
	local cost = 0
	local hasMats = false
	local mats = nil
	if private.matsTempInUse then
		mats = TempTable.Acquire()
	else
		mats = private.matsTemp
		private.matsTempInUse = true
		wipe(mats)
	end
	TSM.Crafting.GetMatsAsTable(craftString, mats)
	local concentration = 0
	if recipeString then
		assert(not optionalMats)
		for _, _, itemId in RecipeString.OptionalMatIterator(recipeString) do
			local optionalMatItemString = ItemString.Get(itemId)
			local optionalMatItemId = ItemString.ToId(optionalMatItemString)
			local matchStr1 = "[:,]"..optionalMatItemId.."$"
			local matchStr2 = "[:,]"..optionalMatItemId..","
			for itemString, quantity in pairs(mats) do
				if (strmatch(itemString, matchStr1) or strmatch(itemString, matchStr2)) then
					mats[optionalMatItemString] = ((mats[optionalMatItemString] or 0) + 1) * quantity
					break
				end
			end
		end
	elseif TSM.Crafting.IsQualityCraft(craftString) then
		local canCraft, craftConcentration = TSM.Crafting.Quality.GetOptionalMats(craftString, mats, qualityMats)
		if canCraft then
			concentration = craftConcentration
		else
			if mats == private.matsTemp then
				private.matsTempInUse = false
			else
				TempTable.Release(mats)
			end
			return nil, nil
		end
		for _, itemString in ipairs(qualityMats) do
			mats[itemString] = mats[qualityMats[itemString]]
		end
	elseif optionalMats then
		for _, optionalMatItemString in pairs(optionalMats) do
			local optionalMatItemId = ItemString.ToId(optionalMatItemString)
			local matchStr1 = "[:,]"..optionalMatItemId.."$"
			local matchStr2 = "[:,]"..optionalMatItemId..","
			for itemString, quantity in pairs(mats) do
				if (strmatch(itemString, matchStr1) or strmatch(itemString, matchStr2)) then
					mats[optionalMatItemString] = ((mats[optionalMatItemString] or 0) + 1) * quantity
					break
				end
			end
		end
	end
	local didSetProfession = false
	if not private.currentMatProfession then
		private.currentMatProfession = TSM.Crafting.GetProfession(craftString)
		didSetProfession = true
	end
	for itemString, quantity in pairs(mats) do
		if MatString.GetType(itemString) == MatString.TYPE.NORMAL then
			hasMats = true
			local matCost = CustomString.GetSourceValue("MatPrice", itemString)
			if not matCost then
				cost = nil
			elseif cost then
				cost = cost + matCost * quantity
			end
		end
	end
	if didSetProfession then
		private.currentMatProfession = nil
	end
	if mats == private.matsTemp then
		private.matsTempInUse = false
	else
		TempTable.Release(mats)
	end
	if not cost or not hasMats then
		return nil, nil
	end
	cost = Math.Round(cost / TSM.Crafting.GetNumResult(craftString))
	return cost > 0 and cost or nil, concentration
end
