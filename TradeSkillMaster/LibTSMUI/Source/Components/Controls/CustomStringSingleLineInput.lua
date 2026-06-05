-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local private = {}
local POPOUT_ICON = "iconPack.12x12/Popout"
local PADDING_LEFT = 8
local PADDING_RIGHT = 20
local PADDING_TOP_BOTTOM = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local CustomStringSingleLineInput = UIElements.Define("CustomStringSingleLineInput", "BaseInput")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CustomStringSingleLineInput:__init()
	local frame = self:_CreateEditBox()
	self.__super:__init(frame, frame)
	frame:SetTextInsets(PADDING_LEFT, PADDING_RIGHT, PADDING_TOP_BOTTOM, PADDING_TOP_BOTTOM)

	self._popoutIcon = self:_CreateTexture(frame, "ARTWORK")
	self._popoutIcon:SetPoint("RIGHT", -4, 0)
	self._popoutIcon:TSMSetSize(POPOUT_ICON)

	self._popoutButton = self:_CreateButton(frame)
	self._popoutButton:SetAllPoints(self._popoutIcon)
	self._popoutButton:TSMSetScript("OnClick", self:__closure("_ShowPopout"))
	self._popoutButton:TSMSetPropagate("OnEnter")
	self._popoutButton:TSMSetPropagate("OnLeave")
	self._popoutButton:SetHitRectInsets(-2, -2, -2, -2)

	self._isNumber = false
	self._popoutTitle = nil
end

function CustomStringSingleLineInput:Acquire()
	self.__super:Acquire()
	self._state:PublisherForKeyChange("disabled")
		:MapWithFunction(private.DisabledToPopoutIcon)
		:CallMethod(self._popoutIcon, "TSMSetTexture")
end

function CustomStringSingleLineInput:Release()
	self._isNumber = false
	self._popoutTitle = nil
	self.__super:Release()
end

---Sets whether or not the result of the custom string is a number rather than a price.
---@param isNumber boolean Whether or not the result is a number
---@return CustomStringSingleLineInput
function CustomStringSingleLineInput:SetIsNumber(isNumber)
	self._isNumber = isNumber
	local value = self._settingTable[self._settingKey]
	if not isNumber then
		value = Money.ToStringExact(value) or value
	end
	self:SetValue(value)
	return self
end

---Sets the popout dialog title.
---@param title string The popout dialog title
---@return CustomStringSingleLineInput
function CustomStringSingleLineInput:SetPopoutTitle(title)
	self._popoutTitle = title
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CustomStringSingleLineInput.__private:_ShowPopout()
	assert(self._popoutTitle)
	self:GetBaseElement():ShowDialogFrame(UIElements.New("CustomStringDialog", "dialog")
		:Configure(self._popoutTitle, self:GetValue(), self._validateFunc, self._validateContext)
		:SetScript("OnDoneEditing", self:__closure("_HandlePopoutDoneEditing"))
	)
end

function CustomStringSingleLineInput.__private:_HandlePopoutDoneEditing(_, value)
	if not self._isNumber then
		value = Money.ToStringExact(value) or value
	end
	assert(self:_SetValueHelper(value))
	self._escValue = self._value
	self:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.DisabledToPopoutIcon(disabled)
	return TextureAtlas.GetColoredKey(POPOUT_ICON, disabled and "TEXT_DISABLED" or "TEXT")
end
