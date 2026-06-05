-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMSystem = select(2, ...).LibTSMSystem
local MailingOperation = LibTSMSystem:Init("MailingOperation")
local Util = LibTSMSystem:Include("Operation.Util")
local TempTable = LibTSMSystem:From("LibTSMUtil"):Include("BaseType.TempTable")
local Iterator = LibTSMSystem:From("LibTSMUtil"):IncludeClassType("Iterator")
local Table = LibTSMSystem:From("LibTSMUtil"):Include("Lua.Table")
local Group = LibTSMSystem:From("LibTSMTypes"):Include("Group")
local Operation = LibTSMSystem:From("LibTSMTypes"):Include("Operation")
local CustomString = LibTSMSystem:From("LibTSMTypes"):Include("CustomString")
local private = {
	quantityFunc = nil,
	isPlayerFunc = nil,
	usedTemp = {},
	keepTemp = {},
	operationIter = nil,
}
local OPERATION_TYPE = "Mailing"
local VALUE_LIMITS = {
	maxQty = { min = 1, max = 50000 },
	keepQty = { min = 0, max = 50000 },
}



-- ============================================================================
-- Module Loading
-- ============================================================================

MailingOperation:OnModuleLoad(function()
	private.operationIter = Iterator.New()
		:SetFilterFunc(function(_, _, operationSettings) return operationSettings.target ~= "" end)
	Util.ConfigureItemPrices(OPERATION_TYPE, function(itemString, operationSettings, key)
		local value = CustomString.GetValue(operationSettings[key], itemString, true)
		local minValue, maxValue = MailingOperation.GetMinMaxValues(key)
		if value and (value < minValue or value > maxValue) then
			value = nil
		end
		return value
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the Mailing operation code.
---@param localizedName string The localized operation type name
---@param quantityFunc fun(characterName: string, itemString: string, includeGuild: boolean, includeBank: boolean): number Function which gets charcter item quantity
---@param isPlayerFunc fun(characterName: string): boolean Function which checks if a character belongs to the player
function MailingOperation.Load(localizedName, quantityFunc, isPlayerFunc)
	private.quantityFunc = quantityFunc
	private.isPlayerFunc = isPlayerFunc
	local operationType = Operation.NewType(OPERATION_TYPE, localizedName, 50)
		:AddBooleanSetting("maxQtyEnabled")
		:AddCustomStringSetting("maxQty", "10")
		:AddStringSetting("target")
		:AddBooleanSetting("restock")
		:AddTableSetting("restockSources", { guild = false, bank = false })
		:AddCustomStringSetting("keepQty", "0")
	Operation.RegisterType(operationType)
end

---Gets the min and max value for a setting.
---@param key "maxQty"|"keepQty"
---@return number minVal
---@return number maxVal
function MailingOperation.GetMinMaxValues(key)
	local limits = VALUE_LIMITS[key]
	assert(limits)
	return limits.min, limits.max
end

---Gets the shortfall quantity to move to bags.
---@param itemString string The item string
---@param numHave number The number already in the bags
---@return number
function MailingOperation.TargetShortfallGetNumToBags(itemString, numHave)
	local isInvalid = false
	local totalNumToSend = 0
	for _, operationSettings in Util.OperationIteratorByItem(OPERATION_TYPE, itemString) do
		if not isInvalid then
			local numToSend = private.GetNumToSendForOperation(itemString, operationSettings, numHave)
			if numToSend then
				totalNumToSend = totalNumToSend + numToSend
				numHave = numHave - numToSend
			else
				isInvalid = true
				totalNumToSend = 0
			end
		end
	end
	return totalNumToSend
end

---Iterates over the items to send for a given group.
---@param groupPath GroupPathValue the group path
---@param numMailableFunc fun(itemString: string): number A function which gets the quantity of mailable items
---@return fun(): number, string, string, number @Iterator with fields: `index`, `target`, `itemString`, `quantity`
function MailingOperation.SendItemIterator(groupPath, numMailableFunc)
	assert(not next(private.usedTemp))
	assert(not next(private.keepTemp))
	local result = TempTable.Acquire()
	for _, operationSettings in private.operationIter:Execute(Util.OperationIteratorByGroup(OPERATION_TYPE, groupPath)) do
		local target = operationSettings.target
		for _, itemString in Group.ItemIterator(groupPath) do
			itemString = Group.TranslateItemString(itemString)
			local maxQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "maxQty", operationSettings)
			local keepQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepQty", operationSettings)
			if (maxQty or not operationSettings.maxQtyEnabled) and keepQty then
				private.usedTemp[itemString] = private.usedTemp[itemString] or 0
				private.keepTemp[itemString] = max(private.keepTemp[itemString] or 0, keepQty)
				local numAvailable = numMailableFunc(itemString) - private.usedTemp[itemString] - private.keepTemp[itemString]
				local quantity = private.GetNumToSend(itemString, operationSettings, numAvailable, maxQty)
				assert(quantity >= 0)
				if private.isPlayerFunc(target) then
					private.keepTemp[itemString] = max(private.keepTemp[itemString], quantity)
				else
					private.usedTemp[itemString] = private.usedTemp[itemString] + quantity
					if quantity > 0 then
						Table.InsertMultiple(result, target, itemString, quantity)
					end
				end
			end
		end
	end
	wipe(private.usedTemp)
	wipe(private.keepTemp)
	return TempTable.Iterator(result, 3)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetNumToSend(itemString, operationSettings, numAvailable, maxQty)
	if numAvailable <= 0 then
		return 0
	end
	local numToSend = 0
	local isTargetPlayer = private.isPlayerFunc(operationSettings.target)
	if operationSettings.maxQtyEnabled then
		if operationSettings.restock then
			local targetQty = private.quantityFunc(operationSettings.target, itemString, operationSettings.restockSources.guild, operationSettings.restockSources.bank)
			if isTargetPlayer and targetQty <= maxQty then
				numToSend = numAvailable
			else
				numToSend = min(numAvailable, maxQty - targetQty)
			end
			if isTargetPlayer then
				numToSend = numAvailable - (targetQty - maxQty)
			end
		else
			numToSend = min(numAvailable, maxQty)
		end
	elseif not isTargetPlayer then
		numToSend = numAvailable
	end
	return max(numToSend, 0)
end

function private.GetNumToSendForOperation(itemString, operationSettings, numHave)
	local keepQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "keepQty", operationSettings)
	if not keepQty then
		-- This operation isn't valid
		return nil
	end
	local numAvailable = numHave - keepQty
	local numToSend = 0
	if numAvailable > 0 then
		if operationSettings.maxQtyEnabled then
			local maxQty = Util.GetItemPrice(OPERATION_TYPE, itemString, "maxQty", operationSettings)
			if not maxQty then
				-- This operation isn't valid
				return nil
			end
			if operationSettings.restock then
				local targetQty = private.quantityFunc(operationSettings.target, itemString, operationSettings.restockSources.guild, operationSettings.restockSources.bank)
				if private.isPlayerFunc(operationSettings.target) and targetQty <= maxQty then
					numToSend = numAvailable
				else
					numToSend = min(numAvailable, maxQty - targetQty)
				end
				if private.isPlayerFunc(operationSettings.target) then
					-- If using restock and target == player ensure that subsequent operations don't take reserved bag inventory
					numHave = numHave - max((numAvailable - (targetQty - maxQty)), 0)
				end
			else
				numToSend = min(numAvailable, maxQty)
			end
		else
			numToSend = numAvailable
		end
	end
	return numToSend
end
