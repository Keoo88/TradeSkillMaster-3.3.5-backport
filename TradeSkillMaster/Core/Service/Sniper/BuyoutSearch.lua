-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local BuyoutSearch = TSM.Sniper:NewPackage("BuyoutSearch")
local SoundAlert = TSM.LibTSMWoW:Include("UI.SoundAlert")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Group = TSM.LibTSMTypes:Include("Group")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local private = {
	settings = nil,
	scanThreadId = nil,
	searchContext = nil,
}
local RESCAN_DELAY = (ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and 5 or 30



-- ============================================================================
-- Module Functions
-- ============================================================================

function BuyoutSearch.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "sniperOptions", "sniperSound")
	private.scanThreadId = Threading.New("SNIPER_BUYOUT_SEARCH", private.ScanThread)
	private.searchContext = TSM.Sniper.SniperSearchContext(private.scanThreadId, private.MarketValueFunction, "BUYOUT")
end

function BuyoutSearch.GetSearchContext()
	return private.searchContext
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

---@param auctionScan AuctionScanManager
function private.ScanThread(auctionScan)
	local numQueries = auctionScan:GetNumQueries()
	if numQueries == 0 then
		local query = auctionScan:NewQuery()
			:AddCustomFilter(private.QueryFilter)
		if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
			query:SetPage("LAST")
		end
	end
	auctionScan:SetScript("OnQueryDone", private.OnQueryDone)
	-- Just constantly rerun the scan until the thread is killed (don't care if it fails)
	while true do
		auctionScan:ScanQueriesThreaded()
		auctionScan:SleepThreaded(RESCAN_DELAY)
	end
end

function private.QueryFilter(_, subRow, isSubRow, itemKey)
	local baseItemString = subRow:GetBaseItemString()
	local itemString = subRow:GetItemString()
	local isClassic = ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()

	-- 3.3.5 fix: if SubRow has no itemString, we can't check operations - filter it out
	if isSubRow and not itemString then
		return true
	end

	-- Get max price: try item-specific first, then base item as fallback
	local maxPrice = itemString and SniperOperation.GetMaxPrice(itemString) or nil
	if not maxPrice and baseItemString and baseItemString ~= itemString then
		maxPrice = SniperOperation.GetMaxPrice(baseItemString)
	end
	if not maxPrice then
		-- No Sniper operation applies to this item, so filter it out
		return true
	end

	local auctionBuyout, itemBuyout, minItemBuyout = subRow:GetBuyouts()
	itemBuyout = itemBuyout or minItemBuyout
	if not itemBuyout then
		-- Don't have buyout info yet, so don't filter
		return false
	elseif auctionBuyout == 0 then
		-- No buyout, so filter it out
		return true
	elseif itemString then
		-- Filter if the buyout is too high
		return itemBuyout > maxPrice
	end

	-- Retail path: check variations
	if not isClassic then
		local canHaveVariations = ItemInfo.CanHaveVariations(baseItemString)
		if canHaveVariations == nil then
			-- Item info not loaded yet, filter out suspicious lot
			return true
		end
		if not canHaveVariations then
			return itemBuyout > maxPrice
		end
		-- Check if any variant in a group could be worth scanning
		local hasPotentialItem = false
		for _, groupItemString in Group.ItemByBaseItemStringIterator(baseItemString) do
			hasPotentialItem = hasPotentialItem or itemBuyout < (SniperOperation.GetMaxPrice(groupItemString) or 0)
		end
		if hasPotentialItem then
			return false
		elseif not SniperOperation.HasOperation(baseItemString) then
			return true
		end
		return false
	end

	-- Classic: itemString=nil reached here only for parent rows, filter strictly
	return itemBuyout > maxPrice
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
