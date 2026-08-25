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
local DEFAULT_FONT_PATH_BY_LOCALE = {
	enUS = "Fonts\\FRIZQT__.ttf",
	enGB = "Fonts\\FRIZQT__.ttf",
	esES = "Fonts\\FRIZQT__.ttf",
	esMX = "Fonts\\FRIZQT__.ttf",
	deDE = "Fonts\\FRIZQT__.ttf",
	frFR = "Fonts\\FRIZQT__.ttf",
	itIT = "Fonts\\FRIZQT__.ttf",
	ptBR = "Fonts\\FRIZQT__.ttf",
	koKR = "Fonts\\2002.ttf",
	zhCN = "Fonts\\ZYKai_T.ttf",
	zhTW = "Fonts\\bLEI00D.ttf",
	ruRU = "Fonts\\FRIZQT___CYR.ttf",
}
local DEFAULT_FONT_PATH = {
	[ALPHABET.ROMAN] = "Fonts\\FRIZQT__.ttf",
	[ALPHABET.KOREAN] = "Fonts\\2002.ttf",
	[ALPHABET.CHINESE] = "Fonts\\ZYKai_T.ttf",
	[ALPHABET.CYRILLIC] = "Fonts\\FRIZQT___CYR.ttf",
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Loads font path data.
---@param overrides table<EnumValue,table<EnumValue,string>> Overrides by alphabet and type
function FontObject.__static.LoadPaths(overrides)
	local locale = GetLocale()
	private.alphabet = ALPHABET_LOOKUP[locale] or ALPHABET.ROMAN
	assert(private.alphabet)

	-- Create a frame to load fonts
	private.loadFrame = CreateFrame("Frame", nil, UIParent)
	private.loadFrame.texts = {}
	private.loadFrame:SetAllPoints()
	private.loadFrame:SetScript("OnUpdate", private.LoadFrameOnUpdate)

	-- Collect all the paths and queue loading of the fonts
	private.paths = {}
	local defaultPath = DEFAULT_FONT_PATH_BY_LOCALE[locale] or DEFAULT_FONT_PATH[private.alphabet]
	for _, fontType in pairs(TYPE) do
		local path = overrides[private.alphabet] and overrides[private.alphabet][fontType] or defaultPath
		assert(path)
		-- QueueFontLoad returns the font path that actually loaded.
		-- If a font fails to load (e.g. ARKai_C.ttf missing on 3.3.5 zhCN, or FRIZQT___CYR.ttf missing on ruRU),
		-- it falls back to a working font for the current client locale.
		private.paths[fontType] = private.QueueFontLoad(path)
	end
end

---Updates font path data after the initial load (for live appearance font changes).
---@param overrides table<EnumValue,table<EnumValue,string>> Overrides by alphabet and type
function FontObject.__static.UpdatePaths(overrides)
	assert(private.alphabet and private.paths and private.loadFrame)
	local locale = GetLocale()
	local defaultPath = DEFAULT_FONT_PATH_BY_LOCALE[locale] or DEFAULT_FONT_PATH[private.alphabet]
	for _, fontType in pairs(TYPE) do
		local path = overrides[private.alphabet] and overrides[private.alphabet][fontType] or defaultPath
		assert(path)
		private.paths[fontType] = private.QueueFontLoad(path)
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
	if self._path == "Fonts\\ARKai_C.ttf" or self._path == "Fonts\\ZYKai_T.ttf" or self._path == "Fonts\\ZYHei.ttf" or self._path == "Fonts\\bLEI00D.ttf" or self._path == "Fonts\\bKAI00M.ttf" then
		return self._path, self._size, self._flags
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
		return private.loadFrame.texts[path].resolvedPath or path
	end
	local fontString = private.loadFrame:CreateFontString()
	fontString:SetPoint("TOPRIGHT")
	fontString:SetWidth(100)
	fontString:SetHeight(6)
	-- 3.3.5a: SetFont can fail (return false) when the requested font file is
	-- missing on a client/locale (e.g. ARKai_C.ttf on 3.3.5 zhCN, or FRIZQT___CYR.ttf on ruRU).
	-- Calling SetText on a font string with no font set throws a hard "Font not set" error.
	-- We fall back through candidate fonts for the current locale to ensure a font with
	-- proper glyphs (Chinese/Cyrillic/Korean) is loaded instead of an ASCII-only font.
	local resolvedPath = path
	local fontSet = fontString:SetFont(path, 6, "")
	if not fontSet then
		local locale = GetLocale()
		local candidates = {}
		if locale == "zhCN" then
			candidates = { "Fonts\\ZYKai_T.ttf", "Fonts\\ZYHei.ttf", "Fonts\\ZYKai_C.ttf", "Fonts\\ARKai_T.ttf", "Fonts\\ARKai_C.ttf" }
		elseif locale == "zhTW" then
			candidates = { "Fonts\\bLEI00D.ttf", "Fonts\\bKAI00M.ttf", "Fonts\\bHEI00M.ttf", "Fonts\\bHEI01B.ttf", "Fonts\\ARKai_T.ttf" }
		elseif locale == "koKR" then
			candidates = { "Fonts\\2002.ttf", "Fonts\\2002B.ttf", "Fonts\\K_Pagetext.TTF" }
		elseif locale == "ruRU" then
			candidates = { "Fonts\\FRIZQT___CYR.ttf", "Fonts\\NimrodMT.ttf", "Fonts\\FRIZQT__.ttf" }
		else
			candidates = { "Fonts\\FRIZQT__.ttf" }
		end

		local stockFont = nil
		if GameFontNormal and GameFontNormal.GetFont then
			stockFont = GameFontNormal:GetFont()
		elseif ChatFontNormal and ChatFontNormal.GetFont then
			stockFont = ChatFontNormal:GetFont()
		end
		if stockFont then
			tinsert(candidates, stockFont)
		end
		tinsert(candidates, "Fonts\\FRIZQT__.ttf")

		for _, candidate in ipairs(candidates) do
			if candidate ~= path and fontString:SetFont(candidate, 6, "") then
				resolvedPath = candidate
				fontSet = true
				break
			end
		end
	end
	if fontSet then
		fontString:SetText("1")
	end
	fontString.resolvedPath = resolvedPath
	private.loadFrame.texts[path] = fontString
	private.loadFrame:Show()
	return resolvedPath
end

function private.LoadFrameOnUpdate(frame)
	-- On 3.3.5a custom TTFs can report a zero string width on the first frame
	-- even though they load fine, so we no longer hard-assert here; we just
	-- clean up the preload font strings and hide the frame.
	for _, fontString in pairs(frame.texts) do
		fontString:Hide()
	end
	frame:Hide()
end
