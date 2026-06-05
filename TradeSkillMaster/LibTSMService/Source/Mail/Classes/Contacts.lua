-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Contacts = LibTSMService:Init("Mail.Contacts")
local FriendList = LibTSMService:From("LibTSMWoW"):Include("API.FriendList")
local Guild = LibTSMService:From("LibTSMWoW"):Include("API.Guild")
local CharacterInfo = LibTSMService:From("LibTSMWoW"):Include("Util.CharacterInfo")
local SessionInfo = LibTSMService:From("LibTSMWoW"):Include("Util.SessionInfo")
local TempTable = LibTSMService:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMService:From("LibTSMUtil"):Include("Lua.Table")
local private = {
	settingsDB = nil,
	recentlyMailedStorage = nil,
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data table.
---@param settingsDB SettingsDB The settings DB
---@param recentlyMailedStorage table<string,number> Recently mailed characters (as keys)
function Contacts.Load(settingsDB, recentlyMailedStorage)
	private.settingsDB = settingsDB
	private.recentlyMailedStorage = recentlyMailedStorage
	-- Clean up the storage table
	private.recentlyMailedStorage[""] = nil
end

---Iterates over recently mailed characters.
---@return fun(): string @Iterator with fields: `name`
function Contacts.RecentIterator()
	return Table.KeyIterator(private.recentlyMailedStorage)
end

---Iterates over alt characters.
---@param regionWide boolean Whether or not to include region-wide data.
---@return fun(): string @Iterator with fields: `name`
function Contacts.AltIterator(regionWide)
	local result = TempTable.Acquire()
	for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not regionWide) do
		local realm = gsub(strmatch(factionrealm, "^[^%-]+ %- (.+)$"), "%-", "")
		for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm) do
			character = CharacterInfo.Ambiguate(gsub(character.."-"..realm, " ", ""), "none")
			if character ~= SessionInfo.GetCharacterName() then
				result[character] = true
			end
		end
	end
	return TempTable.KeyIterator(result)
end

---Iterates over friend characters.
---@return fun(): string @Iterator with fields: `name`
function Contacts.FriendsIterator()
	local result = TempTable.Acquire()
	for _, name in FriendList.Iterator() do
		if name and name ~= SessionInfo.GetDisambiguatedCharacterName() then
			local key = CharacterInfo.Ambiguate(name)
			if key then
				result[key] = true
			end
		end
	end
	return TempTable.KeyIterator(result)
end

---Iterates over guild characters.
---@return fun(): string @Iterator with fields: `name`
function Contacts.GuildIterator()
	local result = TempTable.Acquire()
	for _, name in Guild.MemberIterator() do
		if name ~= SessionInfo.GetDisambiguatedCharacterName() then
			result[CharacterInfo.Ambiguate(name)] = true
		end
	end
	return TempTable.KeyIterator(result)
end

---Removes a recent contact.
---@param name string The character name
function Contacts.RemoveRecent(name)
	private.recentlyMailedStorage[name] = nil
end
