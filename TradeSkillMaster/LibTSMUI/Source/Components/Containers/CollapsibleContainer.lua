-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CollapsibleContainer = UIElements.Define("CollapsibleContainer", "Frame")
CollapsibleContainer:_ExtendStateSchema()
	:AddBooleanField("collapsed", true)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CollapsibleContainer:__init()
	self.__super:__init()
	self._setContext = false
end

function CollapsibleContainer:Acquire()
	self.__super:Acquire()
	self:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
	self.__super:SetLayout("VERTICAL")
	self.__super:SetPadding(12, 12, 8, 8)
	self.__super:AddChild(UIElements.New("Frame", "heading")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:AddChild(UIElements.New("Button", "expander")
			:SetMargin(0, 4, 0, 0)
			:SetScript("OnClick", private.OnExpanderClick)
		)
		:AddChild(UIElements.New("Text", "text")
			:SetFont("BODY_BODY1_BOLD")
		)
	)
	self.__super:AddChild(UIElements.New("Frame", "content"))

	self._state:PublisherForKeyChange("collapsed")
		:InvertBoolean()
		:CallMethod(self:GetElement("content"), "SetShown")
	self._state:PublisherForKeyChange("collapsed")
		:MapBooleanWithValues("iconPack.18x18/Caret/Right", "iconPack.18x18/Caret/Down")
		:CallMethod(self:GetElement("heading.expander"), "SetBackgroundAndSize")
end

function CollapsibleContainer:Release()
	self._setContext = false
	self.__super:Release()
end

---Sets the context table and key where to store the collapsed state.
---@generic T: CollapsibleContainer
---@param self T
---@param tbl table The table
---@param key string The key
---@return T
function CollapsibleContainer:SetContextTable(tbl, key)
	assert(type(tbl) == "table" and type(key) == "string")
	assert(not self._setContext)
	self._setContext = true
	self._state.collapsed = tbl[key] and true or false
	self._state:PublisherForKeyChange("collapsed")
		:AssignToTableKey(tbl, key)
	return self
end

---Set the heading text.
---@generic T: CollapsibleContainer
---@param self T
---@param headingText? string|number The heading text
---@return T
function CollapsibleContainer:SetHeadingText(headingText)
	assert(type(headingText) == "string" or type(headingText) == "number")
	self:GetElement("heading.text"):SetText(headingText)
	return self
end

---@private
function CollapsibleContainer:SetPadding(left, right, top, bottom)
	error("CollapsibleContainer doesn't support this method")
end

---Sets the layout of the content frame.
---@generic T: CollapsibleContainer
---@param self T
---@param layout FrameLayout The frame layout
---@return T
function CollapsibleContainer:SetLayout(layout)
	self:GetElement("content"):SetLayout(layout)
	return self
end

---Adds a child element to the content frame.
---@param child Element The child element
---@return CollapsibleContainer
function CollapsibleContainer:AddChild(child)
	self:GetElement("content"):AddChild(child)
	return self
end

---Add a child element when the required condition is true.
---@param condition boolean The required condition
---@param child Element The child element
---@return CollapsibleContainer
function CollapsibleContainer:AddChildIf(condition, child)
	self:GetElement("content"):AddChildIf(condition, child)
	return self
end

---Add child elements using a function.
---@param func fun(container: Container, ...: any) The function to call which will add children
---@param ... any Additional arguments to pass to the function
---@return CollapsibleContainer
function CollapsibleContainer:AddChildrenWithFunction(func, ...)
	self:GetElement("content"):AddChildrenWithFunction(func, ...)
	return self
end

---Add a child element before another one.
---@param beforeId string The id of the child element to add this one before
---@param child Element The child element
---@return CollapsibleContainer
function CollapsibleContainer:AddChildBeforeById(beforeId, child)
	self:GetElement("content"):AddChildBeforeById(beforeId, child)
	return self
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.OnExpanderClick(button)
	local self = button:GetParentElement():GetParentElement()
	self._state.collapsed = not self._state.collapsed
	-- TODO: is there a better way to notify the elements up the stack that our size has changed?
	self:GetBaseElement():Draw()
end
