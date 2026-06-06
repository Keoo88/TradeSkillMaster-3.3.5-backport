-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local PostScan = TSM.Auctioning:NewPackage("PostScan") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local Database = TSM.LibTSMUtil:Include("Database")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local SlotId = TSM.LibTSMWoW:Include("Type.SlotId")
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Container = TSM.LibTSMWoW:Include("API.Container")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local Operation = TSM.LibTSMTypes:Include("Operation")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local AuctionHouseWrapper = TSM.LibTSMWoW:Include("API.AuctionHouseWrapper")
local private = {
	settings = nil,
	scanThreadId = nil,
	queueDB = nil,
	nextQueueAuctionId = -1,
	bagDB = nil,
	itemList = {},
	operationDB = nil,
	debugLog = {},
	subRowsTemp = {},
	groupsQuery = nil, --luacheck: ignore 1004 - just stored for GC reasons
	operationsQuery = nil, --luacheck: ignore 1004 - just stored for GC reasons
	operationsChangedTimer = nil,
	currentRowQuery = nil,
	statusQuery = nil,
}
local MAX_COMMODITY_STACKS_PER_AUCTION = 40



-- ============================================================================
-- Module Functions
-- ============================================================================

function PostScan.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctioningOptions", "disableInvalidMsg")
		:AddKey("global", "auctioningOptions", "matchWhitelist")
	private.operationsChangedTimer = DelayTimer.New("POST_SCAN_OPERATIONS_CHANGED", private.UpdateOperationDB)
	BagTracking.RegisterQuantityCallback(private.UpdateOperationDB)
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.UpdateOperationDB, true)
	private.operationDB = Database.NewSchema("AUCTIONING_OPERATIONS")
		:AddUniqueStringField("autoBaseItemString")
		:AddStringField("firstOperation")
		:Commit()
	private.scanThreadId = Threading.New("POST_SCAN", private.ScanThread)
	private.queueDB = Database.NewSchema("AUCTIONING_POST_QUEUE")
		:AddNumberField("auctionId")
		:AddStringField("itemString")
		:AddStringField("operationName")
		:AddNumberField("bid")
		:AddNumberField("buyout")
		:AddNumberField("itemBid")
		:AddNumberField("itemBuyout")
		:AddNumberField("stackSize")
		:AddNumberField("numStacks")
		:AddNumberField("postTime")
		:AddNumberField("numProcessed")
		:AddNumberField("numConfirmed")
		:AddNumberField("numFailed")
		:AddIndex("auctionId")
		:AddIndex("itemString")
		:Commit()
	-- We maintain our own bag database rather than using the one in BagTracking since we need to be able to remove items
	-- as they are posted, without waiting for bag update events, and control when our DB updates.
	private.bagDB = Database.NewSchema("AUCTIONING_POST_BAGS")
		:AddStringField("itemString")
		:AddNumberField("bag")
		:AddNumberField("slot")
		:AddNumberField("quantity")
		:AddUniqueNumberField("slotId")
		:AddIndex("itemString")
		:AddIndex("slotId")
		:Commit()
	-- Create a groups and operations query just to register for updates
	private.groupsQuery = GroupOperation.CreateQuery()
		:SetUpdateCallback(private.OnGroupsOperationsChanged)
	private.operationsQuery = Operation.NewQuery()
		:SetUpdateCallback(private.OnGroupsOperationsChanged)
	-- Create our queries
	private.currentRowQuery = private.queueDB:NewQuery()
		:Custom(private.NextProcessRowQueryHelper)
		:OrderBy("auctionId", false)
	private.statusQuery = private.queueDB:NewQuery()
end

function PostScan.CreateBagsQuery()
	return BagTracking.CreateQueryBagsAuctionable()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:VirtualField("name", "string", ItemInfo.GetName, "autoBaseItemString", "")
		:VirtualField("groupPath", "string", Group.GetPathByItem, "itemString", "")
		:Distinct("autoBaseItemString")
		:LeftJoin(private.operationDB, "autoBaseItemString")
end

function PostScan.Prepare()
	return private.scanThreadId
end

function PostScan.CurrentRowPublisher()
	return private.currentRowQuery:Publisher()
		:MapToValue(private.currentRowQuery)
		:MapWithMethod("GetFirstResult")
end

function PostScan.StatusQueryPublisher()
	return private.statusQuery:Publisher()
		:MapToValue(private.statusQuery)
		:MapWithFunction(private.StatusQueryToQueueStatus)
end

