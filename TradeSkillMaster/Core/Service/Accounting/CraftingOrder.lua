-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local CraftingOrder = TSM.Accounting:NewPackage("CraftingOrder")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function CraftingOrder.OnInitialize()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_ORDERS) then
		Event.Register("CRAFTINGORDERS_DISPLAY_CRAFTER_FULFILLED_MSG", private.CraftingOrderFulfilled)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CraftingOrderFulfilled(_, _, _, playerNameString, tipAmount)
	TSM.Accounting.Money.InsertCraftingOrderIncome(tipAmount, playerNameString, time())
end
