-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Util = LibTSMService:Init("AuctionScan.Util")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not sufficient item info is available for an item.
---@param itemString string The item string
---@return boolean hasInfo
---@return boolean fetchedInfo
function Util.HasItemInfo(itemString)
	local itemName = ItemInfo.GetName(itemString)
	local itemLevel = ItemInfo.GetItemLevel(itemString)
	local quality = ItemInfo.GetQuality(itemString)
	local minLevel = ItemInfo.GetMinLevel(itemString)
	local hasIsCommodity = (LibTSMService.IsVanillaClassic() or LibTSMService.IsBCClassic() or LibTSMService.IsWrathClassic()) or ItemInfo.IsCommodity(itemString) ~= nil
	local hasCanHaveVariations = ItemInfo.CanHaveVariations(itemString) ~= nil
	if itemName and itemLevel and quality and minLevel and hasIsCommodity and hasCanHaveVariations then
		return true, false
	else
		return false, ItemInfo.FetchInfo(itemString)
	end
end
