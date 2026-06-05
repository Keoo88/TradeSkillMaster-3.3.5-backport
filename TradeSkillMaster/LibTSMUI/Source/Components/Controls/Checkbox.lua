-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local THEME_TEXTURES = {
	RADIO = {
		checked = "iconPack.Misc/Radio/Checked",
		unchecked = "iconPack.Misc/Radio/Unchecked",
	},
	CHECK = {
		checked = "iconPack.Misc/Checkbox/Checked",
		unchecked = "iconPack.Misc/Checkbox/Unchecked",
	},
}
local CHECKBOX_SPACING = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local Checkbox = UIElements.Define("Checkbox", "Text")
Checkbox:_ExtendStateSchema()
	:UpdateFieldDefault("font", "BODY_BODY3")
	:AddStringField("theme", "CHECK", private.ValidateTheme)
	:AddBooleanField("checked", false)
	:AddBooleanField("enabled", true)
	:AddStringField("enabledColor", "TEXT", Theme.IsValidColor)
	:Commit()
Checkbox:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Checkbox:__init()
	local frame = self:_CreateButton()
	self.__super:__init(frame)
	frame:TSMSetScript("OnClick", self:__closure("_HandleClick"))

	-- Create the check texture
	frame.check = self:_CreateTexture(frame)

	-- Layout the text and check
	frame.text:ClearAllPoints()
	frame.check:ClearAllPoints()
	frame.check:SetPoint("LEFT")
	frame.text:SetJustifyH("LEFT")
	frame.text:SetPoint("LEFT", frame.check, "RIGHT", CHECKBOX_SPACING, 0)
	frame.text:SetPoint("TOPRIGHT")
	frame.text:SetPoint("BOTTOMRIGHT")

	self._onValueChangedHandler = nil
	self._settingTable = nil
	self._settingKey = nil
end

function Checkbox:Acquire()
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()

	-- Set the check texture
	self._state:PublisherForKeys("theme", "checked")
		:MapWithFunction(private.StateToCheckTexture)
		:CallMethod(frame.check, "TSMSetTextureAndSize")

	-- Set the text color
	self._state:PublisherForKeys("enabled", "enabledColor")
		:MapWithFunction(private.StateToTextColor)
		:AssignToTableKey(self._state, "color")

	-- Set the check alpha
	self._state:PublisherForKeyChange("enabled")
		:MapWithFunction(private.EnabledToCheckAlpha)
		:CallMethod(frame.check, "SetAlpha")

	-- Set the enabled / disabled state
	self._state:PublisherForKeyChange("enabled")
		:CallMethod(frame, "TSMSetEnabled")
end

function Checkbox:Release()
	self._onValueChangedHandler = nil
	self._settingTable = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the color of the text when not disabled.
---@param color ThemeColorKey The text color as a theme color key
---@return Checkbox
function Checkbox:SetTextColor(color)
	self._state.enabledColor = color
	return self
end

---Sets the checkbox theme
---@param theme "RADIO"|"CHECK" The checkbox theme
---@return Checkbox
function Checkbox:SetTheme(theme)
	self._state.theme = theme
	return self
end

---Sets whether or not the checkbox is disabled.
---@param disabled boolean Whether or not the checkbox is disabled
---@return Checkbox
function Checkbox:SetDisabled(disabled)
	self._state.enabled = not disabled
	return self
end

---Sets whether or not the checkbox is checked.
---@param value boolean Whether or not the checkbox is checked
---@param silent boolean If true, will not trigger the `OnValueChanged` script
---@return Checkbox
function Checkbox:SetChecked(value, silent)
	self:SetCheckedSilent(value)
	if not silent then
		self:_SendActionScript("OnValueChanged")
		if self._onValueChangedHandler then
			self:_onValueChangedHandler(value)
		end
	end
	return self
end

---Sets whether or not the checkbox is checked without calling the value changed handler.
---@param value boolean Whether or not the checkbox is checked
---@return Checkbox
function Checkbox:SetCheckedSilent(value)
	self._state.checked = value and true or false
	return self
end

---Subscribes to a publisher to set whether or not the checkbox is checked silently.
---@param publisher ReactivePublisher The publisher
---@return Checkbox
function Checkbox:SetCheckedSilentPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetCheckedSilent"))
	return self
end

---Sets the setting info.
---
---This method is used to have the state of the checkbox automatically correspond with the boolean state of a field in
---a table. This is useful for checkboxes which are tied directly to settings.
---@param tbl table The table which the field to set belongs to
---@param key string The key into the table to be set based on the checkbox state
---@return Checkbox
function Checkbox:SetSettingInfo(tbl, key)
	self._settingTable = tbl
	self._settingKey = key
	self:SetChecked(tbl[key])
	return self
end

---Gets the checked state.
---@return boolean
function Checkbox:IsChecked()
	return self._state.checked
end

---Registers a script handler.
---@param script string The script to register for (supported scripts: `OnValueChanged`)
---@param handler function The script handler which will be called with the checkbox object followed by any arguments
---to the script
---@return Checkbox
function Checkbox:SetScript(script, handler)
	if script == "OnValueChanged" then
		self._onValueChangedHandler = handler
	elseif script == "OnEnter" or script == "OnLeave" then
		return self.__super:SetScript(script, handler)
	else
		error("Unknown Checkbox script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Checkbox.__private:_HandleClick()
	local value = not self._state.checked
	if self._settingTable and self._settingKey then
		self._settingTable[self._settingKey] = value
	end
	self:SetChecked(value)
end

function Checkbox:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" and self._state.autoWidth then
		local checkboxWidth = TextureAtlas.GetWidth(THEME_TEXTURES[self._state.theme].checked)
		return self:GetStringWidth() + CHECKBOX_SPACING + checkboxWidth, nil
	else
		return self.__super:_GetMinimumDimension(dimension)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateTheme(theme)
	return THEME_TEXTURES[theme] and true or false
end

function private.StateToCheckTexture(state)
	return THEME_TEXTURES[state.theme][state.checked and "checked" or "unchecked"]
end

function private.StateToTextColor(state)
	return state.enabled and state.enabledColor or "TEXT_DISABLED"
end

function private.EnabledToCheckAlpha(enabled)
	return enabled and 1 or 0.3
end
