-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:Init("Guild.Scanner")
local Database = LibTSMService:From("LibTSMUtil"):Include("Database")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Guild = LibTSMService:From("LibTSMWoW"):Include("API.Guild")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local TooltipScanning = LibTSMService:From("LibTSMWoW"):Include("Service.TooltipScanning")
local SlotId = LibTSMService:From("LibTSMWoW"):Include("Type.SlotId")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local private = {
	indexDB = nil,
	quantityDB = nil,
	baseItemQuantityQuery = nil,
	scanTimer = nil,
	petScanTimer = nil,
	nameTimer = nil,
	quantityStorage = nil,
	currentQuantityStorage = nil,
	playerGuild = nil,
	nameCallbacks = {},
	pendingPetSlotIds = {},
}
local MAX_PET_SCANS = 10



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	private.indexDB = Database.NewSchema("GUILD_BANK_INDEX")
		:AddUniqueNumberField("slotId")
		:AddNumberField("tab")
		:AddNumberField("slot")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("quantity")
		:AddIndex("slotId")
		:AddIndex("itemString")
		:Commit()
	private.quantityDB = Database.NewSchema("GUILD_BANK_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("guildQuantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewQuery()
		:Select("guildQuantity")
		:Equal("baseItemString", Database.BoundQueryParam())
	if ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
		private.scanTimer = DelayTimer.New("GUILD_BANK_SCAN", private.GuildBankChangedDelayed)
		private.petScanTimer = DelayTimer.New("GUILD_BANK_PET_SCAN", private.ScanPetsDeferred)
	end
	private.nameTimer = DelayTimer.New("GUILD_BANK_GUILD_NAME", private.GetGuildName)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param quantityData table<string,number> Guild bank item quantities
function Scanner.Load(quantityData)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
		wipe(quantityData)
		return
	end
	private.quantityStorage = quantityData
end

---Starts running the scanning code.
function Scanner.Start()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
		DefaultUI.RegisterGuildBankVisibleCallback(Guild.QueryAllTabs, true)
		Event.Register("GUILDBANKBAGSLOTS_CHANGED", function() private.scanTimer:RunForFrames(2) end)
	end
	Event.Register("PLAYER_GUILD_UPDATE", private.GetGuildName)
	private.nameTimer:RunForFrames(1)
end

---Registers a function to call when the player's guild name is loaded or changes.
---@param func fun(name?: string)
function Scanner.RegisterNameCallback(func)
	tinsert(private.nameCallbacks, func)
end

---Creates a query against the index DB.
---@return DatabaseQuery
function Scanner.NewIndexQuery()
	return private.indexDB:NewQuery()
end

---Creates a query against the index DB for a specific item.
---@param itemString string The item string
---@return DatabaseQuery
function Scanner.NewIndexQueryItem(itemString)
	local query = Scanner.NewIndexQuery()
	if itemString == ItemString.GetBaseFast(itemString) then
		query:Equal("baseItemString", itemString)
	elseif ItemString.IsLevel(itemString) then
		query:Equal("levelItemString", itemString)
	else
		query:Equal("itemString", itemString)
	end
	return query
end

---Gets the quantity of a given item.
---@param itemString string The item string
---@return number
function Scanner.GetQuantity(itemString)
	if itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("guildQuantity")
	else
		local levelItemString = ItemString.ToLevel(itemString)
		return private.quantityDB:GetUniqueRowField("levelItemString", levelItemString, "guildQuantity") or 0
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetGuildName()
	if not Guild.IsInGuild() then
		private.SetPlayerGuild(nil)
		return
	end
	if not private.SetPlayerGuild(Guild.GetName()) then
		-- Try again next frame
		private.nameTimer:RunForFrames(1)
		return
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
		for levelItemString, quantity in pairs(private.currentQuantityStorage) do
			if quantity <= 0 or levelItemString ~= ItemString.ToLevel(levelItemString) then
				private.currentQuantityStorage[levelItemString] = nil
			end
		end
		private.RebuildQuantityDB()
	end
end

function private.SetPlayerGuild(name)
	if private.playerGuild == name then
		return
	end
	private.playerGuild = name
	for _, callback in ipairs(private.nameCallbacks) do
		callback(name)
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) and name then
		private.quantityStorage[name] = private.quantityStorage[name] or {}
		private.currentQuantityStorage = private.quantityStorage[name]
	else
		private.currentQuantityStorage = nil
	end
	return name and true or false
