-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Operation = LibTSMUI:From("LibTSMTypes"):Include("Operation")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local private = {}
local LINK_TEXTURE = "iconPack.14x14/Link"



-- ============================================================================
-- Element Definition
-- ============================================================================

local OperationLinkButton = UIElements.Define("OperationLinkButton", "Button")
OperationLinkButton:_ExtendStateSchema()
	:AddBooleanField("relationshipSet", false)
	:Commit()
OperationLinkButton:_AddActionScripts("OnValueChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function OperationLinkButton:__init(frame)
	self.__super:__init(frame)
	self._operationType = nil
	self._operationName = nil
	self._settingKey = nil
	self._childManager = UIManager.Create("OPERATION_LINK_BUTTON", self._state, self:__closure("_ActionHandler"))
end

function OperationLinkButton:Acquire()
	self.__super:Acquire()
	self:SetSize(TextureAtlas.GetSize(LINK_TEXTURE))
	self._state:PublisherForKeys("relationshipSet", "enabled")
		:MapWithFunction(private.StateToLinkTexture)
		:CallMethod(self, "SetBackground")
end

function OperationLinkButton:Release()
	self._operationType = nil
	self._operationName = nil
	self._settingKey = nil
	self.__super:Release()
end

---Sets the operation represented by the link button.
---@param operationType string The type of the operation
---@param operationName string The name of the operation
---@param settingKey string The setting key
---@return OperationLinkButton
function OperationLinkButton:SetOperationSetting(operationType, operationName, settingKey)
	self._operationType = operationType
	self._operationName = operationName
	self._settingKey = settingKey
	self._state.relationshipSet = Operation.HasRelationship(operationType, operationName, settingKey)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function OperationLinkButton.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_DIALOG_VALUE_CHANGED" then
		self.__super:_SendActionScript("OnValueChanged")
	else
		error("Unknown action: "..tostring(action))
	end
end

function OperationLinkButton.__protected:_SendActionScript(script)
	if script == "OnClick" then
		-- Handle click events by showing the dialog
		self:GetBaseElement():ShowDialogFrame(UIElements.New("OperationLinkDialog", "linkDialog")
			:SetSize(263, 243)
			:AddAnchor("TOPRIGHT", self, "BOTTOM", 22, -16)
			:SetManager(self._childManager)
			:SetOperationSetting(self._operationType, self._operationName, self._settingKey)
			:SetAction("OnValueChanged", "ACTION_HANDLE_DIALOG_VALUE_CHANGED")
		)
	else
		error("Invalid script: "..tostring(script))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.StateToLinkTexture(state)
	if state.relationshipSet then
		return TextureAtlas.GetColoredKey(LINK_TEXTURE, state.enabled and "INDICATOR" or "INDICATOR_DISABLED")
	else
		return TextureAtlas.GetColoredKey(LINK_TEXTURE, state.enabled and "TEXT" or "TEXT_DISABLED")
	end
end
