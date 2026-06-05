-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local Path = LibTSMTypes:Init("Group.Path")
local String = LibTSMTypes:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local ROOT_GROUP_PATH = ""
local GROUP_SEP = "`"
local private = {
	sortLookupTemp = {},
}
---@alias GroupPathValue string



-- ============================================================================
-- Module Functions
-- ============================================================================

---Gets the root group path.
---@return GroupPathValue
function Path.GetRoot()
	return ROOT_GROUP_PATH
end

---Checks if a group path is valid.
---@param groupPath GroupPathValue The group path
---@return boolean
function Path.IsValid(groupPath)
	return not strmatch(groupPath, GROUP_SEP..GROUP_SEP)
end

---Returns whether or not a group name is valid.
---@param name string The name
---@return boolean
function Path.IsValidName(name)
	return name ~= ROOT_GROUP_PATH and not strfind(name, GROUP_SEP)
end

---Converts the group path into a sortable representation.
---@param groupPath GroupPathValue The group path
---@return string
function Path.GetSortableString(groupPath)
	local str = gsub(groupPath, GROUP_SEP, "\001")
	return strlower(str)
end

---Gets the name of the group from a group path.
---@param groupPath GroupPathValue The group path
---@return string
function Path.GetName(groupPath)
	local _, name = private.SplitPath(groupPath)
	return name
end

---Gets the parent group path or nil for the given group path.
---@param groupPath GroupPathValue The group path
---@return GroupPathValue?
function Path.GetParent(groupPath)
	local parentPath = private.SplitPath(groupPath)
	return parentPath
end

---Splits a group path into the parent group path and name.
---@param groupPath GroupPathValue The group path
---@return GroupPathValue?
---@return string
function Path.Split(groupPath)
	return private.SplitPath(groupPath)
end

---Creates a new group path by joining the components.
---@param ... string The components
---@return GroupPathValue
function Path.Join(...)
	if select(1, ...) == ROOT_GROUP_PATH then
		return Path.Join(select(2, ...))
	end
	return strjoin(GROUP_SEP, ...)
end

---Checks whether a group path is the child of another.
---@param groupPath GroupPathValue The group path to check
---@param parentPath GroupPathValue The parent group path to compare with
---@return boolean
function Path.IsChild(groupPath, parentPath)
	if parentPath == ROOT_GROUP_PATH then
		return groupPath ~= ROOT_GROUP_PATH
	end
	local parentSearchStr = parentPath..GROUP_SEP
	return strsub(groupPath, 1, #parentSearchStr) == parentSearchStr
end

---Returns whether or not the group path is a top-level group.
---@param groupPath GroupPathValue The group path
---@return boolean
function Path.IsTopLevel(groupPath)
	return not strmatch(groupPath, GROUP_SEP)
end

---Returns whether or not the group path is the root group.
---@param groupPath GroupPathValue The group path
---@return boolean
function Path.IsRoot(groupPath)
	return groupPath == ROOT_GROUP_PATH
end

---Formats a group path for display to the user.
---@param groupPath GroupPathValue The group path
---@return string
function Path.Format(groupPath)
	local result = gsub(groupPath, GROUP_SEP, "->")
	return result
end

---Gets the relative path between two group paths.
---@param groupPath GroupPathValue The group path
---@param prefixGroupPath GroupPathValue The base group path component
---@return GroupPathValue
function Path.GetRelative(groupPath, prefixGroupPath)
	if groupPath == prefixGroupPath then
		return ROOT_GROUP_PATH
	end
	local relativePath, numSubs = gsub(groupPath, "^"..String.Escape(prefixGroupPath)..GROUP_SEP, "")
	assert(numSubs == 1 and relativePath)
	return relativePath
end

---Gets the top level group for a group path.
---@param groupPath GroupPathValue The group path
---@return GroupPathValue
function Path.GetTopLevel(groupPath)
	assert(groupPath ~= ROOT_GROUP_PATH)
	return strmatch(groupPath, "^([^"..GROUP_SEP.."]+)")
end

---Gets the level of a group path (top-level groups are 1)
---@param groupPath GroupPathValue The group path
---@return number
function Path.GetLevel(groupPath)
	return select('#', strsplit(GROUP_SEP, groupPath))
end

---Sorts a list of group paths.
---@param list GroupPathValue[]
function Path.SortPaths(list)
	assert(not next(private.sortLookupTemp))
	for _, groupPath in ipairs(list) do
		private.sortLookupTemp[groupPath] = Path.GetSortableString(groupPath)
	end
	Table.SortWithValueLookup(list, private.sortLookupTemp)
	wipe(private.sortLookupTemp)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.SplitPath(groupPath)
	local parentPath, groupName = strmatch(groupPath, "^(.+)"..GROUP_SEP.."([^"..GROUP_SEP.."]+)$")
	if parentPath then
		return parentPath, groupName
	elseif groupPath ~= ROOT_GROUP_PATH then
		return ROOT_GROUP_PATH, groupPath
	else
		return nil, groupPath
	end
end
