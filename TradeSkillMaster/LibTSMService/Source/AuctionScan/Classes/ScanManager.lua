-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local AuctionScanManager = LibTSMService:DefineClassType("AuctionScanManager")
local FindThread = LibTSMService:Include("AuctionScan.FindThread")
local QueryUtil = LibTSMService:Include("AuctionScan.QueryUtil")
local AuctionQuery = LibTSMService:IncludeClassType("AuctionQuery")
local Scanner = LibTSMService:Include("AuctionScan.Scanner")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local AuctionHouseWrapper = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local private = {
	objectPool = ObjectPool.New("AUCTION_SCAN_MANAGER", AuctionScanManager, 1),
}
-- Arbitrary estimate that finishing the browse request is worth 10% of the query's progress
local BROWSE_PROGRESS = 0.1
local ACTION_SCRIPTS = { OnProgressUpdate = true, OnQueryDone = true, OnCurrentSearchChanged = true, OnNumItemsChanged = true }



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets an auction scan manager.
---@return AuctionScanManager
function AuctionScanManager.__static.Get()
	return private.objectPool:Get()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function AuctionScanManager:__init()
	self._manager = nil
	self._scriptAction = {}
	self._resolveSellers = nil
	self._ignoreItemLevel = nil
	self._queries = {}
	self._queriesScanned = 0
	self._queryDidBrowse = false
	self._onProgressUpdateHandler = nil
	self._onQueryDoneHandler = nil
	self._resultsUpdateCallbacks = {}
	self._nextSearchItemFunction = nil
	self._currentSearchChangedCallback = nil
	self._findResult = {}
	self._cancelled = false
	self._shouldPause = false
	self._paused = false
	self._scanQuery = nil
	self._findQuery = nil
	self._numItems = nil
	self._queryCallback = function(query, searchRow)
		for func in pairs(self._resultsUpdateCallbacks) do
			func(self, query, searchRow)
		end
	end
end

function AuctionScanManager:_Release()
	self._manager = nil
	wipe(self._scriptAction)
	self._resolveSellers = nil
	self._ignoreItemLevel = nil
	for _, query in ipairs(self._queries) do
		query:Release()
	end
	wipe(self._queries)
	self._queriesScanned = 0
	self._queryDidBrowse = false
	self._onProgressUpdateHandler = nil
	self._onQueryDoneHandler = nil
	wipe(self._resultsUpdateCallbacks)
	self._nextSearchItemFunction = nil
	self._currentSearchChangedCallback = nil
	self._cancelled = false
	self._shouldPause = false
	self._paused = false
	wipe(self._findResult)
	self._scanQuery = nil
	if self._findQuery then
		self._findQuery:Release()
		self._findQuery = nil
	end
	self._numItems = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Releases the scan manager.
function AuctionScanManager:Release()
	self:_Release()
	private.objectPool:Recycle(self)
end

---Sets whether or not to resolve seller names.
---@param resolveSellers boolean
---@return AuctionScanManager
function AuctionScanManager:SetResolveSellers(resolveSellers)
	self._resolveSellers = resolveSellers
	return self
end

---Sets whether or not to ignore item level.
---@param ignoreItemLevel boolean
---@return AuctionScanManager
function AuctionScanManager:SetIgnoreItemLevel(ignoreItemLevel)
	self._ignoreItemLevel = ignoreItemLevel
	return self
end

---Sets the UI manager to send actions to.
---@param manager UIManager The UI manager
---@return AuctionScanManager
function AuctionScanManager:SetUIManager(manager)
	assert(not self._manager and manager)
	self._manager = manager
	return self
end

---Sets the UI manager action to send for one of the scripts.
---@param script "OnProgressUpdate"|"OnQueryDone"|"OnCurrentSearchChanged"|"OnNumItemsChanged" The script to send the action for
---@param action string The action to send
---@return AuctionScanManager
function AuctionScanManager:SetAction(script, action)
	assert(ACTION_SCRIPTS[script])
	assert(not self._scriptAction[script])
	self._scriptAction[script] = action
	return self
end

