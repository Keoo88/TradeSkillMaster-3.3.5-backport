-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local Group = LibTSMUI:From("LibTSMTypes"):Include("Group")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local private = {
	groupsTemp = {},
}



-- ============================================================================
-- Element Definition
-- ============================================================================

local CraftingRestockDialog = UIElements.Define("CraftingRestockDialog", "Frame")
CraftingRestockDialog:_AddActionScripts("OnRestockClick", "OnGroupSelectionChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function CraftingRestockDialog:__init(frame)
	self.__super:__init(frame)
	self._filterText = ""
	self._childManager = UIManager.Create("CRAFTING_RESTOCK_DIALOG", self._state, self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_GROUP_SELECTION_CHANGED")
end

function CraftingRestockDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(8)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:SetMouseEnabled(true)
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 8)
		:AddChild(UIElements.New("Text", "title")
			:SetMargin(32, 8, 0, 0)
			:SetFont("BODY_BODY1_BOLD")
			:SetJustifyH("CENTER")
			:SetText(L["Restock TSM Groups"])
		)
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
		)
	)
	self:AddChild(UIElements.New("Frame", "content")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("PRIMARY_BG")
		:SetBorderColor("ACTIVE_BG", 2)
		:SetPadding(2)
		:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
			:SetOperationType("Crafting")
			:SetManager(self._childManager)
			:SetAction("OnGroupSelectionChanged", "ACTION_GROUP_SELECTION_CHANGED")
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "footer")
			:SetLayout("HORIZONTAL")
			:SetHeight(26)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChild(UIElements.New("Text", "groupsText")
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("RIGHT")
				:SetText(format(L["%d Groups Selected"], 0))
			)
			:AddChild(UIElements.New("Texture", "vline")
				:SetWidth(1)
				:SetMargin(8, 8, 2, 2)
				:SetColor("ACTIVE_BG_ALT")
			)
			:AddChild(UIElements.New("Text", "itemsText")
				:SetWidth("AUTO")
				:SetMargin(0, 8, 0, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("RIGHT")
				:SetText(L["Total Items"]..": ".."0")
			)
		)
	)
	self:AddChild(UIElements.New("ActionButton", "restockBtn")
		:SetHeight(24)
		:SetMargin(0, 0, 8, 0)
		:SetText(L["Restock Groups"])
		:SetManager(self._childManager)
		:SetAction("OnClick", "ACTION_RESTOCK_CLICKED")
	)
end

function CraftingRestockDialog:Release()
	self._filterText = ""
	self.__super:Release()
end

---Sets the context table from a settings object for the group tree.
---@param settings Settings The settings object
---@param key string The setting key
---@return CraftingRestockDialog
function CraftingRestockDialog:SetGroupTreeSettingsContext(settings, key)
	self:GetElement("content.groupTree"):SetSettingsContext(settings, key)
	self._childManager:ProcessAction("ACTION_GROUP_SELECTION_CHANGED")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function CraftingRestockDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_GROUP_SELECTION_CHANGED" then
		self:GetElement("restockBtn"):SetDisabled(self:GetElement("content.groupTree"):IsSelectionCleared())
		local numGroups, numItems = 0, 0
		for _, groupPath in self:GetElement("content.groupTree"):SelectedGroupsIterator() do
			numGroups = numGroups + 1
			if groupPath ~= Group.GetRootPath() then
				numItems = numItems + Group.GetNumItems(groupPath)
			end
		end
		self:GetElement("content.footer.groupsText")
			:SetText(format(L["%d Groups Selected"], numGroups))
		self:GetElement("content.footer.itemsText")
			:SetText(L["Total Items"]..": "..numItems)
		self:GetElement("content.footer"):Draw()
	elseif action == "ACTION_RESTOCK_CLICKED" then
		assert(not next(private.groupsTemp))
		for _, groupPath in self:GetElement("content.groupTree"):SelectedGroupsIterator() do
			tinsert(private.groupsTemp, groupPath)
		end
		self:_SendActionScript("OnRestockClick", private.groupsTemp)
		wipe(private.groupsTemp)
		self._childManager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end
