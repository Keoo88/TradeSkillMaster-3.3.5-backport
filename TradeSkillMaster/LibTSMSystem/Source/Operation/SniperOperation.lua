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
		-- 3.3.5a: Safe Tiered Anti-Scam Sniper Formula
		-- 1. Arbitrage Floors: 1.1 * vendorsell (vendor profit), 0.85 * destroy (disenchant profit)
		-- 2. Anti-Market-Manipulation: min(DBMarket, DBHistorical) to counter single-day fake inflation
		-- 3. Quality-based Hard Caps (Anti-Trash/Anti-Zombie):
		--    - Epic (quality >= 4): 65% market discount, capped at 1500g
		--    - Rare (quality == 3): 30% market discount, capped at 200g
		--    - Green (quality == 2): 10% market discount, capped at 15g (never pay hundreds of gold for junk greens)
		--    - White/Poor (quality <= 1): capped at 2g (pure vendor/destroy arbitrage)
		:AddCustomStringSetting("belowPrice", "max(1.1 * vendorsell, 0.85 * destroy, min(min(DBMarket, ifgt(DBHistorical, 0c, DBHistorical, DBMarket)) * ifgt(ItemQuality, 3, 0.65, ifgt(ItemQuality, 2, 0.30, 0.10)), ifgt(ItemQuality, 3, 1500g, ifgt(ItemQuality, 2, 200g, ifgt(ItemQuality, 1, 15g, 2g)))))")
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
