-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Connection = LibTSMService:Init("Sync.Connection")
local Comm = LibTSMService:Include("Sync.Comm")
local Constants = LibTSMService:Include("Sync.Constants")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local Threading = LibTSMService:From("LibTSMTypes"):Include("Threading")
local FriendList = LibTSMService:From("LibTSMWoW"):Include("API.FriendList")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Event = LibTSMService:From("LibTSMWoW"):Include("Service.Event")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	managementTimer = nil,
	newAccountTimer = nil,
	friendsInfoTimer = nil,
	localAccountKey = nil,
	accountIteratorFunc = nil,
	accessibleCharactersFunc = nil,
	newAccountHandler = nil,
	removeAccountHandler = nil,
	isActive = false,
	hasFriendsInfo = false,
	newCharacter = nil,
	newAccount = nil,
	newSyncAcked = nil,
	connectionChangedCallbacks = {},
	threadId = {},
	threadRunning = {},
	connectedCharacter = {},
	lastHeartbeat = {},
	suppressThreadTime = {},
	connectionRequestReceived = {},
}
Connection.ERROR = EnumType.New("CONNECTION_ERROR", {
	NOT_READY = EnumType.NewValue(),
	CURRENT_CHARACTER = EnumType.NewValue(),
	NOT_ONLINE = EnumType.NewValue(),
	ALREADY_KNOWN = EnumType.NewValue(),
})
local RECEIVE_TIMEOUT = 5
local HEARTBEAT_TIMEOUT = 10



-- ============================================================================
-- Module Loading
-- ============================================================================

Connection:OnModuleLoad(function()
	private.managementTimer = DelayTimer.New("SYNC_CONNECTION_MANAGEMENT", private.ManagementLoop)
	private.newAccountTimer = DelayTimer.New("SYNC_CONNECTION_NEW_ACCOUNT", private.SendNewAccountWhoAmI)
	private.friendsInfoTimer = DelayTimer.New("SYNC_CONNECTION_FRIENDS_INFO", FriendList.Query)
end)