function PostScan.DoProcess()
	local result, noRetry = nil, false
	local postRow = private.currentRowQuery:GetFirstResult()
	if not postRow then
		return false, false
	end
	local itemString, stackSize, bid, buyout, itemBuyout, postTime = postRow:GetFields("itemString", "stackSize", "bid", "buyout", "itemBuyout", "postTime")
	local bag, slot = private.GetPostBagSlot(itemString, stackSize)
	if bag then
		local bagQuantity = Container.GetStackCount(bag, slot)
		Log.Info("Posting %s x %d from %d,%d (%d)", itemString, stackSize, bag, slot, bagQuantity or -1)
		ChatMessage.PrintfUser("DEBUG: Posting %s x%d", tostring(itemString), stackSize)
		if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
			result = AuctionHouseWrapper.PostAuction(bag, slot, postTime, stackSize, 1, bid, buyout)
		else
			result = AuctionHouseWrapper.PostAuction(bag, slot, postTime, stackSize, 1, bid / stackSize, itemBuyout)
		end
		if not result then
			Log.Err("Failed to post (%s, %s, %s)", itemString, bag, slot)
		end
	else
		-- we couldn't find this item, so mark this post as failed and we'll try again later
		result = false
		noRetry = slot
		if noRetry then
			ChatMessage.PrintfUser(L["Failed to post %sx%d as the item no longer exists in your bags."], ItemInfo.GetLink(itemString), stackSize)
		end
	end
	if result then
		private.DebugLogInsert(itemString, "Posting %d from %d, %d", stackSize, bag, slot)
		if postRow:GetField("numProcessed") + 1 == postRow:GetField("numStacks") then
			-- update the log
			local auctionId = postRow:GetField("auctionId")
			TSM.Auctioning.Log.UpdateRowByIndex(auctionId, "state", "POSTED")
		end
	end
	postRow:SetField("numProcessed", postRow:GetField("numProcessed") + 1)
		:Update()
	return result, noRetry
end

function PostScan.DoSkip()
	local postRow = private.currentRowQuery:GetFirstResult()
	local auctionId = postRow:GetField("auctionId")
	local numStacks = postRow:GetField("numStacks")
	postRow:SetField("numProcessed", numStacks)
		:SetField("numConfirmed", numStacks)
		:Update()
	-- Update the log
	TSM.Auctioning.Log.UpdateRowByIndex(auctionId, "state", "SKIPPED")
end

function PostScan.HandleConfirm(success, canRetry)
	if not success then
		ClearCursor()
	end

	local confirmRow = private.queueDB:NewQuery()
		:Custom(private.ConfirmRowQueryHelper)
		:OrderBy("auctionId", false)
		:GetFirstResultAndRelease()
	if not confirmRow then
		-- we may have posted something outside of TSM
		return
	end

	private.DebugLogInsert(confirmRow:GetField("itemString"), "HandleConfirm(success=%s) x %d", tostring(success), confirmRow:GetField("stackSize"))
	if canRetry then
		assert(not success)
		confirmRow:SetField("numFailed", confirmRow:GetField("numFailed") + 1)
	end
	confirmRow:SetField("numConfirmed", confirmRow:GetField("numConfirmed") + 1)
		:Update()
	confirmRow:Release()
end

function PostScan.PrepareFailedPosts()
	private.queueDB:SetQueryUpdatesPaused(true)
	local query = private.queueDB:NewQuery()
		:GreaterThan("numFailed", 0)
		:OrderBy("auctionId", false)
	for _, row in query:Iterator() do
		local numFailed, numProcessed, numConfirmed = row:GetFields("numFailed", "numProcessed", "numConfirmed")
		assert(numProcessed >= numFailed and numConfirmed >= numFailed)
		private.DebugLogInsert(row:GetField("itemString"), "Preparing failed (%d, %d, %d)", numFailed, numProcessed, numConfirmed)
		row:SetField("numFailed", 0)
			:SetField("numProcessed", numProcessed - numFailed)
			:SetField("numConfirmed", numConfirmed - numFailed)
			:Update()
	end
	query:Release()
	private.queueDB:SetQueryUpdatesPaused(false)
	private.UpdateBagDB()
end

function PostScan.Reset()
	private.queueDB:Truncate()
	private.nextQueueAuctionId = -1
	private.bagDB:Truncate()
end

