-- TradeSkillMaster_AuctionDB - Local auction scan database for 3.3.5a
-- Schema v2: per-item record {mb, mv, na, ts}
--   mb = minBuyout       (per-unit копейки)
--   mv = marketValue     (per-unit копейки, формула TSM2-lite)
--   na = numAuctions     (sum stackSize)
--   ts = lastScan        (unix time)

local CURRENT_VERSION = 2

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
			items[is] = existing
			recorded = recorded + 1
		end
	end
	return recorded
end

-- Public API: read all data for current realm-faction.
-- Возвращает {[is]={mb,mv,na,ts}} (значения могут быть nil кроме mb).
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

_G.TSM_AuctionDB_RecordScan = TSM_AuctionDB_RecordScan
_G.TSM_AuctionDB_GetRealmData = TSM_AuctionDB_GetRealmData
