-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local private = {}
local BUTTON_HEIGHT = 24
local BUTTON_PADDING_BOTTOM = 2
local LINE_PADDING_TOP = 2
local LINE_THICKNESS = 2



-- ============================================================================
-- Element Definition
-- ============================================================================

local TabGroup = UIElements.Define("TabGroup", "ViewContainer")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function TabGroup:__init()
	self.__super:__init()
	self._buttons = {}
	self._buttonsFrame = nil
	self._theme = "NORMAL"
end

function TabGroup:Acquire()
	self._buttonsFrame = UIElements.New("Frame", "buttons")
		:SetLayout("HORIZONTAL")
		:AddAnchor("TOPLEFT")
		:AddAnchor("TOPRIGHT")
	self:_AddChild(self._buttonsFrame)
	self.__super:Acquire()
end

function TabGroup:Release()
	wipe(self._buttons)
	self._buttonsFrame = nil
	self._theme = "NORMAL"
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the tab group theme.
---@param theme "NORMAL"|"SIMPLE"
---@return TabGroup
function TabGroup:SetTheme(theme)
	assert(theme == "NORMAL" or theme == "SIMPLE")
	self._theme = theme
	return self
end

function TabGroup.Draw(self)
	self.__super.__super:Draw()
	local selectedPath = self:GetPath()
	self._buttonsFrame:SetHeight(self:_GetContentPadding("TOP"))

	-- In 3.3.5 TOPLEFT+TOPRIGHT anchors don't update width synchronously
	-- Use self._width (set by ViewContainer via _SetDimension) instead of GetWidth()
	local parentWidth = self._width or self:_GetDimension("WIDTH")
	if parentWidth and parentWidth > 0 then
		self._buttonsFrame:_GetBaseFrame():SetWidth(parentWidth)
	end

	self._buttonsFrame:ReleaseAllChildren()

	local buttonsFrameWidth = self._buttonsFrame:_GetBaseFrame():GetWidth()

	-- Calculate button width to fit available space (3.3.5 fix)
	local numButtons = #self._pathsList
	local buttonWidth = nil
	if buttonsFrameWidth > 0 and numButtons > 0 then
		-- Each button has 8px margin on each side (16px total per button)
		local totalMargins = numButtons * 16
		local availableWidth = buttonsFrameWidth - totalMargins
		buttonWidth = availableWidth / numButtons
	end

	for i, buttonPath in ipairs(self._pathsList) do
		local isSelected = buttonPath == selectedPath
		if self._theme == "SIMPLE" then
			local btn = UIElements.New("Button", self._id.."_Tab"..i)
				:SetMargin(8, 8, 0, BUTTON_PADDING_BOTTOM)
				:SetJustifyH("LEFT")
				:SetFont("BODY_BODY1_BOLD")
				:SetTextColor(isSelected and "INDICATOR" or "TEXT_ALT")
				:SetContext(self)
				:SetText(buttonPath)
				:SetScript("OnEnter", not isSelected and private.OnButtonEnter)
				:SetScript("OnLeave", not isSelected and private.OnButtonLeave)
				:SetScript("OnClick", private.OnButtonClicked)
			if buttonWidth then
				btn:SetWidth(buttonWidth)
			else
				btn:SetWidth("AUTO")
			end
			self._buttonsFrame:AddChild(btn)
		elseif self._theme == "NORMAL" then
			local frame = UIElements.New("Frame", self._id.."_Tab"..i)
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("Button", "button")
					:SetMargin(0, 0, 0, BUTTON_PADDING_BOTTOM)
					:SetFont("BODY_BODY1_BOLD")
					:SetJustifyH("CENTER")
					:SetTextColor(isSelected and "INDICATOR" or "TEXT_ALT")
					:SetContext(self)
					:SetText(buttonPath)
					:SetScript("OnEnter", not isSelected and private.OnButtonEnter)
					:SetScript("OnLeave", not isSelected and private.OnButtonLeave)
					:SetScript("OnClick", private.OnButtonClicked)
				)
				:AddChild(UIElements.New("Texture", "line")
					:SetMargin(0, 0, LINE_PADDING_TOP, 0)
					:SetHeight(LINE_THICKNESS)
					:SetColor(isSelected and "INDICATOR" or "TEXT_ALT")
				)
			if buttonWidth then
				frame:SetWidth(buttonWidth)
			end
			self._buttonsFrame:AddChild(frame)
		else
			error("Invalid theme: "..tostring(self._theme))
		end
	end
	self._buttonsFrame:Draw()
	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function TabGroup:_GetContentPadding(side)
	if side == "TOP" then
		if self._theme == "NORMAL" then
			return BUTTON_HEIGHT + BUTTON_PADDING_BOTTOM + LINE_THICKNESS + LINE_PADDING_TOP
		elseif self._theme == "SIMPLE" then
			return BUTTON_HEIGHT + BUTTON_PADDING_BOTTOM
		else
			error("Invalid theme: "..tostring(self._theme))
		end
	end
	return self.__super:_GetContentPadding(side)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.OnButtonEnter(button)
	button:SetTextColor("TEXT")
		:Draw()
end

function private.OnButtonLeave(button)
	button:SetTextColor("TEXT_ALT")
		:Draw()
end

function private.OnButtonClicked(button)
	local self = button:GetContext()
	local path = button:GetText()
	self:SetPath(path, self:GetPath() ~= path)
end
