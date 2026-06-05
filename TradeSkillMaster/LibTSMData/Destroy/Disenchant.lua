-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMData = select(2, ...).LibTSMData
local Disenchant = LibTSMData:Init("Disenchant")
Disenchant.ITEM_CLASSES = {
	ARMOR = newproxy(),
	WEAPON = newproxy(),
	PROFESSION = newproxy(),
}
local DATA = {}




-- ============================================================================
-- Module Functions
-- ============================================================================

function Disenchant.Get()
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
	-- Dust
	["i:10940"] = { -- Strange Dust
		minLevel = 1,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 5, maxItemLevel = 15, matRate = 0.800, minAmount = 1, maxAmount = 2, amountOfMats = 1.200},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, matRate = 0.750, minAmount = 4, maxAmount = 6, amountOfMats = 3.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 5, maxItemLevel = 15, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, matRate = 0.200, minAmount = 2, maxAmount = 3, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, matRate = 0.150, minAmount = 4, maxAmount = 6, amountOfMats = 0.750},
		},
	},
	["i:11083"] = { -- Soul Dust
		minLevel = 21,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:11137"] = { -- Vision Dust
		minLevel = 31,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:11176"] = { -- Dream Dust
		minLevel = 41,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:16204"] = { -- Illusion Dust
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 99, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 99, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},

	-- Essences
	["i:10938"] = { -- Lesser Magic Essence
		minLevel = 1,
		maxLevel = 10,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 5, maxItemLevel = 15, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 5, maxItemLevel = 15, matRate = 0.800, minAmount = 1, maxAmount = 2, amountOfMats = 1.200},
		},
	},
	["i:10939"] = { -- Greater Magic Essence
		minLevel = 11,
		maxLevel = 15,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:10998"] = { -- Lesser Astral Essence
		minLevel = 16,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, matRate = 0.150, minAmount = 1, maxAmount = 2, amountOfMats = 0.220},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11082"] = { -- Greater Astral Essence
		minLevel = 21,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11134"] = { -- Lesser Mystic Essence
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11135"] = { -- Greater Mystic Essence
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11174"] = { -- Lesser Nether Essence
		minLevel = 36,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11175"] = { -- Greater Nether Essence
		minLevel = 41,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, matRate = 0.250, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:16202"] = { -- Lesser Eternal Essence
		minLevel = 46,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:16203"] = { -- Greater Eternal Essence
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 99, matRate = 0.200, minAmount = 2, maxAmount = 3, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 99, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
		},
	},

	-- Shards
	["i:10978"] = { -- Small Glimmering Shard
		minLevel = 1,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, matRate = 0.100, minAmount = 1, maxAmount = 1, amountOfMats = 0.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 20, maxItemLevel = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, matRate = 0.100, minAmount = 1, maxAmount = 1, amountOfMats = 0.100},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 20, maxItemLevel = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11084"] = { -- Large Glimmering Shard
		minLevel = 21,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 26, maxItemLevel = 30, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 26, maxItemLevel = 30, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11138"] = { -- Small Glowing Shard
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 31, maxItemLevel = 35, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 31, maxItemLevel = 35, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11139"] = { -- Large Glowing Shard
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 36, maxItemLevel = 40, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 36, maxItemLevel = 40, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11177"] = { -- Small Radiant Shard
		minLevel = 36,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 41, maxItemLevel = 45, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 40, maxItemLevel = 45, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 41, maxItemLevel = 45, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 40, maxItemLevel = 45, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:11178"] = { -- Large Radiant Shard
		minLevel = 41,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 46, maxItemLevel = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 46, maxItemLevel = 50, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 46, maxItemLevel = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 46, maxItemLevel = 50, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:14343"] = { -- Small Brilliant Shard
		minLevel = 46,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 51, maxItemLevel = 55, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 51, maxItemLevel = 55, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 51, maxItemLevel = 55, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 51, maxItemLevel = 55, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:14344"] = { -- Large Brilliant Shard
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 99, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 56, maxItemLevel = 60, matRate = 0.995, minAmount = 1, maxAmount = 1, amountOfMats = 0.995},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 61, maxItemLevel = 99, matRate = 0.990, minAmount = 1, maxAmount = 1, amountOfMats = 0.990},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 99, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 56, maxItemLevel = 60, matRate = 0.995, minAmount = 1, maxAmount = 1, amountOfMats = 0.995},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 61, maxItemLevel = 99, matRate = 0.990, minAmount = 1, maxAmount = 1, amountOfMats = 0.990},
		},
	},

	-- Crystals
	["i:20725"] = { -- Nexus Crystal
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 56, maxItemLevel = 60, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 61, maxItemLevel = 99, matRate = 0.010, minAmount = 1, maxAmount = 1, amountOfMats = 0.010},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 56, maxItemLevel = 60, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 61, maxItemLevel = 99, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 56, maxItemLevel = 60, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 61, maxItemLevel = 99, matRate = 0.010, minAmount = 1, maxAmount = 1, amountOfMats = 0.010},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 56, maxItemLevel = 60, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 61, maxItemLevel = 99, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
		},
	},
}



-- ============================================================================
-- Burning Crusade
-- ============================================================================

