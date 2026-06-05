-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Inventory = TSM.MainUI.Ledger:NewPackage("Inventory") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local Database = TSM.LibTSMUtil:Include("Database")
local Group = TSM.LibTSMTypes:Include("Group")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local Auction = TSM.LibTSMService:Include("Auction")
local Mail = TSM.LibTSMService:Include("Mail")
local AltTracking = TSM.LibTSMApp:Include("Service.AltTracking")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	db = nil,
	query = nil,
	searchFilter = "",
	groupFilter = {},
	valuePriceSource = "dbmarket", -- luacheck: ignore 1005 - hidden modify via SetSettingInfo()
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Inventory.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "ledgerInventoryScrollingTable")
	TSM.MainUI.Ledger.RegisterPage(L["Inventory"], private.DrawInventoryPage)
end

function Inventory.OnEnable()
	private.db = Database.NewSchema("LEDGER_INVENTORY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("bagQuantity")
		:AddNumberField("bankQuantity")
		:AddNumberField("auctionQuantity")
		:AddNumberField("mailQuantity")
		:AddNumberField("altQuantity")
		:AddNumberField("guildQuantity")
		:AddNumberField("totalBankQuantity")
		:AddNumberField("totalQuantity")
		:Commit()
	private.query = private.db:NewQuery()
		:VirtualField("totalValue", "number", private.TotalValueVirtualField)
		:VirtualField("name", "string", ItemInfo.GetName, "levelItemString", "")
		:VirtualField("groupPath", "string", Group.GetPathByItem, "levelItemString")
end



-- ============================================================================
-- Inventory UI
-- ============================================================================

function private.DrawInventoryPage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "inventory")
	local items = TempTable.Acquire()
	local bagQuantityLookup = TempTable.Acquire()
	local bankQuantityLookup = TempTable.Acquire()
	local auctionQuantityLookup = TempTable.Acquire()
	local mailQuantityLookup = TempTable.Acquire()
	local altQuantityLookup = TempTable.Acquire()
	local guildQuantityLookup = TempTable.Acquire()
	local warbankQuantityLookup = TempTable.Acquire()
	for _, levelItemString, bagQuantity, bankQuantity in BagTracking.QuantityIterator() do
		items[levelItemString] = true
		bagQuantityLookup[levelItemString] = bagQuantity
		bankQuantityLookup[levelItemString] = bankQuantity
	end
	for _, levelItemString, auctionQuantity in Auction.QuantityIterator() do
		items[levelItemString] = true
		auctionQuantityLookup[levelItemString] = auctionQuantity
	end
	for _, levelItemString, mailQuantity in Mail.QuantityIterator() do
		items[levelItemString] = true
		mailQuantityLookup[levelItemString] = mailQuantity
	end
	for _, levelItemString, altQuantity in AltTracking.QuantityIterator() do
		items[levelItemString] = true
		altQuantityLookup[levelItemString] = altQuantity
	end
	AltTracking.GetGuildItems(guildQuantityLookup)
	for levelItemString in pairs(guildQuantityLookup) do
		items[levelItemString] = true
	end
	for _, levelItemString, quantity in WarbankTracking.QuantityIterator() do
		items[levelItemString] = true
		warbankQuantityLookup[levelItemString] = quantity
	end
	private.db:TruncateAndBulkInsertStart()
	for levelItemString in pairs(items) do
		local bagQuantity = bagQuantityLookup[levelItemString] or 0
		local bankQuantity = bankQuantityLookup[levelItemString] or 0
		local auctionQuantity = auctionQuantityLookup[levelItemString] or 0
		local mailQuantity = mailQuantityLookup[levelItemString] or 0
		local altQuantity = altQuantityLookup[levelItemString] or 0
		local guildQuantity = guildQuantityLookup[levelItemString] or 0
		local warbankQuantity = warbankQuantityLookup[levelItemString] or 0
		local totalBankQuantity = bankQuantity + warbankQuantity
		local totalQuantity = bagQuantity + totalBankQuantity + guildQuantity + auctionQuantity + mailQuantity + altQuantity
		private.db:BulkInsertNewRow(levelItemString, bagQuantity, bankQuantity, auctionQuantity, mailQuantity, altQuantity, guildQuantity, totalBankQuantity, totalQuantity)
	end
	private.db:BulkInsertEnd()
	TempTable.Release(items)
	TempTable.Release(bagQuantityLookup)
	TempTable.Release(bankQuantityLookup)
	TempTable.Release(auctionQuantityLookup)
	TempTable.Release(mailQuantityLookup)
	TempTable.Release(altQuantityLookup)
	TempTable.Release(warbankQuantityLookup)

	local content = UIElements.New("Frame", "content")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "row1")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8)
			:AddChild(UIElements.New("Input", "filter")
				:SetMargin(0, 8, 0, 0)
				:SetIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:AllowItemInsert()
				:SetHintText(L["Filter by keyword"])
				:SetValue(private.searchFilter)
				:SetScript("OnValueChanged", private.SearchFilterChanged)
			)
			:AddChild(UIElements.New("GroupSelector", "group")
				:SetWidth(240)
				:SetHintText(L["Filter by groups"])
				:SetSelection(next(private.groupFilter) and private.groupFilter or nil)
				:SetScript("OnSelectionChanged", private.GroupFilterChanged)
			)
		)
		:AddChild(UIElements.New("Frame", "row2")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8, 8, 0, 8)
			:AddChild(UIElements.New("Text", "label")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY3")
				:SetText(L["Value Price Source"])
			)
			:AddChild(UIElements.New("Input", "input")
				:SetMargin(4, 8, 0, 0)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:SetBorderColor("ACTIVE_BG")
				:SetFont("TABLE_TABLE1")
				:SetValidateFunc("CUSTOM_STRING")
				:SetSettingInfo(private, "valuePriceSource")
				:SetScript("OnValueChanged", private.FilterChangedCommon)
			)
			:AddChild(UIElements.New("Frame", "value")
				:SetLayout("HORIZONTAL")
				:SetWidth(240)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "label")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY3")
					:SetMargin(0, 4, 0, 0)
					:SetText(L["Total Value"]..":")
				)
				:AddChild(UIElements.New("Text", "value")
					:SetWidth("AUTO")
					:SetFont("TABLE_TABLE1")
				)
			)
		)
		:AddChild(UIElements.New("LedgerInventoryScrollTable", "scrollingTable")
			:SetSettings(private.settings, "ledgerInventoryScrollingTable")
			:SetQuery(private.query)
			:SetFilters(private.GetScrollTableFilters())
		)

	content:GetElement("row2.value.value"):SetText(Money.ToStringForUI(private.GetTotalValue()))
	return content
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.FilterChangedCommon(element)
	local content = element:GetParentElement():GetParentElement()
	content:GetElement("scrollingTable"):SetFilters(private.GetScrollTableFilters())
	content:GetElement("row2.value.value")
		:SetText(Money.ToStringForUI(private.GetTotalValue()))
		:Draw()
