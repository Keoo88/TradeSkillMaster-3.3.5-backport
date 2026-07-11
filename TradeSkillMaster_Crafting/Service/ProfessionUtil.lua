-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local ProfessionUtil = TSM.Crafting:NewPackage("ProfessionUtil")
local Spell = TSM.LibTSMWoW:Include("API.Spell")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local RecipeString = TSM.LibTSMTypes:Include("Crafting.RecipeString")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local TradeSkill = TSM.LibTSMWoW:Include("API.TradeSkill")
local Profession = TSM.LibTSMService:Include("Profession")
local private = {
	recipeString = nil,
	craftQuantity = nil,
	craftSpellId = nil,
	craftBaseString = nil,
	craftCallback = nil,
	craftName = nil,
	castingTimeout = nil,
	craftTimeout = nil,
	preparedSpellId = nil,
	preparedTime = 0,
	timeoutTimer = nil,
	optionalMatTable = {},
	unusedOptionalMatTempTables = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function ProfessionUtil.OnInitialize()
	private.timeoutTimer = DelayTimer.New("PROFESSION_UTIL_TIMEOUT", private.CraftTimeoutMonitor)
	Event.Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, spellNameOrGUID, rankOrNil, spellIdOrNil)
		-- 3.3.5: (unit, spellName, spellRank, lineID); retail: (unit, castGUID, spellID)
		local spellId = ClientInfo.IsRetail() and rankOrNil or spellNameOrGUID
		if unit ~= "player" or not private.SpellMatchesCraft(spellId) then
			return
		end

		if ClientInfo.IsRetail() then
			-- check if we need to update bank quantity manually
			for _, itemString, quantity in TSM.Crafting.MatIteratorByRecipeString(private.recipeString) do
				local bagQuantity, bankQuantity = BagTracking.GetQuantities(itemString)
				local warbankQuantity = WarbankTracking.GetQuantity(itemString)
				local bankUsed = quantity - bagQuantity
				if bankUsed > 0 and bankUsed <= (bankQuantity + warbankQuantity) then
					local warbankUsed = min(bankUsed, warbankQuantity)
					bankUsed = bankUsed - warbankUsed
					Log.Info("Used %d from bank, %d from the warbank", bankUsed, warbankUsed)
					if bankUsed > 0 then
						BagTracking.ForceBankQuantityDeduction(itemString, bankUsed)
					end
					if warbankUsed > 0 then
						WarbankTracking.ForceQuantityDeduction(itemString, warbankUsed)
					end
				end
			end
		end

		local callback = private.craftCallback
		if not callback then return end
		private.craftQuantity = private.craftQuantity - 1
		private.DoCraftCallback(true, private.craftQuantity == 0)
		-- Ignore profession updates from crafting something
		Profession.IgnoreNextProfessionUpdates()
		-- Restart the timeout
	end)
	local function SpellCastFailedEventHandler(_, unit, spellNameOrGUID, rankOrNil, spellIdOrNil)
		-- 3.3.5: (unit, spellName, spellRank, lineID); retail: (unit, castGUID, spellID)
		local spellId = ClientInfo.IsRetail() and rankOrNil or spellNameOrGUID
		if unit ~= "player" or not private.SpellMatchesCraft(spellId) then
			return
		end
		private.DoCraftCallback(false, true)
	end
	local function ClearCraftCast()
		-- 3.3.5 fix: если окно профессии закрыли во время активного крафта,
		-- завершаем его через callback (failure) — иначе UI, ждущий колбэк,
		-- зависал в состоянии "CRAFTING", т.к. поля чистились без уведомления
		if private.craftSpellId and private.craftCallback then
			private.DoCraftCallback(false, true)
			return
		end
		private.recipeString = nil
		private.craftQuantity = nil
		private.craftSpellId = nil
		private.craftBaseString = nil
		private.craftName = nil
		private.castingTimeout = nil
		private.craftTimeout = nil
	end
	Event.Register("UNIT_SPELLCAST_INTERRUPTED", SpellCastFailedEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED", SpellCastFailedEventHandler)
	-- 3.3.5 fix (зеркально Destroying/Core.lua): UNIT_SPELLCAST_FAILED_QUIET
	-- добавлен в MoP — регистрация неизвестного события на 3.3.5a даёт Lua error
	-- на логине и обрывает инициализацию Crafting; UNIT_SPELLCAST_FAILED и так
	-- покрывает отказы
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
		Event.Register("UNIT_SPELLCAST_FAILED_QUIET", SpellCastFailedEventHandler)
	end
	Event.Register("TRADE_SKILL_CLOSE", ClearCraftCast)
	if not ClientInfo.IsRetail() then
		Event.Register("CRAFT_CLOSE", ClearCraftCast)
	end
end

function ProfessionUtil.GetNumCraftable(craftString)
	local num, numAll = math.huge, math.huge
	for i = 1, Profession.GetNumMats(craftString) do
		local itemString, quantity = Profession.GetMatInfo(craftString, i)
		local totalQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
		if not itemString or not quantity or totalQuantity == 0 then
			return 0, 0
		end
		num = min(num, floor(private.GetMatQuantity(itemString) / quantity))
		numAll = min(numAll, floor(totalQuantity / quantity))
	end
	if num == math.huge or numAll == math.huge then
		return 0, 0
	end
	return num, numAll
end

function ProfessionUtil.GetNumCraftableRecipeString(recipeString)
	local num, numAll = math.huge, math.huge
	local craftString = CraftString.FromRecipeString(recipeString)
	for i = 1, Profession.GetNumMats(craftString) do
		local itemString, quantity, _, isQuality = Profession.GetMatInfo(craftString, i)
		if not isQuality then
			local totalQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
			if not itemString or not quantity or totalQuantity == 0 then
				return 0, 0
			end
			local bagQuantity = private.GetMatQuantity(itemString)
			num = min(num, floor(bagQuantity / quantity))
			numAll = min(numAll, floor(totalQuantity / quantity))
		end
	end
	for _, _, itemId in RecipeString.OptionalMatIterator(recipeString) do
		local itemString = ItemString.Get(itemId)
		local totalQuantity = CustomString.GetSourceValue("NumInventory", itemString) or 0
		if totalQuantity == 0 then
			return 0, 0
		end
		local quantity = TSM.Crafting.GetOptionalMatQuantity(craftString, itemId)
		local bagQuantity = private.GetMatQuantity(itemString)
		num = min(num, floor(bagQuantity / quantity))
		numAll = min(numAll, floor(totalQuantity / quantity))
	end
	if num == math.huge or numAll == math.huge then
		return 0, 0
	end
	return num, numAll
end

function ProfessionUtil.HasVellum(recipeString)
	local craftString = CraftString.FromRecipeString(recipeString)
	if Profession.IsEnchant(craftString) and not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() then
		return BagTracking.GetBagQuantity(Profession.GetVellumItemString(craftString)) > 0
	else
		return false
	end
end

function ProfessionUtil.IsCraftable(craftString)
	for i = 1, Profession.GetNumMats(craftString) do
		local itemString, quantity = Profession.GetMatInfo(craftString, i)
		if not itemString or not quantity then
			return false
		end
		if floor(private.GetMatQuantity(itemString) / quantity) == 0 then
			return false
		end
	end
	return true
end

function ProfessionUtil.GetNumCraftableFromDB(craftString, optionalMats)
	local num = math.huge
	for _, itemString, quantity in TSM.Crafting.MatIterator(craftString) do
		num = min(num, floor(private.GetMatQuantity(itemString) / quantity))
	end
	if optionalMats then
		for _, itemId in pairs(optionalMats) do
			num = min(num, private.GetMatQuantity(ItemString.Get(itemId)))
		end
	end
	if num == math.huge then
		return 0
	end
	return num
end

function ProfessionUtil.GetNumCraftableFromDBRecipeString(recipeString)
	local num = math.huge
	for _, itemString, quantity in TSM.Crafting.MatIteratorByRecipeString(recipeString) do
		num = min(num, floor(private.GetMatQuantity(itemString) / quantity))
	end
	if num == math.huge then
		return 0
	end
	return num
end

function ProfessionUtil.PrepareToCraft(recipeString, quantity, level, salvageSlotId)
	if not salvageSlotId then
		quantity = min(quantity, ProfessionUtil.GetNumCraftableRecipeString(recipeString))
	end
	if quantity == 0 then
		return
	end
	private.preparedSpellId = RecipeString.GetSpellId(recipeString)
	private.preparedTime = GetTime()
end

function ProfessionUtil.Craft(recipeString, quantity, useVellum, salvageSlotId, callback)
	local spellId = nil
	local level = nil
	local craftString = CraftString.FromRecipeString(recipeString)
	if salvageSlotId then
		spellId = RecipeString.GetSpellId(recipeString)
	elseif type(recipeString) == "string" then
		spellId = RecipeString.GetSpellId(recipeString)
		level = RecipeString.GetLevel(recipeString)
		quantity = min(quantity, ProfessionUtil.GetNumCraftableRecipeString(recipeString))
	else
		spellId = recipeString
		quantity = min(quantity, ProfessionUtil.GetNumCraftable(craftString))
	end
	assert(Profession.HasCraftString(craftString))
	if private.craftSpellId then
		private.craftCallback = callback
		private.DoCraftCallback(false, true)
		return 0
	end
	if quantity == 0 then
		return 0
	end
	local isEnchant = Profession.IsEnchant(craftString)
	local vellumable = isEnchant and not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic()
	if not ClientInfo.IsRetail() and (isEnchant or TradeSkill.IsClassicCrafting()) then
		quantity = 1
	elseif spellId ~= private.preparedSpellId or private.preparedTime == GetTime() then
		-- We can only craft one of this item due to a bug on Blizzard's end
		quantity = 1
	end
	local enchantItemSlotId = nil
	if ClientInfo.IsRetail() and useVellum and isEnchant and vellumable then
		enchantItemSlotId = BagTracking.CreateQueryBagsItem(Profession.GetVellumItemString(craftString))
			:Select("slotId")
			:GetFirstResultAndRelease()
		if not enchantItemSlotId then
			return 0
		end
	end
	private.recipeString = recipeString
	private.craftQuantity = quantity
	private.craftSpellId = spellId
	private.craftBaseString = ItemString.GetBase(TSM.Crafting.GetItemString(craftString)) or ""
	private.craftCallback = callback
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) then
		assert(not next(private.optionalMatTable))
		local applyConcentration = false
		if type(recipeString) == "string" then
			applyConcentration = RecipeString.GetConcentration(recipeString) and true or false
			for _, slotId, itemId in RecipeString.OptionalMatIterator(recipeString) do
				local info = tremove(private.unusedOptionalMatTempTables) or {}
				info.reagent = info.reagent or {}
				info.reagent.itemID = itemId
				info.dataSlotIndex = slotId
				info.quantity = TSM.Crafting.GetOptionalMatQuantity(craftString, itemId)
				tinsert(private.optionalMatTable, info)
			end
		end
		TradeSkill.Craft(spellId, quantity, private.optionalMatTable, level, enchantItemSlotId, salvageSlotId, applyConcentration)
		for _, tbl in ipairs(private.optionalMatTable) do
			tinsert(private.unusedOptionalMatTempTables, tbl)
		end
		wipe(private.optionalMatTable)
	else
		local index = Profession.GetIndexByCraftString(craftString)
		private.craftName = TradeSkill.Craft(index, quantity)
		if useVellum and isEnchant and vellumable then
			UseItemByName(ItemInfo.GetName(Profession.GetVellumItemString(craftString)))
		end
	end
	private.castingTimeout = nil
	private.craftTimeout = nil
	private.timeoutTimer:RunForTime(0.5)
	return quantity
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DoCraftCallback(result, isDone)
	local callback = private.craftCallback
	assert(callback)
	-- reset timeouts
	private.castingTimeout = nil
	private.craftTimeout = nil
	if isDone then
		private.recipeString = nil
		private.craftQuantity = nil
		private.craftSpellId = nil
		private.craftBaseString = nil
		private.craftCallback = nil
		private.craftName = nil
		private.timeoutTimer:Cancel()
	end
	callback(result, isDone)
