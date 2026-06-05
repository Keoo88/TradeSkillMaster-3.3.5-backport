-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local VendoringOperation = LibTSMSystem:Init("VendoringOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local TempTable = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.TempTable")
local Iterator = LibTSMSystem:From("LibTSMUtil"):IncludeClassType("Iterator")
local Table = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Table")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local Group = LibTSMSystem:From("LibTSMTypes"):Include("Group")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local private = {
	inventoryNumFunc = nil,
	sellOperationIter = nil,
}
local OPERATION_TYPE = "Vendoring"
local VALUE_LIMITS = {
	sellAfterExpired = { min = 0, max = 50000 },
	keepQty = { min = 0, max = 50000 },
	restockQty = { min = 0, max = 50000 },
}



-- ============================================================================
-- Module Loading
-- ============================================================================

VendoringOperation:OnModuleLoad(function()
	private.sellOperationIter = Iterator.New()
		:SetFilterFunc(function(_, _, operationSettings) return operationSettings.enableSell end)
	Util.ConfigureItemPrices(OPERATION_TYPE, function(itemString, operationSettings, key)
		local value = CustomString.GetValue(operationSettings[key], itemString, true)
		local minValue, maxValue = VendoringOperation.GetMinMaxValues(key)
		if value and (value < minValue or value > maxValue) then
			value = nil
		end
		return value
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Vendoring operation code.
---@alias VendoringOperationInventoryNumFunc fun(itemString: string, includeBank: boolean, includeGuild: boolean, includeAuctions: boolean, includeMail: boolean, includeAlts: boolean, includeAltAuctions: boolean): number
---@param localizedName string The localized operation type name
---@param inventoryNumFunc VendoringOperationInventoryNumFunc Function to get the number in inventory for restocking against
function VendoringOperation.Load(localizedName, inventoryNumFunc)
	private.inventoryNumFunc = inventoryNumFunc
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 1)
		:AddCustomStringSetting("sellAfterExpired", "20")
		:AddBooleanSetting("sellSoulbound")
		:AddCustomStringSetting("keepQty", "0")
		:AddCustomStringSetting("restockQty", "0")
		:AddTableSetting("restockSources", { alts = false, ah = false, bank = false, guild = false, alts_ah = false, mail = false })
		:AddBooleanSetting("enableBuy", true)
		:AddBooleanSetting("enableSell", true)
		:AddCustomStringSetting("vsMarketValue", "dbmarket")
		:AddCustomStringSetting("vsMaxMarketValue", "0c")
		:AddCustomStringSetting("vsDestroyValue", "dbmarket")
		:AddCustomStringSetting("vsMaxDestroyValue", "0c")
	Operation.RegisterType(operationType)
end

---Gets the min and max value for a setting.
---@param key "sellAfterExpired"|"keepQty"|"restockQty"
---@return number minVal
---@return number maxVal
function VendoringOperation.GetMinMaxValues(key)
	local limits = VALUE_LIMITS[key]
	assert(limits)
	return limits.min, limits.max
end

---Gets the number to buy of an item.
---@param itemString string The item string
---@return number
function VendoringOperation.GetNumToBuy(itemString)
	local operationSettings = Util.GetFirstOperationByItem(OPERATION_TYPE, itemString)
	if not operationSettings or not operationSettings.enableBuy then
		return 0
	end
	local restockQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "restockQty", operationSettings)
	if not restockQty then
		return 0
	end
	local numHave = private.inventoryNumFunc(itemString, operationSettings.restockSources.bank, operationSettings.restockSources.guild, operationSettings.restockSources.ah, operationSettings.restockSources.mail, operationSettings.restockSources.alts, operationSettings.restockSources.alts_ah)
	return max(restockQty - numHave, 0)
end

---Iterates over items to sell from the specified group.
---@param groupPath GroupPathValue The group path
---@return fun(): number, string, number, boolean @Iterator with fields: `index`, `itemString`, `numToSell`, `sellSoulbound`
function VendoringOperation.SellItemIterator(groupPath)
	local result = TempTable.Acquire()
	for _, operationSettings in private.sellOperationIter:Execute(Util.OperationIteratorByGroup(OPERATION_TYPE, groupPath)) do
		for _, itemString in Group.ItemIterator(groupPath) do
			local numToSell = private.GetNumToSell(itemString, operationSettings)
			if numToSell > 0 then
				Table.InsertMultiple(result, itemString, numToSell, operationSettings.sellSoulbound)
			end
		end
	end
	return TempTable.Iterator(result, 3)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetNumToSell(itemString, operationSettings)
	local keepQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepQty", operationSettings)
	local sellAfterExpired = Util.GetItemPrice(OPERATION_TYPE, itemString, "sellAfterExpired", operationSettings)
	if not keepQty or not sellAfterExpired then
		-- This operation isn't valid
		return 0
	end
	local numHave = private.inventoryNumFunc(itemString, false, false, false, false, false, false)
	local numToSell = numHave - keepQty
	if numToSell <= 0 then
		return 0
	end

	-- Check the expires
	if sellAfterExpired > 0 and (CustomString.GetValue("NumExpires", itemString) or 0) < sellAfterExpired then
		return 0
	end

	-- Check the destroy value
	local destroyValue = CustomString.GetValue(operationSettings.vsDestroyValue, itemString) or 0
	local maxDestroyValue = CustomString.GetValue(operationSettings.vsMaxDestroyValue, itemString) or 0
	if maxDestroyValue > 0 and destroyValue >= maxDestroyValue then
		return 0
	end

	-- Check the market value
	local marketValue = CustomString.GetValue(operationSettings.vsMarketValue, itemString) or 0
	local maxMarketValue = CustomString.GetValue(operationSettings.vsMaxMarketValue, itemString) or 0
	if maxMarketValue > 0 and marketValue >= maxMarketValue then
		return 0
	end

	return numToSell
end
