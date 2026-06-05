-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local Tooltip = LibTSMUI:Include("Tooltip")
local UIElements = LibTSMUI:Include("Util.UIElements")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local ROW_HEIGHT = 24
local EXPANDER_SPACING = 2
local FLAG_WIDTH = 6
local FLAG_SPACING = 2
local EXPANDER_TEXTURE_EXPANDED = "iconPack.14x14/Caret/Down"
local EXPANDER_TEXTURE_COLLAPSED = "iconPack.14x14/Caret/Right"



-- ============================================================================
-- Element Definition
-- ============================================================================

local GroupTree = UIElements.Define("GroupTree", "List", "ABSTRACT")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function GroupTree:__init()
	self.__super:__init()

	self._groupPath = {}
	self._allGroupPaths = {}
	self._contextTable = nil
	self._defaultContextTable = nil
	self._hasChildrenLookup = {}
	self._query = nil
	self._searchStr = ""
	self._moduleOperationFilter = nil
end

function GroupTree:Acquire()
	self.__super:Acquire(ROW_HEIGHT)
end

function GroupTree:Release()
	wipe(self._groupPath)
	wipe(self._allGroupPaths)
	if self._query then
		self._query:Release()
		self._query = nil
	end
	self._searchStr = ""
	self._moduleOperationFilter = nil
	self._contextTable = nil
	self._defaultContextTable = nil
	wipe(self._hasChildrenLookup)
	self.__super:Release()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Sets the context table which is used to persist collapsed state.
---@param tbl table The context table
---@param defaultTbl table The default table (required fields: `collapsed`)
---@return GroupTree
function GroupTree:SetContextTable(tbl, defaultTbl)
	assert(type(defaultTbl.collapsed) == "table")
	tbl.collapsed = tbl.collapsed or CopyTable(defaultTbl.collapsed)
	self._contextTable = tbl
	self._defaultContextTable = defaultTbl
	if self._query then
		self:_HandleQueryUpdate()
	end
	return self
end

---Sets the context table from a settings object.
---@param settings Settings The settings object
---@param key string The setting key
---@return GroupTree
function GroupTree:SetSettingsContext(settings, key)
	return self:SetContextTable(settings[key], settings:GetDefaultReadOnly(key))
end

---Sets the query used to populate the group tree.
---@param query DatabaseQuery The database query object
---@param operationType? string The operation type to filter groups by
---@return GroupTree
function GroupTree:SetQuery(query, operationType)
	assert(query)
	if self._query then
		self._query:Release()
	end
	self._query = query
	self._query:SetUpdateCallback(self:__closure("_HandleQueryUpdate"))
	self._moduleOperationFilter = operationType
	self:_HandleQueryUpdate()
	return self
end

function GroupTree:SetScript(script, handler)
	-- GroupTree doesn't support any scripts
	error("Unknown GroupTree script: "..tostring(script))
end

---Sets the search string.
-- This search string is used to filter the groups which are displayed in the group tree.
---@param searchStr string The search string which filters the displayed groups
---@return GroupTree
function GroupTree:SetSearchString(searchStr)
	self._searchStr = String.Escape(searchStr)
	self:_HandleQueryUpdate()
	return self
end

---Expand every group.
---@return GroupTree
function GroupTree:ExpandAll()
	for _, groupPath in ipairs(self._allGroupPaths) do
		if groupPath ~= Group.GetRootPath() and self._hasChildrenLookup[groupPath] and self._contextTable.collapsed[groupPath] then
			self:_SetCollapsed(groupPath, false)
		end
	end
	self:_HandleQueryUpdate()
	return self
end

---Collapse every group.
---@return GroupTree
function GroupTree:CollapseAll()
	for _, groupPath in ipairs(self._allGroupPaths) do
		if groupPath ~= Group.GetRootPath() and self._hasChildrenLookup[groupPath] and not self._contextTable.collapsed[groupPath] then
			self:_SetCollapsed(groupPath, true)
		end
	end
	self:_HandleQueryUpdate()
	return self
end

---Toggle the expand/collapse all state of the group tree.
---@return GroupTree
function GroupTree:ToggleExpandAll()
	if next(self._contextTable.collapsed) then
		-- at least one group is collapsed, so expand everything
		self:ExpandAll()
	else
		-- nothing is collapsed, so collapse everything
		self:CollapseAll()
	end
	return self
