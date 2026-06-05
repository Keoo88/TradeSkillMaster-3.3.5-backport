-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")



-- ============================================================================
-- Element Definition
-- ============================================================================

local DropdownDialog = UIElements.Define("DropdownDialog", "Frame")
DropdownDialog:_ExtendStateSchema()
	:AddBooleanField("noneSelected", false)
	:AddBooleanField("allSelected", false)
	:Commit()



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function DropdownDialog:__init()
	self.__super:__init()
	self._mutliselect = nil
	self._onSelectionChange = nil
end

function DropdownDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(0, 0, 4, 4)
	self:SetRoundedBackgroundColor("ACTIVE_BG")
	self:AddChild(UIElements.New("DropdownList", "list"))
end

function DropdownDialog:Draw()
	self.__super:Draw()
end

function DropdownDialog:Release()
	self._mutliselect = nil
	self._onSelectionChange = nil
	self.__super:Release()
end

function DropdownDialog:SetMultiselect(multiselect)
	assert(self._mutliselect == nil and type(multiselect) == "boolean")
	self._mutliselect = multiselect
	if multiselect then
		self:AddChildBeforeById("list", UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetPadding(8, 8, 2, 2)
			:SetHeight(24)
			:AddChild(UIElements.New("Button", "selectAll")
				:SetWidth("AUTO")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_BODY2_BOLD")
				:SetText(L["Select All"])
				:SetScript("OnClick", self:__closure("_HandleSelectAllClick"))
			)
			:AddChild(UIElements.New("Button", "deselectAll")
				:SetWidth("AUTO")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_BODY2_BOLD")
				:SetText(L["Deselect All"])
				:SetScript("OnClick", self:__closure("_HandleDeselectAllClick"))
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
		self:AddChildBeforeById("list", UIElements.New("HorizontalLine", "line")
			:SetColor("ACTIVE_BG_ALT")
		)
		self._state:PublisherForKeyChange("allSelected")
			:Share(2)
			:CallMethod(self:GetElement("header.selectAll"), "SetDisabled")
			:MapBooleanWithValues("ACTIVE_BG_ALT", "TEXT")
			:CallMethod(self:GetElement("header.selectAll"), "SetTextColor")
		self._state:PublisherForKeyChange("noneSelected")
			:Share(2)
			:CallMethod(self:GetElement("header.deselectAll"), "SetDisabled")
			:MapBooleanWithValues("ACTIVE_BG_ALT", "TEXT")
			:CallMethod(self:GetElement("header.deselectAll"), "SetTextColor")
	end
	self:GetElement("list")
		:SetMultiselect(multiselect)
		:SetScript("OnSelectionChanged", self:__closure("_HandleSelectionChanged"))
	return self
end

function DropdownDialog:SetItems(items, selection)
	self:GetElement("list"):SetItems(items, selection)
	self:_HandleSelectionChanged(nil, selection)
	return self
end

---Registers a script handler.
---@param script "OnSelectionChanged" The script to register for
---@param handler function The script handler function
---@return DropdownDialog
function DropdownDialog:SetScript(script, handler)
	if script == "OnSelectionChanged" then
		self._onSelectionChange = handler
	else
		error("Invalid DropdownDialog script: "..tostring(script))
	end
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function DropdownDialog.__private:_HandleSelectionChanged(_, selected)
	self._state.noneSelected = self:GetElement("list"):IsNoneSelected()
	self._state.allSelected = self:GetElement("list"):IsAllSelected()
	if self._onSelectionChange then
		self._onSelectionChange(selected)
	end
end

function DropdownDialog.__private:_HandleSelectAllClick()
	self:GetElement("list"):SelectAll()
end

function DropdownDialog.__private:_HandleDeselectAllClick()
	self:GetElement("list"):DeselectAll()
end
