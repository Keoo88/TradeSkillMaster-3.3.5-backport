-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Operations = TSM:NewPackage("Operations") ---@type AddonPackage
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local Operation = TSM.LibTSMTypes:Include("Operation")
local OperationUtil = TSM.LibTSMSystem:Include("Operation.Util")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local CraftingOperation = TSM.LibTSMSystem:Include("CraftingOperation")
local MailingOperation = TSM.LibTSMSystem:Include("MailingOperation")
local ShoppingOperation = TSM.LibTSMSystem:Include("ShoppingOperation")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local VendoringOperation = TSM.LibTSMSystem:Include("VendoringOperation")
local WarehousingOperation = TSM.LibTSMSystem:Include("WarehousingOperation")
local Auction = TSM.LibTSMService:Include("Auction")
local Guild = TSM.LibTSMService:Include("Guild")
local Mail = TSM.LibTSMService:Include("Mail")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local CustomPrice = TSM.LibTSMApp:Include("Service.CustomPrice")
local AltTracking = TSM.LibTSMApp:Include("Service.AltTracking")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local L = TSM.Locale.GetTable()
local private = {
	settingsDB = nil,
	settings = nil,
	characterKey = nil,
	connectedCharacterCache = {},
}
local BAD_CRAFTING_PRICE_SOURCES = {
	crafting = true,
}



-- ============================================================================
-- Modules Functions
-- ============================================================================

function Operations.OnInitialize(settingsDB)
	local factionrealm = SessionInfo.GetFactionrealmName()
	private.characterKey = SessionInfo.GetCharacterName().." - "..factionrealm
	Operation.SetPlayerInfo(private.characterKey, factionrealm)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "globalOperations")
		:AddKey("global", "userData", "sharedOperations")
		:AddKey("profile", "userData", "operations")
		:AddKey("profile", "internalData", "createdDefaultOperations")
		:AddKey("global", "coreOptions", "regionWide")
		:RegisterCallback("operations", private.OnProfileUpdated)
	private.LoadDBSettings()
	Operation.SetShouldCreateDefault(not private.settings.createdDefaultOperations)
	private.settings.createdDefaultOperations = true

	OperationUtil.SetFrameTimeFunc(GetTime)
	AuctioningOperation.Load(L["Auctioning"], ClientInfo.HasFeature(ClientInfo.FEATURES.AH_LIFO), ClientInfo.HasFeature(ClientInfo.FEATURES.AH_SELLERS), ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and ItemInfo.GetMaxStack or nil)
	CraftingOperation.Load(L["Crafting"], private.ValidateCraftingCraftPriceMethod)
	MailingOperation.Load(L["Mailing"], private.GetMailingTargetQuantity, PlayerInfo.IsPlayer)
	ShoppingOperation.Load(L["Shopping"], private.GetShoppingInventoryNum)
	SniperOperation.Load(L["Sniper"])
	VendoringOperation.Load(L["Vendoring"], private.GetVendoringInventoryNum)
	WarehousingOperation.Load(L["Warehousing"], private.GetWarehousingBagQuantity)
end

function Operations.GetFirstOperationByItem(moduleName, itemString)
	local groupPath = Group.GetPathByItem(itemString)
	for _, operationName in GroupOperation.Iterator(groupPath, moduleName) do
		Operation.UpdateFromRelationships(moduleName, operationName)
		if not Operation.IsIgnored(moduleName, operationName) then
			return operationName, Operation.GetSettings(moduleName, operationName)
		end
	end
end

function Operations.GetRelationshipColors(operationType, operationName, settingKey, value)
	local relationshipSet = Operation.HasRelationship(operationType, operationName, settingKey)
	local linkColor = nil
	if not value and relationshipSet then
		linkColor = "INDICATOR_DISABLED"
	elseif not value then
		linkColor = "TEXT_DISABLED"
	elseif relationshipSet then
		linkColor = "INDICATOR"
	else
		linkColor = "TEXT"
	end
	local linkTexture = TextureAtlas.GetColoredKey("iconPack.14x14/Link", linkColor)
	return relationshipSet, linkTexture, value and not relationshipSet and "TEXT" or "TEXT_DISABLED"
end

