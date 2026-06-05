-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local MatString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatString")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local RecipeString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.RecipeString")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local private = {
	optionalMatsTemp = {},
}
local MAX_NUM_OPTIONAL_MATS = 5
local MAX_NUM_FINISHING_MATS = 3



-- ============================================================================
-- Element Definition
-- ============================================================================

local OptionalMatsRow = UIElements.Define("OptionalMatsRow", "Frame")
OptionalMatsRow:_ExtendStateSchema()
	:AddOptionalStringField("recipeString")
	:AddOptionalStringField("craftString")
	:AddNumberField("numOptionalMats", 0)
	:AddNumberField("numFinishingMats", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OptionalMatsRow:__init(frame)
	self.__super:__init(frame)
	self._onRecipeStringChanged = nil
end

function OptionalMatsRow:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	self:SetPadding(0, 0, 2, 2)
	self:SetRoundedBackgroundColor("FRAME_BG")

	-- Set up some computed state properties
	self._state:PublisherForKeyChange("recipeString")
		:MapNonNilWithFunction(CraftString.FromRecipeString)
		:AssignToTableKey(self._state, "craftString")
	self._state:PublisherForKeyChange("craftString")
		:MapNonNilWithFunction(Profession.GetNumOptionalMats, MatString.TYPE.OPTIONAL)
		:MapNilToValue(0)
		:AssignToTableKey(self._state, "numOptionalMats")
	self._state:PublisherForKeyChange("craftString")
		:MapNonNilWithFunction(Profession.GetNumOptionalMats, MatString.TYPE.FINISHING)
		:MapNilToValue(0)
		:AssignToTableKey(self._state, "numFinishingMats")

	-- Show/hide this row based on whether or not a recipe string is set
	self._state:PublisherForExpression([[numOptionalMats + numFinishingMats > 0]])
		:CallMethod(self, "SetShown")

	-- Add optional mats
	local optionalLabel = UIElements.New("Text", "optionalLabel")
		:SetWidth("AUTO")
		:SetMargin(8, 0, 0, 0)
		:SetFont("BODY_BODY3_MEDIUM")
		:SetText(LibTSMUI.IsRetail() and PROFESSIONS_OPTIONAL_REAGENT_CONTAINER_LABEL or "")
	self:AddChild(optionalLabel)
	self._state:PublisherForKeyChange("numOptionalMats")
		:MapBooleanNotEquals(0)
		:CallMethod(optionalLabel, "SetShown")
	for i = 1, MAX_NUM_OPTIONAL_MATS do
		local itemSelector = UIElements.New("ItemSelector", "optionalMat"..i)
			:SetSize(24, 24)
			:SetMargin(4, i == MAX_NUM_OPTIONAL_MATS and 4 or 0, 0, 0)
			:SetOptionalMatInfo(MatString.TYPE.OPTIONAL, i)
			:SetScript("OnSelectionChanged", self:__closure("_HandleItemSelectionChanged"))
		self:AddChild(itemSelector)
		self._state:PublisherForKeyChange("numOptionalMats")
			:MapBooleanGreaterThanOrEquals(i)
			:CallMethod(itemSelector, "SetShown")
		self._state:PublisherForKeyChange("recipeString")
			:IgnoreNil()
			:CallMethod(itemSelector, "SetOptionalMatRecipeString")
	end

	-- Add finishing mats
	local finishingLabel = UIElements.New("Text", "finishingLabel")
		:SetWidth("AUTO")
		:SetMargin(8, 0, 0, 0)
		:SetFont("BODY_BODY3_MEDIUM")
		:SetText(LibTSMUI.IsRetail() and PROFESSIONS_CRAFTING_FINISHING_HEADER or "")
	self:AddChild(finishingLabel)
	self._state:PublisherForKeyChange("numFinishingMats")
		:MapBooleanNotEquals(0)
		:CallMethod(finishingLabel, "SetShown")
	for i = 1, MAX_NUM_FINISHING_MATS do
		local itemSelector = UIElements.New("ItemSelector", "finishingMat"..i)
			:SetSize(24, 24)
			:SetMargin(4, i == MAX_NUM_FINISHING_MATS and 4 or 0, 0, 0)
			:SetOptionalMatInfo(MatString.TYPE.FINISHING, i)
			:SetScript("OnSelectionChanged", self:__closure("_HandleItemSelectionChanged"))
		self:AddChild(itemSelector)
		self._state:PublisherForKeyChange("numFinishingMats")
			:MapBooleanGreaterThanOrEquals(i)
			:CallMethod(itemSelector, "SetShown")
		self._state:PublisherForKeyChange("recipeString")
			:IgnoreNil()
			:CallMethod(itemSelector, "SetOptionalMatRecipeString")
	end

	self:AddChild(UIElements.New("Spacer", "spacer"))
end

function OptionalMatsRow:Release()
	self._onRecipeStringChanged = nil
	self.__super:Release()
end

---Sets the recipe string.
---@param recipeString string The recipe string
---@return OptionalMatsRow
function OptionalMatsRow:SetRecipeString(recipeString)
	self._state.recipeString = recipeString
	return self
end

---Registers a script handler.
---@param script "OnRecipeStringChanged"
---@param handler fun(optionalMatsRow: OptionalMatsRow, ...: any) The handler
---@return OptionalMatsRow
function OptionalMatsRow:SetScript(script, handler)
	if script == "OnRecipeStringChanged" then
		self._onRecipeStringChanged = handler
	else
		error("Invalid script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param itemSelector ItemSelector
function OptionalMatsRow.__private:_HandleItemSelectionChanged(itemSelector, itemString)
	local matString = itemSelector:GetMatString()
	if not matString then
		return
	end
	local slotId = MatString.GetSlotId(matString)
	assert(slotId)

	local recipeString = self._state.recipeString
	assert(recipeString)
	assert(not next(private.optionalMatsTemp))
	if itemString then
		local itemId = ItemString.ToId(itemString)
		for _, existingSlotId, existingItemId in RecipeString.OptionalMatIterator(recipeString) do
			-- Remove this item from any existing slots its in
			if existingItemId ~= itemId then
				private.optionalMatsTemp[existingSlotId] = existingItemId
			end
		end
		private.optionalMatsTemp[slotId] = itemId
	else
		for _, existingSlotId, existingItemId in RecipeString.OptionalMatIterator(recipeString) do
			if existingSlotId ~= slotId then
				private.optionalMatsTemp[existingSlotId] = existingItemId
			end
		end
	end
	recipeString = RecipeString.SetOptionalMats(recipeString, private.optionalMatsTemp)
	wipe(private.optionalMatsTemp)
	if recipeString == self._state.recipeString then
		return
	end
	self._state.recipeString = recipeString
	self:_onRecipeStringChanged(self._state.recipeString)
end
