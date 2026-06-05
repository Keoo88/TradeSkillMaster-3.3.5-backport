-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_TABLE = select(2, ...)
local LibTSMCore = {} ---@class LibTSMCore
ADDON_TABLE.LibTSMCore = LibTSMCore
local LibTSMClass = LibStub("LibTSMClass")
local private = {
	components = {}, ---@type LibTSMComponent[]
	componentByModule = {}, ---@type table<LibTSMModule,LibTSMComponent>
	timeFunc = nil,
	versionStr = nil,
	versionIsDev = nil,
	versionIsTest = nil,
	didLoad = false,
	allContexts = {}, ---@type LibTSMModuleContext[]
}
local GAME_VERSION = nil
do
	assert(WOW_PROJECT_ID)
	if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
		GAME_VERSION = "VANILLA"
	elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
		GAME_VERSION = "BCC"
	elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
		GAME_VERSION = "WRATH"
	elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
		GAME_VERSION = "MOP"
	elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
		GAME_VERSION = "RETAIL"
	end
	assert(GAME_VERSION, "Invalid game version: "..tostring(WOW_PROJECT_ID))

	local versionRaw = C_AddOns.GetAddOnMetadata("TradeSkillMaster", "Version")
	local isDevVersion = strmatch(versionRaw, "^@tsm%-project%-version@$") and true or false
	private.versionStr = isDevVersion and "Dev" or versionRaw
	private.versionIsDev = isDevVersion
	private.versionIsTest = versionRaw == "v4.99.99"
end



-- ============================================================================
-- LibTSMModule Metatable
-- ============================================================================

---@class LibTSMModule
local MODULE_METHODS = {}

---Registers the function be called when the module is loaded.
---@protected
---@param func fun() The function to call
function MODULE_METHODS:OnModuleLoad(func)
	private.componentByModule[self]:_SetModuleLoadFunc(self, func)
end

---Registers the function be called when the module is unloaded.
---@protected
---@param func fun() The function to call
---@param isLate? boolean Runs the unload as late as possible in the process
function MODULE_METHODS:OnModuleUnload(func, isLate)
	private.componentByModule[self]:_SetModuleUnloadFunc(self, func, isLate)
end

local MODULE_MT = {
	__index = MODULE_METHODS,
	__newindex = function(self, key, value)
		assert(not private.componentByModule[self]:_DidModuleLoad(self) and not MODULE_METHODS[key])
		rawset(self, key, value)
	end,
	__metatable = false,
}



-- ============================================================================
-- LibTSMComponent Class - Meta Methods
-- ============================================================================

local LibTSMComponent = LibTSMClass.DefineClass("LibTSMComponent") ---@class LibTSMComponent

---@class LibTSMModuleContext
---@field path string
---@field module LibTSMModule
---@field moduleLoadFunc fun()?
---@field moduleLoadTime number
---@field moduleUnloadFunc fun()?
---@field moduleUnloadTime number
---@field moduleUnloadIsLate boolean

---@private
function LibTSMComponent:__init(name)
	self._name = name
	self._moduleContext = {} ---@type table<LibTSMModule|string,LibTSMModuleContext>
	self._classTypes = {} ---@type table<string,Class>
	self._initOrder = {} ---@type LibTSMModuleContext[]
	self._loadOrder = {} ---@type LibTSMModuleContext[]
	self._lateUnload = {} ---@type LibTSMModuleContext[]
	self._dependencies = {} ---@type table<string,LibTSMComponent>
end



-- ============================================================================
-- LibTSMComponent Class - Static Functions
-- ============================================================================

---Returns whether or not we're running within the Vanilla Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsVanillaClassic()
	return GAME_VERSION == "VANILLA"
end

---Returns whether or not we're running within the Burning Crusade Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsBCClassic()
	return GAME_VERSION == "BCC"
end

---Returns whether or not we're running within the Wrath of the Lich King Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsWrathClassic()
	return GAME_VERSION == "WRATH"
end

