-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Inbox = TSM.UI.MailingUI:NewPackage("Inbox") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local SoundAlert = TSM.LibTSMWoW:Include("UI.SoundAlert")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local Database = TSM.LibTSMUtil:Include("Database")
local FSM = TSM.LibTSMUtil:Include("FSM")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local Mail = TSM.LibTSMService:Include("Mail")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local InboxAPI = TSM.LibTSMWoW:Include("API.Inbox")
local private = {
	settings = nil,
	fsm = nil,
	frame = nil,
	view = nil,
	inboxQuery = nil, ---@type DatabaseQuery
	inboxQueryCancellable = nil,
	itemsQuery = nil,
	selectedMail = nil,
	nextUpdate = nil,
	filterText = "",
	updateCounterTimer = nil,
}
local PLAYER_NAME = UnitName("player")
local MAIL_REFRESH_TIME = ClientInfo.IsRetail() and 15 or 60



-- ============================================================================
-- Module Functions
-- ============================================================================

function Inbox.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mailingUIContext", "mailsScrollingTable")
		:AddKey("global", "mailingOptions", "openMailSound")
	private.updateCounterTimer = DelayTimer.New("INBOX_UPDATE_COUNTER", private.UpdateCountDown)
	private.FSMCreate()
	TSM.UI.MailingUI.RegisterTopLevelPage(INBOX, private.GetInboxFrame)
	-- 3.3.5: fallback подписка на конец mail-скана через прямой callback
	Mail.RegisterMailCallback(private.InboxOnMailScanComplete)
end

function Inbox.IsMailOpened()
	if not private.view or not private.view:HasChildById("view") then
		return
	end

	return private.view:GetElement("view"):GetPath() == "items"
end



-- ============================================================================
-- Inbox UI
-- ============================================================================

function private.GetInboxFrame()
	UIUtils.AnalyticsRecordPathChange("mailing", "inbox")
	local frame = UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("ViewContainer", "view")
			:SetNavCallback(private.GetViewContentFrame)
			:AddPath("mails", true)
			:AddPath("items")
		)

	private.view = frame

	return frame
end

function private.GetViewContentFrame(viewContainer, path)
	if path == "mails" then
		private.selectedMail = nil
		return private.GetInboxMailsFrame()
	elseif path == "items" then
		return private.GetInboxItemsFrame()
	else
		error("Unexpected path: "..tostring(path))
	end
end

