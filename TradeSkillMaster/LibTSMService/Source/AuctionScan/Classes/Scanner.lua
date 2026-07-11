-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:Init("AuctionScan.Scanner")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local FSM = LibTSMService:From("LibTSMUtil"):Include("FSM")
local Future = LibTSMService:From("LibTSMUtil"):IncludeClassType("Future")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local private = {
	resolveSellers = nil,
	pendingFuture = nil,
	query = nil, ---@type AuctionQuery
	callback = nil,
	browseId = 1,
	browseIsNoScan = false,
	browseIndex = 1,
	browsePendingIndexes = {},
	searchRow = nil,
	useCachedData = nil,
	retryCount = 0,
	browseEmptyRetryCount = 0,
	requestFuture = Future.New("AUCTION_SCANNER_FUTURE"),
	requestResult = nil,
	fsm = nil,
	retryTimer = nil,
	doneTimer = nil,
	updateTimer = nil,
	missingItemIds = {},
	-- 3.3.5 diagnostics: per-scan counters for the classic browse processing
	-- pipeline (printed for traced queries, e.g. DE scan)
	classicStats = { seen = 0, noInfo = 0, noLink = 0, badLink = 0, nameSkip = 0, earlyReject = 0, added = 0 },
}
local BROWSE_MISSING_INFO_RETRY_DELAY = 0.5
local BROWSE_EMPTY_RETRY_DELAY = 0.25
local BROWSE_EMPTY_RETRY_MAX = 12
local SEARCH_NOT_READY_RETRY_DELAY = 0.1
local SEARCH_MISSING_ITEM_INFO_RETRY_DELAY = 0.1
local SEARCH_AH_NOT_READY_RETRY_DELAY = 0.5
local SEARCH_MISSING_INFO_RETRY_DELAY = 0.5
local FUTURE_FAILED_RETRY_DELAY = 0.1
local SORT_RETRY_DELAY = 0.5
-- 3.3.5 perf: бюджет времени (мс) на обработку browse-страницы за один кадр.
-- Без него цикл ограничивался только числом pending-предметов: если данные
-- всех лотов были в кэше, страница целиком (сотни/тысячи лотов на ядрах с
-- крупными страницами / GetAll) обрабатывалась за один кадр — каждый лот
-- это дорогие C-вызовы GetAuctionItemInfo/GetAuctionItemLink. Это давало
-- многосекундные фризы на каждом поиске.
local BROWSE_PROCESS_TIME_BUDGET_MS = 25



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	private.retryTimer = DelayTimer.New("AUCTION_SCANNER_RETRY", private.RetryHandler)
	private.doneTimer = DelayTimer.New("AUCTION_SCANNER_DONE", private.RequestDoneHandler)
	private.updateTimer = DelayTimer.New("AUCTION_SCANNER_RETRY", function()
		private.fsm:SetLoggingEnabled(false)
		private.fsm:ProcessEvent("EV_BROWSE_RESULTS_UPDATED")
		private.fsm:SetLoggingEnabled(true)
	end)
	private.requestFuture:SetScript("OnCleanup", function()
		private.doneTimer:Cancel()
		private.fsm:ProcessEvent("EV_CANCEL")
	end)

	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		Event.Register("COMMODITY_SEARCH_RESULTS_UPDATED", function()
			private.fsm:ProcessEvent("EV_SEARCH_RESULTS_UPDATED")
		end)
		Event.Register("ITEM_SEARCH_RESULTS_UPDATED", function()
			private.fsm:ProcessEvent("EV_SEARCH_RESULTS_UPDATED")
		end)
		Event.Register("ITEM_KEY_ITEM_INFO_RECEIVED", function(_, itemId)
			private.fsm:SetLoggingEnabled(false)
			private.fsm:ProcessEvent("EV_ITEM_KEY_INFO_RECEIVED", itemId)
			private.fsm:SetLoggingEnabled(true)
		end)
	else
		Event.Register("AUCTION_ITEM_LIST_UPDATE", function()
			local numAuctions, totalAuctions = AuctionHouse.GetNumAuctions()
			TSMDBG.Log("Scanner", "AUCTION_ITEM_LIST_UPDATE numAuctions=%d totalAuctions=%d", numAuctions or 0, totalAuctions or 0)
			private.updateTimer:RunForFrames(0)
		end)
	end

	private.fsm = FSM.New("AUCTION_SCANNER_FSM")
		:AddState(FSM.NewState("ST_INIT")
			:SetOnEnter(function()
				private.query = nil
				private.resolveSellers = nil
				private.useCachedData = nil
				private.searchRow = nil
				private.callback = nil
				private.retryCount = 0
				private.browseEmptyRetryCount = 0
				private.retryTimer:Cancel()
				if private.pendingFuture then
					private.pendingFuture:Cancel()
					private.pendingFuture = nil
				end
			end)
			:AddTransition("ST_BROWSE_SORT")
			:AddTransition("ST_BROWSE_CHECKING")
			:AddTransition("ST_SEARCH_GET_KEY")
			:AddEvent("EV_START_BROWSE", function(_, query, resolveSellers, callback)
				assert(not private.query)
				-- Debug output disabled for EV_START_BROWSE to reduce chat spam
				-- print(string.format("TSM:EV_START_BROWSE query._str=%s", tostring(query._str)))
				private.query = query
				private.resolveSellers = resolveSellers
				private.browseId = private.browseId + 1
				private.browseIsNoScan = false
				private.callback = callback
				return "ST_BROWSE_SORT"
			end)
			:AddEvent("EV_START_BROWSE_NO_SCAN", function(_, query, itemKeys, callback)
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				assert(not private.query)
				private.query = query
				private.browseId = private.browseId + 1
				private.browseIsNoScan = true
				private.callback = callback
				for _, itemKey in ipairs(itemKeys) do
					local baseItemString = ItemString.GetBaseFromItemKey(itemKey)
					private.query:_ProcessBrowseResult(baseItemString, itemKey)
				end
				return "ST_BROWSE_CHECKING"
			end)
			:AddEvent("EV_START_SEARCH", function(_, query, resolveSellers, useCachedData, searchRow, callback)
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				assert(not private.query)
				private.query = query
				private.resolveSellers = resolveSellers
				private.useCachedData = useCachedData
				private.searchRow = searchRow
				private.callback = callback
				private.searchRow:SearchReset()
				return "ST_SEARCH_GET_KEY"
			end)
		)
		:AddState(FSM.NewState("ST_BROWSE_SORT")
			:SetOnEnter(function()
				if not private.query:_SetSort() then
					private.retryTimer:RunForTime(SORT_RETRY_DELAY)
					return
				end
				return "ST_BROWSE_SEND"
			end)
			:AddTransition("ST_BROWSE_SORT")
			:AddTransition("ST_BROWSE_SEND")
			:AddTransition("ST_CANCELING")
			:AddEventTransition("EV_RETRY", "ST_BROWSE_SORT")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_BROWSE_SEND")
			:SetOnEnter(function()
				private.HandleAuctionHouseWrapperResult(private.query:_SendWowQuery())
			end)
			:AddTransition("ST_BROWSE_SEND")
			:AddTransition("ST_BROWSE_CHECKING")
			:AddTransition("ST_CANCELING")
			:AddEvent("EV_FUTURE_SUCCESS", function()
				if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
					for _, result in ipairs(AuctionHouse.GetBrowseResults()) do
						local baseItemString = ItemString.GetBaseFromItemKey(result.itemKey)
						private.query:_ProcessBrowseResult(baseItemString, result.itemKey, result.minPrice, result.totalQuantity)
					end
				else
					private.browseIndex = 1
					wipe(private.browsePendingIndexes)
				end
				return "ST_BROWSE_CHECKING"
			end)
			:AddEventTransition("EV_RETRY", "ST_BROWSE_SEND")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_BROWSE_CHECKING")
			:SetOnEnter(function()
				-- Debug output disabled for ST_BROWSE_CHECKING to reduce chat spam
				-- print(string.format("TSM:ST_BROWSE_CHECKING browseIndex=%d numAuctions=%d", private.browseIndex, AuctionHouse.GetNumAuctions() or 0))
				if not private.query:_BrowseIsPageValid() then
					-- This page isn't valid, so go to the next page
					return "ST_BROWSE_REQUEST_MORE"
				elseif not private.CheckBrowseResults() then
					-- Results aren't valid yet, so check again
					private.retryTimer:RunForTime(BROWSE_MISSING_INFO_RETRY_DELAY)
					return
				end
				-- We're done with this set of browse results
				if private.callback then
					private.callback(private.query)
				end
				if private.browseIsNoScan or private.query:_BrowseIsDone() then
					-- We're done
					return "ST_BROWSE_DONE"
				else
					-- move on to the next page
					return "ST_BROWSE_REQUEST_MORE"
				end
			end)
			:AddTransition("ST_BROWSE_CHECKING")
			:AddTransition("ST_BROWSE_DONE")
			:AddTransition("ST_BROWSE_REQUEST_MORE")
			:AddTransition("ST_CANCELING")
			:AddEventTransition("EV_RETRY", "ST_BROWSE_CHECKING")
			:AddEventTransition("EV_BROWSE_RESULTS_UPDATED", "ST_BROWSE_CHECKING")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
			:AddEvent("EV_ITEM_KEY_INFO_RECEIVED", function(_, itemId)
				if not next(private.missingItemIds) then
					return
				end
				private.missingItemIds[itemId] = nil
				if not next(private.missingItemIds) then
					private.retryTimer:Cancel()
					return "ST_BROWSE_CHECKING"
				end
			end)
		)
		:AddState(FSM.NewState("ST_BROWSE_REQUEST_MORE")
			:SetOnEnter(function(_, isRetry)
				if private.query:_BrowseIsDone(isRetry) then
					return "ST_BROWSE_CHECKING"
				else
					private.HandleAuctionHouseWrapperResult(private.query:_BrowseRequestMore(isRetry))
				end
			end)
			:AddTransition("ST_BROWSE_REQUEST_MORE")
			:AddTransition("ST_BROWSE_CHECKING")
			:AddTransition("ST_CANCELING")
			:AddEvent("EV_FUTURE_SUCCESS", function(_, ...)
				if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
					local newResults = ...
					for _, result in ipairs(newResults) do
						local baseItemString = ItemString.GetBaseFromItemKey(result.itemKey)
						private.query:_ProcessBrowseResult(baseItemString, result.itemKey, result.minPrice, result.totalQuantity)
					end
				else
					private.browseIndex = 1
					wipe(private.browsePendingIndexes)
				end
				return "ST_BROWSE_CHECKING"
			end)
			:AddEvent("EV_RETRY", function()
				return "ST_BROWSE_REQUEST_MORE", true
			end)
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_BROWSE_DONE")
			:SetOnEnter(function()
				private.HandleRequestDone(true)
				return "ST_INIT"
			end)
			:AddTransition("ST_INIT")
		)
		:AddState(FSM.NewState("ST_SEARCH_GET_KEY")
			:SetOnEnter(function()
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				if not private.searchRow:SearchIsReady() then
					private.retryTimer:RunForTime(SEARCH_NOT_READY_RETRY_DELAY)
					return
				end
				return "ST_SEARCH_SEND"
			end)
			:AddTransition("ST_SEARCH_GET_KEY")
			:AddTransition("ST_SEARCH_SEND")
			:AddTransition("ST_CANCELING")
			:AddEventTransition("EV_FUTURE_SUCCESS", "ST_SEARCH_SEND")
			:AddEventTransition("EV_RETRY", "ST_SEARCH_GET_KEY")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_SEARCH_SEND")
			:SetOnEnter(function()
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				if not DefaultUI.IsAuctionHouseVisible() then
					return "ST_CANCELING"
				end
				if private.useCachedData and private.searchRow:HasCachedSearchData() then
					return "ST_SEARCH_REQUEST_MORE"
				end
				local future, delayTime = private.searchRow:SearchSend()
				if future then
					private.HandleAuctionHouseWrapperResult(future)
				else
					if not delayTime then
						Log.Err("Failed to send search query - retrying")
						delayTime = SEARCH_AH_NOT_READY_RETRY_DELAY
					end
					-- Try again after a delay
					private.retryTimer:RunForTime(delayTime)
				end
			end)
			:AddTransition("ST_SEARCH_SEND")
			:AddTransition("ST_SEARCH_REQUEST_MORE")
			:AddTransition("ST_CANCELING")
			:AddEventTransition("EV_FUTURE_SUCCESS", "ST_SEARCH_REQUEST_MORE")
			:AddEventTransition("EV_RETRY", "ST_SEARCH_SEND")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_SEARCH_REQUEST_MORE")
			:SetOnEnter(function()
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				local baseItemString = private.searchRow:GetBaseItemString()
				-- Get if the item is a commodity or not
				local isCommodity = ItemInfo.IsCommodity(baseItemString)
				if isCommodity == nil then
					private.retryTimer:RunForTime(SEARCH_MISSING_ITEM_INFO_RETRY_DELAY)
					return
				end

				local isDone, future = private.searchRow:SearchCheckStatus()
				if isDone then
					return "ST_SEARCH_CHECKING"
				elseif future then
					private.HandleAuctionHouseWrapperResult(future)
				else
					private.retryTimer:RunForTime(SEARCH_AH_NOT_READY_RETRY_DELAY)
				end
			end)
			:AddTransition("ST_SEARCH_SEND")
			:AddTransition("ST_SEARCH_CHECKING")
			:AddTransition("ST_CANCELING")
			:AddEventTransition("EV_FUTURE_SUCCESS", "ST_SEARCH_CHECKING")
			:AddEventTransition("EV_RETRY", "ST_SEARCH_SEND")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_SEARCH_CHECKING")
			:SetOnEnter(function()
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				private.retryTimer:Cancel()
				private.searchRow:PopulateSubRows(private.browseId)

				-- check if all the sub rows have their data
				local missingInfo = false
				for _, subRow in private.searchRow:SubRowIterator(true) do
					if not subRow:HasRawData() or not subRow:HasItemString() then
						missingInfo = true
					elseif private.resolveSellers and not subRow:HasOwners() and not private.query:_IsFiltered(subRow, true) then
						-- Waiting for owner info
						-- Currently can't rely on owner info as of 9.2.7, so limit the retries for it
						if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) or private.retryCount <= 10 then
							missingInfo = true
						end
					end
				end

				if missingInfo and private.retryCount >= 100 then
					-- Out of retries, so give up
					return "ST_SEARCH_DONE", false
				elseif missingInfo then
					-- We'll try again
					private.retryCount = private.retryCount + 1
					private.retryTimer:RunForTime(SEARCH_MISSING_INFO_RETRY_DELAY)
					return
				end

				-- Filter the sub rows we don't care about
				private.searchRow:FilterSubRows(private.query)

				if private.callback then
					private.callback(private.query, private.searchRow)
				end
				if private.searchRow:SearchNext() then
					-- there is more to search
					return "ST_SEARCH_GET_KEY"
				else
					-- scanned everything
					return "ST_SEARCH_DONE", true
				end
			end)
			:AddTransition("ST_SEARCH_GET_KEY")
			:AddTransition("ST_SEARCH_CHECKING")
			:AddTransition("ST_SEARCH_DONE")
			:AddTransition("ST_CANCELING")
			:AddEventTransition("EV_RETRY", "ST_SEARCH_CHECKING")
			:AddEventTransition("EV_SEARCH_RESULTS_UPDATED", "ST_SEARCH_CHECKING")
			:AddEventTransition("EV_CANCEL", "ST_CANCELING")
		)
		:AddState(FSM.NewState("ST_SEARCH_DONE")
			:SetOnEnter(function(_, result)
				assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
				private.HandleRequestDone(result)
				return "ST_INIT"
			end)
			:AddTransition("ST_INIT")
		)
		:AddState(FSM.NewState("ST_CANCELING")
			:SetOnEnter(function()
				private.doneTimer:Cancel()
				return "ST_INIT"
			end)
			:AddTransition("ST_INIT")
		)
		:Init("ST_INIT", nil)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts a browse scan.
