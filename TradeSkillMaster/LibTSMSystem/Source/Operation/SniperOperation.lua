-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local SniperOperation = LibTSMSystem:Init("SniperOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local OPERATION_TYPE = "Sniper"



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Sniper operation code.
---@param localizedName string The localized operation type name
function SniperOperation.Load(localizedName)
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 1)
		-- 3.3.5a: no region data, so the default uses DBMarket instead of DBRegionMarketAvg
		-- (which would always be nil and leave Sniper non-functional out of the box).
		:AddCustomStringSetting("belowPrice", "max(vendorsell, ifgt(DBMarket, 250000g, 0.8, ifgt(DBMarket, 100000g, 0.7, ifgt(DBMarket, 50000g, 0.6, ifgt(DBMarket, 25000g, 0.5, ifgt(DBMarket, 10000g, 0.4, ifgt(DBMarket, 5000g, 0.3, ifgt(DBMarket, 2000g, 0.2, ifgt(DBMarket, 1000g, 0.1, 0.05)))))))) * DBMarket)")
	Operation.RegisterType(operationType)
end

---Returns whether or not the Sniper operation is valid for an item.
---@param itemString string The item string
---@return boolean
function SniperOperation.IsValid(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return false
	end
	local isValid = CustomString.Validate(operationSettings.belowPrice)
	return isValid
end

---Returns whether or not an item has a Sniper operation.
---@param itemString any
---@return boolean
function SniperOperation.HasOperation(itemString)
	return Util.GetFirstOperationByItem(OPERATION_TYPE, itemString) and true or false
end

---Gets the max price for an item.
---@param itemString string The item string
---@return number?
function SniperOperation.GetMaxPrice(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings then
		return nil
	end
	local value = CustomString.GetValue(operationSettings.belowPrice, itemString)
	return value
end
