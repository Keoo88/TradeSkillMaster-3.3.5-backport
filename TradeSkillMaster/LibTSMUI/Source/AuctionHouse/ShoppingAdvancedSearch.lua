-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local Item = LibTSMUI:From("LibTSMWoW"):Include("API.Item")
local CharacterInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.CharacterInfo")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local ItemClass = LibTSMUI:From("LibTSMWoW"):Include("Util.ItemClass")
local TempTable = LibTSMUI:From("LibTSMUtil"):Include("BaseType.TempTable")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local RARITY_LIST = nil
local DEFAULT_LEVEL_RANGE = "0,"..CharacterInfo.GetMaxLevel()
local DEFAULT_ITEM_LEVEL_RANGE = "0,"..Item.GetMaxItemLevel()



-- ============================================================================
-- Element Definition
-- ============================================================================

local ShoppingAdvancedSearch = UIElements.Define("ShoppingAdvancedSearch", "Frame")
ShoppingAdvancedSearch:_ExtendStateSchema()
	:AddStringField("keyword", "")
	:AddOptionalStringField("class")
	:AddOptionalStringField("subClass")
	:AddOptionalStringField("invSlot")
	:AddStringField("levelRange", DEFAULT_LEVEL_RANGE)
	:AddStringField("itemLevelRange", DEFAULT_ITEM_LEVEL_RANGE)
	:AddNumberField("maxQty", 0)
	:AddOptionalStringField("minRarity")
	:AddBooleanField("uncollected", false)
	:AddBooleanField("upgrades", false)
	:AddBooleanField("usable", false)
	:AddBooleanField("exact", false)
	:AddBooleanField("crafting", false)
	:Commit()
ShoppingAdvancedSearch:_AddActionScripts("OnBackClicked", "OnStartScanClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingAdvancedSearch:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("SHOPPING_ADVANCED_SEARCH", self._state, self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_KEYWORD_CHANGED")
		:SuppressActionLog("ACTION_LEVEL_CHANGED")
		:SuppressActionLog("ACTION_ITEM_LEVEL_CHANGED")
	if not RARITY_LIST then
		RARITY_LIST = {}
		for i = 1, 7 do
			tinsert(RARITY_LIST, _G["ITEM_QUALITY"..i.."_DESC"])
		end
	end
end

