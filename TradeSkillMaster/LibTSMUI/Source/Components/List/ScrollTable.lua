-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local CustomStringFormat = LibTSMUI:Include("Util.CustomStringFormat")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local CustomString = LibTSMUI:From("LibTSMTypes"):Include("CustomString")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local Iterator = LibTSMUI:From("LibTSMUtil"):IncludeClassType("Iterator")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Vararg = LibTSMUI:From("LibTSMUtil"):Include("Lua.Vararg")
local Log = LibTSMUI:From("LibTSMUtil"):Include("Util.Log")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local private = {
	colsTemp = {},
	groupItemsIterator = nil,
	headerInfoCellTemp = {},
	existingSourcesTemp = {},
}
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 22
local HEADER_LINE_HEIGHT = 2
local HEADER_LINE_WIDTH = 2
local MORE_COL_WIDTH = 8
local MIN_TEXT_WIDTH = 12
local RESIZER_WIDTH = 4
local PRICE_SOURCE_ID_PREFIX = "_priceSource_"
local CUSTOM_SOURCE_ID_PREFIX = "_customSource_"
local EXTRA_SOURCE_TEXT_INFO = {
	justifyH = "RIGHT",
	font = "TABLE_TABLE1",
}
local EXTRA_SOURCE_DEFAULT_WIDTH = 100



-- ============================================================================
-- Element Definition
-- ============================================================================

local ScrollTable = UIElements.Define("ScrollTable", "List", "ABSTRACT")
ScrollTable.DEFERRED_DATA = newproxy()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ScrollTable:__init(colInfo)
	-- Create the groupItemsIterator if needed
	if not private.groupItemsIterator then
		private.groupItemsIterator = Iterator.New()
			:SetFilterFunc(function(_, itemString) return not Group.IsItemInGroup(itemString) and not ItemInfo.IsSoulbound(itemString) end)
	end

	-- Validate the col info
	for id, info in pairs(colInfo) do
		assert(type(id) == "string" and type(info) == "table")
		assert((info.title == nil and info.titleIcon) or (info.titleIcon == nil and info.title))
		assert(info.justifyH and info.font)
	end

	self.__super:__init()

	self._childManager = UIManager.Create("SCROLL_TABLE", self._state, self:__closure("_ActionHandler"))

	local header = self:_CreateFrame(self._hContent)
	self._header = header
	header:EnableMouse(true)
	header:SetPoint("TOPLEFT", 0, -HEADER_LINE_HEIGHT)
	header:SetPoint("TOPRIGHT", 0, -HEADER_LINE_HEIGHT)
	header:SetHeight(HEADER_HEIGHT)

	header.sortBackground = self:_CreateTexture(header, "ARTWORK", -2)
	header.sortBackground:Hide()
	header.sortFlag = self:_CreateTexture(header, "ARTWORK", -1)
	header.sortFlag:SetHeight(3)
	header.sortFlag:Hide()

	local lineTop = self:_CreateTexture(self._hContent)
	self._lineTop = lineTop
	lineTop:SetPoint("BOTTOMLEFT", header, "TOPLEFT")
	lineTop:SetPoint("BOTTOMRIGHT", header, "TOPRIGHT")
	lineTop:SetHeight(HEADER_LINE_HEIGHT)

	local lineBottom = self:_CreateTexture(self._hContent)
	self._lineBottom = lineBottom
	lineBottom:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
	lineBottom:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
	lineBottom:SetHeight(HEADER_LINE_HEIGHT)

	self._vScrollFrame:SetPoint("TOPLEFT", lineBottom, "BOTTOMLEFT")
	self._vScrollbar:SetPoint("TOPRIGHT", -Theme.GetScrollbarMargin(), -Theme.GetScrollbarMargin() - HEADER_HEIGHT - HEADER_LINE_HEIGHT * 2)

	self._colMoveFrame = self:_CreateFrame(self._hContent)
	self._colMoveFrame:Hide()
	self._colMoveFrame:TSMSetScript("OnUpdate", self:__closure("_HandleColMoveFrameUpdate"))

	self._colMoveLine = self:_CreateTexture(self._colMoveFrame)
	self._colMoveLine:SetWidth(HEADER_LINE_WIDTH)
	self._colMoveLine:Hide()

	local colSpacing = Theme.GetColSpacing()

	local moreButton = self:_CreateButton(header)
	header.moreButton = moreButton
	moreButton:TSMSetSize(MORE_COL_WIDTH, HEADER_HEIGHT)
	moreButton:SetPoint("LEFT", colSpacing / 2, 0)
	moreButton:TSMSetScript("OnClick", self:__closure("_HandleMoreClick"))
	local moreIcon = self:_CreateTexture(moreButton)
	header.moreIcon = moreIcon
	moreIcon:TSMSetTextureAndSize("iconPack.12x12/More/Vertical")
	moreIcon:SetPoint("CENTER", moreButton)

	local moreSepIcon = self:_CreateTexture(header, "BORDER")
	header.moreSepIcon = moreSepIcon
	moreSepIcon:SetWidth(HEADER_LINE_WIDTH)
	moreSepIcon:SetPoint("TOP", moreButton, "TOPRIGHT", colSpacing / 2, 0)
	moreSepIcon:SetPoint("BOTTOM", moreButton, "BOTTOMRIGHT", colSpacing / 2, 0)

	self._header.cells = {}
	for id, info in pairs(colInfo) do
		self._header.cells[id] = self:_CreateHeaderCell(info, true)
	end

	self._colInfo = colInfo
	self._sortDisabled = false
	self._settings = nil
	self._settingsKey = nil
	self._actionIcon = {}
	self._createGroupsData = {}
	self._customSourceItemStringDataCol = false
	self._data = {}
	for id, info in pairs(colInfo) do
		self._data[id] = {}
		if info.hasTooltip then
			self._data[id.."_tooltip"] = {}
		end
	end
