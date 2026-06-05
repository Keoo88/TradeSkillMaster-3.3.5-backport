-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ChatEvent = LibTSMWoW:Init("Service.ChatEvent")
local Event = LibTSMWoW:Include("Service.Event")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local String = LibTSMWoW:From("LibTSMUtil"):Include("Lua.String")
local private = {
	lootHandlers = {},
}
local LOOT_PATTERN_STR = "^"..String.FormatToMatchPattern(LOOT_ITEM_PUSHED_SELF).."$"
local LOOT_MULTIPLE_PATTERN_STR = "^"..String.FormatToMatchPattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE).."$"



-- ============================================================================
-- Module Loading
-- ============================================================================

ChatEvent:OnModuleLoad(function()
	Event.Register("CHAT_MSG_LOOT", private.HandleLootEvent)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a handler for player loot messages.
---@param handler fun(itemLink: string, quantity: number) The handler
function ChatEvent.RegisterLootHandler(handler)
	tinsert(private.lootHandlers, handler)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLootEvent(_, msg)
	if ClientInfo.IsRetail() and issecretvalue(msg) then
		-- The message is a secret, so just ignore it
		return
	end
	if #private.lootHandlers == 0 then
		return
	end

	-- Check if this was a loot multiple message
	local itemLink, quantity = strmatch(msg, LOOT_MULTIPLE_PATTERN_STR)
	if itemLink then
		private.CallLootHandlers(itemLink, tonumber(quantity))
		return
	end

	-- Check if this was a loot message
	itemLink = strmatch(msg, LOOT_PATTERN_STR)
	if itemLink then
		private.CallLootHandlers(itemLink, 1)
		return
	end
end

function private.CallLootHandlers(itemLink, quantity)
	for _, handler in ipairs(private.lootHandlers) do
		handler(itemLink, quantity)
	end
end
