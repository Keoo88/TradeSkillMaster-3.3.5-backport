-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Buyback = TSM.Vendoring:NewPackage("Buyback")
local Merchant = TSM.LibTSMWoW:Include("API.Merchant")
local Vendor = TSM.LibTSMService:Include("Vendor")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

function Buyback.CreateQuery()
	return Vendor.NewBuybackScannerQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
end

function Buyback.BuybackItem(index)
	Merchant.BuybackItem(index)
end