---Registers a script handler.
---@param script "OnProgressUpdate"|"OnQueryDone"|"OnCurrentSearchChanged" The script to register for
---@param handler fun(manager: AuctionScanManager, ...: any) The function called with the applicable arguments
---@return AuctionScanManager
function AuctionScanManager:SetScript(script, handler)
	if script == "OnProgressUpdate" then
		self._onProgressUpdateHandler = handler
	elseif script == "OnQueryDone" then
		self._onQueryDoneHandler = handler
	elseif script == "OnCurrentSearchChanged" then
		self._currentSearchChangedCallback = handler
	else
		error("Unknown AuctionScanManager script: "..tostring(script))
	end
	return self
end

---Adds a callback when results are updated.
---@param func fun(manager: AuctionScanManager, query: AuctionQuery, row: AuctionRow) The callback function
function AuctionScanManager:AddResultsUpdateCallback(func)
	self._resultsUpdateCallbacks[func] = true
end

---Removes a callback which was previously registered.
---@param func function
function AuctionScanManager:RemoveResultsUpdateCallback(func)
	self._resultsUpdateCallbacks[func] = nil
end

---Sets the function to use to get the next item to be searched.
---@param func fun(): string Function which returns the base item string of the next item
function AuctionScanManager:SetNextSearchItemFunction(func)
	self._nextSearchItemFunction = func
end

---Gets the number of queries.
---@return number
function AuctionScanManager:GetNumQueries()
	return #self._queries
end

---Iterates over the queries registerd with the scan manager.
---@param offset? number The starting offset
---@return fun(): number, AuctionQuery @Iterator with fields: `index`, `query`
function AuctionScanManager:QueryIterator(offset)
	return private.QueryIteratorHelper, self._queries, offset or 0
end

---Creates a new query.
---@return AuctionQuery
function AuctionScanManager:NewQuery()
	local query = AuctionQuery.Get()
	self:_AddQuery(query)
	return query
end

---Adds queries which are generated from a list of items.
---@param itemList string[] The list of items to generate and add queries for
function AuctionScanManager:AddItemListQueriesThreaded(itemList)
	assert(Threading.IsThreadContext())
	-- remove duplicates
	local usedItems = TempTable.Acquire()
	for i = #itemList, 1, -1 do
		local itemString = itemList[i]
		if usedItems[itemString] then
			tremove(itemList, i)
		end
		usedItems[itemString] = true
	end
	TempTable.Release(usedItems)
	self._numItems = #itemList
	self:_SendActionScript("OnNumItemsChanged")
	QueryUtil.GenerateThreaded(itemList, self:__closure("_AddQuery"))
end

---Scans for all the added queries and returns if they were all successful.
---@return boolean
function AuctionScanManager:ScanQueriesThreaded()
	assert(Threading.IsThreadContext())
	self._queriesScanned = 0
	self._cancelled = false
	AuctionHouseWrapper.GetAndResetTotalHookedTime()
	self:_NotifyProgressUpdate()
	self:_Pause()

	-- Loop through each filter to perform
	local allSuccess = true
	while self._queriesScanned < #self._queries do
		local query = self._queries[self._queriesScanned + 1]
		-- Run the browse query
		local querySuccess, numNewResults = self:_ProcessQuery(query)
		if not querySuccess then
			allSuccess = false
			break
		end
		self._queriesScanned = self._queriesScanned + 1
		self:_NotifyProgressUpdate()
		self:_SendActionScript("OnQueryDone")
		if self._onQueryDoneHandler then
			self:_onQueryDoneHandler(query, numNewResults)
		end
		self:_Pause()
	end

	if allSuccess then
		local hookedTime, topAddon, topTime = AuctionHouseWrapper.GetAndResetTotalHookedTime()
		if hookedTime > 1 and topAddon ~= "Blizzard_AuctionHouseUI" then
			Log.Warn("Scan was slowed down by %s seconds by other AH addons (%s seconds by %s).", Math.Round(hookedTime, 0.1), Math.Round(topTime, 0.1), topAddon)
		end
	end
	return allSuccess
end

---Sleeps while checking for the scan being paused.
---@param seconds number The time to sleep for in seconds
function AuctionScanManager:SleepThreaded(seconds)
	while seconds > 0 do
		local stepSeconds = min(seconds, 0.5)
		Threading.Sleep(stepSeconds)
		seconds = seconds - stepSeconds
		self:_Pause()
	end
end

---Finds the specified auction
---@param auction AuctionSubRow The sub row to find
---@param callback fun(...: any) The result callback
---@param noSeller boolean Ignore seller names
function AuctionScanManager:FindAuction(auction, callback, noSeller)
	FindThread.StartFindAuction(self, auction, callback, noSeller)
