-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local CraftingUIUtils = LibTSMUI:Include("Crafting.CraftingUIUtils")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local MatString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.RecipeString")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
	matsTemp = {},
	qualityMatsTemp = {},
	optionalMatsTemp = {},
	rankDropdownTemp = {},
}
local MAX_CRAFT_RANK = 3
local MAX_CRAFT_LEVEL = 4
local MAX_CRAFT_QUALITY = 5
local CRAFT_TYPE_BUTTON_TEXT_MAP = {
	ITEM = L["Craft"],
	RESEARCH = L["Craft"],
	ENCHANT = L["Enchant"],
	ENCHANT_VELLUM = L["Enchant"],
	SALVAGE = L["Salvage"],
	TINKER = L["Tinker"],
	NONE = "",
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftDetails = UIElements.Define("CraftDetails", "Frame")
CraftDetails:_ExtendStateSchema()
	:AddOptionalStringField("craftString")
	:AddOptionalStringField("recipeString")
	:AddNumberField("numCraftable", 0)
	:AddBooleanField("hasVellum", false)
	:AddOptionalStringField("neededTools")
	:AddOptionalNumberField("remainingCooldown")
	:AddOptionalEnumField("craftingSource", CraftingUIUtils.CRAFTING_SOURCE)
	:AddBooleanField("canCraft", false)
	:AddStringField("craftType", "NONE")
	:AddOptionalNumberField("craftingCost")
	:AddOptionalNumberField("concentration")
	:Commit()
CraftDetails:_AddActionScripts("OnQueueButtonClick", "OnCraftButtonMouseDown", "OnCraftButtonClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftDetails:__init(frame)
	self.__super:__init(frame)
	self._craftableQuantityFunc = nil
	self._qualityCraftingOptionalMatsFunc = nil
	self._craftStringCostsFunc = nil
	BagTracking.RegisterCallback(self:__closure("_HandleCraftableUpdate"))
end

function CraftDetails:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(4)
	self:SetBorderColor("ACTIVE_BG", 1)
	self:SetRoundedBackgroundColor("PRIMARY_BG")
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(28)
		:SetPadding(0, 0, 0, 4)
		:AddChild(UIElements.New("Button", "icon")
			:SetSize(20, 20)
			:SetMargin(8, 4, 0, 0)
			:SetScript("OnClick", self:__closure("_HandleItemClick"))
		)
		:AddChild(UIElements.New("Button", "name")
			:SetHeight(24)
			:SetWidth("AUTO")
			:SetFont("ITEM_BODY1")
			:SetJustifyH("LEFT")
			:SetScript("OnClick", self:__closure("_HandleItemClick"))
		)
		:AddChild(UIElements.New("Text", "craftNum")
			:SetMargin(4, 0, 0, 0)
			:SetWidth("AUTO")
			:SetFont("ITEM_BODY1")
			:SetTextColor("INDICATOR")
			:SetJustifyH("LEFT")
		)
		:AddChild(UIElements.New("Button", "qualityBtn")
			:SetWidth("AUTO")
			:SetHeight(20)
			:SetMargin(4, 0, 0, 0)
			:SetBackground("FRAME_BG")
			:SetScript("OnClick", self:__closure("_HandleQualityBtnClick"))
		)
		:AddChild(UIElements.New("ListDropdown", "rankDropdown")
			:SetSize(80, 20)
			:SetMargin(12, 0, 0, 0)
			:SetScript("OnSelectionChanged", self:__closure("_HandleRankDropdownSelectionChanged"))
		)
		:AddChild(UIElements.New("Text", "rankText")
			:SetWidth("AUTO")
			:SetMargin(12, 0, 0, 0)
		)
		:AddChild(UIElements.New("VerticalLine", "line1")
			:SetMargin(12, 12, 2, 2)
		)
		:AddChild(UIElements.New("Text", "craftingCostLabel")
			:SetWidth("AUTO")
			:SetMargin(0, 4, 0, 0)
			:SetFont("BODY_BODY3")
			:SetText(L["Crafting Cost"]..":")
		)
		:AddChild(UIElements.New("Text", "craftingCostText")
			:SetWidth("AUTO")
			:SetMargin(0, 0, 0, 0)
			:SetFont("TABLE_TABLE1")
		)
		:AddChild(UIElements.New("VerticalLine", "line2")
			:SetMargin(12, 12, 2, 2)
		)
		:AddChild(UIElements.New("Text", "error")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY3_MEDIUM")
			:SetTextColor("FEEDBACK_RED")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
	)
	self:AddChild(UIElements.New("HorizontalLine", "line"))
	self:AddChild(UIElements.New("Frame", "content")
		:SetLayout("HORIZONTAL")
		:AddChild(UIElements.New("Frame", "left")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("Frame", "selection")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("Text", "description")
					:SetSize("AUTO", 32)
					:SetMargin(8, 8, 4, 0)
					:SetFont("BODY_BODY3")
				)
				:AddChild(UIElements.New("Frame", "content")
					:SetLayout("HORIZONTAL")
					:SetHeight(50)
					:SetMargin(8, 12, 4, 4)
					:AddChild(UIElements.New("ItemSelector", "itemSelector")
						:SetSize(32, 32)
						:SetScript("OnSelectionChanged", self:__closure("_HandleItemSelectionChanged"))
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "mats")
				:SetLayout("VERTICAL")
				:SetMargin(4, 8, 4, 4)
				:AddChild(UIElements.New("CraftingMatList", "matList")
					:SetScript("OnMatQualityChanged", self:__closure("_HandleDialogRecipeStringChanged"))
				)
				:AddChild(UIElements.New("OptionalMatsRow", "optionalMats")
					:SetHeight(32)
					:SetMargin(0, 0, 4, 0)
					:SetScript("OnRecipeStringChanged", self:__closure("_HandleDialogRecipeStringChanged"))
				)
			)
		)
		:AddChild(UIElements.New("Frame", "buttons")
			:SetLayout("VERTICAL")
			:SetWidth(230)
			:SetMargin(8, 4, 4, 4)
			:AddChild(UIElements.New("Frame", "quantity")
				:SetLayout("HORIZONTAL")
				:AddChild(UIElements.New("ActionButton", "decrease")
					:SetWidth("AUTO")
					:SetMargin(0, 4, 0, 0)
					:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey("iconPack.18x18/Caret/Right")))
					:DisableClickCooldown()
					:SetScript("OnClick", private.QuantityDecreaseOnClick)
				)
				:AddChild(UIElements.New("Input", "input")
					:SetMargin(0, 4, 0, 0)
					:SetBackgroundColor("FRAME_BG")
					:SetFont("BODY_BODY2_BOLD")
					:SetJustifyH("CENTER")
					:SetValidateFunc("NUMBER", "1:9999")
					:SetValue(1)
				)
				:AddChild(UIElements.New("ActionButton", "increase")
					:SetWidth("AUTO")
					:SetMargin(0, 4, 0, 0)
					:SetText(TextureAtlas.GetTextureLink("iconPack.18x18/Caret/Right"))
					:DisableClickCooldown()
					:SetScript("OnClick", private.QuantityIncreaseOnClick)
				)
				:AddChild(UIElements.New("ActionButton", "maxBtn")
					:SetWidth("AUTO")
					:SetPadding(4, 4, 0, 0)
					:SetFont("BODY_BODY2_BOLD")
					:SetText(L["MAX"])
					:DisableClickCooldown()
					:SetScript("OnClick", self:__closure("_HandleMaxBtnOnClick"))
				)
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetMargin(0, 0, 6, 6)
				:AddChild(UIElements.New("ActionButton", "craftBtn")
					:SetWidth(80)
					:SetMargin(0, 6, 0, 0)
					:SetText(L["Craft"])
					:SetScript("OnMouseDown", self:__closure("_HandleCraftButtonMouseDown"))
					:SetScript("OnClick", self:__closure("_HandleCraftButtonClick"))
				)
				:AddChild(UIElements.New("ActionButton", "craftVellumBtn")
					:SetWidth(144)
					:SetMargin(0, 0, 0, 0)
					:SetText(L["Craft Vellum"])
					:SetScript("OnMouseDown", self:__closure("_HandleCraftButtonMouseDown"))
					:SetScript("OnClick", self:__closure("_HandleCraftButtonClick"))
				)
			)
			:AddChild(UIElements.New("ActionButton", "queueBtn")
				:SetText(L["Queue"])
				:DisableClickCooldown()
				:SetScript("OnClick", self:__closure("_HandleQueueButtonClick"))
			)
		)
	)
	self:GetElement("content.left.mats.optionalMats"):Hide()
	local buttons = self:GetElement("content.buttons")

	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToNeededTools)
		:AssignToTableKey(self._state, "neededTools")
	self._state:PublisherForExpression([[not neededTools and not remainingCooldown and numCraftable > 0 and craftingSource == nil]])
		:AssignToTableKey(self._state, "canCraft")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToCraftType)
		:AssignToTableKey(self._state, "craftType")
	self._state:PublisherForKeyChange("craftString")
		:MapNonNilWithFunction(Profession.GetRemainingCooldown)
		:AssignToTableKey(self._state, "remainingCooldown")

	self._state:PublisherForKeys("craftString", "neededTools", "remainingCooldown", "numCraftable")
		:MapWithFunction(private.StateToErrStr)
		:IgnoreDuplicates()
		:CallFunction(self:__closure("_SetErrorText"))

	local craftBtn = buttons:GetElement("content.craftBtn")
	self._state:PublisherForKeyChange("craftType")
		:MapWithLookupTable(CRAFT_TYPE_BUTTON_TEXT_MAP)
		:CallMethod(craftBtn, "SetText")
	self._state:PublisherForKeyChange("craftType")
		:MapBooleanEquals("ENCHANT_VELLUM")
		:MapBooleanWithValues(80, 230)
		:CallMethod(craftBtn, "SetWidth")
	self._state:PublisherForKeyChange("canCraft")
		:Share(2)
		:CallFunction(self:__closure("_UpdateClassicCraftingButton"))
		:InvertBoolean()
		:CallMethod(craftBtn, "SetDisabled")
	self._state:PublisherForKeyChange("craftingSource")
		:MapBooleanEquals(CraftingUIUtils.CRAFTING_SOURCE.CRAFT)
		:CallMethod(craftBtn, "SetPressed")

	self._state:PublisherForExpression([[craftType ~= "ENCHANT_VELLUM" and craftType ~= "ITEM"]])
		:CallMethod(buttons:GetElement("queueBtn"), "SetDisabled")
	self._state:PublisherForExpression(LibTSMUI.IsRetail() and [[craftType ~= "ITEM" and craftType ~= "SALVAGE" and craftType ~= "ENCHANT_VELLUM"]] or [[craftType ~= "ITEM" and craftType ~= "SALVAGE"]])
		:Share(4)
		:CallMethod(buttons:GetElement("quantity.decrease"), "SetDisabled")
		:CallMethod(buttons:GetElement("quantity.input"), "SetDisabled")
		:CallMethod(buttons:GetElement("quantity.increase"), "SetDisabled")
		:CallMethod(buttons:GetElement("quantity.maxBtn"), "SetDisabled")

	local craftVellumBtn = buttons:GetElement("content.craftVellumBtn")
	self._state:PublisherForExpression([[craftType ~= "ENCHANT_VELLUM" or not canCraft or not hasVellum]])
		:CallMethod(craftVellumBtn, "SetDisabled")
	self._state:PublisherForKeyChange("craftType")
		:MapBooleanEquals("ENCHANT_VELLUM")
		:CallMethod(craftVellumBtn, "SetShown")
	self._state:PublisherForKeyChange("craftingSource")
		:MapBooleanEquals(CraftingUIUtils.CRAFTING_SOURCE.VELLUM)
		:CallMethod(craftVellumBtn, "SetPressed")

	self._state:PublisherForKeyChange("craftingCost")
		:MapWithFunction(private.CraftingCostToText)
		:CallFunction(self:__closure("_SetCraftingCostText"))

	local craftNum = self:GetElement("header.craftNum")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToCraftNumText)
		:CallMethod(craftNum, "SetText")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToCraftNumShown)
		:CallMethod(craftNum, "SetShown")

	local rankText = self:GetElement("header.rankText")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToRankText)
		:CallMethod(rankText, "SetText")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToRankTextShown)
		:CallMethod(rankText, "SetShown")

	self._state:PublisherForKeyChange("recipeString")
		:CallMethod(self:GetElement("content.left.mats.optionalMats"), "SetRecipeString")

	self._state:PublisherForKeyChange("recipeString")
		:CallMethod(self:GetElement("content.left.mats.matList"), "SetRecipeString")

	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToMatsShown)
		:CallMethod(self:GetElement("content.left.mats"), "SetShown")

	self._state:PublisherForKeyChange("craftType")
		:MapBooleanEquals("SALVAGE")
		:CallMethod(self:GetElement("content.left.selection"), "SetShown")

	self._state:PublisherForKeyChange("recipeString")
		:CallFunction(self:__closure("_HandleCraftableUpdate"))

	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(Profession.GetRecipeDescription)
		:CallMethod(self:GetElement("content.left.selection.description"), "SetText")

	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToRankDropdownShown)
		:CallMethod(self:GetElement("header.rankDropdown"), "SetShown")

	local icon = self:GetElement("header.icon")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToIconBackground)
		:CallMethod(icon, "SetBackground")
	self._state:PublisherForKeyChange("recipeString")
		:MapWithFunction(private.RecipeStringToResultTooltip)
		:CallMethod(icon, "SetTooltip")
	self._state:PublisherForKeyChange("craftString")
		:MapToBoolean()
		:CallMethod(icon, "SetShown")

	local name = self:GetElement("header.name")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToNameText)
		:CallMethod(name, "SetText")
	self._state:PublisherForKeyChange("recipeString")
		:MapWithFunction(private.RecipeStringToResultTooltip)
		:CallMethod(name, "SetTooltip")

	local qualityBtn = self:GetElement("header.qualityBtn")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToQualityBtnText)
		:CallMethod(qualityBtn, "SetText")
	self._state:PublisherForKeyChange("craftString")
		:MapWithFunction(private.CraftStringToQualityBtnShown)
		:CallMethod(qualityBtn, "SetShown")
