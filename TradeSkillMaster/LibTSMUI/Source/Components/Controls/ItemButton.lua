-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local WarbankTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.WarbankTracking")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local private = {}
local CORNER_RADIUS = 2
local HIGHLIGHT_TEXTURE = 130718



-- ============================================================================
-- Element Definition
-- ============================================================================

local ItemButton = UIElements.Define("ItemButton", "Element")
ItemButton:_ExtendStateSchema()
	:AddOptionalStringField("itemString")
	:AddBooleanField("selected", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ItemButton:__init()
	local frame = self:_CreateButton()
	self.__super:__init(frame)

	BagTracking.RegisterQuantityCallback(self:__closure("_HandleBagUpdate"))
	WarbankTracking.RegisterQuantityCallback(self:__closure("_HandleBagUpdate"))

	self._highlight = self:_CreateTexture(frame, "HIGHLIGHT")
	self._highlight:SetAllPoints()
	self._highlight:TSMSetTextureAndCoord(HIGHLIGHT_TEXTURE)
	frame:SetHighlightTexture(self._highlight)

	self._background = self:_CreateRectangle()
	self._background:SetCornerRadius(CORNER_RADIUS)
	self._background:SetColor("INDICATOR")

	self._icon = self:_CreateTexture(frame, "ARTWORK")
	self._icon:SetPoint("TOPLEFT", frame, 1, -1)
	self._icon:SetPoint("BOTTOMRIGHT", frame, -1, 1)

	self._quality = self:_CreateFontString(frame)
	self._quality:SetSize(20, 20)
	self._quality:TSMSetFont("BODY_BODY2")
	self._quality:SetPoint("TOPLEFT", -2, 2)
	self._quality:SetJustifyH("LEFT")

	self._quantity = self:_CreateFontString(frame)
	self._quantity:SetHeight(16)
	self._quantity:TSMSetFont("TABLE_TABLE1_OUTLINE")
	self._quantity:SetPoint("BOTTOMLEFT", 1, 1)
	self._quantity:SetPoint("BOTTOMRIGHT", -1, 1)
	self._quantity:SetJustifyH("RIGHT")
end

function ItemButton:Acquire()
	self.__super:Acquire()
	self._icon:TSMSubscribeColorTexture("INDICATOR_ALT")

	-- Set the background state
	self._state:PublisherForKeyChange("selected")
		:CallMethod(self._background, "SetShown")

	-- Set the icon texture
	self._state:PublisherForKeyChange("itemString")
		:MapWithFunction(ItemInfo.GetTexture)
		:CallMethod(self._icon, "TSMSetTextureAndCoord")

	-- Set the quality state
	self._state:PublisherForKeyChange("itemString")
		:IgnoreNil()
		:MapWithFunction(private.ItemStringToCraftedQualityTexture)
		:CallMethod(self._quality, "SetText")

	-- Set the quantity state
	self._state:PublisherForKeyChange("itemString")
		:IgnoreNil()
		:MapWithFunction(private.GetAvailableMatQuantity)
		:CallMethod(self._quantity, "SetText")
end

---Sets the item displayed by the button.
---@param items string The item to display
---@return ItemButton
function ItemButton:SetItem(itemString)
	self._state.itemString = itemString
	self:SetTooltip(itemString)
	return self
end

---Sets whether or not the button is selected.
---@param selected boolean The selected state
---@return ItemButton
function ItemButton:SetSelected(selected)
	self._state.selected = selected
	return self
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function ItemButton.__private:_HandleBagUpdate(itemsChanged)
	local itemString = self._acquired and self._state.itemString
	if not itemString or not itemsChanged[self._state.itemString] then
		return
	end
	self._quantity:SetText(private.GetAvailableMatQuantity(itemString))
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemStringToCraftedQualityTexture(itemString)
	local craftedQuality, useMidnightIcon = ItemInfo.GetCraftedQuality(itemString)
	if not craftedQuality or craftedQuality <= 0 then
		return ""
	end
	local large = useMidnightIcon and true or false
	return TradeSkill.GetCraftedQualityChatIcon(craftedQuality, useMidnightIcon, large)
end

function private.GetAvailableMatQuantity(itemString)
	return BagTracking.GetCraftingMatQuantity(itemString) + WarbankTracking.GetQuantity(itemString)
end
