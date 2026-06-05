-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMData = select(2, ...).LibTSMData
local VendorTrade = LibTSMData:Init("VendorTrade")
local DATA = {}




-- ============================================================================
-- Module Functions
-- ============================================================================

function VendorTrade.Get()
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
}



-- ============================================================================
-- Burning Crusade
-- ============================================================================

DATA.BCC = {
}



-- ============================================================================
-- Panda
-- ============================================================================

DATA.Panda = {
	["i:37101"] = {
		["i:79254"] = 1, -- Ivory Ink
	},
	["i:39469"] = {
		["i:79254"] = 1, -- Moonglow Ink
	},
	["i:39774"] = {
		["i:79254"] = 1, -- Midnight Ink
	},
	["i:43116"] = {
		["i:79254"] = 1, -- Lion's Ink
	},
	["i:43118"] = {
		["i:79254"] = 1, -- Jadefire Ink
	},
	["i:43120"] = {
		["i:79254"] = 1, -- Celestial Ink
	},
	["i:43122"] = {
		["i:79254"] = 1, -- Shimmering Ink
	},
	["i:43124"] = {
		["i:79254"] = 1, -- Ethereal Ink
	},
	["i:43126"] = {
		["i:79254"] = 1, -- Ink of the Sea
	},
	["i:43127"] = {
		["i:79254"] = 0.1, -- Snowfall Ink
	},
	["i:61981"] = {
		["i:79254"] = 0.1, -- Inferno Ink
	},
}



-- ============================================================================
-- Wrath (Inscription vendor trades lower inks → Ink of the Sea)
-- ============================================================================

DATA.Wrath = {
	["i:37101"] = {
		["i:43126"] = 1, -- Ivory Ink
	},
	["i:39469"] = {
		["i:43126"] = 1, -- Moonglow Ink
	},
	["i:39774"] = {
		["i:43126"] = 1, -- Midnight Ink
	},
	["i:43116"] = {
		["i:43126"] = 1, -- Lion's Ink
	},
	["i:43118"] = {
		["i:43126"] = 1, -- Jadefire Ink
	},
	["i:43120"] = {
		["i:43126"] = 1, -- Celestial Ink
	},
	["i:43122"] = {
		["i:43126"] = 1, -- Shimmering Ink
	},
	["i:43124"] = {
		["i:43126"] = 1, -- Ethereal Ink
	},
	["i:43127"] = {
		["i:43126"] = 0.1, -- Snowfall Ink
	},
}



-- ============================================================================
-- Retail
-- ============================================================================

DATA.Retail = {
	["i:39469"] = {
		["i:173058"] = 1, -- Moonglow Ink
	},
	["i:39774"] = {
		["i:173058"] = 1, -- Midnight Ink
	},
	["i:43116"] = {
		["i:173058"] = 1, -- Lion's Ink
	},
	["i:43118"] = {
		["i:173058"] = 1, -- Jadefire Ink
	},
	["i:43120"] = {
		["i:173058"] = 1, -- Celestial Ink
	},
	["i:43122"] = {
		["i:173058"] = 1, -- Shimmering Ink
	},
	["i:43124"] = {
		["i:173058"] = 1, -- Ethereal Ink
	},
	["i:43125"] = {
		["i:173058"] = 0.1, -- Darkflame Ink
	},
	["i:43126"] = {
		["i:173058"] = 1, -- Ink of the Sea
	},
	["i:43127"] = {
		["i:173058"] = 0.1, -- Snowfall Ink
	},
	["i:61978"] = {
		["i:173058"] = 1, -- Blackfallow Ink
	},
	["i:61981"] = {
		["i:173058"] = 0.1, -- Inferno Ink
	},
	["i:79254"] = {
		["i:173058"] = 1, -- Ink of Dreams
	},
	["i:79255"] = {
		["i:173058"] = 0.1, -- Starlight Ink
	},
	["i:113111"] = {
		["i:173058"] = 1, -- Warbinder's Ink
	},
	["i:129032"] = {
		["i:173058"] = 1, -- Roseate Pigment
	},
	["i:129034"] = {
		["i:173058"] = 1, -- Sallow Pigment
	},
	["i:158187"] = {
		["i:173058"] = 1, -- Ultramarine Ink
	},
	["i:158188"] = {
		["i:173058"] = 1, -- Crimson Ink
	},
	["i:158189"] = {
		["i:173058"] = 0.1, -- Viridescent Ink
	},
	["i:168663"] = {
		["i:173058"] = 1, -- Maroon Ink
	},
}
