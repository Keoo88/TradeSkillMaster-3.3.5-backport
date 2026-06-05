-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local MoveContext = TSM.Banking:NewPackage("MoveContext")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local SlotId = TSM.LibTSMWoW:Include("Type.SlotId")
local Container = TSM.LibTSMWoW:Include("API.Container")
local GuildAPI = TSM.LibTSMWoW:Include("API.Guild")
local Group = TSM.LibTSMTypes:Include("Group")
local Threading = TSM.LibTSMTypes:Include("Threading")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local Guild = TSM.LibTSMService:Include("Guild")
local LibTSMClass = LibStub("LibTSMClass")
local private = {
	bagToBank = nil,
	bagToWarbank = nil,
	bankToBag = nil,
	warBankToBag = nil,
	bagToGuildBank = nil,
	guildBankToBag = nil,
}



-- ============================================================================
-- BaseMoveContext Class
-- ============================================================================

local BaseMoveContext = LibTSMClass.DefineClass("BaseMoveContext", nil, "ABSTRACT")



-- ============================================================================
-- BagToBankMoveContext Class
-- ============================================================================

local BagToBankMoveContext = LibTSMClass.DefineClass("BagToBankMoveContext", BaseMoveContext)

function BagToBankMoveContext.MoveSlot(self, fromSlotId, toSlotId, quantity)
	local fromBag, fromSlot = SlotId.Split(fromSlotId)
	Container.SplitItem(fromBag, fromSlot, quantity)
	if GetCursorInfo() == "item" then
		Container.PickupItem(SlotId.Split(toSlotId))
	end
	ClearCursor()
end

function BagToBankMoveContext.GetSlotQuantity(self, slotId)
	return private.ContainerGetSlotQuantity(slotId)
end

function BagToBankMoveContext.SlotIdIterator(self, itemString)
	return private.BagSlotIdIterator(itemString)
end

function BagToBankMoveContext.GetEmptySlotsThreaded(self, emptySlotIds)
	local sortValue = Threading.AcquireSafeTempTable()
	if not ClientInfo.IsRetail() then
		private.GetEmptySlotsHelper(BANK_CONTAINER, emptySlotIds, sortValue)
	end
	for bag in Container.BankBagIterator() do
		private.GetEmptySlotsHelper(bag, emptySlotIds, sortValue)
	end
	Table.SortWithValueLookup(emptySlotIds, sortValue)
	TempTable.Release(sortValue)
end

function BagToBankMoveContext.GetTargetSlotId(self, itemString, emptySlotIds, slotId)
	return private.ContainerGetTargetSlotId(itemString, emptySlotIds, slotId)
end



-- ============================================================================
-- BagToWarbankMoveContext Class
-- ============================================================================

local BagToWarbankMoveContext = LibTSMClass.DefineClass("BagToWarbankMoveContext", BagToBankMoveContext)

function BagToWarbankMoveContext.GetEmptySlotsThreaded(self, emptySlotIds)
	local sortValue = Threading.AcquireSafeTempTable()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		for bag in Container.WarbankBagIterator() do
			private.GetEmptySlotsHelper(bag, emptySlotIds, sortValue)
		end
	end
end



-- ============================================================================
-- BankToBagMoveContext Class
-- ============================================================================

local BankToBagMoveContext = LibTSMClass.DefineClass("BankToBagMoveContext", BaseMoveContext)

function BankToBagMoveContext.MoveSlot(self, fromSlotId, toSlotId, quantity)
	local fromBag, fromSlot = SlotId.Split(fromSlotId)
	Container.SplitItem(fromBag, fromSlot, quantity)
	if GetCursorInfo() == "item" then
		Container.PickupItem(SlotId.Split(toSlotId))
	end
	ClearCursor()
end

function BankToBagMoveContext.GetSlotQuantity(self, slotId)
	return private.ContainerGetSlotQuantity(slotId)
end

