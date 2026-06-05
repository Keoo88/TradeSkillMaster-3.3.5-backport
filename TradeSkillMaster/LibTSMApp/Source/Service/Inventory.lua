-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local Inventory = LibTSMApp:Init("Service.Inventory")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local AltTracking = LibTSMApp:Include("Service.AltTracking")
local CustomString = LibTSMApp:From("LibTSMTypes"):Include("CustomString")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local BagTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMApp:From("LibTSMService"):Include("Inventory.WarbankTracking")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local Mail = LibTSMApp:From("LibTSMService"):Include("Mail")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local private = {
	sources = {},
	settingsDB = nil,
	settings = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Inventory:OnModuleLoad(function()
	tinsert(private.sources, "NumInventory")
	-- Register the "NumInventory" custom price source so that GetSourceValue("NumInventory", itemString)
	-- returns the total owned quantity. Without this, crafting sees 0 mats and disables crafting.
	if not CustomString.IsSourceRegistered("NumInventory") then
		CustomString.RegisterSource("Inventory", "NumInventory", "Number in Bags / Bank / AH / Mail", Inventory.GetTotalQuantity, CustomString.SOURCE_TYPE.NORMAL)
	end
	AddonSettings.RegisterOnLoad("Service.Inventory", function(db)
		private.settingsDB = db
		private.settings = db:NewView()
			:AddKey("sync", "internalData", "bagQuantity")
			:AddKey("sync", "internalData", "bankQuantity")
			:AddKey("char", "internalData", "auctionSaleHints")
			:AddKey("factionrealm", "internalData", "expiringAuction")
			:AddKey("sync", "internalData", "auctionQuantity")
			:AddKey("factionrealm", "internalData", "pendingMail")
			:AddKey("factionrealm", "internalData", "expiringMail")
			:AddKey("sync", "internalData", "mailQuantity")
			:AddKey("factionrealm", "internalData", "guildVaults")
			:AddKey("global", "mailingOptions", "recentlyMailedList")
			:AddKey("global", "internalData", "warbankQuantity")

		-- Bag tracking
		BagTracking.Load(private.settings.bagQuantity, private.settings.bankQuantity)
		BagTracking.Start()
		BagTracking.RegisterQuantityCallback(private.QuantityChangedCallback)

		-- Warbank tracking
		WarbankTracking.Load(private.settings.warbankQuantity)
		WarbankTracking.Start()
		WarbankTracking.RegisterQuantityCallback(private.QuantityChangedCallback)

		-- Auction tracking
		Auction.Load(private.settings.auctionQuantity, private.settings.auctionSaleHints, private.settings.expiringAuction)
		Auction.Start()
		Auction.RegisterQuantityCallback(private.QuantityChangedCallback)

		-- Mail Tracking
		private.SanitizePendingMail()
		Mail.Load(private.settings.mailQuantity, private.settings.pendingMail, private.settings.expiringMail, db, private.settings.recentlyMailedList, private.ValidateMailCharacter)
		Mail.Start()
		Mail.RegisterQuantityCallback(private.QuantityChangedCallback)

		-- Guild Tracking
		Guild.Load(private.settings.guildVaults)
		Guild.Start()

		AltTracking.RegisterQuantityCallback(private.QuantityChangedCallback)
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function Inventory.RegisterDependentCustomSource(source)
	tinsert(private.sources, source)
end

function Inventory.GetTotalQuantity(itemString)
	local total = 0
	total = total + BagTracking.GetBagQuantity(itemString)
	total = total + BagTracking.GetBankQuantity(itemString)
	total = total + WarbankTracking.GetQuantity(itemString)
	total = total + Mail.GetQuantity(itemString)
	total = total + Auction.GetQuantity(itemString)
	total = total + AltTracking.GetTotalQuantity(itemString)
	total = total + AltTracking.GetTotalGuildQuantity(itemString)
	return total
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SanitizePendingMail()
	-- Remove pending mail data for characters we don't own
	for character in pairs(private.settings.pendingMail) do
		if private.settingsDB:GetOwnerSyncAccountKey(character) ~= private.settingsDB:GetLocalSyncAccountKey() then
			Log.Info("Removed pending mail data for %s", character)
			private.settings.pendingMail[character] = nil
		end
	end
end

function private.ValidateMailCharacter(character)
	if not character then
		return nil
	end
	local characterName, realm = strsplit("-", strlower(character))
	-- We only care to track mails with characters on this realm
	if realm and realm ~= strlower(SessionInfo.GetRealmName()) then
		return nil
	end
	-- We only care to track mails with characters on this account
	local result = nil
	for _, name in private.settingsDB:AccessibleCharacterIterator(private.settingsDB:GetLocalSyncAccountKey()) do
		if strlower(name) == characterName then
			result = name
		end
	end
	return result
end

function private.QuantityChangedCallback(updatedItems)
	for _, source in ipairs(private.sources) do
		for itemString in pairs(updatedItems) do
			CustomString.InvalidateCache(source, itemString)
		end
	end
end
