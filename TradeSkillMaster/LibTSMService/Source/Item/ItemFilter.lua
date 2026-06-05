-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local ItemFilter = LibTSMService:DefineClassType("ItemFilter")
local ItemFilterPart = LibTSMService:IncludeClassType("ItemFilterPart")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local String = LibTSMService:From("LibTSMUtil"):Include("Lua.String")
local Money = LibTSMService:From("LibTSMUtil"):Include("UI.Money")
local ItemClass = LibTSMService:From("LibTSMWoW"):Include("Util.ItemClass")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {
	parts = nil,
	addedKeys = {},
	validateDataTemp = {},
}
ItemFilter.ERROR = EnumType.New("ITEM_FILTER_ERROR", {
	ITEM_NOT_FOUND = EnumType.NewValue(),
	DUPLICATE_FILTER = EnumType.NewValue(),
	MAX_QUANTITY_ZERO = EnumType.NewValue(),
	UNKNOWN_WORD = EnumType.NewValue(),
	CRAFTING_DISENCHANT_ADDITIONAL = EnumType.NewValue(),
})
local IS_NON_CRAFTING_KEY = {
	minLevel = true,
	maxLevel = true,
	minItemLevel = true,
	maxItemLevel = true,
	class = true,
	subClass = true,
	invSlotId = true,
	minQuality = true,
	maxQuality = true,
	uncollected = true,
	usable = true,
	upgrades = true,
	exact = true,
}
local IS_NON_CRAFTING_KEY_WITH_ITEM = {
	minItemLevel = true,
	maxItemLevel = true,
	invSlotId = true,
	uncollected = true,
	usable = true,
	upgrades = true,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new item filter object.
---@return ItemFilter
function ItemFilter.__static.New()
	private.InitializeParts()
	return ItemFilter()
end

---Validates a string.
---@param str string The string to validate
---@return boolean isValid
---@return EnumValue|nil errType
---@return string|nil errArg
function ItemFilter.__static.ValidateStr(str)
	assert(not next(private.validateDataTemp))
	local isValid, errType, errArg = private.ParseStr(str, private.validateDataTemp)
	wipe(private.validateDataTemp)
	if not isValid then
		return false, errType, errArg
	end
	return true
end

---Adds a key match filter part.
---@param key string The key to match against
---@param evalFunc fun(item: string): boolean The function which evalulates the filter part
function ItemFilter.__static.AddKeyMatchPart(key, evalFunc)
	private.InitializeParts()
	assert(type(key) == "string" and key ~= "" and strlower(key) == key)
	for _, part in ipairs(private.parts) do
		assert(not part:HasKey(key))
	end
	tinsert(private.parts, ItemFilterPart.NewKeyMatch(key):SetEvalFunc(evalFunc))
	private.addedKeys[key] = true
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function ItemFilter.__private:__init()
	self._isValid = false
	self._data = {}
	self:_Reset()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Parses the specifed string.
---@param str string The string to validate
---@return boolean isValid
---@return EnumValue|nil errType
---@return string|nil errArg
function ItemFilter:ParseStr(str)
	self:_Reset()
	local isValid, errType, errArg = private.ParseStr(str, self._data)
	self._isValid = isValid
	return isValid, errType, errArg
end

---Gets the string.
---@return string?
function ItemFilter:GetStr()
	return self._data.str
end

---Gets the item.
---@return string?
function ItemFilter:GetItem()
	return self._data.item
end

---Gets the min quality.
---@return number?
function ItemFilter:GetMinQuality()
	return self._data.minQuality
end

---Gets the max quality.
---@return number?
function ItemFilter:GetMaxQuality()
	return self._data.maxQuality
end

---Gets the item class ID.
---@return number?
function ItemFilter:GetClass()
	return self._data.class
end

---Gets the item sub class ID.
---@return number?
function ItemFilter:GetSubClass()
	return self._data.subClass
end

---Gets the item inventory slot ID.
---@return number?
function ItemFilter:GetInvSlotId()
	return self._data.invSlotId
end

---Gets the min required level.
---@return number?
function ItemFilter:GetMinLevel()
	return self._data.minLevel
end

---Gets the max required level.
---@return number?
function ItemFilter:GetMaxLevel()
	return self._data.maxLevel
end

---Gets the min item level.
---@return number?
function ItemFilter:GetMinItemLevel()
	return self._data.minItemLevel
end

---Gets the max item level.
---@return number?
function ItemFilter:GetMaxItemLevel()
	return self._data.maxItemLevel
end

---Gets the uncollected value.
---@return boolean?
function ItemFilter:GetUncollected()
	return self._data.uncollected
end

---Gets the usable only value.
---@return boolean?
function ItemFilter:GetUsableOnly()
	return self._data.usable
end

---Gets the upgrades value.
---@return boolean?
function ItemFilter:GetUpgrades()
	return self._data.upgrades
end

---Gets the exact only value.
---@return boolean?
function ItemFilter:GetExactOnly()
	return self._data.exact
end

---Gets the max quantity.
---@return number?
function ItemFilter:GetMaxQuantity()
	return self._data.maxQuantity
end

---Gets the min price.
---@return number?
function ItemFilter:GetMinPrice()
	return self._data.price2 and self._data.price1 or nil
end

---Gets the max price.
---@return number?
function ItemFilter:GetMaxPrice()
	return self._data.price2 or self._data.price1
end

---Gets whether or not it's a crafting filter.
---@return boolean?
function ItemFilter:GetCrafting()
	return self._data.crafting
end

---Gets whether or not it's a disenchant filter.
---@return boolean?
function ItemFilter:GetDisenchant()
	return self._data.disenchant
end

---Gets the value for an added key match key.
---@param key string The key
---@return boolean
function ItemFilter:GetAddedKeyValue(key)
	assert(private.addedKeys[key])
	return self._data[key]
end

---Gets whether or not the item matches the filter.
---@param item string The item
---@param price number The price value for the item
---@return boolean
function ItemFilter:Matches(item, price)
	if not self._isValid then
		return false
	end

	-- Check the name
	local name = ItemInfo.GetName(item)
	name = name and strlower(name) or ""
	if not strfind(name, self._data.escapedStr or "") or (self._data.exact and name ~= (self._data.str or "")) then
		return false
	end

	-- Check all the other parts
	for _, part in ipairs(private.parts) do
		if not part:Matches(item, self._data, price) then
			return false
		end
	end

	-- It passed!
	return true
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ItemFilter.__private:_Reset()
	self._isValid = false
	wipe(self._data)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.InitializeParts()
	if private.parts then
		return
	end
	private.parts = {
		ItemFilterPart.NewKeyMatch("usable"),
		ItemFilterPart.NewKeyMatch("exact"),
		ItemFilterPart.NewKeyMatch("crafting", "disenchant"),
		ItemFilterPart.NewKeyMatch("disenchant", "crafting"),
		ItemFilterPart.NewNumberMatch("maxQuantity", nil, "^x(%d+)$"),
		ItemFilterPart.NewNumberMatch("minItemLevel", "maxItemLevel", "^i(%d+)$")
			:SetEvalFunc(function(item, minItemLevel, maxItemLevel)
				local itemLevel = ItemInfo.GetItemLevel(item) or 0
				return itemLevel >= minItemLevel and itemLevel <= (maxItemLevel or math.huge)
			end),
		ItemFilterPart.NewFunctionMatch("minLevel", "maxLevel", tonumber)
			:SetEvalFunc(function(item, minLevel, maxLevel)
				local level = ItemInfo.GetMinLevel(item) or 0
				return level >= minLevel and level <= (maxLevel or math.huge)
			end),
		ItemFilterPart.NewFunctionMatch("price1", "price2", Money.FromString)
			:SetEvalFunc(function(_, price1, price2, itemPrice)
				local minPrice, maxPrice = nil, nil
				if price2 then
					minPrice = price1
					maxPrice = price2
				else
					minPrice = 0
					maxPrice = price1
				end
				-- Check the priceInfo
				itemPrice = itemPrice or 0
				return itemPrice >= minPrice and itemPrice <= maxPrice
			end),
		ItemFilterPart.NewFunctionMatch("class", nil, ItemClass.GetClassIdFromClassString)
			:SetEvalFunc(function(item, class)
				return ItemInfo.GetClassId(item) == class
			end),
		ItemFilterPart.NewFunctionMatch("subClass", nil, ItemClass.GetSubClassIdFromSubClassString, "class")
			:SetEvalFunc(function(item, subClass)
				return ItemInfo.GetSubClassId(item) == subClass
			end),
		ItemFilterPart.NewFunctionMatch("invSlotId", nil, ItemClass.GetInventorySlotIdFromInventorySlotString)
			:SetEvalFunc(function(item, invSlotId)
				return ItemInfo.GetInvSlotId(item) == invSlotId
			end),
		ItemFilterPart.NewFunctionMatch("minQuality", "maxQuality", private.ItemQualityToIndex)
			:SetEvalFunc(function(item, minQuality, maxQuality)
				local quality = ItemInfo.GetQuality(item) or -1
				return quality >= minQuality and quality <= (maxQuality or math.huge)
			end),
	}
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_UNCOLLECTED_FILTER) then
		tinsert(private.parts, ItemFilterPart.NewKeyMatch("uncollected"))
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_UPGRADES_FILTER) then
		tinsert(private.parts, ItemFilterPart.NewKeyMatch("upgrades"))
	end
