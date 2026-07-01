-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local PlayerProfessions = TSM.Crafting:NewPackage("PlayerProfessions") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Database = TSM.LibTSMUtil:Include("Database")
local Spell = TSM.LibTSMWoW:Include("API.Spell")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local MatString = TSM.LibTSMTypes:Include("Crafting.MatString")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local Threading = TSM.LibTSMTypes:Include("Threading")
local TradeSkill = TSM.LibTSMWoW:Include("API.TradeSkill")
local private = {
	settingsDB = nil,
	settings = nil,
	playerProfessionsThread = nil,
	playerProfessionsThreadRunning = false,
	db = nil,
	query = nil,
	retryTimer = nil,
}
local TAILORING_ES = "Sastrería"
local TAILORING_SKILL_ES = "Costura"
local LEATHERWORKING_ES = "Peletería"
local LEATHERWORKING_SKILL_ES = "Marroquinería"
local ENGINEERING_FR = "Ingénieur"
local ENGINEERING_SKILL_FR = "Ingénierie"
local FIRST_AID_FR = "Premiers soins"
local FIRST_AID_SKILL_FR = "Secourisme"
-- 3.3.5a: на некоторых клиентах (в частности ruRU на Warmane) названия рангов
-- профессий (Ученик/Подмастерье/Знаток/...) не совпадают с клиентскими
-- константами APPRENTICE/JOURNEYMAN/..., из-за чего профессии переставали
-- определяться вовсе. Дополнительно опознаём профессию по её локализованному
-- имени, полученному из ID заклинаний (это не зависит от локали и рангов).
local PROFESSION_SPELL_IDS = {
	2259,  -- Alchemy
	2018,  -- Blacksmithing
	7411,  -- Enchanting
	4036,  -- Engineering
	45357, -- Inscription
	25229, -- Jewelcrafting
	2108,  -- Leatherworking
	3908,  -- Tailoring
	2575,  -- Mining
	2656,  -- Smelting
	2550,  -- Cooking
	3273,  -- First Aid
}
local PROFESSION_NAMES = {}
for _, professionSpellId in ipairs(PROFESSION_SPELL_IDS) do
	local professionName = Spell.GetInfo(professionSpellId)
	if professionName then
		PROFESSION_NAMES[professionName] = true
	end
end



-- ============================================================================
-- Module Functions
-- ============================================================================

function PlayerProfessions.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("sync", "internalData", "playerProfessions")
		:AddKey("factionrealm", "internalData", "isCraftFavorite")
		:AddKey("factionrealm", "internalData", "mats")
	private.db = Database.NewSchema("PLAYER_PROFESSIONS")
		:AddStringField("player")
		:AddStringField("profession")
		:AddNumberField("skillId")
		:AddNumberField("level")
		:AddNumberField("maxLevel")
		:AddBooleanField("isSecondary")
		:AddIndex("player")
		:Commit()
	private.query = private.db:NewQuery()
		:Select("player", "profession", "skillId", "level", "maxLevel")
		:OrderBy("isSecondary", true)
		:OrderBy("level", false)
		:OrderBy("profession", true)
	private.playerProfessionsThread = Threading.New("PLAYER_PROFESSIONS", private.PlayerProfessionsThread)
	private.StartPlayerProfessionsThread()
	private.retryTimer = DelayTimer.New("PLAYER_PROFESSIONS_RETRY", private.PlayerProfessionsSkillUpdate)
	Event.Register("SKILL_LINES_CHANGED", private.PlayerProfessionsSkillUpdate)
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsPandaClassic() then
		Event.Register("LEARNED_SPELL_IN_TAB", private.StartPlayerProfessionsThread)
	elseif ClientInfo.IsRetail() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		Event.Register("LEARNED_SPELL_IN_SKILL_LINE", private.StartPlayerProfessionsThread)
	end
end

function PlayerProfessions.GetProfessionSkill(player, profession)
	-- 3.3.5a: Spell.GetInfo() для некоторых ID профессий (напр. 28897 Ювелирное дело)
	-- может вернуть nil, тогда сюда прилетает profession=nil и Query:Equal падает на assert.
	-- Защищаемся от nil player/profession и просто возвращаем nil (downstream это обрабатывает).
	if not player or not profession then
		return nil
	end
	return private.db:NewQuery()
		:Select("level")
		:Equal("player", player)
		:Equal("profession", profession)
		:GetFirstResultAndRelease()
end

function PlayerProfessions.CreateQuery()
	return private.db:NewQuery()
end

function PlayerProfessions.Iterator()
	return private.query:Iterator()
end



-- ============================================================================
-- Player Professions Thread
-- ============================================================================

