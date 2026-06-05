-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local NineSlice = LibTSMUI:IncludeClassType("NineSlice")
local Rectangle = LibTSMUI:IncludeClassType("Rectangle")
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local Scrollbar = LibTSMUI:Include("Util.Scrollbar")
local ScriptWrapper = LibTSMUI:From("LibTSMWoW"):Include("API.ScriptWrapper")
local Reactive = LibTSMUI:From("LibTSMUtil"):Include("Reactive")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local private = {}
local ANCHOR_REL_PARENT = newproxy()
local PROPAGATE = newproxy()



-- ============================================================================
-- Class Definition / Static Class Functions
-- ============================================================================

---@class Element
---@field _state ReactiveState
local Element = UIElements.Define("Element", nil, "ABSTRACT")

Element._STATE_SCHEMA = Reactive.CreateStateSchema("ELEMENT_STATE")
	:Commit()
Element._ACTION_SCRIPTS = {}

---@return ReactiveStateSchema
function Element.__static._ExtendStateSchema(cls)
	local clsName = strupper(tostring(cls))
	clsName = gsub(clsName, "^CLASS:", "")
	cls._STATE_SCHEMA = cls._STATE_SCHEMA:Extend(clsName.."_STATE")
	return cls._STATE_SCHEMA
end

function Element.__static._AddActionScripts(cls, ...)
	cls._ACTION_SCRIPTS = CopyTable(cls._ACTION_SCRIPTS)
	for i = 1, select("#", ...) do
		local script = select(i, ...)
		assert(not cls._ACTION_SCRIPTS[script])
		cls._ACTION_SCRIPTS[script] = true
	end
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function Element:__init(frame)
	self._frame = frame
	frame:TSMSetDebugObject(self)
	self._scripts = {}
	self._baseElementCache = nil
	self._parent = nil
	self._children = {}
	self._context = nil
	self._acquired = nil
	self._tooltip = nil
	self._tooltipPath = nil
	self._width = nil
	self._height = nil
	self._margin = { left = 0, right = 0, top = 0, bottom = 0 }
	self._padding = { left = 0, right = 0, top = 0, bottom = 0 }
	self._relativeLevel = nil
	self._anchors = {}
	-- TODO: Clean this up - currently this can be initialized by the :_Create*() methods
	self._cancellables = self._cancellables or {}
	self._state = self._STATE_SCHEMA:CreateState()
		:SetAutoStore(self._cancellables)
	self._manager = nil
	self._inheritedManager = nil
	self._scriptAction = {}
end

function Element:__tostring()
	local parentId = self._parent and self._parent._id
	return self.__class.__name..":"..(parentId and (parentId..".") or "")..(self._id or "?")
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the ID of the element.
---@param id? string
function Element:SetId(id)
	-- Should only be called by core UI code before acquiring the element
	assert(not self._acquired)
	self._id = id or tostring(self)
end

---Acquire the element.
function Element:Acquire()
	assert(not self._acquired)
	self._acquired = true
	self:Show()
end

