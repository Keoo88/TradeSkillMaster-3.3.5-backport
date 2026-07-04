-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
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
	lastMailAction = nil,
}
local MAIL_REFRESH_TIME = ClientInfo.IsRetail() and 15 or 60
local IS_CLASSIC = not ClientInfo.IsRetail()
-- 3.3.5/Warmane: нет реального IsCommandPending, держим мин. интервал между операциями
-- (это и есть скорость сборки писем). Меньше значение — быстрее сборка; слишком малый
-- интервал сервер может «глотать», но пропущенные письма подхватит повторный проход.
local CLASSIC_MAIL_THROTTLE = 0.1
-- 3.3.5/Warmane: макс. время ожидания подтверждения изъятия одного письма (замена
-- ненадёжного MAIL_INBOX_UPDATE), чтобы поток сборки не зависал «на половине».
local CLASSIC_MAIL_CONFIRM_TIMEOUT = 1
-- 3.3.5/Warmane: страховочный лимит числа повторных проходов сборки (защита от зацикливания).
local MAX_OPEN_PASSES = 15
-- 3.3.5/Warmane: короткая пауза между рескана��и ЖИВОГО инбокса (замена старой Sleep(1) между
-- проходами, которая и давала рваный сбор «пару писем — пауза — пару писем»). Так как теперь
-- читаем живой инбокс, а не догоняющую трекинг-БД, длинная пауза не нужна — хватает короткой,
-- чтобы сервер успел применить удаления и подтянуть скрытые письма.
local CLASSIC_MAIL_RESCAN_SETTLE = 0.2
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
	-- 3.3.5/Warmane: у классики отдельный цикл по живому инбоксу (см. OpenMailThreadClassic).
	if IS_CLASSIC then
		return private.OpenMailThreadClassic(autoRefresh, keepMoney, filterText, filterType)
	end
	local passCount = 0
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

		local tookAny = private.OpenMails(mails, keepMoney, filterType)
		TempTable.Release(mails)
		passCount = passCount + 1

		local postLeftMail, postTotalMail = Inbox.GetNumItems()
		local shouldContinue
		if IS_CLASSIC then
			-- 3.3.5/Warmane: трекинговая БД писем отстаёт от живого инбокса (скан по MAIL_INBOX_UPDATE
			-- приходит с задержкой), поэтому самое свежее/верхнее письмо могло не попасть в запрос и
			-- за один проход собирались не все (напр. «2 из 3, самое первое не собралось»). Инвойсы
			-- теперь собираются без блокирующего ожидания, поэтому решаем по факту «забрали ли что-то
			-- за проход», а не по ещё не обновлённым сервером сч��тчикам: пока проход что-то забирает —
			-- делаем ещё один (после рескана), с лимитом MAX_OPEN_PASSES от зацикливания.
			shouldContinue = tookAny and postTotalMail > 0 and passCount < MAX_OPEN_PASSES
		else
			-- retail: прежнее поведение по счётчикам инбокса.
			shouldContinue = autoRefresh and not (preLeftMail == postLeftMail and preTotalMail == postTotalMail and postTotalMail == postLeftMail)
		end
		if not shouldContinue then
			Threading.Sleep(1)
			break
		end

		CheckInbox()
		Threading.Sleep(1)
	end

	private.PrintMoneyCollected()
	private.isOpening = false
end

