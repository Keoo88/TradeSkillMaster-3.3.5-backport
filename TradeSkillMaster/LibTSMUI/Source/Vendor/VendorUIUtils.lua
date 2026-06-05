-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local VendorUIUtils = LibTSMUI:Init("Vendor.VendorUIUtils")
local Currency = LibTSMUI:From("LibTSMWoW"):Include("API.Currency")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Vendor = LibTSMUI:From("LibTSMService"):Include("Vendor")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local private = {
	costTextTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the alt cost text for a vendor item.
---@param index number The vendor index
---@param quantity number The quantity to display the price of
---@return string
function VendorUIUtils.GetAltCostText(index, quantity)
	local price, numStacks = Vendor.GetTotalCost(index, quantity)
	local color = Vendor.GetNumCanAfford(index) < quantity and Theme.GetColor("FEEDBACK_RED") or nil
	local priceText = price > 0 and Money.ToStringForUI(price, color and color:GetTextColorPrefix() or nil) or nil
	local costItemsText = private.GetAdditionalCostText(index, numStacks, color)
	if priceText and costItemsText then
		return priceText.." "..costItemsText
	else
		return priceText or costItemsText or ""
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetAdditionalCostText(index, numStacks, costColor)
	assert(#private.costTextTemp == 0)
	for _, itemString, quantity in Vendor.AdditionalCostIterator(index) do
		quantity = quantity * numStacks
		if costColor then
			quantity = costColor:ColorText(quantity)
		end
		local currencyName, currencyTexture = Currency.GetInfo(itemString)
		if currencyName then
			local suffixStr = currencyName == HONOR_POINTS and ":14:14:00:0:64:64:0:40:0:40|t" or ":12|t"
			tinsert(private.costTextTemp, quantity.." |T"..currencyTexture..suffixStr)
		else
			tinsert(private.costTextTemp, quantity.." |T"..ItemInfo.GetTexture(itemString)..":12|t")
		end
	end
	local text = table.concat(private.costTextTemp, " ")
	wipe(private.costTextTemp)
	return text
end
