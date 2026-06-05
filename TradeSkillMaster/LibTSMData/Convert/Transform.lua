-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMData = select(2, ...).LibTSMData
local Transform = LibTSMData:Init("Transform")
local DATA = {}




-- ============================================================================
-- Module Functions
-- ============================================================================

function Transform.Get()
	if LibTSMData.IsRetail() then
		return DATA.Retail
	elseif LibTSMData.IsPandaClassic() then
		return DATA.Panda
	elseif LibTSMData.IsWrathClassic() then
		return DATA.Wrath
	elseif LibTSMData.IsBCClassic() then
		return DATA.BCC
	elseif LibTSMData.IsVanillaClassic() then
		return DATA.Vanilla
	else
		error("Unknown game version")
	end
end



-- ============================================================================
-- Vanilla
-- ============================================================================

DATA.Vanilla = {
	-- Essences
	["i:16203"] = {
		["i:16202"] = 1/3, -- Greater Eternal Essence
	},
	["i:16202"] = {
		["i:16203"] = 3, -- Lesser Eternal Essence
	},
	["i:11175"] = {
		["i:11174"] = 1/3, -- Greater Nether Essence
	},
	["i:11174"] = {
		["i:11175"] = 3, -- Lesser Nether Essence
	},
	["i:11135"] = {
		["i:11134"] = 1/3, -- Greater Mystic Essence
	},
	["i:11134"] = {
		["i:11135"] = 3, -- Lesser Mystic Essence
	},
	["i:11082"] = {
		["i:10998"] = 1/3, -- Greater Astral Essence
	},
	["i:10998"] = {
		["i:11082"] = 3, -- Lesser Astral Essence
	},
	["i:10939"] = {
		["i:10938"] = 1/3, -- Greater Magic Essence
	},
	["i:10938"] = {
		["i:10939"] = 3, -- Lesser Magic Essence
	},
}



-- ============================================================================
-- Burning Crusade
-- ============================================================================

DATA.BCC = {
	-- Essences
	["i:22446"] = {
		["i:22447"] = 1/3, -- Greater Planar Essence
	},
	["i:22447"] = {
		["i:22446"] = 3, -- Lesser Planar Essence
	},
	["i:16203"] = {
		["i:16202"] = 1/3, -- Greater Eternal Essence
	},
	["i:16202"] = {
		["i:16203"] = 3, -- Lesser Eternal Essence
	},
	["i:11175"] = {
		["i:11174"] = 1/3, -- Greater Nether Essence
	},
	["i:11174"] = {
		["i:11175"] = 3, -- Lesser Nether Essence
	},
	["i:11135"] = {
		["i:11134"] = 1/3, -- Greater Mystic Essence
	},
	["i:11134"] = {
		["i:11135"] = 3, -- Lesser Mystic Essence
	},
	["i:11082"] = {
		["i:10998"] = 1/3, -- Greater Astral Essence
	},
	["i:10998"] = {
		["i:11082"] = 3, -- Lesser Astral Essence
	},
	["i:10939"] = {
		["i:10938"] = 1/3, -- Greater Magic Essence
	},
	["i:10938"] = {
		["i:10939"] = 3, -- Lesser Magic Essence
	},

	-- Primals
	["i:21885"] = {
		["i:22578"] = 0.1, -- Water
	},
	["i:22456"] = {
		["i:22577"] = 0.1, -- Shadow
	},
	["i:22457"] = {
		["i:22576"] = 0.1, -- Mana
	},
	["i:21886"] = {
		["i:22575"] = 0.1, -- Life
	},
	["i:21884"] = {
		["i:22574"] = 0.1, -- Fire
	},
	["i:22452"] = {
		["i:22573"] = 0.1, -- Earth
	},
	["i:22451"] = {
		["i:22572"] = 0.1, -- Air
	},
}




-- ============================================================================
-- Panda
-- ============================================================================

