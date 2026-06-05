-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local CraftString = LibTSMUI:From("LibTSMTypes"):Include("Crafting.CraftString")
local Profession = LibTSMUI:From("LibTSMService"):Include("Profession")
local TradeSkill = LibTSMUI:From("LibTSMWoW"):Include("API.TradeSkill")



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftTierDialog = UIElements.Define("CraftTierDialog", "Frame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftTierDialog:__init(frame)
	self.__super:__init(frame)
	self._hasCraftString = false
	self._onQualityChanged = nil
end

function CraftTierDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(252, 108)
	self:AddAnchor("CENTER")
	self:SetMouseEnabled(true)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:AddChild(UIElements.New("Text", "title")
			:SetMargin(22, 0, 0, 0)
			:SetJustifyH("CENTER")
			:SetFont("BODY_BODY3_MEDIUM")
			:SetText(L["Select Crafted Item Quality"])
		)
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetMargin(4, 4, 0, 0)
			:SetBackgroundAndSize("iconPack.14x14/Close/Default")
			:SetScript("OnClick", self:__closure("_CloseDialog"))
		)
	)
	self:AddChild(UIElements.New("Frame", "options")
		:SetLayout("HORIZONTAL")
		:SetHeight(88)
		:SetPadding(4, 0, 4, 4)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("Spacer", "leftSpacer"))
		:AddChild(UIElements.New("Frame", "inner")
			:SetLayout("HORIZONTAL")
			:SetHeight(88)
		)
		:AddChild(UIElements.New("Spacer", "rightSpacer"))
	)
end

function CraftTierDialog:Release()
	self._hasCraftString = false
	self._onQualityChanged = nil
	self.__super:Release()
end

---Sets the craft string which options should be displayed for.
---@param craftString string The craft string
---@param costsFunc fun(craftString: string): number?, number?, number? A function which returns costs for a craft string
function CraftTierDialog:SetCraftString(craftString, costsFunc)
	assert(craftString and costsFunc and not self._hasCraftString)
	self._hasCraftString = true
	local selectedQuality = CraftString.GetQuality(craftString)
	local foundSelectedQuality = false
	local numOptions = 0
	local maxQuality = TradeSkill.GetMaxQualityForRecipe(CraftString.GetSpellId(craftString)) or 0
	for quality = 1, maxQuality do
		local qualityCraftString = CraftString.SetQuality(craftString, quality)
		if Profession.GetIndexByCraftString(qualityCraftString) then
			local isSelected = quality == selectedQuality
			foundSelectedQuality = foundSelectedQuality or isSelected
			local cost, _, profit, concentration = costsFunc(qualityCraftString)
			self:GetElement("options.inner"):AddChild(UIElements.New("CraftTierButton", "button_"..quality)
				:SetSize(120, 80)
				:SetMargin(0, 4, 0, 0)
				:SetCraftString(qualityCraftString, concentration or 0)
				:SetPrices(cost, profit)
				:SetSelected(isSelected)
				:SetScript("OnClick", self:__closure("_HandleQualityClick"))
			)
			numOptions = numOptions + 1
		end
	end
	self:SetWidth(max(numOptions, 2) * 124 + 4)
	return self
end

---Registers a script handler.
---@param script "OnQualityChanged"
---@param handler fun(craftDetails: CraftTierDialog, ...: any) The handler
---@return CraftTierDialog
function CraftTierDialog:SetScript(script, handler)
	if script == "OnQualityChanged" then
		self._onQualityChanged = handler
	else
		error("Invalid script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftTierDialog.__private:_CloseDialog()
	self:GetBaseElement():HideDialog()
end

function CraftTierDialog.__private:_HandleQualityClick(_, craftString, concentration)
	self:_onQualityChanged(craftString, concentration)
	self:_CloseDialog()
end