function private.GetInboxMailsFrame()
	if not private.inboxQuery then
		private.inboxQuery = TSM.Mailing.Inbox.CreateQuery()
			:OrderBy("index", true)
	end
	private.filterText = ""
	assert(not private.inboxQueryCancellable)
	private.inboxQueryCancellable = private.inboxQuery:Publisher()
		:CallFunction(private.InboxOnDataUpdated)
		:Stored()

	local frame = UIElements.New("Frame", "inbox")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "top")
			:SetLayout("HORIZONTAL")
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Input", "filterInput")
				:SetHeight(24)
				:SetMargin(0, 8, 0, 0)
				:AllowItemInsert()
				:SetIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:SetHintText(L["Search items in mailbox"])
				:SetDisabled(false)
				:SetScript("OnValueChanged", private.SearchOnValueChanged)
			)
			:AddChild(UIElements.New("ActionButton", "reload")
				:SetSize(110, 24)
				:SetFormattedText(L["Reload UI (%d)"], MAIL_REFRESH_TIME)
				:SetScript("OnClick", ReloadUI)
			)
		)
		:AddChild(UIElements.New("MailsScrollTable", "mails")
			:SetSettings(private.settings, "mailsScrollingTable")
			:SetQuery(private.inboxQuery)
			:SetFilters(private.filterText ~= "" and private.filterText or nil)
			:SetScript("OnRowClick", private.MailsOnRowClick)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(26)
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("Text", "mailNum")
				:SetWidth(200)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("RIGHT")
			)
			:AddChild(UIElements.New("Texture", "vline")
				:SetWidth(1)
				:SetMargin(8, 8, 3, 3)
				:SetColor("ACTIVE_BG_ALT")
			)
			:AddChild(UIElements.New("Text", "itemNum")
				:SetWidth(130)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("RIGHT")
				:SetText(format(L["%s Items Total"], Theme.GetColor("FEEDBACK_GREEN"):ColorText(0)))
			)
			:AddChild(UIElements.New("Texture", "vline")
				:SetWidth(1)
				:SetMargin(8, 8, 3, 3)
				:SetColor("ACTIVE_BG_ALT")
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetWidth(190)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "totalText")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetJustifyH("RIGHT")
					:SetText(L["Total Gold"]..": ")
				)
				:AddChild(UIElements.New("Text", "gold")
					:SetWidth("AUTO")
					:SetMargin(0, 8, 0, 0)
					:SetFont("TABLE_TABLE1")
					:SetJustifyH("RIGHT")
					:SetText(Money.ToStringForUI(0))
				)
			)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
	if ClientInfo.IsRetail() then
		frame:AddChild(UIElements.New("Frame", "bottom")
			:SetLayout("VERTICAL")
			:SetHeight(74)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "openAllMail")
				:SetHeight(26)
				:SetText(L["Open All Mail"])
				:SetScript("OnClick", private.OpenBtnOnClick)
				:SetModifierText(L["Open Mail"], "SHIFT")
				:SetModifierText(L["Open All Mail Without Money"], "CTRL")
				:SetModifierText(L["Open Mail Without Money"], "SHIFT", "CTRL")
				:SetTooltip(L["Hold SHIFT to not continue after the inbox refreshes and CTRL to not open mail with money attached."])
			)
			:AddChild(UIElements.New("Frame", "buttons")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 8, 0)
				:AddChild(UIElements.New("ActionButton", "openAllSales")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["All Sold"])
					:SetContext(InboxAPI.MAIL_TYPE.SALE)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["Sold"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to not continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllBuys")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["All Bought"])
					:SetContext(InboxAPI.MAIL_TYPE.BUY)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["Bought"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to not continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllCancels")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["All Cancelled"])
					:SetContext(InboxAPI.MAIL_TYPE.CANCEL)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["Cancelled"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to not continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllExpires")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["All Expired"])
					:SetContext(InboxAPI.MAIL_TYPE.EXPIRE)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["Expired"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to not continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllOthers")
					:SetFont("BODY_BODY2")
					:SetText(L["All Other"])
					:SetContext(InboxAPI.MAIL_TYPE.OTHER)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["Other"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to not continue after the inbox refreshes"])
				)
			)
		)
	else
		frame:AddChild(UIElements.New("Frame", "bottom")
			:SetLayout("VERTICAL")
			:SetHeight(74)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "openAllMail")
				:SetHeight(26)
				:SetText(L["Open Mail"])
				:SetScript("OnClick", private.OpenBtnOnClick)
				:SetModifierText(L["Open All Mail"], "SHIFT")
				:SetModifierText(L["Open Mail Without Money"], "CTRL")
				:SetModifierText(L["Open All Mail Without Money"], "SHIFT", "CTRL")
				:SetTooltip(L["Hold SHIFT to continue after the inbox refreshes and CTRL to not open mail with money attached."])
			)
			:AddChild(UIElements.New("Frame", "buttons")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 8, 0)
				:AddChild(UIElements.New("ActionButton", "openAllSales")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["Sold"])
					:SetContext(InboxAPI.MAIL_TYPE.SALE)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["All Sold"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllBuys")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["Bought"])
					:SetContext(InboxAPI.MAIL_TYPE.BUY)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["All Bought"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllCancels")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["Cancelled"])
					:SetContext(InboxAPI.MAIL_TYPE.CANCEL)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["All Cancelled"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllExpires")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2")
					:SetText(L["Expired"])
					:SetContext(InboxAPI.MAIL_TYPE.EXPIRE)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["All Expired"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to continue after the inbox refreshes"])
				)
				:AddChild(UIElements.New("ActionButton", "openAllOthers")
					:SetFont("BODY_BODY2")
					:SetText(L["Other"])
					:SetContext(InboxAPI.MAIL_TYPE.OTHER)
					:SetScript("OnClick", private.OpenBtnOnClick)
					:SetModifierText(L["All Other"], "SHIFT")
					:SetTooltip(L["Hold SHIFT to continue after the inbox refreshes"])
				)
			)
		)
	end
	frame:SetScript("OnUpdate", private.InboxFrameOnUpdate)
	frame:SetScript("OnHide", private.InboxFrameOnHide)
	frame:SetScript("OnShow", private.InboxFrameOnShow)

	private.frameWasShown = false
	private.frame = frame

	return frame
end

function private.GetInboxItemsFrame()
	if not private.itemsQuery then
		private.itemsQuery = Mail.NewItemQuery()
			:OrderBy("itemIndex", true)
			:Equal("index", Database.BoundQueryParam())
	end
	private.itemsQuery:BindParams(private.selectedMail)

	local _, isTakeable = InboxAPI.GetText(private.selectedMail)
	local _, _, _, _, _, _, textCreated = InboxAPI.GetHeaderInfo(private.selectedMail)
	local frame = UIElements.New("Frame", "items")
		:SetLayout("VERTICAL")
		:AddChild(UIElements.New("Frame", "content")
			:SetLayout("VERTICAL")
			:SetBackgroundColor("PRIMARY_BG")
			:AddChild(UIElements.New("Frame", "top")
				:SetLayout("HORIZONTAL")
				:SetHeight(40)
				:SetPadding(8)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("Frame", "back")
					:SetLayout("VERTICAL")
					:SetWidth(100)
					:AddChild(UIElements.New("ActionButton", "button")
						:SetWidth(64)
						:SetMargin(0, 36, 0, 0)
						:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey("iconPack.14x14/Chevron/Right"))..BACK)
						:SetScript("OnClick", private.ViewBackButtonOnClick)
					)
				)
				:AddChild(UIElements.New("Text", "title")
					:SetFont("BODY_BODY1_BOLD")
					:SetJustifyH("CENTER")
					:SetText(L["Open Mail"])
				)
				:AddChild(UIElements.New("Frame", "copy")
					:SetLayout("VERTICAL")
					:SetWidth(100)
					:AddChild(UIElements.New("Button", "button")
						:SetFont("BODY_BODY2_MEDIUM")
						:SetIcon("iconPack.14x14/Duplicate", "LEFT")
						:SetText(L["Copy Letter"])
						:SetDisabled(not isTakeable or textCreated)
						:SetScript("OnClick", private.CopyLetterButtonOnClick)
					)
				)
			)
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("VERTICAL")
				:SetPadding(12, 12, 4, 6)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("Frame", "top")
					:SetLayout("VERTICAL")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 6)
					:AddChild(UIElements.New("Frame", "left")
						:SetLayout("HORIZONTAL")
						:AddChild(UIElements.New("Text", "label")
							:SetWidth("AUTO")
							:SetFont("BODY_BODY2_MEDIUM")
							:SetText(L["From"]..": ")
						)
						:AddChild(UIElements.New("Text", "sender")
							:SetFont("BODY_BODY2")
						)
						:AddChild(UIElements.New("Spacer", "spacer"))
						:AddChild(UIElements.New("ActionButton", "report")
							:SetSize(124, 20)
							:SetFont("BODY_BODY2_MEDIUM")
							:SetText(L["Report Spam"])
							:SetScript("OnClick", private.ReportSpamOnClick)
						)
					)
				)
				:AddChild(UIElements.New("Frame", "bottom")
					:SetLayout("VERTICAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Frame", "left")
						:SetLayout("HORIZONTAL")
						:AddChild(UIElements.New("Text", "label")
							:SetWidth("AUTO")
							:SetFont("BODY_BODY2_MEDIUM")
							:SetText(L["Subject"]..": ")
						)
						:AddChild(UIElements.New("Text", "subject")
							:SetFont("BODY_BODY2")
						)
					)
				)
			)
			:AddChild(UIElements.New("HorizontalLine", "line"))
			:AddChild(UIElements.New("Frame", "body")
				:SetLayout("VERTICAL")
				:SetPadding(4, 4, 8, 12)
				:AddChild(UIElements.New("MultiLineInput", "input")
					:SetBackgroundColor("PRIMARY_BG")
					:SetFont("BODY_BODY2")
					:SetValue("")
				)
			)
			:AddChild(UIElements.New("Frame", "attachments")
				:SetLayout("VERTICAL")
				:SetHeight(144)
				:SetPadding(12, 12, 0, 8)
				:SetBackgroundColor("PRIMARY_BG")
				:AddChild(UIElements.New("Frame", "header")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Text", "text")
						:SetWidth("AUTO")
						:SetFont("BODY_BODY2_MEDIUM")
						:SetText(L["Attachments"])
					)
					:AddChild(UIElements.New("Button", "takeAll")
						:SetWidth("AUTO")
						:SetMargin(8, 0, 0, 0)
						:SetFont("BODY_BODY3")
						:SetTextColor("INDICATOR")
						:SetText(L["Move all to Bags"])
						:SetScript("OnClick", private.TakeAllOnClick)
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "cod")
						:SetMargin(0, 5, 0, 0)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetJustifyH("RIGHT")
						:SetText(L["COD"]..":")
					)
					:AddChild(UIElements.New("Text", "codAmount")
						:SetWidth("AUTO")
						:SetMargin(0, 8, 0, 0)
						:SetFont("ITEM_BODY2")
						:SetJustifyH("RIGHT")
					)
				)
				:AddChild(UIElements.New("MailItemsList", "items")
					:SetQuery(private.itemsQuery)
					:SetScript("OnItemClick", private.ItemsHandleItemClick)
				)
			)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(42)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "reply")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Reply"])
				:SetScript("OnClick", private.ReplyOnClick)
			)
			:AddChild(UIElements.New("ActionButton", "return/send")
				:SetWidth(144)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(MAIL_RETURN)
				:SetScript("OnClick", private.DeleteMailOnClick)
			)
		)

	private.UpdateInboxItemsFrame(frame)

	return frame
