-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AddonSettings = LibTSMApp:Init("Service.AddonSettings")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local StaticPopupDialog = LibTSMApp:From("LibTSMWoW"):IncludeClassType("StaticPopupDialog")
local Settings = LibTSMApp:From("LibTSMTypes"):Include("Settings")
local Schema = LibTSMApp:From("LibTSMSystem"):Include("AddonSettings.Schema")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local CSV = LibTSMApp:From("LibTSMUtil"):Include("Format.CSV")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local LibRealmInfo = LibStub("LibRealmInfo")
local private = {
	db = nil,
	loadCallbacks = {},
}
local LOAD_WARNING_THRESHOLD = 0.02



-- ============================================================================
-- Module Loading
-- ============================================================================

---Loads the addon settings database.
function AddonSettings.LoadDB()
	local connectedRealms = nil
	if LibTSMApp then
		connectedRealms = {}
		local realmId, _, _, _, _, _, _, _, connectedRealmIds = LibRealmInfo:GetRealmInfo(SessionInfo.GetRealmName())
		if connectedRealmIds then
			for _, id in ipairs(connectedRealmIds) do
				if id ~= realmId then
					local _, connectedRealmName = LibRealmInfo:GetRealmInfoByID(id)
					if connectedRealmName then
						tinsert(connectedRealms, connectedRealmName)
					end
				end
			end
		end
	end
	local factionName = SessionInfo.GetFactionName()
	local accessibleFactions = nil
	if LibTSMApp.IsRetail() then
		accessibleFactions = { "Horde", "Alliance", "Neutral" }
	else
		accessibleFactions = { factionName }
	end
	local db, upgradeObj = Settings.NewDB("TradeSkillMasterDB", Schema.Get(), SessionInfo.GetRealmName(), factionName, SessionInfo.GetCharacterName(), connectedRealms, accessibleFactions)
	if upgradeObj then
		private.ProcessUpgrade(db, upgradeObj)
	end
	private.db = db
	for _, callback in ipairs(private.loadCallbacks) do
		local startTime = LibTSMApp.GetTime()
		callback(db)
		local timeTaken = LibTSMApp.GetTime() - startTime
		if timeTaken > LOAD_WARNING_THRESHOLD then
			Log.Warn("Loading settings for %s took %0.5fs", private.loadCallbacks[callback], timeTaken)
		end
	end
	wipe(private.loadCallbacks)
end

---Register a callback when the settings are loaded.
---@param debugName string A name used for debugging
---@param callback fun(db: SettingsDB) The callback function
function AddonSettings.RegisterOnLoad(debugName, callback)
	assert(not private.db and not private.loadCallbacks[callback])
	tinsert(private.loadCallbacks, callback)
	private.loadCallbacks[callback] = debugName
end

