-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local FontObject = LibTSMWoW:DefineClassType("FontObject")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local private = {
	alphabet = nil,
	loadFrame = nil,
	paths = nil,
}
local ALPHABET = EnumType.New("FONT_ALPHABET", {
	ROMAN = EnumType.NewValue(),
	KOREAN = EnumType.NewValue(),
	CHINESE = EnumType.NewValue(),
	CYRILLIC = EnumType.NewValue(),
})
FontObject.ALPHABET = ALPHABET
local TYPE = EnumType.New("FONT_TYPE", {
	BODY_REGULAR = EnumType.NewValue(),
	BODY_MEDIUM = EnumType.NewValue(),
	BODY_BOLD = EnumType.NewValue(),
	ITEM = EnumType.NewValue(),
	TABLE = EnumType.NewValue(),
})
FontObject.TYPE = TYPE
local ALPHABET_LOOKUP = {
	enUS = ALPHABET.ROMAN,
	esES = ALPHABET.ROMAN,
	esMX = ALPHABET.ROMAN,
	deDE = ALPHABET.ROMAN,
	frFR = ALPHABET.ROMAN,
	itIT = ALPHABET.ROMAN,
	ptBR = ALPHABET.ROMAN,
	koKR = ALPHABET.KOREAN,
	zhCN = ALPHABET.CHINESE,
	zhTW = ALPHABET.CHINESE,
	ruRU = ALPHABET.CYRILLIC,
}
local DEFAULT_FONT_PATH = {
	[ALPHABET.ROMAN] = "Fonts\\FRIZQT__.ttf",
	[ALPHABET.KOREAN] = "Fonts\\2002.ttf",
	[ALPHABET.CHINESE] = "Fonts\\ARKai_C.ttf",
	[ALPHABET.CYRILLIC] = "Fonts\\FRIZQT___CYR.ttf",
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Loads font path data.
---@param overrides table<EnumValue,table<EnumValue,string>> Overrides by alphabet and type
function FontObject.__static.LoadPaths(overrides)
	private.alphabet = ALPHABET_LOOKUP[GetLocale()]
	assert(private.alphabet)

	-- Create a frame to load fonts
	private.loadFrame = CreateFrame("Frame", nil, UIParent)
	private.loadFrame.texts = {}
	private.loadFrame:SetAllPoints()
	private.loadFrame:SetScript("OnUpdate", private.LoadFrameOnUpdate)

	-- Collect all the paths and queue loading of the fonts
	private.paths = {}
	for _, fontType in pairs(TYPE) do
		local path = overrides[private.alphabet] and overrides[private.alphabet][fontType] or DEFAULT_FONT_PATH[private.alphabet]
		assert(path)
		private.QueueFontLoad(path)
		private.paths[fontType] = path
	end
end

---Create an font object from a path and height.
---@param fontType EnumValue The font type (FontObject.TYPE)
---@param size number The size of the font in pixels
---@param lineHeight number The height of each line of text in pixels
---@param flags? 'OUTLINE'|'THICK'|'MONOCHROME' A set of flags
---@return FontObject
function FontObject.__static.New(fontType, size, lineHeight, flags)
	assert(EnumType.IsValue(fontType, TYPE))
	local path = private.paths[fontType]
	assert(path and type(size) == "number" and type(lineHeight) == "number" and (flags == nil or type(flags) == "string"))
	return FontObject(path, size, lineHeight, flags or "")
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function FontObject.__private:__init(path, size, lineHeight, flags)
	self._path = path
	self._size = size
	self._lineHeight = lineHeight
	self._flags = flags
end

function FontObject:__tostring()
	local shortPath = strmatch(self._path, "([^/\\]+)%.[A-Za-z]+$")
	return "FontObject:"..tostring(shortPath)..":"..tostring(self._size)..":"..tostring(self._lineHeight)
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Gets the WoW font information.
---@return string
---@return number
---@return 'OUTLINE'|'THICK'|'MONOCHROME'|nil
function FontObject:GetWowFont()
	if self._path == "Fonts\\ARKai_C.ttf" then
		-- This font is a bit smaller than it should be, so increase it by 1
		return self._path, self._size + 1, self._flags
	else
		-- Wow renders other fonts slightly bigger than the designs would indicate, so decrease the height by 1
		return self._path, self._size - 1, self._flags
	end
end

---Gets the spacing of the font.
---@return number
function FontObject:GetSpacing()
	assert(self._lineHeight >= self._size)
	return self._lineHeight - self._size
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QueueFontLoad(path)
	if private.loadFrame.texts[path] then
		return
	end
	local fontString = private.loadFrame:CreateFontString()
	fontString:SetPoint("TOPRIGHT")
	fontString:SetWidth(100)
	fontString:SetHeight(6)
	fontString:SetFont(path, 6, "")
	fontString:SetText("1")
	private.loadFrame.texts[path] = fontString
	private.loadFrame:Show()
end

function private.LoadFrameOnUpdate(frame)
	for _, fontString in pairs(frame.texts) do
		if fontString:IsVisible() then
			assert(fontString:GetStringWidth() > 0, "Text not loaded: "..tostring(fontString:GetFont()))
			fontString:Hide()
		end
	end
	frame:Hide()
end
