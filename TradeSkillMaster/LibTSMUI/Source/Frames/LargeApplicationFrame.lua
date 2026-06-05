-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local private = {}
local NAV_BAR_SPACING = 16
local NAV_BAR_HEIGHT = 24
local NAV_BAR_RELATIVE_LEVEL = 21
local NAV_BAR_TOP_OFFSET = -8



-- ============================================================================
-- Element Definition
-- ============================================================================

local LargeApplicationFrame = UIElements.Define("LargeApplicationFrame", "ApplicationFrame")
LargeApplicationFrame:_ExtendStateSchema()
	:AddOptionalNumberField("pulsingButtonIndex")
	:AddOptionalNumberField("selectedButtonIndex")
	:AddOptionalNumberField("mouseOverButtonIndex")
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function LargeApplicationFrame:__init()
	self.__super:__init()
	self._buttons = {} ---@type FlashingButton[]
	self._buttonText = {}
end

function LargeApplicationFrame:Acquire()
	self:SetContentFrame(UIElements.New("Frame", "content")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("FRAME_BG")
	)
	self.__super:Acquire()
end

function LargeApplicationFrame:Release()
	wipe(self._buttons)
	wipe(self._buttonText)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the context table which is used to persist position and size info.
---@param tbl table The context table
---@param defaultTbl table Default values (required attributes: `width`, `height`, `centerX`, `centerY`, `page`)
---@return LargeApplicationFrame
function LargeApplicationFrame:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.page)
	self._state:PublisherForKeyChange("selectedButtonIndex")
		:IgnoreNil()
		:AssignToTableKey(tbl, "page")
	self._state.selectedButtonIndex = tbl.page or defaultTbl.page
	self.__super:SetContextTable(tbl, defaultTbl)
	return self
end

---Adds a top-level navigation button.
---@param text string The button text
---@param drawCallback fun(frame: LargeApplicationFrame) The function called when the button is clicked to get the corresponding content
---@return LargeApplicationFrame
function LargeApplicationFrame:AddNavButton(text, drawCallback)
	local button = UIElements.New("FlashingButton", "NavBar_"..text)
		:SetRelativeLevel(NAV_BAR_RELATIVE_LEVEL)
		:SetContext(drawCallback)
		:SetText(text)
		:SetFont("BODY_BODY1_BOLD")
		:SetScript("OnEnter", self:__closure("_HandleButtonEnter"))
		:SetScript("OnLeave", self:__closure("_HandleButtonLeave"))
		:SetScript("OnClick", self:__closure("_HandleButtonClick"))
	self:AddChildNoLayout(button)
	tinsert(self._buttons, button)
	local index = #self._buttons

	self._state:PublisherForKeyChange("pulsingButtonIndex")
		:MapBooleanEquals(index)
		:CallMethod(button, "SetPlaying")
	self._state:PublisherForKeys("selectedButtonIndex", "mouseOverButtonIndex")
		:MapWithFunction(private.StateToButtonTextColor, index)
		:CallMethod(button, "SetTextColor")

	self._buttonText[index] = text
	self._buttonText[text] = index
	if self._buttonText[text] == self._state.selectedButtonIndex then
		self._contentFrame:ReleaseAllChildren()
		self._contentFrame:AddChild(drawCallback(self))
	end

	return self
end

---Set the selected nav button.
---@param buttonText string The button text
---@param redraw boolean Whether or not to redraw the frame
function LargeApplicationFrame:SetSelectedNavButton(buttonText, redraw)
	local index = self._buttonText[buttonText]
	if index == self._state.selectedButtonIndex then
		return
	end
	self._state.selectedButtonIndex = index
	self._contentFrame:ReleaseAllChildren()
	self._contentFrame:AddChild(self._buttons[index]:GetContext()(self))
	if redraw then
		self:Draw()
	end
	return self
end

---Get the selected nav button.
---@return string
function LargeApplicationFrame:GetSelectedNavButton()
	return self._buttonText[self._state.selectedButtonIndex]
end

---Sets which nav button is pulsing.
---@param buttonText? string The button text or nil if no nav button should be pulsing
function LargeApplicationFrame:SetPulsingNavButton(buttonText)
	self._state.pulsingButtonIndex = buttonText and self._buttonText[buttonText] or nil
end

function LargeApplicationFrame:Draw()
	-- DEBUG: Log Draw() start
	if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
		local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
		if currentLog then
			local frame = self:_GetBaseFrame()
			local frameWidth = frame:GetWidth()
			table.insert(currentLog, string.format("  DRAW_START: frameWidth=%.1f", frameWidth))
		end
	end

	self.__super:Draw()
	for _, button in ipairs(self._buttons) do
		button:Draw()
		button:SetSize(button:GetStringWidth(), NAV_BAR_HEIGHT)
	end

	local offsetX = 104
	for i, button in ipairs(self._buttons) do
		local buttonWidth = button:GetStringWidth()
		button:SetSize(buttonWidth, NAV_BAR_HEIGHT)
		button:WipeAnchors()
		button:AddAnchor("TOPLEFT", offsetX, NAV_BAR_TOP_OFFSET)

		-- DEBUG: Log button positioning
		if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
			local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
			if currentLog then
				table.insert(currentLog, string.format("  DRAW_BTN[%d]: offsetX=%.1f buttonWidth=%.1f nextOffset=%.1f",
					i, offsetX, buttonWidth, offsetX + buttonWidth + NAV_BAR_SPACING))
			end
		end

		offsetX = offsetX + buttonWidth + NAV_BAR_SPACING
		-- Draw the buttons again now that we know their dimensions
		button:Draw()
	end

	-- DEBUG: Log Draw() end
	if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
		local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
		if currentLog then
			local frame = self:_GetBaseFrame()
			local frameWidth = frame:GetWidth()
			table.insert(currentLog, string.format("  DRAW_END: frameWidth=%.1f totalButtonWidth=%.1f", frameWidth, offsetX))
		end
	end
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function LargeApplicationFrame.__protected:_SetResizing(resizing)
	for _, button in ipairs(self._buttons) do
		button:SetShown(not resizing)
	end
	self.__super:_SetResizing(resizing)
end

function LargeApplicationFrame.__private:_HandleButtonEnter(button)
	self._state.mouseOverButtonIndex = self._buttonText[button:GetText()]
end

function LargeApplicationFrame.__private:_HandleButtonLeave(button)
	self._state.mouseOverButtonIndex = nil
end

function LargeApplicationFrame.__private:_HandleButtonClick(button)
	self:SetSelectedNavButton(button:GetText(), true)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.StateToButtonTextColor(state, index)
	if state.selectedButtonIndex == index then
		return "INDICATOR"
	elseif state.mouseOverButtonIndex == index then
		return "TEXT"
	else
		return "TEXT_ALT"
	end
end