Connection:OnModuleUnload(function()
	for _, player in pairs(private.connectedCharacter) do
		private.DisconnectCharacter(player)
	end
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and starts the connection code.
---@param localAccountKey string The local account key
---@param accountIteratorFunc function Function which returns an iterator with fields: `index`, `accountKey`
---@param accessibleCharactersFunc fun(accountKeyFilter?: string, resultTbl: string[]) Function which populates a list of accessible characters
---@param newAccountHandler fun(accountKey: string, character: string) Handler for a new account being added
---@param removeAccountHandler fun(accountKey: string) Handler for an account being removed
function Connection.Load(localAccountKey, accountIteratorFunc, accessibleCharactersFunc, newAccountHandler, removeAccountHandler)
	private.localAccountKey = localAccountKey
	private.accountIteratorFunc = accountIteratorFunc
	private.accessibleCharactersFunc = accessibleCharactersFunc
	private.newAccountHandler = newAccountHandler
	private.removeAccountHandler = removeAccountHandler

	for _ in private.accountIteratorFunc() do
		private.isActive = true
	end

	Comm.SetDisconnectFunction(private.DisconnectCharacter)
	Comm.RegisterHandler(Constants.DATA_TYPES.WHOAMI_ACCOUNT, private.WhoAmIAccountHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.WHOAMI_ACK, private.WhoAmIAckHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CONNECTION_REQUEST, private.ConnectionRequestAndAckHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CONNECTION_REQUEST_ACK, private.ConnectionRequestAndAckHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.DISCONNECT, private.DisconnectHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.HEARTBEAT, private.HeartbeatHandler)

	Event.Register("FRIENDLIST_UPDATE", private.PrepareFriendsInfo)
	private.PrepareFriendsInfo()
end

---Registers a callback for when a connection changes.
---@param handler fun(accountKey: string, character: string, connected: boolean|nil)
function Connection.RegisterConnectionChangedCallback(handler)
	tinsert(private.connectionChangedCallbacks, handler)
end

---Returns if a character is connected or not.
---@param character string The character
---@return boolean
function Connection.IsCharacterConnected(character)
	return Table.KeyByValue(private.connectedCharacter, character) ~= nil
end

---Iteartes over the connected accounts.
---@return fun(): string, string @Iterator with fields: `accountKey`, `character`
function Connection.ConnectedAccountIterator()
	return pairs(private.connectedCharacter)
end

---Establishes a new connection.
---@param targetCharacter string The character to connect to
---@return boolean isConnecting
---@return EnumValue? errType
function Connection.Establish(targetCharacter)
	if not private.hasFriendsInfo then
		return false, Connection.ERROR.NOT_READY
	end
	local wasFriend = FriendList.IsFriend(targetCharacter)
	if strlower(targetCharacter) == strlower(SessionInfo.GetCharacterName()) then
		return false, Connection.ERROR.CURRENT_CHARACTER
	elseif not private.IsOnline(targetCharacter) and wasFriend then
		return false, Connection.ERROR.NOT_ONLINE
	end
	local invalidCharacter = false
	local accessibleCharacters = TempTable.Acquire()
	private.accessibleCharactersFunc(nil, accessibleCharacters)
	for _, player in ipairs(accessibleCharacters) do
		if strlower(player) == strlower(targetCharacter) then
			invalidCharacter = true
		end
	end
	TempTable.Release(accessibleCharacters)
	if invalidCharacter then
		return false, Connection.ERROR.ALREADY_KNOWN
	end
	if not private.isActive then
		private.isActive = true
		private.managementTimer:RunForTime(1)
	end
	private.newCharacter = targetCharacter
	private.newAccount = nil
	private.newSyncAcked = nil
	private.newAccountTimer:Cancel()
	private.newAccountTimer:RunForTime(0)
	return true
end

---Gets the character currently being connected to.
---@return string
function Connection.GetConnectingCharacter()
	return private.newCharacter
end

---Gets the status for an account.
---@param accountKey string The account key
---@return boolean isConnected
---@return string? character
function Connection.GetStatus(accountKey)
	if private.connectedCharacter[accountKey] then
		return true, private.connectedCharacter[accountKey]
	else
		return false
	end
end

---Removes the connection to an account.
---@param accountKey string The account key
function Connection.Remove(accountKey)
	if private.threadRunning[accountKey] then
		private.KillConnectionThread(accountKey)
	end
	private.removeAccountHandler(accountKey)
end



-- ============================================================================
-- Message Handlers
-- ============================================================================

function private.WhoAmIAckHandler(sourceAccount, sourceCharacter, data)
	if not private.newCharacter or strlower(private.newCharacter) ~= strlower(sourceCharacter) then
		-- we aren't trying to connect with a new account
		return
	end
	Log.Info("WHOAMI_ACK '%s'", tostring(private.newCharacter))
	private.newSyncAcked = true
	private.CheckNewAccountStatus()
end

function private.WhoAmIAccountHandler(sourceAccount, sourceCharacter, data)
	if not private.newCharacter then
		-- we aren't trying to connect with a new account
		return
	elseif strlower(private.newCharacter) ~= strlower(sourceCharacter) then
		Log.Info("WHOAMI_ACCOUNT from unknown player \"%s\", expected \"%s\"", private.newCharacter, sourceCharacter)
		return
	end
	private.newCharacter = sourceCharacter -- get correct capatilization
	private.newAccount = sourceAccount
	Log.Info("WHOAMI_ACCOUNT '%s' '%s'", private.newCharacter, private.newAccount)
	Comm.SendData(Constants.DATA_TYPES.WHOAMI_ACK, private.newCharacter)
	private.CheckNewAccountStatus()
end

function private.ConnectionRequestAndAckHandler(sourceAccount, sourceCharacter, data)
	if not private.threadRunning[sourceAccount] then
		return
	end
	private.connectionRequestReceived[sourceAccount] = true
end

function private.DisconnectHandler(sourceAccount, sourceCharacter, data)
	if not private.threadRunning[sourceAccount] then
		return
	end

	-- kill the thread and prevent it from running again for 2 seconds
	private.KillConnectionThread(sourceAccount)
	private.suppressThreadTime[sourceAccount] = LibTSMService.GetTime() + 2
end

function private.HeartbeatHandler(sourceAccount, sourceCharacter)
	if not Connection.IsCharacterConnected(sourceCharacter) then
		-- We're not connected to this player
		return
	end
	private.lastHeartbeat[sourceAccount] = LibTSMService.GetTime()
end



-- ============================================================================
-- Management Loop / Sync Thread
-- ============================================================================

function private.PrepareFriendsInfo()
	if not FriendList.IsPopulated() then
		-- Try again
		Log.Err("Missing friends info - will try again")
		private.friendsInfoTimer:RunForTime(0.5)
		return
	end

	if not private.hasFriendsInfo and private.isActive then
		-- start the management loop
		private.managementTimer:RunForTime(1)
	end
	private.hasFriendsInfo = true
end

function private.ManagementLoop()
	private.managementTimer:RunForTime(1)
	-- continuously spawn connection threads with online players as necessary
	FriendList.Query()
	local hasAccount = false
	for _, account in private.accountIteratorFunc() do
		hasAccount = true
		local targetCharacter = private.GetTargetCharacter(account)
		if targetCharacter then
			if not private.threadId[account] then
				private.threadId[account] = Threading.New("SYNC_"..strmatch(account, "(%d+)$"), private.ConnectionThread)
			end
			if not private.threadRunning[account] and (private.suppressThreadTime[account] or 0) < LibTSMService.GetTime() then
				private.threadRunning[account] = true
				Threading.Start(private.threadId[account], account, targetCharacter)
			end
		end
	end
	if not hasAccount then
		Log.Info("No more sync accounts.")
		private.isActive = false
		if not private.newCharacter then
			private.managementTimer:Cancel()
		end
	end
end

function private.ConnectionThreadInner(account, targetCharacter)
	-- For the initial handshake, the lower account key is the server, other is the client - after this it doesn't matter
	-- add some randomness to the timeout so we don't get stuck in a race condition
	local timeout = LibTSMService.GetTime() + RECEIVE_TIMEOUT + random(0, 1000) / 1000
	if account < private.localAccountKey then
		-- Wait for the connection request from the client
		while not private.connectionRequestReceived[account] do
			if LibTSMService.GetTime() > timeout then
				-- Timed out on the connection - don't try again for a bit
				Log.Warn("Timed out")
				return
			end
			Threading.Yield(true)
		end
		-- Send an connection request ACK back to the client
		Comm.SendData(Constants.DATA_TYPES.CONNECTION_REQUEST_ACK, targetCharacter)
	else
		-- Send a connection request to the server
		Comm.SendData(Constants.DATA_TYPES.CONNECTION_REQUEST, targetCharacter)
		-- Wait for the connection request ACK
		while not private.connectionRequestReceived[account] do
			if LibTSMService.GetTime() > timeout then
				-- Timed out on the connection - don't try again for a bit
				Log.Warn("Timed out")
				private.suppressThreadTime[account] = LibTSMService.GetTime() + RECEIVE_TIMEOUT
				return
			end
			Threading.Yield(true)
		end
	end

	-- We are now connected
	Log.Info("Connected to: %s %s", account, targetCharacter)
	private.connectedCharacter[account] = targetCharacter
	private.lastHeartbeat[account] = LibTSMService.GetTime()
	for _, callback in ipairs(private.connectionChangedCallbacks) do
		callback(account, targetCharacter, true)
	end

	-- Now that we are connected, data can flow in both directions freely
	local lastHeartbeatSend = LibTSMService.GetTime()
	while true do
		-- Check if they either logged off or the heartbeats have timed-out
		if not private.IsOnline(targetCharacter, true) or LibTSMService.GetTime() - private.lastHeartbeat[account] > HEARTBEAT_TIMEOUT then
			return
		end

		-- Check if we should send a heartbeat
		if LibTSMService.GetTime() - lastHeartbeatSend > floor(HEARTBEAT_TIMEOUT / 2) then
			Comm.SendData(Constants.DATA_TYPES.HEARTBEAT, targetCharacter)
			lastHeartbeatSend = LibTSMService.GetTime()
		end

		Threading.Yield(true)
	end
end

function private.ConnectionThread(account, targetCharacter)
	private.ConnectionThreadInner(account, targetCharacter)
	private.ConnectionThreadDone(account)
end

function private.ConnectionThreadDone(account)
	Log.Info("Connection ended to %s", account)
	local player = private.connectedCharacter[account]
	private.connectedCharacter[account] = nil
	if player then
		for _, callback in ipairs(private.connectionChangedCallbacks) do
			callback(account, player, false)
		end
	end
	private.threadRunning[account] = nil
	private.connectionRequestReceived[account] = nil
end



-- ============================================================================
-- Helper Functions
-- ============================================================================

function private.SendNewAccountWhoAmI()
	if not private.newCharacter then
		private.newAccountTimer:Cancel()
	elseif not FriendList.IsFriend(private.newCharacter) then
		Log.Info("Waiting for friends list to update")
		private.newAccountTimer:RunForTime(1)
	elseif not private.IsOnline(private.newCharacter) then
		private.newAccountTimer:Cancel()
		private.newCharacter = nil
		private.newAccount = nil
		private.newSyncAcked = nil
		Log.Err("New player went offline")
	else
		Comm.SendData(Constants.DATA_TYPES.WHOAMI_ACCOUNT, private.newCharacter)
		Log.Info("Sent WHOAMI_ACCOUNT")
		private.newAccountTimer:RunForTime(1)
	end
end

function private.CheckNewAccountStatus()
	if not private.newCharacter or not private.newAccount or not private.newSyncAcked then
		return
	end
	Log.Info("New sync character: '%s' '%s'", private.newCharacter, private.newAccount)
	-- The other account ACK'd so setup a connection
	private.newAccountHandler(private.newAccount, private.newCharacter)

	-- Call the callbacks for this new account
	for _, callback in ipairs(private.connectionChangedCallbacks) do
		callback(private.newAccount, private.newCharacter, nil)
	end

	private.newCharacter = nil
	private.newAccount = nil
	private.newSyncAcked = nil
end

function private.GetTargetCharacter(account)
	local characters = TempTable.Acquire()
	private.accessibleCharactersFunc(account, characters)

	-- Find the player to connect to without adding to the friends list
	for _, player in ipairs(characters) do
		if private.IsOnline(player, true) then
			TempTable.Release(characters)
			return player
		end
	end
	-- If we failed, try again with adding to friends list
	for _, player in ipairs(characters) do
		if private.IsOnline(player) then
			TempTable.Release(characters)
			return player
		end
	end
	TempTable.Release(characters)
end

function private.IsOnline(target, noAdd)
	if FriendList.IsFriend(target) then
		return FriendList.IsOnline(target)
	elseif not noAdd and FriendList.CanAdd(target) then
		-- Add them as a friend
		FriendList.Add(target)
		FriendList.Query()
		return FriendList.IsOnline(target)
	else
		return false
	end
end

function private.DisconnectCharacter(character)
	local account = Table.KeyByValue(private.connectedCharacter, character)
	if not account or not private.threadRunning[account] then
		return
	end
	Comm.SendData(Constants.DATA_TYPES.DISCONNECT, character)
	private.KillConnectionThread(account)
end

function private.KillConnectionThread(account)
	Threading.Kill(private.threadId[account])
	private.ConnectionThreadDone(account)
end
