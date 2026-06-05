-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Auctions = TSM.MainUI.Ledger.Common:NewPackage("Auctions") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local String = TSM.LibTSMUtil:Include("Lua.String")
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
	searchFilter = "",
	groupFilter = {},
	rarityFilter = {},
	timeFrameFilter = 30 * SECONDS_PER_DAY,
	type = nil,
	filteredItemMode = "specific", --luacheck: ignore 1005
}
local RARITY_LIST = {}
local RARITY_KEYS = { 0, 1, 2, 3, 4, 5 }
do
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

function Auctions.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "ledgerAuctionsScrollingTable")
	TSM.MainUI.Ledger.FailedAuctions.RegisterPage(L["Expired"], private.DrawExpiredPage)
	TSM.MainUI.Ledger.FailedAuctions.RegisterPage(L["Cancelled"], private.DrawCancelledPage)
end



-- ============================================================================
-- Auctions UIs
-- ============================================================================

function private.DrawExpiredPage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "failed_auctions", "expired")
	private.type = "expire"
	return private.DrawAuctionsPage()
end

function private.DrawCancelledPage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "failed_auctions", "cancelled")
	private.type = "cancel"
	return private.DrawAuctionsPage()
end

function private.DrawAuctionsPage()
	private.query = private.query or TSM.Accounting.Auctions.CreateQuery()

	private.query:Reset()
		:Equal("type", "cancel")
		:Distinct("player")
		:Select("player")
	wipe(private.characters)
	for _, character in private.query:Iterator() do
		tinsert(private.characters, character)
		private.characterFilter[character] = true
	end

	private.query:Reset()
	TSM.Accounting.Auctions.AddSmartMap(private.query)
	TSM.Accounting.Auctions.UpdateSmartMap(private.filteredItemMode)

	private.query:VirtualField("name", "string", ItemInfo.GetName, "filteredItemString", "?")
		:VirtualField("quality", "number", ItemInfo.GetQuality, "filteredItemString", 0)
		:VirtualField("auctions", "number", private.AuctionsVirtualField)

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
			:AddChild(UIElements.New("MultiselectionDropdown", "rarity")
				:SetMargin(0, 8, 0, 0)
				:SetItems(RARITY_LIST, RARITY_KEYS)
				:SetSettingInfo(private, "rarityFilter")
				:SetSelectionText(L["No Rarities"], L["%d Rarities"], L["All Rarites"])
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
		:AddChild(UIElements.New("LedgerAuctionsScrollTable", "scrollingTable")
			:SetSettings(private.settings, "ledgerAuctionsScrollingTable")
			:SetCreatedGroupName(L["Ledger"].." - "..(private.type == "sale" and L["Expired Auctions"] or L["Cancelled Auctions"]))
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
			:AddChild(UIElements.New("Spacer", "spacer"))
		)

	content:GetElement("footer.num"):SetText(format(private.type == "expire" and L["%s Items Expired"] or L["%s Items Cancelled"], Theme.GetColor("INDICATOR"):ColorText(FormatLargeNumber(private.query:Sum("quantity")))))
	return content
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.HandleFilterChanged(element)
	local content = element:GetParentElement():GetParentElement()
	content:GetElement("scrollingTable"):SetFilters(private.GetScrollTableFilters())
	local footer = content:GetElement("footer")
	footer:GetElement("num"):SetText(format(private.type == "expire" and L["%s Items Expired"] or L["%s Items Cancelled"], Theme.GetColor("INDICATOR"):ColorText(FormatLargeNumber(private.query:Sum("quantity")))))
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

function private.AuctionsVirtualField(row)
	return row:GetField("quantity") / row:GetField("stackSize")
end

function private.GetScrollTableFilters()
	local typeFilter = private.type
	local name = String.Escape(private.searchFilter)
	name = name ~= "" and name or nil
	local quality = Table.Count(private.rarityFilter) ~= #RARITY_LIST and private.rarityFilter or nil
	local player = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
	local timeFilter = private.timeFrameFilter ~= 0 and private.timeFrameFilter or nil
	local group = next(private.groupFilter) and private.groupFilter or nil
	return typeFilter, name, quality, player, timeFilter, group
end

function private.TableHandleItemRowClick(scrollTable, itemString)
	TSM.MainUI.Ledger.ShowItemDetail(scrollTable:GetParentElement():GetParentElement(), itemString, "sale")
end

function private.ItemModeOnSelectionChanged(dropDown)
	TSM.Accounting.Auctions.UpdateSmartMap(private.filteredItemMode)
	private.HandleFilterChanged(dropDown)
end
