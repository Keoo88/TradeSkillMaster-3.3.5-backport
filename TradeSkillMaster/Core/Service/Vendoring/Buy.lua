-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Buy = TSM.Vendoring:NewPackage("Buy")
local Vendor = TSM.LibTSMService:Include("Vendor")



-- ============================================================================
-- Module Functions
-- ============================================================================

function Buy.BuyItem(itemString, quantity)
	local index = Vendor.GetFirstIndex(itemString)
	if not index then
		return
	end
	Vendor.BuyIndex(index, quantity)
end