end

---Checks if an auciton can be bid on.
---@param subRow AuctionSubRow
---@return boolean
function AuctionScanManager:CanBid(subRow)
	if not subRow:IsSubRow() then
		return false
	end
	local _, _, _, isHighBidder = subRow:GetBidInfo()
	local displayedBid = subRow:GetDisplayedBids()
	local buyout = subRow:GetBuyouts()
	if isHighBidder then
		return false
	elseif displayedBid == buyout then
		return false
	elseif ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and subRow:IsCommodity() then
		return false
	elseif Currency.GetMoney() < subRow:GetRequiredBid() then
		return false
	end
	return true
end

---Checks if an auction can be bought.
---@param subRow AuctionSubRow The auciton sub row to check
---@return boolean
function AuctionScanManager:CanBuy(subRow)
	if not subRow:IsSubRow() then
		return false
	end
	local buyout, itemBuyout = subRow:GetBuyouts()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		buyout = itemBuyout
	end
	local itemString = subRow:GetItemString()
	if buyout == 0 or Currency.GetMoney() < buyout then
		return false
	elseif ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and subRow:IsCommodity() then
		-- Make sure it's the cheapest
		local isCheapest = false
		for _, query in self:QueryIterator() do
			isCheapest = isCheapest or subRow == query:GetCheapestSubRow(itemString)
		end
		if not isCheapest then
			return false
		end
	end
	return true
end

---Prepares to bid or buy on an auction.
---@param index number The index of the auction
---@param subRow AuctionSubRow The sub row for the auction
---@param noSeller boolean Whether or not to ignore the seller name
---@param quantity number The quantity to prepare to bid or buy
---@param itemBuyout number The per-item buyout
---@return boolean
---@return Future?
function AuctionScanManager:PrepareForBidOrBuyout(index, subRow, noSeller, quantity, itemBuyout)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local itemString = subRow:GetItemString()
		if ItemInfo.IsCommodity(itemString) then
			local future = AuctionHouseWrapper.StartCommoditiesPurchase(ItemString.ToId(itemString), quantity, itemBuyout)
			if not future then
				return false
			end
			return true, future
		else
			return true
		end
	else
		return subRow:EqualsIndex(index, noSeller)
	end
end

---Places a bid or buyout for an auction.
---@param index number The index of the auction
---@param bidBuyout number The amount to bid or buy for
---@param subRow AuctionSubRow The auction sub row
---@param quantity number The quantity to bid or buy
---@return Future?
function AuctionScanManager:PlaceBidOrBuyout(index, bidBuyout, subRow, quantity)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local itemString = subRow:GetItemString()
		local future = nil
		if ItemInfo.IsCommodity(itemString) then
			local itemId = ItemString.ToId(itemString)
			future = AuctionHouseWrapper.ConfirmCommoditiesPurchase(itemId, quantity)
		else
			local _, auctionId = subRow:GetListingInfo()
			future = AuctionHouseWrapper.PlaceBid(auctionId, bidBuyout)
			quantity = 1
		end
		return future
	else
		return AuctionHouseWrapper.PlaceBid(index, bidBuyout)
	end
end

---Gets the progress of the scan.
---@return number progress
---@return boolean? paused
function AuctionScanManager:GetProgress()
	local numQueries = self:GetNumQueries()
	if self._queriesScanned == numQueries then
		return 1, self._paused
	end
	local currentQuery = self._queries[self._queriesScanned + 1]
	local searchProgress = nil
	if self._queryDidBrowse and ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		searchProgress = currentQuery:GetSearchProgress() * (1 - BROWSE_PROGRESS) + BROWSE_PROGRESS
	elseif self._queryDidBrowse then
		-- 3.3.5: на классике GetSearchProgress = browse-page progress (см. Query.GetSearchProgress)
		searchProgress = currentQuery:GetSearchProgress()
	else
		searchProgress = 0
	end
	local queryStep = 1 / numQueries
	local progress = min((self._queriesScanned + searchProgress) * queryStep, 1)
	return progress, self._paused
end

---Cancels the scan.
function AuctionScanManager:Cancel()
	self._cancelled = true
	if self._scanQuery then
		self._scanQuery:CancelBrowseOrSearch()
		self._scanQuery = nil
	end
