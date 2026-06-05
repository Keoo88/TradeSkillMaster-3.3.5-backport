-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local ItemInfoConfig = LibTSMApp:Init("Config.ItemInfoConfig")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local SlashCommands = LibTSMApp:Include("Service.SlashCommands")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local VendorBuy = LibTSMApp:From("LibTSMService"):Include("Item.VendorBuy")
local MillData = LibTSMApp:From("LibTSMData"):Include("Mill")
local ProspectData = LibTSMApp:From("LibTSMData"):Include("Prospect")
local TransformData = LibTSMApp:From("LibTSMData"):Include("Transform")
local VendorTradeData = LibTSMApp:From("LibTSMData"):Include("VendorTrade")
local DisenchantData = LibTSMApp:From("LibTSMData"):Include("Disenchant")
local private = {
	wiped = false,
}
local CACHE_DB_GLOBAL_NAME = "TSMItemInfoDB"
local UNKNOWN_ITEM_NAME = L["Unknown Item"]
local PLACEHOLDER_ITEM_NAME = L["Example Item"]



-- ============================================================================
-- Module Loading
-- ============================================================================

ItemInfoConfig:OnModuleLoad(function()
	local function RebuildCallback(isDone)
		if isDone then
			ChatMessage.PrintUser(L["Done rebuilding item cache."])
		else
			ChatMessage.PrintUser(L["TSM is currently rebuilding its item cache which may cause FPS drops and result in TSM not being fully functional until this process is complete. This is normal and typically takes a few minutes."])
		end
	end
	ItemInfo.Configure(RebuildCallback, UNKNOWN_ITEM_NAME, PLACEHOLDER_ITEM_NAME)

	AddonSettings.RegisterOnLoad("Config.ItemInfoConfig", private.HandleSettingsLoaded)

	-- Debug command to wipe the item info cache
	SlashCommands.RegisterDebug("clearitemdb", private.WipeDB)
end)

ItemInfoConfig:OnModuleUnload(function()
	if private.wiped then
		return
	end
	ItemInfo.SaveCache(_G[CACHE_DB_GLOBAL_NAME])
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleSettingsLoaded(db)
	local settings = db:NewView()
		:AddKey("global", "internalData", "vendorItems")

	-- Create the DB if it doesn't exist
	local cacheDB = _G[CACHE_DB_GLOBAL_NAME]
	if not cacheDB then
		cacheDB = {}
		_G[CACHE_DB_GLOBAL_NAME] = cacheDB
	end

	-- Migrate from separate fields to a single versionStr field
	if cacheDB.version and not cacheDB.versionStr then
		cacheDB.versionStr = strjoin(",", tostringall(cacheDB.version, cacheDB.locale, cacheDB.build, cacheDB.revision))
	end

	-- Load the DB
	if not ItemInfo.LoadCache(cacheDB) then
		-- Wipe vendor items since the cache wasn't valid
		wipe(settings.vendorItems)
	end

	-- Load VendorBuy
	local function VendorBuyUpdateCallback(itemString)
		ItemInfo.StreamSend(itemString)
	end
	VendorBuy.Load(settings.vendorItems, VendorBuyUpdateCallback)

	-- Start
	ItemInfo.Start()

	-- Cache item info from destroy data
	private.FetchDestroyItemInfo(MillData.Get())
	private.FetchDestroyItemInfo(ProspectData.Get())
	private.FetchDestroyItemInfo(TransformData.Get())
	private.FetchDestroyItemInfo(VendorTradeData.Get())
	for itemString in pairs(DisenchantData.Get()) do
		ItemInfo.FetchInfo(itemString)
	end
end

function private.FetchDestroyItemInfo(data)
	for targetItemString, items in pairs(data) do
		ItemInfo.FetchInfo(targetItemString)
		for sourceItemString in pairs(items) do
			ItemInfo.FetchInfo(sourceItemString)
		end
	end
end

function private.WipeDB()
	wipe(_G[CACHE_DB_GLOBAL_NAME])
	private.wiped = true
	ReloadUI()
end