DATA.Panda = {
	-- Essences
	["i:34055"] = {
		["i:34056"] = 1/3, -- Greater Cosmic Essence
	},
	["i:34056"] = {
		["i:34055"] = 3, -- Lesser Cosmic Essence
	},
	["i:22446"] = {
		["i:22447"] = 1/3, -- Greater Planar Essence
	},
	["i:22447"] = {
		["i:22446"] = 3, -- Lesser Planar Essence
	},
	["i:16203"] = {
		["i:16202"] = 1/3, -- Greater Eternal Essence
	},
	["i:16202"] = {
		["i:16203"] = 3, -- Lesser Eternal Essence
	},
	["i:11175"] = {
		["i:11174"] = 1/3, -- Greater Nether Essence
	},
	["i:11174"] = {
		["i:11175"] = 3, -- Lesser Nether Essence
	},
	["i:11135"] = {
		["i:11134"] = 1/3, -- Greater Mystic Essence
	},
	["i:11134"] = {
		["i:11135"] = 3, -- Lesser Mystic Essence
	},
	["i:11082"] = {
		["i:10998"] = 1/3, -- Greater Astral Essence
	},
	["i:10998"] = {
		["i:11082"] = 3, -- Lesser Astral Essence
	},
	["i:10939"] = {
		["i:10938"] = 1/3, -- Greater Magic Essence
	},
	["i:10938"] = {
		["i:10939"] = 3, -- Lesser Magic Essence
	},

	-- Shards
	["i:34052"] = {
		["i:34053"] = 1/3, -- Dream Shard
	},
	["i:52721"] = {
		["i:52720"] = 1/3, -- Heavenly Shard
	},
	["i:74247"] = {
		["i:74252"] = 1/3, -- Ethereal Shard
	},

	-- Crystals
	["i:74248"] = {
		["i:105718"] = 1/3, -- Sha Crystal Fragment
	},

	-- Primals
	["i:21885"] = {
		["i:22578"] = 0.1, -- Water
	},
	["i:22456"] = {
		["i:22577"] = 0.1, -- Shadow
	},
	["i:22457"] = {
		["i:22576"] = 0.1, -- Mana
	},
	["i:21886"] = {
		["i:22575"] = 0.1, -- Life
	},
	["i:21884"] = {
		["i:22574"] = 0.1, -- Fire
	},
	["i:22452"] = {
		["i:22573"] = 0.1, -- Earth
	},
	["i:22451"] = {
		["i:22572"] = 0.1, -- Air
	},

	-- Eternals
	["i:37700"] = {
		["i:35623"] = 10, -- Air
	},
	["i:35623"] = {
		["i:37700"] = 0.1, -- Air
	},
	["i:37701"] = {
		["i:35624"] = 10, -- Earth
	},
	["i:35624"] = {
		["i:37701"] = 0.1, -- Earth
	},
	["i:37702"] = {
		["i:36860"] = 10, -- Fire
	},
	["i:36860"] = {
		["i:37702"] = 0.1, -- Fire
	},
	["i:37703"] = {
		["i:35627"] = 10, -- Shadow
	},
	["i:35627"] = {
		["i:37703"] = 0.1, -- Shadow
	},
	["i:37704"] = {
		["i:35625"] = 10, -- Life
	},
	["i:35625"] = {
		["i:37704"] = 0.1, -- Life
	},
	["i:37705"] = {
		["i:35622"] = 10, -- Water
	},
	["i:35622"] = {
		["i:37705"] = 0.1, -- Water
	},

	-- Ore Nuggets
	["i:72092"] = {
		["i:97512"] = 0.1, -- Ghost Iron Ore
	},
	["i:72093"] = {
		["i:97546"] = 0.1, -- Kyparite
	},

	-- Herb Parts
	["i:72234"] = {
		["i:97619"] = 0.1, -- Torn Green Tea Leaf
	},
	["i:79010"] = {
		["i:97622"] = 0.1, -- Snow Lily Petal
	},
	["i:79011"] = {
		["i:97623"] = 0.1, -- Fool's Cap Spores
	},
	["i:72237"] = {
		["i:97620"] = 0.1, -- Rain Poppy Petal
	},
	["i:72235"] = {
		["i:97621"] = 0.1, -- Silkweed Stem
	},
	["i:89639"] = {
		["i:97624"] = 0.1, -- Desecrated Herb Pod
	},

	-- Misc
	["i:76061"] = {
		["i:89112"] = 0.1, -- Mote of Harmony
	},
	["i:76734"] = {
		["i:90407"] = 0.1, -- Sparkling Shard
	},
	["i:90636"] = {
		["i:90637"] = 0.1, -- Splinter of Hate
	},
}



