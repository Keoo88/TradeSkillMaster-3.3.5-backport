-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local AuctionDB = TSM:NewPackage("AuctionDB")
local L = TSM.Locale.GetTable()
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local AppHelper = TSM.LibTSMApp:Include("Service.AppHelper")
local private = {
	realmData = {},
	realmUpdateTime = nil,
	regionData = {},
	regionUpdateTime = nil,
	altRealmData = {},
	lastScanTemp = {},
	localScanTime = 0,
}
local UPDATE_TIME_KEYS = {
	AUCTIONDB_NON_COMMODITY_DATA = true,
	AUCTIONDB_NON_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_REGION_STAT = true,
	AUCTIONDB_REGION_HISTORICAL = true,
	AUCTIONDB_REGION_SALE = true,
}

-- Fields populated locally on 3.3.5 (no App). Browse scans feed these via
-- AuctionDB.RecordLocalScanResults so DBMinBuyout / DBMarket etc resolve
-- to live data instead of nil. Order matters: index = field position in
-- the shared holder's data tuple.
private.LOCAL_FIELDS = {
	"minBuyout",   -- index 1
	"marketValue", -- index 2
	"numAuctions", -- index 3
}

-- 3.3.5: один shared multi-field holder для всех LOCAL_FIELDS. Все ключи
-- private.realmData указывают на ОДИН holder, чтобы UnpackData возвращал
-- общую таблицу {mb, mv, na} per item, а GetRealmItemData по разным key
-- доставал нужный индекс через fieldLookup.
do
	local holder = { fieldLookup = {}, itemLookup = {} }
	for i, key in ipairs(private.LOCAL_FIELDS) do
		holder.fieldLookup[key] = i
		private.realmData[key] = holder
	end
	private.localHolder = holder
end



-- ============================================================================
-- Module Functions
-- ============================================================================

function AuctionDB.OnEnable()
	-- 3.3.5: expose the in-memory scan recorder so the Scanner (LibTSMService
	-- layer) can refresh DBMinBuyout / DBMarket live after each browse scan,
	-- not just persist to the TradeSkillMaster_AuctionDB SavedVariable. Without
	-- this, freshly scanned items (e.g. a single searched lot) only resolve
	-- after a /reload, when OnEnable re-reads the SavedVariable.
	_G.TSM_AuctionDB_RecordLocalScanResults = AuctionDB.RecordLocalScanResults

	local realmData, regionData, commodityData, altRealmData = AppHelper.GetAuctionDBData()
	private.realmUpdateTime = private.LoadRegionRealmAppData(private.realmData, realmData)
	private.regionUpdateTime = private.LoadRegionRealmAppData(private.regionData, regionData)
	private.LoadRegionRealmAppData(private.realmData, commodityData)
	private.LoadRegionRealmAppData(private.altRealmData, altRealmData)
	if next(private.altRealmData) then
		private.LoadRegionRealmAppData(private.altRealmData, commodityData)
	end

	-- 3.3.5: Load local scan data from TradeSkillMaster_AuctionDB addon
	-- (separate SavedVariable file, written by Scanner.HandleRequestDone).
	-- Schema v2: items[is] = {mb=N, mv=N, na=N, ts=N}
	-- Schema v1: items[is] = N (minBuyout only) — handled via fallback.
	if _G.TSM_AuctionDB_GetRealmData and private.localHolder then
		local localData = _G.TSM_AuctionDB_GetRealmData()
		local count = 0
		local maxTs = 0
		for itemString, record in pairs(localData) do
			local mb, mv, na, ts
			if type(record) == "number" then
				mb = record
			elseif type(record) == "table" then
				mb = record.mb or record.minBuyout
				mv = record.mv or record.marketValue
				na = record.na or record.numAuctions
				ts = record.ts
			end
			if type(mb) == "number" and mb > 0 then
				private.localHolder.itemLookup[itemString] = {
					mb,
					(type(mv) == "number" and mv > 0) and mv or mb,
					(type(na) == "number" and na > 0) and na or 1,
				}
				count = count + 1
				if type(ts) == "number" and ts > maxTs then
					maxTs = ts
				end
			end
		end
		-- 3.3.5: запомнить самое свежее время скана из локальной БД, чтобы
		-- тултип показывал "X auctions (… ago)", а не "Not Scanned".
		if maxTs > 0 then
			private.localScanTime = maxTs
		end
		if count > 0 then
			Log.Info("Loaded %d items from local auction scans (TradeSkillMaster_AuctionDB)", count)
		end
	end

	-- Pre-fetch item info for items currently on the AH
	if private.localHolder then
		for itemString in pairs(private.localHolder.itemLookup) do
			ItemInfo.FetchInfo(itemString)
		end
	end

	-- Only show warning if no realm data AND no local data (for 3.3.5 private servers)
	if private.realmUpdateTime == 0 and not private.localHolder then
		ChatMessage.PrintfUser(L["TSM doesn't currently have any AuctionDB pricing data for your realm. We recommend you download the TSM Desktop Application from %s to automatically update your AuctionDB data (and auto-backup your TSM settings)."], ChatMessage.ColorUserAccentText("https://tradeskillmaster.com"))
	end

	CustomString.InvalidateCache("DBMarket")
	CustomString.InvalidateCache("DBMinBuyout")
	CustomString.InvalidateCache("DBHistorical")
	CustomString.InvalidateCache("DBRecent")
	CustomString.InvalidateCache("DBRegionMarketAvg")
	CustomString.InvalidateCache("DBRegionHistorical")
	CustomString.InvalidateCache("DBRegionSaleAvg")
	CustomString.InvalidateCache("DBRegionSaleRate")
	CustomString.InvalidateCache("DBRegionSoldPerDay")
	collectgarbage()
