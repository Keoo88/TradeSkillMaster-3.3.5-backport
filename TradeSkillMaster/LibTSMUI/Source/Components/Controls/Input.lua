-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ItemLinked = LibTSMUI:Include("Util.ItemLinked")
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {}
local PADDING_LEFT = 8
local PADDING_RIGHT = 8
local PADDING_TOP_BOTTOM = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local Input = UIElements.Define("Input", "BaseInput")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function Input:__init()
	local frame = self:_CreateEditBox()
	self.__super:__init(frame, frame)

	self._hintText = self:_CreateFontString(frame)
	self._hintText:SetJustifyH("LEFT")
	self._hintText:SetJustifyV("MIDDLE")
	self._hintText:SetPoint("TOPLEFT", PADDING_LEFT, 0)
	self._hintText:SetPoint("BOTTOMRIGHT", -PADDING_RIGHT, 0)

	self._icon = self:_CreateTexture(frame)
	self._icon:SetPoint("RIGHT", -PADDING_RIGHT / 2, 0)

	self._clearBtn = self:_CreateButton(frame)
	self._clearBtn:SetAllPoints(self._icon)
	self._clearBtn:TSMSetScript("OnClick", self:__closure("_ClearBtnOnClick"))

	self._subIcon = self:_CreateTexture(frame)
	self._subIcon:SetPoint("LEFT", PADDING_LEFT / 2, 0)
	self._subIcon:TSMSetTextureAndSize("iconPack.14x14/Subtract/Default")

	self._subBtn = self:_CreateButton(frame)
	self._subBtn:SetAllPoints(self._subIcon)
	self._subBtn:TSMSetScript("OnClick", self:__closure("Subtract"))
	self._subBtn:TSMSetPropagate("OnEnter")
	self._subBtn:TSMSetPropagate("OnLeave")

	self._addIcon = self:_CreateTexture(frame)
	self._addIcon:SetPoint("RIGHT", -PADDING_RIGHT / 2, 0)
	self._addIcon:TSMSetTextureAndSize("iconPack.14x14/Add/Default")

	self._addBtn = self:_CreateButton(frame)
	self._addBtn:SetAllPoints(self._addIcon)
	self._addBtn:TSMSetScript("OnClick", self:__closure("Add"))
	self._addBtn:TSMSetPropagate("OnEnter")
	self._addBtn:TSMSetPropagate("OnLeave")

	frame:TSMSetScript("OnEnter", self:__closure("_OnEnter"))
	frame:TSMSetScript("OnLeave", self:__closure("_OnLeave"))

	local function ItemLinkedCallback(name, link)
		if self._allowItemInsert == nil or not self:IsVisible() or not self:HasFocus() then
			return
		end
		if self._allowItemInsert == true then
			self._editBox:Insert(link)
		else
			self._editBox:Insert(name)
		end
		return true
	end
	ItemLinked.RegisterCallback(ItemLinkedCallback)

	self._clearEnabled = false
	self._subAddEnabled = false
	self._iconTexture = nil
	self._autoComplete = nil
	self._allowItemInsert = nil
	self._lostFocusOnButton = false
	self._onEnterHandler = nil
	self._onLeaveHandler = nil
end

function Input:Acquire()
	self.__super:Acquire()

	-- Set the hint text
	self._state:PublisherForKeyChange("font")
		:CallMethod(self._hintText, "TSMSetFont")
	self._state:PublisherForKeyChange("font")
		:CallMethod(self._hintText, "TSMSetFont")
	self._state:PublisherForKeys("backgroundIsLight", "disabled")
		:MapWithFunction(private.StateToHintTextColor)
		:CallMethod(self._hintText, "TSMSetTextColor")
end

function Input:Release()
	self._clearEnabled = false
	self._subAddEnabled = false
	self._iconTexture = nil
	self._autoComplete = nil
	self._allowItemInsert = nil
	self._lostFocusOnButton = false
	self._onEnterHandler = nil
	self._onLeaveHandler = nil
	self._hintText:SetText("")
	self.__super:Release()
end

