-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local L = LibTSMUI.Locale.GetTable()
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local SessionInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.SessionInfo")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local private = {}
local SECONDS_PER_HOUR = 60 * 60
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR
local APP_UPDATE_AGE_WARNING = SECONDS_PER_HOUR
local APP_UPDATE_AGE_ERROR = SECONDS_PER_DAY
local AUCTIONDB_REALM_AGE_WARNING = 12 * SECONDS_PER_HOUR
local AUCTIONDB_REALM_AGE_ERROR = 7 * SECONDS_PER_DAY
local AUCTIONDB_REGION_AGE_ERROR = 7 * SECONDS_PER_DAY
local CONTENT_FRAME_OFFSET = 8
local DIALOG_RELATIVE_LEVEL = 18
local HEADER_HEIGHT = 40
local MIN_SCALE = 0.3
local DIALOG_OPACITY_PCT = 65
local MIN_ON_SCREEN_PX = 50
local CORNER_RADIUS = 6
local function NoOp() end



-- ============================================================================
-- Element Definition
-- ============================================================================

local ApplicationFrame = UIElements.Define("ApplicationFrame", "Frame")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ApplicationFrame:__init()
	self.__super:__init()
	self._contentFrame = nil
	self._contextTable = nil
	self._defaultContextTable = nil
	self._isScaling = nil
	self._isResizingWindow = nil
	self._protected = nil
	self._minWidth = 0
	self._minHeight = 0
	self._dialogStack = {}
	self._appRegion = "???"
	self._appTimes = {
		sync = 0,
		realm = 0,
		region = 0,
	}

	local frame = self:_GetBaseFrame()
	local globalFrameName = tostring(frame)
	_G[globalFrameName] = frame
	-- Insert our frames before other addons (i.e. Skillet) to avoid conflicts
	tinsert(UISpecialFrames, 1, globalFrameName)

	self._backgroundTexture = self:_CreateRectangle()
	self._backgroundTexture:SetCornerRadius(CORNER_RADIUS)

	frame.resizeIcon = self:_CreateTexture(frame)
	frame.resizeIcon:SetPoint("BOTTOMRIGHT")
	frame.resizeIcon:TSMSetTextureAndSize("iconPack.14x14/Resize")

	frame.resizeBtn = self:_CreateButton(frame)
	frame.resizeBtn:SetAllPoints(frame.resizeIcon)
	frame.resizeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.resizeBtn:TSMSetScript("OnEnter", private.ResizeOnEnter)
	frame.resizeBtn:TSMSetScript("OnLeave", private.ResizeOnLeave)
	frame.resizeBtn:TSMSetScript("OnMouseDown", self:__closure("_HandleResizeMouseDown"))
	frame.resizeBtn:TSMSetScript("OnMouseUp", self:__closure("_HandleResizeMouseUp"))
	frame.resizeBtn:TSMSetScript("OnClick", self:__closure("_HandleResizeClick"))
	Theme.RegisterChangeCallback(function()
		if self:IsVisible() then
			self:Draw()
		end
	end)
end

function ApplicationFrame:Acquire()
	self:AddChildNoLayout(UIElements.New("Frame", "titleFrame")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:AddAnchor("TOPLEFT", 8, -8)
		:AddAnchor("TOPRIGHT", -8, -8)
		:SetBackgroundColor("FRAME_BG")
		:AddChild(UIElements.New("Texture", "icon")
			:SetMargin(0, 16, 0, 0)
			:SetTextureAndSize("uiFrames.SmallLogo")
		)
		:AddChild(UIElements.New("Text", "title")
			:AddAnchor("CENTER")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2_BOLD")
			:SetTextColor("TEXT_ALT")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetScript("OnClick", private.CloseButtonOnClick)
		)
	)
	self.__super:Acquire()
	local frame = self:_GetBaseFrame()
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self:__closure("_HandleDragStart"))
	self:SetScript("OnDragStop", self:__closure("_HandleDragStop"))

	self._backgroundTexture:SubscribeColor("FRAME_BG")
end

