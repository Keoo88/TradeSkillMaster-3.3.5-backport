-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local BlackMarket = LibTSMService:Init("Auction.BlackMarket")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local private = {
	data = nil,
	time = nil,
}
local COPPER_PER_GOLD = 100 * 100



-- ============================================================================
-- Module Functions
-- ============================================================================

---Start the black market code.
function BlackMarket.Start()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.BLACK_MARKET_AH) then
		return
	end
	Event.Register("BLACK_MARKET_ITEM_UPDATE", private.ScanBMAH)
end

---Gets the most recent black market scan data.
---@return string? scanData
---@return number? scanTime
function BlackMarket.GetScanData()
	return private.data, private.time
end



-- ============================================================================
-- Private Helper Features
-- ============================================================================

function private.ScanBMAH()
	local numItems = AuctionHouse.GetNumBlackMarketAuctions()
	if not numItems then
		return
	end
	local now = floor(LibTSMService.GetTime())
	local items = TempTable.Acquire()
	for i = 1, numItems do
		local quantity, minBid, minIncr, currBid, numBids, timeLeft, itemLink, bmId = AuctionHouse.GetBlackMarketItemInfo(i)
		local itemID = ItemString.ToId(itemLink)
		if itemID then
			minBid = floor(minBid / COPPER_PER_GOLD)
			minIncr = floor(minIncr / COPPER_PER_GOLD)
			currBid = floor(currBid / COPPER_PER_GOLD)
			tinsert(items, "[" .. strjoin(",", bmId, itemID, quantity, timeLeft, minBid, minIncr, currBid, numBids, now) .. "]")
		end
	end
	private.data = "[" .. table.concat(items, ",") .. "]"
	private.time = now
	TempTable.Release(items)
end
