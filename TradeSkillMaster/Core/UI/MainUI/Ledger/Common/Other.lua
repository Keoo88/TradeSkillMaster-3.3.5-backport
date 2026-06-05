-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Other = TSM.MainUI.Ledger.Common:NewPackage("Other") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local SECONDS_PER_DAY = 24 * 60 * 60
local private = {
	settings = nil,
	characters = {},
	characterFilter = {},
	typeFilter = {},
	recordType = nil,
	timeFrameFilter = 30 * SECONDS_PER_DAY,
}
local TIME_LIST = { L["All Time"], L["Last 3 Days"], L["Last 7 Days"], L["Last 14 Days"], L["Last 30 Days"], L["Last 60 Days"] }
local TIME_KEYS = { 0, 3 * SECONDS_PER_DAY, 7 * SECONDS_PER_DAY, 14 * SECONDS_PER_DAY, 30 * SECONDS_PER_DAY, 60 * SECONDS_PER_DAY }
local TYPE_LIST = {
	expense = { L["Money Transfer"], L["Postage"], L["Repair Bill"], L["Crafting Order"] },
	income = { L["Money Transfer"], L["Garrison"], L["Crafting Order"] },
}
local TYPE_KEYS = {
	expense = { "Money Transfer", "Postage", "Repair Bill", "Crafting Order" },
	income = { "Money Transfer", "Garrison", "Crafting Order" },
}
local TYPE_STR_LOOKUP = {}
do
	-- populate lookup table
	assert(#TYPE_LIST.expense == #TYPE_KEYS.expense)
	for i = 1, #TYPE_LIST.expense do
		TYPE_STR_LOOKUP[TYPE_KEYS.expense[i]] = TYPE_LIST.expense[i]
	end
	assert(#TYPE_LIST.income == #TYPE_KEYS.income)
	for i = 1, #TYPE_LIST.income do
		TYPE_STR_LOOKUP[TYPE_KEYS.income[i]] = TYPE_LIST.income[i]
	end
end



-- ============================================================================
-- Module Functions
-- ============================================================================

function Other.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "ledgerOtherScrollingTable")
	TSM.MainUI.Ledger.Expenses.RegisterPage(OTHER, private.DrawOtherExpensesPage)
	TSM.MainUI.Ledger.Revenue.RegisterPage(OTHER, private.DrawOtherRevenuePage)
end



-- ============================================================================
-- Other UIs
-- ============================================================================

function private.DrawOtherExpensesPage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "expenses", "other")
	return private.DrawOtherPage("expense")
end

function private.DrawOtherRevenuePage()
	UIUtils.AnalyticsRecordPathChange("main", "ledger", "revenue", "other")
	return private.DrawOtherPage("income")
end

function private.DrawOtherPage(recordType)
	wipe(private.characters)
	for _, character in TSM.Accounting.Money.CharacterIterator(recordType) do
		tinsert(private.characters, character)
		private.characterFilter[character] = true
	end
	wipe(private.typeFilter)
	for _, key in ipairs(TYPE_KEYS[recordType]) do
		private.typeFilter[key] = true
	end

	local query = TSM.Accounting.Money.CreateQuery()
		:VirtualField("typeStr", "string", private.TypeStrVirtualField, "type")
	private.recordType = recordType

	return UIElements.New("Frame", "content")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "row2")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8)
			:AddChild(UIElements.New("MultiselectionDropdown", "type")
				:SetMargin(0, 8, 0, 0)
				:SetItems(TYPE_LIST[recordType], TYPE_KEYS[recordType])
				:SetSettingInfo(private, "typeFilter")
				:SetSelectionText(L["No Types"], L["%d Types"], L["All Types"])
				:SetScript("OnSelectionChanged", private.DropdownChangedCommon)
			)
			:AddChild(UIElements.New("MultiselectionDropdown", "character")
				:SetMargin(0, 8, 0, 0)
				:SetItems(private.characters, private.characters)
				:SetSettingInfo(private, "characterFilter")
				:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
				:SetScript("OnSelectionChanged", private.DropdownChangedCommon)
			)
			:AddChild(UIElements.New("SelectionDropdown", "time")
				:SetItems(TIME_LIST, TIME_KEYS)
				:SetSelectedItemByKey(private.timeFrameFilter)
				:SetSettingInfo(private, "timeFrameFilter")
				:SetScript("OnSelectionChanged", private.DropdownChangedCommon)
			)
		)
		:AddChild(UIElements.New("LedgerOtherScrollTable", "table")
			:SetSettings(private.settings, "ledgerOtherScrollingTable")
			:SetQuery(query)
			:SetFilters(private.GetScrollTableFilters())
		)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DropdownChangedCommon(dropdown)
	dropdown:GetElement("__parent.__parent.table"):SetFilters(private.GetScrollTableFilters())
end

function private.TypeStrVirtualField(typeValue)
	return TYPE_STR_LOOKUP[typeValue]
end

function private.GetScrollTableFilters()
	local recordType = private.recordType
	local typeFilter = Table.Count(private.typeFilter) ~= #TYPE_KEYS[private.recordType] and private.typeFilter or nil
	local player = Table.Count(private.characterFilter) ~= #private.characters and private.characterFilter or nil
	local timeFilter = private.timeFrameFilter ~= 0 and private.timeFrameFilter or nil
	return recordType, typeFilter, player, timeFilter
end