function ShoppingAdvancedSearch:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetBackgroundColor("PRIMARY_BG_ALT")
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("ScrollFrame", "search")
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8)
			:AddChild(UIElements.New("ActionButton", "backBtn")
				:SetWidth(64)
				:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey("iconPack.14x14/Chevron/Right"))..BACK)
				:SetAction("OnClick", "ACTION_BACK")
			)
			:AddChild(UIElements.New("Input", "keyword")
				:SetMargin(8, 0, 0, 0)
				:SetIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:SetHintText(L["Filter by Keyword"])
				:SetValuePublisher(self._state:PublisherForKeyChange("keyword"))
				:SetAction("OnValueChanged", "ACTION_KEYWORD_CHANGED")
			)
		)
		:AddChild(UIElements.New("Frame", "body")
			:SetLayout("VERTICAL")
			:SetPadding(8, 8, 0, 0)
			:AddChild(UIElements.New("Frame", "classAndSubClassLabels")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 16, 0)
				:AddChild(UIElements.New("Text", "classLabel")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Item Class"])
				)
				:AddChild(UIElements.New("Text", "subClassLabel")
					:SetMargin(20, 0, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Item Subclass"])
				)
			)
			:AddChild(UIElements.New("Frame", "classAndSubClass")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 4, 0)
				:AddChild(UIElements.New("ListDropdown", "classDropdown")
					:SetMargin(0, 20, 0, 0)
					:SetItems(ItemClass.GetClasses())
					:SetHintText(L["All Item Classes"])
					:SetSelectedItemSilentPublisher(self._state:PublisherForKeyChange("class"))
					:SetAction("OnSelectionChanged", "ACTION_CLASS_CHANGED")
				)
				:AddChild(UIElements.New("ListDropdown", "subClassDropdown")
					:SetHintText(L["All Subclasses"])
					:SetDisabledPublisher(self._state:PublisherForKeyChange("class")
						:MapBooleanEquals(nil)
					)
					:SetSelectedItemSilentPublisher(self._state:PublisherForKeyChange("subClass"))
					:SetAction("OnSelectionChanged", "ACTION_SUB_CLASS_CHANGED")
				)
			)
			:AddChild(UIElements.New("Frame", "itemSlot")
				:SetLayout("VERTICAL")
				:SetMargin(0, 0, 16, 0)
				:AddChild(UIElements.New("Text", "label")
					:SetHeight(20)
					:SetMargin(0, 0, 0, 4)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Item Slot"])
				)
				:AddChild(UIElements.New("Frame", "frame")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:AddChild(UIElements.New("ListDropdown", "dropdown")
						:SetWidth(238)
						:SetHintText(L["All Slots"])
						:SetDisabledPublisher(self._state:PublisherForKeyChange("subClass")
							:MapBooleanEquals(nil)
						)
						:SetSelectedItemSilentPublisher(self._state:PublisherForKeyChange("invSlot"))
						:SetAction("OnSelectionChanged", "ACTION_INV_SLOT_CHANGED")
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
			:AddChild(UIElements.New("Frame", "frame")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 16, 0)
				:AddChild(UIElements.New("Text", "label")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Required Level Range"])
				)
			)
			:AddChild(UIElements.New("Frame", "level")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 2, 0)
				:AddChild(UIElements.New("RangeInput", "slider")
					:SetRange(DEFAULT_LEVEL_RANGE)
					:SetValuePublisher(self._state:PublisherForKeyChange("levelRange"))
					:SetAction("OnValueChanged", "ACTION_LEVEL_CHANGED")
				)
			)
			:AddChild(UIElements.New("Frame", "frame")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 18, 0)
				:AddChild(UIElements.New("Text", "label")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Item Level Range"])
				)
			)
			:AddChild(UIElements.New("Frame", "itemLevel")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 2, 0)
				:AddChild(UIElements.New("RangeInput", "slider")
					:SetRange(DEFAULT_ITEM_LEVEL_RANGE)
					:SetValuePublisher(self._state:PublisherForKeyChange("itemLevelRange"))
					:SetAction("OnValueChanged", "ACTION_ITEM_LEVEL_CHANGED")
				)
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(48)
				:SetMargin(0, 0, 18, 0)
				:AddChild(UIElements.New("Frame", "frame")
					:SetLayout("VERTICAL")
					:SetWidth(254)
					:AddChild(UIElements.New("Text", "label")
						:SetFont("BODY_BODY2_MEDIUM")
						:SetText(L["Maximum Quantity to Buy"])
					)
					:AddChild(UIElements.New("Frame", "maxQty")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:SetMargin(0, 0, 4, 0)
						:AddChild(UIElements.New("Input", "input")
							:SetWidth(178)
							:SetMargin(0, 4, 0, 0)
							:SetBackgroundColor("ACTIVE_BG")
							:SetValidateFunc("NUMBER", "0:2000")
							:SetValuePublisher(self._state:PublisherForKeyChange("maxQty"))
							:SetAction("OnValueChanged", "ACTION_MAX_QTY_CHANGED")
						)
						:AddChild(UIElements.New("Text", "label")
							:SetWidth(100)
							:SetFont("BODY_BODY3_MEDIUM")
							:SetFormattedText("(%d - %d)", 0, 2000)
						)
					)
				)
				:AddChild(UIElements.New("Frame", "minRarity")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Text", "label")
						:SetFont("BODY_BODY2_MEDIUM")
						:SetText(L["Minimum Rarity"])
					)
					:AddChild(UIElements.New("ListDropdown", "dropdown")
						:SetHeight(24)
						:SetMargin(0, 0, 4, 0)
						:SetItems(RARITY_LIST)
						:SetHintText(L["All"])
						:SetSelectedItemSilentPublisher(self._state:PublisherForKeyChange("minRarity"))
						:SetAction("OnSelectionChanged", "ACTION_MIN_RARITY_CHANGED")
					)
				)
			)
			:AddChild(UIElements.New("Frame", "filters")
				:SetLayout("HORIZONTAL")
				:SetMargin(0, 0, 16, 8)
				:AddChildIf(ClientInfo.HasFeature(ClientInfo.FEATURES.AH_UNCOLLECTED_FILTER), UIElements.New("Frame", "uncollected")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Checkbox", "checkbox")
						:SetText(L["Uncollected Only"])
						:SetCheckedSilentPublisher(self._state:PublisherForKeyChange("uncollected"))
						:SetAction("OnValueChanged", "ACTION_UNCOLLECTED_CHANGED")
					)
				)
				:AddChildIf(ClientInfo.HasFeature(ClientInfo.FEATURES.AH_UPGRADES_FILTER), UIElements.New("Frame", "upgrades")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Checkbox", "checkbox")
						:SetText(L["Upgrades Only"])
						:SetCheckedSilentPublisher(self._state:PublisherForKeyChange("upgrades"))
						:SetAction("OnValueChanged", "ACTION_UPGRADES_CHANGED")
					)
				)
				:AddChild(UIElements.New("Frame", "usable")
					:SetLayout("HORIZONTAL")
					:SetHeight(20)
					:AddChild(UIElements.New("Checkbox", "checkbox")
						:SetText(L["Usable Only"])
						:SetCheckedSilentPublisher(self._state:PublisherForKeyChange("usable"))
						:SetAction("OnValueChanged", "ACTION_USABLE_CHANGED")
					)
				)
			)
			:AddChild(UIElements.New("Frame", "filters2")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Checkbox", "exact")
					:SetText(L["Exact Match"])
					:SetCheckedSilentPublisher(self._state:PublisherForKeyChange("exact"))
					:SetAction("OnValueChanged", "ACTION_EXACT_CHANGED")
				)
				:AddChild(UIElements.New("Checkbox", "crafting")
					:SetText(L["Crafting Mode"])
					:SetCheckedSilentPublisher(self._state:PublisherForKeyChange("crafting"))
					:SetAction("OnValueChanged", "ACTION_CRAFTING_CHANGED")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
		)
	)
	self:AddChild(UIElements.New("HorizontalLine", "line"))
	self:AddChild(UIElements.New("Frame", "buttons")
		:SetLayout("HORIZONTAL")
		:SetHeight(40)
		:SetPadding(8)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:SetManager(self._childManager)
		:AddChild(UIElements.New("ActionButton", "startBtn")
			:SetHeight(24)
			:SetMargin(0, 8, 0, 0)
			:SetText(L["Run Advanced Item Search"])
			:SetAction("OnClick", "ACTION_START_SCAN")
		)
		:AddChild(UIElements.New("Button", "resetBtn")
			:SetSize("AUTO", 24)
			:SetFont("BODY_BODY3_MEDIUM")
			:SetText(L["Reset All Filters"])
			:SetAction("OnClick", "ACTION_RESET")
		)
	)
	self._state:SetAutoStorePaused(false)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ShoppingAdvancedSearch.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_BACK" then
		self:_SendActionScript("OnBackClicked")
	elseif action == "ACTION_KEYWORD_CHANGED" then
		state.keyword = self:GetElement("search.header.keyword"):GetValue()
	elseif action == "ACTION_CLASS_CHANGED" then
		state.class = self:GetElement("search.body.classAndSubClass.classDropdown"):GetSelectedItem()
		state.subClass = nil
		state.invSlot = nil
		if state.class then
			local subClasses = TempTable.Acquire()
			for _, v in ipairs(ItemClass.GetSubClasses(state.class)) do
				tinsert(subClasses, v)
			end
			for _, v in ItemClass.GenericInventorySlotStringIterator(state.class) do
				tinsert(subClasses, v)
			end
			self:GetElement("search.body.classAndSubClass.subClassDropdown"):SetItems(subClasses)
			TempTable.Release(subClasses)
		end
	elseif action == "ACTION_SUB_CLASS_CHANGED" then
		state.subClass = self:GetElement("search.body.classAndSubClass.subClassDropdown"):GetSelectedItem()
		state.invSlot = nil
		if state.subClass then
			self:GetElement("search.body.itemSlot.frame.dropdown"):SetItems(ItemClass.GetInventorySlots(state.class, state.subClass))
		end
	elseif action == "ACTION_INV_SLOT_CHANGED" then
		state.invSlot = self:GetElement("search.body.itemSlot.frame.dropdown"):GetSelectedItem()
	elseif action == "ACTION_LEVEL_CHANGED" then
		state.levelRange = self:GetElement("search.body.level.slider"):GetValue()
	elseif action == "ACTION_ITEM_LEVEL_CHANGED" then
		state.itemLevelRange = self:GetElement("search.body.itemLevel.slider"):GetValue()
	elseif action == "ACTION_MAX_QTY_CHANGED" then
		state.maxQty = tonumber(self:GetElement("search.body.content.frame.maxQty.input"):GetValue())
	elseif action == "ACTION_MIN_RARITY_CHANGED" then
		state.minRarity = self:GetElement("search.body.content.minRarity.dropdown"):GetSelectedItem()
	elseif action == "ACTION_UNCOLLECTED_CHANGED" then
		state.uncollected = self:GetElement("search.body.filters.uncollected.checkbox"):IsChecked()
	elseif action == "ACTION_UPGRADES_CHANGED" then
		state.upgrades = self:GetElement("search.body.filters.upgrades.checkbox"):IsChecked()
	elseif action == "ACTION_USABLE_CHANGED" then
		state.usable = self:GetElement("search.body.filters.usable.checkbox"):IsChecked()
	elseif action == "ACTION_EXACT_CHANGED" then
		state.exact = self:GetElement("search.body.filters.exact.checkbox"):IsChecked()
	elseif action == "ACTION_CRAFTING_CHANGED" then
		state.crafting = self:GetElement("search.body.filters.crafting.checkbox"):IsChecked()
	elseif action == "ACTION_RESET" then
		state.keyword = ""
		state.class = nil
		state.subClass = nil
		state.invSlot = nil
		state.levelRange = DEFAULT_LEVEL_RANGE
		state.itemLevelRange = DEFAULT_ITEM_LEVEL_RANGE
		state.maxQty = 0
		state.minRarity = nil
		state.uncollected = false
		state.upgrades = false
		state.usable = false
		state.exact = false
		state.crafting = false
		self:Draw()
	elseif action == "ACTION_START_SCAN" then
		local filterParts = TempTable.Acquire()
		tinsert(filterParts, strtrim(state.keyword))
		if state.levelRange ~= DEFAULT_LEVEL_RANGE then
			local minLevel, maxLevel = strsplit(",", state.levelRange)
			assert(minLevel and maxLevel)
			tinsert(filterParts, minLevel)
			tinsert(filterParts, maxLevel)
		end
		if state.itemLevelRange ~= DEFAULT_ITEM_LEVEL_RANGE then
			local minItemLevel, maxItemLevel = strsplit(",", state.itemLevelRange)
			assert(minItemLevel and maxItemLevel)
			tinsert(filterParts, "i"..minItemLevel)
			tinsert(filterParts, "i"..maxItemLevel)
		end
		if state.class then
			tinsert(filterParts, state.class)
		end
		if state.subClass then
			tinsert(filterParts, state.subClass)
		end
		if state.invSlot then
			tinsert(filterParts, state.invSlot)
		end
		if state.minRarity then
			tinsert(filterParts, state.minRarity)
		end
		if state.maxQty > 0 then
			tinsert(filterParts, "x"..state.maxQty)
		end
		if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_UNCOLLECTED_FILTER) and state.uncollected then
			tinsert(filterParts, "uncollected")
		end
		if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_UPGRADES_FILTER) and state.upgrades then
			tinsert(filterParts, "upgrades")
		end
		if state.usable then
			tinsert(filterParts, "usable")
		end
		if state.exact then
			tinsert(filterParts, "exact")
		end
		if state.crafting then
			tinsert(filterParts, "crafting")
		end
		local filter = table.concat(filterParts, "/")
		TempTable.Release(filterParts)
		self:_SendActionScript("OnStartScanClicked", filter)
	else
		error("Unknown action: "..tostring(action))
	end
end
