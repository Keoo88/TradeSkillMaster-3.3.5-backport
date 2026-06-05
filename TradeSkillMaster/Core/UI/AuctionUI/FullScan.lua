-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

-- Full Auction House scan for WoW 3.3.5
-- Tries QueryAuctionItems(..., getAll=true) first, falls back to paginated scan
-- Saves results to local AuctionDB

local TSM = select(2, ...) ---@type TSM
local FullScan = TSM.UI.AuctionUI:NewPackage("FullScan") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local private = {
	frame = nil,
	scanState = nil, -- nil | "querying" | "processing" | "paged" | "done"
	startTime = 0,
	totalAuctions = 0,
	scannedItems = 0,
	scanData = nil,
	mode = nil, -- "getAll" | "paged"
	currentPage = 0,
	totalPages = 0,
	timeoutToken = 0,
	getAllRegistered = false,
	pagedRegistered = false,
	processedIndices = nil, -- set: idx -> true для уже обработанных
	missingIndices = nil, -- список idx где link == nil (для retry, только getAll mode)
	retryPass = 0,
	stats = nil, -- diagnostic counters
	pageRetries = nil, -- map: page -> retryCount (для paged mode)
}

local MAX_RETRY_PASSES = 3
local RETRY_DELAY = 3 -- seconds between retry passes (getAll mode)
-- Paged mode: пропущенные линки добираем ЛОКАЛЬНО (повторный GetAuctionItemLink по тем же
-- индексам), БЕЗ повторного QueryAuctionItems. Данные страницы остаются в буфере "list" до
-- следующего query, а item-info ответы доходят за пару сотен мс. Это убирает целый server
-- round-trip с каждой "грязной" страницы (старый путь re-query'ил страницу = +1 round-trip).
local MAX_LINK_RESOLVE_PASSES = 2 -- локальных проходов по missing-линкам на страницу
local LINK_RESOLVE_DELAY = 0.25 -- пауза, чтобы in-flight item-info ответы успели дойти
local MIN_MISSING_FOR_RETRY = 15 -- добор включаем только если потеряли ≥30% страницы
local DEBUG_LOG_EVERY_N_PAGES = 0 -- частота snapshot-сообщений в чат
local DEBUG_LOG_RETRIES = false -- логировать каждый page retry в чат

-- ============================================================================
-- Time formatting / ETA helpers
-- ============================================================================

local function FormatDuration(seconds)
	if not seconds or seconds < 0 then return "?:??" end
	if seconds > 3600 then return "1h+" end
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds - mins * 60)
	return string.format("%d:%02d", mins, secs)
end

local function GetElapsed()
	if not private or not private.startTime or private.startTime == 0 then return 0 end
	return GetTime() - private.startTime
end

-- Возвращает строку "Mode: 1234/5678  elapsed 0:42  ETA 1:15" если progress > 0.05
local function FormatProgressLine(prefix, doneCount, totalCount)
	local elapsed = GetElapsed()
	local progress = (totalCount > 0) and (doneCount / totalCount) or 0
	local etaStr = ""
	if progress > 0.02 then
		local total = elapsed / progress
		local eta = total - elapsed
		etaStr = string.format("  ETA %s", FormatDuration(eta))
	end
	return string.format("%s %d/%d  %s%s", prefix, doneCount, totalCount, FormatDuration(elapsed), etaStr)
end

local GETALL_TIMEOUT = 15 -- seconds for getAll to respond
local PAGE_TIMEOUT = 30 -- seconds for single page to respond
local NEXT_PAGE_DELAY = 0 -- query next page immediately, server throttle gates real send rate
local THROTTLE_RETRY = 0.03 -- legacy C_Timer fallback (used only if frame poll fails)
local THROTTLE_MAX_WAIT = 30 -- seconds max wait for throttle clear before abort
local PAGE_SIZE = 50
-- Bypass probe: fire QueryAuctionItems immediately without waiting for CanSendAuctionQuery().
-- Private servers often have a shorter server-side throttle than the 1.5s client timer.
-- If the server accepts the probe → AUCTION_ITEM_LIST_UPDATE fires quickly → faster scan.
-- If the server drops it → no response within BYPASS_PROBE_TIMEOUT → fall back to frame poll.
local BYPASS_PROBE_TIMEOUT = 0.5
-- Защитное окно: внутри него резенд запрещён. Сервер мог ПРИНЯТЬ probe и ответ ещё в пути
-- (accept-response ~0.1-0.2s). Резенд той же страницы в этом окне = второй
-- AUCTION_ITEM_LIST_UPDATE → данные приедут под номером уже следующей страницы. Нельзя.
local BYPASS_PROBE_MIN = 0.2
-- Stealth getAll: fire QueryAuctionItems(..., getAll=true) regardless of canQueryAll.
-- Most private servers skip the 15-min client cooldown. If the server accepts, the
-- entire AH arrives in ONE response — scan done in seconds instead of 22+ min.
-- If server ignores → fall through to normal paged scan after STEALTH_GETALL_TIMEOUT.
-- Slow Scan = чистый page-by-page. stealth-getAll отключён: запоздавший getAll-ответ
-- прилетал в OnPagedResult и подменял paged-скан (ложный "Full scan complete"). getAll живёт только на Fast Scan.
local STEALTH_GETALL_ENABLED = false
local STEALTH_GETALL_TIMEOUT = 4
private.stealthGetAllToken = 0
private.stealthGetAllActive = false
-- Adaptive burst: server silently drops bypass probes after 5-15 acceptances.
-- Each drop costs BYPASS_PROBE_TIMEOUT (0.5s) dead time. We LEARN the burst limit
-- and proactively switch to throttle poll before hitting it — eliminating drops.
--   bypassBurstLimit adapts down on drops, recovers slowly as confidence builds.
local ADAPTIVE_BURST_ENABLED = true
private.consecutiveBypassHits = 0
private.bypassBurstLimit = 14
private.bypassBurstMin = 5
private.bypassTotalDrops = 0
private.bypassTotalHits = 0
private.bypassBurstRecoveryTimer = nil

