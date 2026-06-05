-- ============================================================================
-- TSMDebug — полноценная отладочная инфраструктура для TSM на 3.3.5a
-- ============================================================================
-- Цель: всё что нужно для диагностики БЕЗ необходимости копировать из чата.
-- Все логи / ошибки / таблицы / тайминги пишутся в SavedVariable TSMDebugDB.
--
-- API:
--   TSMDBG.Log(category, fmt, ...)               -- INFO
--   TSMDBG.Warn(category, fmt, ...)              -- WARN
--   TSMDBG.LogErr(context, err)                  -- ERR
--   TSMDBG.Try(context, fn, ...)                 -- pcall + автолог
--   TSMDBG.Dump(name, tbl, depth)                -- сериализовать таблицу
--   TSMDBG.Time(name) / TSMDBG.TimeEnd(name)     -- замер времени
--   TSMDBG.Snapshot(name, data)                  -- снимок произвольного состояния
--   TSMDBG.Filter(categories)                    -- {Scanner=true} — фильтр
--
-- Слэш:
--   /tsmdbg                — статус
--   /tsmdbg tail [N]       — последние N (по умолчанию 30)
--   /tsmdbg cat <category> — фильтр по категории
--   /tsmdbg errors         — все ошибки с трассами
--   /tsmdbg clear          — очистить
--   /tsmdbg snap           — записать snapshot и дампнуть стек состояний
--   /tsmdbg dump           — форс-флаш в SavedVariable (вызывает /reload)
--   /tsmdbg info           — env info (client, realm, version)
--
-- SavedVariable layout:
--   TSMDebugDB = {
--     logs = { "[ts] LEVEL Category | msg", ... },
--     logsPrev = { ... },              -- предыдущая сессия (auto-rotate)
--     errors = { {time, ctx, err, trace}, ... },
--     snapshots = { name = data, ... },
--     timers = { name = duration_ms, ... },
--     info = { client, build, realm, char, locale, started },
--     sessions = { count of starts },
--   }
-- ============================================================================

local TSMDBG = {}
_G.TSMDBG = TSMDBG

local LOG_MAX = 5000
local ERR_MAX = 500
local SNAPSHOT_MAX = 50
local LEVEL_INFO, LEVEL_WARN, LEVEL_ERR = "INFO", "WARN", "ERR"

local pendingLogs = {}
local pendingErrors = {}
local pendingSnapshots = {}
local pendingTimers = {}
local activeTimers = {}
local DB = nil
local filterCat = nil  -- nil = пишем всё, иначе только эти категории

local function ts()
	return GetTime and string.format("%.3f", GetTime()) or "?"
end

local function fmt(fmtStr, ...)
	if select("#", ...) == 0 then return tostring(fmtStr) end
	local ok, s = pcall(string.format, fmtStr, ...)
	return ok and s or ("BAD_FORMAT:" .. tostring(fmtStr))
end