end

function ScrollTable:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
	self._lineBottom:TSMSubscribeColorTexture("ACTIVE_BG")
	self._lineTop:TSMSubscribeColorTexture("ACTIVE_BG")
	self._header:TSMSubscribeBackdropColor("FRAME_BG")
	self._header.moreSepIcon:TSMSubscribeColorTexture("ACTIVE_BG")
	self._colMoveFrame:TSMSubscribeBackdropColor("SEMI_TRANSPARENT")
	self._colMoveLine:TSMSubscribeColorTexture("ACTIVE_BG+HOVER")
	for _, cell in pairs(self._header.cells) do
		cell.resizerHighlight:TSMSubscribeColorTexture("ACTIVE_BG+HOVER")
		cell.sepIcon:TSMSubscribeColorTexture("ACTIVE_BG")
	end
end

function ScrollTable:Release()
	self._sortDisabled = false
	self._settings = nil
	self._settingsKey = nil
	wipe(self._actionIcon)
	wipe(self._createGroupsData)
	for _, tbl in pairs(self._data) do
		wipe(tbl)
	end
	self.__super:Release()
end

---Sets the settings view and key.
---@generic T: ScrollTable
---@param self T
---@param settings SettingsView The settings object
---@param key string The settings key
---@return T
function ScrollTable:SetSettings(settings, key)
	self._settings = settings
	self._settingsKey = key
	if not self:_ValidateSettings() then
		settings:ResetToDefault(key)
	end
	self:_DrawHeader()
	return self
end


-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param manager UIManager
function ScrollTable.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_MENU_ROW_CLICK" then
		self:_HandleMoreDialogClick(...)
	else
		error("Unknown action: "..tostring(action))
	end
end

function ScrollTable.__protected:_GetSettingsValue()
	return self._settings[self._settingsKey]
end

function ScrollTable.__protected:_GetSettingsDefaultReadOnly()
	return self._settings:GetDefaultReadOnly(self._settingsKey)
end

function ScrollTable.__private:_ValidateSettings()
	local value = self:_GetSettingsValue()
	if not value.cols then
		Log.Err("Missing cols key")
		return false
	elseif self._sortDisabled and (value.sortCol ~= nil or value.sortAscending ~= nil) then
		Log.Err("Has sort keys")
		return false
	elseif not self._sortDisabled and (value.sortCol == nil or type(value.sortAscending) ~= "boolean") then
		Log.Err("Invalid sort keys")
		return false
	end
	for k in pairs(value) do
		if not self:_IsValidSettingsKey(k) then
			Log.Err("Unknown key (%s)", k)
			return false
		end
	end
	assert(not next(private.colsTemp))
	for _, col in ipairs(self:_GetSettingsDefaultReadOnly().cols) do
		private.colsTemp[col.id] = true
	end
	if not self._sortDisabled and not private.colsTemp[value.sortCol] then
		-- 3.3.5a: allow sorting by a custom price/value source column (e.g. Destroy Value)
		local customSortKey = self._customSourceItemStringDataCol and value.sortCol and self:_GetCustomStringSourceKey(value.sortCol) or nil
		if not customSortKey then
			Log.Err("Invalid sort col (%s)", value.sortCol)
			wipe(private.colsTemp)
			return false
		end
	end
	for _, col in ipairs(value.cols) do
		for k in pairs(col) do
			if not Vararg.In(k, "id", "width", "hidden") then
				Log.Err("Col settings has unknown key (%s)", k)
				wipe(private.colsTemp)
				return false
			end
		end
		if not col.id then
			Log.Err("Col settings has no 'id' value")
			wipe(private.colsTemp)
			return false
		elseif not private.colsTemp[col.id] and self._customSourceItemStringDataCol then
			local sourceKey, isCustomSource = self:_GetCustomStringSourceKey(col.id)
			if not sourceKey then
				Log.Err("Col settings has invalid 'id' value (%s)", col.id)
				wipe(private.colsTemp)
				return false
			elseif (isCustomSource and not CustomString.IsCustomSourceRegistered(sourceKey)) or (not isCustomSource and not CustomString.GetSourceInfo(sourceKey)) then
				Log.Err("Col settings has invalid 'id' value (%s)", col.id)
				wipe(private.colsTemp)
				return false
			end
		end
		if type(col.width) ~= "number" then
			Log.Err("Col settings has invalid 'width' value (%s)", col.width)
			wipe(private.colsTemp)
			return false
		elseif col.hidden ~= nil and col.hidden ~= true then
			Log.Err("Col settings has invalid 'hidden' value (%s)", col.hidden)
			wipe(private.colsTemp)
			return false
		end
		private.colsTemp[col.id] = nil
	end
	local missingId = next(private.colsTemp)
	wipe(private.colsTemp)
	if missingId then
		Log.Err("Missing col settings (%s)", missingId)
		return false
	end
	return true
