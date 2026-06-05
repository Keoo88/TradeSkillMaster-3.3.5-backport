-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local QueryUtil = LibTSMService:Init("AuctionScan.QueryUtil")
local Query = LibTSMService:IncludeClassType("AuctionQuery")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Item = LibTSMService:From("LibTSMWoW"):Include("API.Item")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local private = {
	itemListSortValue = {},
}
local MAX_ITEM_INFO_RETRIES = 30



-- ============================================================================
-- Module Functions
-- ============================================================================

---Generates auction queries for a list of items.
---@param itemList string[] The list of items to generate queries for
---@param callback fun(query: AuctionQuery) Function to call with generated queries
function QueryUtil.GenerateThreaded(itemList, callback)
	-- Get all the item info into the game's cache
	for _ = 1, MAX_ITEM_INFO_RETRIES do
		local isMissingItemInfo = false
		for _, itemString in ipairs(itemList) do
			if not private.HasInfo(itemString) then
				isMissingItemInfo = true
			end
			Threading.Yield()
		end
		if not isMissingItemInfo then
			break
		end
		Threading.Sleep(0.1)
	end

	-- Remove items we're missing info for
	for i = #itemList, 1, -1 do
		if not private.HasInfo(itemList[i]) then
			Log.Err("Missing item info for %s", itemList[i])
			tremove(itemList, i)
		end
		Threading.Yield()
	end
	if #itemList == 0 then
		return
	end

	-- Add all the items
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		-- Sort the item list so all base items are grouped together but keep relative ordering between base items the same
		wipe(private.itemListSortValue)
		for i, itemString in ipairs(itemList) do
			local baseItemString = ItemString.GetBaseFast(itemString)
			private.itemListSortValue[baseItemString] = private.itemListSortValue[baseItemString] or i
			private.itemListSortValue[itemString] = private.itemListSortValue[baseItemString]
		end
		sort(itemList, private.ItemListSortHelper)
		local currentBaseItemString = nil
		local currentItems = TempTable.Acquire()
		for _, itemString in ipairs(itemList) do
			local baseItemString = ItemString.GetBaseFast(itemString)
			assert(baseItemString)
			if baseItemString == currentBaseItemString then
				-- Same base item
				tinsert(currentItems, itemString)
			else
				-- New base item
				if currentBaseItemString then
					private.GenerateQuery(callback, currentItems, ItemInfo.GetName(currentBaseItemString))
					wipe(currentItems)
				end
				currentBaseItemString = baseItemString
				tinsert(currentItems, itemString)
			end
		end
		if currentBaseItemString then
			private.GenerateQuery(callback, currentItems, ItemInfo.GetName(currentBaseItemString))
			wipe(currentItems)
		end
		TempTable.Release(currentItems)
	else
		for _, itemString in ipairs(itemList) do
			private.GenerateQuery(callback, itemString, private.GetItemQueryInfo(itemString))
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetItemQueryInfo(itemString)
	local name = ItemInfo.GetName(itemString)
	local level = ItemInfo.GetMinLevel(itemString) or 0
	local quality = ItemInfo.GetQuality(itemString)
	local classId = ItemInfo.GetClassId(itemString) or 0
	local subClassId = ItemInfo.GetSubClassId(itemString) or 0
	local canHaveVariatinos, specificSubClassId = Item.ClassCanHaveVariations(classId)
	if itemString == ItemString.GetBase(itemString) and (canHaveVariatinos and (specificSubClassId or subClassId) == subClassId) then
		-- Ignoring level because level can now vary
		level = nil
	end
	return name, level, level, quality, classId, subClassId
end

function private.HasInfo(itemString)
	return ItemInfo.GetName(itemString) and ItemInfo.GetQuality(itemString) and ItemInfo.GetMinLevel(itemString)
end

function private.GenerateQuery(callback, items, name, minLevel, maxLevel, quality, class, subClass)
	local query = Query.Get()
		:SetStr(name, false)
		:SetQualityRange(quality, quality)
		:SetLevelRange(minLevel, maxLevel)
		:SetClass(class, subClass)
		:SetItems(items)
	callback(query)
end

function private.ItemListSortHelper(a, b)
	local aSortValue = private.itemListSortValue[a]
	local bSortValue = private.itemListSortValue[b]
	if aSortValue ~= bSortValue then
		return aSortValue < bSortValue
	end
	return a < b
end
