-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Container = LibTSMWoW:Init("API.Container")
local Event = LibTSMWoW:Include("Service.Event")
local SlotId = LibTSMWoW:Include("Type.SlotId")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local private = {
	numBagSlots = nil,
	minBankSlot = nil,
	maxBankSlot = nil,
	minWarbankSlot = nil,
	maxWarbankSlot = nil,
	slotIdLocked = {},
	itemLocation = ItemLocation:CreateEmpty(),
}
local BANKSLOTS = ClientInfo.IsRetail() and Constants.InventoryConstants.NumCharacterBankSlots or NUM_BANKBAGSLOTS
local MAX_BANK_SLOTS_PER_TAB = 98



-- ============================================================================
-- Module Loading
-- ============================================================================

Container:OnModuleLoad(function()
	private.numBagSlots = NUM_BAG_SLOTS
	if ClientInfo.HasFeature(ClientInfo.FEATURES.REAGENT_BAG) then
		private.numBagSlots = private.numBagSlots + Constants.InventoryConstants.NumReagentBagSlots
	end
	private.minBankSlot = private.numBagSlots + 1
	private.maxBankSlot = private.numBagSlots + BANKSLOTS
	if ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		private.minWarbankSlot = private.maxBankSlot + 1
		private.maxWarbankSlot = private.maxBankSlot + Constants.InventoryConstants.NumAccountBankSlots
	end
	Event.Register("ITEM_LOCKED", private.ItemLockedHandler)
	Event.Register("ITEM_UNLOCKED", private.ItemUnlockedHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Iterates over all bag slots
---@return fun(): number, number @An iterator with fields: `index`, `slotId`
function Container.GetBagSlotIterator()
	return private.BagSlotIterator, nil, SlotId.Join(0, 0)
end

---Gets the item family for items that can fit in the specified bag.
---@param bag number The bag
---@return number
function Container.GetBagItemFamily(bag)
	if bag == BACKPACK_CONTAINER then
		return 0
	end
	local inventoryId = C_Container.ContainerIDToInventoryID(bag)
	local inventoryLink = GetInventoryItemLink("player", inventoryId)
	return inventoryLink and C_Item.GetItemFamily(inventoryLink) or 0
end

---Gets a list of empty slotIds and their sort values.
---@param bag number The bag to check
---@param itemFamily number The item family to check for
---@param emptySlotIds number[] A table to store the list of empty slotIds in
---@param sortvalue table<number, number> A table to store the sort values in
function Container.GenerateSortedEmptyFamilySlots(bag, itemFamily, emptySlotIds, sortvalue)
	local bagFamily = Container.GetBagItemFamily(bag)
	if bagFamily == 0 or bit.band(itemFamily, bagFamily) > 0 then
		for slot = 1, Container.GetNumSlots(bag) do
			if not Container.GetItemLink(bag, slot) then
				local slotId = SlotId.Join(bag, slot)
				tinsert(emptySlotIds, slotId)
				sortvalue[slotId] = slotId + (bagFamily > 0 and 0 or 100000)
			end
		end
	end
end

---Returns the total number of bag slots.
---@return number
function Container.GetNumBags()
	return private.numBagSlots
end

---Returns whether or not the specified bag index is a character bag.
---@param bag number The bag to check
---@return boolean
function Container.IsBag(bag)
	return bag >= BACKPACK_CONTAINER and bag <= private.numBagSlots
end

---Returns whether or not the specified bag index is a bank bag (or base container).
---@param bag number The bag to check
---@return boolean
function Container.IsBank(bag)
	return bag == BANK_CONTAINER or bag >= private.minBankSlot and bag <= private.maxBankSlot
end

---Returns whether or not the specified bag index is a warbank container.
---@param bag number The bag to check
---@return boolean
function Container.IsWarbankBag(bag)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		return false
	end
	return bag >= private.minWarbankSlot and bag <= private.maxWarbankSlot
end

---Returns whether or not the warbank is accessible.
---@return boolean
function Container.CanAccessWarbank()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		return false
	end
	return C_PlayerInfo.HasAccountInventoryLock()
end

---Iterates over the bank bags/tabs.
---@return fun(): number
function Container.BankBagIterator()
	return private.BagIteratorHelper, private.maxBankSlot, private.minBankSlot - 1
end

---Iterates over the warbank bags.
---@return fun(): number
function Container.WarbankBagIterator()
	return private.BagIteratorHelper, private.maxWarbankSlot, private.minWarbankSlot - 1
end

---Gets the keyring container index.
---@return number
function Container.GetKeyringContainer()
	return KEYRING_CONTAINER
end

---Gets the backpack container index.
---@return number
function Container.GetBackpackContainer()
	return BACKPACK_CONTAINER
end

---Gets the bank container index.
---@return number
function Container.GetBankContainer()
	return BANK_CONTAINER
end

---Gets the first bank tab index.
---@return number
function Container.GetFirstBankTabIndex()
	return private.minBankSlot
end

---Returns the total number of slots in the bag specified by the index.
---@param bag number The index of the bag
---@return number
function Container.GetNumSlots(bag)
	if ClientInfo.IsRetail() then
		if bag >= private.minBankSlot and bag <= private.maxBankSlot then
			return MAX_BANK_SLOTS_PER_TAB
		end
	else
		if bag == BANK_CONTAINER then
			return NUM_BANKGENERIC_SLOTS
		end
	end
	return C_Container.GetContainerNumSlots(bag)
end

---Returns the number of free slots in a bag.
---@param bag number The index of the bag
---@return number numFreeSlots
---@return number? bagFamily
function Container.GetNumFreeSlots(bag)
	return C_Container.GetContainerNumFreeSlots(bag)
end

---Returns the item ID in a container slot.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
---@return number
function Container.GetItemId(bag, slot)
	return C_Container.GetContainerItemID(bag, slot)
end

---Returns info for an item in a container slot.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
---@return number iconFileID The icon texture
---@return number stackCount The number of items in the bag slot
---@return number quality The quality of the contained item
---@return string link The itemLink of the item in the bag slot
---@return number itemId The unique identifier for the item in the bag slot
---@return boolean isBound Whether the item is bound of the character
function Container.GetItemInfo(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info then
		return
	end
	return info.iconFileID, info.stackCount, info.quality, info.hyperlink, info.itemID, info.isBound
end

---Returns the size of the stack in a container slot.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
---@return number
function Container.GetStackCount(bag, slot)
	local _, stackCount = Container.GetItemInfo(bag, slot)
	return stackCount
end

---Returns whether or not an item is bound.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
---@return boolean
function Container.IsBound(bag, slot)
	local _, _, _, _, _, isBound = Container.GetItemInfo(bag, slot)
	return isBound
end

---Returns a link of the object located in the specified slot of a specified bag.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
---@return string
function Container.GetItemLink(bag, slot)
	return C_Container.GetContainerItemLink(bag, slot)
end

---Uses an item from given bag slot.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
function Container.UseItem(bag, slot)
	C_Container.UseContainerItem(bag, slot)
end

---Pick up an item from given bag slot.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
function Container.PickupItem(bag, slot)
	C_Container.PickupContainerItem(bag, slot)
end

---Places part of a stack of items from a container onto the cursor.
---@param bag number The index of the bag
---@param slot number The index of the slot whitin the bag
---@param count number The quantity to split
function Container.SplitItem(bag, slot, count)
	C_Container.SplitContainerItem(bag, slot, count)
end

---Register a secure hook function for when a container item is used.
---@param func function
function Container.SecureHookUseItem(func)
	hooksecurefunc(C_Container, "UseContainerItem", func)
	-- 3.3.5: продажа торговцу правым кликом в стандартных/ElvUI сумках вызывает ГЛОБАЛЬНУЮ
	-- UseContainerItem, а не C_Container.UseContainerItem. Шим ClassicAPI делает
	-- C_Container.UseContainerItem = UseContainerItem (ссылка на оригинал), поэтому хук
	-- таблицы выше ловит только вызовы изнутри TSM (кнопка Vendoring Sell). Без этого
	-- ручные продажи торговцу не пишутся в Accounting -> на Dashboard не виден профит
	-- от вендоринга. Дополнительно хукаем глобальную функцию. После хука таблицы поле
	-- C_Container.UseContainerItem становится обёрткой и уже не равно глобалу, поэтому
	-- двойного вызова колбэка не будет.
	if type(UseContainerItem) == "function" and UseContainerItem ~= C_Container.UseContainerItem then
		hooksecurefunc("UseContainerItem", func)
	end
end

---Queries the game for how many of an item the character owns.
---@param itemId number The item ID
---@return number bagQuantity
---@return number bankQuantity
---@return number warbankQuantity
function Container.GetItemCount(itemId)
	-- GetItemCount() is a bit buggy and not all combinations of arguments work, so carefully call it to calculate the quantities
	local bagQuantity = C_Item.GetItemCount(itemId, false, false, false, false)
	local warbankQuantity = C_Item.GetItemCount(itemId, false, false, false, true) - bagQuantity
	local bankQuantity = C_Item.GetItemCount(itemId, true, false, true, false) - bagQuantity
	return bagQuantity, bankQuantity, warbankQuantity
end

---Returns if a bag slot is locked.
---@param bag number The index of the bag
---@param slot number The index of the slot within the bag
---@return boolean
function Container.IsBagSlotLocked(bag, slot)
	return private.slotIdLocked[SlotId.Join(bag, slot)] or false
end

---Gets the total number of free bag slots.
---@return number
function Container.GetTotalFreeBagSlots()
	return CalculateTotalNumberOfFreeBagSlots()
end

---Returns whether or not an item can be deposited into the warbank.
---@param bag number The source bag index
---@param slot number The source slot index
---@return boolean
function Container.CanDepositIntoWarbank(bag, slot)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		return false
	end
	private.itemLocation:SetBagAndSlot(bag, slot)
	return C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, private.itemLocation)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.BagIteratorHelper(maxValue, bag)
	bag = bag + 1
	if bag > maxValue then
		return
	end
	return bag
end

function private.BagSlotIterator(_, slotId)
	local bag, slot = SlotId.Split(slotId)
	while bag <= private.numBagSlots do
		slot = slot + 1
		if slot <= Container.GetNumSlots(bag) then
			return SlotId.Join(bag, slot)
		end
		bag = bag + 1
		slot = 0
	end
end

function private.ItemLockedHandler(_, bag, slot)
	if not slot then
		return
	end
	private.slotIdLocked[SlotId.Join(bag, slot)] = true
end

function private.ItemUnlockedHandler(_, bag, slot)
	if not slot then
		return
	end
	private.slotIdLocked[SlotId.Join(bag, slot)] = nil
end