end

function private.ViewBackButtonOnClick(button)
	private.filterText = ""
	button:GetElement("__parent.__parent.__parent.__parent.__parent"):SetPath("mails", true)
end

function private.CopyLetterButtonOnClick(button)
	TakeInboxTextItem(private.selectedMail)
	button:SetDisabled(true)
		:Draw()
end

function private.ItemsHandleItemClick(list, index, itemIndex)
	local _, _, cod = InboxAPI.GetHeaderInfo(index)
	if cod > 0 then
		list:GetBaseElement():ShowConfirmationDialog(L["Accept COD?"], format(L["Accepting this item will cost: %s"], Money.ToStringExact(cod)), private.TakeInboxItem, list, index, itemIndex)
	else
		private.TakeInboxItem(list, index, itemIndex)
	end
end

function private.TakeInboxItem(list, index, itemIndex)
	if private.itemsQuery:Count() == 1 then
		if itemIndex == 0 then
			TakeInboxMoney(index)
		else
			TakeInboxItem(index, itemIndex)
		end
		list:GetElement("__parent.__parent.__parent.__parent"):SetPath("mails", true)
	else
		if itemIndex == 0 then
			TakeInboxMoney(index)
		else
			TakeInboxItem(index, itemIndex)
		end
	end
end

function private.ReportSpamOnClick(button)
	if not CanComplainInboxItem(private.selectedMail) then
		return
	end
	local sender = InboxAPI.GetHeaderInfo(private.selectedMail)
	local dialog = StaticPopup_Show("CONFIRM_REPORT_SPAM_MAIL", sender)
	if dialog then
		dialog.data = private.selectedMail
	end
