-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local MainUI = TSM:NewPackage("MainUI") ---@type AddonPackage
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local AppHelper = TSM.LibTSMApp:Include("Service.AppHelper")
local private = {
	settings = nil,
	topLevelPages = {},
	frame = nil,
}
local MIN_FRAME_SIZE = { width = 720, height = 588 }



-- ============================================================================
-- Module Functions
-- ============================================================================

function MainUI.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "mainUIContext", "frame")
		:AddKey("global", "coreOptions", "regionWide")
		:AddKey("global", "appearanceOptions", "showTotalMoney")
		:AddKey("global", "internalData", "warbankMoney")
		:AddKey("sync", "internalData", "money")
end

function MainUI.OnDisable()
	-- hide the frame
	if private.frame then
		MainUI.Toggle()
	end
end

function MainUI.RegisterTopLevelPage(name, callback)
	tinsert(private.topLevelPages, { name = name, callback = callback })
end

function MainUI.Toggle()
	if private.frame then
		-- it's already shown, so hide it
		private.frame:Hide()
		assert(not private.frame)
	else
		private.frame = private.CreateMainFrame()
		private.frame:Draw()
		private.frame:Show()
	end
end



-- ============================================================================
-- Main Frame
-- ============================================================================

function private.CreateMainFrame()
	UIUtils.AnalyticsRecordPathChange("main")
	-- Always show the Dashboard first
	private.settings.frame.page = 1
	local frame = UIElements.New("LargeApplicationFrame", "base")
		:SetParent(UIParent)
		:SetSettingsContext(private.settings, "frame")
		:SetMinResize(MIN_FRAME_SIZE.width, MIN_FRAME_SIZE.height)
		:SetStrata("HIGH")
		:AddPlayerGold(private.settings)
		:AddAppStatusIcon(AppHelper.GetRegion(), AppHelper.GetLastSync(), TSM.AuctionDB.GetAppDataUpdateTimes())
		:AddDiscordIcon("https://discord.gg/sKpJbUrsvR")
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

function private.BaseFrameOnHide(frame)
	if frame ~= private.frame then return end
	frame:Release()
	private.frame = nil
	UIUtils.AnalyticsRecordClose("main")
end
