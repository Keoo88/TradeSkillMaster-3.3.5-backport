-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local Crafting = TSM.UI.CraftingUI:NewPackage("Crafting") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local RecipeString = TSM.LibTSMTypes:Include("Crafting.RecipeString")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local ItemLinked = TSM.LibTSMUI:Include("Util.ItemLinked")
local Profession = TSM.LibTSMService:Include("Profession")
local Tooltip = TSM.LibTSMUI:Include("Tooltip")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local TradeSkill = TSM.LibTSMWoW:Include("API.TradeSkill")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local CraftingUIUtils = TSM.LibTSMUI:Include("Crafting.CraftingUIUtils")
local private = {
	manager = nil, ---@type UIManager
	settings = nil,
	professions = {},
	professionsKeys = {},
	showDelayFrame = 0,
	costsCache = {
		updateTime = 0,
		isCached = {},
		craftingCost = {},
		itemValue = {},
		profit = {},
		saleRate = {},
	},
	craftTimer = nil,
	craftResult = {
		success = nil,
		done = nil,
	},
}
local SHOW_DELAY_FRAMES = 2
local KEY_SEP = "\001"
local STATE_SCHEMA = Reactive.CreateStateSchema("CRAFTING_UI_STATE")
	:AddOptionalTableField("frame")
	:AddOptionalEnumField("professionType", TradeSkill.TYPE)
	:AddBooleanField("haveSkillUpFilter", false)
	:AddBooleanField("haveMaterialsFilter", false)
	:AddBooleanField("queueCanCraftNext", false)
	:AddNumberField("numQueued", 0)
	:AddOptionalStringField("selectedCraftString")
	:AddOptionalStringField("craftingRecipeString")
	:AddOptionalStringField("craftingCraftString")
	:AddOptionalNumberField("craftingQuantity")
	:AddOptionalEnumField("craftingSource", CraftingUIUtils.CRAFTING_SOURCE)
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Crafting.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "craftingUIContext", "professionScrollingTable")
		:AddKey("global", "craftingUIContext", "professionDividedContainer")
		:AddKey("global", "craftingUIContext", "professionDividedContainerBottom")
		:AddKey("char", "craftingUIContext", "groupTree")
		:AddKey("factionrealm", "internalData", "isCraftFavorite")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("CRAFTING", state, private.ActionHandler)
		:SuppressActionLog("ACTION_SKILL_UPDATE")
		:SuppressActionLog("ACTION_RECIPE_FILTER_CHANGED")
		:SuppressActionLog("ACTION_BAG_QUANTITY_UPDATED")

	-- Set some computed state properties
	private.manager:SetStateFromPublisher("craftingCraftString", state:PublisherForKeyChange("craftingRecipeString")
		:MapNonNilWithFunction(CraftString.FromRecipeString)
	)

	-- Set up some callbacks
	Profession.RegisterStateCallback(function()
		if Profession.GetCurrentProfession() and (ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and CraftCreateButton then
			if TradeSkill.IsClassicCrafting() then
				CraftCreateButton:Show()
			else
				CraftCreateButton:Hide()
			end
		end
		private.manager:ProcessAction("ACTION_PROFESSION_STATE_UPDATED")
	end)
	local function ItemLinkedCallback(name, itemLink)
		if not state.frame then
			return
		end
		state.frame:GetElement("top.left.controls.filterInput")
			:SetValue(ItemInfo.GetName(ItemString.GetBase(itemLink)))
			:SetFocused(false)
			:Draw()
		private.manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
		return true
	end
	ItemLinked.RegisterCallback(ItemLinkedCallback, true)
	Profession.RegisterHasScannedCallback(private.manager:CallbackToProcessAction("ACTION_PROFESSION_STATE_UPDATED"))
	BagTracking.RegisterQuantityCallback(private.manager:CallbackToProcessAction("ACTION_BAG_QUANTITY_UPDATED"))
	WarbankTracking.RegisterQuantityCallback(private.manager:CallbackToProcessAction("ACTION_BAG_QUANTITY_UPDATED"))

	-- Set up the craft timer
	private.craftTimer = DelayTimer.New("CRAFTING_CRAFT", function()
		local success = private.craftResult.success
		local isDone = private.craftResult.isDone
		private.craftResult.success = nil
		private.craftResult.isDone = nil
		private.manager:ProcessAction("ACTION_HANDLE_CRAFT_DONE", success, isDone)
	end)

	-- Register this page with the Crafting UI
	TSM.UI.CraftingUI.RegisterTopLevelPage(L["Crafting"], function() return private.GetCraftingFrame(state) end)
end

function Crafting.OnEnable()
	-- Set up queries
	local queueQuery = TSM.Crafting.Queue.CreateQuery() ---@type DatabaseQuery
	private.manager:SetStateFromPublisher("numQueued", queueQuery:Publisher()
		:MapToValue(queueQuery)
		:MapWithMethod("Count")
	)
	local professionsQuery = TSM.Crafting.PlayerProfessions.CreateQuery() ---@type DatabaseQuery
	private.manager:ProcessActionFromPublisher("ACTION_SKILL_UPDATE", professionsQuery:Publisher())
end



-- ============================================================================
-- Crafting UI
-- ============================================================================

---@param state CraftingUIState
function private.GetCraftingFrame(state)
	UIUtils.AnalyticsRecordPathChange("crafting", "crafting")
	return UIElements.New("DividedContainer", "crafting")
		:SetMinWidth(200, ClientInfo.IsRetail() and 189 or 147)
		:SetVertical()
		:HideDivider()
		:SetSettingsContext(private.settings, "professionDividedContainerBottom")
		:SetManager(private.manager)
		:SetTopChild(UIElements.New("DividedContainer", "top")
			:SetMinWidth(400, 200)
			:HideDivider()
			:SetMargin(0, 0, 0, 2)
			:SetBackgroundColor("FRAME_BG")
			:SetSettingsContext(private.settings, "professionDividedContainer")
			:SetLeftChild(UIElements.New("Frame", "left")
				:SetLayout("VERTICAL")
				:SetMargin(0, 2, 0, 0)
				:AddChild(UIElements.New("Frame", "controls")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:SetMargin(0, 0, 0, 4)
					:AddChild(UIElements.New("SelectionDropdown", "professionDropdown")
						:SetWidth(205)
						:SetMargin(0, 4, 0, 0)
						:SetHintText(L["No Profession Opened"])
						:SetAction("OnSelectionChanged", "ACTION_PROFESSION_SELECTION_CHANGED")
					)
					:AddChild(UIElements.New("Input", "filterInput")
						:SetMargin(0, 4, 0, 0)
						:SetIconTexture("iconPack.18x18/Search")
						:SetClearButtonEnabled(true)
						:SetHintText(L["Search Patterns"])
						:SetAction("OnValueChanged", "ACTION_RECIPE_FILTER_CHANGED")
					)
					:AddChild(UIElements.New("Frame", "buttons")
						:SetLayout("HORIZONTAL")
						:SetSize(24, 24)
						:SetPadding(4)
						:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
						:AddChild(UIElements.New("Button", "filterBtn")
							:SetSize(16, 16)
							:SetIcon("iconPack.14x14/Filter", "CENTER")
							:SetBackground("PRIMARY_BG_ALT", true)
							:SetHighlightLockedPublisher(state:PublisherForExpression([[haveSkillUpFilter or haveMaterialsFilter]]))
							:SetAction("OnClick", "ACTION_FILTER_BUTTON_CLICKED")
						)
					)
				)
				:AddChild(UIElements.New("Frame", "content")
					:SetLayout("VERTICAL")
					:SetPadding(1)
					:SetBackgroundColor("PRIMARY_BG")
					:SetBorderColor("ACTIVE_BG", 1)
					:AddChild(UIElements.New("ProfessionScrollTable", "recipeList")
						:SetSettings(private.settings, "professionScrollingTable", private.settings.isCraftFavorite)
						:SetCostsFunction(private.ScrollTableCostsFunc)
						:SetCraftableQuantityFunction(TSM.Crafting.ProfessionUtil.GetNumCraftable)
						:SetAction("OnSelectionChanged", "ACTION_RECIPE_SELECTION_CHANGED")
					)
				)
			)
			:SetRightChild(UIElements.New("Frame", "right")
				:SetLayout("VERTICAL")
				:SetMargin(2, 0, 0, 0)
				:AddChild(UIElements.New("ActionButton", "restockDialog")
					:SetMargin(0, 0, 0, 4)
					:SetHeight(24)
					:SetText(L["Restock Groups"])
					:SetAction("OnClick", "ACTION_SHOW_RESTOCK_DIALOG")
				)
				:AddChild(UIElements.New("Frame", "queue")
					:SetLayout("VERTICAL")
					:SetBackgroundColor("PRIMARY_BG")
					:SetPadding(1)
					:SetBorderColor("ACTIVE_BG", 1)
					:AddChild(UIElements.New("Frame", "header")
						:SetLayout("HORIZONTAL")
						:SetHeight(20)
						:SetPadding(4, 4, 0, 0)
						:SetBackgroundColor("PRIMARY_BG_ALT")
						:AddChild(UIElements.New("Text", "title")
							:SetFont("BODY_BODY3_MEDIUM")
							:SetTextPublisher(state:PublisherForKeyChange("numQueued")
								:MapWithFunction(private.QueueCountToText)
							)
						)
						:AddChild(UIElements.New("Button", "info")
							:SetSize(12, 12)
							:SetBackground("iconPack.12x12/Attention")
							:SetTooltip(private.QueueTooltipFunc)
						)
					)
					:AddChild(UIElements.New("HorizontalLine", "line")
						:SetMargin(0, 0, 0, 4)
					)
					:AddChild(UIElements.New("CraftingQueueList", "queueList")
						:SetMatIteratorFunc(TSM.Crafting.MatIteratorByRecipeString)
						:SetQuery(TSM.Crafting.CreateQueueQuery())
						:SetAction("OnRowMouseDown", "ACTION_QUEUE_ROW_MOUSE_DOWN")
						:SetAction("OnRowClick", "ACTION_QUEUE_ROW_CLICK")
						:SetAction("OnNumUpdated", "ACTION_QUEUE_NUM_UPDATED")
						:SetAction("OnNextCraftChanged", "ACTION_QUEUE_NEXT_CRAFT_CHANGED")
					)
					:AddChild(UIElements.New("HorizontalLine", "line2"))
					:AddChild(UIElements.New("Frame", "footer")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:SetMargin(8, 8, 8, 8)
						:AddChild(UIElements.NewNamed("ActionButton", "craftNextBtn", "TSMCraftingBtn")
							:SetMargin(0, 8, 0, 0)
							:SetText(L["Craft Next"])
							:SetPressedPublisher(state:PublisherForExpression([[craftingRecipeString and EnumEquals(craftingSource, QUEUE_NEXT)]]))
							:SetDisabledPublisher(state:PublisherForExpression([[not EnumEquals(professionType, PLAYER) or not queueCanCraftNext or craftingRecipeString]]))
							:SetAction("OnClick", "ACTION_CRAFT_NEXT_CLICK")
						)
						:AddChild(UIElements.New("Button", "clearBtn")
							:SetWidth(70)
							:SetFont("BODY_BODY3_MEDIUM")
							:SetText(L["Clear All"])
							:SetTextColor("INDICATOR")
							:SetAction("OnClick", "ACTION_CLEAR_QUEUE")
						)
					)
				)
			)
		)
		:SetBottomChild(UIElements.New("CraftDetails", "details")
			:SetCraftableQuantityFunction(TSM.Crafting.ProfessionUtil.GetNumCraftableRecipeString)
			:SetHasVellumFunction(TSM.Crafting.ProfessionUtil.HasVellum)
			:SetQualityCraftingMatsFunction(TSM.Crafting.Quality.GetOptionalMats)
			:SetCostsFunctions(TSM.Crafting.Cost.GetCostsByRecipeString, TSM.Crafting.Cost.GetCostsByCraftString)
			:SetSpellIdPublisher(state:PublisherForKeyChange("selectedCraftString")
				:MapNonNilWithFunction(CraftString.GetSpellId)
			)
			:SetCraftingSourcePublisher(state:PublisherForExpression([[selectedCraftString and craftingRecipeString and craftingSource or nil]]))
			:SetCraftingQuantityPublisher(state:PublisherForExpression([[craftingCraftString and craftingSource and (craftingCraftString == selectedCraftString and craftingQuantity or 1) or nil]]))
			:SetAction("OnCraftButtonClick", "ACTION_DETAILS_CRAFT_BUTTON_CLICKED")
			:SetAction("OnCraftButtonMouseDown", "ACTION_DETAILS_CRAFT_BUTTON_MOUSE_DOWN")
			:SetAction("OnQueueButtonClick", "ACTION_QUEUE_BUTTON_CLICKED")
		)
		:SetScript("OnUpdate", private.FrameOnUpdate)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_FRAME_HIDE"))
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state CraftingUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW_DELAYED" then
		local frame = ...
		assert(not state.frame)
		state.frame = frame
		assert(not state.professionType)
		if private.IsProfessionLoaded() then
			return manager:ProcessAction("ACTION_PROFESSION_LOADED")
		else
			return manager:ProcessAction("ACTION_OPEN_NO_PROFESSION")
		end

	elseif action == "ACTION_FRAME_HIDE" then
		private.showDelayFrame = 0
		if not state.frame then
			-- Delay might not have elapsed
			return
		end
		state.frame = nil
		manager:ProcessAction("ACTION_PROFESSION_UNLOADED")
		state.craftingRecipeString = nil
		state.craftingQuantity = nil
		state.craftingSource = nil
		state.selectedCraftString = nil
	elseif action == "ACTION_OPEN_NO_PROFESSION" then
		state.professionType = nil
		state.craftingRecipeString = nil
		state.craftingQuantity = nil
		state.craftingSource = nil
		private.UpdateProfessionsDropdown(state)
		state.frame:GetElement("top.right.queue"):GetElement("queueList"):HandleProfessionChange()
	elseif action == "ACTION_PROFESSION_STATE_UPDATED" then
		if not state.frame then
			return
		end
		local isProfessionLoaded = private.IsProfessionLoaded()
		if state.professionType and isProfessionLoaded then
			-- Switched professions
			state.professionType = TradeSkill.GetType()
			private.UpdateProfessionsDropdown(state)
		elseif not state.professionType and not isProfessionLoaded then
			-- No change
		elseif isProfessionLoaded then
			-- Profession loaded
			manager:ProcessAction("ACTION_PROFESSION_LOADED")
		else
			-- Profession unloaded
			manager:ProcessAction("ACTION_PROFESSION_UNLOADED")
			manager:ProcessAction("ACTION_OPEN_NO_PROFESSION")
		end
	elseif action == "ACTION_PROFESSION_LOADED" then
		assert(not state.professionType)
		state.professionType = TradeSkill.GetType()
		local recipeQuery = Profession.CreateScannerQuery()
			:Select("craftString", "categoryId")
			:OrderBy("index", true)
			:VirtualField("matNames", "string", TSM.Crafting.GetMatNames, "craftString")
		state.frame:GetElement("top.left.controls.filterInput")
			:SetValue("")
			:SetFocused(false)
			:Draw()
		local prevSelectedCraftString = state.selectedCraftString
		local recipeList = state.frame:GetElement("top.left.content.recipeList")
		recipeList:SetQuery(recipeQuery)
		if prevSelectedCraftString and Profession.GetIndexByCraftString(prevSelectedCraftString) then
			recipeList:SetSelectedCraft(prevSelectedCraftString)
		end
		private.UpdateProfessionsDropdown(state)
		state.frame:GetElement("top.right.queue"):GetElement("queueList"):HandleProfessionChange()
		manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
	elseif action == "ACTION_PROFESSION_UNLOADED" then
		state.professionType = nil
		state.haveSkillUpFilter = false
		state.haveMaterialsFilter = false
		if state.frame then
			state.frame:GetElement("top.left.content.recipeList"):SetQuery(nil)
		end
	elseif action == "ACTION_FILTER_BUTTON_CLICKED" then
		local button = state.frame:GetElement("top.left.controls.buttons.filterBtn")
		local menuDialog = UIElements.New("MenuDialog", "menu")
			:AddAnchor("TOPRIGHT", button, "BOTTOMRIGHT", 2, -4)
			:SetContext(state)
			:Configure("")
			:SetManager(manager)
			:SetAction("OnRowClick", "ACTION_FILTER_DIALOG_ROW_CLICKED")
			:AddRow("SKILLUP", "", private.ColorFilterDialogText(state.haveSkillUpFilter, L["Have Skill Ups"]))
			:AddRow("MATS", "", private.ColorFilterDialogText(state.haveMaterialsFilter, L["Have Mats"]))
			:AddRow("RESET", "", L["Reset Filters"])
		state.frame:GetBaseElement():ShowDialogFrame(menuDialog)
	elseif action == "ACTION_FILTER_DIALOG_ROW_CLICKED" then
		local menuDialog, id = ...
		if id == "SKILLUP" then
			state.haveSkillUpFilter = not state.haveSkillUpFilter
			menuDialog:UpdateRow(id, private.ColorFilterDialogText(state.haveSkillUpFilter, L["Have Skill Ups"]))
		elseif id == "MATS" then
			state.haveMaterialsFilter = not state.haveMaterialsFilter
			menuDialog:UpdateRow(id, private.ColorFilterDialogText(state.haveMaterialsFilter, L["Have Mats"]))
		elseif id == "RESET" then
			menuDialog:GetBaseElement():HideDialog()
			state.haveSkillUpFilter = false
			state.haveMaterialsFilter = false
		else
			error("Unexpected id: "..tostring(id))
		end
		return manager:ProcessAction("ACTION_RECIPE_FILTER_CHANGED")
	elseif action == "ACTION_RECIPE_FILTER_CHANGED" then
		local recipeList = state.frame:GetElement("top.left.content.recipeList")
		local filterText = state.frame:GetElement("top.left.controls.filterInput"):GetValue()
		filterText = String.Escape(filterText)
		filterText = filterText ~= "" and filterText or nil
		recipeList:SetFilters(filterText, state.haveSkillUpFilter, state.haveMaterialsFilter and TSM.Crafting.ProfessionUtil.IsCraftable)
	elseif action == "ACTION_QUEUE_BUTTON_CLICKED" then
		local recipeString, quantity = ...
		TSM.Crafting.Queue.Adjust(recipeString, quantity)
	elseif action == "ACTION_SELECT_CRAFT" then
		if not state.professionType then
			return
		end
		local craftString = ...
		if TSM.Crafting.GetProfession(craftString) ~= Profession.GetCurrentProfession() then
			return
		end
		local recipeList = state.frame:GetElement("top.left.content.recipeList")
		recipeList:SetSelectedCraft(craftString)
	elseif action == "ACTION_RECIPE_SELECTION_CHANGED" then
		state.selectedCraftString = state.frame:GetElement("top.left.content.recipeList"):GetSelectedCraft()
	elseif action == "ACTION_BAG_QUANTITY_UPDATED" then
		if not state.frame then
			return
		end
		TSM.Crafting.InvalidateNumQueuedSmartMap()
		if state.frame:HasElement("top.left.content.recipeList") then
			state.frame:GetElement("top.left.content.recipeList"):UpdateData()
		end
		if state.frame:HasElement("top.right.queue.queueList") then
			state.frame:GetElement("top.right.queue.queueList"):UpdateData()
		end
		local details = state.frame:HasElement("details") and state.frame:GetElement("details")
		if details and details._acquired then
			details:Draw()
		end
	elseif action == "ACTION_SKILL_UPDATE" then
		if not state.frame then
			return
		end
		state.professionType = TradeSkill.GetType()
		private.UpdateProfessionsDropdown(state)
	elseif action == "ACTION_QUEUE_NEXT_CRAFT_CHANGED" then
		if not state.frame then
			return
		end
		local recipeString, num = state.frame:GetElement("top.right.queue.queueList"):GetNextCraft()
		local craftString = recipeString and CraftString.FromRecipeString(recipeString)
		if recipeString and (not Profession.HasCraftString(craftString) or TSM.Crafting.ProfessionUtil.GetNumCraftableRecipeString(recipeString) == 0) then
			recipeString = nil
		end
		state.queueCanCraftNext = recipeString and true or false
		if recipeString then
			TSM.Crafting.ProfessionUtil.PrepareToCraft(recipeString, num, CraftString.GetLevel(craftString))
		end
	elseif action == "ACTION_PREPARE_TO_CRAFT" then
		local recipeString, quantity, craftingSource, salvageItemLocation = ...
		state.craftingSource = craftingSource
		local level = RecipeString.GetLevel(recipeString)
		TSM.Crafting.ProfessionUtil.PrepareToCraft(recipeString, quantity, level, salvageItemLocation)
	elseif action == "ACTION_START_CRAFT" then
		local recipeString, quantity, craftingSource, salvageItemLocation = ...
		local craftString = CraftString.FromRecipeString(recipeString)
		if state.craftingRecipeString or Profession.NeededTools(craftString) or (not salvageItemLocation and TSM.Crafting.ProfessionUtil.GetNumCraftableRecipeString(recipeString) == 0) or Profession.GetRemainingCooldown(craftString) then
			return
		end
		state.craftingSource = craftingSource
		private.StartCraft(state, recipeString, quantity, salvageItemLocation)
	elseif action == "ACTION_HANDLE_CRAFT_DONE" then
		local success, isDone = ...
		if success and state.craftingRecipeString then
			Log.Info("Crafted %s", state.craftingRecipeString)
			TSM.Crafting.Queue.Adjust(state.craftingRecipeString, -1)
			assert(state.craftingQuantity > 0)
			if state.craftingQuantity == 1 then
				assert(isDone)
			else
				state.craftingQuantity = state.craftingQuantity - 1
				isDone = false
			end
		else
			isDone = true
		end
		if isDone then
			state.craftingRecipeString = nil
			state.craftingQuantity = nil
			state.craftingSource = nil
		end
	elseif action == "ACTION_DETAILS_CRAFT_BUTTON_CLICKED" then
		local recipeString, quantity, isVellum, salvageItemLocation = ...
		local craftingSource = isVellum and CraftingUIUtils.CRAFTING_SOURCE.VELLUM or CraftingUIUtils.CRAFTING_SOURCE.CRAFT
		if isVellum and not ClientInfo.IsRetail() then
			quantity = math.huge
		end
		return manager:ProcessAction("ACTION_START_CRAFT", recipeString, quantity, craftingSource, salvageItemLocation)
	elseif action == "ACTION_DETAILS_CRAFT_BUTTON_MOUSE_DOWN" then
		local recipeString, quantity, isVellum, salvageItemLocation = ...
		local craftingSource = isVellum and CraftingUIUtils.CRAFTING_SOURCE.VELLUM or CraftingUIUtils.CRAFTING_SOURCE.CRAFT
		if isVellum and not ClientInfo.IsRetail() then
			quantity = math.huge
		end
		return manager:ProcessAction("ACTION_PREPARE_TO_CRAFT", recipeString, quantity, craftingSource, salvageItemLocation)
	elseif action == "ACTION_QUEUE_ROW_MOUSE_DOWN" then
		if state.craftingRecipeString or state.professionType ~= TradeSkill.TYPE.PLAYER then
			return
		end
		local recipeString = ...
		local craftString = CraftString.FromRecipeString(recipeString)
		if Profession.HasCraftString(craftString) then
			local quantity = TSM.Crafting.Queue.GetNum(recipeString)
			return manager:ProcessAction("ACTION_PREPARE_TO_CRAFT", recipeString, quantity, CraftingUIUtils.CRAFTING_SOURCE.QUEUE_CRAFT)
		end
	elseif action == "ACTION_QUEUE_ROW_CLICK" then
		if state.craftingRecipeString or state.professionType ~= TradeSkill.TYPE.PLAYER then
			return
		end
		local recipeString, mouseButton = ...
		local craftString = CraftString.FromRecipeString(recipeString)
		if mouseButton == "RightButton" then
			return manager:ProcessAction("ACTION_SELECT_CRAFT", craftString)
		elseif Profession.HasCraftString(craftString) then
			return manager:ProcessAction("ACTION_START_CRAFT", recipeString, TSM.Crafting.Queue.GetNum(recipeString), CraftingUIUtils.CRAFTING_SOURCE.QUEUE_CRAFT)
		end
	elseif action == "ACTION_QUEUE_NUM_UPDATED" then
		local recipeString, num = ...
		TSM.Crafting.Queue.SetNum(recipeString, num)
	elseif action == "ACTION_CRAFT_NEXT_CLICK" then
		local recipeString = state.frame:GetElement("top.right.queue.queueList"):GetNextCraft()
		private.manager:ProcessAction("ACTION_START_CRAFT", recipeString, TSM.Crafting.Queue.GetNum(recipeString), CraftingUIUtils.CRAFTING_SOURCE.QUEUE_NEXT)
	elseif action == "ACTION_CLEAR_QUEUE" then
		TSM.Crafting.Queue.Clear()
	elseif action == "ACTION_SHOW_RESTOCK_DIALOG" then
		state.frame:GetBaseElement():ShowDialogFrame(UIElements.New("CraftingRestockDialog", "frame")
			:SetSize(540, 420)
			:AddAnchor("CENTER")
			:SetGroupTreeSettingsContext(private.settings, "groupTree")
			:SetManager(manager)
			:SetAction("OnRestockClick", "ACTION_RESTOCK_GROUPS")
		)
	elseif action == "ACTION_RESTOCK_GROUPS" then
		local groups = ...
		TSM.Crafting.Queue.RestockGroups(groups)
	elseif action == "ACTION_PROFESSION_SELECTION_CHANGED" then
		local key = state.frame:GetElement("top.left.controls.professionDropdown"):GetSelectedItemKey()
		if not key then
			return
		end
		local player, profession, skillId = strsplit(KEY_SEP, key)
		if not profession then
			-- The current linked / guild / NPC profession was re-selected, so just ignore this change
			return
		elseif profession == Profession.GetCurrentProfession() then
			-- The selection didn't change
			return
		end
		-- TODO: Support showing of other player's professions?
		assert(player == UnitName("player"))
		TradeSkill.OpenUI(not ClientInfo.IsRetail() and profession or tonumber(skillId))
	else
		error("Unknown action: "..tostring(action))
	end
end

function private.IsProfessionLoaded()
	return not Profession.IsClosed() and Profession.GetCurrentProfession() and Profession.HasScanned() and Profession.ScannerHasSkills() and true or false
end

function private.ColorFilterDialogText(filterActive, text)
	return Theme.GetColor(filterActive and "TEXT" or "TEXT+DISABLED"):ColorText(text)
end

function private.StartCraft(state, recipeString, quantity, salvageItemLocation)
	local numCrafted = TSM.Crafting.ProfessionUtil.Craft(recipeString, quantity, state.craftingSource ~= CraftingUIUtils.CRAFTING_SOURCE.CRAFT, salvageItemLocation, private.CraftCallback)
	Log.Info("Crafting %d (requested %s) of %s", numCrafted, quantity == math.huge and "all" or quantity, recipeString)
	if numCrafted == 0 then
		return
	end
	state.craftingRecipeString = recipeString
	state.craftingQuantity = numCrafted
end

function private.CraftCallback(success, isDone)
	private.craftResult.success = success
	private.craftResult.isDone = isDone
	private.craftTimer:RunForFrames(1)
end

---@param state CraftingUIState
function private.UpdateProfessionsDropdown(state)
	-- Update the professions dropdown info
	local dropdownSelection = nil
	local currentProfession = Profession.GetCurrentProfession()
	wipe(private.professions)
	wipe(private.professionsKeys)
	if currentProfession and state.professionType and state.professionType ~= TradeSkill.TYPE.PLAYER then
		assert(not ClientInfo.IsVanillaClassic())
		local playerName = nil
		if state.professionType == TradeSkill.TYPE.LINKED then
			playerName = TradeSkill.GetLinkedPlayer() or "?"
		elseif state.professionType == TradeSkill.TYPE.NPC then
			playerName = L["NPC"]
		elseif state.professionType == TradeSkill.TYPE.GUILD then
			playerName = L["Guild"]
		end
		assert(playerName)
		tinsert(private.professions, currentProfession)
		local key = currentProfession
		tinsert(private.professionsKeys, key)
		dropdownSelection = key
	end

	for _, player, profession, skillId, level, maxLevel in TSM.Crafting.PlayerProfessions.Iterator() do
		if player == UnitName("player") then
			tinsert(private.professions, format("%s (%d/%d)", profession, level, maxLevel))
			local key = player..KEY_SEP..profession..KEY_SEP..skillId
			tinsert(private.professionsKeys, key)
			if state.professionType == TradeSkill.TYPE.PLAYER and profession == currentProfession then
				assert(not dropdownSelection)
				dropdownSelection = key
			end
		end
	end

	state.frame:GetElement("top.left.controls.professionDropdown")
		:SetItems(private.professions, private.professionsKeys)
		:SetSelectedItemByKey(dropdownSelection, true)
		:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameOnUpdate(frame)
	-- Delay the event by a few frames to give textures a chance to load
	if private.showDelayFrame == SHOW_DELAY_FRAMES then
		frame:SetScript("OnUpdate", nil)
		private.manager:ProcessAction("ACTION_FRAME_SHOW_DELAYED", frame)
	else
		private.showDelayFrame = private.showDelayFrame + 1
	end
end

function private.QueueTooltipFunc()
	local tooltipLines = TempTable.Acquire()
	tinsert(tooltipLines, Theme.GetColor("INDICATOR"):ColorText(L["Queue Summary"]))
	local totalCost, totalProfit, totalCastTime = TSM.Crafting.Queue.GetTotals()
	local totalCostStr = totalCost and Money.ToStringForUI(totalCost) or "---"
	local totalProfitStr =  totalProfit and Money.ToStringForUI(totalProfit, Theme.GetColor(totalProfit >= 0 and "FEEDBACK_GREEN" or "FEEDBACK_RED"):GetTextColorPrefix()) or "---"
	local totalCastTimeStr = totalCastTime and SecondsToTime(totalCastTime) or "---"
	tinsert(tooltipLines, L["Crafting Cost"]..":"..Tooltip.GetSepChar()..totalCostStr)
	tinsert(tooltipLines, L["Estimated Profit"]..":"..Tooltip.GetSepChar()..totalProfitStr)
	tinsert(tooltipLines, L["Estimated Time"]..":"..Tooltip.GetSepChar()..totalCastTimeStr)
	return strjoin("\n", TempTable.UnpackAndRelease(tooltipLines)), true, 16
end

function private.QueueCountToText(count)
	return format(L["Queue (%d)"], count)
end

function private.ScrollTableCostsFunc(craftString)
	if GetTime() - private.costsCache.updateTime > 0.5 then
		wipe(private.costsCache.isCached)
		wipe(private.costsCache.craftingCost)
		wipe(private.costsCache.itemValue)
		wipe(private.costsCache.profit)
		wipe(private.costsCache.saleRate)
		private.costsCache.updateTime = GetTime()
	end
	if not private.costsCache.isCached[craftString] then
		local craftingCost, itemValue, profit = TSM.Crafting.Cost.GetCostsByCraftString(craftString)
		private.costsCache.isCached[craftString] = true
		private.costsCache.craftingCost[craftString] = craftingCost
		private.costsCache.itemValue[craftString] = itemValue
		private.costsCache.profit[craftString] = profit
		private.costsCache.saleRate[craftString] = TSM.Crafting.Cost.GetSaleRateByCraftString(craftString)
	end
	return private.costsCache.craftingCost[craftString], private.costsCache.itemValue[craftString], private.costsCache.profit[craftString], private.costsCache.saleRate[craftString]
end