end

function private.TakeAllOnClick(button)
	local _, _, cod = InboxAPI.GetHeaderInfo(private.selectedMail)
	if cod > 0 then
		button:GetBaseElement():ShowConfirmationDialog(L["Accept COD?"], format(L["Accepting this item will cost: %s"], Money.ToStringExact(cod)), private.AutoLootMailItem, button)
	else
		private.AutoLootMailItem(button)
	end
end

function private.AutoLootMailItem(button)
	-- Marks the mail as read
	InboxAPI.GetText(private.selectedMail)
	AutoLootMailItem(private.selectedMail)
	button:GetElement("__parent.__parent.__parent.__parent.__parent"):SetPath("mails", true)
end

function private.ReplyOnClick(button)
	local sender = InboxAPI.GetHeaderInfo(private.selectedMail)
	TSM.UI.MailingUI.Send.SetSendRecipient(sender)
	TSM.UI.MailingUI.SetSelectedTab(L["Send"], true)
end

function private.DeleteMailOnClick(button)
	local _, money, _, itemCount = InboxAPI.GetHeaderInfo(private.selectedMail)
	if InboxItemCanDelete(private.selectedMail) then
		if itemCount and itemCount > 0 then
			return
		elseif money and money > 0 then
			return
		else
			DeleteInboxItem(private.selectedMail)
		end
	else
		ReturnInboxItem(private.selectedMail)
	end
	button:GetElement("__parent.__parent.__parent"):SetPath("mails", true)
end

