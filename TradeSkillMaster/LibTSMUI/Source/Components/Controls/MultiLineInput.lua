-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local MultiLineInput = UIElements.Define("MultiLineInput", "BaseInput")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function MultiLineInput:__init()
	local frame = self:_CreateScrollFrame()
	self.__super:__init(frame, self:_CreateEditBox(frame))

	frame:EnableMouseWheel(true)
	frame:SetClipsChildren(true)
	frame:TSMSetOnUpdate(self:__closure("_FrameOnUpdate"))
	frame:TSMSetScript("OnMouseWheel", self:__closure("_OnMouseWheel"))
	frame:TSMSetScript("OnMouseUp", self:__closure("_OnMouseUp"))

	self._scrollbar = self:_CreateScrollbar(frame)
	self._scrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnScrollbarValueChanged"))

	self._editBox:SetMultiLine(true)
	self._editBox:SetTextInsets(8, 8, 4, 4)
	frame:SetScrollChild(self._editBox)

	self._editBox:TSMSetScript("OnCursorChanged", self:__closure("_OnCursorChanged"))
	self._editBox:TSMSetScript("OnSizeChanged", self:__closure("_UpdateScrollBar"))

	self._scrollValue = 0
	self._ignoreEnter = false
end

function MultiLineInput:Acquire()
	self:SetBackgroundColor("ACTIVE_BG")
	self:SetJustifyH("LEFT")
	self:SetJustifyV("TOP")
	self.__super:Acquire()
	self._scrollValue = 0
	self._ignoreEnter = false
	self._scrollbar:SetValue(0)
end

--- Sets to ignore enter pressed scripts for the input multi-line input.
---@return MultiLineInput
function MultiLineInput:SetIgnoreEnter()
	self._editBox:TSMSetScript("OnEnterPressed", nil)
	self._ignoreEnter = true
	return self
end

function MultiLineInput:Draw()
	self._editBox:SetWidth(self:_GetBaseFrame():GetWidth())
	self.__super:Draw()
	self:_UpdateScrollBar()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function MultiLineInput.__private:_UpdateScrollBar()
	local maxScroll = self:_GetMaxScroll()
	self._scrollbar:SetMinMaxValues(0, maxScroll)
	self._scrollbar:SetValue(min(self._scrollValue, maxScroll))
	self._scrollbar:TSMUpdateThumbLength(self._editBox:GetHeight(), self:_GetDimension("HEIGHT"))
end

function MultiLineInput.__private:_OnScrollValueChanged(value)
	self:_GetBaseFrame():SetVerticalScroll(value)
	self._scrollValue = value
end

function MultiLineInput.__private:_GetMaxScroll()
	return max(self._editBox:GetHeight() - self:_GetDimension("HEIGHT"), 0)
end

function MultiLineInput.__private:_OnCursorChanged(_, y, _, lineHeight)
	y = abs(y)
	local offset = y - self._scrollValue
	if offset < 0 or offset > self:_GetDimension("HEIGHT") - lineHeight then
		self._scrollbar:SetValue(y)
	end
end

function MultiLineInput.__private:_OnScrollbarValueChanged(_, value)
	value = max(min(value, self:_GetMaxScroll()), 0)
	self:_OnScrollValueChanged(value)
end

function MultiLineInput.__private:_FrameOnUpdate()
	if (self:_GetBaseFrame():IsMouseOver() and self:_GetMaxScroll() > 0) or self._scrollbar.dragging then
		self._scrollbar:Show()
	else
		self._scrollbar:Hide()
	end
end

function MultiLineInput.__private:_OnMouseWheel(_, direction)
	local parentScroll = nil
	local parent = self:GetParentElement()
	while parent do
		if UIElements.IsType(parent, "ScrollFrame") then
			parentScroll = parent
			break
		else
			parent = parent:GetParentElement()
		end
	end

	if parentScroll then
		local minValue, maxValue = self._scrollbar:GetMinMaxValues()
		if direction > 0 then
			if self._scrollbar:GetValue() == minValue then
				local scrollAmount = min(parentScroll:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
				parentScroll._scrollbar:SetValue(parentScroll._scrollbar:GetValue() + -1 * direction * scrollAmount)
			else
				local scrollAmount = min(self:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
				self._scrollbar:SetValue(self._scrollbar:GetValue() + -1 * direction * scrollAmount)
			end
		else
			if self._scrollbar:GetValue() == maxValue then
				local scrollAmount = min(parentScroll:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
				parentScroll._scrollbar:SetValue(parentScroll._scrollbar:GetValue() + -1 * direction * scrollAmount)
			else
				local scrollAmount = min(self:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
				self._scrollbar:SetValue(self._scrollbar:GetValue() + -1 * direction * scrollAmount)
			end
		end
	else
		local scrollAmount = min(self:_GetDimension("HEIGHT") / 3, Theme.GetMouseWheelScrollAmount())
		self._scrollbar:SetValue(self._scrollbar:GetValue() + -1 * direction * scrollAmount)
	end
end

function MultiLineInput.__private:_OnMouseUp()
	self:SetFocused(true)
end
