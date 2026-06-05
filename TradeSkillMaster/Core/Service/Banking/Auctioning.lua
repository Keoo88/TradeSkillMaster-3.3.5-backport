-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Auctioning = TSM.Banking:NewPackage("Auctioning") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local Auction = TSM.LibTSMService:Include("Auction")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local AltTracking = TSM.LibTSMApp:Include("Service.AltTracking")
local Mail = TSM.LibTSMService:Include("Mail")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local private = {
	settingsDB = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Auctioning.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
end

function Auctioning.MoveGroupsToBank(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromBags(items, groups, private.GroupsGetNumToMoveToBank)
	TSM.Banking.MoveToBank(items, callback)
	TempTable.Release(items)
end

function Auctioning.PostCapToBags(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromOpenBank(items, groups, private.GetNumToMoveToBags)
	TSM.Banking.MoveToBag(items, callback)
	TempTable.Release(items)
end

function Auctioning.ShortfallToBags(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromOpenBank(items, groups, private.GetNumToMoveToBags, true)
	TSM.Banking.MoveToBag(items, callback)
	TempTable.Release(items)
end

function Auctioning.MaxExpiresToBank(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromBags(items, groups, private.MaxExpiresGetNumToMoveToBank)
	TSM.Banking.MoveToBank(items, callback)
	TempTable.Release(items)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GroupsGetNumToMoveToBank(itemString, numHave)
	-- move everything
	return numHave
end

function private.GetNumToMoveToBags(itemString, numHave, includeAH)
	local totalNumToMove = 0
	local numAvailable = numHave
	local numInBags = BagTracking.CreateQueryBagsItem(itemString)
		:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
		:Equal("autoBaseItemString", itemString)
		:SumAndRelease("quantity")
	if includeAH then
		numInBags = numInBags + Auction.GetQuantity(itemString) + Mail.GetQuantity(itemString)
		-- include alt auctions on connected realms
		local isCommodity = ItemInfo.IsCommodity(itemString)
		for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not isCommodity) do
			for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
				numInBags = numInBags + AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
			end
		end
	end

	for _, _, operationSettings in GroupOperation.OperationIterator(Group.GetPathByItem(itemString), "Auctioning") do
		local maxExpires = AuctioningOperation.GetItemPrice(itemString, "maxExpires", operationSettings)
		local operationHasExpired = false
		if maxExpires and maxExpires > 0 then
			local numExpires = TSM.Accounting.Auctions.GetNumExpiresSinceSale(itemString)
			if numExpires and numExpires > maxExpires then
				operationHasExpired = true
			end
		end

		local postCap = AuctioningOperation.GetItemPrice(itemString, "postCap", operationSettings)
		local stackSize = private.GetOperationStackSize(operationSettings, itemString)
		if not operationHasExpired and postCap and stackSize then
			local numNeeded = stackSize * postCap
			if numInBags > numNeeded then
				-- we can satisfy this operation from the bags
				numInBags = numInBags - numNeeded
				numNeeded = 0
			elseif numInBags > 0 then
				-- we can partially satisfy this operation from the bags
				numNeeded = numNeeded - numInBags
				numInBags = 0
			end

			local numToMove = min(numAvailable, numNeeded)
			if numToMove > 0 then
				numAvailable = numAvailable - numToMove
				totalNumToMove = totalNumToMove + numToMove
			end
		end
	end

	return totalNumToMove
end

function private.MaxExpiresGetNumToMoveToBank(itemString, numHave)
	local numToKeepInBags = 0
	for _, _, operationSettings in GroupOperation.OperationIterator(Group.GetPathByItem(itemString), "Auctioning") do
		local maxExpires = AuctioningOperation.GetItemPrice(itemString, "maxExpires", operationSettings)
		local operationHasExpired = false
		if maxExpires and maxExpires > 0 then
			local numExpires = TSM.Accounting.Auctions.GetNumExpiresSinceSale(itemString)
			if numExpires and numExpires > maxExpires then
				operationHasExpired = true
			end
		end
		local postCap = AuctioningOperation.GetItemPrice(itemString, "postCap", operationSettings)
		local stackSize = private.GetOperationStackSize(operationSettings, itemString)
		if not operationHasExpired and postCap and stackSize then
			numToKeepInBags = numToKeepInBags + stackSize * postCap
		end
	end
	return max(numHave - numToKeepInBags, 0)
end

function private.GetOperationStackSize(operationSettings, itemString)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		return AuctioningOperation.GetItemPrice(itemString, "stackSize", operationSettings)
	else
		return 1
	end
end