---Sets the horizontal justification of the hint text.
---@param justifyH string The horizontal justification (either "LEFT", "CENTER" or "RIGHT")
---@return Input
function Input:SetHintJustifyH(justifyH)
	assert(justifyH == "LEFT" or justifyH == "CENTER" or justifyH == "RIGHT")
	self._hintText:SetJustifyH(justifyH)
	return self
end

---Sets the vertical justification of the hint text.
---@param justifyV string The vertical justification (either "TOP", "MIDDLE" or "BOTTOM")
---@return Input
function Input:SetHintJustifyV(justifyV)
	assert(justifyV == "TOP" or justifyV == "MIDDLE" or justifyV == "BOTTOM")
	self._hintText:SetJustifyV(justifyV)
	return self
end

---Sets the auto complete table.
---@param tbl table A list of strings to auto-complete to
---@return Input
function Input:SetAutoComplete(tbl)
	assert(type(tbl) == "table")
	self._autoComplete = tbl
	return self
end

---Sets the hint text.
-- The hint text is shown when there's no other text in the input.
---@param text string The hint text
---@return Input
function Input:SetHintText(text)
	self._hintText:SetText(text)
	return self
end

---Sets whether or not the clear button is enabled.
---@param enabled boolean Whether or not the clear button is enabled
---@return Input
function Input:SetClearButtonEnabled(enabled)
	assert(type(enabled) == "boolean")
	assert(not self._subAddEnabled)
	self._clearEnabled = enabled
	return self
end

---Sets whether or not the sub/add buttons are enabled.
---@param enabled boolean Whether or not the sub/add buttons are enabled
---@return Input
function Input:SetSubAddEnabled(enabled)
	assert(type(enabled) == "boolean")
	assert(not self._clearEnabled and not self._iconTexture)
	self._subAddEnabled = enabled
	return self
end

---Sets the icon texture.
---@param iconTexture? string The texture string to use for the icon texture
---@return Input
function Input:SetIconTexture(iconTexture)
	assert(iconTexture == nil or TextureAtlas.IsValid(iconTexture))
	assert(not self._subAddEnabled)
	self._iconTexture = iconTexture
	return self
end

---Allows inserting an item into the input by linking it while the input has focus.
---@param insertLink boolean Insert the link instead of the item name
---@return Input
function Input:AllowItemInsert(insertLink)
	assert(insertLink == true or insertLink == false or insertLink == nil)
	self._allowItemInsert = insertLink or false
	return self
end

---Subtract from the input.
---@return Input
function Input:Subtract()
	local minVal = self._validateContext and strsplit(":", self._validateContext)
	local value = tostring(max(tonumber(self:GetValue()) - (IsShiftKeyDown() and 10 or 1), minVal or -math.huge))
	if self:_SetValueHelper(value) then
		self._escValue = self._value
		self:_GetBaseFrame():SetText(value)
		self:_UpdateIconsForValue(value)
	end
	return self
end

---Add to the input.
---@return Input
function Input:Add()
	local _, maxVal = nil, nil
	if self._validateContext then
		_, maxVal = strsplit(":", self._validateContext)
	end
	local value = tostring(min(tonumber(self:GetValue()) + (IsShiftKeyDown() and 10 or 1), maxVal or math.huge))
	if self:_SetValueHelper(value) then
		self._escValue = self._value
		self:_GetBaseFrame():SetText(value)
		self:_UpdateIconsForValue(value)
	end
	return self
end

---Registers a script handler.
---@param script string The script to register for
---@param handler? function The script handler which should be called
---@return Input
function Input:SetScript(script, handler)
	if script == "OnEnter" then
		self._onEnterHandler = handler
	elseif script == "OnLeave" then
		self._onLeaveHandler = handler
	else
		return self.__super:SetScript(script, handler)
	end
	return self
end

function Input:Draw()
	self.__super:Draw()
	self:_UpdateIconsForValue(self._value)
end



-- ============================================================================
-- Protected Class Methods
-- ============================================================================

function Input.__protected:_OnTextChanged(value)
	self:_UpdateIconsForValue(value)
end

