-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Theme = LibTSMService:Init("UI.Theme")
local Color = LibTSMService:From("LibTSMUtil"):IncludeClassType("Color")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = LibTSMService:From("LibTSMUtil"):Include("Reactive")
local TradeSkill = LibTSMService:From("LibTSMWoW"):Include("API.TradeSkill")
local FontObject = LibTSMService:From("LibTSMWoW"):IncludeClassType("FontObject")
local private = {
	callbacks = {},
	names = {},
	colorSets = {},
	currentColorSetKey = nil,
	currentFontSet = nil,
	fontsLoaded = false,
	appearanceFontFace = "",
	fontScale = 1,
	itemIconSize = 12,
	streams = {},
	publisherKey = {},
	publishKeysTemp = {},
}
---@alias ThemeColorKey
---|'"PRIMARY_BG"'
---|'"PRIMARY_BG_ALT"'
---|'"FRAME_BG"'
---|'"ACTIVE_BG"'
---|'"ACTIVE_BG_ALT"'
---|'"INDICATOR"'
---|'"INDICATOR_ALT"'
---|'"INDICATOR_DISABLED"'
---|'"TEXT"'
---|'"TEXT_ALT"'
---|'"TEXT_DISABLED"'
---|'"FEEDBACK_RED"'
---|'"FEEDBACK_YELLOW"'
---|'"FEEDBACK_GREEN"'
---|'"FEEDBACK_BLUE"'
---|'"FEEDBACK_ORANGE"'
---|'"GROUP_ONE"'
---|'"GROUP_TWO"'
---|'"GROUP_THREE"'
---|'"GROUP_FOUR"'
---|'"GROUP_FIVE"'
---|'"FULL_BLACK"'
---|'"FULL_WHITE"'
---|'"TRANSPARENT"'
---|'"SEMI_TRANSPARENT"'
---|'"BLIZZARD_YELLOW"'
---|'"BLIZZARD_GM"'
local THEME_COLOR_KEYS = {
	PRIMARY_BG = true,
	PRIMARY_BG_ALT = true,
	FRAME_BG = true,
	ACTIVE_BG = true,
	ACTIVE_BG_ALT = true,
}
local STATIC_COLORS = {
	INDICATOR = Color.NewFromHex("#ffd839"),
	INDICATOR_ALT = Color.NewFromHex("#79a2ff"),
	INDICATOR_DISABLED = Color.NewFromHex("#6f5819"),

	TEXT = Color.NewFromHex("#ffffff"),
	TEXT_ALT = Color.NewFromHex("#e2e2e2"),
	TEXT_DISABLED = Color.NewFromHex("#424242"),

	FEEDBACK_RED = Color.NewFromHex("#f72d20"),
	FEEDBACK_YELLOW = Color.NewFromHex("#e1f720"),
	FEEDBACK_GREEN = Color.NewFromHex("#4ff720"),
	FEEDBACK_BLUE = Color.NewFromHex("#2076f7"),
	FEEDBACK_ORANGE = Color.NewFromHex("#f77a20"),

	GROUP_ONE = Color.NewFromHex("#fcf141"),
	GROUP_TWO = Color.NewFromHex("#bdaec6"),
	GROUP_THREE = Color.NewFromHex("#06a2cb"),
	GROUP_FOUR = Color.NewFromHex("#ffb85c"),
	GROUP_FIVE = Color.NewFromHex("#51b599"),

	FULL_BLACK = Color.NewFromHex("#000000"),
	FULL_WHITE = Color.NewFromHex("#ffffff"),
	TRANSPARENT = Color.NewFromHex("#00000000"),
	SEMI_TRANSPARENT = Color.NewFromHex("#20ffffff"),

	BLIZZARD_YELLOW = Color.NewFromHex("#ffff00"),
	BLIZZARD_GM = Color.NewFromHex("#00b4ff"),

	CRAFTED_QUALITY_ONE_MIDNIGHT = Color.NewFromHex("#7d7e85"),
	CRAFTED_QUALITY_TWO_MIDNIGHT = Color.NewFromHex("#e2b932"),

	CRAFTED_QUALITY_ONE = Color.NewFromHex("#904a3c"),
	CRAFTED_QUALITY_TWO = Color.NewFromHex("#7d7e85"),
	CRAFTED_QUALITY_THREE = Color.NewFromHex("#8f782e"),
	CRAFTED_QUALITY_FOUR = Color.NewFromHex("#4b9694"),
	CRAFTED_QUALITY_FIVE = Color.NewFromHex("#e2b932"),
}
local GROUP_COLOR_KEYS = {
	"GROUP_ONE",
	"GROUP_TWO",
	"GROUP_THREE",
	"GROUP_FOUR",
	"GROUP_FIVE",
}
local CRAFTED_QUALITY_KEYS_MIDNIGHT = {
	"CRAFTED_QUALITY_ONE_MIDNIGHT",
	"CRAFTED_QUALITY_TWO_MIDNIGHT",
}
local CRAFTED_QUALITY_KEYS = {
	"CRAFTED_QUALITY_ONE",
	"CRAFTED_QUALITY_TWO",
	"CRAFTED_QUALITY_THREE",
	"CRAFTED_QUALITY_FOUR",
	"CRAFTED_QUALITY_FIVE",
}
local PROFESSION_DIFFICULTY_COLORS = {
	[TradeSkill.RECIPE_DIFFICULTY.OPTIMAL] = Color.NewFromHex("#ff8040"),
	[TradeSkill.RECIPE_DIFFICULTY.MEDIUM] = Color.NewFromHex("#ffff00"),
	[TradeSkill.RECIPE_DIFFICULTY.EASY] = Color.NewFromHex("#40c040"),
	[TradeSkill.RECIPE_DIFFICULTY.TRIVIAL] = Color.NewFromHex("#808080"),
	header = Color.NewFromHex("#ffd100"),
	subheader = Color.NewFromHex("#ffd100"),
	nodifficulty = Color.NewFromHex("#f5f5f5"),
}
-- NOTE: there is a global ITEM_QUALITY_COLORS so we need to use another name
local TSM_ITEM_QUALITY_COLORS = {
	[0] = Color.NewFromHex("#9d9d9d"),
	[1] = Color.NewFromHex("#ffffff"),
	[2] = Color.NewFromHex("#1eff00"),
	[3] = Color.NewFromHex("#0070dd"),
	[4] = Color.NewFromHex("#a334ee"),
	[5] = Color.NewFromHex("#ff8000"),
	[6] = Color.NewFromHex("#e6cc80"),
	[7] = Color.NewFromHex("#00ccff"),
	[8] = Color.NewFromHex("#00ccff"),
}
local AUCTION_PCT_COLORS = {
	{ -- blue
		color = "FEEDBACK_BLUE",
		value = 50,
	},
	{ -- green
		color = "FEEDBACK_GREEN",
		value = 80,
	},
	{ -- yellow
		color = "FEEDBACK_YELLOW",
		value = 110,
	},
	{ -- orange
		color = "FEEDBACK_ORANGE",
		value = 135,
	},
	{ -- red
		color = "FEEDBACK_RED",
		value = math.huge,
	},
	default = "TEXT",
	bid = "TEXT_ALT",
}
local CONSTANTS = {
	COL_SPACING = 8,
	SCROLLBAR_MARGIN = 4,
	SCROLLBAR_WIDTH = 4,
	MOUSE_WHEEL_SCROLL_AMOUNT = 60,
}
local OVERRIDE_FONT_PATHS = {
	[FontObject.ALPHABET.ROMAN] = {
		[FontObject.TYPE.BODY_REGULAR] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Regular.ttf",
		[FontObject.TYPE.BODY_MEDIUM] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Medium.ttf",
		[FontObject.TYPE.BODY_BOLD] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Bold.ttf",
		[FontObject.TYPE.TABLE] = "Interface\\Addons\\TradeSkillMaster\\Media\\Roboto-Medium.ttf",
	},
	[FontObject.ALPHABET.CYRILLIC] = {
		[FontObject.TYPE.BODY_REGULAR] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Regular.ttf",
		[FontObject.TYPE.BODY_MEDIUM] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Medium.ttf",
		[FontObject.TYPE.BODY_BOLD] = "Interface\\Addons\\TradeSkillMaster\\Media\\Montserrat-Bold.ttf",
		[FontObject.TYPE.TABLE] = "Interface\\Addons\\TradeSkillMaster\\Media\\Roboto-Medium.ttf",
	},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Theme:OnModuleLoad(function()
	Table.SetReadOnly(STATIC_COLORS)
	Table.SetReadOnly(GROUP_COLOR_KEYS)
	Table.SetReadOnly(PROFESSION_DIFFICULTY_COLORS)
	Table.SetReadOnly(TSM_ITEM_QUALITY_COLORS)
	Table.SetReadOnly(CONSTANTS)
end)


-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers a callback when the theme changes.
---@param callback function The callback function
function Theme.RegisterChangeCallback(callback)
	assert(type(callback) == "function")
	tinsert(private.callbacks, callback)
end

---Registers a new color set.
---@param key string The key which represents the color set
---@param name string The name of the color set
---@param colorSet table The colors which make up the color set (with keys specified in `THEME_COLOR_KEYS`)
function Theme.RegisterColorSet(key, name, colorSet)
	assert(not private.colorSets[key] and type(key) == "string" and strmatch(key, "^[a-zA-Z]+$"))
	for k in pairs(THEME_COLOR_KEYS) do
		assert(Color.IsColorValue(colorSet[k]))
	end
	private.names[key] = name
	private.colorSets[key] = colorSet
end

---Gets a theme color publisher which publishes deduplicated color values.
---@param key string The theme color key
---@return ReactivePublisher
function Theme.GetPublisher(key)
	assert(Theme.IsValidColor(key))
	local colorKey = private.GetColorKeyInfo(key)
	if not private.streams[colorKey] then
		local stream = Reactive.CreateStream()
		stream:SetScript("OnPublisherCancelled", private.HandlePublisherCancel)
		private.streams[colorKey] = stream
	end
	local publisher = private.streams[colorKey]:PublisherWithInitialValue(key)
		:IgnoreIfNotEquals(key)
		:MapWithFunction(Theme.GetColor)
		:IgnoreDuplicatesWithMethod("GetHex")
	private.publisherKey[publisher] = key
	return publisher
end

---Sets the active color set.
---@param colorSetKey string The key which represents the color set
function Theme.SetActiveColorSet(colorSetKey)
	assert(private.colorSets[colorSetKey])
	if private.currentColorSetKey == colorSetKey then
		return
	end
	private.currentColorSetKey = colorSetKey
	private.HandleColorChange(colorSetKey, nil)
	private.NotifyChange()
end

---Replaces a specific color within a theme (for user-generated themes)
---@param colorSetKey string The key of the color set to change
---@param colorKey string The key of the color to change
---@param r number The new red value (0-255)
---@param g number The new green value (0-255)
---@param b number The new blue value (0-255)
function Theme.UpdateColor(colorSetKey, colorKey, r, g, b)
	local colorSet = private.colorSets[colorSetKey]
	assert(THEME_COLOR_KEYS[colorKey] and colorSet)
	local color = colorSet[colorKey]
	assert(color)
	color:SetRGBA(r, g, b, 255)
	private.HandleColorChange(colorSetKey, colorKey)
	if colorSetKey == private.currentColorSetKey then
		private.NotifyChange()
	end
end

---Returns whether or not a theme color key is valid.
---@param key string The theme color key
---@return boolean
function Theme.IsValidColor(key)
	local colorKey, _, _, colorSetKey = private.GetColorKeyInfo(key)
	if not colorKey then
		return false
	end
	local color = nil
	if THEME_COLOR_KEYS[colorKey] then
		colorSetKey = colorSetKey or private.currentColorSetKey
		assert(colorSetKey)
		color = private.colorSets[colorSetKey][colorKey]
	else
		if colorSetKey then
			return false
		end
		color = STATIC_COLORS[colorKey]
	end
	return color and true or false
end

---Gets the color object from the current active color set.
---@param key ThemeColorKey|string The key of the color to get
---@return Color
function Theme.GetColor(key)
	local colorKey, tintPct, opacityPct, colorSetKey = private.GetColorKeyInfo(key)
	assert(colorKey)
	local color = nil
	if THEME_COLOR_KEYS[colorKey] then
		colorSetKey = colorSetKey or private.currentColorSetKey
		color = private.colorSets[colorSetKey][colorKey]
	else
		assert(not colorSetKey)
		color = STATIC_COLORS[colorKey]
	end
	assert(color)
	if tintPct then
		color = color:GetTint(tintPct)
	end
	if opacityPct then
		color = color:GetOpacity(opacityPct)
	end
	return color
end

---Gets the theme color key for a given group level.
---@param level number The level of the group (1-based)
---@return ThemeColorKey
function Theme.GetGroupColorKey(level)
	level = ((level - 1) % #GROUP_COLOR_KEYS) + 1
	return GROUP_COLOR_KEYS[level]
end

---Gets the color object for a given group level.
---@param level number The level of the group (1-based)
---@return Color
function Theme.GetGroupColor(level)
	return STATIC_COLORS[Theme.GetGroupColorKey(level)]
end

---Gets the color for a profession.
---@param difficulty EnumValue|"header"|"subheader"|"nodifficulty"
---@return Color
function Theme.GetProfessionDifficultyColor(difficulty)
	return PROFESSION_DIFFICULTY_COLORS[difficulty]
end

---Gets the color for an item quality.
---@param quality number
---@return Color
function Theme.GetItemQualityColor(quality)
	return TSM_ITEM_QUALITY_COLORS[quality]
end

---Gets the color for an auction percentage.
---@param pct number
---@return Color
function Theme.GetAuctionPercentColor(pct)
	if pct == "BID" then
		return Theme.GetColor(AUCTION_PCT_COLORS.bid)
	end
	for _, info in ipairs(AUCTION_PCT_COLORS) do
		if pct < info.value then
			return Theme.GetColor(info.color)
		end
	end
	return Theme.GetColor(AUCTION_PCT_COLORS.default)
end

---Gets the color key for a crafted quality.
---@param quality number The crafted quality
---@param useMidnightIcon boolean The quality icon to use
---@return ThemeColorKey
function Theme.GetCraftedQualityColorKey(quality, useMidnightIcon)
	local key = useMidnightIcon and CRAFTED_QUALITY_KEYS_MIDNIGHT[quality] or CRAFTED_QUALITY_KEYS[quality]
	assert(key and Theme.IsValidColor(key))
	return key
end

---Applies saved appearance font settings and rebuilds the active font set.
---@param fontFace string LibSharedMedia font name, or "" for bundled / auto-detect
---@param fontScale number Scale multiplier for all font roles
---@param itemIconSize number Pixel size for item icons in lists and tables
function Theme.ApplyAppearanceFonts(fontFace, fontScale, itemIconSize)
	private.appearanceFontFace = fontFace or ""
	private.fontScale = fontScale or 1
	private.itemIconSize = itemIconSize or 12
	private.RebuildFontSet()
	private.NotifyChange()
end

---Gets the active font scale multiplier.
---@return number
function Theme.GetFontScale()
	return private.fontScale
end

---Gets the configured item icon size in pixels.
---@return number
function Theme.GetItemIconSize()
	return private.itemIconSize
end

---Gets the row height for lists and scroll tables that show item icons.
---@return number
function Theme.GetListRowHeight()
	return max(ceil(20 * private.fontScale), private.itemIconSize + 8)
end

---Gets a chat/UI escape sequence for an item icon texture.
---@param texture string|number The item texture path or file ID
---@return string
function Theme.GetItemIconLink(texture)
	texture = texture or "Interface\\Icons\\INV_Misc_QuestionMark"
	local size = private.itemIconSize
	return "|T"..texture..":"..size..":"..size.."|t"
end

---Updates a cached cell/list string that starts with a TSM item icon escape sequence.
---@param text string
---@return string
function Theme.RefreshItemIconLinkInText(text)
	if not text or text == "" then
		return text
	end
	local path, rest = strmatch(text, "^|T(.-):(%d+):(%d+)|t(.*)$")
	if not path then
		path, rest = strmatch(text, "^|T(.-):(%d+)|t(.*)$")
	end
	if path then
		return Theme.GetItemIconLink(path)..rest
	end
	return text
end

---Gets display names and keys for the font face dropdown.
---@return string[]
---@return string[]
function Theme.GetFontFaceList()
	local items = { "Default" }
	local keys = { "" }
	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
	if lsm and lsm.List then
		local fonts = lsm:List("font")
		if fonts then
			for _, name in ipairs(fonts) do
				tinsert(items, name)
				tinsert(keys, name)
			end
		end
	end
	return items, keys
end

---Resolves the font path the player is already using via LibSharedMedia.
---Prefers ElvUI's configured font so TSM visually matches the rest of the UI.
---Returns nil when LibSharedMedia is unavailable (e.g. no ElvUI), so callers
---fall back to the bundled fonts.
---@return string|nil
function private.GetSharedMediaFontPath()
	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
	if not lsm then
		return nil
	end
	local fontName = nil
	local elvui = _G.ElvUI
	local engine = elvui and elvui[1]
	if engine and engine.db and engine.db.general and engine.db.general.font then
		fontName = engine.db.general.font
	end
	fontName = fontName or lsm:GetDefault("font")
	if not fontName then
		return nil
	end
	return lsm:Fetch("font", fontName, true)
end

---Builds a font path table that uses a single font file for all roles.
---@param path string
---@return table
function private.BuildSingleFontPathTable(path)
	local paths = {}
	for _, alphabet in ipairs({ FontObject.ALPHABET.ROMAN, FontObject.ALPHABET.KOREAN, FontObject.ALPHABET.CHINESE, FontObject.ALPHABET.CYRILLIC }) do
		paths[alphabet] = {}
		for _, fontType in pairs(FontObject.TYPE) do
			paths[alphabet][fontType] = path
		end
	end
	return paths
end

---Builds the default font path override table. When a SharedMedia font is available we
---use it for body and table text in both Roman and Cyrillic locales -- this pulls
---a font that is already loaded and (for ruRU) actually has Cyrillic glyphs,
---instead of the bundled Latin-only Montserrat/Roboto. Otherwise we fall back to
---the bundled TSM fonts.
---@return table
function private.GetDefaultFontPaths()
	local path = private.GetSharedMediaFontPath()
	if not path then
		return OVERRIDE_FONT_PATHS
	end
	local overrideTypes = {
		FontObject.TYPE.BODY_REGULAR,
		FontObject.TYPE.BODY_MEDIUM,
		FontObject.TYPE.BODY_BOLD,
		FontObject.TYPE.TABLE,
	}
	local paths = {}
	for _, alphabet in ipairs({ FontObject.ALPHABET.ROMAN, FontObject.ALPHABET.CYRILLIC }) do
		paths[alphabet] = {}
		for _, fontType in ipairs(overrideTypes) do
			paths[alphabet][fontType] = path
		end
	end
	return paths
end

---Builds the font path override table for the active appearance font face.
---@return table
function private.GetFontPaths()
	if private.appearanceFontFace ~= "" then
		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		if lsm then
			local path = lsm:Fetch("font", private.appearanceFontFace, true)
			if path then
				return private.BuildSingleFontPathTable(path)
			end
		end
	end
	return private.GetDefaultFontPaths()
end

---Rebuilds the active font set from appearance settings.
function private.RebuildFontSet()
	if not private.fontsLoaded then
		FontObject.LoadPaths(private.GetFontPaths())
		private.fontsLoaded = true
	else
		FontObject.UpdatePaths(private.GetFontPaths())
	end
	local scale = private.fontScale
	local iconMinLineHeight = private.itemIconSize
	local function scaled(size, lineHeight)
		return floor(size * scale + 0.5), floor(lineHeight * scale + 0.5)
	end
	local function scaledWithIconLineHeight(size, lineHeight)
		local scaledSize, scaledLineHeight = scaled(size, lineHeight)
		scaledLineHeight = max(scaledLineHeight, iconMinLineHeight)
		if scaledLineHeight < scaledSize then
			scaledSize = scaledLineHeight
		end
		return scaledSize, scaledLineHeight
	end
	local tableSize, tableLineHeight = scaledWithIconLineHeight(12, 20)
	private.currentFontSet = {
		HEADING_H5 = FontObject.New(FontObject.TYPE.BODY_REGULAR, scaled(20, 28)),
		BODY_BODY1 = FontObject.New(FontObject.TYPE.BODY_REGULAR, scaled(16, 24)),
		BODY_BODY1_BOLD = FontObject.New(FontObject.TYPE.BODY_BOLD, scaled(16, 24)),
		BODY_BODY2 = FontObject.New(FontObject.TYPE.BODY_REGULAR, scaled(14, 20)),
		BODY_BODY2_MEDIUM = FontObject.New(FontObject.TYPE.BODY_MEDIUM, scaled(14, 20)),
		BODY_BODY2_BOLD = FontObject.New(FontObject.TYPE.BODY_BOLD, scaled(14, 20)),
		BODY_BODY3 = FontObject.New(FontObject.TYPE.BODY_REGULAR, scaled(12, 20)),
		BODY_BODY3_MEDIUM = FontObject.New(FontObject.TYPE.BODY_MEDIUM, scaled(12, 20)),
		ITEM_BODY1 = FontObject.New(FontObject.TYPE.ITEM, scaledWithIconLineHeight(16, 24)),
		ITEM_BODY2 = FontObject.New(FontObject.TYPE.ITEM, scaledWithIconLineHeight(14, 20)),
		ITEM_BODY3 = FontObject.New(FontObject.TYPE.ITEM, scaledWithIconLineHeight(12, 20)),
		TABLE_TABLE1 = FontObject.New(FontObject.TYPE.TABLE, tableSize, tableLineHeight),
		TABLE_TABLE1_OUTLINE = FontObject.New(FontObject.TYPE.TABLE, tableSize, tableLineHeight, "OUTLINE"),
	}
end

---Ensures the active font set has been initialized. On some clients (e.g. 3.3.5a)
---the module-load callback may not run before fonts are first needed, so we lazily
---build the font set on demand to avoid indexing a nil currentFontSet.
function private.EnsureFontSet()
	if private.currentFontSet then
		return
	end
	private.RebuildFontSet()
end

---Gets the font object from the current active font set.
---@param key string The key of the font to get
function Theme.IsValidFont(key)
	private.EnsureFontSet()
	return private.currentFontSet[key] and true or false
end

---Gets the font object from the current active font set.
---@param key string The key of the font to get
---@return FontObjectValue
function Theme.GetFont(key)
	assert(Theme.IsValidFont(key))
	return private.currentFontSet[key]
end

---Gets the column spacing constant value.
---@return number
function Theme.GetColSpacing()
	return CONSTANTS.COL_SPACING
end

---Gets the scrollbar margin constant value.
---@return number
function Theme.GetScrollbarMargin()
	return CONSTANTS.SCROLLBAR_MARGIN
end

---Gets the scrollbar width constant value.
---@return number
function Theme.GetScrollbarWidth()
	return CONSTANTS.SCROLLBAR_WIDTH
end

---Gets the mouse scroll amount value.
---@return number
function Theme.GetMouseWheelScrollAmount()
	return CONSTANTS.MOUSE_WHEEL_SCROLL_AMOUNT
end

---Iterates over the theme color keys.
---@return fun(): string @An iterator with fields: `key`
function Theme.ThemeColorKeyIterator()
	return Table.KeyIterator(THEME_COLOR_KEYS)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetColorKeyInfo(key)
	local colorKey, tintPct, opacityPct, colorSetKey = strmatch(key, "^([A-Z_]+)([%-%+]?[0-9A-Z_]*)%%?([0-9A-Z_]*):?([a-zA-Z]*)$")
	tintPct = tonumber(tintPct) or (tintPct ~= "" and tintPct or nil)
	opacityPct = tonumber(opacityPct) or (opacityPct ~= "" and opacityPct or nil)
	colorSetKey = colorSetKey ~= "" and colorSetKey or nil
	return colorKey, tintPct, opacityPct, colorSetKey
end

function private.HandleColorChange(changedColorSetKey, changedColorKey)
	assert(not next(private.publishKeysTemp))
	for _, key in pairs(private.publisherKey) do
		local colorKey, _, _, colorSetKey = private.GetColorKeyInfo(key)
		colorSetKey = colorSetKey or private.currentColorSetKey
		if not private.publishKeysTemp[key] and colorSetKey == changedColorSetKey and (not changedColorKey or colorKey == changedColorKey) then
			private.publishKeysTemp[key] = true
			private.streams[colorKey]:Send(key)
		end
	end
	wipe(private.publishKeysTemp)
end

function private.HandlePublisherCancel(_, publisher)
	assert(private.publisherKey[publisher])
	private.publisherKey[publisher] = nil
end

function private.NotifyChange()
	for _, callback in ipairs(private.callbacks) do
		callback()
	end
end
