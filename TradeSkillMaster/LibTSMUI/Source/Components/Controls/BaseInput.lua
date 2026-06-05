-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local Errors = LibTSMUI:Include("Util.Errors")
local UIElements = LibTSMUI:Include("Util.UIElements")
local CustomString = LibTSMUI:From("LibTSMTypes"):Include("CustomString")
local DelayTimer = LibTSMUI:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {}
local BORDER_THICKNESS = 1
local CORNER_RADIUS = 4
local COPPER_PER_SILVER = 100
---@alias JustifyHValue '"LEFT"'|'"CENTER"'|'"RIGHT"'
---@alias JustifyVValue '"TOP"'|'"MIDDLE"'|'"BOTTOM"'



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseInput = UIElements.Define("BaseInput", "Element", "ABSTRACT")
BaseInput:_ExtendStateSchema()
	:AddStringField("justifyH", "LEFT", private.ValidateJustifyH)
	:AddStringField("justifyV", "MIDDLE", private.ValidateJustifyV)
	:AddBooleanField("backgroundIsLight", false)
	:AddStringField("backgroundColor", "ACTIVE_BG_ALT", Theme.IsValidColor)
	:AddOptionalStringField("borderColor", Theme.IsValidColor)
	:AddBooleanField("disabled", false)
	:AddStringField("font", "BODY_BODY2", Theme.IsValidFont)
	:AddBooleanField("isValid", true)
	:Commit()
BaseInput:_AddActionScripts("OnValueChanged", "OnEnterPressed", "OnValidationChanged", "OnFocusLost")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function BaseInput:__init(frame, editBox)
	self.__super:__init(frame)
	self._editBox = editBox ---@type EditBoxExtended

	self._borderTexture = self:_CreateRectangle()
	self._borderTexture:SetCornerRadius(CORNER_RADIUS)
	self._backgroundTexture = self:_CreateRectangle(1)
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)

	self._editBox:SetShadowColor(0, 0, 0, 0)
	self._editBox:SetAutoFocus(false)
	self._editBox:TSMSetScript("OnEscapePressed", self:__closure("_OnEscapePressed"))
	self._editBox:TSMSetScript("OnTabPressed", self:__closure("_OnTabPressed"))
	self._editBox:TSMSetScript("OnEditFocusGained", self:__closure("_OnEditFocusGained"))
	self._editBox:TSMSetScript("OnEditFocusLost", self:__closure("_OnEditFocusLost"))
	self._editBox:TSMSetScript("OnChar", self:__closure("_OnChar"))

	self._lostFocusTimer = DelayTimer.New("INPUT_LOST_FOCUS_"..tostring(frame), self:__closure("_HandleFocusLost"))
	self._value = ""
	self._escValue = nil
	self._pasteMode = nil
	self._validateFunc = nil
	self._validateContext = nil
	self._settingTable = nil
	self._settingKey = nil
	self._tabPrevPath = nil
	self._tabNextPath = nil
	self._onValueChangedHandler = nil
	self._onEnterPressedHandler = nil
	self._onValidationChangedHandler = nil
	self._onFocusLostHandler = nil
	self._pasteChars = {}
end

function BaseInput:Acquire()
	self.__super:Acquire()
	self._editBox:TSMSetScript("OnEnterPressed", self:__closure("_OnEnterPressed"))
	self._editBox:TSMSetScript("OnTextChanged", self:__closure("_HandleOnTextChanged"))
	self._editBox:TSMSubscribeHighlightColor("TEXT%HIGHLIGHT")

	-- Subscribe background color
	local backgroundColorPublisher = self._state:PublisherForKeys("disabled", "backgroundColor")
		:MapWithFunction(private.StateToBackgroundColor)
		:IgnoreDuplicates()
		:Share(2)
	backgroundColorPublisher
		:MapToPublisherWithFunction(Theme.GetPublisher)
		:MapWithMethod("IsLight")
		:IgnoreDuplicates()
		:AssignToTableKey(self._state, "backgroundIsLight")
	backgroundColorPublisher
		:CallMethod(self._backgroundTexture, "SubscribeColor")

	-- Set the edit box
	self._state:PublisherForKeyChange("justifyH")
		:CallMethod(self._editBox, "SetJustifyH")
	self._state:PublisherForKeyChange("justifyV")
		:CallMethod(self._editBox, "SetJustifyV")
	self._state:PublisherForKeys("disabled", "backgroundIsLight")
		:MapWithFunction(private.StateToTextColorKey)
		:IgnoreDuplicates()
		:CallMethod(self._editBox, "TSMSubscribeTextColor")
	self._state:PublisherForKeyChange("font")
		:CallMethod(self._editBox, "TSMSetFont")

	-- Update the backgorund / border
	local borderStatePublisher = self._state:PublisherForKeys("borderColor", "isValid")
		:Share(3)
	borderStatePublisher
		:MapWithFunction(private.StateToBackgroundInset)
		:CallMethod(self._backgroundTexture, "SetInset")
	borderStatePublisher
		:MapWithFunction(private.StateToBorderShown)
		:CallMethod(self._borderTexture, "SetShown")
	borderStatePublisher
		:MapWithFunction(private.StateToBorderColor)
		:IgnoreDuplicates()
		:CallMethod(self._borderTexture, "SubscribeColor")
