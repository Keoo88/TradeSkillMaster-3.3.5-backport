-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Analytics = LibTSMUtil:Init("Util.Analytics")
local Log = LibTSMUtil:Include("Util.Log")
local private = {
	versionStr = nil,
	session = nil,
	events = {},
	lastEventTime = nil,
	argsTemp = {},
	sequenceNumber = 1,
}
local HIT_TYPE_IS_VALID = {
	AC = true,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Analytics:OnModuleLoad(function()
	private.versionStr = private.AddQuotes(LibTSMUtil.GetVersionStr())
	private.session = floor(LibTSMUtil.GetTime())
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Inserts a new analytics action event.
---@param name string The name of the action
---@param ... any Additional parameters for the action
function Analytics.Action(name, ...)
	private.InsertHit("AC", name, ...)
end

---Gets the time of the last analytics event (or nil if there haven't been any).
---@return number?
function Analytics.GetLastEventTime()
	return private.lastEventTime
end

---Iterates over the saved analytics events.
---@return fun(): number, string @Iterator with fields: `index`, `eventStr`
function Analytics.EventIterator()
	return ipairs(private.events)
end

---Extracts the time from an analytics event string.
---@param eventStr string The event as an encoded string
---@return number
function Analytics.GetEntryTime(eventStr)
	local _, _, timeStr = strsplit(",", eventStr)
	return (tonumber(timeStr) or 0) / 1000
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.InsertHit(hitType, ...)
	assert(HIT_TYPE_IS_VALID[hitType])
	wipe(private.argsTemp)
	for i = 1, select("#", ...) do
		local arg = select(i, ...)
		local argType = type(arg)
		if argType == "string" then
			-- remove non-printable and non-ascii characters
			arg = gsub(arg, "[^ -~]", "")
			-- remove characters we don't want in the JSON
			arg = gsub(arg, "[\\\"]", "")
			arg = private.AddQuotes(arg)
		elseif argType == "number" then
			-- pass
		elseif argType == "boolean" then
			arg = tostring(arg)
		else
			error("Invalid arg type: "..argType)
		end
		tinsert(private.argsTemp, arg)
	end
	Log.Info("%s %s", hitType, strjoin(" ", tostringall(...)))
	hitType = private.AddQuotes(hitType)
	local timestamp = LibTSMUtil.GetTime()
	local timeMs = floor(timestamp * 1000)
	local jsonStr = strjoin(",", hitType, private.versionStr, timeMs, private.session, private.sequenceNumber, unpack(private.argsTemp))
	tinsert(private.events, "["..jsonStr.."]")
	private.sequenceNumber = private.sequenceNumber + 1
	private.lastEventTime = timestamp
end

function private.AddQuotes(str)
	return "\""..str.."\""
end
