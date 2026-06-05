-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local Analytics = LibTSMUI:From("LibTSMUtil"):Include("Util.Analytics")
local String = LibTSMUI:From("LibTSMUtil"):Include("Lua.String")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local DragContext = LibTSMUI:Include("Util.DragContext")
local UIElements = LibTSMUI:Include("Util.UIElements")
local DRAG_SCROLL_SPEED_FACTOR = 12
local MOVE_FRAME_PADDING = 8
local ADD_TEXTURE = "iconPack.14x14/Add/Circle"
local DELETE_TEXTURE = "iconPack.14x14/Delete"
local ICON_SPACING = 4



-- ============================================================================
-- Element Definition
-- ============================================================================

local ManagementGroupTree = UIElements.Define("ManagementGroupTree", "GroupTree")
ManagementGroupTree:_ExtendStateSchema()
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ManagementGroupTree:__init()
	self.__super:__init()

	self._moveFrame = nil
	self._dragButton = nil
	self._dragGroupPath = nil
	self._selectedGroup = nil
	self._onGroupSelectedHandler = nil
	self._onNewGroupHandler = nil
	self._onDragRecievedHandler = nil
	self._scrollAmount = 0
end

function ManagementGroupTree:Acquire()
	self._moveFrame = UIElements.New("Frame", self._id.."_MoveFrame")
		:SetLayout("VERTICAL")
		:SetHeight(20)
		:SetStrata("TOOLTIP")
		:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
		:SetBorderColor("INDICATOR")
		:SetContext(self)
		:AddChild(UIElements.New("Text", "text")
			:SetFont("BODY_BODY3")
			:SetJustifyH("CENTER")
		)
	self._moveFrame:SetParent(self:_GetBaseFrame())
	self._moveFrame:Hide()
	self._moveFrame:SetScript("OnShow", self:__closure("_HandleMoveFrameShow"))
	self._moveFrame:SetScript("OnUpdate", self:__closure("_HandleMoveFrameUpdate"))

	self.__super:Acquire()
end

function ManagementGroupTree:Release()
	self._selectedGroup = nil
	self._onGroupSelectedHandler = nil
	self._onNewGroupHandler = nil
	self._onDragRecievedHandler = nil
	self._moveFrame:Release()
	self._moveFrame = nil
	self._dragButton = nil
	self._dragGroupPath = nil
	self.__super:Release()
end

---Sets the selected group.
---@param groupPath string The selected group's path
---@param redraw boolean Whether or not to redraw the management group tree
---@return ManagementGroupTree
function ManagementGroupTree:SetSelectedGroup(groupPath, redraw)
	if groupPath == self._selectedGroup then
		return
	end
	local prevSelectedGroup = self._selectedGroup
	self._selectedGroup = groupPath

	if groupPath then
		local row = self:_GetRowForGroupPath(groupPath)
		if row then
			self:_DrawSelectedState(row)
		end
	end
	if prevSelectedGroup then
		local prevRow = self:_GetRowForGroupPath(prevSelectedGroup)
		if prevRow then
			self:_DrawSelectedState(prevRow)
		end
	end

	self._selectedGroup = groupPath
	if self._onGroupSelectedHandler then
		self:_onGroupSelectedHandler(groupPath)
	end

	if redraw then
		-- Make sure this group is visible (its parent is expanded)
		local parent = Group.GetParent(groupPath)
		local changed = false
		if self._contextTable.collapsed[Group.GetRootPath()] then
			self._contextTable.collapsed[Group.GetRootPath()] = nil
			changed = true
		end
		while parent and parent ~= Group.GetRootPath() do
			if self._contextTable.collapsed[parent] then
				self._contextTable.collapsed[parent] = nil
				changed = true
			end
			parent = Group.GetParent(parent)
		end
		if changed then
			self:_HandleQueryUpdate()
		end
		self:_ScrollToRow(Table.KeyByValue(self._groupPath, groupPath))
	end
	if self._onGroupSelectedHandler then
		self:_onGroupSelectedHandler(groupPath)
	end
	return self
end

