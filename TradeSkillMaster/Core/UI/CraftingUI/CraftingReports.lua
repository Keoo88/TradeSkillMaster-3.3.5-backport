-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local CraftingReports = TSM.UI.CraftingUI:NewPackage("CraftingReports") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local CraftString = TSM.LibTSMTypes:Include("Crafting.CraftString")
local RecipeString = TSM.LibTSMTypes:Include("Crafting.RecipeString")
local Money = TSM.LibTSMUtil:Include("UI.Money")
local String = TSM.LibTSMUtil:Include("Lua.String")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomPrice = TSM.LibTSMApp:Include("Service.CustomPrice")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	filterText = "",
	craftProfessions = {},
	matProfessions = {},
}
local MAT_PRICE_SOURCES = {ALL, L["Default Price"], L["Custom Price"]}



-- ============================================================================
-- Module Functions
-- ============================================================================

function CraftingReports.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "craftingUIContext", "craftsScrollingTable")
		:AddKey("global", "craftingUIContext", "matsScrollingTable")
		:AddKey("factionrealm", "internalData", "mats")
		:AddKey("global", "craftingOptions", "defaultMatCostMethod")
	TSM.UI.CraftingUI.RegisterTopLevelPage(L["Reports"], private.GetCraftingReportsFrame)
end



-- ============================================================================
-- CraftingReports UI
-- ============================================================================

function private.GetCraftingReportsFrame()
	UIUtils.AnalyticsRecordPathChange("crafting", "crafting_reports")
	return UIElements.New("Frame", "craftingReportsContent")
		:SetLayout("VERTICAL")
		:SetPadding(0, 0, 6, 0)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("TabGroup", "buttons")
			:SetNavCallback(private.GetTabElements)
			:AddPath(L["Crafts"], true)
			:AddPath(L["Materials"])
		)
end