function Input.__protected:_ShouldKeepFocus()
	if not IsMouseButtonDown("LeftButton") then
		return false
	end
	if self._clearBtn:IsVisible() and self._clearBtn:IsMouseOver() then
		return true
	elseif self._subBtn:IsVisible() and self._subBtn:IsMouseOver() then
		return true
	elseif self._addBtn:IsVisible() and self._addBtn:IsMouseOver() then
		return true
	else
		return false
	end
end

function Input.__protected:_OnChar(c)
	self.__super:_OnChar(c)
	if not self._autoComplete then
		return
	end
	local frame = self:_GetBaseFrame()
	local text = frame:GetText()
	local match = nil
	for _, k in ipairs(self._autoComplete) do
		local start, ending = strfind(strlower(k), strlower(text), 1, true)
		if start == 1 and ending and ending == #text then
			match = k
			break
		end
	end
	if match and not IsControlKeyDown() then
		local compStart = #text
		frame:SetText(match)
		self:HighlightText(compStart, #match)
		frame:GetScript("OnTextChanged")(frame, true)
	end
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function Input.__private:_UpdateIconsForValue(value)
	local frame = self:_GetBaseFrame() ---@type EditBoxExtended
	local leftPadding, rightPadding = PADDING_LEFT, PADDING_RIGHT

	-- Set the hint text
	if value == "" and self._hintText:GetText() ~= "" then
		self._hintText:Show()
	else
		self._hintText:Hide()
	end

	local showSubAdd = self._subAddEnabled and (frame:IsMouseOver() or frame:HasFocus())
	if showSubAdd then
		self._subIcon:Show()
		self._subBtn:Show()
		self._addIcon:Show()
		self._addBtn:Show()
	else
		self._subIcon:Hide()
		self._subBtn:Hide()
		self._addIcon:Hide()
		self._addBtn:Hide()
	end

	-- Set the icon
	local iconColorKey = self._state.backgroundIsLight and "FULL_BLACK" or "FULL_WHITE"
	if self._state.disabled then
		iconColorKey = iconColorKey..(self._state.backgroundIsLight and "-DISABLED" or "+DISABLED")
	end
	local iconTexture = nil
	if self._clearEnabled and value ~= "" then
		self._clearBtn:Show()
		iconTexture = TextureAtlas.GetColoredKey("iconPack.18x18/Close/Default", iconColorKey)
	else
		self._clearBtn:Hide()
		iconTexture = not frame:HasFocus() and self._iconTexture and TextureAtlas.GetColoredKey(self._iconTexture, iconColorKey) or nil
	end
	if iconTexture then
		assert(not showSubAdd)
		self._icon:Show()
		self._icon:TSMSetTextureAndSize(iconTexture)
		rightPadding = rightPadding + TextureAtlas.GetWidth(iconTexture)
	else
		self._icon:Hide()
	end
	frame:SetTextInsets(leftPadding, rightPadding, PADDING_TOP_BOTTOM, PADDING_TOP_BOTTOM)
	-- For some reason the text insets don't take effect right away, so on the next frame, we call GetTextInsets() which seems to fix things
	frame:TSMSetOnUpdate(self:__closure("_FrameOnUpdate"))
end

function Input.__private:_FrameOnUpdate()
	local frame = self:_GetBaseFrame() ---@type EditBoxExtended
	frame:TSMSetOnUpdate(nil)
	frame:GetTextInsets()
end

function Input.__private:_ClearBtnOnClick()
	assert(self:_SetValueHelper(""))
	self._escValue = ""
	self._editBox:SetText(self._value)
	self:Draw()
end

function Input.__private:_OnEnter()
	self:_UpdateIconsForValue(self._value)
	if self._onEnterHandler then
		self:_onEnterHandler()
	end
end

function Input.__private:_OnLeave()
	self:_UpdateIconsForValue(self._value)
	if self._onLeaveHandler then
		self:_onLeaveHandler()
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToHintTextColor(state)
	-- The text color should have maximum contrast with the input color, so set it to white/black based on the input color
	local colorKey = state.backgroundIsLight and "FULL_BLACK" or "FULL_WHITE"
	if state.disabled then
		return colorKey..(state.backgroundIsLight and "-DISABLED" or "+DISABLED")
	else
		return colorKey..(state.backgroundIsLight and "+HOVER" or "-HOVER")
	end
end