end

function ScrollTable.__protected:_IsValidSettingsKey(key)
	return Vararg.In(key, "cols", "colWidthLocked", "sortCol", "sortAscending")
end

function ScrollTable.__protected:_CreateHeaderCell(info, noSubscribe)
	local colSpacing = Theme.GetColSpacing()
	local cell = self:_CreateButton(self._header)
	cell:SetHeight(HEADER_HEIGHT)
	cell:SetResizable(true)
	cell:RegisterForDrag("LeftButton")
	cell:TSMSetScript("OnClick", self:__closure("_HandleHeaderCellClick"))
	if not info.disableReordering then
		cell:TSMSetScript("OnMouseDown", self:__closure("_HandleHeaderCellMouseDown"))
		cell:TSMSetScript("OnDragStart", self:__closure("_HandleHeaderCellDragStart"))
		cell:TSMSetScript("OnDragStop", self:__closure("_HandleHeaderCellDragStop"))
	end

	-- The minimum width of the content is our minimum text width plus the size of any icons
	local minWidth = MIN_TEXT_WIDTH
	if info.titleIcon then
		minWidth = max(minWidth, TextureAtlas.GetWidth(info.titleIcon))
	end
	cell:SetResizeBounds(minWidth, 0)

	local resizerButton = self:_CreateButton(cell)
	cell.resizerButton = resizerButton
	resizerButton:SetPoint("LEFT", cell, "RIGHT", (colSpacing - RESIZER_WIDTH) / 2, 0)
	resizerButton:TSMSetSize(RESIZER_WIDTH, HEADER_HEIGHT)
	resizerButton:SetHitRectInsets(-RESIZER_WIDTH / 2, -RESIZER_WIDTH / 2, 0, 0)
	resizerButton:SetMovable(true)
	resizerButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	resizerButton:TSMSetScript("OnEnter", self:__closure("_HandleResizerEnter"))
	resizerButton:TSMSetScript("OnLeave", self:__closure("_HandleResizerLeave"))
	resizerButton:TSMSetScript("OnMouseDown", self:__closure("_HandleResizerMouseDown"))
	resizerButton:TSMSetScript("OnMouseUp", self:__closure("_HandleResizerMouseUp"))
	resizerButton:TSMSetScript("OnClick", self:__closure("_HandleResizerClick"))
	local resizerHighlight = self:_CreateTexture(cell)
	cell.resizerHighlight = resizerHighlight
	resizerHighlight:SetPoint("TOPLEFT", resizerButton)
	resizerHighlight:SetPoint("BOTTOMRIGHT", resizerButton)
	resizerHighlight:Hide()

	local sepIcon = self:_CreateTexture(cell, "BORDER")
	cell.sepIcon = sepIcon
	sepIcon:SetWidth(HEADER_LINE_WIDTH)
	sepIcon:SetPoint("TOP", cell, "TOPRIGHT", colSpacing / 2, 0)
	sepIcon:SetPoint("BOTTOM", cell, "BOTTOMRIGHT", colSpacing / 2, 0)

	if info.title then
		assert(not info.titleIcon)
		local text = self:_CreateFontString(cell)
		cell.titleText = text
		text:SetAllPoints(cell)
		text:TSMSetFont("BODY_BODY3_MEDIUM")
		text:SetJustifyH("LEFT")
		text:SetText(info.title)
	else
		assert(info.titleIcon)
		local icon = self:_CreateTexture(cell, "ARTWORK", 1)
		cell.titleIcon = icon
		icon:TSMSetTextureAndSize(info.titleIcon)
		icon:SetPoint(info.justifyH, cell)
	end

	if not noSubscribe then
		cell.resizerHighlight:TSMSubscribeColorTexture("ACTIVE_BG+HOVER")
		cell.sepIcon:TSMSubscribeColorTexture("ACTIVE_BG")
	end
	return cell
