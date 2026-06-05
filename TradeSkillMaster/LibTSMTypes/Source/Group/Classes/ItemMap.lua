-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GroupItemMap = LibTSMTypes:DefineClassType("GroupItemMap")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local SmartMap = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("SmartMap")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new group item map.
---@param inGroupFunc fun(itemString: string): boolean Function that checks if an item exists in a group
---@return GroupItemMap
function GroupItemMap.__static.New(inGroupFunc)
	return GroupItemMap(inGroupFunc)
end

---Gets the base item string map.
---@return SmartMap
function GroupItemMap.__static.GetBaseItemMap()
	return ItemString.GetBaseMap()
end

---Sanitizes an item string.
---@param itemString string The item string
---@return string?
function GroupItemMap.__static.SanitizeItemString(itemString)
	return ItemString.Get(itemString)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function GroupItemMap.__private:__init(inGroupFunc)
	self._inGroupFunc = inGroupFunc
	self._map = SmartMap.New("string", "string", self:__closure("_MapFunction"))
	self._reader = self._map:CreateReader()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Invalidates the map.
function GroupItemMap:Invalidate()
	self._map:Invalidate()
end

---Translates an itemString based on what's grouped.
---@param itemString string The item string
---@return string
function GroupItemMap:Translate(itemString)
	return self._reader[itemString]
end

---Iterates over items in the map.
---@return fun():string, string @Iterator with fields: `itemString`, `mappedItemString`
function GroupItemMap:Iterator()
	return self._map:Iterator()
end

---Handles the value changing for a given item string.
---@param itemString string The item string
function GroupItemMap:ValueChanged(itemString)
	self._map:ValueChanged(itemString)
	if itemString == ItemString.GetBaseFast(itemString) then
		-- This is a base item string, so need to also update all other items whose base item is equal to this item
		for mapItemString in self._map:Iterator() do
			if ItemString.GetBaseFast(mapItemString) == itemString then
				self._map:ValueChanged(mapItemString)
			end
		end
	elseif itemString == ItemString.ToLevel(itemString) then
		-- This is a level item string, so need to also update all other items whose level item is equal to this item
		for mapItemString in self._map:Iterator() do
			if ItemString.ToLevel(mapItemString) == itemString then
				self._map:ValueChanged(mapItemString)
			end
		end
	end
end

---Handles the value changing for the specified items.
---@param changedItems table<string,boolean> The items which changed
function GroupItemMap:ValuesChanged(changedItems)
	for itemString in self._map:Iterator() do
		if changedItems[itemString] or changedItems[ItemString.GetBaseFast(itemString)] or changedItems[ItemString.ToLevel(itemString)] then
			self._map:ValueChanged(itemString)
		end
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function GroupItemMap.__private:_MapFunction(itemString)
	-- Check if the specific itemString is in a group
	if self._inGroupFunc(itemString) then
		return itemString
	end

	-- Check if the level itemString is in a group
	local levelItemString = ItemString.ToLevel(itemString)
	if self._inGroupFunc(levelItemString) then
		return levelItemString
	end

	-- Check if the base itemString is in a group
	local baseItemString = ItemString.GetBaseFast(itemString)
	if self._inGroupFunc(baseItemString) then
		return baseItemString
	end

	-- Return the original itemString
	return itemString
end
