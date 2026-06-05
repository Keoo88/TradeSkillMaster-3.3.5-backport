-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Tooltip = TSM.MainUI.Settings:NewPackage("Tooltip") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local Money = TSM.LibTSMUtil:Include("UI.Money")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Operation = TSM.LibTSMTypes:Include("Operation")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local private = {
	settings = nil,
	operationModules = {},
	operationModuleNames = {},
}
local GROUPS_OPS_SETTINGS_INFO = {
	{ label = L["Group name"], settingKey = "groupNameTooltip" },
	{ label = L["Auctioning operation"], settingTbl = "operationTooltips", settingKey = "Auctioning" },
	{ label = L["Crafting operation"], settingTbl = "operationTooltips", settingKey = "Crafting" },
	{ label = L["Mailing operation"], settingTbl = "operationTooltips", settingKey = "Mailing" },
	{ label = L["Shopping operation"], settingTbl = "operationTooltips", settingKey = "Shopping" },
	{ label = L["Sniper operation"], settingTbl = "operationTooltips", settingKey = "Sniper" },
	{ label = L["Vendoring operation"], settingTbl = "operationTooltips", settingKey = "Vendoring" },
	{ label = L["Warehousing operation"], settingTbl = "operationTooltips", settingKey = "Warehousing" },
}
local VALUES_SETTINGS_INFO = {
	{ label = L["Full destroy tooltip"], settingKey = "destroyTooltipFormat", setValue = "full", clearValue = "none" },
	{ label = L["Simple destroy tooltip"], settingKey = "destroyTooltipFormat", setValue = "simple", clearValue = "none" },
	{ label = L["Full convert tooltip"], settingKey = "convertTooltipFormat", setValue = "full", clearValue = "none" },
	{ label = L["Simple convert tooltip"], settingKey = "convertTooltipFormat", setValue = "simple", clearValue = "none" },
	{ label = L["Vendor buy price"], settingKey = "vendorBuyTooltip" },
	{ label = L["Vendor sell price"], settingKey = "vendorSellTooltip" },
}
local INVENTORY_SETTINGS_INFO = {
	{ label = L["Full inventory"], settingKey = "inventoryTooltipFormat", setValue = "full", clearValue = "none" },
	{ label = L["Simple inventory"], settingKey = "inventoryTooltipFormat", setValue = "simple", clearValue = "none" },
}
local ACCOUNTING_SETTINGS_INFO = {
	{ label = L["Purchase information"], settingModule = "Accounting", settingKey = "purchase" },
	{ label = L["Sale information"], settingModule = "Accounting", settingKey = "sale" },
	{ label = L["Sale rate"], settingModule = "Accounting", settingKey = "saleRate" },
	{ label = L["Expired information"], settingModule = "Accounting", settingKey = "expiredAuctions" },
	{ label = L["Cancelled information"], settingModule = "Accounting", settingKey = "cancelledAuctions" },
}
local AUCTIONDB_SETTINGS_INFO = ClientInfo.IsRetail() and {
	{ label = L["Min buyout"], settingModule = "AuctionDB", settingKey = "minBuyout" },
	{ label = L["Recent value"], settingModule = "AuctionDB", settingKey = "marketValueRecent" },
	{ label = L["Market value"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Market value and trend"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Historical price"], settingModule = "AuctionDB", settingKey = "historical" },
	{ label = L["Alt realm min buyout"], settingModule = "AuctionDB", settingKey = "altMinBuyout" },
	{ label = L["Alt realm recent value"], settingModule = "AuctionDB", settingKey = "altMarketValueRecent" },
	{ label = L["Alt realm market value"], settingModule = "AuctionDB", settingKey = "altMarketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Alt realm market value and trend"], settingModule = "AuctionDB", settingKey = "altMarketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Alt realm historical price"], settingModule = "AuctionDB", settingKey = "altHistorical" },
	{ label = L["Region market value"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Region market value and trend"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Region historical price"], settingModule = "AuctionDB", settingKey = "regionHistorical" },
	{ label = L["Region sale avg"], settingModule = "AuctionDB", settingKey = "regionSale" },
	{ label = L["Region sale rate"], settingModule = "AuctionDB", settingKey = "regionSalePercent" },
	{ label = L["Region avg daily sold"], settingModule = "AuctionDB", settingKey = "regionSoldPerDay" },
} or {
	{ label = L["Min buyout"], settingModule = "AuctionDB", settingKey = "minBuyout" },
	{ label = L["Recent value"], settingModule = "AuctionDB", settingKey = "marketValueRecent" },
	{ label = L["Market value"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Market value and trend"], settingModule = "AuctionDB", settingKey = "marketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Historical price"], settingModule = "AuctionDB", settingKey = "historical" },
	{ label = L["Region market value"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "noTrend", clearValue = "none" },
	{ label = L["Region market value and trend"], settingModule = "AuctionDB", settingKey = "regionMarketValue", setValue = "withTrend", clearValue = "none" },
	{ label = L["Region historical price"], settingModule = "AuctionDB", settingKey = "regionHistorical" },
	{ label = L["Region sale avg"], settingModule = "AuctionDB", settingKey = "regionSale" },
	{ label = L["Region sale rate"], settingModule = "AuctionDB", settingKey = "regionSalePercent" },
	{ label = L["Region avg daily sold"], settingModule = "AuctionDB", settingKey = "regionSoldPerDay" },
}
local AUCTIONING_SETTINGS_INFO = {
	{ label = L["Post Quantity"], settingModule = "Auctioning", settingKey = "postQuantity" },
	{ label = L["Min/Normal/Max price"], settingModule = "Auctioning", settingKey = "operationPrices" },
}
local CRAFTING_SETTINGS_INFO = {
	{ label = L["Crafting cost"], settingModule = "Crafting", settingKey = "craftingCost" },
	{ label = L["Detailed crafting cost"], settingModule = "Crafting", settingKey = "detailedMats" },
	{ label = L["Mat cost"], settingModule = "Crafting", settingKey = "matPrice" },
}
local SHOPPING_SETTINGS_INFO = {
	{ label = L["Max shopping price"], settingModule = "Shopping", settingKey = "maxPrice" },
}
local SNIPER_SETTINGS_INFO = {
	{ label = L["Max sniper price"], settingModule = "Sniper", settingKey = "belowPrice" },
}
local SETTING_TOOLTIPS = {
	enabled = L["This setting allows for enabling or disabling the tooltip information provided by TSM as a whole."],
	embeddedTooltip = L["This option allows for embedding the information provided by TSM in the existing item tooltip. If disabled, the information provided by TSM will be separated in to another anchored tooltip."],
	tooltipPriceFormat = L["Selects whether TSM uses text or icons to label gold, silver, and copper values."],
	tooltipShowModifier = L["Select whether to show the information provided by TSM in tooltips all the time i.e 'None (Always Show)', or only show the information provided by TSM when holding a modifier i.e CTRL or SHIFT."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Tooltip.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "tooltipOptions", "enabled")
		:AddKey("global", "tooltipOptions", "embeddedTooltip")
		:AddKey("global", "tooltipOptions", "tooltipPriceFormat")
		:AddKey("global", "tooltipOptions", "tooltipShowModifier")
		:AddKey("global", "tooltipOptions", "customPriceTooltips")
		:AddKey("global", "tooltipOptions", "moduleTooltips")
		:AddKey("global", "tooltipOptions", "inventoryTooltipFormat")
		:AddKey("global", "tooltipOptions", "vendorBuyTooltip")
		:AddKey("global", "tooltipOptions", "vendorSellTooltip")
		:AddKey("global", "tooltipOptions", "convertTooltipFormat")
		:AddKey("global", "tooltipOptions", "destroyTooltipFormat")
		:AddKey("global", "tooltipOptions", "groupNameTooltip")
		:AddKey("global", "tooltipOptions", "operationTooltips")
		:AddKey("global", "userData", "customPriceSources")
	TSM.MainUI.Settings.RegisterSettingPage(L["Tooltip Settings"], "top", private.GetTooltipSettingsFrame)
end



-- ============================================================================
-- Tooltip Settings UI
-- ============================================================================

function private.GetTooltipSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "tooltips", "main")
	wipe(private.operationModules)
	wipe(private.operationModuleNames)
	for _, moduleName in Operation.TypeIterator() do
		tinsert(private.operationModules, moduleName)
		tinsert(private.operationModuleNames, Operation.GetLocalizedName(moduleName))
	end
	return UIElements.New("ScrollFrame", "tooltipSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Tooltip", "general", L["General Options"], L["Some general options for the TSM tooltip information are below."])
			:AddChild(UIElements.New("Text", "label")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Enable TSM tooltips"])
			)
			:AddChild(UIElements.New("ToggleYesNo", "enableToggle")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 12)
				:SetSettingInfo(private.settings, "enabled")
				:SetTooltip(SETTING_TOOLTIPS.enabled)
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "embedCheckbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Embed TSM tooltip"])
					:SetSettingInfo(private.settings, "embeddedTooltip")
					:SetTooltip(SETTING_TOOLTIPS.embeddedTooltip, "__parent")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "labelRow1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:AddChild(UIElements.New("Text", "priceFormatLabel")
					:SetMargin(0, 8, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Tooltip price format"])
				)
				:AddChild(UIElements.New("Text", "modifierLabel")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Show on modifier"])
				)
			)
			:AddChild(UIElements.New("Frame", "dropdownRow1")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("SelectionDropdown", "priceFormatDropdown")
					:SetMargin(0, 8, 0, 0)
					:AddItem(format(L["Coins (%s)"], Money.ToStringForTooltip(3451267, nil, true, false)), "icon")
					:AddItem(format(L["Text (%s)"], Money.ToStringForTooltip(3451267, nil, false, false)), "text")
					:SetSettingInfo(private.settings, "tooltipPriceFormat")
					:SetScript("OnSelectionChanged", private.OnSettingChange)
					:SetTooltip(SETTING_TOOLTIPS.tooltipPriceFormat, "__parent")
				)
				:AddChild(UIElements.New("SelectionDropdown", "modifierDropdown")
					:AddItem(L["None (Always Show)"], "none")
					:AddItem(ALT_KEY, "alt")
					:AddItem(CTRL_KEY, "ctrl")
					:SetSettingInfo(private.settings, "tooltipShowModifier")
					:SetTooltip(SETTING_TOOLTIPS.tooltipShowModifier, "__parent")
				)
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Tooltip", "options", L["Tooltip Options"], L["Use the settings below to control which lines are shown in tooltips."])
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetHeight(private.GetSettingsHeight())
				:AddChild(UIElements.New("Frame", "settings")
					:SetLayout("VERTICAL")
					:SetMargin(0, 8, 0, -12)
					:AddChildrenWithFunction(private.AddTooltipSettings)
				)
				:AddChild(UIElements.New("Frame", "example")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 6)
						:SetFont("BODY_BODY2_BOLD")
						:SetText(L["Example Tooltip"])
					)
					:AddChild(UIElements.New("Frame", "tooltip")
						:SetLayout("VERTICAL")
						:SetPadding(4)
						:SetBackgroundColor("PRIMARY_BG")
						:AddChildrenWithFunction(private.AddExampleTooltip)
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
				)
			)
		)
