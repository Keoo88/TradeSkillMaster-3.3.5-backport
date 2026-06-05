-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
---@alias FrameLayout
---|'"NONE"'
---|'"HORIZONTAL"'
---|'"VERTICAL"'
---|'"FLOW"'
local VALID_LAYOUTS = {
	NONE = true,
	HORIZONTAL = true,
	VERTICAL = true,
	FLOW = true,
}
local LAYOUT_CONTEXT = {
	VERTICAL = {
		primaryDimension = "HEIGHT",
		secondaryDimension = "WIDTH",
		sides = { primary = { "TOP", "BOTTOM" }, secondary = { "LEFT", "RIGHT" } },
	},
	HORIZONTAL = {
		primaryDimension = "WIDTH",
		secondaryDimension = "HEIGHT",
		sides = { primary = { "LEFT", "RIGHT" }, secondary = { "TOP", "BOTTOM" } },
	},
}
local ROUNDED_CORNER_RADIUS = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local Frame = UIElements.Define("Frame", "Container")
Frame:_ExtendStateSchema()
	:AddOptionalStringField("backgroundColor", Theme.IsValidColor)
	:AddOptionalStringField("borderColor", Theme.IsValidColor)
	:AddOptionalNumberField("borderSize")
	:AddBooleanField("roundedCorners", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Frame:__init()
	self.__super:__init(self:_CreateFrame())

	self._borderRectangle = self:_CreateRectangle()
	self._borderRectangle:Hide()

	self._backgroundRectangle = self:_CreateRectangle(1)
	self._backgroundRectangle:Hide()

	self._layout = "NONE"
	self._expandWidth = false
	self._strata = nil
	self._scale = 1
end

function Frame:Acquire()
	self.__super:Acquire()

	-- Set the background
	self._state:PublisherForKeyChange("backgroundColor")
		:MapToBoolean()
		:CallMethod(self._backgroundRectangle, "SetShown")
	self._state:PublisherForKeys("borderColor", "borderSize")
		:MapWithFunction(private.StateToBackgroundInset)
		:CallMethod(self._backgroundRectangle, "SetInset")
	self._state:PublisherForKeyChange("backgroundColor")
		:IgnoreNil()
		:CallMethod(self._backgroundRectangle, "SubscribeColor")

	-- Set the border
	self._state:PublisherForKeyChange("borderColor")
		:MapToBoolean()
		:CallMethod(self._borderRectangle, "SetShown")
	self._state:PublisherForKeyChange("borderColor")
		:IgnoreNil()
		:CallMethod(self._borderRectangle, "SubscribeColor")

	-- Set the corner radius
	self._state:PublisherForKeyChange("roundedCorners")
		:MapBooleanWithValues(ROUNDED_CORNER_RADIUS, 0)
		:Share(2)
		:CallMethod(self._backgroundRectangle, "SetCornerRadius")
		:CallMethod(self._borderRectangle, "SetCornerRadius")
end

function Frame:Release()
	self._layout = "NONE"
	self._expandWidth = false
	self._strata = nil
	self._scale = 1
	self._borderRectangle:Hide()
	self._backgroundRectangle:Hide()
	local frame = self:_GetBaseFrame()
	frame:RegisterForDrag()
	frame:EnableMouse(false)
	frame:SetMovable(false)
	frame:EnableMouseWheel(false)
	frame:SetHitRectInsets(0, 0, 0, 0)
	self.__super:Release()
end

---Sets the background of the frame.
---@generic T: Frame
---@param self T
---@param color? ThemeColorKey The background color
---@return T
function Frame:SetBackgroundColor(color)
	self._state.backgroundColor = color
	self._state.roundedCorners = false
	return self
end

---Sets the background color for the frame with rounded corners.
---@generic T: Frame
---@param self T
---@param color? ThemeColorKey The background color
---@return T
function Frame:SetRoundedBackgroundColor(color)
	self._state.backgroundColor = color
	self._state.roundedCorners = true
	return self
end

---Sets the border color of the frame.
---@generic T: Frame
---@param self T
---@param color? ThemeColorKey The border color
---@param borderSize? number The border size (defaults to 1)
---@return T
function Frame:SetBorderColor(color, borderSize)
	self._state.borderColor = color
	self._state.borderSize = borderSize or 1
	return self
end

---Sets the width of the frame
---@generic T: Frame
---@param self T
---@param width? number|"EXPAND" The width of the frame, "EXPAND" to set the width to expand to be
---as large as possible, or nil to have an undefined width
---@return T
function Frame:SetWidth(width)
	if width == "EXPAND" then
		self._expandWidth = true
	else
		self.__super:SetWidth(width)
	end
	return self
end

---Sets the parent frame.
---@generic T: Frame
---@param self T
---@param parent frame The WoW frame to parent to
---@return T
function Frame:SetParent(parent)
	self:_GetBaseFrame():SetParent(parent)
	return self
end

---Sets the level of the frame.
---@generic T: Frame
---@param self T
---@param level number The frame level
---@return Frame
function Frame:SetFrameLevel(level)
	self:_GetBaseFrame():SetFrameLevel(level)
	return self
end

---Sets the strata of the frame.
---@generic T: Frame
---@param self T
---@param strata string The frame strata
---@return T
function Frame:SetStrata(strata)
	self._strata = strata
	return self
end

---Sets the scale of the frame.
---@generic T: Frame
---@param self T
---@param scale string The frame scale
---@return T
function Frame:SetScale(scale)
	self._scale = scale
	return self
end

---Sets the layout of the frame.
---@generic T: Frame
---@param self T
---@param layout FrameLayout The frame layout
---@return T
function Frame:SetLayout(layout)
	assert(VALID_LAYOUTS[layout], format("Invalid layout (%s)", tostring(layout)))
	self._layout = layout
	return self
end

---Sets whether mouse interaction is enabled.
---@generic T: Frame
---@param self T
---@param enabled boolean Whether mouse interaction is enabled
---@return T
function Frame:SetMouseEnabled(enabled)
	self:_GetBaseFrame():EnableMouse(enabled)
	return self
end

---Sets whether mouse wheel interaction is enabled.
---@generic T: Frame
---@param self T
---@param enabled boolean Whether mouse wheel interaction is enabled
---@return T
function Frame:SetMouseWheelEnabled(enabled)
	self:_GetBaseFrame():EnableMouseWheel(enabled)
	return self
end

---Allows dragging of the frame.
---@generic T: Frame
---@param self T
---@param button string The button to support dragging with
---@return T
function Frame:RegisterForDrag(button)
	self:SetMouseEnabled(button and true or false)
	self:_GetBaseFrame():RegisterForDrag(button)
	return self
end

---Gets whether the mouse is currently over the frame.
---@return boolean
function Frame:IsMouseOver()
	return self:_GetBaseFrame():IsMouseOver()
end

---Sets the hit rectangle insets.
---@generic T: Frame
---@param self T
---@param left number The left hit rectangle inset
---@param right number The right hit rectangle inset
---@param top number The top hit rectangle inset
---@param bottom number The bottom hit rectangle inset
---@return T
function Frame:SetHitRectInsets(left, right, top, bottom)
	self:_GetBaseFrame():SetHitRectInsets(left, right, top, bottom)
	return self
end

---Makes the element movable and starts moving it.
---@generic T: Frame
---@param self T
---@return T
function Frame:StartMoving()
	self:_GetBaseFrame():SetMovable(true)
	self:_GetBaseFrame():StartMoving()
	return self
end

---Stops moving the element, and makes it unmovable.
---@generic T: Frame
---@param self T
---@return T
function Frame:StopMovingOrSizing()
	self:_GetBaseFrame():StopMovingOrSizing()
	self:_GetBaseFrame():SetMovable(false)
	return self
end

function Frame:Draw()
	assert(not self._state.borderColor or self._state.backgroundColor)
	local layout = self._layout
	self.__super.__super:Draw()
	local frame = self:_GetBaseFrame()

	frame:SetScale(self._scale)

	local strata = self._strata
	if strata then
		frame:SetFrameStrata(strata)
	end

	if layout == "NONE" then
		-- pass
	elseif layout == "FLOW" then
		local width = self:_GetDimension("WIDTH")
		local height = self:_GetDimension("HEIGHT") - self:_GetPadding("TOP") - self:_GetPadding("BOTTOM")
		local rowHeight = 0
		for _, child in self:LayoutChildrenIterator() do
			child:_GetBaseFrame():ClearAllPoints()
			local childPrimary = child:_GetMinimumDimension("WIDTH")
			child:_SetDimension("WIDTH", childPrimary)
			local childSecondary = child:_GetMinimumDimension("HEIGHT")
			rowHeight = childSecondary + child:_GetMargin("BOTTOM") + child:_GetMargin("TOP")
			child:_SetDimension("HEIGHT", childSecondary)
		end
		local xOffset = self:_GetPadding("LEFT")
		-- calculate the Y offset to properly position stuff with the padding of this frame taken into account
		local yOffset = -self:_GetPadding("TOP")
		for _, child in self:LayoutChildrenIterator() do
			local childFrame = child:_GetBaseFrame()
			local childWidth = childFrame:GetWidth() + child:_GetMargin("LEFT") + child:_GetMargin("RIGHT")
			if xOffset + childWidth + self:_GetPadding("RIGHT") > width then
				-- move to the next row
				xOffset = self:_GetPadding("LEFT")
				yOffset = yOffset - rowHeight
			end
			local childYOffset = yOffset - child:_GetMargin("TOP")
			if height > 0 then
				childYOffset = yOffset + (height - childFrame:GetHeight()) / 2 - child:_GetMargin("TOP")
			end
			childFrame:SetPoint("LEFT", xOffset + child:_GetMargin("LEFT"), childYOffset)
			xOffset = xOffset + childWidth
		end
	else
		local context = LAYOUT_CONTEXT[layout]
		assert(context)
		local primary = self:_GetDimension(context.primaryDimension) - self:_GetPadding(context.sides.primary[1]) - self:_GetPadding(context.sides.primary[2])
		local secondary = self:_GetDimension(context.secondaryDimension) - self:_GetPadding(context.sides.secondary[1]) - self:_GetPadding(context.sides.secondary[2])

		local expandChildren = TempTable.Acquire()
		local preferredChildren = TempTable.Acquire()
		for _, child in self:LayoutChildrenIterator() do
			child:_GetBaseFrame():ClearAllPoints()
			local childPrimary, childPrimaryCanExpand = child:_GetMinimumDimension(context.primaryDimension)
			if childPrimaryCanExpand then
				local childPreferredPrimary = child:_GetPreferredDimension(context.primaryDimension)
				if childPreferredPrimary then
					assert(childPreferredPrimary > childPrimary, "Invalid preferred dimension")
					preferredChildren[child] = childPreferredPrimary
				else
					expandChildren[child] = childPrimary
				end
			else
				child:_SetDimension(context.primaryDimension, childPrimary)
			end
			primary = primary - childPrimary - child:_GetMargin(context.sides.primary[1]) - child:_GetMargin(context.sides.primary[2])
			local childSecondary, childSecondaryCanExpand = child:_GetMinimumDimension(context.secondaryDimension)
			childSecondary = min(childSecondary, secondary)
			if childSecondaryCanExpand and childSecondary < secondary then
				childSecondary = secondary
			end
			child:_SetDimension(context.secondaryDimension, childSecondary - child:_GetMargin(context.sides.secondary[1]) - child:_GetMargin(context.sides.secondary[2]))
		end
		for child, preferredPrimary in pairs(preferredChildren) do
			local childPrimary = min(primary, preferredPrimary)
			child:_SetDimension(context.primaryDimension, childPrimary)
			primary = primary - (childPrimary - child:_GetMinimumDimension(context.primaryDimension))
		end
		local numExpandChildren = Table.Count(expandChildren)
		for child, childPrimary in pairs(expandChildren) do
			if primary >= 0 then
				childPrimary = childPrimary + primary / numExpandChildren
			else
				-- 3.3.5: when the available space is smaller than the sum of the children's
				-- minimum sizes, don't keep expand children at their minimum (which pushes
				-- fixed siblings like the Add/Remove buttons outside the frame). Instead let
				-- the expandable child (e.g. a scrollable list) shrink so fixed siblings stay
				-- visible. Floored at 1 so we never set a non-positive dimension.
				childPrimary = max(1, childPrimary + primary / numExpandChildren)
			end
			child:_SetDimension(context.primaryDimension, childPrimary)
		end
		TempTable.Release(expandChildren)
		TempTable.Release(preferredChildren)
		if layout == "HORIZONTAL" then
			local xOffset = self:_GetPadding("LEFT")
			-- calculate the Y offset to properly position stuff with the padding of this frame taken into account
			local yOffset = (self:_GetPadding("BOTTOM") - self:_GetPadding("TOP")) / 2
			for _, child in self:LayoutChildrenIterator() do
				local childFrame = child:_GetBaseFrame()
				xOffset = xOffset + child:_GetMargin("LEFT")
				local childYOffset = (child:_GetMargin("BOTTOM") - child:_GetMargin("TOP")) / 2
				childFrame:SetPoint("LEFT", xOffset, childYOffset + yOffset)
				xOffset = xOffset + childFrame:GetWidth() + child:_GetMargin("RIGHT")
			end
		elseif layout == "VERTICAL" then
			local yOffset = -self:_GetPadding("TOP")
			-- calculate the X offset to properly position stuff with the padding of this frame taken into account
			local xOffset = (self:_GetPadding("LEFT") - self:_GetPadding("RIGHT")) / 2
			for _, child in self:LayoutChildrenIterator() do
				local childFrame = child:_GetBaseFrame()
				yOffset = yOffset - child:_GetMargin("TOP")
				local childXOffset = (child:_GetMargin("LEFT") - child:_GetMargin("RIGHT")) / 2
				childFrame:SetPoint("TOP", childXOffset + xOffset, yOffset)
				yOffset = yOffset - childFrame:GetHeight() - child:_GetMargin("BOTTOM")
			end
		else
			error()
		end
	end
	for _, child in self:LayoutChildrenIterator() do
		child:Draw()
	end
	for _, child in ipairs(self._noLayoutChildren) do
		child:Draw()
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Frame:_GetMinimumDimension(dimension)
	assert(dimension == "WIDTH" or dimension == "HEIGHT")
	local styleResult = nil
	if dimension == "WIDTH" then
		styleResult = self._width
	elseif dimension == "HEIGHT" then
		styleResult = self._height
	else
		error("Invalid dimension: "..tostring(dimension))
	end
	local layout = self._layout
	local context = LAYOUT_CONTEXT[layout]
	if styleResult then
		return styleResult, false
	elseif self:_GetNumLayoutChildren() == 0 or layout == "NONE" then
		return 0, true
	elseif layout == "FLOW" then
		-- calculate our minimum width which is the largest of the widths of the children
		local minWidth = 0
		for _, child in self:LayoutChildrenIterator() do
			local childMin = child:_GetMinimumDimension("WIDTH")
			childMin = childMin + child:_GetMargin("LEFT") + child:_GetMargin("RIGHT")
			minWidth = max(minWidth, childMin)
		end
		minWidth = minWidth + self:_GetPadding("LEFT") + self:_GetPadding("RIGHT")
		if dimension == "WIDTH" then
			return minWidth, true
		end

		-- calculate the row height (all children should be the exact same height)
		local rowHeight = nil
		for _, child in self:LayoutChildrenIterator() do
			local childMin, childCanExpand = child:_GetMinimumDimension("HEIGHT")
			childMin = childMin + child:_GetMargin("TOP") + child:_GetMargin("BOTTOM")
			rowHeight = rowHeight or childMin
			assert(childMin == rowHeight and not childCanExpand)
		end
		rowHeight = rowHeight or 0

		local parentElement = self:GetParentElement()
		local parentWidth = parentElement:_GetDimension("WIDTH") - parentElement:_GetPadding("LEFT") - parentElement:_GetPadding("RIGHT")
		if parentWidth <= 0 then
			-- parent not yet sized — return height for all children in one column
			return rowHeight * self:_GetNumLayoutChildren(), false
		end
		if minWidth > parentWidth then
			-- we won't fit, so just pretend we're a single row
			return rowHeight, false
		end

		-- calculate our height based on our parent's width
		local height = rowHeight
		local currentRowWidth = 0
		for _, child in self:LayoutChildrenIterator() do
			local childWidth = child:_GetMinimumDimension("WIDTH") + child:_GetMargin("LEFT") + child:_GetMargin("RIGHT")
			if currentRowWidth + childWidth > parentWidth then
				-- this child will go on the next row
				height = height + rowHeight
				currentRowWidth = childWidth
			else
				-- this child fits on the current row
				currentRowWidth = currentRowWidth + childWidth
			end
		end

		return height, false
	elseif context then
		-- calculate the dimension based on the children
		local sides = (dimension == context.primaryDimension) and context.sides.primary or context.sides.secondary
		local result = 0
		local canExpand = false
		for _, child in self:LayoutChildrenIterator() do
			local childMin, childCanExpand = child:_GetMinimumDimension(dimension)
			childMin = childMin + child:_GetMargin(sides[1]) + child:_GetMargin(sides[2])
			canExpand = canExpand or childCanExpand
			if dimension == context.primaryDimension then
				result = result + childMin
			else
				result = max(result, childMin)
			end
		end
		result = result + self:_GetPadding(sides[1]) + self:_GetPadding(sides[2])
		return result, self._expandWidth or canExpand
	else
		error(format("Invalid layout (%s)", tostring(layout)))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToBackgroundInset(state)
	return state.borderColor and state.borderSize or 0
end