end

function BaseInput:Release()
	self._lostFocusTimer:Cancel()
	self._editBox:TSMSetScript("OnEnterPressed", nil)
	self._editBox:TSMSetScript("OnTextChanged", nil)
	self._editBox:SetText("")
	self._editBox:ClearFocus()
	self._editBox:Enable()
	self._editBox:EnableMouse(true)
	self._editBox:EnableKeyboard(true)
	self._editBox:HighlightText(0, 0)
	self._editBox:SetHitRectInsets(0, 0, 0, 0)
	self._editBox:SetMaxLetters(2147483647)
	self._editBox:SetMaxBytes(2147483647)
	self._value = ""
	self._escValue = nil
	self._pasteMode = nil
	self._validateFunc = nil
	self._validateContext = nil
	self._settingTable = nil
	self._settingKey = nil
	self._tabPrevPath = nil
	self._tabNextPath = nil
	self._onValueChangedHandler = nil
	self._onEnterPressedHandler = nil
	self._onValidationChangedHandler = nil
	self._onFocusLostHandler = nil
	wipe(self._pasteChars)
	self.__super:Release()
end

---Sets the background of the input.
---@generic T: BaseInput
---@param self T
---@param color ThemeColorKey The background color
---@return T
function BaseInput:SetBackgroundColor(color)
	self._state.backgroundColor = color
	return self
end

---Sets the border of the input.
---@generic T: BaseInput
---@param self T
---@param color? string The border color or nil
---@return T
function BaseInput:SetBorderColor(color)
	self._state.borderColor = color
	return self
end

---Sets the horizontal justification of the input.
---@generic T: BaseInput
---@param self T
---@param justifyH JustifyHValue The horizontal justification
---@return T
function BaseInput:SetJustifyH(justifyH)
	self._state.justifyH = justifyH
	return self
end

---Sets the vertical justification of the input.
---@generic T: BaseInput
---@param self T
---@param justifyV JustifyVValue The vertical justification
---@return T
function BaseInput:SetJustifyV(justifyV)
	self._state.justifyV = justifyV
	return self
end

---Sets the font.
---@generic T: BaseInput
---@param self T
---@param font string The font key
---@return T
function BaseInput:SetFont(font)
	self._state.font = font
	return self
end

---Sets the path of the inputs to jump to when tab (or shift-tab to go backwards) is pressed.
---@generic T: BaseInput
---@param self T
---@param prevPath string The path to the previous input (for shift-tab)
---@param nextPath string The path to the next input (for tab)
---@return T
function BaseInput:SetTabPaths(prevPath, nextPath)
	self._tabPrevPath = prevPath
	self._tabNextPath = nextPath
	return self
end

---Set the highlight to all or some of the input's text.
---@generic T: BaseInput
---@param self T
---@param starting number The position at which to start the highlight
---@param ending number The position at which to stop the highlight
---@return T
function BaseInput:HighlightText(starting, ending)
	if starting and ending then
		self._editBox:HighlightText(starting, ending)
	else
		self._editBox:HighlightText()
	end
	return self
end

