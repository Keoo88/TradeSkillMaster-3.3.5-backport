-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local ItemString = LibTSMTypes:Init("Item.ItemString")
local BonusIds = LibTSMTypes:Include("Item.BonusIds")
local SmartMap = LibTSMTypes:From("LibTSMUtil"):IncludeClassType("SmartMap")
local private = {
	itemStringCache = {},
	baseItemStringMap = nil,
	baseItemStringReader = nil,
	levelItemStringMap = nil,
	hasNonBaseItemStrings = {},
	bonusIdsTemp = {},
	modifiersTemp = {},
	modifiersValueTemp = {},
	extraStatModifiersTemp = {},
}
local ITEM_MAX_ID = 999999
local UNKNOWN_ITEM_STRING = "i:0"
local PLACEHOLDER_ITEM_STRING = "i:1"
local PET_CAGE_ITEM_STRING = "i:82800"
local IMPORTANT_MODIFIER_TYPES = {
	[9] = true,
}
local EXTRA_STAT_MODIFIER_TYPES = {
	[29] = true,
	[30] = true,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ItemString:OnModuleLoad(function()
	private.baseItemStringMap = SmartMap.New("string", "string", private.ToBaseItemString)
	private.baseItemStringReader = private.baseItemStringMap:CreateReader()
	private.levelItemStringMap = SmartMap.New("string", "string", ItemString.ToLevel)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the constant unknown item string for places where the itemString is not known.
---@return string
function ItemString.GetUnknown()
	return UNKNOWN_ITEM_STRING
end

---Gets the constant placeholder item string.
---@return string
function ItemString.GetPlaceholder()
	return PLACEHOLDER_ITEM_STRING
end

---Gets the battlepet cage item string.
---@return string
function ItemString.GetPetCage()
	return PET_CAGE_ITEM_STRING
end

---Gets the base itemString smart map.
---@return SmartMapObject
function ItemString.GetBaseMap()
	return private.baseItemStringMap
end

---Gets the level itemString smart map.
---@return SmartMapObject
function ItemString.GetLevelMap()
	return private.levelItemStringMap
end

---Converts the parameter into an itemString.
---@param item number|string Either an itemId, itemLink, or itemString to be converted
---@return string
function ItemString.Get(item)
	if not item then
		return nil
	end
	if not private.itemStringCache[item] then
		private.itemStringCache[item] = private.ToItemString(item)
	end
	return private.itemStringCache[item]
end

---Converts the parameter into an itemId.
---@param item string An item to get the id of
---@return number
function ItemString.ToId(item)
	local itemString = ItemString.Get(item)
	if type(itemString) ~= "string" then
		return
	end
	return tonumber(strmatch(itemString, "^[ip]:(%d+)"))
end

---Converts the parameter into a base itemString.
---@param itemString string An itemString to get the base itemString of
---@return string
function ItemString.GetBaseFast(itemString)
	if not itemString then
		return nil
	end
	return private.baseItemStringReader[itemString]
end

---Converts the parameter into a base itemString.
---@param item string An item to get the base itemString of
---@return string
function ItemString.GetBase(item)
	-- make sure it's a valid itemString
	local itemString = ItemString.Get(item)
	if not itemString then return end

	-- quickly return if we're certain it's already a valid baseItemString
	if type(itemString) == "string" and strmatch(itemString, "^[ip]:[0-9]+$") then return itemString end
	return ItemString.GetBaseFast(itemString)
end

---Converts an itemKey from WoW into a base itemString.
---@param itemKey ItemKey An itemKey to get the itemString of
---@return string
function ItemString.GetBaseFromItemKey(itemKey)
	if itemKey.battlePetSpeciesID > 0 then
		return "p:"..itemKey.battlePetSpeciesID
	else
		return "i:"..itemKey.itemID
	end
end

---Returns whether or not a non-base version of an item has been seen.
---@param baseItemString string A base itemString to check
---@return boolean
function ItemString.HasNonBase(baseItemString)
	return private.hasNonBaseItemStrings[baseItemString] or false
end

---Converts an itemString to a level itemString
---@param itemString string An itemString to get the level itemString of
---@return string
function ItemString.ToLevel(itemString)
	if ItemString.IsLevel(itemString) then
		-- Already a level itemString
		return itemString
	end
	local baseItemString = ItemString.GetBaseFast(itemString)
	if itemString == baseItemString then
		-- Already a base itemString
		return itemString
	end
	if ItemString.IsPet(itemString) then
		local petLevel = strmatch(itemString, "^p:%d+:(%d+):.+$")
		return petLevel and baseItemString..":i"..petLevel or baseItemString
	end
	local level = BonusIds.GetItemLevel(itemString)
	if not level then
		return baseItemString
	end
	return baseItemString.."::i"..level
end

---Parse the level modifier from a (potential) level itemString
---@param itemString string An itemString to parse
---@return number? @The item level
function ItemString.ParseLevel(itemString)
	local petLevel = strmatch(itemString, "^p:[0-9]+:i([0-9]+)$")
	if petLevel then
		return tonumber(petLevel)
	end
	local level = strmatch(itemString, "^i:[0-9]+:[0-9%-]*:i([0-9]+)")
	return level and tonumber(level) or nil
end

---Attempts to determine the itemLevel by parsing the itemString
---@param itemString string An itemString to get the itemLevel of
---@return number|nil
function ItemString.GetItemLevel(itemString)
	-- Check if this is a level itemString first
	local itemLevel = ItemString.ParseLevel(itemString)
	if itemLevel then
		return itemLevel
	end
	if ItemString.IsPet(itemString) then
		local petLevel = strmatch(itemString, "^p:%d+:(%d+):.+$")
		return petLevel and tonumber(petLevel) or nil
	else
		-- Try to get the level from the bonusIds
		return BonusIds.GetItemLevel(itemString)
	end
end

---Gets a list of stat modifier values which are present in an itemString
---@param itemString string An itemString to get the stat modifiers of
---@param fromBonusIdsOnly boolean Only get equivalent modifiers from bonusIds
---@param resultTbl table The table to store the results in
function ItemString.GetStatModifiers(itemString, fromBonusIdsOnly, resultTbl)
	if not ItemString.IsItem(itemString) then
		return
	end
	return private.GetStatModifiersHelper(resultTbl, fromBonusIdsOnly, select(4, strsplit(":", itemString)))
end

---Returns whether or not the itemString is for an item
---@param itemString string The itemString to check
---@return boolean
function ItemString.IsItem(itemString)
	return strmatch(itemString, "^i:[%-:0-9%+i]+$") and true or false
end

---Returns whether or not the itemString is a level itemString
---@param itemString string The itemString to check
---@return boolean
function ItemString.IsLevel(itemString)
	return strmatch(itemString, "^i:[0-9]+:[0-9%-]*:[i%+%-][0-9]+$") or strmatch(itemString, "^p:[0-9]+:i[0-9]+$") and true or false
end

---Returns whether or not the itemString is for a pet
---@param itemString string The itemString to check
---@return boolean
function ItemString.IsPet(itemString)
	return strmatch(itemString, "^p:[%-:0-9i]+$") and true or false
end



-- ============================================================================
-- Helper Functions
-- ============================================================================

function private.ToItemString(item)
	local paramType = type(item)
	if paramType == "string" then
		item = strtrim(item)
		local itemId = tonumber(item) or strmatch(item, "^item:(%d+)$")
		if itemId then
			item = "i:"..itemId
		else
			itemId = strmatch(item, "^[ip]:(%d+)$")
		end
		if itemId then
			if tonumber(itemId) > ITEM_MAX_ID then
				return nil
			end
			-- This is already an itemString
			return item
		end
	elseif paramType == "number" or tonumber(item) then
		local itemId = tonumber(item)
		if itemId > ITEM_MAX_ID then
			return nil
		end
		-- assume this is an itemId
		return "i:"..item
	else
		error("Invalid item parameter type: "..tostring(item))
	end

	-- test if it's already (likely) an item string or battle pet string
	if strmatch(item, "^i:([0-9%-:i%+]+)$") then
		return private.FixItemString(item)
	elseif strmatch(item, "^p:([i0-9:]+)$") then
		return private.FixPet(item)
	end

	local result = strmatch(item, "^\124cff[0-9a-z]+\124[Hh](.+)\124h%[.+%]\124h\124r$")
	if not result then
		result = strmatch(item, "^\124cnIQ[0-9]:\124[Hh](.+)\124h%[.+%]\124h\124r$")
	end
	if result then
		-- it was a full item link which we've extracted the itemString from
		item = result
	end

	-- test if it's an old style item string
	result = strjoin(":", strmatch(item, "^(i)tem:([0-9%-]+):[0-9%-]+:[0-9%-]+:[0-9%-]+:[0-9%-]+:[0-9%-]+:([0-9%-]+)$"))
	if result then
		return private.FixItemString(result)
	end

	-- test if it's an old style battle pet string (or if it was a link)
	result = strjoin(":", strmatch(item, "^battle(p)et:(%d+:%d+:%d+)"))
	if result then
		return private.FixPet(result)
	end
	result = strjoin(":", strmatch(item, "^battle(p)et:(%d+)[:]*$"))
	if result then
		return result
	end
	result = strjoin(":", strmatch(item, "^(p):(%d+:%d+:%d+)"))
	if result then
		return private.FixPet(result)
	end

	-- test if it's a long item string
	result = strjoin(":", strmatch(item, "(i)tem:([0-9%-]+):[0-9%-]*:[0-9%-]*:[0-9%-]*:[0-9%-]*:[0-9%-]*:([0-9%-]*):[0-9%-]*:[0-9%-]*:[0-9%-]*:[0-9%-]*:[0-9%-]*:([0-9%-:]+)"))
	if result and result ~= "" then
		return private.FixItemString(result)
	end

	-- test if it's a shorter item string (without bonuses)
	result = strjoin(":", strmatch(item, "(i)tem:([0-9%-]+):[0-9%-]*:[0-9%-]*:[0-9%-]*:[0-9%-]*:[0-9%-]*:([0-9%-]*)"))
	if result and result ~= "" then
		return result
	end
end

function private.RemoveExtra(itemString)
	local num = 1
	while num > 0 do
		itemString, num = gsub(itemString, ":0?$", "")
	end
	return itemString
end

function private.FixItemString(itemString)
	itemString = gsub(itemString, ":0:", "::") -- remove 0s which are in the middle
	itemString = private.RemoveExtra(itemString)
	return private.FilterBonusIdsAndModifiers(itemString, strsplit(":", itemString))
end

function private.FixPet(itemString)
	itemString = private.RemoveExtra(itemString)
	return strmatch(itemString, "^(p:%d+:%d+:%d+)$") or strmatch(itemString, "^(p:%d+:i%d+)$") or strmatch(itemString, "^(p:%d+)")
end

function private.FilterBonusIdsAndModifiers(itemString, itemType, itemId, rand, numBonusIds, ...)
	itemId = tonumber(itemId)
	assert(itemId)
	numBonusIds = tonumber(numBonusIds) or 0
	local numParts = select("#", ...)
	if numParts == 0 then
		return itemString
	elseif not LibTSMTypes.IsRetail() then
		-- No bonus IDs or modifiers on classic
		return rand and strjoin(":", itemType, itemId, rand) or itemString
	end

	-- Grab the modifiers and filter them
	local numModifiers = numParts - numBonusIds
	local modifiersStr = (numModifiers > 0 and numModifiers > 1 and numModifiers % 2 == 1) and strjoin(":", select(numBonusIds + 1, ...)) or ""
	if modifiersStr ~= "" then
		wipe(private.modifiersTemp)
		wipe(private.modifiersValueTemp)
		wipe(private.extraStatModifiersTemp)
		local num, modifierType = nil, nil
		for modifier in gmatch(modifiersStr, "[0-9]+") do
			modifier = tonumber(modifier)
			if not num then
				num = modifier
			elseif not modifierType then
				modifierType = modifier
			else
				if IMPORTANT_MODIFIER_TYPES[modifierType] then
					tinsert(private.modifiersTemp, modifierType)
					assert(not private.modifiersValueTemp[modifierType])
					private.modifiersValueTemp[modifierType] = modifier
				elseif EXTRA_STAT_MODIFIER_TYPES[modifierType] then
					tinsert(private.modifiersTemp, modifierType)
					tinsert(private.extraStatModifiersTemp, modifier)
				end
				modifierType = nil
			end
		end
		if #private.modifiersTemp > 0 then
			sort(private.modifiersTemp)
			sort(private.extraStatModifiersTemp)
			-- insert the values into modifiersTemp
			for i = #private.modifiersTemp, 1, -1 do
				local tempModifierType = private.modifiersTemp[i]
				local modifier = nil
				if EXTRA_STAT_MODIFIER_TYPES[tempModifierType] then
					modifier = tremove(private.extraStatModifiersTemp)
				else
					modifier = private.modifiersValueTemp[tempModifierType]
				end
				assert(modifier)
				tinsert(private.modifiersTemp, i + 1, modifier)
			end
			tinsert(private.modifiersTemp, 1, floor(#private.modifiersTemp / 2))
			modifiersStr = table.concat(private.modifiersTemp, ":")
		else
			modifiersStr = ""
		end
	end

	-- Filter the bonusIds
	local bonusIdsStr = ""
	if numBonusIds > 0 then
		-- get the list of bonusIds and filter them
		wipe(private.bonusIdsTemp)
		for i = 1, numBonusIds do
			private.bonusIdsTemp[i] = select(i, ...)
		end
		BonusIds.FilterTreeBonusId(private.bonusIdsTemp, itemId)
		bonusIdsStr = BonusIds.Filter(table.concat(private.bonusIdsTemp, ":"))
	end

	-- Rebuild the itemString
	itemString = strjoin(":", itemType, itemId, rand, bonusIdsStr, modifiersStr)
	itemString = gsub(itemString, ":0:", "::") -- Remove 0s which are in the middle
	return private.RemoveExtra(itemString)
end

function private.ToBaseItemString(itemString)
	local baseItemString = strmatch(itemString, "[ip]:%d+")
	if baseItemString ~= itemString then
		private.hasNonBaseItemStrings[baseItemString] = true
	end
	return baseItemString
end

function private.GetStatModifiersHelper(resultTbl, fromBonusIds, numBonusIds, ...)
	numBonusIds = tonumber(numBonusIds) or 0
	local numParts = select("#", ...)
	if numParts == 0 then
		return
	end

	-- check the bonusIds
	for i = 1, numBonusIds do
		local bonusId = select(i, ...)
		bonusId = tonumber(bonusId)
		assert(bonusId)
		local modifier = BonusIds.GetCraftingStatModifier(bonusId)
		if modifier then
			tinsert(resultTbl, modifier)
		end
	end
	if fromBonusIds then
		sort(resultTbl)
		return
	end

	-- grab the modifiers and filter them
	local numModifiers = numParts - numBonusIds
	local modifiersStr = (numModifiers > 0 and numModifiers > 1 and numModifiers % 2 == 1) and strjoin(":", select(numBonusIds + 1, ...)) or ""
	if modifiersStr == "" then
		return
	end
	local num, modifierType = nil, nil
	for modifier in gmatch(modifiersStr, "[0-9]+") do
		modifier = tonumber(modifier)
		if not num then
			num = modifier
		elseif not modifierType then
			modifierType = modifier
		else
			if EXTRA_STAT_MODIFIER_TYPES[modifierType] then
				if not tContains(resultTbl, modifier) then
					tinsert(resultTbl, modifier)
				end
			end
			modifierType = nil
		end
	end
	sort(resultTbl)
end
