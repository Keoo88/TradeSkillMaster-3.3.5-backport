-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local AuctionUI = TSM.UI:NewPackage("AuctionUI") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local DelayTimer = TSM.LibTSMWoW:IncludeClassType("DelayTimer")
local ScriptWrapper = TSM.LibTSMWoW:Include("API.ScriptWrapper")
local AuctionScan = TSM.LibTSMService:Include("AuctionScan")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local ItemLinked = TSM.LibTSMUI:Include("Util.ItemLinked")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local AppHelper = TSM.LibTSMApp:Include("Service.AppHelper")
local LibAHTab = LibStub("LibAHTab-1-0")
local private = {
	settings = nil,
	topLevelPages = {},
	frame = nil,
	hasShown = false,
	isSwitching = false,
	scanningPage = nil,
	updateCallbacks = {},
	defaultFrame = nil,
}
local MIN_FRAME_SIZE = { width = 750, height = 450 }
local AH_TAB_ID = "TSM_AH_TAB"



-- ============================================================================
-- Module Functions
-- ============================================================================

function AuctionUI.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctionUIContext", "showDefault")
		:AddKey("global", "auctionUIContext", "frame")
		:AddKey("global", "coreOptions", "protectAuctionHouse")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("sync", "internalData", "money")
	UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW")
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
		UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW_NOTIFICATION")
		UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION")
		UIParent:UnregisterEvent("AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION")
	end
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.AuctionFrameInit, true)
	DefaultUI.RegisterAuctionHouseVisibleCallback(private.AuctionFrameHidden, false)
	AuctionScan.ConfigureLock(L["A scan is already in progress. Please stop that scan before starting another one."], private.ScanLockCallback)
	ItemLinked.RegisterCallback(private.ItemLinkedCallback, true)
	local loadTimer = DelayTimer.New("AUCTION_UI_LOAD_BLIZZ", function() C_AddOns.LoadAddOn((ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and "Blizzard_AuctionUI" or "Blizzard_AuctionHouseUI") end)
	loadTimer:RunForTime(1)
end

function AuctionUI.OnDisable()
	if private.frame then
		private.frame:Hide()
		if private.frame then
			private.BaseFrameOnHide(private.frame)
		end
	end
end

function AuctionUI.RegisterTopLevelPage(name, callback, itemLinkedHandler)
	tinsert(private.topLevelPages, { name = name, callback = callback, itemLinkedHandler = itemLinkedHandler })
end

function AuctionUI.SetOpenPage(name)
	private.frame:SetSelectedNavButton(name, true)
end

function AuctionUI.IsPageOpen(name)
	if not private.frame then
		return false
	end
	return private.frame:GetSelectedNavButton() == name
end

function AuctionUI.IsScanning()
	return private.scanningPage and true or false
end

function AuctionUI.RegisterUpdateCallback(callback)
	tinsert(private.updateCallbacks, callback)
end

function AuctionUI.IsVisible()
	return private.frame and true or false
end



-- ============================================================================
-- Main Frame
-- ============================================================================

local function NoOp()
	-- do nothing - what did you expect?
end

function private.AuctionFrameInit()
	if GameLimitedMode_IsActive() then
		return
	end
	local tabTemplateName = nil
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		private.defaultFrame = AuctionFrame
		tabTemplateName = "AuctionTabTemplate"
	else
		private.defaultFrame = AuctionHouseFrame
		tabTemplateName = "AuctionHouseFrameTabTemplate"
	end
	if not private.hasShown then
		private.hasShown = true
		if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
			local tabId = private.defaultFrame.numTabs + 1
			local tab = CreateFrame("Button", "AuctionFrameTab"..tabId, private.defaultFrame, tabTemplateName)
			tab:Hide()
			tab:SetID(tabId)
			tab:SetText(Theme.GetColor("INDICATOR_ALT"):ColorText("TSM"))
			tab:SetNormalFontObject(GameFontHighlightSmall)
			tab:SetPoint("LEFT", _G["AuctionFrameTab"..tabId - 1], "RIGHT", -8, 0)
			tab:Show()
			PanelTemplates_SetNumTabs(private.defaultFrame, tabId)
			PanelTemplates_EnableTab(private.defaultFrame, tabId)
			ScriptWrapper.Set(tab, "OnClick", private.TSMTabOnClick)
		else
			LibAHTab:CreateTab(AH_TAB_ID, CreateFrame("Frame"), Theme.GetColor("INDICATOR_ALT"):ColorText("TSM"))
			ScriptWrapper.Set(LibAHTab:GetButton(AH_TAB_ID), "OnClick", private.TSMTabOnClick)
			AuctionHouseFrame:HookScript("OnShow", private.UnregisterDefaultUIEvents)
			if private.defaultFrame:IsVisible() then
				private.UnregisterDefaultUIEvents()
			end
		end
	end
	if private.settings.showDefault then
		if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
			UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
		end
	else
		if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
			private.defaultFrame:SetScale(0.001)
			LibAHTab:SetSelected(AH_TAB_ID)
		end
		PlaySound(SOUNDKIT.AUCTION_WINDOW_OPEN)
		private.ShowAuctionFrame()
	end
end

function private.UnregisterDefaultUIEvents()
	private.defaultFrame:UnregisterEvent("AUCTION_HOUSE_AUCTION_CREATED")
	private.defaultFrame:UnregisterEvent("AUCTION_HOUSE_SHOW_NOTIFICATION")
	private.defaultFrame:UnregisterEvent("AUCTION_HOUSE_SHOW_FORMATTED_NOTIFICATION")
	private.defaultFrame:UnregisterEvent("AUCTION_HOUSE_SHOW_COMMODITY_WON_NOTIFICATION")
end

function private.ShowAuctionFrame()
	if private.frame then
		return
	end
	private.frame = private.CreateMainFrame()
	private.frame:Show()
	private.frame:Draw()
	for _, callback in ipairs(private.updateCallbacks) do
		callback()
	end
end

function private.AuctionFrameHidden()
	if not private.frame then
		return
	end
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
		private.defaultFrame:SetScale(1)
		private.defaultFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
	end
	private.HideAuctionFrame()
end

function private.HideAuctionFrame()
	if not private.frame then
		return
	end
	private.frame:Hide()
	-- On 3.3.5 OnHide is not called synchronously, so call it manually if needed
	if private.frame then
		private.BaseFrameOnHide(private.frame)
	end
	for _, callback in ipairs(private.updateCallbacks) do
		callback()
	end
end

function private.CreateMainFrame()
	UIUtils.AnalyticsRecordPathChange("auction")
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:SetParent(UIParent)
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetStrata("HIGH")
		:SetProtected((ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and private.settings.protectAuctionHouse)
		:AddPlayerGold(private.settings)
		:AddAppStatusIcon(AppHelper.GetRegion(), AppHelper.GetLastSync(), TSM.AuctionDB.GetAppDataUpdateTimes())
		:AddSwitchButton(private.SwitchBtnOnClick)
		:SetScript("OnHide", private.BaseFrameOnHide)
	for _, info in ipairs(private.topLevelPages) do
		frame:AddNavButton(info.name, info.callback)
	end
	local whatsNewDialog = TSM.UI.WhatsNew.GetDialog()
	if whatsNewDialog then
		frame:ShowDialogFrame(whatsNewDialog)
	end
	return frame
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.ScanLockCallback(name)
	private.scanningPage = name
	if private.frame then
		private.frame:SetPulsingNavButton(name)
	end
	for _, callback in ipairs(private.updateCallbacks) do
		callback()
	end
end

function private.BaseFrameOnHide(frame)
	if frame ~= private.frame then return end
	frame:Release()
	private.frame = nil
	if not private.isSwitching then
		PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE)
		if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
			CloseAuctionHouse()
		else
			private.defaultFrame:SetScale(1)
			C_AuctionHouse.CloseAuctionHouse()
		end
	end
	UIUtils.AnalyticsRecordClose("auction")
end

function private.SwitchBtnOnClick(button)
	private.isSwitching = true
	private.settings.showDefault = true
	private.HideAuctionFrame()
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
		private.defaultFrame:SetScale(1)
		private.defaultFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
	end
	UIParent_OnEvent(UIParent, "AUCTION_HOUSE_SHOW")
	private.isSwitching = false
end

function private.TSMTabOnClick()
	private.settings.showDefault = false
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		ClearCursor()
		ClickAuctionSellItemButton(AuctionsItemButton, "LeftButton")
	end
	ClearCursor()
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		-- Replace CloseAuctionHouse() with a no-op while hiding the AH frame so we don't stop interacting with the AH NPC
		local origCloseAuctionHouse = CloseAuctionHouse
		CloseAuctionHouse = NoOp
		AuctionFrame_Hide()
		CloseAuctionHouse = origCloseAuctionHouse
	else
		private.defaultFrame:SetScale(0.001)
		LibAHTab:SetSelected(AH_TAB_ID)
	end
	private.ShowAuctionFrame()
end

function private.ItemLinkedCallback(name, itemLink)
	if not private.frame then
		return
	end
	local path = private.frame:GetSelectedNavButton()
	for _, info in ipairs(private.topLevelPages) do
		if info.name == path then
			if info.itemLinkedHandler(name, itemLink) then
				return true
			else
				return
			end
		end
	end
	error("Invalid frame path")
end
