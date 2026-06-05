-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Color = LibTSMUtil:DefineClassType("Color")
local Math = LibTSMUtil:Include("Lua.Math")
local HSLuv = LibTSMUtil:Include("UI.HSLuv")
local private = {}
local TINT_VALUES = {
	SELECTED = 15,
	HOVER = 12,
	SELECTED_HOVER = 20,
	DISABLED = -40,
}
local OPACITY_VALUES = {
	HIGHLIGHT = 50,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Create a new color value object from a hex string.
---@param hex string The hex string which represents the color (in either "#AARRGGBB" or "#RRGGBB" format)
---@return Color
function Color.__static.NewFromHex(hex)
	return Color(private.HexToRGBA(hex))
end

---Returns whether or not the argument is a color value object.
---@param arg any The argument to check
---@return boolean
function Color.__static.IsColorValue(arg)
	return type(arg) == "table" and arg:__isa(Color) and true or false
end



-- ============================================================================
-- Color Class Methods
-- ============================================================================

function Color:__init(r, g, b, a)
	assert(private.IsValidValue(r, 255) and private.IsValidValue(g, 255) and private.IsValidValue(b, 255) and private.IsValidValue(a, 255))
	if a == 0 then
		assert(r == 0 and g == 0 and b == 0, "Invalid color with alpha of 0")
	end
	self._r = nil
	self._g = nil
	self._b = nil
	self._a = nil
	self._h = nil
	self._s = nil
	self._l = nil
	self._hex = nil
	self._hexNoAlpha = nil
	self._tints = {}
	self._opacities = {}
	self:SetRGBA(r, g, b, a)
end

function Color:__tostring()
	return "Color:"..self._hex
end

---Sets the RGBA values of the color as values from 0 to 255.
---@param r number
---@param g number
---@param b number
---@param a number
function Color:SetRGBA(r, g, b, a)
	wipe(self._tints)
	self._r = r
	self._g = g
	self._b = b
	self._a = a
	self._h, self._s, self._l = HSLuv.FromRGB(r, g, b)
	self._hex = private.RGBAToHex(r, g, b, a)
	self._hexNoAlpha = private.RGBToHex(r, g, b)
	for tintPct, color in pairs(self._tints) do
		local l = self._l + tintPct
		l = min(l, 100)
		assert(private.IsValidValue(l, 100))
		local tintR, tintG, tintB = HSLuv.ToRGB(self._h, self._s, l)
		color:SetRGBA(tintR, tintG, tintB, self._a)
	end
	for opacityPct, color in pairs(self._opacities) do
		assert(self._a == 255)
		local opacityA = Math.Round(255 * opacityPct / 100)
		assert(private.IsValidValue(opacityA, 255))
		color:SetRGBA(self._r, self._g, self._b, opacityA)
	end
end

---Gets a tinted version of the color.
---@param tintPct number The tint percent
---@return Color
function Color:GetTint(tintPct)
	assert(self._hex)
	if type(tintPct) == "string" then
		local sign, tintKey = strmatch(tintPct, "^([%+%-])([A-Z_]+)$")
		assert(TINT_VALUES[tintKey])
		tintPct = tonumber(TINT_VALUES[tintKey]) * (sign == "+" and 1 or -1)
	end
	assert(type(tintPct) == "number")
	if tintPct == 0 then
		return self
	end
	if not self._tints[tintPct] then
		local l = self._l + tintPct
		l = min(l, 100)
		assert(private.IsValidValue(l, 100))
		local r, g, b = HSLuv.ToRGB(self._h, self._s, l)
		self._tints[tintPct] = Color(r, g, b, self._a)
	end
	return self._tints[tintPct]
end

---Gets a version of the color with a different opacity.
---@param opacityPct number The opacity percentage
---@return Color
function Color:GetOpacity(opacityPct)
	assert(self._hex)
	if type(opacityPct) == "string" then
		assert(OPACITY_VALUES[opacityPct])
		opacityPct = tonumber(OPACITY_VALUES[opacityPct])
	end
	assert(private.IsValidValue(opacityPct, 100))
	if opacityPct == 100 then
		return self
	end
	if not self._opacities[opacityPct] then
		assert(self._a == 255)
		local a = Math.Round(255 * opacityPct / 100)
		assert(private.IsValidValue(a, 255))
		self._opacities[opacityPct] = Color(self._r, self._g, self._b, a)
	end
	return self._opacities[opacityPct]
end

---Gets the RGBA values of the color as values from 0 to 255.
---@return number r
---@return number g
---@return number b
---@return number a
function Color:GetRGBA()
	assert(self._hex)
	return self._r, self._g, self._b, self._a
end

---Gets the RGBA values of the color as values from 0 to 1.
---@return number r
---@return number g
---@return number b
---@return number a
function Color:GetFractionalRGBA()
	assert(self._hex)
	return self._r / 255, self._g / 255, self._b / 255, self._a / 255
end

---Returns whether or not the color is considered light.
---@return boolean
function Color:IsLight()
	assert(self._hex)
	return self._l >= 50
end

---Gets the hex string representation of the color.
---@return string
function Color:GetHex()
	assert(self._hex)
	return self._hex
end

---Gets the hex string representation of the color without the alpha channel.
---@return string
function Color:GetHexNoAlpha()
	assert(self._hexNoAlpha)
	return self._hexNoAlpha
end

---Colors a text string with the color.
---@param text string The text string to color
---@return string
function Color:ColorText(text)
	return self:GetTextColorPrefix()..text.."|r"
end

---Gets the prefix used to color a text string.
---@return string
function Color:GetTextColorPrefix()
	assert(self._hex)
	return format("|c%02x%02x%02x%02x", self._a, self._r, self._g, self._b)
end

---Compares two colors for equality.
---@param other Color
---@return boolean
function Color:Equals(other)
	return self:GetHex() == other:GetHex()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsValidValue(value, maxValue)
	return type(value) == "number" and value >= 0 and value <= maxValue and value == floor(value)
end

function private.HexToRGBA(hex)
	local a, r, g, b = strmatch(strlower(hex), "^#([0-9a-f]?[0-9a-f]?)([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])([0-9a-f][0-9a-f])$")
	return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a ~= "" and a or "ff", 16)
end

function private.RGBToHex(r, g, b)
	return format("#%02x%02x%02x", Math.Round(r), Math.Round(g), Math.Round(b))
end

function private.RGBAToHex(r, g, b, a)
	return format("#%02x%02x%02x%02x", Math.Round(a), Math.Round(r), Math.Round(g), Math.Round(b))
end