---Sets the current value.
---@generic T: BaseInput
---@param self T
---@param value string The value
---@return T
function BaseInput:SetValue(value)
	if type(value) == "number" then
		value = tostring(value)
	end
	assert(type(value) == "string")
	if self:_SetValueHelper(value, true) then
		self._escValue = self._value
	else
		self._escValue = nil
	end
	return self
end

---Subscribes to a publisher to set the value.
---@generic T: BaseInput
---@param self T
---@param publisher ReactivePublisher The publisher
---@return T
function BaseInput:SetValuePublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetValue"))
	return self
end

---Sets whether or not the input is disabled.
---@generic T: BaseInput
---@param self T
---@param disabled boolean Whether or not the input is disabled
---@return T
function BaseInput:SetDisabled(disabled)
	self._state.disabled = disabled and true or false
	self._editBox:TSMSetEnabled(not disabled)
	return self
end

---Subscribes to a publisher to set the disabled state.
---@generic T: BaseInput
---@param self T
---@param publisher ReactivePublisher The publisher
---@return T
function BaseInput:SetDisabledPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetDisabled"))
	return self
end

---Sets the function to use to validate the input text.
---@generic T: BaseInput
---@param self T
---@param validateFunc? "NUMBER"|"CUSTOM_STRING"|"UNDERCUT"|fun(value: string, context: any): boolean The validation func
---@param context? any|string[]|string Extra context to pass to the validate function.
---@return T
function BaseInput:SetValidateFunc(validateFunc, context)
	if type(validateFunc) == "function" then
		self._validateFunc = validateFunc
		self._validateContext = context
	elseif validateFunc == "CUSTOM_STRING" then
		assert(context == nil or type(context) == "table")
		self._validateFunc = private.CustomPriceValidateFunc
		self._validateContext = context
	elseif validateFunc == "UNDERCUT" then
		assert(context == nil or type(context) == "table")
		self._validateFunc = private.UndercutValidateFunction
		self._validateContext = context
	elseif validateFunc == "NUMBER" then
		local minVal, maxVal, extra = strsplit(":", context)
		assert(tonumber(minVal) <= tonumber(maxVal) and not extra)
		self._validateFunc = private.NumberValidateFunc
		self._validateContext = context
	else
		error("Invalid validateFunc: "..tostring(validateFunc))
	end
	return self
end

---Returns the input's focus state.
---@return boolean
function BaseInput:HasFocus()
	return self._editBox:HasFocus()
end

---Sets whether or not this input is focused.
---@generic T: BaseInput
---@param self T
---@param focused boolean Whether or not this input is focused
---@return T
function BaseInput:SetFocused(focused)
	if focused then
		self._editBox:SetFocus()
	else
		self._editBox:ClearFocus()
	end
	return self
end

---Clears the highlight.
---@generic T: BaseInput
---@param self T
---@return T
function BaseInput:ClearHighlight()
	self._editBox:HighlightText(0, 0)
	return self
end

---Set the maximum number of letters for the input's entered text.
---@generic T: BaseInput
---@param self T
---@param number number The number of letters for entered text
---@return T
function BaseInput:SetMaxLetters(number)
	self._editBox:SetMaxLetters(number)
	return self
end

---Gets the input value.
---@return string
function BaseInput:GetValue()
	return self._ignoreEnter and self._value or strtrim(self._value)
end

---Registers a script handler.
---@generic T: BaseInput
---@param self T
---@param script string The script to register for
---@param handler? function The script handler which should be called
---@return T
function BaseInput:SetScript(script, handler)
	if script == "OnValueChanged" then
		self._onValueChangedHandler = handler
	elseif script == "OnEnterPressed" then
		self._onEnterPressedHandler = handler
	elseif script == "OnValidationChanged" then
		self._onValidationChangedHandler = handler
	elseif script == "OnFocusLost" then
		self._onFocusLostHandler = handler
	elseif script == "OnEnter" or script == "OnLeave" then
		self.__super:SetScript(script, handler)
	else
		error("Invalid base input script: "..tostring(script))
	end
	return self
end

---Sets the setting info.
---
-- This method is used to have the value of the input automatically correspond with the value of a
-- field in a table. This is useful for inputs which are tied directly to settings.
---@generic T: BaseInput
---@param self T
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the input state
---@return T
function BaseInput:SetSettingInfo(tbl, key)
	assert(self._value == "")
	self._settingTable = tbl
	self._settingKey = key
	self:SetValue(tbl[key])
	return self
