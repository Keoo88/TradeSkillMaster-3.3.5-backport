-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local ChatMessage = LibTSMService:Init("UI.ChatMessage")
local Theme = LibTSMService:Include("UI.Theme")
local ChatFrame = LibTSMService:From("LibTSMWoW"):Include("API.ChatFrame")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Prints a raw user-facing message to chat.
---@param str string The message
function ChatMessage.PrintUserRaw(str)
	ChatFrame.AddMessage(str)
end

---Prints a raw, formatted user-facing message to chat.
---@param ... string The message
function ChatMessage.PrintfUserRaw(...)
	ChatMessage.PrintUserRaw(format(...))
end

---Prints a user-facing message to chat.
---@param str string The message
function ChatMessage.PrintUser(str)
	ChatMessage.PrintUserRaw(Theme.GetColor("INDICATOR"):ColorText("TSM")..": "..str)
end

---Prints a formatted user-facing message to chat.
---@param ... string The message
function ChatMessage.PrintfUser(...)
	ChatMessage.PrintUser(format(...))
end

---Colors some accent text for display to the user.
---@param text string The text to color
---@return string
function ChatMessage.ColorUserAccentText(text)
	return Theme.GetColor("INDICATOR_ALT"):ColorText(text)
end
