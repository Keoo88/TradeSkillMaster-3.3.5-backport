-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Mail = LibTSMService:Init("Mail")
local Scanner = LibTSMService:Include("Mail.Scanner")
local Util = LibTSMService:Include("Mail.Util")
local PendingMail = LibTSMService:Include("Mail.PendingMail")
local Expiring = LibTSMService:Include("Mail.Expiring")
local Contacts = LibTSMService:Include("Mail.Contacts")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Mail item quantities
---@param pendingMailData table<string,table<string,number>> Pending mail item quantities by character
---@param expiringData table<string,number> Expiring time by character
---@param settingsDB SettingsDB The settings DB which is used for looking up alt characters
---@param recentlyMailedData table<string,number> Recently mailed character data
---@param characterValidationFunc fun(character: string): string? Function used to validate character names for tracking pending mail
function Mail.Load(quantityData, pendingMailData, expiringData, settingsDB, recentlyMailedData, characterValidationFunc)
	Scanner.Load(quantityData)
	PendingMail.Load(pendingMailData, characterValidationFunc)
	Expiring.Load(expiringData)
	Contacts.Load(settingsDB, recentlyMailedData)
end

---Starts the mail code.
function Mail.Start()
	Scanner.Start()
	PendingMail.Start()
end

---Forces a mail inbox rescan after a delay (3.3.5 workaround for late inbox data).
---@param delaySeconds? number Delay before the rescan (default 1.0)
function Mail.ForceRescan(delaySeconds)
	Scanner.ForceRescan(delaySeconds)
end

---Registers a callback for when the quantity data changes.
---@param callback fun(updatedItems: table<string,true>) The callback function which is passed a table with the changed base item strings as keys
function Mail.RegisterQuantityCallback(callback)
	Scanner.RegisterQuantityCallback(callback)
end

---Registers a callback for when the mail data changes (fired after a scan completes).
---@param callback fun() The callback function
function Mail.RegisterMailCallback(callback)
	Scanner.RegisterMailCallback(callback)
end

---Registers a callback for when the expiring time changes.
---@param func fun()
function Mail.RegisterExpiresCallback(callback)
	Expiring.RegisterCallback(callback)
end

---Iterates over all known mail items and their quantity.
---@return fun(): number, string, number @Iterator with fields: `index`, `levelItemString`, `mailQuantity`
function Mail.QuantityIterator()
	return Scanner.QuantityIterator()
end

---Creates a new query against the mail DB.
---@return DatabaseQuery
function Mail.NewMailQuery()
	return Scanner.NewMailQuery()
end

---Creates a new query against the item DB.
---@return DatabaseQuery
function Mail.NewItemQuery()
	return Scanner.NewItemQuery()
end

---Gets the item link of the first attachment for an inbox mail.
---@param index number The mail index
---@return string?
function Mail.GetInboxItemLink(index)
	local itemLink = Util.GetAttachment(index, 1)
	return itemLink
end

---Gets the quantity of an item in the mail.
---@param itemString string The item string
---@return number
function Mail.GetQuantity(itemString)
	return Scanner.GetQuantity(itemString)
end

---Handles an auction purchase by updating the pending mail data.
---@param levelItemString string The level item string
---@param stackSize number The stack size
function Mail.HandleAuctionPurchase(levelItemString, stackSize)
	PendingMail.HandleAuctionPurchase(levelItemString, stackSize)
end

---Iterates over recently mailed characters.
---@return fun(): string @Iterator with fields: `name`
function Mail.RecentContactsIterator()
	return Contacts.RecentIterator()
end

---Iterates over alt characters.
---@param regionWide boolean Whether or not to include region-wide data.
---@return fun(): string @Iterator with fields: `name`
function Mail.AltContactsIterator(regionWide)
	return Contacts.AltIterator(regionWide)
end

---Iterates over friend characters.
---@return fun(): string @Iterator with fields: `name`
function Mail.FriendContactsIterator()
	return Contacts.FriendsIterator()
end

---Iterates over guild characters.
---@return fun(): string @Iterator with fields: `name`
function Mail.GuildContactsIterator()
	return Contacts.GuildIterator()
end

---Removes a recent contact.
---@param name string The character name
function Mail.RemoveRecentContact(name)
	Contacts.RemoveRecent(name)
end