function ApplicationFrame:Release()
	if self._protected then
		tinsert(UISpecialFrames, 1, tostring(self:_GetBaseFrame()))
	end
	self._contentFrame = nil
	self._contextTable = nil
	self._defaultContextTable = nil
	self:_GetBaseFrame():SetResizeBounds(0, 0, 0, 0)
	self._isScaling = nil
	self._isResizingWindow = nil
	self._protected = nil
	self._minWidth = 0
	self._minHeight = 0
	self._appRegion = "???"
	self._appTimes.sync = 0
	self._appTimes.realm = 0
	self._appTimes.region = 0
	self.__super:Release()
end

---Adds player gold text to the title frame.
---@param settings SettingsView The settings view to pass to `PlayerGoldText:SetSettings()`
---@return ApplicationFrame
function ApplicationFrame:AddPlayerGold(settings)
	local titleFrame = self:GetElement("titleFrame")
	local prevId = titleFrame:HasChildById("switchBtn") and "switchBtn" or "closeBtn"
	titleFrame:AddChildBeforeById(prevId, UIElements.New("PlayerGoldText", "playerGold")
		:SetWidth("AUTO")
		:SetMargin(0, 8, 0, 0)
		:SetSettings(settings)
	)
	return self
end

---Adds the app status icon to the title frame.
---@return ApplicationFrame
---@param regionName string The name of the current region
---@param syncTime number The last sync
---@param realmTime number The last realm data update
---@param regionTime number The last region data update
---@return ApplicationFrame
function ApplicationFrame:AddAppStatusIcon(regionName, syncTime, realmTime, regionTime)
	-- TSM Desktop App integration отключён — иконку статуса не показываем.
	return self
end

---Adds a switch button to the title frame.
---@param onClickHandler function The handler for the OnClick script for the button
---@return ApplicationFrame
function ApplicationFrame:AddSwitchButton(onClickHandler)
	local titleFrame = self:GetElement("titleFrame")
	titleFrame:AddChildBeforeById("closeBtn", UIElements.New("ActionButton", "switchBtn")
		:SetSize(95, 20)
		:SetMargin(0, 8, 0, 0)
		:SetFont("BODY_BODY3_MEDIUM")
		:SetText(L["WOW UI"])
		:SetScript("OnClick", onClickHandler)
	)
	return self
end

---Sets whether or not the frame is protected (doesn't close with ESC).
---@param protected boolean
---@return ApplicationFrame
function ApplicationFrame:SetProtected(protected)
	self._protected = protected
	local globalFrameName = tostring(self:_GetBaseFrame())
	if protected then
		Table.RemoveByValue(UISpecialFrames, globalFrameName)
	else
		if not Table.KeyByValue(UISpecialFrames, globalFrameName) then
			-- Insert our frames before other addons (i.e. Skillet) to avoid conflicts
			tinsert(UISpecialFrames, 1, globalFrameName)
		end
	end
	return self
end

---Sets the title text.
---@param title string The title text
---@return ApplicationFrame
function ApplicationFrame:SetTitle(title)
	local titleFrame = self:GetElement("titleFrame")
	titleFrame:GetElement("title"):SetText(title)
	titleFrame:Draw()
	return self
end

---Sets the content frame.
---@param frame Frame The frame's content frame
---@return ApplicationFrame
function ApplicationFrame:SetContentFrame(frame)
	assert(UIElements.IsType(frame, "Frame"))
	frame:WipeAnchors()
	frame:AddAnchor("TOPLEFT", CONTENT_FRAME_OFFSET, -HEADER_HEIGHT)
	-- No BOTTOMRIGHT anchor — size is set explicitly in Draw() so GetWidth/Height work in 3.3.5
	frame:SetPadding(2)
	frame:SetBorderColor("ACTIVE_BG", 2)
	self._contentFrame = frame
	self:AddChildNoLayout(frame)
	return self
end

---Sets the context table which is used to persist position and size info.
---@param tbl table The context table
---@param defaultTbl table Default values (required attributes: `width`, `height`, `centerX`, `centerY`)
---@return ApplicationFrame
function ApplicationFrame:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.width > 0 and defaultTbl.height > 0)
	assert(defaultTbl.centerX and defaultTbl.centerY)
	tbl.width = tbl.width or defaultTbl.width
	tbl.height = tbl.height or defaultTbl.height
	tbl.centerX = tbl.centerX or defaultTbl.centerX
	tbl.centerY = tbl.centerY or defaultTbl.centerY
	tbl.scale = tbl.scale or defaultTbl.scale
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	return self
end

