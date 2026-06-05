-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Guild = LibTSMWoW:Init("API.Guild")
local private = {}
-- Don't use MAX_GUILDBANK_SLOTS_PER_TAB since it isn't available right away
local GUILD_BANK_TAB_SLOTS = 98



-- ============================================================================
-- Module Functions
-- ============================================================================

---Return whether or not the player is in a guild.
---@return boolean
function Guild.IsInGuild()
	return IsInGuild() and true or false
end

---Gets the name of the current guild if any.
---@return string?
function Guild.GetName()
	local name = GetGuildInfo("player")
	return name
end

---Returns whether or not the player is the guild leader.
---@return boolean
function Guild.IsLeader()
	return IsGuildLeader()
end

---Iterates over the members in the guild.
---@return fun(): number, string, boolean @Iterator with fields: `index`, `name`, `isLeader`
function Guild.MemberIterator()
	return private.MemberIterator, nil, 0
end

---Gets the amount of gold in the guild bank.
---@return number
function Guild.GetMoney()
	return GetGuildBankMoney()
end

---Gets the amount of money that can be widthdrawn from the guild bank.
---@return number
function Guild.GetWidthdrawMoney()
	return GetGuildBankWithdrawMoney()
end

---Gets the number of slots available in a guild bank tab.
---@return number
function Guild.GetNumTabSlots()
	return GUILD_BANK_TAB_SLOTS
end

---Gets the currently-loaded guild bank tab.
---@return number
function Guild.GetCurrentTab()
	return GetCurrentGuildBankTab()
end

---Queries a guild bank tab to load its data.
---@param tab number The tab index
function Guild.QueryTab(tab)
	QueryGuildBankTab(tab)
end

---Queries all the guild bank tabs to load their data.
function Guild.QueryAllTabs()
	local initialTab = Guild.GetCurrentTab()
	for i = 1, Guild.GetNumTabs() do
		Guild.QueryTab(i)
	end
	Guild.QueryTab(initialTab)
end

---Gets the number of guild bank tabs.
---@return number
function Guild.GetNumTabs()
	return GetNumGuildBankTabs()
end

---Gets the number of daily withdrawals for a guild bank tab.
---@param tab number The tab index
---@return number
function Guild.GetNumDailyWithdrawals(tab)
	local _, _, _, _, numWithdrawals = GetGuildBankTabInfo(tab)
	return numWithdrawals
end

---Gets the item link for a given guild bank slot.
---@param tab number The tab index
---@param slot number The slot index
---@return string
function Guild.GetItemLink(tab, slot)
	return GetGuildBankItemLink(tab, slot)
end

---Gets the number of items in a guild bank slot.
---@param tab number The tab index
---@param slot number The slot index
---@return number
function Guild.GetItemCount(tab, slot)
	local _, itemCount = GetGuildBankItemInfo(tab, slot)
	return itemCount or 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.MemberIterator(_, index)
	index = index + 1
	if index > GetNumGuildMembers() then
		return
	end
	local name, _, rankIndex = GetGuildRosterInfo(index)
	return index, name, rankIndex == 0
end
