-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Mail = LibTSMUI:From("LibTSMService"):Include("Mail")
local private = {
	charactersTemp = {},
}
local ID_SEP = "`"



-- ============================================================================
-- Element Definition
-- ============================================================================

local MailContactsDialog = UIElements.Define("MailContactsDialog", "MenuDialog")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Configures the mail contacts dialog.
---@param regionWide boolean Whether or not to show region-wide alt characters.
---@return MailContactsDialog
function MailContactsDialog:Configure(regionWide)
	self.__super:Configure("")
	self:SetDataUpdatesPaused(true)
	self:_AddMenuDialogCharacterRows("RECENT", L["Recent"], Mail.RecentContactsIterator())
	self:EnableDeletion("RECENT")
	self:_AddMenuDialogCharacterRows("ALTS", L["Alts"], Mail.AltContactsIterator(regionWide))
	self:_AddMenuDialogCharacterRows("FRIENDS", L["Friends"], Mail.FriendContactsIterator())
	self:_AddMenuDialogCharacterRows("GUILD", L["Guild"], Mail.GuildContactsIterator())
	self:SetDataUpdatesPaused(false)
	return self
end

---Sets the UI manager action to send for one of the element's scripts.
---@param script string The script to send the action for
---@param action string The action to send (along with any arguments)
---@return MailContactsDialog
function MailContactsDialog:SetAction(script, action)
	assert(script == "OnRowClick")
	self.__super:SetAction(script, action)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MailContactsDialog.__private:_AddMenuDialogCharacterRows(parentId, label, ...)
	assert(#private.charactersTemp == 0)
	for name in ... do
		tinsert(private.charactersTemp, name)
	end
	if #private.charactersTemp == 0 then
		return
	end
	sort(private.charactersTemp)
	self:AddRow(parentId, "", label)
	for _, character in ipairs(private.charactersTemp) do
		self:AddRow(parentId..ID_SEP..character, parentId, character)
	end
	wipe(private.charactersTemp)
end

function MailContactsDialog.__protected:_SendActionScript(script, menuDialog, id1, id2, extra)
	-- Hook and overwrite action scripts
	assert(script == "OnRowClick" or script == "OnRowDelete")
	assert(menuDialog == self)
	assert(id1 and id2 and not extra)
	local character = select(2, strsplit(ID_SEP, id2))
	if script == "OnRowClick" then
		self.__super:_SendActionScript(script, character)
		self:GetBaseElement():HideDialog()
	elseif script == "OnRowDelete" then
		assert(id1 == "RECENT")
		Mail.RemoveRecentContact(character)
		local hasRecent = false
		for _ in Mail.RecentContactsIterator() do
			hasRecent = true
		end
		if hasRecent then
			self:RemoveRow(id2)
		else
			self:RemoveRow("RECENT")
			self:RemoveChild(self:GetElement("subMenu"))
			self:Draw()
		end
	else
		error("Unknown action script: "..tostring(script))
	end
end
