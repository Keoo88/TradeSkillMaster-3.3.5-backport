-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Transactions = TSM.MainUI.Ledger.Common:NewPackage("Transactions") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Money = TSM.LibTSMUtil:Include("UI.Money")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	query = nil,
	characters = {},
	characterFilter = {},
	typeFilter = {},
	searchFilter = "",
	groupFilter = {},
	rarityFilter = {},
	timeFrameFilter = 30 * SECONDS_PER_DAY,
	type = nil,
	filteredItemMode = "specific", --luacheck: ignore 1005
}
local TYPE_LIST = { L["Auction"], COD, TRADE, L["Vendor"] }
local TYPE_KEYS = { "Auction", "COD", "Trade", "Vendor" }
local RARITY_LIST = {}
local RARITY_KEYS = { 0, 1, 2, 3, 4, 5 }
do
	for _, key in ipairs(TYPE_KEYS) do
		private.typeFilter[key] = true
	end
	for _, key in ipairs(RARITY_KEYS) do
		tinsert(RARITY_LIST, _G[format("ITEM_QUALITY%d_DESC", key)])
		private.rarityFilter[key] = true
	end
end
local TIME_LIST = { L["All Time"], L["Last 3 Days"], L["Last 7 Days"], L["Last 14 Days"], L["Last 30 Days"], L["Last 60 Days"] }
local TIME_KEYS = { 0, 3 * SECONDS_PER_DAY, 7 * SECONDS_PER_DAY, 14 * SECONDS_PER_DAY, 30 * SECONDS_PER_DAY, 60 * SECONDS_PER_DAY }



-- ============================================================================
-- Module Functions
-- ============================================================================

function Transactions.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "ledgerTransactionsScrollingTable")
	TSM.MainUI.Ledger.Expenses.RegisterPage(L["Purchases"], private.DrawPurchasesPage)
	TSM.MainUI.Ledger.Revenue.RegisterPage(L["Sales"], private.DrawSalesPage)
end



-- ============================================================================
-- Transactions UIs
-- ============================================================================

function private.DrawPurchasesPage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "expenses", "purchases")
	private.type = "buy"
	return private.DrawTransactionPage()
end

function private.DrawSalesPage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "sales")
	private.type = "sale"
	return private.DrawTransactionPage()
end