DATA.BCC = {
	-- Dust
	["i:10940"] = { -- Strange Dust
		minLevel = 1,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.800, minAmount = 1, maxAmount = 2, amountOfMats = 1.200},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.750, minAmount = 4, maxAmount = 6, amountOfMats = 3.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.200, minAmount = 2, maxAmount = 3, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.150, minAmount = 4, maxAmount = 6, amountOfMats = 0.750},
		},
	},
	["i:11083"] = { -- Soul Dust
		minLevel = 21,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:11137"] = { -- Vision Dust
		minLevel = 31,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:11176"] = { -- Dream Dust
		minLevel = 41,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
		},
	},
	["i:16204"] = { -- Illusion Dust
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.220, minAmount = 1, maxAmount = 2, amountOfMats = 0.330},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
		},
	},
	["i:22445"] = { -- Arcane Dust
		minLevel = 61,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.750, minAmount = 1, maxAmount = 3, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.800},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.220, minAmount = 1, maxAmount = 3, amountOfMats = 0.440},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.220, minAmount = 2, maxAmount = 3, amountOfMats = 0.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.770},
		},
	},

	-- Essences
	["i:10938"] = { -- Lesser Magic Essence
		minLevel = 1,
		maxLevel = 10,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.800, minAmount = 1, maxAmount = 2, amountOfMats = 1.200},
		},
	},
	["i:10939"] = { -- Greater Magic Essence
		minLevel = 11,
		maxLevel = 15,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:10998"] = { -- Lesser Astral Essence
		minLevel = 16,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.150, minAmount = 1, maxAmount = 2, amountOfMats = 0.220},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11082"] = { -- Greater Astral Essence
		minLevel = 21,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11134"] = { -- Lesser Mystic Essence
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11135"] = { -- Greater Mystic Essence
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11174"] = { -- Lesser Nether Essence
		minLevel = 36,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11175"] = { -- Greater Nether Essence
		minLevel = 41,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:16202"] = { -- Lesser Eternal Essence
		minLevel = 46,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:16203"] = { -- Greater Eternal Essence
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.200, minAmount = 2, maxAmount = 3, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
		},
	},
	["i:22447"] = { -- Lesser Planar Essence
		minLevel = 61,
		maxLevel = 65,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.220, minAmount = 1, maxAmount = 3, amountOfMats = 0.340},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.220, minAmount = 2, maxAmount = 3, amountOfMats = 0.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.750, minAmount = 1, maxAmount = 3, amountOfMats = 1.175},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
		},
	},
	["i:22446"] = { -- Greater Planar Essence
		minLevel = 66,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.220, minAmount = 1, maxAmount = 2, amountOfMats = 0.330},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},

	-- Shards
	["i:10978"] = { -- Small Glimmering Shard
		minLevel = 1,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.100, minAmount = 1, maxAmount = 1, amountOfMats = 0.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.100, minAmount = 1, maxAmount = 1, amountOfMats = 0.100},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11084"] = { -- Large Glimmering Shard
		minLevel = 21,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11138"] = { -- Small Glowing Shard
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11139"] = { -- Large Glowing Shard
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11177"] = { -- Small Radiant Shard
		minLevel = 36,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:11178"] = { -- Large Radiant Shard
		minLevel = 41,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:14343"] = { -- Small Brilliant Shard
		minLevel = 46,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:14344"] = { -- Large Brilliant Shard
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:22448"] = { -- Small Prismatic Shard
		minLevel = 61,
		maxLevel = 65,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},




		},
	},
	["i:22449"] = { -- Large Prismatic Shard
		minLevel = 66,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},

	-- Crystals
	["i:20725"] = { -- Nexus Crystal
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 61, maxItemLevel = 99, requiredSkill = 225, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},


			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 61, maxItemLevel = 89, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 90, maxItemLevel = 94, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 61, maxItemLevel = 99, requiredSkill = 225, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},


			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 61, maxItemLevel = 89, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 90, maxItemLevel = 94, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
		},
	},
	["i:22450"] = { -- Void Crystal
		minLevel = 61,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 95, maxItemLevel = 104, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 105, maxItemLevel = 999, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 100, maxItemLevel = 999, requiredSkill = 275, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 95, maxItemLevel = 104, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 105, maxItemLevel = 999, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
		},
	},
}


-- ============================================================================
-- Panda
-- ============================================================================

