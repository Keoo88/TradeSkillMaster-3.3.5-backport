-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ChatFrame = LibTSMWoW:Init("API.ChatFrame")
local private = {
	active = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Sets the active chat frame to add messages to.
---@param name string The name of the chat frame
function ChatFrame.SetActive(name)
	private.active = strlower(name)
end

---Adds a message to the active chat frame.
---@param str string The message
function ChatFrame.AddMessage(str)
	local frame = DEFAULT_CHAT_FRAME
	for i = 1, NUM_CHAT_WINDOWS do
		local name = strlower(GetChatWindowInfo(i) or "")
		if name ~= "" and name == private.active then
			frame = _G["ChatFrame" .. i]
			break
		end
	end
	frame:AddMessage(str)
end

---Adds a filter function for chat messages.
---@param func function
function ChatFrame.AddMessageFilter(func)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", func)
end

---Suppresses auction messages from showing in chat.
function ChatFrame.SuppressAuctionMessages()
	local funcTable = _G
	-- luacheck: globals ElvUI
	if C_AddOns.IsAddOnLoaded("ElvUI") and ElvUI then
		local tbl, _, settings = unpack(ElvUI)
		if settings.chat.enable then
			funcTable = tbl:GetModule("Chat")
		end
	end
	local origChatFrameOnEvent = funcTable.ChatFrame_OnEvent
	funcTable.ChatFrame_OnEvent = function(self, event, msg, ...)
		-- Suppress auction created / cancelled spam
		if event == "CHAT_MSG_SYSTEM" and (msg == ERR_AUCTION_STARTED or msg == ERR_AUCTION_REMOVED) then
			return
		end
		return origChatFrameOnEvent(self, event, msg, ...)
	end
end
