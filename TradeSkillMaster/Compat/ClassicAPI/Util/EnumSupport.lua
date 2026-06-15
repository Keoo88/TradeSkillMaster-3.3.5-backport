local Enum = Enum

-- These are used by internal functions, etc.
-- TODO: Certain strings need to be localized.
-- TODO: Certain locale tables have outdated information.

local ItemConsumableSubclassLocale = {
	[Enum.ItemConsumableSubclass.Generic] = "Explosives and Devices",
	[Enum.ItemConsumableSubclass.Potion] = "Potion",
	[Enum.ItemConsumableSubclass.Elixir] = "Elixir",
	[Enum.ItemConsumableSubclass.Scroll] = "Scroll (OBSOLETE)",
	[Enum.ItemConsumableSubclass.Fooddrink] = "Food & Drink",
	[Enum.ItemConsumableSubclass.Itemenhancement] = "Item Enhancement (OBSOLETE)",
	[Enum.ItemConsumableSubclass.Bandage] = "Bandage",
	[Enum.ItemConsumableSubclass.Other] = "Other",
}

local ItemContainerSubclassLocale = {
	"Bag",
	"Soul Bag",
	"Herb Bag",
	"Enchanting Bag",
	"Engineering Bag",
	"Gem Bag",
	"Mining Bag",
	"Leatherworking Bag",
	"Inscription Bag",
	"Tackle Box",
	"Cooking Bag",
}

local ItemProjectileSubclassLocale = {
	"Wand(OBSOLETE)",
	"Bolt(OBSOLETE)",
	"Arrow",
	"Bullet",
	"Thrown(OBSOLETE)",
}

local ItemTradegoodsSubclassLocale = {
	"Trade Goods (OBSOLETE)",
	"Parts",
	"Explosives (OBSOLETE)",
	"Devices (OBSOLETE)",
	"Jewelcrafting",
	"Cloth",
	"Leather",
	"Metal & Stone",
	"Cooking",
	"Herb",
	"Elemental",
	"Other",
	"Enchanting",
	"Materials (OBSOLETE)",
	"Item Enchantment (OBSOLETE)",
	"Weapon Enchantment (OBSOLETE)",
	"Inscription",
	"Explosives and Devices (OBSOLETE)",
}

local ItemQuiverSubclassLocale = {
	"Quiver(OBSOLETE)",
	"Bolt(OBSOLETE)",
	"Quiver",
	"Ammo Pouch",
}

local ItemQuestitemSubclassLocale = {
	"Quest",
}

local ItemGlyphSubclassLocale = {
	"Warrior",
	"Paladin",
	"Hunter",
	"Rogue",
	"Priest",
	"Death Knight",
	"Shaman",
	"Mage",
	"Warlock",
	"Monk",
	"Druid",
	"Demon Hunter",
}

local ItemWeaponSubclassLocale = {
	[Enum.ItemWeaponSubclass.Axe1H] = "One-Handed Axes",
	[Enum.ItemWeaponSubclass.Axe2H] = "Two-Handed Axes",
	[Enum.ItemWeaponSubclass.Bows] = "Bows",
	[Enum.ItemWeaponSubclass.Guns] = "Guns",
	[Enum.ItemWeaponSubclass.Mace1H] = "One-Handed Maces",
	[Enum.ItemWeaponSubclass.Mace2H] = "Two-Handed Maces",
	[Enum.ItemWeaponSubclass.Polearm] = "Polearms",
	[Enum.ItemWeaponSubclass.Sword1H] = "One-Handed Swords",
	[Enum.ItemWeaponSubclass.Sword2H] = "Two-Handed Swords",
	[Enum.ItemWeaponSubclass.Warglaive] = "Warglaives",
	[Enum.ItemWeaponSubclass.Staff] = "Staves",
	[Enum.ItemWeaponSubclass.Bearclaw] = "Bear Claws",
	[Enum.ItemWeaponSubclass.Catclaw] = "CatClaws",
	[Enum.ItemWeaponSubclass.Unarmed] = "Fist Weapons",
	[Enum.ItemWeaponSubclass.Generic] = "Miscellaneous",
	[Enum.ItemWeaponSubclass.Dagger] = "Daggers",
	[Enum.ItemWeaponSubclass.Thrown] = "Thrown",
	[Enum.ItemWeaponSubclass.Obsolete3] = "Spears",
	[Enum.ItemWeaponSubclass.Crossbow] = "Crossbows",
	[Enum.ItemWeaponSubclass.Wand] = "Wands",
	[Enum.ItemWeaponSubclass.Fishingpole] = "Fishing Poles",
}