function private.UpdateInboxItemsFrame(frame)
	local sender, money, cod, itemCount, subject, _, _, isGM, canReply = InboxAPI.GetHeaderInfo(private.selectedMail)
	frame:GetElement("content.header.top.left.sender"):SetText(sender or UNKNOWN)
	frame:GetElement("content.header.bottom.left.subject"):SetText(subject)

	if isGM then
		frame:GetElement("content.header.top.left.sender"):SetTextColor("BLIZZARD_GM")
			:Draw()
	else
		frame:GetElement("content.header.top.left.sender"):SetTextColor("TEXT_ALT")
			:Draw()
	end

	if CanComplainInboxItem(private.selectedMail) then
		frame:GetElement("content.header.top.left.report"):Show()
	else
		frame:GetElement("content.header.top.left.report"):Hide()
	end

	if cod and cod > 0 then
		frame:GetElement("content.attachments.header.cod"):Show()
		frame:GetElement("content.attachments.header.codAmount"):SetText(Money.ToStringExact(cod, Theme.GetColor("FEEDBACK_RED"):GetTextColorPrefix()))
		frame:GetElement("content.attachments.header.codAmount"):Show()
	else
		frame:GetElement("content.attachments.header.cod"):Hide()
		frame:GetElement("content.attachments.header.codAmount"):Hide()
	end

	if itemCount and itemCount > 0 then
		frame:GetElement("content.attachments.header.takeAll"):Show()
	else
		frame:GetElement("content.attachments.header.takeAll"):Hide()
	end

	if not sender or not canReply or sender == PLAYER_NAME then
		frame:GetElement("footer.reply"):SetDisabled(true)
	else
		frame:GetElement("footer.reply"):SetDisabled(false)
	end

	if InboxItemCanDelete(private.selectedMail) then
		frame:GetElement("footer.return/send"):SetText(DELETE)
		if (itemCount and itemCount > 0) or (money and money > 0) then
			frame:GetElement("footer.return/send"):SetDisabled(true)
		else
			frame:GetElement("footer.return/send"):SetDisabled(false)
		end
	else
		frame:GetElement("footer.return/send"):SetText(MAIL_RETURN)
		frame:GetElement("footer.return/send"):SetDisabled(false)
	end

	local body = nil
	local mailType = InboxAPI.GetMailType(private.selectedMail)
	if mailType == InboxAPI.MAIL_TYPE.BUY.AUCTION then
		local itemName, playerName, bid, buyout = InboxAPI.GetInvoiceInfo(private.selectedMail)
		playerName = playerName or AUCTION_HOUSE_MAIL_MULTIPLE_SELLERS
		local purchaseType = bid == buyout and BUYOUT or HIGH_BIDDER
		body = strjoin(
			"\n",
			ITEM_PURCHASED_COLON.." "..itemName,
			SOLD_BY_COLON.." "..playerName.." ("..purchaseType..")",
			"",
			AMOUNT_PAID_COLON.." "..Money.ToStringExact(bid)
		)
	elseif mailType == InboxAPI.MAIL_TYPE.SALE.AUCTION then
		local itemName, playerName, bid, buyout, deposit, consignment = InboxAPI.GetInvoiceInfo(private.selectedMail)
		playerName = playerName or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS
		local purchaseType = bid == buyout and BUYOUT or HIGH_BIDDER
		body = strjoin(
			"\n",
			ITEM_SOLD_COLON.." "..itemName,
			PURCHASED_BY_COLON.." "..playerName.." ("..purchaseType..")",
			"",
			L["Sale Price"]..": "..Money.ToStringExact(bid),
			L["Deposit"]..": +"..Money.ToStringExact(deposit),
			L["Auction House Cut"]..": -"..Money.ToStringExact(consignment, Theme.GetColor("FEEDBACK_RED"):GetTextColorPrefix()),
			"",
			AMOUNT_RECEIVED_COLON.." "..Money.ToStringExact(bid + deposit - consignment)
		)
	elseif mailType == InboxAPI.MAIL_TYPE.OTHER.TEMP_INVOICE then
		local itemName, playerName, bid, buyout, deposit, consignment, etaHour, etaMin = InboxAPI.GetInvoiceInfo(private.selectedMail)
		playerName = playerName or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS
		local purchaseType = bid == buyout and BUYOUT or HIGH_BIDDER
		body = strjoin(
			"\n",
			ITEM_SOLD_COLON.." "..itemName,
			PURCHASED_BY_COLON.." "..playerName.." ("..purchaseType..")",
			"",
			AUCTION_INVOICE_PENDING_FUNDS_COLON.." "..Money.ToStringExact(bid + deposit - consignment),
			L["Estimated deliver time"]..": "..GameTime_GetFormattedTime(etaHour, etaMin, true)
		)
	elseif mailType == InboxAPI.MAIL_TYPE.BUY.CRAFTING_ORDER then
		local _, commission, crafter, recipeName = InboxAPI.GetCraftingOrderInfo(private.selectedMail)
		body = strjoin(
			"\n",
			format(CRAFTING_ORDER_MAIL_ORDER_HEADER, recipeName),
			format(CRAFTING_ORDER_MAIL_FULFILLED_BY, crafter),
			"",
			CRAFTING_ORDER_MAIL_COMMISSION_PAID.." "..Money.ToStringExact(commission)
		)
	elseif mailType == InboxAPI.MAIL_TYPE.SALE.CRAFTING_ORDER then
		local _, commission, customer, recipeName = InboxAPI.GetCraftingOrderInfo(private.selectedMail)
		body = strjoin(
			"\n",
			format(CRAFTING_ORDER_MAIL_ORDER_HEADER, recipeName),
			format(CRAFTING_ORDER_MAIL_FULFILLED_TO, customer),
			"",
			CRAFTING_ORDER_COMMISSION_ENCLOSED.." "..Money.ToStringExact(commission)
		)
	elseif mailType == InboxAPI.MAIL_TYPE.CANCEL.CRAFTING_ORDER then
		body = CRAFTING_ORDER_MAIL_CANCELED_BODY
	elseif mailType == InboxAPI.MAIL_TYPE.EXPIRE.CRAFTING_ORDER then
		body = CRAFTING_ORDER_MAIL_EXPIRED_BODY
	else
		body = InboxAPI.GetText(private.selectedMail)
	end
	frame:GetElement("content.body.input")
		:SetValue(body or "")
		:Draw()

	if not body then
		frame:GetElement("content.body.input"):Hide()
		frame:GetElement("content.attachments.header.text"):SetText(L["Attachments"])
		frame:GetElement("content.attachments")
			:SetHeight(nil)
			:Draw()
	elseif private.itemsQuery:Count() == 0 then
		frame:GetElement("content.body.input"):Show()
		frame:GetElement("content.attachments.header.text"):SetText(L["No Attachments"])
		frame:GetElement("content.attachments")
			:SetHeight(48)
			:Draw()
	else
		frame:GetElement("content.body.input"):Show()
		frame:GetElement("content.attachments.header.text"):SetText(L["Attachments"])
		frame:GetElement("content.attachments")
			:SetHeight(144)
			:Draw()
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.InboxFrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.UpdateCountDown(true)
	private.updateCounterTimer:RunForTime(0)
	private.fsm:ProcessEvent("EV_FRAME_SHOW", frame, private.filterText)
