-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local VendorBuy = LibTSMService:Init("Item.VendorBuy")
local Math = LibTSMService:From("LibTSMUtil"):Include("Lua.Math")
local VendorSellData = LibTSMService:From("LibTSMData"):Include("VendorSell")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Vendor = LibTSMService:Include("Vendor")
local private = {
	itemsTable = nil,
	updateCallback = nil,
	query = nil, --luacheck: ignore 1004 - just stored for GC reasons
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and configures the vendor buy data.
---@param itemsTable table<string,number> The table to store vendor buy data in
---@param updateCallback fun(itemString: string) Function called when vendor buy data is updated for an item
function VendorBuy.Load(itemsTable, updateCallback)
	private.itemsTable = itemsTable
	private.updateCallback = updateCallback
	private.query = Vendor.NewScannerQuery()
		:Select("itemString", "price", "stackSize")
		:Equal("numAvailable", -1)
		:SetUpdateCallback(private.HandleVendorQueryUpdate)

	local vendorSellData = nil
	if LibTSMService.IsRetail() then
		vendorSellData = VendorSellData.Retail
	elseif LibTSMService.IsPandaClassic() or LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() or LibTSMService.IsWrathClassic() then
		vendorSellData = VendorSellData.Classic
	else
		error("Unknown game version")
	end
	for itemString, cost in pairs(vendorSellData) do
		private.itemsTable[itemString] = private.itemsTable[itemString] or cost
	end
end

---Get the vendor buy price.
---@param item string The item
---@return number?
function VendorBuy.Get(item)
	local itemString = ItemString.Get(item)
	if not itemString or ItemString.ParseLevel(itemString) then
		return nil
	end
	return private.itemsTable[itemString]
end



-- ============================================================================
-- Helper Functions
-- ============================================================================

function private.HandleVendorQueryUpdate(query)
	for _, itemString, price, stackSize in query:Iterator() do
		local newValue = price > 0 and Math.Round(price / stackSize) or nil
		if newValue ~= private.itemsTable[itemString] then
			private.itemsTable[itemString] = newValue
			private.updateCallback(itemString)
		end
	end
end