local ItemGemSubclassLocale = {
	[Enum.ItemGemSubclass.Red] = "Red",
	[Enum.ItemGemSubclass.Blue] = "Blue",
	[Enum.ItemGemSubclass.Yellow] = "Yellow",
	[Enum.ItemGemSubclass.Purple] = "Purple",
	[Enum.ItemGemSubclass.Green] = "Green",
	[Enum.ItemGemSubclass.Orange] = "Orange",
	[Enum.ItemGemSubclass.Meta] = "Meta",
	[Enum.ItemGemSubclass.Simple] = "Simple",
	[Enum.ItemGemSubclass.Prismatic] = "Prismatic",
}

local ItemArmorSubclassLocale = {
	[Enum.ItemArmorSubclass.Generic] = "Miscellaneous",
	[Enum.ItemArmorSubclass.Cloth] = "Cloth",
	[Enum.ItemArmorSubclass.Leather] = "Leather",
	[Enum.ItemArmorSubclass.Mail] = "Mail",
	[Enum.ItemArmorSubclass.Plate] = "Plate",
	[Enum.ItemArmorSubclass.Cosmetic] = "Cosmetic",
	[Enum.ItemArmorSubclass.Shield] = "Shields",
	[Enum.ItemArmorSubclass.Libram] = "Librams",
	[Enum.ItemArmorSubclass.Idol] = "Idols",
	[Enum.ItemArmorSubclass.Totem] = "Totems",
	[Enum.ItemArmorSubclass.Sigil] = "Sigils",
	[Enum.ItemArmorSubclass.Relic] = "Relic",
}

local ItemReagentSubclassLocale = {
	[Enum.ItemReagentSubclass.Reagent] = "Reagent",
	[Enum.ItemReagentSubclass.Keystone] = "Keystone",
	[Enum.ItemReagentSubclass.ContextToken] = "Context Token",
}

local ItemRecipeSubclassLocale = {
	[Enum.ItemRecipeSubclass.Book] = "Book",
	[Enum.ItemRecipeSubclass.Leatherworking] = "Leatherworking",
	[Enum.ItemRecipeSubclass.Tailoring] = "Tailoring",
	[Enum.ItemRecipeSubclass.Engineering] = "Engineering",
	[Enum.ItemRecipeSubclass.Blacksmithing] = "Blacksmithing",
	[Enum.ItemRecipeSubclass.Cooking] = "Cooking",
	[Enum.ItemRecipeSubclass.Alchemy] = "Alchemy",
	[Enum.ItemRecipeSubclass.FirstAid] = "First Aid",
	[Enum.ItemRecipeSubclass.Enchanting] = "Enchanting",
	[Enum.ItemRecipeSubclass.Fishing] = "Fishing",
	[Enum.ItemRecipeSubclass.Jewelcrafting] = "Jewelcrafting",
	[Enum.ItemRecipeSubclass.Inscription] = "Inscription",
}

local ItemMiscellaneousSubclassLocale = {
	[Enum.ItemMiscellaneousSubclass.Junk] = "Junk",
	[Enum.ItemMiscellaneousSubclass.Reagent] = "Reagent",
	[Enum.ItemMiscellaneousSubclass.CompanionPet] = "Companion Pets",
	[Enum.ItemMiscellaneousSubclass.Holiday] = "Holiday",
	[Enum.ItemMiscellaneousSubclass.Other] = "Other",
	[Enum.ItemMiscellaneousSubclass.Mount] = "Mount",
	[Enum.ItemMiscellaneousSubclass.MountEquipment] = "Mount Equipment",
}

local BattlePetTypesLocale = {
	[Enum.BattlePetTypes.Humanoid] = "Humanoid",
	[Enum.BattlePetTypes.Dragonkin] = "Dragonkin",
	[Enum.BattlePetTypes.Flying] = "Flying",
	[Enum.BattlePetTypes.Undead] = "Undead",
	[Enum.BattlePetTypes.Critter] = "Critter",
	[Enum.BattlePetTypes.Magic] = "Magic",
	[Enum.BattlePetTypes.Elemental] = "Elemental",
	[Enum.BattlePetTypes.Beast] = "Beast",
	[Enum.BattlePetTypes.Aquatic] = "Aquatic",
	[Enum.BattlePetTypes.Mechanical] = "Mechanical",
	[Enum.BattlePetTypes.NonCombat] = "Non-Combat",
}

