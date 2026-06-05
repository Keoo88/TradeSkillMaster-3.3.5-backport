-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local MatString = LibTSMTypes:Init("Crafting.MatString")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local EnumType = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.EnumType")
MatString.TYPE = EnumType.New("MAT_STRING_TYPE", {
	NORMAL = EnumType.NewValue(),
	OPTIONAL = EnumType.NewValue(),
	QUALITY = EnumType.NewValue(),
	FINISHING = EnumType.NewValue(),
	REQUIRED = EnumType.NewValue(),
})
local private = {}
local TYPE_TO_PREFIX_LOOKUP = {
	[MatString.TYPE.NORMAL] = "i",
	[MatString.TYPE.OPTIONAL] = "o",
	[MatString.TYPE.QUALITY] = "q",
	[MatString.TYPE.FINISHING] = "f",
	[MatString.TYPE.REQUIRED] = "r",
}
local PREFIX_TO_TYPE_LOOKUP = {
	i = MatString.TYPE.NORMAL,
	o = MatString.TYPE.OPTIONAL,
	q = MatString.TYPE.QUALITY,
	f = MatString.TYPE.FINISHING,
	r = MatString.TYPE.REQUIRED,
}
local QUALITY_MAT_STRING_ITEM_ID_PATTERNS_MIDNIGHT = {
	"^q:%d+:(%d+),%d+$",
	"^q:%d+:%d+,(%d+)$",
}
local QUALITY_MAT_STRING_ITEM_ID_PATTERNS = {
	"^q:%d+:(%d+),%d+,%d+$",
	"^q:%d+:%d+,(%d+),%d+$",
	"^q:%d+:%d+,%d+,(%d+)$",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a new mat string.
---@param matType table The type of the mat
---@param dataSlotIndex number The data slot index
---@param itemIds number[] The list of itemIds
---@return string
function MatString.Create(matType, dataSlotIndex, itemIds)
	assert(matType ~= MatString.TYPE.NORMAL)
	local prefix = TYPE_TO_PREFIX_LOOKUP[matType]
	assert(prefix)
	return strjoin(":", prefix, dataSlotIndex, table.concat(itemIds, ","))
end

---Gets the type of the mat string.
---@param matString string The mat string
---@return table
function MatString.GetType(matString)
	local matType = PREFIX_TO_TYPE_LOOKUP[strsplit(":", matString)]
	assert(matType)
	return matType
end

---Gets the slotId for a mat string.
---@param matString string The mat string
---@return number
function MatString.GetSlotId(matString)
	local prefix, slotId = strsplit(":", matString)
	slotId = tonumber(slotId)
	assert(slotId and prefix ~= TYPE_TO_PREFIX_LOOKUP[MatString.TYPE.NORMAL])
	return slotId
end

---Gets the mat list from a mat string.
---@param matString string The mat string
---@return string
function MatString.GetMatList(matString)
	local prefix, _, matList = strsplit(":", matString)
	assert(matList and prefix ~= TYPE_TO_PREFIX_LOOKUP[MatString.TYPE.NORMAL])
	return matList
end

---Iterates through the items in the mat string.
---@param matString string The mat string
---@return fun(): string @An iterator with fields: `itemString`
function MatString.ItemIterator(matString)
	local matType = MatString.GetType(matString)
	if matType == MatString.TYPE.NORMAL then
		return private.SingleItemIterator, matString, -1
	else
		local matList = select(3, strsplit(":", matString))
		matList = gsub(matList, "([^,]+)", "i:%1")
		return String.SplitIterator(matList, ",")
	end
end

---Returns whether or not a mat string contains an item.
---@param matString string The mat string
---@param itemId number The itemId to check for
---@return boolean
function MatString.ContainsItem(matString, itemId)
	local matList = select(3, strsplit(":", matString))
	return String.SeparatedContains(matList, ",", tostring(itemId))
end

---Gets the number of quality tiers for a quality mat string.
---@param matString string The mat string
---@return number
function MatString.GetNumQualities(matString)
	return private.IsMidnightMaterial(matString) and 2 or 3
end

---Gets the itemString for a specific quality.
---@param matString string The mat string
---@param quality number The quality
---@return string
function MatString.GetQualityItem(matString, quality)
	return "i:"..strmatch(matString, private.IsMidnightMaterial(matString) and QUALITY_MAT_STRING_ITEM_ID_PATTERNS_MIDNIGHT[quality] or QUALITY_MAT_STRING_ITEM_ID_PATTERNS[quality])
end

---Gets the itemString for a required mat at the specified index.
---@param matString string The mat string
---@param index number The index of the material
---@return string
function MatString.GetRequiredItem(matString, index)
	local matList = select(3, strsplit(":", matString))
	local itemId = select(index, strsplit(",", matList))
	return "i:"..itemId
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SingleItemIterator(itemString, prev)
	if prev == -1 then
		return itemString
	end
end

function private.IsMidnightMaterial(matString)
	return strmatch(matString, QUALITY_MAT_STRING_ITEM_ID_PATTERNS_MIDNIGHT[1]) and true or false
end