end

---Sets whether or not the scan is paused.
---@param paused boolean
function AuctionScanManager:SetPaused(paused)
	self._shouldPause = paused
	if self._scanQuery then
		self._scanQuery:CancelBrowseOrSearch()
		self._scanQuery = nil
	end
end

---Gets the number of items being scanned for.
---@return number
function AuctionScanManager:GetNumItems()
	return self._numItems
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@private
function AuctionScanManager:_FindAuctionThreaded(findSubRow, noSeller)
	assert(Threading.IsThreadContext())
	wipe(self._findResult)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		return self:_FindAuctionThreadedRetail(findSubRow)
	else
		return self:_FindAuctionThreadedClassic(findSubRow, noSeller)
	end
end

function AuctionScanManager.__private:_SendActionScript(script)
	assert(ACTION_SCRIPTS[script])
	local action = self._scriptAction[script]
	if not self._manager or not action then
		return
	end
	self._manager:ProcessAction(action)
end

function AuctionScanManager.__private:_AddQuery(query)
	query:SetResolveSellers(self._resolveSellers)
	query:SetCallback(self._queryCallback)
	tinsert(self._queries, query)
end

function AuctionScanManager.__private:_Pause()
	if not self._shouldPause then
		return
	end
	self._paused = true
	self:_NotifyProgressUpdate()
	self:_SendActionScript("OnCurrentSearchChanged")
	if self._currentSearchChangedCallback then
		self:_currentSearchChangedCallback()
	end
	while self._shouldPause do
		Threading.Yield(true)
	end
	self._paused = false
	self:_NotifyProgressUpdate()
	self:_SendActionScript("OnCurrentSearchChanged")
	if self._currentSearchChangedCallback then
		self:_currentSearchChangedCallback()
	end
end

function AuctionScanManager.__private:_NotifyProgressUpdate()
	self:_SendActionScript("OnProgressUpdate")
	if self._onProgressUpdateHandler then
		self:_onProgressUpdateHandler()
	end
end

-- 3.3.5: один browse-future длится через все N страниц, и _NotifyProgressUpdate
-- вызывается только в конце. Тиковый фрейм шлёт OnProgressUpdate каждые 0.2s
-- пока есть активный _scanQuery — UI прогресс-бар обновляется в реальном времени.
local _progressTickFrame = CreateFrame("Frame", "TSMScanProgressTicker")
local _progressTickAccum = 0
local _progressTickManagers = setmetatable({}, { __mode = "k" })
_progressTickFrame:SetScript("OnUpdate", function(_, dt)
	_progressTickAccum = _progressTickAccum + dt
	if _progressTickAccum < 0.2 then return end
	_progressTickAccum = 0
	for mgr in pairs(_progressTickManagers) do
		if mgr._scanQuery and not mgr._paused then
			pcall(mgr._NotifyProgressUpdate, mgr)
		end
	end
end)