end

function private.GetSettingsHeight()
	-- calculate the height of the settings and use that for the content height since the settings will always be larger than the tooltip
	local height = 0
	height = height + 32 + #GROUPS_OPS_SETTINGS_INFO * 32
	height = height + 32 + #VALUES_SETTINGS_INFO * 32 + Table.Count(private.settings.customPriceSources) * 32
	height = height + 32 + #INVENTORY_SETTINGS_INFO * 32
	height = height + 32 + #ACCOUNTING_SETTINGS_INFO * 32
	height = height + 32 + #AUCTIONDB_SETTINGS_INFO * 32
	height = height + 32 + #AUCTIONING_SETTINGS_INFO * 32
	height = height + 32 + #CRAFTING_SETTINGS_INFO * 32
	height = height + 32 + #SHOPPING_SETTINGS_INFO * 32
	height = height + 32 + #SNIPER_SETTINGS_INFO * 32
	height = height - 12
	return height
end

function private.AddTooltipSettings(frame)
	private.AddSettingHeading(frame, "groupsOpsHeading", L["Groups & Operations"])
	private.AddSettingsFromInfoTable(frame, GROUPS_OPS_SETTINGS_INFO)

	private.AddSettingHeading(frame, "valuesHeading", L["Values"])
	private.AddSettingsFromInfoTable(frame, VALUES_SETTINGS_INFO)

	local customPriceSources = TempTable.Acquire()
	for name in pairs(private.settings.customPriceSources) do
		tinsert(customPriceSources, name)
	end
	sort(customPriceSources)
	for _, name in ipairs(customPriceSources) do
		frame:AddChild(UIElements.New("Checkbox", "checkbox_"..name)
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_BODY2")
			:SetText(format(L["Custom source (%s)"], name))
			:SetSettingInfo(private.settings.customPriceTooltips, name)
			:SetScript("OnValueChanged", private.CustomPriceSourceOnValueChanged)
		)
	end
	TempTable.Release(customPriceSources)

	private.AddSettingHeading(frame, "inventoryHeading", L["Inventory"])
	private.AddSettingsFromInfoTable(frame, INVENTORY_SETTINGS_INFO)

	private.AddSettingHeading(frame, "accountingHeading", L["Accounting"])
	private.AddSettingsFromInfoTable(frame, ACCOUNTING_SETTINGS_INFO)

	private.AddSettingHeading(frame, "auctiondbHeading", L["AuctionDB"])
	private.AddSettingsFromInfoTable(frame, AUCTIONDB_SETTINGS_INFO)

	private.AddSettingHeading(frame, "auctioningHeading", L["Auctioning"])
	private.AddSettingsFromInfoTable(frame, AUCTIONING_SETTINGS_INFO)

	private.AddSettingHeading(frame, "craftingHeading", L["Crafting"])
	private.AddSettingsFromInfoTable(frame, CRAFTING_SETTINGS_INFO)

	private.AddSettingHeading(frame, "shoppingHeading", L["Shopping"])
	private.AddSettingsFromInfoTable(frame, SHOPPING_SETTINGS_INFO)

	private.AddSettingHeading(frame, "sniperHeading", L["Sniper"])
	private.AddSettingsFromInfoTable(frame, SNIPER_SETTINGS_INFO)
