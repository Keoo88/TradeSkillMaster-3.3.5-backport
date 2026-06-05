-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local RPC = LibTSMService:Init("Sync.RPC")
local Constants = LibTSMService:Include("Sync.Constants")
local Comm = LibTSMService:Include("Sync.Comm")
local Connection = LibTSMService:Include("Sync.Connection")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local private = {
	rpcFunctions = {},
	pendingRPC = {},
	rpcSeqNum = 0,
	pendingTimer = nil,
}
local RPC_EXTRA_TIMEOUT = 15
local CALLBACK_TIME_WARNING_THRESHOLD = 0.02



-- ============================================================================
-- Module Loading
-- ============================================================================

RPC:OnModuleLoad(function()
	private.pendingTimer = DelayTimer.New("SYNC_RPC_PENDING", private.HandlePendingRPC)
	Comm.RegisterHandler(Constants.DATA_TYPES.RPC_CALL, private.HandleCall)
	Comm.RegisterHandler(Constants.DATA_TYPES.RPC_RETURN, private.HandleReturn)
	Comm.RegisterHandler(Constants.DATA_TYPES.RPC_PREAMBLE, private.HandlePreamble)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Registers an RPC.
---@param name string The name of the RPC (must be globally-unique)
---@param func function The function which implements the RPC
function RPC.Register(name, func)
	assert(name)
	private.rpcFunctions[name] = func
end

---Calls an RPC.
---@param name string The name of the RPC
---@param character string The character to send the RPC to
---@param handler function The result handler
---@param ... any The arguments
---@return boolean success
---@return number estimatedTime
function RPC.Call(name, character, handler, ...)
	assert(character)
	if not Connection.IsCharacterConnected(character) then
		return false
	end

	assert(private.rpcFunctions[name], "Cannot call an RPC which is not also registered locally.")
	private.rpcSeqNum = private.rpcSeqNum + 1

	local requestData = TempTable.Acquire()
	requestData.name = name
	requestData.args = TempTable.Acquire(...)
	requestData.seq = private.rpcSeqNum
	local numBytes = Comm.SendData(Constants.DATA_TYPES.RPC_CALL, character, requestData)
	TempTable.Release(requestData.args)
	TempTable.Release(requestData)

	local context = TempTable.Acquire()
	context.name = name
	context.character = character
	context.handler = handler
	context.timeoutTime = LibTSMService.GetTime() + RPC_EXTRA_TIMEOUT + private.EstimateTransferTime(numBytes)
	private.pendingRPC[private.rpcSeqNum] = context
	private.pendingTimer:RunForTime(1)

	return true, (context.timeoutTime - LibTSMService.GetTime()) * 2 / 3
end



-- ============================================================================
-- Message Handlers
-- ============================================================================

function private.HandleCall(_, sourcePlayer, data)
	if type(data) ~= "table" or type(data.name) ~= "string" or type(data.seq) ~= "number" or type(data.args) ~= "table" then
		return
	end
	if not private.rpcFunctions[data.name] then
		return
	end
	local responseData = TempTable.Acquire()

	local funcStartTime = LibTSMService.GetTime()
	responseData.result = TempTable.Acquire(private.rpcFunctions[data.name](unpack(data.args)))
	local funcTimeTaken = LibTSMService.GetTime() - funcStartTime
	if funcTimeTaken > CALLBACK_TIME_WARNING_THRESHOLD then
		Log.Warn("RPC (%s) took %0.5fs", tostring(data.name), funcTimeTaken)
	end
	responseData.seq = data.seq
	local sendStartTime = LibTSMService.GetTime()
	local numBytes = Comm.SendData(Constants.DATA_TYPES.RPC_RETURN, sourcePlayer, responseData)
	local sendTimeTaken = LibTSMService.GetTime() - sendStartTime
	if sendTimeTaken > CALLBACK_TIME_WARNING_THRESHOLD then
		Log.Warn("Sending RPC result (%s) took %0.5fs (%d bytes)", tostring(data.name), sendTimeTaken, numBytes)
	end
	TempTable.Release(responseData.result)
	TempTable.Release(responseData)

	local transferTime = private.EstimateTransferTime(numBytes)
	if transferTime > 1 then
		-- We sent more than 1 second worth of data back, so send a preamble to allow the source to adjust its timeout accordingly.
		local preambleData = TempTable.Acquire()
		preambleData.transferTime = transferTime
		preambleData.seq = data.seq
		Comm.SendData(Constants.DATA_TYPES.RPC_PREAMBLE, sourcePlayer, preambleData)
		TempTable.Release(preambleData)
	end
end

function private.HandleReturn(_, character, data)
	if type(data.seq) ~= "number" or type(data.result) ~= "table" then
		return
	end
	local context = private.pendingRPC[data.seq]
	if not context then
		return
	end
	assert(character == context.character)
	local startTime = LibTSMService.GetTime()
	context.handler(true, context.character, unpack(data.result))
	local timeTaken = LibTSMService.GetTime() - startTime
	if timeTaken > CALLBACK_TIME_WARNING_THRESHOLD then
		Log.Warn("RPC (%s) result handler took %0.5fs", tostring(context.name), timeTaken)
	end
	TempTable.Release(context)
	private.pendingRPC[data.seq] = nil
end

function private.HandlePreamble(_, _, data)
	if type(data.seq) ~= "number" or type(data.transferTime) ~= "number" then
		return
	elseif not private.pendingRPC[data.seq] then
		return
	end
	-- Extend the timeout
	private.pendingRPC[data.seq].timeoutTime = LibTSMService.GetTime() + RPC_EXTRA_TIMEOUT + data.transferTime
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.EstimateTransferTime(numBytes)
	-- luacheck: globals ChatThrottleLib
	return ceil(numBytes / (ChatThrottleLib.MAX_CPS / 2))
end

function private.HandlePendingRPC()
	if not next(private.pendingRPC) then
		return
	end
	local timedOut = TempTable.Acquire()
	for seq, info in pairs(private.pendingRPC) do
		if LibTSMService.GetTime() > info.timeoutTime then
			tinsert(timedOut, seq)
		end
	end
	for _, seq in ipairs(timedOut) do
		local context = private.pendingRPC[seq]
		Log.Warn("RPC timed out (%s)", context.name)
		context.handler(false, context.character)
		TempTable.Release(context)
		private.pendingRPC[seq] = nil
	end
	TempTable.Release(timedOut)
end
