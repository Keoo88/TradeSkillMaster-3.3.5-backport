-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AppHelper = LibTSMApp:Init("Service.AppHelper")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local Addon = LibTSMApp:From("LibTSMWoW"):Include("API.Addon")
local AuctionHouseWrapper = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local StaticPopupDialog = LibTSMApp:From("LibTSMWoW"):IncludeClassType("StaticPopupDialog")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local Lifecycle = LibTSMApp:From("LibTSMWoW"):Include("Util.Lifecycle")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local ErrorHandler = LibTSMApp:From("LibTSMService"):Include("Debug.ErrorHandler")
local RealmData = LibTSMApp:From("LibTSMData"):Include("Realm")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local Hash = LibTSMApp:From("LibTSMUtil"):Include("Util.Hash")
local Analytics = LibTSMApp:From("LibTSMUtil"):Include("Util.Analytics")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local BinarySearch = LibTSMApp:From("LibTSMUtil"):Include("Util.BinarySearch")
local LibRealmInfo = LibStub("LibRealmInfo")
local private = {
	settings = nil,
	-- The addon has historically had the game version as a suffix, whereas the app data has it as a prefix, so we store both
	addonRegion = nil,
	appDataRegion = nil,
	appInfo = nil,
	auctionDBData = {
		realm = {},
		region = {},
		commodity = {},
		altRealm = {},
	},
	shoppingData = nil,
	altRealms = {},
}
local APP_INFO_REQUIRED_KEYS = { "version", "lastSync", "message", "news" }
local AUCTIONDB_REALM_TAGS = {
	AUCTIONDB_NON_COMMODITY_DATA = true,
	AUCTIONDB_NON_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_NON_COMMODITY_HISTORICAL = true,
}
local AUCTIONDB_REGION_TAGS = {
	AUCTIONDB_REGION_STAT = true,
	AUCTIONDB_REGION_HISTORICAL = true,
	AUCTIONDB_REGION_SALE = true,
}
local AUCTIONDB_COMMODITY_TAGS = {
	AUCTIONDB_COMMODITY_DATA = true,
	AUCTIONDB_COMMODITY_SCAN_STAT = true,
	AUCTIONDB_COMMODITY_HISTORICAL = true,
}
local LOGOUT_TIME_WARNING_THRESHOLD = 0.02
local MAX_ANALYTICS_AGE = 14 * 24 * 60 * 60 -- 2 weeks
local MAX_FULL_SCAN_AGE = 12 * 60 * 60 -- 12 hours
local APP_DB_GLOBAL_NAME = "TradeSkillMaster_AppHelperDB"



-- ============================================================================
-- Global Function
-- ============================================================================

-- luacheck: globals TSM_APPHELPER_LOAD_DATA
function TSM_APPHELPER_LOAD_DATA(tag, realmOrRegion, data)
	if type(tag) ~= "string" or type(realmOrRegion) ~= "string" or type(data) ~= "string" then
		Log.Err("Unknown AppHelper data: %s, %s, %s", strsub(tostring(tag), 1, 20), strsub(tostring(realmOrRegion), 1, 20), strsub(tostring(data), 1, 20))
		return
	end
	if tag == "APP_INFO" and realmOrRegion == "Global" then
		if private.appInfo then
			Log.Err("Duplicate app info")
			return
		end
		Log.Info("Got app info")

		-- Load the app info
		private.appInfo = assert(loadstring(data))()
		for _, key in ipairs(APP_INFO_REQUIRED_KEYS) do
			assert(private.appInfo[key])
		end

		-- Clean up the news content strings
		for _, info in ipairs(private.appInfo.news) do
			-- For some reason the data is missing a few newlines before bold headings, so add one
			info.content = gsub(info.content, "(<strong>)", "\n\n%1")
			info.content = gsub(info.content, "<br%s+/>", "\n")
			info.content = gsub(info.content, "<strong>(.-)</strong>", "%1")
			info.content = gsub(info.content, "<a href='.-'>(.-)</a>", "%1")
			info.content = gsub(info.content, "&#8211;", "-")
			info.content = gsub(info.content, "&#8216;", "'")
		end
	elseif AUCTIONDB_REALM_TAGS[tag] or AUCTIONDB_REGION_TAGS[tag] or AUCTIONDB_COMMODITY_TAGS[tag] then
		if AUCTIONDB_REALM_TAGS[tag] and private.IsCurrentRealm(realmOrRegion) then
			private.StoreAuctionDBData(private.auctionDBData.realm, tag, data, "realm")
		elseif AUCTIONDB_REALM_TAGS[tag] and private.IsRealm(realmOrRegion, private.settings.auctionDBAltRealm) then
			private.altRealms[realmOrRegion] = true
			private.StoreAuctionDBData(private.auctionDBData.altRealm, tag, data, "alt realm")
		elseif AUCTIONDB_REGION_TAGS[tag] and realmOrRegion == private.appDataRegion then
			private.StoreAuctionDBData(private.auctionDBData.region, tag, data, "region")
		elseif AUCTIONDB_COMMODITY_TAGS[tag] and realmOrRegion == private.appDataRegion then
			private.StoreAuctionDBData(private.auctionDBData.commodity, tag, data, "commodity")
		else
			Log.Info("Ignoring AuctionDB data (%s) for '%s'", tag, realmOrRegion)
			if AUCTIONDB_REALM_TAGS[tag] then
				private.altRealms[realmOrRegion] = true
			end
		end
	elseif tag == "SHOPPING_SEARCHES" then
		if not private.IsCurrentRealm(realmOrRegion) then
			Log.Info("Ignoring Shopping data for '%s'", realmOrRegion)
			private.altRealms[realmOrRegion] = true
			return
		elseif private.shoppingData then
			Log.Err("Duplicate Shopping data")
			return
		end
		private.shoppingData = data
		Log.Info("Got Shopping data")
	else
		Log.Err("Unknown AppHelper data: %s, %s", strsub(tag, 1, 25), strsub(realmOrRegion, 1, 25))
	end
