-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftTierButton = UIElements.Define("CraftTierButton", "Frame")
CraftTierButton:_ExtendStateSchema()
	:AddBooleanField("selected", false)
	:AddBooleanField("mouseOver", false)
	:AddOptionalStringField("craftString")
	:AddOptionalNumberField("cost")
	:AddOptionalNumberField("profit")
	:AddNumberField("concentration", 0)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftTierButton:__init()
	self.__super:__init()
	self._onClickHandler = nil
end

function CraftTierButton:Acquire()
	self.__super:Acquire()
	self:SetMouseEnabled(true)
	self:SetRoundedBackgroundColor("PRIMARY_BG")
	self.__super:SetScript("OnMouseDown", self:__closure("_HandleClick"))
	self.__super:SetScript("OnEnter", self:__closure("_HandleFrameEnter"))
	self.__super:SetScript("OnLeave", self:__closure("_HandleFrameLeave"))
	self:SetLayout("VERTICAL")
	self:SetPadding(4)
	self:AddChild(UIElements.New("Frame", "header")
		:SetHeight(20)
		:SetPadding(4, 4, 0, 0)
		:SetLayout("HORIZONTAL")
		:AddChild(UIElements.New("Button", "icon")
			:SetWidth("AUTO")
		)
		:AddChild(UIElements.New("Text", "text")
			:SetJustifyH("RIGHT")
			:SetTextColor("PRIMARY_BG")
		)
	)
	self:AddChild(UIElements.New("Frame", "cost")
		:SetHeight(20)
		:SetMargin(4, 4, 8, 0)
		:SetLayout("HORIZONTAL")
		:AddChild(UIElements.New("Text", "label")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY3_MEDIUM")
			:SetTextColor("TEXT_ALT")
			:SetText(L["Cost"]..":")
		)
		:AddChild(UIElements.New("Text", "value")
			:SetJustifyH("RIGHT")
			:SetFont("TABLE_TABLE1")
		)
	)
	self:AddChild(UIElements.New("Frame", "profit")
		:SetHeight(20)
		:SetMargin(4, 4, 0, 4)
		:SetLayout("HORIZONTAL")
		:AddChild(UIElements.New("Text", "label")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY3_MEDIUM")
			:SetTextColor("TEXT_ALT")
			:SetText(L["Profit"]..":")
		)
		:AddChild(UIElements.New("Text", "value")
			:SetJustifyH("RIGHT")
			:SetFont("TABLE_TABLE1")
		)
	)

	-- Set the border state
	self._state:PublisherForKeys("mouseOver", "selected")
		:MapWithFunction(private.StateToBorderColor)
		:IgnoreDuplicates()
		:CallMethod(self, "_UpdateBorderColor")

	-- Set the header state
	local qualityPublisher = self._state:PublisherForKeyChange("craftString")
		:IgnoreNil()
		:Share(2)
	qualityPublisher
		:MapWithFunction(private.CraftStringToCraftedQuality)
		:CallMethod(self:GetElement("header.icon"), "SetText")
	qualityPublisher
		:MapWithFunction(private.CraftStringToCraftedQualityColorKey)
		:CallMethod(self:GetElement("header"), "SetRoundedBackgroundColor")
	self._state:PublisherForKeyChange("craftString")
		:IgnoreNil()
		:MapWithFunction(Profession.GetItemStringByCraftString)
		:CallMethod(self:GetElement("header.icon"), "SetTooltip")

	-- Set the cost text
	self._state:PublisherForKeyChange("cost")
		:MapWithFunction(private.CostToString)
		:CallMethod(self:GetElement("cost.value"), "SetText")

	-- Set the profit text
	self._state:PublisherForKeyChange("profit")
		:MapWithFunction(private.ProfitToString)
		:CallMethod(self:GetElement("profit.value"), "SetText")

	-- Set the concentration text
	self._state:PublisherForKeyChange("concentration")
		:MapWithFunction(private.ConcentrationToString)
		:CallMethod(self:GetElement("header.text"), "SetText")
end

function CraftTierButton:Release()
	self._onClickHandler = nil
	self.__super:Release()
end

---Sets the craft string.
---@param craftString string The craft string
---@param concentration number The required concentration amount
---@return CraftTierButton
function CraftTierButton:SetCraftString(craftString, concentration)
	self._state.craftString = craftString
	self._state.concentration = concentration
	return self
end

---Sets the prices for this button.
---@param cost? number The crafting cost
---@param profit? number The profit
---@return CraftTierButton
function CraftTierButton:SetPrices(cost, profit)
	self._state.cost = cost
	self._state.profit = profit
	return self
end

---Sets whether or not the button is selected.
---@param selected boolean The selected state
---@return CraftTierButton
function CraftTierButton:SetSelected(selected)
	self._state.selected = selected
	return self
end

---Sets a script handler.
---@param script string The script to register for (currently only supports `OnClick`)
---@param handler function The script handler which will be called with the action button object followed by any arguments to the script
---@return CraftTierButton
function CraftTierButton:SetScript(script, handler)
	if script == "OnClick" then
		self._onClickHandler = handler
	else
		error("Unknown CraftTierButton script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftTierButton.__private:_UpdateBorderColor(color)
	self:SetBorderColor(color, 2)
		:Draw()
end

function CraftTierButton.__private:_HandleClick()
	if self._onClickHandler then
		self:_onClickHandler(self._state.craftString, self._state.concentration)
	end
end

function CraftTierButton.__private:_HandleFrameEnter()
	self._state.mouseOver = true
end

function CraftTierButton.__private:_HandleFrameLeave()
	if not self:_GetBaseFrame():IsMouseEnabled() then
		return
	end
	self._state.mouseOver = false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CraftStringToCraftedQuality(craftString)
	local craftQuality = CraftString.GetQuality(craftString)
	local useMidnightIcon = TradeSkill.IsMidnightRecipe(CraftString.GetSpellId(craftString))
	return TradeSkill.GetCraftedQualityChatIcon(craftQuality, useMidnightIcon)
end

function private.CraftStringToCraftedQualityColorKey(craftString)
	local craftQuality = CraftString.GetQuality(craftString)
	local useMidnightIcon = TradeSkill.IsMidnightRecipe(CraftString.GetSpellId(craftString))
	return Theme.GetCraftedQualityColorKey(craftQuality, useMidnightIcon)
end

function private.StateToBorderColor(state)
	return (state.selected or state.mouseOver) and "ACTIVE_BG_ALT" or "ACTIVE_BG"
end

function private.CostToString(cost)
	return cost and Money.ToStringForUI(cost) or "---"
end

function private.ProfitToString(profit)
	return profit and Money.ToStringForUI(profit, Theme.GetColor(profit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"):GetTextColorPrefix()) or "---"
end

function private.ConcentrationToString(concentration)
	if concentration == 0 then
		return ""
	else
		-- TODO: display how much concentration is needed
		return "|TInterface\\ICONS\\UI_Concentration:0|t"
	end
end
