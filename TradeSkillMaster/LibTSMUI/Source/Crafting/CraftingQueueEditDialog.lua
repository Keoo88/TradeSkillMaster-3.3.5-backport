-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingQueueEditDialog = UIElements.Define("CraftingQueueEditDialog", "Frame")



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function CraftingQueueEditDialog:__init()
	self.__super:__init()
	self._value = nil
	self._onValueChanged = nil
end

function CraftingQueueEditDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	self:SetBackgroundColor("PRIMARY_BG")
	self:AddChild(UIElements.New("Button", "icon")
		:SetSize(12, 12)
		:SetMargin(16, 4, 0, 0)
	)
	self:AddChild(UIElements.New("Text", "name")
		:SetWidth("AUTO")
		:SetFont("ITEM_BODY3")
	)
	self:AddChild(UIElements.New("Spacer", "spacer"))
	self:AddChild(UIElements.New("Input", "input")
		:SetWidth(75)
		:SetBackgroundColor("ACTIVE_BG")
		:SetJustifyH("CENTER")
		:SetSubAddEnabled(true)
		:SetValidateFunc("NUMBER", "1:9999")
		:SetScript("OnFocusLost", self:__closure("_HandleInputFocusLost"))
		:SetScript("OnValueChanged", self:__closure("_HandleInputValueChanged"))
	)
end

function CraftingQueueEditDialog:Release()
	self.__super:Release()
	self._value = nil
	self._onValueChanged = nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the info to display in the dialog.
---@param name string The item name
---@param texture number The item texture
---@param tooltip string The item tooltip
---@param num number The input quantity
---@return CraftingQueueEditDialog
function CraftingQueueEditDialog:SetInfo(name, texture, tooltip, num)
	self._value = num
	self:GetElement("icon")
		:SetBackground(texture)
		:SetTooltip(tooltip)
	self:GetElement("name")
		:SetText(name)
	self:GetElement("input")
		:SetValue(num)
	return self
end

---Sets the input to be focused.
function CraftingQueueEditDialog:Focus()
	self:GetElement("input"):SetFocused(true)
end

---Gets the current value of the input.
---@return number
function CraftingQueueEditDialog:GetValue()
	assert(self._value ~= nil)
	return self._value
end

---Registers a script handler.
---@param script "OnHide" The script to register for
---@param handler function The script handler function
---@return CraftingQueueEditDialog
function CraftingQueueEditDialog:SetScript(script, handler)
	if script == "OnHide" then
		self.__super:SetScript(script, handler)
	else
		error("Invalid CraftingQueueEditDialog script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftingQueueEditDialog.__private:_HandleInputFocusLost(input)
	input:GetBaseElement():HideDialog()
end

function CraftingQueueEditDialog.__private:_HandleInputValueChanged(input)
	self._value = tonumber(input:GetValue())
end