end

function ScrollTable.__protected:_DrawSortFlag()
	local sortBackground = self._header.sortBackground
	local sortFlag = self._header.sortFlag
	sortBackground:Hide()
	sortBackground:ClearAllPoints()
	sortFlag:Hide()
	sortFlag:ClearAllPoints()
	local settings = self:_GetSettingsValue()
	for _, data in ipairs(settings.cols) do
		if settings.sortCol == data.id then
			if data.hidden then
				break
			end
			local colSpacing = Theme.GetColSpacing()
			local cell = self._header.cells[data.id]
			sortBackground:SetPoint("TOPLEFT", cell, -colSpacing / 2, 0)
			sortBackground:SetPoint("BOTTOMRIGHT", cell, colSpacing / 2, 0)
			sortBackground:SetColorTexture(Theme.GetColor("ACTIVE_BG"):GetFractionalRGBA())
			sortBackground:Show()
			sortFlag:SetPoint("TOPLEFT", cell, -colSpacing / 2, 2)
			sortFlag:SetPoint("TOPRIGHT", cell, colSpacing / 2, 2)
			sortFlag:TSMSetColorTexture(settings.sortAscending and "INDICATOR" or "INDICATOR_ALT")
			sortFlag:Show()
			break
		end
	end
end

function ScrollTable.__protected:_DrawHeader()
	local colSpacing = Theme.GetColSpacing()
	local prevCellButton = self._header.moreButton
	local settings = self:_GetSettingsValue()
	assert(not next(private.colsTemp))
	for _, colSettings in ipairs(settings.cols) do
		local cell = self._header.cells[colSettings.id]
		private.colsTemp[colSettings.id] = true
		if not cell and self._customSourceItemStringDataCol then
			local sourceKey = self:_GetCustomStringSourceKey(colSettings.id)
			assert(not colSettings.hidden and sourceKey)
			assert(not next(private.headerInfoCellTemp))
			private.headerInfoCellTemp.title = CustomString.GetSourceInfo(sourceKey) or sourceKey
			cell = self:_CreateHeaderCell(private.headerInfoCellTemp)
			wipe(private.headerInfoCellTemp)
			self._header.cells[colSettings.id] = cell
		end
		if colSettings.hidden then
			cell:Hide()
		else
			cell:Show()
			cell:SetWidth(colSettings.width)
			cell:ClearAllPoints()
			cell:SetPoint("LEFT", prevCellButton, "RIGHT", colSpacing, 0)
			prevCellButton = cell
			local resizerButton = cell.resizerButton
			if settings.colWidthLocked then
				resizerButton:Disable()
				resizerButton:SetMovable(false)
				if resizerButton.SetMouseClickEnabled then resizerButton:SetMouseClickEnabled(false) end
			else
				resizerButton:Enable()
				resizerButton:SetMovable(true)
				if resizerButton.SetMouseClickEnabled then resizerButton:SetMouseClickEnabled(true) end
			end
		end
	end
	-- Hide extra cols that were added by previous users of this element
	for id, cell in pairs(self._header.cells) do
		if not private.colsTemp[id] then
			cell:Hide()
		end
	end
	wipe(private.colsTemp)
	self:_DrawHFrames()
end

function ScrollTable.__protected:_DrawHFrames()
	local colSpacing = Theme.GetColSpacing()
	local totalWidth = MORE_COL_WIDTH + colSpacing
	for _, colSettings in ipairs(self:_GetSettingsValue().cols) do
		if not colSettings.hidden then
			totalWidth = totalWidth + colSpacing + colSettings.width
		end
	end

	self._hContent:SetWidth(max(totalWidth, self:_GetDimension("WIDTH")))
	self._content:SetWidth(self._hContent:GetWidth())

	local visibleWidth = self._hScrollFrame:GetWidth()
	local hScrollOffset = min(self._hScrollValue, self:_GetMaxHScroll())

	self._hScrollbar:TSMUpdateThumbLength(self._hContent:GetWidth(), visibleWidth)
	self._hScrollbar:SetMinMaxValues(0, self:_GetMaxHScroll())
	self._hScrollbar:SetValue(hScrollOffset)
	self._hScrollFrame:SetHorizontalScroll(hScrollOffset)
end

function ScrollTable.__protected:_UpdateDataDeferredLoading(numRows)
	for _, tbl in pairs(self._data) do
		wipe(tbl)
		Table.InsertFill(tbl, 1, numRows, self.DEFERRED_DATA)
	end
	self:_SetNumRows(numRows)
	self:Draw()
end