function private.GetTabElements(self, path)
	if path == L["Crafts"] then
		UIUtils.AnalyticsRecordPathChange("crafting", "crafting_reports", "crafts")
		private.filterText = ""
		wipe(private.craftProfessions)
		tinsert(private.craftProfessions, L["All Professions"])
		for _, player, profession in TSM.Crafting.PlayerProfessions.Iterator() do
			tinsert(private.craftProfessions, format("%s - %s", profession, player))
		end

		return UIElements.New("Frame", "crafts")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("Frame", "filters")
				:SetLayout("HORIZONTAL")
				:SetHeight(72)
				:SetPadding(10, 10, 8, 16)
				:AddChild(UIElements.New("Frame", "search")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 4)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Filter by Keyword"])
					)
					:AddChild(UIElements.New("Input", "input")
						:SetHeight(24)
						:AllowItemInsert()
						:SetIconTexture("iconPack.18x18/Search")
						:SetClearButtonEnabled(true)
						:SetHintText(L["Enter Keyword"])
						:SetScript("OnValueChanged", private.CraftsInputOnValueChanged)
					)
				)
				:AddChild(UIElements.New("Frame", "profession")
					:SetLayout("VERTICAL")
					:SetMargin(16, 16, 0, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 4)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Filter by Profession"])
					)
					:AddChild(UIElements.New("ListDropdown", "dropdown")
						:SetHeight(24)
						:SetItems(private.craftProfessions)
						:SetSelectedItem(private.craftProfessions[1], true)
						:SetScript("OnSelectionChanged", private.CraftsDropdownOnSelectionChanged)
					)
				)
				:AddChild(UIElements.New("Frame", "craftable")
					:SetLayout("HORIZONTAL")
					:SetSize(176, 24)
					:SetMargin(0, 0, 24, 0)
					:AddChild(UIElements.New("Checkbox", "checkbox")
						:SetWidth(24)
						:SetFont("BODY_BODY2")
						:SetScript("OnValueChanged", private.CheckboxOnValueChanged)
					)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_BODY2")
						:SetText(L["Only show craftable"])
					)
				)
			)
			:AddChild(UIElements.New("CraftsScrollTable", "crafts")
				:SetSettings(private.settings, "craftsScrollingTable")
				:SetQuery(TSM.Crafting.CreateCraftsQuery()
					:VirtualField("firstOperation", "string", private.FirstOperationVirtualField, "itemString")
					:VirtualField("itemName", "string", ItemInfo.GetName, "itemString", "?")
				)
				:SetScript("OnCraftQueueChange", private.CraftsOnCraftQueueChange)
			)
	elseif path == L["Materials"] then
		UIUtils.AnalyticsRecordPathChange("crafting", "crafting_reports", "materials")
		wipe(private.matProfessions)
		tinsert(private.matProfessions, L["All Professions"])
		for _, _, profession in TSM.Crafting.PlayerProfessions.Iterator() do
			if not private.matProfessions[profession] then
				tinsert(private.matProfessions, profession)
				private.matProfessions[profession] = true
			end
		end

		return UIElements.New("Frame", "materials")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("Frame", "filters")
				:SetLayout("HORIZONTAL")
				:SetHeight(72)
				:SetPadding(10, 10, 8, 16)
				:AddChild(UIElements.New("Frame", "search")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 4)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Filter by Keyword"])
					)
					:AddChild(UIElements.New("Input", "input")
						:SetHeight(24)
						:AllowItemInsert()
						:SetIconTexture("iconPack.18x18/Search")
						:SetClearButtonEnabled(true)
						:SetHintText(L["Enter Keyword"])
						:SetScript("OnValueChanged", private.MatsInputOnValueChanged)
					)
				)
				:AddChild(UIElements.New("Frame", "profession")
					:SetLayout("VERTICAL")
					:SetMargin(16, 0, 0, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 4)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Filter by Profession"])
					)
					:AddChild(UIElements.New("ListDropdown", "dropdown")
						:SetHeight(24)
						:SetItems(private.matProfessions)
						:SetSelectedItem(private.matProfessions[1], true)
						:SetScript("OnSelectionChanged", private.MatsDropdownOnSelectionChanged)
					)
				)
				:AddChild(UIElements.New("Frame", "priceSource")
					:SetLayout("VERTICAL")
					:SetMargin(16, 0, 0, 0)
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 4)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Filter by Price Source"])
					)
					:AddChild(UIElements.New("ListDropdown", "dropdown")
						:SetHeight(24)
						:SetItems(MAT_PRICE_SOURCES)
						:SetSelectedItemByIndex(1, true)
						:SetScript("OnSelectionChanged", private.MatsDropdownOnSelectionChanged)
					)
				)
			)
			:AddChild(UIElements.New("MatsScrollTable", "mats")
				:SetSettings(private.settings, "matsScrollingTable")
				:SetQuery(TSM.Crafting.CreateMatItemQuery())
				:SetScript("OnRowClick", private.MatsOnRowClick)
			)
	else
		error("Unknown path: "..tostring(path))
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.CraftsInputOnValueChanged(input)
	local text = input:GetValue()
	if text == private.filterText then
		return
	end
	private.filterText = text
	private.UpdateCraftsQueryWithFilters(input:GetParentElement():GetParentElement())
end

function private.CraftsDropdownOnSelectionChanged(dropdown)
	private.UpdateCraftsQueryWithFilters(dropdown:GetParentElement():GetParentElement())
end

function private.CheckboxOnValueChanged(checkbox)
	private.UpdateCraftsQueryWithFilters(checkbox:GetParentElement():GetParentElement())
end

function private.CraftsOnCraftQueueChange(_, craftString, change)
	local recipeString = RecipeString.FromCraftString(craftString)
	if CraftString.GetLevel(craftString) then
		return
	end
	TSM.Crafting.Queue.Adjust(recipeString, change)
end

function private.MatsInputOnValueChanged(input)
	private.UpdateMatsQueryWithFilters(input:GetParentElement():GetParentElement())
end

function private.MatsDropdownOnSelectionChanged(dropdown)
	private.UpdateMatsQueryWithFilters(dropdown:GetParentElement():GetParentElement())
end

