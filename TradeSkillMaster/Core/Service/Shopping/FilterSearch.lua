-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local FilterSearch = TSM.Shopping:NewPackage("FilterSearch") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Conversion = TSM.LibTSMTypes:Include("Item.Conversion")
local DisenchantData = TSM.LibTSMData:Include("Disenchant")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemFilter = TSM.LibTSMService:IncludeClassType("ItemFilter")
local Conversions = TSM.LibTSMApp:Include("Service.Conversions")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local AuctionSearchContext = TSM.LibTSMService:IncludeClassType("AuctionSearchContext")
local LibTSMClass = LibStub("LibTSMClass")
local FilterSearchContext = LibTSMClass.DefineClass("FilterSearchContext", AuctionSearchContext) ---@class FilterSearchContext: AuctionSearchContext
local private = {
	settings = nil,
	scanThreadId = nil,
	itemFilter = nil,
	isSpecial = false,
	marketValueSource = nil,
	searchContext = nil, ---@type FilterSearchContext
	gatheringSearchContext = nil, ---@type FilterSearchContext
	targetItem = {},
	itemList = {},
	generalMaxQuantity = {},
	gatheringQuerySignatures = {},
}
local DISENCHANT_CLASS_ID_LOOKUP = {
	[DisenchantData.ITEM_CLASSES.ARMOR] = Enum.ItemClass.Armor,
	[DisenchantData.ITEM_CLASSES.WEAPON] = Enum.ItemClass.Weapon,
	[DisenchantData.ITEM_CLASSES.PROFESSION] = Enum.ItemClass.Profession,
}
local ITEM_FILTER_ERRROR_LOOKUP = {
	[ItemFilter.ERROR.ITEM_NOT_FOUND] = L["The specified item was not found."],
	[ItemFilter.ERROR.DUPLICATE_FILTER] = L["The same filter was specified multiple times."],
	[ItemFilter.ERROR.MAX_QUANTITY_ZERO] = L["The max quantity cannot be zero."],
	[ItemFilter.ERROR.UNKNOWN_WORD] = L["Unknown word (%s)."],
	[ItemFilter.ERROR.CRAFTING_DISENCHANT_ADDITIONAL] = L["Cannot use additional filters with /crafting or /disenchant."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function FilterSearch.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "shoppingOptions", "pctSource")
	-- Initialize thread
	private.scanThreadId = Threading.New("FILTER_SEARCH", private.ScanThread)
	private.itemFilter = ItemFilter.New()
	private.searchContext = FilterSearchContext(private.scanThreadId, private.MarketValueFunction)
	private.gatheringSearchContext = FilterSearchContext(private.scanThreadId, private.MarketValueFunction, private.GatheringResultsFunction)
end

function FilterSearch.GetGreatDealsSearchContext(filterStr)
	filterStr = private.ValidateFilterStr(filterStr, "NORMAL")
	if not filterStr then
		return nil
	end
	private.marketValueSource = private.settings.pctSource
	private.isSpecial = true
	return private.searchContext:SetScanContext(L["Great Deals Search"], filterStr, nil, L["Market Value"])
end

function FilterSearch.GetSearchContext(filterStr, itemInfo)
	local errMsg = nil
	local origFilterStr = filterStr
	filterStr, errMsg = private.ValidateFilterStr(filterStr, "NORMAL")
	if not filterStr then
		if type(origFilterStr) == "string" then
			ChatMessage.PrintUser(format(L["Invalid search filter (%s)."], origFilterStr).." "..errMsg)
		end
		return nil
	end
	private.marketValueSource = private.settings.pctSource
	private.isSpecial = false
	return private.searchContext:SetScanContext(filterStr, filterStr, itemInfo, L["Market Value"])
end

function FilterSearch.GetGatheringSearchContext(filterStr, mode)
	filterStr = private.ValidateFilterStr(filterStr, mode)
	if not filterStr then
		return nil
	end
	private.marketValueSource = "matprice"
	private.isSpecial = true
	return private.gatheringSearchContext:SetScanContext(L["Gathering Search"], filterStr, nil, L["Material Cost"])
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

function private.ScanThread(auctionScan, filterStr)
	wipe(private.generalMaxQuantity)
	wipe(private.gatheringQuerySignatures)
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() and filterStr == "" then
		auctionScan:NewQuery()
			:SetStr("")
		wipe(private.targetItem)
		wipe(private.itemList)
	else
		local hasFilter, errMsg = false, nil
		for filter in String.SplitIterator(filterStr, ";") do
			filter = strtrim(filter)
			if filter ~= "" then
				local filterIsValid, filterErrType, filterErrArg = private.itemFilter:ParseStr(filter)
				if filterIsValid then
					hasFilter = true
				else
					errMsg = errMsg or format(ITEM_FILTER_ERRROR_LOOKUP[filterErrType], filterErrArg)
				end
			end
		end
		if not hasFilter then
			ChatMessage.PrintUser(format(L["Invalid search filter (%s)."], filterStr).." "..errMsg)
			return false
		end
		wipe(private.targetItem)
		wipe(private.itemList)
		local itemFilter = private.itemFilter
		for filterPart in String.SplitIterator(filterStr, ";") do
			filterPart = strtrim(filterPart)
			if filterPart ~= "" and itemFilter:ParseStr(filterPart) then
				if itemFilter:GetCrafting() then
					local targetItem = private.GetConversionTargetItem(itemFilter:GetStr())
					assert(targetItem)
					local partSig = "craft:"..targetItem..":"..tostring(itemFilter:GetMaxQuantity())
					if private.marketValueSource == "matprice" and private.gatheringQuerySignatures[partSig] then
						-- Duplicate gathering filter for the same target; skip it.
					else
					if private.marketValueSource == "matprice" then
						private.gatheringQuerySignatures[partSig] = true
					end
					wipe(private.itemList)
					-- populate the list of items
					private.targetItem[targetItem] = targetItem
					tinsert(private.itemList, targetItem)
					local conversionInfo = Conversion.GetSourceItems(targetItem)
					for itemString in pairs(conversionInfo) do
						if not private.targetItem[itemString] then
							private.targetItem[itemString] = targetItem
							tinsert(private.itemList, itemString)
						end
					end
					-- generate the queries and add our filter
					local queryOffset = auctionScan:GetNumQueries()
					auctionScan:AddItemListQueriesThreaded(private.itemList)
					local maxQuantity = itemFilter:GetMaxQuantity()
					local firstQuery = nil
					for _, query in auctionScan:QueryIterator(queryOffset) do
						private.targetItem[query] = targetItem
						query:AddCustomFilter(private.TargetItemQueryFilter)
						if maxQuantity then
							if firstQuery then
								-- redirect to the first query so the max quantity spans them all
								private.generalMaxQuantity[query] = firstQuery
							else
								private.generalMaxQuantity[query] = maxQuantity
								firstQuery = query
							end
						end
					end
					auctionScan:AddResultsUpdateCallback(private.ResultsUpdated)
					auctionScan:SetScript("OnQueryDone", private.OnQueryDone)
					end
				elseif itemFilter:GetDisenchant() then
					local targetItem = private.GetConversionTargetItem(itemFilter:GetStr())
					assert(targetItem)
					local partSig = "de:"..targetItem..":"..tostring(itemFilter:GetMaxQuantity())
					if private.marketValueSource == "matprice" and private.gatheringQuerySignatures[partSig] then
						-- Duplicate gathering filter for the same target; skip it.
					else
					if private.marketValueSource == "matprice" then
						private.gatheringQuerySignatures[partSig] = true
					end
					local queryOffset = auctionScan:GetNumQueries()
					-- generate queries for groups of items that d/e into the target item
					local data = Conversion.GetDisenchantData(targetItem)
					local seenDESignatures = private.marketValueSource == "matprice" and {} or nil
					for _, info in ipairs(data.sourceInfo) do
						local classId = DISENCHANT_CLASS_ID_LOOKUP[info.class]
						assert(classId)
						local rangeSig = format("de-range:%s:%d:%d:%d:%d", targetItem, classId, info.quality, info.minItemLevel, info.maxItemLevel)
						if not seenDESignatures or not seenDESignatures[rangeSig] then
							if seenDESignatures then
								seenDESignatures[rangeSig] = true
							end
							auctionScan:NewQuery()
								:SetLevelRange(data.minLevel, data.maxLevel)
								:SetQualityRange(info.quality, info.quality)
								:SetClass(classId)
								:SetItemLevelRange(info.minItemLevel, info.maxItemLevel)
						end
					end
					-- add a query for the target item itself
					wipe(private.itemList)
					tinsert(private.itemList, targetItem)
					private.targetItem[targetItem] = targetItem
					auctionScan:AddItemListQueriesThreaded(private.itemList)
					-- add our filter to each query and generate a lookup from query to target item
					local maxQuantity = itemFilter:GetMaxQuantity()
					local firstQuery = nil
					for _, query in auctionScan:QueryIterator(queryOffset) do
						private.targetItem[query] = targetItem
						query:AddCustomFilter(private.TargetItemQueryFilter)
						if maxQuantity then
							if firstQuery then
								-- redirect to the first query so the max quantity spans them all
								private.generalMaxQuantity[query] = firstQuery
							else
								private.generalMaxQuantity[query] = maxQuantity
								firstQuery = query
							end
						end
					end
					auctionScan:AddResultsUpdateCallback(private.ResultsUpdated)
					auctionScan:SetScript("OnQueryDone", private.OnQueryDone)
					end
				else
					local searchStr = itemFilter:GetStr()
					local exactItemString = itemFilter:GetItem()
					-- 3.3.5 backport: if the search string exactly matches a known item name,
					-- convert it to an itemString and run a fast exact search instead of a
					-- slow substring scan across all pages
					if not exactItemString and searchStr and searchStr ~= "" then
						exactItemString = ItemInfo.ItemNameToItemString(searchStr)
						if exactItemString == ItemString.GetUnknown() then
							-- multiple distinct items share this name; can't do an exact item search
							exactItemString = nil
						end
					end
					local normalSig = private.GetNormalGatheringQuerySignature(itemFilter, exactItemString, searchStr)
					if not (private.marketValueSource == "matprice" and private.gatheringQuerySignatures[normalSig]) then
						if private.marketValueSource == "matprice" then
							private.gatheringQuerySignatures[normalSig] = true
						end
						local query = auctionScan:NewQuery()
						if exactItemString then
							query:SetStr(searchStr, true)
						else
							query:SetStr(searchStr, itemFilter:GetExactOnly())
						end
						query:SetQualityRange(itemFilter:GetMinQuality(), itemFilter:GetMaxQuality())
						query:SetLevelRange(itemFilter:GetMinLevel(), itemFilter:GetMaxLevel())
						query:SetItemLevelRange(itemFilter:GetMinItemLevel(), itemFilter:GetMaxItemLevel())
						query:SetClass(itemFilter:GetClass(), itemFilter:GetSubClass(), itemFilter:GetInvSlotId())
						query:SetUsable(itemFilter:GetUsableOnly())
						query:SetUncollected(itemFilter:GetUncollected())
						query:SetUpgrades(itemFilter:GetUpgrades())
						query:SetPriceRange(itemFilter:GetMinPrice(), itemFilter:GetMaxPrice())
						if exactItemString then
							query:SetItems(exactItemString)
						end
						-- luacheck: globals CanIMogIt
						if CanIMogIt and CanIMogIt.PlayerKnowsTransmog then
							query:SetUnlearned(itemFilter:GetAddedKeyValue("unlearned"))
						end
						if CanIMogIt and CanIMogIt.CharacterCanLearnTransmog then
							query:SetCanLearn(itemFilter:GetAddedKeyValue("canlearn"))
						end
						private.generalMaxQuantity[query] = itemFilter:GetMaxQuantity()
					end
				end
			end
		end
		if not private.isSpecial then
			TSM.Shopping.SavedSearches.RecordFilterSearch(filterStr)
		end
	end

	-- Gathering scans on Classic: filter only rows touched by the current page.
	if private.marketValueSource == "matprice" and not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		for _, query in auctionScan:QueryIterator() do
			query:SetIncrementalFilter(true)
		end
	end

	-- run the scan
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
	return true
end



-- ============================================================================
-- FilterSearchContext Class
-- ============================================================================

function FilterSearchContext:GetMaxCanBuy(itemString)
	local targetItemString = private.targetItem[itemString]
	local maxNum = nil
	local itemQuery = private.GetMaxQuantityQuery(targetItemString or itemString)
	if itemQuery then
		maxNum = private.generalMaxQuantity[itemQuery]
		if targetItemString then
			local rate, chunkSize = private.GetTargetItemRate(targetItemString, itemString)
			maxNum = Math.Ceil(maxNum / rate, chunkSize)
		end
	end
	return maxNum
end

function FilterSearchContext:OnBuy(itemString, quantity)
	local targetItemString = private.targetItem[itemString]
	if targetItemString then
		quantity = quantity * private.GetTargetItemRate(targetItemString, itemString)
		itemString = targetItemString
	end
	self.__super:OnBuy(itemString, quantity)

	local itemQuery = private.GetMaxQuantityQuery(itemString)
	if itemQuery then
		private.generalMaxQuantity[itemQuery] = private.generalMaxQuantity[itemQuery] - quantity
		if private.generalMaxQuantity[itemQuery] <= 0 then
			itemQuery:WipeBrowseResults()
			for query, maxQuantity in pairs(private.generalMaxQuantity) do
				if maxQuantity == itemQuery then
					query:WipeBrowseResults()
				end
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateFilterStr(filterStr, mode)
	assert(mode == "NORMAL" or mode == "CRAFTING" or mode == "DISENCHANT")
	filterStr = strtrim(filterStr)
	if mode == "NORMAL" and not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() and filterStr == "" then
		return filterStr
	end
	local isValid, errMsg = true, nil
	local filters = TempTable.Acquire()
	for filter in String.SplitIterator(filterStr, ";") do
		filter = strtrim(filter)
		if isValid and gsub(filter, "/", "") ~= "" then
			local filterIsValid, filterErrType, filterErrArg = private.itemFilter:ParseStr(filter)
			if filterIsValid then
				local str = private.itemFilter:GetStr()
				if mode == "CRAFTING" and not strfind(strlower(filter), "/crafting") and str then
					filter = filter.."/crafting"
				elseif mode == "DISENCHANT" and not strfind(strlower(filter), "/disenchant") and str then
					filter = filter.."/disenchant"
				end
				if strfind(strlower(filter), "/crafting") then
					local craftingTargetItem = str and private.GetConversionTargetItem(str) or nil
					if not craftingTargetItem or not Conversion.GetSourceItems(craftingTargetItem) then
						isValid = false
						errMsg = errMsg or L["The specified item is not supported for crafting searches."]
					end
				end
				if strfind(strlower(filter), "/disenchant") then
					local targetItemString = str and private.GetConversionTargetItem(str) or nil
					if not Conversion.IsDisenchantTargetItem(targetItemString) then
						isValid = false
						errMsg = errMsg or L["The specified item is not supported for disenchant searches."]
					end
				end
			else
				isValid = false
				errMsg = errMsg or format(ITEM_FILTER_ERRROR_LOOKUP[filterErrType], filterErrArg)
			end
		else
			isValid = false
		end
		if isValid then
			tinsert(filters, filter)
		end
	end
	local result = table.concat(filters, ";")
	TempTable.Release(filters)
	result = isValid and result ~= "" and result or nil
	errMsg = errMsg or L["The specified filter was empty."]
	return result, errMsg
end

function private.MarketValueFunction(subRow)
	local baseItemString = subRow:GetBaseItemString()
	local itemString = subRow:GetItemString()
	if next(private.targetItem) then
		local targetItemString = private.targetItem[itemString]
		if not itemString or not targetItemString then
			return nil
		end
		local targetItemRate = private.GetTargetItemRate(targetItemString, itemString)
		return Math.Round(targetItemRate * CustomString.GetValue(private.marketValueSource, targetItemString))
	else
		local value = CustomString.GetValue(private.marketValueSource, itemString or baseItemString)
		return value
	end
end

function private.GatheringResultsFunction(auctionScan, marketValueFunc, itemString, quantity, maxQuantity)
	local filterQuantity = 0
	for _, query in auctionScan:QueryIterator() do
		for _, subRow in query:ItemSubRowIterator(itemString) do
			local _, itemBuyout = subRow:GetBuyouts()
			if marketValueFunc(subRow) >= itemBuyout then
				local _, numOwnerItems = subRow:GetOwnerInfo()
				local quantityAvailable = subRow:GetQuantities() - numOwnerItems
				filterQuantity = filterQuantity + quantityAvailable
			end
		end
	end
	return filterQuantity > 0 and min(filterQuantity, quantity, maxQuantity) or min(quantity, maxQuantity)
end

function private.GetTargetItemRate(targetItemString, itemString)
	if itemString == targetItemString then
		return 1, 1
	end
	if Conversion.IsDisenchantTargetItem(targetItemString) then
		local classId = ItemInfo.GetClassId(itemString)
		local quality = ItemInfo.GetQuality(itemString)
		local itemLevel = ClientInfo.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBase(itemString))
		local expansion = ClientInfo.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
		local amountOfMats = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
		if amountOfMats then
			return amountOfMats, 1
		end
	end
	local conversionInfo = Conversion.GetSourceItems(targetItemString)
	local conversionChunkSize = 1
	for _ in Conversion.TargetItemsByMethodIterator(itemString, Conversion.METHOD.MILL) do
		conversionChunkSize = 5
	end
	for _ in Conversion.TargetItemsByMethodIterator(itemString, Conversion.METHOD.PROSPECT) do
		conversionChunkSize = 5
	end
	return conversionInfo and conversionInfo[itemString] or 0, conversionChunkSize
