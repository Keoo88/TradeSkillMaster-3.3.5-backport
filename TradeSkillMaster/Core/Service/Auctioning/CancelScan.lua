-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local CancelScan = TSM.Auctioning:NewPackage("CancelScan") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local Database = TSM.LibTSMUtil:Include("Database")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local Auction = TSM.LibTSMService:Include("Auction")
local AuctionHouseWrapper = TSM.LibTSMWoW:Include("API.AuctionHouseWrapper")
local private = {
	settings = nil,
	scanThreadId = nil,
	queueDB = nil,
	currentRowQuery = nil,
	statusQuery = nil,
	itemList = {},
	usedAuctionIndex = {},
	subRowsTemp = {},
	listedAuctionTemp = {},
	scanResultTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function CancelScan.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctioningOptions", "cancelWithBid")
		:AddKey("global", "auctioningOptions", "disableInvalidMsg")
	private.scanThreadId = Threading.New("CANCEL_SCAN", private.ScanThread)
	private.queueDB = Database.NewSchema("AUCTIONING_CANCEL_QUEUE")
		:AddNumberField("auctionId")
		:AddStringField("itemString")
		:AddStringField("operationName")
		:AddNumberField("bid")
		:AddNumberField("buyout")
		:AddNumberField("itemBid")
		:AddNumberField("itemBuyout")
		:AddNumberField("stackSize")
		:AddNumberField("duration")
		:AddNumberField("numStacks")
		:AddNumberField("numProcessed")
		:AddNumberField("numConfirmed")
		:AddNumberField("numFailed")
		:AddIndex("auctionId")
		:AddIndex("itemString")
		:Commit()
	-- Create our queries
	private.currentRowQuery = private.queueDB:NewQuery()
		:Custom(private.NextProcessRowQueryHelper)
		:OrderBy("auctionId", false)
	private.statusQuery = private.queueDB:NewQuery()
end

function CancelScan.Prepare()
	return private.scanThreadId
end

function CancelScan.CurrentRowPublisher()
	return private.currentRowQuery:Publisher()
		:MapToValue(private.currentRowQuery)
		:MapWithMethod("GetFirstResult")
end

function CancelScan.StatusQueryPublisher()
	return private.statusQuery:Publisher()
		:MapToValue(private.statusQuery)
		:MapWithFunction(private.StatusQueryToQueueStatus)
end

function CancelScan.DoProcess()
	local cancelRow = private.currentRowQuery:GetFirstResult()
	local cancelItemString = cancelRow:GetField("itemString")
	local query = private.NewAuctionsQuery(cancelItemString, cancelItemString)
		:Equal("stackSize", cancelRow:GetField("stackSize"))
		:Custom(private.ProcessQueryHelper, cancelRow)
		:Select("auctionId", "autoBaseItemString", "currentBid", "buyout")
	if not private.settings.cancelWithBid then
		query:Equal("highBidder", "")
	end
	local auctionId, itemString, currentBid, buyout = query:GetFirstResultAndRelease()
	if auctionId then
		local usedAuctionIndex = (not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic()) and auctionId or (itemString..buyout..currentBid..auctionId)
		private.usedAuctionIndex[usedAuctionIndex] = true
		-- 3.3.5 fix: on classic clients auctionId is just the owner-list INDEX, and
		-- indexes shift after every successful cancel/sale until the owned list is
		-- rescanned. Verify the live owner-list row at this index still matches the
		-- item/prices we intend to cancel; if it doesn't, fail this cancel (it will
		-- be retried after the owned auctions rescan) instead of cancelling a wrong lot.
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
			local liveLink = GetAuctionItemLink("owner", auctionId)
			-- Compare base itemStrings (autoBaseItemString is group-translated, so
			-- reduce both sides to their base for a reliable identity check)
			local liveBase = liveLink and ItemString.GetBase(liveLink)
			local expectedBase = ItemString.GetBaseFast(itemString)
			local _, _, _, _, _, _, liveMinBid, _, liveBuyout, liveBid, liveHighBidder = GetAuctionItemInfo("owner", auctionId)
			local liveCurrentBid = (liveHighBidder and liveHighBidder ~= "") and liveBid or liveMinBid
			if liveBase ~= expectedBase or (liveBuyout or 0) ~= buyout or (liveCurrentBid or 0) ~= currentBid then
				Log.Warn("Owner-list index %d shifted (item %s vs %s); skipping cancel until rescan", auctionId, tostring(liveBase), tostring(expectedBase))
				cancelRow:SetField("numProcessed", cancelRow:GetField("numProcessed") + 1)
					:Update()
				return false, false
			end
		end
		local result = AuctionHouseWrapper.CancelAuction(auctionId)
		local isRowDone = cancelRow:GetField("numProcessed") + 1 == cancelRow:GetField("numStacks")
		cancelRow:SetField("numProcessed", cancelRow:GetField("numProcessed") + 1)
			:Update()
		if result and isRowDone then
			-- update the log
			TSM.Auctioning.Log.UpdateRowByIndex(auctionId, "state", "CANCELLED")
		end
		return result, false
	end

	-- we couldn't find this item, so mark this cancel as failed and we'll try again later
	cancelRow:SetField("numProcessed", cancelRow:GetField("numProcessed") + 1)
		:Update()
	return false, false
