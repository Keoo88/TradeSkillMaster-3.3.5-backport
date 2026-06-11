-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local WidgetExtensions = LibTSMUI:Init("Util.WidgetExtensions")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local ScriptWrapper = LibTSMUI:From("LibTSMWoW"):Include("API.ScriptWrapper")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local private = {
	debugObject = {},
	cancellables = {},
	colorTemp1 = CreateColor(0, 0, 0, 1),
	colorTemp2 = CreateColor(0, 0, 0, 1),
}
local FRAME_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8" }

---@alias ScrollFrameExtended ScrollFrame|BaseExtension



-- ============================================================================
-- BaseExtension Methods
-- ============================================================================

---@class BaseExtension: Region
local BaseExtension = {}

---Sets whether or not the widget is shown.
---@param shown boolean
function BaseExtension:TSMSetShown(shown)
	if shown then
		self:Show()
	else
		self:Hide()
	end
end

---Sets the size of the widget.
---@param width number
---@param height number
function BaseExtension:TSMSetSize(width, height)
	self:SetWidth(width)
	self:SetHeight(height)
end

---Sets the points of the widget.
---@param points table A list of points that each unpack into `:SetPoint(...)` arguments
function BaseExtension:TSMSetPoints(points)
	self:ClearAllPoints()
	for _, point in ipairs(points) do
		self:SetPoint(unpack(point))
	end
end

---Sets a script handler.
---@param script name The script name
---@param handler? function The script handler (or nil to clear the script)
---@param obj? any The object to pass as the first parameter of the script handler instead of the widget
function BaseExtension:TSMSetScript(script, handler, obj)
	if type(handler) == "function" then
		ScriptWrapper.Set(self, script, handler, obj, private.debugObject[self])
	elseif handler == nil then
		ScriptWrapper.Clear(self, script)
	else
		error("Invalid handler: "..tostring(handler))
	end
end

---Sets the script handler to simply propogate the script to the parent.
---@param script string The script which should be propagated
---@param obj? table The object to pass to the handler as the first parameter (instead of frame)
function BaseExtension:TSMSetPropagate(script, obj)
	ScriptWrapper.SetPropagate(self, script, obj)
end

---Sets the OnUpdate handler.
---@param handler? function The OnUpdate script handler (or nil to clear the script)
---@param obj? any The object to pass as the first parameter of the script handler instead of the widget
function BaseExtension:TSMSetOnUpdate(handler, obj)
	self:TSMSetScript("OnUpdate", handler, obj)
end

---Sets the object used for debugging purposes to represent this widget.
---@param obj table The object which is converted to a string for debugging purposes
function BaseExtension:TSMSetDebugObject(obj)
	private.debugObject[self] = obj
end

---Sets the table used to store cancellables.
---@param tbl table The table
function BaseExtension:TSMSetCancellablesTable(tbl)
	assert(not private.cancellables[self] and tbl)
	private.cancellables[self] = tbl
end

---@private
function BaseExtension:_TSMSetOrUpdateCancellable(key, publisher)
	key = tostring(self)..":"..key
	assert(private.cancellables[self])
	if private.cancellables[self][key] then
		private.cancellables[self][key]:Cancel()
	end
	private.cancellables[self][key] = publisher:Stored()
end



-- ============================================================================
-- FrameExtended Methods
-- ============================================================================

---@class FrameExtended: BaseExtension, Frame
local FrameExtended = {}

---@private
function FrameExtended:_TSMSetBackdropColor(color)
	self:SetBackdropColor(color:GetFractionalRGBA())
end

---Subscribes the backdrop color.
---@param color ThemeColorKey The color key
function FrameExtended:TSMSubscribeBackdropColor(color)
	self.__debug.backdropColor = color
	self:SetBackdrop(FRAME_BACKDROP)
	self:_TSMSetOrUpdateCancellable("backdropColor", Theme.GetPublisher(color)
		:CallMethod(self, "_TSMSetBackdropColor")
	)
end



-- ============================================================================
-- ButtonExtended Methods
-- ============================================================================

---@class ButtonExtended: BaseExtension, Button
local ButtonExtended = {}

---Sets whether or not the button is enabled.
---@param enabled boolean
function ButtonExtended:TSMSetEnabled(enabled)
	self.__debug.enabled = enabled
	if enabled then
		self:Enable()
	else
		self:Disable()
	end
end

---Sets whether or not the highlight is locked.
---@param locked boolean
function ButtonExtended:TSMSetHighlightLocked(locked)
	self.__debug.highlightLocked = locked
	if locked then
		self:LockHighlight()
	else
		self:UnlockHighlight()
	end
end



-- ============================================================================
-- TextureExtended Methods
-- ============================================================================

---@class TextureExtended: BaseExtension, Texture
local TextureExtended = {}

