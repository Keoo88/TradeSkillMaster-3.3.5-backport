-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local MatString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.MatString")
local RecipeString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.RecipeString")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local Container = LibTSMUI:From("LibTSMWoW"):Include("API.Container")
local SlotId = LibTSMUI:From("LibTSMWoW"):Include("Type.SlotId")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local private = {}
local CORNER_RADIUS = 6



-- ============================================================================
-- Element Definition
-- ============================================================================

local ItemSelector = UIElements.Define("ItemSelector", "Button")
ItemSelector:_ExtendStateSchema()
	:AddBooleanField("disabled", false)
	:AddBooleanField("mouseOver", false)
	:AddOptionalStringField("selection")
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ItemSelector:__init(button)
	self.__super:__init(button)

	local frame = self:_GetBaseFrame()
	frame:TSMSetScript("OnMouseUp", self:__closure("_HandleMouseUp"))
	frame:TSMSetScript("OnEnter", self:__closure("_HandleFrameEnter"))
	frame:TSMSetScript("OnLeave", self:__closure("_HandleFrameLeave"))

	self._background = self:_CreateRectangle()
	self._background:SetCornerRadius(CORNER_RADIUS)
	self._backgroundOverlay = self:_CreateRectangle(1)
	self._backgroundOverlay:SetCornerRadius(CORNER_RADIUS)
	self._backgroundOverlay:SetInset(2)
	self._backgroundOverlay:SetColor("PRIMARY_BG_ALT")

	self._quality = self:_CreateFontString(frame)
	self._quality:SetSize(32, 32)
	self._quality:TSMSetFont("BODY_BODY1")
	self._quality:SetPoint("TOPLEFT", -2, 10)
	self._quality:SetJustifyH("LEFT")

	self._quantity = self:_CreateFontString(frame)
	self._quantity:SetHeight(16)
	self._quantity:TSMSetFont("TABLE_TABLE1_OUTLINE")
	self._quantity:SetPoint("BOTTOMLEFT", 1, 1)
	self._quantity:SetPoint("BOTTOMRIGHT", -1, 1)
	self._quantity:SetJustifyH("RIGHT")

	self._addIcon = self:_CreateTexture(frame, "ARTWORK")
	self._addIcon:SetPoint("BOTTOMRIGHT", -2, 2)
	self._addIcon:TSMSetTextureAndSize("iconPack.14x14/Add/Default")

	self._items = {}
	self._matString = nil
	self._optionalMatType = nil
	self._optionalMatIndex = nil
	self._selectionSlotId = nil
	self._requiredQty = nil
	self._onSelectionChanged = nil
end

function ItemSelector:Acquire()
	self.__super:Acquire()

	self:EnableRightClick()

	-- Set our own state
	self._state:PublisherForKeyChange("selection")
		:Share(2)
		:CallMethod(self, "SetTooltip")
		:CallMethod(self, "SetBackgroundWithItemHighlight")

	-- Set the background state
	self._state:PublisherForKeys("disabled", "mouseOver")
		:MapWithFunction(private.StateToBackgroundColorKey)
		:IgnoreDuplicates()
		:CallMethod(self._background, "SubscribeColor")

	self._state:PublisherForKeyChange("selection")
		:MapBooleanEquals(nil)
		:Share(3)
		:CallMethod(self._background, "SetShown")
		:CallMethod(self._backgroundOverlay, "SetShown")
		:CallMethod(self._addIcon, "SetShown")

	-- Set the quality state
	self._state:PublisherForKeyChange("selection")
		:MapWithFunction(private.SelectionToQualityText)
		:CallMethod(self._quality, "SetText")
end

function ItemSelector:Release()
	self.__super:Release()

	wipe(self._items)
	self._matString = nil
	self._optionalMatType = nil
	self._optionalMatIndex = nil
	self._selectionSlotId = nil
	self._requiredQty = nil
	self._onSelectionChanged = nil
end

---Sets the selectable items that can be picked.
---@param items string[] The indexed table that contains the possible selections
---@return ItemSelector
function ItemSelector:SetItems(items)
	wipe(self._items)
	self:SetDisabled(not next(items))
	for _, itemString in ipairs(items) do
		tinsert(self._items, itemString)
	end
	return self
