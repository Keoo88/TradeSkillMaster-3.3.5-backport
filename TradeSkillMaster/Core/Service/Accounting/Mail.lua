-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Mail = TSM.Accounting:NewPackage("Mail")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local String = TSM.LibTSMUtil:Include("Lua.String")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Vararg = TSM.LibTSMUtil:Include("Lua.Vararg")
local Container = TSM.LibTSMWoW:Include("API.Container")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local Auction = TSM.LibTSMService:Include("Auction")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local TooltipScanning = TSM.LibTSMWoW:Include("Service.TooltipScanning")
local Inbox = TSM.LibTSMWoW:Include("API.Inbox")
local private = {
	hooks = {},
	sellersTimer = nil,
	rescanTimer = nil,
	rescanContext = {},
}
local SECONDS_PER_DAY = 24 * 60 * 60



-- ============================================================================
-- Module Functions
-- ============================================================================

function Mail.OnInitialize()
	-- If the mail should container the seller, setup a timer to query the seller names
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_SELLERS) then
		private.sellersTimer = DelayTimer.New("ACCOUNTING_MAIL_SELLERS", private.RequestSellerInfo)
		DefaultUI.RegisterMailVisibleCallback(function(visible)
			if visible then
				private.sellersTimer:RunForTime(0.1)
			else
				private.sellersTimer:Cancel()
			end
		end)
	end
	private.rescanTimer = DelayTimer.New("ACCOUNTING_MAIL_RESCAN", private.RescanHandler)
	-- Hook certain mail functions
	private.hooks.TakeInboxItem = TakeInboxItem
	TakeInboxItem = function(...)
		private.ScanCollectedMail("TakeInboxItem", 1, ...)
	end
	private.hooks.TakeInboxMoney = TakeInboxMoney
	TakeInboxMoney = function(...)
		private.ScanCollectedMail("TakeInboxMoney", 1, ...)
	end
	private.hooks.AutoLootMailItem = AutoLootMailItem
	AutoLootMailItem = function(...)
		private.ScanCollectedMail("AutoLootMailItem", 1, ...)
	end
	private.hooks.SendMail = SendMail
	SendMail = private.CheckSendMail
end



-- ============================================================================
-- Inbox Functions
-- ============================================================================

function private.RequestSellerInfo()
	local isDone = true
	for i = 1, Inbox.GetNumItems() do
		local itemName, seller = Inbox.GetInvoiceInfo(i)
		if itemName and seller == "" then
			isDone = false
		end
	end
	if not isDone or Inbox.GetNumItems() == 0 then
		private.sellersTimer:RunForTime(0.1)
	end
end

function private.CanLootMailIndex(index, copper)
	local currentMoney = GetMoney()
	local moneyCap = nil
	if ClientInfo.IsRetail() then
		moneyCap = MAXIMUM_BID_PRICE
	elseif ClientInfo.IsPandaClassic() then
		moneyCap = 9999999999
	else
		moneyCap = 2147483647
	end
	assert(currentMoney <= moneyCap)
	-- Check if this would put them over the gold cap
	if currentMoney + copper > moneyCap then
		return
	end
	local _, _, _, itemCount = Inbox.GetHeaderInfo(index)
	if not itemCount or itemCount == 0 then
		return true
	end
	for j = 1, Inbox.GetMaxAttachments() do
		-- TODO: prevent items that you can't loot because of internal mail error
		if CalculateTotalNumberOfFreeBagSlots() <= 0 then
			return
		end
		local link, quantity = Inbox.GetAttachment(index, j)
		local itemString = ItemString.Get(link)
		if not itemString then
			return
		end
		quantity = quantity or 0
		local maxUnique = TooltipScanning.GetInboxMaxUnique(index, j)
		-- Dont record unique items that we can't loot
		if maxUnique > 0 and maxUnique < BagTracking.GetTotalQuantity(ItemString.GetBaseFast(itemString)) + quantity then
			return
		end
		for bag = 0, Container.GetNumBags() do
			if BagTracking.ItemWillGoInBag(itemString, bag) then
				for slot = 1, Container.GetNumSlots(bag) do
					local iString = ItemString.Get(Container.GetItemLink(bag, slot))
					if iString == itemString then
						local stackSize = Container.GetStackCount(bag, slot)
						local maxStackSize = ItemInfo.GetMaxStack(itemString) or 1
						if (maxStackSize - stackSize) >= quantity then
							return true
						end
					elseif not iString then
						return true
					end
				end
			end
		end
	end