---Registers a script handler.
---@param script string The script to register for (supported scripts: `OnGroupSelected`)
---@param handler function The script handler which will be called with the management group tree object followed by
-- any arguments to the script
---@return ManagementGroupTree
function ManagementGroupTree:SetScript(script, handler)
	if script == "OnGroupSelected" then
		self._onGroupSelectedHandler = handler
	elseif script == "OnNewGroup" then
		self._onNewGroupHandler = handler
	elseif script == "OnDragRecieved" then
		self._onDragRecievedHandler = handler
	else
		error("Unknown ManagementGroupTree script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowAcquired(row)
	self.__super:_HandleRowAcquired(row)

	row:EnableDragging(self:__closure("_HandleDragStart"), nil, self:__closure("_HandleDragReceived"))

	-- Add
	local add = row:AddTexture("add")
	add:TSMSetTextureAndSize(ADD_TEXTURE)

	-- Delete
	local delete = row:AddTexture("delete")
	delete:TSMSetTextureAndSize(DELETE_TEXTURE)

	-- Layout the elements
	delete:SetPoint("RIGHT", -Theme.GetColSpacing() * 1.5, 0)
	add:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowDraw(row)
	self.__super:_HandleRowDraw(row)
	self:_DrawAddDeleteIcons(row)
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowEnter(row)
	self.__super:_HandleRowEnter(row)
	self:_DrawAddDeleteIcons(row)
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowLeave(row)
	self.__super:_HandleRowLeave(row)
	self:_DrawAddDeleteIcons(row)
end

---@param row ListRow
function ManagementGroupTree.__protected:_DrawAddDeleteIcons(row)
	local groupPath = self._groupPath[row:GetDataIndex()]
	local isSelected = self:_IsSelected(groupPath)
	local add = row:GetTexture("add")
	local delete = row:GetTexture("delete")
	local text = row:GetText("text")
	if row:IsHovering() or isSelected then
		-- Re-apply the icon texture/size and anchor on every draw. Row textures come from a
		-- shared recycle pool, so relying solely on the one-time setup in _HandleRowAcquired can
		-- leave the delete icon without its texture/texcoords on some redraws -- the icon then
		-- renders blank even though its size and click region (IsMouseOver) are still correct.
		add:TSMSetTextureAndSize(ADD_TEXTURE)
		add:Show()
		text:SetPoint("RIGHT", add, "LEFT", -ICON_SPACING, 0)
		if groupPath == Group.GetRootPath() then
			delete:Hide()
			add:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
		else
			delete:TSMSetTextureAndSize(DELETE_TEXTURE)
			delete:SetPoint("RIGHT", -Theme.GetColSpacing() * 1.5, 0)
			delete:Show()
			add:SetPoint("RIGHT", delete, "LEFT", -ICON_SPACING, 0)
		end
	else
		add:Hide()
		delete:Hide()
		text:SetPoint("RIGHT", -Theme.GetColSpacing(), 0)
	end
end

---@param row ListRow
function ManagementGroupTree.__protected:_DrawSelectedState(row)
	self.__super:_DrawSelectedState(row)
	self:_DrawAddDeleteIcons(row)
end

function ManagementGroupTree.__protected:_SetCollapsed(groupPath, collapsed)
	self.__super:_SetCollapsed(groupPath, collapsed)
	if collapsed and self._selectedGroup ~= groupPath and strmatch(self._selectedGroup, "^"..String.Escape(groupPath)) then
		-- We collapsed a parent of the selected group, so select the group we just collapsed instead
		self:SetSelectedGroup(groupPath, true)
	end
end

function ManagementGroupTree.__protected:_IsSelected(groupPath)
	return groupPath == self._selectedGroup
end

---@param row ListRow
function ManagementGroupTree.__protected:_HandleRowClick(row, mouseButton)
	if self.__super:_HandleRowClick(row, mouseButton) then
		return
	end

	local groupPath = self._groupPath[row:GetDataIndex()]
	if row:GetTexture("add"):IsMouseOver() then
		self:_HandleAddClick(groupPath)
		return
	elseif row:GetTexture("delete"):IsMouseOver() then
		self:_HandleDeleteClick(groupPath)
		return
	end

	if self._selectedGroup == groupPath then
		return
	end
	local prevSelectedGroup = self._selectedGroup
	self._selectedGroup = groupPath

	self:_DrawSelectedState(row)
	if prevSelectedGroup then
		local prevRow = self:_GetRowForGroupPath(prevSelectedGroup)
		if prevRow then
			self:_DrawSelectedState(prevRow)
		end
	end

	self._selectedGroup = groupPath
	if self._onGroupSelectedHandler then
		self:_onGroupSelectedHandler(groupPath)
	end
end

function ManagementGroupTree.__private:_HandleAddClick(groupPath)
	local newGroupPath = Group.JoinPath(groupPath, L["New Group"])
	if Group.Exists(newGroupPath) then
		local num = 1
		while Group.Exists(newGroupPath.." "..num) do
			num = num + 1
		end
		newGroupPath = newGroupPath.." "..num
	end
	GroupOperation.CreateGroup(newGroupPath)
	Analytics.Action("CREATED_GROUP", newGroupPath)
	self:SetSelectedGroup(newGroupPath, true)
	if self._onNewGroupHandler then
		self:_onNewGroupHandler()
	end
end

function ManagementGroupTree.__private:_HandleDeleteClick(groupPath)
	local groupColor = Theme.GetGroupColor(Group.GetLevel(groupPath))
	local desc = format(L["Deleting this group (%s) will also remove any sub-groups attached to this group."], groupColor:ColorText(Group.GetName(groupPath)))
	self:GetBaseElement():ShowConfirmationDialog(L["Delete Group?"], desc, self:__closure("_DeleteConfirmed"), groupPath)
end

function ManagementGroupTree.__private:_DeleteConfirmed(groupPath)
	GroupOperation.DeleteGroup(groupPath)
	Analytics.Action("DELETED_GROUP", groupPath)
	self:SetSelectedGroup(Group.GetRootPath(), true)
end

---@param row ListRow
function ManagementGroupTree.__private:_HandleDragStart(row, mouseButton)
	local groupPath = self._groupPath[row:GetDataIndex()]
	if groupPath == Group.GetRootPath() then
		-- Don't do anything for the root group
		return
	end
	self._dragButton = mouseButton
	self._dragGroupPath = groupPath
	self._moveFrame:Show()
	self._moveFrame:SetHeight(self._rowHeight)
	local moveFrameText = self._moveFrame:GetElement("text")
	moveFrameText:SetTextColor(Theme.GetGroupColorKey(Group.GetLevel(groupPath)))
	moveFrameText:SetText(Group.GetName(groupPath))
	moveFrameText:SetWidth(1000)
	moveFrameText:Draw()
	self._moveFrame:SetWidth(moveFrameText:GetStringWidth() + MOVE_FRAME_PADDING * 2)
	self._moveFrame:Draw()
end

---@param row ListRow
function ManagementGroupTree.__private:_HandleDragReceived(row)
	if self._dragGroupPath then
		self._dragButton = nil
		self._moveFrame:Hide()
		local destPath = self._groupPath[row:GetDataIndex()]
		local oldPath = self._dragGroupPath
		self._dragGroupPath = nil
		if not destPath or destPath == oldPath or Group.IsChild(destPath, oldPath) then
			return
		end
		local newPath = Group.JoinPath(destPath, Group.GetName(oldPath))
		if oldPath == newPath then
			return
		elseif Group.Exists(newPath) then
			ChatMessage.PrintfUser(L["Failed to move group, as a group with the same name already exists in the target location."])
			return
		end

		GroupOperation.MoveGroup(oldPath, newPath)
		Analytics.Action("MOVED_GROUP", oldPath, newPath)
		self:SetSelectedGroup(newPath, true)
	else
		local context = DragContext.Get()
		if self._onDragRecievedHandler and context then
			self:_onDragRecievedHandler(context, self._groupPath[row:GetDataIndex()])
		end
	end
end

function ManagementGroupTree.__private:_HandleMoveFrameShow()
	self._scrollAmount = 0
end

function ManagementGroupTree.__private:_HandleMoveFrameUpdate()
	if not IsMouseButtonDown(self._dragButton) then
		-- No longer dragging
		self._dragGroupPath = nil
		self._dragButton = nil
		self._moveFrame:Hide()
		return
	end

	local uiScale = self._moveFrame:_GetBaseFrame():GetEffectiveScale()
	local x, y = GetCursorPosition()
	x = x / uiScale
	y = y / uiScale
	self._moveFrame:_GetBaseFrame():SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)

	-- Figure out if we're above or below the frame for scrolling while dragging
	local top = self:_GetBaseFrame():GetTop()
	local bottom = self:_GetBaseFrame():GetBottom()
	if y > top then
		self._scrollAmount = top - y
	elseif y < bottom then
		self._scrollAmount = bottom - y
	else
		self._scrollAmount = 0
	end

	self._vScrollbar:SetValue(self._vScrollbar:GetValue() + self._scrollAmount / DRAG_SCROLL_SPEED_FACTOR)
end