end

function private.InboxFrameOnHide(frame)
	if frame ~= private.frame then return end
	-- 3.3.5: WoW Frame создаётся hidden по умолчанию, SetScript("OnHide") ловит
	-- initial hide. Игнорируем пока ни разу не было реального OnShow.
	if not private.frameWasShown then
		return
	end
	private.frame = nil
	private.frameWasShown = false
	if private.inboxQueryCancellable then
		private.inboxQueryCancellable:Cancel()
		private.inboxQueryCancellable = nil
	end

	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end

function private.InboxFrameOnShow(frame)
	private.frameWasShown = true
end

function private.InboxOnDataUpdated()
	if not private.frame then
		return
	end
	private.fsm:ProcessEvent("EV_MAIL_DATA_UPDATED", private.filterText)
end

-- 3.3.5: Query publisher через :CallFunction иногда не пересрабатывает после
-- BulkInsertEnd на mailDB. Подписываемся напрямую на Mail Scanner callback —
-- он гарантированно вызывается в конце каждого скана. FSM сам пропустит
-- EV_MAIL_DATA_UPDATED если не в ST_SHOWN.
function private.InboxOnMailScanComplete()
	private.fsm:ProcessEvent("EV_MAIL_DATA_UPDATED", private.filterText or "")
end

function private.OpenBtnOnClick(button)
	local filterType = button:GetContext()
	button:SetPressed(true)
	local openAll = nil
	if ClientInfo.IsRetail() then
		openAll = not IsShiftKeyDown()
	else
		openAll = IsShiftKeyDown()
	end
	private.fsm:ProcessEvent("EV_BUTTON_CLICKED", openAll, not filterType and IsControlKeyDown(), private.filterText, filterType)