local ItemProfessionSubclassLocale = {
	[Enum.ItemProfessionSubclass.Blacksmithing] = "Blacksmithing",
	[Enum.ItemProfessionSubclass.Leatherworking] = "Leatherworking",
	[Enum.ItemProfessionSubclass.Alchemy] = "Alchemy",
	[Enum.ItemProfessionSubclass.Herbalism] = "Herbalism",
	[Enum.ItemProfessionSubclass.Cooking] = "Cooking",
	[Enum.ItemProfessionSubclass.Mining] = "Mining",
	[Enum.ItemProfessionSubclass.Tailoring] = "Tailoring",
	[Enum.ItemProfessionSubclass.Engineering] = "Engineering",
	[Enum.ItemProfessionSubclass.Enchanting] = "Enchanting",
	[Enum.ItemProfessionSubclass.Fishing] = "Fishing",
	[Enum.ItemProfessionSubclass.Skinning] = "Skinning",
	[Enum.ItemProfessionSubclass.Jewelcrafting] = "Jewelcrafting",
	[Enum.ItemProfessionSubclass.Inscription] = "Inscription",
	[Enum.ItemProfessionSubclass.Archaeology] = "Archaeology",
}

Enum.__ItemClassInfo = {
	[Enum.ItemClass.Consumable] = ItemConsumableSubclassLocale,
	[Enum.ItemClass.Container] = ItemContainerSubclassLocale,
	[Enum.ItemClass.Weapon] = ItemWeaponSubclassLocale,
	[Enum.ItemClass.Gem] = ItemGemSubclassLocale,
	[Enum.ItemClass.Armor] = ItemArmorSubclassLocale,
	[Enum.ItemClass.Reagent] = ItemReagentSubclassLocale,
	[Enum.ItemClass.Projectile] = ItemProjectileSubclassLocale,
	[Enum.ItemClass.Tradegoods] = ItemTradegoodsSubclassLocale,
	[Enum.ItemClass.Recipe] = ItemRecipeSubclassLocale,
	[Enum.ItemClass.Quiver] = ItemQuiverSubclassLocale,
	[Enum.ItemClass.Questitem] = ItemQuestitemSubclassLocale,
	[Enum.ItemClass.Miscellaneous] = ItemMiscellaneousSubclassLocale,
	[Enum.ItemClass.Glyph] = ItemGlyphSubclassLocale,
	[Enum.ItemClass.Battlepet] = BattlePetTypesLocale,
	[Enum.ItemClass.Profession] = ItemProfessionSubclassLocale,
}

Enum.__InventoryTypeInfo = {
	[Enum.InventoryType.IndexNonEquipType] = INVTYPE_NON_EQUIP or "Non-equippable",
	[Enum.InventoryType.IndexHeadType] = INVTYPE_HEAD or "Head",
	[Enum.InventoryType.IndexNeckType] = INVTYPE_NECK or "Neck",
	[Enum.InventoryType.IndexShoulderType] = INVTYPE_SHOULDER or "Shoulder",
	[Enum.InventoryType.IndexBodyType] = INVTYPE_BODY or "Shirt",
	[Enum.InventoryType.IndexChestType] = INVTYPE_CHEST or "Chest",
	[Enum.InventoryType.IndexWaistType] = INVTYPE_WAIST or "Waist",
	[Enum.InventoryType.IndexLegsType] = INVTYPE_LEGS or "Legs",
	[Enum.InventoryType.IndexFeetType] = INVTYPE_FEET or "Feet",
	[Enum.InventoryType.IndexWristType] = INVTYPE_WRIST or "Wrist",
	[Enum.InventoryType.IndexHandType] = INVTYPE_HAND or "Hands",
	[Enum.InventoryType.IndexFingerType] = INVTYPE_FINGER or "Finger",
	[Enum.InventoryType.IndexTrinketType] = INVTYPE_TRINKET or "Trinket",
	[Enum.InventoryType.IndexWeaponType] = INVTYPE_WEAPON or "One-Hand",
	[Enum.InventoryType.IndexShieldType] = INVTYPE_SHIELD or "Off Hand",
	[Enum.InventoryType.IndexRangedType] = INVTYPE_RANGED or "Ranged",
	[Enum.InventoryType.IndexCloakType] = INVTYPE_CLOAK or "Back",
	[Enum.InventoryType.Index2HweaponType] = INVTYPE_2HWEAPON or "Two-Hand",
	[Enum.InventoryType.IndexBagType] = INVTYPE_BAG or "Bag",
	[Enum.InventoryType.IndexTabardType] = INVTYPE_TABARD or "Tabard",
	[Enum.InventoryType.IndexRobeType] = INVTYPE_ROBE or "Chest",
	[Enum.InventoryType.IndexWeaponmainhandType] = INVTYPE_WEAPONMAINHAND or "Main Hand",
	[Enum.InventoryType.IndexWeaponoffhandType] = INVTYPE_WEAPONOFFHAND or "Off Hand",
	[Enum.InventoryType.IndexHoldableType] = INVTYPE_HOLDABLE or "Held In Off-hand",
	[Enum.InventoryType.IndexAmmoType] = INVTYPE_AMMO or "Ammo",
	[Enum.InventoryType.IndexThrownType] = INVTYPE_THROWN or "Thrown",
	[Enum.InventoryType.IndexRangedrightType] = INVTYPE_RANGEDRIGHT or "Ranged",
	[Enum.InventoryType.IndexQuiverType] = INVTYPE_QUIVER or "Quiver",
	[Enum.InventoryType.IndexRelicType] = INVTYPE_RELIC or "Relic",
	[Enum.InventoryType.IndexProfessionToolType] = INVTYPE_PROFESSION_TOOL or "Profession Tool",
	[Enum.InventoryType.IndexProfessionGearType] = INVTYPE_PROFESSION_GEAR or "Profession Equipment",
	[Enum.InventoryType.IndexEquipablespellOffensiveType] = INVTYPE_EQUIPABLESPELL_OFFENSIVE or "Equipable Spell - Offensive",
	[Enum.InventoryType.IndexEquipablespellUtilityType] = INVTYPE_EQUIPABLESPELL_UTILITY or "Equipable Spell - Utility",
	[Enum.InventoryType.IndexEquipablespellDefensiveType] = INVTYPE_EQUIPABLESPELL_DEFENSIVE or "Equipable Spell - Defensive",
	[Enum.InventoryType.IndexEquipablespellWeaponType] = INVTYPE_EQUIPABLESPELL_WEAPON or "Equipable Spell - Weapon",
}