end

function CraftDetails:Release()
	self._craftableQuantityFunc = nil
	self._hasVellumFunc = nil
	self._qualityCraftingOptionalMatsFunc = nil
	self._craftStringCostsFunc = nil
	self.__super:Release()
end

---Sets the craftable quantity function.
---@param func fun(recipeString: string): number Function which gets the craftable quantity
---@return CraftDetails
function CraftDetails:SetCraftableQuantityFunction(func)
	assert(func and not self._craftableQuantityFunc)
	self._craftableQuantityFunc = func
	return self
end

function CraftDetails:SetHasVellumFunction(func)
	assert(func and not self._hasVellumFunc)
	self._hasVellumFunc = func
	self._state:PublisherForKeyChange("recipeString")
		:MapWithFunction(private.RecipeStringToHasVellum, func)
		:AssignToTableKey(self._state, "hasVellum")
	return self
end

---Sets the quality crafting optional mats function.
---@param func fun(craftString: string, mats, optionalMats): boolean Function which gets the quality crafting optional mats
---@return CraftDetails
function CraftDetails:SetQualityCraftingMatsFunction(func)
	assert(func and not self._qualityCraftingOptionalMatsFunc)
	self._qualityCraftingOptionalMatsFunc = func
	return self
end

---Sets the crafting costs function.
---@param recipeStringFunc fun(recipeString: string): number?, number?, number? Function which calculates the crafting cost, crafted item value, and profit for a recipe string
---@param craftStringFunc fun(craftString: string): number?, number?, number? Function which calculates the crafting cost, crafted item value, and profit for a craft string
---@return CraftDetails
function CraftDetails:SetCostsFunctions(recipeStringFunc, craftStringFunc)
	assert(recipeStringFunc and craftStringFunc and not self._craftStringCostsFunc)
	self._craftStringCostsFunc = craftStringFunc
	self._state:PublisherForKeyChange("recipeString")
		:MapWithFunction(private.RecipeStringToCraftingCost, recipeStringFunc)
		:AssignToTableKey(self._state, "craftingCost")
	return self
