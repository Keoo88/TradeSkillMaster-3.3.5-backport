-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Conversion = LibTSMTypes:Init("Item.Conversion")
local MillData = LibTSMTypes:From("LibTSMData"):Include("Mill")
local ProspectData = LibTSMTypes:From("LibTSMData"):Include("Prospect")
local TransformData = LibTSMTypes:From("LibTSMData"):Include("Transform")
local VendorTradeData = LibTSMTypes:From("LibTSMData"):Include("VendorTrade")
local DisenchantData = LibTSMTypes:From("LibTSMData"):Include("Disenchant")
local TempTable = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.TempTable")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
Conversion.METHOD = EnumType.New("ITEM_CONVERSION_METHOD", {
	DISENCHANT = EnumType.NewValue(),
	MILL = EnumType.NewValue(),
	PROSPECT = EnumType.NewValue(),
	TRANSFORM = EnumType.NewValue(),
	VENDOR_TRADE = EnumType.NewValue(),
	CRAFT = EnumType.NewValue(),
})
Conversion.DISENCHANT_ITEM_CLASSES = DisenchantData.ITEM_CLASSES
local private = {
	disenchantData = nil,
	data = {},
	sourceItemCache = {},
	skippedConversions = {},
}
local MAX_CONVERSION_DEPTH = 3
local EMPTY_CONVERSION = newproxy()



-- ============================================================================
-- Module Loading
-- ============================================================================

Conversion:OnModuleLoad(function()
	for targetItemString, items in pairs(MillData.Get()) do
		for sourceItemString, data in pairs(items) do
			private.Add(targetItemString, sourceItemString, Conversion.METHOD.MILL, data.amountOfMats, data.matRate, data.minAmount, data.maxAmount, data.targetQuality, data.sourceQuality, data.requiredSkill)
		end
	end
	for targetItemString, items in pairs(ProspectData.Get()) do
		for sourceItemString, data in pairs(items) do
			private.Add(targetItemString, sourceItemString, Conversion.METHOD.PROSPECT, data.amountOfMats, data.matRate, data.minAmount, data.maxAmount, data.targetQuality, data.sourceQuality, data.requiredSkill)
		end
	end
	for targetItemString, items in pairs(TransformData.Get()) do
		for sourceItemString, rate in pairs(items) do
			private.Add(targetItemString, sourceItemString, Conversion.METHOD.TRANSFORM, rate)
		end
	end
	for targetItemString, items in pairs(VendorTradeData.Get()) do
		for sourceItemString, rate in pairs(items) do
			private.Add(targetItemString, sourceItemString, Conversion.METHOD.VENDOR_TRADE, rate)
		end
	end
	private.disenchantData = DisenchantData.Get()
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function Conversion.AddCraft(targetItemString, sourceItemString, rate)
	targetItemString = ItemString.GetBase(targetItemString)
	sourceItemString = ItemString.GetBase(sourceItemString)
	private.Add(targetItemString, sourceItemString, Conversion.METHOD.CRAFT, rate)
end

function Conversion.TargetItemIterator()
	return private.TargetItemIteratorHelper, private.data
end

function Conversion.TargetItemsByMethodIterator(sourceItemString, method)
	local context = TempTable.Acquire()
	context.sourceItemString = sourceItemString
	context.method = method
	return private.TargetItemsByMethodIteratorHelper, context, nil
end

function Conversion.GetSourceItems(targetItemString)
	if not targetItemString or not private.data[targetItemString] or private.sourceItemCache[targetItemString] == EMPTY_CONVERSION then
		return
	end
	if not private.sourceItemCache[targetItemString] then
		local depthLookup = TempTable.Acquire()
		depthLookup[targetItemString] = -1 -- set this so we don't loop back through the target item
		private.sourceItemCache[targetItemString] = {}
		private.GetSourceItemsHelper(targetItemString, private.sourceItemCache[targetItemString], depthLookup, 0, 1)
		TempTable.Release(depthLookup)
		if not next(private.sourceItemCache[targetItemString]) then
			private.sourceItemCache[targetItemString] = EMPTY_CONVERSION
			return
		end
	end
	return private.sourceItemCache[targetItemString]
end

function Conversion.SourceItemsByMethodIterator(targetItemString, method)
	local context = TempTable.Acquire()
	context.targetItemString = targetItemString
	context.method = method
	return private.SourceItemsByMethodIteratorHelper, context, nil
end

function Conversion.GetRate(sourceItemString, targetItemString)
	local info = private.data[targetItemString][sourceItemString]
	return info and info.rate or nil
end

function Conversion.DisenchantTargetItemIterator()
	return private.TargetItemIteratorHelper, private.disenchantData
end

function Conversion.GetDisenchantData(targetItemString)
	return private.disenchantData[targetItemString]
end

function Conversion.IsDisenchantTargetItem(itemString)
	return Conversion.GetDisenchantData(itemString) and true or false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Add(targetItemString, sourceItemString, method, rate, amount, minAmount, maxAmount, targetQuality, sourceQuality, skillRequired)
	assert(targetItemString and sourceItemString)

	private.data[targetItemString] = private.data[targetItemString] or {}
	if private.data[targetItemString][sourceItemString] then
		-- if there is more than one way to go from source to target, then just skip all conversions between these items
		private.skippedConversions[targetItemString..sourceItemString] = true
		private.data[targetItemString][sourceItemString] = nil
	end
	if private.skippedConversions[targetItemString..sourceItemString] then
		return
	end

	private.data[targetItemString][sourceItemString] = {
		method = method,
		rate = rate,
		amount = amount,
		minAmount = minAmount,
		maxAmount = maxAmount,
		targetQuality = targetQuality,
		sourceQuality = sourceQuality,
		skillRequired = skillRequired
	}
	wipe(private.sourceItemCache)
end

function private.GetSourceItemsHelper(targetItemString, result, depthLookup, currentDepth, currentRate)
	if currentDepth >= MAX_CONVERSION_DEPTH or not private.data[targetItemString] then
		return
	end
	for sourceItemString, info in pairs(private.data[targetItemString]) do
		if not result[sourceItemString] or depthLookup[sourceItemString] > currentDepth then
			local rate = info.rate * currentRate
			result[sourceItemString] = rate
			depthLookup[sourceItemString] = currentDepth
			private.GetSourceItemsHelper(sourceItemString, result, depthLookup, currentDepth + 1, rate)
		end
	end
end

function private.TargetItemsByMethodIteratorHelper(context, index)
	while true do
		index = next(private.data, index)
		local items = private.data[index]
		if not items then
			TempTable.Release(context)
			return
		end
		local info = items[context.sourceItemString]
		if info and ((not context.method and info.method ~= Conversion.METHOD.CRAFT) or info.method == context.method) then
			return index, info.rate, info.amount, info.minAmount, info.maxAmount, info.targetQuality, info.sourceQuality, info.skillRequired, info.method
		end
	end
end

function private.SourceItemsByMethodIteratorHelper(context, index)
	if not private.data[context.targetItemString] then
		TempTable.Release(context)
		return
	end
	while true do
		index = next(private.data[context.targetItemString], index)
		local info = private.data[context.targetItemString][index]
		if not info then
			TempTable.Release(context)
			return
		end
		if info.method == context.method then
			return index, info.rate
		end
	end
end

function private.TargetItemIteratorHelper(data, itemString)
	itemString = next(data, itemString)
	return itemString
end
