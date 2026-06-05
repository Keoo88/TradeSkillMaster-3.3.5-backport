-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local BuybackScanner = LibTSMService:Init("Vendor.BuybackScanner")
local Database = LibTSMService:From("LibTSMUtil"):Include("Database")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Merchant = LibTSMService:From("LibTSMWoW"):Include("API.Merchant")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	db = nil,
	updateTimer = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

BuybackScanner:OnModuleLoad(function()
	private.db = Database.NewSchema("VENDOR_BUYBACK")
		:AddUniqueNumberField("index")
		:AddStringField("itemString")
		:AddNumberField("price")
		:AddNumberField("quantity")
		:Commit()
	private.updateTimer = DelayTimer.New("VENDOR_BUYBACK_UPDATE", private.UpdateBuybackDB)
	DefaultUI.RegisterMerchantVisibleCallback(private.MechantVisibilityHandler)
	Event.Register("MERCHANT_UPDATE", private.MerchantUpdateEventHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new query for the scanner DB.
---@return DatabaseQuery
function BuybackScanner.NewQuery()
	return private.db:NewQuery()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MechantVisibilityHandler(visible)
	if visible then
		private.updateTimer:RunForFrames(1)
	else
		private.updateTimer:Cancel()
		private.db:Truncate()
	end
end

function private.MerchantUpdateEventHandler()
	private.updateTimer:RunForFrames(1)
end

function private.UpdateBuybackDB()
	private.db:TruncateAndBulkInsertStart()
	for i = 1, Merchant.GetNumBuybackItems() do
		local itemString = ItemString.Get(Merchant.GetBuybackItemLink(i))
		if itemString then
			local price, quantity = Merchant.GetBuybackItemInfo(i)
			private.db:BulkInsertNewRow(i, itemString, price, quantity)
		end
	end
	private.db:BulkInsertEnd()
end
