-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local AuctionDB = TSM.Tooltip:NewPackage("AuctionDB")
local L = TSM.Locale.GetTable()
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local private = {
	settings = nil,
	altRealm = nil,
}
local DATA_OLD_THRESHOLD_SECONDS = 12 * 60 * 60
local REALM_INFO = {
	{ key = "minBuyout", default = true, label = L["Min Buyout"], format = "PRICE" },
	{ key = "marketValueRecent", default = false, label = L["Recent Value"], format = "PRICE" },
	{ key = "marketValue", default = "withTrend", label = L["Market Value"], format = "PRICE", hasTrend = true },
	{ key = "historical", default = false, label = L["Historical Price"], format = "PRICE" },
}
local ALT_REALM_INFO = {
	{ key = "altMinBuyout", default = false, label = L["Min Buyout"], format = "PRICE", isAltRealm = true },
	{ key = "altMarketValueRecent", default = false, label = L["Recent Value"], format = "PRICE", isAltRealm = true },
	{ key = "altMarketValue", default = "none", label = L["Market Value"], format = "PRICE", hasTrend = true, isAltRealm = true },
	{ key = "altHistorical", default = false, label = L["Historical Price"], format = "PRICE", isAltRealm = true },
}
local REGION_INFO = {
	{ key = "regionMarketValue", default = "withTrend", label = L["Region Market Value Avg"], format = "PRICE", hasTrend = true },
	{ key = "regionHistorical", default = false, label = L["Region Historical Price"], format = "PRICE" },
	{ key = "regionSale", default = true, label = L["Region Sale Avg"], format = "PRICE" },
	{ key = "regionSalePercent", default = true, label = L["Region Sale Rate"], format = "DECIMAL" },
	{ key = "regionSoldPerDay", default = true, label = L["Region Avg Daily Sold"], format = "DECIMAL" },
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function AuctionDB.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "tooltipOptions", "moduleTooltips")
		:AddKey("realm", "coreOptions", "auctionDBAltRealm")
	private.altRealm = private.settings.auctionDBAltRealm
end

function AuctionDB.OnEnable()
	local tooltipInfo = TSM.Tooltip.CreateInfo()
		:SetHeadings(L["TSM AuctionDB"], private.PopulateRightText)
		:SetSettingsModule("AuctionDB")
	private.AddTooltipInfo(tooltipInfo, REALM_INFO)
	if ClientInfo.IsRetail() then
		private.AddTooltipInfo(tooltipInfo, ALT_REALM_INFO)
		-- 3.3.5: нет TSM App → нет region-данных. Не регистрируем REGION_INFO
		-- чтобы не засорять настройки тултипа мёртвыми строками "[---]".
		private.AddTooltipInfo(tooltipInfo, REGION_INFO)
	end
	TSM.Tooltip.Register(tooltipInfo)
	private.SetDefaultTrendValues(REALM_INFO)
	if ClientInfo.IsRetail() then
		private.SetDefaultTrendValues(ALT_REALM_INFO)
		private.SetDefaultTrendValues(REGION_INFO)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AddTooltipInfo(tooltipInfo, infoTbl)
	for _, info in ipairs(infoTbl) do
		if info.hasTrend then
			tooltipInfo:AddSettingValueEntry(info.key, "noTrend", "none", private.PopulateLine, info)
			tooltipInfo:AddSettingValueEntry(info.key, "withTrend", "none", private.PopulateLineWithTrend, info)
		else
			tooltipInfo:AddSettingEntry(info.key, info.default, private.PopulateLine, info)
		end
	end
end

function private.SetDefaultTrendValues(infoTbl)
	for _, info in ipairs(infoTbl) do
		if info.hasTrend and private.settings.moduleTooltips.AuctionDB[info.key] == nil then
			private.settings.moduleTooltips.AuctionDB[info.key] = info.default
		end
	end
end

