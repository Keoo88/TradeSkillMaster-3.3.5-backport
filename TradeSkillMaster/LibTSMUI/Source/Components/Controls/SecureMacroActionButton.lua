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

local SecureMacroActionButton = UIElements.Define("SecureMacroActionButton", "ActionButton")
SecureMacroActionButton:_AddActionScripts("PreClick")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SecureMacroActionButton:__init(name)
	self.__super:__init(name, true)
	local frame = self:_GetBaseFrame()
	frame:SetAttribute("*type1", "macro")
	frame:SetAttribute("*macrotext1", "")
	frame:TSMSetScript("PreClick", self:__closure("_HandlePreClick"))
	self._preClickHandler = nil
end

function SecureMacroActionButton:Acquire()
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()
	frame:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "LeftButtonDown" or "LeftButtonUp")
end

function SecureMacroActionButton:Release()
	self._preClickHandler = nil
	local frame = self:_GetBaseFrame()
	frame:SetAttribute("*macrotext1", "")
	self.__super:Release()
end

---Registers a script handler.
---@param script string The script to register for (supported scripts: `PreClick`)
---@param handler function The script handler which will be called with the secure macro action button object followed by any arguments to the script
---@return SecureMacroActionButton
function SecureMacroActionButton:SetScript(script, handler)
	if script == "PreClick" then
		self._preClickHandler = handler
	elseif script == "OnClick" then
		self.__super:SetScript(script, handler)
	else
		error("Unknown SecureActionButton script: "..tostring(script))
	end
	return self
end

---Sets the macro text which clicking the button executes.
---@param text string The macro text
---@return SecureMacroActionButton
function SecureMacroActionButton:SetMacroText(text)
	self:_GetBaseFrame():SetAttribute("*macrotext1", text)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SecureMacroActionButton:_HandlePreClick()
	if not self._acquired then
		return
	end
	self:_SendActionScript("PreClick")
	if self._preClickHandler then
		self:_preClickHandler()
	end
end
