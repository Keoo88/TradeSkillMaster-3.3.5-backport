-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local RecipeString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.RecipeString")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local SessionInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.SessionInfo")
local private = {
	categoryOrder = {},
	sortSelf = nil,
}
local ROW_HEIGHT = 20
local CATEGORY_SEP = "\001"
local EXPANDER_TEXTURE_EXPANDED = "iconPack.12x12/Caret/Down"
local EXPANDER_TEXTURE_COLLAPSED = "iconPack.12x12/Caret/Right"
local EDIT_TEXTURE = "iconPack.12x12/Edit"
local DELETE_TEXTURE = "iconPack.12x12/Close/Default"
local ATTENTION_TEXTURE = "iconPack.12x12/Attention"
local ICON_SIZE = 12
local CONCENTRATION_ICON = "Interface\\ICONS\\UI_Concentration"



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingQueueList = UIElements.Define("CraftingQueueList", "List")
CraftingQueueList:_AddActionScripts("OnNextCraftChanged", "OnNumUpdated", "OnRowMouseDown", "OnRowClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftingQueueList:__init()
	self.__super:__init()
	self._matIteratorFunc = nil
	self._data = {}
	self._recipeString = {}
	self._numQueued = {}
	self._profession = {}
	self._players = {}
	self._numCraftable = {}
	self._profit = {}
	self._tooltipData = {}
	self._texture = {}
	self._itemString = {}
	self._numResult = {}
	self._collapsed = {}
	self._query = nil
end

function CraftingQueueList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function CraftingQueueList:Release()
	self._matIteratorFunc = nil
	wipe(self._data)
	wipe(self._recipeString)
	wipe(self._numQueued)
	wipe(self._profession)
	wipe(self._players)
	wipe(self._numCraftable)
	wipe(self._profit)
	wipe(self._tooltipData)
	wipe(self._texture)
	wipe(self._itemString)
	wipe(self._numResult)
	wipe(self._collapsed)
	if self._query then
		self._query:Release()
		self._query = nil
	end
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the function to use to create an iterator over the materials for a recipe string.
---@param func fun(recipeString): function, any, any Function which returns an iterator with fields: `index`, `itemString`, `quantity`
---@return CraftingQueueList
function CraftingQueueList:SetMatIteratorFunc(func)
	assert(func and not self._matIteratorFunc)
	self._matIteratorFunc = func
	return self
end

---Gets the data of the first row.
---@return string? recipeString
---@return number? numQueued
function CraftingQueueList:GetNextCraft()
	for _, data in ipairs(self._data) do
		if type(data) ~= "string" then
			return self._recipeString[data], self._numQueued[data]
		end
	end
end

---Forces a refresh of the queue data.
function CraftingQueueList:UpdateData()
	if #self._data == 0 then
		return
	end
	self:_HandleQueryUpdate()
end

---Refreshes data in response to the current profession changing.
function CraftingQueueList:HandleProfessionChange()
	if #self._data == 0 then
		return
	end
	-- If there's just a single category, don't need to do a full update
	local singleCategoryDataIndex = nil
	for i, data in ipairs(self._data) do
		if type(data) == "string" then
			if singleCategoryDataIndex then
				singleCategoryDataIndex = nil
				break
			end
			singleCategoryDataIndex = i
		end
	end
	if singleCategoryDataIndex then
		self:_DrawRowsForUpdatedData(singleCategoryDataIndex, singleCategoryDataIndex)
		self:_SendActionScript("OnNextCraftChanged")
	else
		self:_HandleQueryUpdate()
	end
end

---Sets the query source for this list.
---@param query DatabaseQuery The query object
---@return CraftingQueueList
function CraftingQueueList:SetQuery(query)
	if self._query then
		self._query:Release()
	end
	self._query = query
	self._query:SetUpdateCallback(self:__closure("_HandleQueryUpdate"))
	self:_HandleQueryUpdate()
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function CraftingQueueList.__private:_HandleQueryUpdate()
	wipe(self._data)
	wipe(self._recipeString)
	wipe(self._numQueued)
	wipe(self._profession)
	wipe(self._players)
	wipe(self._numCraftable)
	wipe(self._profit)
	wipe(self._tooltipData)
	wipe(self._texture)
	wipe(self._itemString)
	wipe(self._numResult)
	local categories = TempTable.Acquire()
	for _, row in self._query:Iterator() do
		local recipeString, profession, numQueued, numCraftable, profit, itemString, numResult = row:GetFields("recipeString", "profession", "num", "numCraftable", "profit", "itemString", "numResult")
		local players = strjoin(",", row:GetField("players"))
		local rawCategory = strjoin(CATEGORY_SEP, profession, players)
		local category = strlower(rawCategory)
		if not categories[category] then
			tinsert(categories, category)
		end
		categories[category] = rawCategory
		if not self._collapsed[rawCategory] then
			assert(itemString and itemString ~= "")
			local uuid = row:GetUUID()
			tinsert(self._data, uuid)
			self._numCraftable[uuid] = numCraftable
			self._profit[uuid] = not Math.IsNan(profit) and profit or nil
			self._recipeString[uuid] = recipeString
			self._numQueued[uuid] = numQueued
			self._profession[uuid] = profession
			self._players[uuid] = players
			local level = RecipeString.GetLevel(recipeString)
			local rank = RecipeString.GetRank(recipeString)
			if level or rank or RecipeString.HasOptionalMats(recipeString) then
				self._tooltipData[uuid] = level and row:GetField("levelItemString") or recipeString
			else
				self._tooltipData[uuid] = itemString
			end
			-- 3.3.5: ItemInfo.GetTexture может быть nil; GetItemIcon синхронный fallback
			local texture = ItemInfo.GetTexture(itemString)
			if not texture then
				local itemId = tonumber(strmatch(itemString or "", "i:(%d+)"))
				if itemId and _G.GetItemIcon then
					texture = _G.GetItemIcon(itemId)
				end
			end
			self._texture[uuid] = texture or 0
			self._itemString[uuid] = itemString
			self._numResult[uuid] = numResult
		end
	end
	sort(categories, private.CategorySortComparator)
	assert(not next(private.categoryOrder))
	for i, category in ipairs(categories) do
		private.categoryOrder[category] = i
		tinsert(self._data, categories[category])
	end
	TempTable.Release(categories)
	private.sortSelf = self
	sort(self._data, private.DataSortComparator)
	wipe(private.categoryOrder)
	private.sortSelf = nil
	self:_SetNumRows(#self._data)
	self:Draw()
	self:_SendActionScript("OnNextCraftChanged")
end

---@param row ListRow
function CraftingQueueList.__protected:_HandleRowAcquired(row)
	-- Action button
	local action = row:AddTexture("action")
	action:TSMSetSize(EXPANDER_TEXTURE_EXPANDED)
	action:Hide()

	-- Item icon
	local icon = row:AddTexture("icon")
	icon:TSMSetSize(ICON_SIZE, ICON_SIZE)
	row:AddTooltipRegion("iconTooltip", icon, self:__closure("_GetIconTooltip"))

	-- Name text
	local name = row:AddText("name")
	name:SetHeight(ROW_HEIGHT)
	name:SetJustifyH("LEFt")
	name:TSMSetFont("ITEM_BODY3")
	row:AddTooltipRegion("nameTooltip", name, self:__closure("_GetNameTooltip"))

	-- Edit icon
	local edit = row:AddTexture("edit")
	edit:TSMSetTextureAndSize(EDIT_TEXTURE)
	edit:Hide()

	-- Quantity text
	local qty = row:AddText("qty")
	qty:SetHeight(ROW_HEIGHT)
	qty:SetJustifyH("RIGHT")
	qty:TSMSetFont("TABLE_TABLE1")

	-- Layout the row
	local colSpacing = Theme.GetColSpacing()
	action:SetPoint("LEFT", colSpacing / 2, 0)
	icon:SetPoint("LEFT", action, "RIGHT", colSpacing / 2, 0)
	name:SetPoint("LEFT", icon, "RIGHT", colSpacing / 2, 0)
	qty:SetWidth(10)
	name:SetPoint("RIGHT", edit, "LEFT", -colSpacing / 2, 0)
	edit:SetPoint("RIGHT", qty, "LEFT", -colSpacing / 2, 0)
	qty:SetPoint("RIGHT", -colSpacing * 1.5, 0)
end

---@param row ListRow
function CraftingQueueList.__protected:_HandleRowDraw(row)
	local data = self._data[row:GetDataIndex()]
	local isCategory = type(data) == "string"
	local recipeString = not isCategory and self._recipeString[data] or nil
	local numQueued = not isCategory and self._numQueued[data] or nil
	local nameText = row:GetText("name")
	local qtyText = row:GetText("qty")
	local actionTexture = row:GetTexture("action")
	local iconTexture = row:GetTexture("icon")
	local colSpacing = Theme.GetColSpacing()

	-- Update textures and the row layout based on the type of the row
	iconTexture:TSMSetShown(not isCategory)
	actionTexture:TSMSetShown(isCategory)
	if isCategory then
		actionTexture:TSMSetTexture(self._collapsed[data] and EXPANDER_TEXTURE_COLLAPSED or EXPANDER_TEXTURE_EXPANDED)
		nameText:SetPoint("LEFT", actionTexture, "RIGHT", colSpacing / 2, 0)
	else
		actionTexture:TSMSetTexture(DELETE_TEXTURE)
		nameText:SetPoint("LEFT", iconTexture, "RIGHT", colSpacing / 2, 0)
	end

	-- Quantity
	if isCategory then
		qtyText:SetText("")
		-- Setting the width to 0 causes issues
		qtyText:SetWidth(1)
	else
		local numCraftable = min(self._numCraftable[data], numQueued)
		local craftString = CraftString.FromRecipeString(recipeString)
		local onCooldown = Profession.GetRemainingCooldown(craftString)
		qtyText:TSMSetTextColor(((numCraftable == 0 or onCooldown) and "FEEDBACK_RED") or (numCraftable < numQueued and "FEEDBACK_YELLOW") or "FEEDBACK_GREEN")
		qtyText:SetText(format("%s / %s", numCraftable, numQueued))
		qtyText:SetWidth(qtyText:GetUnboundedStringWidth())
	end

	-- Name / icon texture
	if isCategory then
		local profession, players = strsplit(CATEGORY_SEP, data)
		local isValid = private.PlayersContainsCurrentCharacter(players) and strlower(profession) == strlower(TradeSkill.GetName() or "")
		local text = Theme.GetColor("INDICATOR"):ColorText(profession).." ("..players..")"
		if not isValid then
			text = text.."  "..TextureAtlas.GetTextureLink(ATTENTION_TEXTURE)
		end
		nameText:SetText(text)
	else
		nameText:SetText(self:_GetRecipeStringName(data))
		iconTexture:SetTexture(self._texture[data])
	end
end

---@param row ListRow
function CraftingQueueList.__protected:_HandleRowEnter(row)
	if type(self._data[row:GetDataIndex()]) == "string" then
		return
	end
	row:GetTexture("action"):Show()
	row:GetTexture("edit"):Show()
end

---@param row ListRow
function CraftingQueueList.__protected:_HandleRowLeave(row)
	if type(self._data[row:GetDataIndex()]) == "string" then
		return
	end
	row:GetTexture("action"):Hide()
	row:GetTexture("edit"):Hide()
end

---@param row ListRow
function CraftingQueueList.__protected:_HandleRowClick(row, mouseButton)
	local data = self._data[row:GetDataIndex()]
	if type(data) == "string" then
		self._collapsed[data] = not self._collapsed[data] or nil
		self:_HandleQueryUpdate()
	else
		local recipeString = self._recipeString[data]
		if row:GetText("qty"):IsMouseOver(8, -8, -8, 8) or row:GetTexture("edit"):IsMouseOver() then
			local name = self:_GetRecipeStringName(data)
			local dialogFrame = UIElements.New("CraftingQueueEditDialog", "dialog")
				:SetInfo(name, self._texture[data], self._tooltipData[data], self._numQueued[data])
				:AddAnchor("LEFT", row._frame, Theme.GetColSpacing() / 2, 0)
				:AddAnchor("RIGHT", row._frame, -Theme.GetColSpacing(), 0)
				:SetHeight(20)
				:SetContext(recipeString)
				:SetScript("OnHide", self:__closure("_HandleDialogHide"))
			self:GetBaseElement():ShowDialogFrame(dialogFrame)
			dialogFrame:Focus()
		elseif row:GetTexture("action"):IsMouseOver() then
			self:_SendActionScript("OnNumUpdated", recipeString, 0)
		else
			self:_SendActionScript("OnRowClick", recipeString, mouseButton)
		end
	end
end

---@param row ListRow
function CraftingQueueList.__protected:_HandleRowMouseDown(row, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	local data = self._data[row:GetDataIndex()]
	if type(data) == "string" then
		return
	end
	self:_SendActionScript("OnRowMouseDown", self._recipeString[data])
end

function CraftingQueueList:_GetIconTooltip(dataIndex)
	local data = self._data[dataIndex]
	if type(data) == "string" then
		return nil
	end
	return self._tooltipData[data]
end

function CraftingQueueList.__private:_GetNameTooltip(dataIndex)
	local data = self._data[dataIndex]
	if type(data) == "string" then
		local profession, players = strsplit(CATEGORY_SEP, data)
		if not private.PlayersContainsCurrentCharacter(players) then
			return L["You are not on one of the listed characters."]
		elseif strlower(profession) ~= strlower(TradeSkill.GetName() or "") then
			return L["This profession is not open."]
		end
		return
	end

	local recipeString = self._recipeString[data]
	local numQueued = self._numQueued[data]
	local numResult = self._numResult[data]
	local name = self:_GetRecipeStringName(data)
	local tooltipLines = TempTable.Acquire()
	tinsert(tooltipLines, name.." (x"..numQueued..")")
	local profit = self._profit[data]
	local profitStr = profit and Money.ToStringForUI(profit * numResult, Theme.GetColor(profit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"):GetTextColorPrefix()) or "---"
	local totalProfitStr = profit and Money.ToStringForUI(profit * numResult * numQueued, Theme.GetColor(profit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"):GetTextColorPrefix()) or "---"
	tinsert(tooltipLines, L["Profit (Total)"]..": "..profitStr.." ("..totalProfitStr..")")
	for _, matItemString, quantity in self._matIteratorFunc(recipeString) do
		local numHave = BagTracking.GetCraftingMatQuantity(matItemString) + WarbankTracking.GetQuantity(matItemString)
		local numNeed = quantity * numQueued
		local color = Theme.GetColor(numHave >= numNeed and "FEEDBACK_GREEN" or "FEEDBACK_RED")
		tinsert(tooltipLines, color:ColorText(numHave.."/"..numNeed).." - "..(UIUtils.GetDisplayItemName(matItemString) or "?"))
	end
	local concentration = RecipeString.GetConcentration(recipeString)
	if concentration then
		tinsert(tooltipLines, "|T"..CONCENTRATION_ICON..":0|t "..PROFESSIONS_CRAFTING_STAT_CONCENTRATION)
	end
	local cooldown = Profession.GetRemainingCooldown(CraftString.FromRecipeString(recipeString))
	if cooldown then
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_RED"):ColorText(format(L["On Cooldown for %s"], SecondsToTime(cooldown))))
	end
	return strjoin("\n", TempTable.UnpackAndRelease(tooltipLines)), true
end

function CraftingQueueList.__private:_HandleDialogHide(dialog)
	self:_SendActionScript("OnNumUpdated", dialog:GetContext(), dialog:GetValue())
	self:Draw()
end

function CraftingQueueList.__private:_GetRecipeStringName(data)
	local itemString = self._itemString[data]
	local spellId = RecipeString.GetSpellId(self._recipeString[data])
	return itemString and UIUtils.GetDisplayItemName(itemString) or TradeSkill.GetBasicInfo(spellId) or "?"
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PlayersContainsCurrentCharacter(players)
	local player = strlower(SessionInfo.GetCharacterName())
	players = strlower(players)
	return players == player or strmatch(players, "^"..player..",") or strmatch(players, ","..player..",") or strmatch(players, ","..player.."$")
end

function private.CategorySortComparator(a, b)
	local aProfession, aPlayers = strsplit(CATEGORY_SEP, a)
	local bProfession, bPlayers = strsplit(CATEGORY_SEP, b)
	if aProfession ~= bProfession then
		local currentProfession = TradeSkill.GetName()
		currentProfession = strlower(currentProfession or "")
		if aProfession == currentProfession then
			return true
		elseif bProfession == currentProfession then
			return false
		else
			return aProfession < bProfession
		end
	end
	local aContainsPlayer = private.PlayersContainsCurrentCharacter(aPlayers)
	local bContainsPlayer = private.PlayersContainsCurrentCharacter(bPlayers)
	if aContainsPlayer and not bContainsPlayer then
		return true
	elseif bContainsPlayer and not aContainsPlayer then
		return false
	else
		return aPlayers < bPlayers
	end
end

function private.DataSortComparator(a, b)
	local self = private.sortSelf ---@type CraftingQueueList
	-- Sort by category
	local aCategory, bCategory = nil, nil
	if type(a) == "string" and type(b) == "string" then
		return private.categoryOrder[strlower(a)] < private.categoryOrder[strlower(b)]
	elseif type(a) == "string" then
		aCategory = strlower(a)
		bCategory = strlower(strjoin(CATEGORY_SEP, self._profession[b], self._players[b]))
		if aCategory == bCategory then
			return true
		end
	elseif type(b) == "string" then
		aCategory = strlower(strjoin(CATEGORY_SEP, self._profession[a], self._players[a]))
		bCategory = strlower(b)
		if aCategory == bCategory then
			return false
		end
	else
		aCategory = strlower(strjoin(CATEGORY_SEP, self._profession[a], self._players[a]))
		bCategory = strlower(strjoin(CATEGORY_SEP, self._profession[b], self._players[b]))
	end
	if aCategory ~= bCategory then
		return private.categoryOrder[aCategory] < private.categoryOrder[bCategory]
	end
	-- Sort spells within a category
	local aRecipeString = self._recipeString[a]
	local bRecipeString = self._recipeString[b]
	local aNumCraftable = self._numCraftable[a]
	local bNumCraftable = self._numCraftable[b]
	local aNumQueued = self._numQueued[a]
	local bNumQueued = self._numQueued[b]
	local aCanCraftAll = aNumCraftable >= aNumQueued
	local bCanCraftAll = bNumCraftable >= bNumQueued
	if aCanCraftAll and not bCanCraftAll then
		return true
	elseif not aCanCraftAll and bCanCraftAll then
		return false
	end
	local aCanCraftSome = aNumCraftable > 0
	local bCanCraftSome = bNumCraftable > 0
	if aCanCraftSome and not bCanCraftSome then
		return true
	elseif not aCanCraftSome and bCanCraftSome then
		return false
	end
	local aProfit = self._profit[a]
	local bProfit = self._profit[b]
	if aProfit and not bProfit then
		return true
	elseif not aProfit and bProfit then
		return false
	end
	if aProfit ~= bProfit then
		return aProfit > bProfit
	end
	return aRecipeString < bRecipeString
end