end



-- ============================================================================
-- Module Loading
-- ============================================================================

AppHelper:OnModuleLoad(function()
	AddonSettings.RegisterOnLoad("Service.AppHelper", function(settingsDB)
		private.settings = settingsDB:NewView()
			:AddKey("global", "internalData", "appMessageId")
			:AddKey("global", "internalData", "lastCharacter")
			:AddKey("realm", "coreOptions", "auctionDBAltRealm")
		-- Set the last character we logged into for display in the app
		private.settings.lastCharacter = SessionInfo.GetCharacterName().." - "..SessionInfo.GetRealmName()

		local cVar = SessionInfo.GetRegion()
		local region = nil
		if ClientInfo.IsRetail() then
			region = LibRealmInfo:GetCurrentRegion()
		else
			local currentRealmName = private.SanitizedRealmName(SessionInfo.GetRealmName())
			local realmInfo = RealmData.Classic[currentRealmName]
			region = realmInfo and realmInfo.region
		end
		region = region or (cVar ~= "public-test" and cVar) or "PTR"
		if ClientInfo.IsRetail() then
			private.addonRegion = region
			private.appDataRegion = region
		elseif ClientInfo.IsVanillaClassic() and SessionInfo.IsHardcore() then
			private.addonRegion = region.."-HC"
			private.appDataRegion = "HC-"..region
		elseif ClientInfo.IsVanillaClassic() and SessionInfo.IsSeasonOfDiscovery() then
			private.addonRegion = region.."-SoD"
			private.appDataRegion = "SoD-"..region
		elseif (ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and SessionInfo.IsFresh() then
			private.addonRegion = region.."-Fresh"
			private.appDataRegion = "Fresh-"..region
		elseif ClientInfo.IsVanillaClassic() then
			private.addonRegion = region.."-Classic"
			private.appDataRegion = "Classic-"..region
		elseif ClientInfo.IsBCClassic() then
			private.addonRegion = region.."-BCC"
			private.appDataRegion = "BCC-"..region
		elseif ClientInfo.IsWrathClassic() then
			private.addonRegion = region.."-Wrath"
			private.appDataRegion = "Wrath-"..region
		elseif ClientInfo.IsPandaClassic() then
			private.addonRegion = region.."-MoP"
			private.appDataRegion = "MoP-"..region
		else
			error("Invalid game version")
		end
		AuctionHouseWrapper.SetAnalyticsRegionRealm(private.addonRegion.."-"..private.SanitizedRealmName(SessionInfo.GetRealmName()))
		Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
	end)
end)

AppHelper:OnModuleUnload(function()
	local startTime = LibTSMApp.GetTime()
	private.SaveAppData()
	local timeTaken = LibTSMApp.GetTime() - startTime
	if timeTaken > LOGOUT_TIME_WARNING_THRESHOLD then
		Log.Warn("private.SaveAppData took %0.5fs", timeTaken)
	end
end, true)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the last sync time.
---@return number?
function AppHelper.GetLastSync()
	return private.appInfo and private.appInfo.lastSync or 0
end

---Gets the news data.
---@return table?
function AppHelper.GetNews()
	return private.appInfo and private.appInfo.news or nil
end

---Gets the current region.
---@return string
function AppHelper.GetRegion()
	return private.addonRegion
end

---Gets the AuctionDB data.
---@return table realm
---@return table region
---@return table commodity
---@return table altRealm
function AppHelper.GetAuctionDBData()
	return private.auctionDBData.realm, private.auctionDBData.region, private.auctionDBData.commodity, private.auctionDBData.altRealm
end

---Gets the shopping data.
---@return string?
function AppHelper.GetShoppingData()
	return private.shoppingData
end

---Iterates over the alt realm names.
---@return fun(): string @Iterator with fields: `realm`
function AppHelper.AltRealmIterator()
	return Table.KeyIterator(private.altRealms)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	-- TSM Desktop App integration отключён — порт под in-game-only.
	-- Никаких попапов "App not running", никакого автозапуска full scan.
	TSM_APPHELPER_LOAD_DATA = function() end
	return true
end

function private.StoreAuctionDBData(tbl, tag, data, label)
	if tbl[tag] then
		Log.Err("Duplicate AuctionDB %s data (%s)", label, tag)
		return
	end
	tbl[tag] = data
	Log.Info("Got AuctionDB %s data (%s)", label, tag)
end

function private.SanitizedRealmName(realm)
	return gsub(realm, "\226", "'")
end

function private.IsCurrentRealm(realm)
	return private.IsRealm(realm, SessionInfo.GetRealmName())
end

function private.IsRealm(realm, targetRealm)
	local currentRealmName = private.SanitizedRealmName(targetRealm)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.CONNECTED_FACTION_AH) then
		currentRealmName = currentRealmName.."-"..SessionInfo.GetFactionName()
	end
	return strlower(private.SanitizedRealmName(realm)) == strlower(currentRealmName)
