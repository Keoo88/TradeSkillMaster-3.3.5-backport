-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Theme = LibTSMUI:From("LibTSMService"):Include("UI.Theme")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local GroupOperation = LibTSMUI:From("LibTSMTypes"):Include("GroupOperation")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local private = {}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationGroupLine = UIElements.Define("OperationGroupLine", "Frame")
OperationGroupLine:_ExtendStateSchema()
	:AddOptionalStringField("groupPath")
	:AddOptionalStringField("operationType")
	:AddOptionalStringField("operationName")
	:Commit()
OperationGroupLine:_AddActionScripts("OnViewGroup", "OnRemoved")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationGroupLine:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("OPERATION_GROUP_LINE", self._state, self:__closure("_ActionHandler"))
end

function OperationGroupLine:Acquire()
	self.__super:Acquire()
	self:SetLayout("HORIZONTAL")
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("Text", "text")
		:SetWidth("AUTO")
		:SetFont("BODY_BODY2")
		:SetTextColorPublisher(self._state:PublisherForKeyChange("groupPath")
			:IgnoreNil()
			:MapWithFunction(Group.GetLevel)
			:MapWithFunction(Theme.GetGroupColorKey)
		)
		:SetTextPublisher(self._state:PublisherForKeyChange("groupPath")
			:IgnoreNil()
			:MapWithFunction(private.GroupPathToName)
		)
	)
	self:AddChild(UIElements.New("Button", "viewBtn")
		:SetMargin(2, 2, 0, 0)
		:SetBackgroundAndSize("iconPack.14x14/Groups")
		:SetManager(self._childManager)
		:SetAction("OnClick", "ACTION_VIEW_GROUP")
		:SetTooltip(L["Open this group."], "__parent")
	)
	self:AddChild(UIElements.New("Button", "removeBtn")
		:SetBackgroundAndSize("iconPack.14x14/Close/Default")
		:SetManager(self._childManager)
		:SetAction("OnClick", "ACTION_REMOVE_GROUP")
		:SetTooltip(L["Remove this operation from the group."], "__parent")
	)
	self:AddChild(UIElements.New("Spacer", "spacer"))
	self._state:SetAutoStorePaused(false)
end

---Sets the group and operation info.
---@param groupPath string The group path
---@param operationType string The type of the operation
---@param operationName string The name of the operation
---@return OperationGroupLine
function OperationGroupLine:SetGroupAndOperation(groupPath, operationType, operationName)
	self._state.groupPath = groupPath
	self._state.operationType = operationType
	self._state.operationName = operationName
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationGroupLine.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_VIEW_GROUP" then
		self:_SendActionScript("OnViewGroup", state.groupPath)
	elseif action == "ACTION_REMOVE_GROUP" then
		GroupOperation.Remove(state.groupPath, state.operationType, state.operationName)
		self:_SendActionScript("OnRemoved", self)
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GroupPathToName(groupPath)
	return groupPath == Group.GetRootPath() and L["Base Group"] or Group.GetName(groupPath)
end