end

function AuctionDB.GetAppDataUpdateTimes()
	return private.realmUpdateTime, private.regionUpdateTime
end

---Returns the most recent local browse-scan time (3.3.5), or 0 if no local scan.
---Used by the tooltip so the AuctionDB heading shows "X auctions (… ago)"
---instead of "Not Scanned" when only local scan data exists (no TSM App data).
---@return number
function AuctionDB.GetLocalScanTime()
	return private.localScanTime or 0
end

---Returns true if local scan data has been recorded (3.3.5).
---@return boolean
function AuctionDB.HasLocalScanData()
	if not private.localHolder then return false end
	return next(private.localHolder.itemLookup) ~= nil
end

function AuctionDB.LastScanIteratorThreaded()
	wipe(private.lastScanTemp)
	local minBuyoutData = private.realmData and private.realmData.minBuyout
	if not minBuyoutData or not minBuyoutData.itemLookup or not minBuyoutData.fieldLookup then
		return pairs(private.lastScanTemp)
	end
	local minBuyoutIndex = minBuyoutData.fieldLookup.minBuyout
	if not minBuyoutIndex then
		return pairs(private.lastScanTemp)
	end
	local baseItems = Threading.AcquireSafeTempTable()
	for itemString in pairs(minBuyoutData.itemLookup) do
		local unpacked = private.UnpackData(minBuyoutData, itemString)
		local minBuyout = type(unpacked) == "table" and unpacked[minBuyoutIndex] or nil
		itemString = ItemString.Get(itemString)
		if itemString then
			local baseItemString = ItemString.GetBaseFast(itemString)
			if baseItemString ~= itemString then
				baseItems[baseItemString] = true
			end
			if type(minBuyout) == "number" and minBuyout > 0 then
				local existing = private.lastScanTemp[itemString]
				if type(existing) ~= "number" then
					existing = math.huge
				end
				private.lastScanTemp[itemString] = min(existing, minBuyout)
			end
		end
		Threading.Yield()
	end

	-- remove the base items since they would be double-counted with the specific variants
	for itemString in pairs(baseItems) do
		private.lastScanTemp[itemString] = nil
	end
	TempTable.Release(baseItems)

	return pairs(private.lastScanTemp)
end

function AuctionDB.GetRealmItemData(itemString, key)
	return private.GetItemDataHelper(private.realmData[key], key, itemString)
end

function AuctionDB.GetAltRealmItemData(itemString, key)
	return private.GetItemDataHelper(private.altRealmData[key], key, itemString)
end

function AuctionDB.GetRegionItemData(itemString, key)
	local result = private.GetItemDataHelper(private.regionData[key], key, itemString)
	if key == "regionSalePercent" or key == "regionSoldPerDay" then
		result = result and (result / 1000) or nil
	end
	return result
end

