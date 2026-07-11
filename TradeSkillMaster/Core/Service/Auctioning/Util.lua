-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Util = TSM.Auctioning:NewPackage("Util") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Util.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_SELLERS) then
		private.settings:AddKey("factionrealm", "auctioningOptions", "whitelist")
	end
end

function Util.GetLowestAuction(subRows, itemString, operationSettings, resultTbl)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		local foundLowest = false
		for _, subRow in ipairs(subRows) do
			local _, itemBuyout = subRow:GetBuyouts()
			local quantity = subRow:GetQuantities()
			local timeLeft = subRow:GetListingInfo()
			if not foundLowest and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
				local ownerStr, numOwnerAuctions = subRow:GetOwnerInfo()
				local _, auctionId = subRow:GetListingInfo()
				local _, itemMinBid = subRow:GetBidInfo()
				local firstSeller = strsplit(",", ownerStr) or (numOwnerAuctions > 0 and UnitName("player")) or "?"
				resultTbl.buyout = itemBuyout
				resultTbl.bid = itemMinBid
				resultTbl.seller = firstSeller
				resultTbl.auctionId = auctionId
				resultTbl.isWhitelist = false
				resultTbl.isBlacklist = false
				resultTbl.isPlayer = numOwnerAuctions > 0
				foundLowest = true
			end
		end
		return foundLowest
	else
		local hasInvalidSeller = nil
		local ignoreWhitelist = nil
		local lowestItemBuyout = nil
		local lowestAuction = nil
		for _, subRow in ipairs(subRows) do
			local _, itemBuyout = subRow:GetBuyouts()
			local quantity = subRow:GetQuantities()
			local timeLeft = subRow:GetListingInfo()
			-- 3.3.5 fix: bid-only лоты (itemBuyout == 0) пропускаем вместо assert —
			-- GetFilteredSubRows их уже отбрасывает, но защищаемся и здесь на случай
			-- вызова с нефильтрованными subRows
			if itemBuyout and itemBuyout > 0 and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
				lowestItemBuyout = lowestItemBuyout or itemBuyout
				if itemBuyout == lowestItemBuyout then
					local ownerStr = subRow:GetOwnerInfo()
					local _, auctionId = subRow:GetListingInfo()
					local _, itemMinBid = subRow:GetBidInfo()
					local temp = TempTable.Acquire()
					temp.buyout = itemBuyout
					temp.bid = itemMinBid
					temp.seller = ownerStr
					temp.auctionId = auctionId
					temp.isWhitelist = private.settings.whitelist[strlower(ownerStr)] and true or false
					temp.isBlacklist = AuctioningOperation.IsBlacklisted(operationSettings, ownerStr)
					temp.isPlayer = PlayerInfo.IsPlayer(ownerStr, true, true, true)
					if not temp.isWhitelist and not temp.isPlayer then
						-- there is a non-whitelisted competitor, so we don't care if a whitelisted competitor also posts at this price
						ignoreWhitelist = true
					end
					if not subRow:HasOwners() and next(private.settings.whitelist) then
						hasInvalidSeller = true
					end
					if not lowestAuction then
						lowestAuction = temp
					elseif private.LowestAuctionCompare(temp, lowestAuction) then
						TempTable.Release(lowestAuction)
						lowestAuction = temp
					else
						TempTable.Release(temp)
					end
				end
			end
		end
		if not lowestAuction then
			return false
		end
		for k, v in pairs(lowestAuction) do
			resultTbl[k] = v
		end
		TempTable.Release(lowestAuction)
		if resultTbl.isWhitelist and ignoreWhitelist then
			resultTbl.isWhitelist = false
		end
		resultTbl.hasInvalidSeller = hasInvalidSeller
		return true
	end
end

