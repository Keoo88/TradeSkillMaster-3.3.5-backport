-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local WarehousingOperation = LibTSMSystem:Init("WarehousingOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local Math = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Math")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local private = {
	bagQuantityFunc = nil,
}
local OPERATION_TYPE = "Warehousing"
local VALUE_LIMITS = {
	moveQuantity = { min = 0, max = 50000 },
	keepBagQuantity = { min = 0, max = 50000 },
	keepBankQuantity = { min = 0, max = 50000 },
	restockQuantity = { min = 0, max = 50000 },
	stackSize = { min = 0, max = 200 },
	restockKeepBankQuantity = { min = 0, max = 50000 },
	restockStackSize = { min = 0, max = 200 },
}



-- ============================================================================
-- Module Loading
-- ============================================================================

WarehousingOperation:OnModuleLoad(function()
	Util.ConfigureItemPrices(OPERATION_TYPE, function(itemString, operationSettings, key)
		local value = CustomString.GetValue(operationSettings[key], itemString, true)
		local minValue, maxValue = WarehousingOperation.GetMinMaxValues(key)
		if value and (value < minValue or value > maxValue) then
			value = nil
		end
		return value
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Warehousing operation code.
---@param localizedName string The localized operation type name
---@param bagQuantityFunc fun(itemString: string): number A function to get the quantity of an item in the bags
function WarehousingOperation.Load(localizedName, bagQuantityFunc)
	private.bagQuantityFunc = bagQuantityFunc
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 12)
		:AddCustomStringSetting("moveQuantity", "0")
		:AddCustomStringSetting("keepBagQuantity", "0")
		:AddCustomStringSetting("keepBankQuantity", "0")
		:AddCustomStringSetting("restockQuantity", "0")
		:AddCustomStringSetting("stackSize", "0")
		:AddCustomStringSetting("restockKeepBankQuantity", "0")
		:AddCustomStringSetting("restockStackSize", "0")
	Operation.RegisterType(operationType)
end

---Gets the min and max value for a setting.
---@param key "moveQuantity"|"keepBagQuantity"|"keepBankQuantity"|"restockQuantity"|"stackSize"|"restockKeepBankQuantity"|"restockStackSize"
---@return number minVal
---@return number maxVal
function WarehousingOperation.GetMinMaxValues(key)
	local limits = VALUE_LIMITS[key]
	assert(limits)
	return limits.min, limits.max
end

---Gets the number of an item to move to the bank.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function WarehousingOperation.GetNumToMoveToBank(itemString, numHave)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return 0
	end
	local keepBagQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepBagQuantity", operationSettings)
	local moveQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "moveQuantity", operationSettings)
	if not keepBagQuantity or not moveQuantity then
		-- This operation isn't valid
		return 0
	end
	local numToMove = numHave
	if keepBagQuantity ~= 0 then
		numToMove = max(numToMove - keepBagQuantity, 0)
	end
	if moveQuantity ~= 0 then
		numToMove = min(numToMove, moveQuantity)
	end
	return numToMove
end

---Gets the number of an item to move to bags.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function WarehousingOperation.GetNumToMoveToBags(itemString, numHave)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return 0
	end
	local keepBankQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepBankQuantity", operationSettings)
	local moveQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "moveQuantity", operationSettings)
	local stackSize = Util.GetItemPrice(OPERATION_TYPE, itemString, "stackSize", operationSettings)
	if not keepBankQuantity or not moveQuantity or not stackSize then
		-- This operation isn't valid
		return 0
	end
	local numToMove = numHave
	if keepBankQuantity ~= 0 then
		numToMove = max(numToMove - keepBankQuantity, 0)
	end
	if moveQuantity ~= 0 then
		numToMove = min(numToMove, moveQuantity)
	end
	return Math.Floor(numToMove, stackSize ~= 0 and stackSize or 1)
end

---Gets the number of an item to move for restocking.
---@param itemString string The item string
---@param numHave number The number available to move
---@return number
function WarehousingOperation.GetNumToMoveRestock(itemString, numHave)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return 0
	end
	local restockQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockQuantity", operationSettings)
	local restockKeepBankQuantity = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockKeepBankQuantity", operationSettings)
	local restockStackSize = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockStackSize", operationSettings)
	if not restockQuantity or not restockKeepBankQuantity or not restockStackSize then
		-- This operation isn't valid
		return 0
	end
	local numInBags = private.bagQuantityFunc(itemString)
	if restockQuantity == 0 or numInBags >= restockQuantity then
		return 0
	end
	local numToMove = numHave
	if restockKeepBankQuantity ~= 0 then
		numToMove = max(numToMove - restockKeepBankQuantity, 0)
	end
	numToMove = min(numToMove, restockQuantity - numInBags)
	return Math.Floor(numToMove, restockStackSize ~= 0 and restockStackSize or 1)
end
