-- TradeSkillMaster_AuctionDB - Local auction scan database for 3.3.5a
-- Schema v3: per-item record {mb, mv, na, ts, mkt, hist, histDay}
--   mb = minBuyout       (per-unit копейки)
--   mv = marketValue     (per-unit копейки, дневной snapshot = DBRecent)
--   na = numAuctions     (sum stackSize)
--   ts = lastScan        (unix time)
--   mkt = DBMarket       (EMA snapshot'а ≈ retail weighted 14-day avg)
--   hist = DBHistorical  (EMA от mkt ≈ retail 60-day average)
--   histDay = день (floor(ts/86400)) последнего фолда mkt/hist

local CURRENT_VERSION = 3

-- EMA-константы (рассчитаны по retail-документации TSM):
--   MARKET_ALPHA = 0.27  → half-life ≈ 2.2 дня (≈ retail 14-дневное окно)
--   HIST_BETA    = 0.033 → ≈ 60-дневный SMA (2/(60+1))
-- Фолд происходит ОДИН РАЗ В ДЕНЬ (по calendar day), а не при каждом скане —
-- это предотвращает "вымывание" истории спам-ресканами.
local MARKET_ALPHA = 0.27
local HIST_BETA    = 0.033
-- Адаптивная alpha: если дневной snapshot отклоняется от mkt сильнее чем на
-- FAST_DEVIATION (в долях от mkt), значит EMA грубо неверна (отравленная
-- история старой формулы, резкий сдвиг рынка) и обычная alpha будет догонять
-- реальность неделю. В этом случае фолдим с FAST_ALPHA — схождение за 1-2 дня.
-- Однодневный демпинг это не ломает: даже FAST_ALPHA оставляет 40% старой
-- цены, а на следующий день рынок вернётся и mkt вернётся с ним.
local FAST_DEVIATION = 0.4
local FAST_ALPHA     = 0.6

-- Initialize / migrate database
local function EnsureDB()
	if not TSM_AuctionDB then
		TSM_AuctionDB = { __version = CURRENT_VERSION, realms = {} }
		return
	end
	TSM_AuctionDB.realms = TSM_AuctionDB.realms or {}
	local v = TSM_AuctionDB.__version or 1
	if v < 2 then
		-- v1: realms[key][is] = number (minBuyout)
		-- v2: realms[key][is] = {mb=N, mv=N, na=N, ts=N}
		for _, items in pairs(TSM_AuctionDB.realms) do
			for is, val in pairs(items) do
				if type(val) == "number" then
					items[is] = { mb = val }
				end
			end
		end
		TSM_AuctionDB.__version = 2
	end
	if v < 3 then
		-- v3: новые поля mkt/hist/histDay добавляются лениво при следующем скане
		TSM_AuctionDB.__version = 3
	end
end

local function GetRealmKey()
	local realm = GetRealmName()
	local faction = UnitFactionGroup("player")
	return faction .. " - " .. realm
end

-- Public API: write scan summary.
-- Принимает либо новый формат {[is]={mb=N, mv=N, na=N}}, либо старый {[is]=N}.
function TSM_AuctionDB_RecordScan(scanData)
	if type(scanData) ~= "table" then return 0 end
	EnsureDB()
	local key = GetRealmKey()
	TSM_AuctionDB.realms[key] = TSM_AuctionDB.realms[key] or {}
	local items = TSM_AuctionDB.realms[key]
	local now = time()
	local recorded = 0
	for is, data in pairs(scanData) do
		local mb, mv, na
		if type(data) == "number" then
			mb = data
		elseif type(data) == "table" then
			mb = data.mb or data.minBuyout
			mv = data.mv or data.marketValue
			na = data.na or data.numAuctions
		end
		if type(mb) == "number" and mb > 0 then
			local existing = items[is]
			if type(existing) ~= "table" then existing = {} end
			existing.mb = mb
			if type(mv) == "number" and mv > 0 then existing.mv = mv end
			if type(na) == "number" and na > 0 then existing.na = na end
			existing.ts = now
			-- v3: EMA-фолд DBMarket/DBHistorical, раз в календарный день.
			-- gap-decay по Δ дней сохраняет "дневную" семантику при редких сканах:
			-- если прошло N дней — применяем (1-α)^N вместо одного шага.
			if type(mv) == "number" and mv > 0 then
				local day = math.floor(now / 86400)
				if not (existing.mkt and existing.hist and existing.histDay) then
					-- первый скан для этого предмета: сидируем обе EMA
					existing.mkt, existing.hist, existing.histDay = mv, mv, day
				elseif day > existing.histDay then
					local delta = day - existing.histDay
					-- Адаптивная alpha: при большом отклонении snapshot'а от mkt
					-- (>40%) ускоряем схождение — иначе отравленная история
					-- (напр. накрученные 100g при реальном рынке 33g) неделю
					-- держала бы завышенные минималки в операциях
					local alpha = MARKET_ALPHA
					if existing.mkt > 0 and math.abs(mv - existing.mkt) / existing.mkt > FAST_DEVIATION then
						alpha = FAST_ALPHA
					end
					-- DBMarket: новый snapshot + decay-scaled EMA
					existing.mkt = math.floor(mv + (existing.mkt - mv) * (1 - alpha) ^ delta + 0.5)
					-- DBHistorical: медленная EMA от DBMarket
					existing.hist = math.floor(existing.mkt + (existing.hist - existing.mkt) * (1 - HIST_BETA) ^ delta + 0.5)
					existing.histDay = day
				end
				if type(data) == "table" then
					-- Аннотируем входную таблицу: оба скан-пути (Scanner и FullScan)
					-- передают её же в AuctionDB.RecordLocalScanResults сразу после,
					-- поэтому live holder получает свежие mkt/hist без перечтения
					-- SavedVariable.
					data.mkt  = existing.mkt
					data.hist = existing.hist
				end
			end
			items[is] = existing
			recorded = recorded + 1
		end
	end
	return recorded
end

-- Public API: read all data for current realm-faction.
-- Возвращает {[is]={mb,mv,na,ts,mkt,hist,histDay}} (кроме mb все поля опциональны).
function TSM_AuctionDB_GetRealmData()
	EnsureDB()
	local key = GetRealmKey()
	return TSM_AuctionDB.realms[key] or {}
end

-- Bootstrap: миграция при загрузке (если SavedVar уже есть)
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
	if name == "TradeSkillMaster_AuctionDB" then
		EnsureDB()
		f:UnregisterEvent("ADDON_LOADED")
	end
end)

_G.TSM_AuctionDB_RecordScan    = TSM_AuctionDB_RecordScan
_G.TSM_AuctionDB_GetRealmData  = TSM_AuctionDB_GetRealmData
