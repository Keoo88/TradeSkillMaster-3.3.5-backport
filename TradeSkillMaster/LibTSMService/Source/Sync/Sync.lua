-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Sync = LibTSMService:Init("Sync")
local Comm = LibTSMService:Include("Sync.Comm")
local Mirror = LibTSMService:Include("Sync.Mirror")
local RPC = LibTSMService:Include("Sync.RPC")
local Connection = LibTSMService:Include("Sync.Connection")
Sync.CONNECTION_ERROR = Connection.ERROR



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads the sync code.
---@param db SettingsDB The settings DB
---@param svCopyError string The localized error to show if we detect the SV have been copied
function Sync.Load(db, svCopyError)
	local localAccountKey = db:GetLocalSyncAccountKey()

	-- Load the comm code
	local function GetOwnerSyncAccountKey(character)
		return db:GetOwnerSyncAccountKey(character)
	end
	Comm.Load(localAccountKey, svCopyError, GetOwnerSyncAccountKey)
	if db:WipedFromUserError() then
		Comm.ShowSVCopyError()
	end

	-- Load the connection code
	local function AccountIteratorFunc()
		return db:SyncAccountIterator()
	end
	local function AccessibleCharactersFunc(accountKeyFilter, resultTbl)
		for _, character in db:AccessibleCharacterIterator(accountKeyFilter) do
			tinsert(resultTbl, character)
		end
	end
	local function HandleNewAccount(accountKey, character)
		db:NewSyncCharacter(accountKey, character)
	end
	local function RemoveAccount(accountKey)
		db:RemoveSyncAccount(accountKey)
	end
	Connection.Load(localAccountKey, AccountIteratorFunc, AccessibleCharactersFunc, HandleNewAccount, RemoveAccount)

	-- Load the mirror code
	Mirror.Load(db)
end

---Registers a callback for when a connection changes.
---@param handler fun(accountKey: string, character: string, connected: boolean|nil)
function Sync.RegisterConnectionChangedCallback(callback)
	Connection.RegisterConnectionChangedCallback(callback)
end

---Registers an RPC.
---@param name string The name of the RPC (must be globally-unique)
---@param func function The function which implements the RPC
function Sync.RegisterRPC(name, func)
	RPC.Register(name, func)
end

---Calls an RPC.
---@param name string The name of the RPC
---@param targetPlayer string The player to send the RPC to
---@param handler fun(success: boolean, targetPlayer: string, ...: any) A callback function which handles the result
---@param ... any Arguments to pass to the RPC
---@return boolean success
---@return number? estimatedTime
function Sync.CallRPC(name, targetPlayer, handler, ...)
	return RPC.Call(name, targetPlayer, handler, ...)
end

---Gets the connection status for an account.
---@param accountKey string The account key
---@return boolean isConnected
---@return string? character
function Sync.GetConnectionStatus(account)
	return Connection.GetStatus(account)
end

---Gets the mirror status for an account.
---@param accountKey string The account key
---@return boolean isConnected
---@return boolean isSynced
function Sync.GetMirrorStatus(account)
	return Mirror.GetStatus(account)
end

---Registers a callback for when a setting is updated.
---@param callback fun(settingKey: string)
function Sync.RegisterMirrorCallback(callback)
	Mirror.RegisterCallback(callback)
end

---Establishes a new connection.
---@param targetCharacter string The character to connect to
---@return boolean isConnecting
---@return EnumValue errType
function Sync.EstablishConnection(character)
	return Connection.Establish(character)
end

---Gets the character actively being connected to.
---@return string?
function Sync.GetConnectingCharacter()
	return Connection.GetConnectingCharacter()
end

---Removes the connection to an account.
---@param accountKey string The account key
function Sync.RemoveAccount(account)
	Connection.Remove(account)
end