function ScrollTable.__private:_GetCustomStringSourceKey(id)
	assert(self._customSourceItemStringDataCol)
	local prefix, source = strmatch(id, "^(_%a+_)(.+)$")
	if prefix == PRICE_SOURCE_ID_PREFIX then
		return source, false
	elseif prefix == CUSTOM_SOURCE_ID_PREFIX then
		return source, true
	else
		assert(not prefix)
		return nil, false
	end
end

---@param row ListRow
function ScrollTable.__protected:_HandleRowAcquired(row)
	for _, colSettings in ipairs(self:_GetSettingsValue().cols) do
		local id = colSettings.id
		local info = self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(id) and EXTRA_SOURCE_TEXT_INFO or self._colInfo[id]
		local text = row:AddText(id)
		text:SetHeight(ROW_HEIGHT)
		text:TSMSetFont(info.font)
		text:SetJustifyH(info.justifyH)
		if info.hasTooltip then
			row:AddMouseRegion(id.."_tooltip", text, self:__closure("_GetRowData"), not info.disableTooltipLinking and self:__closure("_LinkRowTooltip") or nil)
		end
	end
	local actionIcon = row:AddTexture("actionIcon")
	actionIcon:SetPoint("LEFT", Theme.GetColSpacing() / 2, 0)
end

---@param row ListRow
function ScrollTable.__protected:_HandleRowDraw(row)
	local dataIndex = row:GetDataIndex()
	for _, colSettings in ipairs(self:_GetSettingsValue().cols) do
		if not colSettings.hidden then
			local id = colSettings.id
			row:GetText(id):SetText(self:_GetRowData(dataIndex, id))
		end
	end
	local actionIcon = row:GetTexture("actionIcon")
	if self._actionIcon[dataIndex] then
		actionIcon:TSMSetTextureAndSize(self._actionIcon[dataIndex])
	else
		actionIcon:Hide()
	end
	self:_LayoutDataRow(row)
end

function ScrollTable.__private:_GetRowData(dataIndex, id)
	if not self._data[id] then
		assert(self._customSourceItemStringDataCol)
		local sourceKey, isCustomSource = self:_GetCustomStringSourceKey(id)
		assert(sourceKey)
		local itemString = self:_GetRowData(dataIndex, self._customSourceItemStringDataCol)
		local value = isCustomSource and CustomString.GetValue(sourceKey, itemString) or CustomString.GetSourceValue(sourceKey, itemString)
		return value and CustomStringFormat.Get(sourceKey, value) or ""
	end
	local value = self._data[id][dataIndex]
	if value == self.DEFERRED_DATA then
		self:_LoadDeferredRowData(dataIndex)
		value = self._data[id][dataIndex]
		assert(value ~= self.DEFERRED_DATA)
	end
	return value
end

function ScrollTable.__protected:_LoadDeferredRowData(dataIndex)
	error("Must be implemented by subclass")
end

---@param row ListRow
function ScrollTable.__protected:_LayoutDataRow(row)
	local colSpacing = Theme.GetColSpacing()
	local prevText = nil
	for _, colSettings in ipairs(self:_GetSettingsValue().cols) do
		local id = colSettings.id
		local text = row:GetText(id)
		if colSettings.hidden then
			text:Hide()
		else
			text:Show()
			text:SetWidth(colSettings.width)
			if prevText then
				text:SetPoint("LEFT", prevText, "RIGHT", colSpacing, 0)
			else
				text:SetPoint("LEFT", MORE_COL_WIDTH + colSpacing * 1.5, 0)
			end
			prevText = text
		end
	end
end

function ScrollTable.__private:_LinkRowTooltip(mouseButton, dataIndex, key)
	if not IsShiftKeyDown() and not IsControlKeyDown() then
		self:_HandleRowClick(self:_GetRow(dataIndex), mouseButton)
		return
	end
	local item = self:_GetRowData(dataIndex, key)
	if not item then
		self:_HandleRowClick(self:_GetRow(dataIndex), mouseButton)
		return
	end
	UIUtils.HandleModifiedItemClick(item)
end

function ScrollTable.__private:_SetColWidth(id, width)
	local settings = self:_GetSettingsValue()
	assert(not settings.colWidthLocked)
	local colSettings = nil
	for _, data in ipairs(settings.cols) do
		if data.id == id then
			colSettings = data
			break
		end
	end
	assert(colSettings)
	if width == colSettings.width then
		return
	end
	colSettings.width = width
	self:_DrawRows()
end

function ScrollTable.__private:_ResetColWidth(id)
	if self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(id) then
		self:_SetColWidth(id, EXTRA_SOURCE_DEFAULT_WIDTH)
		return
	end
	for _, colSettings in ipairs(self:_GetSettingsDefaultReadOnly().cols) do
		if colSettings.id == id then
			self:_SetColWidth(id, colSettings.width)
			return
		end
	end
	error("Invalid id: "..tostring(id))
end

