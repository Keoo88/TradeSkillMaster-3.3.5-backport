-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local private = {}
local DIVIDER_SIZE = 2



-- ============================================================================
-- Element Definition
-- ============================================================================

local DividedContainer = UIElements.Define("DividedContainer", "Frame")
DividedContainer:_ExtendStateSchema()
	:AddBooleanField("resizing", false)
	:AddBooleanField("dividerHidden", false)
	:AddBooleanField("mouseOver", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DividedContainer:__init()
	self.__super:__init()
	self._leftChild = nil
	self._rightChild = nil
	self._resizeOffset = 0
	self._contextTable = nil
	self._defaultContextTable = nil
	self._minLeftWidth = nil
	self._minRightWidth = nil
	self._resizeStartX = nil
end

function DividedContainer:Acquire()
	self.__super:AddChildNoLayout(UIElements.New("Frame", "leftEmpty")
		:AddAnchor("TOPLEFT")
		:AddAnchor("BOTTOMRIGHT", "divider", "BOTTOMLEFT")
	)
	self.__super:AddChild(UIElements.New("Button", "divider")
		:SetSize(DIVIDER_SIZE, nil)
		:SetHitRectInsets(-2, -2, 0, 0)
		:SetRelativeLevel(2)
		:EnableRightClick()
		:SetBackground("ACTIVE_BG", true)
		:SetScript("OnMouseDown", self:__closure("_HandleOnMouseDown"))
		:SetScript("OnMouseUp", self:__closure("_HandleOnMouseUp"))
		:SetScript("OnClick", self:__closure("_HandleOnClick"))
		:SetScript("OnEnter", self:__closure("_HandleOnEnter"))
		:SetScript("OnLeave", self:__closure("_HandleOnLeave"))
	)
	self.__super:AddChildNoLayout(UIElements.New("Frame", "rightEmpty")
		:AddAnchor("TOPLEFT", "divider", "TOPRIGHT")
		:AddAnchor("BOTTOMRIGHT")
	)
	self.__super:Acquire()
	self.__super:SetLayout("HORIZONTAL")

	-- Set the empty frame state
	self._state:PublisherForKeyChange("resizing")
		:Share(2)
		:CallMethod(self:GetElement("leftEmpty"), "SetShown")
		:CallMethod(self:GetElement("rightEmpty"), "SetShown")

	-- Set the OnUpdate handler while resizing
	self._state:PublisherForKeyChange("resizing")
		:MapBooleanWithValues(self:__closure("_HandleOnUpdate"), nil)
		:CallFunction(self:__closure("_SetDividerOnUpdate"))

	-- Set the divider background
	self._state:PublisherForKeys("dividerHidden", "mouseOver", "resizing")
		:MapWithFunction(private.StateToDividerBackground)
		:IgnoreDuplicates()
		:CallFunction(self:__closure("_SetDividerBackground"))
end

function DividedContainer:Release()
	self._isVertical = false
	self._leftChild = nil
	self._rightChild = nil
	self._resizeOffset = 0
	self._contextTable = nil
	self._defaultContextTable = nil
	self._minLeftWidth = nil
	self._minRightWidth = nil
	self._resizeStartX = nil
	self.__super:Release()
end

---Sets the divided container as vertical.
---@return DividedContainer
function DividedContainer:SetVertical()
	assert(not self._leftChild and not self._rightChild and not self._isVertical)
	self._isVertical = true
	self:GetElement("leftEmpty")
		:WipeAnchors()
		:AddAnchor("TOPLEFT")
		:AddAnchor("BOTTOMRIGHT", "divider", "TOPRIGHT")
	self:GetElement("divider")
		:SetSize(nil, DIVIDER_SIZE)
		:SetHitRectInsets(0, 0, -2, -2)
	self:GetElement("rightEmpty")
		:WipeAnchors()
		:AddAnchor("TOPLEFT", "divider", "BOTTOMLEFT")
		:AddAnchor("BOTTOMRIGHT")
	self.__super:SetLayout("VERTICAL")
	return self
end

---Hides the divider
---@return DividedContainer
function DividedContainer:HideDivider()
	self._state.dividerHidden = true
	return self
end

---@private
function DividedContainer:SetLayout(layout)
	error("DividedContainer doesn't support this method")
end

---@private
function DividedContainer:AddChild(child)
	error("DividedContainer doesn't support this method")
end

---@private
function DividedContainer:AddChildBeforeById(beforeId, child)
	error("DividedContainer doesn't support this method")
end

---Sets the context table.
---
-- This table can be used to preserve the divider position across lifecycles of the divided container and even WoW
-- sessions if it's within the settings DB. The position is stored as the width of the left child element.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `leftWidth`)
---@return DividedContainer
function DividedContainer:SetContextTable(tbl, defaultTbl)
	assert(defaultTbl.leftWidth > 0)
	tbl.leftWidth = tbl.leftWidth or defaultTbl.leftWidth
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	return self
end

---Sets the context table from a settings object.
---@param settings Settings The settings object
---@param key string The setting key
---@return DividedContainer
function DividedContainer:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

---Sets the minimum width of the child element.
---@param minLeftWidth number The minimum width of the left child element
---@param minRightWidth number The minimum width of the right child element
---@return DividedContainer
function DividedContainer:SetMinWidth(minLeftWidth, minRightWidth)
	self._minLeftWidth = minLeftWidth
	self._minRightWidth = minRightWidth
	return self
end

---Sets the left child element.
---@param child Element The left child element
---@return DividedContainer
function DividedContainer:SetLeftChild(child)
	assert(not self._isVertical)
	self:_AddDividedChild(child, true)
	return self
end

---Sets the right child element.
---@param child Element The right child element
---@return DividedContainer
function DividedContainer:SetRightChild(child)
	assert(not self._isVertical)
	self:_AddDividedChild(child, false)
	return self
end

---Sets the top child element in vertical mode.
---@param child Element The top child element
---@return DividedContainer
function DividedContainer:SetTopChild(child)
	assert(self._isVertical)
	self:_AddDividedChild(child, true)
	return self
end

---Sets the bottom child element in vertical mode.
---@param child Element The bottom child element
---@return DividedContainer
function DividedContainer:SetBottomChild(child)
	assert(self._isVertical)
	self:_AddDividedChild(child, false)
	return self
end

function DividedContainer:Draw()
	assert(self._contextTable and self._minLeftWidth and self._minRightWidth)
	self.__super.__super.__super:Draw()

	local width = self:_GetDimension(self._isVertical and "HEIGHT" or "WIDTH") - DIVIDER_SIZE
	if width <= 0 then return end
	local leftWidth = self._contextTable.leftWidth + self._resizeOffset
	local rightWidth = width - leftWidth
	if rightWidth < self._minRightWidth then
		leftWidth = width - self._minRightWidth
		if leftWidth < self._minLeftWidth then
			leftWidth = self._minLeftWidth
		end
	elseif leftWidth < self._minLeftWidth then
		leftWidth = self._minLeftWidth
	end
	self._contextTable.leftWidth = leftWidth - self._resizeOffset

	if self._isVertical then
		self:GetElement("leftEmpty"):SetHeight(leftWidth)
		self._leftChild:SetHeight(leftWidth)
	else
		self:GetElement("leftEmpty"):SetWidth(leftWidth)
		self._leftChild:SetWidth(leftWidth)
	end
	self.__super:Draw()
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DividedContainer.__private:_AddDividedChild(child, isLeft)
	assert(child)
	if isLeft then
		assert(not self._leftChild)
		self._leftChild = child
		self.__super:AddChildBeforeById("divider", child)
	else
		assert(self._leftChild and not self._rightChild)
		self._rightChild = child
		self.__super:AddChild(child)
	end
	-- Update for resizing
	self._state:PublisherForKeyChange("resizing")
		:MapBooleanWithValues(0, 1)
		:CallMethod(child:_GetBaseFrame(), "SetAlpha")
	self._state:PublisherForKeyChange("resizing")
		:MapWithFunction(private.ResizingToStrata, self:_GetBaseFrame())
		:CallMethod(child:_GetBaseFrame(), "SetFrameStrata")
end

function DividedContainer.__private:_SetDividerBackground(background)
	self:GetElement("divider"):SetBackground(background, background and true or false)
end

function DividedContainer.__private:_SetDividerOnUpdate(handler)
	self:GetElement("divider"):SetScript("OnUpdate", handler)
end

function DividedContainer.__private:_HandleOnUpdate()
	if self._isVertical then
		local currY = select(2, GetCursorPosition()) / self:_GetBaseFrame():GetEffectiveScale()
		self._resizeOffset = self._resizeStartX - currY
	else
		local currX = GetCursorPosition() / self:_GetBaseFrame():GetEffectiveScale()
		self._resizeOffset = currX - self._resizeStartX
	end
	self:Draw()
end

function DividedContainer.__private:_HandleOnMouseDown(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	self._resizeStartX = select(self._isVertical and 2 or 1, GetCursorPosition()) / self:_GetBaseFrame():GetEffectiveScale()
	self._resizeOffset = 0
	self._state.resizing = true
end

function DividedContainer.__private:_HandleOnMouseUp(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return
	end
	self._contextTable.leftWidth = max(self._contextTable.leftWidth + self._resizeOffset, self._minLeftWidth)
	self._resizeOffset = 0
	self._resizeStartX = nil
	self._state.resizing = false
	self:Draw()
end

function DividedContainer.__private:_HandleOnClick(_, mouseButton)
	if mouseButton ~= "RightButton" then
		return
	end
	self._contextTable.leftWidth = self._defaultContextTable.leftWidth
	self:Draw()
end

function DividedContainer.__private:_HandleOnEnter()
	self._state.mouseOver = true
end

function DividedContainer.__private:_HandleOnLeave()
	self._state.mouseOver = false
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ResizingToStrata(resizing, frame)
	return resizing and "LOW" or frame:GetFrameStrata()
end

function private.StateToDividerBackground(state)
	if state.dividerHidden and not state.mouseOver and not state.resizing then
		return nil
	else
		return "ACTIVE_BG"
	end
end
