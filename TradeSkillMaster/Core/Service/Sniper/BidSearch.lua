-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local BidSearch = TSM.Sniper:NewPackage("BidSearch")
local SoundAlert = TSM.LibTSMWoW:Include("UI.SoundAlert")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Threading = TSM.LibTSMTypes:Include("Threading")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local private = {
	settings = nil,
	scanThreadId = nil,
	searchContext = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function BidSearch.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "sniperOptions", "sniperSound")
	private.scanThreadId = Threading.New("SNIPER_BID_SEARCH", private.ScanThread)
	private.searchContext = TSM.Sniper.SniperSearchContext(private.scanThreadId, private.MarketValueFunction, "BID")
end

function BidSearch.GetSearchContext()
	assert(ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic())
	return private.searchContext
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

function private.ScanThread(auctionScan)
	assert(ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic())
	local numQueries = auctionScan:GetNumQueries()
	if numQueries == 0 then
		local query = auctionScan:NewQuery()
			:AddCustomFilter(private.QueryFilter)
			:SetPage("FIRST")
		-- 3.3.5: как и в BuyoutSearch — найденные лоты остаются в списке между
		-- пересканами (без этого лот пропадал, когда сдвигался с первой страницы
		-- по мере истечения других аукционов). Список чистится при рестарте скана.
		query:SetAccumulate(true)
	else
		assert(numQueries == 1)
	end
	auctionScan:SetScript("OnQueryDone", private.OnQueryDone)
	-- Just constantly rerun the scan until the thread is killed (don't care if it fails)
	while true do
		auctionScan:ScanQueriesThreaded()
		auctionScan:SleepThreaded(5)
	end
end

function private.QueryFilter(_, subRow)
	-- 3.3.5 sticky (см. BuyoutSearch): уже принятый в список лот не отфильтровывается
	-- повторно — ни дрейфом порога, ни временным отсутствием данных
	if subRow:IsSubRow() and subRow._sniperKept then
		return false
	end
	local itemString = subRow:GetItemString()
	if not itemString or not subRow:IsSubRow() or not subRow:HasRawData() then
		-- can only filter complete subRows
		return false
	end
	local maxPrice = SniperOperation.GetMaxPrice(itemString) or nil
	if not maxPrice then
		-- no Shopping operation applies to this item, so filter it out
		return true
	end

	local _, itemDisplayedBid = subRow:GetDisplayedBids()
	local filtered = itemDisplayedBid > maxPrice
	if not filtered then
		-- Принятый снайп: фиксируем порог, чтобы отображаемый % не дрейфовал
		subRow._sniperKept = true
		subRow._sniperMaxPrice = maxPrice
	end
	return filtered
end

function private.MarketValueFunction(row)
	-- 3.3.5: для принятого лота возвращаем порог на момент находки (см. BuyoutSearch)
	if row._sniperMaxPrice then
		return row._sniperMaxPrice
	end
	local itemString = row:GetItemString()
	return itemString and SniperOperation.GetMaxPrice(itemString) or nil
end

function private.OnQueryDone(_, _, numNewResults)
	if numNewResults > 0 then
		SoundAlert.Play(private.settings.sniperSound)
	end
end
