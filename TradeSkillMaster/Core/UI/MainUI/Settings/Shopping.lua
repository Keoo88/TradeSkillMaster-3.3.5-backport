-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Shopping = TSM.MainUI.Settings:NewPackage("Shopping") ---@type AddonPackage
local L = TSM.Locale.GetTable()
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Item = TSM.LibTSMWoW:Include("API.Item")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local private = {
	manager = nil, ---@type UIManager
	settings = nil,
}
local SETTING_TOOLTIPS = {
	searchAutoFocus = L["When enabled, the search input in the Browse tab of the AH will automatically be focused to allow for quickly searching the AH."],
	buyoutConfirm = L["If enabled, TSM will display an additional confirmation when attempting to buy an auction above the value set in the 'Buyout alert source' setting. This can help avoid accidental purchases of expensive auctions."],
	deSearchLevelRange = L["The item level range to show in the Disenchant search results."],
	maxDeSearchPercent = L["When running a Disenchant search, only auctions which are listed for below this percentage of their disenchant value will be displayed in the search results."],
	pctSource = L["This custom string defines how TSM determines the market value of items for calculating the '%' column in the search results. This value is only used when running a manual search in the Browse tab of the AH."],
	buyoutAlertSource = L["TSM will display an additional confirmation when attempting to buy an auction above this value. This can help avoid accidental purchases of expensive auctions."],
	sniperSound = L["The sound to play when an auction is found by the Sniper scan."],
}
local STATE_SCHEMA = Reactive.CreateStateSchema("SHOPPING_SETTINGS_UI_STATE")
	:AddOptionalTableField("frame")
	:AddBooleanField("buyoutConfirmationAlertEnabled", false)
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Shopping.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "shoppingOptions", "searchAutoFocus")
		:AddKey("global", "shoppingOptions", "buyoutConfirm")
		:AddKey("global", "shoppingOptions", "minDeSearchLvl")
		:AddKey("global", "shoppingOptions", "maxDeSearchLvl")
		:AddKey("global", "shoppingOptions", "maxDeSearchPercent")
		:AddKey("global", "shoppingOptions", "pctSource")
		:AddKey("global", "shoppingOptions", "buyoutAlertSource")
		:AddKey("global", "sniperOptions", "sniperSound")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MY_AUCTIONS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_UPDATE_DE_LEVEL_RANGE")

	-- Register this settings page
	TSM.MainUI.Settings.RegisterSettingPage(L["Browse / Sniper"], "middle", function()
		return private.GetShoppingSettingsFrame(state)
	end)

	-- Set up a publisher to mirror buyoutConfirmationAlertEnabled to the settings value
	state.buyoutConfirmationAlertEnabled = private.settings.buyoutConfirm
	private.manager:AddCancellable(state:PublisherForKeyChange("buyoutConfirmationAlertEnabled")
		:AssignToTableKey(private.settings, "buyoutConfirm")
	)
end



-- ============================================================================
-- Shopping Settings UI
-- ============================================================================

