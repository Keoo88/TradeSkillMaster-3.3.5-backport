-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local WarbankTracking = LibTSMService:Init("Inventory.WarbankTracking")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Database = LibTSMService:From("LibTSMUtil"):Include("Database")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local SlotId = LibTSMService:From("LibTSMWoW"):Include("Type.SlotId")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	slotDB = nil,
	quantityDB = nil,
	quantityStorage = nil,
	updates = {
		pending = {},
		bagList = {},
	},
	isFirstBankOpen = true,
	baseItemQuantityQuery = nil,
	quantityCallbackQuery = nil, -- luacheck: ignore 1004 - just stored for GC reasons
	quantityCallbacks = {},
	bagUpdateTimer = nil,
	quantityCallbackTimer = nil,
	prevQuantities = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

WarbankTracking:OnModuleLoad(function()
	private.slotDB = Database.NewSchema("WARBANK_TRACKING_SLOTS")
		:AddUniqueNumberField("slotId")
		:AddNumberField("bag")
		:AddNumberField("slot")
		:AddStringField("itemLink")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("quantity")
		:AddIndex("slotId")
		:Commit()
	private.quantityDB = Database.NewSchema("WARBANK_TRACKING_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("quantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewQuery()
		:Select("quantity")
		:Equal("baseItemString", Database.BoundQueryParam())
	private.quantityCallbackQuery = private.quantityDB:NewQuery()
		:SetUpdateCallback(private.OnQuantityCallbackQueryUpdated)
	private.bagUpdateTimer = DelayTimer.New("WARBANK_TRACKING_BAG_UPDATE", private.UpdateDelayedHandler)
	private.quantityCallbackTimer = DelayTimer.New("WARBANK_TRACKING_QUANTITY_CALLBACK", private.DelayedBagTrackingQuantityCallback)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Warbank item quantities
function WarbankTracking.Load(quantityData)
	if not LibTSMService.IsRetail() then
		wipe(quantityData)
		return
	end
	-- Sanitize the storage table
	for levelItemString, quantity in pairs(quantityData) do
		if quantity <= 0 then
			quantityData[levelItemString] = nil
		end
	end
	private.quantityStorage = quantityData
	-- Build the DB
	private.quantityDB:BulkInsertStart()
	for levelItemString, quantity in pairs(quantityData) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
end

---Starts running the bag tracking code.
function WarbankTracking.Start()
	if not LibTSMService.IsRetail() then
		return
	end
	Event.Register("BAG_UPDATE", private.BagUpdateHandler)
	Event.Register("BAG_UPDATE_DELAYED", private.UpdateDelayedHandler)
	DefaultUI.RegisterBankVisibleCallback(private.BankVisible, true)
	DefaultUI.RegisterAccountBankVisibleCallback(private.BankVisible, true)
end

---Registers a callback for when the bag quantities change.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function WarbankTracking.RegisterQuantityCallback(callback)
	tinsert(private.quantityCallbacks, callback)
end

---Creates a query of the account warbank.
---@return DatabaseQuery
function WarbankTracking.CreateQuerySlot()
	return private.slotDB:NewQuery()
end

---Creates a query of warbank slots with the specified item.
---@return DatabaseQuery
function WarbankTracking.CreateQuerySlotItem(itemString)
	local query = private.slotDB:NewQuery()
	if itemString == ItemString.GetBaseFast(itemString) then
		query:Equal("baseItemString", itemString)
	elseif ItemString.IsLevel(itemString) then
		query:Equal("levelItemString", itemString)
	else
		query:Equal("itemString", itemString)
	end
	return query
end

---Iterates over the bag quantities.
---@return fun(): number, string, number @Iterator with fields: `index`, `levelItemString`, `quantity`
function WarbankTracking.QuantityIterator()
	return private.quantityDB:NewQuery()
		:Select("levelItemString", "quantity")
		:IteratorAndRelease()
end

---Gets the number of an item.
---@param itemString string The item string
---@return number
function WarbankTracking.GetQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("quantity")
	else
		local levelItemString = ItemString.ToLevel(itemString)
		return private.quantityDB:GetUniqueRowField("levelItemString", levelItemString, "quantity") or 0
	end
end

---Forces a deduction in the item quantity.
---@param itemString string The item string
---@param quantity number The amount to deduct
function WarbankTracking.ForceQuantityDeduction(itemString, quantity)
	if DefaultUI.IsBankVisible() or DefaultUI.IsAccountBankVisible() then
		return
	end
	local levelItemString = ItemString.ToLevel(itemString)
	if private.isFirstBankOpen then
		-- Haven't scanned yet, so just deduct the quantity
		if (private.quantityStorage[levelItemString] or -math.huge) >= quantity then
			private.ChangeItemTotal(levelItemString, -quantity)
		end
		return
	end
	private.slotDB:SetQueryUpdatesPaused(true)
	local query = private.slotDB:NewQuery()
		:Equal("itemString", itemString)
	for _, row in query:Iterator() do
		if quantity > 0 then
			local rowQuantity = row:GetField("quantity")
			if rowQuantity <= quantity then
				private.ChangeItemTotal(levelItemString, -rowQuantity)
				private.slotDB:DeleteRow(row)
				quantity = quantity - rowQuantity
			else
				row:SetField("quantity", rowQuantity - quantity)
					:Update()
				private.ChangeItemTotal(levelItemString, -quantity)
				quantity = 0
			end
		end
	end
	query:Release()
	private.slotDB:SetQueryUpdatesPaused(false)
end



-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.BankVisible()
	if not Container.CanAccessWarbank() then
		return
	end
	private.quantityDB:SetQueryUpdatesPaused(true)
	if private.isFirstBankOpen then
		private.isFirstBankOpen = false
		-- This is the first time opening the bank so we'll scan all the items so wipe our existing quantities
		wipe(private.quantityStorage)
		private.quantityDB:Truncate()
	end
	for bag in Container.WarbankBagIterator() do
		private.BagUpdateHandler(nil, bag)
	end
	private.UpdateDelayedHandler()
	private.quantityDB:SetQueryUpdatesPaused(false)
end

function private.BagUpdateHandler(_, bag)
	if private.updates.pending[bag] or not Container.IsWarbankBag(bag) or not Container.CanAccessWarbank() then
		return
	end
	private.updates.pending[bag] = true
	tinsert(private.updates.bagList, bag)
end

function private.UpdateDelayedHandler()
	if (not DefaultUI.IsBankVisible() and not DefaultUI.IsAccountBankVisible()) or not Container.CanAccessWarbank() then
		return
	end
	private.slotDB:SetQueryUpdatesPaused(true)

	-- Scan any pending bank bags
	for i, bag in Table.ReverseIPairs(private.updates.bagList) do
		local result = true
		for slot = 1, Container.GetNumSlots(bag) do
			if not private.ScanSlot(bag, slot) then
				result = false
			end
		end
		if result then
			private.updates.pending[bag] = nil
			tremove(private.updates.bagList, i)
		end
	end
	if #private.updates.bagList > 0 then
		-- Some failed to scan so try again
		private.bagUpdateTimer:RunForFrames(2)
	end

	private.slotDB:SetQueryUpdatesPaused(false)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ScanSlot(bag, slot)
	local _, quantity, _, link, itemId = Container.GetItemInfo(bag, slot)
	if quantity and not itemId then
		-- We are pending item info for this slot so try again later to scan it
		return false
	elseif quantity == 0 then
		-- This item is going away, so try again later to scan it
		return false
	end
	local itemString = ItemString.Get(link)
	local levelItemString = itemString and ItemString.ToLevel(itemString)
	local slotId = SlotId.Join(bag, slot)
	local row = private.slotDB:GetUniqueRow("slotId", slotId)
	if levelItemString then
		if row then
			if row:GetField("itemLink") ~= link then
				row:SetField("itemLink", link)
					:SetField("itemString", ItemString.Get(link))
			end
			local oldLevelItemString, oldQuantity = row:GetFields("levelItemString", "quantity")
			if levelItemString ~= oldLevelItemString then
				-- Remove the old item and add the new one
				private.ChangeItemTotal(oldLevelItemString, -oldQuantity)
				private.ChangeItemTotal(levelItemString, quantity)
				row:SetField("quantity", quantity)
			elseif quantity ~= oldQuantity then
				-- Update the quantity
				private.ChangeItemTotal(levelItemString, quantity - oldQuantity)
				row:SetField("quantity", quantity)
			end
			row:CreateOrUpdateAndRelease()
		else
			-- There was nothing here previously so create a new row
			private.slotDB:NewRow()
				:SetField("slotId", slotId)
				:SetField("bag", bag)
				:SetField("slot", slot)
				:SetField("itemLink", link)
				:SetField("itemString", ItemString.Get(link))
				:SetField("quantity", quantity)
				:CreateOrUpdateAndRelease()
			-- Add to the item totals
			private.ChangeItemTotal(levelItemString, quantity)
		end
	elseif row then
		-- Nothing here now so delete the row and remove from the item totals
		local oldLevelItemString, oldQuantity = row:GetFields("levelItemString", "quantity")
		private.ChangeItemTotal(oldLevelItemString, -oldQuantity)
		private.slotDB:DeleteRow(row)
		row:Release()
	end
	return true
end

function private.DelayedBagTrackingQuantityCallback()
	local newQuantities = TempTable.Acquire()
	private.quantityDB:NewQuery()
		:Select("levelItemString", "quantity")
		:AsTable(newQuantities)
		:Release()
	local updatedItems = TempTable.Acquire()
	Table.GetChangedKeys(private.prevQuantities, newQuantities, updatedItems)
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
		wipe(private.prevQuantities)
		for levelItemString, quantity in pairs(newQuantities) do
			private.prevQuantities[levelItemString] = quantity
		end
		for _, callback in ipairs(private.quantityCallbacks) do
			callback(updatedItems)
		end
	end
	TempTable.Release(newQuantities)
	TempTable.Release(updatedItems)
end

function private.OnQuantityCallbackQueryUpdated(...)
	private.quantityCallbackTimer:RunForFrames(2)
end

function private.ChangeItemTotal(levelItemString, changeQuantity)
	assert(changeQuantity ~= 0)
	private.quantityStorage[levelItemString] = (private.quantityStorage[levelItemString] or 0) + changeQuantity

	local row = private.quantityDB:GetUniqueRow("levelItemString", levelItemString)
	if row then
		local newValue = row:GetField("quantity") + changeQuantity
		assert(newValue >= 0)
		if newValue == 0 then
			-- Remove this row
			private.quantityDB:DeleteRow(row)
		else
			-- Update this row
			row:SetField("quantity", newValue)
				:Update()
		end
		row:Release()
	else
		-- Create a new row
		assert(changeQuantity > 0)
		private.quantityDB:NewRow()
			:SetField("levelItemString", levelItemString)
			:SetField("quantity", changeQuantity)
			:Create()
	end

	assert(private.quantityStorage[levelItemString] >= 0)
	if private.quantityStorage[levelItemString] == 0 then
		private.quantityStorage[levelItemString] = nil
	end
end