end

function private.CraftTimeoutMonitor()
	private.timeoutTimer:RunForTime(0.5)
	if not private.craftSpellId then
		Log.Info("No longer crafting")
		private.castingTimeout = nil
		private.craftTimeout = nil
		private.timeoutTimer:Cancel()
		return
	end
	local _, _, _, _, castEndTimeMs, _, _, _, spellId = private.GetPlayerCastingInfo()
	if spellId then
		private.castingTimeout = nil
	else
		private.craftTimeout = nil
	end
	if not spellId then
		-- no active cast
		if GetTime() > (private.castingTimeout or math.huge) then
			Log.Err("Craft timed out (%s)", private.craftSpellId)
			private.DoCraftCallback(false, true)
			return
		end
		-- set the casting timeout to 1 second from now
		private.castingTimeout = GetTime() + 1
		return
	elseif private.craftSpellId ~= spellId then
		-- 3.3.5 fix: завершаем крафт через callback (failure) вместо тихого
		-- выхода — раньше craft-состояние оставалось взведённым и UI навсегда
		-- зависал в "CRAFTING". На 3.3.5 чужой каст во время очереди крафта
		-- легко спровоцировать (авто-еда, бинты, макросы).
		Log.Err("Crafting something else (%s, %s)", private.craftSpellId, spellId)
		private.DoCraftCallback(false, true)
		return
	end

	if GetTime() > (private.craftTimeout or math.huge) then
		Log.Err("Craft timed out (%s)", private.craftSpellId)
		private.DoCraftCallback(false, true)
		return
	end
	-- set the timeout to 1 second after the end time
	private.craftTimeout = castEndTimeMs / 1000 + 1
