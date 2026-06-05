-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Scanner = LibTSMService:Init("Mail.Scanner")
local Util = LibTSMService:Include("Mail.Util")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Database = LibTSMService:From("LibTSMUtil"):Include("Database")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local private = {
	quantityStorage = nil,
	mailDB = nil,
	itemDB = nil,
	quantityDB = nil,
	baseItemQuantityQuery = nil,
	mailCallbacks = {},
	quantityCallbacks = {},
	scanTimer = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Scanner:OnModuleLoad(function()
	private.mailDB = Database.NewSchema("MAIL_TRACKING_INBOX_INFO")
		:AddUniqueNumberField("index")
		:AddEnumField("type", Inbox.MAIL_TYPE)
		:AddStringField("sender")
		:AddStringField("subject")
		:AddStringField("itemString")
		:AddSmartMapField("levelItemString", ItemString.GetLevelMap(), "itemString")
		:AddNumberField("itemCount")
		:AddNumberField("money")
		:AddNumberField("cost")
		:AddNumberField("expires")
		:AddIndex("index")
		:Commit()
	private.itemDB = Database.NewSchema("MAIL_TRACKING_INBOX_ITEMS")
		:AddNumberField("index")
		:AddNumberField("itemIndex")
		:AddStringField("itemLink")
		:AddNumberField("quantity")
		:Commit()
	private.quantityDB = Database.NewSchema("MAIL_TRACKING_QUANTITY")
		:AddUniqueStringField("levelItemString")
		:AddNumberField("mailQuantity")
		:AddSmartMapField("baseItemString", ItemString.GetBaseMap(), "levelItemString")
		:AddIndex("baseItemString")
		:Commit()
	private.baseItemQuantityQuery = private.quantityDB:NewQuery()
		:Select("mailQuantity")
		:Equal("baseItemString", Database.BoundQueryParam())
	private.scanTimer = DelayTimer.New("MAIL_TRACKING_SCAN", private.MailInboxUpdateDelayed)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Mail item quantities
function Scanner.Load(quantityData)
	private.quantityStorage = quantityData
end

---Starts the scanner.
function Scanner.Start()
	Event.Register("MAIL_INBOX_UPDATE", function() private.scanTimer:RunForFrames(1) end)
end

---Forces a mail inbox rescan after a delay. 3.3.5 may fire MAIL_INBOX_UPDATE
---before the server has actually delivered the inbox payload, leaving the DB
---empty after the first mailbox open. The UI calls this on EV_MAIL_SHOW to
---kick off a delayed rescan once data has arrived.
---@param delaySeconds? number Delay before the rescan (default 1.0)
function Scanner.ForceRescan(delaySeconds)
	private.scanTimer:RunForTime(delaySeconds or 1.0)
end

---Registers a callback for when the mail data changes.
---@param callback fun() The callback function
function Scanner.RegisterMailCallback(callback)
	tinsert(private.mailCallbacks, callback)
end

---Registers a callback for when the quantity data changes.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function Scanner.RegisterQuantityCallback(callback)
	tinsert(private.quantityCallbacks, callback)
end

---Creates a new query against the mail DB.
---@return DatabaseQuery
function Scanner.NewMailQuery()
	return private.mailDB:NewQuery()
end

---Creates a new query against the item DB.
---@return DatabaseQuery
function Scanner.NewItemQuery()
	return private.itemDB:NewQuery()
end

---Gets the quantity of an item in the mail.
---@param itemString string The item string
---@return number
function Scanner.GetQuantity(itemString)
	if not ItemString.IsLevel(itemString) and itemString == ItemString.GetBaseFast(itemString) then
		return private.baseItemQuantityQuery
			:BindParams(itemString)
			:Sum("mailQuantity")
	else
		local levelItemString = ItemString.ToLevel(itemString)
		return private.quantityDB:GetUniqueRowField("levelItemString", levelItemString, "mailQuantity") or 0
	end
end

---Iterates over all known mail items and their quantity.
---@return fun(): number, string, number @Iterator with fields: `index`, `levelItemString`, `mailQuantity`
function Scanner.QuantityIterator()
	return private.quantityDB:NewQuery()
		:Select("levelItemString", "mailQuantity")
		:IteratorAndRelease()
end

---Inserts pending mail.
---@param pendingMail table<string,number> Pending mail data
function Scanner.InsertPendingMail(pendingMail)
	private.quantityDB:BulkInsertStart()
	for levelItemString, quantity in pairs(pendingMail) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
end

---Handles a pending mail quantity change.
---@param levelItemString string The level item string
---@param changeQuantity number The change quantity (positive or negative)
function Scanner.HandlePendingMailChange(levelItemString, changeQuantity)
	assert(changeQuantity ~= 0)
	local row = private.quantityDB:GetUniqueRow("levelItemString", levelItemString)
	local newValue = nil
	if row then
		newValue = row:GetField("mailQuantity") + changeQuantity
		assert(newValue >= 0)
		if newValue == 0 then
			-- Remove this row
			private.quantityDB:DeleteRow(row)
		else
			-- Update this row
			row:SetField("mailQuantity", newValue)
				:Update()
		end
		row:Release()
	else
		-- Create a new row
		assert(changeQuantity > 0)
		newValue = changeQuantity
		private.quantityDB:NewRow()
			:SetField("levelItemString", levelItemString)
			:SetField("mailQuantity", changeQuantity)
			:Create()
	end
	local updatedItems = TempTable.Acquire()
	updatedItems[levelItemString] = true
	updatedItems[ItemString.GetBaseFast(levelItemString)] = true
	for _, callback in ipairs(private.quantityCallbacks) do
		callback(updatedItems)
	end
	TempTable.Release(updatedItems)
end



-- ============================================================================
-- Event Handlers
-- ============================================================================

function private.MailInboxUpdateDelayed()
	if not DefaultUI.IsMailVisible() then
		if TSMDBG then TSMDBG.Log("MailScan", "skipped: mail not visible") end
		return
	end
	local numMails = Inbox.GetNumItems()
	if TSMDBG then TSMDBG.Log("MailScan", "start numMails=%d", numMails) end

	wipe(private.quantityStorage)
	private.mailDB:TruncateAndBulkInsertStart()
	private.itemDB:TruncateAndBulkInsertStart()
	for i = 1, numMails do
		local sender, money, cost, itemCount, subject, daysLeft = Inbox.GetHeaderInfo(i)
		if TSMDBG then TSMDBG.Log("MailScan", "mail %d sender=%s subj=%s money=%s items=%s expires=%s",
			i, tostring(sender), tostring(subject), tostring(money), tostring(itemCount), tostring(daysLeft)) end
		if money and money > 0 then
			private.itemDB:BulkInsertNewRow(i, 0, tostring(money), 0)
		end

		local firstItemString = nil
		for j = 1, Inbox.GetMaxAttachments() do
			local itemLink, quantity = Util.GetAttachment(i, j)
			local itemString = itemLink and ItemString.Get(itemLink) or nil
			if itemString then
				firstItemString = firstItemString or itemString
				local levelItemString = ItemString.ToLevel(itemString)
				private.quantityStorage[levelItemString] = (private.quantityStorage[levelItemString] or 0) + quantity
				private.itemDB:BulkInsertNewRow(i, j, itemLink, quantity)
			end
		end

		local mailType = nil
		local ok, mt = pcall(Inbox.GetMailType, i)
		if ok then
			mailType = mt
		else
			if TSMDBG then TSMDBG.Warn("MailScan", "GetMailType failed for mail %d: %s", i, tostring(mt)) end
		end
		if mailType == Inbox.MAIL_TYPE.BUY.AUCTION then
			local _, _, bid = Inbox.GetInvoiceInfo(i)
			cost = bid
		end

		private.mailDB:BulkInsertNewRow(i, mailType or Inbox.MAIL_TYPE.OTHER.ITEMS, sender or "", subject or "--", firstItemString or ItemString.GetUnknown(), itemCount or 0, money or 0, cost or 0, daysLeft)
	end
	local prevQuantities = TempTable.Acquire()
	private.quantityDB:NewQuery()
		:Select("levelItemString", "mailQuantity")
		:AsTable(prevQuantities)
		:Release()
	private.quantityDB:TruncateAndBulkInsertStart()
	for levelItemString, quantity in pairs(private.quantityStorage) do
		private.quantityDB:BulkInsertNewRow(levelItemString, quantity)
	end
	private.quantityDB:BulkInsertEnd()
	local updatedItems = TempTable.Acquire()
	Table.GetChangedKeys(prevQuantities, private.quantityStorage, updatedItems)
	TempTable.Release(prevQuantities)
	private.itemDB:BulkInsertEnd()
	private.mailDB:BulkInsertEnd()

	for _, callback in ipairs(private.mailCallbacks) do
		callback()
	end

	if next(updatedItems) then
		-- Add the base items
		local baseItemStrings = TempTable.Acquire()
		for levelItemString in pairs(updatedItems) do
			baseItemStrings[ItemString.GetBaseFast(levelItemString)] = true
		end
		for baseItemString in pairs(baseItemStrings) do
			updatedItems[baseItemString] = true
		end
		TempTable.Release(baseItemStrings)
		for _, callback in ipairs(private.quantityCallbacks) do
			callback(updatedItems)
		end
	end
	TempTable.Release(updatedItems)
end