end

-- Scans the mail that the player just attempted to collected (Pre-Hook)
function private.ScanCollectedMail(oFunc, attempt, index, subIndex)
	local _, _, _, _, subject, _, _, _, _, texture = Inbox.GetHeaderInfo(index)
	if not subject then
		return
	end
	local success, shouldRetry = private.RecordMail(index, subIndex, attempt <= 2)
	if not success and attempt <= 5 and (not texture or shouldRetry) then
		-- Try again
		wipe(private.rescanContext)
		Vararg.IntoTable(private.rescanContext, oFunc, attempt + 1, index, subIndex)
		private.rescanTimer:RunForTime(0.2)
	else
		private.hooks[oFunc](index, subIndex)
	end
end

function private.RecordMail(index, subIndex, resolveNames)
	local mailType = Inbox.GetMailType(index)
	local sender, money, codAmount, _, subject, daysLeft = Inbox.GetHeaderInfo(index)
	sender = (sender and sender ~= "") and sender or "?"
	if mailType == Inbox.MAIL_TYPE.SALE.AUCTION then
		local itemName, buyer, bid, _, _, ahcut, _, _, quantity = Inbox.GetInvoiceInfo(index)
		buyer = buyer or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS or ""
		if buyer == "" and not resolveNames then
			-- Give up on resolving the buyer name
			buyer = "?"
		elseif buyer == "" then
			return false, true
		end
		if not private.CanLootMailIndex(index, bid - ahcut) then
			return false
		end
		-- 3.3.5: GetInboxInvoiceInfo не возвращает count — берём из attachment.
		if not quantity then
			quantity = private.GetQuantity(index, 1) or 1
		end
		local itemString = ItemInfo.ItemNameToItemString(itemName)
		if not itemString or itemString == ItemString.GetUnknown() then
			itemString = Auction.GetSaleHintItemString(itemName, quantity, bid)
		end
		if itemString then
			local copper = floor((bid - ahcut) / quantity + 0.5)
			local saleTime = (time() + (daysLeft - 30) * SECONDS_PER_DAY)
			TSM.Accounting.Transactions.InsertAuctionSale(itemString, quantity, copper, buyer, saleTime)
		else
			Log.Err("Failed to get itemString: %s", tostring(itemName))
		end
	elseif mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
		local _, buyer, bid, _, _, _, _, _, quantity = Inbox.GetInvoiceInfo(index)
		-- 3.3.5: GetInboxInvoiceInfo не возвращает count — берём из attachment.
		if not quantity then
			quantity = private.GetQuantity(index, 1) or 1
		end
		buyer = buyer or AUCTION_HOUSE_MAIL_MULTIPLE_SELLERS or ""
		if buyer == "" and not resolveNames then
			-- Give up on resolving the buyer name
			buyer = "?"
		elseif buyer == "" then
			return false, true
		end

		local isValid, itemString, itemQuantity = private.ValidateAuctionItemMail(index, subIndex)
		if not isValid then
			print(format("|cff33ff99TSMDBG|r accounting: buy mail #%d NOT recorded (validation failed - bag space / item link)", index))
			return false
		end
		local copper = floor(bid / quantity + 0.5)
		if not ClientInfo.IsVanillaClassic() then
			quantity = itemQuantity
		end
		local buyTime = (time() + (daysLeft - 30) * SECONDS_PER_DAY)
		TSM.Accounting.Transactions.InsertAuctionBuy(itemString, quantity, copper, buyer, buyTime)
		print(format("|cff33ff99TSMDBG|r accounting: recorded buy %s x%d @ %s copper (from %s)", tostring(itemString), quantity or 0, tostring(copper), tostring(buyer)))
	elseif mailType == Inbox.MAIL_TYPE.SALE.CRAFTING_ORDER then
		if not private.CanLootMailIndex(index, money) then
			return false
		end
		local _, craftingOrderComission, craftingOrderCustomer = Inbox.GetCraftingOrderInfo(index)
		local saleTime = (time() + (daysLeft - 30) * SECONDS_PER_DAY)
		TSM.Accounting.Money.InsertCraftingOrderIncome(craftingOrderComission, craftingOrderCustomer, saleTime)
	elseif mailType == Inbox.MAIL_TYPE.BUY.CRAFTING_ORDER then
		if not private.CanLootMailIndex(index, 0) then
			return false
		end
		local _, craftingOrderComission, craftingOrderCrafter = Inbox.GetCraftingOrderInfo(index)
		local buyTime = (time() + (daysLeft - 30) * SECONDS_PER_DAY)
		TSM.Accounting.Money.InsertCraftingOrderExpense(craftingOrderComission, craftingOrderCrafter, buyTime)
	elseif mailType == Inbox.MAIL_TYPE.LETTER.COD then
		local link = private.GetItemLink(index, subIndex or 1)
		local itemString = ItemString.Get(link)
		if not itemString then
			return false
		end
		-- COD Buys (only if all attachments are same item)
		local name = ItemInfo.GetName(link)
		local total = 0
		local stacks = 0
		for i = 1, Inbox.GetMaxAttachments() do
			local _, count, nameCheck = Inbox.GetAttachment(index, i)
			if count and nameCheck then
				if nameCheck == name then
					total = total + count
					stacks = stacks + 1
				else
					-- Multiple unique items, so just ignore
					return true
				end
			end
		end
		if total == 0 then
			-- No items (?), so just ignore
			return true
		end
		if not private.CanLootMailIndex(index, codAmount) then
			-- Don't bother recording
			return true
		end
		local copper = floor(codAmount / total + 0.5)
		local buyTime = (time() + (daysLeft - 3) * SECONDS_PER_DAY)
		local maxStack = ItemInfo.GetMaxStack(link)
		for _ = 1, stacks do
			local stackSize = (total >= maxStack) and maxStack or total
			TSM.Accounting.Transactions.InsertCODBuy(itemString, stackSize, copper, sender, buyTime)
			total = total - stackSize
			if total <= 0 then
				break
			end
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD then
		if not private.CanLootMailIndex(index, money) then
			return false
		end
		local str = nil
		if GetLocale() == "deDE" then
			str = gsub(subject, gsub(COD_PAYMENT, String.Escape("%1$s"), ""), "")
		else
			str = gsub(subject, gsub(COD_PAYMENT, String.Escape("%s"), ""), "")
		end
		local saleTime = (time() + (daysLeft - 31) * SECONDS_PER_DAY)
		if str and strfind(str, "TSM$") then
			-- Payment for a COD the player sent
			local codName = strtrim(strmatch(str, "([^%(]+)"))
			local qty = strmatch(str, "%(([0-9]+)%)")
			qty = tonumber(qty)
			local itemString = ItemInfo.ItemNameToItemString(codName)
			if itemString then
				local copper = floor(money / qty + 0.5)
				local maxStack = ItemInfo.GetMaxStack(itemString) or 1
				local stacks = ceil(qty / maxStack)

				for _ = 1, stacks do
					local stackSize = (qty >= maxStack) and maxStack or qty
					TSM.Accounting.Transactions.InsertCODSale(itemString, stackSize, copper, sender, saleTime)
					qty = qty - stackSize
					if qty <= 0 then
						break
					end
				end
			end
		else
			-- Record a money transfer
			TSM.Accounting.Money.InsertMoneyTransferIncome(money, sender, saleTime)
		end
	elseif mailType == Inbox.MAIL_TYPE.OTHER.GOLD_AND_ITEMS then
		if not private.CanLootMailIndex(index, money) then
			return false
		end
		local saleTime = (time() + (daysLeft - 31) * SECONDS_PER_DAY)
		TSM.Accounting.Money.InsertMoneyTransferIncome(money, sender, saleTime)
	elseif mailType == Inbox.MAIL_TYPE.EXPIRE.AUCTION then
		local isValid, itemString, quantity = private.ValidateAuctionItemMail(index, subIndex)
		if not isValid then
			return false
		end
		local expiredTime = (time() + (daysLeft - 30) * SECONDS_PER_DAY)
		TSM.Accounting.Auctions.InsertExpire(itemString, quantity, expiredTime)
	elseif mailType == Inbox.MAIL_TYPE.CANCEL.AUCTION then
		local isValid, itemString, quantity = private.ValidateAuctionItemMail(index, subIndex)
		if not isValid then
			return false
		end
		local cancelledTime = (time() + (daysLeft - 30) * SECONDS_PER_DAY)
		TSM.Accounting.Auctions.InsertCancel(itemString, quantity, cancelledTime)
	end
	return true