function AuctionScanManager.__private:_ProcessQuery(query)
	local prevMaxBrowseId = 0
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		for _, row in query:BrowseResultsIterator() do
			prevMaxBrowseId = max(prevMaxBrowseId, row:GetMinBrowseId())
		end
	end

	-- run the browse query
	self._queryDidBrowse = false
	-- 3.3.5: ставим флаг сразу — это даёт прогрессу читать GetSearchProgress (browse pages) пока скан идёт
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		self._queryDidBrowse = true
	end
	while not self:_DoBrowse(query) do
		if self._shouldPause then
			-- this browse failed due to a pause request, so try again after we're resumed
			self:_Pause()
			-- wipe the browse results since we're going to do another search
			query:WipeBrowseResults()
		else
			return false, 0
		end
	end
	self._queryDidBrowse = true
	self:_NotifyProgressUpdate()

	local numNewResults = 0
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		for _, row in query:BrowseResultsIterator() do
			if row:GetMinBrowseId() > prevMaxBrowseId then
				numNewResults = numNewResults + row:GetNumSubRows()
			end
		end
		return true, numNewResults
	end

	local rows = Threading.AcquireSafeTempTable()
	for baseItemString, row in query:BrowseResultsIterator() do
		rows[baseItemString] = row
	end
	while true do
		local baseItemString, row = nil, nil
		if self._nextSearchItemFunction then
			baseItemString = self._nextSearchItemFunction()
			row = baseItemString and rows[baseItemString]
		end
		if not row then
			baseItemString, row = next(rows)
		end
		if not row then
			break
		end
		rows[baseItemString] = nil
		self:_SendActionScript("OnCurrentSearchChanged")
		if self._currentSearchChangedCallback then
			self:_currentSearchChangedCallback(baseItemString)
		end
		-- store all the existing auctionIds so we can see what changed
		local prevAuctionIds = Threading.AcquireSafeTempTable()
		for _, subRow in row:SubRowIterator() do
			local _, auctionId = subRow:GetListingInfo()
			assert(not prevAuctionIds[auctionId])
			prevAuctionIds[auctionId] = true
		end
		-- send the query for this item
		while not self:_DoSearch(query, row) do
			if self._shouldPause then
				-- this search failed due to a pause request, so try again after we're resumed
				self:_Pause()
				-- wipe the search results since we're going to do another search
				row:WipeSearchResults()
			else
				TempTable.Release(prevAuctionIds)
				TempTable.Release(rows)
				return false, numNewResults
			end
		end

		local numSubRows = row:GetNumSubRows()
		for _, subRow in row:SubRowIterator() do
			local _, auctionId = subRow:GetListingInfo()
			if not prevAuctionIds[auctionId] then
				numNewResults = numNewResults + 1
			end
		end
		TempTable.Release(prevAuctionIds)
		if numSubRows == 0 then
			-- Remove this row since there are no search results
			query:RemoveResultRow(row)
		end

		self:_NotifyProgressUpdate()
		self:_Pause()
		Threading.Yield()
	end
	TempTable.Release(rows)
	return true, numNewResults
end

function AuctionScanManager.__private:_DoBrowse(query)
	return self:_DoBrowseSearchHelper(query, query:Browse())
end

function AuctionScanManager.__private:_DoSearch(query, ...)
	return self:_DoBrowseSearchHelper(query, query:Search(...))
end

function AuctionScanManager.__private:_DoBrowseSearchHelper(query, future)
	if not future then
		return false
	end
	self._scanQuery = query
	_progressTickManagers[self] = true
	local result = Threading.WaitForFuture(future)
	_progressTickManagers[self] = nil
	self._scanQuery = nil
	Threading.Yield()
	return result
end

