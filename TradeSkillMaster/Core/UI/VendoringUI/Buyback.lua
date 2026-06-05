-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Buyback = TSM.UI.VendoringUI:NewPackage("Buyback") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Buyback.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "vendoringUIContext", "buybackScrollingTable")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("sync", "internalData", "money")
	TSM.UI.VendoringUI.RegisterTopLevelPage(BUYBACK, private.GetFrame)
end



-- ============================================================================
-- Buy UI
-- ============================================================================

function private.GetFrame()
	UIUtils.AnalyticsRecordPathChange("vendoring", "buyback")
	return UIElements.New("Frame", "buy")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("VendorBuybackScrollTable", "items")
			:SetMargin(0, 0, -2, 0)
			:SetSettings(private.settings, "buybackScrollingTable")
			:SetQuery(TSM.Vendoring.Buyback.CreateQuery())
			:SetScript("OnBuyback", private.RowOnBuyback)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Frame", "gold")
				:SetLayout("HORIZONTAL")
				:SetWidth(166)
				:SetMargin(0, 8, 0, 0)
				:SetPadding(4)
				:AddChild(UIElements.New("PlayerGoldText", "text")
					:SetSettings(private.settings)
				)
			)
			:AddChild(UIElements.New("ActionButton", "buybackAllBtn")
				:SetText(L["Buyback All"])
				:SetScript("OnClick", private.BuybackAllBtnOnClick)
			)
		)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.RowOnBuyback(_, index)
	TSM.Vendoring.Buyback.BuybackItem(index)
end

function private.BuybackAllBtnOnClick(button)
	local query = TSM.Vendoring.Buyback.CreateQuery()
		:Select("index")
	for _, index in query:Iterator() do
		TSM.Vendoring.Buyback.BuybackItem(index)
	end
	query:Release()
end
