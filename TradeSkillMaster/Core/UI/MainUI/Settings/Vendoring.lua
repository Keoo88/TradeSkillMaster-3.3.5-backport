-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Vendoring = TSM.MainUI.Settings:NewPackage("Vendoring") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
}
local SETTING_TOOLTIPS = {
	displayMoneyCollected = L["If enables, the total amount of money earned from selling items to the vendor will be displayed in chat."],
	qsMarketValue = L["How TSM determines the market value for the purpose of displaying in the 'Sell' tab of the Vendor UI."],
}


-- ============================================================================
-- Module Functions
-- ============================================================================

function Vendoring.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "vendoringOptions", "displayMoneyCollected")
		:AddKey("global", "vendoringOptions", "qsMarketValue")
	TSM.MainUI.Settings.RegisterSettingPage(L["Vendoring"], "middle", private.GetVendoringSettingsFrame)
end



-- ============================================================================
-- Vendoring Settings UI
-- ============================================================================

function private.GetVendoringSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "vendoring")
	return UIElements.New("ScrollFrame", "vendoringSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Vendoring", "general", L["General Options"], "")
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetSettingInfo(private.settings, "displayMoneyCollected")
					:SetText(L["Display total money received in chat"])
					:SetTooltip(SETTING_TOOLTIPS.displayMoneyCollected)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("qsMarketValueSourceField", L["Market Value Price Source"], private.settings, "qsMarketValue", nil, nil, SETTING_TOOLTIPS.qsMarketValue))
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Vendoring", "ignore", L["Ignored Items"], L["Click on an item below to unignore it for vendoring."])
			:AddChild(UIElements.New("SimpleItemList", "items")
				:SetHeight(326)
				:SetQuery(TSM.Vendoring.Sell.CreateIgnoreQuery())
				:SetScript("OnItemClick", private.RemoveIgnoredItem)
			)
		)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.RemoveIgnoredItem(_, itemString)
	TSM.Vendoring.Sell.ForgetIgnoreItemPermanent(itemString)
end
