-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Log = LibTSMUtil:Init("Util.Log")
local DebugStack = LibTSMUtil:Include("Lua.DebugStack")
local private = {
	severity = {},
	location = {},
	timeStr = {},
	msg = {},
	writeIndex = 1,
	len = 0,
	temp = {},
	logToChat = false,
	currentThreadNameFunc = nil,
	stackLevel = 3,
	overrideLocation = nil,
}
local MAX_ROWS = 200
local MAX_MSG_LEN = 200
---@alias LogSeverity
---|'"TRACE"'
---|'"INFO"'
---|'"WARN"'
---|'"ERR"'
local CHAT_LOG_COLOR_PREFIX = {
	TRACE = "|cff2076f7",
	INFO = "|cff4ff720",
	WARN = "|cffe1f720",
	ERR = "|cfff72d20",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a function for getting the name of the current thread to include in log messages.
---@param func fun(): string A function which returns the name of the currently-running thread
function Log.SetCurrentThreadNameFunction(func)
	private.currentThreadNameFunc = func
end

---Enables or disables printing log messages to chat.
---@param enabled boolean The logging state to set
---@param ignoreBuffered boolean Ignore any buffered logs
function Log.SetLoggingToChatEnabled(enabled, ignoreBuffered)
	if private.logToChat == enabled then
		return
	end
	private.logToChat = enabled
	if enabled and not ignoreBuffered then
		-- dump our buffer
		local len = Log.Length()
		if len == 0 then
			return
		end
		print(format("Printing %d buffered logs:", len))
		for i = 1, len do
			private.LogToChat(Log.Get(i))
		end
	end
end

---Gets the length of the log buffer.
---@return number
function Log.Length()
	return private.len
end

---Gets a log entry from the log buffer.
---@param index number The index within the buffer
---@return LogSeverity severity
---@return string location
---@return string timeStr
---@return string msg
function Log.Get(index)
	assert(index <= private.len)
	local readIndex = (private.writeIndex - private.len + index - 2) % MAX_ROWS + 1
	return private.severity[readIndex], private.location[readIndex], private.timeStr[readIndex], private.msg[readIndex]
end

---Raises the stack level of log messages.
function Log.RaiseStackLevel()
	private.stackLevel = private.stackLevel + 1
end

---Lowers the stack level of log messages.
function Log.LowerStackLevel()
	private.stackLevel = private.stackLevel - 1
end

---Logs a stack trace.
---@param maxLines? number The maximum number of lines (defaults to all available)
function Log.StackTrace(maxLines)
	maxLines = maxLines or math.huge
	private.Log("TRACE", "Stack Trace:")
	local level = 2
	local line = DebugStack.GetLocation(level)
	while line and maxLines > 0 do
		private.Log("TRACE", "  " .. line)
		level = level + 1
		line = DebugStack.GetLocation(level)
		maxLines = maxLines - 1
	end
end

---Logs a formatted message at the info level.
---@param ... string
function Log.Info(...)
	private.Log("INFO", ...)
end

---Logs a formatted message at the warning level.
---@param ... string
function Log.Warn(...)
	private.Log("WARN", ...)
end

---Logs a formatted message at the error level.
---@param ... string
function Log.Err(...)
	private.Log("ERR", ...)
end

---Logs a formatted message with custom options.
---@param severity LogSeverity
---@param location string The location for the log message
---@param ... string
function Log.Custom(severity, location, ...)
	private.overrideLocation = location
	private.Log(severity, ...)
	assert(not private.overrideLocation)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Log(severity, fmtStr, ...)
	assert(type(fmtStr) == "string" and CHAT_LOG_COLOR_PREFIX[severity])
	wipe(private.temp)
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		if type(arg) == "boolean" then
			arg = arg and "T" or "F"
		elseif type(arg) ~= "string" and type(arg) ~= "number" then
			arg = tostring(arg)
		end
		private.temp[i] = arg
	end
	-- ignore anything after a newline in the log message
	local msg = strsplit("\n", format(fmtStr, unpack(private.temp)))
	if #msg > MAX_MSG_LEN then
		msg = strsub(msg, 1, -4).."..."
	end
	local location = nil
	if private.overrideLocation then
		location = private.overrideLocation
		private.overrideLocation = nil
	else
		location = DebugStack.GetLocation(private.stackLevel)
		location = location and strmatch(location, "([^\\/]+%.lua:[0-9]+)") or "?:?"
	end
	local threadName = private.currentThreadNameFunc and private.currentThreadNameFunc() or nil
	if threadName then
		location = location.."|"..threadName
	end
	local timeMs = LibTSMUtil.GetTime() * 1000
	local timeStr = format("%s.%03d", date("%H:%M:%S", floor(timeMs / 1000)), timeMs % 1000)

	-- append the log
	private.severity[private.writeIndex] = severity
	private.location[private.writeIndex] = location
	private.timeStr[private.writeIndex] = timeStr
	private.msg[private.writeIndex] = msg
	private.writeIndex = (private.writeIndex < MAX_ROWS) and (private.writeIndex + 1) or 1
	private.len = min(private.len + 1, MAX_ROWS)

	if private.logToChat then
		private.LogToChat(severity, location, timeStr, msg)
	end
end

function private.LogToChat(severity, location, timeStr, msg)
	print(strjoin(" ", timeStr, CHAT_LOG_COLOR_PREFIX[severity].."{"..location.."}|r", msg))
end