end

function private.TargetItemQueryFilter(query, row)
	local itemString = row:GetItemString()
	local targetItemString = private.targetItem[itemString] or private.targetItem[query]
	return itemString and targetItemString and private.GetTargetItemRate(targetItemString, itemString) == 0
end

function private.ResultsUpdated(_, query)
	local targetItemString = private.targetItem[query]
	if not targetItemString then
		return
	end

	-- populate the targetItem table for each item in the results
	for _, row in query:BrowseResultsIterator() do
		if row:HasItemInfo() then
			for _, subRow in row:SubRowIterator() do
				local itemString = subRow:GetItemString()
				if itemString then
					private.targetItem[itemString] = targetItemString
				end
			end
		end
	end
end

function private.OnQueryDone(_, query)
	private.ResultsUpdated(nil, query)
	private.targetItem[query] = nil
end

function private.GetMaxQuantityQuery(itemString)
	if not next(private.generalMaxQuantity) then
		return
	end

	-- find the query this item belongs to
	local itemQuery = nil
	for query, value in pairs(private.generalMaxQuantity) do
		local containsItem = false
		for _ in query:ItemSubRowIterator(itemString) do
			containsItem = true
		end
		if containsItem then
			-- resolve any potential redirection to the base query
			itemQuery = type(value) == "number" and query or value
			break
		end
	end
	if not itemQuery or not private.generalMaxQuantity[itemQuery] then
		return
	end
	return itemQuery
