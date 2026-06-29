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

local ScrollFrame = UIElements.Define("ScrollFrame", "Container")
ScrollFrame:_ExtendStateSchema()
	:AddOptionalStringField("backgroundColor", Theme.IsValidColor)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ScrollFrame:__init()
	local frame = self:_CreateScrollFrame()

	self.__super:__init(frame)

	self._background = self:_CreateRectangle(1)
	self._background:SetCornerRadius(0)
	self._background:Hide()

	frame:EnableMouseWheel(true)
	-- 3.3.5: SetClipsChildren is not guaranteed (standalone !!!ClassicAPI may lack it). ScrollFrames
	-- already clip their scroll child to their bounds, so guard the call instead of erroring.
	if frame.SetClipsChildren then
		frame:SetClipsChildren(true)
	end
	frame:TSMSetOnUpdate(self:__closure("_FrameOnUpdate"))
	frame:TSMSetScript("OnMouseWheel", self:__closure("_FrameOnMouseWheel"))

	self._scrollbar = self:_CreateScrollbar(frame)
	self._scrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnScrollValueChanged"))

	self._content = self:_CreateScrollFrame(frame)
	self._content:SetPoint("TOPLEFT")
	self._content:SetPoint("TOPRIGHT")
	frame:SetScrollChild(self._content)

	self._scrollValue = 0
	self._onUpdateHandler = nil
end

function ScrollFrame:Acquire()
	self.__super:Acquire()
	self._scrollValue = 0
	self._scrollbar:SetValue(0)
	-- In 3.3.5 SetParent(nil) in Release hides the entire subtree including _content
	-- Explicitly restore _content visibility on re-acquire
	self._content:Show()

	-- Set the background
	self._state:PublisherForKeyChange("backgroundColor")
		:MapToBoolean()
		:CallMethod(self._background, "SetShown")
	self._state:PublisherForKeyChange("backgroundColor")
		:IgnoreNil()
		:CallMethod(self._background, "SubscribeColor")
end

function ScrollFrame:Release()
	self._onUpdateHandler = nil
	self._background:Hide()
	self.__super:Release()
end

---Sets the background of the scroll frame.
---@param color? ThemeColorKey The background color as a theme color key or nil
---@return ScrollFrame
function ScrollFrame:SetBackgroundColor(color)
	self._state.backgroundColor = color
	return self
end

---Sets a script handler.
---@param script string The script to register for
---@param handler function The script handler which will be called with the scroll frame object followed by any arguments to the script
---@return ScrollFrame
function ScrollFrame:SetScript(script, handler)
	if script == "OnUpdate" then
		self._onUpdateHandler = handler
	else
		self.__super:SetScript(script, handler)
	end
	return self
end

function ScrollFrame:Draw()
	self.__super.__super:Draw()

	local width = self:_GetDimension("WIDTH")
	self._content:SetWidth(width)
	width = width - self:_GetPadding("LEFT") - self:_GetPadding("RIGHT")

	local totalHeight = self:_GetPadding("TOP") + self:_GetPadding("BOTTOM")
	for _, child in self:LayoutChildrenIterator() do
		local childFrame = child:_GetBaseFrame()
		if childFrame:GetParent() ~= self._content then
			childFrame:SetParent(self._content)
			childFrame:Show()
		end
		childFrame:ClearAllPoints()

		-- Set the height
		local childHeight, childHeightCanExpand = child:_GetMinimumDimension("HEIGHT")
		assert(not childHeightCanExpand, "Invalid height for child: "..tostring(child._id))
		child:_SetDimension("HEIGHT", childHeight)
		totalHeight = totalHeight + childHeight + child:_GetMargin("TOP") + child:_GetMargin("BOTTOM")

		-- Set the width
		local childWidth, childWidthCanExpand = child:_GetMinimumDimension("WIDTH")
		if childWidthCanExpand then
			childWidth = max(childWidth, width - child:_GetMargin("LEFT") - child:_GetMargin("RIGHT"))
		end
		child:_SetDimension("WIDTH", childWidth)
	end
	self._content:SetHeight(totalHeight)
	local maxScroll = self:_GetMaxScroll()
	self._scrollbar:SetMinMaxValues(0, maxScroll)
	self._scrollbar:SetValue(min(self._scrollValue, maxScroll))
	self._scrollbar:TSMUpdateThumbLength(totalHeight, self:_GetDimension("HEIGHT"))

	local yOffset = -1 * self:_GetPadding("TOP")
	for _, child in self:LayoutChildrenIterator() do
		local childFrame = child:_GetBaseFrame()
		yOffset = yOffset - child:_GetMargin("TOP")
		childFrame:SetPoint("TOPLEFT", child:_GetMargin("LEFT") + self:_GetPadding("LEFT"), yOffset)
		yOffset = yOffset - childFrame:GetHeight() - child:_GetMargin("BOTTOM")
	end

	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ScrollFrame.__private:_OnScrollValueChanged(_, value)
	value = max(min(value, self:_GetMaxScroll()), 0)
	self:_GetBaseFrame():SetVerticalScroll(value)
	self._scrollValue = value
end

function ScrollFrame.__private:_GetMaxScroll()
	return max(self._content:GetHeight() - self:_GetDimension("HEIGHT"), 0)
end

function ScrollFrame:_GetMinimumDimension(dimension)
	local styleResult = nil
	if dimension == "WIDTH" then
		styleResult = self._width
	elseif dimension == "HEIGHT" then
		styleResult = self._height
	else
		error("Invalid dimension: "..tostring(dimension))
	end
	if styleResult then
		return styleResult, false
	elseif dimension == "HEIGHT" or self:_GetNumLayoutChildren() == 0 then
		-- regarding the first condition for this if statment, a scrollframe can be any height (including greater than
		-- the height of the content if no scrolling is needed), so has no minimum and can always expand
		return 0, true
	else
		-- we're trying to determine the width based on the max width of any of the children
		local result = 0
		local canExpand = false
		for _, child in self:LayoutChildrenIterator() do
			local childMin, childCanExpand = child:_GetMinimumDimension(dimension)
			childMin = childMin + child:_GetMargin("LEFT") + child:_GetMargin("RIGHT")
			canExpand = canExpand or childCanExpand
			result = max(result, childMin)
		end
		result = result + self:_GetPadding("LEFT") + self:_GetPadding("RIGHT")
		return result, canExpand
	end
end

function ScrollFrame.__private:_FrameOnUpdate()
	if (self:_GetBaseFrame():IsMouseOver() and self:_GetMaxScroll() > 0) or self._scrollbar.dragging then
		self._scrollbar:Show()
	else
		self._scrollbar:Hide()
	end
	if self._onUpdateHandler then
		self:_onUpdateHandler()
	end
end

function ScrollFrame.__private:_FrameOnMouseWheel(_, direction)
	local parentScroll = nil
	local parent = self:GetParentElement()
	while parent do
		if parent:__isa(ScrollFrame) then
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
