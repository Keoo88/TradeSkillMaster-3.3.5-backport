-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Auction = LibTSMService:Init("Auction")
local BlackMarket = LibTSMService:Include("Auction.BlackMarket")
local Expiring = LibTSMService:Include("Auction.Expiring")
local FullScan = LibTSMService:Include("Auction.FullScan")
local Scanner = LibTSMService:Include("Auction.Scanner")
local SaleHint = LibTSMService:Include("Auction.SaleHint")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Auction item quantities
---@param saleHintData table<string,number> Auction sale hints
---@param expiresData table<string,number> Auction expires
function Auction.Load(quantityData, saleHintData, expiresData)
	Scanner.Load(quantityData)
	SaleHint.Load(saleHintData)
	Expiring.Load(expiresData)
end

---Starts running the auction code.
function Auction.Start()
	Scanner.Start()
	SaleHint.Start()
	Expiring.Start()
	BlackMarket.Start()
end

---Registers a callback for when the auction index DB changes.
---@param callback fun() The callback function
function Auction.RegisterIndexCallback(callback)
	Scanner.RegisterIndexCallback(callback)
end

---Registers a callback for when the auction index DB changes which is throttled to not be too spammy.
---@param callback fun() The callback function
function Auction.RegisterThrottledIndexCallback(callback)
	Scanner.RegisterThrottledIndexCallback(callback)
end

---Registers a callback for when the auction quantity changes.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function Auction.RegisterQuantityCallback(callback)
	Scanner.RegisterQuantityCallback(callback)
end

---Registers a callback for when the expires data changes.
---@param callback fun() The callback function
function Auction.RegisterExpiresCallback(callback)
	Expiring.RegisterCallback(callback)
end

---Creates a new query against the index DB.
---@return DatabaseQuery
function Auction.NewIndexQuery()
	return Scanner.NewIndexQuery()
end

---Gets the quantity of a given item on the auction house.
---@param itemString string The item string
---@return number
function Auction.GetQuantity(itemString)
	return Scanner.GetQuantity(itemString)
end

---Iterates over each item and its auction quantity.
---@return fun(): number, string, number @Iterator with fields: `index`, `levelItemString`, `auctionQuantity`
function Auction.QuantityIterator()
	return Scanner.NewQuantityQuery()
		:Select("levelItemString", "auctionQuantity")
		:IteratorAndRelease()
end

---Gets the item string for a given auction sale based on tracked sale hints.
---@param name string The item name
---@param stackSize number The stack size
---@param buyout number The buyout price
---@return string?
function Auction.GetSaleHintItemString(name, stackSize, buyout)
	return SaleHint.GetItemString(name, stackSize, buyout)
end

---Gets the most recent black market scan data.
---@return string? scanData
---@return number? scanTime
function Auction.GetBlackMarketScanData()
	return BlackMarket.GetScanData()
end

---Gets summary info if the AH is visible.
---@return number? numPosted
---@return number? numSold
---@return number? postedGold
---@return number? soldGold
function Auction.GetSummaryInfo()
	return Scanner.GetSummaryInfo()
end

---Enables the full scan code.
function Auction.EnableFullScan()
	FullScan.Enable()
end

---Gets any available full scan data.
---@return string? data
---@return number? scanTime
function Auction.GetFullScanData()
	return FullScan.GetData()
end