end

function private.ValidateAuctionItemMail(index, subIndex)
	if not private.CanLootMailIndex(index, 0) then
		return false
	end
	local link = private.GetItemLink(index, subIndex or 1)
	local quantity = private.GetQuantity(index, subIndex)
	local itemString = ItemString.Get(link)
	if not itemString then
		Log.Err("Failed to get itemString: %s, %s, %s", tostring(index), tostring(subIndex), tostring(link))
		return false
	elseif not quantity or quantity <= 0 then
		Log.Err("Invalid quantity for mail: index=%s subIndex=%s qty=%s", tostring(index), tostring(subIndex), tostring(quantity))
		return false
	end
	return true, itemString, quantity
end

function private.RescanHandler()
	private.ScanCollectedMail(unpack(private.rescanContext))
end



-- ============================================================================
-- Sending Functions
-- ============================================================================

-- scans the mail that the player just attempted to send (Pre-Hook) to see if COD
function private.CheckSendMail(destination, currentSubject, ...)
	local codAmount = GetSendMailCOD()
	local moneyAmount = GetSendMailMoney()
	local mailCost = GetSendMailPrice()
	local subject
	local total = 0
	local ignore = false

	if codAmount ~= 0 then
		for i = 1, 12 do
			local itemName, _, _, count = GetSendMailItem(i)
			if itemName and count then
				if not subject then
					subject = itemName
				end

				if subject == itemName then
					total = total + count
				else
					ignore = true
				end
			end
		end
	else
		ignore = true
	end

	-- 3.3.5: destination может быть пустым/nil при определённых сценариях
	-- (например quick-send с не-зарезолвенным recipient). InsertRecord
	-- assert'ит otherPlayer не-nil, поэтому пропускаем запись без получателя.
	local hasDest = destination and destination ~= ""
	if moneyAmount > 0 and hasDest then
		-- Add a record for the money transfer
		TSM.Accounting.Money.InsertMoneyTransferExpense(moneyAmount, destination)
		mailCost = mailCost - moneyAmount
	elseif moneyAmount > 0 then
		mailCost = mailCost - moneyAmount
	end
	if mailCost and mailCost > 0 and hasDest then
		TSM.Accounting.Money.InsertPostageExpense(mailCost, destination)
	end

	if not ignore then
		private.hooks.SendMail(destination, subject .. " (" .. total .. ") TSM", ...)
	else
		private.hooks.SendMail(destination, currentSubject, ...)
	end