---@param query AuctionQuery The query
---@param resolveSellers boolean Whether or not to resolve seller names
---@param callback fun(query: AuctionQuery, row: AuctionRow) A function to call with results
---@return Future
function Scanner.Browse(query, resolveSellers, callback)
	if not private.WaitForFutureReady() then
		if TSMDBG then TSMDBG.Warn("Scanner", "Browse: WaitForFutureReady FAILED, returning nil") end
		return nil
	end
	if TSMDBG then TSMDBG.Log("Scanner", "Browse: starting future for new browse") end
	private.requestFuture:Start()
	private.fsm:ProcessEvent("EV_START_BROWSE", query, resolveSellers, callback)
	return private.requestFuture
end

---Starts a browse scan without issuing a new query to the game.
---@param query AuctionQuery The query
---@param itemKeys ItemKey[] The item keys to browse for
---@param callback fun(query: AuctionQuery, row: AuctionRow) A function to call with results
---@return Future
function Scanner.BrowseNoScan(query, itemKeys, callback)
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	if not private.WaitForFutureReady() then
		return nil
	end
	private.requestFuture:Start()
	private.fsm:ProcessEvent("EV_START_BROWSE_NO_SCAN", query, itemKeys, callback)
	return private.requestFuture
end

-- 3.3.5: requestFuture is shared across all browse callers. When two threads
-- (e.g. FILTER_SEARCH and AUCTION_SCAN_FIND) want to scan back-to-back, the
-- second one hits assert(self._state == STATE.RESET) inside Future:Start.
-- Wait briefly for the previous browse to finish before we Start ours.
function private.WaitForFutureReady()
	if private.requestFuture:IsReady() then
		return true
	end
	if TSMDBG then TSMDBG.Log("Scanner", "WaitForFutureReady: future busy, yielding...") end
	local waitStart = GetTime()
	local yields = 0
	while not private.requestFuture:IsReady() do
		Threading.Yield(true)
		yields = yields + 1
		if GetTime() - waitStart > 5 then
			if TSMDBG then TSMDBG.Warn("Scanner", "WaitForFutureReady: timeout after %d yields, %.2fs", yields, GetTime() - waitStart) end
			return false
		end
	end
	if TSMDBG then TSMDBG.Log("Scanner", "WaitForFutureReady: ready after %d yields, %.2fs", yields, GetTime() - waitStart) end
	return true
