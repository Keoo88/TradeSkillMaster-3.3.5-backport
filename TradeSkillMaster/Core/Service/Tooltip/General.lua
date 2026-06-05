-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local General = TSM.Tooltip:NewPackage("General") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local Operation = TSM.LibTSMTypes:Include("Operation")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local Conversion = TSM.LibTSMTypes:Include("Item.Conversion")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local VendorBuy = TSM.LibTSMService:Include("Item.VendorBuy")
local Conversions = TSM.LibTSMApp:Include("Service.Conversions")
local Inventory = TSM.LibTSMApp:Include("Service.Inventory")
local AltTracking = TSM.LibTSMApp:Include("Service.AltTracking")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local Auction = TSM.LibTSMService:Include("Auction")
local Mail = TSM.LibTSMService:Include("Mail")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local private = {
	tooltipInfo = nil,
	settings = nil,
}
local CONVERT_METHODS = {
	Conversion.METHOD.MILL,
	Conversion.METHOD.PROSPECT,
	Conversion.METHOD.TRANSFORM,
	Conversion.METHOD.VENDOR_TRADE,
}
local IGNORE_INVENTORY_ITEMS = {
	["i:6948"] = true, -- Hearthstone
	["i:110560"] = true, -- Garrison Hearthstone
	["i:140192"] = true, -- Dalaran Hearthstone
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function General.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("sync", "internalData", "classKey")
		:AddKey("global", "userData", "customPriceSources")
		:AddKey("global", "userData", "customPriceSourceFormat")
		:AddKey("global", "coreOptions", "destroyValueSource")
end

function General.OnEnable()
	local tooltipInfo = TSM.Tooltip.CreateInfo()
		:SetHeadings(L["TSM General Info"])
	private.tooltipInfo = tooltipInfo
	CustomString.RegisterCustomSourceCallback(private.UpdateCustomSources)

	-- Group name
	tooltipInfo:AddSettingEntry("groupNameTooltip", nil, private.PopulateGroupLine)

	-- Operations
	for _, moduleName in Operation.TypeIterator() do
		tooltipInfo:AddSettingEntry("operationTooltips."..moduleName, false, private.PopulateOperationLine, moduleName)
	end

	-- Destroy info
	tooltipInfo:AddSettingValueEntry("destroyTooltipFormat", "full", "none", private.PopulateFullDestroyLines)
	tooltipInfo:AddSettingValueEntry("destroyTooltipFormat", "simple", "none", private.PopulateSimpleDestroyLines)

	-- Convert info
	tooltipInfo:AddSettingValueEntry("convertTooltipFormat", "full", "none", private.PopulateFullConvertLines)
	tooltipInfo:AddSettingValueEntry("convertTooltipFormat", "simple", "none", private.PopulateSimpleConvertLines)

	-- Vendor prices
	tooltipInfo:AddSettingEntry("vendorBuyTooltip", nil, private.PopulateVendorBuyLine)
	tooltipInfo:AddSettingEntry("vendorSellTooltip", nil, private.PopulateVendorSellLine)

	-- Custom sources
	private.UpdateCustomSources()

	-- Inventory info
	tooltipInfo:AddSettingValueEntry("inventoryTooltipFormat", "full", "none", private.PopulateFullInventoryLines)
	tooltipInfo:AddSettingValueEntry("inventoryTooltipFormat", "simple", "none", private.PopulateSimpleInventoryLine)

	TSM.Tooltip.Register(tooltipInfo)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateCustomSources()
	private.tooltipInfo:DeleteSettingsByKeyMatch("^customPriceTooltips%.")
	local customPriceSources = TempTable.Acquire()
	for name in pairs(private.settings.customPriceSources) do
		tinsert(customPriceSources, name)
	end
	sort(customPriceSources)
	for _, name in ipairs(customPriceSources) do
		private.tooltipInfo:AddSettingEntry("customPriceTooltips."..name, false, private.PopulateCustomPriceLine, name)
	end
	TempTable.Release(customPriceSources)
end

function private.PopulateGroupLine(tooltip, itemString)
	-- Add group / operation info
	local groupPath, itemInGroup = nil, nil
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		groupPath = L["Example"]
		itemInGroup = true
	else
		groupPath = Group.GetPathByItem(itemString)
		if groupPath == Group.GetRootPath() then
			groupPath = nil
		else
			itemInGroup = Group.IsItemInGroup(itemString)
		end
	end
	if groupPath then
		local leftText = nil
		if itemInGroup then
			leftText = GROUP
		elseif ItemString.ParseLevel(Group.TranslateItemString(itemString)) then
			leftText = GROUP.." ("..L["Item Level"]..")"
		else
			leftText = GROUP.." ("..L["Base Item"]..")"
		end
		tooltip:AddTextLine(leftText, Group.FormatPath(groupPath))
	end
end

function private.PopulateOperationLine(tooltip, itemString, moduleName)
	assert(moduleName)
	local operations = TempTable.Acquire()
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tinsert(operations, L["Example"])
	else
		local groupPath = Group.GetPathByItem(itemString)
		if groupPath == Group.GetRootPath() then
			groupPath = nil
		end
		if not groupPath then
			TempTable.Release(operations)
			return
		end
		for _, operationName in GroupOperation.OperationIterator(groupPath, moduleName) do
			tinsert(operations, operationName)
		end
	end
	if #operations > 0 then
		tooltip:AddLine(format(#operations == 1 and L["%s operation"] or L["%s operations"], Operation.GetLocalizedName(moduleName)), tooltip:ApplyValueColor(table.concat(operations, ", ")))
	end
	TempTable.Release(operations)
end

function private.PopulateFullDestroyLines(tooltip, itemString)
	private.PopulateSimpleDestroyLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:StartSection()
		tooltip:AddSubItemValueLine(ItemString.GetPlaceholder(), 2, 10, 1, 1, 20)
		tooltip:EndSection()
		return
	end
	local value, method = TSM.Crafting.GetConversionsValue(itemString, private.settings.destroyValueSource)
	if not value then
		return nil, nil
	end

	tooltip:StartSection()
	if method == Conversion.METHOD.DISENCHANT then
		local classId = ItemInfo.GetClassId(itemString)
		local quality = ItemInfo.GetQuality(itemString)
		local itemLevel = ClientInfo.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBase(itemString))
		local expansion = ClientInfo.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
		for targetItemString in Conversion.DisenchantTargetItemIterator() do
			local amountOfMats, matRate, minAmount, maxAmount = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
			if amountOfMats then
				local matValue = CustomString.GetSourceValue(private.settings.destroyValueSource, targetItemString) or 0
				if matValue > 0 then
					tooltip:AddSubItemValueLine(targetItemString, matValue, amountOfMats, matRate, minAmount, maxAmount)
				end
			end
		end
	else
		for targetItemString, amountOfMats, matRate, minAmount, maxAmount, targetQuality, sourceQuality in Conversion.TargetItemsByMethodIterator(itemString, method) do
			local matValue = CustomString.GetSourceValue(private.settings.destroyValueSource, targetItemString) or TSM.Crafting.GetConversionsValue(targetItemString, private.settings.destroyValueSource) or 0
			if matValue > 0 then
				local quality = sourceQuality and TSM.Crafting.Quality.GetExpectedSalvageResult(method, sourceQuality)
				if not targetQuality or targetQuality == quality then
					tooltip:AddSubItemValueLine(targetItemString, matValue, amountOfMats, matRate, minAmount, maxAmount)
				end
			end
		end
	end
	tooltip:EndSection()
end

function private.PopulateSimpleDestroyLines(tooltip, itemString)
	local value, method = nil, nil
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		value = 20
		method = Conversion.METHOD.PROSPECT
	else
		value, method = TSM.Crafting.GetConversionsValue(itemString, private.settings.destroyValueSource)
	end
	if not value then
		return nil, nil
	end

	local label = nil
	if method == Conversion.METHOD.DISENCHANT then
		label = L["Disenchant Value"]
	elseif method == Conversion.METHOD.MILL then
		label = L["Mill Value"]
	elseif method == Conversion.METHOD.PROSPECT then
		label = L["Prospect Value"]
	elseif method == Conversion.METHOD.TRANSFORM then
		label = L["Transform Value"]
	elseif method == Conversion.METHOD.VENDOR_TRADE then
		label = L["Vendor Trade Value"]
	else
		error("Invalid method: "..tostring(method))
	end
	tooltip:AddItemValueLine(label, value)
end

function private.PopulateFullConvertLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(format(L["Convert Value (%s)"], L["Transform"]), 55)
		tooltip:StartSection()
		tooltip:AddSubItemValueLine(ItemString.GetPlaceholder(), 55, 1)
		tooltip:EndSection()
		return
	end

	local sources = TempTable.Acquire()
	local minValue, method, methodStr = private.GetConvertTooltipInfo(itemString, sources)
	if minValue then
		tooltip:AddItemValueLine(format(L["Convert Value (%s)"], methodStr), minValue)
		tooltip:StartSection()
		for _, sourceItemString in ipairs(sources) do
			local price = sources[sourceItemString]
			tooltip:AddSubItemValueLine(sourceItemString, price, 1 / Conversion.GetRate(sourceItemString, itemString, method))
		end
		tooltip:EndSection()
	end
	TempTable.Release(sources)
end

function private.PopulateSimpleConvertLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		tooltip:AddTextLine(format(L["Convert Value (%s)"], L["Transform"]), 55)
		return
	end

	local minValue, _, methodStr = private.GetConvertTooltipInfo(itemString)
	if not minValue then
		return
	end
	tooltip:AddItemValueLine(format(L["Convert Value (%s)"], methodStr), minValue)
end

function private.GetConvertTooltipInfo(itemString, sourcesResultTbl)
	local minValue, method = nil, nil
	for i = 1, #CONVERT_METHODS do
		method = CONVERT_METHODS[i]
		for sourceItemString, rate in Conversion.SourceItemsByMethodIterator(itemString, method) do
			local value = CustomString.GetSourceValue(private.settings.destroyValueSource, sourceItemString)
			if value then
				if sourcesResultTbl then
					tinsert(sourcesResultTbl, sourceItemString)
					sourcesResultTbl[sourceItemString] = value
				end
				minValue = min(minValue or math.huge, value / rate)
			end
		end
		if minValue then
			break
		end
	end
	if not minValue then
		return nil, nil
	end
	local methodStr = nil
	if method == Conversion.METHOD.MILL then
		methodStr = L["Mill"]
	elseif method == Conversion.METHOD.PROSPECT then
		methodStr = L["Prospect"]
	elseif method == Conversion.METHOD.TRANSFORM then
		methodStr = L["Transform"]
	elseif method == Conversion.METHOD.VENDOR_TRADE then
		methodStr = L["Vendor Trade"]
	else
		error("Invalid method")
	end
	return minValue, method, methodStr
end

function private.PopulateVendorBuyLine(tooltip, itemString)
	local value = nil
	if itemString == ItemString.GetPlaceholder() then
		-- Example item
		value = 50
	else
		value = VendorBuy.Get(itemString) or 0
	end
	if value > 0 then
		tooltip:AddItemValueLine(L["Vendor Buy Price"], value)
	end
end

function private.PopulateVendorSellLine(tooltip, itemString)
	local value = nil
	if itemString == ItemString.GetPlaceholder() then
		-- Example item
		value = 8
	else
		value = ItemInfo.GetVendorSell(itemString) or 0
	end
	if value > 0 then
		tooltip:AddItemValueLine(L["Vendor Sell Price"], value)
	end
end

---@param tooltip TooltipBuilder
function private.PopulateCustomPriceLine(tooltip, itemString, name)
	assert(name)
	if not private.settings.customPriceSources[name] then
		-- TODO: this custom price source has been removed (ideally shouldn't get here)
		return
	end
	local value = nil
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		value = 10
	else
		value = CustomString.GetValue(name, itemString) or 0
	end
	if value > 0 then
		local format = private.settings.customPriceSourceFormat[name]
		if format == "gold" then
			tooltip:AddItemValueLine(L["Custom Source"].." ("..name..")", value)
		elseif format == "number" then
			tooltip:AddLine(L["Custom Source"].." ("..name..")", tooltip:ApplyValueColor(FormatLargeNumber(value)))
		elseif format == "pct" then
			tooltip:AddLine(L["Custom Source"].." ("..name..")", Theme.GetAuctionPercentColor(value):ColorText(FormatLargeNumber(value).."%"))
		end
	end
end

function private.PopulateFullInventoryLines(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		local totalNum = 0
		local playerName = UnitName("player")
		local bag, bank, auction, mail, guildQuantity = 5, 4, 4, 9, 1
		local playerTotal = bag + bank + auction + mail
		totalNum = totalNum + playerTotal
		tooltip:StartSection(L["Inventory"], format(L["%s total"], tooltip:ApplyValueColor(totalNum)))
		local classColor = RAID_CLASS_COLORS[private.settings.classKey]
		local rightText = private.RightTextFormatHelper(tooltip, L["%s (%s bags, %s bank, %s AH, %s mail)"], playerTotal, bag, bank, auction, mail)
		if classColor then
			tooltip:AddLine("|c"..classColor.colorStr..playerName.."|r", rightText)
		else
			tooltip:AddLine(playerName, rightText)
		end
		totalNum = totalNum + guildQuantity
		tooltip:AddLine(L["Example"], format(L["%s in guild vault"], tooltip:ApplyValueColor(guildQuantity)))
		tooltip:EndSection()
		return
	elseif IGNORE_INVENTORY_ITEMS[itemString] then
		return
	end

	-- Calculate the total number
	local totalNum = Inventory.GetTotalQuantity(itemString)
	tooltip:StartSection(L["Inventory"], format(L["%s total"], tooltip:ApplyValueColor(totalNum)))

	-- Add a line for the current character
	private.AddInventoryLine(tooltip, itemString)

	-- Add lines for alts
	for _, character, factionrealm in AltTracking.CharacterIterator() do
		private.AddInventoryLine(tooltip, itemString, character, factionrealm)
	end

	-- Add lines for guilds
	for _, guildName, guildQuantity in AltTracking.GuildQuantityIterator(itemString) do
		tooltip:AddLine(guildName, tooltip:ApplyValueColor(guildQuantity))
	end

	-- Add line for the warbank
	local warbankQuantity = WarbankTracking.GetQuantity(itemString)
	if warbankQuantity > 0 then
		tooltip:AddLine(L["Warbank"], tooltip:ApplyValueColor(warbankQuantity))
	end

	tooltip:EndSection()
end

function private.AddInventoryLine(tooltip, itemString, character, factionrealm)
	local bag, bank, auction, mail = nil, nil, nil, nil
	if character then
		bag = AltTracking.GetBagQuantity(itemString, character, factionrealm)
		bank = AltTracking.GetBankQuantity(itemString, character, factionrealm)
		auction = AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
		mail = AltTracking.GetMailQuantity(itemString, character, factionrealm)
	else
		bag = BagTracking.GetBagQuantity(itemString)
		bank = BagTracking.GetBankQuantity(itemString)
		auction = Auction.GetQuantity(itemString)
		mail = Mail.GetQuantity(itemString)
	end
	local playerTotal = bag + bank + auction + mail
	if playerTotal <= 0 then
		return
	end
	local characterStr = character and SessionInfo.FormatCharacterName(character, factionrealm) or SessionInfo.GetCharacterName()
	local classKey = private.settings:GetForScopeKey("classKey", character or SessionInfo.GetCharacterName(), factionrealm)
	characterStr = RAID_CLASS_COLORS[classKey] and "|c"..RAID_CLASS_COLORS[classKey].colorStr..characterStr.."|r" or characterStr
	local rightText = private.RightTextFormatHelper(tooltip, L["%s (%s bags, %s bank, %s AH, %s mail)"], playerTotal, bag, bank, auction, mail)
	tooltip:AddLine(characterStr, rightText)
end

function private.PopulateSimpleInventoryLine(tooltip, itemString)
	if itemString == ItemString.GetPlaceholder() then
		-- Example tooltip
		local totalPlayer, totalAlt, totalGuild, totalAuction, warbank = 18, 0, 1, 4, 2
		local totalNum2 = totalPlayer + totalAlt + totalGuild + totalAuction
		local rightText2 = nil
		if ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
			rightText2 = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s guild, %s warbank, %s AH)"], totalNum2, totalPlayer, totalAlt, totalGuild, warbank, totalAuction)
		elseif ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
			rightText2 = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s guild, %s AH)"], totalNum2, totalPlayer, totalAlt, totalGuild, totalAuction)
		else
			rightText2 = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s AH)"], totalNum2, totalPlayer, totalAlt, totalAuction)
		end
		tooltip:AddLine(L["Inventory"], rightText2)
		return
	elseif IGNORE_INVENTORY_ITEMS[itemString] then
		return
	end

	local totalAlt, totalAltAuction = AltTracking.GetQuantity(itemString)
	local totalPlayer = BagTracking.GetBagQuantity(itemString) + BagTracking.GetBankQuantity(itemString) + Mail.GetQuantity(itemString)
	local totalAuction = Auction.GetQuantity(itemString) + totalAltAuction
	local totalGuild = AltTracking.GetTotalGuildQuantity(itemString)
	local warbank = WarbankTracking.GetQuantity(itemString)
	local totalNum = totalPlayer + totalAlt + totalGuild + totalAuction + warbank
	if totalNum > 0 then
		local rightText = nil
		if ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
			rightText = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s guild, %s warbank, %s AH)"], totalNum, totalPlayer, totalAlt, totalGuild, warbank, totalAuction)
		elseif ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
			rightText = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s guild, %s AH)"], totalNum, totalPlayer, totalAlt, totalGuild, totalAuction)
		else
			rightText = private.RightTextFormatHelper(tooltip, L["%s (%s player, %s alts, %s AH)"], totalNum, totalPlayer, totalAlt, totalAuction)
		end
		tooltip:AddLine(L["Inventory"], rightText)
	end
end

function private.RightTextFormatHelper(tooltip, fmtStr, ...)
	local parts = TempTable.Acquire(...)
	for i = 1, #parts do
		parts[i] = tooltip:ApplyValueColor(parts[i])
	end
	local result = format(fmtStr, unpack(parts))
	TempTable.Release(parts)
	return result
end
