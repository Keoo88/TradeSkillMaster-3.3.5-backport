-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local VendorUIUtils = LibTSMUI:Include("Vendor.VendorUIUtils")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local Container = LibTSMUI:From("LibTSMWoW"):Include("API.Container")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local Vendor = LibTSMUI:From("LibTSMService"):Include("Vendor")



-- ============================================================================
-- Element Definition
-- ============================================================================

local VendorQuantityDialog = UIElements.Define("VendorQuantityDialog", "Frame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function VendorQuantityDialog:__init(frame)
	self.__super:__init(frame)
	self._index = nil
	self._itemString = nil
end

function VendorQuantityDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(328, 214)
	self:SetPadding(12)
	self:AddAnchor("CENTER")
	self:SetMouseEnabled(true)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, -4, 10)
		:AddChild(UIElements.New("Spacer", "spacer")
			:SetWidth(20)
		)
		:AddChild(UIElements.New("Text", "title")
			:SetJustifyH("CENTER")
			:SetFont("BODY_BODY1_BOLD")
			:SetText(L["Purchase Item"])
		)
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetMargin(0, -4, 0, 0)
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetScript("OnClick", self:__closure("_CloseDialog"))
		)
	)
	self:AddChild(UIElements.New("Frame", "item")
		:SetLayout("HORIZONTAL")
		:SetPadding(6)
		:SetMargin(0, 0, 0, 16)
		:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("Button", "icon")
			:SetSize(36, 36)
			:SetMargin(0, 8, 0, 0)
		)
		:AddChild(UIElements.New("Text", "name")
			:SetHeight(36)
			:SetFont("ITEM_BODY1")
		)
	)
	self:AddChild(UIElements.New("Frame", "qty")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Text", "text")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Quantity"]..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetWidth(156)
			:SetMargin(12, 8, 0, 0)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetJustifyH("CENTER")
			:SetSubAddEnabled(true)
			:SetValidateFunc("NUMBER", "1:99999")
			:SetValue(1)
			:SetScript("OnValidationChanged", self:__closure("_HandleQtyValidationChanged"))
			:SetScript("OnValueChanged", self:__closure("_HandleQtyValueChanged"))
			:SetScript("OnEnterPressed", self:__closure("_HandleQtyEnterPressed"))
		)
		:AddChild(UIElements.New("ActionButton", "max")
			:SetText(L["Max"])
			:SetScript("OnClick", self:__closure("_HandleMaxBtnClick"))
		)
	)
	self:AddChild(UIElements.New("Frame", "cost")
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Text", "label")
			:SetWidth("AUTO")
			:SetMargin(0, 8, 0, 0)
			:SetJustifyH("RIGHT")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(L["Current Price"]..":")
		)
		:AddChild(UIElements.New("Button", "text")
			:SetWidth("AUTO")
			:SetJustifyH("RIGHT")
			:SetFont("TABLE_TABLE1")
		)
	)
	self:AddChild(UIElements.New("ActionButton", "purchaseBtn")
		:SetHeight(24)
		:SetText(L["Purchase"])
		:SetScript("OnClick", self:__closure("_HandlePurchaseBtnClick"))
	)
end

function VendorQuantityDialog:Release()
	self._index = nil
	self._itemString = nil
	self.__super:Release()
end

---Configures the vendor item to be displayed.
---@param index number The vendor buy index
---@param itemString string The item string
---@param firstCostItem? string The first cost item
---@return VendorQuantityDialog
function VendorQuantityDialog:Configure(index, itemString, firstCostItem)
	assert(index and itemString and not self._index and not self._itemString)
	self._index = index
	self._itemString = itemString
	self:GetElement("item.icon")
		:SetBackground(ItemInfo.GetTexture(itemString))
		:SetTooltip(itemString)
	self:GetElement("item.name")
		:SetText(UIUtils.GetDisplayItemName(itemString) or "?")
	self:GetElement("cost.text")
		:SetText(VendorUIUtils.GetAltCostText(index, 1))
		:SetTooltip(firstCostItem)
	self:GetElement("purchaseBtn"):SetDisabled(Vendor.GetNumCanAfford(index) < 1)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function VendorQuantityDialog.__private:_CloseDialog()
	self:GetBaseElement():HideDialog()
end

function VendorQuantityDialog.__private:_HandleQtyValidationChanged(input)
	if input:IsValid() and tonumber(input:GetValue()) <= Vendor.GetNumCanAfford(self._index) then
		input:GetElement("__parent.__parent.purchaseBtn")
			:SetDisabled(false)
			:Draw()
	else
		input:GetElement("__parent.__parent.purchaseBtn")
			:SetDisabled(true)
			:Draw()
	end
end

function VendorQuantityDialog.__private:_HandleQtyValueChanged(input)
	local value = tonumber(input:GetValue())
	input:GetElement("__parent.__parent.cost.text")
		:SetText(VendorUIUtils.GetAltCostText(self._index, value))
	input:GetElement("__parent.__parent.cost")
		:Draw()
	if input:IsValid() and value <= Vendor.GetNumCanAfford(self._index) then
		input:GetElement("__parent.__parent.purchaseBtn")
			:SetDisabled(false)
			:Draw()
	else
		input:GetElement("__parent.__parent.purchaseBtn")
			:SetDisabled(true)
			:Draw()
	end
end

function VendorQuantityDialog.__private:_HandleQtyEnterPressed(input)
	input:GetElement("__parent.__parent.purchaseBtn"):Click()
end

function VendorQuantityDialog.__private:_HandleMaxBtnClick(button)
	local value = max(1, min(Vendor.GetNumCanAfford(self._index), ItemInfo.GetMaxStack(self._itemString) * Container.GetTotalFreeBagSlots()))
	button:GetElement("__parent.input")
		:SetValue(value)
		:Draw()
	self:_HandleQtyValidationChanged(button:GetElement("__parent.input"))
	button:GetElement("__parent.__parent.cost.text")
		:SetText(VendorUIUtils.GetAltCostText(self._index, tonumber(value)))
	button:GetElement("__parent.__parent.cost")
		:Draw()
end

function VendorQuantityDialog.__private:_HandlePurchaseBtnClick(button)
	Vendor.BuyIndex(self._index, button:GetElement("__parent.qty.input"):GetValue())
	self:_CloseDialog()
end
