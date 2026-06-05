-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Auctioning = TSM.Tooltip:NewPackage("Auctioning")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Group = TSM.LibTSMTypes:Include("Group")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Auctioning.OnEnable()
	TSM.Tooltip.Register(TSM.Tooltip.CreateInfo()
		:SetHeadings(L["TSM Auctioning"])
		:SetSettingsModule("Auctioning")
		:AddSettingEntry("postQuantity", false, private.PopulatePostQuantityLine)
		:AddSettingEntry("operationPrices", false, private.PopulatePricesLine)
	)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PopulatePostQuantityLine(tooltip, itemString)
	local postCap, stackSize = nil, nil
	if itemString == ItemString.GetPlaceholder() then
		postCap = 5
		stackSize = ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and 200 or nil
	elseif ItemInfo.IsSoulbound(itemString) then
		return
	else
		itemString = Group.TranslateItemString(itemString)
		local _, operation = TSM.Operations.GetFirstOperationByItem("Auctioning", itemString)
		if not operation then
			return
		end

		postCap = AuctioningOperation.GetItemPrice(itemString, "postCap", operation)
		stackSize = ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and AuctioningOperation.GetItemPrice(itemString, "stackSize", operation) or nil
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		tooltip:AddTextLine(L["Post Quantity"], postCap and stackSize and postCap.."x"..stackSize or "---")
	else
		tooltip:AddTextLine(L["Post Quantity"], postCap or "---")
	end
end

function private.PopulatePricesLine(tooltip, itemString)
	local minPrice, normalPrice, maxPrice = nil, nil, nil
	if itemString == ItemString.GetPlaceholder() then
		minPrice = 20
		normalPrice = 24
		maxPrice = 29
	elseif ItemInfo.IsSoulbound(itemString) then
		return
	else
		itemString = Group.TranslateItemString(itemString)
		local _, operation = TSM.Operations.GetFirstOperationByItem("Auctioning", itemString)
		if not operation then
			return
		end

		minPrice = AuctioningOperation.GetItemPrice(itemString, "minPrice", operation)
		normalPrice = AuctioningOperation.GetItemPrice(itemString, "normalPrice", operation)
		maxPrice = AuctioningOperation.GetItemPrice(itemString, "maxPrice", operation)
	end
	tooltip:AddItemValuesLine(L["Min/Normal/Max Prices"], minPrice, normalPrice, maxPrice)
end
