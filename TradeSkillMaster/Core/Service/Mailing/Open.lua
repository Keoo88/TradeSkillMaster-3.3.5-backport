-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Open = TSM.Mailing:NewPackage("Open") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local Threading = TSM.LibTSMTypes:Include("Threading")
local Inbox = TSM.LibTSMWoW:Include("API.Inbox")
local Mail = TSM.LibTSMService:Include("Mail")
local private = {
	settings = nil,
	thread = nil,
	isOpening = false,
	lastCheck = nil,
	moneyCollected = 0,
	checkInboxTimer = nil,
}
local MAIL_REFRESH_TIME = ClientInfo.IsRetail() and 15 or 60
local MANUAL_MAIL_TYPES = {
	[Inbox.MAIL_TYPE.OTHER.GOLD_AND_ITEMS] = true,
	[Inbox.MAIL_TYPE.OTHER.ITEMS] = true,
	[Inbox.MAIL_TYPE.OTHER.GOLD] = true,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Open.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mailingOptions", "inboxMessages")
		:AddKey("global", "mailingOptions", "keepMailSpace")
	private.thread = Threading.New("MAIL_OPENING", private.OpenMailThread)
	private.checkInboxTimer = DelayTimer.New("MAILING_OPEN_CHECK_INBOX", private.CheckInbox)
	DefaultUI.RegisterMailVisibleCallback(private.FrameVisibleCallback)
end

function Open.KillThread()
	Threading.Kill(private.thread)

	private.PrintMoneyCollected()
	private.isOpening = false
end

function Open.StartOpening(callback, autoRefresh, keepMoney, filterText, filterType)
	Threading.Kill(private.thread)

	private.isOpening = true
	private.moneyCollected = 0

	Threading.SetCallback(private.thread, callback)
	Threading.Start(private.thread, autoRefresh, keepMoney, filterText, filterType)
end

function Open.GetLastCheckTime()
	return private.lastCheck
end



-- ============================================================================
-- Mail Opening Thread
-- ============================================================================

function private.OpenMailThread(autoRefresh, keepMoney, filterText, filterType)
	-- 3.3.5: input:GetValue() может вернуть nil → Matches() ассертит.
	filterText = filterText or ""
	while true do
		local preLeftMail, preTotalMail = Inbox.GetNumItems()
		local query = TSM.Mailing.Inbox.CreateQuery()
		query:ResetOrderBy()
			:OrderBy("index", false)
			:Or()
				:Matches("itemList", filterText)
				:Matches("subject", filterText)
			:End()
			:Select("index")

		if filterType then
			query:Equal("type", filterType)
		end

		local mails = Threading.AcquireSafeTempTable()
		for _, index in query:Iterator() do
			tinsert(mails, index)
		end
		query:Release()

		private.OpenMails(mails, keepMoney, filterType)
		TempTable.Release(mails)

		local postLeftMail, postTotalMail = Inbox.GetNumItems()
		if not autoRefresh or (preLeftMail == postLeftMail and preTotalMail == postTotalMail and postTotalMail == postLeftMail) then
			Threading.Sleep(1)
			break
		end

		CheckInbox()
		Threading.Sleep(1)
	end

	private.PrintMoneyCollected()
	private.isOpening = false
end

function private.CanOpenMail()
	return not C_Mail.IsCommandPending()
end

-- 3.3.5: нет CalculateTotalNumberOfFreeBagSlots, считаем сами по бэгам.
function private.GetTotalFreeBagSlots()
	if type(CalculateTotalNumberOfFreeBagSlots) == "function" then
		return CalculateTotalNumberOfFreeBagSlots()
	end
	local total = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		total = total + (GetContainerNumFreeSlots(bag) or 0)
	end
	return total
end

function private.OpenMails(mails, keepMoney, filterType)
	for i = 1, #mails do
		local index = mails[i]
		Threading.WaitForFunction(private.CanOpenMail)

		local mailType = Inbox.GetMailType(index)
		local matchesFilter = (not filterType and mailType) or (filterType == mailType)
		local hasBagSpace = not Mail.GetInboxItemLink(index) or private.GetTotalFreeBagSlots() > private.settings.keepMailSpace
		if matchesFilter and hasBagSpace then
			local _, money, cod, numItems, _, _, textCreated = Inbox.GetHeaderInfo(index)
			if cod == 0 and (not keepMoney or (keepMoney and money <= 0)) then
				local message = private.settings.inboxMessages and private.GetOpenMailMessage(index) or nil
				-- Marks the mail as read
				Inbox.GetText(index)
				AutoLootMailItem(index)
				private.moneyCollected = private.moneyCollected + money

				local event = nil
				if money > 0 or numItems > 0 then
					if mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER or MANUAL_MAIL_TYPES[mailType] then
						event = "MAIL_SUCCESS"
					elseif textCreated and mailType ~= Inbox.MAIL_TYPE.OTHER.TEMP_INVOICE then
						-- Temporary invoices are not auto deleted
						event = "CLOSE_INBOX_ITEM"
					end
				end
				if event and Threading.WaitForEvent(event, "MAIL_FAILED") ~= "MAIL_FAILED" then
					if message then
						ChatMessage.PrintUser(message)
					end
					if textCreated and event == "MAIL_SUCCESS" then
						private.DeleteEmptyMail(index)
					end
				end
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameVisibleCallback(visible)
	if visible then
		private.ScheduleCheck()
	else
		private.checkInboxTimer:Cancel()
	end
end

function private.CheckInbox()
	if private.isOpening then
		private.ScheduleCheck()
		return
	end

	if not TSM.UI.MailingUI.Inbox.IsMailOpened() then
		CheckInbox()
	end
	private.ScheduleCheck()
end

function private.PrintMoneyCollected()
	if private.settings.inboxMessages and private.moneyCollected > 0 then
		ChatMessage.PrintfUser(L["Total Gold Collected: %s"], Money.ToStringForUI(private.moneyCollected))
	end
	private.moneyCollected = 0
end

function private.GetOpenMailMessage(index)
	local mailType = Inbox.GetMailType(index)
	if mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
		local itemName, seller, bid, _, _, _, _, _, quantity = Inbox.GetInvoiceInfo(index)
		seller = seller or AUCTION_HOUSE_MAIL_MULTIPLE_SELLERS
		local itemLink = Mail.GetInboxItemLink(index) or "["..tostring(itemName).."]"
		-- 3.3.5a: 0 is truthy in Lua, so a 0 count (invoice mail has no attachment) slipped past the old
		-- 'if not quantity' check and the log showed 'Sold/Bought ... x0'. Treat 0 as missing.
		if not quantity or quantity == 0 then
			local _, _, attachQty = private.GetMailItemInfo(index)
			quantity = (attachQty and attachQty > 0) and attachQty or 1
		end
		return format(L["Bought %sx%d for %s from %s"], itemLink, quantity, private.FormatMoney(bid or 0, "FEEDBACK_RED"), seller)
	elseif mailType == Inbox.MAIL_TYPE.SALE.AUCTION then
		local itemName, buyer, bid, _, _, ahcut, _, _, quantity = Inbox.GetInvoiceInfo(index)
		buyer = buyer or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS
		local itemLink = "["..tostring(itemName).."]"
		-- 3.3.5a: 0 is truthy in Lua, so a 0 count (invoice mail has no attachment) slipped past the old
		-- 'if not quantity' check and the log showed 'Sold/Bought ... x0'. Treat 0 as missing.
		if not quantity or quantity == 0 then
			local _, _, attachQty = private.GetMailItemInfo(index)
			quantity = (attachQty and attachQty > 0) and attachQty or 1
		end
		return format(L["Sold %sx%d for %s to %s"], itemLink, quantity, private.FormatMoney((bid or 0) - (ahcut or 0), "FEEDBACK_GREEN"), buyer)
	elseif mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER then
		local _, commission, crafter = Inbox.GetCraftingOrderInfo(index)
		return format(L["Crafting order bought for %s from %s"], private.FormatMoney(commission, "FEEDBACK_RED"), crafter)
	elseif mailType == Inbox.MAIL_TYPE.SALE.CRAFTING_ORDER then
		local _, commission, customer = Inbox.GetCraftingOrderInfo(index)
		return format(L["Crafting order sold for %s to %s"], private.FormatMoney(commission, "FEEDBACK_GREEN"), customer)
	elseif mailType == Inbox.MAIL_TYPE.CANCEL.AUCTION then
		local numItems, itemLink, quantity = private.GetMailItemInfo(index)
		if numItems == 1 and quantity > 0 then
			return format(L["Cancelled auction of %sx%d"], itemLink, quantity)
		end
	elseif mailType == Inbox.MAIL_TYPE.EXPIRE.AUCTION then
		local numItems, itemLink, quantity = private.GetMailItemInfo(index)
		if numItems == 1 and itemLink and quantity > 0 then
			return format(L["Your auction of %sx%s expired"], itemLink, quantity)
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD_AND_ITEMS then
		local sender, money = Inbox.GetHeaderInfo(index)
		sender = sender or "?"
		local _, itemLink, quantity = private.GetMailItemInfo(index)
		if quantity > 0 then
			return format(L["%s sent you %sx%d and %s"], sender, itemLink, quantity, private.FormatMoney(money, "FEEDBACK_GREEN"))
		elseif quantity == -1 then
			return format(L["%s sent you multiple items and %s"], sender, private.FormatMoney(money, "FEEDBACK_GREEN"))
		else
			return format(L["%s sent you %s"], sender, private.FormatMoney(money, "FEEDBACK_GREEN"))
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.ITEMS then
		local sender = Inbox.GetHeaderInfo(index)
		sender = sender or "?"
		local _, itemLink, quantity = private.GetMailItemInfo(index)
		if quantity > 0 then
			return format(L["%s sent you %sx%d"], sender, itemLink, quantity)
		elseif quantity == -1 then
			return format(L["%s sent you multiple items"], sender)
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD then
		local sender, money = Inbox.GetHeaderInfo(index)
		sender = sender or "?"
		return format(L["%s sent you %s"], sender, private.FormatMoney(money, "FEEDBACK_GREEN"))
	end
end

function private.FormatMoney(amount, color)
	return Money.ToStringExact(amount, Theme.GetColor(color):GetTextColorPrefix())
end

function private.GetMailItemInfo(index)
	local _, _, _, numItems = Inbox.GetHeaderInfo(index)
	local itemLink = nil
	local quantity = 0
	for i = 1, numItems do
		local link, count = Inbox.GetAttachment(index, i)
		itemLink = itemLink or link
		quantity = quantity + (count or 0)
		if ItemString.Get(itemLink) ~= ItemString.Get(link) then
			itemLink = L["Multiple Items"]
			quantity = -1
			break
		end
	end
	if numItems == 1 then
		itemLink = Mail.GetInboxItemLink(index) or itemLink
	end
	return numItems, itemLink, quantity
end

function private.DeleteEmptyMail(index)
	local _, money, _, itemCount = Inbox.GetHeaderInfo(index)
	-- Only force delete completely empty mails
	if money == 0 and not itemCount then
		DeleteInboxItem(index)
	end
end


-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.ScheduleCheck()
	if not private.lastCheck or time() - private.lastCheck > (MAIL_REFRESH_TIME - 1) then
		private.lastCheck = time()
		private.checkInboxTimer:RunForTime(MAIL_REFRESH_TIME)
	else
		local nextUpdate = MAIL_REFRESH_TIME - (time() - private.lastCheck)
		private.checkInboxTimer:RunForTime(nextUpdate)
	end
end