end

function private.ParseStr(str, data)
	-- Request item info in case we fail due to not having it (for next time)
	for symbol in String.SplitIterator(strtrim(str), "/") do
		if strmatch(symbol, "^[ip]:[0-9]+") then
			ItemInfo.FetchInfo(symbol)
		end
	end

	-- Parse and validate each symbol
	local isFirstPart = true
	for symbol in String.SplitIterator(strtrim(str), "/", true) do
		symbol = strtrim(symbol)
		local isValid, errType, errArg = nil, nil, nil
		if isFirstPart then
			isFirstPart = false
			isValid, errType, errArg = private.HandleFirstSymbol(symbol, data)
		elseif symbol == "" then
			-- Ignore an empty symbol
			isValid = true
		else
			isValid, errType, errArg = private.HandleSymbol(symbol, data)
		end
		if not isValid then
			return false, errType, errArg
		end
	end

	-- Extra validation
	if data.maxQuantity == 0 then
		return false, ItemFilter.ERROR.MAX_QUANTITY_ZERO
	end
	if data.crafting or data.disenchant then
		for key in pairs(data) do
			if (data.item and IS_NON_CRAFTING_KEY_WITH_ITEM[key]) or (not data.item and IS_NON_CRAFTING_KEY[key]) or private.addedKeys[key] then
				return false, ItemFilter.ERROR.CRAFTING_DISENCHANT_ADDITIONAL
			end
		end
	end

	return true
