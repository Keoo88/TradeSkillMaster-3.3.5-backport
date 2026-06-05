-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Event = LibTSMUI:From("LibTSMWoW"):Include("Service.Event")
local private = {}
local CLICK_COOLDOWN = 0.2
local CORNER_RADIUS = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local ActionButton = UIElements.Define("ActionButton", "Text")
ActionButton:_ExtendStateSchema()
	:UpdateFieldDefault("justifyH", "CENTER")
	:UpdateFieldDefault("font", "BODY_BODY2_MEDIUM")
	:AddStringField("defaultTextStr", "")
	:AddOptionalStringField("modifierTextStr")
	:AddOptionalStringField("pressedModifier")
	:AddBooleanField("disabled", false)
	:AddBooleanField("locked", false)
	:AddOptionalStringField("lockedColor")
	:AddBooleanField("clickCooldownActive", false)
	:AddBooleanField("mouseOver", false)
	:Commit()
ActionButton:_AddActionScripts("OnMouseDown", "OnMouseUp", "OnClick", "OnEnter", "OnLeave")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ActionButton:__init(name, isSecure)
	local frame = self:_CreateButton(nil, name, isSecure)
	self.__super:__init(frame)
	frame:TSMSetScript(isSecure and "PostClick" or "OnClick", self:__closure("_HandleClick"))
	frame:TSMSetScript("OnMouseDown", self:__closure("_HandleMouseDown"))
	frame:TSMSetScript("OnMouseUp", self:__closure("_HandleMouseUp"))
	frame:TSMSetScript("OnEnter", self:__closure("_HandleFrameEnter"))
	frame:TSMSetScript("OnLeave", self:__closure("_HandleFrameLeave"))

	self._background = self:_CreateRectangle()
	self._background:SetCornerRadius(CORNER_RADIUS)
	self._backgroundOverlay = self:_CreateRectangle(1)
	self._backgroundOverlay:SetCornerRadius(CORNER_RADIUS)
	self._backgroundOverlay:SetInset(1)

	self._clickCooldown = nil
	self._clickCooldownDisabled = false
	self._modifierText = {}
	self._onClickHandler = nil
	self._onEnterHandler = nil
	self._onLeaveHandler = nil
	self._onMouseDownHandler = nil
	self._onMouseUpHandler = nil
	self._isMouseDown = false
	self._manualRequired = false
end

function ActionButton:Acquire()
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()

	-- Set the text color
	self._state:PublisherForKeys("pressedModifier", "clickCooldownActive", "disabled", "locked", "mouseOver", "color")
		:MapWithFunction(private.StateToTextColorKey)
		:IgnoreDuplicates()
		:CallMethod(frame.text, "TSMSubscribeTextColor") -- FIXME: This conflicts with the publisher set by `Text`

	-- Set the background state
	self._state:PublisherForKeys("pressedModifier", "clickCooldownActive", "disabled", "locked", "mouseOver")
		:MapWithFunction(private.StateToBackgroundColorKey)
		:IgnoreNil()
		:IgnoreDuplicates()
		:CallMethod(self._background, "SubscribeColor")
	self._state:PublisherForKeys("pressedModifier", "clickCooldownActive", "disabled", "locked", "mouseOver")
		:MapWithFunction(private.StateToBackgroundColorKey)
		:MapToBoolean()
		:IgnoreDuplicates()
		:CallMethod(self._background, "SetShown")

	-- Set the background overlay texture state
	self._state:PublisherForKeys("pressedModifier", "clickCooldownActive", "disabled")
		:MapWithFunction(private.StateToBackgroundOverlayColorKey)
		:IgnoreNil()
		:IgnoreDuplicates()
		:CallMethod(self._backgroundOverlay, "SubscribeColor")
	self._state:PublisherForKeys("pressedModifier", "clickCooldownActive", "disabled")
		:MapWithFunction(private.StateToBackgroundOverlayColorKey)
		:MapToBoolean()
		:IgnoreDuplicates()
		:CallMethod(self._backgroundOverlay, "SetShown")

	-- Set the button state
	self._state:PublisherForKeys("pressedModifier", "clickCooldownActive", "disabled")
		:MapWithFunction(private.StateToEnabledValue)
		:IgnoreDuplicates()
		:CallMethod(frame, "TSMSetEnabled")
	self._state:PublisherForKeyChange("locked")
		:CallMethod(frame, "TSMSetHighlightLocked")

	-- Handle modifier updates and update the displayed text string
	self._state:PublisherForKeyChange("pressedModifier")
		:CallMethod(self, "_UpdateModifierText")
	self._state:Publisher()
		:MapWithKeyCoalesced("modifierTextStr", "defaultTextStr")
		:IgnoreDuplicates()
		:AssignToTableKey(self._state, "textStr")

	-- Set the OnUpdate script handler based on whether or not the cooldown is active
	self._state:PublisherForKeyChange("clickCooldownActive")
		:MapBooleanWithValues(self:__closure("_HandleFrameUpdate"), nil)
		:CallMethod(frame, "TSMSetOnUpdate")
end