function private.PopulateLine(tooltip, itemString, info)
	local value = nil
	if itemString == ItemString.GetPlaceholder() then
		-- example tooltip
		value = 11
	else
		value = private.GetItemData(itemString, info.key)
	end
	if not value then
		return
	end
	local label = info.label
	if info.isAltRealm then
		label = private.altRealm.." - "..label
	end
	if info.format == "PRICE" then
		tooltip:AddItemValueLine(label, value)
	elseif info.format == "DECIMAL" then
		tooltip:AddTextLine(label, format("%0.3f", value))
	elseif info.format == "PERCENT" then
		local color = value >= 0 and Theme.GetColor("FEEDBACK_GREEN") or Theme.GetColor("FEEDBACK_RED")
		tooltip:AddTextLine(label, color:ColorText(format("%s%d%%", value < 0 and "-" or "", abs(value))))
	else
		error("Invalid format: "..tostring(info.format))
	end
end

function private.PopulateLineWithTrend(tooltip, itemString, info)
	local value, trend = nil, nil
	if itemString == ItemString.GetPlaceholder() then
		-- example tooltip
		value = 11
		trend = 0
	else
		value = private.GetItemData(itemString, info.key)
		local marketValue, historical = nil, nil
		if strmatch(info.key, "^region") then
			marketValue = private.GetItemData(itemString, "regionMarketValue")
			historical = private.GetItemData(itemString, "regionHistorical")
		elseif strmatch(info.key, "^alt") then
			marketValue = private.GetItemData(itemString, "altMarketValue")
			historical = private.GetItemData(itemString, "altHistorical")
		else
			marketValue = private.GetItemData(itemString, "marketValue")
			historical = private.GetItemData(itemString, "historical")
		end
		trend = marketValue and historical and Math.Round((marketValue - historical) * 100 / historical)
	end
	if not value then
		return
	end
	local trendStr = nil
	if trend then
		local color = trend >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"
		local iconTextureKey = trend >= 0 and TextureAtlas.GetFlippedVerticallyKey("iconPack.12x12/Caret/Down") or "iconPack.12x12/Caret/Down"
		local iconTextureStr = TextureAtlas.GetTextureLink(TextureAtlas.GetColoredKey(iconTextureKey, color))
		trendStr = "["..iconTextureStr..Theme.GetColor(color):ColorText(abs(trend).."%").."]"
	else
		trendStr = "[---]"
	end
	local label = info.label
	if info.isAltRealm then
		label = private.altRealm.." - "..label
	end
	tooltip:AddItemValueLine(label, value, trendStr)
end

function private.PopulateRightText(tooltip, itemString)
	local lastScan, numAuctions = nil, nil
	if itemString == ItemString.GetPlaceholder() then
		-- example tooltip
		lastScan = time() - 120
		numAuctions = 5
	else
		-- 3.3.5: предпочитаем per-item время скана (index 6 в holder, ключ
		-- "lastScan") — показывает когда именно ЭТОТ предмет был последний раз
		-- в скане, а не глобальное время последнего скана реалма.
		lastScan = TSM.AuctionDB.GetRealmItemData(itemString, "lastScan")
		if not lastScan or lastScan == 0 then
			-- fallback: глобальное время последнего App-апдейта или локального скана
			lastScan = TSM.AuctionDB.GetAppDataUpdateTimes()
			if (not lastScan or lastScan == 0) and TSM.AuctionDB.GetLocalScanTime then
				lastScan = TSM.AuctionDB.GetLocalScanTime()
			end
		end
		numAuctions = TSM.AuctionDB.GetRealmItemData(itemString, "numAuctions") or 0
	end
	if lastScan > 0 then
		local timeColor = (time() - lastScan) > DATA_OLD_THRESHOLD_SECONDS and Theme.GetColor("FEEDBACK_RED") or Theme.GetColor("FEEDBACK_GREEN")
		local timeDiff = SecondsToTime(time() - lastScan)
		return tooltip:ApplyValueColor(format(L["%d auctions"], numAuctions)).." ("..timeColor:ColorText(format(L["%s ago"], timeDiff))..")"
	else
		return tooltip:ApplyValueColor(L["Not Scanned"])
	end
end

function private.GetItemData(itemString, key)
	if strmatch(key, "^region") then
		return TSM.AuctionDB.GetRegionItemData(itemString, key)
	elseif strmatch(key, "^alt") then
		local firstLetter, remainder = strmatch(key, "^alt(.)(.+)")
		key = strlower(firstLetter)..remainder
		return TSM.AuctionDB.GetAltRealmItemData(itemString, key)
	else
		return TSM.AuctionDB.GetRealmItemData(itemString, key)
	end
end