end

function private.HandleFirstSymbol(symbol, data)
	if strmatch(symbol, "^[ip]:[0-9]+") then
		-- This is an item
		local name = ItemInfo.GetName(symbol)
		local level = ItemInfo.GetMinLevel(symbol)
		local quality = ItemInfo.GetQuality(symbol)
		if not name or not level or not quality then
			return false, ItemFilter.ERROR.ITEM_NOT_FOUND
		end
		name = strlower(name)
		data.exact = true
		data.item = symbol
		data.str = name
		data.escapedStr = String.Escape(name)
		data.minQuality = quality
		data.maxQuality = quality
		data.minLevel = level
		data.maxLevel = level
		data.class = ItemInfo.GetClassId(symbol) or 0
		data.subClass = ItemInfo.GetSubClassId(symbol) or 0
	elseif symbol ~= "" then
		symbol = strlower(symbol)
		data.str = symbol
		data.escapedStr = String.Escape(symbol)
	end
	return true
end

function private.HandleSymbol(symbol, data)
	for _, part in ipairs(private.parts) do
		local wasValid = part:HandleSymbol(symbol, data)
		if wasValid ~= nil then
			return wasValid, not wasValid and ItemFilter.ERROR.DUPLICATE_FILTER or nil
		end
	end
	return false, ItemFilter.ERROR.UNKNOWN_WORD, symbol
end

function private.ItemQualityToIndex(str)
	for i = 0, 7 do
		local text =  _G["ITEM_QUALITY"..i.."_DESC"]
		if strlower(str) == strlower(text) then
			return i
		end
	end
end