end

function private.AddSettingHeading(frame, id, heading)
	frame:AddChild(UIElements.New("Text", id)
		:SetHeight(20)
		:SetMargin(0, 0, 0, 12)
		:SetFont("BODY_BODY2_BOLD")
		:SetText(heading)
	)
end

function private.GetSettingTableFromInfo(info)
	if info.settingModule then
		return private.settings.moduleTooltips[info.settingModule]
	elseif info.settingTbl then
		return private.settings[info.settingTbl]
	else
		return private.settings
	end
end

function private.AddSettingsFromInfoTable(frame, infoTbl)
	for i, info in ipairs(infoTbl) do
		local settingTbl = private.GetSettingTableFromInfo(info)
		frame:AddChild(UIElements.New("Checkbox", "checkbox_"..i)
			:SetHeight(20)
			:SetMargin(0, 0, 0, 12)
			:SetFont("BODY_BODY2")
			:SetContext(info)
			:SetText(info.label)
			:SetChecked(settingTbl[info.settingKey] == (info.setValue or true))
			:SetScript("OnValueChanged", private.ContentCheckboxOnValueChanged)
		)
	end
end

function private.AddExampleTooltip(frame)
	for i, left, right, lineColor in TSM.Tooltip.SettingsLineIterator() do
		frame:AddChild(UIElements.New("Frame", "row_"..i)
			:SetLayout("HORIZONTAL")
			:SetHeight(20)
			:AddChild(UIElements.New("Text", "left_"..i)
				:SetWidth("AUTO")
				:SetFont("ITEM_BODY3")
				:SetTextColor(lineColor)
				:SetText(left)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
			:AddChildIf(right, UIElements.New("Text", "right_"..i)
				:SetWidth("AUTO")
				:SetFont("ITEM_BODY3")
				:SetTextColor(lineColor)
				:SetJustifyH("RIGHT")
				:SetText(right or "")
			)
		)
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.OnSettingChange(checkbox)
	private.RebuildExampleTooltip(checkbox:GetElement("__parent.__parent.__parent.__parent.options.content.content.example.tooltip"))
end

function private.ContentCheckboxOnValueChanged(checkbox)
	local info = checkbox:GetContext()
	local settingTbl = private.GetSettingTableFromInfo(info)
	if checkbox:IsChecked() then
		settingTbl[info.settingKey] = info.setValue or true
	else
		settingTbl[info.settingKey] = info.clearValue or false
	end
	local frame = checkbox:GetParentElement()
	for _, child in frame:LayoutChildrenIterator() do
		local childContext = child:GetContext()
		if child ~= checkbox and childContext and childContext.settingTbl == info.settingTbl and childContext.settingKey == info.settingKey then
			child:SetChecked(settingTbl[childContext.settingKey] == (childContext.setValue or true), true)
				:Draw()
		end
	end
	private.RebuildExampleTooltip(checkbox:GetElement("__parent.__parent.example.tooltip"))
end

function private.CustomPriceSourceOnValueChanged(checkbox)
	private.RebuildExampleTooltip(checkbox:GetElement("__parent.__parent.example.tooltip"))
end

function private.RebuildExampleTooltip(tooltipFrame)
	tooltipFrame:ReleaseAllChildren()
	tooltipFrame:AddChildrenWithFunction(private.AddExampleTooltip)
	tooltipFrame:Draw()
end
