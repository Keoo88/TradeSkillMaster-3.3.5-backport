-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local ErrorHandler = LibTSMService:Init("Debug.ErrorHandler")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local Addon = LibTSMService:From("LibTSMWoW"):Include("API.Addon")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local Debug = LibTSMService:From("LibTSMWoW"):Include("Util.Debug")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local Addons = LibTSMService:From("LibTSMData"):Include("Addons")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local JSON = LibTSMService:From("LibTSMUtil"):Include("Format.JSON")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local ObjectPool = LibTSMService:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local private = {
	uiShowFunc = nil,
	uiHideFunc = nil,
	isShown = false,
	errorSuppressed = nil,
	errorReports = {},
	num = 0,
	localLinesTemp = {},
	hitInternalError = false,
	ignoreErrors = false,
	globalNameTranslation = {},
	globalNameTranslationFuncs = {},
}
local MAX_ERROR_REPORT_AGE = 7 * 24 * 60 * 60 -- 1 week
local MAX_STACK_DEPTH = 50
local PRINT_PREFIX = "|cffff0000TSM:|r "



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the UI callbacks for displaying errors.
---@param uiShowFunc function The function to call to show the UI
---@param uiHideFunc function The function to call to hide the UI
function ErrorHandler.ConfigureUI(uiShowFunc, uiHideFunc)
	assert(uiShowFunc and uiHideFunc and not private.uiShowFunc and not private.uiHideFunc)
	private.uiShowFunc = uiShowFunc
	private.uiHideFunc = uiHideFunc
end

---Shows an error for the specified thread.
---@param err string The error message
---@param thread thread The thread
function ErrorHandler.ShowForThread(err, thread)
	if type(thread) ~= "thread" then
		thread = nil
	end
	private.ErrorHandler(err, thread, true, false)
end

---Shows a manual error.
function ErrorHandler.ShowManual()
	private.ErrorHandler("Manually triggered error", nil, true, true)
end