end

function CancelScan.DoSkip()
	local cancelRow = private.currentRowQuery:GetFirstResult()
	local auctionId = cancelRow:GetField("auctionId")
	cancelRow:SetField("numProcessed", cancelRow:GetField("numProcessed") + 1)
		:SetField("numConfirmed", cancelRow:GetField("numConfirmed") + 1)
		:Update()
	-- update the log
	TSM.Auctioning.Log.UpdateRowByIndex(auctionId, "state", "SKIPPED")
end

function CancelScan.HandleConfirm(success, canRetry)
	local confirmRow = private.queueDB:NewQuery()
		:Custom(private.ConfirmRowQueryHelper)
		:OrderBy("auctionId", true)
		:GetFirstResultAndRelease()
	if not confirmRow then
		-- we may have cancelled something outside of TSM
		return
	end

	if canRetry then
		assert(not success)
		confirmRow:SetField("numFailed", confirmRow:GetField("numFailed") + 1)
	end
	confirmRow:SetField("numConfirmed", confirmRow:GetField("numConfirmed") + 1)
		:Update()
	confirmRow:Release()
end

function CancelScan.PrepareFailedCancels()
	wipe(private.usedAuctionIndex)
	private.queueDB:SetQueryUpdatesPaused(true)
	local query = private.queueDB:NewQuery()
		:GreaterThan("numFailed", 0)
	for _, row in query:Iterator() do
		local numFailed, numProcessed, numConfirmed = row:GetFields("numFailed", "numProcessed", "numConfirmed")
		assert(numProcessed >= numFailed and numConfirmed >= numFailed)
		row:SetField("numFailed", 0)
			:SetField("numProcessed", numProcessed - numFailed)
			:SetField("numConfirmed", numConfirmed - numFailed)
			:Update()
	end
	query:Release()
	private.queueDB:SetQueryUpdatesPaused(false)
end

function CancelScan.Reset()
	private.queueDB:Truncate()
	wipe(private.usedAuctionIndex)
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

function private.ScanThread(auctionScan, groupList)
	auctionScan:SetScript("OnQueryDone", private.AuctionScanOnQueryDone)

	-- generate the list of items we want to scan for
	wipe(private.itemList)
	local processedItems = TempTable.Acquire()
	local query = Auction.NewIndexQuery()
		:Equal("isSold", false)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Select("autoBaseItemString")
	if not private.settings.cancelWithBid then
		query:Equal("highBidder", "")
	end
	for _, itemString in query:Iterator() do
		if not processedItems[itemString] and private.CanCancelItem(itemString, groupList) then
			tinsert(private.itemList, itemString)
		end
		processedItems[itemString] = true
	end
	query:Release()
	TempTable.Release(processedItems)

	if #private.itemList == 0 then
		return
	end
	TSM.Auctioning.SavedSearches.RecordSearch(groupList, "cancelGroups")

	-- run the scan
	auctionScan:AddItemListQueriesThreaded(private.itemList)
	for _, query2 in auctionScan:QueryIterator() do
		query2:AddCustomFilter(private.QueryBuyoutFilter)
	end
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CanCancelItem(itemString, groupList)
	local groupPath = Group.GetPathByItem(itemString)
	if not groupPath or not tContains(groupList, groupPath) then
		return false
	end

	local hasValidOperation, hasInvalidOperation = false, false
	for _, operationName, operationSettings in GroupOperation.OperationIterator(groupPath, "Auctioning") do
		local isValid = private.IsOperationValid(itemString, operationName, operationSettings)
		if isValid == true then
			hasValidOperation = true
		elseif isValid == false then
			hasInvalidOperation = true
		else
			-- we are ignoring this operation
			assert(isValid == nil, "Invalid return value")
		end
	end
	return hasValidOperation and not hasInvalidOperation, itemString
