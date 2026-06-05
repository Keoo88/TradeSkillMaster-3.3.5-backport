-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local GroupsSync = TSM.Groups:NewPackage("Sync") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local Operation = TSM.LibTSMTypes:Include("Operation")
local Sync = TSM.LibTSMService:Include("Sync")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local private = {
	settingsDB = nil,
	settings = nil,
}



-- ============================================================================
-- New Modules Functions
-- ============================================================================

function GroupsSync.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("profile", "userData", "groups")
		:AddKey("profile", "userData", "items")
		:AddKey("profile", "userData", "operations")
	Sync.RegisterRPC("CREATE_PROFILE", private.RPCCreateProfile)
end

function GroupsSync.SendCurrentProfile(targetPlayer)
	local profileName = private.settingsDB:GetCurrentProfile()
	local data = TempTable.Acquire()
	data.groups = TempTable.Acquire()
	for groupPath, moduleOperations in pairs(private.settings:GetForScopeKey("groups", profileName)) do
		data.groups[groupPath] = {}
		for _, module in Operation.TypeIterator() do
			local operations = moduleOperations[module]
			if operations.override then
				data.groups[groupPath][module] = operations
			end
		end
	end
	data.items = private.settings:GetForScopeKey("items", profileName)
	data.operations = private.settings:GetForScopeKey("operations", profileName)
	local result, estimatedTime = Sync.CallRPC("CREATE_PROFILE", targetPlayer, private.RPCCreateProfileResultHandler, profileName, UnitName("player"), data)
	if result then
		estimatedTime = max(Math.Round(estimatedTime, 60), 60)
		ChatMessage.PrintfUser(L["Sending your '%s' profile to %s. Please keep both characters online until this completes. This will take approximately: %s"], profileName, targetPlayer, SecondsToTime(estimatedTime))
	else
		ChatMessage.PrintUser(L["Failed to send profile. Ensure both characters are online and try again."])
	end
	TempTable.Release(data.groups)
	TempTable.Release(data)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CopyTable(srcTbl, dstTbl)
	for k, v in pairs(srcTbl) do
		dstTbl[k] = v
	end
end

function private.RPCCreateProfile(profileName, playerName, data)
	assert(private.settingsDB:IsValidProfileName(profileName))
	if private.settingsDB:ProfileExists(profileName) then
		return false, L["A profile with that name already exists on the target account. Rename it first and try again."]
	end

	-- Create the new profile
	private.settingsDB:CreateProfile(profileName)

	-- Copy all the data into this new profile
	private.CopyTable(data.groups, private.settings:GetForScopeKey("groups", profileName))
	private.CopyTable(data.items, private.settings:GetForScopeKey("items", profileName))
	private.CopyTable(data.operations, private.settings:GetForScopeKey("operations", profileName))

	ChatMessage.PrintfUser(L["Added '%s' profile which was received from %s."], profileName, playerName)

	return true, profileName, UnitName("player")
end

function private.RPCCreateProfileResultHandler(_, _, success, ...)
	if success == nil then
		ChatMessage.PrintUser(L["Failed to send profile."].." "..L["Ensure both characters are online and try again."])
		return
	elseif not success then
		local errMsg = ...
		ChatMessage.PrintUser(L["Failed to send profile."].." "..errMsg)
		return
	end

	local profileName, targetPlayer = ...
	ChatMessage.PrintfUser(L["Successfully sent your '%s' profile to %s!"], profileName, targetPlayer)
end
