	-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local PopupFrame = UIElements.Define("PopupFrame", "Frame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PopupFrame:__init()
	self.__super:__init()
	self._nineSlice = self:_CreateNineSlice()
	self._nineSlice:SetStyle("popup")
end

function PopupFrame:Acquire()
	self.__super:Acquire()
	-- TODO: Proper color
	self._nineSlice:SubscribePartVertexColor("center", "PRIMARY_BG_ALT:duskwood")
end