end

---Get the current validation state.
---@return boolean
function BaseInput:IsValid()
	return self._state.isValid
end

---Sets the input into paste mode for supporting the pasting of large strings.
---@generic T: BaseInput
---@param self T
---@return T
function BaseInput:SetPasteMode()
	self._pasteMode = true
	-- 3.3.5/Classic: SetMaxBytes(1) + отключение OnTextChanged ломает paste —
	-- WoW обрезает Ctrl+V до 1 байта и не пушит остальное через OnChar.
	-- Оставляем нативный OnTextChanged path, который и так работает.
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		return self
	end
	self._editBox:TSMSetScript("OnTextChanged", nil)
	self._editBox:SetMaxBytes(1)
	return self
end

function BaseInput:Draw()
	self.__super:Draw()
	if not self._editBox:HasFocus() then
		-- Set the text
		self._editBox:SetText(self._value)
	end
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function BaseInput.__protected:_SetValueHelper(value, noCallback)
	if not self._validateFunc or self:_validateFunc(strtrim(value), self._validateContext) then
		self._value = value
		if self._settingTable then
			if type(self._settingTable[self._settingKey]) == "number" then
				value = tonumber(value)
				assert(value)
			end
			self._settingTable[self._settingKey] = value
		end
		if not noCallback then
			self:_SendActionScript("OnValueChanged")
			if self._onValueChangedHandler then
				self:_onValueChangedHandler()
			end
		end
		if not self._state.isValid then
			self._state.isValid = true
			self:_SendActionScript("OnValidationChanged")
			if self._onValidationChangedHandler then
				self:_onValidationChangedHandler()
			end
		end
		return true
	else
		if self._value == "" then
			self._value = value
		end
		if self._state.isValid then
			self._state.isValid = false
			self:_SendActionScript("OnValidationChanged")
			if self._onValidationChangedHandler then
				self:_onValidationChangedHandler()
			end
		end
		return false
	end
end

function BaseInput.__protected:_OnTextChanged(value)
	-- Can be overridden
end

function BaseInput.__protected:_ShouldKeepFocus()
	-- Can be overridden
	return false
end

function BaseInput.__protected:_OnChar(_, c)
	-- Can be overridden
	if not self._pasteMode then
		return
	end
	-- 3.3.5/Classic: paste идёт через нативный OnTextChanged (см. SetPasteMode).
	-- Не накапливаем _pasteChars и не ставим OnUpdate — это создаёт гонку с
	-- OnTextChanged и затирает уже обработанное значение.
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		return
	end
	tinsert(self._pasteChars, c)
	self._editBox:TSMSetOnUpdate(self:__closure("_OnUpdate"))
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function BaseInput.__private:_HandleFocusLost()
	if self:HasFocus() then
		return
	end
	self:_SendActionScript("OnFocusLost")
	if self._onFocusLostHandler then
		self:_onFocusLostHandler()
	end
end

function BaseInput.__private:_OnEscapePressed()
	if self._escValue then
		self._value = self._escValue
		assert(self:_SetValueHelper(self._escValue))
	end
	self:SetFocused(false)
	self:HighlightText(0, 0)
	self:Draw()
end

function BaseInput.__private:_OnTabPressed()
	local isValid, err = true, nil
	if self._validateFunc then
		local value = strtrim(self._editBox:GetText())
		isValid, err = self:_validateFunc(value, self._validateContext)
	end
	if not isValid and err then
		-- TODO: Better way to show the error message?
		ChatMessage.PrintUser(err)
	end
	self:SetFocused(false)
	self:HighlightText(0, 0)
	if self._tabPrevPath and IsShiftKeyDown() then
		self:GetElement(self._tabPrevPath):SetFocused(true)
	elseif self._tabNextPath and not IsShiftKeyDown() then
		self:GetElement(self._tabNextPath):SetFocused(true)
	end
end

function BaseInput.__private:_OnEditFocusGained()
	self._lostFocusTimer:Cancel()
	self:Draw()
	self:HighlightText()
end

