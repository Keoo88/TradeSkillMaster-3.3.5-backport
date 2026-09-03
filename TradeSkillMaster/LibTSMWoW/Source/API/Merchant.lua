-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Merchant = LibTSMWoW:Init("API.Merchant")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets all currencies (by ID) used by the merchant.
---@return number ...
function Merchant.GetCurrencies()
	if not GetMerchantCurrencies then
		-- 3.3.5: GetMerchantCurrencies() doesn't exist (added in 4.0); extended
		-- costs are handled via GetMerchantItemCostInfo() instead
		return nil
	end
	return GetMerchantCurrencies()
end

---Gets the number of available merchant items.
---@return number
function Merchant.GetNumItems()
	return GetMerchantNumItems()
end

---Gets the item link.
---@param index number The index
---@return string?
function Merchant.GetItemLink(index)
	return GetMerchantItemLink(index)
end

---Gets info about a merchant item.
---@param index number The index
---@return number price
---@return number stackSize
---@return number numAvailable
function Merchant.GetItemInfo(index)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_MERCHANTFRAME) then
		local info = C_MerchantFrame.GetItemInfo(index)
		if info then
			return info.price, info.stackCount, info.numAvailable
		end
	else
		local _, _, price, stackSize, numAvailable = GetMerchantItemInfo(index)
		return price, stackSize, numAvailable
	end
end

---Gets the max stack size that can be bought of an item.
---@return number
function Merchant.GetItemMaxStack(index)
	-- 3.3.5: GetMerchantItemMaxStack возвращает 1 для патронов/реагентов (нет понятия "max stack purchase").
	-- Fallback на stackSize из GetMerchantItemInfo — реальный размер пачки за одну покупку.
	local maxStack = GetMerchantItemMaxStack(index)
	if (not maxStack or maxStack <= 1) and not ClientInfo.HasFeature(ClientInfo.FEATURES.C_MERCHANTFRAME) then
		local _, _, _, stackSize = GetMerchantItemInfo(index)
		if stackSize and stackSize > 1 then
			return stackSize
		end
	end
	return maxStack or 1
end

---Gets the number of extended cost items.
---@param index number The index
---@return number
function Merchant.GetNumCostItems(index)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_MERCHANTFRAME) then
		return GetMerchantItemCostInfo(index)
	end
	-- Interface 30300 returns honorPoints, arenaPoints, itemCount. The scanner
	-- iterates item costs only, so use the third return rather than honorPoints.
	local _, _, itemCount = GetMerchantItemCostInfo(index)
	return itemCount or 0
end

---Gets info about an extended cost item.
---@param index number The index
---@param costIndex number The cost index
---@return string? itemLink
---@return number quantity
function Merchant.GetCostItemInfo(index, costIndex)
	local _, quantity, itemLink = GetMerchantItemCostItem(index, costIndex)
	return itemLink, quantity
end

---Purchase an item from the merchant.
---@param index number The index
---@param quantity number Quantity to buy
function Merchant.BuyItem(index, quantity)
	BuyMerchantItem(index, quantity)
end

---Register a secure hook function for when an item is bought.
---@param func function
function Merchant.SecureHookBuyItem(func)
	hooksecurefunc("BuyMerchantItem", func)
end

---Gets the number of buyback items.
---@return number
function Merchant.GetNumBuybackItems()
	return GetNumBuybackItems()
end

---Gets info about a buyback item.
---@param index number The index
---@return number price
---@return number quantity
function Merchant.GetBuybackItemInfo(index)
	local _, _, price, quantity = GetBuybackItemInfo(index)
	return price, quantity
end

---Gets the buyback item link.
---@param index number The index
---@return string?
function Merchant.GetBuybackItemLink(index)
	return GetBuybackItemLink(index)
end

---Buys back an item from the merchant.
---@param index number The index
function Merchant.BuybackItem(index)
	BuybackItem(index)
end

---Register a secure hook function for when a buyback item is bought.
---@param func function
function Merchant.SecureHookBuybackItem(func)
	hooksecurefunc("BuybackItem", func)
end

---Returns whether or not the merchant can repair.
---@return boolean
function Merchant.CanRepair()
	return CanMerchantRepair() and true or false
end

---Returns whether or not the merchant can repair from the guild bank.
---@return boolean
function Merchant.CanGuildBankRepair()
	return ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) and CanGuildBankRepair() and true or false
end

---Gets the repair all cost and whether or not the player needs to repair.
---@return number cost
---@return boolean needsRepair
function Merchant.GetRepairAllCost()
	return GetRepairAllCost()
end

---Performs a repair.
---@param fromGuildBank? boolean Repair from the guild bank
function Merchant.RepairAllItems(fromGuildBank)
	RepairAllItems(fromGuildBank)
end
