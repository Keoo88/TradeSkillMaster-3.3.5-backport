-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local WhatsNew = TSM.UI:NewPackage("WhatsNew") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local Analytics = TSM.LibTSMUtil:Include("Util.Analytics")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local private = {
	settings = nil,
	showTime = nil,
}
local WHATS_NEW_VERSION = 5
local CONTENT_LINES = ClientInfo.IsRetail() and {
	Theme.GetColor("INDICATOR"):ColorText(L["New Sniper Mechanism"]).." "..L["In retail, Sniper works in a new way which makes it much faster and now supports the base group."],
	Theme.GetColor("INDICATOR"):ColorText(L["Alternate AuctionDB Realm Data"]).." "..L["You can configure an alternate realm to load AuctionDB data for to allow easy comparison between two realms in item tooltips."],
	Theme.GetColor("INDICATOR"):ColorText(L["Scroll Table Improvements"]).." "..L["TSM uses scroll tables through the addon to show large amounts of data. 4.14 includes significant performance improvements, dragging to reorder columns, adding price sources and custom sources as additional columns, and more."],
	Theme.GetColor("INDICATOR"):ColorText(L["Custom Strings in More Operations"]).." "..L["Mailing, Vendoring, and Warehousing operation settings now fully support using custom strings."],
	Theme.GetColor("INDICATOR"):ColorText(L["Import Item IDs from Wowhead"]).." "..L["When searching for items on Wowhead, you can copy the results as a list of item IDs. TSM now allows paste that list direclty into the group import dialog to make it easy to create TSM groups."],
} or {
	Theme.GetColor("INDICATOR"):ColorText(L["Scroll Table Improvements"]).." "..L["TSM uses scroll tables through the addon to show large amounts of data. 4.14 includes significant performance improvements, dragging to reorder columns, adding price sources and custom sources as additional columns, and more."],
	Theme.GetColor("INDICATOR"):ColorText(L["Custom Strings in More Operations"]).." "..L["Mailing, Vendoring, and Warehousing operation settings now fully support using custom strings."],
	Theme.GetColor("INDICATOR"):ColorText(L["Import Item IDs from Wowhead"]).." "..L["When searching for items on Wowhead, you can copy the results as a list of item IDs. TSM now allows paste that list direclty into the group import dialog to make it easy to create TSM groups."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function WhatsNew.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "internalData", "whatsNewVersion")
end

function WhatsNew.GetDialog()
	if private.settings.whatsNewVersion == WHATS_NEW_VERSION then
		return
	end
	private.showTime = GetTime()
	return UIElements.New("Frame", "whatsNew")
		:SetLayout("VERTICAL")
		:SetSize(650, 500)
		:SetPadding(12, 12, 0, 12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("FRAME_BG")
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(0, 0, 8, 16)
			:AddChild(UIElements.New("Spacer", "spacer")
				:SetWidth(20)
			)
			:AddChild(UIElements.New("Text", "title")
				:SetJustifyH("CENTER")
				:SetFont("BODY_BODY1_BOLD")
				:SetFormattedText(L["TSM %s: What's new"], "4.14")
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetMargin(0, -4, 0, 0)
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetScript("OnClick", private.DialogCloseBtnOnClick)
			)
		)
		:AddChild(UIElements.New("ScrollFrame", "body")
			:AddChild(UIElements.New("Text", "content1")
				:SetHeight(400)
				:SetFont("BODY_BODY2")
				:SetText(table.concat(CONTENT_LINES, "\n\n"))
			)
		)
		:AddChild(UIElements.New("Text", "footer1")
			:SetHeight(20)
			:SetMargin(0, 0, 12, 0)
			:SetFont("BODY_BODY3")
			:SetFormattedText(L["For more info, visit %s. For help, join us in Discord: %s."], Theme.GetColor("INDICATOR_ALT"):ColorText("blog.tradeskillmaster.com"), Theme.GetColor("INDICATOR_ALT"):ColorText("discord.gg/woweconomy"))
		)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DialogCloseBtnOnClick(button)
	private.settings.whatsNewVersion = WHATS_NEW_VERSION
	button:GetBaseElement():HideDialog()
	Analytics.Action("WHATS_NEW_TIME", floor((GetTime() - private.showTime) * 1000), WHATS_NEW_VERSION)
end
