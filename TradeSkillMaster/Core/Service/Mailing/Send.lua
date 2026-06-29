-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Send = TSM.Mailing:NewPackage("Send") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local SlotId = TSM.LibTSMWoW:Include("Type.SlotId")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Container = TSM.LibTSMWoW:Include("API.Container")
local Group = TSM.LibTSMTypes:Include("Group")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local Inbox = TSM.LibTSMWoW:Include("API.Inbox")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local private = {
	settings = nil,
	thread = nil,
	bagUpdate = nil,
}

local PLAYER_NAME = UnitName("player")
local PLAYER_NAME_REALM = gsub(PLAYER_NAME.."-"..GetRealmName(), "%s+", "")



-- ============================================================================
-- Module Functions
-- ============================================================================

function Send.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mailingOptions", "sendItemsIndividually")
		:AddKey("global", "mailingOptions", "sendMessages")
	private.thread = Threading.New("MAIL_SENDING", private.SendMailThread)
	BagTracking.RegisterCallback(private.BagUpdate)
end

function Send.KillThread()
	Threading.Kill(private.thread)
end

function Send.StartSending(callback, recipient, subject, body, money, items, isGroup, isDryRun)
	if TSMDBG then TSMDBG.Log("Send", "StartSending recipient=%s money=%s items=%s",
		tostring(recipient), tostring(money), tostring(items)) end
	Threading.Kill(private.thread)

	Threading.SetCallback(private.thread, callback)
	Threading.Start(private.thread, recipient, subject, body, money, items, isGroup, isDryRun)
end



-- ============================================================================
-- Mail Sending Thread
-- ============================================================================

function private.SendMailThread(recipient, subject, body, money, items, isGroup, isDryRun)
	if TSMDBG then TSMDBG.Log("Send", "SendMailThread start recipient=%s items=%s",
		tostring(recipient), tostring(items)) end
	if not recipient or recipient == "" or recipient == PLAYER_NAME or recipient == PLAYER_NAME_REALM then
		if TSMDBG then TSMDBG.Warn("Send", "SendMailThread early-exit: invalid recipient=%s", tostring(recipient)) end
		return
	end

	-- 3.3.5: items может прийти с отрицательными quantity из-за бага в ListOnAddItem/UpdateSendMailInfo
	-- Чистим items от не-положительных значений
	if items then
		local removed = 0
		for itemString, quantity in pairs(items) do
			if type(quantity) ~= "number" or quantity <= 0 then
				items[itemString] = nil
				removed = removed + 1
			end
		end
		if removed > 0 and TSMDBG then
			TSMDBG.Warn("Send", "SendMailThread cleaned %d invalid items entries", removed)
		end
		if not next(items) then
			items = nil
		end
	end

	private.PrintMailMessage(money, items, recipient, isGroup, isDryRun)
	if isDryRun then
		return
	end

	if not items then
		if TSMDBG then TSMDBG.Log("Send", "SendMailThread no items → SendMail recipient=%s", tostring(recipient)) end
		private.SendMail(recipient, subject, body, money, true)
		return
	end

	ClearSendMail()
	local itemInfo = Threading.AcquireSafeTempTable()

	-- 3.3.5: the slotDB can be stale/empty for non-backpack bags because the login-time
	-- BAG_UPDATE events are unreliable on this client, so the send query below found 0
	-- locations for items that are actually in the bags and item mail silently did nothing.
	-- Force a synchronous rescan first, exactly like the Auctioning post scan / CanPost do.
	if not ClientInfo.IsRetail() then
		BagTracking.RescanAllBags()
	end

	-- 3.3.5: the slotDB "isBound" flag is unreliable here (it ends up true for many
	-- perfectly mailable items - the native container API has no real bound flag), and
	-- isWarBound does not exist on this client, so this bound filter removed every item
	-- from the send query: nothing got attached and item mail silently never sent (gold
	-- still worked via the no-items path above). Only apply the bound filter on clients
	-- that actually report it; the explicit `items` list below already gates attachments.
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		query:Or()
			:Equal("isBound", false)
			:Equal("isWarBound", true)
		:End()
	end
	query:Select("bag", "slot", "itemString", "quantity")
	for _, bag, slot, itemString, quantity in query:Iterator() do
		if isGroup then
			itemString = Group.TranslateItemString(itemString)
		end
		if items[itemString] and not Container.IsBagSlotLocked(bag, slot) then
			if not itemInfo[itemString] then
				itemInfo[itemString] = { locations = {} }
			end
			tinsert(itemInfo[itemString].locations, { bag = bag, slot = slot, quantity = quantity })
		end
	end
	query:Release()

	for itemString, quantity in pairs(items) do
		if quantity > 0 and itemInfo[itemString] and #itemInfo[itemString].locations > 0 then
			for i = 1, #itemInfo[itemString].locations do
				local info = itemInfo[itemString].locations[i]
				if info.quantity > 0 then
					if quantity == info.quantity then
						Container.PickupItem(info.bag, info.slot)
						ClickSendMailItemButton()

						if private.GetNumPendingAttachments() == Inbox.GetMaxSendAttachments() or (isGroup and private.settings.sendItemsIndividually) then
							private.SendMail(recipient, subject, body, money)
						end

						items[itemString] = 0
						info.quantity = 0

						break
					end
				end
			end
		end
	end

	for itemString in pairs(items) do
		if items[itemString] > 0 and itemInfo[itemString] and #itemInfo[itemString].locations > 0 then
			local emptySlotIds = private.GetEmptyBagSlotsThreaded(ItemString.IsItem(itemString) and C_Item.GetItemFamily(ItemString.ToId(itemString)) or 0)
			for i = 1, #itemInfo[itemString].locations do
				local info = itemInfo[itemString].locations[i]
				if items[itemString] > 0 and info.quantity > 0 then
					if items[itemString] < info.quantity then
						if #emptySlotIds > 0 then
							local splitBag, splitSlot = SlotId.Split(tremove(emptySlotIds, 1))
							Container.SplitItem(info.bag, info.slot, items[itemString])
							Container.PickupItem(splitBag, splitSlot)
							Threading.WaitForFunction(private.BagSlotHasItem, splitBag, splitSlot)
							Container.PickupItem(splitBag, splitSlot)
							ClickSendMailItemButton()

							if private.GetNumPendingAttachments() == Inbox.GetMaxSendAttachments() then
								private.SendMail(recipient, subject, body, money)
							end

							items[itemString] = 0
							info.quantity = 0

							break
						end
					else
						Container.PickupItem(info.bag, info.slot)
						ClickSendMailItemButton()

						if private.GetNumPendingAttachments() == Inbox.GetMaxSendAttachments() then
							private.SendMail(recipient, subject, body, money)
						end

						items[itemString] = items[itemString] - info.quantity
						info.quantity = 0
					end
				end
			end

			if isGroup and private.settings.sendItemsIndividually then
				private.SendMail(recipient, subject, body, money)
			end
			TempTable.Release(emptySlotIds)
		end
	end

	if private.HasPendingAttachments() then
		private.SendMail(recipient, subject, body, money)
	end

	TempTable.Release(itemInfo)