function ScrollTable.__private:_HandleColMoveFrameUpdate()
	local colSpacing = Theme.GetColSpacing()
	local x = GetCursorPosition() / self._colMoveFrame:GetEffectiveScale() - self._hContent:GetLeft()
	local frameX = Math.Bound(x - self._colMoveFrame.cellStartX, MORE_COL_WIDTH + colSpacing, self._hContent:GetWidth() - self._colMoveFrame:GetWidth())
	self._colMoveFrame:SetPoint("TOPLEFT", frameX, 0)
	local hoverId, hoverAfter = self:_GetColMoveHoverCell()
	local hoverCell = self._header.cells[hoverId]
	local lineX = hoverCell:GetLeft() - self._hContent:GetLeft() - colSpacing / 2 - self._colMoveLine:GetWidth() / 2
	if hoverAfter then
		lineX = lineX + hoverCell:GetWidth() + colSpacing
	end
	self._colMoveLine:SetPoint("TOPLEFT", self._hContent, lineX, 0)
end

function ScrollTable.__private:_GetColMoveHoverCell()
	assert(self._colMoveFrame.id)
	local x = GetCursorPosition() / self._colMoveFrame:GetEffectiveScale() - self._hContent:GetLeft()
	local colSpacing = Theme.GetColSpacing()
	local hoverAfter, foundMoveCol, lastCellId, isFirst = false, false, nil, true
	for _, data in ipairs(self:_GetSettingsValue().cols) do
		local id = data.id
		if not data.hidden and ((self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(id)) or not self._colInfo[id].disableReordering) then
			local cell = self._header.cells[id]
			local minX = cell:GetLeft() - self._hContent:GetLeft() - colSpacing / 2
			local maxX = minX + cell:GetWidth() + colSpacing
			if id == self._colMoveFrame.id then
				foundMoveCol = true
			elseif foundMoveCol then
				hoverAfter = true
			end
			if x >= minX and x <= maxX then
				return id, hoverAfter
			elseif isFirst and x < minX then
				-- Off the left side of the frame, so use this cell
				return id, false
			end
			lastCellId = id
			isFirst = true
		end
	end

	-- We're off the frame, so use the first/last visible cell
	return lastCellId, self._colMoveFrame.id ~= lastCellId
end

function ScrollTable.__protected:_HandleHeaderCellClick(button, mouseButton)
	if mouseButton ~= "LeftButton" or self._sortDisabled then
		return false
	end
	local id = Table.GetDistinctKey(self._header.cells, button)
	if self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(id) then
		-- Can't sort by custom string source columns
		return false
	end
	local settingsValue = self:_GetSettingsValue()
	if id == settingsValue.sortCol then
		settingsValue.sortAscending = not settingsValue.sortAscending
	else
		settingsValue.sortCol = id
		settingsValue.sortAscending = true
	end
	self:_DrawSortFlag()
	return true
end

function ScrollTable.__private:_HandleHeaderCellMouseDown(button)
	local colSpacing = Theme.GetColSpacing()
	local buttonLeftX = button:GetLeft() - colSpacing / 2
	local x = GetCursorPosition() / self._colMoveFrame:GetEffectiveScale() - buttonLeftX
	self._colMoveFrame.cellStartX = Math.Bound(x, 0, button:GetWidth() + colSpacing)
end

function ScrollTable.__private:_HandleHeaderCellDragStart(button)
	if self:_GetSettingsValue().colWidthLocked then
		return
	end
	self._colMoveFrame:Show()
	self._colMoveFrame:SetWidth(button:GetWidth() + Theme.GetColSpacing())
	self._colMoveFrame:SetHeight(self._hContent:GetHeight())
	self._colMoveFrame.id = Table.GetDistinctKey(self._header.cells, button)
	self._colMoveLine:Show()
	self._colMoveLine:SetHeight(self._hContent:GetHeight())
end

function ScrollTable.__private:_HandleHeaderCellDragStop(button)
	if self:_GetSettingsValue().colWidthLocked then
		return
	end
	local hoverId, hoverAfter = self:_GetColMoveHoverCell()
	local moveId = self._colMoveFrame.id
	self._colMoveFrame.id = nil
	self._colMoveFrame:Hide()
	self._colMoveLine:Hide()
	if moveId ~= hoverId and self:IsVisible() then
		local settings = self:_GetSettingsValue()
		local moveIndex, hoverIndex = nil, nil
		for i, data in ipairs(settings.cols) do
			if data.id == moveId then
				assert(not moveIndex)
				moveIndex = i
			end
			if data.id == hoverId then
				assert(not hoverIndex)
				hoverIndex = i
			end
		end
		assert(moveIndex and hoverIndex and moveIndex ~= hoverIndex)
		if moveIndex > hoverIndex then
			tinsert(settings.cols, hoverIndex + (hoverAfter and 1 or 0), tremove(settings.cols, moveIndex))
		else
			tinsert(settings.cols, hoverIndex + (hoverAfter and 1 or 0) - 1, tremove(settings.cols, moveIndex))
		end
		self:_DrawHeader()
		self:_DrawRows()
	end
