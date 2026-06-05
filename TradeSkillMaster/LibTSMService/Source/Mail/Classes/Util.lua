-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Util = LibTSMService:Init("Mail.Util")
local ItemInfo = LibTSMService:Include("Item.ItemInfo")
local Inbox = LibTSMService:From("LibTSMWoW"):Include("API.Inbox")
local TooltipScanning = LibTSMService:From("LibTSMWoW"):Include("Service.TooltipScanning")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")




-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets info on a mail attachment and handles getting the itemLink for battle pets.
---@param index number The mail index
---@param attachIndex number The attachment index
---@return string itemLink
---@return number quantity
function Util.GetAttachment(index, attachIndex)
	local itemLink, quantity = Inbox.GetAttachment(index, attachIndex)
	if ItemString.GetBase(itemLink) == ItemString.GetPetCage() then
		local speciesId, level, breedQuality = TooltipScanning.GetInboxBattlePetInfo(index, attachIndex)
		assert(speciesId and speciesId > 0)
		itemLink = ItemInfo.GetLink(strjoin(":", "p", speciesId, level, breedQuality))
	end
	return itemLink, quantity
end