end

---Sets the list of items from a mat string.
---@param matString? string The mat string
---@param requiredQuantity? number The required stack size for this mat
---@return ItemSelector
function ItemSelector:SetMatString(matString, requiredQty)
	wipe(self._items)
	self._matString = matString
	self._requiredQty = requiredQty
	if matString then
		for itemString in MatString.ItemIterator(matString) do
			if not requiredQty or private.GetBagSlotId(itemString, requiredQty) then
				tinsert(self._items, itemString)
			end
		end
	end
	self:SetDisabled(not next(self._items))
	self:SetSelection(self._state.selection, true)
	return self
end

---Sets optional mat info ahead of calling :SetOptionalMatRecipeString().
---@param matType EnumValue The optional mat type
---@param index number The optional mat index
---@return ItemSelector
function ItemSelector:SetOptionalMatInfo(matType, index)
	self._optionalMatType = matType
	self._optionalMatIndex = index
	return self
end

---Sets the recipe string for showing an optional material.
---@param recipeString string
function ItemSelector:SetOptionalMatRecipeString(recipeString)
	assert(self._optionalMatType and self._optionalMatIndex)
	local index = self._optionalMatIndex
	local craftString = CraftString.FromRecipeString(recipeString)
	local matString = nil
	for _, craftMatString in Profession.MatIterator(craftString) do
		if MatString.GetType(craftMatString) == self._optionalMatType then
			index = index - 1
			if index == 0 then
				matString = craftMatString
			end
		end
	end
	self._optionalMatString = matString
	self:SetMatString(matString)
	local itemId = matString and RecipeString.GetOptionalMat(recipeString, MatString.GetSlotId(matString))
	local itemString = itemId and "i:"..itemId or nil
	self:SetSelection(itemString)
	local slotText = matString and Profession.GetMatSlotText(craftString, matString) or ""
	self:SetTooltip(itemString or slotText ~= "" and slotText or nil)
end

---Gets the current mat string.
---@return string
function ItemSelector:GetMatString()
	return self._matString
end

---Get the currently selected item.
---@return The selected item
function ItemSelector:GetSelection()
	return self._state.selection
end

---Get the next targetable salvage slot id
---@return ItemLocation
function ItemSelector:GetNextSalvageSlotId()
	if not self._state.selection then
		return nil
	end
	return self:IsSelectionSlotValid() and self._selectionSlotId or private.GetBagSlotId(self._state.selection, self._requiredQty)
end

---Sets the current selection of the ItemSelector.
---@param selection? string The item to select or nil to clear the selection
---@return ItemSelector
function ItemSelector:SetSelection(selection, silent)
	self._state.selection = selection
	local slotId = self:IsSelectionSlotValid() and self._selectionSlotId or private.GetBagSlotId(self._state.selection, self._requiredQty)
	self._selectionSlotId = slotId
	self._quantity:SetText(slotId and BagTracking.GetQuantityBySlotId(slotId) or "")
	if not silent and self._onSelectionChanged then
		self:_onSelectionChanged(selection)
	end
	return self
end

---Set whether or not the item selector is disabled.
---@param disabled boolean Whether or not the item selector should be disabled
---@return ItemSelector
function ItemSelector:SetDisabled(disabled)
	self._state.disabled = disabled and true or false
	return self
end