---Sets the color texture.
---@param color Color|ThemeColorKey The color key
function TextureExtended:TSMSetColorTexture(color)
	if type(color) == "string" then
		self.__debug.colorTexture = color
		color = Theme.GetColor(color)
	end
	self:SetColorTexture(color:GetFractionalRGBA())
end

---Subscribes the color texture.
---@param color ThemeColorKey The color key
function TextureExtended:TSMSubscribeColorTexture(color)
	self.__debug.colorTexture = color
	self:_TSMSetOrUpdateCancellable("colorTexture", Theme.GetPublisher(color)
		:CallMethod(self, "TSMSetColorTexture")
	)
end

---Sets the vertex color.
---@param color Color|ThemeColorKey The color key
function TextureExtended:TSMSetVertexColor(color)
	if type(color) == "string" then
		self.__debug.vertexColor = color
		color = Theme.GetColor(color)
	end
	self:SetVertexColor(color:GetFractionalRGBA())
end

---Subscribes the vertex color.
---@param color ThemeColorKey The color key
function TextureExtended:TSMSubscribeVertexColor(color)
	self.__debug.vertexColor = color
	self:_TSMSetOrUpdateCancellable("vertexColor", Theme.GetPublisher(color)
		:CallMethod(self, "TSMSetVertexColor")
	)
end

---Sets the texture based on a texture atlas key.
---@param atlasKey string The texture atlas key
function TextureExtended:TSMSetTexture(atlasKey)
	self.__debug.texture = atlasKey
	TextureAtlas.SetTexture(self, atlasKey)
end

---Sets the texture and size based on a texture atlas key.
---@param atlasKey string The texture atlas key
function TextureExtended:TSMSetTextureAndSize(atlasKey)
	self.__debug.texture = atlasKey
	TextureAtlas.SetTextureAndSize(self, atlasKey)
end

---Sets the texture and coord based on a texture atlas key or texture path.
---@param value string|number The texture atlas key, texture path, or texture ID
function TextureExtended:TSMSetTextureAndCoord(value)
	if type(value) == "string" and TextureAtlas.IsValid(value) then
		self.__debug.texture = value
		TextureAtlas.SetTexture(self, value)
	else
		self.__debug.texture = nil
		self:SetTexture(value)
		self:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	end
end

---Sets a vertical gradient.
---@param color Color The color
---@param minAlpha number The min color alpha
---@param maxAlpha number The max color alpha
function TextureExtended:TSMSetVerticalGradient(color, minAlpha, maxAlpha)
	local r, g, b = color:GetFractionalRGBA()
	if not ClientInfo.IsRetail() and self.SetGradientAlpha then
		-- 3.3.5a: Texture:SetGradient takes numeric r,g,b (no alpha) on this client, so passing
		-- Color objects produced an opaque black fill that covered the gridlines under the graph
		-- line. The legacy SetGradientAlpha(orientation, r,g,b,a, r,g,b,a) supports per-stop alpha.
		self:SetGradientAlpha("VERTICAL", r, g, b, minAlpha, r, g, b, maxAlpha)
	else
		private.colorTemp1:SetRGBA(r, g, b, minAlpha)
		private.colorTemp2:SetRGBA(r, g, b, maxAlpha)
		self:SetGradient("VERTICAL", private.colorTemp1, private.colorTemp2)
	end
end

---Sets the size based on a texture atlas key or width / height.
---@param widthOrAtlasKey number|string The width or texture atlas key
---@param height? number The height (if and only if `width` is supplied as the first argument)
function TextureExtended:TSMSetSize(widthOrAtlasKey, height)
	if type(widthOrAtlasKey) == "string" then
		assert(height == nil)
		TextureAtlas.SetSize(self, widthOrAtlasKey)
	else
		self:SetWidth(widthOrAtlasKey)
		self:SetHeight(height)
	end
end



-- ============================================================================
-- FontStringExtended Methods
-- ============================================================================

---@class FontStringExtended: BaseExtension, FontString
local FontStringExtended = {}

---Sets the text color.
---@param color Color|ThemeColorKey The color key
function FontStringExtended:TSMSetTextColor(color)
	if type(color) == "string" then
		self.__debug.textColor = color
		color = Theme.GetColor(color)
	end
	self:SetTextColor(color:GetFractionalRGBA())
end

---Sbuscribes the text color.
---@param color ThemeColorKey The color key
function FontStringExtended:TSMSubscribeTextColor(color)
	self.__debug.textColor = color
	self:_TSMSetOrUpdateCancellable("textColor", Theme.GetPublisher(color)
		:CallMethod(self, "TSMSetTextColor")
	)
end

---Gets the width of the string ignoring the region's width constraint.
---@return number
function FontStringExtended:TSMGetUnboundedStringWidth()
	if self.GetUnboundedStringWidth then
		return self:GetUnboundedStringWidth()
	end
	-- 3.3.5: FontString has no GetUnboundedStringWidth; GetStringWidth returns the
	-- unwrapped width of the full string, which is the closest equivalent
	return self:GetStringWidth()