end

function private.IsOperationValid(itemString, operationName, operationSettings)
	local errType, errArg, errArg2 = AuctioningOperation.ValidateForCanceling(itemString, operationSettings)
	if not errType then
		return true
	end
	TSM.Auctioning.Log.AddEntry(itemString, operationName, errType, "", 0, 0)
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		if not private.settings.disableInvalidMsg then
			private.PrintInvalidGroupError(itemString, errType, errArg, errArg2)
		end
		return false
	elseif errType == AuctioningOperation.RESULT.WONT_CANCEL.DISABLED then
		-- Ignore this operation
		return nil
	else
		error("Unknown error: "..tostring(errType))
	end
end

function private.PrintInvalidGroupError(itemString, errType, errArg, errArg2)
	local itemLink = ItemInfo.GetLink(itemString)
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MIN_PRICE then
		ChatMessage.PrintfUser(L["Did not cancel %s because your minimum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_PRICE then
		ChatMessage.PrintfUser(L["Did not cancel %s because your maximum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE then
		ChatMessage.PrintfUser(L["Did not cancel %s because your normal price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.CANCEL_REPOST_THRESHOLD then
		ChatMessage.PrintfUser(L["Did not cancel %s because your cancel to repost threshold (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.UNDERCUT then
		ChatMessage.PrintfUser(L["Did not cancel %s because your undercut (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN then
		ChatMessage.PrintfUser(L["Did not cancel %s because your maximum price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN then
		ChatMessage.PrintfUser(L["Did not cancel %s because your normal price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	else
		error("Unknown error type: "..tostring(errType))
	end
end

function private.QueryBuyoutFilter(_, row)
	local _, itemBuyout, minItemBuyout = row:GetBuyouts()
	return (itemBuyout and itemBuyout == 0) or (minItemBuyout and minItemBuyout == 0)
end

function private.NewAuctionsQuery(itemString, autoBaseItemString)
	local itemStringField = nil
	if itemString == ItemString.GetBaseFast(itemString) then
		itemStringField = "baseItemString"
	elseif ItemString.IsLevel(itemString) then
		itemStringField = "levelItemString"
	else
		itemStringField = "itemString"
	end
	return Auction.NewIndexQuery()
		:Equal("isSold", false)
		:Equal(itemStringField, itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", autoBaseItemString)
		:OrderBy("auctionId", false)
end

function private.AuctionScanOnQueryDone(_, query)
	TSM.Auctioning.Log.SetQueryUpdatesPaused(true)
	for itemString in query:ItemIterator() do
		local groupPath = Group.GetPathByItem(itemString)
		if groupPath then
			local baseItemString = ItemString.GetBaseFast(itemString)
			local levelItemString = ItemString.ToLevel(itemString)
			local isLevelItemString = itemString == levelItemString and itemString ~= baseItemString
			local auctionsDBQuery = private.NewAuctionsQuery(isLevelItemString and baseItemString or itemString, itemString)
			for _, auctionsDBRow in auctionsDBQuery:IteratorAndRelease() do
				private.GenerateCancels(auctionsDBRow, itemString, groupPath, query)
			end
		else
			Log.Warn("Item removed from group since start of scan: %s", itemString)
		end
	end
	TSM.Auctioning.Log.SetQueryUpdatesPaused(false)
end

function private.GenerateCancels(auctionsDBRow, itemString, groupPath, query)
	local isHandled = false
	for _, operationName, operationSettings in GroupOperation.OperationIterator(groupPath, "Auctioning") do
		if not isHandled and private.IsOperationValid(itemString, operationName, operationSettings) then
			assert(not next(private.subRowsTemp))
			TSM.Auctioning.Util.GetFilteredSubRows(query, itemString, operationSettings, private.subRowsTemp)
			assert(not next(private.listedAuctionTemp))
			private.GetListedAuction(auctionsDBRow, private.listedAuctionTemp)
			local handled, result, seller = private.GenerateCancel(private.listedAuctionTemp, itemString, operationName, operationSettings, private.subRowsTemp)
			local itemBuyout = private.listedAuctionTemp.itemBuyout
			local auctionId = private.listedAuctionTemp.auctionId or 0
			wipe(private.listedAuctionTemp)
			wipe(private.subRowsTemp)
			if result then
				seller = seller or ""
				TSM.Auctioning.Log.AddEntry(itemString, operationName, result, seller, itemBuyout, auctionId)
			end
			isHandled = isHandled or handled
		end
	end
end

function private.GetListedAuction(auctionsDBRow, resultTbl)
	local auctionId, stackSize, currentBid, buyout, highBidder, duration = auctionsDBRow:GetFields("auctionId", "stackSize", "currentBid", "buyout", "highBidder", "duration")
	resultTbl.auctionId = auctionId
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		resultTbl.itemBuyout = floor(buyout / stackSize)
		resultTbl.itemBid = floor(currentBid / stackSize)
	else
		resultTbl.itemBuyout = buyout
		resultTbl.itemBid = currentBid
	end
	resultTbl.stackSize = stackSize
	resultTbl.duration = duration
	resultTbl.hasBid = highBidder ~= "" and not private.settings.cancelWithBid
	resultTbl.canAffordCancel = not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) or C_AuctionHouse.GetCancelCost(auctionId) <= GetMoney()
end

function private.GenerateCancel(listedAuction, itemString, operationName, operationSettings, subRows)
	local lowestAuction = TempTable.Acquire()
	if not TSM.Auctioning.Util.GetLowestAuction(subRows, itemString, operationSettings, lowestAuction) then
		TempTable.Release(lowestAuction)
		lowestAuction = nil
	end
	assert(not next(private.scanResultTemp))
	TSM.Auctioning.Util.GetCancelScanResult(subRows, itemString, operationSettings, lowestAuction, private.scanResultTemp)
	local handled, result = AuctioningOperation.MakeCancelDecision(itemString, operationSettings, lowestAuction, listedAuction, private.scanResultTemp)
	wipe(private.scanResultTemp)
	local seller = lowestAuction and lowestAuction.seller or nil
	if lowestAuction then
		TempTable.Release(lowestAuction)
	end
	if result == AuctioningOperation.RESULT.INVALID.SELLER then
		ChatMessage.PrintfUser(L["The seller name of the lowest auction for %s was not given by the server. Skipping this item."], ItemInfo.GetLink(itemString))
	elseif result == AuctioningOperation.RESULT.CANCELING or result == AuctioningOperation.RESULT.CANCELING_EXCESS then
		private.AddToQueue(itemString, operationName, listedAuction)
	end
	return handled, result, seller
end

function private.AddToQueue(itemString, operationName, listedAuction)
	private.queueDB:NewRow()
		:SetField("auctionId", listedAuction.auctionId)
		:SetField("itemString", itemString)
		:SetField("operationName", operationName)
		:SetField("bid", listedAuction.itemBid * listedAuction.stackSize)
		:SetField("buyout", listedAuction.itemBuyout * listedAuction.stackSize)
		:SetField("itemBid", listedAuction.itemBid)
		:SetField("itemBuyout", listedAuction.itemBuyout)
		:SetField("stackSize", listedAuction.stackSize)
		:SetField("duration", listedAuction.duration)
		:SetField("numStacks", 1)
		:SetField("numProcessed", 0)
		:SetField("numConfirmed", 0)
		:SetField("numFailed", 0)
		:Create()
end

function private.ProcessQueryHelper(row, cancelRow)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		local auctionId, itemString, stackSize, currentBid, buyout = row:GetFields("auctionId", "autoBaseItemString", "stackSize", "currentBid", "buyout")
		local itemBid = floor(currentBid / stackSize)
		local itemBuyout = floor(buyout / stackSize)
		return not private.usedAuctionIndex[itemString..buyout..currentBid..auctionId] and cancelRow:GetField("itemBid") == itemBid and cancelRow:GetField("itemBuyout") == itemBuyout
	else
		local auctionId = row:GetField("auctionId")
		return not private.usedAuctionIndex[auctionId] and cancelRow:GetField("auctionId") == auctionId
	end
end

function private.ConfirmRowQueryHelper(row)
	return row:GetField("numConfirmed") < row:GetField("numProcessed")
end

function private.NextProcessRowQueryHelper(row)
	return row:GetField("numProcessed") < row:GetField("numStacks")
end

function private.StatusQueryToQueueStatus(query)
	return TempTable.Acquire(TSM.Auctioning.Util.GetQueueStatus(query))
end
