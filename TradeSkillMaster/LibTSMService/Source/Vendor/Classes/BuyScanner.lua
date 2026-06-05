-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local BuyScanner = LibTSMService:Init("Vendor.BuyScanner")
local Vararg = LibTSMService:From("LibTSMUtil"):Include("Lua.Vararg")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Database = LibTSMService:From("LibTSMUtil"):Include("Database")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMService:From("LibTSMWoW"):Include("API.Container")
local Currency = LibTSMService:From("LibTSMWoW"):Include("API.Currency")
local Merchant = LibTSMService:From("LibTSMWoW"):Include("API.Merchant")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	db = nil,
	updateTimer = nil,
	rescanTimer = nil,
	costItemTemp = {},
	costQuantityTemp = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

BuyScanner:OnModuleLoad(function()
	private.db = Database.NewSchema("VENDOR_ITEMS")
		:AddUniqueNumberField("index")
		:AddStringField("itemString")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "itemString")
		:AddNumberField("price")
		:AddStringListField("costItems")
		:AddNumberListField("costQuantities")
		:AddNumberField("stackSize")
		:AddNumberField("numAvailable")
		:Commit()
	private.updateTimer = DelayTimer.New("VENDOR_BUY_UPDATE_DB", private.UpdateMerchantDB)
	private.rescanTimer = DelayTimer.New("VENDOR_BUY_RESCAN", private.UpdateMerchantDB)
	DefaultUI.RegisterMerchantVisibleCallback(private.MechantVisibilityHandler)
	Event.Register("MERCHANT_UPDATE", private.MerchantUpdateEventHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new query for the scanner DB.
---@return DatabaseQuery
function BuyScanner.NewQuery()
	return private.db:NewQuery()
end

---Gets the first index of the specified item (or nil if it doesn't exist).
---@param itemString string The item string or base item string to search for
---@return number?
function BuyScanner.GetFirstIndex(itemString)
	local index = private.db:NewQuery()
		:Select("index")
		:Equal("itemString", itemString)
		:OrderBy("index", true)
		:GetFirstResultAndRelease()
	if not index and ItemString.GetBaseFast(itemString) == itemString then
		index = private.db:NewQuery()
			:Select("index")
			:Equal("baseItemString", itemString)
			:OrderBy("index", true)
			:GetFirstResultAndRelease()
	end
	return index
end

---Iterates over the additional cost items and quantities.
---@param index number The index of the row to iterate over
---@return fun(): number, string, number @Iterator with fields: `index`, `itemString`, `quantity`
function BuyScanner.AdditionalCostIterator(index)
	local row = private.db:NewQuery()
		:Equal("index", index)
		:GetFirstResultAndRelease()
	assert(#private.costItemTemp == 0 and #private.costQuantityTemp == 0)
	if row then
		Vararg.IntoTable(private.costItemTemp, row:GetField("costItems"))
		Vararg.IntoTable(private.costQuantityTemp, row:GetField("costQuantities"))
		row:Release()
	end

	assert(#private.costItemTemp == #private.costQuantityTemp)
	local result = TempTable.Acquire()
	for i = 1, #private.costItemTemp do
		tinsert(result, private.costItemTemp[i])
		tinsert(result, private.costQuantityTemp[i])
	end
	wipe(private.costItemTemp)
	wipe(private.costQuantityTemp)
	return TempTable.Iterator(result, 2)
end

---Gets the max number of an item that can be afforded.
---@param index number The index of the item
---@return number
function BuyScanner.GetNumCanAfford(index)
	local row = private.db:NewQuery()
		:Equal("index", index)
		:GetFirstResultAndRelease()
	if not row then
		return 0
	end

	local price, stackSize = row:GetFields("price", "stackSize")
	local maxCanAfford = math.huge

	-- Check the price
	if price > 0 then
		maxCanAfford = min(floor(Currency.GetMoney() / price), maxCanAfford)
	end

	-- Check the additional cost
	assert(#private.costItemTemp == 0 and #private.costQuantityTemp == 0)
	Vararg.IntoTable(private.costItemTemp, row:GetField("costItems"))
	Vararg.IntoTable(private.costQuantityTemp, row:GetField("costQuantities"))
	row:Release()
	for i = 1, #private.costItemTemp do
		local itemString = private.costItemTemp[i]
		local quantity = private.costQuantityTemp[i]
		local _, _, currencyQuantity = Currency.GetInfo(itemString)
		local numHave = currencyQuantity or Container.GetItemCount(ItemString.ToId(itemString))
		maxCanAfford = min(floor(numHave / quantity), maxCanAfford)
	end
	wipe(private.costItemTemp)
	wipe(private.costQuantityTemp)

	return maxCanAfford * stackSize
end

---Gets the total cost for a given quantity of an item.
---@param index number The index of the item
---@param quantity number The index of the item
---@return number price
---@return number numStacks
function BuyScanner.GetTotalCost(index, quantity)
	local price, stackSize = private.db:NewQuery()
		:Select("price", "stackSize")
		:Equal("index", index)
		:GetFirstResultAndRelease()
	if not price then
		return 0, 0
	end
	local numStacks = quantity / stackSize
	return price * numStacks, numStacks
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MechantVisibilityHandler(visible)
	if visible then
		private.updateTimer:RunForFrames(1)
	else
		private.updateTimer:Cancel()
		private.rescanTimer:Cancel()
		private.db:Truncate()
	end
end

function private.MerchantUpdateEventHandler()
	private.updateTimer:RunForFrames(1)
end

function private.UpdateMerchantDB()
	local needsRetry = false
	private.db:TruncateAndBulkInsertStart()
	for i = 1, Merchant.GetNumItems() do
		local itemString = ItemString.Get(Merchant.GetItemLink(i))
		if itemString then
			local price, stackSize, numAvailable = Merchant.GetItemInfo(i)
			assert(#private.costItemTemp == 0 and #private.costQuantityTemp == 0)
			for j = 1, Merchant.GetNumCostItems(i) do
				local costItemLink, costNum = Merchant.GetCostItemInfo(i, j)
				if not costItemLink then
					needsRetry = true
				else
					local costItemString = ItemString.Get(costItemLink) or strmatch(costItemLink, "currency:%d+")
					assert(costItemString)
					tinsert(private.costItemTemp, costItemString)
					tinsert(private.costQuantityTemp, costNum)
				end
			end
			private.db:BulkInsertNewRow(i, itemString, price, private.costItemTemp, private.costQuantityTemp, stackSize, numAvailable)
			wipe(private.costItemTemp)
			wipe(private.costQuantityTemp)
		end
	end
	private.db:BulkInsertEnd()

	if needsRetry then
		Log.Err("Failed to scan merchant")
		private.rescanTimer:RunForTime(0.2)
	else
		private.rescanTimer:Cancel()
	end
end