end

function private.PrintMailMessage(money, items, target, isGroup, isDryRun)
	if not private.settings.sendMessages and not isDryRun then
		return
	end
	money = money or 0
	if money > 0 and not items then
		ChatMessage.PrintfUser(L["Sending %s to %s"], Money.ToStringExact(money), target)
		return
	end

	if not items then
		return
	end

	local itemList = ""
	for k, v in pairs(items) do
		local coloredItem = ItemInfo.GetLink(k)
		itemList = itemList..coloredItem.."x"..v..", "
	end
	itemList = strtrim(itemList, ", ")

	if next(items) and money < 0 then
		if isDryRun then
			ChatMessage.PrintfUser(L["Would send %s to %s with a COD of %s"], itemList, target, Money.ToStringExact(money, Theme.GetColor("FEEDBACK_RED"):GetTextColorPrefix()))
		else
			ChatMessage.PrintfUser(L["Sending %s to %s with a COD of %s"], itemList, target, Money.ToStringExact(money, Theme.GetColor("FEEDBACK_RED"):GetTextColorPrefix()))
		end
	elseif next(items) then
		if isDryRun then
			ChatMessage.PrintfUser(L["Would send %s to %s"], itemList, target)
		else
			ChatMessage.PrintfUser(L["Sending %s to %s"], itemList, target)
		end
	end
end

function private.SendMail(recipient, subject, body, money, noItem)
	if subject == nil or subject == "" then
		local text = SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() or nil
		subject = (text and text ~= "") and text or "TSM Mailing"
	end
	body = body or ""

	money = money or 0
	if money > 0 then
		SetSendMailMoney(money)
		SetSendMailCOD(0)
	elseif money < 0 then
		SetSendMailCOD(abs(money))
		SetSendMailMoney(0)
	else
		SetSendMailMoney(0)
		SetSendMailCOD(0)
	end

	private.bagUpdate = false
	if TSMDBG then TSMDBG.Log("Send", "SendMail recipient=%s subject=%s body=%s money=%s noItem=%s",
		tostring(recipient), tostring(subject), tostring(body), tostring(money), tostring(noItem)) end
	SendMail(recipient, subject, body)

	-- 3.3.5: успешная отправка шлёт MAIL_SEND_SUCCESS, а не ретейловое MAIL_SUCCESS.
	local sendSuccessEvent = ClientInfo.IsRetail() and "MAIL_SUCCESS" or "MAIL_SEND_SUCCESS"
	if Threading.WaitForEvent(sendSuccessEvent, "MAIL_FAILED") == sendSuccessEvent then
		if noItem then
			Threading.Sleep(0.5)
		else
			Threading.WaitForFunction(private.HasNewBagUpdate)
		end
	else
		Threading.Sleep(0.5)
	end
end

function private.BagUpdate()
	private.bagUpdate = true
end

function private.HasNewBagUpdate()
	return private.bagUpdate
end

function private.HasPendingAttachments()
	for i = 1, Inbox.GetMaxSendAttachments() do
		if GetSendMailItem(i) then
			return true
		end
	end

	return false
end

function private.GetNumPendingAttachments()
	local totalAttached = 0
	for i = 1, Inbox.GetMaxSendAttachments() do
		if GetSendMailItem(i) then
			totalAttached = totalAttached + 1
		end
	end

	return totalAttached
end

function private.GetEmptyBagSlotsThreaded(itemFamily)
	local emptySlotIds = Threading.AcquireSafeTempTable()
	local sortvalue = Threading.AcquireSafeTempTable()
	for bag = 0, Container.GetNumBags() do
		Container.GenerateSortedEmptyFamilySlots(bag, itemFamily, emptySlotIds, sortvalue)
		Threading.Yield()
	end
	Table.SortWithValueLookup(emptySlotIds, sortvalue)
	TempTable.Release(sortvalue)

	return emptySlotIds
end

function private.BagSlotHasItem(bag, slot)
	return Container.GetItemLink(bag, slot) and true or false
end
