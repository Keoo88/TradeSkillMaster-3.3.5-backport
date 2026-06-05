-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Sell = TSM.Vendoring:NewPackage("Sell") ---@type AddonPackage
local Database = TSM.LibTSMUtil:Include("Database")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Container = TSM.LibTSMWoW:Include("API.Container")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local private = {
	settings = nil,
	ignoreDB = nil,
	potentialValueDB = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sell.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "userData", "vendoringIgnore")
		:AddKey("global", "vendoringOptions", "qsMarketValue")
	local used = TempTable.Acquire()
	private.ignoreDB = Database.NewSchema("VENDORING_IGNORE")
		:AddUniqueStringField("itemString")
		:AddBooleanField("ignoreSession")
		:AddBooleanField("ignorePermanent")
		:Commit()
	private.ignoreDB:BulkInsertStart()
	for itemString in pairs(private.settings.vendoringIgnore) do
		itemString = ItemString.Get(itemString)
		if not used[itemString] then
			used[itemString] = true
			private.ignoreDB:BulkInsertNewRow(itemString, false, true)
		end
	end
	private.ignoreDB:BulkInsertEnd()
	TempTable.Release(used)

	private.potentialValueDB = Database.NewSchema("VENDORING_POTENTIAL_VALUE")
		:AddUniqueStringField("itemString")
		:AddNumberField("potentialValue")
		:Commit()
	BagTracking.RegisterCallback(private.UpdatePotentialValueDB)
end

function Sell.IgnoreItemSession(itemString)
	local row = private.ignoreDB:GetUniqueRow("itemString", itemString)
	if row then
		assert(not row:GetField("ignoreSession"))
		row:SetField("ignoreSession", true)
		row:Update()
		row:Release()
	else
		private.ignoreDB:NewRow()
			:SetField("itemString", itemString)
			:SetField("ignoreSession", true)
			:SetField("ignorePermanent", false)
			:Create()
	end
end

function Sell.IgnoreItemPermanent(itemString)
	assert(not private.settings.vendoringIgnore[itemString])
	private.settings.vendoringIgnore[itemString] = true

	local row = private.ignoreDB:GetUniqueRow("itemString", itemString)
	if row then
		assert(not row:GetField("ignorePermanent"))
		row:SetField("ignorePermanent", true)
		row:Update()
		row:Release()
	else
		private.ignoreDB:NewRow()
			:SetField("itemString", itemString)
			:SetField("ignoreSession", false)
			:SetField("ignorePermanent", true)
			:Create()
	end
end

function Sell.ForgetIgnoreItemPermanent(itemString)
	assert(private.settings.vendoringIgnore[itemString])
	private.settings.vendoringIgnore[itemString] = nil

	local row = private.ignoreDB:GetUniqueRow("itemString", itemString)
	assert(row and row:GetField("ignorePermanent"))
	if row:GetField("ignoreSession") then
		row:SetField("ignorePermanent")
		row:Update()
	else
		private.ignoreDB:DeleteRow(row)
	end
	row:Release()
end

function Sell.CreateIgnoreQuery()
	return private.ignoreDB:NewQuery()
		:Equal("ignorePermanent", true)
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:OrderBy("name", true)
end

function Sell.CreateBagsQuery()
	local query = BagTracking.CreateQueryBags()
		:Distinct("itemString")
		:LeftJoin(private.ignoreDB, "itemString")
		:LeftJoin(private.potentialValueDB, "itemString")
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:VirtualField("vendorSell", "number", ItemInfo.GetVendorSell, "itemString", 0)
		:VirtualField("quality", "number", ItemInfo.GetQuality, "itemString", -1)
	Sell.ResetBagsQuery(query)
	return query
end

function Sell.ResetBagsQuery(query)
	query:ResetFilters()
	BagTracking.FilterQueryBags(query)
	query:NotEqual("ignoreSession", true)
		:NotEqual("ignorePermanent", true)
		:Equal("isBound", false)
		:GreaterThan("vendorSell", 0)
end

function Sell.SellItem(itemString, includeSoulbound)
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
		:Select("bag", "slot", "itemString")
		:Equal("isBound", false)
	for _, bag, slot, bagItemString in query:Iterator() do
		if itemString == bagItemString and ItemString.Get(Container.GetItemLink(bag, slot)) == itemString then
			Container.UseItem(bag, slot)
		end
	end
	query:Release()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdatePotentialValueDB()
	private.potentialValueDB:TruncateAndBulkInsertStart()
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
		:Select("itemString")
		:Distinct("itemString")
		:Equal("isBound", false)
	for _, itemString in query:Iterator() do
		local value = CustomString.GetValue(private.settings.qsMarketValue, itemString)
		if value then
			private.potentialValueDB:BulkInsertNewRow(itemString, value)
		end
	end
	query:Release()
	private.potentialValueDB:BulkInsertEnd()
end