DATA.Panda = {
	-- Dust
	["i:10940"] = { -- Strange Dust
		minLevel = 1,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.800, minAmount = 1, maxAmount = 2, amountOfMats = 1.200},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.750, minAmount = 4, maxAmount = 6, amountOfMats = 3.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.200, minAmount = 2, maxAmount = 3, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.150, minAmount = 4, maxAmount = 6, amountOfMats = 0.750},
		},
	},
	["i:11083"] = { -- Soul Dust
		minLevel = 21,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:11137"] = { -- Vision Dust
		minLevel = 31,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.200, minAmount = 2, maxAmount = 5, amountOfMats = 0.700},
		},
	},
	["i:11176"] = { -- Dream Dust
		minLevel = 41,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
		},
	},
	["i:16204"] = { -- Illusion Dust
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.220, minAmount = 1, maxAmount = 2, amountOfMats = 0.330},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
		},
	},
	["i:22445"] = { -- Arcane Dust
		minLevel = 61,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.750, minAmount = 1, maxAmount = 3, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.800},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 2.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.220, minAmount = 1, maxAmount = 3, amountOfMats = 0.440},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.220, minAmount = 2, maxAmount = 3, amountOfMats = 0.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.770},
		},
	},
	["i:34054"] = { -- Infinite Dust
		minLevel = 71,
		maxLevel = 80,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 121, maxItemLevel = 153, requiredSkill = 325, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.800},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 154, maxItemLevel = 231, requiredSkill = 350, matRate = 0.750, minAmount = 4, maxAmount = 7, amountOfMats = 4.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 121, maxItemLevel = 153, requiredSkill = 325, matRate = 0.220, minAmount = 2, maxAmount = 3, amountOfMats = 0.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 154, maxItemLevel = 231, requiredSkill = 350, matRate = 0.220, minAmount = 4, maxAmount = 7, amountOfMats = 1.210},
		},
	},
	["i:52555"] = { -- Hypnotic Dust
		minLevel = 81,
		maxLevel = 85,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 232, maxItemLevel = 277, requiredSkill = 425, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.125},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 278, maxItemLevel = 294, requiredSkill = 425, matRate = 0.750, minAmount = 1, maxAmount = 3, amountOfMats = 1.350},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 295, maxItemLevel = 305, requiredSkill = 425, matRate = 0.750, minAmount = 1, maxAmount = 4, amountOfMats = 1.600},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 306, maxItemLevel = 312, requiredSkill = 425, matRate = 0.750, minAmount = 1, maxAmount = 5, amountOfMats = 2.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 313, maxItemLevel = 363, requiredSkill = 425, matRate = 0.750, minAmount = 1, maxAmount = 6, amountOfMats = 2.400},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 232, maxItemLevel = 277, requiredSkill = 425, matRate = 0.250, minAmount = 1, maxAmount = 2, amountOfMats = 0.375},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 278, maxItemLevel = 294, requiredSkill = 425, matRate = 0.250, minAmount = 1, maxAmount = 3, amountOfMats = 0.450},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 295, maxItemLevel = 305, requiredSkill = 425, matRate = 0.250, minAmount = 1, maxAmount = 4, amountOfMats = 0.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 306, maxItemLevel = 312, requiredSkill = 425, matRate = 0.250, minAmount = 1, maxAmount = 5, amountOfMats = 0.770},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 313, maxItemLevel = 363, requiredSkill = 425, matRate = 0.250, minAmount = 1, maxAmount = 6, amountOfMats = 0.775},

		},
	},
	["i:74249"] = { -- Spirit Dust
		minLevel = 86,
		maxLevel = 90,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 364, maxItemLevel = 390, requiredSkill = 475, matRate = 0.850, minAmount = 1, maxAmount = 9, amountOfMats = 2.285},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 391, maxItemLevel = 416, requiredSkill = 475, matRate = 0.850, minAmount = 1, maxAmount = 9, amountOfMats = 2.710},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 417, maxItemLevel = 999, requiredSkill = 475, matRate = 0.850, minAmount = 2, maxAmount = 10, amountOfMats = 3.135},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 364, maxItemLevel = 390, requiredSkill = 475, matRate = 0.850, minAmount = 1, maxAmount = 8, amountOfMats = 2.245},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 391, maxItemLevel = 416, requiredSkill = 475, matRate = 0.850, minAmount = 1, maxAmount = 8, amountOfMats = 2.700},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 417, maxItemLevel = 999, requiredSkill = 475, matRate = 0.850, minAmount = 3, maxAmount = 10, amountOfMats = 3.560},
		},
	},

	-- Essences
	["i:10938"] = { -- Lesser Magic Essence
		minLevel = 1,
		maxLevel = 10,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 5, maxItemLevel = 15, requiredSkill = 1, matRate = 0.800, minAmount = 1, maxAmount = 2, amountOfMats = 1.200},
		},
	},
	["i:10939"] = { -- Greater Magic Essence
		minLevel = 11,
		maxLevel = 15,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:10998"] = { -- Lesser Astral Essence
		minLevel = 16,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.150, minAmount = 1, maxAmount = 2, amountOfMats = 0.220},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11082"] = { -- Greater Astral Essence
		minLevel = 21,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11134"] = { -- Lesser Mystic Essence
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11135"] = { -- Greater Mystic Essence
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11174"] = { -- Lesser Nether Essence
		minLevel = 36,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:11175"] = { -- Greater Nether Essence
		minLevel = 41,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:16202"] = { -- Lesser Eternal Essence
		minLevel = 46,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:16203"] = { -- Greater Eternal Essence
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.200, minAmount = 1, maxAmount = 2, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.200, minAmount = 2, maxAmount = 3, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
		},
	},
	["i:22447"] = { -- Lesser Planar Essence
		minLevel = 61,
		maxLevel = 65,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.220, minAmount = 1, maxAmount = 3, amountOfMats = 0.340},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.220, minAmount = 2, maxAmount = 3, amountOfMats = 0.550},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 66, maxItemLevel = 79, requiredSkill = 225, matRate = 0.750, minAmount = 1, maxAmount = 3, amountOfMats = 1.175},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 80, maxItemLevel = 99, requiredSkill = 225, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.850},
		},
	},
	["i:22446"] = { -- Greater Planar Essence
		minLevel = 66,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.220, minAmount = 1, maxAmount = 2, amountOfMats = 0.330},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:34056"] = { -- Lesser Cosmic Essence
		minLevel = 71,
		maxLevel = 75,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 121, maxItemLevel = 153, requiredSkill = 325, matRate = 0.220, minAmount = 1, maxAmount = 2, amountOfMats = 0.330},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 121, maxItemLevel = 153, requiredSkill = 325, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:34055"] = { -- Greater Cosmic Essence
		minLevel = 76,
		maxLevel = 80,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 154, maxItemLevel = 231, requiredSkill = 275, matRate = 0.220, minAmount = 1, maxAmount = 2, amountOfMats = 0.330},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 154, maxItemLevel = 231, requiredSkill = 275, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.100},
		},
	},
	["i:52718"] = { -- Lesser Celestial Essence
		minLevel = 81,
		maxLevel = 85,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 232, maxItemLevel = 277, requiredSkill = 425, matRate = 0.400, minAmount = 1, maxAmount = 3, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 278, maxItemLevel = 294, requiredSkill = 425, matRate = 0.300, minAmount = 1, maxAmount = 3, amountOfMats = 0.600},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 295, maxItemLevel = 300, requiredSkill = 425, matRate = 0.250, minAmount = 2, maxAmount = 4, amountOfMats = 0.700},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 301, maxItemLevel = 305, requiredSkill = 425, matRate = 0.300, minAmount = 1, maxAmount = 4, amountOfMats = 0.650},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 306, maxItemLevel = 315, requiredSkill = 425, matRate = 0.100, minAmount = 1, maxAmount = 3, amountOfMats = 0.190},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 316, maxItemLevel = 363, requiredSkill = 425, matRate = 0.050, minAmount = 1, maxAmount = 3, amountOfMats = 0.090},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 232, maxItemLevel = 277, requiredSkill = 425, matRate = 0.600, minAmount = 1, maxAmount = 2, amountOfMats = 0.900},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 278, maxItemLevel = 294, requiredSkill = 425, matRate = 0.700, minAmount = 1, maxAmount = 3, amountOfMats = 1.350},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 295, maxItemLevel = 300, requiredSkill = 425, matRate = 0.750, minAmount = 2, maxAmount = 4, amountOfMats = 2.250},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 301, maxItemLevel = 305, requiredSkill = 425, matRate = 0.700, minAmount = 2, maxAmount = 4, amountOfMats = 2.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 306, maxItemLevel = 315, requiredSkill = 425, matRate = 0.030, minAmount = 1, maxAmount = 3, amountOfMats = 0.060},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 316, maxItemLevel = 363, requiredSkill = 425, matRate = 0.020, minAmount = 1, maxAmount = 3, amountOfMats = 0.038},
		},
	},
	["i:52719"] = { -- Greater Celestial Essence
		minLevel = 81,
		maxLevel = 85,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 306, maxItemLevel = 315, requiredSkill = 425, matRate = 0.250, minAmount = 1, maxAmount = 2, amountOfMats = 0.375},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 316, maxItemLevel = 363, requiredSkill = 425, matRate = 0.250, minAmount = 2, maxAmount = 3, amountOfMats = 0.625},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 306, maxItemLevel = 315, requiredSkill = 425, matRate = 0.750, minAmount = 1, maxAmount = 2, amountOfMats = 1.125},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 316, maxItemLevel = 363, requiredSkill = 425, matRate = 0.750, minAmount = 2, maxAmount = 3, amountOfMats = 1.875},
		},
	},
	["i:74250"] = { -- Mysterious Essence
		minLevel = 86,
		maxLevel = 90,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 364, maxItemLevel = 390, requiredSkill = 475, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.178},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 391, maxItemLevel = 416, requiredSkill = 475, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.244},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 417, maxItemLevel = 999, requiredSkill = 475, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.244},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 364, maxItemLevel = 390, requiredSkill = 475, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.178},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 391, maxItemLevel = 416, requiredSkill = 475, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.244},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 417, maxItemLevel = 999, requiredSkill = 475, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.333},
		},
	},

	-- Shards
	["i:10978"] = { -- Small Glimmering Shard
		minLevel = 1,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.100, minAmount = 1, maxAmount = 1, amountOfMats = 0.100},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 20, requiredSkill = 1, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 21, maxItemLevel = 25, requiredSkill = 25, matRate = 0.100, minAmount = 1, maxAmount = 1, amountOfMats = 0.100},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 1, maxItemLevel = 25, requiredSkill = 25, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11084"] = { -- Large Glimmering Shard
		minLevel = 21,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 26, maxItemLevel = 30, requiredSkill = 50, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11138"] = { -- Small Glowing Shard
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 31, maxItemLevel = 35, requiredSkill = 75, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11139"] = { -- Large Glowing Shard
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 36, maxItemLevel = 40, requiredSkill = 100, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:11177"] = { -- Small Radiant Shard
		minLevel = 36,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 41, maxItemLevel = 45, requiredSkill = 125, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:11178"] = { -- Large Radiant Shard
		minLevel = 41,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 46, maxItemLevel = 50, requiredSkill = 150, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:14343"] = { -- Small Brilliant Shard
		minLevel = 46,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 51, maxItemLevel = 55, requiredSkill = 175, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 3.000},
		},
	},
	["i:14344"] = { -- Large Brilliant Shard
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 61, maxItemLevel = 65, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:22448"] = { -- Small Prismatic Shard
		minLevel = 61,
		maxLevel = 65,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 66, maxItemLevel = 99, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:22449"] = { -- Large Prismatic Shard
		minLevel = 66,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:34053"] = { -- Small Dream Shard
		minLevel = 71,
		maxLevel = 75,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 121, maxItemLevel = 153, requiredSkill = 325, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 121, maxItemLevel = 166, requiredSkill = 325, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 121, maxItemLevel = 153, requiredSkill = 325, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 121, maxItemLevel = 166, requiredSkill = 325, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:34052"] = { -- Dream Shard
		minLevel = 76,
		maxLevel = 80,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 154, maxItemLevel = 231, requiredSkill = 350, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 167, maxItemLevel = 271, requiredSkill = 325, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 154, maxItemLevel = 231, requiredSkill = 350, matRate = 0.030, minAmount = 1, maxAmount = 1, amountOfMats = 0.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 167, maxItemLevel = 271, requiredSkill = 325, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:52720"] = { -- Small Heavenly Shard
		minLevel = 81,
		maxLevel = 85,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 272, maxItemLevel = 316, requiredSkill = 450, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 272, maxItemLevel = 316, requiredSkill = 450, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.030},
		},
	},
	["i:52721"] = { -- Heavenly Shard
		minLevel = 81,
		maxLevel = 85,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 317, maxItemLevel = 377, requiredSkill = 450, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 317, maxItemLevel = 377, requiredSkill = 450, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:74252"] = { -- Small Ethereal Shard
		minLevel = 86,
		maxLevel = 90,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 378, maxItemLevel = 424, requiredSkill = 525, matRate = 0.950, minAmount = 1, maxAmount = 2, amountOfMats = 0.950},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 425, maxItemLevel = 999, requiredSkill = 550, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 378, maxItemLevel = 424, requiredSkill = 525, matRate = 0.950, minAmount = 1, maxAmount = 2, amountOfMats = 0.950},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 425, maxItemLevel = 999, requiredSkill = 550, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
		},
	},
	["i:74247"] = { -- Ethereal Shard
		minLevel = 86,
		maxLevel = 90,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 378, maxItemLevel = 424, requiredSkill = 525, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 425, maxItemLevel = 999, requiredSkill = 550, matRate = 0.950, minAmount = 1, maxAmount = 1, amountOfMats = 0.950},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 378, maxItemLevel = 424, requiredSkill = 525, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 425, maxItemLevel = 999, requiredSkill = 550, matRate = 0.950, minAmount = 1, maxAmount = 1, amountOfMats = 0.950},
		},
	},

	-- Crystals
	["i:20725"] = { -- Nexus Crystal
		minLevel = 51,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 61, maxItemLevel = 99, requiredSkill = 225, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 61, maxItemLevel = 89, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 90, maxItemLevel = 94, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 61, maxItemLevel = 99, requiredSkill = 225, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 56, maxItemLevel = 60, requiredSkill = 200, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 61, maxItemLevel = 89, requiredSkill = 225, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 90, maxItemLevel = 94, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
		},
	},
	["i:22450"] = { -- Void Crystal
		minLevel = 61,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 95, maxItemLevel = 104, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 105, maxItemLevel = 199, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 100, maxItemLevel = 120, requiredSkill = 275, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 95, maxItemLevel = 104, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 105, maxItemLevel = 199, requiredSkill = 300, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.666},
		},
	},
	["i:34057"] = { -- Abyss Crystal
		minLevel = 71,
		maxLevel = 80,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 121, maxItemLevel = 271, requiredSkill = 325, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 200, maxItemLevel = 299, requiredSkill = 375, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 121, maxItemLevel = 271, requiredSkill = 325, matRate = 0.005, minAmount = 1, maxAmount = 1, amountOfMats = 0.005},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 200, maxItemLevel = 299, requiredSkill = 375, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:52722"] = { -- Maelstrom Crystal
		minLevel = 81,
		maxLevel = 85,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 300, maxItemLevel = 419, requiredSkill = 475, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 300, maxItemLevel = 419, requiredSkill = 475, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:74248"] = { -- Sha Crystal
		minLevel = 86,
		maxLevel = 90,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 420, maxItemLevel = 999, requiredSkill = 575, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 420, maxItemLevel = 999, requiredSkill = 575, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
}