-- 3.3.5/Warmane: цикл сбора для классики по образцу Postal (Modules/OpenAll.lua) и TSM 2.8
-- (Mailing/Inbox.lua): идём по ЖИВОМУ инбоксу и продвигаемся к следующему письму только после
-- подтверждения изъятия текущего. Раньше классика собирала пачку индексов из трекинг-БД (которая
-- отстаёт от инбокса) и делала Sleep(1) между проходами — отсюда рваный сбор «пару писем — пауза».
-- Теперь пейсинг задаёт само подтверждение изъятия, без длинных пауз.
function private.OpenMailThreadClassic(autoRefresh, keepMoney, filterText, filterType)
	filterText = strlower(filterText or "")
	local passCount = 0
	while true do
		local tookAny = false
		local numLeft = Inbox.GetNumItems()
		-- Нисходящий обход безопасен при удалении: изъятое письмо сдвигает только большие индексы,
		-- которые мы уже прошли; ещё не обработанные меньшие индексы не смещаются (как в Postal).
		for index = numLeft, 1, -1 do
			Threading.WaitForFunction(private.CanOpenMail)
			if private.OpenSingleMailClassic(index, keepMoney, filterText, filterType) then
				tookAny = true
			end
		end
		passCount = passCount + 1

		local _, numTotal = Inbox.GetNumItems()
		-- Повторяем проход, только пока реально что-то собираем и остаются письма (со страховочным
		-- лимитом MAX_OPEN_PASSES от зацикливания).
		if not (tookAny and numTotal > 0 and passCount < MAX_OPEN_PASSES) then
			break
		end
		CheckInbox()
		Threading.Sleep(CLASSIC_MAIL_RESCAN_SETTLE)
	end

	private.PrintMoneyCollected()
	private.isOpening = false
end

-- 3.3.5/Warmane: собирает ОДНО письмо и ограниченно ждёт подтверждения изъятия. Возвращает true,
-- если письмо было взято (нужно для решения о ещё одном проходе).
function private.OpenSingleMailClassic(index, keepMoney, filterText, filterType)
	local mailType = Inbox.GetMailType(index)
	if filterType then
		if mailType ~= filterType then
			return false
		end
	elseif not mailType then
		return false
	end
	if filterText ~= "" and not private.MatchesFilterText(index, filterText) then
		return false
	end

	local hasBagSpace = not Mail.GetInboxItemLink(index) or private.GetTotalFreeBagSlots() > private.settings.keepMailSpace
	if not hasBagSpace then
		return false
	end

	local _, money, cod, numItems, _, _, textCreated = Inbox.GetHeaderInfo(index)
	if cod ~= 0 then
		return false
	end
	if keepMoney and money > 0 then
		return false
	end
	-- Нечего забирать (письмо уже опустошено или это просто текстовое письмо) — пропускаем, иначе
	-- дёргали бы AutoLootMailItem по пустышкам и держали бы tookAny=true, накручивая лишние проходы.
	if money <= 0 and numItems <= 0 then
		return false
	end

	local message = private.settings.inboxMessages and private.GetOpenMailMessage(index) or nil
	-- Отмечаем письмо прочитанным
	Inbox.GetText(index)
	-- Снимок инбокса ДО изъятия — по нему ждём реальное изменение.
	local preTakeLeft, preTakeTotal = Inbox.GetNumItems()
	AutoLootMailItem(index)
	private.lastMailAction = GetTime()
	private.moneyCollected = private.moneyCollected + money

	-- Ограниченное по времени подтверждение изъятия (аналог ожидания MAIL_INBOX_UPDATE в TSM 2.8 и
	-- опроса дельты «предметы/золото» в Postal): выходим сразу при изменении инбокса, но не дольше
	-- CLASSIC_MAIL_CONFIRM_TIMEOUT, чтобы не обгонять сервер (иначе он «глотает» частые запросы и
	-- письма пропускаются) и при этом не зависать.
	local deadline = GetTime() + CLASSIC_MAIL_CONFIRM_TIMEOUT
	local _, changed = Threading.WaitForFunction(private.MailActionConfirmed, deadline, index, preTakeLeft, preTakeTotal)
	if message then
		ChatMessage.PrintUser(message)
	end
	-- Личные письма с телом сервер не удаляет сам — удаляем вручную, только когда изъятие подтверждено.
	if changed and textCreated and MANUAL_MAIL_TYPES[mailType] then
		private.DeleteEmptyMail(index)
	end
	return true
end

-- 3.3.5/Warmane: замена фильтра трекинг-БД (Matches itemList/subject) для обхода по живому инбоксу.
function private.MatchesFilterText(index, filterText)
	local _, _, _, numItems, subject = Inbox.GetHeaderInfo(index)
	if subject and strfind(strlower(subject), filterText, 1, true) then
		return true
	end
	for i = 1, numItems do
		local link = Inbox.GetAttachment(index, i)
		if link and strfind(strlower(link), filterText, 1, true) then
			return true
		end
	end
	return false