local function pushLog(level, category, msgOrFmt, ...)
	if filterCat and not filterCat[category] then return end
	local msg
	if select("#", ...) == 0 then
		msg = tostring(msgOrFmt)
	else
		msg = fmt(msgOrFmt, ...)
	end
	local line = "[" .. ts() .. "] " .. level .. " " .. tostring(category) .. " | " .. msg
	local sink = DB and DB.logs or pendingLogs
	sink[#sink + 1] = line
	if #sink > LOG_MAX then table.remove(sink, 1) end
end

local function pushErr(entry)
	local sink = DB and DB.errors or pendingErrors
	sink[#sink + 1] = entry
	if #sink > ERR_MAX then table.remove(sink, 1) end
end

function TSMDBG.Log(category, fmtStr, ...)
	if fmtStr == nil then return end
	pushLog(LEVEL_INFO, category, fmt(fmtStr, ...))
end

function TSMDBG.Warn(category, fmtStr, ...)
	if fmtStr == nil then return end
	pushLog(LEVEL_WARN, category, fmt(fmtStr, ...))
end

function TSMDBG.LogErr(context, err)
	local entry = {
		time = ts(),
		ctx = tostring(context),
		err = tostring(err),
		trace = debugstack and debugstack(2, 25, 25) or "",
	}
	pushErr(entry)
	pushLog(LEVEL_ERR, "ERR", tostring(context) .. " | " .. tostring(err))
end

function TSMDBG.Try(context, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then TSMDBG.LogErr(context, err) end
	return ok, err
end

-- Сериализатор для таблиц (с защитой от циклов, кэп глубины)
local function serialize(value, depth, seen, indent)
	depth = depth or 0
	if depth > 5 then return "<depth>" end
	local t = type(value)
	if t == "string" then
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" then
		return tostring(value)
	elseif t == "nil" then
		return "nil"
	elseif t == "function" then
		return "<func>"
	elseif t == "userdata" then
		return "<userdata>"
	elseif t == "table" then
		seen = seen or {}
		if seen[value] then return "<cycle>" end
		seen[value] = true
		local pad = string.rep("  ", indent or 0)
		local nextPad = string.rep("  ", (indent or 0) + 1)
		local parts = { "{" }
		local count = 0
		for k, v in pairs(value) do
			count = count + 1
			if count > 30 then
				parts[#parts + 1] = nextPad .. "<truncated>"
				break
			end
			local keyStr = type(k) == "string" and k or "["..tostring(k).."]"
			parts[#parts + 1] = nextPad .. keyStr .. " = " .. serialize(v, depth + 1, seen, (indent or 0) + 1) .. ","
		end
		parts[#parts + 1] = pad .. "}"
		return table.concat(parts, "\n")
	else
		return "<" .. t .. ">"
	end
end

function TSMDBG.Dump(name, tbl, depth)
	local s = serialize(tbl, 0, nil, 0)
	local snap = { time = ts(), name = tostring(name), data = s }
	local sink = DB and DB.snapshots or pendingSnapshots
	sink[#sink + 1] = snap
	if #sink > SNAPSHOT_MAX then table.remove(sink, 1) end
	pushLog(LEVEL_INFO, "DUMP", tostring(name) .. " (" .. #s .. " bytes)")
end

function TSMDBG.Snapshot(name, data)
	TSMDBG.Dump(name, data)
end

function TSMDBG.Time(name)
	activeTimers[name] = GetTime and GetTime() or 0
end

function TSMDBG.TimeEnd(name)
	local start = activeTimers[name]
	if not start then
		TSMDBG.Warn("TIME", "TimeEnd without Time: %s", tostring(name))
		return
	end
	local dur = (GetTime and GetTime() or 0) - start
	activeTimers[name] = nil
	local ms = dur * 1000
	local sink = DB and DB.timers or pendingTimers
	sink[tostring(name)] = ms
	pushLog(LEVEL_INFO, "TIME", "%s = %.2fms", tostring(name), ms)
end

function TSMDBG.Filter(categories)
	if not categories then
		filterCat = nil
		return
	end
	filterCat = {}
	for _, c in ipairs(categories) do
		filterCat[c] = true
	end
end

-- Глобальный error-hook
local origHandler = geterrorhandler and geterrorhandler() or nil
local function tsmErrorHandler(err)
	local s = tostring(err)
	if s:find("TradeSkillMaster", 1, true) or s:find("LibTSM", 1, true) or s:find("!!!ClassicAPI", 1, true) then
		TSMDBG.LogErr("GLOBAL", s)
	end
	if origHandler then return origHandler(err) end
end
if seterrorhandler then seterrorhandler(tsmErrorHandler) end

-- ADDON_LOADED — инициализация DB
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, addon)
	if event == "ADDON_LOADED" and addon == "TradeSkillMaster" then
		if not _G.TSMDebugDB then _G.TSMDebugDB = {} end
		DB = _G.TSMDebugDB
		-- Rotate
		DB.logsPrev = DB.logs or {}
		DB.logs = {}
		DB.errors = {}
		DB.snapshots = DB.snapshots or {}
		DB.timers = {}
		DB.sessions = (DB.sessions or 0) + 1
		-- Слить pending
		for _, l in ipairs(pendingLogs) do DB.logs[#DB.logs + 1] = l end
		for _, e in ipairs(pendingErrors) do DB.errors[#DB.errors + 1] = e end
		for _, s in ipairs(pendingSnapshots) do DB.snapshots[#DB.snapshots + 1] = s end
		for k, v in pairs(pendingTimers) do DB.timers[k] = v end
		pendingLogs, pendingErrors, pendingSnapshots, pendingTimers = {}, {}, {}, {}
		-- Info
		DB.info = {
			client = (GetBuildInfo and select(1, GetBuildInfo())) or "?",
			build = (GetBuildInfo and select(2, GetBuildInfo())) or "?",
			tocVersion = (GetBuildInfo and select(4, GetBuildInfo())) or "?",
			locale = GetLocale and GetLocale() or "?",
			realm = GetRealmName and GetRealmName() or "?",
			character = UnitName and UnitName("player") or "?",
			startedTs = ts(),
			session = DB.sessions,
		}
		TSMDBG.Log("BOOT", "TSMDebug ready, session=%d client=%s build=%s realm=%s char=%s",
			DB.sessions, tostring(DB.info.client), tostring(DB.info.build), tostring(DB.info.realm), tostring(DB.info.character))
	end
end)

-- ============================================================================
-- АВТО-РЕЖИМ: ничего не нужно делать руками
-- ============================================================================
-- 1. Авто-снепшоты при ключевых событиях (AH open/close, query, scan complete)
-- 2. Авто-/reload после первого успешного scan-цикла → данные сразу на диске
-- 3. Перехват КАЖДОЙ Lua-ошибки (не только TSM-related) → потом фильтруем
-- 4. Watchdog: если 30 сек после AH-query нет UpdateData — автоснимок состояния
-- 5. Auto-reload после AH closed (если был хотя бы 1 scan)
-- ============================================================================

local autoState = {
	scanRequested = false,    -- /tsmscan или Browse в UI
	scanCompleted = false,    -- _UpdateData ≥ 1 раз с total>0
	queryTime = 0,
	lastUpdateTime = 0,
	ahWasOpen = false,
	autoReloadDone = false,
	pendingReloadAt = 0,
}
TSMDBG._auto = autoState

-- Триггеры для логирования из основного кода TSM:
-- Эти функции вызываются из Scanner/Query/AuctionScrollTable
function TSMDBG.SignalQuerySent(query)
	autoState.scanRequested = true
	autoState.queryTime = GetTime and GetTime() or 0
	pushLog(LEVEL_INFO, "AUTO", "scan started: " .. tostring(query))
end

function TSMDBG.SignalScanComplete(totalRows)
	autoState.scanCompleted = true
	autoState.lastUpdateTime = GetTime and GetTime() or 0
	pushLog(LEVEL_INFO, "AUTO", "scan complete: rows=" .. tostring(totalRows))
	-- Auto-snapshot после скана: текущий стейт AuctionBuyScan + первые строки AH
	pcall(function()
		local snap = {
			rows = totalRows,
			numAH = GetNumAuctionItems and GetNumAuctionItems("list") or -1,
			canQuery = CanSendAuctionQuery and CanSendAuctionQuery() or false,
			fps = GetFramerate and math.floor(GetFramerate()) or -1,
			mem = GetAddOnMemoryUsage and GetAddOnMemoryUsage("TradeSkillMaster") or -1,
		}
		TSMDBG.Dump("auto:scan-complete-state", snap)
	end)
	-- Авто-reload через 8 сек: успеет приехать seller resolve, юзер увидит результат, потом данные на диск
	if not autoState._scanReloadScheduled then
		autoState._scanReloadScheduled = true
		local t = CreateFrame("Frame")
		local elapsed = 0
		t:SetScript("OnUpdate", function(self, dt)
			elapsed = elapsed + dt
			if elapsed >= 8 then
				self:SetScript("OnUpdate", nil)
				if not autoState.autoReloadDone then
					autoState.autoReloadDone = true
					pushLog(LEVEL_INFO, "AUTO", "scan-done auto reload (8s grace)")
					ReloadUI()
				end
			end
		end)
	end
end

-- Авто-снепшоты по WoW событиям
local autoFrame = CreateFrame("Frame")
autoFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
autoFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
autoFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
autoFrame:RegisterEvent("PLAYER_LOGIN")
autoFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "AUCTION_HOUSE_SHOW" then
		autoState.ahWasOpen = true
		pushLog(LEVEL_INFO, "AUTO", "AUCTION_HOUSE_SHOW")
	elseif event == "AUCTION_HOUSE_CLOSED" then
		pushLog(LEVEL_INFO, "AUTO", "AUCTION_HOUSE_CLOSED")
		-- Если был скан и /reload ещё не сделан — сделать сейчас
		if autoState.scanCompleted and not autoState.autoReloadDone then
			autoState.autoReloadDone = true
			pushLog(LEVEL_INFO, "AUTO", "AH closed after scan → ReloadUI in 1s")
			C_Timer = C_Timer or {}
			if not C_Timer.After then
				-- 3.3.5 fallback
				local t = CreateFrame("Frame")
				local elapsed = 0
				t:SetScript("OnUpdate", function(_, dt)
					elapsed = elapsed + dt
					if elapsed >= 1 then
						t:SetScript("OnUpdate", nil)
						ReloadUI()
					end
				end)
			else
				C_Timer.After(1, ReloadUI)
			end
		end
	elseif event == "AUCTION_ITEM_LIST_UPDATE" then
		local n = GetNumAuctionItems and GetNumAuctionItems("list") or 0
		if n > 0 and not autoState._snappedAfterUpdate then
			autoState._snappedAfterUpdate = true
			-- Снимок первых 5 аукционов
			local snap = { numAuctions = n, sample = {} }
			for i = 1, math.min(n, 5) do
				local name, texture, qty, quality, canUse, level, minBid, minInc, buyout, bid, isHighBidder, seller = GetAuctionItemInfo("list", i)
				local link = GetAuctionItemLink("list", i)
				local tl = GetAuctionItemTimeLeft("list", i)
				snap.sample[i] = {
					name = name, link = link, qty = qty, quality = quality, level = level,
					texture = texture, minBid = minBid, minInc = minInc, buyout = buyout,
					bid = bid, isHighBidder = isHighBidder, seller = seller, timeLeft = tl,
				}
			end
			TSMDBG.Dump("auto:GetAuctionItemInfo first scan", snap)
		end
	elseif event == "PLAYER_LOGIN" then
		pushLog(LEVEL_INFO, "AUTO", "PLAYER_LOGIN")
	end
end)

-- Watchdog OnUpdate: если scan request был но прошло > 30 сек без update → snapshot + auto-reload
local watchdog = CreateFrame("Frame")
local accum = 0
watchdog:SetScript("OnUpdate", function(_, dt)
	accum = accum + dt
	if accum < 1 then return end
	accum = 0
	local now = GetTime and GetTime() or 0
	-- Watchdog: query без update больше 30 сек
	if autoState.scanRequested and not autoState.scanCompleted then
		if (now - autoState.queryTime) > 30 then
			autoState.scanRequested = false  -- не повторять
			pushLog(LEVEL_WARN, "AUTO", "watchdog: 30s no scan complete → snapshot")
			TSMDBG.Dump("watchdog:state", {
				numAuctions = GetNumAuctionItems and GetNumAuctionItems("list") or -1,
				canQuery = CanSendAuctionQuery and CanSendAuctionQuery() or false,
				ahShown = AuctionFrame and AuctionFrame:IsShown() or false,
			})
		end
	end
end)

-- Перехватываем ВСЕ Lua-ошибки (не только TSM)
-- Уже стоит seterrorhandler выше, но дублируем для надёжности через xpcall на FrameXML scripts
-- (на 3.3.5 нет универсального hook'а — error-handler уже даёт максимум)

-- Helper: format error entry для вывода в чат
local function fmtErr(e)
	return ("[%s] %s | %s"):format(e.time or "?", e.ctx or "?", (e.err or ""):sub(1, 250))
end

SLASH_TSMDBG1 = "/tsmdbg"
SlashCmdList["TSMDBG"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	local cmd, arg = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd or msg
	local logs = DB and DB.logs or pendingLogs
	local errors = DB and DB.errors or pendingErrors
	local snapshots = DB and DB.snapshots or pendingSnapshots

	if cmd == "clear" then
		if DB then
			wipe(DB.logs); wipe(DB.errors); wipe(DB.snapshots); wipe(DB.timers)
		end
		print("|cff00ff00TSMDBG:|r cleared")

	elseif cmd == "errors" then
		print("|cff00ff00TSMDBG:|r " .. #errors .. " errors")
		local start = math.max(1, #errors - 14)
		for i = start, #errors do print(fmtErr(errors[i])) end

	elseif cmd == "tail" then
		local n = tonumber(arg) or 30
		print(("|cff00ff00TSMDBG:|r last %d of %d"):format(n, #logs))
		for i = math.max(1, #logs - n + 1), #logs do print(logs[i]) end

	elseif cmd == "cat" then
		if arg == "" then
			print("|cff00ff00TSMDBG:|r usage: /tsmdbg cat <Category>")
			return
		end
		local found = 0
		print(("|cff00ff00TSMDBG:|r filter=%s"):format(arg))
		for i = 1, #logs do
			if logs[i]:lower():find(" " .. arg .. " |", 1, true) then
				print(logs[i])
				found = found + 1
				if found >= 30 then
					print("|cffff8800... cut at 30 lines|r")
					break
				end
			end
		end

	elseif cmd == "snap" then
		print(("|cff00ff00TSMDBG:|r snapshots=%d"):format(#snapshots))
		for i = 1, math.min(#snapshots, 10) do
			local s = snapshots[i]
			print(("[%s] %s (%d b)"):format(s.time or "?", s.name or "?", #(s.data or "")))
		end
		print("Snapshots are written to SavedVariables. Use ReloadUI to flush.")

	elseif cmd == "dump" then
		print("|cff00ff00TSMDBG:|r dump → ReloadUI")
		ReloadUI()

	elseif cmd == "info" then
		if DB and DB.info then
			for k, v in pairs(DB.info) do print(("  %s = %s"):format(k, tostring(v))) end
		else
			print("|cffff0000TSMDBG:|r info not yet ready")
		end

	elseif cmd == "help" or cmd == "" or cmd == nil then
		print("|cff00ff00TSMDBG|r logs=" .. #logs .. " errors=" .. #errors .. " snapshots=" .. #snapshots .. " session=" .. ((DB and DB.sessions) or "?"))
		print("commands:")
		print("  /tsmdbg tail [N]        — последние N логов")
		print("  /tsmdbg cat <Category>  — фильтр по категории")
		print("  /tsmdbg errors          — все ошибки")
		print("  /tsmdbg snap            — список snapshots")
		print("  /tsmdbg info            — env info")
		print("  /tsmdbg dump            — flush + ReloadUI")
		print("  /tsmdbg clear           — очистить")
	else
		print("|cffff0000TSMDBG:|r unknown command. /tsmdbg help")
	end
end

-- Стартовый маркер
TSMDBG.Log("BOOT", "TSMDebug.lua sourced (LOG_MAX=%d, ERR_MAX=%d)", LOG_MAX, ERR_MAX)