function AuctionScanManager.__private:_FindAuctionThreadedClassic(row, noSeller)
	self._cancelled = false
	-- 3.3.5: ждём CanSendQuery с таймаутом.
	local waitStart = GetTime and GetTime() or 0
	local maxWait = 5
	while not AuctionHouse.CanSendQuery() do
		Threading.Yield(true)
		if (GetTime and GetTime() or 0) - waitStart > maxWait then
			break
		end
	end

	-- Two-pass find (по образцу Auctionator/TSM v2):
	-- pass 1: strict (с seller если он resolved у нас)
	-- pass 2: noSeller=true (если seller на сервере не успел резолвнуться, либо изменился)
	for passNoSeller = 0, 1 do
		local passFlag = passNoSeller == 1 or noSeller
		-- search the current page for the auction first (cheap)
		-- 3.3.5 sniper buyout fix: SKIP the current-page shortcut for the sniper.
		-- The sniper's live Blizzard "list" is its own accumulated, custom-sorted
		-- browse page (SetPage("LAST") / reverse sort), and PlaceAuctionBid("list", i)
		-- against an index into that list is silently dropped by the server on 3.3.5a
		-- (no event, no gold change, 5s timeout) even though the index is valid
		-- client-side. The per-item NAME query below re-populates the native "list"
		-- with a small, default-sorted (SetPage(0)) result set that the server accepts
		-- bids against -- exactly like the Browse tab and the default UI, both of
		-- which buy fine. Browse keeps the fast current-page shortcut (resolveSellers
		-- is true for the classic Browse scan, false for Sniper).
		wipe(self._findResult)
		if self:_FindAuctionOnCurrentPage(row, passFlag) then
			-- 3.3.5 sniper buyout fix (part 5): bid into the EXISTING live "list" with NO
			-- preceding query, exactly like the Browse tab / default UI (both buy fine).
			-- Every attempt that fired a fresh QueryAuctionItems right before
			-- PlaceAuctionBid -- broad accumulate list, clean 6-item name query, or
			-- 50-item name query, with a 0.2s OR a 2s wait -- was silently dropped by the
			-- server (no event, no gold, 5s timeout). The only path that works (Browse)
			-- never re-queries before bidding. The clicked sniper lot is almost always
			-- still on the current live page, so locate it there and bid with no new
			-- query. (Previously gated on self._resolveSellers, i.e. Browse-only; the
			-- per-item-query fallback below still runs only when the lot is not on the
			-- current live page.)
			-- 3.3.5 buyout-drop fix: this is the path the DE / shopping scan actually
			-- hits on Warmane. getAll is rate-limited (~15 min CD), so the scan almost
			-- always runs the slowscan/per-class queries and the clicked lot is found on
			-- the current live page here. If the scan queried recently (still running, or
			-- just finished), the server-side PlaceAuctionBid throttle (~2s after ANY
			-- auction query) is still active, so the subsequent click-bid into this list
			-- is silently dropped (no event, no gold, 5s timeout) -> the intermittent
			-- "находит, а покупается через раз". Wait the throttle out before returning
			-- the index, exactly like the per-item-query fallback below already does.
			-- A settled / completed scan (no recent query) clears both checks instantly,
			-- so the common case keeps returning with no added delay.
			local BID_THROTTLE = 2
			if not AuctionHouse.CanSendQuery() or AuctionHouse.GetTimeSinceLastQuery() < BID_THROTTLE then
				local settleStart = GetTime and GetTime() or 0
				while not AuctionHouse.CanSendQuery() do
					Threading.Yield(true)
					if self._cancelled then
						return nil
					end
					if (GetTime and GetTime() or 0) - settleStart > 3 then
						break
					end
				end
				local remaining = BID_THROTTLE - AuctionHouse.GetTimeSinceLastQuery()
				if remaining > 0 then
					Threading.Sleep(remaining)
				end
			end
			return self._findResult
		end

		-- per-item query, page=0..maxPage
		local page, maxPage = 0, nil
		while true do
			if self._findQuery then
				self._findQuery:Release()
				self._findQuery = nil
			end
			local itemString = row:GetItemString()
			if not itemString then
				return nil
			end
			local nameStr = ItemInfo.GetName(itemString) or row._itemLink and row._itemLink:match("%[(.-)%]") or ""
			-- 3.3.5: NAME-only exact query. Do NOT add SetClass / SetQualityRange /
			-- SetLevelRange here. On 3.3.5 the AH class/subclass filter args are auction
			-- CATEGORY indices (not item class ids), so SetClass makes QueryAuctionItems
			-- return 0 auctions. This fallback runs whenever the lot is no longer on the
			-- visible page (e.g. the page got refreshed after buying the previous lot),
			-- so a broken query here makes the find return nil and the lot "vanishes"
			-- from the results. Exact name + SetItems locates the lot reliably.
			self._findQuery = AuctionQuery.Get():SetStr(nameStr, true)
				:SetItems(itemString)
				:SetResolveSellers(not passFlag)
				:SetPage(page)
			local filterSuccess = self:_DoBrowse(self._findQuery)
			if self._findQuery then
				self._findQuery:Release()
				self._findQuery = nil
			end
			if not filterSuccess then
				break
			end
			wipe(self._findResult)
			if self:_FindAuctionOnCurrentPage(row, passFlag) then
				-- 3.3.5 sniper buyout fix (part 2): the per-item query above just
				-- repopulated the native "list" and the server is still streaming
				-- AUCTION_ITEM_LIST_UPDATE events (CanSendQuery() is still on its
				-- post-query throttle, i.e. canSendQuery=false). Placing PlaceAuctionBid
				-- against the list during this unsettled window is silently dropped by
				-- the server (5s timeout, gold not spent). Wait for the AH to go idle
				-- again (throttle cleared / list settled) before returning the index,
				-- exactly like the Browse tab and default UI where the list has long
				-- settled before the user clicks Buyout.
				local settleStart = GetTime and GetTime() or 0
				while not AuctionHouse.CanSendQuery() do
					Threading.Yield(true)
					if self._cancelled then
						return nil
					end
					if (GetTime and GetTime() or 0) - settleStart > 3 then
						break
					end
				end
				-- 3.3.5 sniper buyout fix (part 3): Warmane throttles PlaceAuctionBid for
				-- a couple seconds after ANY auction query from the player. CanSendQuery()
				-- (the client query throttle) clears FASTER than this server-side bid
				-- throttle, which is why canSendQuery=true above yet the bid is still
				-- silently dropped (no event, no gold change, 5s client timeout). The
				-- sniper is always querying (or just requeried right here), so the bid
				-- always lands inside that window. Browse / default UI work only because
				-- of the human gap (select -> click Buy -> confirm) with no query in
				-- between. The scan is paused during this find (no queries fire while we
				-- sleep), so wait out the server bid-throttle before returning the index.
				Threading.Sleep(2)
				return self._findResult
			elseif self._cancelled then
				return nil
			end
			local numPages = AuctionHouse.GetNumPages()
			maxPage = maxPage or (numPages - 1)
			if page < maxPage then
				page = page + 1
			else
				break
			end
		end
		-- pass 1 ничего не дал — если был с seller-strict и owner не "?", делаем pass 2
		-- Если passFlag (noSeller) уже true — выходим, ничего не нашли
		if passFlag then
			break
		end
		-- Не делаем pass 2 если у нас owner был "?" и так — pass 1 уже игнорил seller
		if row._ownerStr == "?" then
			break
		end
	end
	return nil
