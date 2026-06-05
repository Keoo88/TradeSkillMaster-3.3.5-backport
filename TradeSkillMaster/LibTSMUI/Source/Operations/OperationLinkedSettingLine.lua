-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkedSettingLine = UIElements.Define("OperationLinkedSettingLine", "Frame")
OperationLinkedSettingLine:_ExtendStateSchema()
	:AddBooleanField("relationshipSet", false)
	:AddBooleanField("disabled", false)
	:Commit()
OperationLinkedSettingLine:_AddActionScripts("OnRelationshipChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkedSettingLine:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("OPERATION_LINK_SETTING_LINE", self._state, self:__closure("_ActionHandler"))
	self._operationType = nil
	self._operationName = nil
	self._settingKey = nil
end

function OperationLinkedSettingLine:Acquire()
	self.__super:Acquire()
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("Frame", "line")
		:SetLayout("HORIZONTAL")
		:AddChild(UIElements.New("Text", "label")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetTextColorPublisher(self._state:PublisherForExpression([[relationshipSet or disabled]])
				:MapBooleanWithValues("TEXT_DISABLED", "TEXT")
			)
		)
		:AddChild(UIElements.New("OperationLinkButton", "linkBtn")
			:SetMargin(4, 4, 0, 0)
			:SetDisabledPublisher(self._state:PublisherForKeyChange("disabled"))
			:SetManager(self._childManager)
			:SetAction("OnValueChanged", "ACTION_HANDLE_RELATIONSHIP_CHANGED")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
	)
	self._state:SetAutoStorePaused(false)
end

function OperationLinkedSettingLine:Release()
	self._operationType = nil
	self._operationName = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the operation setting to display in the dialog.
---@param operationType string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return OperationLinkedSettingLine
function OperationLinkedSettingLine:SetOperationSetting(operationType, operationName, settingKey)
	self._operationType = operationType
	self._operationName = operationName
	self._settingKey = settingKey
	self._state.relationshipSet = Operation.HasRelationship(operationType, operationName, settingKey)
	self:GetElement("line.linkBtn"):SetOperationSetting(operationType, operationName, settingKey)
	return self
end

---Sets the label text.
---@param text string The label text
---@return OperationLinkedSettingLine
function OperationLinkedSettingLine:SetLabel(text)
	self:GetElement("line.label"):SetText(text)
	return self
end

---Sets whether or not the settings line is disabled.
---@param disabled boolean The disabled value
---@return OperationLinkedSettingLine
function OperationLinkedSettingLine:SetDisabled(disabled)
	self._state.disabled = disabled
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationLinkedSettingLine.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_RELATIONSHIP_CHANGED" then
		self:_SendActionScript("OnRelationshipChanged")
	else
		error("Unknown action: "..tostring(action))
	end
end
