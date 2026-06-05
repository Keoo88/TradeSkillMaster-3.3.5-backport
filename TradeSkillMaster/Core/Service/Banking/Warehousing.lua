-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Warehousing = TSM.Banking:NewPackage("Warehousing")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local WarehousingOperation = TSM.LibTSMSystem:Include("WarehousingOperation")



-- ============================================================================
-- Module Functions
-- ============================================================================

function Warehousing.MoveGroupsToBank(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromBags(items, groups, WarehousingOperation.GetNumToMoveToBank)
	TSM.Banking.MoveToBank(items, callback)
	TempTable.Release(items)
end

function Warehousing.MoveGroupsToBags(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromOpenBank(items, groups, WarehousingOperation.GetNumToMoveToBags)
	TSM.Banking.MoveToBag(items, callback)
	TempTable.Release(items)
end

function Warehousing.RestockBags(callback, groups)
	local items = TempTable.Acquire()
	TSM.Banking.Util.PopulateGroupItemsFromOpenBank(items, groups, WarehousingOperation.GetNumToMoveRestock)
	TSM.Banking.MoveToBag(items, callback)
	TempTable.Release(items)
end