function private.StartPlayerProfessionsThread()
	if private.playerProfessionsThreadRunning then
		Threading.Kill(private.playerProfessionsThread)
	end
	private.playerProfessionsThreadRunning = true
	Threading.Start(private.playerProfessionsThread)
end

function private.UpdatePlayerProfessionInfo(name, skillId, level, maxLevel, isSecondary)
	local professionInfo = private.settings.playerProfessions[name] or {}
	private.settings.playerProfessions[name] = professionInfo
	-- preserve whether or not we've prompted to create groups and the profession link if possible
	local oldPrompted = professionInfo.prompted or nil
	local oldLink = professionInfo.link or nil
	wipe(professionInfo)
	professionInfo.skillId = skillId
	professionInfo.level = level
	professionInfo.maxLevel = maxLevel
	professionInfo.isSecondary = isSecondary
	professionInfo.prompted = oldPrompted
	professionInfo.link = oldLink
end

function private.PlayerProfessionsSkillUpdate()
	if ClientInfo.IsRetail() or ClientInfo.IsPandaClassic() then
		local professionIds = TempTable.Acquire(GetProfessions())
		-- ignore archaeology and fishing which are in the 3rd and 4th slots respectively
		professionIds[3] = nil
		professionIds[4] = nil
		for i, id in pairs(professionIds) do -- needs to be pairs since there might be holes
			local name, _, level, maxLevel, _, _, skillId = GetProfessionInfo(id)
			if not TSM.UI.CraftingUI.IsProfessionIgnored(name) then -- exclude ignored professions
				private.UpdatePlayerProfessionInfo(name, skillId, level, maxLevel, i > 2)
			end
		end
		TempTable.Release(professionIds)
	else
		local _, _, offset, numSpells = GetSpellTabInfo(1)
		for i = offset + 1, offset + numSpells do
			local name, subName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
			if not subName then
				private.retryTimer:RunForTime(0.05)
				return
			end
			local level, maxLevel = nil, nil
			name, level, maxLevel = private.GetProfessionInfo(name, subName)
			if name and level and maxLevel then
				private.UpdatePlayerProfessionInfo(name, -1, level, maxLevel, name == Spell.GetInfo(129))
			end
		end
	end

	-- update our DB
	private.db:TruncateAndBulkInsertStart()
	for _, character in private.settingsDB:AccessibleCharacterIterator() do
		local playerProfessions = private.settings:GetForScopeKey("playerProfessions", character, SessionInfo.GetFactionrealmName())
		if playerProfessions then
			for name, info in pairs(playerProfessions) do
				private.db:BulkInsertNewRow(character, name, info.skillId or -1, info.level, info.maxLevel, info.isSecondary)
			end
		end
	end
	private.db:BulkInsertEnd()
end

