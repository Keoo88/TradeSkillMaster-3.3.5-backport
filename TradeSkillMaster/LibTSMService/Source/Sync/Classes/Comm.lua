-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Comm = LibTSMService:Init("Sync.Comm")
local Constants = LibTSMService:Include("Sync.Constants")
local ChatMessage = LibTSMService:Include("UI.ChatMessage")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local ClientInfo = LibTSMService:From("LibTSMWoW"):Include("Util.ClientInfo")
local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local private = {
	localAccountKey = nil,
	svCopyError = nil,
	ownerAccountKeyFunc = nil,
	svCopyErrorTime = 0,
	disconnectFunc = nil,
	handler = {},
	queuedPacket = {},
	queuedSourceCharacter = {},
	queueTimer = nil,
	versionStr = Constants.VERSION.."_"..ClientInfo.GetLocale(),
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Comm:OnModuleLoad(function()
	private.queueTimer = DelayTimer.New("SYNC_COMM_QUEUE", private.ProcessReceiveQueue)
	AceComm:RegisterComm("TSMSyncData", private.OnCommReceived)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the comm code.
---@param localAccountKey string The local account key
---@param svCopyError string The localized error to show if we detect the SV have been copied
---@param ownerAccountKeyFunc fun(character: string): string A function to look up the owner account key for a character
function Comm.Load(localAccountKey, svCopyError, ownerAccountKeyFunc)
	private.localAccountKey = localAccountKey
	private.svCopyError = svCopyError
	private.ownerAccountKeyFunc = ownerAccountKeyFunc
end

---Sets the function to call to force a character to be disconnected.
---@param func fun(character: string) The function
function Comm.SetDisconnectFunction(func)
	private.disconnectFunc = func
end

---Registers a handler function for a data type.
---@param dataType string The data type (value of `Constants.DATA_TYPES`)
---@param handler fun(sourceAccount: string, sourceCharacter: string, data: any) The handler function
function Comm.RegisterHandler(dataType, handler)
	assert(Table.KeyByValue(Constants.DATA_TYPES, dataType) ~= nil)
	assert(not private.handler[dataType])
	private.handler[dataType] = handler
end

---Sends data to a target character and returns the number of bytes sent.
---@param dataType string The data type (value of `Constants.DATA_TYPES`)
---@param targetCharacter string The character to send to
---@param data any The data to send
---@return number
function Comm.SendData(dataType, targetCharacter, data)
	assert(type(dataType) == "string" and #dataType == 1)
	local serialized = LibSerialize:Serialize(private.versionStr, dataType, private.localAccountKey, data)
	local compressed = LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(serialized))
	assert(LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(compressed)) == serialized)

	-- Give heartbeats and rpc preambles a higher priority
	local priority = (dataType == Constants.DATA_TYPES.HEARTBEAT or dataType == Constants.DATA_TYPES.RPC_PREAMBLE) and "ALERT" or nil
	-- Send the message
	AceComm:SendCommMessage("TSMSyncData", compressed, "WHISPER", targetCharacter, priority)
	return #compressed
end

---Shows the SV copy error in chat.
function Comm.ShowSVCopyError()
	if LibTSMService.GetTime() - private.svCopyErrorTime < 60 then
		return
	end
	private.svCopyErrorTime = LibTSMService.GetTime()
	ChatMessage.PrintfUser(private.svCopyError)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnCommReceived(_, packet, _, sourceCharacter)
	-- Delay the processing to make sure it happens within a debuggable context (this function is called via pcall)
	tinsert(private.queuedPacket, packet)
	tinsert(private.queuedSourceCharacter, sourceCharacter)
	private.queueTimer:RunForFrames(0)
end

function private.ProcessReceiveQueue()
	assert(#private.queuedPacket == #private.queuedSourceCharacter)
	while #private.queuedPacket > 0 do
		local packet = tremove(private.queuedPacket, 1)
		local sourceCharacter = tremove(private.queuedSourceCharacter, 1)
		private.ProcessReceivedPacket(packet, sourceCharacter)
	end
end

function private.ProcessReceivedPacket(msg, sourceCharacter)
	-- Remove realm name from source player
	sourceCharacter = strsplit("-", sourceCharacter)
	sourceCharacter = strtrim(sourceCharacter)
	local sourceCharacterAccountKey = private.ownerAccountKeyFunc(sourceCharacter)
	if sourceCharacterAccountKey and sourceCharacterAccountKey == private.localAccountKey then
		Log.Err("We own the source character")
		Comm.ShowSVCopyError()
		return
	end

	if ClientInfo.IsInCombat() then
		-- In combat, so drop the connection
		private.disconnectFunc(sourceCharacter)
		return
	end

	-- Decode and decompress
	msg = LibDeflate:DecompressDeflate(LibDeflate:DecodeForWoWAddonChannel(msg))
	if not msg then
		Log.Err("Invalid packet")
		return
	end
	local success, versionStr, dataType, sourceAccount, data = LibSerialize:Deserialize(msg)
	if not success then
		Log.Err("Invalid packet")
		return
	end

	-- Validate the packet
	if versionStr ~= private.versionStr or type(dataType) ~= "string" or #dataType ~= 1 or not sourceAccount then
		Log.Info("Invalid message received")
		return
	elseif sourceAccount == private.localAccountKey then
		Log.Err("We are the source account (SV copy)")
		Comm.ShowSVCopyError()
		return
	elseif sourceCharacterAccountKey and sourceCharacterAccountKey ~= sourceAccount then
		-- The source player now belongs to a different account than what we expect
		Log.Err("Unexpected source account")
		Comm.ShowSVCopyError()
		return
	end

	if private.handler[dataType] then
		private.handler[dataType](sourceAccount, sourceCharacter, data)
	else
		Log.Info("Received unhandled message of type: "..strbyte(dataType))
	end
end
