-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ListRow = LibTSMUI:DefineClassType("ListRow")
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Reactive = LibTSMUI:From("LibTSMUtil"):Include("Reactive")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local DelayTimer = LibTSMUI:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local private = {
	tooltipTimer = nil,
	tooltipRow = nil,
	tooltipValue = nil,
}
local LONG_TEXT_TOOLTIP_DELAY = 1

---@class ListRow
---@field _state ReactiveState



-- ============================================================================
-- Element Definition
-- ============================================================================

ListRow._STATE_SCHEMA = Reactive.CreateStateSchema("LIST_ROW_STATE")
	:AddStringField("backgroundColor", "PRIMARY_BG", Theme.IsValidColor)
	:AddBooleanField("isHovering", false)
	:AddBooleanField("highlightDisabled", false)
	:AddBooleanField("isSelected", false)
	:AddBooleanField("showHoverHighlight", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ListRow:__init()
	if not private.tooltipTimer then
		private.tooltipTimer = DelayTimer.New("LIST_ROW_TOOLTIP_TIMER", private.HandleTooltipTimer)
	end
	self._cancellables = {}
	self._state = self._STATE_SCHEMA:CreateState()
		:SetAutoStore(self._cancellables)
	self._frameEventHandler = nil
	self._dataIndex = nil
	self._used = {
		texts = {}, ---@type table<string,FontStringExtended>
		textures = {}, ---@type table<string,TextureExtended>
		rotatingTextures = {}, ---@type table<string,TextureExtended>
		buttons = {}, ---@type table<string,ButtonExtended>
	}
	self._recycled = {
		texts = {}, ---@type FontStringExtended[]
		textures = {}, ---@type TextureExtended[]
		rotatingTextures = {}, ---@type TextureExtended[]
		buttons = {}, ---@type ButtonExtended[]
	}
	self._tooltipDataFunc = {}
	self._clickFunc = {}

	local frame = UIElements.CreateButton(self)
	self._frame = frame
	frame:TSMSetDebugObject(self)
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:TSMSetCancellablesTable(self._cancellables)
	frame:TSMSetScript("OnEnter", self:__closure("_FrameOnEnter"))
	frame:TSMSetScript("OnLeave", self:__closure("_FrameOnLeave"))
	frame:TSMSetScript("OnClick", self:__closure("_FrameOnClick"))
	frame:TSMSetScript("OnDoubleClick", self:__closure("_FrameOnDoubleClick"))
	frame:TSMSetScript("OnMouseDown", self:__closure("_FrameOnMouseDown"))

	frame.background = UIElements.CreateTexture(self, frame, "BACKGROUND")
	frame.background:TSMSetCancellablesTable(self._cancellables)
	frame.background:SetAllPoints()

	-- We create separate highlight textures for each state as there seems to be a bug in the game's
	-- engine where :SetColorTexture() can take way longer than it should.
	frame.highlightHover = UIElements.CreateTexture(self, frame, "ARTWORK", -1)
	frame.highlightHover:TSMSetCancellablesTable(self._cancellables)
	frame.highlightHover:SetAllPoints()
	frame.highlightHover:Hide()

	frame.highlightSelected = UIElements.CreateTexture(self, frame, "ARTWORK", -1)
	frame.highlightSelected:TSMSetCancellablesTable(self._cancellables)
	frame.highlightSelected:SetAllPoints()
	frame.highlightSelected:Hide()

	frame.highlightSelectedHover = UIElements.CreateTexture(self, frame, "ARTWORK", -1)
	frame.highlightSelectedHover:TSMSetCancellablesTable(self._cancellables)
	frame.highlightSelectedHover:SetAllPoints()
	frame.highlightSelectedHover:Hide()
end

function ListRow:Acquire(parentFrame, height, frameEventHandler)
	self._frameEventHandler = frameEventHandler
	local frame = self._frame
	frame:SetParent(parentFrame)
	frame:SetHeight(height)
	-- In 3.3.5 SetParent doesn't automatically show the frame
	frame:Show()

	-- Computed state properties
	self._state:PublisherForExpression([[isHovering and not highlightDisabled]])
		:AssignToTableKey(self._state, "showHoverHighlight")

	-- Set the background color
	self._state:PublisherForKeyChange("backgroundColor")
		:CallMethod(frame.background, "TSMSubscribeColorTexture")

	-- Set the various highlight states and colors
	self._state:PublisherForExpression([[showHoverHighlight and not isSelected]])
		:CallMethod(frame.highlightHover, "TSMSetShown")
	self._state:PublisherForKeyChange("backgroundColor")
		:MapWithFunction(private.AddStringSuffix, "+HOVER")
		:CallMethod(frame.highlightHover, "TSMSubscribeColorTexture")
	self._state:PublisherForExpression([[not showHoverHighlight and isSelected]])
		:CallMethod(frame.highlightSelected, "TSMSetShown")
	self._state:PublisherForKeyChange("backgroundColor")
		:MapWithFunction(private.AddStringSuffix, "+SELECTED")
		:CallMethod(frame.highlightSelected, "TSMSubscribeColorTexture")
	self._state:PublisherForExpression([[showHoverHighlight and isSelected]])
		:CallMethod(frame.highlightSelectedHover, "TSMSetShown")
	self._state:PublisherForKeyChange("backgroundColor")
		:MapWithFunction(private.AddStringSuffix, "+SELECTED_HOVER")
		:CallMethod(frame.highlightSelectedHover, "TSMSubscribeColorTexture")
end

---Sets the row height.
---@param height number
function ListRow:SetHeight(height)
	self._frame:SetHeight(height)
end

function ListRow:Release()
	for _, cancellable in pairs(self._cancellables) do
		cancellable:Cancel()
	end
	wipe(self._cancellables)
	self._state:ResetToDefault()
	local frame = self._frame
	frame:Hide()
	self._frameEventHandler = nil
	self._dataIndex = nil
	wipe(self._tooltipDataFunc)
	wipe(self._clickFunc)

	for key in pairs(self._used.texts) do
		self:RemoveText(key)
	end
	assert(not next(self._used.texts))

	for key in pairs(self._used.textures) do
		self:RemoveTexture(key)
	end
	assert(not next(self._used.textures))

	for texture in pairs(self._used.rotatingTextures) do
		self:RemoveRotatingTexture(texture)
	end
	assert(not next(self._used.rotatingTextures))

	for key in pairs(self._used.buttons) do
		self:RemoveButton(key)
	end
	assert(not next(self._used.buttons))

	frame:RegisterForDrag()
	frame:TSMSetScript("OnDragStart", nil)
	frame:TSMSetScript("OnDragStop", nil)
	frame:TSMSetScript("OnReceiveDrag", nil)
	frame:SetParent(nil)
	frame:ClearAllPoints()

	if private.tooltipRow == self then
		private.tooltipTimer:Cancel()
		private.tooltipRow = nil
		private.tooltipValue = nil
	end
end

---Sets the vertical offset of the row within the list.
---@param offset number
function ListRow:SetOffset(offset)
	local frame = self._frame
	local height = self._frame:GetHeight()
	frame:SetPoint("TOPLEFT", 0, -height * offset)
	frame:SetPoint("TOPRIGHT", 0, -height * offset)
end

---Sets the background color.
---@param color ThemeColorKey The background color as a theme color key
function ListRow:SetBackgroundColor(color)
	self._state.backgroundColor = color
end

---Sets the row's data index.
---@param dataIndex number The data index
function ListRow:SetDataIndex(dataIndex)
	local frame = self._frame
	-- Explicitly hide the row first in order to fire any necessary OnLeave handlers
	frame:Hide()
	self._dataIndex = dataIndex
	if dataIndex then
		frame:Show()
	end
end

---Updates the data index without redrawing the row for when the index changes but the data doesn't.
---@param dataIndex number The new data index
function ListRow:UpdateDataIndex(dataIndex)
	self._dataIndex = dataIndex
end

---Gets the data index.
---@return number
function ListRow:GetDataIndex()
	assert(self._dataIndex)
	return self._dataIndex
end

---Sets whether or not highlighting is enabled.
function ListRow:SetHighlightEnabled(enabled)
	self._state.highlightDisabled = not enabled
end

---Adds a text element to the row.
---@param key string A key to identify the text element
---@return FontStringExtended
function ListRow:AddText(key)
	assert(not self._used.texts[key])
	local text = tremove(self._recycled.texts)
	if not text then
		text = UIElements.CreateFontString(self, self._frame)
		text:TSMSetCancellablesTable(self._cancellables)
	end
	text:SetWordWrap(false)
	text:Show()
	self._used.texts[key] = text
	return text
end

---Gets an existing text element.
---@param key string The key which identifies the text element
---@return FontStringExtended
function ListRow:GetText(key)
	local text = self._used.texts[key]
	assert(text)
	return text
end

---Removes a text element from the row.
---@param key string The key which identifies the text element
function ListRow:RemoveText(key)
	local text = self._used.texts[key]
	self._used.texts[key] = nil
	text:Hide()
	text:SetText("")
	text:ClearAllPoints()
	text:SetWidth(0)
	text:SetHeight(0)
	text:SetTextColor(1, 1, 1, 1)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("MIDDLE")
	tinsert(self._recycled.texts, text)
end

---Adds a texture element to the row.
---@param key string A key to identify the texture element
---@return TextureExtended
function ListRow:AddTexture(key)
	assert(not self._used.textures[key])
	local texture = tremove(self._recycled.textures)
	if not texture then
		texture = UIElements.CreateTexture(self, self._frame)
		texture:TSMSetCancellablesTable(self._cancellables)
	end
	texture:Show()
	self._used.textures[key] = texture
	return texture
end

---Gets an existing texture element.
---@param key string The key which identifies the texture element
---@return TextureExtended
function ListRow:GetTexture(key)
	local texture = self._used.textures[key]
	assert(texture)
	return texture
end

---Removes a texture element from the row.
---@param key string The key which identifies the texture element
function ListRow:RemoveTexture(key)
	local texture = self._used.textures[key]
	self._used.textures[key] = nil
	texture:Hide()
	texture:SetDrawLayer("ARTWORK", 0)
	texture:SetTexture(nil)
	texture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	texture:SetColorTexture(0, 0, 0, 0)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:ClearAllPoints()
	texture:SetWidth(0)
	texture:SetHeight(0)
	tinsert(self._recycled.textures, texture)
end

---Adds a rotating texture element to the row.
---@param key string A key to identify the texture element
---@return TextureExtended
function ListRow:AddRotatingTexture(key)
	assert(not self._used.rotatingTextures[key])
	local texture = tremove(self._recycled.rotatingTextures)
	if not texture then
		texture = UIElements.CreateTexture(self, self._frame)
		texture:TSMSetCancellablesTable(self._cancellables)
		local ag = UIElements.CreateAnimationGroup(texture)
		texture.ag = ag
		local spin = ag:CreateAnimation("Rotation")
		spin:SetDuration(2)
		spin:SetDegrees(360)
		ag:SetLooping("REPEAT")
	end
	texture:Show()
	self._used.rotatingTextures[key] = texture
	return texture
end

---Gets an existing rotating texture element.
---@param key string The key which identifies the texture element
---@return TextureExtended
function ListRow:GetRotatingTexture(key)
	local texture = self._used.rotatingTextures[key]
	assert(texture)
	return texture
end

---Removes a rotating texture element from the row.
---@param key string The key which identifies the texture element
function ListRow:RemoveRotatingTexture(key)
	local texture = self._used.rotatingTextures[key]
	self._used.rotatingTextures[key] = nil
	texture.ag:Stop()
	texture:Hide()
	texture:SetDrawLayer("ARTWORK", 0)
	texture:SetTexture(nil)
	texture:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
	texture:SetColorTexture(0, 0, 0, 0)
	texture:SetVertexColor(1, 1, 1, 1)
	texture:ClearAllPoints()
	texture:SetWidth(0)
	texture:SetHeight(0)
	tinsert(self._recycled.rotatingTextures, texture)
end

---Adds a button element to the row.
---@param key string A key to identify the button element
---@return ButtonExtended
function ListRow:AddButton(key)
	assert(not self._used.buttons[key])
	local button = tremove(self._recycled.buttons)
	if not button then
		button = UIElements.CreateButton(self)
		button:TSMSetCancellablesTable(self._cancellables)
	end
	button:SetParent(self._frame)
	button:SetHitRectInsets(0, 0, 0, 0)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:Show()
	self._used.buttons[key] = button
	return button
end

---Gets an existing button element.
---@param key string The key which identifies the button element
---@return ButtonExtended
function ListRow:GetButton(key)
	local button = self._used.buttons[key]
	assert(button)
	return button
end

---Removes a button element from the row.
---@param key string The key which identifies the button element
function ListRow:RemoveButton(key)
	local button = self._used.buttons[key]
	self._used.buttons[key] = nil
	if button.isShowingTooltip then
		Tooltip.Hide()
		button.isShowingTooltip = nil
	end
	button:Hide()
	if button.SetMouseClickEnabled then button:SetMouseClickEnabled(true) end
	button:RegisterForDrag()
	button:SetResizable(false)
	button:SetMovable(false)
	button:TSMSetScript("OnEnter", nil)
	button:TSMSetScript("OnLeave", nil)
	button:TSMSetScript("OnClick", nil)
	button:TSMSetScript("OnMouseDown", nil)
	button:TSMSetScript("OnMouseUp", nil)
	button:TSMSetScript("OnUpdate", nil)
	button:SetParent(nil)
	button:ClearAllPoints()
	button:SetWidth(0)
	button:SetHeight(0)
	tinsert(self._recycled.buttons, button)
end

---Adds a tooltip region which overlays an existing element.
---@param key string The key which identifies the tooltip region
---@param element FontStringExtended|TextureExtended The element to overlay
---@param dataFunc fun(dataIndex: number, key: string): number|string|function|nil, boolean? The function to get the tooltip data
function ListRow:AddTooltipRegion(key, element, dataFunc)
	self:AddMouseRegion(key, element, dataFunc)
end

---Adds a tooltip region which overlays an existing element.
---@param key string The key which identifies the tooltip region
---@param element FontStringExtended|TextureExtended The element to overlay
---@param tooltipFunc fun(dataIndex: number, key: string): number|string|function|nil, boolean? The function to get the tooltip data
---@param clickFunc? fun(mouseButton: string, dataIndex: number, key: string) The function to handle clicks
function ListRow:AddMouseRegion(key, element, tooltipFunc, clickFunc)
	assert(tooltipFunc)
	assert(Table.KeyByValue(self._used.texts, element) or Table.KeyByValue(self._used.textures, element))
	local btn = self:AddButton(key)
	btn:SetAllPoints(element)
	btn:TSMSetScript("OnEnter", self:__closure("_HandleTooltipRegionOnEnter"))
	btn:TSMSetScript("OnLeave", self:__closure("_HandleTooltipRegionOnLeave"))
	if clickFunc then
		self._clickFunc[btn] = clickFunc
		btn:TSMSetScript("OnClick", self:__closure("_HandleTooltipRegionOnClick"))
	else
		btn:TSMSetPropagate("OnClick")
		btn:TSMSetPropagate("OnMouseDown")
	end
	btn:TSMSetPropagate("OnDoubleClick")
	self._tooltipDataFunc[btn] = tooltipFunc
end

---Sets whether a tooltip region is shown.
---@param key string The key which identifies the tooltip region
---@param show boolean Whether or not the region should be shown
function ListRow:SetTooltipRegionShown(key, show)
	self:GetButton(key):SetShown(show)
end

---Sets a script on the row's frame.
---@param script string The script to set
---@param handler? function The script handler
function ListRow:SetScript(script, handler)
	self._frame:TSMSetScript(script, handler, self)
end

---Shows a tooltip anchored to the row.
---@param data string|number|function The tooltip data
function ListRow:ShowTooltip(data)
	Tooltip.Show(self._frame, data)
end

---Shows a tooltip with the full contents of a text element after a delay if it doesn't fit.
---@param text FontStringExtended The text element
function ListRow:ShowDelayedLongTextTooltip(text)
	if text:GetWidth() + 0.5 < text:TSMGetUnboundedStringWidth() then
		private.tooltipTimer:Cancel()
		private.tooltipRow = self
		private.tooltipValue = text:GetText()
		private.tooltipTimer:RunForTime(LONG_TEXT_TOOLTIP_DELAY)
	end
end

---Enables dragging of the list row.
---@param dragStartHandler function The OnDragStart handler
---@param dragStopHandler? function The OnDragStop handler
---@param dragRecievedHandler? function The OnReceiveDrag handler
function ListRow:EnableDragging(dragStartHandler, dragStopHandler, dragRecievedHandler)
	local frame = self._frame
	frame:RegisterForDrag("LeftButton")
	frame:TSMSetScript("OnDragStart", dragStartHandler, self)
	frame:TSMSetScript("OnDragStop", dragStopHandler, self)
	frame:TSMSetScript("OnReceiveDrag", dragRecievedHandler, self)
end

---Sets the selected state of the row.
---@param selected boolean The row is selected
function ListRow:SetSelected(selected)
	self._state.isSelected = selected
end

---Gets whether or not the mouse is hovering over the row.
---@return boolean
function ListRow:IsHovering()
	return self._state.isHovering
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ListRow.__private:_FrameOnEnter()
	self._state.isHovering = true
	self:_frameEventHandler("OnEnter")
end

function ListRow.__private:_FrameOnLeave()
	if private.tooltipRow == self then
		private.tooltipTimer:Cancel()
		private.tooltipRow = nil
		private.tooltipValue = nil
	end
	self._state.isHovering = false
	self:_frameEventHandler("OnLeave")
end

function ListRow.__private:_FrameOnClick(_, mouseButton)
	self:_frameEventHandler("OnClick", mouseButton)
end

function ListRow.__private:_FrameOnDoubleClick(_, mouseButton)
	self:_frameEventHandler("OnDoubleClick", mouseButton)
end

function ListRow.__private:_FrameOnMouseDown(_, mouseButton)
	self:_frameEventHandler("OnMouseDown", mouseButton)
end

function ListRow.__private:_HandleTooltipRegionOnEnter(btn)
	local key = Table.KeyByValue(self._used.buttons, btn)
	assert(key)
	local data, noWrap = self._tooltipDataFunc[btn](self:GetDataIndex(), key)
	if data then
		Tooltip.Show(btn, data, noWrap)
	end
	self:_FrameOnEnter()
end

function ListRow.__private:_HandleTooltipRegionOnLeave()
	Tooltip.Hide()
	self:_FrameOnLeave()
end

function ListRow.__private:_HandleTooltipRegionOnClick(btn, mouseButton)
	local key = Table.KeyByValue(self._used.buttons, btn)
	assert(key)
	self._clickFunc[btn](mouseButton, self:GetDataIndex(), key)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.AddStringSuffix(str, suffix)
	return str..suffix
end

function private.HandleTooltipTimer()
	local row = private.tooltipRow
	private.tooltipRow = nil
	local value = private.tooltipValue
	private.tooltipValue = nil
	row:ShowTooltip(value)
end