function private.PlayerProfessionsThread()
	-- get the player's tradeskills
	if ClientInfo.IsRetail() then
		ProfessionsBookFrame_Update()
	elseif ClientInfo.IsPandaClassic() then
		SpellBook_UpdateProfTab()
	elseif ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		if SpellBookFrame.UpdateSkillLineTabs then
			SpellBookFrame:UpdateSkillLineTabs()
		end
	end
	local forgetProfession = Threading.AcquireSafeTempTable()
	for name in pairs(private.settings.playerProfessions) do
		forgetProfession[name] = true
	end
	if ClientInfo.IsRetail() or ClientInfo.IsPandaClassic() then
		Threading.WaitForFunction(GetProfessions)
		local professionIds = Threading.AcquireSafeTempTable(GetProfessions())
		-- ignore archaeology and fishing which are in the 3rd and 4th slots respectively
		professionIds[3] = nil
		professionIds[4] = nil
		for i, id in pairs(professionIds) do -- needs to be pairs since there might be holes
			local name, _, level, maxLevel, _, _, skillId = Threading.WaitForFunction(GetProfessionInfo, id)
			if not TSM.UI.CraftingUI.IsProfessionIgnored(name) then -- exclude ignored professions
				forgetProfession[name] = nil
				private.UpdatePlayerProfessionInfo(name, skillId, level, maxLevel, i > 2)
			end
		end
		TempTable.Release(professionIds)
	else
		local _, _, offset, numSpells = GetSpellTabInfo(1)
		for i = offset + 1, offset + numSpells do
			local name, level, maxLevel = private.GetProfessionInfo(GetSpellBookItemName(i, BOOKTYPE_SPELL))
			if name and level and maxLevel then
				forgetProfession[name] = nil
				private.UpdatePlayerProfessionInfo(name, -1, level, maxLevel, name == Spell.GetInfo(129))
			end
		end
	end
	for name in pairs(forgetProfession) do
		private.settings.playerProfessions[name] = nil
	end
	TempTable.Release(forgetProfession)

	-- clean up crafts which are no longer known
	local matUsed = Threading.AcquireSafeTempTable()
	local craftStrings = Threading.AcquireSafeTempTable()
	local spellIds = Threading.AcquireSafeTempTable()
	for _, craftString in TSM.Crafting.CraftStringIterator() do
		tinsert(craftStrings, craftString)
		local spellId = CraftString.GetSpellId(craftString)
		spellIds[spellId] = true
	end
	for _, craftString in ipairs(craftStrings) do
		local playersToRemove = TempTable.Acquire()
		for _, player in TSM.Crafting.PlayerIterator(craftString) do
			-- check if the player still exists and still has this profession
			local playerProfessions = private.settings:GetForScopeKey("playerProfessions", player, SessionInfo.GetFactionrealmName())
			if not playerProfessions or not playerProfessions[TSM.Crafting.GetProfession(craftString)] then
				playersToRemove[player] = true
			end
		end
		local stillExists = true
		if next(playersToRemove) then
			stillExists = TSM.Crafting.RemoveCraftPlayers(craftString, playersToRemove)
		end
		TempTable.Release(playersToRemove)
		if stillExists then
			for _, itemString in TSM.Crafting.MatIterator(craftString) do
				matUsed[itemString] = true
			end
			for _, matString in TSM.Crafting.OptionalMatIterator(craftString) do
				for itemString in MatString.ItemIterator(matString) do
					matUsed[itemString] = true
				end
			end
		end
		Threading.Yield()
	end
	TempTable.Release(craftStrings)

	-- clean up favorite crafts
	for spellId, isFavorite in pairs(private.settings.isCraftFavorite) do
		if not isFavorite or not spellIds[spellId] then
			private.settings.isCraftFavorite[spellId] = nil
		end
	end
	TempTable.Release(spellIds)

	-- clean up mats which aren't used anymore
	local toRemove = TempTable.Acquire()
	for itemString, matInfo in pairs(private.settings.mats) do
		-- clear out old names
		matInfo.name = nil
		if not matUsed[itemString] then
			tinsert(toRemove, itemString)
		end
	end
	TempTable.Release(matUsed)
	for _, itemString in ipairs(toRemove) do
		private.settings.mats[itemString] = nil
	end
	TempTable.Release(toRemove)

	-- update our DB
	private.db:TruncateAndBulkInsertStart()
	for _, character in private.settingsDB:AccessibleCharacterIterator() do
		local playerProfessions = private.settings:GetForScopeKey("playerProfessions", character, SessionInfo.GetFactionrealmName())
		if playerProfessions then
			for name, info in pairs(playerProfessions) do
				private.db:BulkInsertNewRow(character, name, info.skillId or -1, info.level, info.maxLevel, info.isSecondary)
			end
		end
	end
	private.db:BulkInsertEnd()

	private.playerProfessionsThreadRunning = false
end

function private.GetProfessionInfo(name, subName)
	if not name or not subName or not private.IsValidName(name, subName) then
		return nil, nil, nil
	elseif TSM.UI.CraftingUI.IsProfessionIgnored(name) then
		-- Ignored profession
		return nil, nil, nil
	end
	local level, maxLevel = nil, nil
	for i = 1, GetNumSkillLines() do
		local skillName, _, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)
		if skillName == name then
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif name == TradeSkill.NAMES.SMELTING and skillName == TradeSkill.NAMES.MINING then
			name = TradeSkill.NAMES.MINING
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif name == LEATHERWORKING_ES and skillName == LEATHERWORKING_SKILL_ES then
			name = LEATHERWORKING_SKILL_ES
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif name == TAILORING_ES and skillName == TAILORING_SKILL_ES then
			name = TAILORING_SKILL_ES
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif name == ENGINEERING_FR and skillName == ENGINEERING_SKILL_FR then
			name = ENGINEERING_SKILL_FR
			level = skillRank
			maxLevel = skillMaxRank
			break
		elseif name == FIRST_AID_FR and skillName == FIRST_AID_SKILL_FR then
			name = FIRST_AID_SKILL_FR
			level = skillRank
			maxLevel = skillMaxRank
			break
		end
	end
	return name, level, maxLevel
end

function private.IsValidName(name, subName)
	if name and PROFESSION_NAMES[name] then
		-- locale-independent: имя совпало с известной профессией (см. PROFESSION_NAMES)
		return true
	elseif TradeSkill.IsClassicSubName(strtrim(subName, " ")) then
		return true
	elseif name == TradeSkill.NAMES.SMELTING then
		return true
	elseif name == TradeSkill.NAMES.POISONS then
		return true
	elseif name == LEATHERWORKING_ES then
		return true
	elseif name == TAILORING_ES then
		return true
	elseif name == ENGINEERING_FR then
		return true
	elseif name == FIRST_AID_FR then
		return true
	else
		return false
	end
end
