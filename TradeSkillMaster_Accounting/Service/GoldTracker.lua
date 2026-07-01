-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local GoldTracker = TSM.Accounting:NewPackage("GoldTracker") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local GoldLog = TSM.LibTSMTypes:IncludeClassType("GoldLog")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local Guild = TSM.LibTSMWoW:Include("API.Guild")
local Container = TSM.LibTSMWoW:Include("API.Container")
local private = {
	truncateGoldLog = {},
	characterLog = {}, ---@type table<string,GoldLog>
	characterLastUpdate = {}, ---@type table<string,number>
	guildLog = {}, ---@type table<string,GoldLog>
	guildLastUpdate = {}, ---@type table<string,number>
	warbankLog = nil, ---@type GoldLog?
	warbankLogLastUpdate = nil, ---@type number?
	currentCharacterKey = nil, ---@type string
	playerLogCount = 0,
	playerGoldRetryTimer = nil,
	settings = nil,
}
local SECONDS_PER_MIN = 60
local SECONDS_PER_DAY = SECONDS_PER_MIN * 60 * 24



-- ============================================================================
-- Module Functions
-- ============================================================================

function GoldTracker.OnInitialize(settingsDB)
	private.playerGoldRetryTimer = DelayTimer.New("PLAYER_GOLD_RETRY", private.PlayerLogGold)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
		DefaultUI.RegisterGuildBankVisibleCallback(private.GuildLogGold, true)
		Event.Register("GUILDBANK_UPDATE_MONEY", private.GuildLogGold)
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		DefaultUI.RegisterBankVisibleCallback(private.WarbankLogGold, true)
		Event.Register("ACCOUNT_MONEY", private.WarbankLogGold)
	end
	Event.Register("PLAYER_MONEY", private.PlayerLogGold)

	private.settings = settingsDB:NewView()
		:AddKey("sync", "internalData", "goldLog")
		:AddKey("sync", "internalData", "goldLogLastUpdate")
		:AddKey("sync", "internalData", "money")
		:AddKey("factionrealm", "internalData", "guildGoldLog")
		:AddKey("factionrealm", "internalData", "guildGoldLogLastUpdate")
		:AddKey("factionrealm", "internalData", "characterGuilds")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("global", "internalData", "warbankGoldLog")
		:AddKey("global", "internalData", "warbankGoldLogLastUpdate")

	-- Get a list of known guilds and load character gold log data
	local validGuilds = TempTable.Acquire()
	for _, data, character, factionrealm in private.settings:AccessibleValueIterator("goldLog") do
		local guild = private.settings:GetForScopeKey("characterGuilds", factionrealm)[character]
		if guild then
			validGuilds[guild] = true
		end
		local lastUpdate = private.settings:GetForScopeKey("goldLogLastUpdate", character, factionrealm) or 0
		local characterKey = SessionInfo.FormatCharacterName(character, factionrealm, true)
		private.LoadCharacterGoldLog(characterKey, data, lastUpdate)
	end

	-- Load guild gold log data
	for _, guildData, factionrealm in private.settings:AccessibleValueIterator("guildGoldLog") do
		for guild, data in pairs(guildData) do
			local log = GoldLog.Load(data) or GoldLog.New()
			private.guildLog[guild] = log
			local endMinute = log:GetEndMinute()
			local lastEntryTime = endMinute and endMinute * SECONDS_PER_MIN or math.huge
			local lastUpdate = private.settings:GetForScopeKey("guildGoldLogLastUpdate", factionrealm)
			if not validGuilds[guild] and max(lastEntryTime, lastUpdate and lastUpdate[guild] or 0) < time() - 30 * SECONDS_PER_DAY then
				-- This guild may not be valid and the last entry is over 30 days old, so truncate the data
				private.truncateGoldLog[guild] = lastEntryTime
			end
		end
	end

	-- Load warbank gold log data
	if ClientInfo.HasFeature(ClientInfo.FEATURES.WARBAND_BANK) then
		private.warbankLog = GoldLog.Load(private.settings.warbankGoldLog) or GoldLog.New()
		private.warbankLogLastUpdate = private.settings.warbankGoldLogLastUpdate
	end

	TempTable.Release(validGuilds)
	private.currentCharacterKey = SessionInfo.FormatCharacterName(SessionInfo.GetCharacterName(), SessionInfo.GetFactionrealmName(), true)
	assert(private.characterLog[private.currentCharacterKey])
end

function GoldTracker.OnEnable()
	-- Log the current player gold (need to wait for OnEnable, otherwise GetMoney() returns 0 when first logging in)
	private.PlayerLogGold()
	-- Log warbank gold amount
	private.WarbankLogGold()
end

function GoldTracker.OnDisable()
	private.PlayerLogGold()
	private.settings.goldLog = private.characterLog[private.currentCharacterKey]:Serialize()
	private.settings.goldLogLastUpdate = private.characterLastUpdate[private.currentCharacterKey]
	local guild = PlayerInfo.GetPlayerGuild(SessionInfo.GetCharacterName(), SessionInfo.GetFactionrealmName())
	if guild and private.guildLog[guild] then
		private.settings.guildGoldLog[guild] = private.guildLog[guild]:Serialize()
		private.settings.guildGoldLogLastUpdate[guild] = private.guildLastUpdate[guild]
	end
	if private.warbankLog then
		private.settings.warbankGoldLog = private.warbankLog:Serialize()
		private.settings.warbankGoldLogLastUpdate = private.warbankLogLastUpdate
	end
