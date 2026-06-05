-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Auctions = TSM.Accounting:NewPackage("Auctions") ---@type AddonPackage
local SmartMap = TSM.LibTSMUtil:IncludeClassType("SmartMap")
local Database = TSM.LibTSMUtil:Include("Database")
local CSV = TSM.LibTSMUtil:Include("Format.CSV")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local Group = TSM.LibTSMTypes:Include("Group")
local private = {
	settings = nil,
	db = nil,
	numExpiresQuery = nil,
	dataChanged = false,
	statsQuery = nil,
	statsTemp = {},
	filteredItemStringSmartMap = nil,
	filteredItemMode = "specific",
}
local COMBINE_TIME_THRESHOLD = 300 -- group expenses within 5 minutes together
local REMOVE_OLD_THRESHOLD = 180 * 24 * 60 * 60 -- remove records over 6 months old
local SECONDS_PER_DAY = 24 * 60 * 60
local CSV_KEYS = { "itemString", "stackSize", "quantity", "player", "time" }



-- ============================================================================
-- Module Functions
-- ============================================================================

function Auctions.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("realm", "internalData", "csvCancelled")
		:AddKey("realm", "internalData", "saveTimeCancels")
		:AddKey("realm", "internalData", "csvExpired")
		:AddKey("realm", "internalData", "saveTimeExpires")
		:AddKey("global", "coreOptions", "regionWide")
	private.db = Database.NewSchema("ACCOUNTING_AUCTIONS")
		:AddStringField("baseItemString")
		:AddStringField("type")
		:AddStringField("itemString")
		:AddNumberField("stackSize")
		:AddNumberField("quantity")
		:AddStringField("player")
		:AddNumberField("time")
		:AddNumberField("saveTime")
		:AddBooleanField("isCurrentRealm")
		:AddIndex("baseItemString")
		:AddIndex("time")
		:Commit()
	private.numExpiresQuery = private.db:NewQuery()
		:Select("quantity")
		:Equal("type", "expire")
		:Equal("baseItemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())
	private.statsQuery = private.db:NewQuery()
		:Select("type", "quantity")
		:Equal("baseItemString", Database.BoundQueryParam())
		:GreaterThanOrEqual("time", Database.BoundQueryParam())

	private.filteredItemStringSmartMap = SmartMap.New("string", "string", private.FilteredItemStringLookup)

	private.db:BulkInsertStart()
	for _, csvCancelled, realm in private.settings:AccessibleValueIterator("csvCancelled") do
		local saveTimeCancels = private.settings:GetForScopeKey("saveTimeCancels", realm)
		private.LoadData("cancel", csvCancelled, saveTimeCancels, realm == SessionInfo.GetRealmName())
	end
	for _, csvExpired, realm in private.settings:AccessibleValueIterator("csvExpired") do
		local saveTimeExpires = private.settings:GetForScopeKey("saveTimeExpires", realm)
		private.LoadData("expire", csvExpired, saveTimeExpires, realm == SessionInfo.GetRealmName())
	end
	private.db:BulkInsertEnd()
	CustomString.InvalidateCache("NumExpires")
end

function Auctions.OnDisable()
	if not private.dataChanged then
		-- nothing changed, so no need to save
		return
	end
	local cancelSaveTimes, expireSaveTimes = {}, {}
	local cancelEncodeContext = CSV.EncodeStart(CSV_KEYS)
	local expireEncodeContext = CSV.EncodeStart(CSV_KEYS)
	-- order by time to speed up loading
	local query = private.db:NewQuery()
		:Select("type", "itemString", "stackSize", "quantity", "player", "time", "saveTime")
		:OrderBy("time", true)
		:Equal("isCurrentRealm", true)
	for _, recordType, itemString, stackSize, quantity, player, timestamp, saveTime in query:Iterator() do
		local saveTimes, encodeContext = nil, nil
		if recordType == "cancel" then
			saveTimes = cancelSaveTimes
			encodeContext = cancelEncodeContext
		elseif recordType == "expire" then
			saveTimes = expireSaveTimes
			encodeContext = expireEncodeContext
		else
			error("Invalid recordType: "..tostring(recordType))
		end
		-- add the save time
		tinsert(saveTimes, saveTime ~= 0 and saveTime or time())
		-- add to our list of CSV lines
		CSV.EncodeAddRowDataRaw(encodeContext, itemString, stackSize, quantity, player, timestamp)
	end
	query:Release()
	private.settings.csvCancelled = CSV.EncodeEnd(cancelEncodeContext)
	private.settings.saveTimeCancels = table.concat(cancelSaveTimes, ",")
	private.settings.csvExpired = CSV.EncodeEnd(expireEncodeContext)
	private.settings.saveTimeExpires = table.concat(expireSaveTimes, ",")
end

function Auctions.InsertCancel(itemString, stackSize, timestamp)
	private.InsertRecord("cancel", itemString, stackSize, timestamp)
end

function Auctions.InsertExpire(itemString, stackSize, timestamp)
	private.InsertRecord("expire", itemString, stackSize, timestamp)
end

function Auctions.GetStats(itemString, minTime)
	private.statsQuery:BindParams(ItemString.GetBase(itemString), minTime or 0)
	wipe(private.statsTemp)
	private.statsQuery:GroupedSum("type", "quantity", private.statsTemp)
	local cancel = private.statsTemp.cancel or 0
	local expire = private.statsTemp.expire or 0
	local total = cancel + expire
	return cancel, expire, total
end

function Auctions.GetNumExpires(itemString, minTime)
	private.numExpiresQuery:BindParams(ItemString.GetBase(itemString), minTime or 0)
	local num = 0
	for _, quantity in private.numExpiresQuery:Iterator() do
		num = num + quantity
	end
	return num
end

function Auctions.GetNumExpiresSinceSale(itemString)
	return Auctions.GetNumExpires(itemString, TSM.Accounting.Transactions.GetLastSaleTime(itemString))
end

function Auctions.CreateQuery()
	return private.db:NewQuery()
		:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

function Auctions.AddSmartMap(query)
	query:VirtualSmartMapField("filteredItemString", private.filteredItemStringSmartMap, "itemString")
		:LeftJoin(Group.GetItemDBForJoin(), "filteredItemString", "itemString")
end

function Auctions.UpdateSmartMap(itemStringFilter)
	private.filteredItemMode = itemStringFilter
	private.filteredItemStringSmartMap:Invalidate()
end

function Auctions.RemoveOldData(days)
	private.dataChanged = true
	private.db:SetQueryUpdatesPaused(true)
	local numRecords = private.db:NewQuery()
		:LessThan("time", time() - days * SECONDS_PER_DAY)
		:Equal("isCurrentRealm", true)
		:DeleteAndRelease()
	private.db:SetQueryUpdatesPaused(false)
	CustomString.InvalidateCache("NumExpires")
	return numRecords
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData(recordType, csvRecords, csvSaveTimes, isCurrentRealm)
	local saveTimes = String.SafeSplit(csvSaveTimes, ",")
	if not saveTimes then
		return
	end

	local decodeContext = CSV.DecodeStart(csvRecords, CSV_KEYS)
	if not decodeContext then
		Log.Err("Failed to decode %s records", recordType)
		private.dataChanged = true
		return
	end

	local removeTime = time() - REMOVE_OLD_THRESHOLD
	local index = 1
	local prevTimestamp = 0
	for itemString, stackSize, quantity, player, timestamp in CSV.DecodeIterator(decodeContext) do
		itemString = ItemString.Get(itemString)
		local baseItemString = ItemString.GetBaseFast(itemString)
		local saveTime = tonumber(saveTimes[index])
		stackSize = tonumber(stackSize)
		quantity = tonumber(quantity)
		timestamp = tonumber(timestamp)
		if itemString and baseItemString and stackSize and quantity and timestamp and saveTime and timestamp > removeTime then
			local newTimestamp = floor(timestamp)
			if newTimestamp ~= timestamp then
				-- make sure all timestamps are stored as integers
				private.dataChanged = true
				timestamp = newTimestamp
			end
			if timestamp < prevTimestamp then
				-- not ordered by timestamp
				private.dataChanged = true
			end
			prevTimestamp = timestamp
			private.db:BulkInsertNewRowFast9(baseItemString, recordType, itemString, stackSize, quantity, player, timestamp, saveTime, isCurrentRealm)
		else
			private.dataChanged = true
		end
		index = index + 1
	end

	if not CSV.DecodeEnd(decodeContext) then
		Log.Err("Failed to decode %s records", recordType)
		private.dataChanged = true
	end
end

function private.InsertRecord(recordType, itemString, stackSize, timestamp)
	private.dataChanged = true
	assert(itemString and stackSize and stackSize > 0 and timestamp)
	timestamp = floor(timestamp)
	local baseItemString = ItemString.GetBase(itemString)
	local matchingRow = private.db:NewQuery()
		:Equal("type", recordType)
		:Equal("baseItemString", baseItemString)
		:Equal("itemString", itemString)
		:Equal("stackSize", stackSize)
		:Equal("player", UnitName("player"))
		:GreaterThan("time", timestamp - COMBINE_TIME_THRESHOLD)
		:LessThan("time", timestamp + COMBINE_TIME_THRESHOLD)
		:Equal("saveTime", 0)
		:Equal("isCurrentRealm", true)
		:GetFirstResultAndRelease()
	if matchingRow then
		matchingRow:SetField("quantity", matchingRow:GetField("quantity") + stackSize)
		matchingRow:Update()
		matchingRow:Release()
	else
		private.db:NewRow()
			:SetField("baseItemString", baseItemString)
			:SetField("type", recordType)
			:SetField("itemString", itemString)
			:SetField("stackSize", stackSize)
			:SetField("quantity", stackSize)
			:SetField("player", UnitName("player"))
			:SetField("time", timestamp)
			:SetField("saveTime", 0)
			:SetField("isCurrentRealm", true)
			:Create()
	end

	if recordType == "expire" then
		CustomString.InvalidateCache("NumExpires", itemString)
	end
end

function private.FilteredItemStringLookup(itemString)
	if private.filteredItemMode == "level" then
		return ItemString.ToLevel(itemString)
	elseif private.filteredItemMode == "base" then
		return ItemString.GetBase(itemString)
	elseif private.filteredItemMode == "specific" then
		return itemString
	else
		error("Invalid item mode: "..tostring(private.filteredItemMode))
	end
end
