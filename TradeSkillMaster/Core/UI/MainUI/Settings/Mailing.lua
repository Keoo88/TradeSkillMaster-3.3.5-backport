-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Mailing = TSM.MainUI.Settings:NewPackage("Mailing") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
}
local ITEM_QUALITY_DESCS = { ITEM_QUALITY2_DESC, ITEM_QUALITY3_DESC, ITEM_QUALITY4_DESC }
local ITEM_QUALITY_KEYS = { 2, 3, 4 }
local SETTING_TOOLTIP = {
	inboxMessages = L["If enabled, TSM will add chat messages describing mail being opened."],
	keepMailSpace = L["TSM will stop automatically opening mail as needed in order keep this number of slots empty in your bags."],
	openMailSound = L["The sound to play when mail has finished automatically opening."],
	sendMessages = L["If enabled, TSM will add chat messages describing mail being sent."],
	sendItemsIndividually = L["Setting this will result in different items being sent in separate mails rather than mixing them within the same mail when sending with Mailing operations."],
	resendDelay = L["How long in minutes to wait between automatically attempting to re-send items according to your Mailing operations."],
	deMaxQuality = L["The max quality of item to send when mailing disenchantables in the 'Other' tab."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Mailing.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mailingOptions", "inboxMessages")
		:AddKey("global", "mailingOptions", "keepMailSpace")
		:AddKey("global", "mailingOptions", "openMailSound")
		:AddKey("global", "mailingOptions", "sendMessages")
		:AddKey("global", "mailingOptions", "sendItemsIndividually")
		:AddKey("global", "mailingOptions", "resendDelay")
		:AddKey("global", "mailingOptions", "deMaxQuality")
	TSM.MainUI.Settings.RegisterSettingPage(L["Mailing"], "middle", private.GetMailingSettingsFrame)
end



-- ============================================================================
-- Mailing Settings UI
-- ============================================================================

function private.GetMailingSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "mailing")
	return UIElements.New("ScrollFrame", "mailingSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Mailing", "inbox", L["Inbox Settings"], "")
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "inboxMessagesCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Enable inbox chat messages"])
					:SetSettingInfo(private.settings, "inboxMessages")
					:SetTooltip(SETTING_TOOLTIP.inboxMessages)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(18)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Amount of bag space to keep free"])
			)
			:AddChild(UIElements.New("Frame", "freeSpaceFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("Input", "keepMailInput")
					:SetMargin(0, 8, 0, 0)
					:SetBackgroundColor("ACTIVE_BG")
					:SetValidateFunc("NUMBER", "0:20")
					:SetSettingInfo(private.settings, "keepMailSpace")
					:SetTooltip(SETTING_TOOLTIP.keepMailSpace, "__parent")
				)
				:AddChild(UIElements.New("Text", "label")
					:SetSize("AUTO", 16)
					:SetFont("BODY_BODY3")
					:SetText(L["Min 0 - Max 20"])
				)
			)
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(18)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Open mail complete sound"])
			)
			:AddChild(UIElements.New("SoundDropdown", "mailSoundDropdown")
				:SetHeight(24)
				:SetSettingInfo(private.settings, "openMailSound")
				:SetTooltip(SETTING_TOOLTIP.openMailSound)
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Mailing", "send", L["Sending Settings"], "")
			:AddChild(UIElements.New("Frame", "check1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "sendMessagesCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Enable sending chat messages"])
					:SetSettingInfo(private.settings, "sendMessages")
					:SetTooltip(SETTING_TOOLTIP.sendMessages)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "check2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 22)
				:AddChild(UIElements.New("Checkbox", "sendItemsCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Send grouped items individually"])
					:SetSettingInfo(private.settings, "sendItemsIndividually")
					:SetTooltip(SETTING_TOOLTIP.sendItemsIndividually)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Restart delay (minutes)"])
			)
			:AddChild(UIElements.New("Frame", "restartDelayFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Input", "restartDelay")
					:SetMargin(0, 8, 0, 0)
					:SetBackgroundColor("ACTIVE_BG")
					:SetValidateFunc("NUMBER", "0.5:10")
					:SetValue(private.settings.resendDelay)
					:SetScript("OnValueChanged", private.RestartDelayOnValueChanged)
					:SetTooltip(SETTING_TOOLTIP.resendDelay, "__parent")
				)
				:AddChild(UIElements.New("Text", "label")
					:SetSize("AUTO", 16)
					:SetFont("BODY_BODY3")
					:SetText(L["Min 0.5 - Max 10"])
				)
			)
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Mail disenchantables max quality"])
			)
			:AddChild(UIElements.New("SelectionDropdown", "mailPageDropdown")
				:SetHeight(26)
				:SetItems(ITEM_QUALITY_DESCS, ITEM_QUALITY_KEYS)
				:SetSettingInfo(private.settings, "deMaxQuality")
				:SetTooltip(SETTING_TOOLTIP.deMaxQuality)
			)
		)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.RestartDelayOnValueChanged(input)
	local value = Math.Round(tonumber(input:GetValue()), 0.5)
	private.settings.resendDelay = value
end