end

function private.GetItemLink(index, attachIndex)
	local link = nil
	if attachIndex == 1 then
		-- Find the first attachment index with an item
		local foundIndex = nil
		for i = 1, Inbox.GetMaxAttachments() do
			link = Inbox.GetAttachment(index, i)
			if link then
				foundIndex = i
				break
			end
		end
		if not foundIndex then
			-- 3.3.5a: attachment data may not be loaded yet (mail still populating during
			-- auto-loot); return nil so the caller retries gracefully instead of crashing
			return nil
		end
		local speciesId, level, breedQuality = TooltipScanning.GetInboxBattlePetInfo(index, foundIndex)
		if speciesId and speciesId > 0 then
			link = ItemInfo.GetLink(strjoin(":", "p", speciesId, level, breedQuality))
		end
	end
	return link or Inbox.GetAttachment(index, attachIndex)
end

function private.GetQuantity(index, attachIndex)
	if attachIndex or ClientInfo.IsVanillaClassic() then
		local _, quantity = Inbox.GetAttachment(index, attachIndex or 1)
		return quantity or 0
	else
		local quantity = 0
		for i = 1, Inbox.GetMaxAttachments() do
			local _, count = Inbox.GetAttachment(index, i)
			quantity = quantity + (count or 0)
		end
		return quantity
	end
end
