-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local BuyoutSearch = TSM.Sniper:NewPackage("BuyoutSearch")
local SoundAlert = TSM.LibTSMWoW:Include("UI.SoundAlert")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local AuctionHouse = TSM.LibTSMWoW:Include("API.AuctionHouse")
local Group = TSM.LibTSMTypes:Include("Group")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local TempTable = TSM.LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local USE_GET_ALL = true
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
	-- print("TSM:SniperDebug ScanThread started")
	local numQueries = auctionScan:GetNumQueries()
		if numQueries == 0 then
			-- Prefer per-item exact-name queries when we have a list of items to
			-- search for (faster than scanning the whole AH). Fall back to the
			-- legacy page-scan query when no item list exists.
			local itemList = TempTable.Acquire()
			local added = false
			if TSM and TSM.Sniper and TSM.Sniper.PopulateItemList then
				local ok, err = pcall(function() return TSM.Sniper.PopulateItemList(itemList) end)
				-- PopulateItemList returns true/false; we just need items added to itemList
				if ok and #itemList > 0 then
					auctionScan:AddItemListQueriesThreaded(itemList)
					added = true
				end
			end
			TempTable.Release(itemList)

			if not added then
				local query = auctionScan:NewQuery()
					:AddCustomFilter(private.QueryFilter)
				if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
					if USE_GET_ALL and AuctionHouse.CanSendGetAllQuery() then
						query:SetUseGetAll(true)
					else
						query:SetPage("LAST")
					end
					-- 3.3.5: keep found lots in the list across rescans; the list is cleared
					-- only when the scan is stopped/restarted (the query is released then)
					query:SetAccumulate(true)
				end
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

	-- 3.3.5 accumulate mode: once a lot has been accepted into the Sniper list it
	-- becomes sticky and is kept across rescans, so DBMarket drift (each rescan
	-- rewrites market value, which lowers the belowPrice threshold) or a transient
	-- itemInfo gap can no longer silently drop an already-found lot. The list is
	-- cleared only when the scan is stopped/restarted (the query is released).
	if isClassic and isSubRow and subRow._sniperKept then
		return false
	end

	-- 3.3.5 fix: if SubRow has no itemString, we can't check operations - filter it out
	if isSubRow and not itemString then
		return true
	end

	-- Get max price: try item-specific first, then base item as fallback
	local maxPrice = itemString and SniperOperation.GetMaxPrice(itemString) or nil
	if not maxPrice and baseItemString and baseItemString ~= itemString then
		maxPrice = SniperOperation.GetMaxPrice(baseItemString)
	end

	local herbName = itemString and ItemInfo.GetName(itemString) or baseItemString and ItemInfo.GetName(baseItemString)
	if herbName and strlower(herbName) == "личецвет" then
		-- local _, herbItemBuyout, herbMinItemBuyout = subRow:GetBuyouts()
		-- print(string.format(
		-- 	"TSM:SniperDebug item=%s itemString=%s base=%s buyout=%s maxPrice=%s",
		-- 	tostring(herbName), tostring(itemString), tostring(baseItemString), tostring(herbItemBuyout or herbMinItemBuyout), tostring(maxPrice)
		-- ))
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
		local filtered = itemBuyout > maxPrice
		if isClassic and isSubRow and not filtered then
			-- Accepted snipe: mark sticky so it persists across rescans (see note above)
			subRow._sniperKept = true
			-- Freeze the threshold used for the displayed % so it doesn't drift upward
			-- as later rescan passes rewrite DBMarket and lower the live threshold.
			subRow._sniperMaxPrice = maxPrice
		end
		return filtered
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
	-- 3.3.5: for a lot already accepted into the Sniper list, return the snipe
	-- threshold captured at find time so the displayed % stays stable instead of
	-- drifting upward as each rescan pass rewrites DBMarket (which lowers the live
	-- threshold). Falls back to the live value for not-yet-accepted/parent rows.
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