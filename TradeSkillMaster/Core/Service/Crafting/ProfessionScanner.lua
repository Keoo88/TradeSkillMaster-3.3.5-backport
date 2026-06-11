-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local ProfessionScanner = TSM.Crafting:NewPackage("ProfessionScanner") ---@type AddonPackage
local Log = TSM.LibTSMUtil:Include("Util.Log")
local MatString = TSM.LibTSMTypes:Include("Crafting.MatString")
local TradeSkill = TSM.LibTSMWoW:Include("API.TradeSkill")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local Profession = TSM.LibTSMService:Include("Profession")
local private = {
	settings = nil,
	matQuantitiesTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function ProfessionScanner.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("sync", "internalData", "playerProfessions")
		:AddKey("factionrealm", "internalData", "mats")
	Profession.SetScanHookFuncs(private.ScanHook, private.HandleInactiveRecipes)
end



-- ============================================================================
-- Profession Scanning
-- ============================================================================

function private.ScanHook(professionName, craftStrings)
	if not private.settings.playerProfessions[professionName] then
		-- we are in combat or the player's professions haven't been scanned yet by PlayerProfessions.lua, so will try again in a bit
		-- Auto-print debug (once per profession per session) since this silently blocks the
		-- profession from ever being imported if the name never appears in playerProfessions
		private.dbgPrinted = private.dbgPrinted or {}
		if not private.dbgPrinted[professionName] then
			private.dbgPrinted[professionName] = true
			local keys = {}
			for name in pairs(private.settings.playerProfessions) do
				tinsert(keys, tostring(name))
			end
			print(format("|cff33ff99TSMDBG|r import blocked: '%s' not found in player professions [%s] - will keep retrying", tostring(professionName), table.concat(keys, ", ")))
		end
		return false, true
	end

	-- update the link for this profession
	private.settings.playerProfessions[professionName].link = TradeSkill.GetLink()

	-- scan all the recipes
	TSM.Crafting.SetSpellDBQueryUpdatesPaused(true)
	local numFailed = 0
	for _, craftString in ipairs(craftStrings) do
		if not private.ScanRecipe(professionName, craftString) then
			numFailed = numFailed + 1
		end
	end
	TSM.Crafting.SetSpellDBQueryUpdatesPaused(false)

	Log.Info("Scanned %s (failed to scan %d)", professionName, numFailed)
	-- Auto-print debug (once per profession per session) confirming the import went through
	private.dbgPrinted = private.dbgPrinted or {}
	if not private.dbgPrinted["imported:"..professionName] then
		private.dbgPrinted["imported:"..professionName] = true
		print(format("|cff33ff99TSMDBG|r imported '%s': %d recipes (%d failed)", tostring(professionName), #craftStrings, numFailed))
	end
	return numFailed == 0, false
end

function private.ScanRecipe(professionName, craftString)
	local itemString = Profession.GetItemStringByCraftString(craftString)
	local craftName = Profession.GetCraftNameByCraftString(craftString)
	assert(itemString and craftName ~= "")

	local lNum, hNum = Profession.GetCraftedQuantityRange(craftString)
	local numResult = floor(((lNum or 1) + (hNum or 1)) / 2)

	local numResultItems = Profession.GetNumResultItems(craftString)
	local hasCD = Profession.HasCooldown(craftString)
	local recipeDifficulty, baseRecipeQuality = Profession.GetRecipeQualityInfo(craftString)
	local categoryId = Profession.GetCategoryIdByCraftString(craftString)
	local rootCategoryId = ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) and TradeSkill.GetRootCategoryId(categoryId) or -1

	TSM.Crafting.CreateOrUpdate(craftString, itemString, professionName, rootCategoryId, craftName, numResult, SessionInfo.GetCharacterName(), hasCD, recipeDifficulty, baseRecipeQuality, numResultItems)

	assert(not next(private.matQuantitiesTemp))
	for _, matString, quantity in Profession.MatIterator(craftString) do
		local matType = MatString.GetType(matString)
		if matType == MatString.TYPE.NORMAL then
			private.settings.mats[matString] = private.settings.mats[matString] or {}
		else
			for matItemString in MatString.ItemIterator(matString) do
				private.settings.mats[matItemString] = private.settings.mats[matItemString] or {}
			end
		end
		private.matQuantitiesTemp[matString] = quantity
	end
	if next(private.matQuantitiesTemp) then
		TSM.Crafting.SetMats(craftString, private.matQuantitiesTemp)
	end
	wipe(private.matQuantitiesTemp)
	return true
end

function private.HandleInactiveRecipes(craftStrings)
	TSM.Crafting.RemovePlayerSpells(SessionInfo.GetCharacterName(), craftStrings)
end
