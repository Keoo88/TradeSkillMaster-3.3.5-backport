-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local ADDON_NAME = select(1, ...)
local TSM = select(2, ...) ---@type TSM
local Log = TSM.LibTSMUtil:Include("Util.Log")
local AddonSettings = TSM.LibTSMApp:Include("Service.AddonSettings")
local Lifecycle = TSM.LibTSMWoW:Include("Util.Lifecycle")
local LibTSMClass = LibStub("LibTSMClass")
local private = {
	queues = {
		OnInitialize = {},
		OnEnable = {},
		OnDisable = {},
		OnDisableLate = {},
	},
}
local TIME_WARNING_THRESHOLD = 0.02
local NEXT_FUNC_NAME = {
	[""] = "OnInitialize",
	["OnInitialize"] = "OnEnable",
	["OnEnable"] = "OnDisable",
	["OnDisable"] = "OnDisableLate",
}



-- ============================================================================
-- AddonPackage Class
-- ============================================================================

---@class AddonPackage
---@field OnInitialize fun(settingsDB: SettingsDB)
local AddonPackage = LibTSMClass.DefineClass("AddonPackage")

function AddonPackage:__init(name)
	self._name = name
	tinsert(private.queues[NEXT_FUNC_NAME[""]], self)
end

function AddonPackage:__tostring()
	return self._name
end

---Creates a new application-level module.
---@param name string The name of the module
---@return AddonPackage
function AddonPackage:NewPackage(name)
	local package = AddonPackage(name)
	assert(not self[name])
	self[name] = package
	return package
end



-- ============================================================================
-- Lifecycle Handling
-- ============================================================================

function private.ProcessQueue(funcName, maxTime, ...)
	local queue = private.queues[funcName]
	if maxTime == math.huge then
		-- This is a test event so don't modify the queues
		for _, addon in ipairs(queue) do
			private.CallFunction(addon, funcName, ...)
		end
		return true
	else
		local nextQueue = NEXT_FUNC_NAME[funcName] and private.queues[NEXT_FUNC_NAME[funcName]] or nil
		while #queue > 0 and TSM.LibTSMUtil.GetTime() < maxTime do
			local addon = tremove(queue, 1)
			private.CallFunction(addon, funcName, ...)
			if nextQueue then
				tinsert(nextQueue, addon)
			end
		end
		return #queue == 0
	end
end

function private.DoInitialize(maxTime)
	return private.ProcessQueue("OnInitialize", maxTime, AddonSettings.GetDB())
end

function private.DoEnable(maxTime)
	return private.ProcessQueue("OnEnable", maxTime)
end

function private.DoDisable(maxTime)
	return private.ProcessQueue("OnDisable", maxTime) and private.ProcessQueue("OnDisableLate", maxTime)
end

function private.CallFunction(addon, funcName, ...)
	if not addon[funcName] then
		return
	end
	local startTime = TSM.LibTSMUtil.GetTime()
	addon[funcName](...)
	local timeTaken = TSM.LibTSMUtil.GetTime() - startTime
	if timeTaken > TIME_WARNING_THRESHOLD then
		Log.Warn("%s.%s() took %0.5fs", addon, funcName, timeTaken)
	end
end



-- ============================================================================
-- Initialization Code
-- ============================================================================

do
	Lifecycle.RegisterCallback(function(event, maxTime)
		if event == Lifecycle.EVENT.LOADED then
			return private.DoInitialize(maxTime)
		elseif event == Lifecycle.EVENT.LOGIN then
			return private.DoEnable(maxTime)
		elseif event == Lifecycle.EVENT.LOGOUT then
			return private.DoDisable(maxTime)
		else
			error("Unknown event: "..tostring(event))
		end
	end)

	LibTSMClass.ConstructWithTable(TSM, AddonPackage, ADDON_NAME)
end
