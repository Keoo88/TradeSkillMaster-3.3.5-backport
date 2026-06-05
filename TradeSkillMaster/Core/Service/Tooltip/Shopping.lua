-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Shopping = TSM.Tooltip:NewPackage("Shopping")
local L = TSM.Locale.GetTable()
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local ShoppingOperation = TSM.LibTSMSystem:Include("ShoppingOperation")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Shopping.OnEnable()
	TSM.Tooltip.Register(TSM.Tooltip.CreateInfo()
		:SetHeadings(L["TSM Shopping"])
		:SetSettingsModule("Shopping")
		:AddSettingEntry("maxPrice", false, private.PopulateMaxPriceLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PopulateMaxPriceLine(tooltip, itemString)
	local maxPrice = nil
	if itemString == ItemString.GetPlaceholder() then
		-- example tooltip
		maxPrice = 37
	else
		maxPrice = ShoppingOperation.GetMaxPrice(itemString)
	end
	if maxPrice then
		tooltip:AddItemValueLine(L["Max Shopping Price"], maxPrice)
	end
end