end

function private.CanOpenMail()
	if C_Mail.IsCommandPending() then
		return false
	end
	-- 3.3.5/Warmane: заглушка IsCommandPending всегда false, поэтому страхуемся
	-- минимальным интервалом, иначе сервер глотает частые запросы и письма пропускаются.
	if IS_CLASSIC and private.lastMailAction and (GetTime() - private.lastMailAction) < CLASSIC_MAIL_THROTTLE then
		return false
	end
	return true
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

-- 3.3.5/Warmane: предикат ограниченного по времени ожидания подтверждения изъятия письма.
-- Возвращает (true, true) при реальном и��менении инбокса и (true, false) по истечении дедлайна.
function private.MailActionConfirmed(deadline, index, prevLeft, prevTotal)
	if GetTime() >= deadline then
		return true, false
	end
	local left, total = Inbox.GetNumItems()
	if left ~= prevLeft or total ~= prevTotal then
		return true, true
	end
	-- Письмо могло не удалиться сервером сразу (остаётся прочитанным пустым) — тогда общий
	-- счётчик не меняется. Подтверждаем по факту: у самого письма больше нет золота/вложений
	-- (срабатывает сразу после изъятия, не дожидаясь удаления последнего письма).
	local _, money, _, numItems = Inbox.GetHeaderInfo(index)
	if money <= 0 and numItems <= 0 then
		return true, true
	end
	return false
end

function private.OpenMails(mails, keepMoney, filterType)
	local tookAny = false
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
				-- 3.3.5/Warmane: снимок инбокса ДО изъятия — по нему затем ждём реальное изменение.
				local preTakeLeft, preTakeTotal = Inbox.GetNumItems()
				AutoLootMailItem(index)
				private.lastMailAction = GetTime()
				private.moneyCollected = private.moneyCollected + money
				tookAny = true

				local needConfirm, isManualType = false, false
				if money > 0 or numItems > 0 then
					if mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER or MANUAL_MAIL_TYPES[mailType] then
						needConfirm, isManualType = true, true
					elseif textCreated and mailType ~= Inbox.MAIL_TYPE.OTHER.TEMP_INVOICE then
						-- Temporary invoices are not auto deleted
						needConfirm = true
					end
				end
				if needConfirm then
					if not IS_CLASSIC then
						-- Retail: ждём событие подтверждения изъятия.
						local confirmEvent = isManualType and "MAIL_SUCCESS" or "CLOSE_INBOX_ITEM"
						if Threading.WaitForEvent(confirmEvent, "MAIL_FAILED") ~= "MAIL_FAILED" then
							if message then
								ChatMessage.PrintUser(message)
							end
							if textCreated and isManualType then
								private.DeleteEmptyMail(index)
							end
						end
					elseif isManualType and textCreated then
						-- 3.3.5/Warmane: только ручные письма нужно удалять вручную; DeleteEmptyMail нельзя
						-- звать до фактического изъятия (иначе можно удалить непустое письмо), поэтому
						-- здесь ждём реального изъятия, но не дольше CLASSIC_MAIL_CONFIRM_TIMEOUT.
						local deadline = GetTime() + CLASSIC_MAIL_CONFIRM_TIMEOUT
						local _, changed = Threading.WaitForFunction(private.MailActionConfirmed, deadline, index, preTakeLeft, preTakeTotal)
						if changed then
							if message then
								ChatMessage.PrintUser(message)
							end
							private.DeleteEmptyMail(index)
						end
					else
						-- 3.3.5/Warmane: инвойсы (продажи/отмены/истёкшие) сервер удаляет сам после изъятия,
						-- вручную удалять не нужно. Предмет/золото уже забраны AutoLootMailItem, поэтому НЕ
						-- блокируем поток ожиданием ответа сервера — это и убирало заметную паузу перед сбором
						-- (в т.ч. первого письма). Пейсинг задаёт троттл CanOpenMail, а недобранное подхватит
						-- повторный проход внешнего цикла.
						if message then
							ChatMessage.PrintUser(message)
						end
					end
				end
			end
		end
	end
	return tookAny
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