-- Frame-based throttle poller: проверяет CanSendAuctionQuery() каждый кадр (~16ms @ 60fps),
-- быстрее чем C_Timer.After(0.03). Открывается через StartThrottlePoll, закрывается автоматически.
private.throttlePollFrame = private.throttlePollFrame or CreateFrame("Frame")
private.throttlePollFrame:Hide()
private.throttlePollFrame:SetScript("OnUpdate", function(self, elapsed)
	self._elapsed = (self._elapsed or 0) + elapsed
	if self._elapsed > THROTTLE_MAX_WAIT then
		self:Hide()
		self._elapsed = nil
		if private.scanState == "paged" then
			ChatMessage.PrintfUser("Server throttle never cleared — aborting scan.")
			private.AbortScan()
		end
		return
	end
	if CanSendAuctionQuery() then
		self:Hide()
		self._elapsed = nil
		if private.scanState == "paged" then
			private.QueryNextPage()
		end
	end
end)

local function StartThrottlePoll()
	private.throttlePollFrame._elapsed = 0
	private.throttlePollFrame:Show()
end

-- Anti-AFK: раз в ANTI_AFK_INTERVAL отправляем /say "1" в чат — сервер видит chat-пакет и сбрасывает idle-таймер.
local ANTI_AFK_INTERVAL = 300
private.antiAfkFrame = private.antiAfkFrame or CreateFrame("Frame")
private.antiAfkFrame:Hide()
private.antiAfkFrame:SetScript("OnUpdate", function(self, elapsed)
	self._elapsed = (self._elapsed or 0) + elapsed
	if self._elapsed < ANTI_AFK_INTERVAL then return end
	self._elapsed = 0
	if private.scanState == "paged" and DefaultUI.IsAuctionHouseVisible() then
		pcall(SendChatMessage, "1", "SAY")
	end
end)

function private.StartAntiAfk()
	if private.antiAfkFrame then
		private.antiAfkFrame._elapsed = 0
		private.antiAfkFrame:Show()
	end
end

function private.StopAntiAfk()
	if private.antiAfkFrame then private.antiAfkFrame:Hide() end
end

-- bypass-поллер и StartBypassPoll удалены вместе с bypass-методом (давал echo/DUP и дроп probe).
-- Ожидание снятия throttle теперь идёт только через StartThrottlePoll выше.



-- ============================================================================
-- Module Functions
-- ============================================================================

function FullScan.OnInitialize()
	if not (ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) then
		return
	end
	TSM.UI.AuctionUI.RegisterTopLevelPage("Scan", private.GetFrame)
end



-- ============================================================================
-- UI
-- ============================================================================

function private.GetFrame()
	UIUtils.AnalyticsRecordPathChange("auction", "full_scan")
	private.frame = UIElements.New("Frame", "fullScan")
		:SetLayout("VERTICAL")
		:SetPadding(16)
		:SetBackgroundColor("FULL_BLACK")
		:AddChild(UIElements.New("Text", "title")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 6)
			:SetFont("BODY_BODY1_BOLD")
			:SetText("Full Auction House Scan")
		)
		:AddChild(UIElements.New("HorizontalLine", "titleLine")
			:SetMargin(0, 0, 0, 12)
			:SetColor("ACTIVE_BG_ALT")
		)
		:AddChild(UIElements.New("Text", "desc")
			:SetHeight(80)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_BODY2")
			:SetText("Scan the entire Auction House and save its prices to your local AuctionDB.\n\n|cffffd839Fast Scan|r  -  single getAll request, reads everything at once, no cooldown.\n|cffffd839Slow Scan|r  -  page by page, slower but no cooldown.")
		)
		:AddChild(UIElements.New("Frame", "buttonsRow")
			:SetLayout("HORIZONTAL")
			:SetHeight(28)
			:SetMargin(0, 0, 0, 16)
			:AddChild(UIElements.New("ActionButton", "fastBtn")
				:SetWidth(140)
				:SetMargin(0, 8, 0, 0)
				:SetText("Fast Scan")
				:SetScript("OnClick", private.OnFastScanClick)
			)
			:AddChild(UIElements.New("ActionButton", "slowBtn")
				:SetWidth(140)
				:SetMargin(0, 8, 0, 0)
				:SetText("Slow Scan")
				:SetScript("OnClick", private.OnSlowScanClick)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("ActionButton", "abortBtn")
				:SetWidth(120)
				:SetText("Abort")
				:SetScript("OnClick", private.OnAbortClick)
			)
		)
		:AddChild(UIElements.New("ProgressBar", "progressBar")
			:SetHeight(24)
			:SetMargin(0, 0, 0, 12)
			:SetProgress(0)
			:SetText("Idle")
		)
		:AddChild(UIElements.New("Text", "result")
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY3")
			:SetText("Open the Auction House, then run Fast or Slow Scan.")
		)
	return private.frame
