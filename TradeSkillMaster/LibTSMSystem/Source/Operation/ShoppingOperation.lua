-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local ShoppingOperation = LibTSMSystem:Init("ShoppingOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local EnumType = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.EnumType")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local private = {
	inventoryNumFunc = nil,
}
ShoppingOperation.ERROR = EnumType.New("SHOPPING_OPERATION_ERROR", {
	MAX_PRICE_INVALID = EnumType.NewValue(),
	RESTOCK_INVALID = EnumType.NewValue(),
	RESTOCK_INVALID_RANGE = EnumType.NewValue(),
})
local OPERATION_TYPE = "Shopping"
local MIN_RESTOCK_VALUE = 0
local MAX_RESTOCK_VALUE = 50000



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Shopping operation code.
---@alias ShoppingOperationInventoryNumFunc fun(itemString: string, includeBank: boolean, includeAuctions: boolean, includeAlts: boolean, includeGuilds: boolean): number
---@param localizedName string The localized operation type name
---@param inventoryNumFunc ShoppingOperationInventoryNumFunc to get the number in inventory for restocking against
function ShoppingOperation.Load(localizedName, inventoryNumFunc)
	private.inventoryNumFunc = inventoryNumFunc
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 1)
		:AddCustomStringSetting("restockQuantity", "0")
		:AddCustomStringSetting("maxPrice", "dbmarket")
		:AddBooleanSetting("showAboveMaxPrice", true)
		:AddTableSetting("restockSources", { alts = false, auctions = false, bank = false, guild = false })
	Operation.RegisterType(operationType)
end

---Gets the range of valid restock quantity values.
---@return number minValue
---@return number maxValue
function ShoppingOperation.GetRestockRange()
	return MIN_RESTOCK_VALUE, MAX_RESTOCK_VALUE
end

---Gets the max price for an item.
---@param itemString string The item string
---@return number?
function ShoppingOperation.GetMaxPrice(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return nil
	end
	local value = CustomString.GetValue(operationSettings.maxPrice, itemString)
	return value
end

---Gets whether or not auctions of the item above the max price should be shown.
---@param itemString string The item string
---@return boolean
function ShoppingOperation.ShouldShowAboveMaxPrice(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	return operationSettings and operationSettings.showAboveMaxPrice or false
end

---Returns whether or not a buyout value for an item should be filtered.
---@param itemString string The item string
---@param itemBuyout number The item buyout price
---@return boolean isFiltered
---@return boolean aboveMax
function ShoppingOperation.IsFiltered(itemString, itemBuyout)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return true
	end
	if operationSettings.showAboveMaxPrice then
		return false
	end
	local maxPrice = CustomString.GetValue(operationSettings.maxPrice, itemString)
	if itemBuyout > (maxPrice or 0) then
		return true, true
	end
	return false
end

---Validates and gets the restock quantity for an item.
---@param itemString string The item string
---@return boolean isValid
---@return number|EnumValue|nil maxQuantityOrErrType
---@return any errArg
function ShoppingOperation.ValidateAndGetRestockQuantity(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false, nil
	end
	if not CustomString.Validate(operationSettings.maxPrice) then
		return false, ShoppingOperation.ERROR.MAX_PRICE_INVALID, operationSettings.maxPrice
	end
	local restockQuantity = CustomString.GetValue(operationSettings.restockQuantity, itemString, true)
	if not restockQuantity then
		return false, ShoppingOperation.ERROR.RESTOCK_INVALID, operationSettings.restockQuantity
	elseif restockQuantity < MIN_RESTOCK_VALUE or restockQuantity > MAX_RESTOCK_VALUE then
		return false, ShoppingOperation.ERROR.RESTOCK_INVALID_RANGE, operationSettings.restockQuantity
	end
	local maxQuantity = nil
	if restockQuantity > 0 then
		local numHave = private.inventoryNumFunc(itemString, operationSettings.restockSources.bank, operationSettings.restockSources.auctions, operationSettings.restockSources.alts, operationSettings.restockSources.guild)
		if numHave >= restockQuantity then
			return false, nil
		end
		maxQuantity = restockQuantity - numHave
	end
	if not operationSettings.showAboveMaxPrice and not CustomString.GetValue(operationSettings.maxPrice, itemString) then
		-- We're not showing auctions above the max price and the max price isn't valid for this item, so skip it
		return false, nil
	end
	return true, maxQuantity
end
