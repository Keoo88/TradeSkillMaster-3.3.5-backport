-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

if not TSMDEV then
	return
end



-- ============================================================================
-- Module Functions
-- ============================================================================

function TSMDEV.Dump(value)
	C_AddOns.LoadAddOn("Blizzard_DebugTools")
	DevTools_Dump(value)
end