end

function private.RebuildQuantityDB()
	private.quantityDB:TruncateAndBulkInsertStart()
	for levelItemString, quantity in pairs(private.currentQuantityStorage) do
		if quantity > 0 then
			private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
		else
			private.currentQuantityStorage[levelItemString] = nil
		end
	end
	private.quantityDB:BulkInsertEnd()
end

function private.GuildBankChangedDelayed()
	if not DefaultUI.IsGuildBankVisible() then
		return
	end
	if not private.currentQuantityStorage then
		-- We don't have the guild name yet, so try again after a short delay
		private.scanTimer:RunForFrames(2)
		return
	end

	wipe(private.currentQuantityStorage)
	wipe(private.pendingPetSlotIds)
	private.indexDB:TruncateAndBulkInsertStart()
	local didFail = false
	for tab = 1, Guild.GetNumTabs() do
		-- Only scan tabs which we have at least enough withdrawals to withdraw every slot
		local numWithdrawals = Guild.GetNumDailyWithdrawals(tab)
		if numWithdrawals == -1 or numWithdrawals >= Guild.GetNumTabSlots() then
			for slot = 1, Guild.GetNumTabSlots() do
				local itemLink = Guild.GetItemLink(tab, slot)
				if itemLink then
					local slotId = SlotId.Join(tab, slot)
					local itemString = ItemString.Get(itemLink)
					local levelItemString = ItemString.ToLevel(itemString)
					if levelItemString == ItemString.GetPetCage() then
						private.pendingPetSlotIds[slotId] = true
						levelItemString = nil
					end
					if levelItemString then
						local quantity = Guild.GetItemCount(tab, slot)
						if quantity == 0 then
							-- The info for this slot isn't fully loaded yet
							Log.Err("Failed to scan guild bank slot (%d)", slotId)
							didFail = true
							break
						end
						private.currentQuantityStorage[levelItemString] = (private.currentQuantityStorage[levelItemString] or 0) + quantity
						private.indexDB:BulkInsertNewRow(slotId, tab, slot, itemString, quantity)
					end
				end
			end
		end
		if didFail then
			break
		end
	end
	private.RebuildQuantityDB()
	private.indexDB:BulkInsertEnd()

	if didFail then
		private.scanTimer:RunForFrames(2)
	elseif next(private.pendingPetSlotIds) then
		private.petScanTimer:RunForFrames(2)
	else
		private.petScanTimer:Cancel()
	end
end

function private.ScanPetsDeferred()
	if not DefaultUI.IsGuildBankVisible() or not private.currentQuantityStorage then
		return
	end

	local numPetSlotIdsScanned = 0
	private.indexDB:BulkInsertStart()
	for slotId in pairs(private.pendingPetSlotIds) do
		local tab, slot = SlotId.Split(slotId)
		local speciesId, level, breedQuality = TooltipScanning.GetGuildBankBattlePetInfo(tab, slot)
		if speciesId and level and breedQuality then
			local itemString = "p:"..speciesId..":"..level..":"..breedQuality
			if itemString then
				private.pendingPetSlotIds[slotId] = nil
				local quantity = Guild.GetItemCount(tab, slot)
				local levelItemString = ItemString.ToLevel(itemString)
				private.currentQuantityStorage[levelItemString] = (private.currentQuantityStorage[levelItemString] or 0) + quantity
				private.indexDB:BulkInsertNewRow(slotId, tab, slot, itemString, quantity)
			end
		end
		-- Throttle how many pet slots we scan per call (regardless of whether or not it was successful)
		numPetSlotIdsScanned = numPetSlotIdsScanned + 1
		if numPetSlotIdsScanned == MAX_PET_SCANS then
			break
		end
	end
	private.RebuildQuantityDB()
	private.indexDB:BulkInsertEnd()
	Log.Info("Scanned %d pet slots", numPetSlotIdsScanned)

	if next(private.pendingPetSlotIds) then
		-- There are more to scan
		private.petScanTimer:RunForFrames(2)
	end
end
