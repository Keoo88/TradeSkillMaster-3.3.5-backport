-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Rectangle = LibTSMUI:DefineClassType("Rectangle")
local WidgetExtensions = LibTSMUI:Include("Util.WidgetExtensions")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	textureInfo = nil,
}
local CORNER_TEXTURE_INFO = {
	topLeft = {
		points = {
			{ "TOPRIGHT", "vertical", "TOPLEFT" },
			{ "BOTTOMLEFT", "horizontal", "TOPLEFT" },
		},
	},
	bottomLeft = {
		points = {
			{ "TOPLEFT", "horizontal", "BOTTOMLEFT" },
			{ "BOTTOMRIGHT", "vertical", "BOTTOMLEFT" },
		},
	},
	topRight = {
		points = {
			{ "TOPLEFT", "vertical", "TOPRIGHT" },
			{ "BOTTOMRIGHT", "horizontal", "TOPRIGHT" },
		},
	},
	bottomRight = {
		points = {
			{ "TOPRIGHT", "horizontal", "BOTTOMRIGHT" },
			{ "BOTTOMLEFT", "vertical", "BOTTOMRIGHT" },
		},
	},
}
local CENTER_TEXTURE_KEYS = {
	"horizontal",
	"vertical",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers the rectange corner textures.
---@param info table The corner texture info
function Rectangle.__static.RegisterTextures(info)
	private.textureInfo = info
	for key in pairs(CORNER_TEXTURE_INFO) do
		assert(info[key])
		assert(type(info[key].texture) == "string")
		assert(#info[key].coord == 4)
	end
end

---Create a rectangle object.
---@param frame Frame The parent frame
---@param subLayer? number The texture subLayer
---@param cancellables table The cancellables table to use
---@return Rectangle
function Rectangle.__static.New(frame, subLayer, cancellables)
	assert(frame and cancellables)
	return Rectangle(frame, subLayer, cancellables)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function Rectangle.__private:__init(frame, subLayer, cancellables)
	self._frame = frame
	self._textures = {} ---@type table<string,TextureExtended>
	self._inset = 0
	self._cornerRadius = 0
	self._shown = true
	self._cancellables = cancellables

	-- Create the textures
	for _, key in ipairs(CENTER_TEXTURE_KEYS) do
		self._textures[key] = self:_CreateTexture(subLayer)
	end
	for key, info in pairs(CORNER_TEXTURE_INFO) do
		local texture = self:_CreateTexture(subLayer)
		self._textures[key] = texture
		local textureInfo = private.textureInfo[key]
		texture:SetTexture(textureInfo.texture)
		texture:SetTexCoord(unpack(textureInfo.coord))
		for _, point in ipairs(info.points) do
			assert(#point == 3)
			local anchor, relFrame, relAnchor = unpack(point)
			relFrame = self._textures[relFrame]
			assert(relFrame)
			texture:SetPoint(anchor, relFrame, relAnchor)
		end
	end

	self:_LayoutTextures()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Shows the rectangle.
function Rectangle:Show()
	if self._shown then
		return
	end
	for _, texture in pairs(self._textures) do
		texture:Show()
	end
	self._shown = true
end

---Hides the rectangle.
function Rectangle:Hide()
	if not self._shown then
		return
	end
	for _, texture in pairs(self._textures) do
		texture:Hide()
	end
	self._shown = false
end

---Sets whether or not the rectangle is shown.
---@param shown boolean Whether or not the rectangle should be shown
function Rectangle:SetShown(shown)
	if shown then
		self:Show()
	else
		self:Hide()
	end
end

---Sets the color of the rectangle.
---@param color ThemeColorKey|Color
function Rectangle:SetColor(color)
	if type(color) == "string" then
		color = Theme.GetColor(color)
	end
	for _, key in ipairs(CENTER_TEXTURE_KEYS) do
		self._textures[key]:SetColorTexture(color:GetFractionalRGBA())
	end
	for key in pairs(CORNER_TEXTURE_INFO) do
		self._textures[key]:SetVertexColor(color:GetFractionalRGBA())
	end
end

---Subscribes the color of the rectangle to a theme color.
---@param color ThemeColorKey
function Rectangle:SubscribeColor(color)
	for _, key in ipairs(CENTER_TEXTURE_KEYS) do
		self._textures[key]:TSMSubscribeColorTexture(color)
	end
	for key in pairs(CORNER_TEXTURE_INFO) do
		self._textures[key]:TSMSubscribeVertexColor(color)
	end
end

---Sets the inset of the rectangle.
---@param inset number The inset amount
function Rectangle:SetInset(inset)
	assert(inset >= 0)
	self._inset = inset
	self:_LayoutTextures()
end

---Sets the corner radius.
---@param cornerRadius number The corner radius
function Rectangle:SetCornerRadius(cornerRadius)
	assert(cornerRadius >= 0)
	self._cornerRadius = cornerRadius
	self:_LayoutTextures()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Rectangle.__private:_LayoutTextures()
	self._textures.horizontal:SetPoint("TOPLEFT", self._inset, -self._cornerRadius - self._inset)
	self._textures.horizontal:SetPoint("BOTTOMRIGHT", -self._inset, self._cornerRadius + self._inset)
	self._textures.vertical:SetPoint("TOPLEFT", self._cornerRadius + self._inset, -self._inset)
	self._textures.vertical:SetPoint("BOTTOMRIGHT", -self._cornerRadius - self._inset, self._inset)
end

function Rectangle.__private:_CreateTexture(subLayer)
	local texture = WidgetExtensions.CreateTexture(self._frame, "BACKGROUND", subLayer or 0)
	texture:TSMSetCancellablesTable(self._cancellables)
	texture:SetBlendMode("BLEND")
	return texture
end