-- ============================================================================
-- Wrath (Panda DE table minus Cataclysm/MoP materials)
-- ============================================================================

DATA.Wrath = {}
do
	-- Materials introduced after WotLK — must not be reachable on 3.3.5.
	local POST_WRATH_MATERIALS = {
		["i:52555"] = true, -- Hypnotic Dust (Cata)
		["i:74249"] = true, -- Spirit Dust (MoP)
		["i:52718"] = true, -- Lesser Celestial Essence (Cata)
		["i:52719"] = true, -- Greater Celestial Essence (Cata)
		["i:74250"] = true, -- Mysterious Essence (MoP)
		["i:52720"] = true, -- Small Heavenly Shard (Cata)
		["i:52721"] = true, -- Heavenly Shard (Cata)
		["i:74252"] = true, -- Small Ethereal Shard (MoP)
		["i:74247"] = true, -- Ethereal Shard (MoP)
		["i:52722"] = true, -- Maelstrom Crystal (Cata)
		["i:74248"] = true, -- Sha Crystal (MoP)
	}
	for itemString, info in pairs(DATA.Panda) do
		if not POST_WRATH_MATERIALS[itemString] then
			DATA.Wrath[itemString] = info
		end
	end
end



-- ============================================================================
-- Retail
-- ============================================================================

