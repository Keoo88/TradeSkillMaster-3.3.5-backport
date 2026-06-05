-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Destroying = TSM.MainUI.Settings:NewPackage("Destroying") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
}
local ITEM_QUALITY_DESCS = { ITEM_QUALITY2_DESC, ITEM_QUALITY3_DESC, ITEM_QUALITY4_DESC }
local ITEM_QUALITY_KEYS = { 2, 3, 4 }
local SETTING_TOOLTIPS = {
	autoStack = L["Automtaically combine smaller stacks of herbs and ore as needed for milling and prospecting respectively."],
	autoShow = L["Automatically show the Destroying UI when you have something in your bags to destroy."],
	includeSoulbound = L["Include soulbound items in the list of items to disenchant."],
	deMaxQuanlity = L["The max quality of item which Destroying will list for disenchanting."],
	deAbovePrice = L["Destroying will only list items with a disenchant value above this price for disenchanting."],

}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Destroying.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "destroyingOptions", "autoStack")
		:AddKey("global", "destroyingOptions", "autoShow")
		:AddKey("global", "destroyingOptions", "includeSoulbound")
		:AddKey("global", "destroyingOptions", "deMaxQuality")
		:AddKey("global", "destroyingOptions", "deAbovePrice")
	TSM.MainUI.Settings.RegisterSettingPage(L["Destroying"], "middle", private.GetDestroyingSettingsFrame)
end



-- ============================================================================
-- Destroying Settings UI
-- ============================================================================

function private.GetDestroyingSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "destroying")
	return UIElements.New("ScrollFrame", "destroyingSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection(L["Destroying"], "general", L["General Options"], "")
			:AddChild(UIElements.New("Frame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "autoStackCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Enable automatic stack combination"])
					:SetSettingInfo(private.settings, "autoStack")
					:SetTooltip(SETTING_TOOLTIPS.autoStack)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "autoShowCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Show destroying frame automatically"])
					:SetSettingInfo(private.settings, "autoShow")
					:SetTooltip(SETTING_TOOLTIPS.autoShow)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "check3")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "includeSoulboundCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Include soulbound items"])
					:SetSettingInfo(private.settings, "includeSoulbound")
					:SetTooltip(SETTING_TOOLTIPS.includeSoulbound)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Destroying", "disenchanting", L["Disenchanting Options"], "")
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(18)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Maximum disenchant quality"])
			)
			:AddChild(UIElements.New("SelectionDropdown", "maxQualityDropDown")
				:SetHeight(26)
				:SetMargin(0, 0, 0, 12)
				:SetItems(ITEM_QUALITY_DESCS, ITEM_QUALITY_KEYS)
				:SetSettingInfo(private.settings, "deMaxQuality")
				:SetTooltip(SETTING_TOOLTIPS.deMaxQuanlity)
			)
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("deDisenchantPriceField", L["Only show items with disenchant values above this price"], private.settings, "deAbovePrice", nil, nil, SETTING_TOOLTIPS.deAbovePrice))
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Destroying", "ignore", L["Ignored Items"], L["Click on an item below to unignore it for destroying."])
			:AddChild(UIElements.New("SimpleItemList", "items")
				:SetHeight(136)
				:SetQuery(TSM.Destroying.CreateIgnoreQuery())
				:SetScript("OnItemClick", private.RemoveIgnoredItem)
			)
		)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.RemoveIgnoredItem(_, itemString)
	TSM.Destroying.ForgetIgnoreItemPermanent(itemString)
end