---Sets the context table from a settings object.
---@param settings Settings The settings object
---@param key string The setting key
---@return ApplicationFrame
function ApplicationFrame:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

---Sets the minimum size the application frame can be resized to.
---@param minWidth number The minimum width
---@param minHeight number The minimum height
---@return ApplicationFrame
function ApplicationFrame:SetMinResize(minWidth, minHeight)
	self._minWidth = minWidth
	self._minHeight = minHeight
	return self
end

---Shows a dialog frame.
---@param frame Element The element to show in a dialog
---@param context any The context to set on the dialog frame
function ApplicationFrame:ShowDialogFrame(frame, context)
	local dialogFrame = UIElements.New("Frame", "_dialog_"..random(1, 1000000))
		:SetRelativeLevel(DIALOG_RELATIVE_LEVEL * (#self._dialogStack + 1))
		:SetBackgroundColor("FULL_BLACK%"..DIALOG_OPACITY_PCT)
		:AddAnchor("TOPLEFT")
		:AddAnchor("BOTTOMRIGHT")
		:SetMouseEnabled(true)
		:SetMouseWheelEnabled(true)
		:SetContext(context)
		:SetScript("OnMouseWheel", NoOp)
		:SetScript("OnMouseUp", private.DialogOnMouseUp)
		:AddChildNoLayout(frame)
	tinsert(self._dialogStack, dialogFrame)
	self._contentFrame:AddChildNoLayout(dialogFrame)
	dialogFrame:Show()
	-- In 3.3.5 TOPLEFT+BOTTOMRIGHT anchors don't update GetWidth/Height synchronously
	-- Explicitly size the dialog frame to match _contentFrame so child layouts work
	local cfW = self._contentFrame:_GetDimension("WIDTH")
	local cfH = self._contentFrame:_GetDimension("HEIGHT")
	if cfW > 0 then dialogFrame:_SetDimension("WIDTH", cfW) end
	if cfH > 0 then dialogFrame:_SetDimension("HEIGHT", cfH) end
	dialogFrame:Draw()
	-- 3.3.5: OnHide стреляет ложно при AddChildNoLayout/Show/Draw — ставим OnHide ПОСЛЕ
	-- инициализации, иначе DialogOnHide обнуляет context и Confirm кнопка молча no-op'ит.
	dialogFrame:SetScript("OnHide", private.DialogOnHide)
end

---Show a confirmation dialog.
---@param title string The title of the dialog
---@param subTitle string The sub-title of the dialog
---@param callback function The callback for when the dialog is closed
---@param ... any Arguments to pass to the callback
function ApplicationFrame:ShowConfirmationDialog(title, subTitle, callback, ...)
	local context = TempTable.Acquire(...)
	context.callback = callback
	local frame = UIElements.New("Frame", "frame")
		:SetLayout("VERTICAL")
		:SetSize(328, 158)
		:SetPadding(12, 12, 8, 12)
		:AddAnchor("CENTER")
		:SetRoundedBackgroundColor("FRAME_BG")
		:SetMouseEnabled(true)
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:AddChild(UIElements.New("Text", "title")
				:SetHeight(20)
				:SetMargin(32, 8, 0, 0)
				:SetFont("BODY_BODY2_BOLD")
				:SetJustifyH("CENTER")
				:SetText(title)
			)
			:AddChild(UIElements.New("Button", "closeBtn")
				:SetBackgroundAndSize("iconPack.24x24/Close/Default")
				:SetScript("OnClick", private.DialogCancelBtnOnClick)
			)
		)
		:AddChild(UIElements.New("Text", "desc")
			:SetMargin(0, 0, 16, 16)
			:SetFont("BODY_BODY3")
			:SetJustifyH("LEFT")
			:SetJustifyV("TOP")
			:SetText(subTitle)
		)
		:AddChild(UIElements.New("ActionButton", "confirmBtn")
			:SetHeight(24)
			:SetText(L["Confirm"])
			:SetScript("OnClick", private.DialogConfirmBtnOnClick)
		)
	self:ShowDialogFrame(frame, context)
end

---Show a dialog triggered by a "more" button.
---@param moreBtn Button The "more" button
---@param iter function A dialog menu row iterator with the following fields: `index, text, callback`
function ApplicationFrame:ShowMoreButtonDialog(moreBtn, iter)
	local frame = UIElements.New("PopupFrame", "moreDialog")
		:SetLayout("VERTICAL")
		:SetWidth(200)
		:SetPadding(0, 0, 8, 4)
		:AddAnchor("TOPRIGHT", moreBtn, "BOTTOM", 22, -16)
	local numRows = 0
	for i, text, callback in iter do
		frame:AddChild(UIElements.New("Button", "row"..i)
			:SetHeight(20)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetText(text)
			:SetScript("OnClick", callback)
		)
		numRows = numRows + 1
	end
	frame:SetHeight(12 + numRows * 20)
	self:ShowDialogFrame(frame)
end

---Hides the current dialog.
function ApplicationFrame:HideDialog()
	local dialogFrame = tremove(self._dialogStack)
	if not dialogFrame then
		return
	end
	dialogFrame:GetParentElement():RemoveChild(dialogFrame)
end

function ApplicationFrame:Draw()
	local frame = self:_GetBaseFrame()

	-- While a window resize drag is in progress, leave geometry entirely to the live
	-- StartSizing("BOTTOMRIGHT") + TOPLEFT pin set up in _HandleResizeMouseDown. Any
	-- Draw() that runs mid-drag (the theme callback, or a content redraw triggered by the
	-- Groups page's live bag/item queries) would otherwise WipeAnchors() and re-anchor
	-- CENTER using the stale pre-drag center, undoing the pin so the window grows from its
	-- center and flies off-screen instead of tracking the cursor. The content is hidden
	-- during the drag, so skipping layout here is safe; _HandleResizeMouseUp clears the
	-- flag and calls Draw() again to finalize position and size.
	if self._isResizingWindow then
		return
	end

	-- DEBUG: Log Draw() entry
	if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
		local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
		if currentLog then
			local w, h = frame:GetWidth(), frame:GetHeight()
			local l, b = frame:GetLeft(), frame:GetBottom()
			table.insert(currentLog, string.format("  AppFrame.Draw ENTRY: frame=%.1fx%.1f pos=(%.1f,%.1f) ctx=%.1fx%.1f scale=%.3f",
				w, h, l or -1, b or -1, self._contextTable.width, self._contextTable.height, self._contextTable.scale))
		end
	end

	frame:SetToplevel(true)
	frame:Raise()

	-- update the size if it's less than the set min size
	assert(self._minWidth > 0 and self._minHeight > 0)
	local widthBefore = self._contextTable.width
	local heightBefore = self._contextTable.height
	self._contextTable.width = max(self._contextTable.width, self._minWidth)
	self._contextTable.height = max(self._contextTable.height, self._minHeight)
	self._contextTable.scale = max(self._contextTable.scale, MIN_SCALE)

	-- DEBUG: Log if size was clamped
	if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
		local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
		if currentLog and (widthBefore ~= self._contextTable.width or heightBefore ~= self._contextTable.height) then
			table.insert(currentLog, string.format("  AppFrame.Draw CLAMP: %.1fx%.1f -> %.1fx%.1f (min=%.1fx%.1f)",
				widthBefore, heightBefore, self._contextTable.width, self._contextTable.height, self._minWidth, self._minHeight))
		end
	end

	-- set the frame size from the contextTable
	self:SetScale(self._contextTable.scale)
	self:SetSize(self._contextTable.width, self._contextTable.height)

	-- In 3.3.5 anchor-based sizing returns 0 from GetWidth/Height until next frame.
	-- Explicitly size _contentFrame so child layouts have correct dimensions immediately.
	if self._contentFrame then
		local cfWidth = self._contextTable.width - CONTENT_FRAME_OFFSET * 2
		local cfHeight = self._contextTable.height - HEADER_HEIGHT - CONTENT_FRAME_OFFSET
		self._contentFrame:_SetDimension("WIDTH", cfWidth)
		self._contentFrame:_SetDimension("HEIGHT", cfHeight)
	end

	-- In 3.3.5 TOPLEFT+TOPRIGHT anchors don't update width synchronously on resize
	-- Explicitly size titleFrame so close button and gold text position correctly
	local titleFrame = self:GetElement("titleFrame")
	if titleFrame then
		local tfWidth = self._contextTable.width - 16  -- 8px margin on each side
		titleFrame:_GetBaseFrame():SetWidth(tfWidth)
	end

	-- make sure at least 50px of the frame is on the screen and offset by at least 1 scaled pixel to fix some rendering issues
	local maxAbsCenterX = (UIParent:GetWidth() / self._contextTable.scale + self._contextTable.width) / 2 - MIN_ON_SCREEN_PX
	local maxAbsCenterY = (UIParent:GetHeight() / self._contextTable.scale + self._contextTable.height) / 2 - MIN_ON_SCREEN_PX
	local effectiveScale = UIParent:GetEffectiveScale()
	local centerXBefore = self._contextTable.centerX
	local centerYBefore = self._contextTable.centerY
	if self._contextTable.centerX < 0 then
		self._contextTable.centerX = min(max(self._contextTable.centerX, -maxAbsCenterX), -effectiveScale)
	else
		self._contextTable.centerX = max(min(self._contextTable.centerX, maxAbsCenterX), effectiveScale)
	end
	if self._contextTable.centerY < 0 then
		self._contextTable.centerY = min(max(self._contextTable.centerY, -maxAbsCenterY), -effectiveScale)
	else
		self._contextTable.centerY = max(min(self._contextTable.centerY, maxAbsCenterY), effectiveScale)
	end

	-- DEBUG: Log if position was clamped
	if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
		local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
		if currentLog and (centerXBefore ~= self._contextTable.centerX or centerYBefore ~= self._contextTable.centerY) then
			table.insert(currentLog, string.format("  AppFrame.Draw POS_CLAMP: center (%.1f,%.1f) -> (%.1f,%.1f) maxAbs=(%.1f,%.1f)",
				centerXBefore, centerYBefore, self._contextTable.centerX, self._contextTable.centerY, maxAbsCenterX, maxAbsCenterY))
		end
	end

	-- adjust the position of the frame based on the UI scale to make rendering more consistent
	self._contextTable.centerX = Math.Round(self._contextTable.centerX, effectiveScale)
	self._contextTable.centerY = Math.Round(self._contextTable.centerY, effectiveScale)

	-- set the frame position from the contextTable
	self:WipeAnchors()
	self:AddAnchor("CENTER", self._contextTable.centerX, self._contextTable.centerY)

	-- DEBUG: Log Draw() before super
	if TSMDebugDB and TSMDebugDB.resize_debug and #TSMDebugDB.resize_debug > 0 then
		local currentLog = TSMDebugDB.resize_debug[#TSMDebugDB.resize_debug].log
		if currentLog then
			local w, h = frame:GetWidth(), frame:GetHeight()
			local l, b = frame:GetLeft(), frame:GetBottom()
			table.insert(currentLog, string.format("  AppFrame.Draw BEFORE_SUPER: frame=%.1fx%.1f pos=(%.1f,%.1f)",
				w, h, l or -1, b or -1))
		end
	end

	self.__super:Draw()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function ApplicationFrame.__private:_SavePositionAndSize(wasScaling, skipPosition)
	local frame = self:_GetBaseFrame()
	local parentFrame = frame:GetParent()
	local width = frame:GetWidth()
	local height = frame:GetHeight()
	if wasScaling then
		-- the anchor is in our old frame's scale, so convert the parent measurements to our old scale and then the resuslt to our new scale
		local scaleAdjustment = width / self._contextTable.width
		local frameLeftOffset = frame:GetLeft() - parentFrame:GetLeft() / self._contextTable.scale
		self._contextTable.centerX = (frameLeftOffset - (parentFrame:GetWidth() / self._contextTable.scale - width) / 2) / scaleAdjustment
		local frameBottomOffset = frame:GetBottom() - parentFrame:GetBottom() / self._contextTable.scale
		self._contextTable.centerY = (frameBottomOffset - (parentFrame:GetHeight() / self._contextTable.scale - height) / 2) / scaleAdjustment
		self._contextTable.scale = self._contextTable.scale * scaleAdjustment
	else
		self._contextTable.width = width
		self._contextTable.height = height
		-- Only skip position update during resize (skipPosition=true)
		-- For drag, we need to save position
		if not skipPosition then
			-- the anchor is in our frame's scale, so convert the parent measurements to our scale
			local frameLeftOffset = frame:GetLeft() - parentFrame:GetLeft() / self._contextTable.scale
			self._contextTable.centerX = (frameLeftOffset - (parentFrame:GetWidth() / self._contextTable.scale - width) / 2)
			local frameBottomOffset = frame:GetBottom() - parentFrame:GetBottom() / self._contextTable.scale
			self._contextTable.centerY = (frameBottomOffset - (parentFrame:GetHeight() / self._contextTable.scale - height) / 2)
		end
	end
end

function ApplicationFrame.__protected:_SetResizing(resizing)
	if resizing then
		self:GetElement("titleFrame"):Hide()
		self._contentFrame:_GetBaseFrame():SetAlpha(0)
		self._contentFrame:_GetBaseFrame():SetFrameStrata("LOW")
		self._contentFrame:Draw()
	else
		self:GetElement("titleFrame"):Show()
		self._contentFrame:_GetBaseFrame():SetAlpha(1)
		self._contentFrame:_GetBaseFrame():SetFrameStrata(self._strata)
	end
end

function ApplicationFrame.__private:_GetAppStatusTooltip()
	local tooltipLines = TempTable.Acquire()
	local regionRealmName = self._appRegion.."-"..SessionInfo.GetRealmName()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.CONNECTED_FACTION_AH) then
		regionRealmName = regionRealmName.."-"..SessionInfo.GetFactionName()
	end
	tinsert(tooltipLines, format(L["TSM Desktop App Status (%s)"], regionRealmName))

	local appUpdateAge = LibTSMUI.GetTime() - self._appTimes.sync
	if appUpdateAge < APP_UPDATE_AGE_WARNING then
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_GREEN"):ColorText(format(L["App Synced %s Ago"], SecondsToTime(appUpdateAge))))
	elseif appUpdateAge < APP_UPDATE_AGE_ERROR then
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_YELLOW"):ColorText(format(L["App Synced %s Ago"], SecondsToTime(appUpdateAge))))
	else
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_RED"):ColorText(L["App Not Synced"]))
	end

	local auctionDBRealmAge = LibTSMUI.GetTime() - self._appTimes.realm
	local auctionDBRegionAge = LibTSMUI.GetTime() - self._appTimes.region
	if auctionDBRealmAge < AUCTIONDB_REALM_AGE_WARNING then
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_GREEN"):ColorText(format(L["AuctionDB Realm Data is %s Old"], SecondsToTime(auctionDBRealmAge))))
	elseif auctionDBRealmAge < AUCTIONDB_REALM_AGE_ERROR then
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_YELLOW"):ColorText(format(L["AuctionDB Realm Data is %s Old"], SecondsToTime(auctionDBRealmAge))))
	else
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_RED"):ColorText(L["No AuctionDB Realm Data"]))
	end
	if auctionDBRegionAge < AUCTIONDB_REGION_AGE_ERROR then
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_GREEN"):ColorText(format(L["AuctionDB Region Data is %s Old"], SecondsToTime(auctionDBRegionAge))))
	else
		tinsert(tooltipLines, Theme.GetColor("FEEDBACK_RED"):ColorText(L["No AuctionDB Region Data"]))
	end

	return strjoin("\n", TempTable.UnpackAndRelease(tooltipLines)), true, 16
end

function ApplicationFrame.__private:_HandleResizeMouseDown(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	self._isScaling = IsShiftKeyDown() and true or false
	local frame = self:_GetBaseFrame()
	local width = frame:GetWidth()
	local height = frame:GetHeight()
	-- Record the starting logical size and scale. The resize is driven manually from the
	-- cursor position in OnUpdate (see _HandleResizeOnUpdate) instead of via WoW's
	-- StartSizing(), which on 3.3.5 does not reliably keep the opposite corner fixed and
	-- made the window grow away from the cursor / off-screen.
	self._resizeStartWidth = (type(width) == "number" and width > 0) and width or self._contextTable.width
	self._resizeStartHeight = (type(height) == "number" and height > 0) and height or self._contextTable.height
	self._resizeStartScale = self._contextTable.scale

	-- Capture the TOP-LEFT corner position in UIParent-space units so we can keep it
	-- perfectly fixed for the whole drag (and re-pin it when scaling changes the frame's
	-- scale). GetLeft()/GetTop() are in the frame's own coordinate units; multiplying by
	-- the frame scale converts them to UIParent-space units (independent of frame scale).
	local s0 = self._resizeStartScale
	local left = frame:GetLeft()
	local top = frame:GetTop()
	self._resizePinLeftUI = (left or 0) * s0
	self._resizePinTopUI = (top or 0) * s0

	-- Capture the cursor's starting position in UIParent-space units.
	local uiEff = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	self._resizeStartCursorX = cursorX / uiEff
	self._resizeStartCursorY = cursorY / uiEff

	self:_SetResizing(true)
	-- A window resize drag is now in progress. While it is, ApplicationFrame:Draw() must
	-- not re-anchor/re-size the frame (see the guard at the top of Draw); otherwise a
	-- redraw triggered mid-drag (e.g. the theme-change callback) would WipeAnchors() and
	-- re-center the frame, undoing the pin below.
	self._isResizingWindow = true

	-- Pin the TOP-LEFT corner to its exact current position. The manual driver below then
	-- only grows the size toward the bottom-right, directly under the cursor.
	if left and top then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	end

	-- Drive the resize manually from the cursor each frame.
	frame.resizeBtn:TSMSetScript("OnUpdate", self:__closure("_HandleResizeOnUpdate"))
end

function ApplicationFrame.__private:_HandleResizeOnUpdate()
	if not self._isResizingWindow then
		return
	end
	local frame = self:_GetBaseFrame()
	local uiEff = UIParent:GetEffectiveScale()
	local cursorX, cursorY = GetCursorPosition()
	cursorX = cursorX / uiEff
	cursorY = cursorY / uiEff
	local dx = cursorX - self._resizeStartCursorX
	local dy = cursorY - self._resizeStartCursorY
	if self._isScaling then
		-- SHIFT-drag scales the whole window uniformly while keeping its logical size.
		-- Match the physical width change to the horizontal drag so the grip tracks the
		-- cursor.
		local startPhysW = self._resizeStartWidth * self._resizeStartScale
		local ratio = startPhysW > 0 and ((startPhysW + dx) / startPhysW) or 1
		if ratio < 0.05 then ratio = 0.05 end
		local newScale = min(max(self._resizeStartScale * ratio, MIN_SCALE), self._resizeStartScale * 10)
		frame:SetScale(newScale)
		frame:SetWidth(self._resizeStartWidth)
		frame:SetHeight(self._resizeStartHeight)
		-- Re-pin TOPLEFT: SetPoint offsets are in frame units, which change with scale, so
		-- divide the fixed UIParent-space position by the new scale to keep it put.
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", self._resizePinLeftUI / newScale, self._resizePinTopUI / newScale)
	else
		-- Normal drag changes the size. Convert the UIParent-space cursor delta into frame
		-- units (scale is constant during a non-scaling drag) and clamp to the min/max.
		local s = self._resizeStartScale
		local newWidth = self._resizeStartWidth + dx / s
		local newHeight = self._resizeStartHeight - dy / s
		newWidth = min(max(newWidth, self._minWidth), self._resizeStartWidth * 10)
		newHeight = min(max(newHeight, self._minHeight), self._resizeStartHeight * 10)
		frame:SetWidth(newWidth)
		frame:SetHeight(newHeight)
	end
end

function ApplicationFrame.__private:_HandleResizeMouseUp(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	local frame = self:_GetBaseFrame()
	-- Stop the manual resize driver.
	frame.resizeBtn:TSMSetScript("OnUpdate", nil)
	self:_SetResizing(false)
	-- The resize drag is finished; allow Draw() to re-anchor/re-size normally again. This
	-- must be cleared before the final self:Draw() at the end of this handler so that draw
	-- runs unguarded and commits the new position and size.
	self._isResizingWindow = nil

	-- Read the final geometry the OnUpdate driver applied. These are reliable because we
	-- set them ourselves via SetWidth/SetHeight/SetScale (no engine sizing op involved).
	local sf = frame:GetScale()
	if type(sf) ~= "number" or sf <= 0 then
		sf = self._contextTable.scale
	end
	local newWidth = frame:GetWidth()
	local newHeight = frame:GetHeight()
	if type(newWidth) ~= "number" or newWidth <= 0 then
		newWidth = self._resizeStartWidth or self._contextTable.width
	end
	if type(newHeight) ~= "number" or newHeight <= 0 then
		newHeight = self._resizeStartHeight or self._contextTable.height
	end

	-- The TOP-LEFT corner stayed pinned at (_resizePinLeftUI, _resizePinTopUI) in
	-- UIParent-space for the whole drag. Derive the CENTER anchor offsets Draw() expects
	-- from that fixed corner and the final size/scale so the window stays exactly in place.
	local pinLeftUI = self._resizePinLeftUI or 0
	local pinTopUI = self._resizePinTopUI or 0
	local centerUIX = pinLeftUI + (newWidth * sf) / 2
	local centerUIY = pinTopUI - (newHeight * sf) / 2
	self._contextTable.scale = sf
	self._contextTable.width = newWidth
	self._contextTable.height = newHeight
	self._contextTable.centerX = (centerUIX - UIParent:GetWidth() / 2) / sf
	self._contextTable.centerY = (centerUIY - UIParent:GetHeight() / 2) / sf

	self._resizeStartWidth = nil
	self._resizeStartHeight = nil
	self._resizeStartScale = nil
	self._resizePinLeftUI = nil
	self._resizePinTopUI = nil
	self._resizeStartCursorX = nil
	self._resizeStartCursorY = nil
	self._isScaling = nil

	-- Draw() clamps the size to the minimum, keeps the frame on-screen, and re-anchors
	-- it using the updated context values.
	self:Draw()
end

function ApplicationFrame.__private:_HandleResizeClick(_, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	self._contextTable.scale = self._defaultContextTable.scale
	self._contextTable.width = self._defaultContextTable.width
	self._contextTable.height = self._defaultContextTable.height
	self._contextTable.centerX = self._defaultContextTable.centerX
	self._contextTable.centerY = self._defaultContextTable.centerY
	self:Draw()
end

function ApplicationFrame.__private:_HandleDragStart()
	if self:_GetBaseFrame():IsProtected() and ClientInfo.IsInCombat() then
		return
	end
	self:_GetBaseFrame():StartMoving()
end

function ApplicationFrame.__private:_HandleDragStop()
	if self:_GetBaseFrame():IsProtected() and ClientInfo.IsInCombat() then
		return
	end
	self:_GetBaseFrame():StopMovingOrSizing()
	self:_SavePositionAndSize()
	self:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ResizeOnEnter(btn)
	local text = strjoin("\n",
		L["Click and drag to resize this window."],
		L["Hold SHIFT while dragging to scale the window instead."],
		L["Right-Click to reset the window size, scale, and position to their defaults."]
	)
	Tooltip.Show(btn, text, true)
end

function private.ResizeOnLeave()
	Tooltip.Hide()
end

function private.CloseButtonOnClick(button)
	button:GetElement("__parent.__parent"):Hide()
end

function private.DialogOnMouseUp(dialog)
	dialog:GetParentElement():GetParentElement():HideDialog()
end

function private.DialogOnHide(dialog)
	local context = dialog:GetContext()
	if context then
		dialog:SetContext(nil)
		TempTable.Release(context)
	end
end

function private.DialogCancelBtnOnClick(button)
	button:GetBaseElement():HideDialog()
end

function private.DialogConfirmBtnOnClick(button)
	local self = button:GetBaseElement()
	local dialogFrame = button:GetParentElement():GetParentElement()
	local context = dialogFrame:GetContext()
	if not context then return end
	dialogFrame:SetContext(nil)
	self:HideDialog()
	context.callback(TempTable.UnpackAndRelease(context))
end
