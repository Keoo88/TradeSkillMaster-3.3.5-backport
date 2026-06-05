-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local SlotId = LibTSMWoW:Init("Type.SlotId")
local SLOT_ID_MULTIPLIER = 1000



-- ============================================================================
-- Module Functions
-- ============================================================================

---Combines a bag and slot into a slotId.
---@param bag number The bag
---@param slot number The slot
---@return number
function SlotId.Join(bag, slot)
	return bag * SLOT_ID_MULTIPLIER + slot
end

---Splits a slotId into a bag and slot
---@param slotId number The slotId
---@return number bag
---@return number slot
function SlotId.Split(slotId)
	local bag = floor(slotId / SLOT_ID_MULTIPLIER)
	local slot = slotId % SLOT_ID_MULTIPLIER
	return bag, slot
end
