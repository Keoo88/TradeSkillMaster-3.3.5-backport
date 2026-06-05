-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local StaticPopupDialog = LibTSMWoW:DefineClassType("StaticPopupDialog")



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Create a new static popup dialog.
---@return StaticPopupDialog
function StaticPopupDialog.__static.New()
	return StaticPopupDialog()
end

---Show a static popup dialog with a single "Ok" button to accept.
---@param text string The description text
function StaticPopupDialog.__static.ShowWithOk(text)
	StaticPopupDialog()
		:SetText(text)
		:SetAcceptButtonText(OKAY)
		:Show()
end



-- ============================================================================
-- StaticPopupDialog Class
-- ============================================================================

function StaticPopupDialog.__private:__init()
	self._name = "TSM_"..gsub(tostring(self), ":", "")
	self._wowObj = {
		timeout = 0,
		whileDead = true,
	}
	StaticPopupDialogs[self._name] = self._wowObj
end

---Sets the text to be shown in the dialog.
---@param text string The text
---@return StaticPopupDialog
function StaticPopupDialog:SetText(text)
	self._wowObj.text = text
	return self
end

---Sets the text to be shown in a single accept button.
---@param text string The text
---@return StaticPopupDialog
function StaticPopupDialog:SetAcceptButtonText(text)
	self._wowObj.button1 = text
	return self
end

---Sets the dialog options to yes/no.
---@return StaticPopupDialog
function StaticPopupDialog:SetYesNo()
	self._wowObj.button1 = YES
	self._wowObj.button2 = NO
	return self
end

---Sets the dialog to hide on the escape button being pressed.
---@return StaticPopupDialog
function StaticPopupDialog:HideOnEscape()
	self._wowObj.hideOnEscape = true
	return self
end

---Registers a script handler.
---@param script "OnAccept"|"OnCancel"
---@param handler fun() The handler
---@return StaticPopupDialog
function StaticPopupDialog:SetScript(script, handler)
	assert(script == "OnAccept" or script == "OnCancel")
	assert(not self._wowObj[script] and handler)
	self._wowObj[script] = handler
	return self
end

---Shows the dialog.
function StaticPopupDialog:Show()
	self._wowObj.preferredIndex = 4
	StaticPopup_Show(self._name)
	for i = 1, 100 do
		if _G["StaticPopup" .. i] and _G["StaticPopup" .. i].which == self._name then
			_G["StaticPopup" .. i]:SetFrameStrata("TOOLTIP")
			break
		end
	end
end