end

function GoldTracker.GetCharacterGuilds(resultTbl)
	for character in pairs(private.characterLog) do
		tinsert(resultTbl, character)
	end
	for guild in pairs(private.guildLog) do
		tinsert(resultTbl, guild)
	end
	if private.warbankLog then
		tinsert(resultTbl, L["Warbank"])
	end
end

function GoldTracker.GetGoldAtTime(timestamp, ignoredCharactersGuilds)
	local value = 0
	local timestampMinute = floor(timestamp / SECONDS_PER_MIN)
	for key, log in pairs(private.characterLog) do
		if not ignoredCharactersGuilds[key] and (private.truncateGoldLog[key] or math.huge) > timestamp then
			value = value + log:GetValue(timestampMinute)
		end
	end
	for key, log in pairs(private.guildLog) do
		if not ignoredCharactersGuilds[key] and (private.truncateGoldLog[key] or math.huge) > timestamp then
			value = value + log:GetValue(timestampMinute)
		end
	end
	if private.warbankLog and not ignoredCharactersGuilds[L["Warbank"]] then
		value = value + private.warbankLog:GetValue(timestampMinute)
	end
	return value
end

function GoldTracker.GetGraphTimeRange(ignoredCharactersGuilds)
	local minTime = Math.Floor(time(), SECONDS_PER_MIN)
	for key, log in pairs(private.characterLog) do
		if not ignoredCharactersGuilds[key] then
			local startMinute = log:GetStartMinute()
			if startMinute then
				minTime = min(minTime, startMinute * SECONDS_PER_MIN)
			end
		end
	end
	for key, log in pairs(private.guildLog) do
		if not ignoredCharactersGuilds[key] then
			local startMinute = log:GetStartMinute()
			if startMinute then
				minTime = min(minTime, startMinute * SECONDS_PER_MIN)
			end
		end
	end
	if private.warbankLog and not ignoredCharactersGuilds[L["Warbank"]] then
		local startMinute = private.warbankLog:GetStartMinute()
		if startMinute then
			minTime = min(minTime, startMinute * SECONDS_PER_MIN)
		end
	end
	return minTime, Math.Floor(time(), SECONDS_PER_MIN), SECONDS_PER_MIN
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadCharacterGoldLog(characterKey, data, lastUpdate)
	assert(not private.characterLog[characterKey])
	local log = GoldLog.Load(data)
	if not log then
		Log.Err("Failed to decode (%s, %d)", characterKey, #data)
		private.characterLog[characterKey] = GoldLog.New()
		return
	end
	log:Clean()
	private.characterLastUpdate[characterKey] = lastUpdate
	private.characterLog[characterKey] = log
end

function private.GuildLogGold()
	local guild = Guild.GetName()
	local isGuildLeader = Guild.IsLeader()
	if guild and not isGuildLeader then
		-- Check if our alt is the guild leader
		for _, name, isLeader in Guild.MemberIterator() do
			if name and isLeader and PlayerInfo.IsPlayer(gsub(name, "%-", " - "), true) then
				isGuildLeader = true
			end
		end
	end
	if guild and isGuildLeader then
		if not private.guildLog[guild] then
			private.guildLog[guild] = GoldLog.New()
		end
		private.UpdateGuildGoldLog(guild, Guild.GetMoney())
	end
end

function private.WarbankLogGold()
	if not private.warbankLog or not Container.CanAccessWarbank() then
		return
	end
	local copper = C_Bank.FetchDepositedMoney(Enum.BankType.Account)
	local currentMinute = floor(time() / SECONDS_PER_MIN)
	private.warbankLog:Append(currentMinute, private.RoundCopperValue(copper))
	private.warbankLogLastUpdate = time()
	private.settings.warbankMoney = copper
end

function private.PlayerLogGold()
	-- GetMoney sometimes returns 0 for a while after login, so keep trying for 30 seconds before recording a 0
	local money = GetMoney()
	if money == 0 and private.playerLogCount < 30 then
		private.playerLogCount = private.playerLogCount + 1
		private.playerGoldRetryTimer:RunForTime(1)
		return
	end
	private.playerLogCount = 0
	private.UpdateCurrentCharacterGoldLog(money)
	private.settings.money = money
end

function private.UpdateGuildGoldLog(guild, copper)
	local currentMinute = floor(time() / SECONDS_PER_MIN)
	private.guildLog[guild]:Append(currentMinute, private.RoundCopperValue(copper))
	private.guildLastUpdate[guild] = time()
end

function private.UpdateCurrentCharacterGoldLog(copper)
	local currentMinute = floor(time() / SECONDS_PER_MIN)
	private.characterLog[private.currentCharacterKey]:Append(currentMinute, private.RoundCopperValue(copper))
	private.characterLastUpdate[private.currentCharacterKey] = time()
end

function private.RoundCopperValue(copper)
	return Math.Round(copper, COPPER_PER_GOLD * ((ClientInfo.IsRetail() and 1000) or ((ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and 1) or 100))
end
