-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Currency = LibTSMWoW:Init("API.Currency")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the current player money amount.
---@return number
function Currency.GetMoney()
	return GetMoney()
end

---Gets info on a currency.
---@param currencyString string The currency string
---@return string? name
---@return number? texture
---@return quantity? itemLevel
function Currency.GetInfo(currencyString)
	local id = strmatch(currencyString, "currency:(%d+)")
	if not id then
		return nil, nil, nil
	end
	local info = C_CurrencyInfo.GetCurrencyInfo(id)
	return info.name, info.iconFileID, info.quantity
end