function PostScan.ChangePostDetail(field, value)
	local postRow = private.currentRowQuery:GetFirstResult()
	local isCommodity = ItemInfo.IsCommodity(postRow:GetField("itemString"))
	if field == "bid" or field == "itemBid" then
		assert(not isCommodity)
		value = max(value, 1)
		local stackSize = postRow:GetField("stackSize")
		local itemBid = field == "itemBid" and value or floor(value / stackSize)
		local itemBuyout = postRow:GetField("itemBuyout")
		if itemBuyout > 0 then
			itemBid = min(itemBid, itemBuyout)
		end
		postRow:SetField("bid", itemBid * stackSize)
		postRow:SetField("itemBid", itemBid)
	elseif field == "buyout" or field == "itemBuyout" then
		local stackSize = postRow:GetField("stackSize")
		local itemBuyout = field == "itemBuyout" and value or floor(value / stackSize)
		if isCommodity or (itemBuyout > 0 and itemBuyout < postRow:GetField("itemBid")) then
			postRow:SetField("bid", itemBuyout * stackSize)
			postRow:SetField("itemBid", itemBuyout)
		end
		TSM.Auctioning.Log.UpdateRowByIndex(postRow:GetField("auctionId"), "buyout", itemBuyout)
		postRow:SetField("buyout", itemBuyout * stackSize)
		postRow:SetField("itemBuyout", itemBuyout)
	elseif field == "postTime" then
		postRow:SetField("postTime", value)
	else
		error("Invalid field: "..tostring(field))
	end
	postRow:Update()
end



-- ============================================================================
-- Private Helper Functions (General)
-- ============================================================================

function private.OnGroupsOperationsChanged()
	private.operationsChangedTimer:RunForFrames(1)
end

function private.UpdateOperationDB()
	if not DefaultUI.IsAuctionHouseVisible() then
		return
	end
	private.operationDB:TruncateAndBulkInsertStart()
	local query = BagTracking.CreateQueryBagsAuctionable()
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Select("autoBaseItemString")
		:Distinct("autoBaseItemString")
	for _, itemString in query:Iterator() do
		local firstOperation = TSM.Operations.GetFirstOperationByItem("Auctioning", itemString)
		if firstOperation then
			private.operationDB:BulkInsertNewRow(itemString, firstOperation)
		end
	end
	query:Release()
	private.operationDB:BulkInsertEnd()
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

function private.ScanThread(auctionScan, scanContext)
	wipe(private.debugLog)
	auctionScan:SetScript("OnQueryDone", private.AuctionScanOnQueryDone)
	private.UpdateBagDB()

	-- get the state of the player's bags
	local bagCounts = TempTable.Acquire()
	local bagQuery = private.bagDB:NewQuery()
		:Select("itemString", "quantity")
	for _, itemString, quantity in bagQuery:Iterator() do
		bagCounts[itemString] = (bagCounts[itemString] or 0) + quantity
	end
	bagQuery:Release()

	-- generate the list of items we want to scan for
	wipe(private.itemList)
	for itemString, numHave in pairs(bagCounts) do
		private.DebugLogInsert(itemString, "Scan thread has %d", numHave)
		local groupPath = Group.GetPathByItem(itemString)
		local contextFilter = scanContext.isItems and itemString or groupPath
		if groupPath and tContains(scanContext, contextFilter) and private.CanPostItem(itemString, groupPath, numHave) then
			tinsert(private.itemList, itemString)
		end
	end
	TempTable.Release(bagCounts)
	if #private.itemList == 0 then
		return
	end
	-- record this search
	TSM.Auctioning.SavedSearches.RecordSearch(scanContext, scanContext.isItems and "postItems" or "postGroups")

	-- run the scan
	auctionScan:AddItemListQueriesThreaded(private.itemList)
	for _, query in auctionScan:QueryIterator() do
		query:SetIsBrowseDoneFunction(private.QueryIsBrowseDoneFunction)
		query:AddCustomFilter(private.QueryBuyoutFilter)
	end
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
end



-- ============================================================================
-- Private Helper Functions for Scanning
-- ============================================================================

