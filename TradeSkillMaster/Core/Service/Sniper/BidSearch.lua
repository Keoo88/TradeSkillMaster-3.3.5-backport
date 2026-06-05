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
		auctionScan:NewQuery()
			:AddCustomFilter(private.QueryFilter)
			:SetPage("FIRST")
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
	return itemDisplayedBid > maxPrice
end

function private.MarketValueFunction(row)
	local itemString = row:GetItemString()
	return itemString and SniperOperation.GetMaxPrice(itemString) or nil
end

function private.OnQueryDone(_, _, numNewResults)
	if numNewResults > 0 then
		SoundAlert.Play(private.settings.sniperSound)
	end
end
