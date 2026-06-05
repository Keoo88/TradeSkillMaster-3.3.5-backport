-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local VendorSearch = TSM.Shopping:NewPackage("VendorSearch")
local L = TSM.Locale.GetTable()
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local AuctionSearchContext = TSM.LibTSMService:IncludeClassType("AuctionSearchContext")
local LibTSMClass = LibStub("LibTSMClass")
local VendorSearchContext = LibTSMClass.DefineClass("VendorSearchContext", AuctionSearchContext) ---@class VendorSearchContext: AuctionSearchContext
local private = {
	itemList = {},
	scanThreadId = nil,
	searchContext = nil ---@type VendorSearchContext,
}
-- Min absolute profit per stack (copper) to keep a lot visible.
-- WoW arithmetic rounds per-unit prices down (floor), so a stack of 5 at 24999c
-- vs vendor 5000c looks like "1c profit per unit × 5 = 5c stack" — useless.
-- Setting to 1 silver = 100c filters out these noise lots while keeping real flips.
local MIN_STACK_PROFIT_COPPER = 100



-- ============================================================================
-- Module Functions
-- ============================================================================

function VendorSearch.OnInitialize()
	-- initialize thread
	private.scanThreadId = Threading.New("VENDOR_SEARCH", private.ScanThread)
	private.searchContext = VendorSearchContext(private.scanThreadId, private.MarketValueFunction)
end

function VendorSearch.GetSearchContext()
	return private.searchContext:SetScanContext(L["Vendor Search"], nil, nil, L["Vendor Sell Price"])
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

function private.ScanThread(auctionScan)
	-- 3.3.5 fix: check both App data and local scan data
	-- AppData may be 0 on private servers without TSM Desktop App
	local hasAppData = TSM.AuctionDB.GetAppDataUpdateTimes() >= time() - 60 * 60 * 12
	local hasLocalData = TSM.AuctionDB.HasLocalScanData and TSM.AuctionDB.HasLocalScanData()
	if not hasAppData and not hasLocalData then
		ChatMessage.PrintUser(L["No recent AuctionDB scan data found."])
		return false
	end

	-- create the list of items: AuctionDB min buyout must beat vendor by the same
	-- noise threshold used in QueryFilter (otherwise we'd waste queries on items
	-- that always end up filtered out at sub-row time).
	wipe(private.itemList)
	for itemString, minBuyout in TSM.AuctionDB.LastScanIteratorThreaded() do
		if type(minBuyout) == "number" and minBuyout > 0 then
			local vendorSell = ItemInfo.GetVendorSell(itemString)
			if type(vendorSell) == "number" and vendorSell > 0
				and minBuyout < vendorSell
				and (vendorSell - minBuyout) >= MIN_STACK_PROFIT_COPPER then
				tinsert(private.itemList, itemString)
			end
		end
		Threading.Yield()
	end

	-- run the scan
	auctionScan:AddItemListQueriesThreaded(private.itemList)
	for _, query in auctionScan:QueryIterator() do
		query:AddCustomFilter(private.QueryFilter)
	end
	if not auctionScan:ScanQueriesThreaded() then
		ChatMessage.PrintUser(L["TSM failed to scan some auctions. Please rerun the scan."])
	end
	return true
end

function private.QueryFilter(_, row)
	local itemString = row:GetItemString()
	if not itemString then
		return false
	end
	local stackBuyout, itemBuyout = row:GetBuyouts()
	if not itemBuyout or not stackBuyout then
		return false
	end
	local vendorSell = ItemInfo.GetVendorSell(itemString)
	if not vendorSell or itemBuyout == 0 or itemBuyout >= vendorSell then
		return true
	end
	-- Absolute profit on the whole stack must beat the noise threshold.
	local quantity = stackBuyout > 0 and (stackBuyout / itemBuyout) or 1
	local stackProfit = (vendorSell - itemBuyout) * quantity
	if stackProfit < MIN_STACK_PROFIT_COPPER then
		return true
	end
	return false
end

function private.MarketValueFunction(row)
	return ItemInfo.GetVendorSell(row:GetItemString() or row:GetBaseItemString())
end



-- ============================================================================
-- VendorSearchContext Class
-- ============================================================================

function VendorSearchContext:GetMaxCanBuy()
	-- Buy everything that's below the vendor cost
	return math.huge
end
