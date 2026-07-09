-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Item = LibTSMWoW:Init("API.Item")
local ItemClass = LibTSMWoW:Include("Util.ItemClass")
local private = {
	cacheTooltip = nil,
	cacheRequestTimes = {},
	cacheRequestWindowStart = 0,
	cacheRequestWindowCount = 0,
}
local MAX_STACK_SIZE = 4000
-- 3.3.5 backport fix: 700 is a retail value; the highest item level in WotLK is 284
-- (Shadowmourne / late ICC gear). This drives the Advanced Search item level slider.
local MAX_ITEM_LEVEL = 284
local CACHE_REQUEST_COOLDOWN = 5
local MAX_CACHE_REQUESTS_PER_SEC = 20



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets item info or queries it if it's not already loaded.
---@param item string The WoW item string
---@return string? name
---@return string? link
---@return Enum.ItemQuality? quality
---@return number? itemLevel
---@return number? minLevel
---@return number? maxStack
---@return number? vendorSell
---@return boolean? isBoP
---@return number? expansionId
---@return boolean? isCraftingReagent
function Item.GetInfo(item)
	local name, link, quality, itemLevel, minLevel, _, _, maxStack, _, _, vendorSell, _, _, bindType, expansionId, _, isCraftingReagent = C_Item.GetItemInfo(item)
	local isBoP = (bindType == LE_ITEM_BIND_ON_ACQUIRE or bindType == LE_ITEM_BIND_QUEST) and 1 or 0
	-- Some items (i.e. "i:117356::1:573") produce an negative min level
	minLevel = minLevel and max(minLevel, 0) or nil
	-- Some items (i.e. "i:40752" produce a very high max stack, so cap it)
	maxStack = maxStack and min(maxStack, MAX_STACK_SIZE) or nil
	return name, link, quality, itemLevel, minLevel, maxStack, vendorSell, isBoP, expansionId, isCraftingReagent
end

---Gets precached item info.
---@param itemId number The item ID
---@return number? texture
---@return number? classId
---@return number? subClassId
---@return number? invSlotId
function Item.GetInfoInstant(itemId)
	local id, classStr, subClassStr, equipSlot, texture, classId, subClassId = C_Item.GetItemInfoInstant(itemId)
	equipSlot = equipSlot and equipSlot ~= "" and _G[equipSlot] or nil
	if not texture then
		return nil, nil, nil, nil
	end
	-- On 3.3.5 ClassicAPI returns texture as a string path, but the cache serializer
	-- expects a numeric FileID. Use -1 (missing-value sentinel) so the cache skips it,
	-- and ItemInfo.GetTexture falls back to GetItemIcon.
	if type(texture) == "string" then
		texture = -1
	end
	-- On 3.3.5 ClassicAPI's GetItemInfoInstant returns only (id, classStr, subClassStr, equipSlot, texture)
	-- without classId/subClassId, so look them up via ItemClass.
	if not classId then
		classId = ItemClass.GetClassIdFromClassString(classStr)
		if not classId then
			return nil, nil, nil, nil
		end
		subClassId = ItemClass.GetSubClassIdFromSubClassString(subClassStr or "", classId) or 0
	end
	if classId < 0 then
		classId = ItemClass.GetClassIdFromClassString(classStr)
		if not classId and not LibTSMWoW.IsRetail() then
			-- This can happen for items which don't yet exist in classic (i.e. WoW Tokens)
			return nil, nil, nil, nil
		end
		assert(subClassStr == "")
		subClassId = 0
	end
	local invSlotId = equipSlot and ItemClass.GetInventorySlotIdFromInventorySlotString(equipSlot) or 0
	-- 3.3.5 safety: some custom server polyfills of GetItemInfoInstant put the subClass
	-- *string* (e.g. "Miscellaneous") into the subClassID slot. The cache serializer
	-- requires numeric IDs. Re-resolve via the lookup if we still have a string.
	if type(classId) == "string" then
		classId = ItemClass.GetClassIdFromClassString(classId) or -1
	end
	if type(subClassId) == "string" then
		subClassId = ItemClass.GetSubClassIdFromSubClassString(subClassId, classId) or 0
	end
	if type(invSlotId) ~= "number" then
		invSlotId = 0
	end
	return texture, classId, subClassId, invSlotId
