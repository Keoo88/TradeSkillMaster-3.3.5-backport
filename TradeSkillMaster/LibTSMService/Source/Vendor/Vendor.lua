-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Vendor = LibTSMService:Init("Vendor")
local Buy = LibTSMService:Include("Vendor.Buy")
local BuyScanner = LibTSMService:Include("Vendor.BuyScanner")
local BuybackScanner = LibTSMService:Include("Vendor.BuybackScanner")
local Merchant = LibTSMService:From("LibTSMWoW"):Include("API.Merchant")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new query for the scanner DB.
---@return DatabaseQuery
function Vendor.NewScannerQuery()
	return BuyScanner.NewQuery()
end

---Gets the first index of the specified item (or nil if it doesn't exist).
---@param itemString string The item string or base item string to search for
---@return number?
function Vendor.GetFirstIndex(itemString)
	return BuyScanner.GetFirstIndex(itemString)
end

---Iterates over the additional cost items and quantities.
---@param index number The index of the vendor item to iterate over
---@return fun(): number, string, number @Iterator with fields: `index`, `itemString`, `quantity`
function Vendor.AdditionalCostIterator(index)
	return BuyScanner.AdditionalCostIterator(index)
end

---Gets the max number of an item that can be afforded.
---@param index number The index of the item
---@return number
function Vendor.GetNumCanAfford(index)
	return BuyScanner.GetNumCanAfford(index)
end

---Gets the total cost for a given quantity of an item.
---@param index number The index of the item
---@param quantity number The index of the item
---@return number price
---@return number numStacks
function Vendor.GetTotalCost(index, quantity)
	return BuyScanner.GetTotalCost(index, quantity)
end

---Creates a new query for the buyback scanner DB.
---@return DatabaseQuery
function Vendor.NewBuybackScannerQuery()
	return BuybackScanner.NewQuery()
end

---Returns whether or not the player needs to repair.
---@return boolean
function Vendor.NeedsRepair()
	local _, needsRepair = Merchant.GetRepairAllCost()
	return needsRepair
end

---Returns whether or not the player can repair from the guild bank.
---@return boolean
function Vendor.CanGuildRepair()
	return Vendor.NeedsRepair() and Merchant.CanGuildBankRepair()
end

---Performs a repair.
function Vendor.DoRepair()
	Merchant.RepairAllItems()
end

---Performs a repair from the guild bank.
function Vendor.DoGuildRepair()
	Merchant.RepairAllItems(true)
end

---Buys an item from the vendor.
---@param index number The index of the item to buy
---@param quantity number The quantity to buy
function Vendor.BuyIndex(index, quantity)
	quantity = min(quantity, BuyScanner.GetNumCanAfford(index))
	if quantity == 0 then
		return
	end
	Buy.BuyIndex(index, quantity)
end
