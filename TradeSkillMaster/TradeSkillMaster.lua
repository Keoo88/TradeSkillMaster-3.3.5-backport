-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--        WotLK 3.3.5a backport by Keoo - https://discord.gg/sKpJbUrsvR           --
--    Based on the original TradeSkillMaster. License info included with addon.   --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Log = TSM.LibTSMUtil:Include("Util.Log")
local MoneyFormatter = TSM.LibTSMUtil:IncludeClassType("MoneyFormatter")
local Addon = TSM.LibTSMWoW:Include("API.Addon")
local ChatFrame = TSM.LibTSMWoW:Include("API.ChatFrame")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local ShoppingOperation = TSM.LibTSMSystem:Include("ShoppingOperation")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local ItemFilter = TSM.LibTSMService:IncludeClassType("ItemFilter")
local VendorBuy = TSM.LibTSMService:Include("Item.VendorBuy")
local Sync = TSM.LibTSMService:Include("Sync")
local Inventory = TSM.LibTSMApp:Include("Service.Inventory")
local L = TSM.Locale.GetTable()
local CustomStringFormat = TSM.LibTSMUI:Include("Util.CustomStringFormat")
local private = {
	settings = nil,
	itemInfoPublisher = nil,  --luacheck: ignore 1004 - just stored for GC reasons
	oribosExchangeTemp = {},
}
do
	-- Basic module configuration
	Log.SetLoggingToChatEnabled(TSM.LibTSMUtil.IsTestVersion())
	MoneyFormatter.SetLargeNumberSeperator(LARGE_NUMBER_SEPERATOR)
end



-- ============================================================================
-- Module Functions
-- ============================================================================

