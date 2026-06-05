-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Inbox = LibTSMWoW:Init("API.Inbox")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local MAIL_TYPE = EnumType.NewNested("MAIL_TYPE", {
	SALE = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
	},
	BUY = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
	},
	CANCEL = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
		BID = EnumType.NewValue(),
	},
	EXPIRE = {
		AUCTION = EnumType.NewValue(),
		CRAFTING_ORDER = EnumType.NewValue(),
	},
	LETTER = {
		GM = EnumType.NewValue(),
		COD = EnumType.NewValue(),
		EMPTY = EnumType.NewValue(),
	},
	OTHER = {
		TEMP_INVOICE = EnumType.NewValue(),
		OUTBID = EnumType.NewValue(),
		GOLD_AND_ITEMS = EnumType.NewValue(),
		GOLD = EnumType.NewValue(),
		ITEMS = EnumType.NewValue(),
	},
})
Inbox.MAIL_TYPE = MAIL_TYPE
local EXPIRED_MATCH_TEXT = gsub(AUCTION_EXPIRED_MAIL_SUBJECT, "%%s", "")
local CANCELLED_MATCH_TEXT = gsub(AUCTION_REMOVED_MAIL_SUBJECT, "%%s", "")
local OUTBID_MATCH_TEXT = gsub(AUCTION_OUTBID_MAIL_SUBJECT, "%%s", "(.+)")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the number of inbox mail items.
---@return number numItems
---@return number totalItems
function Inbox.GetNumItems()
	return GetInboxNumItems()
end

---Gets header info.
---@param index number The mail index
---@return string sender
---@return number money
---@return number cod
---@return number numItems
---@return string subject
---@return number daysLeft
---@return boolean textCreated
---@return boolean isGM
---@return boolean canReply
---@return number texture
function Inbox.GetHeaderInfo(index)
	local _, texture, sender, subject, money, cod, daysLeft, numItems, _, _, textCreated, canReply, isGM = GetInboxHeaderInfo(index)
	return sender, money or 0, cod or 0, numItems or 0, subject, daysLeft, textCreated, isGM, canReply, texture
end

---Gets invoice info.
---@param index number The mail index
---@return string? itemName
---@return string? playerName
---@return number bid
---@return number buyout
---@return number deposit
---@return number consignment
---@return number? etaHour
---@return number? etaMin
---@return number? count
function Inbox.GetInvoiceInfo(index)
	local _, itemName, playerName, bid, buyout, deposit, consignment, _, etaHour, etaMin, count = GetInboxInvoiceInfo(index)
	return itemName, playerName, bid, buyout, deposit, consignment, etaHour, etaMin, count
end

---Gets the crafting order info for a mail.
---@param index number The mail index
---@return number? reason
---@return number? commissionPaid
---@return string? playerName
---@return string? recipeName
function Inbox.GetCraftingOrderInfo(index)
	local info = C_Mail.GetCraftingOrderMailInfo(index)
	if info.reason == Enum.RcoCloseReason.RcoCloseFulfill and not info.crafterName then
		return nil, nil, nil, nil
	end
	return info.reason, info.commissionPaid, info.customerName or info.crafterName, info.recipeName
end

---Gets the type of a mail.
---@param index index The mail index
---@return EnumValue
function Inbox.GetMailType(index)
	-- Check if this is auction sale / buy mail
	local invoiceType = GetInboxInvoiceInfo(index)
	if invoiceType == "seller" then
		return MAIL_TYPE.SALE.AUCTION
	elseif invoiceType == "seller_temp_invoice" then
		return MAIL_TYPE.OTHER.TEMP_INVOICE
	elseif invoiceType == "buyer" then
		return MAIL_TYPE.BUY.AUCTION
	end

	-- Check for letters
	local sender, money, cod, numItems, subject, _, _, isGM, canReply = Inbox.GetHeaderInfo(index)
	if isGM then
		return MAIL_TYPE.LETTER.GM
	elseif cod > 0 then
		return MAIL_TYPE.LETTER.COD
	elseif money == 0 and numItems == 0 then
		return MAIL_TYPE.LETTER.EMPTY
	end

	-- Check if this is a crafting order mail (this is deferred as much as possible since it creates a table)
	if not canReply and sender == ARTISANS_CONSORTIUM and ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_ORDERS) then
		local reason = Inbox.GetCraftingOrderInfo(index)
		if reason == Enum.RcoCloseReason.RcoCloseCancel then
			return MAIL_TYPE.CANCEL.CRAFTING_ORDER
		elseif reason == Enum.RcoCloseReason.RcoCloseExpire then
			return MAIL_TYPE.EXPIRE.CRAFTING_ORDER
		elseif reason == Enum.RcoCloseReason.RcoCloseCrafterFulfill then
			return MAIL_TYPE.SALE.CRAFTING_ORDER
		elseif reason == Enum.RcoCloseReason.RcoCloseFulfill then
			return MAIL_TYPE.BUY.CRAFTING_ORDER
		end
	end

	-- Check for other auction mail
	if strfind(subject, CANCELLED_MATCH_TEXT) then
		if money > 0 then
			return MAIL_TYPE.CANCEL.BID
		else
			return MAIL_TYPE.CANCEL.AUCTION
		end
	elseif strfind(subject, EXPIRED_MATCH_TEXT) then
		return MAIL_TYPE.EXPIRE.AUCTION
	elseif strfind(subject, OUTBID_MATCH_TEXT) then
		return MAIL_TYPE.OTHER.OUTBID
	end

	-- Check for other mail types
	if money > 0 and numItems > 0 then
		return MAIL_TYPE.OTHER.GOLD_AND_ITEMS
	elseif money > 0 then
		return MAIL_TYPE.OTHER.GOLD
	else
		assert(numItems > 0)
		return MAIL_TYPE.OTHER.ITEMS
	end
end

---Gets the text of a mail.
---@param index index The mail index
---@return string body
---@return boolean isTakeable
function Inbox.GetText(index)
	local body, _, _, isTakeable = GetInboxText(index)
	return body, isTakeable
end

---Gets the max number of attachment that can be in a received mail.
---@return number
function Inbox.GetMaxAttachments()
	return ATTACHMENTS_MAX_RECEIVE
end

---Gets info on a mail attachment.
---@param index number The mail index
---@param attachIndex number The attachment index
---@return string itemLink
---@return number quantity
---@return string name
function Inbox.GetAttachment(index, attachIndex)
	local name, _, _, stackSize = GetInboxItem(index, attachIndex)
	local itemLink = GetInboxItemLink(index, attachIndex)
	return itemLink, stackSize, name
end

---Gets the max number of attachment that can be sent.
---@return number
function Inbox.GetMaxSendAttachments()
	return ATTACHMENTS_MAX_SEND
end

---Gets info on a send attachment.
---@param index number The attachment index
---@return string itemLink
---@return number quantity
function Inbox.GetSendAttachment(index)
	local itemLink = GetSendMailItemLink(index)
	local _, _, _, quantity = GetSendMailItem(index)
	return itemLink, quantity
end

---Register a secure hook function for when mail is sent.
---@param func fun(target: string) The function to call
function Inbox.SecureHookSendMail(func)
	hooksecurefunc("SendMail", func)
end

---Register a secure hook function for when mail is returned.
---@param func fun(index: number) The function to call
function Inbox.SecureHookReturnMail(func)
	hooksecurefunc("ReturnInboxItem", func)
end