end

function private.PreflightChecks()
	if private.scanState and private.scanState ~= "done" then
		ChatMessage.PrintfUser("Scan already in progress. Use Abort to stop it.")
		return false
	end
	if private.scanState == "done" then
		ChatMessage.PrintfUser("Previous scan still cleaning up, wait a moment.")
		return false
	end
	if not DefaultUI.IsAuctionHouseVisible() then
		ChatMessage.PrintfUser("Open the Auction House first.")
		return false
	end
	return true
end

function private.OnFastScanClick()
	if not private.PreflightChecks() then return end
	local canQuery = CanSendAuctionQuery()
	if not canQuery then
		ChatMessage.PrintfUser("Cannot query auction right now (throttled).")
		return
	end
	-- No getAll cooldown gate: private servers ignore the 15-min client cooldown,
	-- so we fire getAll regardless of canQueryAll.
	private.StartGetAllScan()
end

function private.OnSlowScanClick()
	if not private.PreflightChecks() then return end
	local canQuery = CanSendAuctionQuery()
	if not canQuery then
		ChatMessage.PrintfUser("Cannot query auction right now (throttled).")
		return
	end
	private.StartPagedScan()
end

function private.OnAbortClick()
	if not private.scanState or private.scanState == "done" then
		ChatMessage.PrintfUser("No active scan to abort.")
		return
	end
	private.AbortScan()
end

function private.AbortScan()
	ChatMessage.PrintfUser("Scan aborted by user.")
	private.scanState = "done"
	private.UnregisterGetAll()
	private.UnregisterPaged()
	private.UnregisterStealthGetAll()
	if private.throttlePollFrame then private.throttlePollFrame:Hide() end
	if private.bypassPollFrame then private.bypassPollFrame:Hide() end
	-- Освободить ресурсы, но сохранить то что собрали
	private.FinishScan()
end



-- ============================================================================
-- GetAll Scan (fast mode)
-- ============================================================================

function private.StartGetAllScan()
	private.scanState = "querying"
	private.mode = "getAll"
	private.finished = false
	private.startTime = GetTime()
	private.totalAuctions = 0
	private.scannedItems = 0
	private.scanData = {}
	private.processedIndices = {}
	private.missingIndices = {}
	private.retryPass = 0
	private.pageRetries = {}
	private.stats = { noLink = 0, noItemString = 0, noBuyout = 0, ok = 0, retryFound = 0, pageRetries = 0 }
	private.timeoutToken = (private.timeoutToken or 0) + 1
	local myToken = private.timeoutToken

	private.SafeUpdateUI("Fast Scan: waiting for server (getAll)...", 0.05)

	Event.Register("AUCTION_ITEM_LIST_UPDATE", private.OnGetAllResult)
	private.getAllRegistered = true
	QueryAuctionItems(nil, nil, nil, nil, nil, nil, 0, nil, nil, true)

	-- Timeout: if getAll doesn't respond, abort (user can try Slow Scan)
	C_Timer.After(GETALL_TIMEOUT, function()
		if private.scanState == "querying" and private.mode == "getAll" and private.timeoutToken == myToken then
			ChatMessage.PrintfUser("Server didn't respond to Fast Scan. Try Slow Scan.")
			private.UnregisterGetAll()
			private.AbortScan()
		end
	end)
end

function private.OnGetAllResult()
	if private.scanState ~= "querying" or private.mode ~= "getAll" then return end
	private.UnregisterGetAll()

	local numBatch = GetNumAuctionItems("list")
	if numBatch == 0 then
		private.SafeUpdateUI("No auctions found.", 0)
		private.scanState = nil
		return
	end

	private.totalAuctions = numBatch
	private.scanState = "processing"
	private.SafeUpdateUI(string.format("Processing %d auctions...", numBatch), 0.1)
	private.ProcessChunk(1, numBatch)
end



-- ============================================================================
-- Stealth GetAll Probe (bypass 15-min cooldown)
-- ============================================================================

