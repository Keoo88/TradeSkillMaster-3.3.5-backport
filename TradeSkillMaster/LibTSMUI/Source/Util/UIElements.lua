-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Init("Util.UIElements")
local WidgetExtensions = LibTSMUI:Include("Util.WidgetExtensions")
local ErrorHandler = LibTSMUI:From("LibTSMService"):Include("Debug.ErrorHandler")
local ObjectPool = LibTSMUI:From("LibTSMUtil"):IncludeClassType("ObjectPool")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local LibTSMClass = LibStub("LibTSMClass")
local private = {
	elementClasses = {},
	objectPools = {}, ---@type table<any,ObjectPool>
	namedElements = {},
	activeFrameElementMap = {},
	debugNameElementLookup = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

UIElements:OnModuleLoad(function()
	ErrorHandler.RegisterNameTranslationFunction(function(result)
		for name, element in pairs(private.debugNameElementLookup) do
			result[name] = "<"..tostring(element)..">"
		end
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Defines and registers a UI element subclass.
---@generic T
---@generic P
---@param elementType `T` The name of the new element class
---@param parentElementType? `P` The name of the parent class (can only be nil for the base Element class)
---@param ... ClassProperties Any additional class modifiers to pass to LibTSMClass.DefineClass()
---@return T|P
function UIElements.Define(elementType, parentElementType, ...)
	local parentClass = parentElementType and private.elementClasses[parentElementType]
	assert(parentClass or not next(private.elementClasses))
	local class = LibTSMClass.DefineClass(elementType, parentClass, ...)
	UIElements.Register(class)
	return class
end

---Registers a UI element sublcass.
---@param class Element The element subclass
function UIElements.Register(class)
	assert(not private.elementClasses[class.__name])
	private.elementClasses[class.__name] = class
end

---Creates a new UI element.
---@generic T
---@param elementType `T` The name of the element class
---@param id string The id to assign to the element
---@return T
function UIElements.New(elementType, id)
	return private.NewElementHelper(elementType, id, nil)
end

---Creates a new named UI element.
---@generic T
---@param elementType `T` The name of the element class
---@param id string The id to assign to the element
---@param name string The global name of the element
---@return T
function UIElements.NewNamed(elementType, id, name)
	assert(name)
	return private.NewElementHelper(elementType, id, name)
end

---Recycles a UI element.
---@param element Element The UI element object
function UIElements.Recycle(element)
	private.activeFrameElementMap[element:_GetBaseFrame()] = nil
	if not Table.KeyByValue(private.namedElements, element) then
		private.objectPools[element.__class]:Recycle(element)
	end
end

---Creates a WoW UI frame, adds our custom extensions to it, and tracks it for easier debugging.
---@param element Element The element which owns the new frame (for debug purposes)
---@param parentFrame? Frame The parent WoW UI object
---@return FrameExtended
function UIElements.CreateFrame(element, parentFrame)
	local name = private.GetDebugName("TSM_FRAME", element)
	private.debugNameElementLookup[name] = element
	local frame = WidgetExtensions.CreateFrame(name, parentFrame)
	_G[name] = nil
	return frame
end

---Creates a WoW UI scroll frame, adds our custom extensions to it, and tracks it for easier debugging.
---@param element Element The TSM UI element object
---@param parentFrame? Frame The parent WoW UI frame
---@return ScrollFrameExtended
function UIElements.CreateScrollFrame(element, parentFrame)
	local name = private.GetDebugName("TSM_SCROLL_FRAME", element)
	private.debugNameElementLookup[name] = element
	local scrollFrame = WidgetExtensions.CreateScrollFrame(name, parentFrame)
	_G[name] = nil
	return scrollFrame
end

---Creates a WoW UI button, adds our custom extensions to it, and tracks it for easier debugging.
---@param element Element The TSM UI element object
---@param parentFrame? Frame The parent WoW UI frame
---@param name? string The global name
---@param isSecure? boolean Whether or not the button is secure
---@return ButtonExtended
function UIElements.CreateButton(element, parentFrame, name, isSecure)
	local isNamed = name and true or false
	name = name or private.GetDebugName("TSM_BUTTON", element)
	private.debugNameElementLookup[name] = element
	local button = WidgetExtensions.CreateButton(name, parentFrame, isSecure and "SecureActionButtonTemplate" or nil)
	if not isNamed then
		_G[name] = nil
	end
	return button
end

---Creates a WoW edit box, adds our custom extensions to it, and tracks it for easier debugging.
---@param element Element The TSM UI element object
---@param parentFrame? Frame The parent WoW UI frame
---@return EditBoxExtended
function UIElements.CreateEditBox(element, parentFrame)
	local name = private.GetDebugName("TSM_EDIT_BOX", element)
	private.debugNameElementLookup[name] = element
	local editBox = WidgetExtensions.CreateEditBox(name, parentFrame)
	_G[name] = nil
	return editBox
end

---Creates a WoW UI font string, adds our custom extensions to it, and tracks it for easier debugging.
---@param element Element The TSM UI element object
---@param parentFrame Frame The parent WoW UI frame
---@return FontStringExtended
function UIElements.CreateFontString(element, parentFrame)
	local name = private.GetDebugName("TSM_FONT_STRING", element)
	private.debugNameElementLookup[name] = element
	local fontString = WidgetExtensions.CreateFontString(parentFrame, name)
	_G[name] = nil
	return fontString
end

---Creates a WoW UI texture, adds our custom extensions to it, and tracks it for easier debugging.
---@param element Element The element which owns the new frame (for debug purposes)
---@param parentFrame Frame The parent WoW UI frame
---@param layer? DrawLayer The layer (defaults to "ARTWORK")
---@param subLayer? number The sublayer
---@return TextureExtended
function UIElements.CreateTexture(element, parentFrame, layer, subLayer)
	local name = private.GetDebugName("TSM_TEXTURE", element)
	private.debugNameElementLookup[name] = element
	local texture = WidgetExtensions.CreateTexture(parentFrame, layer, subLayer, name)
	_G[name] = nil
	return texture
end

---Creates an animation group and adds our custom extensions to it.
---@param texture Texture
---@return AnimationGroupExtended
function UIElements.CreateAnimationGroup(texture)
	return WidgetExtensions.CreateAnimationGroup(texture)
end

---Check if an object is an `Element` or not.
---@generic T: Element
---@param obj table The object to check
---@param elementType `T` The element type to check for
---@return boolean
function UIElements.IsType(obj, elementType)
	local class = private.elementClasses[elementType]
	assert(class)
	return obj.__isa and obj:__isa(class)
end

---Gets a UI element by its frame (for debugging purposes).
---@param table frame The frame
---@return Element?
function UIElements.GetByFrame(frame)
	return private.activeFrameElementMap[frame]
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NewElementHelper(elementType, id, name)
	local class = private.elementClasses[elementType]
	if not class then
		error("Invalid elementType: "..tostring(elementType))
	end
	local element = nil
	if name then
		private.namedElements[name] = private.namedElements[name] or class(name)
		element = private.namedElements[name]
		assert(_G[name] == element:_GetBaseFrame())
	else
		if not private.objectPools[class] then
			private.objectPools[class] = ObjectPool.New("UI_"..class.__name, class, 1)
		end
		element = private.objectPools[class]:Get()
	end
	private.activeFrameElementMap[element:_GetBaseFrame()] = element
	element:SetId(id)
	element:Acquire()
	return element
end

function private.GetDebugName(typePrefix, element)
	return strjoin(":", typePrefix, element.__class.__name, format("%06x", random(0, 2 ^ 24 - 1)))
end