function ActionButton:Release()
	wipe(self._modifierText)
	self._onClickHandler = nil
	self._onEnterHandler = nil
	self._onLeaveHandler = nil
	self._onMouseDownHandler = nil
	self._onMouseUpHandler = nil
	self._manualRequired = false
	self._isMouseDown = false
	self._clickCooldown = nil
	self._clickCooldownDisabled = false
	local frame = self:_GetBaseFrame()
	frame:Enable()
	frame:RegisterForClicks("LeftButtonUp")
	frame:UnlockHighlight()
	self.__super:Release()
end

---Set the text.
---@param text string|number The text
---@return ActionButton
function ActionButton:SetText(text)
	self.__super:SetText(text)
	self._state.defaultTextStr = self:GetText()
	return self
end

---Sets a script handler.
---@param script string The script to register for (currently only supports `OnClick`)
---@param handler function The script handler which will be called with the action button object followed by any
---arguments to the script
---@return ActionButton
function ActionButton:SetScript(script, handler)
	if script == "OnClick" then
		self._onClickHandler = handler
	elseif script == "OnEnter" then
		self._onEnterHandler = handler
	elseif script == "OnLeave" then
		self._onLeaveHandler = handler
	elseif script == "OnMouseDown" then
		self._onMouseDownHandler = handler
	elseif script == "OnMouseUp" then
		self._onMouseUpHandler = handler
	else
		error("Unknown ActionButton script: "..tostring(script))
	end
	return self
end

---Sets a script to propagate to the parent element.
---@param script string The script to propagate
---@return ActionButton
function ActionButton:PropagateScript(script)
	if script == "OnMouseDown" or script == "OnMouseUp" then
		self.__super:PropagateScript(script)
	else
		error("Cannot propagate ActionButton script: "..tostring(script))
	end
	return self
end

---Set whether or not the action button is disabled.
---@param disabled boolean Whether or not the action button should be disabled
---@return ActionButton
function ActionButton:SetDisabled(disabled)
	self._state.disabled = disabled and true or false
	return self
end

---Subscribes to a publisher to set the disabled state.
---@param publisher ReactivePublisher The publisher
---@return ActionButton
function ActionButton:SetDisabledPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetDisabled"))
	return self
end

---Set whether or not the highlight is locked.
---@param locked boolean Whether or not to lock the action button's highlight
---@param color? ThemeColorKey The locked highlight color as a theme color key
---@return ActionButton
function ActionButton:SetHighlightLocked(locked, color)
	self._state.locked = locked and true or false
	self._state.lockedColor = color
	return self
end

---Subscribes to a publisher to set whether or not the highlight is locked.
---@param publisher ReactivePublisher The publisher
---@return ActionButton
function ActionButton:SetHighlightLockedPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetHighlightLocked"))
	return self
end

---Set whether or not the action button is pressed.
---@param pressed boolean Whether or not the action button should be pressed
---@return ActionButton
function ActionButton:SetPressed(pressed)
	self._state.pressedModifier = pressed and private.GetModifierKey(IsShiftKeyDown(), IsControlKeyDown(), IsAltKeyDown()) or nil
	if self._clickCooldown then
		self._clickCooldown = nil
		self._state.clickCooldownActive = false
	end
	return self
end

---Subscribes to a publisher to set the pressed state.
---@param publisher ReactivePublisher The publisher
---@return ActionButton
function ActionButton:SetPressedPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetPressed"))
	return self
end

---Disables the default click cooldown to allow the button to be spammed (i.e. for macro-able buttons).
---@return ActionButton
function ActionButton:DisableClickCooldown()
	self._clickCooldownDisabled = true
	if self._clickCooldown then
		self._clickCooldown = nil
		self._state.clickCooldownActive = false
	end
	return self
end

---Change the text based on the modifier state.
---@param text string The text to set
---@param ... string The modifiers to set the text for (when they are all pressed together)
---@return ActionButton
function ActionButton:SetModifierText(text, ...)
	local key = private.GetModifierKey(private.ParseModifierKey(strjoin("-", ...)))
	assert(key and key ~= "NONE" and type(text) == "string")
	if not next(self._modifierText) then
		self:AddCancellable(Event.GetPublisher("MODIFIER_STATE_CHANGED")
			:UnpackAndCallMethod(self, "_HandleModifierStateChanged")
		)
	end
	self._modifierText[key] = text
	return self
end

---Set whether a manual click (vs. a macro) is required.
---@param required boolean Whether or not a manual click is required
---@return ActionButton
function ActionButton:SetRequireManualClick(required)
	self._manualRequired = required
	return self
end

---Subscribes to a publisher to set the required manual click state.
---@param publisher ReactivePublisher The publisher
---@return ActionButton
function ActionButton:SetRequireManualClickPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetRequireManualClick"))
	return self
end

---Click on the action button.
function ActionButton:Click()
	local frame = self:_GetBaseFrame()
	if frame:IsEnabled() and frame:IsVisible() then
		self:_HandleClick()
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ActionButton:_HandleModifierStateChanged()
	self:_UpdateModifierText(self._state.pressedModifier)
end

