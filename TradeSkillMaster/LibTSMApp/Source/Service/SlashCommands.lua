-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local SlashCommands = LibTSMApp:Init("Service.SlashCommands")
local Log = LibTSMApp:From("LibTSMUtil"):Include("Util.Log")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local SlashCommandList = LibTSMApp:From("LibTSMWoW"):Include("UI.SlashCommandList")
local private = {
	baseCommandInfo = nil,
	commandInfo = {},
	commandOrder = {},
	debugCommandInfo = {},
}
local CALLBACK_TIME_WARNING = 0.02



-- ============================================================================
-- Module Loading
-- ============================================================================

SlashCommands:OnModuleLoad(function()
	-- Register the TSM slash commands
	SlashCommandList.Add("tsm", private.OnChatCommand)
	SlashCommandList.Add("tradeskillmaster", private.OnChatCommand)
	SlashCommands.Register("help", private.PrintHelp, L["Prints the slash command help listing"])
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function SlashCommands.Register(key, callback, label)
	assert(key and callback and label)
	local keyLower = strlower(key)
	assert(not private.commandInfo[keyLower])
	private.commandInfo[keyLower] = {
		key = key,
		callback = callback,
		label = label,
	}
	tinsert(private.commandOrder, keyLower)
end

function SlashCommands.RegisterBase(callback, label)
	assert(callback and label and not private.baseCommandInfo)
	private.baseCommandInfo = {
		callback = callback,
		label = label,
	}
end

function SlashCommands.RegisterDebug(key, callback)
	assert(key and callback)
	local keyLower = strlower(key)
	private.debugCommandInfo[keyLower] = {
		key = key,
		callback = callback,
	}
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnChatCommand(input)
	input = strtrim(input)
	local cmd, args = strmatch(input, "^([^ ]*) ?(.*)$")
	cmd = strlower(cmd)
	if cmd == "debug" then
		cmd, args = strmatch(args, "^([^ ]*) ?(.*)$")
		local info = private.debugCommandInfo[cmd]
		if not info then
			-- Just silently ignore invalid debug commands
			return
		end
		info.callback(args)
	elseif cmd == "" and private.baseCommandInfo then
		private.RunCommand(private.baseCommandInfo, args, input)
	elseif private.commandInfo[cmd] then
		private.RunCommand(private.commandInfo[cmd], args, input)
	else
		-- We weren't able to handle this command so print out the help
		private.PrintHelp()
	end
end

function private.PrintHelp()
	ChatMessage.PrintUser(L["Slash Commands:"])
	if private.baseCommandInfo then
		ChatMessage.PrintfUserRaw("|cffffaa00/tsm|r - %s", private.baseCommandInfo.label)
	end
	for _, key in ipairs(private.commandOrder) do
		local info = private.commandInfo[key]
		ChatMessage.PrintfUserRaw("|cffffaa00/tsm %s|r - %s", info.key, info.label)
	end
end

function private.RunCommand(info, args, input)
	local startTime = LibTSMApp.GetTime()
	info.callback(args)
	local timeTaken = LibTSMApp.GetTime() - startTime
	if timeTaken > CALLBACK_TIME_WARNING then
		Log.Warn("Handler for slash command (/tsm%s) took %0.5fs", input ~= "" and " "..input or input, timeTaken)
	end
end