end

function private.SaveAppData()
	-- TSM Desktop App integration отключён — данные обратно в AppHelperDB не пишем.
end

function private.SaveBlackMarket(appDB)
	local realmName = SessionInfo.GetRealmName()
	appDB.blackMarket = appDB.blackMarket or {}
	local blackMarketData, blackMarketTime = Auction.GetBlackMarketScanData()
	if blackMarketData then
		appDB.blackMarket[realmName] = {
			data = blackMarketData,
			key = Hash.Calculate(blackMarketData..":"..blackMarketTime),
			updateTime = blackMarketTime
		}
	end
end

function private.SaveAnalytics(appDB)
	appDB.analytics = appDB.analytics or {updateTime=0, data={}}
	appDB.analytics.updateTime = Analytics.GetLastEventTime() or appDB.analytics.updateTime

	-- Remove entries which are too old
	local minTime = LibTSMApp.GetTime() - MAX_ANALYTICS_AGE
	local index, insertIndex = BinarySearch.Table(appDB.analytics.data, minTime, Analytics.GetEntryTime)
	local removeEndIndex = index or (insertIndex - 1)
	if removeEndIndex > 0 then
		Table.RemoveRange(appDB.analytics.data, 1, removeEndIndex)
	end

	-- Add new entries
	for _, eventStr in Analytics.EventIterator() do
		tinsert(appDB.analytics.data, eventStr)
	end
end

function private.SaveFullScan(appDB)
	appDB.fullScan = appDB.fullScan or {updateTime=0, data={}}

	-- Remove entries which are too old
	local minTime = LibTSMApp.GetTime() - MAX_FULL_SCAN_AGE
	for i = #appDB.fullScan.data, 1, -1 do
		if appDB.fullScan.data[i].scanTime < minTime then
			tremove(appDB.fullScan.data, i)
		end
	end

	-- Save the new data (if available)
	local data, scanTime = Auction.GetFullScanData()
	if not data then
		return
	end
	appDB.fullScan.updateTime = scanTime
	tinsert(appDB.fullScan.data, {
		data = data,
		scanTime = scanTime,
	})
end