function ActionButton:_UpdateModifierText(pressedModifier)
	if not next(self._modifierText) then
		self._state.modifierTextStr = nil
		return
	end
	-- Find the key with the highest number of modifiers which is currently satisfied
	local maxRank, maxRankKey = nil, nil
	local currentShift, currentControl, currentAlt = nil, nil, nil
	if pressedModifier then
		currentShift, currentControl, currentAlt = private.ParseModifierKey(pressedModifier)
	else
		currentShift = IsShiftKeyDown()
		currentControl = IsControlKeyDown()
		currentAlt = IsAltKeyDown()
	end
	for key in pairs(self._modifierText) do
		-- Check if this modifier key is currently satisfied
		local hasShift, hasControl, hasAlt = private.ParseModifierKey(key)
		if (not hasShift or currentShift) and (not hasControl or currentControl) and (not hasAlt or currentAlt) then
			local rank = select("#", strsplit("-", key))
			if rank > (maxRank or 0) then
				maxRank = rank
				maxRankKey = key
			else
				assert(rank ~= maxRank)
			end
		end
	end
	self._state.modifierTextStr = maxRankKey and self._modifierText[maxRankKey] or nil
end

function ActionButton.__private:_HandleClick()
	if not self._acquired then
		return
	elseif self._manualRequired and not self._isMouseDown then
		return
	end
	self._isMouseDown = false
	if not self._clickCooldownDisabled then
		self._clickCooldown = CLICK_COOLDOWN
		self._state.clickCooldownActive = true
	end
	self:_SendActionScript("OnClick")
	if self._onClickHandler then
		self:_onClickHandler()
	end
end

function ActionButton.__private:_HandleMouseDown()
	self._isMouseDown = true
	self:_SendActionScript("OnMouseDown")
	if self._onMouseDownHandler then
		self:_onMouseDownHandler()
	end
end

function ActionButton.__private:_HandleMouseUp()
	self:_SendActionScript("OnMouseUp")
	if self._onMouseUpHandler then
		self:_onMouseUpHandler()
	end
end

function ActionButton.__private:_HandleFrameEnter()
	self._state.mouseOver = true
	self:_SendActionScript("OnEnter")
	if self._onEnterHandler then
		self:_onEnterHandler()
	end
end

function ActionButton.__private:_HandleFrameLeave()
	self._state.mouseOver = false
	if not self:IsVisible() then
		return
	end
	self:_SendActionScript("OnLeave")
	if self._onLeaveHandler then
		self:_onLeaveHandler()
	end
end

function ActionButton.__private:_HandleFrameUpdate(frame, elapsed)
	self._clickCooldown = self._clickCooldown - elapsed
	if self._clickCooldown <= 0 then
		self._clickCooldown = nil
		self._state.clickCooldownActive = false
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetModifierKey(hasShift, hasControl, hasAlt)
	if hasShift and hasControl and hasAlt then
		return "SHIFT-CTRL-ALT"
	elseif hasShift and hasControl then
		return "SHIFT-CTRL"
	elseif hasShift and hasAlt then
		return "SHIFT-ALT"
	elseif hasShift then
		return "SHIFT"
	elseif hasControl and hasAlt then
		return "CTRL-ALT"
	elseif hasControl then
		return "CTRL"
	elseif hasAlt then
		return "ALT"
	else
		return "NONE"
	end
end

function private.ParseModifierKey(key)
	local hasShift, hasControl, hasAlt, hasNone = false, false, false, false
	for modifier in String.SplitIterator(key, "-") do
		if modifier == "SHIFT" then
			assert(not hasShift and not hasNone)
			hasShift = true
		elseif modifier == "CTRL" then
			assert(not hasControl and not hasNone)
			hasControl = true
		elseif modifier == "ALT" then
			assert(not hasAlt and not hasNone)
			hasAlt = true
		elseif modifier == "NONE" then
			assert(not hasShift and not hasControl and not hasAlt and not hasNone)
			hasNone = true
		else
			error("Invalid modifier: "..tostring(modifier))
		end
	end
	return hasShift, hasControl, hasAlt
end

function private.StateToTextColorKey(state)
	if state.pressedModifier or state.clickCooldownActive then
		return "FULL_BLACK"
	elseif state.disabled then
		return "ACTIVE_BG_ALT"
	elseif state.locked then
		return "FULL_BLACK"
	elseif state.mouseOver then
		return "TEXT"
	else
		return state.color
	end
end

function private.StateToBackgroundColorKey(state)
	if state.pressedModifier or state.clickCooldownActive then
		return "INDICATOR"
	elseif state.disabled then
		return "ACTIVE_BG"
	elseif state.locked then
		return state.lockedColor or "ACTIVE_BG+HOVER"
	elseif state.mouseOver then
		return "ACTIVE_BG+HOVER"
	else
		return "ACTIVE_BG"
	end
end

function private.StateToBackgroundOverlayColorKey(state)
	if not state.pressedModifier and not state.clickCooldownActive and state.disabled then
		return "PRIMARY_BG_ALT"
	else
		return nil
	end
end

function private.StateToEnabledValue(state)
	return not state.disabled and not state.pressedModifier and not state.clickCooldownActive
end
