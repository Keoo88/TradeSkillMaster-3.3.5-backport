-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Crafting = TSM.MainUI.Settings:NewPackage("Crafting") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local private = {
	settings = nil,
	altCharacters = {},
	altGuilds = {},
}
local BAD_MAT_PRICE_SOURCES = {
	matprice = true,
}
local BAD_CRAFT_VALUE_PRICE_SOURCES = {
	crafting = true,
}
local SETTING_TOOLTIPS = {
	ignoreCharacters = L["Select characters which Crafting should ignore the inventory of for materials and crafted items."],
	ignoreGuilds = L["Select guilds which Crafting should ignore the inventory of for materials and crafted items."],
	defaultMatCostMethod = L["A custom string which defines how TSM determines the cost of acquiring a material by default. This can be overridden on a per-material basis within the 'Crafting Reports' tab of the Crafting UI."],
	defaultCraftPriceMethod = L["A custom string which defines how TSM determines the value of a crafted item. This can be overridden within a Crafting operation."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Crafting.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "craftingOptions", "defaultMatCostMethod")
		:AddKey("global", "craftingOptions", "defaultCraftPriceMethod")
		:AddKey("global", "craftingOptions", "ignoreCharacters")
		:AddKey("global", "craftingOptions", "ignoreGuilds")
	TSM.MainUI.Settings.RegisterSettingPage(L["Crafting"], "middle", private.GetCraftingSettingsFrame)
end



-- ============================================================================
-- Crafting Settings UI
-- ============================================================================

function private.GetCraftingSettingsFrame()
	UIUtils.AnalyticsRecordPathChange("main", "settings", "crafting")
	wipe(private.altCharacters)
	wipe(private.altGuilds)
	for _, character in PlayerInfo.CharacterIterator(true) do
		tinsert(private.altCharacters, character)
	end
	for _, name in PlayerInfo.GuildIterator() do
		tinsert(private.altGuilds, name)
	end

	return UIElements.New("ScrollFrame", "craftingSettings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Crafting", "inventory", L["Inventory Options"], "")
			:AddChild(UIElements.New("Frame", "inventoryOptionsLabels")
				:SetLayout("HORIZONTAL")
				:SetMargin(0, 0, 0, 4)
				:SetHeight(18)
				:AddChild(UIElements.New("Text", "label")
					:SetMargin(0, 12, 0, 0)
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Ignore Characters"])
				)
				:AddChild(UIElements.New("Text", "label")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Ignore Guilds"])
				)
			)
			:AddChild(UIElements.New("Frame", "inventoryOptionsDropdowns")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("MultiselectionDropdown", "charDropdown")
					:SetMargin(0, 12, 0, 0)
					:SetItems(private.altCharacters, private.altCharacters)
					:SetSettingInfo(private.settings, "ignoreCharacters")
					:SetSelectionText(L["No Characters"], L["%d Characters"], L["All Characters"])
					:SetTooltip(SETTING_TOOLTIPS.ignoreCharacters)
				)
				:AddChild(UIElements.New("MultiselectionDropdown", "guildDropdown")
					:SetItems(private.altGuilds, private.altGuilds)
					:SetSettingInfo(private.settings, "ignoreGuilds")
					:SetSelectionText(L["No Guilds"], L["%d Guilds"], L["All Guilds"])
					:SetTooltip(SETTING_TOOLTIPS.ignoreGuilds)
				)
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Crafting", "price", L["Default price configuration"], "")
			:AddChild(TSM.MainUI.Settings.CreateMultiInputWithReset("mastCostFrame", L["Default material cost method"], private.settings, "defaultMatCostMethod", BAD_MAT_PRICE_SOURCES, SETTING_TOOLTIPS.defaultMatCostMethod))
			:AddChild(TSM.MainUI.Settings.CreateMultiInputWithReset("craftPriceFrame", L["Default craft value method"], private.settings, "defaultCraftPriceMethod", BAD_CRAFT_VALUE_PRICE_SOURCES, SETTING_TOOLTIPS.defaultCraftPriceMethod))
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Crafting", "cooldowns", L["Ignored Cooldowns"], L["Click on a cooldown below to unignore it for display in the Task List UI."])
			:AddChild(UIElements.New("IgnoredCooldownList", "items")
				:SetHeight(106)
				:SetQuery(TSM.Crafting.CreateIgnoredCooldownQuery())
				:SetScript("OnRemoveCooldown", private.RemoveCooldown)
			)
		)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RemoveCooldown(_, characterKey, craftString)
	TSM.Crafting.RemoveIgnoredCooldown(characterKey, craftString)
end