function BankToBagMoveContext.SlotIdIterator(self, itemString)
	itemString = Group.TranslateItemString(itemString)
	return BagTracking.CreateQueryBankItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Select("slotId", "quantity")
		:IteratorAndRelease()
end

function BankToBagMoveContext.GetEmptySlotsThreaded(self, emptySlotIds)
	private.BagGetEmptySlotsThreaded(emptySlotIds)
end

function BankToBagMoveContext.GetTargetSlotId(self, itemString, emptySlotIds, slotId)
	return private.ContainerGetTargetSlotId(itemString, emptySlotIds)
end



-- ============================================================================
-- WarbankToBagMoveContext Class
-- ============================================================================

local WarbankToBagMoveContext = LibTSMClass.DefineClass("WarbankToBagMoveContext", BankToBagMoveContext)

function WarbankToBagMoveContext.SlotIdIterator(self, itemString)
	itemString = Group.TranslateItemString(itemString)
	return WarbankTracking.CreateQuerySlotItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Select("slotId", "quantity")
		:IteratorAndRelease()
end



-- ============================================================================
-- BagToGuildBankMoveContext Class
-- ============================================================================

local BagToGuildBankMoveContext = LibTSMClass.DefineClass("BagToGuildBankMoveContext", BaseMoveContext)

function BagToGuildBankMoveContext.MoveSlot(self, fromSlotId, toSlotId, quantity)
	local fromBag, fromSlot = SlotId.Split(fromSlotId)
	Container.SplitItem(fromBag, fromSlot, quantity)
	if GetCursorInfo() == "item" then
		PickupGuildBankItem(SlotId.Split(toSlotId))
	end
	ClearCursor()
end

function BagToGuildBankMoveContext.GetSlotQuantity(self, slotId)
	return private.ContainerGetSlotQuantity(slotId)
end

function BagToGuildBankMoveContext.SlotIdIterator(self, itemString)
	return private.BagSlotIdIterator(itemString)
end

function BagToGuildBankMoveContext.GetEmptySlotsThreaded(self, emptySlotIds)
	local currentTab = GuildAPI.GetCurrentTab()
	local numWithdrawals = GuildAPI.GetNumDailyWithdrawals(currentTab)
	if numWithdrawals == -1 or numWithdrawals >= GuildAPI.GetNumTabSlots() then
		for slot = 1, GuildAPI.GetNumTabSlots() do
			if GuildAPI.GetItemCount(currentTab, slot) == 0 then
				tinsert(emptySlotIds, SlotId.Join(currentTab, slot))
			end
		end
	end
	for tab = 1, GuildAPI.GetNumTabs() do
		if tab ~= currentTab then
			-- Only use tabs which we have at least enough withdrawals to withdraw every slot
			numWithdrawals = GuildAPI.GetNumDailyWithdrawals(tab)
			if numWithdrawals == -1 or numWithdrawals >= GuildAPI.GetNumTabSlots() then
				for slot = 1, GuildAPI.GetNumTabSlots() do
					if GuildAPI.GetItemCount(tab, slot) == 0 then
						tinsert(emptySlotIds, SlotId.Join(tab, slot))
					end
				end
			end
		end
	end
end

function BagToGuildBankMoveContext.GetTargetSlotId(self, itemString, emptySlotIds, slotId)
	return tremove(emptySlotIds, 1)
end



-- ============================================================================
-- GuildBankToBagMoveContext Class
-- ============================================================================

local GuildBankToBagMoveContext = LibTSMClass.DefineClass("GuildBankToBagMoveContext", BaseMoveContext)

function GuildBankToBagMoveContext.MoveSlot(self, fromSlotId, toSlotId, quantity)
	local fromTab, fromSlot = SlotId.Split(fromSlotId)
	SplitGuildBankItem(fromTab, fromSlot, quantity)
	if GetCursorInfo() == "item" then
		Container.PickupItem(SlotId.Split(toSlotId))
	end
	ClearCursor()
end

