-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local MyAuctions = TSM:NewPackage("MyAuctions")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local Database = TSM.LibTSMUtil:Include("Database")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local Group = TSM.LibTSMTypes:Include("Group")
local Auction = TSM.LibTSMService:Include("Auction")
local AuctionHouseWrapper = TSM.LibTSMWoW:Include("API.AuctionHouseWrapper")
local private = {
	pendingDB = nil,
	pendingHashes = {},
	expectedCounts = {},
	pendingFuture = nil,
}
local DB_HASH_FIELDS = {
	"itemLink",
	"itemTexture",
	"itemName",
	"itemQuality",
	"duration",
	"highBidder",
	"currentBid",
	"buyout",
	"stackSize",
	"isSold",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function MyAuctions.OnInitialize()
	private.pendingDB = Database.NewSchema("MY_AUCTIONS_PENDING")
		:AddUniqueNumberField("index")
		:AddNumberField("hash")
		:AddBooleanField("isPending")
		:AddNumberField("pendingAuctionId")
		:AddIndex("index")
		:Commit()
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.AuctionHouseClosed, false)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		Event.Register("CHAT_MSG_SYSTEM", private.ChatMsgSystemEventHandler)
		Event.Register("UI_ERROR_MESSAGE", private.UIErrorMessageEventHandler)
	end
	Auction.RegisterIndexCallback(private.OnAuctionsUpdated)
end

function MyAuctions.CreateQuery()
	local query = Auction.NewIndexQuery()
		:LeftJoin(private.pendingDB, "index")
		:VirtualField("group", "string", Group.GetPathByItem, "itemString", "")
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		query:OrderBy("isSold", false)
		query:OrderBy("itemName", true)
		query:OrderBy("auctionId", true)
	else
		query:OrderBy("index", false)
	end
	return query
end

function MyAuctions.CancelAuction(auctionId)
	local row = private.pendingDB:NewQuery()
		:Equal("pendingAuctionId", auctionId)
		:GetFirstResultAndRelease()
	local hash = row:GetField("hash")
	assert(hash)

	Log.Info("Canceling (auctionId=%d, hash=%d)", auctionId, hash)
	private.pendingFuture = AuctionHouseWrapper.CancelAuction(auctionId)
	if not private.pendingFuture then
		ChatMessage.PrintUser(L["Failed to cancel auction due to the auction house being busy. Ensure no other addons are scanning the AH and try again."])
		return
	end
	private.pendingFuture:SetScript("OnDone", private.PendingFutureOnDone)

	if private.expectedCounts[hash] and private.expectedCounts[hash] > 0 then
		private.expectedCounts[hash] = private.expectedCounts[hash] - 1
	else
		private.expectedCounts[hash] = private.GetNumRowsByHash(hash) - 1
	end
	assert(private.expectedCounts[hash] >= 0)
	assert(not row:GetField("isPending"))
	row:SetField("isPending", true)
		:Update()
	row:Release()

	tinsert(private.pendingHashes, hash)
end

function MyAuctions.CanCancel(index)
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		local numPending = private.pendingDB:NewQuery()
			:Equal("isPending", true)
			:LessThanOrEqual("index", index)
			:CountAndRelease()
		return numPending == 0
	else
		return not private.pendingFuture
	end
end

function MyAuctions.GetNumPending()
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		return private.pendingDB:NewQuery()
			:Equal("isPending", true)
			:CountAndRelease()
	else
		return private.pendingFuture and 1 or 0
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AuctionHouseClosed()
	if private.pendingFuture then
		private.pendingFuture:Cancel()
		private.pendingFuture = nil
	end
end

function private.ChatMsgSystemEventHandler(_, msg)
	if ClientInfo.IsRetail() and issecretvalue(msg) then
		-- The message is a secret, so just ignore it
		return
	end
	if msg == ERR_AUCTION_REMOVED and #private.pendingHashes > 0 then
		local hash = tremove(private.pendingHashes, 1)
		assert(hash)
		Log.Info("Confirmed (hash=%d)", hash)
	end
end

function private.UIErrorMessageEventHandler(_, _, msg)
	if (msg == ERR_ITEM_NOT_FOUND or msg == ERR_NOT_ENOUGH_MONEY) and #private.pendingHashes > 0 then
		local hash = tremove(private.pendingHashes, 1)
		assert(hash)
		Log.Info("Failed to cancel (hash=%d)", hash)
		if private.expectedCounts[hash] then
			private.expectedCounts[hash] = private.expectedCounts[hash] + 1
		end
	end
end

function private.PendingFutureOnDone()
	local result = private.pendingFuture:GetValue()
	private.pendingFuture = nil
	local hash = tremove(private.pendingHashes, 1)
	assert(hash)
	if result then
		Log.Info("Confirmed (hash=%d)", hash)
	else
		Log.Info("Failed to cancel (hash=%d)", hash)
		if private.expectedCounts[hash] then
			private.expectedCounts[hash] = private.expectedCounts[hash] + 1
		end
		private.OnAuctionsUpdated()
		AuctionHouseWrapper.AutoQueryOwnedAuctions()
	end
end

function private.GetNumRowsByHash(hash)
	return private.pendingDB:NewQuery()
		:Equal("hash", hash)
		:CountAndRelease()
end

function private.OnAuctionsUpdated()
	local minPendingIndexByHash = TempTable.Acquire()
	local numByHash = TempTable.Acquire()
	local query = Auction.NewIndexQuery()
		:OrderBy("index", true)
	for _, row in query:Iterator() do
		local index = row:GetField("index")
		local hash = row:CalculateHash(DB_HASH_FIELDS)
		numByHash[hash] = (numByHash[hash] or 0) + 1
		if not minPendingIndexByHash[hash] and private.pendingDB:GetUniqueRowField("index", index, "isPending") then
			minPendingIndexByHash[hash] = index
		end
	end
	local numUsed = TempTable.Acquire()
	private.pendingDB:TruncateAndBulkInsertStart()
	for _, row in query:Iterator() do
		local hash = row:CalculateHash(DB_HASH_FIELDS)
		assert(numByHash[hash] > 0)
		local expectedCount = private.expectedCounts[hash]
		local isPending = nil
		if not expectedCount then
			-- this was never pending
			isPending = false
		elseif numByHash[hash] <= expectedCount then
			-- this is no longer pending
			isPending = false
			private.expectedCounts[hash] = nil
		elseif row:GetField("index") >= (minPendingIndexByHash[hash] or math.huge) then
			local numPending = numByHash[hash] - expectedCount
			assert(numPending > 0)
			numUsed[hash] = (numUsed[hash] or 0) + 1
			isPending = numUsed[hash] <= numPending
		else
			-- it's a later auction which is pending
			isPending = false
		end
		private.pendingDB:BulkInsertNewRow(row:GetField("index"), hash, isPending, row:GetField("auctionId"))
	end
	private.pendingDB:BulkInsertEnd()
	TempTable.Release(numByHash)
	TempTable.Release(numUsed)
	TempTable.Release(minPendingIndexByHash)
	query:Release()
end
