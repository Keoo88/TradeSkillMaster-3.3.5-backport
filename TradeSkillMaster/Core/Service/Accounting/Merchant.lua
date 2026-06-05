-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Merchant = TSM.Accounting:NewPackage("Merchant")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Container = TSM.LibTSMWoW:Include("API.Container")
local MerchantAPI = TSM.LibTSMWoW:Include("API.Merchant")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local private = {
	repairMoney = 0,
	couldRepair = nil,
	repairCost = 0,
	pendingSales = {
		itemString = {},
		quantity = {},
		copper = {},
		insertTime = {},
	},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Merchant.OnInitialize()
	DefaultUI.RegisterMerchantVisibleCallback(private.MechantVisibilityHandler)
	BagTracking.RegisterCallback(private.OnMerchantUpdate)
	Event.Register("UPDATE_INVENTORY_DURABILITY", private.AddRepairCosts)
	Container.SecureHookUseItem(private.CheckMerchantSale)
	MerchantAPI.SecureHookBuyItem(private.OnMerchantBuy)
	MerchantAPI.SecureHookBuybackItem(private.OnMerchantBuyback)
end



-- ============================================================================
-- Repair Cost Tracking
-- ============================================================================

function private.MechantVisibilityHandler(visible)
	if visible then
		private.repairMoney = GetMoney()
		private.couldRepair = MerchantAPI.CanRepair()
		-- if merchant can repair set up variables so we can track repairs
		if private.couldRepair then
			private.repairCost = MerchantAPI.GetRepairAllCost()
		end
	else
		private.couldRepair = nil
		private.repairCost = 0
	end
end

function private.OnMerchantUpdate()
	-- Could have bought something before or after repair
	private.repairMoney = GetMoney()
	-- log any pending sales
	for i, insertTime in ipairs(private.pendingSales.insertTime) do
		if GetTime() - insertTime < 5 then
			TSM.Accounting.Transactions.InsertVendorSale(private.pendingSales.itemString[i], private.pendingSales.quantity[i], private.pendingSales.copper[i])
		end
	end
	wipe(private.pendingSales.itemString)
	wipe(private.pendingSales.quantity)
	wipe(private.pendingSales.copper)
	wipe(private.pendingSales.insertTime)
end

function private.AddRepairCosts()
	if private.couldRepair and private.repairCost > 0 then
		local cash = GetMoney()
		if private.repairMoney > cash then
			-- this is probably a repair bill
			local cost = private.repairMoney - cash
			TSM.Accounting.Money.InsertRepairBillExpense(cost)
			-- reset money as this might have been a single item repair
			private.repairMoney = cash
			-- reset the repair cost for the next repair
			private.repairCost = MerchantAPI.GetRepairAllCost()
		end
	end
end


-- ============================================================================
-- Merchant Purchases / Sales Tracking
-- ============================================================================

function private.CheckMerchantSale(bag, slot, onSelf)
	-- check if we are trying to sell something to a vendor
	if (not MerchantFrame:IsShown() and not TSM.UI.VendoringUI.IsVisible()) or onSelf then
		return
	end

	local itemString = ItemString.Get(Container.GetItemLink(bag, slot))
	local stackSize = Container.GetStackCount(bag, slot)
	local copper = ItemInfo.GetVendorSell(itemString)
	if not itemString or not stackSize or not copper then
		return
	end
	tinsert(private.pendingSales.itemString, itemString)
	tinsert(private.pendingSales.quantity, stackSize)
	tinsert(private.pendingSales.copper, copper)
	tinsert(private.pendingSales.insertTime, GetTime())
end

function private.OnMerchantBuy(index, quantity)
	local price, batchQuantity = MerchantAPI.GetItemInfo(index)
	local itemString = ItemString.Get(MerchantAPI.GetItemLink(index))
	if not itemString or not price or price <= 0 then
		return
	end
	quantity = quantity or batchQuantity
	local copper = Math.Round(price / batchQuantity)
	TSM.Accounting.Transactions.InsertVendorBuy(itemString, quantity, copper)
end

function private.OnMerchantBuyback(index)
	local price, quantity = MerchantAPI.GetBuybackItemInfo(index)
	local itemString = ItemString.Get(MerchantAPI.GetBuybackItemLink(index))
	if not itemString or not price or price <= 0 then
		return
	end
	local copper = Math.Round(price / quantity)
	TSM.Accounting.Transactions.InsertVendorBuy(itemString, quantity, copper)
end
