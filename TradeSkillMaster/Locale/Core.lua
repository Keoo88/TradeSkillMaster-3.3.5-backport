-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local Locale = {}
TSM.Locale = Locale
local private = {
	locale = nil,
	activeLocale = nil,
	tables = {},
	proxy = nil,
	loadLocales = {},
	loadingLocale = nil,
	hasNoLocaleTable = nil,
}

-- Metatable shared by every per-locale string table. A missing key falls back to
-- the key itself (which is the enUS source string), giving an automatic enUS
-- fallback for partial translations on the 3.3.5 backport.
local LOCALE_TABLE_MT = {
	__index = function(t, k)
		local v = tostring(k)
		rawset(t, k, v)
		return v
	end,
	__newindex = function()
		error("Cannot write to the locale table")
	end,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the locale table. This is a stable proxy that resolves to the currently
---active locale at access time, so switching the active locale at runtime
---(Settings > General) takes effect for any string read afterwards.
---@return table<string,string>
function Locale.GetTable()
	return private.proxy
end

function Locale.ShouldLoad(locale)
	assert(private.locale)
	if private.hasNoLocaleTable then
		return false
	end
	if private.loadLocales[locale] then
		-- Remember which locale is currently being loaded so the matching
		-- SetTable() call (at the bottom of the locale file) can associate its
		-- table with the right locale.
		private.loadingLocale = locale
		return true
	end
	return false
end

function Locale.SetTable(tbl)
	local locale = private.loadingLocale
	assert(locale and not private.tables[locale])
	private.tables[locale] = setmetatable(tbl, LOCALE_TABLE_MT)
end

---Sets the active locale used by the GetTable() proxy. Falls back to enUS if the
---requested locale wasn't loaded.
function Locale.SetActiveLocale(locale)
	if not private.tables[locale] then
		locale = "enUS"
	end
	private.activeLocale = locale
end

---Gets the saved language selection key for the Settings dropdown.
---@return string
function Locale.GetLanguageKey()
	local override = _G.TSMLocaleOverride
	if override == "enUS" or override == "ruRU" or override == "auto" then
		return override
	end
	return "auto"
end

---Saves the language selection (account-wide) for use on the next load.
function Locale.SetLanguageKey(key)
	if key ~= "enUS" and key ~= "ruRU" then
		key = "auto"
	end
	_G.TSMLocaleOverride = key
end

---Applies the saved language selection to the active locale. Safe to call once
---TSM's SavedVariables have loaded (ADDON_LOADED for TradeSkillMaster or later).
---Must run before module initialization so strings captured at OnInitialize
---(e.g. settings page names) use the selected language.
function Locale.ApplySavedLanguage()
	local key = Locale.GetLanguageKey()
	Locale.SetActiveLocale(key == "auto" and private.locale or key)
end



-- ============================================================================
-- Initialization Code
-- ============================================================================

do
	local version = C_AddOns.GetAddOnMetadata("TradeSkillMaster", "Version")
	private.hasNoLocaleTable = strmatch(version, "^@tsm%-project%-version@$") or version == "v4.99.99"
	private.locale = GetLocale()
	if private.locale == "enGB" then
		private.locale = "enUS"
	end
	-- Default to the game client's locale until the saved override is applied at
	-- ADDON_LOADED (SavedVariables aren't loaded yet at file-load time).
	private.activeLocale = private.locale

	-- ElvUI-style approach: load every selectable locale into memory so we can
	-- switch between them at runtime without needing the saved choice at
	-- file-load. We load enUS (the base/fallback), ruRU (offered in Settings),
	-- and the game client's locale (used by the "Auto" option).
	private.loadLocales = {
		enUS = true,
		ruRU = true,
		[private.locale] = true,
	}

	-- Stable proxy returned by GetTable(). It resolves to the active locale's
	-- table at access time, so modules that captured L at file-load still see
	-- the active language for any string they read at runtime.
	private.proxy = setmetatable({}, {
		__index = function(_, k)
			local t = private.tables[private.activeLocale] or private.tables.enUS
			if t then
				return t[k]
			end
			return tostring(k)
		end,
		__newindex = function()
			error("Cannot write to the locale table")
		end,
	})

	if private.hasNoLocaleTable then
		-- Dev/source build with no compiled locale tables; use an empty enUS table.
		private.tables.enUS = setmetatable({}, LOCALE_TABLE_MT)
	end

	-- Apply the saved language override once TSM's SavedVariables have loaded.
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("ADDON_LOADED")
	eventFrame:SetScript("OnEvent", function(_, _, addonName)
		if addonName ~= "TradeSkillMaster" then
			return
		end
		eventFrame:UnregisterEvent("ADDON_LOADED")
		Locale.ApplySavedLanguage()
	end)
end
