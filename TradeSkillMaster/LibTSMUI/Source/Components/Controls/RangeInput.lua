-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {}
local THUMB_WIDTH = 8
local INPUT_WIDTH = 50
local INPUT_AREA_SPACE = 128
local CORNER_RADIUS = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local RangeInput = UIElements.Define("RangeInput", "Element")
RangeInput:_ExtendStateSchema()
	:AddOptionalStringField("value")
	:AddStringField("font", "BODY_BODY2")
	:AddStringField("textColor", "TEXT")
	:Commit()
RangeInput:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function RangeInput:__init()
	local frame = self:_CreateFrame()
	self.__super:__init(frame)
	frame:EnableMouse(true)
	frame:TSMSetScript("OnMouseDown", self:__closure("_HandleFrameMouseDown"))
	frame:TSMSetScript("OnMouseUp", self:__closure("_HandleFrameMouseUp"))
	frame:TSMSetOnUpdate(self:__closure("_HandleFrameUpdate"))

	-- Create the textures
	frame.barTexture = self:_CreateTexture(frame, "BACKGROUND", 1)
	frame.activeBarTexture = self:_CreateTexture(frame, "BACKGROUND", 2)
	frame.thumbTextureLeft = self:_CreateTexture(frame, "ARTWORK")
	TextureAtlas.SetTextureAndSize(frame.thumbTextureLeft, "iconPack.14x14/Circle")
	frame.thumbTextureRight = self:_CreateTexture(frame, "ARTWORK")
	TextureAtlas.SetTextureAndSize(frame.thumbTextureRight, "iconPack.14x14/Circle")

	frame.inputLeft = self:_CreateEditBox(frame)
	frame.inputLeft:SetJustifyH("CENTER")
	frame.inputLeft:SetWidth(INPUT_WIDTH)
	frame.inputLeft:SetHeight(24)
	frame.inputLeft:SetAutoFocus(false)
	frame.inputLeft:SetNumeric(true)
	frame.inputLeft:TSMSetScript("OnEscapePressed", self:__closure("_HandleInputEscapePressed"))
	frame.inputLeft:TSMSetScript("OnEnterPressed", self:__closure("_HandleInputEnterPressed"))

	frame.dash = self:_CreateFontString(frame)
	frame.dash:SetJustifyH("CENTER")
	frame.dash:SetJustifyV("MIDDLE")
	frame.dash:SetWidth(12)
	frame.dash:TSMSetFont("BODY_BODY2")
	frame.dash:SetText("-")

	frame.inputRight = self:_CreateEditBox(frame)
	frame.inputRight:SetJustifyH("CENTER")
	frame.inputRight:SetWidth(INPUT_WIDTH)
	frame.inputRight:SetHeight(24)
	frame.inputRight:SetNumeric(true)
	frame.inputRight:SetAutoFocus(false)
	frame.inputRight:TSMSetScript("OnEscapePressed", self:__closure("_HandleInputEscapePressed"))
	frame.inputRight:TSMSetScript("OnEnterPressed", self:__closure("_HandleInputEnterPressed"))

	frame.barTexture:SetPoint("LEFT", 0, 0)
	frame.barTexture:SetPoint("RIGHT", frame.inputLeft, "LEFT", -16, 0)
	frame.inputRight:SetPoint("RIGHT", 0)
	frame.dash:SetPoint("RIGHT", frame.inputRight, "LEFT", 0, 0)
	frame.inputLeft:SetPoint("RIGHT", frame.dash, "LEFT", 0)

	self._inputLeftBackground = self:_CreateRectangle(nil, frame.inputLeft)
	self._inputLeftBackground:SetCornerRadius(CORNER_RADIUS)
	self._inputRightBackground = self:_CreateRectangle(nil, frame.inputRight)
	self._inputRightBackground:SetCornerRadius(CORNER_RADIUS)

	self._minValue = nil
	self._maxValue = nil
	self._dragging = nil
end

function RangeInput:Acquire()
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()

	frame.barTexture:TSMSubscribeColorTexture("FRAME_BG")
	frame.activeBarTexture:TSMSubscribeColorTexture("TEXT")

	-- Font
	self._state:PublisherForKeyChange("font")
		:CallMethod(frame.inputLeft, "TSMSetFont")
	self._state:PublisherForKeyChange("font")
		:CallMethod(frame.dash, "TSMSetFont")
	self._state:PublisherForKeyChange("font")
		:CallMethod(frame.inputRight, "TSMSetFont")

	-- Text color
	self._state:PublisherForKeyChange("textColor")
		:CallMethod(frame.inputLeft, "TSMSubscribeTextColor")
	self._state:PublisherForKeyChange("textColor")
		:CallMethod(frame.dash, "TSMSubscribeTextColor")
	self._state:PublisherForKeyChange("textColor")
		:CallMethod(frame.inputRight, "TSMSubscribeTextColor")

	-- Values
	self._state:PublisherForKeyChange("value")
		:IgnoreNil()
		:MapWithFunction(private.ValueToLeftValue)
		:CallMethod(frame.inputLeft, "SetNumber")
	self._state:PublisherForKeyChange("value")
		:IgnoreNil()
		:MapWithFunction(private.ValueToRightValue)
		:CallMethod(frame.inputRight, "SetNumber")

	-- Input background color
	self._inputLeftBackground:SubscribeColor("ACTIVE_BG")
	self._inputRightBackground:SubscribeColor("ACTIVE_BG")
end

function RangeInput:Release()
	self._minValue = nil
	self._maxValue = nil
	self._dragging = nil
	self.__super:Release()
end