-- Fire a stealth getAll query even when canQueryAll is false. Private servers
-- often skip the 15-min client cooldown. If the server accepts → full AH in one
-- response. If server ignores → soft-land into normal paged scan.
function private.TryStealthGetAll()
    if not STEALTH_GETALL_ENABLED then
        private.StartPagedScanImpl()
        return
    end
    if private.stealthGetAllActive then
        ChatMessage.PrintfUser("|cffffaa00[FullScan]|r stealth getAll already in progress, wait...")
        return
    end
    if private.scanState and private.scanState ~= "done" then
        ChatMessage.PrintfUser("Scan already in progress. Use Abort to stop it.")
        return
    end
    if not DefaultUI.IsAuctionHouseVisible() then
        private.StartPagedScanImpl()
        return
    end

    private.scanState = "stealth"
    private.stealthGetAllToken = (private.stealthGetAllToken or 0) + 1
    local myToken = private.stealthGetAllToken
    private.stealthGetAllActive = true

    ChatMessage.PrintfUser("|cff66ccff[FullScan]|r probing stealth getAll (bypass 15-min cooldown)...")

    Event.Register("AUCTION_ITEM_LIST_UPDATE", private.OnStealthGetAllResult)
    QueryAuctionItems(nil, nil, nil, nil, nil, nil, 0, nil, nil, true)

    -- If canQueryAll was true, server likely responds in ~0.5-2s depending on AH size.
    -- If false (cooldown active), probe may be silently dropped. Wait STEALTH_GETALL_TIMEOUT
    -- then fall through to paged scan.
    C_Timer.After(STEALTH_GETALL_TIMEOUT, function()
        if private.stealthGetAllActive and private.stealthGetAllToken == myToken then
            ChatMessage.PrintfUser("|cffffaa00[FullScan]|r stealth getAll ignored by server â falling back to paged scan")
            private.UnregisterStealthGetAll()
            -- Brief pause to let client-side query state reset after the ignored getAll.
            -- Without this, the first bypass probe often echoes stale data (DUP false positive).
            C_Timer.After(0.8, function()
                if private.scanState == "stealth" then
                    private.StartPagedScanImpl()
                end
            end)
        end
    end)
end

function private.OnStealthGetAllResult()
    if not private.stealthGetAllActive then return end
    private.UnregisterStealthGetAll()

    local numBatch = GetNumAuctionItems("list")
    if not numBatch or numBatch == 0 then
        -- Server fired the event but with zero items — try paged
        ChatMessage.PrintfUser("|cffffaa00[FullScan]|r stealth getAll returned zero — falling back to paged scan")
        private.StartPagedScanImpl()
        return
    end

    -- If we got more than PAGE_SIZE items, this is definitely a getAll response.
    -- If ≤ PAGE_SIZE, could be a stale page-0 response from a previous query.
    -- We check: if numBatch > PAGE_SIZE or totalPages == 1 → treat as getAll success.
    if numBatch <= PAGE_SIZE then
        ChatMessage.PrintfUser("|cffffaa00[FullScan]|r stealth getAll returned only %d items — falling back to paged scan", numBatch)
        private.StartPagedScanImpl()
        return
    end

    ChatMessage.PrintfUser(string.format(
        "|cff00ff00[FullScan]|r STEALTH GETALL SUCCESS — %d items in one response!",
        numBatch))

    private.scanState = "processing"
    private.mode = "getAll"
    private.finished = false
    private.startTime = GetTime()
    private.totalAuctions = numBatch
    private.scannedItems = 0
    private.scanData = {}
    private.processedIndices = {}
    private.missingIndices = {}
    private.retryPass = 0
    private.pageRetries = {}
    private.stats = { noLink = 0, noItemString = 0, noBuyout = 0, ok = 0, retryFound = 0, pageRetries = 0 }

    private.SafeUpdateUI(string.format("Processing %d auctions (stealth getAll)...", numBatch), 0.1)
    private.ProcessChunk(1, numBatch)
end

function private.UnregisterStealthGetAll()
    if private.stealthGetAllActive then
        private.stealthGetAllActive = false
        pcall(Event.Unregister, "AUCTION_ITEM_LIST_UPDATE", private.OnStealthGetAllResult)
    end
end

-- ============================================================================
-- Paged Scan (fallback mode)
-- ============================================================================

function private.StartPagedScan()
    -- Try stealth getAll first; if it fails, StartPagedScanImpl kicks in
    private.TryStealthGetAll()
end

function private.StartPagedScanImpl()
	private.scanState = "paged"
	private.mode = "paged"
	private.finished = false
	private.currentPage = 0
	private.totalAuctions = private.totalAuctions or 0
	private.scannedItems = private.scannedItems or 0
	private.scanData = private.scanData or {}
	private.processedIndices = {}
	private.missingIndices = nil -- paged mode не использует global missing
	private.pageRetries = {}
	private.pageMissingList = nil
	private.lastFirstLink, private.lastLastLink, private.lastSigBatch, private.lastMidLink = nil, nil, nil, nil -- dup-detector
	private.bypassDisabled = false -- авто-отключится при первом DUP-от-bypass
	private.bypassProbeDropped = false
	private.consecutiveBypassHits = 0
		private.consecutiveDups = 0
	private.timeoutToken = (private.timeoutToken or 0) + 1 -- инвалидируем поллеры прошлого скана
	private.stats = private.stats or { noLink = 0, noItemString = 0, noBuyout = 0, ok = 0, retryFound = 0, pageRetries = 0 }
	private.startTime = private.startTime ~= 0 and private.startTime or GetTime()
	private.throttleWaits = 0
	private.SafeUpdateUI("Paged scan: page 1...", 0.05)
	-- [debug off] ChatMessage.PrintfUser(string.format("|cff00ff00[FullScan]|r Slow scan start (%s)", date("%H:%M:%S")))
	private.StartAntiAfk() -- держим персонажа активным на время долгого скана
	private.QueryNextPage()