function private.UpdateBagDB()
	-- 3.3.5: the login-time BAG_UPDATE events for non-backpack bags are unreliable,
	-- so BagTracking's slotDB can be empty/partial here. Force a fresh full bag scan
	-- right before we read it so the post scan always sees the real bag contents.
	BagTracking.RescanAllBags()
	private.bagDB:TruncateAndBulkInsertStart()
	local count = 0
	local query = BagTracking.CreateQueryBagsAuctionable()
		:OrderBy("slotId", true)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Select("slotId", "bag", "slot", "autoBaseItemString", "quantity")
	for _, slotId, bag, slot, itemString, quantity in query:Iterator() do
		private.DebugLogInsert(itemString, "Updating bag DB with %d in %d, %d", quantity, bag, slot)
		private.bagDB:BulkInsertNewRow(itemString, bag, slot, quantity, slotId)
		count = count + 1
	end
	query:Release()
	private.bagDB:BulkInsertEnd()
	-- DIAGNOSTIC: count bag slots at each filter stage to locate where items are lost
	local nAll, nBags, nNotBound = 0, 0, 0
	local diagAll = BagTracking.CreateQueryBagsBank():Select("slotId")
	for _ in diagAll:Iterator() do nAll = nAll + 1 end
	diagAll:Release()
	local diagBags = BagTracking.CreateQueryBags():Select("slotId")
	for _ in diagBags:Iterator() do nBags = nBags + 1 end
	diagBags:Release()
	local diagNotBound = BagTracking.CreateQueryBags():Equal("isBound", false):Select("slotId")
	for _ in diagNotBound:Iterator() do nNotBound = nNotBound + 1 end
	diagNotBound:Release()
	local apiSlots, apiFilled = 0, 0
	for bag = Container.GetBackpackContainer(), Container.GetNumBags() do
		local ns = Container.GetNumSlots(bag) or 0
		apiSlots = apiSlots + ns
		for slot = 1, ns do
			if Container.GetItemLink(bag, slot) then apiFilled = apiFilled + 1 end
		end
	end
	ChatMessage.PrintfUser("DEBUG: slots all=%d bagsRange=%d notBound=%d auctionable=%d", nAll, nBags, nNotBound, count)
	ChatMessage.PrintfUser("DEBUG: API numBags=%d apiSlots=%d apiFilled=%d", Container.GetNumBags(), apiSlots, apiFilled)
	ChatMessage.PrintfUser("DEBUG: UpdateBagDB found %d items in bags", count)
end

function private.CanPostItem(itemString, groupPath, numHave)
	if TSMDBG then
		TSMDBG.Log("PostScan", "CanPostItem itemString=%s groupPath=%s numHave=%d", tostring(itemString), tostring(groupPath), numHave)
	end
	local hasValidOperation, hasInvalidOperation = false, false
	for _, operationName, operationSettings in GroupOperation.OperationIterator(groupPath, "Auctioning") do
		if TSMDBG then
			TSMDBG.Log("PostScan", "  Checking operation=%s", tostring(operationName))
		end
		local isValid, numUsed = private.IsOperationValid(itemString, numHave, operationName, operationSettings)
		if TSMDBG then
			TSMDBG.Log("PostScan", "  Operation %s: isValid=%s numUsed=%s", tostring(operationName), tostring(isValid), tostring(numUsed))
		end
		if isValid == true then
			assert(numUsed and numUsed > 0)
			numHave = numHave - numUsed
			hasValidOperation = true
		elseif isValid == false then
			hasInvalidOperation = true
		else
			-- we are ignoring this operation
			assert(isValid == nil, "Invalid return value")
		end
	end

	local result = hasValidOperation and not hasInvalidOperation
	if TSMDBG then
		TSMDBG.Log("PostScan", "  Result: hasValid=%s hasInvalid=%s canPost=%s", tostring(hasValidOperation), tostring(hasInvalidOperation), tostring(result))
	end
	return result
end

function private.IsOperationValid(itemString, num, operationName, operationSettings, noLog)
	local shouldPost, errTypeOrNum, errArg, errArg2 = AuctioningOperation.ValidateForPosting(itemString, num, operationName, operationSettings)
	if TSMDBG then
		TSMDBG.Log("PostScan", "IsOperationValid itemString=%s operation=%s shouldPost=%s errType=%s",
			tostring(itemString), tostring(operationName), tostring(shouldPost), tostring(errTypeOrNum))
	end
	if shouldPost then
		local minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operationSettings)
		local vendorSellPrice = ItemInfo.GetVendorSell(itemString) or 0
		if vendorSellPrice > 0 and minPrice <= vendorSellPrice / 0.95 and not noLog then
			-- Just a warning, not an error
			ChatMessage.PrintfUser(L["WARNING: Your minimum price for %s is below its vendorsell price (with AH cut taken into account). Consider raising your minimum price, or vendoring the item."], ItemInfo.GetLink(itemString))
		end
		return shouldPost, errTypeOrNum
	elseif errTypeOrNum == nil then
		return shouldPost
	end

	if errTypeOrNum == AuctioningOperation.RESULT.INVALID.ITEM_GROUP then
		if not private.settings.disableInvalidMsg then
			private.PrintInvalidGroupError(itemString, errTypeOrNum, errArg, errArg2)
		end
	elseif errTypeOrNum ~= AuctioningOperation.RESULT.NOT_POSTING then
		error("Unknown result: "..tostring(errTypeOrNum))
	end
	if not noLog then
		TSM.Auctioning.Log.AddEntry(itemString, operationName, errTypeOrNum, "", 0, math.huge)
	end
	return shouldPost
