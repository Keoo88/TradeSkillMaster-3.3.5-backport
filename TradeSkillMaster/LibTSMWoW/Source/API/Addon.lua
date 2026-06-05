-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local Addon = LibTSMWoW:Init("API.Addon")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the number of installed addons.
---@return number
function Addon.GetNum()
	return C_AddOns.GetNumAddOns()
end

---Gets info on a given addon.
---@param nameOrIndex string|number Either the name or index of the addon
---@return string name
---@return string version
---@return boolean loaded
---@return boolean loadable
function Addon.GetInfo(nameOrIndex)
	local name, _, _, loadable = C_AddOns.GetAddOnInfo(nameOrIndex)
	loadable = loadable and true or false
	local version = strtrim(C_AddOns.GetAddOnMetadata(name, "X-Curse-Packaged-Version") or C_AddOns.GetAddOnMetadata(name, "Version") or "")
	local loaded = C_AddOns.IsAddOnLoaded(nameOrIndex)
	return name, version, loaded, loadable
end

---Checks if an addon is installed.
---@param name string The name of the addon
---@return boolean
function Addon.IsInstalled(name)
	return select(2, C_AddOns.GetAddOnInfo(name)) and true or false
end

---Checks if an addon is currently enabled.
---@param name string The name of the addon
---@return boolean
function Addon.IsEnabled(name)
	local character = UnitName("player")
	return C_AddOns.GetAddOnEnableState(name, character) == Enum.AddOnEnableState.All and select(4, C_AddOns.GetAddOnInfo(name))
end

---Enables the specified addon.
---@param name string The name of the addon
function Addon.Enable(name)
	C_AddOns.EnableAddOn(name)
end