end

---Builds a gathering dedup signature for a normal filter part, mirroring every
---parameter applied when constructing the browse query.
---@param itemFilter ItemFilter
---@param exactItemString string?
---@param searchStr string?
---@return string
function private.GetNormalGatheringQuerySignature(itemFilter, exactItemString, searchStr)
	local identity = exactItemString or strlower(searchStr or "")
	local exact = exactItemString and true or (itemFilter:GetExactOnly() and true or false)
	local sig = format(
		"normal:%s:exact%d:q%s-%s:l%s-%s:il%s-%s:c%s.%s.%s:u%d:unc%d:up%d:p%s-%s:x%s",
		identity,
		exact and 1 or 0,
		tostring(itemFilter:GetMinQuality()), tostring(itemFilter:GetMaxQuality()),
		tostring(itemFilter:GetMinLevel()), tostring(itemFilter:GetMaxLevel()),
		tostring(itemFilter:GetMinItemLevel()), tostring(itemFilter:GetMaxItemLevel()),
		tostring(itemFilter:GetClass()), tostring(itemFilter:GetSubClass()), tostring(itemFilter:GetInvSlotId()),
		itemFilter:GetUsableOnly() and 1 or 0,
		itemFilter:GetUncollected() and 1 or 0,
		itemFilter:GetUpgrades() and 1 or 0,
		tostring(itemFilter:GetMinPrice()), tostring(itemFilter:GetMaxPrice()),
		tostring(itemFilter:GetMaxQuantity())
	)
	-- luacheck: globals CanIMogIt
	if CanIMogIt and CanIMogIt.PlayerKnowsTransmog then
		sig = sig..":unl"..(itemFilter:GetAddedKeyValue("unlearned") and 1 or 0)
	end
	if CanIMogIt and CanIMogIt.CharacterCanLearnTransmog then
		sig = sig..":cl"..(itemFilter:GetAddedKeyValue("canlearn") and 1 or 0)
	end
	return sig
end

function private.GetConversionTargetItem(targetItemName)
	targetItemName = strlower(targetItemName)
	for targetItemString in Conversion.TargetItemIterator() do
		local name = ItemInfo.GetName(targetItemString)
		if name and strlower(name) == targetItemName then
			return targetItemString
		end
	end
	for targetItemString in Conversion.DisenchantTargetItemIterator() do
		local name = ItemInfo.GetName(targetItemString)
		if name and strlower(name) == targetItemName then
			return targetItemString
		end
	end
end
