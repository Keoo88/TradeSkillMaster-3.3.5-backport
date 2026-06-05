-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Types = LibTSMTypes:Init("Settings.Types")

---@alias ScopeName
---|'"global"'
---|'"profile"'
---|'"realm"'
---|'"factionrealm"'
---|'"char"'
---|'"sync"'

---@alias ScopeKey
---|'"g"'
---|'"p"'
---|'"r"'
---|'"f"'
---|'"c"'
---|'"s"'

---@type table<ScopeName, ScopeKey>
Types.SCOPES = {
	global = "g",
	profile = "p",
	realm = "r",
	factionrealm = "f",
	char = "c",
	sync = "s",
}

---@type table<ScopeKey, ScopeName>
Types.SCOPES_LOOKUP = {
	g = "global",
	p = "profile",
	r = "realm",
	f = "factionrealm",
	c = "char",
	s = "sync",
}

Types.KEY_SEP = "@"
Types.SCOPE_KEY_SEP = " - "

Types.GLOBAL_SCOPE_KEY = " "
Types.GLOBAL_SCOPE_KEY_VALUES = {Types.GLOBAL_SCOPE_KEY}

Types.DEFAULT_PROFILE_NAME = "Default"