end

---Starts a search.
---@param query AuctionQuery The query
---@param resolveSellers boolean Whether or not to resolve seller names
---@param useCachedData boolean Use cached data
---@param browseRow AuctionRow The auction row to search for
---@param callback fun(query: AuctionQuery, row: AuctionRow) A function to call with results
---@return Future
function Scanner.Search(query, resolveSellers, useCachedData, browseRow, callback)
	assert(ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE))
	private.requestFuture:Start()
	private.fsm:ProcessEvent("EV_START_SEARCH", query, resolveSellers, useCachedData, browseRow, callback)
	return private.requestFuture
end

---Cancels any in progress scan.
function Scanner.Cancel()
	-- 3.3.5 fix: also skip when the future is already DONE (resolved but not yet
	-- cleaned up), which happens when cancel races the done timer on AH close;
	-- calling Done() twice trips the Future.lua:91 assertion
	if private.requestFuture:IsReady() or private.requestFuture:IsDone() then
		return
	end
	private.requestFuture:Done(false)
end

---Cancels and discards any active browse so that a higher-priority operation
---(typically per-item find) can take over the AH query channel without racing
---with a long FILTER_SEARCH browse.
---3.3.5: BrowseAndFind operations share `private.requestFuture` and the
---underlying QueryAuctionItems channel, so we must explicitly preempt.
---ВАЖНО: вызывать ИЗ thread context (например _FindAuctionThreadedClassic).
---Future:Done синхронно резюмирует ожидающий thread, что нарушает Thread.lua:184
---assertion (private.runningThread должен быть nil). Поэтому ставим cancel
---через doneTimer (RunForTime(0)) — он отстрелит на следующем tick'е, когда
---текущий thread уже отдаст квант. После таймера нужно дождаться RESET.
function Scanner.PreemptForFind()
	if private.requestFuture:IsReady() then
		return false
	end
	if TSMDBG then TSMDBG.Log("Scanner", "PreemptForFind: scheduling cancel of active browse") end
	private.requestResult = false
	private.doneTimer:RunForTime(0)
	return true
