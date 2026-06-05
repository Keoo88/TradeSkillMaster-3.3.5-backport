-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Sniper = TSM.Tooltip:NewPackage("Sniper")
local L = TSM.Locale.GetTable()
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local SniperOperation = TSM.LibTSMSystem:Include("SniperOperation")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sniper.OnEnable()
	TSM.Tooltip.Register(TSM.Tooltip.CreateInfo()
		:SetHeadings(L["TSM Sniper"])
		:SetSettingsModule("Sniper")
		:AddSettingEntry("belowPrice", false, private.PopulateBelowPriceLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PopulateBelowPriceLine(tooltip, itemString)
	local belowPrice = nil
	if itemString == ItemString.GetPlaceholder() then
		-- example tooltip
		belowPrice = 35
	else
		belowPrice = SniperOperation.GetMaxPrice(itemString)
	end
	if belowPrice then
		tooltip:AddItemValueLine(L["Sniper Max Price"], belowPrice)
	end
end