---Set the extents of the possible range.
---@param value string The range value with the lower and upper ends separated by a comma
---@return RangeInput
function RangeInput:SetRange(value)
	local minValue, maxValue = private.SplitValue(value)
	self._minValue = minValue
	self._maxValue = maxValue
	self:SetValue(value)
	return self
end

---Sets the current value.
---@param value string The range value with the lower and upper ends separated by a comma
---@return RangeInput
function RangeInput:SetValue(value)
	local leftValue, rightValue = private.SplitValue(value)
	assert(leftValue <= rightValue and leftValue >= self._minValue and rightValue <= self._maxValue)
	self._state.value = value
	self:_SendActionScript("OnValueChanged")
	return self
end

---Subscribes to a publisher to set the value.
---@param publisher ReactivePublisher The publisher
---@return RangeInput
function RangeInput:SetValuePublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetValue"))
	return self
end

---Gets the current value
---@return string
function RangeInput:GetValue()
	assert(self._state.value)
	return self._state.value
end

function RangeInput:Draw()
	self.__super:Draw()

	local frame = self:_GetBaseFrame()
	local sliderHeight = self:_GetDimension("HEIGHT") / 2
	local width = self:_GetDimension("WIDTH") - INPUT_AREA_SPACE
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local leftPos = Math.Scale(leftValue, self._minValue, self._maxValue, 0, width - THUMB_WIDTH)
	local rightPos = Math.Scale(rightValue, self._minValue, self._maxValue, 0, width - THUMB_WIDTH)

	frame.barTexture:SetHeight(sliderHeight / 3)

	frame.thumbTextureLeft:SetPoint("LEFT", frame.barTexture, leftPos, 0)
	frame.thumbTextureRight:SetPoint("LEFT", frame.barTexture, rightPos, 0)

	frame.activeBarTexture:SetPoint("LEFT", frame.thumbTextureLeft, "CENTER")
	frame.activeBarTexture:SetPoint("RIGHT", frame.thumbTextureRight, "CENTER")
	frame.activeBarTexture:SetHeight(sliderHeight / 3)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function RangeInput:_GetCursorPositionValue()
	local frame = self:_GetBaseFrame()
	local x = GetCursorPosition() / frame:GetEffectiveScale()
	local left = frame:GetLeft() + THUMB_WIDTH / 2
	local right = frame:GetRight() - THUMB_WIDTH - INPUT_AREA_SPACE * 2 / 2
	x = min(max(x, left), right)
	local value = Math.Scale(x, left, right, self._minValue, self._maxValue)
	return min(max(Math.Round(value), self._minValue), self._maxValue)
end

function RangeInput:_UpdateLeftValue(value)
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local newValue = max(min(value, rightValue), self._minValue)
	if newValue == leftValue then
		self:_GetBaseFrame().inputLeft:SetNumber(leftValue)
		return
	end
	self:SetValue(newValue..","..rightValue)
	self:Draw()
end

function RangeInput:_UpdateRightValue(value)
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local newValue = min(max(value, leftValue), self._maxValue)
	if newValue == rightValue then
		self:_GetBaseFrame().inputRight:SetNumber(rightValue)
		return
	end
	self:SetValue(leftValue..","..newValue)
	self:Draw()
end

function RangeInput:_HandleFrameMouseDown()
	local frame = self:_GetBaseFrame()
	frame.inputLeft:ClearFocus()
	frame.inputRight:ClearFocus()
	local value = self:_GetCursorPositionValue()
	local leftValue, rightValue = private.SplitValue(self._state.value)
	local leftDiff = abs(value - leftValue)
	local rightDiff = abs(value - rightValue)
	if value < leftValue then
		-- clicked to the left of the left thumb, so drag that
		self._dragging = "left"
	elseif value > rightValue then
		-- clicked to the right of the right thumb, so drag that
		self._dragging = "right"
	elseif leftValue == rightValue then
		-- just ignore this click since they clicked on both thumbs
	elseif leftDiff < rightDiff then
		-- clicked closer to the left thumb, so drag that
		self._dragging = "left"
	else
		-- clicked closer to the right thumb (or right in the middle), so drag that
		self._dragging = "right"
	end
end

function RangeInput:_HandleFrameMouseUp()
	self._dragging = nil
end

function RangeInput:_HandleFrameUpdate()
	if not self._dragging then
		return
	end
	if self._dragging == "left" then
		self:_UpdateLeftValue(self:_GetCursorPositionValue())
	elseif self._dragging == "right" then
		self:_UpdateRightValue(self:_GetCursorPositionValue())
	else
		error("Unexpected dragging: "..tostring(self._dragging))
	end
end

function RangeInput:_HandleInputEscapePressed(input)
	input:ClearFocus()
	local frame = self:_GetBaseFrame()
	local leftValue, rightValue = private.SplitValue(self._state.value)
	if input == frame.inputLeft then
		input:SetNumber(leftValue)
	elseif input == frame.inputRight then
		input:SetNumber(rightValue)
	else
		error("Invalid input")
	end
end

function RangeInput:_HandleInputEnterPressed(input)
	local value = input:GetNumber()
	input:ClearFocus()
	local frame = self:_GetBaseFrame()
	if input == frame.inputLeft then
		self:_UpdateLeftValue(value)
	elseif input == frame.inputRight then
		self:_UpdateRightValue(value)
	else
		error("Invalid input")
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SplitValue(value)
	local leftValue, rightValue = strsplit(",", value)
	leftValue = tonumber(leftValue)
	rightValue = tonumber(rightValue)
	assert(leftValue and rightValue)
	return leftValue, rightValue
end

function private.ValueToLeftValue(value)
	local leftValue = private.SplitValue(value)
	return leftValue
end

function private.ValueToRightValue(value)
	local _, rightValue = private.SplitValue(value)
	return rightValue
end