end

---Returns true if the requestFuture is in RESET (no scan active).
---Public mirror of WaitForFutureReady's check, used by ScanManager to wait
---out a preempted browse before issuing a new query.
function Scanner.IsFutureReady()
	return private.requestFuture:IsReady()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PendingFutureDoneHandler()
	local result = private.pendingFuture:GetValue()
	private.pendingFuture = nil
	if result then
		private.fsm:ProcessEvent("EV_FUTURE_SUCCESS", result)
	else
		private.retryTimer:RunForTime(FUTURE_FAILED_RETRY_DELAY)
	end
end

function private.RetryHandler()
	private.fsm:SetLoggingEnabled(false)
	private.fsm:ProcessEvent("EV_RETRY")
	private.fsm:SetLoggingEnabled(true)
end

function private.RequestDoneHandler()
	local result = private.requestResult
	private.requestResult = nil
	-- 3.3.5 fix: the done timer fires on the NEXT frame, and the future can be
	-- resolved in between (e.g. the AH closes mid-scan -> Scanner.Cancel() calls
	-- Done(false) directly, or a preempt resolves it first). Calling Done() on a
	-- future that isn't STARTED trips the Future.lua:91 assertion, so bail out if
	-- there's nothing left to resolve.
	if private.requestFuture:IsReady() or private.requestFuture:IsDone() then
		return
	end
	private.requestFuture:Done(result)