end

function AuctionScanManager.__private:_FindAuctionCanBeOnLaterPage(row)
	local pageAuctions = AuctionHouse.GetNumAuctions()
	if pageAuctions == 0 then
		-- There are no auctions on this page, so it cannot be on a later one
		return false
	end
	local _, _, stackSize, _, buyout, seller = AuctionHouse.GetBrowseResult(pageAuctions)

	local itemBuyout = (buyout > 0) and floor(buyout / stackSize) or 0
	local _, rowItemBuyout = row:GetBuyouts()
	if rowItemBuyout > itemBuyout then
		-- Item must be on a later page since it would be sorted after the last auction on this page
		return true
	elseif rowItemBuyout < itemBuyout then
		-- Item cannot be on a later page since it would be sorted before the last auction on this page
		return false
	end

	local rowStackSize = row:GetQuantities()
	if rowStackSize > stackSize then
		-- Item must be on a later page since it would be sorted after the last auction on this page
		return true
	elseif rowStackSize < stackSize then
		-- Item cannot be on a later page since it would be sorted before the last auction on this page
		return false
	end

	seller = seller or "?"
	local rowSeller = row:GetOwnerInfo()
	if rowSeller > seller then
		-- Item must be on a later page since it would be sorted after the last auction on this page
		return true
	elseif rowSeller < seller then
		-- Item cannot be on a later page since it would be sorted before the last auction on this page
		return false
	end

	-- All the things we are sorting on are the same, so the auction could be on a later page
	return true
end

function AuctionScanManager.__private:_FindAuctionOnCurrentPage(subRow, noSeller)
	local found = false
	local total = AuctionHouse.GetNumAuctions() or 0
	for i = 1, total do
		if subRow:EqualsIndex(i, noSeller) then
			tinsert(self._findResult, i)
			found = true
		end
	end
	return found
end

function AuctionScanManager.__private:_FindAuctionThreadedRetail(findSubRow)
	assert(findSubRow:IsSubRow())
	self._cancelled = false

	local row = findSubRow:GetResultRow()
	local findHash, findHashNoSeller = findSubRow:GetHashes()

	if not self:_DoSearch(row:GetQuery(), row, false) then
		return nil
	end
	local result = nil
	-- first try to find a subRow with a full matching hash
	for _, subRow in row:SubRowIterator() do
		local quantity, numAuctions = subRow:GetQuantities()
		local hash = subRow:GetHashes()
		if hash == findHash then
			result = (result or 0) + quantity * numAuctions
		end
	end
	if result then
		return result
	end
	-- next try to find the first subRow with a matching no-seller hash
	local firstHash = nil
	for _, subRow in row:SubRowIterator() do
		local quantity, numAuctions = subRow:GetQuantities()
		local hash, hashNoSeller = subRow:GetHashes()
		if (not firstHash or hash == firstHash) and hashNoSeller == findHashNoSeller then
			firstHash = hash
			result = (result or 0) + quantity * numAuctions
		end
	end
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueryIteratorHelper(tbl, index)
	index = index + 1
	if index > #tbl then
		return
	end
	return index, tbl[index]
end
