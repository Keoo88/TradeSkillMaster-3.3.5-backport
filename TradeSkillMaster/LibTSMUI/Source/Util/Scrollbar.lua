-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local Scrollbar = LibTSMUI:Init("Util.Scrollbar")
local WidgetExtensions = LibTSMUI:Include("Util.WidgetExtensions")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	scrollbars = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

Scrollbar:OnModuleLoad(function()
	Theme.RegisterChangeCallback(private.OnThemeChange)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Creates a scrollbar.
---@param parent Frame The parent frame
---@param isHorizontal boolean Whether the scrollbar is horizontal or not (vertical)
---@param cancellables? table The cancellables table to use
---@return SliderExtended
function Scrollbar.Create(parent, isHorizontal, cancellables)
	local scrollbar = WidgetExtensions.CreateSlider(parent)
	-- In 3.3.5 a raw CreateFrame("Slider") is NOT mouse-enabled by default (Blizzard's slider
	-- XML templates set enableMouse="true"). Without this, the thumb can't be dragged and the
	-- OnMouseDown/OnEnter handlers never fire (mouse-wheel still works via the scroll frame).
	scrollbar:EnableMouse(true)
	if cancellables then
		scrollbar:TSMSetCancellablesTable(cancellables)
	end
	scrollbar:ClearAllPoints()
	if isHorizontal then
		scrollbar:SetOrientation("HORIZONTAL")
		scrollbar:SetPoint("BOTTOMLEFT", 4, 0)
		scrollbar:SetPoint("BOTTOMRIGHT", -4, 0)
		scrollbar:SetHitRectInsets(-4, -4, -6, -10)
		scrollbar:SetHeight(Theme.GetScrollbarWidth())
		scrollbar:SetPoint("BOTTOMLEFT", Theme.GetScrollbarMargin(), Theme.GetScrollbarMargin())
		scrollbar:SetPoint("BOTTOMRIGHT", -Theme.GetScrollbarMargin(), Theme.GetScrollbarMargin())
	else
		scrollbar:SetOrientation("VERTICAL")
		scrollbar:SetHitRectInsets(-6, -10, -4, -4)
		scrollbar:SetWidth(Theme.GetScrollbarWidth())
		scrollbar:SetPoint("TOPRIGHT", -Theme.GetScrollbarMargin(), -Theme.GetScrollbarMargin())
		scrollbar:SetPoint("BOTTOMRIGHT", -Theme.GetScrollbarMargin(), Theme.GetScrollbarMargin())
	end
	scrollbar:SetValueStep(1)
	-- 3.3.5: Slider:SetObeyStepOnDrag does not exist (added in later clients). Without it the
	-- scrollbar simply isn't snapped to the value step while dragging, which is harmless. Guard
	-- the call so the whole scrollbar (and its parent List) still gets created on WotLK.
	if scrollbar.SetObeyStepOnDrag then
		scrollbar:SetObeyStepOnDrag(true)
	end
	scrollbar:TSMSetScript("OnShow", private.ScrollbarOnLeave)
	scrollbar:TSMSetScript("OnHide", private.ScrollbarOnMouseUp)
	scrollbar:TSMSetScript("OnUpdate", private.ScrollbarOnUpdate)
	scrollbar:TSMSetScript("OnEnter", private.ScrollbarOnEnter)
	scrollbar:TSMSetScript("OnLeave", private.ScrollbarOnLeave)
	scrollbar:TSMSetScript("OnMouseDown", private.ScrollbarOnMouseDown)
	scrollbar:TSMSetScript("OnMouseUp", private.ScrollbarOnMouseUp)

	scrollbar:TSMCreateThumbTexture("ACTIVE_BG_ALT")
	tinsert(private.scrollbars, scrollbar)

	return scrollbar
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.ScrollbarOnUpdate(scrollbar)
	-- The list rows are mouse-enabled buttons nested several frames deep under the list base
	-- (frame -> hScrollFrame -> hContent -> vScrollFrame -> content -> row -> child buttons), so
	-- a +5 offset is only equal to the rows and they steal the click (OnMouseDown never fires on
	-- the scrollbar). Raise the bar well above the row stack so it wins mouse hit-testing.
	scrollbar:SetFrameLevel(scrollbar:GetParent():GetFrameLevel() + 20)
	-- Manual thumb dragging: on 3.3.5 the native thumb-drag of a code-created Slider does not
	-- move the value, so while the mouse is held down we translate cursor movement into SetValue
	-- ourselves. This is a relative drag (anchored at mouse-down) so the thumb doesn't jump.
	if not scrollbar.dragging or not scrollbar.dragStartCursor then
		return
	end
	local minValue, maxValue = scrollbar:GetMinMaxValues()
	if minValue >= maxValue then
		return
	end
	local scale = scrollbar:GetEffectiveScale()
	if not scale or scale <= 0 then
		return
	end
	local cursorX, cursorY = GetCursorPosition()
	local thumb = scrollbar:GetThumbTexture()
	local orientation = scrollbar:GetOrientation()
	local delta, travel = nil, nil
	if orientation == "HORIZONTAL" then
		local left, right = scrollbar:GetLeft(), scrollbar:GetRight()
		if not left or not right then
			return
		end
		local thumbLength = (thumb and thumb:GetWidth()) or 0
		travel = (right - left) - thumbLength
		delta = (cursorX / scale) - scrollbar.dragStartCursor
	else
		local top, bottom = scrollbar:GetTop(), scrollbar:GetBottom()
		if not top or not bottom then
			return
		end
		local thumbLength = (thumb and thumb:GetHeight()) or 0
		travel = (top - bottom) - thumbLength
		-- Moving the cursor down (decreasing Y) scrolls the content down (increasing value).
		delta = scrollbar.dragStartCursor - (cursorY / scale)
	end
	if not travel or travel <= 0 then
		return
	end
	local newValue = scrollbar.dragStartValue + (delta / travel) * (maxValue - minValue)
	if newValue < minValue then
		newValue = minValue
	elseif newValue > maxValue then
		newValue = maxValue
	end
	scrollbar:SetValue(newValue)
end

function private.ScrollbarOnEnter(scrollbar)
	scrollbar:TSMSetThumbColorTexture("ACTIVE_BG_ALT+SELECTED_HOVER")
end

function private.ScrollbarOnLeave(scrollbar)
	scrollbar:TSMSetThumbColorTexture("ACTIVE_BG_ALT")
end

function private.ScrollbarOnMouseDown(scrollbar)
	scrollbar.dragging = true
	-- Anchor the manual drag (see ScrollbarOnUpdate): remember where the cursor and value were
	-- when the drag started so we can apply relative movement without the thumb jumping.
	local scale = scrollbar:GetEffectiveScale()
	if scale and scale > 0 then
		local cursorX, cursorY = GetCursorPosition()
		if scrollbar:GetOrientation() == "HORIZONTAL" then
			scrollbar.dragStartCursor = cursorX / scale
		else
			scrollbar.dragStartCursor = cursorY / scale
		end
		scrollbar.dragStartValue = scrollbar:GetValue()
	else
		scrollbar.dragStartCursor = nil
	end
end

function private.ScrollbarOnMouseUp(scrollbar)
	scrollbar.dragging = nil
	scrollbar.dragStartCursor = nil
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.OnThemeChange()
	for _, scrollbar in ipairs(private.scrollbars) do
		scrollbar:TSMSetThumbColorTexture("ACTIVE_BG_ALT")
	end
end
