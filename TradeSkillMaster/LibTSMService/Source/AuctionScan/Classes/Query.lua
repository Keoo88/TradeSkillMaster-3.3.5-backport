-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionQuery = LibTSMService:DefineClassType("AuctionQuery")
local AuctionRow = LibTSMService:IncludeClassType("AuctionRow")
local Scanner = LibTSMService:Include("AuctionScan.Scanner")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local AuctionHouseWrapper = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local Item = LibTSMService:From("LibTSMWoW"):Include("API.Item")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local private = {
	objectPool = ObjectPool.New("AUCTION_SCAN_QUERY", AuctionQuery, 1),
	-- 3.3.5 backport: cache of link -> usable result for the client-side usable filter
	usableCache = {},
}
local ITEM_SPECIFIC = newproxy()
local ITEM_BASE = newproxy()
local FILTER_NOT_SET = newproxy()



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Gets an auction query.
---@return AuctionQuery
function AuctionQuery.__static.Get()
	return private.objectPool:Get()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function AuctionQuery:__init()
	self._str = ""
	self._strLower = ""
	self._strMatch = ""
	self._exact = false
	self._minQuality = -math.huge
	self._maxQuality = math.huge
	self._minLevel = -math.huge
	self._maxLevel = math.huge
	self._minItemLevel = -math.huge
	self._maxItemLevel = math.huge
	self._class = FILTER_NOT_SET
	self._subClass = FILTER_NOT_SET
	self._invType = FILTER_NOT_SET
	self._classFilter1 = {}
	self._classFilter2 = {}
	self._usable = false
	self._uncollected = false
	self._upgrades = false
	self._unlearned = false
	self._canLearn = false
	self._minPrice = 0
	self._maxPrice = math.huge
	self._items = {}
	self._customFilters = {}
	self._isBrowseDoneFunc = nil
	self._browseEndedEarly = false
	self._specifiedPage = nil
	self._resolveSellers = false
	self._callback = nil
	self._browseResults = {} ---@type table<string,AuctionRow>
	self._page = 0
	self._staleSubRowsCleared = false
	self._accumulate = false
	self._useGetAll = false
	self._usePriceSort = false
	self._traceTag = nil
	self._tStart = nil
	self._tFirstPage = nil
	self._pageCount = 0
	self._maxTotalSeen = 0
	self._tPageQuerySent = nil
	self._lastPagePrinted = -1
	self._lastPageFingerprint = nil
	self._incrementalFilter = false
	self._dirtyRows = {}
end

function AuctionQuery:_Release()
	self._str = ""
	self._strLower = ""
	self._strMatch = ""
	self._exact = false
	self._minQuality = -math.huge
	self._maxQuality = math.huge
	self._minLevel = -math.huge
	self._maxLevel = math.huge
	self._minItemLevel = -math.huge
	self._maxItemLevel = math.huge
	self._class = FILTER_NOT_SET
	self._subClass = FILTER_NOT_SET
	self._invType = FILTER_NOT_SET
	wipe(self._classFilter1)
	wipe(self._classFilter2)
	self._usable = false
	self._uncollected = false
	self._upgrades = false
	self._unlearned = false
	self._canLearn = false
	self._minPrice = 0
	self._maxPrice = math.huge
	wipe(self._items)
	wipe(self._customFilters)
	self._isBrowseDoneFunc = nil
	self._browseEndedEarly = false
	self._specifiedPage = nil
	self._resolveSellers = false
	self._callback = nil
	for _, row in pairs(self._browseResults) do
		row:Release()
	end
	wipe(self._browseResults)
	self._page = 0
	self._staleSubRowsCleared = false
	self._accumulate = false
	self._useGetAll = false
	self._usePriceSort = false
	self._traceTag = nil
	self._tStart = nil
	self._tFirstPage = nil
	self._pageCount = 0
	self._maxTotalSeen = 0
	self._tPageQuerySent = nil
	self._lastPagePrinted = -1
	self._lastPageFingerprint = nil
	self._incrementalFilter = false
	wipe(self._dirtyRows)
end


-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Release the query.
function AuctionQuery:Release()
	self:_Release()
	private.objectPool:Recycle(self)
end

---Sets the string to query on.
---@param str? string
---@param exact? boolean
---@return AuctionQuery
function AuctionQuery:SetStr(str, exact)
	self._str = str or ""
	self._strLower = strlower(self._str)
	self._strMatch = String.Escape(self._strLower)
	self._exact = exact or false
	-- print(string.format("TSM:Query:SetStr str=%s lower=%s exact=%s", tostring(str), tostring(self._strLower), tostring(exact)))
	return self
end