---Release the element.
function Element:Release()
	-- 3.3.5a backport: the element recycling pool can occasionally release an element
	-- twice during frame teardown or nav-tab switches (Frame.Release -> ReleaseAllChildren
	-- -> child:Release on a child that was already released/recycled). On retail this never
	-- happens, so an assert was fine; here it must be idempotent or the assert crashes the
	-- whole TSM UI on nav clicks / closing the window. If already released, no-op.
	if not self._acquired then
		return
	end
	self:ReleaseAllChildren()

	for _, cancellable in pairs(self._cancellables) do
		cancellable:Cancel()
	end
	wipe(self._cancellables)
	self._state:ResetToDefault()

	local frame = self:_GetBaseFrame()

	-- Clear the OnLeave script before hiding the frame (otherwise it'll get called)
	if self._scripts.OnLeave then
		frame:SetScript("OnLeave", nil)
		self._scripts.OnLeave = nil
	end

	if self._tooltip and Tooltip.IsVisible(frame) then
		-- Hide the tooltip
		Tooltip.Hide()
	end

	self:Hide()
	frame:ClearAllPoints()
	if frame.SetScale then
		frame:SetScale(1)
	end

	-- Clear scripts FIRST so SetParent(nil) below doesn't trigger any OnHide TSM callbacks
	for script in pairs(self._scripts) do
		frame:SetScript(script, nil)
	end
	wipe(self._scripts)
	wipe(self._scriptAction)

	-- SetParent(nil) after scripts are cleared — safe now, no callbacks will fire
	frame:SetParent(nil)
	self._manager = nil
	self._inheritedManager = nil
	self._baseElementCache = nil
	self._parent = nil
	self._context = nil
	self._acquired = nil
	self._tooltip = nil
	self._tooltipPath = nil
	self._width = nil
	self._height = nil
	self._margin.left = 0
	self._margin.right = 0
	self._margin.top = 0
	self._margin.bottom = 0
	self._padding.left = 0
	self._padding.right = 0
	self._padding.top = 0
	self._padding.bottom = 0
	self._relativeLevel = nil
	wipe(self._anchors)

	UIElements.Recycle(self)
end

---Show the element.
function Element:Show()
	self:_GetBaseFrame():Show()
	return self
end

---Hide the element.
function Element:Hide()
	self:_GetBaseFrame():Hide()
	return self
end

---Sets whether or not the element is shown.
---@param isShown boolean
function Element:SetShown(isShown)
	if isShown then
		self:Show()
	else
		self:Hide()
	end
	return self
end

---Returns whether or not the element is visible.
---@return boolean
function Element:IsVisible()
	return self:_GetBaseFrame():IsVisible()
end

---Sets the width of the element.
---@generic T: Element
---@param self T
---@param width? number The width of the element, or nil to have an undefined width
---@return T
function Element:SetWidth(width)
	assert(width == nil or type(width) == "number")
	self._width = width
	return self
end

---Sets the height of the element.
---@generic T: Element
---@param self T
---@param height? number The height of the element, or nil to have an undefined height
---@return T
function Element:SetHeight(height)
	assert(height == nil or type(height) == "number")
	self._height = height
	return self
end

---Sets the width and height of the element.
---@generic T: Element
---@param self T
---@param width? number The width of the element, or nil to have an undefined width
---@param height? number The height of the element, or nil to have an undefined height
---@return T
function Element:SetSize(width, height)
	self:SetWidth(width)
	self:SetHeight(height)
	return self
end

---Sets the padding of the element.
---@generic T: Element
---@param self T
---@param left number The left padding value if all arguments are passed or the value of all sides if a single argument is passed
---@param right? number The right padding value if all arguments are passed
---@param top? number The top padding value if all arguments are passed
---@param bottom? number The bottom padding value if all arguments are passed
---@return T
function Element:SetPadding(left, right, top, bottom)
	if not right and not top and not bottom then
		right = left
		top = left
		bottom = left
	end
	assert(type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number")
	self._padding.left = left
	self._padding.right = right
	self._padding.top = top
	self._padding.bottom = bottom
	return self
end

---Sets the margin of the element.
---@generic T: Element
---@param self T
---@param left number The left margin value if all arguments are passed or the value of all sides if a single argument is passed
---@param right? number The right margin value if all arguments are passed
---@param top? number The top margin value if all arguments are passed
---@param bottom? number The bottom margin value if all arguments are passed
---@return T
function Element:SetMargin(left, right, top, bottom)
	if not right and not top and not bottom then
		right = left
		top = left
		bottom = left
	end
	assert(type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number")
	self._margin.left = left
	self._margin.right = right
	self._margin.top = top
	self._margin.bottom = bottom
	return self
end

---Sets the relative level of this element with regards to its parent.
---@generic T: Element
---@param self T
---@param level number The relative level of this element
---@return T
function Element:SetRelativeLevel(level)
	self._relativeLevel = level
	return self
end

---Wipes the element's anchors.
---@generic T: Element
---@param self T
---@return T
function Element:WipeAnchors()
	wipe(self._anchors)
	return self
end

---Adds an anchor to the element.
---@generic T: Element
---@param self T
---@param ... any The anchor arguments (following WoW's SetPoint() arguments)
---@return T
function Element:AddAnchor(...)
	local numArgs = select("#", ...)
	local point, relFrame, relPoint, x, y = nil, nil, nil, nil, nil
	if numArgs == 1 then
		point = ...
	elseif numArgs == 2 then
		point, relFrame = ...
	elseif numArgs == 3 then
		local arg2 = select(2, ...)
		if type(arg2) == "number" then
			point, x, y = ...
		else
			point, relFrame, relPoint = ...
		end
	elseif numArgs == 4 then
		point, relFrame, x, y = ...
	elseif numArgs == 5 then
		point, relFrame, relPoint, x, y = ...
	else
		error("Invalid anchor")
	end
	tinsert(self._anchors, point)
	tinsert(self._anchors, relFrame or ANCHOR_REL_PARENT)
	tinsert(self._anchors, relPoint or point)
	tinsert(self._anchors, x or 0)
	tinsert(self._anchors, y or 0)
	return self
end

---Gets the top-most element in the tree.
---@return Element
function Element:GetBaseElement()
	if not self._baseElementCache then
		local element = self
		local parent = element:GetParentElement()
		while parent do
			local temp = element
			element = parent
			parent = temp:GetParentElement()
		end
		self._baseElementCache = element
	end
	return self._baseElementCache
end

---Gets the parent element's base frame.
---@return Element
function Element:GetParent()
	return self:GetParentElement():_GetBaseFrame()
end

---Gets the parent element.
---@return Element
function Element:GetParentElement()
	return self._parent
end

---Gets another element in the tree by relative path.
---
---The path consists of element ids separated by `.`. `__parent` may also be used to indicate the parent element.
---@param path string The relative path to the element
---@return Element
function Element:GetElement(path)
	return private.GetElementHelper(self, path)
end

---Check if the element has a child with a given ID.
---@param childId string The id of the child
---@return boolean
function Element:HasChildById(childId)
	for _, child in ipairs(self._children) do
		if child._id == childId then
			return true
		end
	end
	return false
end

---Releases all children elements.
function Element:ReleaseAllChildren()
	for _, child in ipairs(self._children) do
		child:_SetParentElement(nil)
		child:Release()
	end
	wipe(self._children)
end

---Sets the tooltip of the element.
---@generic T: Element
---@param self T
---@param tooltip any The value passed to `Tooltip.Show()` when the user hovers over the element, or nil to clear it
---@param anchorPath? string The relative path to the element to anchor to (defaults to `self`)
---@return T
function Element:SetTooltip(tooltip, path)
	self._tooltip = tooltip
	if tooltip then
		-- setting OnEnter/OnLeave will implicitly enable the mouse, so make sure it's previously been enabled
		if not self:_GetBaseFrame():IsMouseEnabled() then
			self:_GetBaseFrame():EnableMouse(true)
		end
		self._tooltipPath = path
		self:SetScript("OnEnter", private.HandleOnEnter)
		self:SetScript("OnLeave", private.HandleOnLeave)
	else
		self:SetScript("OnEnter", nil)
		self:SetScript("OnLeave", nil)
	end
	return self
end

---Subscribes to a publisher to set the tooltip.
---@generic T: Element
---@param self T
---@param publisher ReactivePublisher The publisher
---@return T
function Element:SetTooltipPublisher(publisher)
	self:AddCancellable(publisher:CallMethod(self, "SetTooltip"))
	return self
end

---Shows a tooltip on the element.
---@generic T: Element
---@param self T
---@param tooltip any The value passed to `Tooltip.Show()` when the user hovers over the element
---@param noWrapping? boolean Disables wrapping of text lines
---@param xOffset? number An extra x offset to apply to the anchor of the tooltip
---@return T
function Element:ShowTooltip(tooltip, noWrapping, xOffset)
	Tooltip.Show(self:_GetBaseFrame(), tooltip, noWrapping, xOffset)
	return self
end

---Sets the context value of the element.
---@generic T: Element
---@param self T
---@param context any The context value
---@return T
function Element:SetContext(context)
	self._context = context
	return self
end

---Gets the context value from the element.
---@return any
function Element:GetContext()
	return self._context
end

---Registers a script handler.
---@generic T: Element
---@param self T
---@param script string The script to register for
---@param handler function The script handler which will be called with the element plus any arguments to the script
---@return T
function Element:SetScript(script, handler)
	self._scripts[script] = handler
	if handler then
		ScriptWrapper.Set(self:_GetBaseFrame(), script, handler, self)
	else
		ScriptWrapper.Clear(self:_GetBaseFrame(), script)
	end
	return self
end

---Sets a script to propagate to the parent element.
---@generic T: Element
---@param self T
---@param script string The script to propagate
---@return T
function Element:PropagateScript(script)
	self._scripts[script] = PROPAGATE
	ScriptWrapper.SetPropagate(self:_GetBaseFrame(), script, self)
	return self
end

---Takes ownership of a cancellable publisher.
---@generic T: Element
---@param self T
---@param publisher ReactivePublisher The cancellable publisher to own
---@return T
function Element:AddCancellable(publisher)
	publisher:StoreIn(self._cancellables)
	return self
end

---Sets the UI manager for the element.
---@generic T: Element
---@param self T
---@param manager UIManager The UI manager
---@return T
function Element:SetManager(manager)
	assert(manager and not self._manager)
	self._manager = manager
	return self
end

---Sets the UI manager action to send for one of the element's scripts.
---@generic T: Element
---@param self T
---@param script string The script to send the action for
---@param action string The action to send (along with any arguments)
---@return T
function Element:SetAction(script, action)
	assert(self._ACTION_SCRIPTS[script])
	assert(not self._scriptAction[script])
	self._scriptAction[script] = action
	return self
end

---Draws the element.
function Element:Draw()
	assert(self._acquired)
	local frame = self:_GetBaseFrame()
	local parentFrame = frame:GetParent()
	local numAnchors = self:_GetNumAnchors()
	if numAnchors > 0 then
		frame:ClearAllPoints()
		for i = 1, numAnchors do
			local point, relFrame, relPoint, x, y = self:_GetAnchor(i)
			if relFrame == ANCHOR_REL_PARENT then
				relFrame = parentFrame
			elseif type(relFrame) == "string" then
				-- This is a relative element
				relFrame = self:GetParentElement():GetElement(relFrame):_GetBaseFrame()
			elseif type(relFrame) == "table" and relFrame.__isa and relFrame:__isa(Element) then
				-- This is an element - anchor to its base frame instead
				relFrame = relFrame:_GetBaseFrame()
			end
			frame:SetPoint(point, relFrame, relPoint, x, y)
		end
	end
	local width = self._width
	if width then
		self:_SetDimension("WIDTH", width)
	end
	local height = self._height
	if height then
		self:_SetDimension("HEIGHT", height)
	end
	local relativeLevel = self._relativeLevel
	if relativeLevel and parentFrame then
		frame:SetFrameLevel(parentFrame:GetFrameLevel() + relativeLevel)
	end

end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

function Element.__private:_GetManager()
	if self._manager then
		return self._manager
	elseif self._inheritedManager then
		return self._inheritedManager
	end
	local parent = self:GetParentElement()
	while parent do
		local manager = parent._manager or parent._inheritedManager
		if manager then
			self._inheritedManager = manager
			return manager
		end
		parent = parent:GetParentElement()
	end
	error("No manager found")
end

function Element.__protected:_SendActionScript(script, ...)
	assert(self._ACTION_SCRIPTS[script])
	local action = self._scriptAction[script]
	if action then
		return self:_GetManager():ProcessAction(action, ...)
	end
end

---@return FrameExtended
function Element:_CreateFrame(parentFrame)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	local frame = UIElements.CreateFrame(self, parentFrame)
	frame:TSMSetCancellablesTable(self._cancellables)
	return frame
end

---@return ScrollFrameExtended
function Element:_CreateScrollFrame(parentFrame)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	local scrollFrame = UIElements.CreateScrollFrame(self, parentFrame)
	scrollFrame:TSMSetCancellablesTable(self._cancellables)
	return scrollFrame
end

---@return ButtonExtended
function Element:_CreateButton(parentFrame, name, isSecure)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	local button = UIElements.CreateButton(self, parentFrame, name, isSecure)
	button:TSMSetCancellablesTable(self._cancellables)
	return button
end

---@return EditBoxExtended
function Element:_CreateEditBox(parentFrame)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	local editBox = UIElements.CreateEditBox(self, parentFrame)
	editBox:TSMSetCancellablesTable(self._cancellables)
	return editBox
end

---@param layer DrawLayer
---@return TextureExtended
function Element:_CreateTexture(parentFrame, layer, subLayer)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	local texture = UIElements.CreateTexture(self, parentFrame, layer, subLayer)
	texture:TSMSetCancellablesTable(self._cancellables)
	return texture
end

---@return FontStringExtended
function Element:_CreateFontString(parentFrame)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	local fontString = UIElements.CreateFontString(self, parentFrame)
	fontString:TSMSetCancellablesTable(self._cancellables)
	return fontString
end

---@return AnimationGroupExtended
function Element:_CreateAnimationGroup(texture)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	local animationGroup = UIElements.CreateAnimationGroup(texture)
	animationGroup:TSMSetCancellablesTable(self._cancellables)
	return animationGroup
end

---@return Rectangle
function Element:_CreateRectangle(subLayer, parentFrame)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	return Rectangle.New(parentFrame, subLayer, self._cancellables)
end

---@return NineSlice
function Element:_CreateNineSlice(subLayer, parentFrame)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	return NineSlice.New(parentFrame, subLayer, self._cancellables)
end

---@return SliderExtended
function Element:_CreateScrollbar(parentFrame, isHorizontal)
	-- TODO: Clean this up
	self._cancellables = self._cancellables or {}
	parentFrame = parentFrame or self:_GetBaseFrame()
	return Scrollbar.Create(parentFrame, isHorizontal, self._cancellables)
end

function Element:_AddChild(child, beforeId)
	assert(child:__isa(Element) and not child._parent)
	if beforeId then
		local insertIndex = nil
		for i, element in ipairs(self._children) do
			if element._id == beforeId then
				insertIndex = i
				break
			end
		end
		if not insertIndex then
			error("Invalid beforeId: "..tostring(beforeId))
		end
		tinsert(self._children, insertIndex, child)
	else
		tinsert(self._children, child)
	end
	child:_GetBaseFrame():SetParent(self:_GetBaseFrame())
	child:_SetParentElement(self)
	child:Show()
end

function Element:_RemoveChild(child)
	if not (child:__isa(Element) and child._parent) then return end
	assert(Table.RemoveByValue(self._children, child) == 1)
	child:_SetParentElement(nil)
	child:Release()
end

function Element:_GetNumAnchors()
	assert(#self._anchors % 5 == 0)
	return #self._anchors / 5
end

function Element:_GetAnchor(index)
	index = (index - 1) * 5 + 1
	assert(index < #self._anchors)
	return unpack(self._anchors, index, index + 4)
end

function Element:_SetParentElement(parent)
	self._parent = parent
	self:_ClearBaseElementCache()
end

function Element:_ClearBaseElementCache()
	self._baseElementCache = nil
	self._inheritedManager = nil
	for _, child in ipairs(self._children) do
		child:_ClearBaseElementCache()
	end
end

function Element:_GetMinimumDimension(dimension)
	if dimension == "WIDTH" then
		local width = self._width
		return width or 0, width == nil
	elseif dimension == "HEIGHT" then
		local height = self._height
		return height or 0, height == nil
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_GetPreferredDimension(dimension)
	if dimension == "WIDTH" then
		return nil
	elseif dimension == "HEIGHT" then
		return nil
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_GetDimension(dimension)
	if dimension == "WIDTH" then
		return self:_GetBaseFrame():GetWidth()
	elseif dimension == "HEIGHT" then
		return self:_GetBaseFrame():GetHeight()
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_SetDimension(dimension, ...)
	if dimension == "WIDTH" then
		self:_GetBaseFrame():SetWidth(...)
	elseif dimension == "HEIGHT" then
		self:_GetBaseFrame():SetHeight(...)
	else
		error("Invalid dimension: " .. tostring(dimension))
	end
end

function Element:_GetBaseFrame()
	return self._frame
end

function Element:_GetPadding(side)
	return self._padding[strlower(side)]
end

function Element:_GetPaddingAnchorOffsets(anchor)
	local xPart, yPart = private.SplitAnchor(anchor)
	local x = xPart and ((xPart == "LEFT" and 1 or -1) * self:_GetPadding(xPart)) or 0
	local y = yPart and ((yPart == "BOTTOM" and 1 or -1) * self:_GetPadding(yPart)) or 0
	return x, y
end

function Element:_GetMargin(side)
	return self._margin[strlower(side)]
end

function Element:_GetMarginAnchorOffsets(anchor)
	local xPart, yPart = private.SplitAnchor(anchor)
	local x = xPart and ((xPart == "LEFT" and 1 or -1) * self:_GetMargin(xPart)) or 0
	local y = yPart and ((yPart == "BOTTOM" and 1 or -1) * self:_GetMargin(yPart)) or 0
	return x, y
end



-- ============================================================================
-- Helper Functions
-- ============================================================================

function private.GetElementHelper(element, path)
	assert(not strfind(path, "..", 1, true))
	for part in String.SplitIterator(path, ".") do
		if part == "__parent" then
			local parentElement = element:GetParentElement()
			if not parentElement then
				error(format("Element (%s) has no parent", tostring(element._id)), 4)
			end
			element = parentElement
		elseif part == "__base" then
			local baseElement = element:GetBaseElement()
			if not baseElement then
				error(format("Element (%s) has no base element", tostring(element._id)), 4)
			end
			element = baseElement
		else
			local found = false
			for _, child in ipairs(element._children) do
				if child._id == part then
					element = child
					found = true
					break
				end
			end
			if not found then
				error(format("Element (%s) has no child with id: '%s'", tostring(element._id), part), 4)
			end
		end
	end
	return element
end

function private.SplitAnchor(anchor)
	if anchor == "BOTTOMLEFT" then
		return "LEFT", "BOTTOM"
	elseif anchor == "BOTTOM" then
		return nil, "BOTTOM"
	elseif anchor == "BOTTOMRIGHT" then
		return "RIGHT", "BOTTOM"
	elseif anchor == "RIGHT" then
		return "RIGHT", nil
	elseif anchor == "TOPRIGHT" then
		return "RIGHT", "TOP"
	elseif anchor == "TOP" then
		return nil, "TOP"
	elseif anchor == "TOPLEFT" then
		return "LEFT", "TOP"
	elseif anchor == "LEFT" then
		return "LEFT", nil
	else
		error("Invalid anchor: "..tostring(anchor))
	end
end

---@param element Element
function private.HandleOnEnter(element)
	local frame = nil
	if element._tooltipPath then
		frame = element:GetElement(element._tooltipPath):_GetBaseFrame()
	else
		frame = element:_GetBaseFrame()
	end
	Tooltip.Show(frame, element._tooltip)
end

function private.HandleOnLeave(element)
	Tooltip.Hide()
end