---Записывает результаты локального browse-скана для использования как fallback
---когда AppHelper не отдал AuctionDB данные (3.3.5 без TSM Desktop App).
---Совместим с двумя форматами входа:
---  legacy: { [itemString] = { minBuyout=N, marketValue=N?, numAuctions=N? } }
---  v2:     { [itemString] = { mb=N, mv=N?, na=N? } }
---@param results table
function AuctionDB.RecordLocalScanResults(results)
	if type(results) ~= "table" or not private.localHolder then return end
	local count = 0
	for itemString, data in pairs(results) do
		itemString = ItemString.Get(itemString) or itemString
		if type(data) == "table" then
			local mb = data.mb or data.minBuyout
			local mv = data.mv or data.marketValue
			local na = data.na or data.numAuctions
			if type(mb) == "number" and mb > 0 then
				private.localHolder.itemLookup[itemString] = {
					mb,
					(type(mv) == "number" and mv > 0) and mv or mb,
					(type(na) == "number" and na > 0) and na or 1,
				}
				count = count + 1
			end
		end
	end
	if count > 0 then
		-- 3.3.5: отметить время скана, чтобы тултип ушёл с "Not Scanned"
		-- сразу после поиска/скана, без /reload.
		private.localScanTime = time()
		CustomString.InvalidateCache("DBMarket")
		CustomString.InvalidateCache("DBMinBuyout")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadRegionRealmAppData(tbl, appData)
	local maxUpdateTime = 0
	for key, data in pairs(appData) do
		local loadedData, updateTime = private.LoadAppData(data)
		local existing = tbl[next(loadedData.fieldLookup)]
		if existing then
			-- Merge items into existing realmData
			assert(Table.Equal(existing.fieldLookup, loadedData.fieldLookup))
			for itemString, itemData in pairs(loadedData.itemLookup) do
				if existing.itemLookup[itemString] then
					error("Duplicate data for item: "..tostring(itemString))
				end
				existing.itemLookup[itemString] = itemData
			end
		else
			for field in pairs(loadedData.fieldLookup) do
				assert(not tbl[field])
				tbl[field] = loadedData
			end
		end
		Log.Info("Loaded %s data (%s)", key, SecondsToTime(time() - updateTime).." ago")
		if UPDATE_TIME_KEYS[key] then
			maxUpdateTime = max(maxUpdateTime, updateTime)
		end
	end
	return maxUpdateTime
end

function private.LoadAppData(appData)
	-- Extract the metadata from the start of the string
	local metadataEndIndex, dataStartIndex = strfind(appData, ",data={")
	local itemData = strsub(appData, dataStartIndex + 1, -3)
	local metadataStr = strsub(appData, 1, metadataEndIndex - 1).."}"
	local metadata = assert(loadstring(metadataStr))()

	local result = { fieldLookup = {}, itemLookup = {} }
	assert(metadata.fields[1] == "itemString")
	for i = 2, #metadata.fields do
		result.fieldLookup[metadata.fields[i]] = i - 1
	end

	for itemString, otherData in gmatch(itemData, "{\"?([^,\"]+)\"?,([^}]+)}") do
		if tonumber(itemString) then
			itemString = "i:"..itemString
		end
		result.itemLookup[itemString] = otherData
	end

	return result, metadata.downloadTime
end

function private.GetItemDataHelper(tbl, key, itemString)
	if not itemString or not tbl then
		return nil
	end
	local fieldIndex = tbl.fieldLookup[key]
	if not fieldIndex then
		return nil
	end
	-- Convert to a level item string
	itemString = ItemString.ToLevel(itemString)
	if not tbl.itemLookup[itemString] then
		-- Try the base item
		itemString = ItemString.GetBaseFast(itemString)
		if not tbl.itemLookup[itemString] then
			return nil
		end
	end
	local data = private.UnpackData(tbl, itemString)
	local value = data and data[fieldIndex] or 0
	return value > 0 and value or nil
end

function private.UnpackData(tbl, itemString)
	local data = tbl.itemLookup[itemString]
	if type(data) ~= "string" then
		return data
	end
	-- Need to unpack the data
	local tblData = {strsplit(",", data)}
	for i = 1, #tblData do
		local val = tblData[i]
		if #val > 6 then
			-- tonumber only works for 32-bit values, so need to cut the value in half
			val = tonumber(strsub(val, -6), 32) + tonumber(strsub(val, 1, -7), 32) * (2 ^ 30)
		else
			val = tonumber(val, 32)
		end
		tblData[i] = val
	end
	tbl.itemLookup[itemString] = tblData
	data = tblData
	return data
end