function GuildBankToBagMoveContext.GetSlotQuantity(self, slotId)
	local tab, slot = SlotId.Split(slotId)
	GuildAPI.QueryTab(tab)
	return GuildAPI.GetItemCount(tab, slot) or 0
end

function GuildBankToBagMoveContext.SlotIdIterator(self, itemString)
	itemString = Group.TranslateItemString(itemString)
	return Guild.NewIndexQueryItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Select("slotId", "quantity")
		:IteratorAndRelease()
end

function GuildBankToBagMoveContext.GetEmptySlotsThreaded(self, emptySlotIds)
	private.BagGetEmptySlotsThreaded(emptySlotIds)
end

function GuildBankToBagMoveContext.GetTargetSlotId(self, itemString, emptySlotIds, slotId)
	return private.ContainerGetTargetSlotId(itemString, emptySlotIds)
end



-- ============================================================================
-- Module Functions
-- ============================================================================

function MoveContext.GetBagToBank()
	private.bagToBank = private.bagToBank or BagToBankMoveContext()
	return private.bagToBank
end

function MoveContext.GetBagToWarbank()
	private.bagToWarbank = private.bagToWarbank or BagToWarbankMoveContext()
	return private.bagToWarbank
end

function MoveContext.GetBankToBag()
	private.bankToBag = private.bankToBag or BankToBagMoveContext()
	return private.bankToBag
end

function MoveContext.GetWarbankToBag()
	private.warBankToBag = private.warBankToBag or WarbankToBagMoveContext()
	return private.warBankToBag
end

function MoveContext.GetBagToGuildBank()
	private.bagToGuildBank = private.bagToGuildBank or BagToGuildBankMoveContext()
	return private.bagToGuildBank
end

function MoveContext.GetGuildBankToBag()
	private.guildBankToBag = private.guildBankToBag or GuildBankToBagMoveContext()
	return private.guildBankToBag
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ContainerGetSlotQuantity(slotId)
	return Container.GetStackCount(SlotId.Split(slotId)) or 0
end

function private.BagSlotIdIterator(itemString)
	itemString = Group.TranslateItemString(itemString)
	local query = BagTracking.CreateQueryBagsItem(itemString)
		:Select("slotId", "quantity")
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
	if TSM.Banking.IsGuildBankOpen() then
		query:Equal("isBound", false)
	end
	return query:IteratorAndRelease()
end

function private.BagGetEmptySlotsThreaded(emptySlotIds)
	local sortValue = Threading.AcquireSafeTempTable()
	for bag = BACKPACK_CONTAINER, Container.GetNumBags() do
		private.GetEmptySlotsHelper(bag, emptySlotIds, sortValue)
	end
	Table.SortWithValueLookup(emptySlotIds, sortValue)
	TempTable.Release(sortValue)
end

function private.GetEmptySlotsHelper(bag, emptySlotIds, sortValue)
	local isSpecial = nil
	if bag == BACKPACK_CONTAINER or bag == BANK_CONTAINER or (ClientInfo.IsRetail() and Container.IsBank(bag)) then
		isSpecial = false
	else
		isSpecial = Container.GetBagItemFamily(bag) ~= 0
	end
	for slot = 1, Container.GetNumSlots(bag) do
		if not private.BagSlotHasItem(bag, slot) then
			local slotId = SlotId.Join(bag, slot)
			tinsert(emptySlotIds, slotId)
			sortValue[slotId] = slotId + (isSpecial and 0 or 100000)
		end
	end
end

function private.BagSlotHasItem(bag, slot)
	return Container.GetItemLink(bag, slot) and true or false
end

function private.ContainerGetTargetSlotId(itemString, emptySlotIds, depositSlotId)
	for i, slotId in ipairs(emptySlotIds) do
		local bag = SlotId.Split(slotId)
		if (not depositSlotId or not Container.IsWarbankBag(bag) or Container.CanDepositIntoWarbank(SlotId.Split(depositSlotId))) and BagTracking.ItemWillGoInBag(itemString, bag) then
			return tremove(emptySlotIds, i)
		end
	end
end