end

---Sets the selected recipe's spell ID.
---@param spellId? number The spellId
---@return CraftDetails
function CraftDetails:SetSpellId(spellId)
	local dropdown = self:GetElement("header.rankDropdown")
	assert(#private.rankDropdownTemp == 0)
	local knownRank, lowestQuality = nil, nil
	if spellId then
		for i = 1, MAX_CRAFT_RANK do
			if Profession.GetIndexByCraftString(CraftString.Get(spellId, i)) then
				knownRank = i
				break
			end
		end
		for i = 1, MAX_CRAFT_LEVEL do
			if Profession.GetIndexByCraftString(CraftString.Get(spellId, nil, i)) then
				tinsert(private.rankDropdownTemp, format(L["Rank %d"], i))
			else
				break
			end
		end
		for i = 1, MAX_CRAFT_QUALITY do
			if Profession.GetIndexByCraftString(CraftString.Get(spellId, nil, nil, i)) then
				lowestQuality = i
				break
			end
		end
	end
	local highestLevel = #private.rankDropdownTemp
	highestLevel = highestLevel > 0 and highestLevel or nil
	local craftString = spellId and CraftString.Get(spellId, knownRank, highestLevel, lowestQuality) or nil
	dropdown:SetItems(private.rankDropdownTemp)
	dropdown:SetSelectedItem(private.rankDropdownTemp[highestLevel], true)
	wipe(private.rankDropdownTemp)

	local changed = craftString ~= self._state.craftString
	self._state.craftString = craftString
	if TradeSkill.IsClassicCrafting() then
		TradeSkill.SelectCraft(craftString and Profession.GetIndexByCraftString(craftString) or 0)
	end
	self:_UpdateRecipeString(changed)
	self:Draw()
	return self
end

---Subscribes to a publisher to set the spell ID.
---@param publisher ReactivePublisher The publisher
---@return CraftDetails
function CraftDetails:SetSpellIdPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetSpellId"))
	return self
end

---Subscribes to a publisher to set the type of the in progress craft.
---@param publisher ReactivePublisher The publisher
---@return CraftDetails
function CraftDetails:SetCraftingSourcePublisher(publisher)
	self:AddCancellable(publisher:AssignToTableKey(self._state, "craftingSource"))
	return self
end

---Sets the quantity currently being crafted.
---@param craftingQuantity number The number being crafted
function CraftDetails:SetCraftingQuantity(craftingQuantity)
	self:GetElement("content.buttons.quantity.input")
		:SetValue(craftingQuantity)
		:Draw()
end

---Subscribes to a publisher to set the quantity currently being crafted.
---@param publisher ReactivePublisher The publisher
---@return CraftDetails
function CraftDetails:SetCraftingQuantityPublisher(publisher)
	self:AddCancellable(publisher
		:IgnoreNil()
		:CallMethod(self, "SetCraftingQuantity")
	)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftDetails.__private:_HandleCraftableUpdate()
	if not self._acquired or not self._state.recipeString then
		return
	end

	if Profession.IsSalvage(self._state.craftString) then
		local matString = Profession.GetOptionalMatString(self._state.craftString, 1)
		local requiredQty = Profession.GetCraftedQuantityRange(self._state.craftString)
		self:GetElement("content.left.selection.content.itemSelector")
			:SetMatString(matString, requiredQty)

		local qualityCraftable, salvageCraftable = self:_GetSalvageCraftNum()
		self._state.numCraftable = qualityCraftable

		if salvageCraftable == 0 and qualityCraftable == 0 then
			self:GetElement("content.left.selection.content.itemSelector")
				:SetSelection(nil)
		end
	else
		self._state.numCraftable = self._craftableQuantityFunc(self._state.recipeString)
	end

	self._state.neededTools = private.CraftStringToNeededTools(self._state.craftString)
	self._state.hasVellum = self._hasVellumFunc(self._state.recipeString)
end

function CraftDetails.__private:_UpdateRecipeString(wipeExisting)
	if not self._state.craftString then
		self._state.recipeString = nil
		return
	end
	assert(not next(private.optionalMatsTemp))
	if self._state.recipeString and not wipeExisting then
		-- Ensure the existing optional mats are valid for the selected recipe and can be used with the selected craft level
		for _, slotId, itemId in RecipeString.OptionalMatIterator(self._state.recipeString) do
			if Profession.IsValidOptionalMat(self._state.craftString, slotId, itemId) then
				private.optionalMatsTemp[slotId] = itemId
			end
		end
	end

	-- Clear the salvage Item Selector
	self:GetElement("content.left.selection.content.itemSelector")
		:SetSelection(nil)
	-- Populate the quality mats
	assert(not next(private.matsTemp) and not next(private.qualityMatsTemp))
	for _, matString, quantity in Profession.MatIterator(self._state.craftString) do
		private.matsTemp[matString] = quantity
	end
	if not self._qualityCraftingOptionalMatsFunc(self._state.craftString, private.matsTemp, private.qualityMatsTemp) then
		wipe(private.qualityMatsTemp)
	end
	for _, matString in Profession.MatIterator(self._state.craftString) do
		local matType = MatString.GetType(matString)
		if matType == MatString.TYPE.QUALITY then
			local slotId = MatString.GetSlotId(matString)
			local qualityMatItemString = Table.KeyByValue(private.qualityMatsTemp, matString)
			private.optionalMatsTemp[slotId] = private.optionalMatsTemp[slotId] or ItemString.ToId(qualityMatItemString or MatString.GetQualityItem(matString, 1))
		elseif matType == MatString.TYPE.REQUIRED and not Profession.IsSalvage(self._state.craftString) then
			local slotId = MatString.GetSlotId(matString)
			private.optionalMatsTemp[slotId] = private.optionalMatsTemp[slotId] or ItemString.ToId(MatString.GetRequiredItem(matString, 1))
		end
	end
	wipe(private.matsTemp)
	wipe(private.qualityMatsTemp)

	self._state.recipeString = RecipeString.FromCraftString(self._state.craftString, private.optionalMatsTemp, self._state.concentration)
	wipe(private.optionalMatsTemp)
end

function CraftDetails.__private:_GetQuantityValue()
	return max(tonumber(self:GetElement("content.buttons.quantity.input"):GetValue()), 1)
end

function CraftDetails.__private:_HandleQualityBtnClick()
	self:GetBaseElement():ShowDialogFrame(UIElements.New("CraftTierDialog", "dialog")
		:SetCraftString(self._state.craftString, self._craftStringCostsFunc)
		:SetScript("OnQualityChanged", self:__closure("_HandleQualityChanged"))
	)
end

function CraftDetails.__private:_HandleQualityChanged(_, craftString, concentration)
	self._state.concentration = concentration
	self._state.craftString = craftString
	self:_UpdateRecipeString(true)
	self:GetElement("header"):Draw()
end

function CraftDetails.__private:_HandleRankDropdownSelectionChanged(dropdown)
	local level = dropdown:GetSelectedItemIndex()
	if not level then
		return
	end
	self._state.craftString = CraftString.SetLevel(self._state.craftString, dropdown:GetSelectedItemIndex())
	self:_UpdateRecipeString()
end

function CraftDetails.__private:_HandleQueueButtonClick()
	self:_SendActionScript("OnQueueButtonClick", self._state.recipeString, self:_GetQuantityValue())
end

function CraftDetails.__private:_HandleItemSelectionChanged(itemSelector)
	if not self._acquired or not self._state.recipeString then
		return
	end
	self._state.neededTools = private.CraftStringToNeededTools(self._state.craftString)
	self._state.numCraftable = Profession.IsSalvage(self._state.craftString) and self:_GetSalvageCraftNum() or self._craftableQuantityFunc(self._state.recipeString)
	self._state.hasVellum = self._hasVellumFunc(self._state.recipeString)
end

function CraftDetails.__private:_GetSalvageCraftNum()
	local slotId = self:GetElement("content.left.selection.content.itemSelector"):GetNextSalvageSlotId()
	if not slotId then
		return 0, 0
	end
	local requiredQty = Profession.GetCraftedQuantityRange(self._state.craftString)
	local craftable = floor(BagTracking.GetQuantityBySlotId(slotId) / requiredQty)
	local _, _, hasQualityMats = Profession.GetRecipeQualityInfo(self._state.craftString)
	if hasQualityMats then
		local qualityCraftable = min(craftable, self._craftableQuantityFunc(self._state.recipeString))
		if qualityCraftable > 0 then
			self:GetElement("content.buttons.quantity.input")
				:SetValue(qualityCraftable)
				:Draw()
		end
		return qualityCraftable, craftable
	else
		if craftable > 0 then
			self:GetElement("content.buttons.quantity.input")
				:SetValue(craftable)
				:Draw()
		end
		return craftable, 0
	end
end

function CraftDetails.__private:_HandleCraftButtonMouseDown(button)
	local isVellum = button == self:GetElement("content.buttons.content.craftVellumBtn")
	self:_SendActionScript("OnCraftButtonMouseDown", self._state.recipeString, self:_GetQuantityValue(), isVellum, self:GetElement("content.left.selection.content.itemSelector"):GetNextSalvageSlotId())
end

function CraftDetails.__private:_HandleCraftButtonClick(button)
	button:SetPressed(true)
	button:Draw()
	local isVellum = button == self:GetElement("content.buttons.content.craftVellumBtn")
	self:_SendActionScript("OnCraftButtonClick", self._state.recipeString, self:_GetQuantityValue(), isVellum, self:GetElement("content.left.selection.content.itemSelector"):GetNextSalvageSlotId())
end

function CraftDetails.__private:_HandleDialogRecipeStringChanged(_, recipeString)
	self._state.recipeString = recipeString
end

function CraftDetails.__private:_HandleMaxBtnOnClick(button)
	local numCraftable = Profession.IsSalvage(self._state.craftString) and self:_GetSalvageCraftNum() or self._craftableQuantityFunc(self._state.recipeString)
	if numCraftable < 1 then
		return
	end
	button:GetElement("__parent.input")
		:SetValue(numCraftable)
		:Draw()
end

function CraftDetails.__private:_HandleItemClick()
	local itemString = Profession.GetResultInfo(self._state.craftString)
	if itemString then
		UIUtils.HandleModifiedItemClick(itemString)
	end
end

function CraftDetails.__private:_SetCraftingCostText(text)
	self:GetElement("header.craftingCostText"):SetText(text)
	self:GetElement("header"):Draw()
end

function CraftDetails.__private:_SetErrorText(text)
	self:GetElement("header.error"):SetText(text)
	self:GetElement("header"):Draw()
end

function CraftDetails.__private:_UpdateClassicCraftingButton(canCraft)
	if not TradeSkill.IsClassicCrafting() or not CraftCreateButton then
		return
	end
	local craftBtnBaseFrame = self:GetElement("content.buttons.content.craftBtn"):_GetBaseFrame()
	CraftCreateButton:SetParent(craftBtnBaseFrame)
	CraftCreateButton:ClearAllPoints()
	CraftCreateButton:SetAllPoints(craftBtnBaseFrame)
	CraftCreateButton:SetFrameLevel(200)
	CraftCreateButton:DisableDrawLayer("BACKGROUND")
	CraftCreateButton:DisableDrawLayer("ARTWORK")
	if canCraft then
		CraftCreateButton:Enable()
	else
		CraftCreateButton:Disable()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.QuantityDecreaseOnClick(button)
	local input = button:GetElement("__parent.input")
	input:Subtract()
end

function private.QuantityIncreaseOnClick(button)
	local input = button:GetElement("__parent.input")
	input:Add()
end

function private.StateToErrStr(state)
	if not state.craftString then
		return L["No recipe selected"]
	elseif state.neededTools then
		return REQUIRES_LABEL.." "..state.neededTools
	elseif state.remainingCooldown then
		return format(L["On Cooldown for %s"], SecondsToTime(state.remainingCooldown))
	elseif state.numCraftable == 0 then
		return L["Missing Materials"]
	else
		return ""
	end
end

function private.CraftStringToNeededTools(craftString)
	return craftString and Profession.NeededTools(craftString) or nil
end

function private.CraftingCostToText(craftingCost)
	return craftingCost and Money.ToStringForUI(craftingCost) or "---"
end

function private.CraftStringToCraftNumText(craftString)
	if not craftString then
		return ""
	end
	local lNum, hNum = Profession.GetCraftedQuantityRange(craftString)
	return lNum == hNum and format("(%d)", lNum) or format("(%d-%d)", lNum, hNum)
end

function private.CraftStringToCraftNumShown(craftString)
	if not craftString then
		return false
	end
	local lNum, hNum = Profession.GetCraftedQuantityRange(craftString)
	return lNum ~= hNum or lNum >= 2
end

function private.CraftStringToRankText(craftString)
	local rank = craftString and CraftString.GetRank(craftString) or -1
	local level = craftString and CraftString.GetLevel(craftString) or -1
	assert(rank <= 0 or level <= 0)
	if rank > 0 then
		local filled = TextureAtlas.GetTextureLink("iconPack.14x14/Star/Filled")
		local unfilled = TextureAtlas.GetTextureLink("iconPack.14x14/Star/Unfilled")
		assert(rank >= 1 and rank <= 3)
		return strrep(filled, rank)..strrep(unfilled, 3 - rank)
	elseif level > 0 then
		local currExp = Profession.GetCurrentExpByCraftString(craftString)
		local nextExp = Profession.GetNextExpByCraftString(craftString)
		return currExp >= 0 and format("%s / %s", currExp, nextExp) or L["Max"]
	else
		return ""
	end
end

function private.CraftStringToRankTextShown(craftString)
	local rank = craftString and CraftString.GetRank(craftString) or -1
	local level = craftString and CraftString.GetLevel(craftString) or -1
	return rank > 0 or level > 0
end

function private.CraftStringToMatsShown(craftString)
	if not craftString then
		return false
	end
	if Profession.IsSalvage(craftString) then
		local _, _, hasQualityMats = Profession.GetRecipeQualityInfo(craftString)
		return hasQualityMats
	else
		return true
	end
end

function private.CraftStringToRankDropdownShown(craftString)
	local level = craftString and CraftString.GetLevel(craftString) or -1
	return level > 0
end

function private.RecipeStringToResultTooltip(recipeString)
	if not recipeString then
		return nil
	end
	local craftString = CraftString.FromRecipeString(recipeString)
	local itemString = Profession.GetResultInfo(craftString)
	if not itemString or itemString == "" then
		if TradeSkill.IsClassicCrafting() then
			return "craft:"..(Profession.GetIndexByCraftString(craftString) or craftString)
		else
			return recipeString
		end
	end

	local level = RecipeString.GetLevel(recipeString)
	local rank = RecipeString.GetRank(recipeString)
	if not level and not rank and not RecipeString.HasOptionalMats(recipeString) then
		return itemString
	elseif not level then
		return Profession.IsEnchant(craftString) and itemString or recipeString
	else
		return Profession.GenerateResultItemString(recipeString, itemString)
	end
end

function private.CraftStringToIconBackground(craftString)
	if not craftString then
		return nil
	end
	local _, texture = Profession.GetResultInfo(craftString)
	return texture
end

function private.CraftStringToNameText(craftString)
	if not craftString then
		return ""
	end
	local itemString, _, name = Profession.GetResultInfo(craftString)

	local itemName = ItemInfo.GetName(itemString)
	local quality = ItemInfo.GetQuality(itemString)
	if not itemName or not quality then
		return name
	end
	return Theme.GetItemQualityColor(quality):ColorText(itemName)
end

function private.CraftStringToQualityBtnText(craftString)
	if not craftString then
		return ""
	end
	local craftQuality = CraftString.GetQuality(craftString)
	local useMidnightIcon = TradeSkill.IsMidnightRecipe(CraftString.GetSpellId(craftString))
	if not craftQuality then
		return ""
	end
	return TradeSkill.GetCraftedQualityChatIcon(craftQuality, useMidnightIcon, true)..TextureAtlas.GetTextureLink("iconPack.18x18/Chevron/Down")
end

function private.CraftStringToQualityBtnShown(craftString)
	return craftString and CraftString.GetQuality(craftString) or false
end

function private.CraftStringToCraftType(craftString)
	if not craftString then
		return "NONE"
	elseif Profession.IsEnchant(craftString) then
		return (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and "ENCHANT" or "ENCHANT_VELLUM"
	elseif Profession.IsSalvage(craftString) then
		return "SALVAGE"
	elseif Profession.IsTinker(craftString) then
		return "TINKER"
	elseif not Profession.GetResultInfo(craftString) then
		return "RESEARCH"
	else
		return "ITEM"
	end
end

function private.RecipeStringToHasVellum(recipeString, func)
	return recipeString and func(recipeString) or false
end

function private.RecipeStringToCraftingCost(recipeString, func)
	if not recipeString then
		return nil
	end
	local cost = func(recipeString)
	return cost
end