end

function private.MailsOnRowClick(scrollTable, index)
	if IsShiftKeyDown() then
		local _, _, cod = InboxAPI.GetHeaderInfo(index)
		if cod <= 0 then
			-- Marks the mail as read
			InboxAPI.GetText(index)
			AutoLootMailItem(index)
		end
	else
		TSM.Mailing.Open.KillThread()
		private.selectedMail = index
		scrollTable:GetElement("__parent.__parent"):SetPath("items", true)
	end
end

function private.SearchOnValueChanged(input)
	local text = input:GetValue() or ""
	if text == private.filterText then
		return
	end
	private.filterText = text
	input:GetElement("__parent.__parent.mails"):SetFilters(text ~= "" and text or nil)
	private.fsm:ProcessEvent("EV_MAIL_DATA_UPDATED", private.filterText)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateCountDown(force)
	if not force then
		private.updateCounterTimer:RunForTime(1)
	end
	if not private.frame then
		return
	end

	local nextUpdate = MAIL_REFRESH_TIME - (time() - TSM.Mailing.Open.GetLastCheckTime())
	if nextUpdate <= 0 then
		nextUpdate = MAIL_REFRESH_TIME
	end

	if nextUpdate ~= private.nextUpdate or force then
		private.frame:GetElement("top.reload"):SetFormattedText(L["Reload UI (%02d)"], Math.Round(nextUpdate))
			:Draw()
		private.nextUpdate = nextUpdate
	end
end



-- ============================================================================
-- FSM
-- ============================================================================