-- ============================================================================
-- Wrath (BCC essences/primals + WotLK cosmic essences, dream shard, eternals)
-- ============================================================================

DATA.Wrath = {
	-- Essences
	["i:34055"] = {
		["i:34056"] = 1/3, -- Greater Cosmic Essence
	},
	["i:34056"] = {
		["i:34055"] = 3, -- Lesser Cosmic Essence
	},
	["i:22446"] = {
		["i:22447"] = 1/3, -- Greater Planar Essence
	},
	["i:22447"] = {
		["i:22446"] = 3, -- Lesser Planar Essence
	},
	["i:16203"] = {
		["i:16202"] = 1/3, -- Greater Eternal Essence
	},
	["i:16202"] = {
		["i:16203"] = 3, -- Lesser Eternal Essence
	},
	["i:11175"] = {
		["i:11174"] = 1/3, -- Greater Nether Essence
	},
	["i:11174"] = {
		["i:11175"] = 3, -- Lesser Nether Essence
	},
	["i:11135"] = {
		["i:11134"] = 1/3, -- Greater Mystic Essence
	},
	["i:11134"] = {
		["i:11135"] = 3, -- Lesser Mystic Essence
	},
	["i:11082"] = {
		["i:10998"] = 1/3, -- Greater Astral Essence
	},
	["i:10998"] = {
		["i:11082"] = 3, -- Lesser Astral Essence
	},
	["i:10939"] = {
		["i:10938"] = 1/3, -- Greater Magic Essence
	},
	["i:10938"] = {
		["i:10939"] = 3, -- Lesser Magic Essence
	},

	-- Shards
	["i:34052"] = {
		["i:34053"] = 1/3, -- Dream Shard
	},

	-- Primals
	["i:21885"] = {
		["i:22578"] = 0.1, -- Water
	},
	["i:22456"] = {
		["i:22577"] = 0.1, -- Shadow
	},
	["i:22457"] = {
		["i:22576"] = 0.1, -- Mana
	},
	["i:21886"] = {
		["i:22575"] = 0.1, -- Life
	},
	["i:21884"] = {
		["i:22574"] = 0.1, -- Fire
	},
	["i:22452"] = {
		["i:22573"] = 0.1, -- Earth
	},
	["i:22451"] = {
		["i:22572"] = 0.1, -- Air
	},

	-- Eternals
	["i:37700"] = {
		["i:35623"] = 10, -- Air
	},
	["i:35623"] = {
		["i:37700"] = 0.1, -- Air
	},
	["i:37701"] = {
		["i:35624"] = 10, -- Earth
	},
	["i:35624"] = {
		["i:37701"] = 0.1, -- Earth
	},
	["i:37702"] = {
		["i:36860"] = 10, -- Fire
	},
	["i:36860"] = {
		["i:37702"] = 0.1, -- Fire
	},
	["i:37703"] = {
		["i:35627"] = 10, -- Shadow
	},
	["i:35627"] = {
		["i:37703"] = 0.1, -- Shadow
	},
	["i:37704"] = {
		["i:35625"] = 10, -- Life
	},
	["i:35625"] = {
		["i:37704"] = 0.1, -- Life
	},
	["i:37705"] = {
		["i:35622"] = 10, -- Water
	},
	["i:35622"] = {
		["i:37705"] = 0.1, -- Water
	},
}



-- ============================================================================
-- Retail
-- ============================================================================