function private.MatsOnRowClick(scrollTable, itemString)
	local matInfo = private.settings.mats[itemString]
	local priceStr = matInfo.customValue or private.settings.defaultMatCostMethod
	scrollTable:GetBaseElement():ShowDialogFrame(UIElements.New("CustomStringDialog", "dialog")
		:Configure(L["Material Cost"], priceStr, private.MatPriceValidateFunc)
		:SetContext(itemString)
		:SetScript("OnDoneEditing", private.MatPriceDialogDoneEditing)
		:SetScript("OnValueChanged", private.MatPriceDialogValueChanged)
		:AddChildBeforeById("input", UIElements.New("Frame", "item")
			:SetLayout("HORIZONTAL")
			:SetHeight(36)
			:SetPadding(6)
			:SetMargin(0, 0, 0, 10)
			:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
			:SetContext(itemString)
			:AddChild(UIElements.New("Button", "icon")
				:SetWidth(24)
				:SetMargin(0, 8, 0, 0)
				:SetBackground(ItemInfo.GetTexture(itemString))
				:SetTooltip(itemString)
			)
			:AddChild(UIElements.New("Text", "name")
				:SetMargin(0, 8, 0, 0)
				:SetFont("ITEM_BODY1")
				:SetText(UIUtils.GetDisplayItemName(itemString))
			)
			:AddChild(UIElements.New("Button", "resetBtn")
				:SetWidth("AUTO")
				:SetFont("BODY_BODY3_MEDIUM")
				:SetTextColor(matInfo.customValue and "TEXT" or "TEXT_ALT")
				:SetDisabled(not matInfo.customValue)
				:SetText(L["Reset to Default"])
				:SetScript("OnClick", private.ResetButtonOnClick)
			)
		)
	)
end

function private.MatPriceValidateFunc(_, value)
	return CustomPrice.Validate(value)
end

function private.MatPriceDialogDoneEditing(dialog, value)
	local itemString = dialog:GetContext()
	if private.IsDefaultMatCost(value) and not private.settings.mats[itemString].customValue then
		return
	end
	TSM.Crafting.SetMatCustomValue(itemString, value)
end

function private.MatPriceDialogValueChanged(dialog, value)
	local resetBtn = dialog:GetElement("item.resetBtn")
	if not value then
		resetBtn:SetTextColor("TEXT")
		resetBtn:SetDisabled(false)
		return
	end
	local itemString = dialog:GetContext()
	local canReset = not private.IsDefaultMatCost(value) or private.settings.mats[itemString].customValue
	resetBtn:SetTextColor(canReset and "TEXT" or "TEXT_ALT")
	resetBtn:SetDisabled(not canReset)
end

function private.IsDefaultMatCost(value)
	return value == gsub(private.settings.defaultMatCostMethod, "[\r\n ]", "")
end

function private.ResetButtonOnClick(button)
	local itemString = button:GetParentElement():GetContext()
	TSM.Crafting.SetMatCustomValue(itemString, nil)
	assert(not private.settings.mats[itemString].customValue)
	button:GetElement("__parent.__parent.input")
		:SetValue(Money.ToStringExact(private.settings.defaultMatCostMethod) or private.settings.defaultMatCostMethod)
		:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FirstOperationVirtualField(itemString)
	return TSM.Operations.GetFirstOperationByItem("Crafting", itemString) or ""
end

function private.UpdateCraftsQueryWithFilters(frame)
	local name = String.Escape(strtrim(frame:GetElement("search.input"):GetValue()))
	if name == "" then
		name = nil
	end
	local profession, player = nil, nil
	local professionPlayer = frame:GetElement("profession.dropdown"):GetSelectedItem()
	if professionPlayer ~= private.craftProfessions[1] then
		profession, player = strmatch(professionPlayer, "^(.+) %- ([^ ]+)$")
	end
	local craftableFilterFunc = frame:GetElement("craftable.checkbox"):IsChecked() and private.IsCraftableQueryFilter or nil
	frame:GetElement("__parent.crafts"):SetFilters(name, profession, player, craftableFilterFunc)
end

function private.IsCraftableQueryFilter(craftString)
	return TSM.Crafting.ProfessionUtil.GetNumCraftableFromDB(craftString) > 0
end

function private.UpdateMatsQueryWithFilters(frame)
	local name = String.Escape(strtrim(frame:GetElement("search.input"):GetValue()))
	if name == "" then
		name = nil
	end
	local profession = frame:GetElement("profession.dropdown"):GetSelectedItem()
	if profession == private.matProfessions[1] then
		profession = nil
	end
	local hasCustomValue = nil
	local priceSource = frame:GetElement("priceSource.dropdown"):GetSelectedItem()
	if priceSource == MAT_PRICE_SOURCES[2] then
		hasCustomValue = false
	elseif priceSource == MAT_PRICE_SOURCES[3] then
		hasCustomValue = true
	end
	frame:GetElement("__parent.mats"):SetFilters(name, profession, hasCustomValue)
end