---Returns whether or not we're running within the Panda Classic version of the game.
---@return boolean
function LibTSMComponent.__static.IsPandaClassic()
	return GAME_VERSION == "MOP"
end

---Returns whether or not we're running within the retail version of the game.
---@return boolean
function LibTSMComponent.__static.IsRetail()
	return GAME_VERSION == "RETAIL"
end

---Gets the current time value (or 0 if no function is registered).
---@return number
function LibTSMComponent.__static.GetTime()
	return private.timeFunc and private.timeFunc() or 0
end

---Gets the version string.
---@return string
function LibTSMComponent.__static.GetVersionStr()
	return private.versionStr
end

---Gets whether or not this is a dev version.
---@return boolean
function LibTSMComponent.__static.IsDevVersion()
	return private.versionIsDev
end

---Gets whether or not this is a test version.
---@return boolean
function LibTSMComponent.__static.IsTestVersion()
	return private.versionIsTest
end




-- ============================================================================
-- LibTSMComponent Class - Public Methods
-- ============================================================================

---Creates a new module.
---@generic T: LibTSMModule
---@param path `T` The path of the module
---@return T
function LibTSMComponent:Init(path)
	assert(type(path) == "string")
	if self._moduleContext[path] then
		error("Module already exists for path: "..tostring(path), 3)
	end
	local moduleObj = setmetatable({}, MODULE_MT)
	private.componentByModule[moduleObj] = self
	local context = {
		path = path,
		module = moduleObj,
		moduleLoadFunc = nil,
		moduleLoadTime = nil,
		moduleUnloadFunc = nil,
		moduleUnloadTime = nil,
		moduleUnloadIsLate = nil,
	}
	-- Store a reference to the context by both the module object and the path
	self._moduleContext[path] = context
	self._moduleContext[moduleObj] = context
	tinsert(self._initOrder, context)
	tinsert(private.allContexts, context)
	return moduleObj
end

---Creates a new class type.
---@generic T: Class
---@param name `T` The name of the class
---@return T
function LibTSMComponent:DefineClassType(name)
	assert(type(name) == "string")
	if self._classTypes[name] then
		error("Class type already exists: "..tostring(name), 3)
	end
	local class = LibTSMClass.DefineClass(name)
	self._classTypes[name] = class
	return class
end

---Returns an existing module.
---@generic T
---@param path `T` The path of the module
---@return T
function LibTSMComponent:Include(path)
	local context = self._moduleContext[path]
	if not context then
		error("Module doesn't exist for path: "..tostring(path), 3)
	end
	self:_ProcessModuleLoad(context)
	return context.module
end

---Returns a class type.
---@generic T
---@param name `T` THe name of the class
---@return T
function LibTSMComponent:IncludeClassType(name)
	local class = self._classTypes[name]
	if not class then
		error("Class type doesn't exist: "..tostring(name), 3)
	end
	return class
end

---Retrieves a component which the current component depends on.
---@generic T: LibTSMComponent
---@param name `T` The name of the component
---@return T
function LibTSMComponent:From(name)
	local component = self._dependencies[name]
	assert(component)
	return component
end

---Adds a component as a dependency of the current component.
---@param name string The name of the component
---@return LibTSMComponent
function LibTSMComponent:AddDependency(name)
	assert(type(name) == "string" and not self._dependencies[name])
	local component = private.components[name]
	assert(component)
	self._dependencies[name] = component
	return self
end



-- ============================================================================
-- LibTSMComponent Class - Private Methods
-- ============================================================================

---@private
function LibTSMComponent:_SetModuleLoadFunc(module, func)
	local context = self._moduleContext[module]
	assert(context and not context.moduleLoadFunc and not context.moduleLoadTime and type(func) == "function")
	context.moduleLoadFunc = func
end

---@private
function LibTSMComponent:_SetModuleUnloadFunc(module, func, isLate)
	local context = self._moduleContext[module]
	assert(context and not context.moduleUnloadFunc and not context.moduleUnloadTime and type(func) == "function")
	context.moduleUnloadFunc = func
	context.moduleUnloadIsLate = isLate or false
