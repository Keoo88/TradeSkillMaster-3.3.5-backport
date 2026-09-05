-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = _G.TSMAddon ---@type TSM
local CraftingUI = TSM.UI:NewPackage("CraftingUI") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Spell = TSM.LibTSMWoW:Include("API.Spell")
local L = TSM.Locale.GetTable()
local FSM = TSM.LibTSMUtil:Include("FSM")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ScriptWrapper = TSM.LibTSMWoW:Include("API.ScriptWrapper")
local TradeSkill = TSM.LibTSMWoW:Include("API.TradeSkill")
local Profession = TSM.LibTSMService:Include("Profession")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local AppHelper = TSM.LibTSMApp:Include("Service.AppHelper")
local private = {
	settings = nil,
	topLevelPages = {},
	fsm = nil,
	craftOpen = nil,
	tradeSkillOpen = nil,
	defaultUISwitchBtn = nil,
	isVisible = false,
	apiCallbacks = {},
}
local MIN_FRAME_SIZE = { width = 650, height = 587 }
local BEAST_TRAINING_DE = "Bestienausbildung"
local BEAST_TRAINING_ES = "Entrenamiento de bestias"
local BEAST_TRAINING_RUS = "Воспитание питомца"
local IGNORED_PROFESSIONS = {
	[2787] = true, -- Abominable Stitching
	[7620] = true, -- Fishing Skills (shows up as Fishing)
	[53428] = true, -- Runeforging
	[158756] = true, -- Skinning Skills
	[193290] = true, -- Herbalism Skills
	[278910] = true, -- Archaeology
}
do
	if not C_AddOns.IsAddOnLoaded("Blizzard_Professions") then
		C_AddOns.LoadAddOn("Blizzard_Professions")
	end
	if ClientInfo.IsRetail() and not C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsBook") then
		C_AddOns.LoadAddOn("Blizzard_ProfessionsBook")
	end
end



-- ============================================================================
-- Module Functions
-- ============================================================================

function CraftingUI.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "craftingUIContext", "showDefault")
		:AddKey("global", "craftingUIContext", "frame")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("sync", "internalData", "money")
	private.FSMCreate()
	Profession.SetScannerDisabled(private.settings.showDefault)
end

function CraftingUI.OnDisable()
	-- hide the frame
	if private.isVisible then
		Profession.SetScannerDisabled(false)
		private.fsm:ProcessEvent("EV_FRAME_TOGGLE")
	end
end

function CraftingUI.RegisterTopLevelPage(name, callback)
	tinsert(private.topLevelPages, { name = name, callback = callback })
end

function CraftingUI.Toggle()
	private.settings.showDefault = false
	Profession.SetScannerDisabled(false)
	private.fsm:ProcessEvent("EV_FRAME_TOGGLE")
end

function CraftingUI.IsProfessionIgnored(name, skillId)
	if not ClientInfo.IsRetail() then
		if name == Spell.GetInfo(5149) or name == BEAST_TRAINING_DE or name == BEAST_TRAINING_ES or name == BEAST_TRAINING_RUS then -- Beast Training
			return true
		elseif name == Spell.GetInfo(7620) then -- Fishing
			return true
		elseif name == Spell.GetInfo(2366) then -- Herb Gathering
			return true
		elseif name == Spell.GetInfo(8613) then -- Skinning
			return true
		end
	end
	for i in pairs(IGNORED_PROFESSIONS) do
		local ignoredName = Spell.GetInfo(i)
		if ignoredName == name or IGNORED_PROFESSIONS[skillId] then
			return true
		end
	end
end

function CraftingUI.IsVisible()
	return private.isVisible
end

function CraftingUI.RegisterApiCallback(addonTag, func)
	if private.apiCallbacks[addonTag] then
		error("Callback already registered for addonTag: "..tostring(addonTag), 3)
	end
	private.apiCallbacks[addonTag] = func
end



-- ============================================================================
-- Main Frame
-- ============================================================================

function private.CreateMainFrame()
	UIUtils.AnalyticsRecordPathChange("crafting")
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:SetParent(UIParent)
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetStrata("HIGH")
		:AddPlayerGold(private.settings)
		:AddAppStatusIcon(AppHelper.GetRegion(), AppHelper.GetLastSync(), TSM.AuctionDB.GetAppDataUpdateTimes())
		:AddSwitchButton(private.SwitchBtnOnClick)
		:SetScript("OnHide", private.BaseFrameOnHide)

	frame:GetElement("content")
		:SetPadding(0)
		:SetBorderColor(nil)

	for _, info in ipairs(private.topLevelPages) do
		frame:AddNavButton(info.name, info.callback)
	end

	return frame
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.BaseFrameOnHide()
	UIUtils.AnalyticsRecordClose("crafting")
	private.fsm:ProcessEvent("EV_FRAME_HIDE")