end

function private.QueryNextPage()
	if private.scanState ~= "paged" then return end
	if not DefaultUI.IsAuctionHouseVisible() then
		private.FinishScan()
		return
	end

	if not private.pageThrottleStart then
		private.pageThrottleStart = GetTime()
	end

	local canQuery = CanSendAuctionQuery()
	if not canQuery then
		-- bypass-метод удалён (давал echo/DUP и дроп probe):
		-- всегда ждём реального снятия throttle и шлём настоящий запрос.
		StartThrottlePoll()
		return
	end

	private.throttleWaits = 0
	private.pageQuerySent = GetTime()
	private.pageThrottleWaitTime = private.pageQuerySent - (private.pageThrottleStart or private.pageQuerySent)

	Event.Register("AUCTION_ITEM_LIST_UPDATE", private.OnPagedResult)
	private.pagedRegistered = true
	QueryAuctionItems(nil, nil, nil, nil, nil, nil, private.currentPage, nil, nil)

	local pageAtStart = private.currentPage
	C_Timer.After(PAGE_TIMEOUT, function()
		if private.scanState == "paged" and private.currentPage == pageAtStart and private.pagedRegistered then
			ChatMessage.PrintfUser(string.format("Page %d timed out after %ds — aborting.", pageAtStart + 1, PAGE_TIMEOUT))
			private.AbortScan()
		end
	end)
end

function private.OnPagedResult()
	if private.scanState ~= "paged" then return end
	private.UnregisterPaged()

	-- Timing: throttle wait + server response
	local now = GetTime()
	local throttleWait = private.pageThrottleWaitTime or 0
	local serverTime = private.pageQuerySent and (now - private.pageQuerySent) or 0
	local totalPageTime = throttleWait + serverTime

	local numBatch, numTotal = GetNumAuctionItems("list")
	if private.currentPage == 0 and (private.pageRetries[0] or 0) == 0 then
		private.totalAuctions = numTotal or 0
		private.totalPages = math.ceil((numTotal or 0) / PAGE_SIZE)
		-- [debug off] ChatMessage.PrintfUser(string.format(
		-- 	"|cff00ff00[FullScan]|r totalAuctions=%d, pages=%d (PAGE_SIZE=%d)",
		-- 	private.totalAuctions, private.totalPages, PAGE_SIZE))
	end

		-- Improved DUP detection: compare first, middle, and last links (not just first+last)
		-- to avoid false positives when adjacent pages happen to share boundary items.
		local firstLink = (numBatch and numBatch > 0) and GetAuctionItemLink("list", 1) or nil
		local lastLink = (numBatch and numBatch > 0) and GetAuctionItemLink("list", numBatch) or nil
		local midIdx = numBatch and numBatch > 2 and math.floor(numBatch / 2) or nil
		local midLink = midIdx and GetAuctionItemLink("list", midIdx) or nil
		local isDup = firstLink ~= nil and firstLink == private.lastFirstLink
			and lastLink == private.lastLastLink and numBatch == private.lastSigBatch
			and (not midLink or midLink == private.lastMidLink)
		if isDup and private.stats then
			private.stats.dupPages = (private.stats.dupPages or 0) + 1
		end

		-- Печатаем тайминг КАЖДОЙ страницы; bypass=true когда throttleWait~0 (probe принят сервером)
		local modeTag = (throttleWait < 0.05) and "|cff00ff00[bypass]|r" or "[normal]"
		-- Adaptive burst tracking: count bypass hits. Only real echoes (serverTime<0.03)
		-- count as failures; false-positive DUPs are still successful bypass probes.
		if ADAPTIVE_BURST_ENABLED then
			local isRealEcho = isDup and throttleWait < 0.05 and serverTime < 0.03
			local isBypass = (throttleWait < 0.05) and not isRealEcho
			if isBypass then
				private.consecutiveBypassHits = private.consecutiveBypassHits + 1
				private.bypassTotalHits = (private.bypassTotalHits or 0) + 1
			else
				if private.bypassProbeDropped then
					private.bypassProbeDropped = false
				end
				private.consecutiveBypassHits = 0
			end
		end
		local dupTag = (isDup and serverTime < 0.03) and " |cffff0000DUP!|r" or ""
		-- [debug off] ChatMessage.PrintfUser(string.format(
		-- 	"|cff66ccff[FullScan]|r page %d/%d: %.2fs (throttle %.2fs + server %.2fs)  batch=%d %s%s",
		-- 	private.currentPage + 1, private.totalPages > 0 and private.totalPages or 0,
		-- 	totalPageTime, throttleWait, serverTime, numBatch or 0, modeTag, dupTag))

		-- bypass-метод удалён: echo-обработка (server dropped probe) убрана.
		if not isDup or serverTime >= 0.03 then
			private.consecutiveDups = 0
		end
		-- Update page fingerprint AFTER DUP check (only for clean pages)
		private.lastFirstLink, private.lastLastLink, private.lastSigBatch, private.lastMidLink =
			firstLink, lastLink, numBatch, midLink

		private.pageMissingList = private.pageMissingList or {}
		for k in pairs(private.pageMissingList) do private.pageMissingList[k] = nil end
		local pageOk, pageMissing = 0, 0
		if numBatch and numBatch > 0 then
			pageOk, pageMissing = private.ProcessPageAuctions(numBatch, private.pageMissingList)
		end

		-- Dirty page (nil links from cold item cache): resolve locally without re-query.
		-- The "list" buffer for this page is still valid; a repeated GetAuctionItemLink
		-- will return the link once the item-info response arrives.
		local passesSoFar = private.pageRetries[private.currentPage] or 0
		if numBatch and numBatch > 0
			and pageMissing > MIN_MISSING_FOR_RETRY
			and passesSoFar < MAX_LINK_RESOLVE_PASSES
		then
			private.curNumBatch = numBatch
			private.ScheduleLinkResolve(pageOk, pageMissing)
			return
		end

		private.AdvanceToNextPage(numBatch)
	end

	-- Schedule a local (no QueryAuctionItems) re-scan of missing links on the current
	-- page after LINK_RESOLVE_DELAY. currentPage does NOT advance.
	function private.ScheduleLinkResolve(pageOk, pageMissing)
		local passesSoFar = private.pageRetries[private.currentPage] or 0
		private.pageRetries[private.currentPage] = passesSoFar + 1
		if private.stats then private.stats.pageRetries = (private.stats.pageRetries or 0) + 1 end
		if DEBUG_LOG_RETRIES then
			ChatMessage.PrintfUser(string.format(
				"|cffffaa00[FullScan]|r resolve page %d locally (ok=%d miss=%d, pass %d/%d)",
				private.currentPage + 1, pageOk, pageMissing,
				passesSoFar + 1, MAX_LINK_RESOLVE_PASSES))
		end
		private.SafeUpdateUI(
			string.format("Page %d/%d resolving %d links (pass %d/%d)...",
				private.currentPage + 1, private.totalPages,
				pageMissing, passesSoFar + 1, MAX_LINK_RESOLVE_PASSES),
			0.05 + (private.currentPage / private.totalPages) * 0.9
		)
		local pageAtResolve = private.currentPage
		C_Timer.After(LINK_RESOLVE_DELAY, function()
			if private.scanState ~= "paged" or private.currentPage ~= pageAtResolve then
				return
			end
			private.ResolvePageMissing()
		end)
	end



