-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Sniper = TSM:NewPackage("Sniper")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local Threading = TSM.LibTSMTypes:Include("Threading")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local AuctionSearchContext = TSM.LibTSMService:IncludeClassType("AuctionSearchContext")
local LibTSMClass = LibStub("LibTSMClass")
local SniperSearchContext = LibTSMClass.DefineClass("SniperSearchContext", AuctionSearchContext)
TSM.Sniper.SniperSearchContext = SniperSearchContext



-- ============================================================================
-- Module Methods
-- ============================================================================

function Sniper.PopulateItemList(itemList)
	local baseHasOperation = false
	for _ in GroupOperation.OperationIterator(Group.GetRootPath(), "Sniper") do
		baseHasOperation = true
	end
	if baseHasOperation and (ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) then
		return false
	end

	-- add all the items from groups with Sniper operations
	for _, groupPath in GroupOperation.GroupIterator() do
		local hasOperations = false
		for _ in GroupOperation.OperationIterator(groupPath, "Sniper") do
			hasOperations = true
		end
		if hasOperations then
			for _, itemString in Group.ItemIterator(groupPath) do
				if SniperOperation.IsValid(itemString) then
					tinsert(itemList, itemString)
				end
			end
		end
	end
	return true
end



-- ============================================================================
-- SniperSearchContext - Public Class Methods
-- ============================================================================

function SniperSearchContext:__init(threadId, marketValueFunc, scanType)
	assert(threadId and marketValueFunc and (scanType == "BUYOUT" or scanType == "BID"))
	self._threadId = threadId
	self._marketValueFunc = marketValueFunc
	self._scanType = scanType
end

function SniperSearchContext:StartThread(callback, auctionScan)
	Threading.SetCallback(self._threadId, callback)
	Threading.Start(self._threadId, auctionScan)
end

function SniperSearchContext:KillThread()
	Threading.Kill(self._threadId)
end

function SniperSearchContext:GetMarketValueFunc()
	return self._marketValueFunc
end

function SniperSearchContext:GetGatheringResultsFunc()
	return nil
end

function SniperSearchContext:IsBuyoutScan()
	return self._scanType == "BUYOUT"
end

function SniperSearchContext:IsBidScan()
	return self._scanType == "BID"
end
