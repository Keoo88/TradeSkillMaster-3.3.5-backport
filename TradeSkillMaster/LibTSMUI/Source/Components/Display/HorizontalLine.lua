-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local DEFAULT_LINE_THICKNESS = 2



-- ============================================================================
-- Element Definition
-- ============================================================================

local HorizontalLine = UIElements.Define("HorizontalLine", "Texture")
HorizontalLine:_ExtendStateSchema()
	:UpdateFieldDefault("color", "ACTIVE_BG")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function HorizontalLine:Acquire()
	self.__super:Acquire()
	self:SetHeight(DEFAULT_LINE_THICKNESS)
end