function Operations.SetStoredGlobally(storeGlobally)
	private.settings.globalOperations = storeGlobally
	if storeGlobally then
		-- Move the current profile operations to global
		private.settings.sharedOperations = CopyTable(private.settings.operations)
		-- Clear out old profile operations
		for _, profile in private.settingsDB:ScopeKeyIterator("profile") do
			private.settings:SetForScopeKey("operations", nil, profile)
		end
	else
		-- Copy global operations to all profiles
		for _, profile in private.settingsDB:ScopeKeyIterator("profile") do
			private.settings:SetForScopeKey("operations", CopyTable(private.settings.sharedOperations), profile)
		end
		-- Clear out old global operations
		private.settings.sharedOperations = nil
	end
	private.OnProfileUpdated()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnProfileUpdated()
	private.LoadDBSettings()
	TSM.Groups.ReloadSettings()
end

function private.LoadDBSettings()
	if private.settings.globalOperations then
		Operation.Load(private.settings.sharedOperations)
	else
		Operation.Load(private.settings.operations)
	end
end

function private.ValidateCraftingCraftPriceMethod(value, operationName)
	local isValid, err = CustomPrice.Validate(value, BAD_CRAFTING_PRICE_SOURCES)
	if not isValid then
		ChatMessage.PrintfUser(L["Your craft value method for '%s' was invalid so it has been returned to the default."].." "..err, operationName)
		return false
	end
	return true
end

function private.GetMailingTargetQuantity(player, itemString, includeGuild, includeBank)
	if player then
		-- TODO: Support targets on connected realms
		player = strtrim(strmatch(player, "^[^-]+"))
	end
	local num = AltTracking.GetBagQuantity(itemString, player) + AltTracking.GetMailQuantity(itemString, player) + AltTracking.GetAuctionQuantity(itemString, player)
	if includeGuild then
		local guild = PlayerInfo.GetPlayerGuild(player, SessionInfo.GetFactionrealmName())
		if guild then
			num = num + AltTracking.GetGuildQuantity(itemString, guild)
		end
	end
	if includeBank then
		num = num + AltTracking.GetBankQuantity(itemString, player)
	end
	return num
end

function private.GetShoppingInventoryNum(itemString, includeBank, includeAuctions, includeAlts, includeGuild)
	-- Check the total inventory as an optimization
	if (CustomString.GetSourceValue("NumInventory", itemString) or 0) == 0 then
		return 0
	end

	local numHave = Mail.GetQuantity(itemString)
	if includeBank then
		numHave = numHave + BagTracking.GetTotalQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
	else
		numHave = numHave + BagTracking.GetBagQuantity(itemString)
	end
	if includeGuild then
		numHave = numHave + Guild.GetQuantity(itemString)
	end
	if includeAlts or includeAuctions then
		if includeAuctions then
			numHave = numHave + Auction.GetQuantity(itemString)
		end
		if private.connectedCharacterCache.time ~= GetTime() then
			wipe(private.connectedCharacterCache)
			for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
				for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
					tinsert(private.connectedCharacterCache, factionrealm)
					tinsert(private.connectedCharacterCache, character)
				end
			end
			private.connectedCharacterCache.time = GetTime()
		end
		for _, factionrealm, character in Table.StrideIterator(private.connectedCharacterCache, 2) do
			if includeAlts then
				numHave = numHave + AltTracking.GetBagQuantity(itemString, character, factionrealm)
				numHave = numHave + AltTracking.GetBankQuantity(itemString, character, factionrealm)
				numHave = numHave + AltTracking.GetMailQuantity(itemString, character, factionrealm)
			end
			if includeAuctions then
				numHave = numHave + AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
			end
		end
	end
	return numHave
end

function private.GetVendoringInventoryNum(itemString, includeBank, includeGuild, includeAuctions, includeMail, includeAlts, includeAltAuctions)
	-- TODO: Need to look into why we're doing this complex query for bags, but not for anything else
	local numHave = BagTracking.CreateQueryBagsItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:SumAndRelease("quantity")
	if includeBank then
		local _, bankQuantity = BagTracking.GetQuantities(itemString)
		numHave = numHave + bankQuantity + WarbankTracking.GetQuantity(itemString)
	end
	if includeGuild then
		numHave = numHave + Guild.GetQuantity(itemString)
	end
	if includeAuctions then
		numHave = numHave + Auction.GetQuantity(itemString)
	end
	if includeMail then
		numHave = numHave + Mail.GetQuantity(itemString)
	end
	if includeAlts or includeAltAuctions then
		local numAlts, numAltAuctions = AltTracking.GetQuantity(itemString)
		numHave = numHave + (includeAlts and numAlts or 0) + (includeAltAuctions and numAltAuctions or 0)
	end
	return numHave
end

function private.GetWarehousingBagQuantity(itemString)
	return BagTracking.CreateQueryBagsItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:SumAndRelease("quantity")
end