---Sets the item quality range.
---@param minQuality? number
---@param maxQuality? number
---@return AuctionQuery
function AuctionQuery:SetQualityRange(minQuality, maxQuality)
	self._minQuality = minQuality or -math.huge
	self._maxQuality = maxQuality or math.huge
	return self
end

---Sets the level range.
---@param minLevel? number
---@param maxLevel? number
---@return AuctionQuery
function AuctionQuery:SetLevelRange(minLevel, maxLevel)
	self._minLevel = minLevel or -math.huge
	self._maxLevel = maxLevel or math.huge
	return self
end

---Gets the item level range.
---@param minItemLevel number
---@param maxItemLevel number
---@return AuctionQuery
function AuctionQuery:SetItemLevelRange(minItemLevel, maxItemLevel)
	self._minItemLevel = minItemLevel or -math.huge
	self._maxItemLevel = maxItemLevel or math.huge
	return self
end

---Sets the class filter.
---@param class? number
---@param subClass? number
---@param invType? number
---@return AuctionQuery
function AuctionQuery:SetClass(class, subClass, invType)
	self._class = class or FILTER_NOT_SET
	self._subClass = subClass or FILTER_NOT_SET
	self._invType = invType or FILTER_NOT_SET
	return self
end

---Sets the usable filter.
---@param usable? boolean
---@return AuctionQuery
function AuctionQuery:SetUsable(usable)
	self._usable = usable or false
	-- 3.3.5 backport: wipe the client-side usable cache when a new usable query starts,
	-- since usability can change between scans (level up, learned skill/recipe)
	if self._usable then
		wipe(private.usableCache)
	end
	return self
end

---Sets the uncollected filter.
---@param uncollected? boolean
---@return AuctionQuery
function AuctionQuery:SetUncollected(uncollected)
	self._uncollected = uncollected or false
	return self
end

---Sets the upgrades filter.
---@param upgrades? boolean
---@return AuctionQuery
function AuctionQuery:SetUpgrades(upgrades)
	self._upgrades = upgrades or false
	return self
end

---Sets the unlearned filter.
---@param unlearned? boolean
---@return AuctionQuery
function AuctionQuery:SetUnlearned(unlearned)
	self._unlearned = unlearned or false
	return self
end

---Sets the can learn filter.
---@param canLearn? boolean
---@return AuctionQuery
function AuctionQuery:SetCanLearn(canLearn)
	self._canLearn = canLearn or false
	return self
end

---Sets the price range.
---@param minPrice? number
---@param maxPrice? number
---@return AuctionQuery
function AuctionQuery:SetPriceRange(minPrice, maxPrice)
	self._minPrice = minPrice or 0
	self._maxPrice = maxPrice or math.huge
	return self
end

---Sets the list of items to query for.
---@param items string[]|string|nil A list of item strings, a single item string, or nil for no items
---@return AuctionQuery
function AuctionQuery:SetItems(items)
	wipe(self._items)
	if type(items) == "table" then
		for _, itemString in ipairs(items) do
			local baseItemString = ItemString.GetBaseFast(itemString)
			self._items[itemString] = ITEM_SPECIFIC
			if baseItemString ~= itemString then
				self._items[baseItemString] = self._items[baseItemString] or ITEM_BASE
			end
		end
	elseif type(items) == "string" then
		local itemString = items
		local baseItemString = ItemString.GetBaseFast(itemString)
		self._items[itemString] = ITEM_SPECIFIC
		if baseItemString ~= itemString then
			self._items[baseItemString] = self._items[baseItemString] or ITEM_BASE
		end
	elseif items ~= nil then
		error("Invalid items type: "..tostring(items))
	end
	return self
end

---Adds a custom filter function.
---@param func fun(query: AuctionQuery, row: AuctionRow|AuctionSubRow, isSubRow: boolean, itemKey: ItemKey): boolean
---@return AuctionQuery
function AuctionQuery:AddCustomFilter(func)
	self._customFilters[func] = true
	return self
end

---Sets a function to call for checking if we're done with a browse query.
---@param func fun(query: AuctionQuery): boolean
---@return AuctionQuery
function AuctionQuery:SetIsBrowseDoneFunction(func)
	self._isBrowseDoneFunc = func
	return self
end