function private.DrawTransactionPage()
	private.query = private.query or TSM.Accounting.Transactions.CreateQuery()

	private.query:Reset()
		:Equal("type", private.type)
		:Distinct("player")
		:Select("player")
	wipe(private.characters)
	for _, character in private.query:Iterator() do
		tinsert(private.characters, character)
		private.characterFilter[character] = true
	end

	private.query:Reset()
	TSM.Accounting.Transactions.AddSmartMap(private.query)
	TSM.Accounting.Transactions.UpdateSmartMap(private.filteredItemMode)

	private.query:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "?")
		:VirtualField("quality", "number", ItemInfo.GetQuality, "filteredItemString", 0)
		:VirtualField("total", "number", private.GetTotal)
		:VirtualField("auctions", "number", private.GetAuctions)

	local frame = UIElements.New("Frame", "content")
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
			:AddChild(UIElements.New("SelectionDropdown", "itemMode")
				:SetWidth(220)
				:SetMargin(0, 8, 0, 0)
				:AddItem(L["Specific Item"], "specific")
				:AddItem(L["Item Level"], "level")
				:AddItem(L["Base Item"], "base")
				:SetSettingInfo(private, "filteredItemMode")
				:SetScript("OnSelectionChanged", private.ItemModeOnSelectionChanged)
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
			:AddChild(UIElements.New("MultiselectionDropdown", "type")
				:SetMargin(0, 8, 0, 0)
				:SetItems(TYPE_LIST, TYPE_KEYS)
				:SetSettingInfo(private, "typeFilter")
				:SetSelectionText(L["No Types"], L["%d Types"], L["All Types"])
				:SetScript("OnSelectionChanged", private.HandleFilterChanged)
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "rarity")
				:SetMargin(0, 8, 0, 0)
				:SetItems(RARITY_LIST, RARITY_KEYS)
				:SetSettingInfo(private, "rarityFilter")
				:SetSelectionText(L["No Rarities"], L["%d Rarities"], L["All Rarities"])
				:SetScript("OnSelectionChanged", private.HandleFilterChanged)
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "character")
				:SetMargin(0, 8, 0, 0)
				:SetItems(private.characters, private.characters)
				:SetSettingInfo(private, "characterFilter")
				:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
				:SetScript("OnSelectionChanged", private.HandleFilterChanged)
			)
			:AddChild(UIElements.New("SelectionDropdown", "time")
				:SetItems(TIME_LIST, TIME_KEYS)
				:SetSelectedItemByKey(private.timeFrameFilter)
				:SetSettingInfo(private, "timeFrameFilter")
				:SetScript("OnSelectionChanged", private.HandleFilterChanged)
			)
		)
		:AddChild(UIElements.New("LedgerTransactionsScrollTable", "scrollingTable")
			:SetSettings(private.settings, "ledgerTransactionsScrollingTable")
			:SetCreatedGroupName(L["Ledger"].." - "..(private.type == "sale" and L["Sales"] or L["Purchases"]))
			:SetQuery(private.query)
			:SetFilters(private.GetScrollTableFilters())
			:SetScript("OnItemRowClick", private.TableHandleItemRowClick)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Text", "num")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY2_MEDIUM")
			)
			:AddChild(UIElements.New("VerticalLine", "line")
				:SetMargin(4, 8, 0, 0)
			)
			:AddChild(UIElements.New("Text", "profit")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY2_MEDIUM")
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)

	local numItems = private.query:Sum("quantity")
	local total = private.query:Sum("total")
	frame:GetElement("footer.num"):SetText(format(private.type == "sale" and L["%s Items Sold"] or L["%s Items Bought"], Theme.GetColor("INDICATOR"):ColorText(FormatLargeNumber(numItems))))
	frame:GetElement("footer.profit"):SetText(format(L["%s Total"], Money.ToStringForUI(total)))
	return frame
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.HandleFilterChanged(element)
	local content = element:GetParentElement():GetParentElement()
	content:GetElement("scrollingTable"):SetFilters(private.GetScrollTableFilters())
	local numItems = private.query:Sum("quantity")
	local total = private.query:Sum("total")
	local footer = content:GetElement("footer")
	footer:GetElement("num"):SetText(format(private.type == "sale" and L["%s Items Sold"] or L["%s Items Bought"], Theme.GetColor("INDICATOR"):ColorText(FormatLargeNumber(numItems))))
	footer:GetElement("profit"):SetText(format(L["%s Total"], Money.ToStringForUI(total)))
	footer:Draw()
end

function private.SearchFilterChanged(input)
	private.searchFilter = input:GetValue()
	private.HandleFilterChanged(input)
end

function private.GroupFilterChanged(groupSelector)
	wipe(private.groupFilter)
	for groupPath in groupSelector:SelectedGroupIterator() do
		private.groupFilter[groupPath] = true
	end
	private.HandleFilterChanged(groupSelector)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetTotal(row)
	return row:GetField("price") * row:GetField("quantity")
end

function private.GetAuctions(row)
	return row:GetField("quantity") / row:GetField("stackSize")
end

function private.GetScrollTableFilters()
	local name = String.Escape(private.searchFilter)
	name = name ~= "" and name or nil
	local source = Table.Count(private.typeFilter) ~= #TYPE_KEYS and private.typeFilter or nil
	local quality = Table.Count(private.rarityFilter) ~= #RARITY_LIST and private.rarityFilter or nil
	local player = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
	local minTimeFrame = private.timeFrameFilter ~= 0 and private.timeFrameFilter or nil
	local group = next(private.groupFilter) and private.groupFilter or nil
	return private.type, name, source, quality, player, minTimeFrame, group
end

function private.TableHandleItemRowClick(scrollTable, itemString)
	TSM.MainUI.Ledger.ShowItemDetail(scrollTable:GetParentElement():GetParentElement(), itemString, private.type)
end

function private.ItemModeOnSelectionChanged(dropDown)
	TSM.Accounting.Transactions.UpdateSmartMap(private.filteredItemMode)
	private.HandleFilterChanged(dropDown)
end
