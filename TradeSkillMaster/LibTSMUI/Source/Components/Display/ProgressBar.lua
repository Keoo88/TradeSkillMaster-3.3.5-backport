-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local PROGRESS_ICON_PADDING = 4
local BG_CORNER_RADIUS = 4
local BAR_CORNER_RADIUS = 2
local BORDER_THICKNESS = 2
local PROGRESS_SCALE = 1000



-- ============================================================================
-- Element Definition
-- ============================================================================

local ProgressBar = UIElements.Define("ProgressBar", "Text")
ProgressBar:_ExtendStateSchema()
	:UpdateFieldDefault("font", "BODY_BODY2_MEDIUM")
	:UpdateFieldDefault("justifyH", "CENTER")
	:UpdateFieldDefault("color", "INDICATOR")
	:AddNumberField("progress", 0)
	:AddBooleanField("iconVisible", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ProgressBar:__init()
	local frame = self:_CreateFrame()

	self.__super:__init(frame)

	frame.background = self:_CreateRectangle()
	frame.background:SetCornerRadius(BG_CORNER_RADIUS)

	frame.bar = self:_CreateRectangle(1)
	frame.bar:SetCornerRadius(BAR_CORNER_RADIUS)
	frame.bar:SetInset(BORDER_THICKNESS)

	frame.barMask = self:_CreateTexture(frame, "ARTWORK", 2)
	frame.barMask:SetPoint("TOPRIGHT", -BORDER_THICKNESS, -BORDER_THICKNESS)
	frame.barMask:SetPoint("BOTTOMRIGHT", -BORDER_THICKNESS, BORDER_THICKNESS)

	-- Create the progress icon
	frame.progressIcon = self:_CreateTexture(frame, "OVERLAY")
	frame.progressIcon:SetPoint("RIGHT", frame.text, "LEFT", -PROGRESS_ICON_PADDING, 0)
	frame.progressIcon:TSMSetTextureAndSize("iconPack.18x18/Running")

	frame.progressIcon.ag = self:_CreateAnimationGroup(frame.progressIcon)
	local spin = frame.progressIcon.ag:CreateAnimation("Rotation")
	spin:SetDuration(2)
	spin:SetDegrees(360)
	frame.progressIcon.ag:SetLooping("REPEAT")
end

function ProgressBar:Acquire()
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()
	frame.background:SubscribeColor("PRIMARY_BG")
	frame.bar:SubscribeColor("ACTIVE_BG")
	frame.barMask:TSMSubscribeColorTexture("PRIMARY_BG")

	-- Redraw when the progress or text changes
	self._state:PublisherForKeys("progress", "textStr")
		:CallMethod(self, "Draw")

	-- Set the icon color to match the text
	self._state:PublisherForKeyChange("color")
		:CallMethod(frame.progressIcon, "TSMSubscribeVertexColor")

	-- Set the icon visibility
	self._state:PublisherForKeyChange("iconVisible")
		:CallMethod(frame.progressIcon, "TSMSetShown")

	-- Set the animation playing state
	self._state:PublisherForKeyChange("iconVisible")
		:CallMethod(frame.progressIcon.ag, "TSMSetPlaying")
end

---Sets the progress.
---@param progress number The progress from a value of 0 to 1 (inclusive)
---@return ProgressBar
function ProgressBar:SetProgress(progress)
	assert(type(progress) == "number" and progress >= 0 and progress <= 1)
	self._state.progress = Math.Round(progress * PROGRESS_SCALE)
	return self
end

---Subscribes to a publisher to set the progress.
---@param publisher ReactivePublisher The publisher
---@return ProgressBar
function ProgressBar:SetProgressPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetProgress"))
	return self
end

---Sets whether or not the progress indicator is hidden.
---@param hidden boolean Whether or not the progress indicator is hidden
---@return ProgressBar
function ProgressBar:SetProgressIconHidden(hidden)
	self._state.iconVisible = not hidden
	return self
end

---Subscribes to a publisher to set whether or not the progress indicator is hidden.
---@param publisher ReactivePublisher The publisher
---@return ProgressBar
function ProgressBar:SetProgressIconHiddenPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetProgressIconHidden"))
	return self
end

function ProgressBar:Draw()
	self.__super:Draw()
	local frame = self:_GetBaseFrame()

	local text = frame.text
	text:ClearAllPoints()
	text:SetWidth(self:_GetDimension("WIDTH"))
	text:SetWidth(frame.text:GetStringWidth())
	text:SetHeight(self:_GetDimension("HEIGHT"))
	text:SetPoint("CENTER", self._state.iconVisible and ((TextureAtlas.GetWidth("iconPack.18x18/Running") + PROGRESS_ICON_PADDING) / 2) or 0, 0)

	local progress = self._state.progress / PROGRESS_SCALE
	local maxWidth = frame:GetWidth() - BORDER_THICKNESS * 2
	local visibleWidth = min(Math.Round(progress * maxWidth), maxWidth)
	if visibleWidth == maxWidth then
		frame.barMask:Hide()
	else
		frame.barMask:Show()
		frame.barMask:SetWidth(maxWidth - visibleWidth)
	end
end
