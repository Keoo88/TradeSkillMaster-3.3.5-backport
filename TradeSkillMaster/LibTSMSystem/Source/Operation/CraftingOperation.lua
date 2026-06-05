-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local CraftingOperation = LibTSMSystem:Init("CraftingOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local EnumType = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.EnumType")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local private = {}
CraftingOperation.ERROR = EnumType.New("CRAFTING_OPERATION_ERROR", {
	RESTOCK_QUANTITIES_CONFLICT = EnumType.NewValue(),
	MIN_RESTOCK_INVALID = EnumType.NewValue(),
	MIN_RESTOCK_INVALID_RANGE = EnumType.NewValue(),
	MAX_RESTOCK_INVALID = EnumType.NewValue(),
	MAX_RESTOCK_INVALID_RANGE = EnumType.NewValue(),
})
local OPERATION_TYPE = "Crafting"
local MIN_RESTOCK_VALUE = 0
local MAX_RESTOCK_VALUE = 2000



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Crafting operation code.
---@param localizedName string The localized operation type name
---@param validateCraftPriceMethodFunc fun(value: string, operationName: string): string Function which validates a craft price method value
function CraftingOperation.Load(localizedName, validateCraftPriceMethodFunc)
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 1)
		:AddCustomStringSetting("minRestock", "10")
		:AddCustomStringSetting("maxRestock", "20")
		:AddCustomStringSetting("minProfit", "100g")
		:AddCustomStringSetting("craftPriceMethod", "")
	Operation.RegisterType(operationType)
	for _, operationName in Operation.Iterator(OPERATION_TYPE) do
		local operation = Operation.GetSettings(OPERATION_TYPE, operationName)
		if operation.craftPriceMethod ~= "" and not validateCraftPriceMethodFunc(operation.craftPriceMethod, operationName) then
			operation.craftPriceMethod = ""
		end
	end
end

---Returns whether or not the item has a Crafting operation.
---@param itemString string The item string
---@return boolean
function CraftingOperation.HasOperation(itemString)
	return Util.GetFirstOperationByItem(OPERATION_TYPE, itemString) and true or false
end

---Gets the valid restock range.
---@return number minValue
---@return number maxValue
function CraftingOperation.GetRestockRange()
	return MIN_RESTOCK_VALUE, MAX_RESTOCK_VALUE
end

---Returns whether or not the crafting operation applied to an item is valid.
---@param itemString string The item string
---@return boolean isValid
---@return string? operationName
---@return EnumValue? errType
---@return string? errArg
---@return string? errArg2
function CraftingOperation.IsValid(itemString)
	local operationSettings, operationName = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false, operationName
	end
	local minRestock, maxRestock, errType, errArg = nil, nil, nil, nil
	minRestock, errType, errArg = private.GetMinRestock(operationSettings, itemString)
	if not minRestock then
		return false, operationName, errType, errArg
	end
	maxRestock, errType, errArg = private.GetMaxRestock(operationSettings, itemString)
	if not maxRestock then
		return false, operationName, errType, errArg
	end
	if minRestock > maxRestock then
		-- Invalid cause min > max restock quantity
		return false, operationName, CraftingOperation.ERROR.RESTOCK_QUANTITIES_CONFLICT, minRestock, maxRestock
	end
	return true, operationName
end

---Gets the restock quantity for an item.
---@param itemString string The item string
---@param haveQuantity haveQuantity How many of the item the player already has
---@return number
function CraftingOperation.GetRestockQuantity(itemString, haveQuantity)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return 0
	end
	local minRestock = private.GetMinRestock(operationSettings, itemString)
	local maxRestock = private.GetMaxRestock(operationSettings, itemString)
	if not minRestock or not maxRestock or minRestock > maxRestock then
		return 0
	end
	local neededQuantity = maxRestock - haveQuantity
	if neededQuantity <= 0 then
		-- Don't need to queue any
		return 0
	elseif neededQuantity < minRestock then
		-- We're below the min restock quantity
		return 0
	end
	return neededQuantity
end

---Gets the min profit for an item.
---@param itemString string The item string
---@return boolean hasMinProfit
---@return number? minProfit
function CraftingOperation.GetMinProfit(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false
	end
	if operationSettings.minProfit == "" then
		return false
	end
	local value = CustomString.GetValue(operationSettings.minProfit, itemString)
	return true, value
end

---Gets the crafted item value for an item.
---@param itemString string The item string
---@return boolean hasCraftPriceMethod
---@return number? value
function CraftingOperation.GetCraftedItemValue(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false
	end
	if operationSettings.craftPriceMethod == "" then
		return false
	end
	local value = CustomString.GetValue(operationSettings.craftPriceMethod, itemString)
	return true, value
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetMinRestock(operationSettings, itemString)
	local minRestock = CustomString.GetValue(operationSettings.minRestock, itemString, true)
	if not minRestock then
		return nil, CraftingOperation.ERROR.MIN_RESTOCK_INVALID, operationSettings.minRestock
	elseif minRestock < MIN_RESTOCK_VALUE or minRestock > MAX_RESTOCK_VALUE then
		return nil, CraftingOperation.ERROR.MIN_RESTOCK_INVALID_RANGE, operationSettings.minRestock
	end
	return minRestock
end

function private.GetMaxRestock(operationSettings, itemString)
	local maxRestock = CustomString.GetValue(operationSettings.maxRestock, itemString, true)
	if not maxRestock then
		return nil, CraftingOperation.ERROR.MAX_RESTOCK_INVALID, operationSettings.maxRestock
	elseif maxRestock < MIN_RESTOCK_VALUE or maxRestock > MAX_RESTOCK_VALUE then
		return nil, CraftingOperation.ERROR.MAX_RESTOCK_INVALID_RANGE, operationSettings.maxRestock
	end
	return maxRestock
end
