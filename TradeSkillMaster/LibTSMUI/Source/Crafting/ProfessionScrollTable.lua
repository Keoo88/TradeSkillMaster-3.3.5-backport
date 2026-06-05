-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local Item = LibTSMUI:From("LibTSMWoW"):Include("API.Item")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatString")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local FAVORITE_CATEGORY_ID = -1
local INDENT_WIDTH = 8
local ICON_SPACING = 4
local EXPANDER_TEXTURE_EXPANDED = "iconPack.12x12/Caret/Down"
local EXPANDER_TEXTURE_COLLAPSED = "iconPack.12x12/Caret/Right"
local FAVORITE_TEXTURE_ACTIVE = "iconPack.12x12/Star/Filled"
local FAVORITE_TEXTURE_INACTIVE = "iconPack.12x12/Star/Unfilled"
local SORTABLE_COLS = {
	name = true,
	qty = true,
	craftingCost = true,
	itemValue = true,
	profit = true,
	profitPct = true,
	saleRate = true,
}
local COL_INFO = {
	name = {
		title = L["Recipe Name"],
		justifyH = "LEFT",
		font = "ITEM_BODY3",
		disableHiding = true,
		disableReordering = true,
	},
	qty = {
		title = L["Craft"],
		justifyH = "CENTER",
		font = "TABLE_TABLE1",
	},
	craftingCost = {
		title = L["Crafting Cost"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	itemValue = {
		title = L["Item Value"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	profit = {
		title = L["Profit"],
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	profitPct = {
		title = "%",
		justifyH = "RIGHT",
		font = "TABLE_TABLE1",
	},
	saleRate = {
		titleIcon = "iconPack.18x18/SaleRate",
		justifyH = "CENTER",
		font = "TABLE_TABLE1",
	},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local ProfessionScrollTable = UIElements.Define("ProfessionScrollTable", "ScrollTable")
ProfessionScrollTable:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ProfessionScrollTable:__init()
	self.__super:__init(COL_INFO)
	self._query = nil
	self._favoritesContextTable = nil
	self._costsFunc = nil
	self._craftableQuantityFunc = nil
	self._rawData = {}
	self._isCraftString = {}
	self._selectedCraftString = nil
	self._sortField = nil
	self._sortAscending = true
	self._currentFilters = {
		name = nil,
		haveSkillUp = nil,
		isCraftable = nil,
	}
end

function ProfessionScrollTable:Acquire()
	self.__super:Acquire()
	self._sortDisabled = true
end

function ProfessionScrollTable:Release()
	local query = self._query
	self._query = nil
	self._favoritesContextTable = nil
	self._costsFunc = nil
	self._craftableQuantityFunc = nil
	wipe(self._rawData)
	wipe(self._isCraftString)
	self._selectedCraftString = nil
	self._sortField = nil
	self._sortAscending = true
	wipe(self._currentFilters)
	self.__super:Release()
	if query then
		query:Release()
	end
end

---Sets the settings view and key.
---@param settings SettingsView The settings object
---@param key string The settings key
---@param favorites table Table to store favorite craft information
---@return ProfessionScrollTable
function ProfessionScrollTable:SetSettings(settings, key, favorites)
	assert(type(favorites) == "table")
	self.__super:SetSettings(settings, key)
	self._favoritesContextTable = favorites
	return self
end

---Sets the function to look up the costs for a given craft.
---@param func fun(craftString: string): number?, number?, number? Function which returns: `craftingCost`, `itemValue`, `profit`
---@return ProfessionScrollTable
function ProfessionScrollTable:SetCostsFunction(func)
	assert(func and not self._costsFunc)
	self._costsFunc = func
	return self
end

---Sets the function to look up craftable quantity for a given craft.
---@param func fun(craftString: string): number?, number?, number? Function which returns: `num`, `numAll`
---@return ProfessionScrollTable
function ProfessionScrollTable:SetCraftableQuantityFunction(func)
	assert(func and not self._craftableQuantityFunc)
	self._craftableQuantityFunc = func
	return self
end

---Sets the query used to populate the table.
---@param query? DatabaseQuery The query object
---@return ProfessionScrollTable
function ProfessionScrollTable:SetQuery(query)
	assert(self._settings)
	if self._query then
		self._query:Release()
		self._query = nil
	end
	wipe(self._currentFilters)
	if query then
		query:ResetFilters()
			:Equal("level", 1)
			:SetUpdateCallback(self:__closure("_HandleQueryUpdate"))
		self._query = query
		self:_HandleQueryUpdate()
	else
		self:_SetNumRows(0)
		self:Draw()
		self:SetSelectedCraft(nil)
	end
	return self
end

---Sets the filters.
---@param name? string Recipe name filter
---@param haveSkillUp? boolean Only recipes with skill ups
---@param craftableFunc? fun(craftString: string): boolean Function to filter craftable recipes
function ProfessionScrollTable:SetFilters(name, haveSkillUp, craftableFunc)
	if not self._query then
		wipe(self._currentFilters)
		return
	end
	haveSkillUp = haveSkillUp or nil
	local isCraftable = craftableFunc and true or nil
	if self._currentFilters.name == name and self._currentFilters.haveSkillUp == haveSkillUp and self._currentFilters.isCraftable == isCraftable then
		return
	end
	self._query:ResetFilters()
		:Equal("level", 1)
	if name then
		self._query
			:Or()
				:Matches("name", name)
				:Matches("matNames", name)
			:End()
	end
	if haveSkillUp then
		self._query:NotEqual("difficulty", TradeSkill.RECIPE_DIFFICULTY.TRIVIAL)
	end
	if isCraftable then
		self._query:Function("craftString", craftableFunc)
	end
	self._currentFilters.name = name
	self._currentFilters.haveSkillUp = haveSkillUp
	self._currentFilters.isCraftable = isCraftable
	self:_HandleQueryUpdate()
end

---Sets the selected craft.
---@param craftString? string The craft string of the recipe to select
---@return ProfessionScrollTable
function ProfessionScrollTable:SetSelectedCraft(craftString)
	local dataIndex = craftString and Table.KeyByValue(self._rawData, craftString) or nil
	if craftString and not dataIndex then
		return
	end
	local prevDataIndex = self._selectedCraftString and Table.KeyByValue(self._rawData, self._selectedCraftString) or nil
	if craftString == self._selectedCraftString and (not craftString or dataIndex) then
		if dataIndex then
			self:_ScrollToRow(dataIndex)
		end
		return
	end
	local prevRow = prevDataIndex and self:_GetRow(prevDataIndex) or nil
	if prevRow then
		self:_SetRowSelected(prevRow, false)
	end
	if dataIndex then
		local newRow = self:_GetRow(dataIndex)
		if newRow then
			self:_SetRowSelected(newRow, true)
		end
		self._selectedCraftString = self._rawData[dataIndex]
		self:_ScrollToRow(dataIndex)
	else
		self._selectedCraftString = nil
	end

	self:_SendActionScript("OnSelectionChanged")
	return self
end

---Gets the selected craft.
---@return string?
function ProfessionScrollTable:GetSelectedCraft()
	return self._selectedCraftString
end

---Forces a refresh of the scroll table data.
function ProfessionScrollTable:UpdateData()
	if #self._data.name == 0 then
		return
	end
	self:_HandleQueryUpdate()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ProfessionScrollTable.__protected:_IsValidSettingsKey(key)
	return self.__super:_IsValidSettingsKey(key) or key == "collapsed"
end

function ProfessionScrollTable.__private:_HandleQueryUpdate()
	wipe(self._rawData)
	wipe(self._isCraftString)

	local currentCategoryPath = TempTable.Acquire()
	local insertedSpellId = TempTable.Acquire()
	for _, craftString in self._query:Iterator() do
		local spellId = CraftString.GetSpellId(craftString)
		local isInserted, lowerLevelIndex = self:_IsCraftStringInserted(craftString, insertedSpellId)
		if self._favoritesContextTable[spellId] and (not isInserted or lowerLevelIndex) then
			if lowerLevelIndex then
				tremove(self._rawData, lowerLevelIndex)
				insertedSpellId[spellId] = nil
			end
			local categoryId = FAVORITE_CATEGORY_ID
			if categoryId ~= currentCategoryPath[#currentCategoryPath] then
				-- This is a new category
				local newCategoryPath = TempTable.Acquire()
				tinsert(newCategoryPath, 1, categoryId)
				-- Create new category headers
				if currentCategoryPath[1] ~= categoryId then
					if not self:_IsCategoryHidden(categoryId) then
						tinsert(self._rawData, categoryId)
					end
				end
				TempTable.Release(currentCategoryPath)
				currentCategoryPath = newCategoryPath
			end
			if not self:_GetSettingsValue().collapsed[categoryId] and not self:_IsCategoryHidden(categoryId) then
				tinsert(self._rawData, craftString)
				self._isCraftString[craftString] = true
				insertedSpellId[spellId] = #self._rawData
			end
		end
	end
	for _, craftString, categoryId in self._query:Iterator() do
		local spellId = CraftString.GetSpellId(craftString)
		local isInserted, lowerLevelIndex = self:_IsCraftStringInserted(craftString, insertedSpellId)
		if not self._favoritesContextTable[spellId] and (not isInserted or lowerLevelIndex) then
			if lowerLevelIndex then
				tremove(self._rawData, lowerLevelIndex)
				insertedSpellId[spellId] = nil
			end
			if categoryId ~= currentCategoryPath[#currentCategoryPath] then
				-- This is a new category
				local newCategoryPath = TempTable.Acquire()
				local currentCategoryId = categoryId
				while currentCategoryId do
					tinsert(newCategoryPath, 1, currentCategoryId)
					currentCategoryId = Profession.GetParentCategoryId(currentCategoryId)
				end
				-- Create new category headers
				for i = 1, #newCategoryPath do
					local newCategoryId = newCategoryPath[i]
					if currentCategoryPath[i] ~= newCategoryId then
						if not self:_IsCategoryHidden(newCategoryId) and Profession.GetCategoryName(newCategoryId) then
							tinsert(self._rawData, newCategoryId)
						end
					end
				end
				TempTable.Release(currentCategoryPath)
				currentCategoryPath = newCategoryPath
			end
			if not self:_GetSettingsValue().collapsed[categoryId] and not self:_IsCategoryHidden(categoryId) then
				tinsert(self._rawData, craftString)
				self._isCraftString[craftString] = true
				insertedSpellId[spellId] = #self._rawData
			end
		end
	end
	TempTable.Release(insertedSpellId)
	TempTable.Release(currentCategoryPath)

	-- Custom flat sort. The default view is a category tree which can't be sorted,
	-- so when the user clicks a sortable column header we drop the category headers,
	-- flatten to just the recipe rows, and sort them by the chosen column's value.
	if self._sortField then
		local flat = TempTable.Acquire()
		local sortValues = TempTable.Acquire()
		for _, data in ipairs(self._rawData) do
			if self._isCraftString[data] then
				tinsert(flat, data)
				sortValues[data] = self:_GetSortValue(data)
			end
		end
		local ascending = self._sortAscending
		sort(flat, function(a, b)
			local va, vb = sortValues[a], sortValues[b]
			if va == vb then
				return strlower(Profession.GetNameByCraftString(a) or "") < strlower(Profession.GetNameByCraftString(b) or "")
			elseif va == nil then
				return false
			elseif vb == nil then
				return true
			elseif ascending then
				return va < vb
			else
				return va > vb
			end
		end)
		wipe(self._rawData)
		for _, craftString in ipairs(flat) do
			tinsert(self._rawData, craftString)
		end
		TempTable.Release(sortValues)
		TempTable.Release(flat)
	end

	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	local firstCraftString, hasExistingSelection = nil, false
	for _, data in ipairs(self._rawData) do
		if self._isCraftString[data] then
			firstCraftString = firstCraftString or data
			hasExistingSelection = hasExistingSelection or data == self._selectedCraftString
			local name = Profession.GetNameByCraftString(data)
			local nameColor = nil
			local tradeSkillType = TradeSkill.GetType()
			if tradeSkillType == TradeSkill.TYPE.GUILD then
				nameColor = Theme.GetProfessionDifficultyColor(TradeSkill.RECIPE_DIFFICULTY.EASY)
			elseif tradeSkillType == TradeSkill.TYPE.NPC then
				nameColor = Theme.GetProfessionDifficultyColor("nodifficulty")
			else
				nameColor = Theme.GetProfessionDifficultyColor(Profession.GetDifficultyByCraftString(data))
			end
			tinsert(self._data.name, nameColor:ColorText(name))
			tinsert(self._data.qty, self.DEFERRED_DATA)
			tinsert(self._data.craftingCost, self.DEFERRED_DATA)
			tinsert(self._data.itemValue, self.DEFERRED_DATA)
			tinsert(self._data.profit, self.DEFERRED_DATA)
			tinsert(self._data.profitPct, self.DEFERRED_DATA)
			tinsert(self._data.saleRate, self.DEFERRED_DATA)
		else
			if data == FAVORITE_CATEGORY_ID then
				tinsert(self._data.name, L["Favorited Patterns"])
			else
				local currentSkillLevel, maxSkillLevel = Profession.GetCategorySkillLevel(data)
				local name = Profession.GetCategoryName(data)
				if name and currentSkillLevel and maxSkillLevel then
					name = name.." ("..currentSkillLevel.."/"..maxSkillLevel..")"
				end
				if name then
					local isTopLevel = data == FAVORITE_CATEGORY_ID or Profession.GetCategoryNumIndents(data) == 0
					tinsert(self._data.name, Theme.GetColor(isTopLevel and "INDICATOR" or "INDICATOR_ALT"):ColorText(name))
				else
					-- This happens if we're switching to another profession
					tinsert(self._data.name, "?")
				end
			end
			tinsert(self._data.qty, "")
			tinsert(self._data.craftingCost, "")
			tinsert(self._data.itemValue, "")
			tinsert(self._data.profit, "")
			tinsert(self._data.profitPct, "")
			tinsert(self._data.saleRate, "")
		end
	end

	self:_SetNumRows(#self._rawData)
	self:Draw()

	-- Update the selection if necessary
	if not hasExistingSelection then
		self:SetSelectedCraft(firstCraftString)
	end
end

function ProfessionScrollTable.__private:_IsCraftStringInserted(craftString, insertedSpellId)
	local spellId = CraftString.GetSpellId(craftString)
	local prevIndex = insertedSpellId[spellId]
	local prevCraftString = prevIndex and self._rawData[prevIndex]
	if not prevCraftString then
		return false
	end
	local level = CraftString.GetLevel(craftString)
	if not level then
		return true
	end
	local isHigherLevel = level > (CraftString.GetLevel(prevCraftString) or -1)
	return true, isHigherLevel and prevIndex or nil
end

function ProfessionScrollTable.__private:_IsCategoryHidden(categoryId)
	if categoryId == FAVORITE_CATEGORY_ID then
		return false
	end
	local parent = Profession.GetParentCategoryId(categoryId)
	while parent do
		if self:_GetSettingsValue().collapsed[parent] then
			return true
		end
		parent = Profession.GetParentCategoryId(parent)
	end
	return false
end

function ProfessionScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if mouseButton ~= "LeftButton" then
		return false
	end
	local id = Table.GetDistinctKey(self._header.cells, button)
	if not id or not SORTABLE_COLS[id] then
		return false
	end
	if self._sortField == id then
		if self._sortAscending then
			self._sortAscending = false
		else
			-- Third click clears the sort and returns to the category tree view
			self._sortField = nil
			self._sortAscending = true
		end
	else
		self._sortField = id
		self._sortAscending = true
	end
	self:_DrawSortFlag()
	self:_HandleQueryUpdate()
	return true
end

function ProfessionScrollTable.__protected:_DrawSortFlag()
	local sortBackground = self._header.sortBackground
	local sortFlag = self._header.sortFlag
	sortBackground:Hide()
	sortBackground:ClearAllPoints()
	sortFlag:Hide()
	sortFlag:ClearAllPoints()
	if not self._sortField then
		return
	end
	local cell = self._header.cells[self._sortField]
	if not cell then
		return
	end
	local colSpacing = Theme.GetColSpacing()
	sortBackground:SetPoint("TOPLEFT", cell, -colSpacing / 2, 0)
	sortBackground:SetPoint("BOTTOMRIGHT", cell, colSpacing / 2, 0)
	sortBackground:SetColorTexture(Theme.GetColor("ACTIVE_BG"):GetFractionalRGBA())
	sortBackground:Show()
	sortFlag:SetPoint("TOPLEFT", cell, -colSpacing / 2, 2)
	sortFlag:SetPoint("TOPRIGHT", cell, colSpacing / 2, 2)
	sortFlag:TSMSetColorTexture(self._sortAscending and "INDICATOR" or "INDICATOR_ALT")
	sortFlag:Show()
end

function ProfessionScrollTable.__private:_GetSortValue(craftString)
	local field = self._sortField
	if field == "name" then
		return strlower(Profession.GetNameByCraftString(craftString) or "")
	elseif field == "qty" then
		local num = self._craftableQuantityFunc(craftString)
		return num
	end
	local craftingCost, itemValue, profit, saleRate = self._costsFunc(craftString)
	if field == "craftingCost" then
		return craftingCost
	elseif field == "itemValue" then
		return itemValue
	elseif field == "profit" then
		return profit
	elseif field == "profitPct" then
		return (profit and craftingCost and craftingCost > 0) and (profit * 100 / craftingCost) or nil
	elseif field == "saleRate" then
		return saleRate
	end
	return nil
end

function ProfessionScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	local data = self._rawData[dataIndex]
	-- TODO: Support optional materials here
	local num, numAll = self._craftableQuantityFunc(data)
	local qty = nil
	if num == numAll then
		qty = num > 0 and Theme.GetColor("FEEDBACK_GREEN"):ColorText(num) or num
	elseif num > 0 then
		qty = Theme.GetColor("FEEDBACK_GREEN"):ColorText(num.."-"..numAll)
	elseif numAll > 0 then
		qty = Theme.GetColor("FEEDBACK_YELLOW"):ColorText(num.."-"..numAll)
	else
		qty = num.."-"..numAll
	end
	self._data.qty[dataIndex] = qty
	local craftingCost, itemValue, profit, saleRate = self._costsFunc(data)
	self._data.craftingCost[dataIndex] = craftingCost and Money.ToStringForUI(craftingCost, nil) or ""
	self._data.itemValue[dataIndex] =  itemValue and Money.ToStringForUI(itemValue) or ""
	local profitColor = profit and Theme.GetColor(profit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED")
	self._data.profit[dataIndex] =  profit and Money.ToStringForUI(profit, profitColor:GetTextColorPrefix()) or ""
	self._data.profitPct[dataIndex] =  profit and profitColor:ColorText(floor(profit * 100 / craftingCost).."%") or ""
	self._data.saleRate[dataIndex] =  saleRate and format("%0.3f", saleRate) or ""
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)
	local name = row:GetText("name")
	local expander = row:AddTexture("expander")
	expander:TSMSetSize(EXPANDER_TEXTURE_EXPANDED)
	expander:SetPoint("RIGHT", name, "LEFT", -ICON_SPACING, 0)
	local favorite = row:AddTexture("favorite")
	favorite:TSMSetSize(FAVORITE_TEXTURE_ACTIVE)
	favorite:SetPoint("RIGHT", name, "LEFT", -ICON_SPACING, 0)
	favorite:Hide()
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowDraw(row)
	self.__super:_HandleRowDraw(row)
	local data = self._rawData[row:GetDataIndex()]

	local indentLevel = 0
	if self._isCraftString[data] then
		indentLevel = 2
	elseif data ~= FAVORITE_CATEGORY_ID then
		indentLevel = Profession.GetCategoryNumIndents(data) * 2
	end

	local colSpacing = Theme.GetColSpacing()
	local text = row:GetText("name")
	text:SetWidth(text:GetWidth() - indentLevel * INDENT_WIDTH)
	text:SetPoint("LEFT", self._header.moreButton:GetWidth() + colSpacing * 1.5 + indentLevel * INDENT_WIDTH, 0)
	row:GetTexture("actionIcon"):SetPoint("LEFT", colSpacing / 2, 0)

	local expander = row:GetTexture("expander")
	if self._isCraftString[data] then
		expander:Hide()
	else
		expander:Show()
		expander:TSMSetTexture(self:_GetSettingsValue().collapsed[data] and EXPANDER_TEXTURE_COLLAPSED or EXPANDER_TEXTURE_EXPANDED)
	end

	local favorite = row:GetTexture("favorite")
	if self._isCraftString[data] then
		favorite:TSMSetTexture(self._favoritesContextTable[CraftString.GetSpellId(data)] and FAVORITE_TEXTURE_ACTIVE or FAVORITE_TEXTURE_INACTIVE)
	else
		favorite:Hide()
	end
	self:_SetRowSelected(row, data == self._selectedCraftString)
end

---@param row ListRow
function ProfessionScrollTable.__private:_SetRowSelected(row, selected)
	local data = self._rawData[row:GetDataIndex()]
	if self._isCraftString[data] then
		local favorite = row:GetTexture("favorite")
		if TradeSkill.GetType() == TradeSkill.TYPE.PLAYER and selected then
			favorite:Show()
		elseif not row:IsHovering() then
			favorite:Hide()
		end
	end
	row:SetSelected(selected)
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowEnter(row)
	local data = self._rawData[row:GetDataIndex()]
	if not self._isCraftString[data] or TradeSkill.GetType() ~= TradeSkill.TYPE.PLAYER then
		return
	end
	row:GetTexture("favorite"):Show()
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowLeave(row)
	local data = self._rawData[row:GetDataIndex()]
	if data ~= self._selectedCraftString then
		row:GetTexture("favorite"):Hide()
	end
end

---@param row ListRow
function ProfessionScrollTable.__protected:_HandleRowClick(row, mouseButton)
	local data = self._rawData[row:GetDataIndex()]
	if self._isCraftString[data] then
		if mouseButton ~= "LeftButton" then
			return
		end
		local favorite = row:GetTexture("favorite")
		if favorite:IsVisible() and favorite:IsMouseOver() then
			local spellId = CraftString.GetSpellId(data)
			self._favoritesContextTable[spellId] = not self._favoritesContextTable[spellId] or nil
			favorite:TSMSetTexture(self._favoritesContextTable[spellId] and FAVORITE_TEXTURE_ACTIVE or FAVORITE_TEXTURE_INACTIVE)
			self:_HandleQueryUpdate()
		elseif IsShiftKeyDown() then
			Profession.LinkRecipe(data)
		else
			self:SetSelectedCraft(data)
		end
	else
		local collapsedSettings = self:_GetSettingsValue().collapsed
		collapsedSettings[data] = not collapsedSettings[data] or nil
		self:_HandleQueryUpdate()
	end
end

function ProfessionScrollTable.__protected:_PopulateMoreDialog(menuDialog)
	self.__super:_PopulateMoreDialog(menuDialog)
	menuDialog:AddRow("CREATE_GROUPS", "", L["Create Profession Groups"])
end

function ProfessionScrollTable.__protected:_HandleMoreDialogClick(menuDialog, id1, id2, extra)
	if id1 == "CREATE_GROUPS" then
		assert(not id2)
		self:GetBaseElement():HideDialog()
		self:_CreateGroups()
	else
		self.__super:_HandleMoreDialogClick(menuDialog, id1, id2, extra)
	end
end

function ProfessionScrollTable.__private:_CreateGroups()
	local profName = Profession.GetCurrentProfession()
	if not profName then
		ChatMessage.PrintUser(L["There is currently no profession open, so cannot create profession groups."])
		return
	end
	if not Group.Exists(profName) then
		GroupOperation.CreateGroup(profName)
	end
	local itemsGroupPath = Group.JoinPath(profName, L["Items"])
	if not Group.Exists(itemsGroupPath) then
		GroupOperation.CreateGroup(itemsGroupPath)
	end
	local matsGroupPath = Group.JoinPath(profName, L["Materials"])
	if not Group.Exists(matsGroupPath) then
		GroupOperation.CreateGroup(matsGroupPath)
	end

	local numMats, numItems = 0, 0
	local query = Profession.CreateScannerQuery()
		:Select("craftString")
	local handledMatString = TempTable.Acquire()
	for _, craftString in query:Iterator() do
		local itemString = Profession.GetItemStringByCraftString(craftString)
		if itemString and not Group.IsItemInGroup(itemString) and not ItemInfo.IsSoulbound(itemString) then
			Group.SetItemGroup(itemString, itemsGroupPath)
			numItems = numItems + 1
		end
		for _, matString in Profession.MatIterator(craftString) do
			if not handledMatString[matString] then
				handledMatString[matString] = true
				local matType = MatString.GetType(matString)
				if matType == MatString.TYPE.NORMAL or matType == MatString.TYPE.QUALITY then
					for matItemString in MatString.ItemIterator(matString) do
						if not Group.IsItemInGroup(matItemString) and not ItemInfo.IsSoulbound(matItemString) and not Item.VariationImpactsQualityByClass(ItemInfo.GetClassId(matItemString)) then
							Group.SetItemGroup(matItemString, matsGroupPath)
							numMats = numMats + 1
						end
					end
				end
			end
		end
	end
	TempTable.Release(handledMatString)
	query:Release()

	if numMats > 0 or numItems > 0 then
		ChatMessage.PrintfUser(L["%s group updated with %d items and %d materials."], profName, numItems, numMats)
	else
		ChatMessage.PrintfUser(L["%s group is already up to date."], profName)
	end
end
