-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Crafting = TSM:NewPackage("Crafting") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local SalvageData = TSM.LibTSMData:Include("Salvage")
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local MatString = TSM.LibTSMTypes:Include("Crafting.MatString")
local RecipeString = TSM.LibTSMTypes:Include("Crafting.RecipeString")
local Database = TSM.LibTSMUtil:Include("Database")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local Math = TSM.LibTSMUtil:Include("Lua.Math")
local SmartMap = TSM.LibTSMUtil:IncludeClassType("SmartMap")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Vararg = TSM.LibTSMUtil:Include("Lua.Vararg")
local Group = TSM.LibTSMTypes:Include("Group")
local Conversion = TSM.LibTSMTypes:Include("Item.Conversion")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomPrice = TSM.LibTSMApp:Include("Service.CustomPrice")
local Conversions = TSM.LibTSMApp:Include("Service.Conversions")
local Auction = TSM.LibTSMService:Include("Auction")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local CraftingOperation = TSM.LibTSMSystem:Include("CraftingOperation")
local private = {
	settings = nil,
	spellDB = nil,
	matDB = nil,
	matItemDB = nil,
	matDBSpellIdQuery = nil,
	matDBAllMatsQuery = nil,
	matDBMatNamesQuery = nil,
	ignoredCooldownDB = nil,
	numMatDBRows = {},
	playerTemp = {},
	numCraftableItemStringSmartMap = nil,
}
local CHARACTER_KEY = UnitName("player").." - "..GetRealmName()
local IGNORED_COOLDOWN_SEP = "\001"
local PROFESSION_SEP = ","
local BAD_CRAFTING_PRICE_SOURCES = {
	crafting = true,
}
local INDIRECT_RESULT_MATERIALS = {
	["i:194545"] = true -- Prismatic Ore
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Crafting.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("factionrealm", "internalData", "crafts")
		:AddKey("factionrealm", "internalData", "mats")
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
		:AddKey("factionrealm", "userData", "craftingCooldownIgnore")
	local used = TempTable.Acquire()
	for craftString, craftInfo in pairs(private.settings.crafts) do
		if next(craftInfo.players) then
			for matString in pairs(craftInfo.mats) do
				for itemString in MatString.ItemIterator(matString) do
					used[itemString] = true
				end
			end
		else
			private.settings.crafts[craftString] = nil
		end
	end
	for itemString in pairs(used) do
		private.settings.mats[itemString] = private.settings.mats[itemString] or {}
	end
	for itemString in pairs(private.settings.mats) do
		if not used[itemString] then
			private.settings.mats[itemString] = nil
		end
	end
	TempTable.Release(used)

	private.numCraftableItemStringSmartMap = SmartMap.New("string", "number", TSM.Crafting.ProfessionUtil.GetNumCraftableFromDBRecipeString)

	local professionItems = TempTable.Acquire()
	local matCountByCraft = TempTable.Acquire()
	local matFirstItemString = TempTable.Acquire()
	local matFirstQuantity = TempTable.Acquire()
	private.matDB = Database.NewSchema("CRAFTING_MATS")
		:AddStringField("craftString")
		:AddStringField("itemString")
		:AddNumberField("quantity")
		:AddIndex("craftString")
		:AddIndex("itemString")
		:Commit()
	private.spellDB = Database.NewSchema("CRAFTING_SPELLS")
		:AddUniqueStringField("craftString")
		:AddStringField("itemString")
		:AddStringField("name")
		:AddStringField("profession")
		:AddNumberField("numResult")
		:AddStringListField("players")
		:AddBooleanField("hasCD")
		:AddIndex("itemString")
		:AddIndex("profession")
		:Commit()
	private.matDB:BulkInsertStart()
	private.spellDB:BulkInsertStart()
	local playersTemp = TempTable.Acquire()
	for craftString, craftInfo in pairs(private.settings.crafts) do
		wipe(playersTemp)
		for player in pairs(craftInfo.players) do
			tinsert(playersTemp, player)
		end
		assert(#playersTemp > 0)
		sort(playersTemp)
		private.spellDB:BulkInsertNewRow(craftString, craftInfo.itemString, craftInfo.name or "", craftInfo.profession, craftInfo.numResult, playersTemp, craftInfo.hasCD and true or false)

		for matString, matQuantity in pairs(craftInfo.mats) do
			private.matDB:BulkInsertNewRow(craftString, matString, matQuantity)
			private.HandleMatDBAddRow(matString)
			professionItems[craftInfo.profession] = professionItems[craftInfo.profession] or TempTable.Acquire()
			matCountByCraft[craftString] = (matCountByCraft[craftString] or 0) + 1
			if matQuantity > 0 and MatString.GetType(matString) == MatString.TYPE.NORMAL then
				matFirstItemString[craftString] = matString
				matFirstQuantity[craftString] = matQuantity
			end
			for itemString in MatString.ItemIterator(matString) do
				professionItems[craftInfo.profession][itemString] = true
			end
		end
	end
	TempTable.Release(playersTemp)
	private.spellDB:BulkInsertEnd()
	private.matDB:BulkInsertEnd()

	private.matDBAllMatsQuery = private.matDB:NewQuery()
		:Select("itemString", "quantity")
		:Equal("craftString", Database.BoundQueryParam())
	private.matDBMatNamesQuery = private.matDB:NewQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:Select("name")
		:Equal("craftString", Database.BoundQueryParam())
		:GreaterThan("quantity", 0)

	private.matItemDB = Database.NewSchema("CRAFTING_MAT_ITEMS")
		:AddUniqueStringField("itemString")
		:AddStringField("professions")
		:AddStringField("customValue")
		:Commit()
	private.matItemDB:BulkInsertStart()
	local professionsTemp = TempTable.Acquire()
	for itemString, info in pairs(private.settings.mats) do
		wipe(professionsTemp)
		for profession, items in pairs(professionItems) do
			if items[itemString] then
				tinsert(professionsTemp, profession)
			end
		end
		sort(professionsTemp)
		local professionsStr = table.concat(professionsTemp, PROFESSION_SEP)
		private.matItemDB:BulkInsertNewRow(itemString, professionsStr, info.customValue or "")
	end
	TempTable.Release(professionsTemp)
	private.matItemDB:BulkInsertEnd()

	for _, tbl in pairs(professionItems) do
		TempTable.Release(tbl)
	end
	TempTable.Release(professionItems)

	private.matDBSpellIdQuery = private.matDB:NewQuery()
		:Equal("craftString", Database.BoundQueryParam())

	-- register 1:1 crafting conversions
	local addedConversion = false
	local query = private.spellDB:NewQuery()
		:Select("craftString", "itemString", "numResult")
		:Equal("hasCD", false)
	for _, craftString, itemString, numResult in query:Iterator() do
		local spellId = CraftString.GetSpellId(craftString)
		if not SalvageData.MassMill[spellId] and matCountByCraft[craftString] == 1 and matFirstItemString[craftString] then
			Conversion.AddCraft(itemString, matFirstItemString[craftString], numResult / matFirstQuantity[craftString])
			addedConversion = true
		end
	end
	query:Release()
	TempTable.Release(matCountByCraft)
	TempTable.Release(matFirstItemString)
	TempTable.Release(matFirstQuantity)
	if addedConversion then
		CustomString.InvalidateCache("Destroy")
	end

	local isValid, err = CustomPrice.Validate(private.settings.defaultCraftPriceMethod, BAD_CRAFTING_PRICE_SOURCES)
	if not isValid then
		ChatMessage.PrintfUser(L["Your default craft value method was invalid so it has been returned to the default. Details: %s"], err)
		private.settings.defaultCraftPriceMethod = private.settings:GetDefaultReadOnly("defaultCraftPriceMethod")
	end

	private.ignoredCooldownDB = Database.NewSchema("IGNORED_COOLDOWNS")
		:AddStringField("characterKey")
		:AddStringField("craftString")
		:Commit()
	private.ignoredCooldownDB:BulkInsertStart()
	for entry in pairs(private.settings.craftingCooldownIgnore) do
		local characterKey, craftString = strsplit(IGNORED_COOLDOWN_SEP, entry)
		if Crafting.HasCraftString(craftString) then
			private.ignoredCooldownDB:BulkInsertNewRow(characterKey, craftString)
		else
			private.settings.craftingCooldownIgnore[entry] = nil
		end
	end
	private.ignoredCooldownDB:BulkInsertEnd()
end

function Crafting.IsOperationValid(itemString)
	local isValid, operationName, errType, errArg, errArg2 = CraftingOperation.IsValid(itemString)
	if isValid or not errType then
		return isValid
	elseif errType == CraftingOperation.ERROR.RESTOCK_QUANTITIES_CONFLICT then
		return false, format(L["'%s' is an invalid operation. Min restock of %d is higher than max restock of %d for %s."], operationName, errArg, errArg2, ItemInfo.GetLink(itemString))
	elseif errType == CraftingOperation.ERROR.MIN_RESTOCK_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		return nil, format(L["Your min restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..errStr
	elseif errType == CraftingOperation.ERROR.MIN_RESTOCK_INVALID_RANGE then
		return nil, format(L["Your min restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..format(L["Must be between %d and %d."], CraftingOperation.GetRestockRange())
	elseif errType == CraftingOperation.ERROR.MAX_RESTOCK_INVALID then
		local _, errStr = CustomPrice.GetValue(errArg, itemString, true)
		return nil, format(L["Your max restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..errStr
	elseif errType == CraftingOperation.ERROR.MAX_RESTOCK_INVALID_RANGE then
		return nil, format(L["Your max restock (%s) is invalid for %s."], errArg, ItemInfo.GetLink(itemString)).." "..format(L["Must be between %d and %d."], CraftingOperation.GetRestockRange())
	else
		error("Invalid errType: "..tostring(errType))
	end
end

function Crafting.HasCraftString(craftString)
	return private.spellDB:HasUniqueRow("craftString", craftString)
end

function Crafting.CreateRawCraftsQuery()
	return private.spellDB:NewQuery()
end

function Crafting.CreateCraftsQuery()
	return private.spellDB:NewQuery()
		:AggregateJoinSummed(TSM.Crafting.Queue.GetDBForJoin(), "craftString", "num")
		:VirtualField("bagQuantity", "number", BagTracking.GetBagQuantity, "itemString")
		:VirtualField("auctionQuantity", "number", Auction.GetQuantity, "itemString")
		:VirtualField("craftingCost", "number", TSM.Crafting.Cost.GetCraftingCostByCraftString, "craftString", Math.GetNan())
		:VirtualField("itemValue", "number", TSM.Crafting.Cost.GetCraftedItemValue, "itemString", Math.GetNan())
		:VirtualField("profit", "number", TSM.Crafting.Cost.GetProfitByCraftString, "craftString", Math.GetNan())
		:VirtualField("profitPct", "number", private.ProfitPctVirtualField, "craftString")
		:VirtualField("saleRate", "number", private.SaleRateVirtualField, "itemString")
end

function Crafting.CreateQueueQuery()
	return TSM.Crafting.Queue.CreateQuery()
		:InnerJoin(private.spellDB, "craftString")
		:VirtualField("profit", "number", TSM.Crafting.Cost.GetProfitByRecipeString, "recipeString", Math.GetNan())
		:VirtualSmartMapField("numCraftable", private.numCraftableItemStringSmartMap, "recipeString")
		:VirtualField("levelItemString", "string", TSM.Crafting.Cost.GetLevelItemString, "recipeString", "")
end

function Crafting.CreateQueuedCraftsQuery()
	return TSM.Crafting.Queue.CreateQuery()
		:InnerJoin(private.spellDB, "craftString")
end

function Crafting.CreateCooldownSpellsQuery()
	return private.spellDB:NewQuery()
		:Equal("hasCD", true)
end

function Crafting.CreateRawMatItemQuery()
	return private.matItemDB:NewQuery()
end

function Crafting.CreateMatItemQuery()
	return private.matItemDB:NewQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:VirtualField("matCost", "number", private.GetMatCost, "itemString")
		:VirtualField("totalQuantity", "number", private.GetTotalQuantity, "itemString")
end

function Crafting.CraftStringIterator()
	return private.spellDB:NewQuery()
		:Select("craftString")
		:IteratorAndRelease()
end

function Crafting.GetCraftStringByItem(itemString)
	local query = private.spellDB:NewQuery()
		:Equal("itemString", itemString)
		:Select("craftString", "hasCD", "profession")
	return query:IteratorAndRelease()
end

function Crafting.InvalidateNumQueuedSmartMap()
	private.numCraftableItemStringSmartMap:Invalidate()
end

function Crafting.GetMostProfitableCraftStringByItem(itemString, playerFilter, noCD)
	local bestCraftString, bestCraftingCost, bestProfit, bestHasCD = nil, nil, nil, nil
	for _, craftString, hasCD in Crafting.GetCraftStringByItem(itemString) do
		if (not playerFilter or playerFilter == "" or Crafting.HasPlayer(craftString, playerFilter)) and (not noCD or not hasCD) then
			local craftingCost, _, profit = TSM.Crafting.Cost.GetCostsByCraftString(craftString)
			if not bestCraftString or private.IsCraftStringHigherProfit(craftingCost, profit, hasCD, bestCraftingCost, bestProfit, bestHasCD) then
				bestCraftString = craftString
				bestCraftingCost = craftingCost
				bestProfit = profit
				bestHasCD = hasCD
			end
		end
	end
	return bestCraftString, bestProfit, bestCraftingCost
end

function Crafting.GetItemString(craftString)
	return private.spellDB:GetUniqueRowField("craftString", craftString, "itemString")
end

function Crafting.GetProfession(craftString)
	return private.spellDB:GetUniqueRowField("craftString", craftString, "profession")
end

function Crafting.GetNumResult(craftString)
	return private.spellDB:GetUniqueRowField("craftString", craftString, "numResult")
end

function Crafting.PlayerIterator(craftString)
	return Vararg.Iterator(private.spellDB:GetUniqueRowField("craftString", craftString, "players"))
end

function Crafting.HasPlayer(craftString, player)
	return private.spellDB:NewQuery()
		:Equal("craftString", craftString)
		:ListContains("players", player)
		:IsNotEmptyAndRelease()
end

function Crafting.GetName(craftString)
	return private.spellDB:GetUniqueRowField("craftString", craftString, "name")
end

function Crafting.MatIterator(craftString)
	return private.matDB:NewQuery()
		:Select("itemString", "quantity")
		:Equal("craftString", craftString)
		:StartsWith("itemString", "i:")
		:IteratorAndRelease()
end

function Crafting.MatIteratorByRecipeString(recipeString)
	local craftString = CraftString.FromRecipeString(recipeString)
	local result = TempTable.Acquire()
	for _, itemString, quantity in Crafting.MatIterator(craftString) do
		Table.InsertMultiple(result, itemString, quantity)
	end
	for _, _, itemId in RecipeString.OptionalMatIterator(recipeString) do
		local itemString = "i:"..itemId
		local quantity = Crafting.GetOptionalMatQuantity(craftString, itemId)
		Table.InsertMultiple(result, itemString, quantity)
	end
	return TempTable.Iterator(result, 2)
end

function Crafting.OptionalMatIterator(craftString)
	return private.matDB:NewQuery()
		:Select("itemString", "slotId")
		:VirtualField("slotId", "number", MatString.GetSlotId, "itemString")
		:Equal("craftString", craftString)
		:Matches("itemString", "^[qofr]:")
		:OrderBy("slotId", true)
		:IteratorAndRelease()
end

function Crafting.GetOptionalMatQuantity(craftString, matItemId)
	return private.matDB:NewQuery()
		:Select("quantity")
		:Equal("craftString", craftString)
		:Matches("itemString", "^[qofr]:.*"..matItemId)
		:GetFirstResultAndRelease()
end

function Crafting.GetMatsAsTable(craftString, tbl)
	private.matDBAllMatsQuery
		:BindParams(craftString)
		:AsTable(tbl)
end

function Crafting.RemoveCraftPlayers(craftString, playersToRemove)
	local row = private.spellDB:GetUniqueRow("craftString", craftString)
	local players = TempTable.Acquire(row:GetField("players"))
	for i = #players, 1, -1 do
		local player = players[i]
		if playersToRemove[player] then
			private.settings.crafts[craftString].players[player] = nil
			tremove(players, i)
		end
	end
	if #players > 0 then
		row:SetField("players", players)
			:Update()
			:Release()
		TempTable.Release(players)
		return true
	else
		-- No more players so remove this spell and all its mats
		TempTable.Release(players)
		private.spellDB:DeleteRow(row)
		row:Release()
		private.settings.crafts[craftString] = nil
		private.MatDBDeleteCraftStrings(craftString)
		return false
	end
end

function Crafting.RemovePlayerSpells(playerName, craftStrings)
	local query = private.spellDB:NewQuery()
		:InTable("craftString", craftStrings)
		:ListContains("players", playerName)
	if query:Count() == 0 then
		query:Release()
		return
	end
	local removedCraftStrings = TempTable.Acquire()
	local toRemove = TempTable.Acquire()
	private.spellDB:SetQueryUpdatesPaused(true)
	if query:Count() > 0 then
		Log.Info("Removing %d crafts", query:Count())
	end
	for _, row in query:Iterator() do
		assert(not next(private.playerTemp))
		Vararg.IntoTable(private.playerTemp, row:GetField("players"))
		local craftString = row:GetField("craftString")
		if #private.playerTemp == 1 then
			-- The current player was the only player, so we'll delete the entire row and all its mats
			removedCraftStrings[craftString] = true
			private.settings.crafts[craftString] = nil
			tinsert(toRemove, row)
		else
			-- Remove this player form the row
			assert(Table.RemoveByValue(private.playerTemp, playerName) == 1)
			row:SetField("players", private.playerTemp)
				:Update()
			private.settings.crafts[craftString].players[playerName] = nil
		end
		wipe(private.playerTemp)
	end
	for _, row in ipairs(toRemove) do
		private.spellDB:DeleteRow(row)
	end
	TempTable.Release(toRemove)
	query:Release()
	private.spellDB:SetQueryUpdatesPaused(false)

	private.MatDBDeleteCraftStrings(removedCraftStrings)
	TempTable.Release(removedCraftStrings)
end

function Crafting.SetSpellDBQueryUpdatesPaused(paused)
	private.spellDB:SetQueryUpdatesPaused(paused)
end

function Crafting.CreateOrUpdate(craftString, itemString, profession, rootCategoryId, name, numResult, player, hasCD, baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality)
	local craftInfo = private.settings.crafts[craftString]
	if craftInfo then
		local row = private.spellDB:GetUniqueRow("craftString", craftString)
		assert(row)
		if not craftInfo.players[player] then
			assert(not next(private.playerTemp))
			Vararg.IntoTable(private.playerTemp, row:GetField("players"))
			assert(not Table.KeyByValue(private.playerTemp, player))
			assert(#private.playerTemp > 0)
			tinsert(private.playerTemp, player)
			row:SetField("players", private.playerTemp)
			wipe(private.playerTemp)
		end
		if itemString ~= craftInfo.itemString then
			craftInfo.itemString = itemString
			row:SetField("itemString", itemString)
		end
		if profession ~= craftInfo.profession then
			craftInfo.profession = profession
			row:SetField("profession", profession)
		end
		craftInfo.rootCategoryId = rootCategoryId
		if name ~= craftInfo.name then
			craftInfo.name = name
			row:SetField("name", name)
		end
		if numResult ~= craftInfo.numResult then
			craftInfo.numResult = numResult
			row:SetField("numResult", numResult)
		end
		if (hasCD or nil) ~= craftInfo.hasCD then
			craftInfo.hasCD = hasCD or nil
			row:SetField("hasCD", hasCD)
		end
		row:Update()
		row:Release()
		if ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_QUALITY) then
			craftInfo.players[player] = type(craftInfo.players[player]) == "table" and craftInfo.players[player] or {}
			craftInfo.players[player].baseRecipeDifficulty = baseRecipeDifficulty
			craftInfo.players[player].baseRecipeQuality = baseRecipeQuality
			craftInfo.players[player].maxRecipeQuality = maxRecipeQuality
		else
			craftInfo.players[player] = true
		end
		local spellId = CraftString.GetSpellId(craftString)
		local rank = CraftString.GetRank(craftString)
		local level = CraftString.GetLevel(craftString)
		local quality = CraftString.GetQuality(craftString)
		local deleteRow = private.spellDB:GetUniqueRow("craftString", "c:"..spellId)
		if (rank or level or quality) and deleteRow then
			private.spellDB:DeleteRow(deleteRow)
			private.settings.crafts["c:"..spellId] = nil
		end
		if deleteRow then
			deleteRow:Release()
		end
	else
		private.settings.crafts[craftString] = {
			mats = {},
			players = {
				[player] = ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_QUALITY) and {
					baseRecipeDifficulty = baseRecipeDifficulty,
					baseRecipeQuality = baseRecipeQuality,
					maxRecipeQuality = maxRecipeQuality,
				} or true,
			},
			itemString = itemString,
			name = name,
			profession = profession,
			rootCategoryId = rootCategoryId,
			numResult = numResult,
			hasCD = hasCD,
		}
		assert(not next(private.playerTemp))
		tinsert(private.playerTemp, player)
		private.spellDB:NewRow()
			:SetField("craftString", craftString)
			:SetField("itemString", itemString)
			:SetField("profession", profession)
			:SetField("name", name)
			:SetField("numResult", numResult)
			:SetField("players", private.playerTemp)
			:SetField("hasCD", hasCD)
			:Create()
		wipe(private.playerTemp)
	end
end

function Crafting.CreateOrUpdatePlayer(craftString, player, baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality)
	local craftPlayers = private.settings.crafts[craftString].players
	if craftPlayers[player] then
		if ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_QUALITY) then
			-- Update the quality info
			craftPlayers[player] = type(craftPlayers[player]) == "table" and craftPlayers[player] or {}
			craftPlayers[player].baseRecipeDifficulty = baseRecipeDifficulty
			craftPlayers[player].baseRecipeQuality = baseRecipeQuality
			craftPlayers[player].maxRecipeQuality = maxRecipeQuality
		end
		return
	end
	local row = private.spellDB:GetUniqueRow("craftString", craftString)
	assert(not next(private.playerTemp))
	Vararg.IntoTable(private.playerTemp, row:GetField("players"))
	assert(#private.playerTemp > 0)
	tinsert(private.playerTemp, player)
	row:SetField("players", private.playerTemp)
		:Update()
		:Release()
	wipe(private.playerTemp)
	craftPlayers[player] = ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_QUALITY) and {
		baseRecipeDifficulty = baseRecipeDifficulty,
		baseRecipeQuality = baseRecipeQuality,
		maxRecipeQuality = maxRecipeQuality,
	} or true
end

function Crafting.SetMats(craftString, matQuantities)
	if Table.Equal(private.settings.crafts[craftString].mats, matQuantities) then
		-- nothing changed
		return
	end

	wipe(private.settings.crafts[craftString].mats)
	for itemString, quantity in pairs(matQuantities) do
		private.settings.crafts[craftString].mats[itemString] = quantity
	end

	private.matDB:SetQueryUpdatesPaused(true)
	local removedMats = TempTable.Acquire()
	local usedMats = TempTable.Acquire()
	private.matDBSpellIdQuery:BindParams(craftString)
	for _, row in private.matDBSpellIdQuery:Iterator() do
		local itemString = row:GetField("itemString")
		local quantity = matQuantities[itemString]
		if not quantity then
			-- remove this row
			private.matDB:DeleteRow(row)
			removedMats[itemString] = true
			private.HandleMatDBDeleteRow(itemString)
		else
			usedMats[itemString] = true
			row:SetField("quantity", quantity)
				:Update()
		end
	end
	local profession = Crafting.GetProfession(craftString)
	for matString, quantity in pairs(matQuantities) do
		if not usedMats[matString] then
			private.matDB:NewRow()
				:SetField("craftString", craftString)
				:SetField("itemString", matString)
				:SetField("quantity", quantity)
				:Create()
			private.HandleMatDBAddRow(matString)
			for itemString in MatString.ItemIterator(matString) do
				private.MatItemDBUpdateOrInsert(itemString, profession)
			end
		end
	end
	TempTable.Release(usedMats)
	private.matDB:SetQueryUpdatesPaused(false)

	private.ProcessRemovedMats(removedMats)
	TempTable.Release(removedMats)
end

function Crafting.SetMatCustomValue(itemString, value)
	private.settings.mats[itemString].customValue = value
	private.matItemDB:GetUniqueRow("itemString", itemString)
		:SetField("customValue", value or "")
		:Update()
end

function Crafting.CanCraftItem(itemString)
	return private.spellDB:NewQuery()
		:Equal("itemString", itemString)
		:IsNotEmptyAndRelease()
end

function Crafting.RestockHelp(link)
	local itemString = ItemString.Get(link)
	if not itemString then
		ChatMessage.PrintUser(L["No item specified. Usage: /tsm restock_help [ITEM_LINK]"])
		return
	end

	local msg = private.GetRestockHelpMessage(itemString)
	ChatMessage.PrintfUser(L["Restock help for %s: %s"], link, msg)
end

function Crafting.IgnoreCooldown(craftString)
	assert(not private.settings.craftingCooldownIgnore[CHARACTER_KEY..IGNORED_COOLDOWN_SEP..craftString])
	private.settings.craftingCooldownIgnore[CHARACTER_KEY..IGNORED_COOLDOWN_SEP..craftString] = true
	private.ignoredCooldownDB:NewRow()
		:SetField("characterKey", CHARACTER_KEY)
		:SetField("craftString", craftString)
		:Create()
end

function Crafting.IsCooldownIgnored(craftString)
	return private.settings.craftingCooldownIgnore[CHARACTER_KEY..IGNORED_COOLDOWN_SEP..craftString]
end

function Crafting.CreateIgnoredCooldownQuery()
	return private.ignoredCooldownDB:NewQuery()
		:VirtualField("name", "string", Crafting.GetName, "craftString", "?")
end

function Crafting.RemoveIgnoredCooldown(characterKey, craftString)
	assert(private.settings.craftingCooldownIgnore[characterKey..IGNORED_COOLDOWN_SEP..craftString])
	private.settings.craftingCooldownIgnore[characterKey..IGNORED_COOLDOWN_SEP..craftString] = nil
	local row = private.ignoredCooldownDB:NewQuery()
		:Equal("characterKey", characterKey)
		:Equal("craftString", craftString)
		:GetFirstResultAndRelease()
	assert(row)
	private.ignoredCooldownDB:DeleteRow(row)
	row:Release()
end

function Crafting.GetMatNames(craftString)
	return private.matDBMatNamesQuery:BindParams(craftString)
		:JoinedString("name", "")
end

function Crafting.IsQualityCraft(craftString)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_QUALITY) then
		return false
	elseif CraftString.GetQuality(craftString) then
		return true
	elseif private.settings.crafts[craftString] and Crafting.GetQualityInfo(craftString) then
		return true
	else
		return false
	end
end

function Crafting.GetQualityInfo(craftString, playerFilter)
	local craftInfo = private.settings.crafts[craftString]
	if not craftInfo or not ClientInfo.HasFeature(ClientInfo.FEATURES.CRAFTING_QUALITY) then
		return nil, nil, nil
	end
	local baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality = nil, nil, nil
	for player, info in pairs(craftInfo.players) do
		if (not playerFilter or player == playerFilter) and type(info) == "table" and info.baseRecipeQuality and (not baseRecipeQuality or info.baseRecipeQuality > baseRecipeQuality) then
			baseRecipeDifficulty = info.baseRecipeDifficulty
			baseRecipeQuality = info.baseRecipeQuality
			maxRecipeQuality = info.maxRecipeQuality
		end
	end
	return baseRecipeDifficulty, baseRecipeQuality, maxRecipeQuality
end

function Crafting.GetRootCategoryId(craftString)
	local craftInfo = private.settings.crafts[craftString]
	return craftInfo and craftInfo.rootCategoryId or nil
end

---Gets the conversion value for an item.
---@param itemString string
---@param customPrice any
---@param method any
---@return number
---@return table
function Crafting.GetConversionsValue(itemString, customPrice, method)
	if not customPrice then
		return
	end

	-- Calculate disenchant value first
	if (not method or method == Conversion.METHOD.DISENCHANT) and ItemInfo.IsDisenchantable(itemString) then
		local classId = ItemInfo.GetClassId(itemString)
		local quality = ItemInfo.GetQuality(itemString)
		local itemLevel = ClientInfo.IsRetail() and ItemInfo.GetItemLevel(itemString) or ItemInfo.GetItemLevel(ItemString.GetBase(itemString))
		local expansion = ClientInfo.IsRetail() and ItemInfo.GetExpansion(itemString) or nil
		local value = 0
		if quality and itemLevel and classId then
			for targetItemString in Conversion.DisenchantTargetItemIterator() do
				local amountOfMats = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel, expansion)
				if amountOfMats then
					local matValue = CustomString.GetValue(customPrice, targetItemString)
					if not matValue or matValue == 0 then
						return
					end
					value = value + matValue * amountOfMats
				end
			end
		end

		value = floor(value)
		if value > 0 then
			return value, Conversion.METHOD.DISENCHANT
		end
	end

	-- Calculate other conversion values
	local value = 0
	for targetItemString, rate, _, _, _, targetQuality, sourceQuality, _, targetItemMethod in Conversion.TargetItemsByMethodIterator(itemString, method) do
		method = method or targetItemMethod
		local quality = sourceQuality and TSM.Crafting.Quality.GetExpectedSalvageResult(method, sourceQuality)
		if not targetQuality or targetQuality == quality then
			local matValue = INDIRECT_RESULT_MATERIALS[targetItemString] and Crafting.GetConversionsValue(targetItemString, customPrice, method) or CustomString.GetValue(customPrice, targetItemString)
			value = value + (matValue or 0) * rate
		end
	end

	value = Math.Round(value)
	return value > 0 and value or nil, method
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ProcessRemovedMats(removedMats)
	private.matItemDB:SetQueryUpdatesPaused(true)
	for matString in pairs(removedMats) do
		for itemString in MatString.ItemIterator(matString) do
			if not private.numMatDBRows[itemString] then
				local matItemRow = private.matItemDB:GetUniqueRow("itemString", itemString)
				if matItemRow then
					private.matItemDB:DeleteRow(matItemRow)
					matItemRow:Release()
				end
			end
		end
	end
	private.matItemDB:SetQueryUpdatesPaused(false)
end

function private.MatDBDeleteCraftStrings(craftStrings)
	local query = private.matDB:NewQuery()
	if type(craftStrings) == "table" then
		query:InTable("craftString", craftStrings)
	elseif type(craftStrings) == "string" then
		query:Equal("craftString", craftStrings)
	else
		error("Invalid craftStrings: "..tostring(craftStrings))
	end
	local removedMats = TempTable.Acquire()
	private.matDB:SetQueryUpdatesPaused(true)
	for _, matRow in query:Iterator() do
		local itemString = matRow:GetField("itemString")
		removedMats[itemString] = true
		private.matDB:DeleteRow(matRow)
		private.HandleMatDBDeleteRow(itemString)
	end
	query:Release()
	private.matDB:SetQueryUpdatesPaused(false)
	private.ProcessRemovedMats(removedMats)
	TempTable.Release(removedMats)
end

function private.HandleMatDBAddRow(matString)
	for itemString in MatString.ItemIterator(matString) do
		private.numMatDBRows[itemString] = (private.numMatDBRows[itemString] or 0) + 1
	end
end

function private.HandleMatDBDeleteRow(matString)
	for itemString in MatString.ItemIterator(matString) do
		private.numMatDBRows[itemString] = private.numMatDBRows[itemString] - 1
		if private.numMatDBRows[itemString] == 0 then
			private.numMatDBRows[itemString] = nil
		end
	end
end

function private.ProfitPctVirtualField(craftString)
	local craftingCost, _, profit = TSM.Crafting.Cost.GetCostsByCraftString(craftString)
	return (craftingCost and profit) and floor(profit * 100 / craftingCost) or Math.GetNan()
end

function private.SaleRateVirtualField(itemString)
	return TSM.AuctionDB.GetRegionItemData(itemString, "regionSalePercent") or Math.GetNan()
end

function private.GetRestockHelpMessage(itemString)
	-- check if the item is in a group
	local groupPath = Group.GetPathByItem(itemString)
	if not groupPath then
		return L["This item is not in a TSM group."]
	end

	-- check that there's a crafting operation applied
	if not CraftingOperation.HasOperation(itemString) then
		return format(L["There is no Crafting operation applied to this item's TSM group (%s)."], Group.FormatPath(groupPath))
	end

	-- check if it's an invalid operation
	local isValid, err = TSM.Crafting.IsOperationValid(itemString)
	if not isValid then
		return err
	end

	-- check that this item is craftable
	local levelItemString = ItemString.ToLevel(itemString)
	if not TSM.Crafting.CanCraftItem(levelItemString) then
		return L["You don't know how to craft this item."]
	end

	-- check the restock quantity
	local neededQuantity = CraftingOperation.GetRestockQuantity(itemString, private.GetTotalQuantity(itemString))
	if neededQuantity == 0 then
		return L["You either already have at least your max restock quantity of this item or the number which would be queued is less than the min restock quantity."]
	end

	-- check if we would actually queue any
	local cost, craftString = TSM.Crafting.Cost.GetLowestCostByItem(itemString)
	local numResult = craftString and TSM.Crafting.GetNumResult(craftString)
	if neededQuantity < numResult then
		return format(L["A single craft makes %d and you only need to restock %d."], numResult, neededQuantity)
	end

	-- check the prices on the item and the min profit
	local hasMinProfit, minProfit = CraftingOperation.GetMinProfit(itemString)
	if hasMinProfit then
		local craftedValue = TSM.Crafting.Cost.GetCraftedItemValue(itemString)
		local profit = cost and craftedValue and (craftedValue - cost) or nil

		-- check that there's a crafted value
		if not craftedValue then
			return L["The 'Craft Value Method' did not return a value for this item."]
		end

		-- check that there's a crafted cost
		if not cost then
			return L["This item does not have a crafting cost. Check that all of its mats have mat prices."]
		end

		-- check that there's a profit
		assert(profit)

		if not minProfit then
			return L["The min profit did not evaluate to a valid value for this item."]
		end

		if profit < minProfit then
			return format(L["The profit of this item (%s) is below the min profit (%s)."], Money.ToStringExact(profit), Money.ToStringExact(minProfit))
		end
	end

	return L["This item will be added to the queue when you restock its group. If this isn't happening, please visit http://support.tradeskillmaster.com for further assistance."]
end

function private.GetTotalQuantity(itemString)
	return CustomString.GetSourceValue("NumInventory", itemString) or 0
end

function private.GetMatCost(itemString)
	return CustomString.GetSourceValue("MatPrice", itemString) or Math.GetNan()
end

function private.MatItemDBUpdateOrInsert(itemString, profession)
	local matItemRow = private.matItemDB:GetUniqueRow("itemString", itemString)
	if matItemRow then
		-- update the professions if necessary
		local professions = TempTable.Acquire(strsplit(PROFESSION_SEP, matItemRow:GetField("professions")))
		if not Table.KeyByValue(professions, profession) then
			tinsert(professions, profession)
			sort(professions)
			matItemRow:SetField("professions", table.concat(professions, PROFESSION_SEP))
				:Update()
		end
		TempTable.Release(professions)
	else
		private.matItemDB:NewRow()
			:SetField("itemString", itemString)
			:SetField("professions", profession)
			:SetField("customValue", private.settings.mats[itemString].customValue or "")
			:Create()
	end
end

function private.IsCraftStringHigherProfit(craftingCost, profit, hasCD, bestCraftingCost, bestProfit, bestHasCD)
	-- No CD is always better than a CD
	if not hasCD and bestHasCD then
		return true
	elseif hasCD and not bestHasCD then
		return false
	end
	-- Order by profit
	if not profit and bestProfit then
		return false
	elseif profit and not bestProfit then
		return true
	elseif profit and bestProfit then
		return profit > bestProfit
	end
	-- Order by crafting cost
	if not craftingCost and bestCraftingCost then
		return false
	elseif craftingCost and not bestCraftingCost then
		return true
	elseif craftingCost and bestCraftingCost then
		return craftingCost < bestCraftingCost
	end
	-- Stick with what we have
	return false
end
