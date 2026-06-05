-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionRow = LibTSMService:DefineClassType("AuctionRow")
local AuctionSubRow = LibTSMService:IncludeClassType("AuctionSubRow")
local Util = LibTSMService:Include("AuctionScan.Util")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local AuctionHouseWrapper = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local private = {
	objectPool = ObjectPool.New("AUCTION_SCAN_RESULT_ROW", AuctionRow, 1),
}
local SUB_ROW_SEARCH_INDEX_MULTIPLIER = 1000000
local FIELD_NOT_SET = newproxy()



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets a new result row.
---@param query any
---@param itemKey ItemKey The item key the result row is for
---@param minPrice? number The minimum price set by the application logic for thw row
---@param totalQuantity? number The total quantity required by the application logic for the row
---@return AuctionRow
function AuctionRow.__static.Get(query, itemKey, minPrice, totalQuantity)
	local row = private.objectPool:Get() ---@type AuctionRow
	row:_Acquire(query, itemKey, minPrice, totalQuantity)
	return row
end



-- ============================================================================
-- AuctionRow - Meta Class Methods
-- ============================================================================

function AuctionRow:__init()
	self._query = nil
	self._items = {} ---@type ItemKey[]|string[]
	self._baseItemString = nil
	self._canHaveNonBaseItemString = nil
	self._minPrice = nil
	self._hasItemInfo = false
	self._isCommodity = ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and FIELD_NOT_SET or false
	self._notFiltered = false
	self._searchIndex = nil
	self._subRows = {} ---@type AuctionSubRow[]
	self._minBrowseId = nil
end

function AuctionRow:_Acquire(query, item, minPrice, totalQuantity)
	self._query = query
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		item._minPrice = minPrice
		item._totalQuantity = totalQuantity
		tinsert(self._items, item)
		self._baseItemString = ItemString.GetBaseFromItemKey(item)
	else
		assert(not minPrice and not totalQuantity)
		tinsert(self._items, item)
		self._baseItemString = ItemString.GetBase(item)
	end
end



-- ============================================================================
-- AuctionRow - Public Class Methods
-- ============================================================================

---Merges an item into the row.
---@param item string The item string
---@param minPrice? number The min price context (retail only)
---@param totalQuantity? number The total quantity context (retail only)
function AuctionRow:Merge(item, minPrice, totalQuantity)
	-- Check if we already have this item
	for i = 1, #self._items do
		if item == self._items[i] then
			return
		end
		if type(item) == "table" then
			local isEqual = true
			for k in pairs(item) do
				if item[k] ~= self._items[i][k] then
					isEqual = false
					break
				end
			end
			if isEqual then
				return
			end
		end
	end
	self._hasItemInfo = false
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		assert(self._baseItemString == ItemString.GetBaseFromItemKey(item))
		item._minPrice = minPrice
		item._totalQuantity = totalQuantity
	else
		assert(not minPrice and not totalQuantity)
		assert(self._baseItemString == ItemString.GetBase(item))
	end
	tinsert(self._items, item)
	self._notFiltered = false
	self._canHaveNonBaseItemString = nil
end

---Release the auction row.
function AuctionRow:Release()
	wipe(self._items)
	self._baseItemString = nil
	self._canHaveNonBaseItemString = nil
	self._minPrice = nil
	self._hasItemInfo = false
	self._isCommodity = ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and FIELD_NOT_SET or false
	self._notFiltered = false
	self._searchIndex = nil
	self._minBrowseId = nil
	for _, subRow in pairs(self._subRows) do
		subRow:Release()
	end
	wipe(self._subRows)
	private.objectPool:Recycle(self)
end

---Returns whether or not this is a sub row.
---@return boolean
function AuctionRow:IsSubRow()
	return false
end