end

---Forces the client to request item data from the server (3.3.5 only).
---On 3.3.5 GetItemInfo() does NOT query the server for uncached items (and there's
---no GET_ITEM_INFO_RECEIVED event), so polling GetItemInfo never resolves them.
---Setting an item hyperlink on a hidden tooltip triggers the server item query;
---once the server responds, the item lands in the client cache and the regular
---GetItemInfo polling picks it up. Throttled per item to avoid query spam.
---@param itemId number The item ID
function Item.RequestServerCache(itemId)
	if LibTSMWoW.IsRetail() or not itemId then
		return false
	end
	-- 3.3.5 crash guard: never SetHyperlink an item ID the client has no record of.
	-- GetItemIcon() resolves locally (no server query) and returns nil for IDs that
	-- don't exist in the client data; SetHyperlink on such IDs can hard-crash the
	-- 3.3.5 client (Error #132), especially with server-custom/removed items.
	if not GetItemIcon(itemId) then
		return false
	end
	local now = GetTime()
	local lastRequest = private.cacheRequestTimes[itemId]
	if lastRequest and now - lastRequest < CACHE_REQUEST_COOLDOWN then
		return false
	end
	-- Global throttle so a huge pending queue can't flood the server with item queries
	if now - private.cacheRequestWindowStart >= 1 then
		private.cacheRequestWindowStart = now
		private.cacheRequestWindowCount = 0
	end
	if private.cacheRequestWindowCount >= MAX_CACHE_REQUESTS_PER_SEC then
		return false
	end
	private.cacheRequestWindowCount = private.cacheRequestWindowCount + 1
	private.cacheRequestTimes[itemId] = now
	if not private.cacheTooltip then
		private.cacheTooltip = CreateFrame("GameTooltip", "TSMItemCacheRequestTooltip", UIParent, "GameTooltipTemplate")
	end
	private.cacheTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	pcall(private.cacheTooltip.SetHyperlink, private.cacheTooltip, "item:"..itemId..":0:0:0:0:0:0:0")
	private.cacheTooltip:Hide()
	return true
end

---Gets the detailed item level for an item.
---@param item string The WoW item string
---@return number
function Item.GetDetailedItemLevel(item)
	if not C_Item.GetDetailedItemLevelInfo then
		local _, _, _, itemLevel = GetItemInfo(item)
		return itemLevel
	end
	local itemLevel = C_Item.GetDetailedItemLevelInfo(item)
	return itemLevel
end

---Gets info on a pet.
---@param speciesId speciesId The pet species ID
---@return string? name
---@return texture? number
---@return petTypeId? number
function Item.GetPetInfo(speciesId)
	local name, texture, petTypeId = C_PetJournal.GetPetInfoBySpeciesID(speciesId)
	if not texture or not petTypeId then
		return nil, nil, nil
	end
	return name, texture, petTypeId
end

---Requests loading of all pet info.
function Item.LoadPetInfo()
	for i = 1, C_PetJournal.GetNumPets() do
		C_PetJournal.GetPetInfoByIndex(i)
	end
end

---Returns whether or not items of a class can have variations (potentially only with a specific sub class ID).
---@param classId number The class ID
---@return boolean canHaveVariations
---@return number? specificSubClassId
function Item.ClassCanHaveVariations(classId)
	if classId == Enum.ItemClass.Armor or classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Battlepet then
		return true, nil
	elseif classId == Enum.ItemClass.Gem then
		return true, Enum.ItemGemSubclass.Artifactrelic
	else
		return false, nil
	end
end

---Returns whether or not the variation impacts the quality of the item for a given class.
---@param classId number The class ID
---@return boolean
function Item.VariationImpactsQualityByClass(classId)
	return classId == Enum.ItemClass.Armor or classId == Enum.ItemClass.Weapon
end

---Returns whether or not items of a class are disenchantable.
---@param classId number The class ID
---@return boolean
function Item.IsClassDisenchantable(classId)
	return classId == Enum.ItemClass.Armor or classId == Enum.ItemClass.Weapon or classId == Enum.ItemClass.Profession
end

---Returns whether or not items of an inventory slot are disenchantable.
---@param invSlotId number The inventory slot ID
---@return boolean
function Item.IsInventorySlotDisenchantable(invSlotId)
	return invSlotId ~= Enum.InventoryType.IndexBodyType and invSlotId ~= Enum.InventoryType.IndexTabardType
end

---Returns whether or not items of a quality are disenchantable.
---@param quality number The quality
---@return boolean
function Item.IsQualityDisenchantable(quality)
	return quality >= (Enum.ItemQuality.Good or Enum.ItemQuality.Uncommon) and quality < Enum.ItemQuality.Legendary
end

---Gets the color prefix string for a given item quality.
---@param quality number The quality
---@return string?
function Item.GetQualityColor(quality)
	return ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex
end

---Gets the item family.
---@param link string The item link
---@param classId number The class ID
---@return number
function Item.GetFamily(link, classId)
	if classId == Enum.ItemClass.Container then
		-- Bags report their family as what can go inside them, not what they can go inside
		return 0
	end
	return C_Item.GetItemFamily(link) or 0
end

---Installs a hook for an item being linked.
---@param hookFunc fun(link: string): boolean The hook function
function Item.HookLink(hookFunc)
	local origHandleModifiedItemClick = HandleModifiedItemClick
	HandleModifiedItemClick = function(link, ...)
		return origHandleModifiedItemClick(link, ...) or hookFunc(link)
	end
	local origChatEdit_InsertLink = ChatEdit_InsertLink
	ChatEdit_InsertLink = function(link, ...)
		return origChatEdit_InsertLink(link, ...) or hookFunc(link)
	end
end

---Handles a modified item click from a UI.
---@param link string The link of the item which was clicked on
function Item.HandleModifiedItemClick(link)
	if not link then
		return
	end
	if IsShiftKeyDown() then
		Item.ShowRef(link)
	elseif IsControlKeyDown() then
		DressUpItemLink(link)
	end
end

---Sets the WoW item ref frame to the specified link.
---@param link string The itemLink to show the item ref frame for
function Item.ShowRef(link)
	if type(link) ~= "string" then
		return
	end
	-- Extract the Blizzard itemString for both items and pets
	local blizzItemString = strmatch(link, "^\124c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\124H(item:[^\124]+)\124.+$")
	blizzItemString = blizzItemString or strmatch(link, "^\124c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\124H(battlepet:[^\124]+)\124.+$")
	if blizzItemString then
		SetItemRef(blizzItemString, link, "LeftButton")
	end
end

---Gets the max item level.
---@return number
function Item.GetMaxItemLevel()
	return MAX_ITEM_LEVEL
end

---Checks whether the player can use the item (3.3.5 backport).
---The 3.3.5 server-side "usable" auction filter can't be relied on, so this scans a
---hidden tooltip for red (unmet requirement) text, which is how the client itself
---renders items you can't use (wrong class, level/skill too low, unknown recipe, etc).
---@param link string The item link
---@return boolean
function Item.IsUsable(link)
	if type(link) ~= "string" then
		return true
	end
	if not private.usableScanTooltip then
		private.usableScanTooltip = CreateFrame("GameTooltip", "TSMUsableScanTooltip", UIParent, "GameTooltipTemplate")
	end
	local tooltip = private.usableScanTooltip
	tooltip:SetOwner(UIParent, "ANCHOR_NONE")
	local ok = pcall(tooltip.SetHyperlink, tooltip, link)
	if not ok then
		tooltip:Hide()
		return true
	end
	local function IsRedLine(textObj)
		local text = textObj and textObj:GetText()
		if not text or text == "" then
			return false
		end
		local r, g, b = textObj:GetTextColor()
		-- The client colors unmet requirements red (RED_FONT_COLOR = 1.0, 0.1, 0.1)
		return r and r > 0.9 and g < 0.2 and b < 0.2
	end
	for i = 2, tooltip:NumLines() do
		if IsRedLine(_G["TSMUsableScanTooltipTextLeft"..i]) or IsRedLine(_G["TSMUsableScanTooltipTextRight"..i]) then
			tooltip:Hide()
			return false
		end
	end
	tooltip:Hide()
	return true
end
