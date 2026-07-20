-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Util = LibTSMService:Init("AuctionScan.Util")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not sufficient item info is available for an item.
---@param itemString string The item string
---@return boolean hasInfo
---@return boolean fetchedInfo
function Util.HasItemInfo(itemString)
	local itemName = ItemInfo.GetName(itemString)
	local itemLevel = ItemInfo.GetItemLevel(itemString)
	local quality = ItemInfo.GetQuality(itemString)
	local minLevel = ItemInfo.GetMinLevel(itemString)
	local hasIsCommodity = (LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() or LibTSMService.IsWrathClassic()) or ItemInfo.IsCommodity(itemString) ~= nil
	local hasCanHaveVariations = ItemInfo.CanHaveVariations(itemString) ~= nil
	if itemName and itemLevel and quality and minLevel and hasIsCommodity and hasCanHaveVariations then
		return true, false
	else
		return false, ItemInfo.FetchInfo(itemString)
	end
end

-- Retail AuctionDB per-scan snapshot (TSM docs). One price point per auction lot.
local MIN_PERCENTILE = 0.15
local MAX_PERCENTILE = 0.30
local MAX_JUMP = 1.2

---Computes the robust per-scan market value snapshot (DBRecent input).
---@param prices number[]
---@return number?
function Util.CalcMarketValue(prices)
	if not prices then
		return nil
	end
	local n = #prices
	if n == 0 then
		return nil
	end
	if n == 1 then
		return prices[1]
	end
	table.sort(prices)

	local protectedThrough = math.max(2, n * MIN_PERCENTILE)
	local totalNum = 0
	local totalBuyout = 0
	for i = 1, n do
		if i ~= 1 and i > protectedThrough and (i > n * MAX_PERCENTILE or prices[i] >= MAX_JUMP * prices[i - 1]) then
			break
		end
		totalBuyout = totalBuyout + prices[i]
		totalNum = i
	end
	if totalNum == 0 then
		return nil
	end

	local mean = totalBuyout / totalNum
	if totalNum < 3 then
		return math.floor(mean + 0.5)
	end

	local variance = 0
	for i = 1, totalNum do
		local d = prices[i] - mean
		variance = variance + d * d
	end
	local stdDev = math.sqrt(variance / totalNum)
	local limitLo = mean - 1.5 * stdDev
	local limitHi = mean + 1.5 * stdDev

	local fSum, fCnt = 0, 0
	for i = 1, totalNum do
		if prices[i] >= limitLo and prices[i] <= limitHi then
			fSum = fSum + prices[i]
			fCnt = fCnt + 1
		end
	end
	if fCnt == 0 then
		return math.floor(mean + 0.5)
	end
	return math.floor(fSum / fCnt + 0.5)
end
