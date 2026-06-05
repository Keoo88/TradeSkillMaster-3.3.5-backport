-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local DURATION = 1
local MIN_ALPHA = 0.3



-- ============================================================================
-- Element Definition
-- ============================================================================

local FlashingButton = UIElements.Define("FlashingButton", "Button")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function FlashingButton:__init()
	self.__super:__init()

	local frame = self:_GetBaseFrame()
	self._ag = self:_CreateAnimationGroup(frame)
	self._ag:SetLooping("BOUNCE")
	self._alpha = self._ag:CreateAnimation("Alpha")
end

function FlashingButton:Acquire()
	self._alpha:SetFromAlpha(1)
	self._alpha:SetToAlpha(MIN_ALPHA)
	self._alpha:SetDuration(DURATION)
	self.__super:Acquire()
end

function FlashingButton:Release()
	self._ag:Stop()
	self.__super:Release()
end

---Sets whether or not the animation is playing.
---@param play boolean Whether the animation should be playing or not
---@return FlashingButton
function FlashingButton:SetPlaying(play)
	self._ag:TSMSetPlaying(play)
	return self
end