---@param settingsDB SettingsDB
function TSM.OnInitialize(settingsDB)
	-- Load settings
	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "chatFrame")
		:AddKey("global", "coreOptions", "destroyValueSource")
		:AddKey("global", "debug", "chatLoggingEnabled")
		:AddKey("sync", "internalData", "classKey")
		:RegisterCallback("destroyValueSource", function() CustomString.InvalidateCache("Destroy") end)

	-- Configure some LibTSM modules
	local svCopyError = L["It appears that you've manually copied your saved variables between accounts which will cause TSM's automatic sync'ing to not work. You'll need to undo this, and/or delete the TradeSkillMaster saved variables files on both accounts (with WoW closed) in order to fix this."]
	Sync.Load(settingsDB, svCopyError)

	-- Configure the logger
	ChatFrame.SetActive(private.settings.chatFrame)
	if TSM.LibTSMUtil.IsTestVersion() then
		private.settings.chatLoggingEnabled = true
	elseif not TSM.LibTSMUtil.IsDevVersion() then
		private.settings.chatLoggingEnabled = false
	end
	Log.SetLoggingToChatEnabled(private.settings.chatLoggingEnabled)

	-- Store the class of this character
	private.settings.classKey = select(2, UnitClass("player"))

	-- CanIMogIt integration
	-- luacheck: globals CanIMogIt
	if CanIMogIt and CanIMogIt.PlayerKnowsTransmog then
		ItemFilter.AddKeyMatchPart("unlearned", function(item)
			return CanIMogIt:PlayerKnowsTransmog(ItemInfo.GetLink(item))
		end)
	end
	if CanIMogIt and CanIMogIt.CharacterCanLearnTransmog then
		ItemFilter.AddKeyMatchPart("canlearn", function(item)
			return CanIMogIt:CharacterCanLearnTransmog(ItemInfo.GetLink(item))
		end)
	end

	-- Core price sources
	private.itemInfoPublisher = ItemInfo.GetPublisher()
		:CallFunction(function(itemString)
			CustomString.InvalidateCache("VendorBuy", itemString)
			CustomString.InvalidateCache("VendorSell", itemString)
			CustomString.InvalidateCache("ItemQuality", itemString)
			CustomString.InvalidateCache("ItemLevel", itemString)
			CustomString.InvalidateCache("RequiredLevel", itemString)
		end)
		:Stored()
	CustomString.RegisterSource("Item", "VendorBuy", L["Buy from Vendor"], VendorBuy.Get, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "VendorSell", L["Sell to Vendor"], ItemInfo.GetVendorSell, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "ItemQuality", L["Item Quality"], ItemInfo.GetQuality, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "ItemLevel", L["Item Level"], ItemInfo.GetItemLevel, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "RequiredLevel", L["Required Level"], ItemInfo.GetMinLevel, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "MaxStack", L["Maximum Stack Size"], ItemInfo.GetMaxStack, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Item", "NumInventory", L["Total Inventory Quantity"], Inventory.GetTotalQuantity, CustomString.SOURCE_TYPE.NORMAL)
	CustomStringFormat.SetFormat("ItemQuality", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("ItemLevel", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("RequiredLevel", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("MaxStack", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("NumInventory", CustomStringFormat.FORMAT.NUMBER)

	-- Auctioneer price sources
	-- luacheck: globals AucAdvanced
	if Addon.IsEnabled("Auc-Advanced") and AucAdvanced then
		local registeredAuctioneerSources = {}
		hooksecurefunc(AucAdvanced, "SendProcessorMessage", function(msg)
			if msg == "scanfinish" then
				for _, source in ipairs(registeredAuctioneerSources) do
					CustomString.InvalidateCache(source)
				end
			end
		end)
		if AucAdvanced.Modules.Util.Appraiser and AucAdvanced.Modules.Util.Appraiser.GetPrice then
			local function PriceFunc(itemString)
				local itemLink = ItemInfo.GetLink(itemString)
				if not itemLink then
					return nil
				end
				return AucAdvanced.Modules.Util.Appraiser.GetPrice(itemLink)
			end
			CustomString.RegisterSource("External", "AucAppraiser", L["Auctioneer - Appraiser"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
			tinsert(registeredAuctioneerSources, "AucAppraiser")
		end
		if AucAdvanced.Modules.Util.SimpleAuction and AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems then
			local function PriceFunc(itemString)
				local itemLink = ItemInfo.GetLink(itemString)
				if not itemLink then
					return nil
				end
				return select(6, AucAdvanced.Modules.Util.SimpleAuction.Private.GetItems(itemLink)) or nil
			end
			CustomString.RegisterSource("External", "AucMinBuyout", L["Auctioneer - Minimum Buyout"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
			tinsert(registeredAuctioneerSources, "AucMinBuyout")
		end
		if AucAdvanced.API.GetMarketValue then
			local function PriceFunc(itemString)
				local itemLink = ItemInfo.GetLink(itemString)
				if not itemLink then
					return nil
				end
				return AucAdvanced.API.GetMarketValue(itemLink)
			end
			CustomString.RegisterSource("External", "AucMarket", L["Auctioneer - Market Value"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
			tinsert(registeredAuctioneerSources, "AucMarket")
		end
	end

	-- Auctionator price sources
	if Addon.IsEnabled("Auctionator") then
		local PriceFunc = nil
		-- luacheck: globals Auctionator Atr_GetAuctionBuyout Atr_RegisterFor_DBupdated
		if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.RegisterForDBUpdate then
			-- Retail version
			local ok = pcall(function()
				Auctionator.API.v1.RegisterForDBUpdate("TradeSkillMaster", function() CustomString.InvalidateCache("AtrValue") end)
			end)
			if ok then
				PriceFunc = function(itemString)
					local itemLink = ItemInfo.GetLink(itemString)
					if not itemLink then
						return nil
					end
					return Auctionator.API.v1.GetAuctionPriceByItemLink("TradeSkillMaster", itemLink)
				end
			end
		elseif Atr_GetAuctionBuyout and Atr_RegisterFor_DBupdated then
			-- Classic version
			Atr_RegisterFor_DBupdated(function()
				CustomString.InvalidateCache("AtrValue")
			end)
			PriceFunc = function(itemString)
				local itemLink = ItemInfo.GetLink(itemString)
				if not itemLink then
					return nil
				end
				return Atr_GetAuctionBuyout(itemLink)
			end
		end
		if PriceFunc then
			CustomString.RegisterSource("External", "AtrValue", L["Auctionator - Auction Value"], PriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		end
	end

	-- OribosExchange price sources
	-- luacheck: globals OEMarketInfo
	if Addon.IsEnabled("OribosExchange") and OEMarketInfo then
		local function PriceFuncHelper(itemString, key)
			local itemLink = ItemInfo.GetLink(itemString)
			if not itemLink then
				return nil
			end
			local data = OEMarketInfo(itemLink, private.oribosExchangeTemp)
			return data and data[key] or nil
		end
		local function RealmPriceFunc(itemString)
			return PriceFuncHelper(itemString, "market")
		end
		CustomString.RegisterSource("External", "OERealm", L["Oribos Exchange Realm Price"], RealmPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		local function RegionPriceFunc(itemString)
			return PriceFuncHelper(itemString, "region")
		end
		CustomString.RegisterSource("External", "OERegion", L["Oribos Exchange Region Price"], RegionPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
	end

	-- AHDB price sources
	-- luacheck: globals AuctionDB
	if Addon.IsEnabled("AuctionDB") and AuctionDB and AuctionDB.AHendOfScanCB and AuctionDB.AHGetAuctionInfoByLink then
		hooksecurefunc(AuctionDB, "AHendOfScanCB", function()
			CustomString.InvalidateCache("AHDBMinBuyout")
			CustomString.InvalidateCache("AHDBMinBid")
		end)
		local function PriceFuncHelper(itemString, key)
			local itemLink = ItemInfo.GetLink(itemString)
			if not itemLink then
				return nil
			end
			local info = AuctionDB:AHGetAuctionInfoByLink(itemLink)
			return info and info[key] or nil
		end
		local function MinBuyoutPriceFunc(itemString)
			return PriceFuncHelper(itemString, "minBuyout")
		end
		CustomString.RegisterSource("External", "AHDBMinBuyout", L["AHDB Minimum Buyout"], MinBuyoutPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
		local function MinBidPriceFunc(itemString)
			return PriceFuncHelper(itemString, "minBid")
		end
		CustomString.RegisterSource("External", "AHDBMinBid", L["AHDB Minimum Bid"], MinBidPriceFunc, CustomString.SOURCE_TYPE.PRICE_DB)
	end

	-- Accounting sources
	CustomString.RegisterSource("Accounting", "AvgSell", L["Avg Sell Price"], TSM.Accounting.Transactions.GetAverageSalePrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MaxSell", L["Max Sell Price"], TSM.Accounting.Transactions.GetMaxSalePrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MinSell", L["Min Sell Price"], TSM.Accounting.Transactions.GetMinSalePrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "AvgBuy", L["Avg Buy Price"], TSM.Accounting.Transactions.GetAverageBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "SmartAvgBuy", L["Smart Avg Buy Price"], TSM.Accounting.Transactions.GetSmartAverageBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MaxBuy", L["Max Buy Price"], TSM.Accounting.Transactions.GetMaxBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "MinBuy", L["Min Buy Price"], TSM.Accounting.Transactions.GetMinBuyPrice, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "NumExpires", L["Expires Since Last Sale"], TSM.Accounting.Auctions.GetNumExpiresSinceSale, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Accounting", "SaleRate", L["Sale Rate"], TSM.Accounting.GetSaleRate, CustomString.SOURCE_TYPE.NORMAL)
	CustomStringFormat.SetFormat("NumExpires", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("SaleRate", CustomStringFormat.FORMAT.NUMBER)

	-- AuctionDB sources
	local function GetAuctionDBPriceFunc(key, isRegion)
		return function(itemString)
			local value
			if isRegion then
				value = TSM.AuctionDB.GetRegionItemData(itemString, key)
			else
				value = TSM.AuctionDB.GetRealmItemData(itemString, key)
			end
			-- 3.3.5 fallback: если marketValue/regionMarketValue нет (нет TSM App), используем minBuyout из локальных сканов
			if not value and (key == "marketValue" or key == "regionMarketValue") then
				value = TSM.AuctionDB.GetRealmItemData(itemString, "minBuyout")
			end
			-- 3.3.5 финальный fallback: если нет auction data вообще, используем vendorsell * 2
			if not value and (key == "marketValue" or key == "regionMarketValue") then
				local vendorSell = ItemInfo.GetVendorSell(itemString)
				if vendorSell and vendorSell > 0 then
					value = vendorSell * 2
				end
			end
			return value
		end
	end
	CustomString.RegisterSource("AuctionDB", "DBMarket", L["AuctionDB - Market Value"], GetAuctionDBPriceFunc("marketValue"), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBMinBuyout", L["AuctionDB - Minimum Buyout"], GetAuctionDBPriceFunc("minBuyout"), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBRecent", L["AuctionDB - Recent Value"], GetAuctionDBPriceFunc("marketValueRecent"), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBHistorical", L["AuctionDB - Historical Price"], GetAuctionDBPriceFunc("historical"), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBRegionMarketAvg", L["AuctionDB - Region Market Value Average"], GetAuctionDBPriceFunc("regionMarketValue", true), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBRegionHistorical", L["AuctionDB - Region Historical Price"], GetAuctionDBPriceFunc("regionHistorical", true), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBRegionSaleAvg", L["AuctionDB - Region Sale Average"], GetAuctionDBPriceFunc("regionSale", true), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBRegionSaleRate", L["AuctionDB - Region Sale Rate"], GetAuctionDBPriceFunc("regionSalePercent", true), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomString.RegisterSource("AuctionDB", "DBRegionSoldPerDay", L["AuctionDB - Region Sold Per Day"], GetAuctionDBPriceFunc("regionSoldPerDay", true), CustomString.SOURCE_TYPE.PRICE_DB)
	CustomStringFormat.SetFormat("DBRegionSaleRate", CustomStringFormat.FORMAT.NUMBER)
	CustomStringFormat.SetFormat("DBRegionSoldPerDay", CustomStringFormat.FORMAT.NUMBER)

	-- Crafting sources
	local function GetDestroyValue(itemString)
		return TSM.Crafting.GetConversionsValue(itemString, private.settings.destroyValueSource)
	end
	CustomString.RegisterSource("Crafting", "Destroy", L["Destroy Value"], GetDestroyValue, CustomString.SOURCE_TYPE.NORMAL)
	CustomString.RegisterSource("Crafting", "Crafting", L["Crafting Cost"], TSM.Crafting.Cost.GetLowestCostByItem, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Crafting", "MatPrice", L["Crafting Material Cost"], TSM.Crafting.Cost.GetMatCost, CustomString.SOURCE_TYPE.VOLATILE)

	-- Operation-based price sources
	local function GetAuctioningOpMin(itemString)
		return AuctioningOperation.GetItemPrice(itemString, "minPrice")
	end
	local function GetAuctioningOpMax(itemString)
		return AuctioningOperation.GetItemPrice(itemString, "maxPrice")
	end
	local function GetAuctioningOpNormal(itemString)
		return AuctioningOperation.GetItemPrice(itemString, "normalPrice")
	end
	CustomString.RegisterSource("Operations", "AuctioningOpMin", L["First Auctioning Operation Min Price"], GetAuctioningOpMin, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "AuctioningOpMax", L["First Auctioning Operation Max Price"], GetAuctioningOpMax, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "AuctioningOpNormal", L["First Auctioning Operation Normal Price"], GetAuctioningOpNormal, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "ShoppingOpMax", L["Shopping Operation Max Price"], ShoppingOperation.GetMaxPrice, CustomString.SOURCE_TYPE.VOLATILE)
	CustomString.RegisterSource("Operations", "SniperOpMax", L["Sniper Operation Max Price"], SniperOperation.GetMaxPrice, CustomString.SOURCE_TYPE.VOLATILE)

	-- Force a garbage collection
	collectgarbage()
end