---Registers a script handler.
---@param script "OnSelectionChanged"
---@param handler fun(itemSelector: ItemSelector, ...: any) The handler
---@return ItemSelector
function ItemSelector:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChanged = handler
	else
		self.__super:SetScript(script, handler)
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ItemSelector.__private:_HandleMouseUp(_, mouseButton)
	if not self._acquired or self._state.disabled then
		return
	end

	if mouseButton == "RightButton" then
		self:SetSelection(nil)
		Tooltip.Hide()
		return
	end

	self._opened = not self._opened
	if not self._opened then
		return
	end

	self:GetBaseElement():ShowDialogFrame(UIElements.New("Frame", "frame")
		:SetSize(130, 168)
		:SetLayout("VERTICAL")
		:SetPadding(2)
		:AddAnchor("TOPLEFT", self:_GetBaseFrame(), "TOPRIGHT", 4, 0)
		:SetRoundedBackgroundColor("FRAME_BG")
		:SetMouseEnabled(true)
		:SetScript("OnHide", self:__closure("_HandleFrameOnHide"))
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetStrata("HIGH")
			:SetRoundedBackgroundColor("ACTIVE_BG")
			:AddChild(UIElements.New("Text", "title")
				:SetMargin(18, 8, -4, 0)
				:SetFont("BODY_BODY3")
				:SetJustifyH("CENTER")
				:SetText(L["Item Selection"])
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetMargin(0, 2, -4, 0)
				:SetBackgroundAndSize("iconPack.14x14/Close/Default")
				:SetScript("OnClick", self:__closure("_HandleFrameOnHide"))
			)
		)
		:AddChild(UIElements.New("Frame", "scroll")
			:SetLayout("HORIZONTAL")
			:SetMargin(0, 0, -4, 0)
			:SetStrata("DIALOG")
			:SetHeight(144)
			:SetBackgroundColor("FRAME_BG")
			:AddChild(UIElements.New("ScrollFrame", "scroll")
				:SetPadding(12, 8, 4, 4)
				:AddChild(UIElements.New("Frame", "items")
					:SetLayout("FLOW")
					:AddChildrenWithFunction(self:__closure("_CreateItems"))
				)
			)
		)
	)
end

function ItemSelector.__private:_HandleFrameOnHide()
	self._opened = false
	self:GetBaseElement():HideDialog()
end

function ItemSelector.__private:_HandleFrameEnter()
	self._state.mouseOver = true
end

function ItemSelector.__private:_HandleFrameLeave()
	self._state.mouseOver = false
end

function ItemSelector.__private:_HandleButtonOnClick(button)
	self:SetSelection(button:GetContext())
	self:GetBaseElement():HideDialog()
end

function ItemSelector.__private:_CreateItems(frame)
	for _, itemString in ipairs(self._items) do
		local craftQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(itemString)
		frame:AddChild(UIElements.New("Frame", "content")
			:SetLayout("HORIZONTAL")
			:AddChild(UIElements.New("Button", itemString.."Icon")
				:SetSize(30, 30)
				:SetPadding(0, 0, 0, 0)
				:SetMargin(2, 2, 2, 2)
				:SetContext(itemString)
				:SetBackgroundWithItemHighlight(itemString)
				:SetTooltip(itemString)
				:SetScript("OnClick", self:__closure("_HandleButtonOnClick"))
			)
			:AddChildNoLayout(UIElements.New("Text", itemString.."Quality")
				:SetSize(30, 30)
				:AddAnchor("TOPLEFT", 0, 8)
				:SetShown(craftQuality and true or false)
				:SetText(craftQuality and TradeSkill.GetCraftedQualityChatIcon(craftQuality, useMidnightIcon) or "")
			)
		)
	end
end

function ItemSelector.__private:IsSelectionSlotValid()
	if not self._state.selection or not self._selectionSlotId then
		return false
	end
	if self._state.selection ~= ItemString.Get(Container.GetItemId(SlotId.Split(self._selectionSlotId))) then
		return false
	end
	local selectionQuantity = BagTracking.GetQuantityBySlotId(self._selectionSlotId)
	return TradeSkill.IsValiMatSlotId(self._selectionSlotId) and self._requiredQty and selectionQuantity and selectionQuantity >= self._requiredQty
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToBackgroundColorKey(state)
	if state.disabled then
		return "ACTIVE_BG"
	else
		if state.mouseOver then
			return "TEXT_ALT+HOVER"
		else
			return "TEXT_ALT"
		end
	end
end

function private.SelectionToQualityText(selection)
	if not selection then
		return ""
	end
	local itemQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(selection)
	if not itemQuality then
		return ""
	end
	return TradeSkill.GetCraftedQualityChatIcon(itemQuality, useMidnightIcon)
end

function private.GetBagSlotId(itemString, requiredQuantity)
	if not itemString or not requiredQuantity then
		return nil
	end
	return BagTracking.CreateQueryBagsBank()
		:Select("slotId")
		:GreaterThanOrEqual("quantity", requiredQuantity)
		:Equal("itemString", itemString)
		:OrderBy("quantity", false)
		:GetFirstResultAndRelease()
end