Enum.__InventoryTypeIndex = {
	INVTYPE_NON_EQUIP = Enum.InventoryType.IndexNonEquipType,
	INVTYPE_HEAD = Enum.InventoryType.IndexHeadType,
	INVTYPE_NECK = Enum.InventoryType.IndexNeckType,
	INVTYPE_SHOULDER = Enum.InventoryType.IndexShoulderType,
	INVTYPE_BODY = Enum.InventoryType.IndexBodyType,
	INVTYPE_CHEST = Enum.InventoryType.IndexChestType,
	INVTYPE_WAIST = Enum.InventoryType.IndexWaistType,
	INVTYPE_LEGS = Enum.InventoryType.IndexLegsType,
	INVTYPE_FEET = Enum.InventoryType.IndexFeetType,
	INVTYPE_WRIST = Enum.InventoryType.IndexWristType,
	INVTYPE_HAND = Enum.InventoryType.IndexHandType,
	INVTYPE_FINGER = Enum.InventoryType.IndexFingerType,
	INVTYPE_TRINKET = Enum.InventoryType.IndexTrinketType,
	INVTYPE_WEAPON = Enum.InventoryType.IndexWeaponType,
	INVTYPE_SHIELD = Enum.InventoryType.IndexShieldType,
	INVTYPE_RANGED = Enum.InventoryType.IndexRangedType,
	INVTYPE_CLOAK = Enum.InventoryType.IndexCloakType,
	INVTYPE_2HWEAPON = Enum.InventoryType.Index2HweaponType,
	INVTYPE_BAG = Enum.InventoryType.IndexBagType,
	INVTYPE_TABARD = Enum.InventoryType.IndexTabardType,
	INVTYPE_ROBE = Enum.InventoryType.IndexRobeType,
	INVTYPE_WEAPONMAINHAND = Enum.InventoryType.IndexWeaponmainhandType,
	INVTYPE_WEAPONOFFHAND = Enum.InventoryType.IndexWeaponoffhandType,
	INVTYPE_HOLDABLE = Enum.InventoryType.IndexHoldableType,
	INVTYPE_AMMO = Enum.InventoryType.IndexAmmoType,
	INVTYPE_THROWN = Enum.InventoryType.IndexThrownType,
	INVTYPE_RANGEDRIGHT = Enum.InventoryType.IndexRangedrightType,
	INVTYPE_QUIVER = Enum.InventoryType.IndexQuiverType,
	INVTYPE_RELIC = Enum.InventoryType.IndexRelicType,
	INVTYPE_PROFESSION_TOOL = Enum.InventoryType.IndexProfessionToolType,
	INVTYPE_PROFESSION_GEAR = Enum.InventoryType.IndexProfessionGearType,
	INVTYPE_EQUIPABLESPELL_OFFENSIVE = Enum.InventoryType.IndexEquipablespellOffensiveType,
	INVTYPE_EQUIPABLESPELL_UTILITY = Enum.InventoryType.IndexEquipablespellUtilityType,
	INVTYPE_EQUIPABLESPELL_DEFENSIVE = Enum.InventoryType.IndexEquipablespellDefensiveType,
	INVTYPE_EQUIPABLESPELL_WEAPON = Enum.InventoryType.IndexEquipablespellWeaponType,
}