function BaseInput.__private:_OnEditFocusLost()
	if self:_ShouldKeepFocus() then
		self:SetFocused(true)
		return
	end
	if self._state.isValid then
		self._escValue = self._value
	end
	self:HighlightText(0, 0)
	self:Draw()
	if not self._state.isValid then
		self._state.isValid = true
		self:_SendActionScript("OnValidationChanged")
		if self._onValidationChangedHandler then
			self:_onValidationChangedHandler()
		end
	end
	-- Wait until the next frame before calling the handler
	self._lostFocusTimer:RunForFrames(0)
end

function BaseInput.__private:_OnEnterPressed()
	local isValid, err = true, nil
	if self._validateFunc then
		local value = strtrim(self._editBox:GetText())
		isValid, err = self:_validateFunc(value, self._validateContext)
	end
	if not isValid and err then
		-- TODO: better way to show the error message?
		ChatMessage.PrintUser(err)
	end
	if isValid then
		self:SetFocused(false)
		self:HighlightText(0, 0)
		self:_SendActionScript("OnEnterPressed")
		if self._onEnterPressedHandler then
			self:_onEnterPressedHandler()
		end
	end
end

function BaseInput.__private:_HandleOnTextChanged(_, isUserInput)
	-- 3.3.5: WoW OnTextChanged до Cata 4.0 не передаёт isUserInput. Если nil — считаем
	-- что это user input (на classic программные SetText сами вызывают _SetValueHelper
	-- через _SetValueImpl и не идут через onTextChanged).
	if isUserInput == false then
		return
	end
	local value = self._editBox:GetText()
	self:_SetValueHelper(value)
	self:_OnTextChanged(value)
end

function BaseInput.__private:_OnUpdate()
	self._editBox:TSMSetOnUpdate(nil)
	local value = table.concat(self._pasteChars)
	wipe(self._pasteChars)
	self:_SetValueHelper(value)
	self:_OnTextChanged(value)
end



-- ============================================================================
-- Built In Validate Functions
-- ============================================================================

function private.CustomPriceValidateFunc(_, value, badSources)
	local isValid, errType, errTokenStr = CustomString.Validate(value)
	local errMsg = nil
	if not isValid then
		errMsg = Errors.FormatCustomString(errType, errTokenStr)
	elseif badSources then
		errMsg = Errors.CheckCustomStringDependencies(value, badSources)
	end
	if errMsg then
		return false, L["Invalid custom price."].." "..errMsg
	else
		return true
	end
end

function private.UndercutValidateFunction(_, value, badSources)
	if not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic() then
		if Money.FromString(Money.ToStringExact(value) or value) == 0 then
			return true
		elseif (Money.FromString(Money.ToStringExact(value) or value) or math.huge) < COPPER_PER_SILVER then
			return false, L["Invalid undercut. To post below the cheapest auction without a significant undercut, set your undercut to 0c."]
		end
	end
	return private.CustomPriceValidateFunc(nil, value, badSources)
end

function private.NumberValidateFunc(input, value, range)
	local minValue, maxValue = strsplit(":", range)
	minValue = tonumber(minValue)
	maxValue = tonumber(maxValue)
	value = tonumber(value)
	if not value then
		return false, L["Invalid numeric value."]
	elseif value < minValue or value > maxValue then
		return false, format(L["Value must be between %d and %d."], minValue, maxValue)
	end
	return true
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateJustifyH(justifyH)
	return justifyH == "LEFT" or justifyH == "CENTER" or justifyH == "RIGHT"
end

function private.ValidateJustifyV(justifyV)
	return justifyV == "TOP" or justifyV == "MIDDLE" or justifyV == "BOTTOM"
end

function private.StateToTextColorKey(state)
	-- The text color should have maximum contrast with the input color, so set it to white/black based on the input color
	local colorKey = state.backgroundIsLight and "FULL_BLACK" or "FULL_WHITE"
	if state.disabled then
		return colorKey..(state.backgroundIsLight and "-DISABLED" or "+DISABLED")
	else
		return colorKey
	end
end

function private.StateToBackgroundInset(state)
	return (state.borderColor or not state.isValid) and BORDER_THICKNESS or 0
end

function private.StateToBackgroundColor(state)
	return state.disabled and "PRIMARY_BG_ALT" or state.backgroundColor
end

function private.StateToBorderShown(state)
	return state.borderColor or not state.isValid
end

function private.StateToBorderColor(state)
	return state.isValid and state.borderColor or "FEEDBACK_RED"
end
