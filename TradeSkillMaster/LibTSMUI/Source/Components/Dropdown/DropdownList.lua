-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ROW_HEIGHT = 20
local CHECK_TEXTURE = "iconPack.12x12/Checkmark/Default"



-- ============================================================================
-- Element Definition
-- ============================================================================

local DropdownList = UIElements.Define("DropdownList", "List")
DropdownList:_ExtendStateSchema()
	:Commit()



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function DropdownList:__init()
	self.__super:__init()
	self._items = {}
	self._selectedItems = {}
	self._multiselect = nil
	self._onSelectionChangedHandler = nil
	self._cachedWidth = 0
end

function DropdownList:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
	self:SetBackgroundColor("ACTIVE_BG")
	self._cachedWidth = 0
end

function DropdownList:Release()
	wipe(self._items)
	wipe(self._selectedItems)
	self._multiselect = nil
	self._onSelectionChangedHandler = nil
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DropdownList:SetMultiselect(multiselect)
	assert(multiselect ~= nil and self._multiselect == nil)
	self._multiselect = multiselect
	return self
end

function DropdownList:SetItems(items, selection)
	wipe(self._items)
	for _, item in ipairs(items) do
		tinsert(self._items, item)
	end
	if self._multiselect then
		self:_SetSelectionHelper(selection)
	else
		assert(self._multiselect == false and selection == nil)
	end
	self:_SetNumRows(#self._items)
	return self
end

function DropdownList:SelectAll()
	assert(self._multiselect)
	self:_SetSelectionHelper(true)
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler(self._selectedItems)
	end
end

function DropdownList:DeselectAll()
	assert(self._multiselect)
	self:_SetSelectionHelper(false)
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler(self._selectedItems)
	end
end

function DropdownList:IsNoneSelected()
	for _, item in ipairs(self._items) do
		if self._selectedItems[item] then
			return false
		end
	end
	return true
end

function DropdownList:IsAllSelected()
	for _, item in ipairs(self._items) do
		if not self._selectedItems[item] then
			return false
		end
	end
	return true
end

function DropdownList:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChangedHandler = handler
	else
		error("Invalid DropdownList script: "..tostring(script))
	end
	return self
end

function DropdownList:Draw()
	-- Cache the width BEFORE calling super:Draw which will call _DrawRows
	self._cachedWidth = self:_GetDimension("WIDTH")
	self.__super:Draw()
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function DropdownList.__protected:_HandleRowAcquired(row)
	assert(self._multiselect ~= nil)

	-- Add the text
	local text = row:AddText("text")
	text:TSMSetFont("BODY_BODY3")
	text:SetJustifyH("LEFT")
	text:SetHeight(ROW_HEIGHT)

	if self._multiselect then
		-- Add the check texture
		local check = row:AddTexture("check")
		check:SetDrawLayer("ARTWORK", 1)
		check:TSMSetTextureAndSize(CHECK_TEXTURE)
		check:SetPoint("LEFT", Theme.GetColSpacing() / 2, 0)
		text:SetPoint("LEFT", check, "RIGHT", Theme.GetColSpacing() / 2, 0)
		text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	else
		text:SetPoint("LEFT", Theme.GetColSpacing() / 2, 0)
		text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	end

end

---@param row ListRow
function DropdownList.__protected:_HandleRowDraw(row)
	local item = self._items[row:GetDataIndex()]
	if self._multiselect then
		self:_DrawRowSelectedState(row, self._selectedItems[item])
	end
	local text = row:GetText("text")

	-- In 3.3.5 dual anchors (LEFT+RIGHT) don't work until first render, so set explicit width
	if self._cachedWidth > 0 then
		local textWidth = self._cachedWidth - Theme.GetColSpacing() * 2
		if self._multiselect then
			textWidth = textWidth - 12 - Theme.GetColSpacing() / 2  -- subtract check texture width
		end
		text:SetWidth(textWidth)
	end

	text:SetText(item)
	-- The text color should have maximum contrast with the background color, so set it to white/black based on the background color
	local isLight = self:_IsBackgroundColorLight()
	local colorKey = isLight and "FULL_BLACK" or "FULL_WHITE"
	text:TSMSetTextColor(colorKey)
end

---@param row ListRow
function DropdownList.__private:_DrawRowSelectedState(row, selected)
	row:GetTexture("check"):TSMSetShown(selected)
end

---@param row ListRow
function DropdownList.__protected:_HandleRowClick(row, mouseButton)
	local item = self._items[row:GetDataIndex()]
	if self._multiselect then
		self._selectedItems[item] = not self._selectedItems[item] or nil
		self:_DrawRowSelectedState(row, self._selectedItems[item])
	end
	if self._onSelectionChangedHandler then
		self:_onSelectionChangedHandler(self._multiselect and self._selectedItems or item)
	end
end

function DropdownList.__private:_SetSelectionHelper(selection)
	assert(self._multiselect)
	wipe(self._selectedItems)
	for i, item in ipairs(self._items) do
		if selection == true then
			-- Select all
			self._selectedItems[item] = true
		elseif selection == false then
			-- Deselect all - do nothing
		else
			-- Selection table
			self._selectedItems[item] = selection[item] and true or nil
		end
		local row = self:_GetRow(i)
		if row then
			self:_DrawRowSelectedState(row, self._selectedItems[item])
		end
	end
end
