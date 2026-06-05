-- ============================================================================
-- TSMDebug-commands — runtime-инспектор для TSM AH-сканера на 3.3.5a
-- ============================================================================
-- Грузится В КОНЦЕ TOC, когда все LibTSM* уже инициализированы.
-- Даёт слэш-команды для дампа внутреннего состояния без UI.
--
-- /tsmscan <query>    — запустить browse-скан через FilterSearch и собрать данные
-- /tsmstate           — дамп текущего FSM-состояния AH-сканера
-- /tsmrows            — дамп всех Browse-rows + первого SubRow каждого
-- /tsmenv             — дамп информации об окружении (что есть в _G)
-- ============================================================================

if not _G.TSMDBG then
	-- TSMDebug.lua должен был загрузиться раньше — но защитимся
	return
end

local TSMDBG = _G.TSMDBG

-- Безопасный доступ к LibTSM модулям (могут не успеть инициализироваться)
local function getModule(libName, modName)
	local ok, lib = pcall(function() return _G.TSMAPI[libName] end)
	if not ok or not lib then return nil end
	local ok2, mod = pcall(function() return lib[modName] end)
	if not ok2 then return nil end
	return mod
end

-- Доступ к LibTSMService через TradeSkillMaster глобал (если есть)
local function getLibService(modName)
	if not _G.TradeSkillMaster then return nil end
	-- Попробуем через registered AddOns
	return nil
end

-- /tsmenv — что доступно глобально
SLASH_TSMENV1 = "/tsmenv"
SlashCmdList["TSMENV"] = function()
	print("|cff00ff00TSMDBG env:|r")
	local keys = { "C_AuctionHouse", "C_TradeSkillUI", "GetAuctionItemInfo", "GetAuctionItemLink",
	               "QueryAuctionItems", "AuctionFrame", "GetItemInfo", "GetItemIcon",
	               "TradeSkillMasterDB", "TSMItemInfoDB", "TSMDebugDB",
	               "WOW_PROJECT_ID", "WOW_PROJECT_CLASSIC", "WOW_PROJECT_MAINLINE",
	               "GetBuildInfo", "GetLocale", "GetRealmName" }
	for _, k in ipairs(keys) do
		local v = _G[k]
		local s = type(v) == "string" and ('"' .. v .. '"') or tostring(v)
		print(("  %s = %s"):format(k, s))
	end
	if _G.GetBuildInfo then
		local ver, build, _, toc = GetBuildInfo()
		print(("  GetBuildInfo: version=%s build=%s toc=%s"):format(tostring(ver), tostring(build), tostring(toc)))
	end
	TSMDBG.Log("ENV", "/tsmenv invoked")
end

