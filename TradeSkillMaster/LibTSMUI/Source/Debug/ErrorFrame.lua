-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ErrorFrame = LibTSMUI:DefineClassType("ErrorFrame")
local ErrorHandler = LibTSMUI:From("LibTSMService"):Include("Debug.ErrorHandler")
local ReactiveState = LibTSMUI:From("LibTSMUtil"):Include("Reactive.Type.State")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local LibTSMClass = LibStub("LibTSMClass")
local private = {}
local STEPS_TEXT = "Steps leading up to the error:\n1) List\n2) Steps\n3) Here"
local FRAME_BACKDROP = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = "Interface\\Buttons\\WHITE8X8",
	edgeSize = 2,
}



-- ============================================================================
-- Static Class Functions
-- ============================================================================

function ErrorFrame.__static.Create()
	return ErrorFrame()
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function ErrorFrame.__private:__init()
	self._errorStr = nil
	self._fullErrorInfo = nil
	self._errorInfo = nil
	self._isManual = nil
	self._showingError = nil
	self._details = nil

	local template = ClientInfo.IsRetail() and BackdropTemplateMixin and "BackdropTemplate" or nil
	local frame = CreateFrame("Frame", nil, UIParent, template)
	self._frame = frame
	frame:Hide()
	frame:SetWidth(500)
	frame:SetHeight(400)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetPoint("RIGHT", -100, 0)
	frame:SetBackdrop(FRAME_BACKDROP)
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	frame:SetScript("OnHide", self:__closure("_HandleHide"))

	local title = frame:CreateFontString()
	title:SetHeight(20)
	title:SetPoint("TOPLEFT", 0, -10)
	title:SetPoint("TOPRIGHT", 0, -10)
	title:SetFontObject(GameFontNormalLarge)
	title:SetTextColor(1, 1, 1, 1)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("MIDDLE")
	title:SetText("TSM Error Window ("..LibTSMUI.GetVersionStr()..")")

	local hLine = frame:CreateTexture(nil, "ARTWORK")
	hLine:SetHeight(2)
	hLine:SetColorTexture(0.3, 0.3, 0.3, 1)
	hLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	hLine:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -10)

	local text = frame:CreateFontString()
	frame.text = text
	text:SetHeight(45)
	text:SetPoint("TOPLEFT", hLine, "BOTTOMLEFT", 8, -8)
	text:SetPoint("TOPRIGHT", hLine, "BOTTOMRIGHT", -8, -8)
	text:SetFontObject(GameFontNormal)
	text:SetTextColor(1, 1, 1, 1)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("MIDDLE")

	local switchBtn = CreateFrame("Button", nil, frame)
	frame.switchBtn = switchBtn
	switchBtn:SetPoint("TOPRIGHT", -4, -10)
	switchBtn:SetWidth(100)
	switchBtn:SetHeight(20)
	local fontString = switchBtn:CreateFontString()
	fontString:SetFontObject(GameFontNormalSmall)
	fontString:SetJustifyH("CENTER")
	fontString:SetJustifyV("MIDDLE")
	switchBtn:SetFontString(fontString)
	switchBtn:SetScript("OnClick", self:__closure("_HandleSwitchClick"))
	if LibTSMUI.IsDevVersion() then
		local fullBtn = CreateFrame("Button", nil, frame)
		frame.fullBtn = fullBtn
		fullBtn:SetPoint("BOTTOM", 0, 10)
		fullBtn:SetWidth(100)
		fullBtn:SetHeight(20)
		local fontString2 = fullBtn:CreateFontString()
		fontString2:SetFontObject(GameFontNormalSmall)
		fontString2:SetJustifyH("CENTER")
		fontString2:SetJustifyV("MIDDLE")
		fullBtn:SetFontString(fontString2)
		fullBtn:SetText("Show Full Error")
		fullBtn:SetScript("OnClick", self:__closure("_HandleFullErrorClick"))
	end

	local hLine2 = frame:CreateTexture(nil, "ARTWORK")
	hLine2:SetHeight(2)
	hLine2:SetColorTexture(0.3, 0.3, 0.3, 1)
	hLine2:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -8, -4)
	hLine2:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 8, -4)

	local scrollFrame = CreateFrame("ScrollFrame", "TSMErrorFrameScrollFrame"..tostring(math.random(1, 999999)), frame, "UIPanelScrollFrameTemplate")
	frame.scrollFrame = scrollFrame
	scrollFrame:SetPoint("TOPLEFT", hLine2, "BOTTOMLEFT", 8, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 38)

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	frame.editBox = editBox
	editBox:SetWidth(scrollFrame:GetWidth())
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(0)
	editBox:SetTextColor(1, 1, 1, 1)
	editBox:SetScript("OnUpdate", self:__closure("_HandleEditUpdate"))
	editBox:SetScript("OnEditFocusGained", self:__closure("_HandleEditFocusGained"))
	editBox:SetScript("OnCursorChanged", self:__closure("_HandleEditCursorChanged"))
	editBox:SetScript("OnTextChanged", self:__closure("_HandleEditTextChanged"))
	editBox:SetScript("OnEscapePressed", self:__closure("_HandleEditEscapePressed"))
	scrollFrame:SetScrollChild(editBox)

	local hLine3 = frame:CreateTexture(nil, "ARTWORK")
	hLine3:SetHeight(2)
	hLine3:SetColorTexture(0.3, 0.3, 0.3, 1)
	hLine3:SetPoint("BOTTOMLEFT", frame, 0, 35)
	hLine3:SetPoint("BOTTOMRIGHT", frame, 0, 35)

	local reloadBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.reloadBtn = reloadBtn
	reloadBtn:SetPoint("BOTTOMLEFT", 4, 4)
	reloadBtn:SetWidth(120)
	reloadBtn:SetHeight(30)
	reloadBtn:SetText(RELOADUI)
	reloadBtn:SetScript("OnClick", self:__closure("_HandleReloadClick"))

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.closeBtn = closeBtn
	closeBtn:SetPoint("BOTTOMRIGHT", -4, 4)
	closeBtn:SetWidth(120)
	closeBtn:SetHeight(30)
	closeBtn:SetText(DONE)
	closeBtn:SetScript("OnClick", self:__closure("_HandleCloseClick"))

	local stepsText = frame:CreateFontString()
	frame.stepsText = stepsText
	stepsText:SetWidth(200)
	stepsText:SetHeight(30)
	stepsText:SetPoint("BOTTOM", 0, 4)
	stepsText:SetFontObject(GameFontNormal)
	stepsText:SetTextColor(1, 0, 0, 1)
	stepsText:SetJustifyH("CENTER")
	stepsText:SetJustifyV("MIDDLE")
	stepsText:SetText("Please enter steps before submitting")
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Shows the frame.
---@param errorStr string The error string
---@param errorInfo table The error info
---@param fullErrorInfo table The full error info
---@param isManual boolean Whether or not this is a manual error
function ErrorFrame:Show(errorStr, errorInfo, fullErrorInfo, isManual)
	self._errorStr = errorStr
	self._errorInfo = errorInfo
	self._fullErrorInfo = fullErrorInfo
	self._isManual = isManual
	local showError = isManual or LibTSMUI.IsDevVersion()
	self._showingError = showError
	self._details = STEPS_TEXT
	local frame = self._frame
	frame:Show()
	if showError then
		-- This is a dev version or manual error so show the error (only)
		frame.text:SetText("Looks like TradeSkillMaster has encountered an error.")
		frame.switchBtn:SetText("Hide Error")
		if LibTSMUI.IsDevVersion() then
			frame.fullBtn:Show()
			frame.stepsText:Hide()
		else
			frame.stepsText:Show()
		end
		frame.editBox:SetText(errorStr)
	else
		frame.text:SetText("Looks like TradeSkillMaster has encountered an error. Please provide the steps which lead to this error to help the TSM team fix it, then click either button at the bottom of the window to automatically report this error.")
		frame.switchBtn:SetText("Show Error")
		if LibTSMUI.IsDevVersion() then
			frame.fullBtn:Hide()
		end
		frame.stepsText:Show()
		frame.editBox:SetText(STEPS_TEXT)
	end