end

---Sets the font.
---@param font string|FontObjectValue The font key or object
function FontStringExtended:TSMSetFont(font)
	if type(font) == "string" then
		self.__debug.font = font
		font = Theme.GetFont(font)
	end
	self:SetFont(font:GetWowFont())
end



-- ============================================================================
-- AnimationGroupExtended Methods
-- ============================================================================

---@class AnimationGroupExtended: BaseExtension, AnimationGroup
local AnimationGroupExtended = {}

---Sets whether or not the animation group is playing.
---@param playing boolean
function AnimationGroupExtended:TSMSetPlaying(playing)
	if playing == self:IsPlaying() then
		return
	end
	if playing then
		self:Play()
	else
		self:Stop()
	end
end



-- ============================================================================
-- EditBoxExtended Methods
-- ============================================================================

---@class EditBoxExtended: BaseExtension, EditBox
local EditBoxExtended = {}

---Sets whether or not the edit box is enabled.
---@param enabled boolean
function EditBoxExtended:TSMSetEnabled(enabled)
	self.__debug.enabled = enabled
	if self.Enable and self.Disable then
		if enabled then
			self:Enable()
		else
			self:Disable()
		end
	else
		-- 3.3.5: EditBox has no native Enable/Disable; emulate via keyboard/mouse input
		self:EnableKeyboard(enabled)
		self:EnableMouse(enabled)
		if not enabled then
			self:ClearFocus()
		end
	end
end

---Sets the text color.
---@param color Color|ThemeColorKey The color value or key
function EditBoxExtended:TSMSetTextColor(color)
	if type(color) == "string" then
		self.__debug.textColor = color
		color = Theme.GetColor(color)
	end
	self:SetTextColor(color:GetFractionalRGBA())
end

---Subscribes the text color.
---@param color ThemeColorKey The color key
function EditBoxExtended:TSMSubscribeTextColor(color)
	self.__debug.textColor = color
	self:_TSMSetOrUpdateCancellable("textColor", Theme.GetPublisher(color)
		:CallMethod(self, "TSMSetTextColor")
	)
end

---Sets the highlight color.
---@param color Color|ThemeColorKey The color value or key
function EditBoxExtended:TSMSetHighlightColor(color)
	if type(color) == "string" then
		self.__debug.highlightColor = color
		color = Theme.GetColor(color)
	end
	self:SetTextColor(color:GetFractionalRGBA())
end

---Subscribes the highlight color.
---@param color ThemeColorKey The color key
function EditBoxExtended:TSMSubscribeHighlightColor(color)
	self.__debug.highlightColor = color
	self:_TSMSetOrUpdateCancellable("highlightColor", Theme.GetPublisher(color)
		:CallMethod(self, "TSMSetHighlightColor")
	)
end

---Sets the font.
---@param font string|FontObjectValue The font key or object
function EditBoxExtended:TSMSetFont(font)
	if type(font) == "string" then
		self.__debug.font = font
		font = Theme.GetFont(font)
	end
	self:SetFont(font:GetWowFont())
end

---Sets whether or not the edit box is focused.
---@param focused boolean
function EditBoxExtended:TSMSetFocused(focused)
	if focused then
		self:SetFocus()
	else
		self:ClearFocus()
	end
end

---Sets whether or not the edit box is fully highlighted.
---@param highlighted boolean
function EditBoxExtended:TSMSetAllHighlighted(highlighted)
	if highlighted then
		self:HighlightText(0, -1)
	else
		self:HighlightText(0, 0)
	end
end



-- ============================================================================
-- SliderExtended Methods
-- ============================================================================

---@class SliderExtended: BaseExtension, Slider
local SliderExtended = {}

---Creates a thumb texture and adds it to the slider.
function SliderExtended:TSMCreateThumbTexture(color)
	local thumb = WidgetExtensions.CreateTexture(self)
	self:SetThumbTexture(thumb)
	-- Do NOT anchor the thumb with SetPoint: on 3.3.5 the Slider widget positions the thumb
	-- itself based on the current value. An explicit SetPoint("CENTER") adds a conflicting
	-- anchor that pins the thumb in place, which freezes it and prevents the native thumb-drag
	-- from changing the value (mouse-wheel still works because it calls SetValue directly).
	local orientation = self:GetOrientation()
	if orientation == "HORIZONTAL" then
		thumb:SetHeight(Theme.GetScrollbarWidth())
	elseif orientation == "VERTICAL" then
		thumb:SetWidth(Theme.GetScrollbarWidth())
	else
		error("Invalid orientation: "..tostring(orientation))
	end
end

