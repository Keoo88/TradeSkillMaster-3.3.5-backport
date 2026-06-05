-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Groups = TSM.Vendoring:NewPackage("Groups") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local SlotId = TSM.LibTSMWoW:Include("Type.SlotId")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Container = TSM.LibTSMWoW:Include("API.Container")
local Group = TSM.LibTSMTypes:Include("Group")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local Vendor = TSM.LibTSMService:Include("Vendor")
local VendoringOperation = TSM.LibTSMSystem:Include("VendoringOperation")
local private = {
	settings = nil,
	buyThreadId = nil,
	sellThreadId = nil,
	tempGroups = {},
	printedBagsFullMsg = false,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Groups.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "vendoringOptions", "displayMoneyCollected")
	private.buyThreadId = Threading.New("VENDORING_GROUP_BUY", private.BuyThread)
	private.sellThreadId = Threading.New("VENDORING_GROUP_SELL", private.SellThread)
end

function Groups.BuyGroups(groups, callback)
	Groups.StopBuySell()

	wipe(private.tempGroups)
	for _, groupPath in ipairs(groups) do
		tinsert(private.tempGroups, groupPath)
	end
	Threading.SetCallback(private.buyThreadId, callback)
	Threading.Start(private.buyThreadId, private.tempGroups)
end

function Groups.SellGroups(groups, callback)
	Groups.StopBuySell()

	wipe(private.tempGroups)
	for _, groupPath in ipairs(groups) do
		tinsert(private.tempGroups, groupPath)
	end
	Threading.SetCallback(private.sellThreadId, callback)
	Threading.Start(private.sellThreadId, private.tempGroups)
end

function Groups.StopBuySell()
	Threading.Kill(private.buyThreadId)
	Threading.Kill(private.sellThreadId)
end



-- ============================================================================
-- Buy Thread
-- ============================================================================

function private.BuyThread(groups)
	for _, groupPath in ipairs(groups) do
		groups[groupPath] = true
	end

	local itemsToBuy = Threading.AcquireSafeTempTable()
	local itemBuyQuantity = Threading.AcquireSafeTempTable()
	local query = Vendor.NewScannerQuery()
		:InnerJoin(Group.GetItemDBForJoin(), "itemString")
		:Select("itemString", "groupPath", "numAvailable")
	for _, itemString, groupPath, numAvailable in query:Iterator() do
		numAvailable = numAvailable == -1 and math.huge or numAvailable
		if groups[groupPath] and numAvailable > 0 then
			local numToBuy = VendoringOperation.GetNumToBuy(itemString)
			if numToBuy > 0 then
				assert(not itemBuyQuantity[itemString])
				tinsert(itemsToBuy, itemString)
				itemBuyQuantity[itemString] = min(numToBuy, numAvailable)
			end
		end
	end
	query:Release()

	for _, itemString in ipairs(itemsToBuy) do
		local numToBuy = itemBuyQuantity[itemString]
		TSM.Vendoring.Buy.BuyItem(itemString, numToBuy)
		Threading.Yield(true)
	end

	TempTable.Release(itemsToBuy)
	TempTable.Release(itemBuyQuantity)
end



-- ============================================================================
-- Sell Thread
-- ============================================================================

function private.SellThread(groups)
	private.printedBagsFullMsg = false
	local totalValue = 0
	for _, groupPath in ipairs(groups) do
		if groupPath ~= Group.GetRootPath() then
			for _, itemString, numToSell, sellSoulbound in VendoringOperation.SellItemIterator(groupPath) do
				totalValue = totalValue + private.SellItemThreaded(itemString, numToSell, sellSoulbound)
			end
		end
	end

	if private.settings.displayMoneyCollected then
		ChatMessage.PrintfUser(L["Sold %s worth of items."], Money.ToStringForUI(totalValue))
	end
end

function private.SellItemThreaded(itemString, numToSell, sellSoulbound)
	-- Get a list of empty slots which we can use to split items into
	local emptySlotIds = private.GetEmptyBagSlotsThreaded(ItemString.IsItem(itemString) and C_Item.GetItemFamily(ItemString.ToId(itemString)) or 0)

	-- Get a list of slots containing the item we want to sell
	local slotIds = Threading.AcquireSafeTempTable()
	local bagQuery = BagTracking.CreateQueryBagsItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:Select("slotId", "quantity")
		:OrderBy("quantity", true)
	if not sellSoulbound then
		bagQuery:Equal("isBound", false)
	end
	for _, slotId in bagQuery:Iterator() do
		tinsert(slotIds, slotId)
	end
	bagQuery:Release()

	local totalValue = 0
	for _, slotId in ipairs(slotIds) do
		local bag, slot = SlotId.Split(slotId)
		local quantity = BagTracking.GetQuantityBySlotId(slotId)
		if quantity <= numToSell then
			Container.UseItem(bag, slot)
			totalValue = totalValue + ((ItemInfo.GetVendorSell(itemString) or 0) * quantity)
			numToSell = numToSell - quantity
		else
			if #emptySlotIds > 0 then
				local splitBag, splitSlot = SlotId.Split(tremove(emptySlotIds, 1))
				Container.SplitItem(bag, slot, numToSell)
				Container.PickupItem(splitBag, splitSlot)
				-- Wait for the stack to be split
				Threading.WaitForFunction(private.BagSlotHasItem, splitBag, splitSlot)
				Container.UseItem(splitBag, splitSlot)
				totalValue = totalValue + ((ItemInfo.GetVendorSell(itemString) or 0) * quantity)
			elseif not private.printedBagsFullMsg then
				ChatMessage.PrintUser(L["Could not sell items due to not having free bag space available to split a stack of items."])
				private.printedBagsFullMsg = true
			end
			-- We're done
			numToSell = 0
		end
		if numToSell == 0 then
			break
		end
		Threading.Yield(true)
	end

	TempTable.Release(slotIds)
	TempTable.Release(emptySlotIds)
	return totalValue
end

function private.GetEmptyBagSlotsThreaded(itemFamily)
	local emptySlotIds = Threading.AcquireSafeTempTable()
	local sortvalue = Threading.AcquireSafeTempTable()
	for bag = 0, Container.GetNumBags() do
		Container.GenerateSortedEmptyFamilySlots(bag, itemFamily, emptySlotIds, sortvalue)
		Threading.Yield()
	end
	Table.SortWithValueLookup(emptySlotIds, sortvalue)
	TempTable.Release(sortvalue)
	return emptySlotIds
end

function private.BagSlotHasItem(bag, slot)
	return Container.GetItemLink(bag, slot) and true or false
end
