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
	tbl = nil,
	hasNoLocaleTable = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the locale table.
---@return table<string,string>
function Locale.GetTable()
	assert(private.tbl)
	return private.tbl
end

function Locale.ShouldLoad(locale)
	assert(private.locale)
	return not private.hasNoLocaleTable and locale == private.locale
end

function Locale.SetTable(tbl)
	assert(not private.tbl)
	private.tbl = setmetatable(tbl, {
		__index = function(t, k)
			local v = tostring(k)
			if not private.hasNoLocaleTable then
				error(format("Locale string does not exist: \"%s\"", v))
			end
			rawset(t, k, v)
			return v
		end,
		__newindex = function()
			error("Cannot write to the locale table")
		end,
	})
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
	if private.hasNoLocaleTable then
		Locale.SetTable({})
	end
end