---Sets the thumb color texture.
---@param color ThemeColorKey The color key
function SliderExtended:TSMSetThumbColorTexture(color)
	self:GetThumbTexture():TSMSetColorTexture(color)
end

---Updates the thumb length for use in a scroll frame.
---@param contentLength number The length of the content
---@param visibleLength number The legnth of the visible area
function SliderExtended:TSMUpdateThumbLength(contentLength, visibleLength)
	-- Arbitrary minimum length
	local minLength = 25
	-- The maximum length of the scrollbar is half the total visible length
	local maxLength = visibleLength / 2
	if minLength >= maxLength or visibleLength >= contentLength then
		return maxLength
	end

	-- Calculate the ratio of our total content length to the visible length (capped at 10)
	local ratio = min(contentLength / visibleLength, 10)
	assert(ratio >= 1)
	-- Calculate the appropriate scroll bar length based on the ratio (which is between 1 and 10)
	local length = Math.Scale(ratio, 1, 10, maxLength, minLength)

	-- Set the appropriate dimension
	local orientation = self:GetOrientation()
	local thumb = self:GetThumbTexture()
	if orientation == "HORIZONTAL" then
		thumb:SetWidth(length)
	elseif orientation == "VERTICAL" then
		thumb:SetHeight(length)
	else
		error("Invalid orientation: "..tostring(orientation))
	end
end



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a frame with extensions.
---@param name? string The global name
---@param parent? Frame The parent WoW UI frame
---@return FrameExtended
function WidgetExtensions.CreateFrame(name, parent)
	return private.WithExtension(CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil), FrameExtended)
end

---Creates a scroll frame with extensions.
---@param name? string The global name
---@param parent? Frame The parent WoW UI frame
---@return ScrollFrameExtended
function WidgetExtensions.CreateScrollFrame(name, parent)
	return private.WithExtension(CreateFrame("ScrollFrame", name, parent, nil))
end

---Creates a button with extensions.
---@param name? string The global name
---@param parent? Frame The parent WoW UI frame
---@param template? string The template type
---@return ButtonExtended
function WidgetExtensions.CreateButton(name, parent, template)
	return private.WithExtension(CreateFrame("Button", name, parent, template), ButtonExtended)
end

---Creates an edit box with extensions.
---@param name? string The global name
---@param parent? Frame The parent WoW UI frame
---@return EditBoxExtended
function WidgetExtensions.CreateEditBox(name, parent)
	return private.WithExtension(CreateFrame("EditBox", name, parent, nil), EditBoxExtended)
end

---Creates a slider with extensions.
---@param parent Frame The parent frame
---@return SliderExtended
function WidgetExtensions.CreateSlider(parent)
	return private.WithExtension(CreateFrame("Slider", nil, parent, nil), SliderExtended)
end

---Creates a texture with extensions.
---@param parent Frame The parent frame
---@param name? string The global name
---@return FontStringExtended
function WidgetExtensions.CreateFontString(parent, name)
	return private.WithExtension(parent:CreateFontString(name), FontStringExtended)
end

---Creates a texture with extensions.
---@param parent Frame The parent frame
---@param layer? DrawLayer The layer (defaults to "ARTWORK")
---@param subLayer? number The sub layer
---@param name? string The global name
---@return TextureExtended
function WidgetExtensions.CreateTexture(parent, layer, subLayer, name)
	layer = layer or "ARTWORK"
	-- On 3.3.5a the texture drawSubLevel argument (4th param of CreateTexture, added in
	-- Cataclysm 4.0) is not honored, so textures which rely on a negative sublevel to draw
	-- below others in the same layer (e.g. ListRow hover/selected highlights at ARTWORK -1
	-- vs the row action icons at ARTWORK 0) render in undefined order and can cover them --
	-- the icons become invisible while still being clickable. Map negative ARTWORK sublevels
	-- onto real lower draw layers, which the client always respects. Passing subLayer too is
	-- harmless on clients that do support it.
	if not ClientInfo.IsRetail() and layer == "ARTWORK" and subLayer and subLayer < 0 then
		layer = subLayer <= -2 and "BACKGROUND" or "BORDER"
	end
	return private.WithExtension(parent:CreateTexture(name, layer, nil, subLayer), TextureExtended)
end

---Creates an animation group with extensions.
---@param texture Texture
---@return AnimationGroupExtended
function WidgetExtensions.CreateAnimationGroup(texture)
	return private.WithExtension(texture:CreateAnimationGroup(), AnimationGroupExtended)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.WithExtension(obj, extension)
	obj.__debug = {}
	if extension then
		for name, func in pairs(extension) do
			assert(not obj[name])
			obj[name] = func
		end
	end
	for name, func in pairs(BaseExtension) do
		if obj[name] then
			assert(extension and extension[name])
		else
			obj[name] = func
		end
	end
	return obj
end