end



-- ============================================================================
-- Protected/Private Class Methods
-- ============================================================================

---@param row ListRow
function GroupTree.__protected:_HandleRowAcquired(row)
	-- Flag
	local flag = row:AddTexture("flag")
	flag:SetDrawLayer("ARTWORK", 1)
	flag:SetWidth(FLAG_WIDTH)
	flag:SetHeight(ROW_HEIGHT - FLAG_SPACING * 2)

	-- Expander
	local expander = row:AddTexture("expander")
	expander:SetDrawLayer("ARTWORK", 1)
	expander:TSMSetSize(EXPANDER_TEXTURE_COLLAPSED)

	-- Text
	local text = row:AddText("text")
	text:SetHeight(ROW_HEIGHT)
	text:TSMSetFont("BODY_BODY2")
	text:SetJustifyH("LEFT")

	-- Layout the elements
	flag:SetPoint("LEFT", FLAG_SPACING, 0)
	expander:SetPoint("LEFT", flag, "RIGHT", EXPANDER_SPACING, 0)
	text:SetPoint("LEFT", expander, "RIGHT", EXPANDER_SPACING, 0)
	text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
end

---@param row ListRow
function GroupTree.__protected:_HandleRowDraw(row)
	local groupPath = self._groupPath[row:GetDataIndex()]
	self:_DrawSelectedState(row)
	self:_DrawRowExpander(row)

	local text = row:GetText("text")
	if groupPath == Group.GetRootPath() then
		text:TSMSetTextColor("FULL_WHITE")
		text:SetText(L["Base Group"])
	else
		text:TSMSetTextColor(Theme.GetGroupColorKey(Group.GetLevel(groupPath)))
		text:SetText(Group.GetName(groupPath))
	end
end

---@param row ListRow
function GroupTree.__protected:_DrawSelectedState(row)
	local groupPath = self._groupPath[row:GetDataIndex()]
	row:SetSelected(self:_IsSelected(groupPath))
	self:_DrawRowFlag(row)
end

---@param row ListRow
function GroupTree.__protected:_DrawRowFlag(row)
	local groupPath = self._groupPath[row:GetDataIndex()]
	local color = nil
	if not self:_IsSelected(groupPath) and not row:IsHovering() then
		color = "PRIMARY_BG_ALT"
	elseif groupPath == Group.GetRootPath() then
		color = "TEXT"
	else
		color = Theme.GetGroupColorKey(Group.GetLevel(groupPath))
	end
	row:GetTexture("flag"):TSMSubscribeColorTexture(color)
end

---@param row ListRow
function GroupTree.__private:_DrawRowExpander(row)
	local groupPath = self._groupPath[row:GetDataIndex()]
	local indentWidth = nil
	local searchIsActive = self._searchStr ~= ""
	if groupPath == Group.GetRootPath() then
		indentWidth = -TextureAtlas.GetWidth(EXPANDER_TEXTURE_COLLAPSED) + EXPANDER_SPACING
	elseif searchIsActive then
		indentWidth = TextureAtlas.GetWidth(EXPANDER_TEXTURE_COLLAPSED) + EXPANDER_SPACING
	else
		indentWidth = (Group.GetLevel(groupPath) - 1) * (TextureAtlas.GetWidth(EXPANDER_TEXTURE_COLLAPSED) + EXPANDER_SPACING)
	end
	local expander = row:GetTexture("expander")
	expander:TSMSetShown(not searchIsActive and groupPath ~= Group.GetRootPath() and self._hasChildrenLookup[groupPath])
	expander:TSMSetTexture(self._contextTable.collapsed[groupPath] and EXPANDER_TEXTURE_COLLAPSED or EXPANDER_TEXTURE_EXPANDED)
	expander:SetPoint("LEFT", row:GetTexture("flag"), "RIGHT", EXPANDER_SPACING + indentWidth, 0)
end

---@param row ListRow
function GroupTree.__protected:_HandleRowClick(row, mouseButton)
	local groupPath = self._groupPath[row:GetDataIndex()]
	local hasExpander = self._searchStr == "" and groupPath ~= Group.GetRootPath() and self._hasChildrenLookup[groupPath]
	if hasExpander and (mouseButton == "RightButton" or row:GetTexture("expander"):IsMouseOver()) then
		self:_SetCollapsed(groupPath, not self._contextTable.collapsed[groupPath])
		self:_HandleQueryUpdate() -- TODO: optimize
		return true
	elseif mouseButton == "RightButton" then
		-- Silently handle all other right clicks
		return true
	end
	return false
