-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local EXPANDER_SIZE = 18
local TEXT_PADDING = 8
local EXPANDER_PADDING = 4
local CORNER_RADIUS = 4
local MIN_DIALOG_WIDTH = 100



-- ============================================================================
-- Element Definition
-- ============================================================================

local BaseDropdown = UIElements.Define("BaseDropdown", "Text", "ABSTRACT")
BaseDropdown:_ExtendStateSchema()
	:UpdateFieldDefault("font", "BODY_BODY2")
	:AddBooleanField("disabled", false)
	:AddBooleanField("backgroundIsLight", false)
	:AddStringField("hintText", "")
	:AddStringField("currentSelectionStr", "")
	:Commit()
BaseDropdown:_AddActionScripts("OnSelectionChanged")



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function BaseDropdown:__init()
	local frame = self:_CreateButton()

	self.__super:__init(frame)

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)

	frame:TSMSetScript("OnClick", self:__closure("_OpenDialog"))
	frame.arrow = self:_CreateTexture()
	frame.arrow:TSMSetTexture("iconPack.18x18/Chevron/Down")

	self._widthText = self:_CreateFontString()
	self._widthText:Hide()

	self._items = {}
	self._onSelectionChangedHandler = nil
end

function BaseDropdown:Acquire()
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()

	local backgroundColorPublisher = self._state:PublisherForKeyChange("disabled")
		:MapBooleanWithValues("PRIMARY_BG_ALT", "ACTIVE_BG")
		:Share(2)
	backgroundColorPublisher
		:CallMethod(self._backgroundTexture, "SubscribeColor")
	backgroundColorPublisher
		:MapToPublisherWithFunction(Theme.GetPublisher)
		:MapWithMethod("IsLight")
		:IgnoreDuplicates()
		:AssignToTableKey(self._state, "backgroundIsLight")

	self._state:PublisherForKeys("disabled", "backgroundIsLight")
		:MapWithFunction(private.StateToTextColor)
		:Share(2)
		:CallMethod(frame.text, "TSMSubscribeTextColor")
		:CallMethod(frame.arrow, "TSMSubscribeVertexColor")

	self._state:PublisherForKeyChange("font")
		:CallMethod(self._widthText, "TSMSetFont")

	self._state:PublisherForKeyChange("disabled")
		:InvertBoolean()
		:CallMethod(frame, "TSMSetEnabled")

	self._state:PublisherForKeyChange("currentSelectionStr")
		:CallFunction(self:__closure("_SetText"))
end

function BaseDropdown:Release()
	wipe(self._items)
	self._onSelectionChangedHandler = nil
	self:_GetBaseFrame():Enable()
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the hint text which is shown when there's no selection.
---@generic T: BaseDropdown
---@param self T
---@param text string The hint text string
---@return T
function BaseDropdown:SetHintText(text)
	self._state.hintText = text
	return self
end

---Set whether or not the dropdown is disabled.
---@generic T: BaseDropdown
---@param self T
---@param disabled boolean Whether or not to disable the dropdown
---@return T
function BaseDropdown:SetDisabled(disabled)
	self._state.disabled = disabled
	return self
end

---Subscribes to a publisher to set the disabled state.
---@generic T: BaseDropdown
---@param self T
---@param publisher ReactivePublisher The publisher
---@return T
function BaseDropdown:SetDisabledPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetDisabled"))
	return self
end

---Registers a script handler.
---@generic T: BaseDropdown
---@param self T
---@param script string The script to register for (supported scripts: `OnSelectionChanged`)
---@param handler function The script handler which will be called with the dropdown object followed by any arguments
-- to the script
---@return T
function BaseDropdown:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChangedHandler = handler
	elseif script == "OnEnter" or script == "OnLeave" then
		self.__super:SetScript(script, handler)
	else
		error("Invalid BaseDropdown script: "..tostring(script))
	end
	return self
end

function BaseDropdown:SetText()
	error("BaseDropdown does not support this method")
end

function BaseDropdown:SetTextColor(color)
	error("BaseDropdown does not support this method")
end

function BaseDropdown:Draw()
	self.__super:Draw()
	local frame = self:_GetBaseFrame()
	local paddingY = (frame:GetHeight() - EXPANDER_SIZE) / 2
	frame.text:ClearAllPoints()
	frame.text:SetPoint("TOPLEFT", TEXT_PADDING, 0)
	frame.text:SetPoint("BOTTOMRIGHT", -EXPANDER_SIZE, 0)
	frame.arrow:ClearAllPoints()
	frame.arrow:SetPoint("BOTTOMLEFT", frame.text, "BOTTOMRIGHT", -EXPANDER_PADDING, paddingY)
	frame.arrow:SetPoint("TOPRIGHT", -EXPANDER_PADDING, -paddingY)
end



-- ============================================================================
-- Abstract Class Methods
-- ============================================================================



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function BaseDropdown.__private:_OpenDialog()
	local dialog = self:_CreateDialog()
	self:GetBaseElement():ShowDialogFrame(dialog)
end

function BaseDropdown.__protected:_GetDialogSize()
	local maxStringWidth = MIN_DIALOG_WIDTH
	self._widthText:Show()
	for _, item in ipairs(self._items) do
		self._widthText:SetText(item)
		maxStringWidth = max(maxStringWidth, self._widthText:GetUnboundedStringWidth())
	end
	self._widthText:Hide()
	local linesHeight = nil
	if #self._items == 0 then
		linesHeight = 16
	elseif #self._items <= 8 then
		linesHeight = #self._items * 20
	else
		linesHeight = 150
	end
	return maxStringWidth + Theme.GetColSpacing() * 2, 8 + linesHeight
end

---@return DropdownDialog
function BaseDropdown.__protected:_CreateDialog()
	local width, height = self:_GetDialogSize()
	width = max(width, self:_GetDimension("WIDTH"))
	local dialog = UIElements.New("DropdownDialog", "dropdown")
		:SetContext(self)
		:AddAnchor("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
		:SetSize(width, height)
	return dialog
end

function BaseDropdown.__private:_SetText(str)
	self.__super:SetText(str)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToTextColor(state)
	local colorKey = state.backgroundIsLight and "FULL_BLACK" or "FULL_WHITE"
	if state.disabled then
		colorKey = colorKey..(state.backgroundIsLight and "-DISABLED" or "+DISABLED")
	end
	return colorKey
end
