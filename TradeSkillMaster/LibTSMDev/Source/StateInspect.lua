-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMDev = select(2, ...).LibTSMDev
local StateInspect = LibTSMDev:Init("StateInspect")
local SlashCommands = LibTSMDev:From("LibTSMApp"):Include("Service.SlashCommands")
local State = LibTSMDev:From("LibTSMUtil"):Include("Reactive.Type.State")



-- ============================================================================
-- Module Loading
-- ============================================================================

StateInspect:OnModuleLoad(function()
	SlashCommands.RegisterDebug("state", function()
		C_AddOns.LoadAddOn("Blizzard_DebugTools")
		--! WotLK fix: dump to chat instead of opening a table inspector window. The
		-- 3.3.5a Blizzard_DebugTools has no inspector at all -- reading the client's own
		-- copy out of patch-enUS-2.MPQ shows EventTraceFrame, DebugTooltip_OnLoad and
		-- DevTools_Dump, and nothing named TableInspector or DisplayTableInspectorWindow
		-- (those arrived in 5.x). This matters more than it looks: unlike Dump.lua and
		-- Tracing.lua this file has no "if not TSMDEV then return end" gate, so the
		-- debug command is registered on a release build too and any player typing it
		-- got "attempt to call global 'DisplayTableInspectorWindow' (a nil value)".
		-- DevTools_Dump is the native equivalent this client does ship and prints the
		-- same tree; it is also what TSM's own TSMDEV.Dump already uses.
		DevTools_Dump(State.GetDebugData())
	end)
end)