---@param state ShoppingSettingsUIState
function private.GetShoppingSettingsFrame(state)
	state.buyoutConfirmationAlertEnabled = private.settings.buyoutConfirm
	UIUtils.AnalyticsRecordPathChange("main", "settings", "shopping")
	local frame = UIElements.New("ScrollFrame", "shoppingSettings")
		:SetPadding(8, 8, 8, 0)
		:SetManager(private.manager)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Shopping", "general", L["General Options"], L["Some general Browse/Sniper options are below."])
			:AddChild(UIElements.New("Frame", "focusFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Auto-focus browse search input"])
					:SetSettingInfo(private.settings, "searchAutoFocus")
					:SetTooltip(SETTING_TOOLTIPS.searchAutoFocus)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("marketValueSourceField", L["Market value price source"], private.settings, "pctSource", nil, nil, SETTING_TOOLTIPS.pctSource)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(UIElements.New("Frame", "showConfirmFrame")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Checkbox", "checkbox")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetText(L["Show confirmation alert if buyout is above the alert price"])
					:SetSettingInfo(state, "buyoutConfirmationAlertEnabled")
					:SetTooltip(SETTING_TOOLTIPS.buyoutConfirm)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(TSM.MainUI.Settings.CreateInputWithReset("buyoutConfirmationAlert", L["Buyout confirmation alert"], private.settings, "buyoutAlertSource", nil, not private.settings.buyoutConfirm)
				:SetMargin(0, 0, 0, 12)
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Shopping", "disenchant", L["Disenchant Search Options"], L["Some options for the Disenchant Search are below."])
			:AddChild(UIElements.New("Text", "minLevelLabel")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Disenchant level range"])
			)
			:AddChild(UIElements.New("RangeInput", "levelRange")
				:SetHeight(24)
				:SetRange("0,"..Item.GetMaxItemLevel())
				:SetValue(private.settings.minDeSearchLvl..","..private.settings.maxDeSearchLvl)
				:SetAction("OnValueChanged", "ACTION_UPDATE_DE_LEVEL_RANGE")
				:SetTooltip(SETTING_TOOLTIPS.deSearchLevelRange)
			)
			:AddChild(UIElements.New("Text", "pctLabel")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Maximum disenchant search percent"])
			)
			:AddChild(UIElements.New("Frame", "pctInput")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("Input", "input")
					:SetMargin(0, 8, 0, 0)
					:SetBackgroundColor("ACTIVE_BG")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetValidateFunc("NUMBER", "0:100")
					:SetSettingInfo(private.settings, "maxDeSearchPercent")
					:SetTooltip(SETTING_TOOLTIPS.maxDeSearchPercent, "__parent")
				)
				:AddChild(UIElements.New("Text", "rangeText")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY3")
					:SetText(format(L["(minimum 0 - maximum %d)"], 100))
				)
			)
		)
		:AddChild(TSM.MainUI.Settings.CreateExpandableSection("Shopping", "sniper", L["Sniper Options"], L["Options specific to Sniper are below."])
			:AddChild(UIElements.New("Text", "soundLabel")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 4)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(L["Found auction sound"])
			)
			:AddChild(UIElements.New("SoundDropdown", "sniperSoundDropdown")
				:SetHeight(24)
				:SetSettingInfo(private.settings, "sniperSound")
				:SetTooltip(SETTING_TOOLTIPS.sniperSound)
			)
		)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_HANDLE_FRAME_HIDDEN"))

	-- Set up some publishers for the buyout alert settings
	local alertFrame = frame:GetElement("general.content.buyoutConfirmationAlert")
	alertFrame:GetElement("label")
		:SetTextColorPublisher(state:PublisherForKeyChange("buyoutConfirmationAlertEnabled")
			:MapBooleanWithValues("TEXT_ALT", "TEXT_DISABLED")
		)
	alertFrame:GetElement("content.input")
		:SetDisabledPublisher(state:PublisherForKeyChange("buyoutConfirmationAlertEnabled"):InvertBoolean())
	alertFrame:GetElement("content.resetButton")
		:SetDisabledPublisher(state:PublisherForKeyChange("buyoutConfirmationAlertEnabled"):InvertBoolean())

	private.manager:ProcessAction("ACTION_HANDLE_FRAME_SHOWN", frame)
	return frame
end




-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state ShoppingSettingsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_HANDLE_FRAME_SHOWN" then
		local frame = ...
		state.frame = frame
	elseif action == "ACTION_HANDLE_FRAME_HIDDEN" then
		state.frame = nil
	elseif action == "ACTION_UPDATE_DE_LEVEL_RANGE" then
		local minLevel, maxLevel = strsplit(",", state.frame:GetElement("disenchant.content.levelRange"):GetValue())
		minLevel = tonumber(minLevel)
		maxLevel = tonumber(maxLevel)
		assert(minLevel and maxLevel)
		private.settings.minDeSearchLvl = minLevel
		private.settings.maxDeSearchLvl = maxLevel
	else
		error("Unknown action: "..tostring(action))
	end
end