function private.FSMCreate()
	local fsmContext = {
		frame = nil,
		opening = false
	}

	Event.Register("PLAYER_REPORT_SUBMITTED", function()
		if not private.view or not private.view:HasChildById("view") then
			return
		end
		private.view:GetElement("view"):SetPath("mails", true)
	end)

	local function UpdateText(context, filterText)
		-- 3.3.5: callback может прилететь когда frame ещё не достроен (нет footer/top),
		-- или когда показан подэкран открытого письма ("items") — у него тоже есть
		-- "footer", но без mailNum/itemNum. Проверяем наличие конкретного потомка.
		if not context.frame or not context.frame:HasChildById("footer") or not context.frame:GetElement("footer"):HasChildById("mailNum") then
			return
		end
		local text = nil
		local numMail, totalMail = InboxAPI.GetNumItems()
		if filterText == "" then
			if totalMail > numMail then
				text = L["Showing %s of %d Mails"]
			elseif (numMail == 0 and totalMail == 0) or (numMail == 1 and totalMail == 1) then
				text = L["Showing %s Mail"]
			else
				text = L["Showing all %s Mails"]
			end
		else
			numMail = private.inboxQuery:Count()
			if (numMail == 0 and totalMail == 0) or (numMail == 1 and totalMail == 1) then
				text = L["Showing %s of %d Mail"]
			else
				text = L["Showing %s of %d Mails"]
			end
		end

		local totalItems, totalGold = 0, 0
		for _, row in private.inboxQuery:Iterator() do
			totalItems = totalItems + row:GetField("itemCount")
			totalGold = totalGold + row:GetField("money")
		end

		context.frame:GetElement("footer.mailNum")
			:SetText(format(text, Theme.GetColor("FEEDBACK_GREEN"):ColorText(tostring(numMail)), totalMail))
			:Draw()
		context.frame:GetElement("footer.itemNum")
			:SetText(format(L["%s Items Total"], Theme.GetColor("FEEDBACK_GREEN"):ColorText(totalItems)))
		context.frame:GetElement("footer.content.gold")
			:SetText(Money.ToStringForUI(totalGold))

		context.frame:GetElement("footer")
			:Draw()
	end

	local function UpdateButtons(context)
		if not context.frame or not context.frame:HasChildById("top") then
			return
		end

		if context.opening then
			context.frame:GetElement("bottom.openAllMail")
				:SetDisabled(true)
			context.frame:GetElement("bottom.buttons.openAllSales")
				:SetDisabled(true)
			context.frame:GetElement("bottom.buttons.openAllBuys")
				:SetDisabled(true)
			context.frame:GetElement("bottom.buttons.openAllCancels")
				:SetDisabled(true)
			context.frame:GetElement("bottom.buttons.openAllExpires")
				:SetDisabled(true)
			context.frame:GetElement("bottom.buttons.openAllOthers")
				:SetDisabled(true)

			context.frame:GetElement("bottom")
				:Draw()
		else
			local all, sales, buys, cancels, expires, other = 0, 0, 0, 0, 0, 0
			for _, row in private.inboxQuery:Iterator() do
				local mailType = row:GetField("type")
				all = all + 1
				if mailType == InboxAPI.MAIL_TYPE.SALE then
					sales = sales + 1
				elseif mailType == InboxAPI.MAIL_TYPE.BUY then
					buys = buys + 1
				elseif mailType == InboxAPI.MAIL_TYPE.CANCEL then
					cancels = cancels + 1
				elseif mailType == InboxAPI.MAIL_TYPE.EXPIRE then
					expires = expires + 1
				elseif mailType == InboxAPI.MAIL_TYPE.OTHER then
					other = other + 1
				else
					assert(mailType == InboxAPI.MAIL_TYPE.LETTER)
				end
			end

			context.frame:GetElement("bottom.openAllMail")
				:SetDisabled(all == 0)
				:SetPressed(false)
			context.frame:GetElement("bottom.buttons.openAllSales")
				:SetDisabled(sales == 0)
				:SetPressed(false)
			context.frame:GetElement("bottom.buttons.openAllBuys")
				:SetDisabled(buys == 0)
				:SetPressed(false)
			context.frame:GetElement("bottom.buttons.openAllCancels")
				:SetDisabled(cancels == 0)
				:SetPressed(false)
			context.frame:GetElement("bottom.buttons.openAllExpires")
				:SetDisabled(expires == 0)
				:SetPressed(false)
			context.frame:GetElement("bottom.buttons.openAllOthers")
				:SetDisabled(other == 0)
				:SetPressed(false)

			context.frame:GetElement("bottom")
				:Draw()
		end
	end

	private.fsm = FSM.New("MAILING_INBOX")
		:AddState(FSM.NewState("ST_HIDDEN")
			:SetOnEnter(function(context)
				TSM.Mailing.Open.KillThread()
				private.updateCounterTimer:Cancel()
				context.frame = nil
			end)
			:AddTransition("ST_SHOWN")
			:AddTransition("ST_HIDDEN")
			:AddEventTransition("EV_FRAME_SHOW", "ST_SHOWN")
		)
		:AddState(FSM.NewState("ST_SHOWN")
			:SetOnEnter(function(context, frame, filterText)
				if not context.frame then
					context.frame = frame
					UpdateText(context, filterText)
					UpdateButtons(context)
				end
			end)
			:AddTransition("ST_HIDDEN")
			:AddTransition("ST_OPENING_START")
			:AddEvent("EV_MAIL_DATA_UPDATED", function(context, filterText)
				UpdateText(context, filterText)
				UpdateButtons(context)
			end)
			:AddEventTransition("EV_BUTTON_CLICKED", "ST_OPENING_START")
		)
		:AddState(FSM.NewState("ST_OPENING_START")
			:SetOnEnter(function(context, autoRefresh, keepMoney, filterText, filterType)
				context.opening = true
				UpdateButtons(context)
				TSM.Mailing.Open.StartOpening(private.FSMOpenCallback, autoRefresh, keepMoney, filterText, filterType)
			end)
			:SetOnExit(function(context)
				context.opening = false
				UpdateButtons(context)
			end)
			:AddTransition("ST_SHOWN")
			:AddTransition("ST_HIDDEN")
			:AddEvent("EV_MAIL_DATA_UPDATED", function(context, filterText)
				UpdateText(context, filterText)
			end)
			:AddEventTransition("EV_OPENING_DONE", "ST_SHOWN")
		)
		:AddDefaultEventTransition("EV_FRAME_HIDE", "ST_HIDDEN")
		:Init("ST_HIDDEN", fsmContext)
end

function private.FSMOpenCallback()
	private.fsm:ProcessEvent("EV_OPENING_DONE")

	SoundAlert.Play(private.settings.openMailSound)
end