-- Локальный повторный проход по пропущенным индексам ТЕКУЩЕЙ страницы.
-- QueryAuctionItems НЕ вызываем: буфер "list" не менялся, GetAuctionItemLink теперь
-- может вернуть линк (item-info ответы дошли за LINK_RESOLVE_DELAY).
function private.ResolvePageMissing()
	local pending = private.pageMissingList or {}
	local stillMissing = {}
	local resolved = 0
	for i = 1, #pending do
		local idx = pending[i]
		local prevOk = private.stats and private.stats.ok or 0
		if private.ProcessSingleAuction(idx) then
			if private.stats and private.stats.ok > prevOk then
				resolved = resolved + 1
			end
		else
			stillMissing[#stillMissing + 1] = idx
		end
	end
	private.pageMissingList = stillMissing
	if private.stats then private.stats.retryFound = (private.stats.retryFound or 0) + resolved end

	local pageMissing = #stillMissing
	local passesSoFar = private.pageRetries[private.currentPage] or 0
	if pageMissing > MIN_MISSING_FOR_RETRY and passesSoFar < MAX_LINK_RESOLVE_PASSES then
		private.ScheduleLinkResolve(0, pageMissing)
	else
		private.AdvanceToNextPage(private.curNumBatch or PAGE_SIZE)
	end
end

-- Сброс page-local state + переход на следующую страницу (или финиш).
function private.AdvanceToNextPage(numBatch)
	private.currentPage = private.currentPage + 1
	private.processedIndices = {}
	private.pageMissingList = nil

	if private.currentPage >= private.totalPages or numBatch == 0 then
		private.FinishScan()
		return
	end

	local progress = 0.05 + (private.currentPage / private.totalPages) * 0.9
	private.SafeUpdateUI(
		FormatProgressLine("Page", private.currentPage + 1, private.totalPages),
		progress
	)

	-- Debug-snapshot каждые N страниц: видно скорость и ETA прямо в чате.
	if DEBUG_LOG_EVERY_N_PAGES > 0
		and private.currentPage > 0
		and (private.currentPage % DEBUG_LOG_EVERY_N_PAGES) == 0
		and private.totalPages > 0
	then
		local elapsed = GetElapsed()
		local progressFrac = private.currentPage / private.totalPages
		local etaStr = "?:??"
		local rate = "?"
		if progressFrac > 0 and elapsed > 0 then
			etaStr = FormatDuration(elapsed / progressFrac - elapsed)
			rate = string.format("%.2f", private.currentPage / elapsed)
		end
		local okCount = (private.stats and private.stats.ok) or 0
		local retriesCount = (private.stats and private.stats.pageRetries) or 0
		ChatMessage.PrintfUser(string.format(
			"|cff00ff00[FullScan]|r page %d/%d elapsed %s ETA %s (%s p/s, ok=%d retries=%d)",
			private.currentPage, private.totalPages,
			FormatDuration(elapsed), etaStr, rate,
			okCount, retriesCount))
	end

	if NEXT_PAGE_DELAY > 0 then
		C_Timer.After(NEXT_PAGE_DELAY, private.QueryNextPage)
	else
		private.QueryNextPage()
	end
end

-- Возвращает: pageOk, pageMissing. missingOut (опц.) — массив, в который складываются
-- индексы с nil-линком (для локального добора без re-query).
function private.ProcessPageAuctions(count, missingOut)
	local pageOk, pageMissing = 0, 0
	for i = 1, count do
		if private.ProcessSingleAuction(i) then
			pageOk = pageOk + 1
		else
			pageMissing = pageMissing + 1
			if missingOut then missingOut[#missingOut + 1] = i end
		end
	end
	return pageOk, pageMissing
end



-- ============================================================================
-- Auction Processing
-- ============================================================================

function private.ProcessSingleAuction(idx)
	if private.processedIndices and private.processedIndices[idx] then return true end

	-- 3.3.5 signature (13 values): name, texture, count, quality, canUse, level,
	-- minBid, minIncrement, buyoutPrice, bidAmount, highBidder, owner, saleStatus.
	-- buyoutPrice = 9th position. Previous code used 10th (bidAmount) → bid-only false positives.
	local _, _, count, _, _, _, _, _, buyoutPrice = GetAuctionItemInfo("list", idx)
	local link = GetAuctionItemLink("list", idx)

	if not link then
		if private.stats then private.stats.noLink = private.stats.noLink + 1 end
		if private.mode == "getAll" and private.missingIndices then
			table.insert(private.missingIndices, idx)
		end
		return false
	end

	local itemString = ItemString.Get(link)
	local baseItemString = itemString and ItemString.GetBaseFast(itemString) or nil
	local key = baseItemString or itemString
	if not key then
		if private.stats then private.stats.noItemString = private.stats.noItemString + 1 end
		if private.mode == "getAll" and private.missingIndices then
			table.insert(private.missingIndices, idx)
		end
		return false
	end

	if not count or count <= 0 then
		if private.processedIndices then private.processedIndices[idx] = true end
		return true
	end

	-- Bid-only лоты (buyout=0): не записываем цену, но считаем na
	if not buyoutPrice or buyoutPrice <= 0 then
		if private.stats then private.stats.noBuyout = private.stats.noBuyout + 1 end
		if not private.scanData[key] then
			private.scanData[key] = { prices = {}, na = count }
		else
			private.scanData[key].na = private.scanData[key].na + count
		end
		if private.processedIndices then private.processedIndices[idx] = true end
		return true
	end

	local perUnit = math.floor(buyoutPrice / count)
	if not private.scanData[key] then
		private.scanData[key] = { mb = perUnit, prices = { perUnit }, na = count }
	else
		local data = private.scanData[key]
		if not data.mb or perUnit < data.mb then
			data.mb = perUnit
		end
		table.insert(data.prices, perUnit)
		data.na = data.na + count
	end
	private.scannedItems = private.scannedItems + 1
	if private.stats then private.stats.ok = private.stats.ok + 1 end
	if private.processedIndices then private.processedIndices[idx] = true end
	return true
end

function private.ProcessChunk(startIdx, total)
	local CHUNK_SIZE = 200
	local endIdx = math.min(startIdx + CHUNK_SIZE - 1, total)

	for i = startIdx, endIdx do
		private.ProcessSingleAuction(i)
	end

	local progress = 0.1 + (endIdx / total) * 0.7
	private.SafeUpdateUI(FormatProgressLine("Processing", endIdx, total), progress)

	if endIdx < total then
		C_Timer.After(0.02, function()
			private.ProcessChunk(endIdx + 1, total)
		end)
	else
		-- Первый проход закончен — попробуем retry для пропущенных
		private.StartRetryPass()
	end
end

function private.StartRetryPass()
	if not private.missingIndices or #private.missingIndices == 0 then
		private.FinishScan()
		return
	end
	if private.retryPass >= MAX_RETRY_PASSES then
		if ChatMessage and ChatMessage.PrintfUser then
			ChatMessage.PrintfUser(string.format("Skipped %d auctions after %d retries (item cache).", #private.missingIndices, MAX_RETRY_PASSES))
		end
		private.FinishScan()
		return
	end

	private.retryPass = private.retryPass + 1
	local pending = private.missingIndices
	private.missingIndices = {} -- очищаем, новые failures пойдут сюда
	private.SafeUpdateUI(string.format("Retry pass %d/%d (%d items)...", private.retryPass, MAX_RETRY_PASSES, #pending), 0.85 + private.retryPass * 0.03)

	-- Делаем pass через RETRY_DELAY чтобы item cache успел подгрузиться
	C_Timer.After(RETRY_DELAY, function()
		local foundThisPass = 0
		for _, idx in ipairs(pending) do
			local prevOk = private.stats and private.stats.ok or 0
			if private.ProcessSingleAuction(idx) then
				if private.stats and private.stats.ok > prevOk then
					foundThisPass = foundThisPass + 1
				end
			end
		end
		if private.stats then private.stats.retryFound = private.stats.retryFound + foundThisPass end
		private.StartRetryPass()
	end)
end



-- ============================================================================
-- Finish & Save
-- ============================================================================

function private.UnregisterGetAll()
	if private.getAllRegistered then
		private.getAllRegistered = false
		pcall(Event.Unregister, "AUCTION_ITEM_LIST_UPDATE", private.OnGetAllResult)
	end
end

function private.UnregisterPaged()
	if private.pagedRegistered then
		private.pagedRegistered = false
		pcall(Event.Unregister, "AUCTION_ITEM_LIST_UPDATE", private.OnPagedResult)
	end
end

function private.FinishScan()
	-- Защита от двойного вызова
	if private.finished then return end
	private.finished = true

	private.UnregisterGetAll()
	private.UnregisterPaged()
	private.UnregisterStealthGetAll()
	private.StopAntiAfk()

	local records = {}
	local recordCount = 0
	for key, data in pairs(private.scanData or {}) do
		-- Записываем только предметы с buyout (есть data.mb)
		if data.mb and data.mb > 0 then
			local mv = private.CalcMarketValue(data.prices) or data.mb
			records[key] = { mb = data.mb, mv = mv, na = data.na }
			recordCount = recordCount + 1
		end
	end

	-- Диагностика
	if private.stats then
		local s = private.stats
		-- [debug off] ChatMessage.PrintfUser(string.format(
		-- 	"Scan diag: ok=%d, noLink=%d, noItemString=%d, bidOnly=%d, retryFound=%d, pageRetries=%d, dupPages=%d",
		-- 	s.ok, s.noLink, s.noItemString, s.noBuyout, s.retryFound, s.pageRetries or 0, s.dupPages or 0
		-- ))
	end

	if recordCount > 0 then
		if _G.TSM_AuctionDB_RecordScan then
			_G.TSM_AuctionDB_RecordScan(records)
		end
		if TSM.AuctionDB and TSM.AuctionDB.RecordLocalScanResults then
			TSM.AuctionDB.RecordLocalScanResults(records)
		end
	end

	local elapsed = GetTime() - private.startTime
	private.scanState = "done"
	private.SafeUpdateUI(
		string.format("Done! %d auctions, %d items in %.1fs (%s mode)",
			private.totalAuctions, recordCount, elapsed, private.mode or "?"),
		1.0
	)
	ChatMessage.PrintfUser(string.format(
		"Full scan complete: %d auctions, %d items saved to local AuctionDB (%.1fs)",
		private.totalAuctions, recordCount, elapsed
	))

	C_Timer.After(3, function()
		private.scanState = nil
		private.scanData = nil
		private.SafeUpdateUI("Idle", 0)
	end)
end



-- ============================================================================
-- Safe UI Updates
-- ============================================================================

function private.SafeUpdateUI(text, progress)
	-- Весь UI update обёрнут в pcall: GetElement бросает error если child удалён,
	-- что случается при закрытии AH / переключении вкладок во время скана.
	if not private.frame then return end
	pcall(function()
		local progressBar = private.frame.GetElement and private.frame:GetElement("progressBar")
		if not progressBar then return end
		local baseFrame = progressBar._GetBaseFrame and progressBar:_GetBaseFrame()
		if not baseFrame or not baseFrame.IsVisible or not baseFrame:IsVisible() then return end
		progressBar:SetProgress(progress or 0)
		if progressBar.SetText then
			progressBar:SetText(text)
		end
		progressBar:Draw()
	end)
	-- Кнопки: отдельный pcall, чтобы крах одного не блокировал другой
	pcall(function()
		local row = private.frame:GetElement("buttonsRow")
		if not row then return end
		local active = (private.scanState ~= nil and private.scanState ~= "done")
		local fastBtn = row:GetElement("fastBtn")
		local slowBtn = row:GetElement("slowBtn")
		local abortBtn = row:GetElement("abortBtn")
		if fastBtn and fastBtn.SetDisabled then fastBtn:SetDisabled(active) end
		if slowBtn and slowBtn.SetDisabled then slowBtn:SetDisabled(active) end
		if abortBtn and abortBtn.SetDisabled then abortBtn:SetDisabled(not active) end
	end)
end



-- ============================================================================
-- Market Value (TSM 2.x lite)
-- ============================================================================

function private.CalcMarketValue(prices)
	if not prices or #prices == 0 then return nil end
	table.sort(prices)
	local n = #prices
	if n == 1 then return prices[1] end
	local startIdx = math.max(1, math.floor(n * 0.25))
	local cutoffMax = prices[startIdx] * 1.20
	local sum, cnt = 0, 0
	for i = startIdx, n do
		if prices[i] > cutoffMax and cnt > 0 then break end
		sum = sum + prices[i]
		cnt = cnt + 1
	end
	if cnt == 0 then return prices[1] end
	return math.floor(sum / cnt)
end