DATA.Retail = {
	-- Essences
	["i:52719"] = {
		["i:52718"] = 1/3, -- Greater Celestial Essence
	},
	["i:52718"] = {
		["i:52719"] = 3, -- Lesser Celestial Essence
	},
	["i:34055"] = {
		["i:34056"] = 1/3, -- Greater Cosmic Essence
	},
	["i:34056"] = {
		["i:34055"] = 3, -- Lesser Cosmic Essence
	},
	["i:22446"] = {
		["i:22447"] = 1/3, -- Greater Planar Essence
	},
	["i:22447"] = {
		["i:22446"] = 3, -- Lesser Planar Essence
	},
	["i:16203"] = {
		["i:16202"] = 1/3, -- Greater Eternal Essence
	},
	["i:16202"] = {
		["i:16203"] = 3, -- Lesser Eternal Essence
	},
	["i:10939"] = {
		["i:10938"] = 1/3, -- Greater Magic Essence
	},
	["i:10938"] = {
		["i:10939"] = 3, -- Lesser Magic Essence
	},

	-- Dust
	["i:156930"] = {
		["i:16204"] = 1/3, -- Rich Illusion Dust
	},
	["i:16204"] = {
		["i:156930"] = 3, -- Light Illusion Dust
	},

	-- Shards
	["i:34052"] = {
		["i:34053"] = 1/3, -- Dream Shard
	},
	["i:52721"] = {
		["i:52720"] = 1/3, -- Heavenly Shard
	},
	["i:74247"] = {
		["i:74252"] = 1/3, -- Ethereal Shard
	},
	["i:111245"] = {
		["i:115502"] = 0.1, -- Luminous Shard
	},

	-- Crystals
	["i:113588"] = {
		["i:115504"] = 0.1, -- Temporal Crystal
	},
	["i:74248"] = {
		["i:105718"] = 1/3, -- Sha Crystal Fragment
	},

	-- Primals
	["i:21885"] = {
		["i:22578"] = 0.1, -- Water
	},
	["i:22456"] = {
		["i:22577"] = 0.1, -- Shadow
	},
	["i:22457"] = {
		["i:22576"] = 0.1, -- Mana
	},
	["i:21886"] = {
		["i:22575"] = 0.1, -- Life
	},
	["i:21884"] = {
		["i:22574"] = 0.1, -- Fire
	},
	["i:22452"] = {
		["i:22573"] = 0.1, -- Earth
	},
	["i:22451"] = {
		["i:22572"] = 0.1, -- Air
	},

	-- Eternals
	["i:37700"] = {
		["i:35623"] = 10, -- Air
	},
	["i:35623"] = {
		["i:37700"] = 0.1, -- Air
	},
	["i:37701"] = {
		["i:35624"] = 10, -- Earth
	},
	["i:35624"] = {
		["i:37701"] = 0.1, -- Earth
	},
	["i:37702"] = {
		["i:36860"] = 10, -- Fire
	},
	["i:36860"] = {
		["i:37702"] = 0.1, -- Fire
	},
	["i:37703"] = {
		["i:35627"] = 10, -- Shadow
	},
	["i:35627"] = {
		["i:37703"] = 0.1, -- Shadow
	},
	["i:37704"] = {
		["i:35625"] = 10, -- Life
	},
	["i:35625"] = {
		["i:37704"] = 0.1, -- Life
	},
	["i:37705"] = {
		["i:35622"] = 10, -- Water
	},
	["i:35622"] = {
		["i:37705"] = 0.1, -- Water
	},

	-- Rousing
	["i:190322"] = {
		["i:190324"] = 10, -- Order
	},
	["i:190324"] = {
		["i:190322"] = 0.1, -- Order
	},
	["i:190326"] = {
		["i:190327"] = 10, -- Air
	},
	["i:190327"] = {
		["i:190326"] = 0.1, -- Air
	},
	["i:190320"] = {
		["i:190321"] = 10, -- Fire
	},
	["i:190321"] = {
		["i:190320"] = 0.1, -- Fire
	},
	["i:190330"] = {
		["i:190331"] = 10, -- Decay
	},
	["i:190331"] = {
		["i:190330"] = 0.1, -- Decay
	},
	["i:190328"] = {
		["i:190329"] = 10, -- Frost
	},
	["i:190329"] = {
		["i:190328"] = 0.1, -- Frost
	},
	["i:190315"] = {
		["i:190316"] = 10, -- Earth
	},
	["i:190316"] = {
		["i:190315"] = 0.1, -- Earth
	},
	["i:190451"] = {
		["i:190450"] = 10, -- Ire
	},
	["i:190450"] = {
		["i:190451"] = 0.1, -- Ire
	},

	-- Fish
	["i:109137"] = {
		["i:111601"] = 4, -- Enormous Crescent Saberfish
		["i:111595"] = 2, -- Crescent Saberfish
		["i:111589"] = 1, -- Small Crescent Saberfish
	},
	["i:109138"] = {
		["i:111676"] = 4, -- Enormous Jawless Skulker
		["i:111669"] = 2, -- Jawless Skulker
		["i:111650"] = 1, -- Small Jawless Skulker
	},
	["i:109139"] = {
		["i:111675"] = 4, -- Enormous Fat Sleeper
		["i:111668"] = 2, -- Fat Sleeper
		["i:111651"] = 1, -- Small Fat Sleeper
	},
	["i:109140"] = {
		["i:111674"] = 4, -- Enormous Blind Lake Sturgeon
		["i:111667"] = 2, -- Blind Lake Sturgeon
		["i:111652"] = 1, -- Small Blind Lake Sturgeon
	},
	["i:109141"] = {
		["i:111673"] = 4, -- Enormous Fire Ammonite
		["i:111666"] = 2, -- Fire Ammonite
		["i:111656"] = 1, -- Small Fire Ammonite
	},
	["i:109142"] = {
		["i:111672"] = 4, -- Enormous Sea Scorpion
		["i:111665"] = 2, -- Sea Scorpion
		["i:111658"] = 1, -- Small Sea Scorpion
	},
	["i:109143"] = {
		["i:111671"] = 4, -- Enormous Abyssal Gulper Eel
		["i:111664"] = 2, -- Abyssal Gulper Eel
		["i:111659"] = 1, -- Small Abyssal Gulper Eel
	},
	["i:109144"] = {
		["i:111670"] = 4, -- Enormous Blackwater Whiptail
		["i:111663"] = 2, -- Blackwater Whiptail
		["i:111662"] = 1, -- Small Blackwater Whiptail
	},

	-- Fish Oil
	["i:160711"] = {
		["i:152543"] = 1, -- Sand Shifter
		["i:152544"] = 1, -- Slimy Mackerel
		["i:152545"] = 1, -- Frenzied Fangtooth
		["i:152546"] = 1, -- Lane Snapper
		["i:152547"] = 1, -- Great Sea Catfish
		["i:152548"] = 1, -- Tiragarde Perch
		["i:152549"] = 1, -- Redtail Loach
		["i:168302"] = 1, -- Viper Fish
		["i:168646"] = 1, -- Mauve Stinger
		["i:174327"] = 1, -- Malformed Gnasher
		["i:174328"] = 1, -- Aberrant Voidfin
	},

	-- Ore Nuggets
	["i:2771"] = {
		["i:108295"] = 0.1, -- Tin Ore
	},
	["i:2772"] = {
		["i:108297"] = 0.1, -- Iron Ore
	},
	["i:2775"] = {
		["i:108294"] = 0.1, -- Silver Ore
	},
	["i:2776"] = {
		["i:108296"] = 0.1, -- Gold Ore
	},
	["i:3858"] = {
		["i:108300"] = 0.1, -- Mithril Ore
	},
	["i:7911"] = {
		["i:108299"] = 0.1, -- Truesilver Ore
	},
	["i:10620"] = {
		["i:108298"] = 0.1, -- Thorium Ore
	},
	["i:23424"] = {
		["i:108301"] = 0.1, -- Fel Iron Ore
	},
	["i:23425"] = {
		["i:108302"] = 0.1, -- Adamantite Ore
	},
	["i:23426"] = {
		["i:108304"] = 0.1, -- Khorium Ore
	},
	["i:23427"] = {
		["i:108303"] = 0.1, -- Eternium Ore
	},
	["i:36909"] = {
		["i:108305"] = 0.1, -- Cobalt Ore
	},
	["i:36910"] = {
		["i:108391"] = 0.1, -- Titanium Ore
	},
	["i:36912"] = {
		["i:108306"] = 0.1, -- Saronite Ore
	},
	["i:52183"] = {
		["i:108309"] = 0.1, -- Pyrite Ore
	},
	["i:52185"] = {
		["i:108308"] = 0.1, -- Elementium Ore
	},
	["i:53038"] = {
		["i:108307"] = 0.1, -- Obsidium Ore
	},
	["i:72092"] = {
		["i:97512"] = 0.1, -- Ghost Iron Ore
	},
	["i:72093"] = {
		["i:97546"] = 0.1, -- Kyparite
	},
	["i:109118"] = {
		["i:109992"] = 0.1, -- Blackrock  Ore
	},
	["i:109119"] = {
		["i:109991"] = 0.1, -- True Iron Ore
	},

	-- Herb Parts
	["i:785"] = {
		["i:108318"] = 0.1, -- Mageroyal Petal
	},
	["i:2449"] = {
		["i:108319"] = 0.1, -- Earthroot Stem
	},
	["i:2450"] = {
		["i:108320"] = 0.1, -- Briarthorn Bramble
	},
	["i:2452"] = {
		["i:108321"] = 0.1, -- Swiftthistle Leaf
	},
	["i:2453"] = {
		["i:108322"] = 0.1, -- Bruiseweed Stem
	},
	["i:3355"] = {
		["i:108323"] = 0.1, -- Wild Steelbloom Petal
	},
	["i:3356"] = {
		["i:108324"] = 0.1, -- Kingsblood Petal
	},
	["i:3357"] = {
		["i:108325"] = 0.1, -- Liferoot Stem
	},
	["i:3358"] = {
		["i:108326"] = 0.1, -- Khadgar's Whisker Stem
	},
	["i:3369"] = {
		["i:108327"] = 0.1, -- Grave Moss Leaf
	},
	["i:3818"] = {
		["i:108328"] = 0.1, -- Fadeleaf Petal
	},
	["i:3819"] = {
		["i:108329"] = 0.1, -- Dragon's Teeth Stem
	},
	["i:3820"] = {
		["i:108330"] = 0.1, -- Stranglekelp Blade
	},
	["i:3821"] = {
		["i:108331"] = 0.1, -- Goldthorn Bramble
	},
	["i:4625"] = {
		["i:108332"] = 0.1, -- Firebloom Petal
	},
	["i:8831"] = {
		["i:108333"] = 0.1, -- Purple Lotus Petal
	},
	["i:8838"] = {
		["i:108335"] = 0.1, -- Sungrass Stalk
	},
	["i:8845"] = {
		["i:108337"] = 0.1, -- Ghost Mushroom Cap
	},
	["i:8846"] = {
		["i:108338"] = 0.1, -- Gromsblood Leaf
	},
	["i:8839"] = {
		["i:108336"] = 0.1, -- Blindweed Stem
	},
	["i:13463"] = {
		["i:108339"] = 0.1, -- Dreamfoil Blade
	},
	["i:13464"] = {
		["i:108340"] = 0.1, -- Golden Sansam Leaf
	},
	["i:13465"] = {
		["i:108341"] = 0.1, -- Mountain Silversage Stalk
	},
	["i:13466"] = {
		["i:108342"] = 0.1, -- Sorrowmoss Leaf
	},
	["i:13467"] = {
		["i:108343"] = 0.1, -- Icecap Petal
	},
	["i:22785"] = {
		["i:108344"] = 0.1, -- Felweed Stalk
	},
	["i:22786"] = {
		["i:108345"] = 0.1, -- Dreaming Glory Petal
	},
	["i:22787"] = {
		["i:108346"] = 0.1, -- Ragveil Cap
	},
	["i:22789"] = {
		["i:108347"] = 0.1, -- Terocone Leaf
	},
	["i:22790"] = {
		["i:108348"] = 0.1, -- Ancient Lichen Petal
	},
	["i:22791"] = {
		["i:108349"] = 0.1, -- Netherbloom Leaf
	},
	["i:22792"] = {
		["i:108350"] = 0.1, -- Nightmare Vine Stem
	},
	["i:22793"] = {
		["i:108351"] = 0.1, -- Mana Thistle Leaf
	},
	["i:36901"] = {
		["i:108352"] = 0.1, -- Goldclover Leaf
	},
	["i:36903"] = {
		["i:108353"] = 0.1, -- Adder's Tongue Stem
	},
	["i:36904"] = {
		["i:108354"] = 0.1, -- Tiger Lily Petal
	},
	["i:36905"] = {
		["i:108355"] = 0.1, -- Lichbloom Stalk
	},
	["i:36906"] = {
		["i:108356"] = 0.1, -- Icethorn Bramble
	},
	["i:36907"] = {
		["i:108357"] = 0.1, -- Talandra's Rose Petal
	},
	["i:37921"] = {
		["i:108358"] = 0.1, -- Deadnettle Bramble
	},
	["i:39970"] = {
		["i:108359"] = 0.1, -- Fire Leaf Bramble
	},
	["i:52983"] = {
		["i:108360"] = 0.1, -- Cinderbloom Petal
	},
	["i:52984"] = {
		["i:108361"] = 0.1, -- Stormvine Stalk
	},
	["i:52985"] = {
		["i:108362"] = 0.1, -- Azshara's Veil Stem
	},
	["i:52986"] = {
		["i:108363"] = 0.1, -- Heartblossom Petal
	},
	["i:52988"] = {
		["i:108365"] = 0.1, -- Whiptail Stem
	},
	["i:72234"] = {
		["i:97619"] = 0.1, -- Torn Green Tea Leaf
	},
	["i:79010"] = {
		["i:97622"] = 0.1, -- Snow Lily Petal
	},
	["i:79011"] = {
		["i:97623"] = 0.1, -- Fool's Cap Spores
	},
	["i:72237"] = {
		["i:97620"] = 0.1, -- Rain Poppy Petal
	},
	["i:72235"] = {
		["i:97621"] = 0.1, -- Silkweed Stem
	},
	["i:89639"] = {
		["i:97624"] = 0.1, -- Desecrated Herb Pod
	},
	["i:109124"] = {
		["i:109624"] = 0.1, -- Broken Frostweed Stem
	},
	["i:109125"] = {
		["i:109625"] = 0.1, -- Broken Fireweed Stem
	},
	["i:109126"] = {
		["i:109626"] = 0.1, -- Gorgrond Flytrap Ichor
	},
	["i:109127"] = {
		["i:109627"] = 0.1, -- Starflower Petal
	},
	["i:109128"] = {
		["i:109628"] = 0.1, -- Nagrand Arrowbloom Petal
	},
	["i:109129"] = {
		["i:109629"] = 0.1, -- Talador Orchid Petal
	},
	["i:168583"] = {
		["i:169698"] = 0.1, -- Widowbloom Petal
	},
	["i:168586"] = {
		["i:169550"] = 0.1, -- Rising Glory Petal
	},
	["i:168589"] = {
		["i:168591"] = 0.1, -- Marrowroot Petal
	},
	["i:169701"] = {
		["i:169700"] = 0.1, -- Death Blossom Petal
	},
	["i:170554"] = {
		["i:169699"] = 0.1, -- Vigil's Torch Petal
	},

	-- Leather Scraps
	["i:110609"] = {
		["i:110610"] = 0.1, -- Raw Beast Hide Scraps
	},

	-- Misc
	["i:76061"] = {
		["i:89112"] = 0.1, -- Mote of Harmony
	},
	["i:76734"] = {
		["i:90407"] = 0.1, -- Sparkling Shard
	},
	["i:90636"] = {
		["i:90637"] = 0.1, -- Splinter of Hate
	},
}
