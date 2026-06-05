-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")



-- ============================================================================
-- Element Definition
-- ============================================================================

local CustomStringDialog = UIElements.Define("CustomStringDialog", "Frame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CustomStringDialog:__init(frame)
	self.__super:__init(frame)
	self._configured = false
	self._value = nil
	self._originalValue = nil
	self._onDoneEditing = nil
	self._onValueChanged = nil
end

function CustomStringDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetSize(590, 442)
	self:SetPadding(12)
	self:AddAnchor("CENTER")
	self:SetMouseEnabled(true)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, -4, 8)
		:AddChild(UIElements.New("Text", "title")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY1_BOLD")
			:SetJustifyH("LEFT")
			:SetText((EDIT or "Edit")..": ")
		)
		:AddChild(UIElements.New("Text", "title")
			:SetFont("BODY_BODY1")
			:SetJustifyH("LEFT")
		)
	)
end

function CustomStringDialog:Release()
	self._configured = false
	self._value = nil
	self._originalValue = nil
	self._onDoneEditing = nil
	self._onValueChanged = nil
	self.__super:Release()
end

---Configures the custom string dialog.
---@param title string The title text
---@param value string The current value
---@param validateFunc SyntaxInputValidateFunc The validation function
---@param badSources table Bad sources to pass to the validation function as context
---@return CustomStringDialog
function CustomStringDialog:Configure(title, value, validateFunc, badSources)
	assert(not self._configured)
	self._configured = true
	self._originalValue = value
	local isValid, validationError = validateFunc(nil, value, badSources)
	self._value = isValid and value or nil
	self:GetElement("header.title"):SetText(title)
	self:AddChild(UIElements.New("SyntaxInput", "input")
		:SetValidateFunc(validateFunc, badSources)
		:SetValue(value)
		:SetScript("OnValueChanged", self:__closure("_HandleInputValueChanged"))
		:SetScript("OnDoneEditing", self:__closure("_HandleInputDoneEditing"))
	)
	self:AddChild(UIElements.New("Frame", "footer")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 8, 0)
		:AddChild(UIElements.New("Text", "status")
			:SetMargin(0, 10, 0, 0)
			:SetFont("BODY_BODY3")
			:SetJustifyH("RIGHT")
			:SetText(self:_GetStatus(validationError))
		)
		:AddChild(UIElements.New("ActionButton", "cancelBtn")
			:SetSize(81, 24)
			:SetMargin(0, 10, 0, 0)
			:SetText(CANCEL)
			:SetScript("OnClick", self:__closure("_Cancel"))
		)
		:AddChild(UIElements.New("ActionButton", "saveBtn")
			:SetSize(121, 24)
			:SetText(L["Save & Close"])
			:SetDisabled(not isValid)
			:SetScript("OnClick", self:__closure("_Save"))
		)
	)
	return self
end

---Registers a script handler.
---@param script "OnDoneEditing"|"OnValueChanged" The script to register for
---@param handler fun(dialog: CustomStringDialog, ...: any) The handler which recieves the dialog plus any arguments
---@return CustomStringDialog
function CustomStringDialog:SetScript(script, handler)
	if script == "OnDoneEditing" then
		self._onDoneEditing = handler
	elseif script == "OnValueChanged" then
		self._onValueChanged = handler
	else
		error("Invalid script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CustomStringDialog.__private:_HandleInputValueChanged(input)
	local value, validationError = input:GetValue()
	self._value = value
	self:GetElement("footer.saveBtn"):SetDisabled(validationError and true or false)
	self:GetElement("footer.status"):SetText(self:_GetStatus(validationError))
	if self._onValueChanged then
		self:_onValueChanged(not validationError and value or nil)
	end
end

function CustomStringDialog.__private:_HandleInputDoneEditing(_, shouldSave)
	if shouldSave then
		self:_Save()
	else
		self:_Cancel()
	end
end

function CustomStringDialog.__private:_Cancel()
	self:_onDoneEditing(self._originalValue)
	self:GetBaseElement():HideDialog()
end

function CustomStringDialog.__private:_Save()
	assert(self._value)
	self:_onDoneEditing(self._value)
	self:GetBaseElement():HideDialog()
end

function CustomStringDialog.__private:_GetStatus(validationError)
	if validationError then
		return Theme.GetColor("FEEDBACK_RED"):ColorText(validationError)
	else
		return L["Saved"]
	end
end
