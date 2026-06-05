-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Mirror = LibTSMService:Init("Sync.Mirror")
local Constants = LibTSMService:Include("Sync.Constants")
local Comm = LibTSMService:Include("Sync.Comm")
local Connection = LibTSMService:Include("Sync.Connection")
local EnumType = LibTSMService:From("LibTSMUtil"):Include("BaseType.EnumType")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Hash = LibTSMService:From("LibTSMUtil"):Include("Util.Hash")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local private = {
	numConnected = 0,
	accountStatus = {},
	callbacks = {},
	characterHashesTimer = nil,
	settingsDB = nil,
}
local STATUS = EnumType.New("MIRROR_STATUS", {
	UPDATING = EnumType.NewValue(),
	SYNCED = EnumType.NewValue(),
})
local BROADCAST_INTERVAL = 3



-- ============================================================================
-- Module Loading
-- ============================================================================

Mirror:OnModuleLoad(function()
	private.characterHashesTimer = DelayTimer.New("SYNC_MIRROR_CHARACTER_HASHES", private.SendCharacterHashes)
	Connection.RegisterConnectionChangedCallback(private.ConnectionChangedHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CHARACTER_HASHES_BROADCAST, private.CharacterHashesBroadcastHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CHARACTER_SETTING_HASHES_REQUEST, private.CharacterSettingHashesRequestHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CHARACTER_SETTING_HASHES_RESPONSE, private.CharacterSettingHashesResponseHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CHARACTER_SETTING_DATA_REQUEST, private.CharacterSettingDataRequestHandler)
	Comm.RegisterHandler(Constants.DATA_TYPES.CHARACTER_SETTING_DATA_RESPONSE, private.CharacterSettingDataResponseHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the mirror code.
---@param settingsDB SettingsDB The settings DB to be mirrored
function Mirror.Load(settingsDB)
	private.settingsDB = settingsDB
end

---Gets the status for an account.
---@param accountKey string The account key
---@return boolean isConnected
---@return boolean isSynced
function Mirror.GetStatus(account)
	local status = private.accountStatus[account]
	if not status then
		return false, false
	elseif status == STATUS.UPDATING then
		return true, false
	elseif status == STATUS.SYNCED then
		return true, true
	else
		error("Invalid status: "..tostring(status))
	end
end

---Registers a callback for when a setting is updated.
---@param callback fun(settingKey: string)
function Mirror.RegisterCallback(callback)
	tinsert(private.callbacks, callback)
end



-- ============================================================================
-- Connection Callback Handlers
-- ============================================================================

function private.ConnectionChangedHandler(account, player, connected)
	if connected == nil then
		-- New account, but not yet connected
		return
	end
	if connected then
		Log.Info("Connected to %s (%s)", account, player)
	else
		Log.Info("Disconnected from %s (%s)", account, player)
	end
	private.numConnected = private.numConnected + (connected and 1 or -1)
	assert(private.numConnected >= 0)
	if connected then
		private.accountStatus[account] = STATUS.UPDATING
		private.characterHashesTimer:RunForTime(0)
	else
		private.accountStatus[account] = nil
		if private.numConnected == 0 then
			private.characterHashesTimer:Cancel()
		end
	end
end



-- ============================================================================
-- Delay-Based Last Update Send Function
-- ============================================================================

function private.SendCharacterHashes()
	assert(private.numConnected > 0)
	private.characterHashesTimer:RunForTime(BROADCAST_INTERVAL)

	-- calculate the hashes of the sync settings for all characters on this account
	local hashes = TempTable.Acquire()
	for _, character in private.settingsDB:AccessibleCharacterIterator(private.settingsDB:GetLocalSyncAccountKey()) do
		hashes[character] = private.CalculateCharacterHash(character)
	end

	-- send the hashes to all connected accounts
	for _, character in Connection.ConnectedAccountIterator() do
		Comm.SendData(Constants.DATA_TYPES.CHARACTER_HASHES_BROADCAST, character, hashes)
	end
	TempTable.Release(hashes)
end



-- ============================================================================
-- Message Handlers
-- ============================================================================

function private.CharacterHashesBroadcastHandler(sourceAccount, sourcePlayer, data)
	if not Connection.IsCharacterConnected(sourcePlayer) then
		-- We're not connected to this player
		Log.Warn("Got CHARACTER_HASHES_BROADCAST for player which isn't connected")
		return
	end
	local didChange = false
	for _, character in private.settingsDB:AccessibleCharacterIterator(sourceAccount) do
		if not data[character] then
			-- This character doesn't exist anymore, so remove it
			Log.Info("Removed character: '%s'", character)
			private.settingsDB:RemoveSyncCharacter(character)
			didChange = true
		end
	end
	for character, hash in pairs(data) do
		if not private.settingsDB:GetOwnerSyncAccountKey(character) then
			-- This is a new character, so add it to our DB
			Log.Info("New character: '%s' '%s'", character, sourceAccount)
			private.settingsDB:NewSyncCharacter(sourceAccount, character)
			didChange = true
		end
		if hash ~= private.CalculateCharacterHash(character) then
			-- This character's data has changed so request a hash of each of the keys
			Log.Info("Character data has changed: '%s'", character)
			Comm.SendData(Constants.DATA_TYPES.CHARACTER_SETTING_HASHES_REQUEST, sourcePlayer, character)
			didChange = true
		end
	end
	if didChange then
		private.accountStatus[sourceAccount] = STATUS.UPDATING
	else
		private.accountStatus[sourceAccount] = STATUS.SYNCED
	end
end

function private.CharacterSettingHashesRequestHandler(sourceAccount, sourcePlayer, character)
	if not Connection.IsCharacterConnected(sourcePlayer) then
		-- we're not connected to this player
		Log.Warn("Got CHARACTER_HASHES_BROADCAST for player which isn't connected")
		return
	elseif private.settingsDB:GetOwnerSyncAccountKey(character) ~= private.settingsDB:GetLocalSyncAccountKey() then
		-- we don't own this character
		Log.Err("Request for character we don't own ('%s', '%s')", tostring(character), tostring(private.settingsDB:GetOwnerSyncAccountKey(character)))
		return
	end
	Log.Info("CHARACTER_SETTING_HASHES_REQUEST (%s)", character)
	local responseData = TempTable.Acquire()
	responseData._character = character
	for _, namespace, settingKey in private.settingsDB:SyncSettingIterator() do
		responseData[namespace.."."..settingKey] = private.CalculateCharacterSettingHash(character, namespace, settingKey)
	end
	Comm.SendData(Constants.DATA_TYPES.CHARACTER_SETTING_HASHES_RESPONSE, sourcePlayer, responseData)
	TempTable.Release(responseData)
end

function private.CharacterSettingHashesResponseHandler(sourceAccount, sourcePlayer, data)
	if not Connection.IsCharacterConnected(sourcePlayer) then
		-- we're not connected to this player
		Log.Warn("Got CHARACTER_HASHES_BROADCAST for player which isn't connected")
		return
	end
	local character = data._character
	data._character = nil
	Log.Info("CHARACTER_SETTING_HASHES_RESPONSE (%s)", character)
	for key, hash in pairs(data) do
		local namespace, settingKey = strsplit(".", key)
		if private.CalculateCharacterSettingHash(character, namespace, settingKey) ~= hash then
			-- the settings data for key changed, so request the latest data for it
			Log.Info("Setting data has changed: '%s', '%s'", character, key)
			Comm.SendData(Constants.DATA_TYPES.CHARACTER_SETTING_DATA_REQUEST, sourcePlayer, character.."."..key)
		end
	end
end

function private.CharacterSettingDataRequestHandler(sourceAccount, sourcePlayer, data)
	local character, namespace, settingKey = strsplit(".", data)
	if not Connection.IsCharacterConnected(sourcePlayer) then
		-- we're not connected to this player
		Log.Warn("Got CHARACTER_HASHES_BROADCAST for player which isn't connected")
		return
	elseif private.settingsDB:GetOwnerSyncAccountKey(character) ~= private.settingsDB:GetLocalSyncAccountKey() then
		-- we don't own this character
		Log.Err("Request for character we don't own ('%s', '%s')", tostring(character), tostring(private.settingsDB:GetOwnerSyncAccountKey(character)))
		return
	end
	Log.Info("CHARACTER_SETTING_DATA_REQUEST (%s,%s,%s)", character, namespace, settingKey)
	local responseData = TempTable.Acquire()
	responseData.character = character
	responseData.namespace = namespace
	responseData.settingKey = settingKey
	responseData.data = private.settingsDB:Get("sync", private.settingsDB:GetSyncScopeKeyByCharacter(character), namespace, settingKey)
	Comm.SendData(Constants.DATA_TYPES.CHARACTER_SETTING_DATA_RESPONSE, sourcePlayer, responseData)
	TempTable.Release(responseData)
end

function private.CharacterSettingDataResponseHandler(sourceAccount, sourcePlayer, data)
	if not Connection.IsCharacterConnected(sourcePlayer) then
		-- we're not connected to this player
		Log.Warn("Got CHARACTER_HASHES_BROADCAST for player which isn't connected")
		return
	end
	local dataValueType = type(data.data)
	Log.Info("CHARACTER_SETTING_DATA_RESPONSE (%s,%s,%s,%s,%s)", data.character, data.namespace, data.settingKey, dataValueType, (dataValueType == "string" or dataValueType == "table") and #dataValueType or "-")
	if dataValueType == "table" then
		local tbl = private.settingsDB:Get("sync", private.settingsDB:GetSyncScopeKeyByCharacter(data.character), data.namespace, data.settingKey)
		wipe(tbl)
		for i, v in pairs(data.data) do
			tbl[i] = v
		end
	else
		private.settingsDB:Set("sync", private.settingsDB:GetSyncScopeKeyByCharacter(data.character), data.namespace, data.settingKey, data.data)
	end
	for _, callback in ipairs(private.callbacks) do
		callback(data.settingKey)
	end
end



-- ============================================================================
-- Helper Functions
-- ============================================================================

function private.CalculateCharacterHash(character)
	local hash = nil
	local settingKeys = TempTable.Acquire()
	for _, namespace, settingKey in private.settingsDB:SyncSettingIterator() do
		tinsert(settingKeys, strjoin(".", namespace, settingKey))
	end
	sort(settingKeys)
	for _, key in ipairs(settingKeys) do
		hash = Hash.Calculate(key, hash)
		local namespace, settingKey = strsplit(".", key)
		local settingValue = private.settingsDB:Get("sync", private.settingsDB:GetSyncScopeKeyByCharacter(character), namespace, settingKey)
		hash = Hash.Calculate(settingValue, hash)
	end
	assert(hash)
	TempTable.Release(settingKeys)
	return hash
end

function private.CalculateCharacterSettingHash(character, namespace, settingKey)
	return Hash.Calculate(private.settingsDB:Get("sync", private.settingsDB:GetSyncScopeKeyByCharacter(character), namespace, settingKey))
end