DATA.Retail = {
	-- Dust
	["i:10940"] = { -- Strange Dust
		expansion = 0,
		minLevel = 1,
		maxLevel = 12,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 7, matRate = 0.800, minAmount = 1, maxAmount = 6, amountOfMats = 1.222},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 8, maxItemLevel = 11, matRate = 0.800, minAmount = 2, maxAmount = 8, amountOfMats = 2.025},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 12, maxItemLevel = 15, matRate = 1.000, minAmount = 4, maxAmount = 10, amountOfMats = 5.008},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 15, matRate = 0.030, minAmount = 3, maxAmount = 6, amountOfMats = 0.127},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 7, matRate = 0.200, minAmount = 1, maxAmount = 4, amountOfMats = 0.302},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 8, maxItemLevel = 11, matRate = 0.200, minAmount = 2, maxAmount = 6, amountOfMats = 0.507},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 12, maxItemLevel = 15, matRate = 0.150, minAmount = 4, maxAmount = 8, amountOfMats = 0.753},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 15, matRate = 0.030, minAmount = 3, maxAmount = 6, amountOfMats = 0.127},
		},
	},
	["i:16204"] = { -- Light Illusion Dust
		expansion = 0,
		minLevel = 11,
		maxLevel = 21,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 24, matRate = 0.750, minAmount = 1, maxAmount = 6, amountOfMats = 1.155},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 16, maxItemLevel = 24, matRate = 0.030, minAmount = 3, maxAmount = 6, amountOfMats = 0.127},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 24, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.344},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 16, maxItemLevel = 24, matRate = 0.030, minAmount = 3, maxAmount = 6, amountOfMats = 0.127},
		},
	},
	["i:156930"] = { -- Rich Illusion Dust
		expansion = 0,
		minLevel = 20,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 25, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 6, amountOfMats = 1.155},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 25, maxItemLevel = 999, matRate = 0.030, minAmount = 3, maxAmount = 6, amountOfMats = 0.127},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 20, maxItemLevel = 999, matRate = 0.220, minAmount = 3, maxAmount = 6, amountOfMats = 0.990},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 25, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 6, amountOfMats = 0.344},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 25, maxItemLevel = 999, matRate = 0.030, minAmount = 3, maxAmount = 6, amountOfMats = 0.127},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 20, maxItemLevel = 999, matRate = 0.220, minAmount = 3, maxAmount = 6, amountOfMats = 0.990},
		},
	},
	["i:22445"] = { -- Arcane Dust
		expansion = 1,
		minLevel = 24,
		maxLevel = 27,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 30, matRate = 0.750, minAmount = 2, maxAmount = 7, amountOfMats = 1.933},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 999, matRate = 0.750, minAmount = 2, maxAmount = 9, amountOfMats = 2.655},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 30, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 999, matRate = 0.220, minAmount = 2, maxAmount = 7, amountOfMats = 0.787},
		},
	},
	["i:34054"] = { -- Infinite Dust
		expansion = 2,
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 33, matRate = 0.750, minAmount = 2, maxAmount = 7, amountOfMats = 1.933},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 34, maxItemLevel = 999, matRate = 0.750, minAmount = 4, maxAmount = 11, amountOfMats = 4.155},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 33, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.562},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 34, maxItemLevel = 999, matRate = 0.220, minAmount = 4, maxAmount = 9, amountOfMats = 1.200},
		},
	},
	["i:52555"] = { -- Hypnotic Dust
		expansion = 3,
		minLevel = 29,
		maxLevel = 32,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 35, matRate = 0.700, minAmount = 1, maxAmount = 7, amountOfMats = 1.428},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 10, amountOfMats = 2.628},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 35, matRate = 0.300, minAmount = 1, maxAmount = 6, amountOfMats = 0.618},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 999, matRate = 0.250, minAmount = 1, maxAmount = 10, amountOfMats = 0.864},
		},
	},
	["i:74249"] = { -- Spirit Dust
		expansion = 4,
		minLevel = 31,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 37, matRate = 0.850, minAmount = 1, maxAmount = 9, amountOfMats = 2.285},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 38, maxItemLevel = 999, matRate = 0.850, minAmount = 2, maxAmount = 10, amountOfMats = 3.135},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 37, matRate = 0.850, minAmount = 1, maxAmount = 8, amountOfMats = 2.245},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 38, maxItemLevel = 999, matRate = 0.850, minAmount = 3, maxAmount = 10, amountOfMats = 3.560},
		},
	},
	["i:109693"] = { -- Draenic Dust
		expansion = 5,
		minLevel = 35,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 4, amountOfMats = 2.600},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.750, minAmount = 5, maxAmount = 12, amountOfMats = 5.810},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 4, amountOfMats = 2.600},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.800, minAmount = 5, maxAmount = 12, amountOfMats = 6.220},
		},
	},
	["i:124440"] = { -- Arkhana
		expansion = 6,
		minLevel = 40,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 4, maxAmount = 6, amountOfMats = 4.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 4, maxAmount = 6, amountOfMats = 4.750},
		},
	},
	["i:152875"] = { -- Gloom Dust
		expansion = 7,
		minLevel = 45,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 52, matRate = 1.000, minAmount = 1, maxAmount = 6, amountOfMats = 3.600},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 53, maxItemLevel = 999, matRate = 1.000, minAmount = 4, maxAmount = 9, amountOfMats = 6.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.950, minAmount = 1, maxAmount = 2, amountOfMats = 1.425},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.200, minAmount = 4, maxAmount = 6, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 52, matRate = 1.000, minAmount = 1, maxAmount = 6, amountOfMats = 3.600},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 53, maxItemLevel = 999, matRate = 1.000, minAmount = 4, maxAmount = 9, amountOfMats = 6.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.950, minAmount = 1, maxAmount = 2, amountOfMats = 1.425},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.200, minAmount = 4, maxAmount = 6, amountOfMats = 1.000},
		},
	},
	["i:172230"] = { -- Soul Dust
		expansion = 8,
		minLevel = 50,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 2.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.400},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 2, maxAmount = 4, amountOfMats = 2.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.400},
		},
	},
	["i:194123"] = { -- Chromatic Dust
		expansion = 9,
		minLevel = 60,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 2, maxAmount = 3, amountOfMats = 1.2500},
			{class = Disenchant.ITEM_CLASSES.PROFESSION, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.PROFESSION, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 2, maxAmount = 3, amountOfMats = 1.2500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.350, minAmount = 4, maxAmount = 5, amountOfMats = 1.575},
		},
	},

	-- Essences
	["i:10938"] = { -- Lesser Magic Essence
		expansion = 0,
		minLevel = 1,
		maxLevel = 7,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 7, matRate = 0.200, minAmount = 1, maxAmount = 6, amountOfMats = 0.303},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 7, matRate = 0.800, minAmount = 1, maxAmount = 5, amountOfMats = 1.218},
		},
	},
	["i:10939"] = { -- Greater Magic Essence
		expansion = 0,
		minLevel = 8,
		maxLevel = 11,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 8, maxItemLevel = 15, matRate = 0.200, minAmount = 1, maxAmount = 5, amountOfMats = 0.307},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 15, matRate = 1.000, minAmount = 2, maxAmount = 2, amountOfMats = 2.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 8, maxItemLevel = 15, matRate = 0.800, minAmount = 1, maxAmount = 4, amountOfMats = 1.217},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 15, matRate = 1.000, minAmount = 2, maxAmount = 2, amountOfMats = 2.000},
		},
	},
	["i:16202"] = { -- Lesser Eternal Essence
		expansion = 0,
		minLevel = 12,
		maxLevel = 20,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 24, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.346},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 16, maxItemLevel = 24, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 24, matRate = 0.750, minAmount = 1, maxAmount = 4, amountOfMats = 1.302},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 16, maxItemLevel = 24, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.750},
		},
	},
	["i:16203"] = { -- Greater Eternal Essence
		expansion = 0,
		minLevel = 20,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 25, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.346},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 25, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.650},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.250, minAmount = 2, maxAmount = 5, amountOfMats = 0.860},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 25, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 4, amountOfMats = 1.182},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 25, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.650},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.250, minAmount = 2, maxAmount = 5, amountOfMats = 0.860},
		},
	},
	["i:22447"] = { -- Lesser Planar Essence
		expansion = 1,
		minLevel = 24,
		maxLevel = 27,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 30, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.562},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 30, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 1.932},
		},
	},
	["i:22446"] = { -- Greater Planar Essence
		expansion = 1,
		minLevel = 24,
		maxLevel = 27,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.346},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 5, amountOfMats = 1.170},
		},
	},
	["i:34056"] = { -- Lesser Cosmic Essence
		expansion = 2,
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 33, matRate = 0.220, minAmount = 2, maxAmount = 5, amountOfMats = 0.562},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 33, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 1.932},
		},
	},
	["i:34055"] = { -- Greater Cosmic Essence
		expansion = 2,
		minLevel = 26,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 34, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 5, amountOfMats = 0.346},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 34, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 5, amountOfMats = 1.170},
		},
	},
	["i:52718"] = { -- Lesser Celestial Essence
		expansion = 3,
		minLevel = 29,
		maxLevel = 32,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 35, matRate = 0.300, minAmount = 1, maxAmount = 5, amountOfMats = 0.405},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 35, matRate = 0.700, minAmount = 1, maxAmount = 4, amountOfMats = 1.420},
		},
	},
	["i:52719"] = { -- Greater Celestial Essence
		expansion = 3,
		minLevel = 29,
		maxLevel = 32,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 36, maxItemLevel = 999, matRate = 0.250, minAmount = 2, maxAmount = 5, amountOfMats = 0.642},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 36, maxItemLevel = 999, matRate = 0.750, minAmount = 2, maxAmount = 5, amountOfMats = 1.892},
		},
	},
	["i:74250"] = { -- Mysterious Essence
		expansion = 4,
		minLevel = 31,
		maxLevel = 34,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 37, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.178},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 38, maxItemLevel = 999, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.244},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 37, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.178},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 38, maxItemLevel = 999, matRate = 0.150, minAmount = 1, maxAmount = 6, amountOfMats = 0.333},
		},
	},

	-- Shards
	["i:14343"] = { -- Small Brilliant Shard
		expansion = 0,
		minLevel = 12,
		maxLevel = 21,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 16, maxItemLevel = 24, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 16, maxItemLevel = 24, matRate = 1.000, minAmount = 1, maxAmount = 3, amountOfMats = 2.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 16, maxItemLevel = 24, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 16, maxItemLevel = 24, matRate = 1.000, minAmount = 1, maxAmount = 3, amountOfMats = 2.000},
		},
	},
	["i:14344"] = { -- Large Brilliant Shard
		expansion = 0,
		minLevel = 20,
		maxLevel = 25,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 25, maxItemLevel = 999, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 25, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 3, amountOfMats = 2.000},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 20, maxItemLevel = 999, matRate = 1.000, minAmount = 2, maxAmount = 5, amountOfMats = 3.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 25, maxItemLevel = 999, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 25, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 3, amountOfMats = 2.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 20, maxItemLevel = 999, matRate = 1.000, minAmount = 2, maxAmount = 5, amountOfMats = 3.500},
		},
	},
	["i:22448"] = { -- Small Prismatic Shard
		expansion = 1,
		minLevel = 23,
		maxLevel = 27,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 30, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 30, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 30, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 30, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.030},
		},
	},
	["i:22449"] = { -- Large Prismatic Shard
		expansion = 1,
		minLevel = 23,
		maxLevel = 27,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 31, maxItemLevel = 999, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 31, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.03},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 31, maxItemLevel = 999, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 31, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.03},
		},
	},
	["i:34053"] = { -- Small Dream Shard
		expansion = 2,
		minLevel = 27,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 2, maxItemLevel = 33, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 34, matRate = 0.980, minAmount = 1, maxAmount = 2, amountOfMats = 1.010},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 2, maxItemLevel = 33, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 34, matRate = 0.850, minAmount = 1, maxAmount = 2, amountOfMats = 0.880},
		},
	},
	["i:34052"] = { -- Dream Shard
		expansion = 2,
		minLevel = 27,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 2, minItemLevel = 34, maxItemLevel = 999, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 34, matRate = 0.020, minAmount = 1, maxAmount = 1, amountOfMats = 0.020},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 35, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 2, minItemLevel = 34, maxItemLevel = 34, matRate = 0.030, minAmount = 1, maxAmount = 2, amountOfMats = 0.033},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.150, minAmount = 1, maxAmount = 1, amountOfMats = 0.150},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 35, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.050},
		},
	},
	["i:52720"] = { -- Small Heavenly Shard
		expansion = 3,
		minLevel = 29,
		maxLevel = 32,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 36, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.030},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 36, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.030},
		},
	},
	["i:52721"] = { -- Heavenly Shard
		expansion = 3,
		minLevel = 29,
		maxLevel = 32,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 37, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 37, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:74252"] = { -- Small Ethereal Shard
		expansion = 4,
		minLevel = 32,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 38, matRate = 0.950, minAmount = 1, maxAmount = 2, amountOfMats = 0.950},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 39, maxItemLevel = 999, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 38, matRate = 0.950, minAmount = 1, maxAmount = 2, amountOfMats = 0.950},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 39, maxItemLevel = 999, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
		},
	},
	["i:74247"] = { -- Ethereal Shard
		expansion = 4,
		minLevel = 32,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 38, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 39, maxItemLevel = 999, matRate = 0.950, minAmount = 1, maxAmount = 1, amountOfMats = 0.950},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 38, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 39, maxItemLevel = 999, matRate = 0.950, minAmount = 1, maxAmount = 1, amountOfMats = 0.950},
		},
	},
	["i:115502"] = { -- Small Luminous Shard
		expansion = 5,
		minLevel = 35,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.100, minAmount = 3, maxAmount = 6, amountOfMats = 0.430},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.100, minAmount = 3, maxAmount = 6, amountOfMats = 0.430},
		},
	},
	["i:111245"] = { -- Luminous Shard
		expansion = 5,
		minLevel = 35,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 1, amountOfMats = 0.220},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.220, minAmount = 1, maxAmount = 1, amountOfMats = 0.220},
		},
	},
	["i:124441"] = { -- Leylight Shard
		expansion = 6,
		minLevel = 40,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:152876"] = { -- Umbra Shard
		expansion = 7,
		minLevel = 45,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.400, minAmount = 1, maxAmount = 2, amountOfMats = 0.600},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.400, minAmount = 1, maxAmount = 2, amountOfMats = 0.600},
		},
	},
	["i:172231"] = { -- Sacred Shard
		expansion = 8,
		minLevel = 50,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.350, minAmount = 1, maxAmount = 1, amountOfMats = 0.350},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 2, amountOfMats = 1.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.350, minAmount = 1, maxAmount = 1, amountOfMats = 0.350},
		},
	},
	["i:194124"] = { -- Vibrant Shard
		expansion = 9,
		minLevel = 60,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 1, maxAmount = 1, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 1, maxAmount = 2, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.PROFESSION, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 1, maxAmount = 1, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.PROFESSION, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 1, maxAmount = 2, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.650, minAmount = 1, maxAmount = 2, amountOfMats = 0.800},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.600, minAmount = 2, maxAmount = 3, amountOfMats = 1.350},
		},
	},

	-- Crystals
	["i:22450"] = { -- Void Crystal
		expansion = 1,
		minLevel = 26,
		maxLevel = 26,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 3, amountOfMats = 1.530},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 3, amountOfMats = 1.530},
		},
	},
	["i:34057"] = { -- Abyss Crystal
		expansion = 2,
		minLevel = 30,
		maxLevel = 30,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:52722"] = { -- Maelstrom Crystal
		expansion = 3,
		minLevel = 32,
		maxLevel = 32,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:74248"] = { -- Sha Crystal
		expansion = 4,
		minLevel = 32,
		maxLevel = 35,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:115504"] = { -- Fractured Temporal Crystal
		expansion = 5,
		minLevel = 35,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.100, minAmount = 3, maxAmount = 3, amountOfMats = 0.300},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.250, minAmount = 3, maxAmount = 3, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.050, minAmount = 3, maxAmount = 3, amountOfMats = 0.150},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.250, minAmount = 3, maxAmount = 3, amountOfMats = 0.750},
		},
	},
	["i:113588"] = { -- Temporal Crystal
		expansion = 5,
		minLevel = 35,
		maxLevel = 40,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 1, amountOfMats = 0.750},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.750, minAmount = 1, maxAmount = 1, amountOfMats = 0.750},
		},
	},
	["i:124442"] = { -- Chaos Crystal
		expansion = 6,
		minLevel = 40,
		maxLevel = 45,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:152877"] = { -- Veiled Crystal
		expansion = 7,
		minLevel = 45,
		maxLevel = 50,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 3, minItemLevel = 2, maxItemLevel = 999, matRate = 0.050, minAmount = 1, maxAmount = 1, amountOfMats = 0.050},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:172232"] = { -- Eternal Crystal
		expansion = 8,
		minLevel = 50,
		maxLevel = 60,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 1.000, minAmount = 1, maxAmount = 1, amountOfMats = 1.000},
		},
	},
	["i:200113"] = { -- Resonant Crystal
		expansion = 9,
		minLevel = 60,
		maxLevel = 70,
		sourceInfo = {
			{class = Disenchant.ITEM_CLASSES.ARMOR, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 1, maxAmount = 1, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.PROFESSION, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.500, minAmount = 1, maxAmount = 1, amountOfMats = 0.500},
			{class = Disenchant.ITEM_CLASSES.WEAPON, quality = 4, minItemLevel = 2, maxItemLevel = 999, matRate = 0.400, minAmount = 1, maxAmount = 2, amountOfMats = 0.450},
		},
	},
}