end

---Hides the error frame.
function ErrorFrame:Hide()
	self._frame:Hide()
end

---Returns whether or not the frame is visible.
---@return boolean
function ErrorFrame:IsVisible()
	return self._frame:IsVisible()
end




-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ErrorFrame.__private:_HandleHide()
	local details = self._showingError and self._details or self._frame.editBox:GetText()
	ErrorHandler.ProcessReport(self._errorInfo, details, self._isManual, IsShiftKeyDown())
	self._errorStr = nil
	self._details = nil
	self._errorInfo = nil
	self._fullErrorInfo = nil
end

function ErrorFrame.__private:_HandleSwitchClick(button)
	self._showingError = not self._showingError
	if self._showingError then
		self._details = self._frame.editBox:GetText()
		button:SetText("Hide Error")
		self._frame.editBox:SetText(self._fullErrorInfo.str or self._errorStr)
		if LibTSMUI.IsDevVersion() then
			self._frame.fullBtn:Show()
			self._frame.stepsText:Hide()
		end
	else
		button:SetText("Show Error")
		self._fullErrorInfo.str = nil
		self._frame.editBox:SetText(self._details)
		if LibTSMUI.IsDevVersion() then
			self._frame.fullBtn:Hide()
			self._frame.stepsText:Show()
		end
	end
end

function ErrorFrame.__private:_HandleFullErrorClick()
	self._fullErrorInfo.str = nil
	local str = self._errorStr
	for placeholderStr, objectName in pairs(self._fullErrorInfo) do
		local fullStr = LibTSMClass.GetDebugInfo(objectName, 5, private.LocalTableLookupFunc)
		fullStr = gsub(fullStr, "[%z\001-\008\011-\031]", "?")
		fullStr = gsub(fullStr, "\n", "\n    ")
		str = gsub(str, String.Escape(placeholderStr), fullStr)
	end
	self._fullErrorInfo.str = str
	self._frame.editBox:SetText(str)
end

function ErrorFrame.__private:_HandleEditUpdate(editBox)
	local offset = self._frame.scrollFrame:GetVerticalScroll()
	editBox:SetHitRectInsets(0, 0, offset, editBox:GetHeight() - offset - self._frame.scrollFrame:GetHeight())
end

function ErrorFrame.__private:_HandleEditFocusGained(editBox)
	editBox:HighlightText()
end

function ErrorFrame.__private:_HandleEditCursorChanged(editBox)
	if self._showingError and editBox:HasFocus() then
		editBox:HighlightText()
	end
end

function ErrorFrame.__private:_HandleEditTextChanged(editBox, isUserInput)
	if isUserInput and self._showingError then
		editBox:SetText(self._fullErrorInfo.str or self._errorStr)
		editBox:HighlightText()
	end
end

function ErrorFrame.__private:_HandleEditEscapePressed(editBox)
	if self._showingError then
		editBox:HighlightText(0, 0)
	end
	editBox:ClearFocus()
end

function ErrorFrame.__private:_HandleReloadClick()
	self._frame:Hide()
	ReloadUI()
end

function ErrorFrame.__private:_HandleCloseClick()
	self._frame:Hide()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LocalTableLookupFunc(tbl)
	local status, result = pcall(function() return ReactiveState.GetDebugInfo(tbl) end)
	return status and result ~= "" and result or nil
end
