-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {}
local TITLE_HEIGHT = 40
local CONTENT_PADDING_BOTTOM = 16



-- ============================================================================
-- Element Definition
-- ============================================================================

local OverlayApplicationFrame = UIElements.Define("OverlayApplicationFrame", "Frame")
OverlayApplicationFrame:_ExtendStateSchema()
	:AddBooleanField("minimized", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OverlayApplicationFrame:__init()
	self.__super:__init()
	self._contentFrame = nil
	self._contextTable = nil
	self._defaultContextTable = nil
	Theme.RegisterChangeCallback(function()
		if self:IsVisible() then
			self:Draw()
		end
	end)
end

function OverlayApplicationFrame:Acquire()
	local frame = self:_GetBaseFrame()
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	self:AddChildNoLayout(UIElements.New("Button", "closeBtn")
		:AddAnchor("TOPRIGHT", -8, -11)
		:SetBackgroundAndSize("iconPack.18x18/Close/Circle")
		:SetScript("OnClick", private.CloseButtonOnClick)
	)
	self:AddChildNoLayout(UIElements.New("Button", "minimizeBtn")
		:AddAnchor("TOPRIGHT", -26, -11)
		:SetScript("OnClick", private.MinimizeBtnOnClick)
	)
	self:AddChildNoLayout(UIElements.New("Text", "title")
		:SetHeight(24)
		:SetFont("BODY_BODY1_BOLD")
		:AddAnchor("TOPLEFT", 8, -8)
		:AddAnchor("TOPRIGHT", -52, -8)
	)
	self:SetScript("OnDragStart", self:__closure("_HandleDragStart"))
	self:SetScript("OnDragStop", self:__closure("_HandleDragStop"))

	self.__super:Acquire()

	self._state:PublisherForKeyChange("minimized")
		:MapBooleanWithValues("iconPack.18x18/Add/Circle", "iconPack.18x18/Subtract/Circle")
		:CallMethod(self:GetElement("minimizeBtn"), "SetBackgroundAndSize")
end

function OverlayApplicationFrame:Release()
	self._contentFrame = nil
	self._contextTable = nil
	self._defaultContextTable = nil
	self:_GetBaseFrame():SetResizeBounds(0, 0)
	self.__super:Release()
end

---Sets the title text.
---@param title string The title text
---@return OverlayApplicationFrame
function OverlayApplicationFrame:SetTitle(title)
	self:GetElement("title"):SetText(title)
	return self
end

---Sets the content frame.
---@param frame Element The content frame
---@return OverlayApplicationFrame
function OverlayApplicationFrame:SetContentFrame(frame)
	frame:WipeAnchors()
	frame:AddAnchor("TOPLEFT", 0, -TITLE_HEIGHT)
	frame:AddAnchor("BOTTOMRIGHT", 0, CONTENT_PADDING_BOTTOM)
	self._contentFrame = frame
	self:AddChildNoLayout(frame)
	return self
end

---Sets the context table which is used to persist position and size info.
---@param tbl table The context table
---@param defaultTbl table Default values (required fields: `minimized`, `topRightX`, `topRightY`)
---@return OverlayApplicationFrame
function OverlayApplicationFrame:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.minimized ~= nil and defaultTbl.topRightX and defaultTbl.topRightY)
	if tbl.minimized == nil then
		tbl.minimized = defaultTbl.minimized
	end
	self._state.minimized = tbl.minimized
	self._state:PublisherForKeyChange("minimized")
		:AssignToTableKey(tbl, "minimized")
	tbl.topRightX = tbl.topRightX or defaultTbl.topRightX
	tbl.topRightY = tbl.topRightY or defaultTbl.topRightY
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	return self
end

---Sets the context table from a settings object.
---@param settings SettingsView The settings object
---@param key string The setting key
---@return OverlayApplicationFrame
function OverlayApplicationFrame:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

function OverlayApplicationFrame:Draw()
	if self._state.minimized then
		self:GetElement("content"):Hide()
		self:SetHeight(TITLE_HEIGHT)
	else
		self:GetElement("content"):Show()
		-- set the height of the frame based on the height of the children
		local contentHeight, contentHeightExpandable = self:GetElement("content"):_GetMinimumDimension("HEIGHT")
		assert(not contentHeightExpandable)
		self:SetHeight(contentHeight + TITLE_HEIGHT + CONTENT_PADDING_BOTTOM)
	end

	-- make sure the frame is on the screen
	self._contextTable.topRightX = max(min(self._contextTable.topRightX, 0), -UIParent:GetWidth() + 100)
	self._contextTable.topRightY = max(min(self._contextTable.topRightY, 0), -UIParent:GetHeight() + 100)

	-- set the frame position from the contextTable
	self:WipeAnchors()
	self:AddAnchor("TOPRIGHT", self._contextTable.topRightX, self._contextTable.topRightY)

	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OverlayApplicationFrame.__private:_SavePosition()
	local frame = self:_GetBaseFrame()
	local parentFrame = frame:GetParent()
	self._contextTable.topRightX = frame:GetRight() - parentFrame:GetRight()
	self._contextTable.topRightY = frame:GetTop() - parentFrame:GetTop()
end

function OverlayApplicationFrame.__private:_HandleDragStart()
	self:_GetBaseFrame():StartMoving()
end

function OverlayApplicationFrame.__private:_HandleDragStop()
	local frame = self:_GetBaseFrame()
	frame:StopMovingOrSizing()
	self:_SavePosition()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.CloseButtonOnClick(button)
	button:GetParentElement():Hide()
end

function private.MinimizeBtnOnClick(button)
	local self = button:GetParentElement()
	self._state.minimized = not self._state.minimized
	self:Draw()
end
