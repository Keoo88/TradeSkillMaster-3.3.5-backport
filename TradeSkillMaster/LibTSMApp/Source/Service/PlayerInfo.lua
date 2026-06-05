-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local PlayerInfo = LibTSMApp:Init("Service.PlayerInfo")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local CharacterInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.CharacterInfo")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local SessionInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.SessionInfo")
local Guild = LibTSMApp:From("LibTSMService"):Include("Guild")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMApp:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMApp:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	settingsDB = nil,
	settings = nil,
	connectedAlts = {},
	isPlayerCache = {},
	auctionIsPlayerCache = {
		lastUpdate = 0,
	},
}
local PLAYER_LOWER = strlower(SessionInfo.GetCharacterName())
local FACTION_LOWER = strlower(SessionInfo.GetFactionName())
local REALM_LOWER = strlower(SessionInfo.GetRealmName())
local PLAYER_REALM_LOWER = PLAYER_LOWER.." - "..REALM_LOWER



-- ============================================================================
-- Module Loading
-- ============================================================================

PlayerInfo:OnModuleLoad(function()
	Guild.RegisterNameCallback(private.HandleGuildNameChange)
	AddonSettings.RegisterOnLoad("Service.PlayerInfo", function(db)
		private.settingsDB = db
		private.settings = db:NewView()
			:AddKey("factionrealm", "internalData", "guildVaults")
			:AddKey("factionrealm", "coreOptions", "ignoreGuilds")
			:AddKey("factionrealm", "internalData", "characterGuilds")
			:AddKey("sync", "internalData", "classKey")
			:AddKey("global", "coreOptions", "regionWide")
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Return all connected realm alt characters as a table.
---@return string[]
function PlayerInfo.GetConnectedAlts()
	wipe(private.connectedAlts)
	for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
		for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm) do
			local realm = gsub(strmatch(factionrealm, "^[^%-]+ %- (.+)$"), "%-", "")
			character = CharacterInfo.Ambiguate(gsub(character.."-"..realm, " ", ""), "none")
			if character ~= SessionInfo.GetCharacterName() then
				tinsert(private.connectedAlts, character)
			end
		end
	end
	sort(private.connectedAlts)
	return private.connectedAlts
end

---Iterate over all characters which are accessible.
---@param currentAccountOnly boolean If true, will only include the current account
---@return fun(): number, string, string @An iterator with the following fields: `index`, `character`, `factionrealm`
function PlayerInfo.CharacterIterator(currentAccountOnly)
	local result = TempTable.Acquire()
	for _, _, character, factionrealm in private.settings:AccessibleValueIterator("classKey") do
		if not currentAccountOnly or private.IsLocalAccountOwner(character, factionrealm) then
			Table.InsertMultiple(result, character, factionrealm)
		end
	end
	return TempTable.Iterator(result, 2)
end

---Iterate over all the guilds which are accessible.
---@param includeIgnored boolean Include ignored guilds
---@return fun(): number, string, string @An iterator with the following fields: `index`, `guildName`, `factionrealm`
function PlayerInfo.GuildIterator(includeIgnored)
	local result = TempTable.Acquire()
	for _, guildVaults, factionrealm in private.settings:AccessibleValueIterator("guildVaults") do
		local ignoreGuilds = private.settings:GetForScopeKey("ignoreGuilds", factionrealm)
		for guildName in pairs(guildVaults) do
			if includeIgnored or not ignoreGuilds[guildName] then
				Table.InsertMultiple(result, guildName, factionrealm)
			end
		end
	end
	return TempTable.Iterator(result, 2)
end

---Get the player's guild.
---@param player string The name of the player
---@return string?
function PlayerInfo.GetPlayerGuild(character, factionrealm)
	return private.settings:GetForScopeKey("characterGuilds", factionrealm)[character]
end

---Check whether or not a player belongs to the user.
---@param target string The name of the player
---@param includeAlts boolean Whether or not to include alts
---@param includeOtherFaction boolean Whether or not to include players on the other faction
---@param includeOtherAccounts boolean Whether or not to include connected accounts
---@return boolean
function PlayerInfo.IsPlayer(target, includeAlts, includeOtherFaction, includeOtherAccounts)
	local cacheKey = strjoin("%", target, includeAlts and "1" or "0", includeOtherFaction and "1" or "0", includeOtherAccounts and "1" or "0")
	if private.isPlayerCache.lastUpdate ~= ClientInfo.GetFrameNumber() then
		wipe(private.isPlayerCache)
		private.isPlayerCache.lastUpdate = ClientInfo.GetFrameNumber()
	end
	if private.isPlayerCache[cacheKey] == nil then
		private.isPlayerCache[cacheKey] = private.IsPlayerHelper(target, includeAlts, includeOtherFaction, includeOtherAccounts)
	end
	return private.isPlayerCache[cacheKey]
end

---Checks if an auction owner string contains the player.
---@param ownerStr string The auction owner string
---@return boolean
function PlayerInfo.AuctionOwnerIsPlayer(ownerStr)
	if private.auctionIsPlayerCache.lastUpdate - LibTSMApp.GetTime() > 60 then
		wipe(private.auctionIsPlayerCache)
		private.auctionIsPlayerCache.lastUpdate = LibTSMApp.GetTime()
	end
	if private.auctionIsPlayerCache[ownerStr] == nil then
		private.auctionIsPlayerCache[ownerStr] = false
		for owner in String.SplitIterator(ownerStr, ",") do
			if PlayerInfo.IsPlayer(owner, true, true, true) then
				private.auctionIsPlayerCache[ownerStr] = true
				break
			end
		end
	end
	return private.auctionIsPlayerCache[ownerStr]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsPlayerHelper(target, includeAlts, includeOtherFaction, includeOtherAccounts)
	target = strlower(target)
	if not strfind(target, " %- ") then
		target = gsub(target, "%-", " - ", 1)
	end
	if target == PLAYER_LOWER then
		return true
	elseif strfind(target, " %- ") and target == PLAYER_REALM_LOWER then
		return true
	end
	if not strfind(target, " %- ") then
		target = target.." - "..REALM_LOWER
	end
	if includeAlts then
		local result = false
		for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
			for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
				local factionKey, realm = strmatch(factionrealm, "(.+) %- (.+)")
				factionKey = strlower(factionKey)
				if not result and target == strlower(character).." - "..strlower(realm) and (includeOtherFaction or factionKey == FACTION_LOWER) and (includeOtherAccounts or private.IsLocalAccountOwner(character, factionrealm)) then
					result = true
				end
			end
		end
		return result
	end
	return false
end

function private.IsLocalAccountOwner(character, factionrealm)
	return private.settingsDB:GetOwnerSyncAccountKey(character, factionrealm) == private.settingsDB:GetLocalSyncAccountKey(factionrealm)
end

function private.HandleGuildNameChange(name)
	private.settings.characterGuilds[SessionInfo.GetCharacterName()] = name
	if not name then
		return
	end

	-- Clean up any guilds with no players in them
	local validGuilds = TempTable.Acquire()
	for _, character in private.settingsDB:AccessibleCharacterIterator(private.settingsDB:GetLocalSyncAccountKey()) do
		local guild = private.settings.characterGuilds[character]
		if guild then
			validGuilds[guild] = true
		end
	end
	Table.FilterValueNotInTable(private.settings.characterGuilds, validGuilds)
	Table.FilterKeyNotInTable(private.settings.guildVaults, validGuilds)
	TempTable.Release(validGuilds)
end
