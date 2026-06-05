-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local AuctionHouseUIUtils = LibTSMUI:Init("AuctionHouse.AuctionHouseUIUtils")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local AuctionHouseWrapper = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local private = {}
local COPPER_PER_SILVER = 100



-- ============================================================================
-- Module Functions
-- ============================================================================

---Parses and validates an auction price value entered by the user.
---@param value string The bid value
---@param canBeZero boolean Whether or not 0 is a valid value
---@return number? value
---@return string? errStr
function AuctionHouseUIUtils.ParseAuctionPrice(value, canBeZero)
	return private.ParseCommon(value, canBeZero)
end

---Calculates the deposit cost for posting an auction.
---@param itemString string The item string
---@param useAutoBaseItemString boolean Whether or not to use the autoBaseItemString field when querying bags to find the item
---@param postTime number The duration
---@param stackSize number The stack size
---@param bid number The bid
---@param buyout number The buyout
---@return number
function AuctionHouseUIUtils.CalculateDeposit(itemString, useAutoBaseItemString, postTime, stackSize, bid, buyout)
	local query = BagTracking.CreateQueryBagsAuctionable()
		:OrderBy("slotId", true)
		:Select("bag", "slot")
	if useAutoBaseItemString then
		query:Equal("baseItemString", ItemString.GetBaseFast(itemString))
			:VirtualField("autoBaseItemString", "string", Group.TranslateItemString, "itemString")
			:Equal("autoBaseItemString", itemString)
	else
		query:Equal("itemString", itemString)
	end
	local postBag, postSlot = query:GetFirstResultAndRelease()
	return (postBag and postSlot) and AuctionHouseWrapper.GetDepositCost(postBag, postSlot, stackSize, postTime, bid, buyout) or nil
end

---Gets the display text for a market value percent.
---@param pct? number The market value percent
---@param bidColor? boolean Use the bid color
---@return string
function AuctionHouseUIUtils.GetMarketValuePercentText(pct, bidColor)
	if not pct then
		return "---"
	end
	local pctText = pct > 999 and ">999%" or pct.."%"
	return Theme.GetAuctionPercentColor(bidColor and "BID" or pct):ColorText(pctText)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ParseCommon(value, canBeZero)
	local wasRawNumber = tonumber(value) and true or false
	value = Money.FromString(value)
	if not value then
		return nil, L["The price must contain g/s/c labels. For example '1g 2s' means 1 gold and 2 silver."]
	end
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.AH_COPPER) and value % COPPER_PER_SILVER ~= 0 then
		if wasRawNumber then
			return nil, L["The price must contain g/s/c labels. For example '1g 2s' means 1 gold and 2 silver."]
		else
			return nil, L["The AH does not support specifying a copper value (only gold and silver)."]
		end
	end
	if not canBeZero and value <= 0 then
		return nil, L["The value must be greater than 0."]
	elseif canBeZero and value < 0 then
		return nil, L["The value must be greater than or equal of 0."]
	elseif value > MAXIMUM_BID_PRICE then
		return nil, L["The value was greater than the maximum allowed auction house price."]
	end
	return value
end