-- /tsmdebug layout — включить debug для List/ViewContainer Draw()
SLASH_TSMDEBUG1 = "/tsmdebug"
SlashCmdList["TSMDEBUG"] = function(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$")
	if msg == "layout" then
		if not _G.TSMDebugDB then
			_G.TSMDebugDB = {}
		end
		_G.TSMDebugDB.list_draw_debug = {}
		_G.TSMDebugDB.viewcontainer_draw_debug = {}
		print("|cff00ff00TSMDBG:|r layout debug enabled. Open/close TSM window to collect data.")
	elseif msg == "layoutdump" then
		if _G.TSMDebugDB and _G.TSMDebugDB.list_draw_debug then
			print("|cff00ff00TSMDBG:|r List:Draw() calls:")
			for _, line in ipairs(_G.TSMDebugDB.list_draw_debug) do
				print("  " .. line)
			end
		end
		if _G.TSMDebugDB and _G.TSMDebugDB.viewcontainer_draw_debug then
			print("|cff00ff00TSMDBG:|r ViewContainer:Draw() calls:")
			for _, line in ipairs(_G.TSMDebugDB.viewcontainer_draw_debug) do
				print("  " .. line)
			end
		end
	elseif msg == "layoutclear" then
		if _G.TSMDebugDB then
			_G.TSMDebugDB.list_draw_debug = nil
			_G.TSMDebugDB.viewcontainer_draw_debug = nil
		end
		print("|cff00ff00TSMDBG:|r layout debug cleared.")
	else
		print("|cff00ff00TSMDBG:|r usage:")
		print("  /tsmdebug layout      - enable layout debug")
		print("  /tsmdebug layoutdump  - dump collected data")
		print("  /tsmdebug layoutclear - clear debug data")
	end
end

-- /tsmscan <query> — попытаться запустить AH browse-скан программно
SLASH_TSMSCAN1 = "/tsmscan"
SlashCmdList["TSMSCAN"] = function(msg)
	msg = (msg or ""):match("^%s*(.-)%s*$")
	if msg == "" then
		print("|cffff8800TSMDBG:|r usage: /tsmscan <name>  (e.g. /tsmscan iron ore)")
		return
	end
	if not AuctionFrame or not AuctionFrame:IsShown() then
		print("|cffff8800TSMDBG:|r open auction house first (right-click auctioneer)")
		return
	end
	TSMDBG.Log("CMD", "/tsmscan %q invoked", msg)
	-- Делаем запрос вручную через старый API (3.3.5)
	local ok, err = pcall(function()
		if not CanSendAuctionQuery() then
			print("|cffff8800TSMDBG:|r CanSendAuctionQuery=false — wait a sec")
			return
		end
		QueryAuctionItems(msg, nil, nil, nil, nil, nil, 0, false, 0, false)
		print("|cff00ff00TSMDBG:|r query sent for " .. msg)
	end)
	if not ok then
		TSMDBG.LogErr("/tsmscan", err)
		print("|cffff0000TSMDBG:|r " .. tostring(err))
	end
end

-- /tsmrows — собрать снимок результатов скана
SLASH_TSMROWS1 = "/tsmrows"
SlashCmdList["TSMROWS"] = function()
	if not _G.GetNumAuctionItems then
		print("|cffff0000TSMDBG:|r GetNumAuctionItems not available")
		return
	end
	local count = GetNumAuctionItems("list")
	print(("|cff00ff00TSMDBG:|r %d auctions in 'list'"):format(count))
	local snapshot = { count = count, items = {} }
	for i = 1, math.min(count, 10) do
		local name, texture, qty, quality, canUse, level, minBid, minInc, buyout, bid, isHighBidder, seller = GetAuctionItemInfo("list", i)
		local link = GetAuctionItemLink("list", i)
		local tl = GetAuctionItemTimeLeft("list", i)
		snapshot.items[i] = {
			name = name, link = link, qty = qty, quality = quality, level = level,
			minBid = minBid, minInc = minInc, buyout = buyout, bid = bid,
			isHighBidder = isHighBidder, seller = seller, timeLeft = tl,
			texture = texture,
		}
		print(("  [%d] %s qty=%s buy=%s bid=%s seller=%s tl=%s"):format(
			i, tostring(name), tostring(qty), tostring(buyout), tostring(bid),
			tostring(seller), tostring(tl)))
	end
	TSMDBG.Dump("/tsmrows", snapshot)
end

-- /tsmstate — дамп внутреннего FSM AH-сканера (если возможно дотянуться)
SLASH_TSMSTATE1 = "/tsmstate"
SlashCmdList["TSMSTATE"] = function()
	print("|cff00ff00TSMDBG:|r runtime state dump")
	local state = {
		ah_visible = AuctionFrame and AuctionFrame:IsShown() or false,
		can_query = CanSendAuctionQuery and CanSendAuctionQuery() or false,
		num_auctions = GetNumAuctionItems and GetNumAuctionItems("list") or 0,
		ts_realm = GetRealmName and GetRealmName() or "?",
		ts_char = UnitName and UnitName("player") or "?",
		ts_money = GetMoney and GetMoney() or 0,
	}
	for k, v in pairs(state) do
		print(("  %s = %s"):format(k, tostring(v)))
	end
	TSMDBG.Dump("/tsmstate", state)
	print("Snapshot saved. Use ReloadUI to flush to TSMDebugDB.")
end

TSMDBG.Log("CMD", "Slash commands registered: /tsmenv /tsmscan /tsmrows /tsmstate")