---Sets the page to query for.
---@param page number|string|nil The specific page number or "FIRST"/"LAST" for relative pages
---@return AuctionQuery
function AuctionQuery:SetPage(page)
	if page == nil then
		self._specifiedPage = nil
	elseif type(page) == "number" or page == "FIRST" or page == "LAST" then
		assert(not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
		self._specifiedPage = page
	else
		error("Invalid page: "..tostring(page))
	end
	return self
end

---Sets whether or not to resolve seller names.
---@param resolveSellers boolean
---@return AuctionQuery
function AuctionQuery:SetResolveSellers(resolveSellers)
	self._resolveSellers = resolveSellers
	return self
end

---Requests a single getAll AH dump for classic. Bypasses pagination.
---Server may rate-limit or reject; caller is responsible for handling that.
---@param useGetAll boolean
---@return AuctionQuery
function AuctionQuery:SetUseGetAll(useGetAll)
	self._useGetAll = useGetAll and true or false
	return self
end
---Requests the classic browse results to be sorted by unit price.
---@param usePriceSort boolean
---@return AuctionQuery
function AuctionQuery:SetUsePriceSort(usePriceSort)
	self._usePriceSort = usePriceSort and true or false
	return self
end
---Sets whether browse results accumulate across repeated browses instead of being
---wiped before each one. Used by the classic Sniper so found lots persist in the
---list between rescans (deduped by auction hash). Results are still cleared when the
---query is released (i.e. when the scan is stopped or restarted).
---@param accumulate boolean
---@return AuctionQuery
function AuctionQuery:SetAccumulate(accumulate)
	self._accumulate = accumulate and true or false
	return self
end

---Enables per-query timing chat-prints (start / per-page / done) with the given tag.
---@param tag string Short label printed in chat to identify this query
---@return AuctionQuery
function AuctionQuery:SetTraceTimings(tag)
	self._traceTag = tag
	return self
end

---Enables Classic incremental browse filtering (Gathering scans only).
---@param incrementalFilter boolean
---@return AuctionQuery
function AuctionQuery:SetIncrementalFilter(incrementalFilter)
	self._incrementalFilter = incrementalFilter and true or false
	if not self._incrementalFilter then
		wipe(self._dirtyRows)
	end
	return self
end

---Sets a callback for the results of the query changing.
---@param callback fun(query: AuctionQuery, row?: AuctionRow)
---@return AuctionQuery
function AuctionQuery:SetCallback(callback)
	self._callback = callback
	return self
end

---Starts the browse query.
---@return Future
function AuctionQuery:Browse()
	-- 3.3.5: очищаем stale subRows перед новым browse (чтобы UI не показывал старые лоты)
	-- Sniper accumulate mode (SetAccumulate) skips this wipe so found lots persist
	-- in the list across rescans instead of vanishing each pass.
	if not self._accumulate and not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local numRows = 0
		local numSubRows = 0
		for _, row in pairs(self._browseResults) do
			numRows = numRows + 1
			for i = #row._subRows, 1, -1 do
				row._subRows[i]:Release()
				row._subRows[i] = nil
				numSubRows = numSubRows + 1
			end
			row._minBrowseId = nil
		end
		if TSMDBG and numSubRows > 0 then
			TSMDBG.Log("Query", "Browse: cleared %d stale subRows from %d rows before new browse", numSubRows, numRows)
		end
		if self._incrementalFilter then
			for baseItemString in pairs(self._browseResults) do
				self._dirtyRows[baseItemString] = true
			end
		end
	end

	local noScan = false
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local numItems = 0
		for _, itemType in pairs(self._items) do
			if itemType == ITEM_SPECIFIC then
				numItems = numItems + 1
			end
		end
		if numItems > 0 and numItems < 500 then
			-- it's faster to just issue individual item searches instead of a browse query
			noScan = true
		end
	end

	if noScan then
		assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
		local itemKeys = TempTable.Acquire()
		for itemString in pairs(self._items) do
			if itemString == ItemString.GetBaseFast(itemString) then
				local itemId, battlePetSpeciesId = nil, nil
				if ItemString.IsPet(itemString) then
					itemId = ItemString.ToId(ItemString.GetPetCage())
					battlePetSpeciesId = ItemString.ToId(itemString)
				else
					itemId = ItemString.ToId(itemString)
					battlePetSpeciesId = 0
				end
				tinsert(itemKeys, AuctionHouse.MakeItemKey(itemId, battlePetSpeciesId))
			end
		end
		local future = Scanner.BrowseNoScan(self, itemKeys, self._callback)
		TempTable.Release(itemKeys)
		return future
	else
		self._page = 0
		if self._traceTag then
			self._tStart = GetTime()
			self._tFirstPage = nil
			self._pageCount = 0
			print(string.format("|cFFFFA500TSM DE Scan:|r query=%s START%s",
				tostring(self._traceTag), self._useGetAll and " (getAll)" or ""))
		end
		return Scanner.Browse(self, self._resolveSellers, self._callback)
	end
end

---Gets the search progress.
---@return number
function AuctionQuery:GetSearchProgress()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		-- 3.3.5: считаем прогресс по страницам browse, т.к. search-step нет.
		-- GetNumAuctionItems total ненадёжный (часто 0 / накопительно), поэтому
		-- используем memoized peak (_maxTotalSeen) как в _BrowseIsDone — иначе
		-- прогресс схлопывается в 0 и прогресс-бар выглядит чёрным квадратом
		-- весь скан (single-query post scan: progress == searchProgress).
		local NUM_AUCTION_ITEMS_PER_PAGE = 50
		local _, totalNumAuctions = GetNumAuctionItems("list")
		totalNumAuctions = totalNumAuctions or 0
		if totalNumAuctions > (self._maxTotalSeen or 0) then
			self._maxTotalSeen = totalNumAuctions
		end
		local total = self._maxTotalSeen or 0
		if total <= 0 then
			-- общее число страниц ещё неизвестно (сервер не отдал total):
			-- показываем растущую по номеру страницы оценку, чтобы бар не был пустым/чёрным
			return math.min(0.05 + (self._page or 0) * 0.1, 0.9)
		end
		local totalPages = math.max(1, math.ceil(total / NUM_AUCTION_ITEMS_PER_PAGE))
		return math.min((self._page + 1) / totalPages, 1)
	end
	local progress, totalNum = 0, 0
	for _, row in pairs(self._browseResults) do
		progress = progress + row:_GetSearchProgress()
		totalNum = totalNum + 1
	end
	if totalNum == 0 then
		return 0
	end
	return progress / totalNum
end

---Iterates over the sub rows for an item.
---@param itemString string The item string
---@return fun(): number, AuctionSubRow @Iterator with fields: `index`, `subRow`
function AuctionQuery:ItemSubRowIterator(itemString)
	local result = TempTable.Acquire()
	local baseItemString = ItemString.GetBaseFast(itemString)
	local levelItemString = ItemString.ToLevel(itemString)
	local isBaseItemString = itemString == baseItemString
	local isLevelItemString = itemString == levelItemString and not isBaseItemString
	local row = self._browseResults[baseItemString]
	if row then
		for _, subRow in row:SubRowIterator() do
			local subRowBaseItemString = subRow:GetBaseItemString()
			local subRowItemString = subRow:GetItemString()
			if (isBaseItemString and subRowBaseItemString == itemString) or (isLevelItemString and ItemString.ToLevel(subRowItemString) == itemString) or (not isBaseItemString and not isLevelItemString and subRowItemString == itemString) then
				tinsert(result, subRow)
			end
		end
	end
	return TempTable.Iterator(result)
end

---Gets the cheapest sub row for an item.
---@param itemString string The item string
---@return AuctionSubRow?
function AuctionQuery:GetCheapestSubRow(itemString)
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	local cheapest, cheapestItemBuyout = nil, nil
	for _, subRow in self:ItemSubRowIterator(itemString) do
		local quantity = subRow:GetQuantities()
		local _, numOwnerItems = subRow:GetOwnerInfo()
		local _, itemBuyout = subRow:GetBuyouts()
		if numOwnerItems ~= quantity and itemBuyout < (cheapestItemBuyout or math.huge) then
			cheapest = subRow
			cheapestItemBuyout = itemBuyout
		end
	end
	return cheapest
end

---Iteratest over the browse results
---@return fun(): string, AuctionRow @Iterator with fields: `baseItemString`, `row`
function AuctionQuery:BrowseResultsIterator()
	return pairs(self._browseResults)
end

---Removes a row from the results.
---@param row AuctionRow The row to removve
function AuctionQuery:RemoveResultRow(row)
	local baseItemString = row:GetBaseItemString()
	assert(baseItemString and self._browseResults[baseItemString])
	self._browseResults[baseItemString] = nil
	row:Release()
	if self._callback then
		self:_callback()
	end
end

---Searches for an auction row.
---@param row AuctionRow The row to search for
---@param useCachedData boolean Use cached data for the search
---@return Future
function AuctionQuery:Search(row, useCachedData)
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	assert(self._browseResults)
	return Scanner.Search(self, self._resolveSellers, useCachedData, row, self._callback)
end

---Cancels the current browse or search.
function AuctionQuery:CancelBrowseOrSearch()
	Scanner.Cancel()
end

---Iterates over the items involved in the query.
---@return fun(): number, string @Iterator with fields: `index`, `itemString`
function AuctionQuery:ItemIterator()
	return private.ItemIteratorHelper, self._items, nil
end

---Wipes the browse results.
function AuctionQuery:WipeBrowseResults()
	for _, row in pairs(self._browseResults) do
		row:Release()
	end
	wipe(self._browseResults)
	if self._callback then
		self:_callback()
	end
end



-- ============================================================================
-- Private Class Methods (Called by the Scanner Code)
-- ============================================================================

function AuctionQuery:_SetSort()
	return AuctionHouseWrapper.SetSort(self._usePriceSort or type(self._specifiedPage) == "string", self._usePriceSort)
end

function AuctionQuery:_SendWowQuery()
	local minLevel = self._minLevel ~= -math.huge and self._minLevel or nil
	local maxLevel = self._maxLevel ~= math.huge and self._maxLevel or nil
	local minQuality = self._minQuality == -math.huge and 0 or self._minQuality
	if self._specifiedPage == "LAST" then
		self._page = max(AuctionHouse.GetNumPages() - 1, 0)
	elseif self._specifiedPage == "FIRST" then
		self._page = 0
	elseif self._specifiedPage then
		self._page = self._specifiedPage
	end
	local class = self._class ~= FILTER_NOT_SET and self._class or nil
	local subClass = self._subClass ~= FILTER_NOT_SET and self._subClass or nil
	local invType = self._invType ~= FILTER_NOT_SET and self._invType or nil
	TSMDBG.Log("Query", "_SendWowQuery str=%s class=%s subClass=%s invType=%s minLvl=%s maxLvl=%s minQual=%s page=%s getAll=%s",
		tostring(self._str), tostring(class), tostring(subClass), tostring(invType), tostring(minLevel), tostring(maxLevel), tostring(minQuality), tostring(self._page), tostring(self._useGetAll))
	if TSMDBG.SignalQuerySent then TSMDBG.SignalQuerySent(self._str) end
	if self._traceTag then
		self._pageCount = (self._pageCount or 0) + 1
		self._tPageQuerySent = GetTime()
		if not self._tFirstPage then
			self._tFirstPage = self._tPageQuerySent
		end
	end
	return AuctionHouseWrapper.SendQuery(self._str, class, subClass, invType, minLevel, maxLevel, minQuality, self._maxQuality, self._uncollected, self._usable, self._upgrades, self._exact, self._page, self._useGetAll)
end

function AuctionQuery:_HasSubRowFilters(ignoreTextSearch)
	if not ignoreTextSearch and self._str ~= "" then
		return true
	end
	if next(self._items) then
		return true
	end
	if self._minLevel ~= -math.huge or self._maxLevel ~= math.huge then
		return true
	end
	if self._minItemLevel ~= -math.huge or self._maxItemLevel ~= math.huge then
		return true
	end
	if self._minQuality ~= -math.huge or self._maxQuality ~= math.huge then
		return true
	end
	if self._class ~= FILTER_NOT_SET or self._subClass ~= FILTER_NOT_SET or self._invType ~= FILTER_NOT_SET then
		return true
	end
	if self._unlearned or self._canLearn then
		return true
	end
	if self._minPrice ~= 0 or self._maxPrice ~= math.huge then
		return true
	end
	for _ in pairs(self._customFilters) do
		return true
	end
	return false
end

function AuctionQuery:_IsFiltered(row, isSubRow, itemKey)
	local baseItemString = row:GetBaseItemString()
	local itemString = row:GetItemString()
	assert(baseItemString)
	local name, quality, itemLevel = row:GetItemInfo(itemKey)
	local _, itemBuyout, minItemBuyout = row:GetBuyouts(itemKey)
	if row:IsSubRow() and itemBuyout == 0 then
		_, itemBuyout = row:GetBidInfo()
	end

	-- 3.3.5: на классике GetItemInfo возвращает nil, поэтому используем itemLink для получения названия
	if not name and row._itemLink then
		local link = row._itemLink or ""
		name = link:match("%[(.-)%]") or ""
	end

	if next(self._items) then
		if not self._items[baseItemString] then
			return true
		end
		local levelItemString = itemString and ItemString.ToLevel(itemString)
		if isSubRow and itemString and self._items[itemString] ~= ITEM_SPECIFIC and self._items[levelItemString] ~= ITEM_SPECIFIC and self._items[baseItemString] ~= ITEM_SPECIFIC then
			-- this is a sub row and we're not looking for this item
			return true
		elseif not isSubRow and itemString and not self._items[itemString] then
			-- this is a base row but the base item doesn't match any item we're interested in
			return true
		end
	end
	if self._str ~= "" and name then
		name = strlower(name)
		if self._exact then
			if name ~= self._strLower then
				return true
			end
		else
			if not strfind(name, self._strLower, 1, true) then
				return true
			end
		end
	end
	if self._minLevel ~= -math.huge or self._maxLevel ~= math.huge then
		local minLevel = ItemString.IsPet(baseItemString) and itemLevel or ItemInfo.GetMinLevel(baseItemString)
		if minLevel < self._minLevel or minLevel > self._maxLevel then
			return true
		end
	end
	if itemLevel and (itemLevel < self._minItemLevel or itemLevel > self._maxItemLevel) then
		return true
	end
	if quality and (quality < self._minQuality or quality > self._maxQuality) then
		return true
	end
	if self._class ~= FILTER_NOT_SET and ItemInfo.GetClassId(baseItemString) ~= self._class then
		return true
	end
	if self._subClass ~= FILTER_NOT_SET and ItemInfo.GetSubClassId(baseItemString) ~= self._subClass then
		return true
	end
	if self._invType ~= FILTER_NOT_SET and ItemInfo.GetInvSlotId(baseItemString) ~= self._invType then
		return true
	end
	-- luacheck: globals CanIMogIt
	if self._unlearned and CanIMogIt:PlayerKnowsTransmog(ItemInfo.GetLink(baseItemString)) then
		return true
	end
	if self._canLearn and not CanIMogIt:CharacterCanLearnTransmog(ItemInfo.GetLink(baseItemString)) then
		return true
	end
	if itemBuyout and (itemBuyout < self._minPrice or itemBuyout > self._maxPrice) then
		return true
	end
	if minItemBuyout and minItemBuyout > self._maxPrice then
		return true
	end
	-- 3.3.5 backport fix: the server-side "usable" flag of QueryAuctionItems can't be
	-- relied on (many private servers ignore it), so post-filter client-side via a
	-- tooltip scan for red (unmet requirement) text. Results are cached per item.
	if self._usable and not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local link = ItemInfo.GetLink(itemString or baseItemString)
		if link then
			local cached = private.usableCache[link]
			if cached == nil then
				cached = Item.IsUsable(link)
				private.usableCache[link] = cached
			end
			if not cached then
				return true
			end
		end
	end
	for func in pairs(self._customFilters) do
		if func(self, row, isSubRow, itemKey) then
			return true
		end
	end
	return false
end

function AuctionQuery:_BrowseIsDone(isRetry)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		if self._isBrowseDoneFunc and self:_isBrowseDoneFunc() then
			self._browseEndedEarly = true
			return true
		end
		return AuctionHouse.HasFullBrowseResults()
	else
		-- 3.3.5: последняя страница определяется тем что на ней < NUM_AUCTION_ITEMS_PER_PAGE
		-- (totalNumAuctions от Blizzard ненадёжный — может возвращать 0 или накопительно)
		local NUM_AUCTION_ITEMS_PER_PAGE = 50
		local numAuctions, totalNumAuctions = GetNumAuctionItems("list")
		numAuctions = numAuctions or 0
		totalNumAuctions = totalNumAuctions or 0
		if self._specifiedPage then
			if isRetry then
				return false
			end
			local numPages = math.max(1, math.ceil(totalNumAuctions / NUM_AUCTION_ITEMS_PER_PAGE))
			local specifiedPage = (self._specifiedPage == "FIRST" and 0) or (self._specifiedPage == "LAST" and numPages - 1) or self._specifiedPage
			return self._page == specifiedPage
		elseif self._isBrowseDoneFunc and self:_isBrowseDoneFunc() then
			self._browseEndedEarly = true
			return true
		else
			-- AUX-стиль: эта страница последняя, если на ней < 50 (или 0) аукционов
			-- 3.3.5: totalNumAuctions ненадёжный (может быть 0 или неправильный), поэтому полагаемся только на pageIsLast
			-- getAll: один запрос вернул всё — всегда done после первой "страницы"
			if self._useGetAll then
				if TSMDBG then TSMDBG.Log("Query", "_BrowseIsDone classic getAll done=true num=%d total=%d", numAuctions, totalNumAuctions) end
				if self._traceTag and self._tStart then
					print(string.format("|cFFFFA500TSM DE Scan:|r query=%s DONE getAll pages=%d auctions=%d elapsed=%.2fs",
						tostring(self._traceTag), self._pageCount or 1, numAuctions, GetTime() - self._tStart))
				end
				return true
			end
			local pageIsLast = numAuctions < NUM_AUCTION_ITEMS_PER_PAGE
			local pageFingerprint = nil
			if numAuctions > 0 then
				local _, firstLink = AuctionHouse.GetBrowseResult(1)
				local _, lastLink = AuctionHouse.GetBrowseResult(numAuctions)
				pageFingerprint = tostring(firstLink or "") .. "|" .. tostring(lastLink or "") .. "|" .. tostring(numAuctions)
			else
				pageFingerprint = "0"
			end
			-- Memoize peak totalNumAuctions: on 3.3.5 it can transiently be 0 or
			-- swing low between pages, but it does monotonically converge to the
			-- real AH total. Peak value is a safe upper bound.
			if totalNumAuctions > (self._maxTotalSeen or 0) then
				self._maxTotalSeen = totalNumAuctions
			end
			-- Page-cap: when server has run out of real auctions but keeps echoing
			-- a full page (numAuctions stays at 50), pageIsLast never trips.
			-- ceil(maxTotalSeen / 50) gives the real page count; once self._page
			-- reaches it, force done. self._page is 0-based.
			local cappedDone = false
			if self._maxTotalSeen > 0 then
				local maxPages = math.ceil(self._maxTotalSeen / NUM_AUCTION_ITEMS_PER_PAGE)
				if self._page + 1 >= maxPages then
					cappedDone = true
				end
			end
			local repeatedPage = self._page > 0 and self._lastPageFingerprint and self._lastPageFingerprint == pageFingerprint and numAuctions >= NUM_AUCTION_ITEMS_PER_PAGE and totalNumAuctions <= 0
			local done = pageIsLast or cappedDone or repeatedPage
			if TSMDBG then TSMDBG.Log("Query", "_BrowseIsDone classic page=%d num=%d total=%d maxTotal=%d pageIsLast=%s cappedDone=%s repeatedPage=%s done=%s",
				self._page, numAuctions, totalNumAuctions, self._maxTotalSeen, tostring(pageIsLast), tostring(cappedDone), tostring(repeatedPage), tostring(done)) end
			-- Per-page chat line, FullScan slow-scan style. Print once per page
			-- (guarded by _lastPagePrinted because _BrowseIsDone can be called
			-- multiple times per AUCTION_ITEM_LIST_UPDATE during validation).
			if self._traceTag and self._page ~= self._lastPagePrinted and self._tPageQuerySent then
				self._lastPagePrinted = self._page
				local serverTime = GetTime() - self._tPageQuerySent
				local maxPages = self._maxTotalSeen > 0
					and math.ceil(self._maxTotalSeen / NUM_AUCTION_ITEMS_PER_PAGE)
					or 0
				print(string.format(
					"|cff66ccff[DE %s]|r page %d/%s: server %.2fs  batch=%d  total=%d",
					tostring(self._traceTag),
					self._page + 1,
					maxPages > 0 and tostring(maxPages) or "?",
					serverTime, numAuctions, self._maxTotalSeen))
			end
			self._lastPageFingerprint = pageFingerprint
			if done and self._traceTag and self._tStart then
				local elapsed = GetTime() - self._tStart
				local pageAvg = self._pageCount and self._pageCount > 0 and elapsed / self._pageCount or 0
				print(string.format("|cFFFFA500TSM DE Scan:|r query=%s DONE pages=%d lastPageItems=%d total=%d (cap=%s repeat=%s) elapsed=%.2fs avg/page=%.2fs",
					tostring(self._traceTag), self._pageCount or 0, numAuctions, self._maxTotalSeen,
					cappedDone and "yes" or "no", repeatedPage and "yes" or "no", elapsed, pageAvg))
			end
			return done
		end
	end
end

function AuctionQuery:_BrowseIsPageValid()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		return true
	end
	if self._specifiedPage then
		return self:_BrowseIsDone()
	else
		return true
	end
end

function AuctionQuery:_BrowseRequestMore(isRetry)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		return AuctionHouseWrapper.RequestMoreBrowseResults()
	else
		if self._specifiedPage then
			return self:_SendWowQuery()
		end
		if not isRetry then
			self._page = self._page + 1
		end
		return self:_SendWowQuery()
	end
end

function AuctionQuery:_OnSubRowRemoved(row)
	local baseItemString = row:GetBaseItemString()
	assert(row == self._browseResults[baseItemString])
	if row:GetNumSubRows() == 0 then
		self._browseResults[baseItemString] = nil
		row:Release()
		row = nil
	end
	if self._callback then
		self:_callback(row)
	end
end

---@private
---@return AuctionRow
function AuctionQuery:_GetBrowseResults(baseItemString)
	return self._browseResults[baseItemString]
end

---Clears all subRows from existing browse results (called once at start of new browse session).
---@private
function AuctionQuery:_ClearStaleSubRows()
	if self._staleSubRowsCleared then
		return
	end
	self._staleSubRowsCleared = true

	local numRows = 0
	local numSubRows = 0
	for _, row in pairs(self._browseResults) do
		numRows = numRows + 1
		-- Wipe all subRows from this row
		for i = #row._subRows, 1, -1 do
			row._subRows[i]:Release()
			row._subRows[i] = nil
			numSubRows = numSubRows + 1
		end
		row._minBrowseId = nil
	end
	if TSMDBG then
		TSMDBG.Log("Query", "_ClearStaleSubRows: cleared %d subRows from %d rows", numSubRows, numRows)
	end
	if self._incrementalFilter then
		for baseItemString in pairs(self._browseResults) do
			self._dirtyRows[baseItemString] = true
		end
	end
end

---@private
function AuctionQuery:_MarkDirtyRow(baseItemString)
	if self._incrementalFilter then
		self._dirtyRows[baseItemString] = true
	end
end

---@private
function AuctionQuery:_ProcessBrowseResult(baseItemString, ...)
	-- Clear stale subRows once at the start of new browse session
	if not self._staleSubRowsCleared then
		self:_ClearStaleSubRows()
	end

	if self._browseResults[baseItemString] then
		self._browseResults[baseItemString]:Merge(...)
	else
		self._browseResults[baseItemString] = AuctionRow.Get(self, ...)
	end
end

---@private
function AuctionQuery:_FilterBrowseResults()
	TSMDBG.Log("Query", "_FilterBrowseResults START")
	local numRemoved = 0
	local numTotal = 0
	local isClassic = not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE)
	local useIncremental = isClassic and self._incrementalFilter
	for baseItemString, row in pairs(self._browseResults) do
		if useIncremental and not self._dirtyRows[baseItemString] then
			-- Row untouched this page; subRows unchanged since last filter pass.
		else
		numTotal = numTotal + 1

		local isFiltered = false
		local filterSubRows = false

		if isClassic then
			-- 3.3.5: filter by query text in ProcessBrowseResultClassic, not in row-level subrow filtering.
			if row:GetNumSubRows() == 0 then
				isFiltered = true
			elseif self:_HasSubRowFilters(true) then
				-- Apply per-subRow filters (price, customFilters from VendorSearch/etc).
				-- Without this, custom filters set via AddCustomFilter are silently skipped on classic.
				local ok2, errOrRes2 = pcall(function() return row:FilterSubRows(self) end)
				if ok2 then filterSubRows = errOrRes2 else TSMDBG.LogErr("Query:FilterSubRows", errOrRes2) end
			end
		else
			local ok, errOrRes = pcall(function() return row:IsFiltered(self) end)
			if ok then isFiltered = errOrRes else TSMDBG.LogErr("Query:IsFiltered", errOrRes) end
			local ok2, errOrRes2 = pcall(function() return row:FilterSubRows(self) end)
			if ok2 then filterSubRows = errOrRes2 else TSMDBG.LogErr("Query:FilterSubRows", errOrRes2) end
		end

		if numTotal <= 3 then
			TSMDBG.Log("Query", "_FilterBrowseResults item=%s isFiltered=%s filterSubRows=%s subRows=%d",
				tostring(baseItemString), tostring(isFiltered), tostring(filterSubRows), #row._subRows)
		end
		if isFiltered or filterSubRows then
			self._browseResults[baseItemString]:Release()
			self._browseResults[baseItemString] = nil
			numRemoved = numRemoved + 1
		end
		end
	end
	if useIncremental then
		wipe(self._dirtyRows)
	end
	TSMDBG.Log("Query", "_FilterBrowseResults total=%d removed=%d remaining=%d", numTotal, numRemoved, numTotal - numRemoved)
	return numRemoved
end

---@private
function AuctionQuery:_PopulateBrowseData(missingItemIds)
	local success = true
	local numRemoved = 0
	for baseItemString, row in pairs(self._browseResults) do
		local ok, hasInfo, giveUp = pcall(row.PopulateBrowseData, row, missingItemIds)
		if not ok then
			TSMDBG.LogErr("Query:_PopulateBrowseData row=" .. tostring(baseItemString), hasInfo)
			-- На ошибке: удаляем строку чтобы не блокировать остальные
			self._browseResults[baseItemString]:Release()
			self._browseResults[baseItemString] = nil
			numRemoved = numRemoved + 1
		elseif not hasInfo and giveUp then
			-- Remove this row completely
			self._browseResults[baseItemString]:Release()
			self._browseResults[baseItemString] = nil
			numRemoved = numRemoved + 1
		elseif not hasInfo then
			success = false
			-- Keep going so we issue requests for all pending rows
		end
	end
	return success, numRemoved
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemIteratorHelper(items, index)
	while true do
		local itemString, itemType = next(items, index)
		if not itemString then
			return
		elseif itemType == ITEM_SPECIFIC then
			return itemString
		end
		index = itemString
	end
end