end

function private.HandleAuctionHouseWrapperResult(future)
	if future then
		private.pendingFuture = future
		private.pendingFuture:SetScript("OnDone", private.PendingFutureDoneHandler)
	else
		private.retryTimer:RunForTime(FUTURE_FAILED_RETRY_DELAY)
	end
end

function private.HandleRequestDone(result)
	private.requestResult = result
	if TSMDBG then TSMDBG.Log("Scanner", "HandleRequestDone result=%s hasQuery=%s",
		tostring(result), tostring(private.query ~= nil)) end
	-- 3.3.5 local DB: запись данных скана делается ТУТ, после успешного browse,
	-- ровно один раз на скан. _UpdateData в ScrollTable дёргается на любой
	-- render-update и для записи не годится.
	-- 3.3.5 ROOT-FIX (Sniper "лот появляется и через 5 сек пропадает"):
	-- НЕ записываем в AuctionDB результаты частичного скана. Sniper сканирует
	-- ТОЛЬКО последнюю страницу (SetPage("LAST") + SetAccumulate) — это по
	-- определению самые дешёвые/недооценённые лоты. Запись их в DBMarket/
	-- DBMinBuyout каждые 5 сек занижает рыночную цену → SniperOperation.GetMaxPrice
	-- (порог снайпа) падает → на следующем проходе лот больше не проходит порог
	-- и ИСЧЕЗАЕТ из списка (само-отравление рынка по таймеру рескана). Полные
	-- сканы и поиск по одному предмету (без _specifiedPage/_accumulate) пишутся
	-- как раньше.
	local isPartialScan = private.query and (private.query._accumulate or private.query._specifiedPage ~= nil)
	if result and private.query and not isPartialScan and _G.TSM_AuctionDB_RecordScan then
		local ok, err = pcall(private.RecordScanResults, private.query)
		if not ok and _G.TSMDebugDB then
			_G.TSMDebugDB.auctiondb_local = _G.TSMDebugDB.auctiondb_local or {}
			table.insert(_G.TSMDebugDB.auctiondb_local, "RecordScanResults ERR: "..tostring(err))
			if TSMDBG then TSMDBG.Warn("Scanner", "RecordScanResults ERR: %s", tostring(err)) end
		end
	end
	-- Delay a bit so that we complete our current FSM transition
	private.doneTimer:RunForTime(0)
