-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local ListRow = LibTSMUI:IncludeClassType("ListRow")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local ObjectPool = LibTSMUI:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local private = {
	rowPool = ObjectPool.New("LIST_ROWS", ListRow, 1),
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local List = UIElements.Define("List", "Element", "ABSTRACT")
List:_ExtendStateSchema()
	:AddStringField("backgroundColor", "PRIMARY_BG", Theme.IsValidColor)
	:Commit()



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function List:__init()
	local frame = self:_CreateFrame()
	self.__super:__init(frame)

	self._hScrollFrame = self:_CreateScrollFrame(frame)
	self._hScrollFrame:SetPoint("TOPLEFT")
	-- No BOTTOMRIGHT anchor тАФ size set explicitly in Draw() so GetWidth/Height work in 3.3.5
	self._hScrollFrame:EnableMouseWheel(true)
	self._hScrollFrame:SetClipsChildren(true)
	self._hScrollFrame:TSMSetScript("OnUpdate", self:__closure("_HScrollFrameOnUpdate"))
	self._hScrollFrame:TSMSetScript("OnMouseWheel", self:__closure("_FrameOnMouseWheel"))

	self._hContent = self:_CreateFrame(self._hScrollFrame)
	self._hContent:SetPoint("TOPLEFT")
	self._hScrollFrame:SetScrollChild(self._hContent)

	self._vScrollFrame = self:_CreateScrollFrame(self._hContent)
	self._vScrollFrame:SetPoint("TOPLEFT")
	-- No BOTTOMRIGHT anchor тАФ size set explicitly in Draw()
	self._vScrollFrame:EnableMouseWheel(true)
	self._vScrollFrame:SetClipsChildren(true)
	self._vScrollFrame:TSMSetScript("OnUpdate", self:__closure("_VScrollFrameOnUpdate"))
	self._vScrollFrame:TSMSetScript("OnMouseWheel", self:__closure("_FrameOnMouseWheel"))

	self._content = self:_CreateFrame(self._vScrollFrame)
	self._content:SetPoint("TOPLEFT")
	self._vScrollFrame:SetScrollChild(self._content)

	self._hScrollbar = self:_CreateScrollbar(frame, true)
	self._vScrollbar = self:_CreateScrollbar(frame)

	self._rowHeight = nil
	self._rowElements = {} ---@type ListRow[]
	self._numRows = 0
	self._hScrollValue = 0
	self._vScrollValue = 0
	self._prevDataOffset = nil
	self._inDrawVFrames = false
	self._cachedVisibleHeight = 0  -- cached from _DrawVFrames for use in _GetMaxVisibleRows
	self._registeredItemInfoObjects = {}
	self._registeredItemInfoBaseItemStrings = {}
	self._itemInfoPublisher = nil
end

function List:Acquire(rowHeight)
	assert(type(rowHeight) == "number" and rowHeight > 0)
	assert(#self._rowElements == 0)
	self._rowHeight = rowHeight

	self.__super:Acquire()
	local frame = self:_GetBaseFrame()

	-- In 3.3.5 SetParent(nil) in Release hides the entire subtree including native WoW frames
	-- Explicitly restore visibility of internal frames on re-acquire
	self._hScrollFrame:Show()
	self._hContent:Show()
	self._vScrollFrame:Show()
	self._content:Show()

	-- Set the background color
	self._state:PublisherForKeyChange("backgroundColor")
		:CallMethod(frame, "TSMSubscribeBackdropColor")
	self._state:PublisherForKeyChange("backgroundColor")
		:CallMethodForEachListValue(self._rowElements, "SetBackgroundColor")

	self._hScrollFrame:SetHorizontalScroll(0)
	self._hScrollValue = 0
	self._vScrollValue = 0

	self._vScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnVScrollbarValueChangedNoDraw"))
	-- don't want to cause this element to be drawn for this initial scrollbar change
	self._vScrollbar:SetValue(0)
	self._vScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnVScrollbarValueChanged"))

	self._hScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnHScrollbarValueChangedNoDraw"))
	-- don't want to cause this element to be drawn for this initial scrollbar change
	self._hScrollbar:SetValue(0)
	self._hScrollbar:TSMSetScript("OnValueChanged", self:__closure("_OnHScrollbarValueChanged"))
end

function List:Release()
	self._prevDataOffset = nil
	for _, row in ipairs(self._rowElements) do
		self:_HandleRowReleased(row)
		row:Release()
		private.rowPool:Recycle(row)
	end
	assert(not self._itemInfoPublisher and not next(self._registeredItemInfoObjects) and not next(self._registeredItemInfoBaseItemStrings))
	wipe(self._rowElements)
	self._numRows = 0
	self._cachedVisibleHeight = 0
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the background of the list.
---@generic T: List
---@param self T
---@param color ThemeColorKey The background color as a theme color key
---@return T
function List:SetBackgroundColor(color)
	self._state.backgroundColor = color
	return self
end

function List:Draw()
	self.__super:Draw()

	-- In 3.3.5 SetPoint-anchored frames return 0 from GetHeight/GetWidth
	-- Explicitly size the scroll frames so rows can be created correctly
	local frameW = self:_GetDimension("WIDTH")
	local frameH = self:_GetDimension("HEIGHT")

	-- In 3.3.5 SetPoint-anchored frames return 0 from GetWidth/GetHeight, so size the
	-- scroll viewports explicitly. The horizontal viewport (hScrollFrame) is limited to
	-- the visible width and is set BEFORE _DrawHFrames so the bottom scrollbar range is
	-- computed correctly. hContent / vScrollFrame / content are intentionally NOT forced
	-- to frameW here -- they must keep the full content width (set by _DrawHFrames) so
	-- overflowing columns can be reached via the bottom scrollbar instead of being clipped.
	if frameW > 0 then
		self._hScrollFrame:SetWidth(frameW)
		if self._hScrollFrame._ClipsChildren then
			self._hScrollFrame._ClipsChildren:SetWidth(frameW)
		end
	end
	if frameH > 0 then
		-- The vertical viewport may be anchored below a header (see ScrollTable), so only its own
		-- height must exclude that top offset; otherwise its bottom drops below the list and the last
		-- row spills onto whatever is underneath on 3.3.5a. The clip mask is anchored to the list top
		-- and must keep the full height (shrinking it would clip early and leave a black gap).
		self._hScrollFrame:SetHeight(frameH)
		self._hContent:SetHeight(frameH)
		self._vScrollFrame:SetHeight(max(0, frameH - self:_GetVScrollTopOffset()))
		self._content:SetHeight(frameH)
		-- In 3.3.5 SetClipsChildren creates internal _ClipsChildren frame that needs explicit sizing
		if self._hScrollFrame._ClipsChildren then
			self._hScrollFrame._ClipsChildren:SetHeight(frameH)
		end
		if self._vScrollFrame._ClipsChildren then
			self._vScrollFrame._ClipsChildren:SetHeight(frameH)
		end
	end

	self:_DrawHFrames()
	self:_DrawVFrames()

	-- The vertical scroll viewport (and its clip frame) plus the row content must span the
	-- full horizontal content width so they only clip rows vertically. If left at frameW the
	-- overflowing columns get clipped horizontally and the bottom scrollbar reveals nothing.
	local contentWidth = self._hContent:GetWidth()
	if contentWidth > 0 then
		self._vScrollFrame:SetWidth(contentWidth)
		self._content:SetWidth(contentWidth)
		if self._vScrollFrame._ClipsChildren then
			self._vScrollFrame._ClipsChildren:SetWidth(contentWidth)
		end
	end

	-- Add/hide rows as needed
	local backgroundColor = self._state.backgroundColor
	local maxVisibleRows = self:_GetMaxVisibleRows()
	for i = #self._rowElements + 1, maxVisibleRows do
		local row = private.rowPool:Get()
		row:Acquire(self._content, self._rowHeight, self:__closure("_HandleRowFrameEvent"))
		row:SetOffset(i - 1)
		row:SetBackgroundColor(backgroundColor)
		self:_HandleRowAcquired(row)
		self._rowElements[i] = row
	end
	self:_HideExtraRows()

	-- Draw all the rows
	self:_DrawRows()
end



-- ============================================================================
-- List - Abstract Class Methods
-- ============================================================================

function List.__abstract:_HandleRowDraw(row)
	-- must be implemented by subclass
end



-- ============================================================================
-- List - Protected Class Methods
-- ============================================================================

function List.__protected:_SetNumRows(numRows)
	self._numRows = numRows
	return self
end

function List.__protected:_IsBackgroundColorLight()
	return Theme.GetColor(self._state.backgroundColor):IsLight()
end

function List.__protected:_GetRow(index)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	local rowIndex = index - dataOffset
	if rowIndex < 1 or rowIndex > numVisibleRows then
		return nil
	end
	return self._rowElements[rowIndex]
end

function List.__protected:_GetMouseOverRow()
	for _, row in ipairs(self._rowElements) do
		if row:IsHovering() then
			return row
		end
	end
end

function List.__protected:_AddRows(dataIndex, num)
	local dataOffset = self:_GetDataOffset()
	self:_SetNumRows(self._numRows + num)
	self:_DrawVFrames()
	local numVisibleRows = self:_GetNumVisibleRows()
	assert(dataOffset == self:_GetDataOffset())
	local firstRowIndex = dataIndex - dataOffset
	local lastRowIndex = firstRowIndex + num - 1
	firstRowIndex = max(firstRowIndex, 1)
	if firstRowIndex > numVisibleRows then
		-- Adding all the rows below the visible range, so don't need to do anything
	elseif lastRowIndex >= numVisibleRows then
		-- We're inserting enough rows that all the ones being shifted down are going off the bottom of the visible area, so just redraw them
		self:_DrawRows(firstRowIndex, numVisibleRows)
	else
		-- Update the dataIndex of all the rows which we're shifting down
		for i = firstRowIndex, numVisibleRows - num do
			local row = self._rowElements[i]
			row:UpdateDataIndex(row:GetDataIndex() + num)
		end
		-- Rotate the existing rows down to just redraw the new rows
		self:_RotateRowsDown(num, firstRowIndex, numVisibleRows)
	end
end

function List.__protected:_RemoveRows(dataIndex, num)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	self:_SetNumRows(self._numRows - num)
	self:_DrawVFrames()
	local newDataOffset = self:_GetDataOffset()
	local newNumVisibleRows = self:_GetNumVisibleRows()
	local rowIndex = dataIndex - newDataOffset
	assert(newNumVisibleRows <= numVisibleRows)
	assert(newNumVisibleRows == numVisibleRows or newDataOffset == 0)
	if numVisibleRows ~= newNumVisibleRows then
		-- We removed enough rows that we have less total now than were previously visible, so
		-- redraw the rows which got shifted into view, and hide the extra ones. Clamp the start
		-- to 1 in case the removed block began above the visible window (rowIndex < 1), which
		-- would otherwise pass a negative start index into _DrawRows and trip its assert.
		self:_DrawRows(max(rowIndex, 1), newNumVisibleRows)
		self:_HideExtraRows()
	elseif dataOffset ~= newDataOffset then
		-- The scroll changed which will already take care of drawing the new rows at the top
		-- which got shifted in, so do nothing
	elseif rowIndex > numVisibleRows then
		-- None of the removed rows were visible, so don't need to draw any
	elseif rowIndex < 1 then
		-- The removed block starts at or above the top of the visible window while the scroll
		-- offset is unchanged, so every visible row now shows data shifted up from below. The
		-- partial-rotate path below assumes rowIndex >= 1 and would compute negative indices
		-- here (e.g. _RotateRowsDown(-42, -26, 22) -> _DrawRows(-19, 22) -> assert), so just
		-- redraw all the visible rows instead.
		self:_DrawRows(1, numVisibleRows)
	elseif num > numVisibleRows - rowIndex then
		-- We're removing enough rows that all the ones being shifted up are coming from off the
		-- visible area, so just need to draw them
		self:_DrawRows(rowIndex, numVisibleRows)
	else
		-- Update the dataIndex of all the rows which we're shifting up
		local startIndex = dataIndex - dataOffset
		for i = max(startIndex + num, 1), numVisibleRows do
			local row = self._rowElements[i]
			row:UpdateDataIndex(row:GetDataIndex() - num)
		end
		-- Rotate the existing rows up to just redraw the new rows
		self:_RotateRowsDown(-num, startIndex, numVisibleRows)
	end
end

function List.__protected:_MoveRow(fromDataIndex, toDataIndex)
	assert(fromDataIndex ~= toDataIndex)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	local fromRowIndex = fromDataIndex - dataOffset
	local toRowIndex = toDataIndex - dataOffset
	if min(fromRowIndex, toRowIndex) > numVisibleRows or max(fromRowIndex, toRowIndex) < 1 then
		-- None of the affected rows are visible, so nothing to do
		return
	end
	local moveFromRowIndex = Math.Bound(fromRowIndex, 1, numVisibleRows)
	local moveToRowIndex = Math.Bound(toRowIndex, 1, numVisibleRows)

	-- Move the existing row
	Table.Move(self._rowElements, moveFromRowIndex, moveToRowIndex)

	-- Update all the affected rows
	for i = min(moveToRowIndex, moveFromRowIndex), max(moveToRowIndex, moveFromRowIndex) do
		local row = self._rowElements[i]
		row:UpdateDataIndex(i + dataOffset)
		row:SetOffset(i - 1)
	end

	-- Redraw the row which was moved to
	self:_DrawRows(moveToRowIndex, moveToRowIndex)
end

function List.__protected:_ScrollToRow(dataIndex)
	if not dataIndex then
		return
	end
	assert(dataIndex > 0 and dataIndex <= self._numRows)
	local firstVisibleIndex = self:_GetDataOffset() + 1
	local lastVisibleIndex = firstVisibleIndex + self:_GetNumVisibleRows() - 2
	if lastVisibleIndex > firstVisibleIndex and (dataIndex < firstVisibleIndex or dataIndex > lastVisibleIndex) then
		local rowHeight = self._rowHeight
		local vScrollOffset = min((dataIndex - 1) * rowHeight, self:_GetMaxVScroll())
		if self._vScrollbar:GetValue() ~= vScrollOffset then
			self._vScrollbar:SetValue(vScrollOffset)
		end
		self._vScrollFrame:SetVerticalScroll(vScrollOffset % rowHeight)
	end
end

function List.__protected:_DrawRows(startRowIndex, endRowIndex)
	local numVisibleRows = self:_GetNumVisibleRows()
	startRowIndex = startRowIndex or 1
	endRowIndex = endRowIndex or numVisibleRows
	assert(startRowIndex >= 1 and endRowIndex <= numVisibleRows)
	local dataOffset = self:_GetDataOffset()
	for i = startRowIndex, endRowIndex do
		local dataIndex = i + dataOffset
		assert(dataIndex <= self._numRows)
		local row = self._rowElements[i]
		if row then
			row:SetDataIndex(dataIndex)
			self:_HandleRowDraw(row)
		end
	end
end

function List.__protected:_DrawRowsForUpdatedData(startDataIndex, endDataIndex)
	local dataOffset = self:_GetDataOffset()
	local numVisibleRows = self:_GetNumVisibleRows()
	startDataIndex = max(startDataIndex, dataOffset + 1)
	endDataIndex = min(endDataIndex, numVisibleRows + dataOffset)
	for i = startDataIndex, endDataIndex do
		self:_HandleRowDraw(self._rowElements[i - dataOffset])
	end
end

function List.__protected:_DrawHFrames()
	local totalWidth = self:_GetDimension("WIDTH")
	self._hContent:SetWidth(totalWidth)
	self._content:SetWidth(self._hContent:GetWidth())

	local visibleWidth = self._hScrollFrame:GetWidth()
	local hScrollOffset = min(self._hScrollValue, self:_GetMaxHScroll())

	self._hScrollbar:TSMUpdateThumbLength(self._hContent:GetWidth(), visibleWidth)
	self._hScrollbar:SetMinMaxValues(0, self:_GetMaxHScroll())
	self._hScrollbar:SetValue(hScrollOffset)
	self._hScrollFrame:SetHorizontalScroll(hScrollOffset)
end

function List.__protected:_DrawVFrames()
	local frameHeight = self._hScrollFrame:GetHeight()
	if frameHeight == 0 then
		frameHeight = self:_GetBaseFrame():GetHeight()
	end
	self._hContent:SetHeight(frameHeight)
	if frameHeight > 0 then
		self._hScrollFrame:SetHeight(frameHeight)
		self._vScrollFrame:SetHeight(max(0, frameHeight - self:_GetVScrollTopOffset()))
	end

	local rowHeight = self._rowHeight
	local totalHeight = self._numRows * rowHeight
	local visibleHeight = self._vScrollFrame:GetHeight()
	if visibleHeight == 0 then visibleHeight = frameHeight end
	self._cachedVisibleHeight = visibleHeight
	local numVisibleRows = self:_GetNumVisibleRows()
	local maxScroll = self:_GetMaxVScroll()
	local vScrollOffset = min(self._vScrollValue, maxScroll)

	-- On 3.3.5a, SetMinMaxValues/SetValue synchronously fire OnValueChanged, which would
	-- re-enter _OnVScrollbarValueChanged and rotate/redraw rows while Draw() hasn't finished
	-- creating all the row elements yet. Guard against that re-entrancy.
	self._inDrawVFrames = true
	self._vScrollbar:TSMUpdateThumbLength(totalHeight, visibleHeight)
	self._vScrollbar:SetMinMaxValues(0, maxScroll)
	-- FIXME: this causes a double-draw on first show(?) and is super hacky
	if self._vScrollbar:GetValue() ~= vScrollOffset or self._numRows > 0 then
		self._vScrollbar:SetValue(vScrollOffset)
	end
	self._inDrawVFrames = false
	self._content:SetHeight(numVisibleRows * rowHeight)
	self._vScrollFrame:SetVerticalScroll(vScrollOffset % rowHeight)
end

function List.__protected:_GetRowVerticalOffset(dataIndex)
	return (dataIndex - 1) * self._rowHeight - self._vScrollValue
end

function List.__protected:_HideExtraRows()
	for i = self:_GetNumVisibleRows() + 1, #self._rowElements do
		self._rowElements[i]:SetDataIndex(nil)
	end
end

function List.__protected:_HandleRowAcquired(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowReleased(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowEnter(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowLeave(row)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowClick(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowDoubleClick(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end

function List.__protected:_HandleRowMouseDown(row, mouseButton)
	-- Do nothing if not implemented by the subclass
end



-- ============================================================================
-- List - Private Class Methods
-- ============================================================================

function List.__private:_HandleRowFrameEvent(row, event, ...)
	if event == "OnEnter" then
		-- In 3.3.5 use GetMouseFocus() instead of GetMouseFoci()
		local focus = GetMouseFocus and GetMouseFocus() or (GetMouseFoci and GetMouseFoci()[1])
		if not focus or (focus ~= row._frame and focus ~= row._frame:GetParent() and focus:GetParent() ~= row._frame) then
			-- Sometimes we get erronous OnEnter events - just ignore them
			return
		end
		assert(select("#", ...) == 0)
		self:_HandleRowEnter(row)
	elseif event == "OnLeave" then
		assert(select("#", ...) == 0)
		self:_HandleRowLeave(row)
	elseif event == "OnClick" then
		assert(select("#", ...) == 1)
		local mouseButton = ...
		self:_HandleRowClick(row, mouseButton)
	elseif event == "OnDoubleClick" then
		assert(select("#", ...) == 1)
		local mouseButton = ...
		self:_HandleRowDoubleClick(row, mouseButton)
	elseif event == "OnMouseDown" then
		assert(select("#", ...) == 1)
		local mouseButton = ...
		self:_HandleRowMouseDown(row, mouseButton)
	else
		error("Unexpected event: "..tostring(event))
	end
end

function List.__private:_GetMaxVScroll()
	local h = self._cachedVisibleHeight > 0 and self._cachedVisibleHeight or self._vScrollFrame:GetHeight()
	return max(self._numRows * self._rowHeight - h, 0)
end

function List.__protected:_GetMaxHScroll()
	return max(self._hContent:GetWidth() - self._hScrollFrame:GetWidth(), 0)
end

-- Vertical offset (px) of the scroll viewport's top from the list's top edge. Subclasses that anchor
-- the viewport below a header (e.g. ScrollTable) override this so the viewport height excludes the
-- header and its bottom lines up with the list bottom. Default 0 leaves plain lists unchanged.
function List.__protected:_GetVScrollTopOffset()
	return 0
end

function List.__private:_GetMaxVisibleRows()
	local h = self._cachedVisibleHeight
	if h == 0 then
		h = self._vScrollFrame:GetHeight()
	end
	if h == 0 or not self._rowHeight or self._rowHeight == 0 then return 0 end
	return ceil(h / self._rowHeight)
end

function List.__private:_GetNumVisibleRows()
	return min(self:_GetMaxVisibleRows(), self._numRows)
end

function List.__private:_GetDataOffset()
	return floor(min(self._vScrollValue, self:_GetMaxVScroll()) / self._rowHeight)
end

function List.__private:_RotateRowsDown(amount, startIndex, endIndex)
	startIndex = startIndex or 1
	endIndex = endIndex or self:_GetNumVisibleRows()
	Table.RotateRight(self._rowElements, amount, startIndex, endIndex)
	-- Fix the points of all the rows
	for i, row in ipairs(self._rowElements) do
		row:SetOffset(i - 1)
	end
	-- Just draw the rows which were rotated in, not the ones which were shifted
	if amount > 0 then
		self:_DrawRows(startIndex, min(startIndex + amount - 1, endIndex))
	else
		self:_DrawRows(endIndex + amount + 1, endIndex)
	end
end



-- ============================================================================
-- List - Private Script Handlers
-- ============================================================================

function List.__private:_FrameOnMouseWheel(frame, direction)
	local scrollAmount = -direction * Theme.GetMouseWheelScrollAmount()
	if IsShiftKeyDown() and self._hScrollbar:IsVisible() then
		-- scroll horizontally
		self._hScrollbar:SetValue(self._hScrollbar:GetValue() + scrollAmount)
	else
		self._vScrollbar:SetValue(self._vScrollbar:GetValue() + scrollAmount)
	end
end

function List.__private:_VScrollFrameOnUpdate()
	local rOffset = max(self._hContent:GetWidth() - self._hScrollFrame:GetWidth() - self._hScrollbar:GetValue(), 0)
	if (self._vScrollFrame:IsMouseOver(0, 0, 0, -rOffset) and self:_GetMaxVScroll() > 1) or self._vScrollbar.dragging then
		self._vScrollbar:Show()
	else
		self._vScrollbar:Hide()
	end
end

function List.__private:_HScrollFrameOnUpdate()
	if (self._hScrollFrame:IsMouseOver() and self:_GetMaxHScroll() > 1) or self._hScrollbar.dragging then
		self._hScrollbar:Show()
	else
		self._hScrollbar:Hide()
	end
end

function List.__private:_OnHScrollbarValueChanged(frame, value)
	self:_OnHScrollbarValueChangedNoDraw(frame, value)
	self:_DrawHFrames()
end

function List.__private:_OnVScrollbarValueChanged(frame, value)
	self:_OnVScrollbarValueChangedNoDraw(frame, value)
	if self._inDrawVFrames then
		-- Re-entered synchronously from SetMinMaxValues/SetValue inside _DrawVFrames on 3.3.5a.
		-- Skip the rotate/redraw to avoid operating on a partially-populated row list; the
		-- in-progress Draw()/_DrawVFrames will draw all rows once it finishes.
		return
	end
	self:_DrawVFrames()

	local numVisibleRows = self:_GetNumVisibleRows()
	assert(numVisibleRows >= 0)
	local dataOffset = self:_GetDataOffset()
	local scrollDiff = dataOffset - (self._prevDataOffset or 0)
	self._prevDataOffset = dataOffset
	if scrollDiff == 0 then
		-- Didn't actually scroll
		return
	elseif abs(scrollDiff) > numVisibleRows then
		-- All rows changed, so just redraw them all
		self:_DrawRows()
		return
	end
	-- Shift the rows to match the scrolling so we only have to update as few rows as possible
	self:_RotateRowsDown(-scrollDiff)
end

function List.__private:_OnHScrollbarValueChangedNoDraw(_, value)
	self._hScrollValue = max(min(value, self:_GetMaxHScroll()), 0)
end

function List.__private:_OnVScrollbarValueChangedNoDraw(_, value)
	self._vScrollValue = max(min(value, self:_GetMaxVScroll()), 0)
end