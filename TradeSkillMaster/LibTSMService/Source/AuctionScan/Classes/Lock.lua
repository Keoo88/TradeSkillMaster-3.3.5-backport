-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Lock = LibTSMService:Init("AuctionScan.Lock")
local ChatMessage = LibTSMService:Include("UI.ChatMessage")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local private = {
	errorMessage = nil,
	activeScan = nil,
	callback = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Configures the auction scan lock code.
---@param errorMessage string The error message to display if another scan is ongoing.
---@param callback fun(name: string) The function to call when the active scan changes
function Lock.Configure(errorMessage, callback)
	private.errorMessage = errorMessage
	private.callback = callback
end

---Attempts to acquire the scan lock at the start of a scan.
---@param name string The name of the type of scan being started
---@return boolean
function Lock.Acquire(name)
	assert(type(name) == "string")
	if private.activeScan and private.activeScan ~= name then
		assert(private.errorMessage)
		ChatMessage.PrintfUser(private.errorMessage)
		return false
	end
	Log.Info("Starting scan (%s)", name)
	private.activeScan = name
	private.callback(name)
	return true
end

---Releases the scan lock and the end of a scan.
---@param name string The name of the type of scan which is ending
function Lock.Release(name)
	if private.activeScan ~= name then
		return
	end
	Log.Info("Ended scan (%s)", name)
	private.activeScan = nil
	private.callback(nil)
end