end

---@private
function LibTSMComponent:_DidModuleLoad(module)
	local context = self._moduleContext[module]
	assert(context)
	return context.moduleLoadTime and true or false
end

function LibTSMComponent.__private:_ProcessModuleLoad(context)
	if context.moduleLoadTime then
		return
	end
	tinsert(self._loadOrder, context)
	context.moduleLoadTime = 0
	if context.moduleLoadFunc then
		local startTime = self.GetTime()
		context.moduleLoadFunc()
		context.moduleLoadTime = self.GetTime() - startTime
	end
end

---@private
function LibTSMComponent:_LoadAll()
	-- Load any module which hasn't already
	for _, context in ipairs(self._initOrder) do
		self:_ProcessModuleLoad(context)
	end
end

---@private
function LibTSMComponent:_UnloadAll(maxTime)
	if maxTime == math.huge then
		-- Don't mutate our `_loadOrder` queue
		assert(#self._lateUnload == 0)
		for _, context in ipairs(self._loadOrder) do
			self:_UnloadModule(context)
		end
	else
		-- Unload in the opposite order we loaded
		while #self._loadOrder > 0 and self.GetTime() < maxTime do
			local context = tremove(self._loadOrder) ---@type LibTSMModuleContext
			context.moduleUnloadTime = self:_UnloadModule(context)
		end
	end
	-- Run the late unload functions
	while #self._lateUnload > 0 and self.GetTime() < maxTime do
		local context = tremove(self._lateUnload) ---@type LibTSMModuleContext
		local startTime = self.GetTime()
		context.moduleUnloadFunc()
		context.moduleUnloadTime = self.GetTime() - startTime
	end
	if maxTime == math.huge then
		assert(#self._lateUnload == 0)
		return true
	end
	return #self._loadOrder == 0 and #self._lateUnload == 0
end

---@param context LibTSMModuleContext
function LibTSMComponent:_UnloadModule(context)
	if context.moduleUnloadTime then
		return context.moduleUnloadTime
	end
	if context.moduleUnloadIsLate then
		tinsert(self._lateUnload, context)
		return nil
	elseif context.moduleUnloadFunc then
		local startTime = self.GetTime()
		context.moduleUnloadFunc()
		return self.GetTime() - startTime
	else
		return 0
	end
end

---@private
function LibTSMComponent:_GetName()
	return self._name
end



-- ============================================================================
-- LibTSMCore Functions
-- ============================================================================

---Creats a new component.
---@param name string The name of the component
---@return LibTSMComponent
function LibTSMCore.NewComponent(name)
	assert(type(name) == "string" and not private.components[name])
	local component = LibTSMComponent(name)
	tinsert(private.components, component)
	private.components[name] = component
	return component
end

---Sets the time function.
---@param timeFunc fun(): number A function which returns the time with high precision
function LibTSMCore.SetTimeFunction(func)
	private.timeFunc = func
end

---Loads all modules.
function LibTSMCore.LoadAll()
	assert(not private.didLoad)
	private.didLoad = true
	for _, component in ipairs(private.components) do
		component:_LoadAll()
	end
end

---Unloads all modules.
---@param maxTime number The max time before aborting early
---@return boolean
function LibTSMCore.UnloadAll(maxTime)
	-- Unload in the opposite order
	for i = #private.components, 1, -1 do
		if not private.components[i]:_UnloadAll(maxTime) then
			return false
		end
	end
	return true
end

---Returns an iterator over all available modules.
---@return fun(): number, string, number, number # An iterator with fields: `index`, `componentName`, `modulePath`, `loadTime`, `unloadTime`
function LibTSMCore.ModuleInfoIterator()
	return private.ModuleInfoIterator, nil, 0
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ModuleInfoIterator(_, index)
	index = index + 1
	local context = private.allContexts[index]
	if not context then
		return
	end
	return index, private.componentByModule[context.module]:_GetName(), context.path, context.moduleLoadTime, context.moduleUnloadTime
end
