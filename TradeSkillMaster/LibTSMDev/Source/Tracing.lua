-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

if not TSMDEV then
	return
end
TSMDEV.Tracing = {}
local Tracing = TSMDEV.Tracing
local LibTSMDev = select(2, ...).LibTSMDev
local Log = LibTSMDev:From("LibTSMUtil"):Include("Util.Log")



-- ============================================================================
-- Module Functions
-- ============================================================================

function Tracing.Enable(apiName)
	local tableName, tableKey = strsplit(".", apiName)
	if not tableKey then
		--! Upstream bug: the two assignments were the wrong way round (tableName was
		-- cleared first, so tableKey got nil and the assert below always fired). That
		-- made Tracing.Enable("SomeGlobal") -- the no-dot form this branch exists for --
		-- impossible to use on any client.
		tableKey = tableName
		tableName = nil
	end
	assert(tableKey)
	--! WotLK fix: trace through TSM's own logger instead of Blizzard's EventTrace.
	-- 3.3.5a has no Blizzard_EventTrace addon at all (probed against the client's MPQs:
	-- Interface\AddOns\Blizzard_EventTrace\Blizzard_EventTrace.toc is ABSENT) and no
	-- EventTrace global -- what this client ships is EventTraceFrame inside
	-- Blizzard_DebugTools, which only records real game events via
	-- EventTraceFrame_OnEvent and has no entry point for an arbitrary API call. So
	-- EventTrace:LogEvent could not be polyfilled onto anything; the hook now writes
	-- the call and its arguments into the TSM log, which is where a developer reading
	-- a trace on this client is looking anyway.
	hooksecurefunc(tableName and _G[tableName] or _G, tableKey, function(...)
		local argStr = ""
		for i = 1, select("#", ...) do
			argStr = argStr..(i > 1 and ", " or "")..tostring((select(i, ...)))
		end
		Log.Info("%s(%s)", apiName, argStr)
	end)
end
