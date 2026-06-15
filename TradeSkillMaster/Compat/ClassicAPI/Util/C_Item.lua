local _, Private = ...

local _G = _G
local Enum = Enum
local Type = type
local Number = tonumber
local Match = string.match
local ITEM_SOULBOUND = ITEM_SOULBOUND
local GetInventoryItemID = GetInventoryItemID
local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetContainerItemLink = GetContainerItemLink
local IsInventoryItemLocked = IsInventoryItemLocked
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemQuality = GetInventoryItemQuality

local Tooltip = Private.Tooltip

local C_Item = C_Item or {}

function C_Item.IsItemDataCachedByID(ItemInfo)
	local _, Cached = C_Item.GetItemInfo(ItemInfo)
	return Cached ~= nil
end

function C_Item.DoesItemExistByID(ItemID)
	return C_Item.GetItemIconByID(ItemID) ~= nil
end

function C_Item.GetItemNameByID(ItemInfo)
	local Name = C_Item.GetItemInfo(ItemInfo)
	return Name
end

function C_Item.RequestLoadItemDataByID(ItemID)
	local Item = Item:CreateFromItemID(ItemID)
	if ( Item ) then
		Item:ContinueOnItemLoad(C_Item.DoesItemExistByID)
	end
end

function C_Item.GetItemInfoInstant(ItemInfo)
	local _, Link, _, _, _, ItemType, ItemSubType, _, EquipLoc, Texture = C_Item.GetItemInfo(ItemInfo)
	local ID = ItemInfo

	if ( Link and Type(ID) == "string" ) then
		ID = Number(Match(Link, "item:(%d+):"))
	end

	return ID, ItemType, ItemSubType, EquipLoc, Texture
end

function C_Item.GetItemSubClassInfo(classID, subClassID)
	local ItemSubType = Enum.__ItemClassInfo[classID]
	ItemSubType = ItemSubType and ItemSubType[subClassID]

	return ItemSubType, (classID == 4 and subClassID >= 0 and subClassID <= 4)
end

function C_Item.GetItemInventorySlotInfo(InventorySlot)
	return Enum.__InventoryTypeInfo[InventorySlot]
end

function C_Item.GetItemInventoryTypeByID(ItemInfo)
	local _, _, _, _, _, _, _, _, EquipLoc = C_Item.GetItemInfo(ItemInfo)
	return Enum.__InventoryTypeIndex[EquipLoc or "INVTYPE_NON_EQUIP"]
end

function C_Item.GetItemQualityByID(ItemInfo)
	local _, _, Quality = C_Item.GetItemInfo(ItemInfo)
	return Quality
end

C_Item.GetItemInfo = GetItemInfo
C_Item.GetItemIconByID = GetItemIcon
C_Item.GetItemCount = GetItemCount

-- ITEMLOCATIONMIXIN RELIANT
function C_Item.GetItemName(ItemLocation)
	return C_Item.GetItemNameByID(C_Item.GetItemID(ItemLocation))
end

function C_Item.IsLocked(ItemLocation)
	local EquipmentSlotIndex, Locked, _ = ItemLocation.equipmentSlotIndex

	if ( EquipmentSlotIndex ) then
		Locked = IsInventoryItemLocked(EquipmentSlotIndex) ~= nil
	else
		_, _, Locked = GetContainerItemInfo(ItemLocation.bagID, ItemLocation.slotIndex)
	end

	return Locked ~= nil
end

function C_Item.GetItemID(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemID("player", EquipmentSlotIndex)
	else
		return GetContainerItemID(ItemLocation.bagID, ItemLocation.slotIndex)
	end
end

function C_Item.GetItemIcon(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemTexture("player", EquipmentSlotIndex)
	else
		local Icon = GetContainerItemInfo(ItemLocation.bagID, ItemLocation.slotIndex)
		return Icon
	end
end

function C_Item.GetItemLink(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemLink("player", EquipmentSlotIndex)
	else
		return GetContainerItemLink(ItemLocation.bagID, ItemLocation.slotIndex)
	end
end

function C_Item.GetItemQuality(ItemLocation)
	local _, _, Quality = C_Item.GetItemInfo(C_Item.GetItemLink(ItemLocation))
	return Quality
end

function C_Item.GetItemInventoryType(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	return EquipmentSlotIndex and Enum.__InventoryTypeInfo[EquipmentSlotIndex or 0]
end

function C_Item.GetCurrentItemLevel(ItemLocation)
	local _, _, _, ItemLevel = C_Item.GetItemInfo(C_Item.GetItemID(ItemLocation))
	return ItemLevel
end

function C_Item.IsItemDataCached(ItemLocation)
	return C_Item.GetItemLink(ItemLocation) ~= nil
end

function C_Item.IsBound(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex

	Tooltip:ClearLines()

	if ( EquipmentSlotIndex ) then
		Tooltip:SetInventoryItem("player", EquipmentSlotIndex)
	else
		Tooltip:SetBagItem(ItemLocation.bagID, ItemLocation.slotIndex)
	end

	local Line = _G["CAPI_ScanTooltipTextLeft2"]
	if ( Line ) then
		return Line:GetText() == ITEM_SOULBOUND
	end
end

C_Item.DoesItemExist = C_Item.GetItemID

C_Item.LockItem = Private.Void
C_Item.UnlockItem = Private.Void
C_Item.GetItemGUID = Private.Void
C_Item.LockItemByGUID = Private.Void
C_Item.UnlockItemByGUID = Private.Void

-- Global
_G.C_Item = C_Item
_G.GetItemInfoInstant = C_Item.GetItemInfoInstant
_G.GetItemSubClassInfo = C_Item.GetItemSubClassInfo
_G.GetItemInventorySlotInfo = C_Item.GetItemInventorySlotInfo