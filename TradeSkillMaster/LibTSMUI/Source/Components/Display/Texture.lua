-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local Texture = UIElements.Define("Texture", "Element")
Texture:_ExtendStateSchema()
	:AddOptionalStringField("color", Theme.IsValidColor)
	:AddOptionalStringField("texturePackKey")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Texture:__init()
	local texture = self:_CreateTexture(UIParent)
	-- Hook SetParent/GetParent since textures can't have a nil parent
	texture._oldSetParent = texture.SetParent
	texture.SetParent = private.SetParent
	texture.GetParent = private.GetParent
	self.__super:__init(texture)
end

function Texture:Acquire()
	self.__super:Acquire()
	local texture = self:_GetBaseFrame()

	-- Set the texture
	self._state:PublisherForKeyChange("color")
		:IgnoreNil()
		:CallMethod(texture, "TSMSubscribeColorTexture")
	self._state:PublisherForKeyChange("texturePackKey")
		:IgnoreNil()
		:CallMethod(texture, "TSMSetTextureAndCoord")
end

function Texture:Release()
	local texture = self:_GetBaseFrame()
	texture:SetTexture(nil)
	texture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	texture:SetColorTexture(0, 0, 0, 0)
	self.__super:Release()
end

---Sets the texture to a theme color key.
---@param texture string A theme color key
---@return Texture
function Texture:SetColor(colorKey)
	assert(not self._state.texturePackKey)
	self._state.color = colorKey
	return self
end

---Sets the texture and size based on a texture pack string.
---@param texturePackKey string A texture pack key
---@return Texture
function Texture:SetTextureAndSize(texturePackKey)
	assert(not self._state.color)
	self._state.texturePackKey = texturePackKey
	self:SetSize(TextureAtlas.GetSize(texturePackKey))
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SetParent(self, parent)
	self._parent = parent
	if parent then
		self:Show()
	else
		self:Hide()
	end
	self:_oldSetParent(parent or UIParent)
end

function private.GetParent(self)
	return self._parent
end