end

function private.SearchFilterChanged(input)
	private.searchFilter = input:GetValue()
	private.FilterChangedCommon(input)
end

function private.GroupFilterChanged(groupSelector)
	wipe(private.groupFilter)
	for groupPath in groupSelector:SelectedGroupIterator() do
		private.groupFilter[groupPath] = true
	end
	private.FilterChangedCommon(groupSelector)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.TotalValueVirtualField(row)
	local levelItemString, totalQuantity = row:GetFields("levelItemString", "totalQuantity")
	local price = CustomString.GetValue(private.valuePriceSource, levelItemString)
	if not price then
		return Math.GetNan()
	end
	return price * totalQuantity
end

function private.GetTotalValue()
	-- can't lookup the value of items while the query is iteratoring, so grab the list of items first
	local itemQuantities = TempTable.Acquire()
	for _, row in private.query:Iterator() do
		local levelItemString, total = row:GetFields("levelItemString", "totalQuantity")
		itemQuantities[levelItemString] = total
	end
	local totalValue = 0
	for levelItemString, total in pairs(itemQuantities) do
		local price = CustomString.GetValue(private.valuePriceSource, levelItemString)
		if price then
			totalValue = totalValue + price * total
		end
	end
	TempTable.Release(itemQuantities)
	return totalValue
end

function private.GetScrollTableFilters()
	local name = String.Escape(private.searchFilter)
	name = name ~= "" and name or nil
	local group = next(private.groupFilter) and private.groupFilter or nil
	return name, group
end
