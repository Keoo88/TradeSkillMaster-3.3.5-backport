-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")



-- ============================================================================
-- Element Definition
-- ============================================================================

local SavedSearchEditDialog = UIElements.Define("SavedSearchEditDialog", "Frame")
SavedSearchEditDialog:_AddActionScripts("OnNameChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function SavedSearchEditDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("SAVED_SEARCH_EDIT", self._state, self:__closure("_ActionHandler"))
	self._context = nil
end

function SavedSearchEditDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetBackgroundColor("FRAME_BG")
	self:SetBorderColor("ACTIVE_BG")
	self:AddChild(UIElements.New("Text", "title")
		:SetHeight(44)
		:SetMargin(16, 16, 24, 16)
		:SetFont("BODY_BODY1_BOLD")
		:SetJustifyH("CENTER")
		:SetText(L["Rename Search"])
	)
	self:AddChild(UIElements.New("Input", "nameInput")
		:SetHeight(26)
		:SetMargin(16, 16, 0, 25)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AllowItemInsert(true)
		:SetManager(self._childManager)
		:SetAction("OnEnterPressed", "ACTION_ENTER_PRESSED")
	)
	self:AddChild(UIElements.New("Frame", "buttons")
		:SetLayout("HORIZONTAL")
		:SetMargin(16, 16, 0, 16)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("ActionButton", "closeBtn")
			:SetSize(126, 26)
			:SetText(CLOSE)
			:SetAction("OnClick", "ACTION_CLOSE")
		)
	)
end

function SavedSearchEditDialog:Release()
	self.__super:Release()
	self._context = nil
end

---Sets the name of the saved search being editted.
---@param name string The name of the saved search
---@param context any Some context to pass through to the OnNameChanged action
---@return SavedSearchEditDialog
function SavedSearchEditDialog:SetName(name, context)
	self._context = context
	self:GetElement("nameInput"):SetValue(name)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function SavedSearchEditDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_ENTER_PRESSED" then
		local name = self:GetElement("nameInput"):GetValue()
		if name == "" then
			return
		end
		self:_SendActionScript("OnNameChanged", self:GetElement("nameInput"):GetValue(), self._context)
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_CLOSE" then
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end