function Util.GetCancelScanResult(subRows, itemString, operationSettings, lowestAuction, resultTbl)
	resultTbl.isPlayerOnlySeller = true
	for _, subRow in ipairs(subRows) do
		local _, itemBuyout = subRow:GetBuyouts()
		local quantity = subRow:GetQuantities()
		local timeLeft, auctionId = subRow:GetListingInfo()
		if not resultTbl.playerLowestItemBuyout and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and private.GetPlayerAuctionCount(subRow) > 0 then
			resultTbl.playerLowestItemBuyout = itemBuyout
			resultTbl.playerLowestAuctionId = auctionId
		end
		-- 3.3.5 fix: при равной цене second-lowest — это ЛЮБОЙ другой лот
		-- (auctionId ~= lowest), а не только с меньшим id. LowestAuctionCompare
		-- ставит blacklist/whitelist выше id, поэтому lowest может оказаться не
		-- с максимальным id — тогда сравнение "<" пропускало реальную конкуренцию
		-- по той же цене и cancel-скан делал лишние/пропущенные отмены.
		local isLower = itemBuyout > lowestAuction.buyout or (itemBuyout == lowestAuction.buyout and auctionId ~= lowestAuction.auctionId)
		if not resultTbl.secondLowestBuyout and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and isLower then
			resultTbl.secondLowestBuyout = itemBuyout
		end
		if resultTbl.isPlayerOnlySeller and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and private.GetPlayerAuctionCount(subRow) < (ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and quantity or 1) then
			resultTbl.isPlayerOnlySeller = false
		end
	end
	if (not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic()) and resultTbl.playerLowestItemBuyout then
		for _, subRow in ipairs(subRows) do
			local _, itemBuyout = subRow:GetBuyouts()
			local quantity = subRow:GetQuantities()
			local timeLeft, auctionId = subRow:GetListingInfo()
			if not resultTbl.nonPlayerLowestAuctionId and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) and private.GetPlayerAuctionCount(subRow) == 0 and itemBuyout == resultTbl.playerLowestItemBuyout then
				resultTbl.nonPlayerLowestAuctionId = auctionId
			end
		end
	end
end

function Util.GetPlayerAuctionCount(subRows, itemString, operationSettings, findBid, findBuyout, findStackSize)
	local playerQuantity = 0
	for _, subRow in ipairs(subRows) do
		local _, itemBuyout = subRow:GetBuyouts()
		local quantity = subRow:GetQuantities()
		local timeLeft = subRow:GetListingInfo()
		if not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
			local _, itemMinBid = subRow:GetBidInfo()
			if itemMinBid == findBid and itemBuyout == findBuyout and (not ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) or quantity == findStackSize) then
				local count = private.GetPlayerAuctionCount(subRow)
				if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and count == 0 and playerQuantity > 0 then
					-- There's another player's auction after ours, so stop counting
					break
				end
				playerQuantity = playerQuantity + count
			end
		end
	end
	return playerQuantity
end

function Util.GetQueueStatus(query)
	local numProcessed, numConfirmed, numFailed, totalNum = 0, 0, 0, 0
	query:OrderBy("auctionId", true)
	for _, row in query:Iterator() do
		local rowNumStacks, rowNumProcessed, rowNumConfirmed, rowNumFailed = row:GetFields("numStacks", "numProcessed", "numConfirmed", "numFailed")
		totalNum = totalNum + rowNumStacks
		numProcessed = numProcessed + rowNumProcessed
		numConfirmed = numConfirmed + rowNumConfirmed
		numFailed = numFailed + rowNumFailed
	end
	return numProcessed, numConfirmed, numFailed, totalNum
end

function Util.GetFilteredSubRows(query, itemString, operationSettings, result)
	for _, subRow in query:ItemSubRowIterator(itemString) do
		local _, itemBuyout = subRow:GetBuyouts()
		local quantity = subRow:GetQuantities()
		local timeLeft = subRow:GetListingInfo()
		-- 3.3.5 fix: отбрасываем bid-only лоты (itemBuyout == 0) — на 3.3.5 они
		-- повсеместны. Без этого нулевой буаут сортировался первым, ронял
		-- assert в GetLowestAuction и отравлял решение ложным "below min price".
		if itemBuyout and itemBuyout > 0 and not AuctioningOperation.IsAuctionFiltered(itemString, operationSettings, itemBuyout, quantity, timeLeft) then
			tinsert(result, subRow)
		end
	end
	sort(result, private.SubRowSortHelper)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SubRowSortHelper(a, b)
	local _, aItemBuyout = a:GetBuyouts()
	local _, bItemBuyout = b:GetBuyouts()
	if aItemBuyout ~= bItemBuyout then
		return aItemBuyout < bItemBuyout
	end
	local _, aAuctionId = a:GetListingInfo()
	local _, bAuctionId = b:GetListingInfo()
	return aAuctionId > bAuctionId
end

function private.LowestAuctionCompare(a, b)
	if a.isBlacklist ~= b.isBlacklist then
		return a.isBlacklist
	end
	if a.isWhitelist ~= b.isWhitelist then
		return a.isWhitelist
	end
	if a.auctionId ~= b.auctionId then
		return a.auctionId > b.auctionId
	end
	if a.isPlayer ~= b.isPlayer then
		return b.isPlayer
	end
	return tostring(a) < tostring(b)
end

function private.GetPlayerAuctionCount(subRow)
	local ownerStr, numOwnerItems = subRow:GetOwnerInfo()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		return numOwnerItems
	else
		return PlayerInfo.IsPlayer(ownerStr, true, true, true) and select(2, subRow:GetQuantities()) or 0
	end
end