end

---@param row ListRow
function GroupTree.__protected:_HandleRowEnter(row)
	if self._searchStr ~= "" then
		row:ShowTooltip(Group.FormatPath(self._groupPath[row:GetDataIndex()]))
	end
	self:_DrawRowFlag(row)
end

function GroupTree.__protected:_HandleRowLeave(row)
	-- The data might not exist anymore, so just hide the tooltip to be safe
	Tooltip.Hide()
	if row:GetDataIndex() then
		self:_DrawRowFlag(row)
	end
end

function GroupTree.__protected:_HandleQueryUpdate()
	if not self._contextTable or not self._query then
		return
	end
	-- Update our groups list
	wipe(self._hasChildrenLookup)
	wipe(self._allGroupPaths)
	wipe(self._groupPath)
	local groups = TempTable.Acquire()
	if self._moduleOperationFilter then
		local shouldKeep = TempTable.Acquire()
		for _, row in self._query:Iterator() do
			local groupPath = row:GetField("groupPath")
			shouldKeep[groupPath] = row:GetField("has"..self._moduleOperationFilter.."Operation")
			if shouldKeep[groupPath] then
				shouldKeep[Group.GetRootPath()] = true
				-- Add all parent groups to the keep table as well
				local checkPath = Group.GetParent(groupPath)
				while checkPath and checkPath ~= Group.GetRootPath() do
					shouldKeep[checkPath] = true
					checkPath = Group.GetParent(checkPath)
				end
			end
		end
		for _, row in self._query:Iterator() do
			local groupPath = row:GetField("groupPath")
			if shouldKeep[groupPath] then
				tinsert(groups, groupPath)
			end
		end
		TempTable.Release(shouldKeep)
	else
		for _, row in self._query:Iterator() do
			tinsert(groups, row:GetField("groupPath"))
		end
	end

	-- Remove collapsed state for any groups which no longer exist or no longer have children
	local pathExists = TempTable.Acquire()
	for i, groupPath in ipairs(groups) do
		pathExists[groupPath] = true
		local nextGroupPath = groups[i + 1]
		self._hasChildrenLookup[groupPath] = nextGroupPath and Group.IsChild(nextGroupPath, groupPath) or nil
	end
	for groupPath in pairs(self._contextTable.collapsed) do
		if groupPath == Group.GetRootPath() or not pathExists[groupPath] or not self._hasChildrenLookup[groupPath] then
			self._contextTable.collapsed[groupPath] = nil
		end
	end
	TempTable.Release(pathExists)

	for _, groupPath in ipairs(groups) do
		tinsert(self._allGroupPaths, groupPath)
		if self._searchStr ~= "" or not self:_IsGroupHidden(groupPath) then
			local groupName = groupPath == Group.GetRootPath() and L["Base Group"] or Group.GetName(groupPath)
			if strmatch(strlower(groupName), self._searchStr) and (self._searchStr == "" or groupPath ~= Group.GetRootPath()) then
				tinsert(self._groupPath, groupPath)
			end
		end
	end
	TempTable.Release(groups)

	self:_SetNumRows(#self._groupPath)
	self:Draw()
end

function GroupTree.__private:_IsGroupHidden(groupPath)
	if groupPath == Group.GetRootPath() then
		return false
	elseif self._contextTable.collapsed[Group.GetRootPath()] then
		return true
	end
	local parent = Group.GetParent(groupPath)
	while parent and parent ~= Group.GetRootPath() do
		if self._contextTable.collapsed[parent] then
			return true
		end
		parent = Group.GetParent(parent)
	end
	return false
end

-- Can be overridden
function GroupTree.__protected:_SetCollapsed(groupPath, collapsed)
	self._contextTable.collapsed[groupPath] = collapsed or nil
end

-- Can be overridden
function GroupTree.__protected:_IsSelected(groupPath)
	return false
end

function GroupTree.__protected:_GetRowForGroupPath(groupPath)
	local index = groupPath and Table.KeyByValue(self._groupPath, groupPath)
	return index and self:_GetRow(index) or nil
end
