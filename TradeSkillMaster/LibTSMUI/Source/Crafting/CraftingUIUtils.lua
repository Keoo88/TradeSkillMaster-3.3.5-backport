-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local CraftingUIUtils = LibTSMUI:Init("Crafting.CraftingUIUtils")
local EnumType = LibTSMUI:From("LibTSMUtil"):Include("BaseType.EnumType")
CraftingUIUtils.CRAFTING_SOURCE = EnumType.New("CRAFTING_SOURCE", {
	VELLUM = EnumType.NewValue(),
	CRAFT = EnumType.NewValue(),
	QUEUE_CRAFT = EnumType.NewValue(),
	QUEUE_NEXT = EnumType.NewValue(),
})
