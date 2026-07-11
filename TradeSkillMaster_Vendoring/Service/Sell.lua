-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local Sell = TSM.Vendoring:NewPackage("Sell") ---@type AddonPackage
local Database = TSM.LibTSMUtil:Include("Database")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Container = TSM.LibTSMWoW:Include("API.Container")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local private = {
	settings = nil,
	ignoreDB = nil,
	potentialValueDB = nil,
	potentialValueDirty = true,
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
	-- 3.3.5 perf: BAG_UPDATE на этом клиенте сыплется очень часто (лут, крафт,
	-- почта), а полная пересборка potentialValueDB с вычислением qsMarketValue
	-- по каждому distinct-предмету дорога. Пересобираем только когда окно
	-- вендора открыто; вне вендора лишь помечаем данные устаревшими.
	BagTracking.RegisterCallback(private.HandleBagUpdate)
	DefaultUI.RegisterMerchantVisibleCallback(private.HandleMerchantShow, true)
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
	-- 3.3.5 fix (зеркально Mailing/Send.lua): флаг isBound в slotDB ненадёжен —
	-- он true для множества обычных предметов (у нативного container API нет
	-- bound-флага), из-за чего Quick Sell прятал валидные предметы. Применяем
	-- фильтр только на клиентах, которые его реально сообщают; BoP-предметы
	-- вендорятся в любом случае, так что риск лишь в лишних строках списка.
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		query:Equal("isBound", false)
	end
	query:GreaterThan("vendorSell", 0)
end

function Sell.SellItem(itemString, includeSoulbound)
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
		:Select("bag", "slot", "itemString")
	-- 3.3.5 fix: см. комментарий в ResetBagsQuery — ненадёжный isBound не должен
	-- мешать продаже валидных предметов
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) and not includeSoulbound then
		query:Equal("isBound", false)
	end
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

function private.HandleBagUpdate()
	if DefaultUI.IsMerchantVisible() then
		private.UpdatePotentialValueDB()
	else
		private.potentialValueDirty = true
	end
end

function private.HandleMerchantShow()
	if private.potentialValueDirty then
		private.UpdatePotentialValueDB()
	end
end

function private.UpdatePotentialValueDB()
	private.potentialValueDirty = false
	private.potentialValueDB:TruncateAndBulkInsertStart()
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
		:Select("itemString")
		:Distinct("itemString")
	-- 3.3.5 fix: см. комментарий в ResetBagsQuery про ненадёжный isBound
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		query:Equal("isBound", false)
	end
	for _, itemString in query:Iterator() do
		local value = CustomString.GetValue(private.settings.qsMarketValue, itemString)
		if value then
			private.potentialValueDB:BulkInsertNewRow(itemString, value)
		end
	end
	query:Release()
	private.potentialValueDB:BulkInsertEnd()
end
