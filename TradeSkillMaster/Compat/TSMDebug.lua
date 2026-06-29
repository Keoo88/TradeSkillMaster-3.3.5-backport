-- ============================================================================
--                                TradeSkillMaster                              --
-- Debug shim. Диагностический модуль (/tsmdiag, /tsmdbg, авто-снепшоты,
-- blocked-capture, авто-ReloadUI и хранилище TSMDebugDB) удалён ради экономии
-- памяти и устранения служебного оверхеда. Здесь остались только no-op
-- заглушки, чтобы внедрённые ранее трассировочные вызовы TSMDBG.* в коде
-- сканера/почты/профессий/UI не падали (attempt to index nil).
--
-- Нулевой оверхед: ничего не хранится в памяти, не пишется в SavedVariables
-- и не регистрируются никакие события. SavedVariable TSMDebugDB больше не
-- объявлена в .toc, поэтому существующие защищённые проверки `if TSMDebugDB`
-- просто не срабатывают.
-- ============================================================================

local function noop() end

_G.TSMDBG = {
	Log = noop,
	Warn = noop,
	LogErr = noop,
	Dump = noop,
	Time = noop,
	TimeEnd = noop,
	SignalQuerySent = noop,
	SignalScanComplete = noop,
	captureBlocked = noop,
	GetBlocked = function() return {} end,
}
