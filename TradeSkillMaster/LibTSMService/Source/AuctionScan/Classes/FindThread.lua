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
function FindThread.StartFindAuction(auctionScan, auction, callback, noSeller)
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
			if TSMDBG then TSMDBG.Log("FindThread", "EqualsIndex(%d) INCOMPLETE link=%s qty=%s buy=%s",
				index, tostring(itemLink), tostring(stackSize), tostring(buyout)) end
			return false
		end

		-- 1. baseItemString match
		local baseItemString = ItemString.Get(itemLink)
		local selfBaseItemString = ItemString.Get(self._itemLink)
		if not baseItemString or not selfBaseItemString or baseItemString ~= selfBaseItemString then
			if TSMDBG then TSMDBG.Log("FindThread", "EqualsIndex(%d) BASE FAIL want=%s got=%s",
				index, tostring(selfBaseItemString), tostring(baseItemString)) end
			return false
		end

		-- 2. Buyout
		if buyout ~= self._buyout then
			if TSMDBG then TSMDBG.Log("FindThread", "EqualsIndex(%d) BUYOUT FAIL want=%d got=%d  (per-unit want=%d got=%d)",
				index, self._buyout, buyout,
				self._quantity > 0 and math.floor(self._buyout / self._quantity) or 0,
				stackSize > 0 and math.floor(buyout / stackSize) or 0) end
			return false
		end

		-- 3. StackSize exact
		if stackSize ~= self._quantity then
			if TSMDBG then TSMDBG.Log("FindThread", "EqualsIndex(%d) QTY FAIL want=%d got=%d", index, self._quantity, stackSize) end
			return false
		end

		-- 4. Seller optional
		if not noSeller and seller ~= "?" and self._ownerStr ~= "?" and seller ~= self._ownerStr then
			if TSMDBG then TSMDBG.Log("FindThread", "EqualsIndex(%d) SELLER FAIL want='%s' got='%s'",
				index, tostring(self._ownerStr), tostring(seller)) end
			return false
		end

		if TSMDBG then TSMDBG.Log("FindThread", "EqualsIndex(%d) MATCH", index) end
		return true
	end

	private.startArgs.auction = snapshot
	private.startArgs.callback = callback
	private.startArgs.noSeller = noSeller
	private.startTimer:RunForTime(0)
end

---Stops any in-progress find thread.
---@param noKill boolean Don't kill the thread
function FindThread.StopFindAuction(noKill)
	wipe(private.startArgs)
	private.callback = nil
	if not noKill then
		Threading.Kill(private.threadId)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param auctionScan AuctionScanManager
function private.FindThread(auctionScan, row, noSeller)
	return auctionScan:_FindAuctionThreaded(row, noSeller)
end

function private.StartThread()
	if not private.startArgs.auctionScan then
		return
	end
	if private.isRunning then
		private.startTimer:RunForTime(0.1)
		return
	end
	private.isRunning = true
	private.callback = private.startArgs.callback
	Threading.Start(private.threadId, private.startArgs.auctionScan, private.startArgs.auction, private.startArgs.noSeller)
	wipe(private.startArgs)
end

function private.ThreadCallback(...)
	private.isRunning = false
	if private.callback then
		private.callback(...)
	end
end