end

function ScrollTable.__private:_HandleResizerEnter(button)
	local cell = button:GetParent()
	cell.resizerHighlight:Show()
end

function ScrollTable.__private:_HandleResizerLeave(button)
	local cell = button:GetParent()
	cell.resizerHighlight:Hide()
end

function ScrollTable.__private:_HandleResizerMouseDown(button, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	button:TSMSetOnUpdate(self:__closure("_HandleResizerUpdate"))
	local cell = button:GetParent()
	cell:StartSizing("RIGHT", true)
	cell.resizerHighlight:SetPoint("TOPLEFT", cell, -Theme.GetColSpacing() / 2, 0)
end

function ScrollTable.__private:_HandleResizerMouseUp(button, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	button:TSMSetOnUpdate(nil)
	local cell = button:GetParent()
	cell:StopMovingOrSizing()
	local id = Table.GetDistinctKey(self._header.cells, cell)
	self:_SetColWidth(id, Math.Round(cell:GetWidth()))
	self:_DrawHeader()
	cell.resizerHighlight:SetPoint("TOPLEFT", cell.resizerButton)
end

function ScrollTable.__private:_HandleResizerClick(button, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	local cell = button:GetParent()
	local id = Table.GetDistinctKey(self._header.cells, cell)
	self:_ResetColWidth(id)
	self:_DrawHeader()
end

function ScrollTable.__private:_HandleResizerUpdate(button)
	local cell = button:GetParent()
	local id = Table.GetDistinctKey(self._header.cells, cell)
	self:_SetColWidth(id, Math.Round(cell:GetWidth()))
end

function ScrollTable.__private:_HandleMoreClick(button)
	local menuDialog = UIElements.New("MenuDialog", "menu")
		:AddAnchor("TOPLEFT", button, "BOTTOMLEFT", 2, -4)
		:Configure("")
		:SetManager(self._childManager)
		:SetAction("OnRowClick", "ACTION_HANDLE_MENU_ROW_CLICK")
	menuDialog:SetDataUpdatesPaused(true)
	self:_PopulateMoreDialog(menuDialog)
	menuDialog:SetDataUpdatesPaused(false)
	self:GetBaseElement():ShowDialogFrame(menuDialog)
end

---@param menuDialog MenuDialog
function ScrollTable.__protected:_PopulateMoreDialog(menuDialog)
	menuDialog:AddRow("HIDE", "", L["Show / Hide Columns"])
	local settings = self:_GetSettingsValue()
	assert(not next(private.existingSourcesTemp))
	for _, colSettings in ipairs(settings.cols) do
		local id = colSettings.id
		local sourceKey = self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(colSettings.id) or nil
		if sourceKey or not self._colInfo[id].disableHiding then
			menuDialog:AddRow(id, "HIDE", self:_GetMenuDialogHideText(colSettings))
		end
		if sourceKey then
			private.existingSourcesTemp[sourceKey] = true
		end
	end
	if self._customSourceItemStringDataCol then
		menuDialog:AddRow("PRICE_SOURCES", "HIDE", L["Add Price / Value Source Column"])
		for _, name in CustomString.SourceIterator() do
			local sourceKey = strlower(name)
			if not private.existingSourcesTemp[sourceKey] then
				menuDialog:AddRow(PRICE_SOURCE_ID_PREFIX..sourceKey, "PRICE_SOURCES", name)
			end
		end
		local addedCustomSources = false
		for name in CustomString.CustomSourceIterator() do
			local sourceKey = strlower(name)
			if not private.existingSourcesTemp[sourceKey] then
				if not addedCustomSources then
					menuDialog:AddRow("CUSTOM_SOURCES", "HIDE", L["Add Custom Source Column"])
					addedCustomSources = true
				end
				menuDialog:AddRow(CUSTOM_SOURCE_ID_PREFIX..sourceKey, "CUSTOM_SOURCES", name)
			end
		end
	end
	wipe(private.existingSourcesTemp)
	menuDialog:AddRow("LOCK", "", settings.colWidthLocked and L["Unlock Column Width"] or L["Lock Column Width"])
	menuDialog:AddRow("RESET", "", L["Reset Table"])
	if next(self._createGroupsData) then
		menuDialog:AddRow("CREATE_GROUPS", "", L["Create Groups from Table"])
	end
end

function ScrollTable.__private:_GetMenuDialogHideText(colSettings)
	local color = colSettings.hidden and "TEXT+DISABLED" or "TEXT"
	local title = nil
	if self._customSourceItemStringDataCol then
		local sourceKey = self:_GetCustomStringSourceKey(colSettings.id)
		title = sourceKey and CustomString.GetSourceInfo(sourceKey) or sourceKey
	end
	if not title then
		local info = self._colInfo[colSettings.id]
		if not info.title then
			local textureKey = TextureAtlas.GetColoredKey(info.titleIcon, color)
			return TextureAtlas.GetTextureLink(textureKey)
		end
		title = info.title
	end
	return Theme.GetColor(color):ColorText(title)
end

---@param menuDialog MenuDialog
function ScrollTable.__protected:_HandleMoreDialogClick(menuDialog, id1, id2, id3, extra)
	assert(id1 and not extra)
	local settings = self:_GetSettingsValue()
	if id1 == "HIDE" then
		assert(id2)
		if id2 == "PRICE_SOURCES" or id2 == "CUSTOM_SOURCES" then
			assert(id3 and self:_GetCustomStringSourceKey(id3))
			tinsert(settings.cols, { id = id3, width = EXTRA_SOURCE_DEFAULT_WIDTH })
			for _, row in ipairs(self._rowElements) do
				local text = row:AddText(id3)
				text:SetHeight(ROW_HEIGHT)
				text:TSMSetFont(EXTRA_SOURCE_TEXT_INFO.font)
				text:SetJustifyH(EXTRA_SOURCE_TEXT_INFO.justifyH)
			end
			self:_DrawHeader()
			self:_DrawSortFlag()
			self:_DrawRows()
			self:GetBaseElement():HideDialog()
		else
			assert(not id3)
			local colSettingsIndex = nil
			for i, data in ipairs(settings.cols) do
				if data.id == id2 then
					colSettingsIndex = i
					break
				end
			end
			assert(colSettingsIndex)
			local isCustomStringSource = self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(id2)
			if isCustomStringSource then
				tremove(settings.cols, colSettingsIndex)
				self:_RemoveColText(id2)
			else
				assert(not self._colInfo[id2].disableHiding)
				settings.cols[colSettingsIndex].hidden = not settings.cols[colSettingsIndex].hidden or nil
			end
			self:_DrawHeader()
			self:_DrawSortFlag()
			self:_DrawRows()
			if isCustomStringSource then
				self:GetBaseElement():HideDialog()
			else
				menuDialog:UpdateRow(id2, self:_GetMenuDialogHideText(settings.cols[colSettingsIndex]))
			end
		end
	elseif id1 == "LOCK" then
		assert(not id2)
		self:GetBaseElement():HideDialog()
		settings.colWidthLocked = not settings.colWidthLocked or nil
		self:_DrawHeader()
	elseif id1 == "RESET" then
		assert(not id2)
		self:GetBaseElement():HideDialog()
		assert(not next(private.colsTemp))
		for _, colSettings in ipairs(settings.cols) do
			private.colsTemp[colSettings.id] = colSettings
			if self._customSourceItemStringDataCol and self:_GetCustomStringSourceKey(colSettings.id) then
				self:_RemoveColText(colSettings.id)
			end
		end
		wipe(settings.cols)
		for _, colSettings in ipairs(self:_GetSettingsDefaultReadOnly().cols) do
			local oldColSettings = private.colsTemp[colSettings.id]
			oldColSettings.width = colSettings.width
			oldColSettings.hidden = colSettings.hidden
			tinsert(settings.cols, oldColSettings)
		end
		wipe(private.colsTemp)
		self:_DrawHeader()
		self:_DrawSortFlag()
		self:_DrawRows()
	elseif id1 == "CREATE_GROUPS" then
		assert(not id2)
		self:GetBaseElement():HideDialog()
		local numNewItems = 0
		local commonGroupPath = ""
		for itemString, groupPath in private.groupItemsIterator:Execute(pairs(self._createGroupsData)) do
			if commonGroupPath == "" then
				assert(groupPath ~= "")
				commonGroupPath = groupPath
			elseif groupPath ~= commonGroupPath then
				commonGroupPath = nil
			end
			if not Group.Exists(groupPath) then
				GroupOperation.CreateGroup(groupPath)
			end
			Group.SetItemGroup(itemString, groupPath)
			numNewItems = numNewItems + 1
		end
		if commonGroupPath and commonGroupPath ~= "" then
			ChatMessage.PrintfUser(L["%d items were added from the table to %s."], numNewItems, ChatMessage.ColorUserAccentText(Group.FormatPath(commonGroupPath)))
		else
			ChatMessage.PrintfUser(L["%d items were added from the table to groups."], numNewItems)
		end
	else
		error("Invalid id: "..tostring(id1))
	end
end

function ScrollTable.__private:_RemoveColText(id)
	for _, row in ipairs(self._rowElements) do
		row:RemoveText(id)
	end
	self._header.cells[id]:Hide()
end
