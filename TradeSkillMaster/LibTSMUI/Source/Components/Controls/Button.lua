-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local ICON_SPACING = 4
local BACKGROUND_POINTS = {
	default = {
		{ "TOPLEFT" },
		{ "BOTTOMRIGHT" },
	},
	textureAtlas = {
		{ "CENTER" },
	},
}
local ITEM_HIGHLIGHT_TEXTURE = 130718


-- ============================================================================
-- Element Definition
-- ============================================================================

local Button = UIElements.Define("Button", "Text")
Button:_ExtendStateSchema()
	:UpdateFieldDefault("justifyH", "CENTER")
	:UpdateFieldDefault("font", "BODY_BODY1")
	:AddOptionalStringField("background")
	:AddStringField("highlightColor", "TRANSPARENT", Theme.IsValidColor)
	:AddOptionalNumberField("highlightTexture")
	:AddBooleanField("enabled", true)
	:AddOptionalStringField("iconTexturePack", TextureAtlas.IsValid)
	:AddOptionalStringField("iconPosition", private.ValidateIconPosition)
	:AddStringField("textAndIconColor", "TEXT")
	:AddBooleanField("locked", false)
	:Commit()
Button:_AddActionScripts("OnClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Button:__init()
	local frame = self:_CreateButton()
	self.__super:__init(frame)
	frame:TSMSetScript("OnClick", self:__closure("_HandleClick"))

	frame.backgroundTexture = self:_CreateTexture(frame, "BACKGROUND")

	-- Create the highlight
	frame.highlight = self:_CreateTexture(frame, "HIGHLIGHT")
	frame.highlight:SetAllPoints()
	-- 3.3.5a: a texture placed on the "HIGHLIGHT" draw layer is NOT auto-gated by mouse-over on
	-- this client (that gating only applies to a texture registered via SetHighlightTexture, and
	-- passing a texture OBJECT to that API does not work here). Left alone, the highlight stays
	-- visible at rest, so every button/tab looks permanently hovered. Manage it manually instead:
	-- hidden by default, shown on mouse-over, kept shown while locked. HookScript is additive, so
	-- it does NOT clobber the tooltip OnEnter/OnLeave handlers set via ScriptWrapper/SetScript.
	frame.highlight:Hide()
	frame._tsmHighlightLocked = false
	frame:HookScript("OnEnter", function()
		frame.highlight:Show()
	end)
	frame:HookScript("OnLeave", function()
		if not frame._tsmHighlightLocked then
			frame.highlight:Hide()
		end
	end)

	-- Create the icon
	frame.icon = self:_CreateTexture(frame, "ARTWORK")

	self._onClickHandler = nil
end

function Button:Acquire()
	local frame = self:_GetBaseFrame()
	frame:RegisterForClicks("LeftButtonUp")
	frame:SetHitRectInsets(0, 0, 0, 0)

	self.__super:Acquire()

	-- Update the textAndIconColor
	self._state:PublisherForKeys("enabled", "color")
		:MapWithFunction(private.StateToTextColor)
		:IgnoreDuplicates()
		:AssignToTableKey(self._state, "textAndIconColor")

	-- Set the button state
	self._state:PublisherForKeyChange("enabled")
		:CallMethod(frame, "TSMSetEnabled")
	-- 3.3.5a: drive the locked (selected) highlight manually since we no longer use the native
	-- highlight texture (see __init). Locked => always show; unlocked => hide unless moused over.
	self._state:PublisherForKeyChange("locked")
		:CallFunction(function(locked)
			frame._tsmHighlightLocked = locked and true or false
			if frame._tsmHighlightLocked then
				frame.highlight:Show()
			elseif not (frame.IsMouseOver and frame:IsMouseOver()) then
				frame.highlight:Hide()
			end
		end)

	-- Set whether or not the background is visible
	self._state:PublisherForKeyChange("background")
		:MapToBoolean()
		:CallMethod(frame.backgroundTexture, "TSMSetShown")

	-- Set the background texture
	self._state:PublisherForKeyChange("background")
		:IgnoreNil()
		:MapWithFunction(private.BackgroundToTexture)
		:CallMethod(frame.backgroundTexture, "TSMSetTextureAndCoord")

	-- Set the background color
	self._state:PublisherForKeyChange("background")
		:IgnoreNil()
		:MapWithFunction(private.BackgroundToColor)
		:CallMethod(frame.backgroundTexture, "TSMSubscribeVertexColor")

	-- Set the background size
	self._state:PublisherForKeyChange("background")
		:IgnoreNil()
		:MapWithFunction(private.BackgroundToSize)
		:IgnoreNil()
		:CallMethod(frame.backgroundTexture, "TSMSetSize")

	-- Set the background anchors
	self._state:PublisherForKeyChange("background")
		:IgnoreNil()
		:MapWithFunction(private.BackgroundToPoints)
		:CallMethod(frame.backgroundTexture, "TSMSetPoints")

	-- Set the highlight texture
	-- Only one of highlightColor / highlightTexture is in use at a time
	self._state:PublisherForKeyChange("highlightColor")
		:CallMethod(frame.highlight, "TSMSubscribeColorTexture")
	self._state:PublisherForKeyChange("highlightTexture")
		:CallMethod(frame.highlight, "TSMSetTextureAndCoord")

	-- Set the text color
	self._state:PublisherForKeyChange("textAndIconColor")
		:CallMethod(frame.text, "TSMSubscribeTextColor")

	-- Set whether or not the icon is visible
	self._state:PublisherForKeyChange("iconTexturePack")
		:MapToBoolean()
		:IgnoreDuplicates()
		:CallMethod(frame.icon, "TSMSetShown")

	-- Set the icon texture
	self._state:PublisherForKeyChange("iconTexturePack")
		:IgnoreNil()
		:CallMethod(frame.icon, "TSMSetTextureAndSize")

	-- Set the icon vertex color
	self._state:PublisherForKeyChange("textAndIconColor")
		:CallMethod(frame.icon, "TSMSubscribeVertexColor")

	-- Redraw to update text and icon layout when needed
	self._state:PublisherForKeys("iconTexturePack", "iconPosition", "justifyH", "textStr")
		:MapToValue(nil)
		:CallMethod(self, "Draw")
end

function Button:Release()
	self._onClickHandler = nil
	self.__super:Release()
end

---Sets the background of the button.
---@param background? string|ThemeColorKey|number Either a texture pack string, itemString, WoW file id, theme color key, or nil
---@param highlightEnabled boolean Whether or not the highlight is enabled
---@return Button
function Button:SetBackground(background, highlightEnabled)
	assert(background == nil or type(background) == "string" or type(background) == "number")
	assert(highlightEnabled == nil or type(highlightEnabled) == "boolean")
	if not highlightEnabled then
		self._state.highlightColor = "TRANSPARENT"
	end
	self._state.background = background ~= nil and tostring(background) or nil
	self._state.highlightTexture = nil
	if highlightEnabled then
		self._state.highlightColor = background.."+HOVER"
	end
	return self
end

---Subscribes to a publisher to set the background.
---@param publisher ReactivePublisher The publisher
---@return Button
function Button:SetBackgroundPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetBackground"))
	return self
end

---Sets the background of the button and enables a WoW-style item highlight.
---@param background? number|string A WoW file id, itemString, or nil
---@return Button
function Button:SetBackgroundWithItemHighlight(background)
	assert(background == nil or type(background) == "number" or type(background) == "string")
	self._state.background = background and tostring(background) or nil
	self._state.highlightTexture = background and ITEM_HIGHLIGHT_TEXTURE or nil
	return self
end

---Sets the background and size of the button based on a texture pack string.
---@param texturePack string A texture pack string to set the background to and base the size on
---@return Button
function Button:SetBackgroundAndSize(texturePack)
	self:SetBackground(texturePack)
	self:SetSize(TextureAtlas.GetSize(texturePack))
	return self
end

---Sets the icon that shows within the button.
---@param texturePack? string A texture pack string to set the icon and its size to
---@param position? string The position of the icon
---@return Button
function Button:SetIcon(texturePack, position)
	assert((texturePack and position) or (not texturePack and not position))
	self._state.iconPosition = position
	self._state.iconTexturePack = texturePack
	return self
end

---Set whether or not the button is disabled.
---@param disabled boolean Whether or not the button should be disabled
---@return Button
function Button:SetDisabled(disabled)
	self._state.enabled = not disabled and true or false
	return self
end

---Subscribes to a publisher to set whether or not the button is disabled.
---@param publisher ReactivePublisher The publisher
---@return Button
function Button:SetDisabledPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetDisabled"))
	return self
end

---Registers the button for drag events.
---@param button string The mouse button to register for drag events from
---@return Button
function Button:RegisterForDrag(button)
	self:_GetBaseFrame():RegisterForDrag(button)
	return self
end

---Click on the button.
function Button:Click()
	self:_GetBaseFrame():Click()
end

---Enable right-click events for the button.
---@return Button
function Button:EnableRightClick()
	self:_GetBaseFrame():RegisterForClicks("LeftButtonUp", "RightButtonUp")
	return self
end

---Set the hit rectangle insets for the button.
---@param left number How much the left side of the hit rectangle is inset
---@param right number How much the right side of the hit rectangle is inset
---@param top number How much the top side of the hit rectangle is inset
---@param bottom number How much the bottom side of the hit rectangle is inset
---@return Button
function Button:SetHitRectInsets(left, right, top, bottom)
	self:_GetBaseFrame():SetHitRectInsets(left, right, top, bottom)
	return self
end

---Set whether or not to lock the button's highlight.
---@param locked boolean Whether or not to lock the button's highlight
---@return Button
function Button:SetHighlightLocked(locked)
	self._state.locked = locked and true or false
	return self
end

---Subscribes to a publisher to set the highlight locked state.
---@param publisher ReactivePublisher The publisher
---@return Button
function Button:SetHighlightLockedPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetHighlightLocked"))
	return self
end

---Sets a script handler.
---@param script string The script to register for (currently only supports `OnClick`)
---@param handler function The script handler which will be called with the button object followed by any
---arguments to the script
---@return Button
function Button:SetScript(script, handler)
	if script == "OnClick" then
		self._onClickHandler = handler
	else
		self.__super:SetScript(script, handler)
	end
	return self
end

function Button:Draw()
	local frame = self:_GetBaseFrame()
	frame.text:Show()
	self.__super:Draw()

	-- Layout the text and icon
	if self._state.iconTexturePack then
		frame.icon:ClearAllPoints()
		local iconWidth = TextureAtlas.GetWidth(self._state.iconTexturePack) + ICON_SPACING
		if self._state.iconPosition == "LEFT" then
			frame.icon:SetPoint("RIGHT", frame.text, "LEFT", -ICON_SPACING, 0)
			frame.text:ClearAllPoints()
			if self._state.justifyH == "CENTER" then
				local xOffset = iconWidth / 2
				frame.text:SetPoint("TOP", xOffset, -self:_GetPadding("TOP"))
				frame.text:SetPoint("BOTTOM", xOffset, self:_GetPadding("BOTTOM"))
				frame.text:SetWidth(self:GetStringWidth())
			elseif self._state.justifyH == "LEFT" then
				frame.text:SetPoint("TOPLEFT", iconWidth + self:_GetPadding("LEFT"), -self:_GetPadding("TOP"))
				frame.text:SetPoint("BOTTOMRIGHT", -self:_GetPadding("RIGHT"), self:_GetPadding("BOTTOM"))
			else
				error("Unsupported justifyH: "..tostring(self._state.justifyH))
			end
		elseif self._state.iconPosition == "LEFT_NO_TEXT" then
			frame.icon:SetPoint("LEFT", self:_GetPadding("LEFT"), 0)
			frame.text:ClearAllPoints()
			frame.text:Hide()
		elseif self._state.iconPosition == "CENTER" then
			frame.icon:SetPoint("CENTER")
			frame.text:ClearAllPoints()
			frame.text:Hide()
		elseif self._state.iconPosition == "RIGHT" then
			frame.icon:SetPoint("RIGHT", -self:_GetPadding("RIGHT"), 0)
			local xOffset = iconWidth
			frame.text:ClearAllPoints()
			-- TODO: support non-left-aligned text
			frame.text:SetPoint("TOPLEFT", self:_GetPadding("LEFT"), -self:_GetPadding("TOP"))
			frame.text:SetPoint("BOTTOMRIGHT", -xOffset, self:_GetPadding("BOTTOM"))
		else
			error("Invalid iconPosition: "..tostring(self._state.iconPosition))
		end
	else
		frame.text:ClearAllPoints()
		frame.text:SetPoint("TOPLEFT", self:_GetPadding("LEFT"), -self:_GetPadding("TOP"))
		frame.text:SetPoint("BOTTOMRIGHT", -self:_GetPadding("RIGHT"), self:_GetPadding("BOTTOM"))
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Button:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth then
		return self:GetStringWidth() + (self._state.iconTexturePack and TextureAtlas.GetWidth(self._state.iconTexturePack) or 0)
	else
		return self.__super:_GetMinimumDimension(dimension)
	end
end

function Button.__private:_HandleClick(_, mouseButton)
	self:_SendActionScript("OnClick", mouseButton)
	if self._onClickHandler then
		self:_onClickHandler(mouseButton)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateIconPosition(position)
	return position == "LEFT" or position == "LEFT_NO_TEXT" or position == "CENTER" or position == "RIGHT"
end

function private.BackgroundToTexture(background)
	if TextureAtlas.IsValid(background) then
		return background
	elseif strmatch(background, "^[ip]:%d+") then
		return ItemInfo.GetTexture(background)
	elseif tonumber(background) then
		-- this is a wow file id
		return tonumber(background)
	elseif strmatch(background, "^[Ii]nterface[\\/]") then
		-- 3.3.5 string texture path
		return background
	else
		-- We'll use the vertex color to color a white texture
		return "Interface\\Buttons\\WHITE8X8"
	end
end

function private.BackgroundToColor(background)
	local isTextureKey = TextureAtlas.IsValid(background)
	local textureColorKey = isTextureKey and TextureAtlas.GetColorKey(background)
	if textureColorKey then
		return textureColorKey
	elseif isTextureKey or strmatch(background, "^[ip]:%d+") or tonumber(background) or strmatch(background, "^[Ii]nterface[\\/]") then
		return "FULL_WHITE"
	else
		return background
	end
end

function private.BackgroundToSize(background)
	return TextureAtlas.IsValid(background) and background or nil
end

function private.BackgroundToPoints(background)
	return TextureAtlas.IsValid(background) and BACKGROUND_POINTS.textureAtlas or BACKGROUND_POINTS.default
end

function private.StateToTextColor(state)
	return state.enabled and state.color or "ACTIVE_BG_ALT"
end
