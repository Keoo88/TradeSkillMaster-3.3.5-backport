-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

-- Classic (3.3.5) scan helper - simplified approach based on AUX/old TSM
-- Bypasses Row/SubRow system and ItemInfo caching for direct auction processing

local LibTSMService = select(2, ...).LibTSMService
local ClassicScanHelper = LibTSMService:Init("AuctionScan.ClassicScanHelper")
local AuctionHouse = LibTSMService:From("LibTSMWoW"):Include("API.AuctionHouse")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")

local private = {
	results = {}, -- Simple table: baseItemString -> array of auction data
}

-- Process all auctions from current page directly without Row/SubRow overhead
function ClassicScanHelper.ProcessPage(query, browseId)
	local numAuctions = AuctionHouse.GetNumAuctions()
	local processed = 0

	for i = 1, numAuctions do
		local rawName, itemLink, stackSize, timeLeft, buyout, seller, minIncrement, minBid, bid, isHighBidder = AuctionHouse.GetBrowseResult(i)
		local baseItemString = ItemString.GetBase(itemLink)

		-- Basic validation - don't wait for seller in 3.3.5
		if rawName and rawName ~= "" and baseItemString and buyout and stackSize and timeLeft then
			-- Create simple auction data structure
			local auctionData = {
				index = i,
				itemLink = itemLink,
				baseItemString = baseItemString,
				name = rawName,
				stackSize = stackSize or 1,
				timeLeft = timeLeft or 0,
				buyout = buyout or 0,
				seller = seller or "?",
				minBid = minBid or 0,
				currentBid = bid or 0,
				minIncrement = minIncrement or 0,
				isHighBidder = isHighBidder and true or false,
			}

			-- Apply query filters directly
			if not ClassicScanHelper.IsFiltered(query, auctionData) then
				-- Store result
				private.results[baseItemString] = private.results[baseItemString] or {}
				table.insert(private.results[baseItemString], auctionData)
				processed = processed + 1
			end
		end
	end

	TSMDBG.Log("ClassicScan", "Processed %d/%d auctions", processed, numAuctions)
	return true
end

-- Simple filter check without ItemInfo dependency
function ClassicScanHelper.IsFiltered(query, auctionData)
	-- Check search string
	if query._str ~= "" and auctionData.name then
		local nameLower = string.lower(auctionData.name)
		local searchLower = string.lower(query._str)
		if not string.find(nameLower, searchLower, 1, true) then
			return true
		end
		if query._exact and nameLower ~= searchLower then
			return true
		end
	end

	-- Check price range
	if auctionData.buyout > 0 then
		local itemBuyout = math.floor(auctionData.buyout / auctionData.stackSize)
		if itemBuyout < query._minPrice or itemBuyout > query._maxPrice then
			return true
		end
	end

	return false
end

-- Get results for UI display
function ClassicScanHelper.GetResults()
	return private.results
end

-- Clear results
function ClassicScanHelper.ClearResults()
	wipe(private.results)
end
