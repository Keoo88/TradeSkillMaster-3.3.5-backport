-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local FindThread = LibTSMService:Init("AuctionScan.FindThread")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local private = {
	threadId = nil,
	startTimer = nil,
	isRunning = false,
	startArgs = {
		auctionScan = nil,
		auction = nil,
		callback = nil,
		noSeller = nil,
	},
	callback = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

FindThread:OnModuleLoad(function()
	-- Initialize threads
	private.threadId = Threading.New("AUCTION_SCAN_FIND", private.FindThread)
	Threading.SetCallback(private.threadId, private.ThreadCallback)
	private.startTimer = DelayTimer.New("AUCTION_SCAN_FIND_START", private.StartThread)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Starts the find thread.
---@param auctionScan AuctionScanManager The auction scan
---@param auction AuctionSubRow The sub row to find
---@param callback fun(...: any) The result callback
---@param noSeller boolean Ignore seller names
---@param forceQuery boolean? Skip the current-page shortcut (3.3.5 buy-after-buy fix)
function FindThread.StartFindAuction(auctionScan, auction, callback, noSeller, forceQuery)
	wipe(private.startArgs)
	private.startArgs.auctionScan = auctionScan
	-- 3.3.5: создаём snapshot данных subRow, потому что он может быть released до старта thread
	local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
	local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
	local snapshot = {
		_itemLink = auction._itemLink,
		_buyout = auction._buyout,
		_quantity = auction._quantity,
		_ownerStr = auction._ownerStr,
	}
	-- Добавляем методы которые использует find
	snapshot.GetItemString = function(self)
		return ItemString.Get(self._itemLink)
	end
	snapshot.EqualsIndex = function(self, index, noSeller)
		local _, itemLink, stackSize, timeLeft, buyout, seller, minIncrement, minBid, bid, isHighBidder = AuctionHouse.GetBrowseResult(index)
		seller = seller or "?"

		-- Guard: incomplete data
		if not itemLink or not stackSize or not buyout then
			return false
		end

		-- 1. baseItemString match
		local baseItemString = ItemString.Get(itemLink)
		local selfBaseItemString = ItemString.Get(self._itemLink)
		if not baseItemString or not selfBaseItemString or baseItemString ~= selfBaseItemString then
			return false
		end

		-- 2. Buyout
		if buyout ~= self._buyout then
			return false
		end

		-- 3. StackSize exact
		if stackSize ~= self._quantity then
			return false
		end

		-- 4. Seller optional
		if not noSeller and seller ~= "?" and self._ownerStr ~= "?" and seller ~= self._ownerStr then
			return false
		end

		return true
	end

	private.startArgs.auction = snapshot
	private.startArgs.callback = callback
	private.startArgs.noSeller = noSeller
	private.startArgs.forceQuery = forceQuery
	private.startTimer:RunForTime(0)
end

---Stops any in-progress find thread.
---@param noKill boolean Don't kill the thread
function FindThread.StopFindAuction(noKill)
	wipe(private.startArgs)
	private.callback = nil
	if not noKill then
		Threading.Kill(private.threadId)
		-- The thread callback only fires on a normal exit, so it won't run for a
		-- killed thread and we must reset the running flag ourselves. Otherwise
		-- every future StartFindAuction() reschedules itself forever waiting for
		-- isRunning to clear, no find ever runs, and the Bid/Buyout buttons stay
		-- permanently disabled (e.g. after buying a lot causes a deselect mid-find).
		private.isRunning = false
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param auctionScan AuctionScanManager
function private.FindThread(auctionScan, row, noSeller, forceQuery)
	return auctionScan:_FindAuctionThreaded(row, noSeller, forceQuery)
end

function private.StartThread()
	if not private.startArgs.auctionScan then
		return
	end
	if private.isRunning then
		if not Threading.IsAlive(private.threadId) then
			-- The previous find thread died without a normal exit (killed or errored),
			-- so its callback never fired to clear this flag. Recover instead of
			-- rescheduling forever (which would leave the Bid/Buyout buttons disabled).
			private.isRunning = false
		else
			private.startTimer:RunForTime(0.1)
			return
		end
	end
	private.isRunning = true
	private.callback = private.startArgs.callback
	Threading.Start(private.threadId, private.startArgs.auctionScan, private.startArgs.auction, private.startArgs.noSeller, private.startArgs.forceQuery)
	wipe(private.startArgs)
end

function private.ThreadCallback(...)
	private.isRunning = false
	if private.callback then
		private.callback(...)
	end
end