end

function private.PrintInvalidGroupError(itemString, errType, errArg, errArg2)
	local itemLink = ItemInfo.GetLink(itemString)
	if errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.POST_CAP then
		ChatMessage.PrintfUser(L["Did not post %s because your post cap (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.STACK_SIZE then
		if errArg then
			ChatMessage.PrintfUser(L["Did not post %s because your stack size (%s) is invalid. Check your settings."], itemLink, errArg)
		else
			ChatMessage.PrintfUser(L["Did not post %s because Blizzard didn't provide all necessary information for it. Try again later."], itemLink)
		end
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.KEEP_QUANTITY then
		ChatMessage.PrintfUser(L["Did not post %s because your keep quantity (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_EXPIRES then
		ChatMessage.PrintfUser(L["Did not post %s because your max expires (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MIN_PRICE then
		ChatMessage.PrintfUser(L["Did not post %s because your minimum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_PRICE then
		ChatMessage.PrintfUser(L["Did not post %s because your maximum price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_PRICE then
		ChatMessage.PrintfUser(L["Did not post %s because your normal price (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.UNDERCUT then
		ChatMessage.PrintfUser(L["Did not post %s because your undercut (%s) is invalid. Check your settings."], itemLink, errArg)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.NORMAL_BELOW_MIN then
		ChatMessage.PrintfUser(L["Did not post %s because your normal price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	elseif errType == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.MAX_BELOW_MIN then
		ChatMessage.PrintfUser(L["Did not post %s because your maximum price (%s) is lower than your minimum price (%s). Check your settings."], itemLink, errArg, errArg2)
	else
		error("Unknown error type: "..tostring(errType))
	end
end

function private.QueryBuyoutFilter(_, row)
	local _, itemBuyout, minItemBuyout = row:GetBuyouts()
	return (itemBuyout and itemBuyout == 0) or (minItemBuyout and minItemBuyout == 0)
end

function private.QueryIsBrowseDoneFunction(query)
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
		return false
	end
	local isDone = true
	for itemString in query:ItemIterator() do
		isDone = isDone and private.QueryIsBrowseDoneForItem(query, itemString)
	end
	return isDone
end

function private.QueryIsBrowseDoneForItem(query, itemString)
	local groupPath = Group.GetPathByItem(itemString)
	if not groupPath then
		return true
	end
	local isFilterDone = true
	for _, _, operationSettings in GroupOperation.OperationIterator(groupPath, "Auctioning") do
		if isFilterDone then
			local numBuyouts, minItemBuyout, maxItemBuyout = 0, nil, nil
			for _, subRow in query:ItemSubRowIterator(itemString) do
				local _, itemBuyout = subRow:GetBuyouts()
				local timeLeft = subRow:GetListingInfo()
				local quantity = subRow:GetQuantities()
				if not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
					numBuyouts = numBuyouts + 1
					minItemBuyout = min(minItemBuyout or math.huge, itemBuyout)
					maxItemBuyout = max(maxItemBuyout or 0, itemBuyout)
				end
			end
			if numBuyouts <= 1 then
				-- There is only one distinct item buyout, so can't stop yet
				isFilterDone = false
			elseif AuctioningOperation.ShouldKeepScanningForPosting(itemString, operationSettings, minItemBuyout, maxItemBuyout) then
				isFilterDone = false
			end
		end
	end
	return isFilterDone
end

function private.AuctionScanOnQueryDone(_, query)
	for itemString in query:ItemIterator() do
		local groupPath = Group.GetPathByItem(itemString)
		if groupPath then
			local numHave = 0
			local bagQuery = private.bagDB:NewQuery()
				:Select("quantity", "bag", "slot")
				:Equal("itemString", itemString)
			for _, quantity, bag, slot in bagQuery:Iterator() do
				numHave = numHave + quantity
				private.DebugLogInsert(itemString, "Filter done and have %d in %d, %d", numHave, bag, slot)
			end
			bagQuery:Release()

			for _, operationName, operationSettings in GroupOperation.OperationIterator(groupPath, "Auctioning") do
				if private.IsOperationValid(itemString, numHave, operationName, operationSettings, true) then
					local keepQuantity = AuctioningOperation.GetItemPrice(itemString, "keepQuantity", operationSettings)
					assert(keepQuantity)
					local operationNumHave = numHave - keepQuantity
					if operationNumHave > 0 then
						assert(not next(private.subRowsTemp))
						TSM.Auctioning.Util.GetFilteredSubRows(query, itemString, operationSettings, private.subRowsTemp)
						local reason, numUsed, itemBuyout, seller, auctionId = private.GeneratePosts(itemString, operationName, operationSettings, operationNumHave, private.subRowsTemp)
						wipe(private.subRowsTemp)
						numHave = numHave - (numUsed or 0)
						seller = seller or ""
						auctionId = auctionId or -math.huge
						TSM.Auctioning.Log.AddEntry(itemString, operationName, reason, seller, itemBuyout or 0, auctionId)
					end
				end
			end
			assert(numHave >= 0)
		else
			Log.Warn("Item removed from group since start of scan: %s", itemString)
		end
	end
end

function private.GeneratePosts(itemString, operationName, operationSettings, numHave, subRows)
	local maxCanPost, perAuction, postCap = AuctioningOperation.GetPostQuantities(itemString, operationSettings, numHave)
	if not maxCanPost then
		return AuctioningOperation.RESULT.NOT_POSTING.NOT_ENOUGH
	end

	local lowestAuction = TempTable.Acquire()
	if not TSM.Auctioning.Util.GetLowestAuction(subRows, itemString, operationSettings, lowestAuction) then
		TempTable.Release(lowestAuction)
		lowestAuction = nil
	end
	local reason, seller, bid, buyout, activeAuctionsBid, activeAuctionsBuyout = AuctioningOperation.MakePostDecision(itemString, lowestAuction, operationSettings, private.settings.matchWhitelist)
	if reason == AuctioningOperation.RESULT.INVALID.SELLER then
		ChatMessage.PrintfUser(L["The seller name of the lowest auction for %s was not given by the server. Skipping this item."], ItemInfo.GetLink(itemString))
	elseif reason == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.ALT_BLACKLISTED then
		ChatMessage.PrintfUser(L["Did not post %s because you or one of your alts (%s) is on the blacklist which is not allowed. Remove this character from your blacklist."], ItemInfo.GetLink(itemString), lowestAuction.seller)
	elseif reason == AuctioningOperation.RESULT.INVALID.ITEM_GROUP.BLACKLIST_WHITELIST then
		ChatMessage.PrintfUser(L["Did not post %s because the owner of the lowest auction (%s) is on both the blacklist and whitelist which is not allowed. Adjust your settings to correct this issue."], ItemInfo.GetLink(itemString), lowestAuction.seller)
	end
	if lowestAuction then
		TempTable.Release(lowestAuction)
	end
	if reason ~= AuctioningOperation.RESULT.POSTING then
		return reason, nil, nil, seller
	end
	local activeAuctions = 0
	if activeAuctionsBid or activeAuctionsBuyout then
		activeAuctions = TSM.Auctioning.Util.GetPlayerAuctionCount(subRows, itemString, operationSettings, activeAuctionsBid, activeAuctionsBuyout, perAuction)
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_COPPER) then
		bid = floor(bid)
	else
		bid = max(Math.Round(bid, COPPER_PER_SILVER), COPPER_PER_SILVER)
		buyout = max(Math.Round(buyout, COPPER_PER_SILVER), COPPER_PER_SILVER)
	end

	bid = min(bid, ClientInfo.HasFeature(ClientInfo.FEATURES.AH_COPPER) and MAXIMUM_BID_PRICE or MAXIMUM_BID_PRICE - 99)
	buyout = min(buyout, ClientInfo.HasFeature(ClientInfo.FEATURES.AH_COPPER) and MAXIMUM_BID_PRICE or MAXIMUM_BID_PRICE - 99)

	-- Check if we can't post anymore
	local queueQuery = private.queueDB:NewQuery()
		:Select("numStacks")
		:Equal("itemString", itemString)
		:Equal("stackSize", perAuction)
		:Equal("itemBuyout", buyout)
	for _, numStacks in queueQuery:Iterator() do
		activeAuctions = activeAuctions + numStacks
	end
	queueQuery:Release()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		maxCanPost = min(postCap - activeAuctions, maxCanPost)
	else
		perAuction = min(postCap - activeAuctions, perAuction)
	end
	if maxCanPost <= 0 or perAuction <= 0 then
		return AuctioningOperation.RESULT.POSTING_NOT_NEEDED.TOO_MANY
	end

	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and (bid * perAuction > MAXIMUM_BID_PRICE or buyout * perAuction > MAXIMUM_BID_PRICE) then
		ChatMessage.PrintfUser(L["The buyout price for %s would be above the maximum allowed price. Skipping this item."], ItemInfo.GetLink(itemString))
		return AuctioningOperation.RESULT.INVALID.ITEM_GROUP.OTHER
	end

	-- Insert the posts into our DB
	local auctionId = private.nextQueueAuctionId
	local postTime, stackSizeIsCap = AuctioningOperation.GetPostSettings(operationSettings)
	local extraStack = 0
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS)  then
		private.AddToQueue(itemString, operationName, bid, buyout, perAuction, maxCanPost, postTime)
		-- Check if we can post an extra partial stack
		extraStack = (maxCanPost < postCap and stackSizeIsCap and (numHave % perAuction)) or 0
	else
		assert(maxCanPost == 1)
		if ItemInfo.IsCommodity(itemString) then
			local maxPerAuction = ItemInfo.GetMaxStack(itemString) * MAX_COMMODITY_STACKS_PER_AUCTION
			maxCanPost = floor(perAuction / maxPerAuction)
			-- Check if we can post an extra partial stack
			extraStack = perAuction % maxPerAuction
			perAuction = min(perAuction, maxPerAuction)
			bid = buyout
		else
			-- Post non-commodities as single stacks
			maxCanPost = perAuction
			perAuction = 1
		end
		assert(maxCanPost > 0 or extraStack > 0)
		if maxCanPost > 0 then
			private.AddToQueue(itemString, operationName, bid, buyout, perAuction, maxCanPost, postTime)
		end
	end
	if extraStack > 0 then
		private.AddToQueue(itemString, operationName, bid, buyout, extraStack, 1, postTime)
	end
	return reason, (perAuction * maxCanPost) + extraStack, buyout, seller, auctionId
end

function private.AddToQueue(itemString, operationName, itemBid, itemBuyout, stackSize, numStacks, postTime)
	private.DebugLogInsert(itemString, "Queued %d stacks of %d", stackSize, numStacks)
	private.queueDB:NewRow()
		:SetField("auctionId", private.nextQueueAuctionId)
		:SetField("itemString", itemString)
		:SetField("operationName", operationName)
		:SetField("bid", itemBid * stackSize)
		:SetField("buyout", itemBuyout * stackSize)
		:SetField("itemBid", itemBid)
		:SetField("itemBuyout", itemBuyout)
		:SetField("stackSize", stackSize)
		:SetField("numStacks", numStacks)
		:SetField("postTime", postTime)
		:SetField("numProcessed", 0)
		:SetField("numConfirmed", 0)
		:SetField("numFailed", 0)
		:Create()
	private.nextQueueAuctionId = private.nextQueueAuctionId - 1
end



-- ============================================================================
-- Private Helper Functions for Posting
-- ============================================================================

function private.GetPostBagSlot(itemString, quantity)
	-- start with the slot which is closest to the desired stack size
	local bag, slot = private.bagDB:NewQuery()
		:Select("bag", "slot")
		:Equal("itemString", itemString)
		:GreaterThanOrEqual("quantity", quantity)
		:OrderBy("quantity", true)
		:GetFirstResultAndRelease()
	if not bag then
		bag, slot = private.bagDB:NewQuery()
			:Select("bag", "slot")
			:Equal("itemString", itemString)
			:LessThanOrEqual("quantity", quantity)
			:OrderBy("quantity", false)
			:GetFirstResultAndRelease()
	end
	if not bag or not slot then
		-- this item was likely removed from the player's bags, so just give up
		Log.Err("Failed to find initial bag / slot (%s, %d)", itemString, quantity)
		return nil, true
	end
	local removeContext = TempTable.Acquire()
	bag, slot = private.ItemBagSlotHelper(itemString, bag, slot, quantity, removeContext)

	local bagItemString = ItemString.Get(Container.GetItemLink(bag, slot))
	if not bagItemString or Group.TranslateItemString(bagItemString) ~= itemString then
		-- something changed with the player's bags so we can't post the item right now
		TempTable.Release(removeContext)
		private.DebugLogInsert(itemString, "Bags changed")
		return nil, nil
	end

	-- On WoW 3.3.5, quality check is unreliable because ItemInfo loads asynchronously
	-- If we have a valid itemLink, the item exists and can be posted
	-- Skip quality check entirely for Classic
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local _, _, quality = Container.GetItemInfo(bag, slot)
		if quality == -1 then
			-- the game client doesn't have item info cached for this item, so we can't post it yet
			TempTable.Release(removeContext)
			private.DebugLogInsert(itemString, "No item info")
			return nil, nil
		end
	end
	for slotId, removeQuantity in pairs(removeContext) do
		private.RemoveBagQuantity(slotId, removeQuantity)
	end
	TempTable.Release(removeContext)
	private.DebugLogInsert(itemString, "GetPostBagSlot(%d) -> %d, %d", quantity, bag, slot)
	return bag, slot
end

function private.ItemBagSlotHelper(itemString, bag, slot, quantity, removeContext)
	local slotId = SlotId.Join(bag, slot)

	-- try to post completely from the selected slot
	local found = private.bagDB:NewQuery()
		:Select("slotId")
		:Equal("slotId", slotId)
		:GreaterThanOrEqual("quantity", quantity)
		:GetFirstResultAndRelease()
	if found then
		removeContext[slotId] = quantity
		return bag, slot
	end

	-- try to find a stack at a lower slot which has enough to post from
	local foundSlotId, foundBag, foundSlot = private.bagDB:NewQuery()
		:Select("slotId", "bag", "slot")
		:Equal("itemString", itemString)
		:LessThan("slotId", slotId)
		:GreaterThanOrEqual("quantity", quantity)
		:OrderBy("slotId", true)
		:GetFirstResultAndRelease()
	if foundSlotId then
		removeContext[foundSlotId] = quantity
		return foundBag, foundSlot
	end

	-- try to post using the selected slot and the lower slots
	local selectedQuantity = private.bagDB:NewQuery()
		:Select("quantity")
		:Equal("slotId", slotId)
		:GetFirstResultAndRelease()
	local query = private.bagDB:NewQuery()
		:Select("slotId", "quantity")
		:Equal("itemString", itemString)
		:LessThan("slotId", slotId)
		:OrderBy("slotId", true)
	local numNeeded = quantity - selectedQuantity
	local numUsed = 0
	local usedSlotIds = TempTable.Acquire()
	for _, rowSlotId, rowQuantity in query:Iterator() do
		if numNeeded ~= numUsed then
			numUsed = min(numUsed + rowQuantity, numNeeded)
			tinsert(usedSlotIds, rowSlotId)
		end
	end
	query:Release()
	if numNeeded == numUsed then
		removeContext[slotId] = selectedQuantity
		for _, rowSlotId in TempTable.Iterator(usedSlotIds) do
			local rowQuantity = private.bagDB:GetUniqueRowField("slotId", rowSlotId, "quantity")
			local rowNumUsed = min(numUsed, rowQuantity)
			numUsed = numUsed - rowNumUsed
			removeContext[rowSlotId] = (removeContext[rowSlotId] or 0) + rowNumUsed
		end
		return bag, slot
	else
		TempTable.Release(usedSlotIds)
	end

	-- try posting from the next highest slot
	local rowBag, rowSlot = private.bagDB:NewQuery()
		:Select("bag", "slot")
		:Equal("itemString", itemString)
		:GreaterThan("slotId", slotId)
		:OrderBy("slotId", true)
		:GetFirstResultAndRelease()
	if not rowBag or not rowSlot then
		private.ErrorForItem(itemString, "Failed to find next highest bag / slot")
	end
	return private.ItemBagSlotHelper(itemString, rowBag, rowSlot, quantity, removeContext)
end

function private.RemoveBagQuantity(slotId, quantity)
	local row = private.bagDB:GetUniqueRow("slotId", slotId)
	local remainingQuantity = row:GetField("quantity") - quantity
	private.DebugLogInsert(row:GetField("itemString"), "Removing %d (%d remain) from %d", quantity, remainingQuantity, slotId)
	if remainingQuantity > 0 then
		row:SetField("quantity", remainingQuantity)
			:Update()
	else
		assert(remainingQuantity == 0)
		private.bagDB:DeleteRow(row)
	end
	row:Release()
end

function private.ConfirmRowQueryHelper(row)
	return row:GetField("numConfirmed") < row:GetField("numProcessed")
end

function private.NextProcessRowQueryHelper(row)
	return row:GetField("numProcessed") < row:GetField("numStacks")
end

function private.DebugLogInsert(itemString, ...)
	Table.InsertMultiple(private.debugLog, itemString, format(...))
end

function private.ErrorForItem(itemString, errorStr)
	for _, debugItemString, msg in Table.StrideIterator(private.debugLog, 2) do
		if debugItemString == itemString then
			Log.Info(msg)
		end
	end
	Log.Info("Bag state:")
	for _, slotId in Container.GetBagSlotIterator() do
		local bag, slot = SlotId.Split(slotId)
		if ItemString.GetBase(Container.GetItemLink(bag, slot)) == itemString then
			local stackSize = Container.GetStackCount(bag, slot)
			Log.Info("%d in %d, %d", stackSize, bag, slot)
		end
	end
	error(errorStr, 2)
end

function private.StatusQueryToQueueStatus(query)
	return TempTable.Acquire(TSM.Auctioning.Util.GetQueueStatus(query))
end
