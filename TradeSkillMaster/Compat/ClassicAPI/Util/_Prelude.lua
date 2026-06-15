-- Bundled !!!ClassicAPI fallback loader (TradeSkillMaster).
--
-- This vendored copy exists only so TSM is self-contained when the standalone !!!ClassicAPI addon is
-- NOT installed. When that addon IS installed it provides the same globals and loads first (OptionalDeps
-- + the "!!!" prefix sort it ahead of TSM). Running the bundled copy on top of it is harmful, not inert:
--   * ClassicAPI.lua would create a second CAPI_ScanTooltip and register a second PLAYER_ENTERING_WORLD
--     handler; ItemEventListener:Init() deletes itself on first call, so the second handler crashes with
--     "attempt to call method 'Init' (a nil value)".
--   * The files capture the addon's private table via `...`; bundled inside TSM that table is TSM's own
--     addon object, and writing keys into it breaks TSM:NewPackage's `assert(not self[name])`.
--
-- So: if the external addon is present, set the SKIP flag and every bundled file early-returns. Otherwise
-- create an ISOLATED private table for the bundled files to share, decoupled from TSM's addon object.
if IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI") then
	_G.__TSM_ClassicAPI_SKIP = true
else
	_G.__TSM_ClassicAPI_SKIP = false
	_G.__TSM_ClassicAPI_Private = {}
end