end

-- 3.3.5: записать сводку browse-скана в локальную DB (TradeSkillMaster_AuctionDB).
-- Собирает minBuyout / marketValue / numAuctions per baseItemString и зовёт
-- _G.TSM_AuctionDB_RecordScan({[is]={mb=N, mv=N, na=N}}).
function private.RecordScanResults(query)
	local scanData = {}
	local count = 0
	local prices = {}
	for baseItemString, row in query:BrowseResultsIterator() do
		local minBuyout, auctionCount = nil, 0
		wipe(prices)
		for _, subRow in row:SubRowIterator() do
			if subRow.HasRawData and subRow:HasRawData() then
				local _, itemBuyout = subRow:GetBuyouts()
				if itemBuyout and itemBuyout > 0 then
					if not minBuyout or itemBuyout < minBuyout then
						minBuyout = itemBuyout
					end
					-- одна точка на АУКЦИОН (как в оригинальном TSM), а не на
					-- единицу в стаке: иначе один дешёвый стак 20 шт даёт 20
					-- точек и полностью захватывает нижний перцентиль выборки,
					-- отравляя marketValue
					prices[#prices + 1] = itemBuyout
				end
				-- na = кол-во аукционов (лотов), а не единиц товара.
				-- Тултип "N auctions" должен означать именно лоты.
				auctionCount = auctionCount + 1
			end
		end
		if minBuyout and minBuyout > 0 then
			scanData[baseItemString] = {
				mb = minBuyout,
				mv = private.CalcMarketValue(prices) or minBuyout,
				na = auctionCount > 0 and auctionCount or nil,
			}
			count = count + 1
		end
	end
	if count > 0 then
		_G.TSM_AuctionDB_RecordScan(scanData)
		-- 3.3.5: also feed the in-memory AuctionDB holder so DBMinBuyout /
		-- DBMarket reflect this scan immediately (e.g. right after searching a
		-- single item), instead of only after the next /reload when the
		-- SavedVariable is re-read into the holder.
		if _G.TSM_AuctionDB_RecordLocalScanResults then
			_G.TSM_AuctionDB_RecordLocalScanResults(scanData)
		end
		if _G.TSMDebugDB then
			_G.TSMDebugDB.auctiondb_local = _G.TSMDebugDB.auctiondb_local or {}
			-- sliding window: храним только последние 200 записей
			local log = _G.TSMDebugDB.auctiondb_local
			while #log > 200 do
				table.remove(log, 1)
			end
			table.insert(log, string.format("[%s] RecordScan items=%d", date("%H:%M:%S"), count))
		end
	end
end

-- Эталонная формула AuctionDB marketValue (TSM), одна точка = один аукцион:
--   1. sort ascending
--   2. берём нижние 30% аукционов, но первые 15% ЗАЩИЩЕНЫ от jump-cutoff
--      (иначе один дешёвый троллинг-лот с cut=1 становится всем MV)
--   3. jump-cutoff: после защищённых 15%, если price[i] > price[i-1]*1.2,
--      отбрасываем хвост
--   4. mean + stddev по оставшимся, отбрасываем точки дальше 1.5σ
--   5. mean остатка
-- Возвращает nil если входной список пустой.
function private.CalcMarketValue(prices)
	local n = #prices
	if n == 0 then return nil end
	if n == 1 then return prices[1] end
	table.sort(prices)
	-- шаг 2-3: нижние 30% (минимум 2 точки), защита первых 15% от cutoff
	local protectedIdx = max(2, ceil(n * 0.15))
	local maxIdx = max(protectedIdx, ceil(n * 0.3))
	local numKept = 0
	for i = 1, n do
		if i <= protectedIdx then
			numKept = i
		elseif i > maxIdx or prices[i] > prices[i - 1] * 1.2 then
			break
		else
			numKept = i
		end
	end
	-- шаг 4: фильтр стандартного отклонения (±1.5σ от среднего)
	local sum = 0
	for i = 1, numKept do
		sum = sum + prices[i]
	end
	local mean = sum / numKept
	if numKept < 3 then
		return floor(mean + 0.5)
	end
	local variance = 0
	for i = 1, numKept do
		local d = prices[i] - mean
		variance = variance + d * d
	end
	local stdDev = math.sqrt(variance / numKept)
	local limitLo = mean - 1.5 * stdDev
	local limitHi = mean + 1.5 * stdDev
	-- шаг 5: среднее точек внутри 1.5σ
	local fSum, fCnt = 0, 0
	for i = 1, numKept do
		if prices[i] >= limitLo and prices[i] <= limitHi then
			fSum = fSum + prices[i]
			fCnt = fCnt + 1
		end
	end
	if fCnt == 0 then
		return floor(mean + 0.5)
	end
	return floor(fSum / fCnt + 0.5)
end

function private.CheckBrowseResults()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		-- Process as many auctions as we can
		local numAuctions = AuctionHouse.GetNumAuctions()
		if private.browseIndex == 1 and #private.browsePendingIndexes == 0 then
			-- new scan starting: reset the diagnostics counters
			local cs = private.classicStats
			cs.seen, cs.noInfo, cs.noLink, cs.badLink, cs.nameSkip, cs.earlyReject, cs.added = 0, 0, 0, 0, 0, 0, 0
		end
		-- Some 3.3.5a cores briefly return an empty page right after a browse query.
		-- Retry a few times instead of immediately showing an empty result set.
		if numAuctions > 0 then
			private.browseEmptyRetryCount = 0
		elseif private.query and private.query._str and private.query._str ~= "" and private.browseEmptyRetryCount < BROWSE_EMPTY_RETRY_MAX then
			private.browseEmptyRetryCount = private.browseEmptyRetryCount + 1
			private.retryTimer:RunForTime(BROWSE_EMPTY_RETRY_DELAY)
			TSMDBG.Log("Scanner", "Classic browse returned empty page; retrying (%d/%d)", private.browseEmptyRetryCount, BROWSE_EMPTY_RETRY_MAX)
			return false
		end
		for i = #private.browsePendingIndexes, 1, -1 do
			local index = private.browsePendingIndexes[i]
			if private.ProcessBrowseResultClassic(index) then
				tremove(private.browsePendingIndexes, i)
			end
		end
		-- 3.3.5 perf: обрабатываем не дольше BROWSE_PROCESS_TIME_BUDGET_MS за
		-- вызов; при исчерпании бюджета продолжаем на следующем кадре через
		-- updateTimer (retryTimer от FSM с его 0.5с задержкой перекрывается
		-- более быстрым тиком updateTimer — EV_BROWSE_RESULTS_UPDATED вернёт
		-- нас в ST_BROWSE_CHECKING немедленно)
		local budgetStart = debugprofilestop()
		local budgetExhausted = false
		local index = private.browseIndex
		while index <= numAuctions and #private.browsePendingIndexes < 50 do
			if not private.ProcessBrowseResultClassic(index) then
				tinsert(private.browsePendingIndexes, index)
			end
			index = index + 1
			if debugprofilestop() - budgetStart > BROWSE_PROCESS_TIME_BUDGET_MS then
				budgetExhausted = index <= numAuctions
				break
			end
		end
		private.browseIndex = index
		if budgetExhausted then
			TSMDBG.Log("Scanner", "Browse page budget exhausted at index %d/%d; continuing next frame", private.browseIndex - 1, numAuctions)
			private.updateTimer:RunForFrames(1)
			return false
		end
		if private.browseIndex <= numAuctions or #private.browsePendingIndexes > 0 then
			return false
		end
	end

	-- Attempt to populate the browse results
	wipe(private.missingItemIds)
	local populated, numRemoved = nil, 0
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		populated, numRemoved = private.query:_PopulateBrowseData(private.missingItemIds)
		if numRemoved > 0 then
			Log.Info("Removed %d results while populing data", numRemoved)
		end
		if not populated then
			return false
		end
	else
		TSMDBG.Log("Scanner", "Calling _PopulateBrowseData (classic, no-wait)")
		populated, numRemoved = private.query:_PopulateBrowseData(private.missingItemIds)
		if numRemoved > 0 then
			Log.Info("Removed %d results while populing data", numRemoved)
		end
		populated = true
	end

	-- Filter the results
	numRemoved = private.query:_FilterBrowseResults()
	if numRemoved > 0 then
		Log.Info("Removed %d filtered results", numRemoved)
		TSMDBG.Log("Scanner", "Filtered out %d results", numRemoved)
	end

	-- Count final results
	local totalResults = 0
	for _ in private.query:BrowseResultsIterator() do
		totalResults = totalResults + 1
	end
	TSMDBG.Log("Scanner", "Final results count=%d", totalResults)
	TSMDBG.TimeEnd("Scanner:CheckBrowseResults")

	return true
end

function private.ProcessBrowseResultClassic(index)
	local cs = private.classicStats
	cs.seen = cs.seen + 1
	local rawName, itemLink, stackSize, timeLeft, buyout, seller = AuctionHouse.GetBrowseResult(index)
	
	if not rawName or rawName == "" or not buyout or not stackSize or not timeLeft then
		cs.noInfo = cs.noInfo + 1
		return false
	end

	-- 3.3.5: Фильтруем по поисковой строке прямо здесь, как в Auctionator (не добавляем в browseResults, если не совпадает)
	if private.query._str and private.query._str ~= "" then
		local nameLower = strlower(rawName)
		if private.query._exact then
			if nameLower ~= private.query._strLower then
				cs.nameSkip = cs.nameSkip + 1
				return true
			end
		else
			if not strfind(nameLower, private.query._strLower, 1, true) then
				cs.nameSkip = cs.nameSkip + 1
				return true
			end
		end
	end


	if not itemLink then
		cs.noLink = cs.noLink + 1
		return false
	end

	local baseItemString = ItemString.GetBase(itemLink)
	if not baseItemString then
		cs.badLink = cs.badLink + 1
		return false
	end

	-- getAll dumps the whole AH; skip items not in the requested set early so we don't
	-- spend cycles populating SubRows for 50k irrelevant lots.
	local items = private.query._items
	if next(items) and not items[baseItemString] then
		cs.earlyReject = cs.earlyReject + 1
		return true
	end
	if not seller and private.resolveSellers then
		seller = "?"
	end
	private.query:_ProcessBrowseResult(baseItemString, itemLink)
	local row = private.query:_GetBrowseResults(baseItemString)
	row:PopulateSubRows(private.browseId, index, itemLink)
	cs.added = cs.added + 1
	-- Classic browse rows always have raw data for newly populated listings,
	-- so no need to scan all existing subRows on every auction index.
	return true
end
