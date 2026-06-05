-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Resale = TSM.MainUI.Ledger.Revenue:NewPackage("Resale") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	summaryQuery = nil,
	characters = {},
	characterFilter = {},
	typeFilter = {},
	rarityFilter = {},
	groupFilter = {},
	searchFilter = "",
	timeFrameFilter = 30 * SECONDS_PER_DAY,
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

function Resale.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "ledgerResaleScrollingTable")
	TSM.MainUI.Ledger.Revenue.RegisterPage(L["Resale"], private.DrawResalePage)
end



-- ============================================================================
-- Resale UI
-- ============================================================================

function private.DrawResalePage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "resale")
	wipe(private.characters)
	TSM.Accounting.Transactions.GetCharacters(private.characters)
	for _, character in ipairs(private.characters) do
		private.characterFilter[character] = true
	end

	private.summaryQuery = private.summaryQuery or TSM.Accounting.Transactions.CreateSummaryQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "?")
		:VirtualField("quality", "number", ItemInfo.GetQuality, "filteredItemString", 0)

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
		:AddChild(UIElements.New("LedgerResaleScrollTable", "scrollingTable")
			:SetSettings(private.settings, "ledgerResaleScrollingTable")
			:SetQuery(private.summaryQuery)
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

	private.UpdateQueryAndFooter(content:GetElement("footer"))
	return content
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.HandleFilterChanged(element)
	local content = element:GetParentElement():GetParentElement()
	content:GetElement("scrollingTable"):SetFilters(private.GetScrollTableFilters())
	local footer = content:GetElement("footer")
	private.UpdateQueryAndFooter(footer)
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

function private.UpdateQueryAndFooter(footer)
	local itemMode = private.filteredItemMode
	local groupFilter = next(private.groupFilter) and private.groupFilter or nil
	local searchFilter = private.searchFilter ~= "" and private.searchFilter or nil
	local typeFilter = Table.Count(private.typeFilter) ~= #TYPE_KEYS and private.typeFilter or nil
	local characterFilter = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
	local minTime = private.timeFrameFilter ~= 0 and (time() - private.timeFrameFilter) or nil
	TSM.Accounting.Transactions.UpdateSummaryData(itemMode, groupFilter, searchFilter, typeFilter, characterFilter, minTime)

	local totalProfit, numItems = 0, 0
	for _, row in private.summaryQuery:Iterator() do
		totalProfit = totalProfit + row:GetField("totalProfit")
		numItems = numItems + min(row:GetFields("sold", "bought"))
	end
	footer:GetElement("num"):SetText(format(L["%s Items Resold"], Theme.GetColor("INDICATOR"):ColorText(FormatLargeNumber(numItems))))
	footer:GetElement("profit"):SetText(format(L["%s Total Profit"], Money.ToStringForUI(totalProfit)))
end

function private.GetScrollTableFilters()
	local quality = Table.Count(private.rarityFilter) ~= #RARITY_LIST and private.rarityFilter or nil
	return quality
end

function private.TableHandleItemRowClick(scrollTable, itemString)
	TSM.MainUI.Ledger.ShowItemDetail(scrollTable:GetParentElement():GetParentElement(), itemString, "sale")
end

function private.ItemModeOnSelectionChanged(dropDown)
	local footer = dropDown:GetElement("__parent.__parent.footer")
	private.UpdateQueryAndFooter(footer)
	private.DrawResalePage()
end
