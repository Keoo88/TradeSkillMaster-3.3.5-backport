-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local private = {
	entriesTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkDialog = UIElements.Define("OperationLinkDialog", "PopupFrame")
OperationLinkDialog:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("OPERATION_LINK_DIALOG", self._state, self:__closure("_ActionHandler"))
	self._operationType = nil
	self._operationName = nil
	self._settingKey = nil
end

function OperationLinkDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:AddChild(UIElements.New("Frame", "titleFrame")
		:SetLayout("VERTICAL")
		:SetHeight(37)
		:AddChild(UIElements.New("Text", "title")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetJustifyH("CENTER")
			:SetText(L["Link to Another Operation"])
		)
	)
	self:AddChild(UIElements.New("HorizontalLine", "line")
		:SetColor("TEXT")
	)
	self:AddChild(UIElements.New("SelectionList", "list")
		:SetMargin(2, 2, 0, 3)
		:SetManager(self._childManager)
		:SetAction("OnEntrySelected", "ACTION_HANDLE_ENTRY_SELECTED")
	)
end

function OperationLinkDialog:Release()
	self._operationType = nil
	self._operationName = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the operation setting to display in the dialog.
---@param operationType string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return OperationLinkDialog
function OperationLinkDialog:SetOperationSetting(operationType, operationName, settingKey)
	self._operationType = operationType
	self._operationName = operationName
	self._settingKey = settingKey
	assert(#private.entriesTemp == 0)
	for _, otherOperationName in Operation.Iterator(operationType) do
		if Operation.CanAddRelationship(operationType, operationName, otherOperationName, settingKey) then
			tinsert(private.entriesTemp, otherOperationName)
		end
	end
	sort(private.entriesTemp)
	self:GetElement("list"):SetEntries(private.entriesTemp, Operation.GetRelationship(operationType, operationName, settingKey))
	wipe(private.entriesTemp)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationLinkDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_ENTRY_SELECTED" then
		local operationName = ...
		local previousValue = Operation.GetRelationship(self._operationType, self._operationName, self._settingKey)
		if operationName == previousValue then
			-- The user selects the same entry to clear the relationship
			operationName = nil
		end
		Operation.SetRelationship(self._operationType, self._operationName, self._settingKey, operationName)
		self:_SendActionScript("OnValueChanged")
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end