end

function private.GetPlayerCastingInfo()
	if ClientInfo.IsRetail() then
		return UnitCastingInfo("player")
	elseif CastingInfo then
		return CastingInfo()
	else
		-- 3.3.5: CastingInfo() doesn't exist and UnitCastingInfo() uses the old
		-- signature (rank as the 2nd return, no spellId at the end), so emulate
		-- the modern return values which CraftTimeoutMonitor expects
		local name, _, text, texture, startTimeMs, endTimeMs, isTradeSkill, castId, notInterruptible = UnitCastingInfo("player")
		if not name then
			return nil
		end
		local spellId = nil
		if private.craftSpellId and GetSpellInfo(private.craftSpellId) == name then
			spellId = private.craftSpellId
		else
			-- some other spell is being cast; return a sentinel so the caller
			-- can tell it apart from "not casting at all"
			spellId = -1
		end
		return name, text, texture, startTimeMs, endTimeMs, isTradeSkill, castId, notInterruptible, spellId
	end
end

function private.SpellMatchesCraft(spellId)
	if ClientInfo.IsRetail() then
		if not Profession.ScannerHasSkills() then
			return false
		end
		local resultItem = Profession.GetResultItem(CraftString.Get(spellId))
		if not resultItem then
			return false
		elseif type(resultItem) == "table" then
			for i = 1, #resultItem do
				local baseItemString = ItemString.GetBase(resultItem[i]) or ""
				if spellId == private.craftSpellId and baseItemString == private.craftBaseString then
					return true
				end
			end
			return false
		else
			local baseItemString = ItemString.GetBase(resultItem) or ""
			return spellId == private.craftSpellId and baseItemString == private.craftBaseString
		end
	else
		if not private.craftName then return false end
		-- 3.3.5 UNIT_SPELLCAST_SUCCEEDED arg 2 is spellName (string), not spellId.
		-- Compare directly to craftName; fall back to spellId→name lookup if numeric.
		if type(spellId) == "string" then
			return spellId == private.craftName
		end
		return Spell.GetInfo(spellId) == private.craftName
	end
end

function private.GetMatQuantity(itemString)
	return BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
end
