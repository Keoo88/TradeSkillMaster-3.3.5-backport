-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Sell = TSM.UI.VendoringUI:NewPackage("Sell") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	filterText = "",
	query = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sell.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "vendoringUIContext", "sellScrollingTable")
	TSM.UI.VendoringUI.RegisterTopLevelPage(L["Sell"], private.GetFrame)
end



-- ============================================================================
-- Sell UI
-- ============================================================================

function private.GetFrame()
	UIUtils.AnalyticsRecordPathChange("vendoring", "sell")
	private.filterText = ""
	private.query = private.query or TSM.Vendoring.Sell.CreateBagsQuery()

	return UIElements.New("Frame", "sell")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("VERTICAL")
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Text", "ignoreText")
				:SetHeight(36)
				:SetMargin(0, 0, 0, 8)
				:SetFont("BODY_BODY3")
				:SetText(format(L["%sLeft-Click|r to ignore an item for this session. Hold %sShift|r to ignore permanently. You can remove items from permanent ignore in the Vendoring settings."], Theme.GetColor("INDICATOR"):GetTextColorPrefix(), Theme.GetColor("INDICATOR"):GetTextColorPrefix()))
			)
			:AddChild(UIElements.New("Frame", "filters")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("Input", "searchInput")
					:SetIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:AllowItemInsert()
					:SetHintText(L["Search Bags"])
					:SetScript("OnValueChanged", private.InputOnValueChanged)
				)
				:AddChild(UIElements.New("Button", "filterBtn")
					:SetWidth("AUTO")
					:SetMargin(8, 8, 0, 0)
					:SetFont("BODY_BODY3_MEDIUM")
					:SetText(FILTERS)
					-- TODO
					-- :SetScript("OnClick", private.FilterButtonOnClick)
				)
				:AddChild(UIElements.New("Button", "filterBtnIcon")
					:SetBackgroundAndSize("iconPack.14x14/Filter")
					-- TODO
					-- :SetScript("OnClick", private.FilterButtonOnClick)
				)
			)
		)
		:AddChild(UIElements.New("VendorSellScrollTable", "items")
			:SetSettings(private.settings, "sellScrollingTable")
			:SetQuery(private.query, private.QueryResetFiltersFunc)
			:SetScript("OnIgnoreItem", private.RowOnIgnoreItem)
			:SetScript("OnSellItem", private.RowOnSellItem)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "sellTrashBtn")
				:SetWidth(128)
				:SetMargin(0, 8, 0, 0)
				:SetText(L["Sell Trash"])
				:SetScript("OnClick", private.SellTrashBtnOnClick)
			)
			:AddChild(UIElements.New("ActionButton", "sellBOEBtn")
				:SetWidth(128)
				:SetMargin(0, 8, 0, 0)
				:SetText(L["Sell BoEs"])
				:SetScript("OnClick", private.SellBOEBtnOnClick)
			)
			:AddChild(UIElements.New("ActionButton", "sellAllBtn")
				:SetText(L["Sell All"])
				:SetScript("OnClick", private.SellAllBtnOnClick)
			)
		)
end

function private.QueryResetFiltersFunc(query)
	TSM.Vendoring.Sell.ResetBagsQuery(query)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.InputOnValueChanged(input)
	local nameFilter = input:GetValue()
	if nameFilter == private.filterText then
		return
	end
	private.filterText = nameFilter
	nameFilter = String.Escape(nameFilter)
	input:GetElement("__parent.__parent.__parent.items"):SetFilters(nameFilter ~= "" and nameFilter or nil)
end

function private.RowOnIgnoreItem(_, itemString, isPermanent)
	if isPermanent then
		TSM.Vendoring.Sell.IgnoreItemPermanent(itemString)
	else
		TSM.Vendoring.Sell.IgnoreItemSession(itemString)
	end
end

function private.RowOnSellItem(_, itemString)
	TSM.Vendoring.Sell.SellItem(itemString)
end

function private.SellTrashBtnOnClick(button)
	for _, row in private.query:Iterator() do
		local itemString, quality = row:GetFields("itemString", "quality")
		if quality == Enum.ItemQuality.Poor then
			TSM.Vendoring.Sell.SellItem(itemString)
		end
	end
end

function private.SellBOEBtnOnClick(button)
	-- Checking if an item is disenchantable might cause our query to change since it depends on the ItemInfo DB, so cache the list of items first
	local items = TempTable.Acquire()
	for _, row in private.query:Iterator() do
		tinsert(items, row:GetField("itemString"))
	end
	for _, itemString in ipairs(items) do
		if ItemInfo.IsDisenchantable(itemString) then
			TSM.Vendoring.Sell.SellItem(itemString)
		end
	end
	TempTable.Release(items)
end

function private.SellAllBtnOnClick(button)
	for _, row in private.query:Iterator() do
		TSM.Vendoring.Sell.SellItem(row:GetField("itemString"))
	end
end