---Saves the error reports into the passed app DB.
---@param appDB table The app DB
function ErrorHandler.SaveReports(appDB)
	if private.isShown then
		private.uiHideFunc()
	end
	appDB.errorReports = appDB.errorReports or { updateTime = 0, data = {} }
	if #private.errorReports > 0 then
		appDB.errorReports.updateTime = private.errorReports[#private.errorReports].timestamp
	end
	-- Remove any events which are too old
	for i = #appDB.errorReports.data, 1, -1 do
		local timestamp = strmatch(appDB.errorReports.data[i], "([0-9]+)%]$") or ""
		if (tonumber(timestamp) or 0) < LibTSMService.GetTime() - MAX_ERROR_REPORT_AGE then
			tremove(appDB.errorReports.data, i)
		end
	end
	for _, report in ipairs(private.errorReports) do
		local line = format("[%s,\"%s\",%d]", JSON.Encode(report.errorInfo), report.details, report.timestamp)
		tinsert(appDB.errorReports.data, line)
	end
end

---Registers a function to use for global name translation.
---@param func fun(result: table<string,string>) A function to populate a lookup table
function ErrorHandler.RegisterNameTranslationFunction(func)
	tinsert(private.globalNameTranslationFuncs, func)
end

---Processes an error report to be saved.
---@param errorInfo table The error info
---@param details string The details string
---@param isManual boolean Whether or not this is a manual error
---@param force boolean Whether or not to force appending this report
function ErrorHandler.ProcessReport(errorInfo, details, isManual, force)
	private.errorSuppressed = nil
	private.isShown = false
	if (LibTSMService.IsDevVersion() or isManual or private.num ~= 1) and not force then
		return
	end
	details = gsub(details, "\124cff[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]([^\124]+)\124r", "%1")
	details = gsub(details, "\124cnIQ[0-9]:([^\124]+)\124r", "%1")
	details = gsub(details, "[\\]+", "/")
	details = gsub(details, "\"", "'")
	tinsert(private.errorReports, {
		errorInfo = errorInfo,
		details = details,
		timestamp = LibTSMService.GetTime(),
	})
	-- 3.3.5: дублируем ошибки TSM Error Window в TSMDebugDB.errors,
	-- чтобы Claude мог их прочитать из SavedVariables без скриншотов.
	if _G.TSMDBG and _G.TSMDBG.LogErr then
		_G.TSMDBG.LogErr("TSMErrorWindow", details)
	end
end



-- ============================================================================
-- Error Handler
-- ============================================================================

function private.ErrorHandler(msg, thread, isSilent, isManual)
	-- Ignore errors while we are handling this error
	private.ignoreErrors = true

	if private.isShown and private.errorSuppressed then
		-- Already showing an error and suppressed another one, so silently ignore this one
		private.ignoreErrors = false
		return true
	end

	-- Shorten the paths in the error message
	msg = gsub(msg, "%.%.%.T?r?a?d?e?S?k?i?l?l?M?a?ster([_A-Za-z]*[\\/])", "TradeSkillMaster%1")
	msg = strsub(msg, strfind(msg, "TradeSkillMaster") or 1)
	msg = gsub(msg, "TradeSkillMaster([^%.])", "TSM%1")

	-- Build our global name translation table
	wipe(private.globalNameTranslation)
	pcall(function()
		for _, func in ipairs(private.globalNameTranslationFuncs) do
			local temp = {}
			func(temp)
			for k, v in pairs(temp) do
				private.globalNameTranslation[String.Escape(k)] = v
			end
		end
	end)

	-- Build stack trace with locals and get addon name
	local stackInfo, newMsg = private.GetStackInfo(msg, thread)
	msg = newMsg
	local addonName = isSilent and "TradeSkillMaster" or nil
	for _, info in ipairs(stackInfo) do
		if not addonName then
			addonName = strmatch(info.file, "[A-Za-z]+%.lua") and private.IsTSMAddon(info.file) or nil
		end
	end
	if not isManual and addonName ~= "TradeSkillMaster" then
		-- Not a TSM error
		private.ignoreErrors = false
		return false
	end

	if not LibTSMService.IsDevVersion() and not isManual then
		-- Log the error (use a format string in case there are '%' characters in the msg)
		Log.Err("%s", msg)
	end

	if private.isShown then
		-- Already showing an error, so suppress this one and return
		private.errorSuppressed = true
		print(PRINT_PREFIX.."Additional error suppressed")
		return true
	end

	private.num = private.num + 1
	local clientVersion, clientBuild = ClientInfo.GetBuildInfo()
	local errorInfo = {
		msg = #stackInfo > 0 and gsub(msg, String.Escape(stackInfo[1].file)..":"..stackInfo[1].line..": ", "") or msg,
		stackInfo = stackInfo,
		time = floor(LibTSMService.GetTime()),
		debugTime = LibTSMService.GetTime(),
		client = format("%s (%s)", clientVersion, clientBuild),
		locale = ClientInfo.GetLocale(),
		inCombat = tostring(ClientInfo.IsInCombat() and true or false),
		version = LibTSMService.GetVersionStr(),
	}

	-- Temp table info
	local tempTableLines = {}
	for _, info in ipairs(TempTable.GetDebugInfo()) do
		tinsert(tempTableLines, info)
	end
	errorInfo.tempTableStr = table.concat(tempTableLines, "\n")

	-- Object pool info
	local objectPoolLines = {}
	for name, objectInfo in pairs(ObjectPool.GetDebugInfo()) do
		tinsert(objectPoolLines, format("%s (%d created, %d in use)", name, objectInfo.numCreated, objectInfo.numInUse))
		for _, info in ipairs(objectInfo.info) do
			tinsert(objectPoolLines, "  "..info)
		end
	end
	errorInfo.objectPoolStr = table.concat(objectPoolLines, "\n")

	-- TSM thread info
	local _, threadInfoStr = pcall(function() return Threading.GetDebugStr() end)
	errorInfo.threadInfoStr = tostring(threadInfoStr)

	-- Recent debug log entries
	local entries = {}
	for i = Log.Length(), 1, -1 do
		local severity, location, timeStr, logMsg = Log.Get(i)
		tinsert(entries, format("%s [%s] {%s} %s", timeStr, severity, location, logMsg))
	end
	errorInfo.debugLogStr = table.concat(entries, "\n")

	-- Addons
	local hasAddonSuite = {}
	local addonsLines = {}
	for i = 1, Addon.GetNum() do
		local name, version, loaded, loadable = Addon.GetInfo(i)
		if loadable then
			local isSuite = nil
			for _, commonTerm in ipairs(Addons.Suites) do
				if strsub(name, 1, #commonTerm) == commonTerm then
					isSuite = commonTerm
					break
				end
			end
			local commonTerm = "TradeSkillMaster"
			if isSuite then
				if not hasAddonSuite[isSuite] then
					tinsert(addonsLines, name.." ("..version..")"..(loaded and "" or " [Not Loaded]"))
					hasAddonSuite[isSuite] = true
				end
			elseif strsub(name, 1, #commonTerm) == commonTerm then
				name = gsub(name, "TradeSkillMaster", "TSM")
				tinsert(addonsLines, name.." ("..version..")"..(loaded and "" or " [Not Loaded]"))
			else
				tinsert(addonsLines, name.." ("..version..")"..(loaded and "" or " [Not Loaded]"))
			end
		end
	end
	errorInfo.addonsStr = table.concat(addonsLines, "\n")

	-- Get the stack info
	local stackInfoLines, fullErrorInfo = {}, {}
	for _, info in ipairs(errorInfo.stackInfo) do
		local localsStr = info.localsStr
		if info.objectName then
			local placeholderStr = "self = <"..info.objectName.."> {}"
			localsStr = (localsStr ~= "" and localsStr.."\n" or "")..placeholderStr
			fullErrorInfo[placeholderStr] = info.objectName
		end
		if localsStr ~= "" then
			localsStr = "\n  |cffaaaaaa"..gsub(localsStr, "\n", "\n  ").."|r"
		end
		local locationStr = info.line ~= 0 and strjoin(":", info.file, info.line) or info.file
		tinsert(stackInfoLines, locationStr.." <"..info.func..">"..localsStr)
	end

	-- Build the error string
	local errorStr = strjoin("\n",
		private.FormatErrorMessageSection("Message", msg),
		private.FormatErrorMessageSection("Time", date("%m/%d/%y %H:%M:%S", errorInfo.time).." ("..floor(errorInfo.debugTime)..")"),
		private.FormatErrorMessageSection("Client", errorInfo.client),
		private.FormatErrorMessageSection("Locale", errorInfo.locale),
		private.FormatErrorMessageSection("Combat", errorInfo.inCombat),
		private.FormatErrorMessageSection("Error Count", private.num),
		private.FormatErrorMessageSection("Stack Trace", table.concat(stackInfoLines, "\n"), true),
		private.FormatErrorMessageSection("Temp Tables", errorInfo.tempTableStr, true),
		private.FormatErrorMessageSection("Object Pools", errorInfo.objectPoolStr, true),
		private.FormatErrorMessageSection("Running Threads", errorInfo.threadInfoStr, true),
		private.FormatErrorMessageSection("Debug Log", errorInfo.debugLogStr, true),
		private.FormatErrorMessageSection("Addons", errorInfo.addonsStr, true)
	)
	-- Remove unprintable characters
	errorStr = gsub(errorStr, "[%z\001-\008\011-\031]", "?")

	-- Show the error
	if private.uiShowFunc then
		private.isShown = true
		private.uiShowFunc(errorStr, errorInfo, fullErrorInfo, isManual)
	end
	print(PRINT_PREFIX.."Looks like TradeSkillMaster has encountered an error. Please help the author fix this error by following the instructions shown.")
	if LibTSMService.IsTestVersion() then
		print(errorStr)
	end

	private.ignoreErrors = false
	return true
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetStackInfo(msg, thread)
	local errLocation = strmatch(msg, "[A-Za-z]+%.lua:[0-9]+")
	local stackFrames = private.GetStackFrames(thread)
	local startIndex = nil
	for i, frame in ipairs(stackFrames) do
		local prevFrame = stackFrames[i-1]
		if prevFrame and strfind(frame.file, "LibTSMClass%.lua") then
			-- TODO: Ignore stack frames from the class code's wrapper function
			if frame.func ~= "?" and prevFrame.func and not strmatch(frame.func, "^.+:[0-9]+$") and strmatch(prevFrame.func, "^.+:[0-9]+$") then
				-- This stack frame includes the class method we were accessing in the previous one, so go back and fix it up
				if frame.rawLocals then
					local className, objKey = strmatch(frame.rawLocals, "\n +str = \"([A-Za-z_0-9]+):([0-9A-F]+)\"\n")
					if className then
						prevFrame.objectName = className..":"..objKey
						prevFrame.func = className.."."..frame.func
					else
						prevFrame.func = "?."..frame.func
					end
				else
					prevFrame.func = "?."..frame.func
				end
			end
		end
		if not startIndex then
			if errLocation and strmatch(frame.file..":"..frame.line, "[A-Za-z]+%.lua:[0-9]+") == errLocation then
				startIndex = strfind(frame.file, "LibTSMClass%.lua") and (i - 1) or i
			elseif not errLocation and i > (thread and 1 or 4) and frame.file ~= "[C]" then
				startIndex = i
			end
		end
	end
	if not startIndex then
		return {}
	end

	-- Remove the extra frames from the top
	for _ = 1, startIndex - 1 do
		tremove(stackFrames, 1)
	end

	-- Fix up the error message
	if errLocation and strfind(errLocation, "LibTSMClass%.lua:%d+") and stackFrames[1] and not strfind(stackFrames[1].file, "LibTSMClass%.lua") then
		msg = gsub(msg, ".+LibTSMClass%.lua:[0-9]+", stackFrames[1].file..":"..stackFrames[1].line)
	end

	return stackFrames, msg
end

function private.GetStackFrames(thread)
	local stackFrames = {}
	local consecutiveIgnored = 0
	for i = 0, math.huge do
		local file, line, func, locals = private.GetStackFrame(i, thread)
		if file then
			tinsert(stackFrames, {
				file = file,
				line = line,
				func = func,
				rawLocals = locals,
				localsStr = locals and private.ParseLocals(locals, file) or "",
			})
			consecutiveIgnored = 0
		else
			consecutiveIgnored = consecutiveIgnored + 1
			if consecutiveIgnored >= 20 or #stackFrames >= MAX_STACK_DEPTH then
				break
			end
		end
	end
	return stackFrames
end

function private.GetStackFrame(level, thread)
	local stackLine = nil
	if thread then
		stackLine = Debug.Stack(thread, level, 1, 0) or ""
	else
		level = level + 1
		stackLine = Debug.Stack(level, 1, 0) or ""
	end
	stackLine = gsub(stackLine, "^%[string \"@([^%.]+%.lua)\"%]", "%1")
	stackLine = gsub(stackLine, "^%[(Interface[^%.]+%.lua)%]", "%1")
	local locals = not thread and Debug.GetLocals(level) or nil
	stackLine = gsub(stackLine, "%.%.%.T?r?a?d?e?S?k?i?l?l?M?a?ster([_A-Za-z]*[\\/])", "TradeSkillMaster%1")
	stackLine = gsub(stackLine, "%.%.%.", "")
	stackLine = gsub(stackLine, "in function '([^']+)'", "in function <%1>")
	if LibTSMService.IsTestVersion() then
		stackLine = gsub(stackLine, "'", "<", 1)
	else
		stackLine = gsub(stackLine, "`", "<", 1)
	end
	stackLine = gsub(stackLine, "'", ">", 1)
	stackLine = strtrim(stackLine)
	if stackLine == "" then
		return
	end

	-- Parse out the file, line, and function name
	local locationStr, functionStr = strmatch(stackLine, "^(.-): in function (<[^\n]*>)")
	if not locationStr then
		locationStr, functionStr = strmatch(stackLine, "^(.-): in (main chunk)")
	end
	if not locationStr then
		return
	end
	locationStr = strsub(locationStr, strfind(locationStr, "TradeSkillMaster") or 1)
	locationStr = gsub(locationStr, "TradeSkillMaster([^%.])", "TSM%1")
	functionStr = functionStr and gsub(gsub(functionStr, ".*[\\/]", ""), "[<>]", "") or ""
	local file, line = strmatch(locationStr, "^(.+):(%d+)$")
	file = file or locationStr
	line = tonumber(line) or 0

	local func = strsub(functionStr, strfind(functionStr, "`") and 2 or 1, -1) or "?"
	func = func ~= "" and func or "?"
	return file, line, func, locals
end

function private.ParseLocals(locals, file)
	if strmatch(file, "^%[") then
		return
	end

	local fileName = strmatch(file, "([A-Za-z%-_0-9]+)%.lua")
	local isBlizzardFile = strmatch(file, "Interface[\\/]FrameXML[\\/]")
	local isPrivateTable, isLocaleTable, isPackageTable, isSelfTable, isTemporaryTable = false, false, false, false, false
	wipe(private.localLinesTemp)
	locals = gsub(locals, "<([a-z]+)> {[\n\t ]+}", "<%1> {}")
	locals = gsub(locals, " = <function> defined @", "@")
	locals = gsub(locals, "<table> {", "{")

	local level = 0
	for localLine in gmatch(locals, "[^\n]+") do
		local shouldIgnoreLine = false
		if strmatch(localLine, "^ *%(%*temporary%) = nil") then
			-- ignore nil temporary variables
			shouldIgnoreLine = true
		elseif strmatch(localLine, "LibTSMClass%.lua:") then
			-- ignore class methods
			shouldIgnoreLine = true
		elseif strmatch(localLine, "<unnamed> {}$") then
			-- ignore internal WoW frame members
			shouldIgnoreLine = true
		elseif strtrim(localLine) == "" then
			-- ignore empty lines
			shouldIgnoreLine = true
		elseif strmatch(localLine, "^ += .+$") then
			-- ignore lines which start with a '='
			shouldIgnoreLine = true
		elseif strmatch(localLine, "= <([^>]+)$") then
			-- ignore lines with unmatched '<', '>' in their value
			shouldIgnoreLine = true
		end
		if not shouldIgnoreLine then
			level = #strmatch(localLine, "^ *")
			localLine = strrep("  ", level)..strtrim(localLine)
			localLine = gsub(localLine, "Interface[\\/][Aa]dd[Oo]ns[\\/]TradeSkillMaster", "TSM")
			localLine = gsub(localLine, "\124", "\\124")
			for matchStr, replaceStr in pairs(private.globalNameTranslation) do
				localLine = gsub(localLine, matchStr, replaceStr)
			end
			if level > 0 then
				if isBlizzardFile then
					-- for Blizzard stack frames, only include level 0 locals
					shouldIgnoreLine = true
				elseif strmatch(localLine, "^ *[_]*[A-Z].+@TSM") then
					-- ignore table methods (based on their name being UpperCamelCase - potentially with leading underscores)
					shouldIgnoreLine = true
				elseif strmatch(localLine, "^ *[_]*[A-Z].+@") and not strmatch(localLine, ":%d+$") then
					-- ignore cut-off table method lines
					shouldIgnoreLine = true
				elseif isLocaleTable then
					-- ignore everything within the locale table
					shouldIgnoreLine = true
				elseif isPackageTable then
					-- ignore the package table completely
					shouldIgnoreLine = true
				elseif isTemporaryTable then
					-- Ignore temporary tables completely
					shouldIgnoreLine = true
				elseif (isSelfTable or isPrivateTable) and strmatch(localLine, "^ *[_a-zA-Z0-9]+ = {}") then
					-- ignore empty tables within objects or the private table
					shouldIgnoreLine = true
				elseif strmatch(localLine, "^%s+0 = <userdata>$") then
					-- remove userdata table entries
					shouldIgnoreLine = true
				end
			end
			if not shouldIgnoreLine then
				tinsert(private.localLinesTemp, localLine)
			end
			if level == 0 then
				isPackageTable = strmatch(localLine, "%s*"..fileName.." = {") and true or false
				isPrivateTable = strmatch(localLine, "%s*private = {") and true or false
				isLocaleTable = strmatch(localLine, "%s*L = {") and true or false
				isSelfTable = strmatch(localLine, "%s*self = {") and true or false
				isTemporaryTable = strmatch(localLine, "%s*%(%*temporary%) =.*{") and true or false
			end
		end
	end
	-- add closing brackets for tables which got cut off at the end
	while level > 0 do
		level = level - 1
		tinsert(private.localLinesTemp, strrep("  ", level).."}")
	end

	-- remove any top-level empty tables
	local i = #private.localLinesTemp
	while i > 0 do
		if i > 1 and private.localLinesTemp[i] == "}" and strmatch(private.localLinesTemp[i - 1], "^[A-Za-z_%(].* = {$") then
			tremove(private.localLinesTemp, i)
			tremove(private.localLinesTemp, i - 1)
			i = i - 2
		elseif strmatch(private.localLinesTemp[i], "^[A-Za-z_%(].* = {}$") then
			tremove(private.localLinesTemp, i)
			i = i - 1
		elseif i > 1 and private.localLinesTemp[i] == "}" and strmatch(private.localLinesTemp[i - 1], "^[A-Za-z_%(].* =.*{$") then
			-- Don't remove this table, but collapse it
			private.localLinesTemp[i - 1] = private.localLinesTemp[i - 1].."}"
			tremove(private.localLinesTemp, i)
			i = i - 1
		else
			i = i - 1
		end
	end
	return #private.localLinesTemp > 0 and table.concat(private.localLinesTemp, "\n") or nil
end

function private.IsTSMAddon(str)
	if strfind(str, "Auc-Adcanced[\\/]CoreScan.lua") then
		-- ignore auctioneer errors
		return nil
	elseif strfind(str, "Master[\\/]External[\\/]") then
		-- ignore errors from libraries
		return nil
	elseif strfind(str, "Master[\\/]Core[\\/]API.lua") then
		-- ignore errors from public APIs
		return nil
	elseif strfind(str, "Master_AppHelper[\\/]") then
		return "TradeSkillMaster_AppHelper"
	elseif strfind(str, "lMaster[\\/]") then
		return "TradeSkillMaster"
	elseif strfind(str, "ster[\\/]Core[\\/]UI[\\/]") then
		return "TradeSkillMaster"
	elseif strfind(str, "r[\\/]LibTSM[\\/]") then
		return "TradeSkillMaster"
	elseif strfind(str, "^TSM[\\/]") then
		return "TradeSkillMaster"
	end
	return nil
end

function private.AddonBlockedHandler(event, addonName, addonFunc)
	if not strmatch(addonName, "TradeSkillMaster") then
		return
	end
	-- just log it - it might not be TSM that cause the taint
	Log.Err("[%s] AddOn '%s' tried to call the protected function '%s'.", event, addonName or "<name>", addonFunc or "<func>")

	if LibTSMService.IsDevVersion() then
		local status, ret = pcall(private.ErrorHandler, "BLOCKED", nil, false, false)
		if not status and not private.hitInternalError then
			private.hitInternalError = true
			print("Internal TSM error: "..tostring(ret))
		end
	end
end

function private.FormatErrorMessageSection(heading, info, isMultiLine)
	-- replace unprintable characters with "?"
	info = gsub(info, "[^\t\n -~]", "?")
	local prefix = nil
	if isMultiLine then
		prefix = info ~= "" and "\n  " or ""
		info = gsub(info, "\n", "\n  ")
	else
		prefix = info ~= "" and " " or ""
	end
	return "|cff99ffff"..heading..":|r"..prefix..info
end



-- ============================================================================
-- Register Error Handler
-- ============================================================================

do
	local function ErrorHandlerFunc(errMsg)
		local tsmErrMsg = strtrim(tostring(errMsg))
		if private.ignoreErrors then
			-- we're ignoring errors
			tsmErrMsg = nil
		elseif strmatch(tsmErrMsg, "auc%-stat%-wowuction") or strmatch(tsmErrMsg, "TheUndermineJournal%.lua") or strmatch(tsmErrMsg, "[\\/]SavedVariables[\\/]TradeSkillMaster") or strmatch(tsmErrMsg, "AddOn TradeSkillMaster[_a-zA-Z]* attempted") then
			-- explicitly ignore these errors
			tsmErrMsg = nil
		elseif strmatch(tsmErrMsg, "Blizzard_AuctionUI%.lua:751") then
			-- suppress this Blizzard error
			return true
		end
		if tsmErrMsg then
			-- look at the stack trace to see if this is a TSM error
			for i = 2, MAX_STACK_DEPTH do
				local stackLine = Debug.Stack(i, 1, 0)
				if not strmatch(stackLine, "^%[C%]:") and not strmatch(stackLine, "[%(%[]tail call[%)%]]:") and not strmatch(stackLine, "%[tsm error check%]") and not strmatch(stackLine, "^%[string \"[^@]") and not strmatch(stackLine, "lMaster[\\/]External[\\/][A-Za-z0-9%-_%.]+[\\/]") and not strmatch(stackLine, "SharedXML") and not strmatch(stackLine, "CallbackHandler") and not strmatch(stackLine, "!BugGrabber") and not strmatch(stackLine, "ErrorHandler%.lua") then
					if not private.IsTSMAddon(stackLine) then
						tsmErrMsg = nil
					end
					break
				end
			end
		end
		if tsmErrMsg then
			local status, ret = pcall(private.ErrorHandler, tsmErrMsg, nil, false, false)
			if status and ret then
				return ret
			elseif not status and not private.hitInternalError then
				private.hitInternalError = true
				print("Internal TSM error: "..tostring(ret))
			end
		end
		return false
	end
	Debug.SetErrorHandler(ErrorHandlerFunc)
	-- luacheck: globals BugGrabber
	if BugGrabber and BugGrabber.RegisterCallback then
		BugGrabber.RegisterCallback({}, "BugGrabber_BugGrabbed", function(_, errObj)
			ErrorHandlerFunc(errObj.message)
		end)
	end
	Event.Register("ADDON_ACTION_FORBIDDEN", private.AddonBlockedHandler)
	Event.Register("ADDON_ACTION_BLOCKED", private.AddonBlockedHandler)
end
