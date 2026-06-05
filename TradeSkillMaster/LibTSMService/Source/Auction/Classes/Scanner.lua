-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:Init("Auction.Scanner")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Database = LibTSMService:From("LibTSMUtil"):Include("Database")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Analytics = LibTSMService:From("LibTSMUtil"):Include("Util.Analytics")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {
	indexDB = nil,
	quantityDB = nil,
	baseItemQuantityQuery = nil,
	updateQuery = nil, -- luacheck: ignore 1004 - just stored for GC reasons
	quantityStorage = nil,
	scanTimer = nil,
	backgroundScanTimer = nil,
	updateThrottleTimer = nil,
	indexUpdates = {
		list = {},
		pending = {},
	},
	prevLogTime = 0,
	prevLogNum = -1,
	indexCallbacks = {},
	indexCallbacksThrottled = {},
	quantityCallbacks = {},
	ignoreUpdateEvent = false,
	lastScanNum = nil,
	cancelAuctionId = nil,
	summaryInfo = {
		numPosted = 0,
		numSold = 0,
		postedGold = 0,
		soldGold = 0,
	},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	private.indexDB = Database.NewSchema("AUCTION_TRACKING_INDEX")
		:AddUniqueNumberField("index")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddStringField("itemLink")
		:AddStringField("itemTexture") -- 3.3.5: string path; retail: numeric FileID
		:AddStringField("itemName")
		:AddNumberField("itemQuality")
		:AddNumberField("duration")
		:AddStringField("highBidder")
		:AddNumberField("currentBid")
		:AddNumberField("buyout")
		:AddNumberField("stackSize")
		:AddBooleanField("isSold")
		:AddNumberField("auctionId")
		:AddIndex("index")
		:AddIndex("isSold")
		:AddIndex("auctionId")
		:Commit()
	private.quantityDB = Database.NewSchema("AUCTION_TRACKING_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("auctionQuantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewQuery()
		:Select("auctionQuantity")
		:Equal("baseItemString", Database.BoundQueryParam())
	private.updateQuery = private.indexDB:NewQuery()
		:SetUpdateCallback(private.OnCallbackQueryUpdated)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param quantityData table<string,number> Auction item quantities
function Scanner.Load(quantityData)
	private.quantityStorage = quantityData
end

---Starts running the auction tracking code.
function Scanner.Start()
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.AuctionHouseVisibilityHandler)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		Event.Register("OWNED_AUCTIONS_UPDATED", private.OwnedAuctionsUpdateHandler)
		Event.Register("AUCTION_CANCELED", private.AuctionCanceledHandler)
		AuctionHouse.SecureHookCancel(function(auctionId)
			private.cancelAuctionId = auctionId
		end)
	else
		Event.Register("AUCTION_OWNED_LIST_UPDATE", private.OwnedAuctionsUpdateHandler)
	end
	private.scanTimer = DelayTimer.New("AUCTION_TRACKING_SCAN", private.ScanTimerHandler)
	private.backgroundScanTimer = DelayTimer.New("AUCTION_TRACKING_BACKGROUND_SCAN", private.DoBackgroundScan)
	private.updateThrottleTimer = DelayTimer.New("AUCTION_TRACKING_UPDATE_THROTTLE", private.HandleThrottledUpdate)
	private.RebuildQuantityDB()
end

---Registers a callback for when the index DB changes.
---@param callback fun() The callback function
function Scanner.RegisterIndexCallback(callback)
	tinsert(private.indexCallbacks, callback)
end

---Registers a callback for when the index DB changes which is throttled to not be too spammy.
---@param callback fun() The callback function
function Scanner.RegisterThrottledIndexCallback(callback)
	tinsert(private.indexCallbacksThrottled, callback)
end

---Registers a callback for when the auction quantity changes.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function Scanner.RegisterQuantityCallback(func)
	tinsert(private.quantityCallbacks, func)
end

---Creates a new query against the index DB.
---@return DatabaseQuery
function Scanner.NewIndexQuery()
	return private.indexDB:NewQuery()
end

---Creates a new query against the index DB.
---@return DatabaseQuery
function Scanner.NewQuantityQuery()
	return private.quantityDB:NewQuery()
end

---Gets the quantity of a given item.
---@param itemString string The item string
---@return number
function Scanner.GetQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("auctionQuantity")
	else
		local levelItemString = ItemString.ToLevel(itemString)
		return private.quantityDB:GetUniqueRowField("levelItemString", levelItemString, "auctionQuantity") or 0
	end
end

---Gets summary info if the AH is visible.
---@return number? numPosted
---@return number? numSold
---@return number? postedGold
---@return number? soldGold
function Scanner.GetSummaryInfo()
	if not DefaultUI.IsAuctionHouseVisible() then
		return nil, nil, nil, nil
	end
	return private.summaryInfo.numPosted, private.summaryInfo.numSold, private.summaryInfo.postedGold, private.summaryInfo.soldGold
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AuctionHouseVisibilityHandler(visible)
	if visible then
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
			-- We don't always get AUCTION_OWNED_LIST_UPDATE events, so do our own scanning if needed
			private.backgroundScanTimer:RunForTime(1)
		end
	else
		private.backgroundScanTimer:Cancel()
	end
end

function private.OwnedAuctionsUpdateHandler()
	if private.ignoreUpdateEvent then
		return
	end
	wipe(private.indexUpdates.pending)
	wipe(private.indexUpdates.list)
	for i = 1, AuctionHouse.GetNumOwned() do
		if not private.indexUpdates.pending[i] then
			private.indexUpdates.pending[i] = true
			tinsert(private.indexUpdates.list, i)
		end
	end
	private.scanTimer:RunForFrames(2)
end

function private.AuctionCanceledHandler(_, auctionId)
	if not private.cancelAuctionId or auctionId ~= 0 then
		-- An auction was sold, so everything will be rescanned
		return
	end
	local row = private.indexDB:NewQuery()
		:Equal("auctionId", private.cancelAuctionId)
		:GetFirstResultAndRelease()
	private.cancelAuctionId = nil
	if not row then
		return
	end

	local levelItemString = row:GetField("levelItemString")
	local stackSize = row:GetField("stackSize")
	assert(stackSize <= private.quantityStorage[levelItemString])
	private.quantityStorage[levelItemString] = private.quantityStorage[levelItemString] - stackSize
	private.RebuildQuantityDB()
	private.indexDB:DeleteRow(row)
	row:Release()
end

function private.ScanTimerHandler()
	if not DefaultUI.IsAuctionHouseVisible() then
		-- AH not visible, so can't scan
		return
	elseif DefaultUI.IsDefaultOwnedAuctionTabVisible() then
		-- Default UI auctions tab is visible, so scan later
		private.scanTimer:RunForFrames(2)
		return
	elseif not AuctionHouse.OwnedFullyLoaded() then
		-- Don't have all the results yet, so try again in a moment
		private.scanTimer:RunForFrames(2)
		return
	end

	-- Check if we need to change the sort
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and not AuctionHouse.AreOwnedSortedByOwnerDuration() then
		Log.Info("Sorting owner auctions")
		-- Ignore events while changing the sort
		private.ignoreUpdateEvent = true
		AuctionHouse.SortOwnedByOwnerDuration()
		private.ignoreUpdateEvent = false
	end

	-- Do the scan
	private.ScanOwnedAuctions()
	if #private.indexUpdates.list > 0 then
		-- Some failed to scan so try again
		private.scanTimer:RunForFrames(2)
	else
		private.lastScanNum = AuctionHouse.GetNumOwned()
	end
end

function private.DoBackgroundScan()
	private.backgroundScanTimer:RunForTime(1)
	if AuctionHouse.GetNumOwned() ~= private.lastScanNum then
		private.OwnedAuctionsUpdateHandler()
	end
end

function private.ScanOwnedAuctions()
	-- Scan the auctions
	local shouldLog = LibTSMService.GetTime() - private.prevLogTime > 5
	if shouldLog then
		private.prevLogTime = LibTSMService.GetTime()
	end

	wipe(private.quantityStorage)
	private.indexDB:TruncateAndBulkInsertStart()
	for i, index in Table.ReverseIPairs(private.indexUpdates.list) do
		local auctionId, link, name, texture, stackSize, quality, currentBid, buyout, highBidder, isSold, duration = private.GetOwnedAuctionInfo(index)
		if auctionId == math.huge then
			-- This is a wow token which we ignore
			private.indexUpdates.pending[index] = nil
			tremove(private.indexUpdates.list, i)
		elseif link then
			local itemString = ItemString.Get(link)
			if not isSold then
				local levelItemString = ItemString.ToLevel(itemString)
				private.quantityStorage[levelItemString] = (private.quantityStorage[levelItemString] or 0) + stackSize
			end
			private.indexUpdates.pending[index] = nil
			tremove(private.indexUpdates.list, i)
			private.indexDB:BulkInsertNewRow(index, itemString, link, texture, name, quality, duration, highBidder, currentBid, buyout, stackSize, isSold, auctionId)
		elseif shouldLog then
			Log.Warn("Missing info (%s, %s, %s, %s)", gsub(tostring(link), "\124", "\\124"), tostring(name), tostring(texture), tostring(quality))
			if link and strmatch(link, "item:") and LibTSMService.IsRetail() then
				Analytics.Action("AUCTION_TRACKING_MISSING_INFO", link)
			end
		end
	end
	private.RebuildQuantityDB()
	private.indexDB:BulkInsertEnd()

	if shouldLog or #private.indexUpdates.list ~= private.prevLogNum then
		Log.Info("Scanned auctions (left=%d)", #private.indexUpdates.list)
		private.prevLogNum = #private.indexUpdates.list
	end
end

function private.GetOwnedAuctionInfo(index)
	local auctionId, link, name, texture, stackSize, quality, currentBid, buyout, highBidder, isSold, duration = AuctionHouse.GetOwnedInfo(index)
	if not link then
		-- Just return the auctionId in case it's indicating a token
		return auctionId
	end
	if type(link) == "number" and ItemInfo.IsCommodity(link) then
		link = ItemInfo.GetLink(link)
	end
	if not link then
		return
	end
	name = name or ItemInfo.GetName(link)
	texture = texture or ItemInfo.GetTexture(link)
	quality = quality or ItemInfo.GetQuality(link)
	if not name or not texture or not quality then
		return
	end
	texture = tostring(texture)
	return auctionId, link, name, texture, stackSize, quality, currentBid, buyout, highBidder, isSold, duration
end

function private.RebuildQuantityDB()
	-- Sanitize the storage table
	for levelItemString, quantity in pairs(private.quantityStorage) do
		if quantity <= 0 then
			private.quantityStorage[levelItemString] = nil
		end
	end
	local prevQuantities = TempTable.Acquire()
	private.quantityDB:NewQuery()
		:Select("levelItemString", "auctionQuantity")
		:AsTable(prevQuantities)
		:Release()
	private.quantityDB:TruncateAndBulkInsertStart()
	for levelItemString, quantity in pairs(private.quantityStorage) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
	local updatedItems = TempTable.Acquire()
	Table.GetChangedKeys(prevQuantities, private.quantityStorage, updatedItems)
	TempTable.Release(prevQuantities)
	if next(updatedItems) then
		-- Add the base items
		local baseItemStrings = TempTable.Acquire()
		for levelItemString in pairs(updatedItems) do
			baseItemStrings[ItemString.GetBaseFast(levelItemString)] = true
		end
		for baseItemString in pairs(baseItemStrings) do
			updatedItems[baseItemString] = true
		end
		TempTable.Release(baseItemStrings)
		for _, callback in ipairs(private.quantityCallbacks) do
			callback(updatedItems)
		end
	end
	TempTable.Release(updatedItems)
end

function private.OnCallbackQueryUpdated()
	for _, callback in ipairs(private.indexCallbacks) do
		callback()
	end
	private.updateThrottleTimer:RunForTime(0.5)
end

function private.HandleThrottledUpdate()
	-- Update the summary info
	private.summaryInfo.numPosted = 0
	private.summaryInfo.numSold = 0
	private.summaryInfo.postedGold = 0
	private.summaryInfo.soldGold = 0
	local query = private.indexDB:NewQuery()
		:Select("itemString", "isSold", "buyout", "currentBid", "stackSize")
	for _, itemString, isSold, buyout, currentBid, stackSize in query:Iterator() do
		if isSold then
			private.summaryInfo.numSold = private.summaryInfo.numSold + 1
			-- If somebody did a buyout, then bid will be equal to buyout, otherwise it'll be the winning bid
			private.summaryInfo.soldGold = private.summaryInfo.soldGold + currentBid
		else
			private.summaryInfo.numPosted = private.summaryInfo.numPosted + 1
			if ItemInfo.IsCommodity(itemString) then
				private.summaryInfo.postedGold = private.summaryInfo.postedGold + (buyout * stackSize)
			else
				private.summaryInfo.postedGold = private.summaryInfo.postedGold + buyout
			end
		end
	end
	query:Release()

	for _, callback in ipairs(private.indexCallbacksThrottled) do
		callback()
	end
end