---Gets the addon settings DB
---@return SettingsDB
function AddonSettings.GetDB()
	assert(private.db)
	return private.db
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ProcessUpgrade(db, upgradeObj)
	local prevVersion = upgradeObj:GetPrevVersion()
	if prevVersion < 19 then
		-- migrate inventory data to the sync scope
		local oldInventoryData = TempTable.Acquire()
		local oldSyncMetadata = TempTable.Acquire()
		local oldAccountKey = TempTable.Acquire()
		local oldCharacters = TempTable.Acquire()
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, nil, "inventory") do
			oldInventoryData[upgradeObj:GetScopeKey(key)] = value
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, nil, "syncMetadata") do
			oldSyncMetadata[upgradeObj:GetScopeKey(key)] = value
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, nil, "accountKey") do
			oldAccountKey[upgradeObj:GetScopeKey(key)] = value
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, nil, "characters") do
			oldCharacters[upgradeObj:GetScopeKey(key)] = value
		end
		for factionrealm, characters in pairs(oldInventoryData) do
			local syncMetadata = oldSyncMetadata[factionrealm] and oldSyncMetadata[factionrealm].TSM_CHARACTERS
			for character, inventoryData in pairs(characters) do
				if not syncMetadata or not syncMetadata[character] or syncMetadata[character].owner == oldAccountKey[factionrealm] then
					db:NewSyncCharacter(db:GetLocalSyncAccountKey(factionrealm), character, factionrealm)
					local syncScopeKey = db:GetSyncScopeKeyByCharacter(character, factionrealm)
					local class = oldCharacters[factionrealm] and oldCharacters[factionrealm][character]
					if type(class) == "string" then
						db:Set("sync", syncScopeKey, "internalData", "classKey", class)
					end
					db:Set("sync", syncScopeKey, "internalData", "bagQuantity", inventoryData.bag)
					db:Set("sync", syncScopeKey, "internalData", "bankQuantity", inventoryData.bank)
					db:Set("sync", syncScopeKey, "internalData", "auctionQuantity", inventoryData.auction)
					db:Set("sync", syncScopeKey, "internalData", "mailQuantity", inventoryData.mail)
				end
			end
		end
		TempTable.Release(oldInventoryData)
		TempTable.Release(oldSyncMetadata)
		TempTable.Release(oldAccountKey)
		TempTable.Release(oldCharacters)
	end
	if prevVersion < 25 then
		-- migrate gold log info
		local NEW_CSV_COLS = { "minute", "copper" }
		local function ConvertGoldLogFormat(data)
			local decodedData = select(2, CSV.Decode(data))
			if not decodedData then
				return
			end
			for _, entry in ipairs(decodedData) do
				local minute = entry.startMinute
				local copper = entry.copper
				wipe(entry)
				entry.minute = minute
				entry.copper = copper
			end
			return CSV.Encode(NEW_CSV_COLS, decodedData)
		end
		local GOLD_LOG_FACTIONS = {
			"Horde",
			"Alliance",
			"Neutral",
		}
		local function ProcessGoldLogData(character, data, realm)
			if type(data) ~= "string" then
				return
			end
			-- check if we know about this character and under what faction
			local syncScopeKey = nil
			for _, faction in ipairs(GOLD_LOG_FACTIONS) do
				local factionrealm = faction.." - "..realm
				local testSyncScopeKey = db:GetSyncScopeKeyByCharacter(character, factionrealm)
				if db:Get("sync", testSyncScopeKey, "internalData", "classKey") then
					syncScopeKey = testSyncScopeKey
				end
			end
			if syncScopeKey then
				db:Set("sync", syncScopeKey, "internalData", "goldLog", ConvertGoldLogFormat(data))
			else
				-- check if this is a known guild
				local found = false
				for _, faction in ipairs(GOLD_LOG_FACTIONS) do
					local factionrealm = faction.." - "..realm
					local characterGuilds = db:Get("factionrealm", factionrealm, "internalData", "characterGuilds")
					if not found and characterGuilds and Table.KeyByValue(characterGuilds, character) then
						local guildGoldLog = db:Get("factionrealm", factionrealm, "internalData", "guildGoldLog") or {}
						guildGoldLog[character] = ConvertGoldLogFormat(data)
						db:Set("factionrealm", factionrealm, "internalData", "guildGoldLog", guildGoldLog)
						found = true
					end
				end
			end
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("realm", nil, nil, "goldLog") do
			local scopeKey = upgradeObj:GetScopeKey(key)
			for character, data in pairs(value) do
				ProcessGoldLogData(character, data, scopeKey)
			end
		end
	end
	if prevVersion < 36 then
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, nil, "playerProfessions") do
			local factionrealm = upgradeObj:GetScopeKey(key)
			for character, data in pairs(value) do
				-- check if we know about this character
				local syncScopeKey = db:GetSyncScopeKeyByCharacter(character, factionrealm)
				if db:Get("sync", syncScopeKey, "internalData", "classKey") then
					db:Set("sync", syncScopeKey, "internalData", "playerProfessions", data)
				end
			end
		end
	end
	if prevVersion < 64 then
		local hadValue = false
		for _, _, value in upgradeObj:RemovedSettingIterator("global", nil, "accountingOptions", "smartBuyPrice") do
			hadValue = hadValue or value
		end
		if hadValue then
			-- show a dialog to inform the user that this was removed
			StaticPopupDialog.ShowWithOk(L["The 'use smart average for purchase price' setting has been removed from TSM and replaced with a new 'SmartAvgBuy' price source. Please update your custom prices appropriately."])
		end
	end
	if prevVersion < 89 then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "craftingOptions", "defaultCraftPriceMethod") do
			-- preserve the previous value
			db:Set("global", upgradeObj:GetScopeKey(key), "craftingOptions", "defaultCraftPriceMethod", value)
		end
	end
	if prevVersion < 96 then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "userData", "savedShoppingSearches") do
			-- convert how they are stored
			local newTbl = db:Get("global", upgradeObj:GetScopeKey(key), "userData", "savedShoppingSearches")
			for i, searchInfo in ipairs(value) do
				local filter = searchInfo.filter
				if searchInfo.name ~= filter then
					newTbl.name[filter] = searchInfo.name
				end
				if searchInfo.isFavorite then
					newTbl.isFavorite[filter] = true
				end
				newTbl.filters[i] = filter
			end
		end

		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "userData", "savedAuctioningSearches") do
			-- convert how they are stored
			local newTbl = db:Get("global", upgradeObj:GetScopeKey(key), "userData", "savedAuctioningSearches")
			for i, searchInfo in ipairs(value) do
				local filter = searchInfo.filter
				if searchInfo.name ~= filter then
					newTbl.name[filter] = searchInfo.name
				end
				if searchInfo.isFavorite then
					newTbl.isFavorite[filter] = true
				end
				newTbl.filters[i] = filter
				newTbl.searchTypes[i] = searchInfo.searchType
			end
		end
	end
	if prevVersion < 105 and LibTSMApp.IsRetail() then
		for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "userData", "craftingCooldownIgnore") do
			if prevVersion < 99 then
				local IGNORED_COOLDOWN_SEP = "\001"
				local newValue = {}
				for entry in pairs(value) do
					local characterKey, spellId = strsplit(IGNORED_COOLDOWN_SEP, entry)
					newValue[characterKey..IGNORED_COOLDOWN_SEP.."c:"..spellId] = true
				end
				value = newValue
			end
			db:Set("factionrealm", upgradeObj:GetScopeKey(key), "userData", "craftingCooldownIgnore", value)
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("char", nil, "internalData", "craftingCooldowns") do
			if prevVersion < 99 then
				local newValue = {}
				for spellId, data in pairs(value) do
					newValue["c:"..spellId] = data
				end
				value = newValue
			end
			db:Set("char", upgradeObj:GetScopeKey(key), "internalData", "craftingCooldowns", value)
		end
	end
	if prevVersion < 108 then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "tooltipOptions", "moduleTooltips") do
			-- update AuctionDB.{marketValue,regionMarketValue} values
			if value.AuctionDB then
				value.AuctionDB.marketValue = value.AuctionDB.marketValue and "withTrend" or "none"
				value.AuctionDB.regionMarketValue = value.AuctionDB.regionMarketValue and "noTrend" or "none"
			end
			db:Set("global", upgradeObj:GetScopeKey(key), "tooltipOptions", "moduleTooltips", value)
		end
	end
	if prevVersion < 121 then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "userData", "operations") do
			db:Set("global", upgradeObj:GetScopeKey(key), "userData", "sharedOperations", value)
		end
	end
	if prevVersion < 122 then
		local function MigrateScrollTableContext(namespace, settingKey)
			for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, namespace, settingKey) do
				local newValue = db:Get("global", upgradeObj:GetScopeKey(key), namespace, settingKey)
				if value.colWidth then
					for _, colSettings in ipairs(newValue.cols) do
						local oldWidth = value.colWidth[colSettings.id]
						if type(oldWidth) == "number" then
							colSettings.width = oldWidth
						end
						colSettings.hidden = value.colHidden[colSettings.id] and true or nil
					end
					newValue.colWidthLocked = value.colWidthLocked and true or nil
					newValue.collapsed = value.collapsed
				end
			end
		end
		for _, _, value in upgradeObj:RemovedSettingIterator("global", nil, "auctionUIContext", "myAuctionsScrollingTable") do
			if value.colWidth then
				value.colWidth.highBidder = value.colWidth.highbidder
			end
		end
		MigrateScrollTableContext("auctionUIContext", "myAuctionsScrollingTable")
		MigrateScrollTableContext("destroyingUIContext", "itemsScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "auctioningBagScrollingTable")
		MigrateScrollTableContext("mainUIContext", "operationsSummaryScrollingTable")
		MigrateScrollTableContext("craftingUIContext", "craftsScrollingTable")
		MigrateScrollTableContext("craftingUIContext", "matsScrollingTable")
		MigrateScrollTableContext("craftingUIContext", "gatheringScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerAuctionsScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerDetailScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerInventoryScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerOtherScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerResaleScrollingTable")
		MigrateScrollTableContext("mainUIContext", "ledgerTransactionsScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "auctioningLogScrollingTable")
		MigrateScrollTableContext("vendoringUIContext", "buyScrollingTable")
		MigrateScrollTableContext("vendoringUIContext", "buybackScrollingTable")
		MigrateScrollTableContext("vendoringUIContext", "sellScrollingTable")
		MigrateScrollTableContext("mailingUIContext", "mailsScrollingTable")
		if prevVersion >= 82 then
			MigrateScrollTableContext("craftingUIContext", "professionScrollingTable")
		end
		MigrateScrollTableContext("auctionUIContext", "auctioningAuctionScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "shoppingAuctionScrollingTable")
		MigrateScrollTableContext("auctionUIContext", "sniperScrollingTable")
	end
	if prevVersion < 129 then
		if LibTSMApp.IsRetail() then
			for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "internalData", "crafts") do
				if prevVersion < 99 then
					local newValue = {}
					for spellId, data in pairs(value) do
						newValue["c:"..spellId] = data
					end
					value = newValue
				end
				if prevVersion < 114 then
					for _, craft in pairs(value) do
						if craft.mats then
							for itemString in pairs(craft.mats) do
								if strmatch(itemString, "^o:") then
									craft.mats[itemString] = 1
								end
							end
						end
					end
				end
				if prevVersion < 129 then
					for _, craft in pairs(value) do
						for _, info in pairs(craft.players) do
							if type(info) == "table" and info.baseRecipeDifficulty then
								info.inspirationAmount = nil
								info.inspirationChance = nil
							end
						end
					end
				end
				db:Set("factionrealm", upgradeObj:GetScopeKey(key), "internalData", "crafts", value)
			end
		else
			for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "internalData", "crafts") do
				db:Set("factionrealm", upgradeObj:GetScopeKey(key), "internalData", "crafts", value)
			end
		end
	end
	if prevVersion >= 122 and prevVersion < 133 and not LibTSMApp.IsPandaClassic() then
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "auctionUIContext", "auctioningAuctionScrollingTable") do
			db:Set("global", upgradeObj:GetScopeKey(key), "auctionUIContext", "auctioningAuctionScrollingTable", value)
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "auctionUIContext", "myAuctionsScrollingTable") do
			db:Set("global", upgradeObj:GetScopeKey(key), "auctionUIContext", "myAuctionsScrollingTable", value)
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "auctionUIContext", "shoppingAuctionScrollingTable") do
			db:Set("global", upgradeObj:GetScopeKey(key), "auctionUIContext", "shoppingAuctionScrollingTable", value)
		end
		for _, key, value in upgradeObj:RemovedSettingIterator("global", nil, "auctionUIContext", "sniperScrollingTable") do
			db:Set("global", upgradeObj:GetScopeKey(key), "auctionUIContext", "sniperScrollingTable", value)
		end
		if not LibTSMApp.IsRetail() then
			for _, key, value in upgradeObj:RemovedSettingIterator("factionrealm", nil, "auctioningOptions", "whitelist") do
				db:Set("factionrealm", upgradeObj:GetScopeKey(key), "auctioningOptions", "whitelist", value)
			end
		end
	end
	-- NOTE: When adding migrations, be careful of multiple migrations modifying the same key, as
	-- the RemovedSettingIterator value could be stale.
end