end

function private.SwitchBtnOnClick(button)
	private.settings.showDefault = button ~= private.defaultUISwitchBtn
	if not private.settings.showDefault then
		TradeSkill.SetDefaultFilters()
	end
	Profession.SetScannerDisabled(private.settings.showDefault)
	private.fsm:ProcessEvent("EV_SWITCH_BTN_CLICKED")
end

function private.SwitchButtonOnEnter(button)
	button:SetTextColor("TEXT")
		:Draw()
end

function private.SwitchButtonOnLeave(button)
	button:SetTextColor("TEXT_ALT")
		:Draw()
end



-- ============================================================================
-- FSM
-- ============================================================================

function private.FSMCreate()
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) then
		Event.Register("CRAFT_SHOW", function()
			CloseTradeSkill()
			private.craftOpen = true
			Profession.SetClassicCraftingOpen(true)
			private.fsm:ProcessEvent("EV_TRADE_SKILL_SHOW")
		end)
		Event.Register("CRAFT_CLOSE", function()
			private.craftOpen = false
			Profession.SetClassicCraftingOpen(false)
			if not private.tradeSkillOpen then
				private.fsm:ProcessEvent("EV_TRADE_SKILL_CLOSED")
			end
		end)
	end
	Event.Register("TRADE_SKILL_SHOW", function()
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) then
			if CloseCraft then CloseCraft() end
		end
		private.tradeSkillOpen = true
		private.fsm:ProcessEvent("EV_TRADE_SKILL_SHOW")
	end)
	Event.Register("TRADE_SKILL_CLOSE", function()
		private.tradeSkillOpen = false
		if not private.craftOpen then
			private.fsm:ProcessEvent("EV_TRADE_SKILL_CLOSED")
		end
	end)
	-- we'll implement UIParent's event handler directly when necessary for TRADE_SKILL_SHOW
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) then
		UIParent:UnregisterEvent("CRAFT_SHOW")
	end
	UIParent:UnregisterEvent("TRADE_SKILL_SHOW")

	local fsmContext = {
		frame = nil,
	}
	local function UpdateDefaultCraftButton()
		if CraftFrame and CraftCreateButton and private.craftOpen then
			CraftCreateButton:SetParent(CraftFrame)
			CraftCreateButton:ClearAllPoints()
			CraftCreateButton:SetPoint("CENTER", CraftFrame, "TOPLEFT", 224, -422)
			CraftCreateButton:SetFrameLevel(2)
			CraftCreateButton:EnableDrawLayer("BACKGROUND")
			CraftCreateButton:EnableDrawLayer("ARTWORK")
		end
	end
	local function DefaultFrameOnHide()
		private.fsm:ProcessEvent("EV_FRAME_HIDE")
	end
	private.fsm = FSM.New("CRAFTING_UI")
		:AddState(FSM.NewState("ST_CLOSED")
			:AddTransition("ST_DEFAULT_OPEN")
			:AddTransition("ST_FRAME_OPEN")
			:AddEvent("EV_FRAME_TOGGLE", function(context)
				assert(not private.settings.showDefault)
				Profession.SetScannerDisabled(false)
				return "ST_FRAME_OPEN"
			end)
			:AddEvent("EV_TRADE_SKILL_SHOW", function(context)
				Profession.SetScannerDisabled(private.settings.showDefault)
				local profName = TradeSkill.GetName()
				if not profName or CraftingUI.IsProfessionIgnored(profName) then
					return "ST_DEFAULT_OPEN", true
				elseif private.settings.showDefault then
					return "ST_DEFAULT_OPEN"
				else
					return "ST_FRAME_OPEN"
				end
			end)
		)
		:AddState(FSM.NewState("ST_DEFAULT_OPEN")
			:SetOnEnter(function(context, isIgnored)
				if private.craftOpen then
					UIParent_OnEvent(UIParent, "CRAFT_SHOW")
					UpdateDefaultCraftButton()
				else
					UIParent_OnEvent(UIParent, "TRADE_SKILL_SHOW")
				end
				local defaultFrame = ClientInfo.IsRetail() and ProfessionsFrame or TradeSkillFrame
				if not private.defaultUISwitchBtn then
					private.defaultUISwitchBtn = UIElements.New("ActionButton", "switchBtn")
						:SetSize(60, ClientInfo.IsRetail() and 15 or 16)
						:SetFont("BODY_BODY3_MEDIUM")
						:AddAnchor("TOPRIGHT", ClientInfo.IsRetail() and -50 or -60, ClientInfo.IsRetail() and -4 or -16)
						:SetRelativeLevel(ClientInfo.IsRetail() and 600 or 3)
						:DisableClickCooldown()
						:SetText(L["TSM4"])
						:SetScript("OnClick", private.SwitchBtnOnClick)
						:SetScript("OnEnter", private.SwitchButtonOnEnter)
						:SetScript("OnLeave", private.SwitchButtonOnLeave)
					private.defaultUISwitchBtn:_GetBaseFrame():SetParent(defaultFrame)
				end
				private.defaultUISwitchBtn:_GetBaseFrame():SetParent(private.craftOpen and CraftFrame or defaultFrame)
				if isIgnored then
					Profession.SetScannerDisabled(true)
					private.defaultUISwitchBtn:Hide()
				else
					private.defaultUISwitchBtn:Show()
					private.defaultUISwitchBtn:Draw()
				end
				if private.craftOpen then
					ScriptWrapper.Set(CraftFrame, "OnHide", DefaultFrameOnHide)
				else
					ScriptWrapper.Set(defaultFrame, "OnHide", DefaultFrameOnHide)
				end
			end)
			:SetOnExit(function(context)
				local defaultFrame = ClientInfo.IsRetail() and ProfessionsFrame or TradeSkillFrame
				if private.craftOpen then
					if CraftFrame then
						ScriptWrapper.Clear(CraftFrame, "OnHide")
						HideUIPanel(CraftFrame)
					end
				else
					if defaultFrame then
						ScriptWrapper.Clear(defaultFrame, "OnHide")
						HideUIPanel(defaultFrame)
					end
				end
			end)
			:AddTransition("ST_CLOSED")
			:AddTransition("ST_FRAME_OPEN")
			:AddTransition("ST_DEFAULT_OPEN")
			:AddEvent("EV_FRAME_HIDE", function(context)
				TradeSkill.CloseUI(false)
				return "ST_CLOSED"
			end)
			:AddEvent("EV_TRADE_SKILL_SHOW", function(context)
				local profName = TradeSkill.GetName()
				if not profName or CraftingUI.IsProfessionIgnored(profName) then
					return "ST_DEFAULT_OPEN", true
				else
					if private.settings.showDefault then
						return "ST_DEFAULT_OPEN"
					else
						Profession.SetScannerDisabled(private.settings.showDefault)
						return "ST_FRAME_OPEN"
					end
				end
			end)
			:AddEventTransition("EV_TRADE_SKILL_CLOSED", "ST_CLOSED")
			:AddEventTransition("EV_SWITCH_BTN_CLICKED", "ST_FRAME_OPEN")
		)
		:AddState(FSM.NewState("ST_FRAME_OPEN")
			:SetOnEnter(function(context)
				assert(not context.frame)
				context.frame = private.CreateMainFrame()
				context.frame:Show()
				if TradeSkill.GetName() then
					context.frame:GetElement("titleFrame.switchBtn"):Show()
				else
					context.frame:GetElement("titleFrame.switchBtn"):Hide()
				end
				context.frame:Draw()
				private.isVisible = true
				for addonTag, func in pairs(private.apiCallbacks) do
					local apiFuncStartTime = GetTimePreciseSec()
					func(true, context.frame:_GetBaseFrame())
					Log.Info("API function (%s) took %0.5fs", addonTag, GetTimePreciseSec() - apiFuncStartTime)
				end
			end)
			:SetOnExit(function(context)
				context.frame:Hide()
				context.frame:Release()
				context.frame = nil
				private.isVisible = false
				if not ClientInfo.IsRetail() then
					UpdateDefaultCraftButton()
				end
				for addonTag, func in pairs(private.apiCallbacks) do
					local apiFuncStartTime = GetTimePreciseSec()
					func(false)
					Log.Info("API function (%s) took %0.5fs", addonTag, GetTimePreciseSec() - apiFuncStartTime)
				end
			end)
			:AddTransition("ST_CLOSED")
			:AddTransition("ST_DEFAULT_OPEN")
			:AddEvent("EV_FRAME_HIDE", function(context)
				TradeSkill.CloseUI(true)
				return "ST_CLOSED"
			end)
			:AddEvent("EV_TRADE_SKILL_SHOW", function(context)
				local profName = TradeSkill.GetName()
				if not profName or CraftingUI.IsProfessionIgnored(profName) then
					return "ST_DEFAULT_OPEN", true
				end
				context.frame:GetElement("titleFrame.switchBtn"):Show()
				context.frame:GetElement("titleFrame"):Draw()
			end)
			:AddEventTransition("EV_TRADE_SKILL_CLOSED", "ST_CLOSED")
			:AddEventTransition("EV_SWITCH_BTN_CLICKED", "ST_DEFAULT_OPEN")
			:AddEventTransition("EV_FRAME_TOGGLE", "ST_CLOSED")
		)
		:Init("ST_CLOSED", fsmContext)
end