---Populates necessary item data ahead of a browse query and returns whether or not this was completed.
---@param missingItemIds table<number,boolean> A table to populate with missing item IDs (as keys)
---@return boolean success
---@return boolean giveUp
function AuctionRow:PopulateBrowseData(missingItemIds)
	assert(self._baseItemString)
	TSMDBG.Log("Row", "PopulateBrowseData START baseItemString=%s isClassic=%s numItems=%d", tostring(self._baseItemString), tostring(not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE)), #self._items)
	if self._hasItemInfo then
		TSMDBG.Log("Row", "PopulateBrowseData EARLY-RETURN already _hasItemInfo=true")
		return true, false
	end

	-- 3.3.5 fast-path: itemLink уже получен из GetAuctionItemLink, не ждём ItemInfo cache.
	-- На классике self._items[i] это string (itemLink) — нельзя писать в него _hasInfo.
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		self._isCommodity = false
		self._hasItemInfo = true
		TSMDBG.Log("Row", "PopulateBrowseData CLASSIC-DONE baseItemString=%s itemsType=%s subRows=%d", tostring(self._baseItemString), type(self._items[1]), #self._subRows)
		return true, false
	end

	local hasBaseInfo, fetchedBaseInfo = Util.HasItemInfo(self._baseItemString)
	if not hasBaseInfo then
		-- Don't have item info yet
		return false, not fetchedBaseInfo
	end

	-- Cache the commodity status since it's referenced a ton
	if self._isCommodity == FIELD_NOT_SET then
		self._isCommodity = ItemInfo.IsCommodity(self._baseItemString)
		assert(self._isCommodity ~= nil)
	end

	-- Check if we have info for all the items and try to fetch it if not
	local missingInfo, fetchedMissingInfo = false, false
	ItemInfo.SetQueryUpdatesPaused(true)
	for _, item in ipairs(self._items) do
		if not item._hasInfo then
			if item.itemSuffix ~= 0 or item.battlePetSpeciesID ~= 0 then
				local itemKeyInfo = AuctionHouse.GetItemKeyInfo(item)
				if itemKeyInfo then
					item._name = itemKeyInfo.itemName
					if itemKeyInfo.battlePetLink then
						item._itemLevel = ItemInfo.GetItemLevel(itemKeyInfo.battlePetLink)
					elseif item.itemLevel ~= 0 then
						item._itemLevel = item.itemLevel
					else
						item._itemLevel = AuctionHouse.GetExtraBrowseInfo(item)
					end
					item._quality = itemKeyInfo.quality
					item._hasInfo = true
				else
					missingItemIds[item.itemID] = true
					missingInfo = true
					fetchedMissingInfo = true
				end
			else
				item._name = ItemInfo.GetName(self._baseItemString)
				item._itemLevel = ItemInfo.GetItemLevel(self._baseItemString)
				item._quality = ItemInfo.GetQuality(self._baseItemString)
				assert(item._name and item._itemLevel and item._quality)
				item._hasInfo = true
			end
		end
	end
	ItemInfo.SetQueryUpdatesPaused(false)
	if missingInfo then
		return false, not fetchedMissingInfo
	end

	self._hasItemInfo = true
	return true, false
end

---Returns whether or not this row is filtered by a query.
---@param query AuctionQuery The query
---@return boolean
function AuctionRow:IsFiltered(query)
	assert(#self._items > 0)
	if self._notFiltered then
		return false
	end

	-- Check if the whole row is filtered
	if query:_IsFiltered(self, false) then
		return true
	end

	-- Filter our items
	for i = #self._items, 1, -1 do
		if query:_IsFiltered(self, false, self._items[i]) then
			tremove(self._items, i)
		end
	end
	self._canHaveNonBaseItemString = nil
	self._minPrice = nil
	if #self._items == 0 then
		-- No more items, so the entire row is filtered
		return true
	end

	-- Not filtered (cache this result)
	self._notFiltered = true
	return false
end

---Resets the index of the item being searched for.
function AuctionRow:SearchReset()
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	assert(#self._items > 0)
	self._searchIndex = 1
end

---Advances the index of the item being searched for and returns if we're done with the entire row.
---@return boolean
function AuctionRow:SearchNext()
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	assert(self._searchIndex)
	if self._searchIndex == #self._items then
		self._searchIndex = nil
		return false
	end
	self._searchIndex = self._searchIndex + 1
	return true
end

---Checks if we're ready to search for this row.
---@return boolean
function AuctionRow:SearchIsReady()
	assert(self._searchIndex)
	-- The client needs to have the item key info cached before we can run the search
	return AuctionHouse.GetItemKeyInfo(self._items[self._searchIndex]) ~= nil
end

---Sends the active item search for this row.
---@return Future?
function AuctionRow:SearchSend()
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	assert(self._searchIndex)
	local itemKey = self._items[self._searchIndex]
	-- Send a sell query if we don't have browse results for the itemKey
	-- For some reason sell queries don't work for commodities or pets
	local isSellQuery = not self:IsCommodity() and not ItemString.IsPet(self._baseItemString) and not itemKey._totalQuantity
	return AuctionHouseWrapper.SendSearchQuery(itemKey, isSellQuery)
end

---Checks if there is cached search data for the current item.
---@return boolean
function AuctionRow:HasCachedSearchData()
	local itemKey = self._items[self._searchIndex]
	return AuctionHouse.HasFullSearchResults(self:IsCommodity() and itemKey.itemID or itemKey)
end

---Checks the status of the search and starts the next query if necessary.
---@return boolean isDone
---@return Future? future
function AuctionRow:SearchCheckStatus()
	assert(self._searchIndex)
	local itemKey = self._items[self._searchIndex]

	-- Check if we have the full results
	local hasFullResults = self:HasCachedSearchData()
	if hasFullResults then
		return true
	end

	-- Request more results
	if self:IsCommodity() then
		return false, AuctionHouseWrapper.RequestMoreCommoditySearchResults(itemKey.itemID)
	else
		return false, AuctionHouseWrapper.RequestMoreItemSearchResults(itemKey)
	end
end

---Populates the sub rows.
---@param browseId number The ID of the browse query
---@param index? number The item index
---@param itemLink? string The item link
function AuctionRow:PopulateSubRows(browseId, index, itemLink)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		assert(self._searchIndex and not index)
		local subRowOffset = self._searchIndex * SUB_ROW_SEARCH_INDEX_MULTIPLIER
		local itemKey = self._items[self._searchIndex]
		local numAuctions = AuctionHouse.GetNumSearchResults(self:IsCommodity() and itemKey.itemID or itemKey)
		if itemKey._numAuctions and numAuctions ~= itemKey._numAuctions then
			-- The results changed so clear out our existing data
			for i = itemKey._numAuctions, 1, -1 do
				if i > numAuctions then
					self._subRows[subRowOffset + i]:Release()
					self._subRows[subRowOffset + i] = nil
				else
					self._subRows[subRowOffset + i]:_SetRawData(nil)
				end
			end
		end
		itemKey._numAuctions = numAuctions
		for i = 1, numAuctions do
			self._subRows[subRowOffset + i] = self._subRows[subRowOffset + i] or AuctionSubRow.Get(self)
			local subRow = self._subRows[subRowOffset + i]
			if not subRow:HasRawData() or not subRow:HasOwners() then
				local result = AuctionHouse.GetSearchResultInfo(self:IsCommodity() and itemKey.itemID or itemKey, i)
				subRow:_SetRawData(result, browseId)
			end
		end
	else
		-- Remove any prior results with a different browseId
		assert(index and not self._searchIndex)
		local subRow = AuctionSubRow.Get(self)
		subRow:_SetRawData(index, browseId, itemLink)
		local _, hashNoSeller = subRow:GetHashes()
		if self._minBrowseId and self._minBrowseId ~= browseId then
			-- Check if this subRow already exists with a prior browseId
			for i, existingSubRow in ipairs(self._subRows) do
				local _, existingHashNoSeller = existingSubRow:GetHashes()
				local _, _, existingBrowseId = existingSubRow:GetListingInfo()
				if hashNoSeller == existingHashNoSeller and browseId ~= existingBrowseId then
					-- Replace the existing subRow
					existingSubRow:Release()
					self._subRows[i] = subRow
					return
				end
			end
		end
		tinsert(self._subRows, subRow)
	end
	self._minBrowseId = min(self._minBrowseId or math.huge, browseId)
end

---Filters sub rows based on a query and returns if this row is empty as a result.
---@param query AuctionQuery
---@return boolean
function AuctionRow:FilterSubRows(query)
	local subRowOffset = ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and (self._searchIndex * SUB_ROW_SEARCH_INDEX_MULTIPLIER) or 0
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local itemKey = self._items[self._searchIndex]
		for j = itemKey._numAuctions, 1, -1 do
			local subRow = self._subRows[subRowOffset + j]
			if query:_IsFiltered(subRow, true) then
				self:_RemoveSubRowByIndex(j)
			end
		end
	else
		for i = #self._subRows, 1, -1 do
			if query:_IsFiltered(self._subRows[i], true) then
				self:_RemoveSubRowByIndex(i)
			end
		end
	end

	-- Merge subRows with identical hashes
	local numSubRows = nil
	local hashIndexLookup = TempTable.Acquire()
	local index = 1
	while true do
		numSubRows = ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and self._items[self._searchIndex]._numAuctions or #self._subRows
		if index > numSubRows then
			break
		end
		local subRow = self._subRows[subRowOffset + index]
		local hash = subRow:GetHashes()
		local prevIndex = hashIndexLookup[hash]
		if prevIndex then
			-- There was a previous subRow with the same hash
			self._subRows[subRowOffset + prevIndex]:Merge(subRow)
			-- Remove this subRow
			self:_RemoveSubRowByIndex(index)
		else
			hashIndexLookup[hash] = index
			index = index + 1
		end
	end
	TempTable.Release(hashIndexLookup)
	return numSubRows == 0
end

---Gets the number of sub rows.
---@return number
function AuctionRow:GetNumSubRows()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local result = 0
		for _, itemKey in ipairs(self._items) do
			result = result + (itemKey._numAuctions or 0)
		end
		return result
	else
		return #self._subRows
	end
end

---Iterates over the sub rows.
---@param searchOnly? boolean Only include sub rows for the current item search index
---@return fun(): number, AuctionSubRow @Iterator with fields: `index`, `subRow`
function AuctionRow:SubRowIterator(searchOnly)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		if searchOnly then
			local result = TempTable.Acquire()
			assert(self._searchIndex)
			for i = 1, self._items[self._searchIndex]._numAuctions do
				local subRow = self._subRows[self._searchIndex * SUB_ROW_SEARCH_INDEX_MULTIPLIER + i]
				assert(subRow)
				tinsert(result, subRow)
			end
			return TempTable.Iterator(result)
		else
			return private.SubRowIteratorHelper, self, SUB_ROW_SEARCH_INDEX_MULTIPLIER
		end
	else
		return ipairs(self._subRows)
	end
end

---Gets a commodity item sub row.
---@param index number The index of the sub row to get
---@return AuctionSubRow
function AuctionRow:GetCommoditySubRow(index)
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and #self._items == 1)
	return self._subRows[SUB_ROW_SEARCH_INDEX_MULTIPLIER + index]
end

---Checks if this row is for a commodity item.
---@return boolean
function AuctionRow:IsCommodity()
	assert(self._isCommodity ~= FIELD_NOT_SET)
	return self._isCommodity
end

---Checks if we have item info cached.
---@return boolean
function AuctionRow:HasItemInfo()
	return self._hasItemInfo
end

---Gets the base item string.
---@return string
function AuctionRow:GetBaseItemString()
	return self._baseItemString
end

---Gets the item string.
---@return string?
function AuctionRow:GetItemString()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) or not self._hasItemInfo or self._canHaveNonBaseItemString then
		return nil
	end
	if self._canHaveNonBaseItemString == nil then
		for _, itemKey in ipairs(self._items) do
			if ItemInfo.CanHaveVariations(self._baseItemString) or itemKey.battlePetSpeciesID ~= 0 or itemKey.itemSuffix ~= 0 or itemKey.itemLevel ~= 0 then
				-- This item can have variations, so we don't know its itemString
				self._canHaveNonBaseItemString = true
				return nil
			end
		end
		self._canHaveNonBaseItemString = false
	end
	return self._baseItemString
end

---Get item info for a given item key.
---@param itemKey? ItemKey The item key
---@return string? name
---@return number? quality
---@return number? itemLevel
function AuctionRow:GetItemInfo(itemKey)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) or not self._hasItemInfo then
		return nil, nil, nil, nil
	end
	itemKey = itemKey or (#self._items == 1 and self._items[1]) or nil
	assert(not itemKey or itemKey._hasInfo)
	local baseItemString = self:GetBaseItemString()
	local itemString = self:GetItemString()
	local itemName, quality, itemLevel = nil, nil, nil
	if itemString then
		-- This item can't have variations, so we can know the name / level / quality
		itemName = ItemInfo.GetName(baseItemString)
		itemLevel = ItemInfo.GetItemLevel(baseItemString)
		quality = ItemInfo.GetQuality(baseItemString)
		assert(itemName and itemLevel and quality)
	else
		if itemKey and not itemKey._totalQuantity then
			-- If we didn't do a browse, then don't use this itemKey
			itemKey = nil
		end
		if itemKey then
			-- Grab the name from the itemKey info
			itemName = itemKey._name
			assert(itemName)
		end
		local hasSingleAuction = itemKey and itemKey._totalQuantity == 1
		if hasSingleAuction then
			-- Grab the quality from the itemKey info since there's only one listing
			quality = itemKey._quality
			assert(quality)
		end
		if itemKey and itemKey._itemLevel and hasSingleAuction then
			-- Grab the itemLevel itemKey info since there's only one listing
			itemLevel = itemKey._itemLevel
			assert(itemLevel)
		elseif not ItemString.IsPet(self._baseItemString) then
			-- Only use the itemLevel from the itemKey info if they are all the same
			itemLevel = self._items[1]._itemLevel
			for i = 2, #self._items do
				if self._items[i]._itemLevel ~= itemLevel then
					itemLevel = nil
					break
				end
			end
		end
	end
	return itemName, quality, itemLevel
end

---Gets the buyouts.
---@return nil buyout
---@return nil itemBuyout
---@return number? minPrice
function AuctionRow:GetBuyouts(resultItemKey)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		return nil, nil, nil
	end
	assert(#self._items > 0)
	if resultItemKey then
		return nil, nil, resultItemKey._minPrice
	else
		if self._minPrice == nil then
			for _, itemKey in ipairs(self._items) do
				if not itemKey._minPrice then
					self._minPrice = -1
					return nil, nil, nil
				end
				self._minPrice = min(self._minPrice or math.huge, itemKey._minPrice)
			end
		elseif self._minPrice == -1 then
			return nil, nil, nil
		end
		return nil, nil, self._minPrice
	end
end

---Gets the quantities.
---@return number quantity
---@return number numAuctions
function AuctionRow:GetQuantities()
	local totalQuantity = 0
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		for _, itemKey in ipairs(self._items) do
			if not itemKey._totalQuantity then
				return
			end
			totalQuantity = totalQuantity + itemKey._totalQuantity
		end
	else
		for _, subRow in ipairs(self._subRows) do
			local quantity, numAuctions = subRow:GetQuantities()
			totalQuantity = totalQuantity + quantity * numAuctions
		end
	end
	return totalQuantity, 1
end

---Gets the max quantities.
---@return number totalQuantity
function AuctionRow:GetMaxQuantities()
	assert(self:IsCommodity())
	local totalQuantity = 0
	for _, subRow in self:SubRowIterator() do
		local _, numOwnerItems = subRow:GetOwnerInfo()
		local quantityAvailable = subRow:GetQuantities() - numOwnerItems
		totalQuantity = totalQuantity + quantityAvailable
	end
	return totalQuantity
end

---Removes a sub row from the row.
---@param subRow AuctionSubRow
function AuctionRow:RemoveSubRow(subRow)
	local index = Table.KeyByValue(self._subRows, subRow)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local searchIndex = floor(index / SUB_ROW_SEARCH_INDEX_MULTIPLIER)
		index = index % SUB_ROW_SEARCH_INDEX_MULTIPLIER
		assert(self._subRows[searchIndex * SUB_ROW_SEARCH_INDEX_MULTIPLIER + index] == subRow)
		local prevSearchIndex = self._searchIndex
		self._searchIndex = searchIndex
		self:_RemoveSubRowByIndex(index)
		self._searchIndex = prevSearchIndex
	else
		self:_RemoveSubRowByIndex(index)
	end
	self._query:_OnSubRowRemoved(self)
end

---Wipes the sub rows.
function AuctionRow:WipeSearchResults()
	wipe(self._subRows)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		for _, itemKey in ipairs(self._items) do
			itemKey._numAuctions = nil
		end
	end
end

---Gets the query which the row belongs to.
---@return AuctionQuery
function AuctionRow:GetQuery()
	return self._query
end

---Decrements the quantity of the row's item.
---@param amount number The amount to decrement by
function AuctionRow:DecrementQuantity(amount)
	assert(self:IsCommodity() and ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and #self._items == 1)
	local index = 1
	while amount > 0 do
		local subRow = self._subRows[index + SUB_ROW_SEARCH_INDEX_MULTIPLIER]
		assert(subRow)
		local _, numOwnerItems = subRow:GetOwnerInfo()
		local quantityAvailable = subRow:GetQuantities() - numOwnerItems
		if quantityAvailable > 0 then
			local usedQuantity = min(quantityAvailable, amount)
			local prevItemBuyout = floor(subRow._buyout / subRow._quantity)
			amount = amount - usedQuantity
			subRow._quantity = subRow._quantity - usedQuantity
			subRow._buyout = prevItemBuyout * subRow._quantity
			subRow._minBid = subRow._buyout
			if numOwnerItems == 0 and subRow._quantity == 0 then
				self:RemoveSubRow(subRow)
			else
				index = index + 1
			end
		else
			index = index + 1
		end
	end
end

---Gets the min browse ID associated with the row.
---@return number
function AuctionRow:GetMinBrowseId()
	return self._minBrowseId
end



-- ============================================================================
-- AuctionRow - Private Class Methods
-- ============================================================================

function AuctionRow.__private:_RemoveSubRowByIndex(index)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local subRowOffset = self._searchIndex * SUB_ROW_SEARCH_INDEX_MULTIPLIER
		local itemKey = self._items[self._searchIndex]
		self._subRows[subRowOffset + index]:Release()
		self._subRows[subRowOffset + index] = nil
		-- shift the other subRows for this item down
		for i = index, itemKey._numAuctions - 1 do
			self._subRows[subRowOffset + i] = self._subRows[subRowOffset + i + 1]
		end
		self._subRows[subRowOffset + itemKey._numAuctions] = nil
		itemKey._numAuctions = itemKey._numAuctions - 1
	else
		self._subRows[index]:Release()
		tremove(self._subRows, index)
	end
end

---@private
function AuctionRow:_GetSearchProgress()
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	if #self._items == 0 then
		return 0
	end
	local numSearched = 0
	for _, itemKey in ipairs(self._items) do
		if itemKey._numAuctions then
			numSearched = numSearched + 1
		end
	end
	return numSearched / #self._items
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SubRowIteratorHelper(row, index)
	local searchIndex = floor(index / SUB_ROW_SEARCH_INDEX_MULTIPLIER)
	local subRowIndex = index % SUB_ROW_SEARCH_INDEX_MULTIPLIER
	while true do
		local itemKey = row._items[searchIndex]
		if not itemKey then
			return
		end

		if subRowIndex >= (itemKey._numAuctions or 0) then
			searchIndex = searchIndex + 1
			subRowIndex = 0
		else
			subRowIndex = subRowIndex + 1
			index = searchIndex * SUB_ROW_SEARCH_INDEX_MULTIPLIER + subRowIndex
			return index, row._subRows[index]
		end
	end
end
