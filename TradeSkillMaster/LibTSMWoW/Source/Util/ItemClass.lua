-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local ItemClass = LibTSMWoW:Init("Util.ItemClass")
local ClientInfo = LibTSMWoW:Include("Util.ClientInfo")
local private = {
	classes = {},
	subClasses = {},
	classLookup = {},
	classIdLookup = {},
	inventorySlotIdLookup = {},
	armorSubClassHasInventorySlots = {},
	armorGenericInventorySlots = {},
	armorInventorySlots = {},
	emptyTable = {},
}



-- ============================================================================
-- Data
-- ============================================================================

local RETAIL_ITEM_CLASS_IDS = {
	Enum.ItemClass.Weapon,
	Enum.ItemClass.Armor,
	Enum.ItemClass.Container,
	Enum.ItemClass.Gem,
	Enum.ItemClass.ItemEnhancement,
	Enum.ItemClass.Consumable,
	Enum.ItemClass.Glyph,
	Enum.ItemClass.Tradegoods,
	Enum.ItemClass.Recipe,
	Enum.ItemClass.Profession,
	Enum.ItemClass.Housing,
	Enum.ItemClass.Battlepet,
	Enum.ItemClass.Questitem,
	Enum.ItemClass.Miscellaneous,
}
local PANDA_ITEM_CLASS_IDS = {
	Enum.ItemClass.Weapon,
	Enum.ItemClass.Armor,
	Enum.ItemClass.Container,
	Enum.ItemClass.Consumable,
	Enum.ItemClass.Glyph,
	Enum.ItemClass.Tradegoods,
	Enum.ItemClass.Projectile,
	Enum.ItemClass.Quiver,
	Enum.ItemClass.Recipe,
	Enum.ItemClass.Gem,
	Enum.ItemClass.Miscellaneous,
	Enum.ItemClass.Questitem,
	Enum.ItemClass.Battlepet,
}
local BCC_ITEM_CLASS_IDS = {
	Enum.ItemClass.Weapon,
	Enum.ItemClass.Armor,
	Enum.ItemClass.Container,
	Enum.ItemClass.Consumable,
	Enum.ItemClass.Tradegoods,
	Enum.ItemClass.Projectile,
	Enum.ItemClass.Quiver,
	Enum.ItemClass.Recipe,
	Enum.ItemClass.Gem,
	Enum.ItemClass.Reagent,
	Enum.ItemClass.Miscellaneous,
	Enum.ItemClass.Questitem,
}
local VANILLA_ITEM_CLASS_IDS = {
	Enum.ItemClass.Weapon,
	Enum.ItemClass.Armor,
	Enum.ItemClass.Container,
	Enum.ItemClass.Consumable,
	Enum.ItemClass.Tradegoods,
	Enum.ItemClass.Projectile,
	Enum.ItemClass.Quiver,
	Enum.ItemClass.Recipe,
	Enum.ItemClass.Reagent,
	Enum.ItemClass.Miscellaneous,
}
local ARMOR_GENERIC_INVENTORY_SLOTS = {
	Enum.InventoryType.IndexNeckType,
	Enum.InventoryType.IndexCloakType,
	Enum.InventoryType.IndexFingerType,
	Enum.InventoryType.IndexTrinketType,
	Enum.InventoryType.IndexHoldableType,
	Enum.InventoryType.IndexBodyType,
}
local ARMOR_INVENTORY_SLOTS = {
	Enum.InventoryType.IndexHeadType,
	Enum.InventoryType.IndexShoulderType,
	Enum.InventoryType.IndexChestType,
	Enum.InventoryType.IndexWaistType,
	Enum.InventoryType.IndexLegsType,
	Enum.InventoryType.IndexFeetType,
	Enum.InventoryType.IndexWristType,
	Enum.InventoryType.IndexHandType,
}
local ARMOR_SUB_CLASSES_WITH_INVENTORY_SLOTS = {
	Enum.ItemArmorSubclass.Plate,
	Enum.ItemArmorSubclass.Mail,
	Enum.ItemArmorSubclass.Leather,
	Enum.ItemArmorSubclass.Cloth,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ItemClass:OnModuleLoad(function()
	local data = nil
	if LibTSMWoW.IsRetail() then
		data = RETAIL_ITEM_CLASS_IDS
	elseif LibTSMWoW.IsPandaClassic() then
		data = PANDA_ITEM_CLASS_IDS
	elseif LibTSMWoW.IsBCClassic() or LibTSMWoW.IsWrathClassic() then
		data = BCC_ITEM_CLASS_IDS
	elseif LibTSMWoW.IsVanillaClassic() then
		data = VANILLA_ITEM_CLASS_IDS
	else
		error("Unknown game version")
	end

	for _, classId in ipairs(data) do
		local class = ItemClass.GetClassInfo(classId)
		if class then
			private.classIdLookup[strlower(class)] = classId
			private.classLookup[class] = {}
			private.classLookup[class]._index = classId
			local subClasses = nil
			if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
				subClasses = C_AuctionHouse.GetAuctionItemSubClasses(classId)
			else
				subClasses = {GetAuctionItemSubClasses(classId)}
			end
			for _, subClassId in pairs(subClasses) do
				-- In 1.5.8, Blizzard added an invalid classId=0, subClassId=1
				if classId ~= 0 and subClassId ~= -1 then
					local subClassName = ItemClass.GetSubClassInfo(classId, subClassId)
					if subClassName and not strfind(subClassName, "(OBSOLETE)") then
						private.classLookup[class][subClassName] = subClassId
					end
				end
			end
		end
	end

	for class, subClasses in pairs(private.classLookup) do
		tinsert(private.classes, class)
		private.subClasses[class] = {}
		for subClass in pairs(subClasses) do
			if subClass ~= "_index" then
				tinsert(private.subClasses[class], subClass)
			end
		end
		sort(private.subClasses[class], function(a, b) return private.classLookup[class][a] < private.classLookup[class][b] end)
	end
	sort(private.classes, function(a, b) return private.classIdLookup[strlower(a)] < private.classIdLookup[strlower(b)] end)

	for _, id in pairs(Enum.InventoryType) do
		local invType = ItemClass.GetInventorySlotInfo(id)
		if invType then
			private.inventorySlotIdLookup[strlower(invType)] = id
		end
	end

	for _, id in ipairs(ARMOR_GENERIC_INVENTORY_SLOTS) do
		tinsert(private.armorGenericInventorySlots, ItemClass.GetInventorySlotInfo(id))
	end

	for _, id in ipairs(ARMOR_INVENTORY_SLOTS) do
		tinsert(private.armorInventorySlots, ItemClass.GetInventorySlotInfo(id))
	end

	for _, subClassId in ipairs(ARMOR_SUB_CLASSES_WITH_INVENTORY_SLOTS) do
		private.armorSubClassHasInventorySlots[ItemClass.GetSubClassInfo(Enum.ItemClass.Armor, subClassId)] = true
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the name of the item type.
---@return string
function ItemClass.GetClassInfo(classId)
	return C_Item.GetItemClassInfo(classId)
end

---Gets the name of the item subtype.
---@return string
function ItemClass.GetSubClassInfo(classId, subClassId)
	return C_Item.GetItemSubClassInfo(classId, subClassId)
end

---Gets the name of the item subtype.
---@return string
function ItemClass.GetInventorySlotInfo(inventorySlot)
	return C_Item.GetItemInventorySlotInfo(inventorySlot)
end

---Gets the pet class ID.
---@return number
function ItemClass.GetPetClassId()
	return Enum.ItemClass.Battlepet
end

---Gets the armor class ID.
---@return number
function ItemClass.GetArmorClassId()
	return Enum.ItemClass.Armor
end

---Gets the weapon class ID.
---@return number
function ItemClass.GetWeaponClassId()
	return Enum.ItemClass.Weapon
end

---Gets the profession class ID.
---@return number
function ItemClass.GetProfessionClassId()
	return Enum.ItemClass.Profession
end

---Gets all item class names.
---@return string[]
function ItemClass.GetClasses()
	return private.classes
end

---Gets all item sub class names.
---@param class string The class name
---@return string[]
function ItemClass.GetSubClasses(class)
	return private.subClasses[class]
end

---Gets the class ID.
---@param classStr string The class name
---@return number
function ItemClass.GetClassIdFromClassString(classStr)
	return private.classIdLookup[strlower(classStr)]
end

---Gets the sub class ID.
---@param subClass string The sub class name
---@param classId number The class ID
---@return number
function ItemClass.GetSubClassIdFromSubClassString(subClass, classId)
	if not classId then return end
	local class = ItemClass.GetClassInfo(classId)
	if not private.classLookup[class] then return end
	for str, index in pairs(private.classLookup[class]) do
		if strlower(str) == strlower(subClass) then
			return index
		end
	end
end

---Gets the inventory slot ID by name.
---@param slot string The name
---@return number
function ItemClass.GetInventorySlotIdFromInventorySlotString(slot)
	return private.inventorySlotIdLookup[strlower(slot)]
end

---Iterates over the generic inventory slots for a given class.
---@param class string The name of the class
---@return fun(): number, string @Iterator with fields: `index`, `name`
function ItemClass.GenericInventorySlotStringIterator(class)
	if class == ItemClass.GetClassInfo(Enum.ItemClass.Armor) then
		return ipairs(private.armorGenericInventorySlots)
	else
		return ipairs(private.emptyTable)
	end
end

---Gets the list of inventory slots for the given class and subClass.
---@return string[]
function ItemClass.GetInventorySlots(class, subClass)
	if class == ItemClass.GetClassInfo(Enum.ItemClass.Armor) and private.armorSubClassHasInventorySlots[subClass] then
		return private.armorInventorySlots
	else
		return private.emptyTable
	end
end
