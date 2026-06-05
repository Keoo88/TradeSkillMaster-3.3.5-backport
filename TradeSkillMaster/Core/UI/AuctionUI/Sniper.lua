-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Sniper = TSM.UI.AuctionUI:NewPackage("Sniper") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local AuctionBuyScan = TSM.LibTSMUI:IncludeClassType("AuctionBuyScan")
local private = {
	manager = nil,
	hasBidSniping = nil,
	settings = nil,
	auctionBuyScan = nil,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("SNIPER_UI_STATE")
	:AddOptionalTableField("frame")
	:AddOptionalTableField("scanFrame")
	:AddBooleanField("selectionFrameShown", false)
	:AddStringField("contentPath", "selection")
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sniper.OnInitialize(settingsDB)
	private.hasBidSniping = not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctionUIContext", "sniperScrollingTable")
		:AddKey("global", "sniperOptions", "sniperSound")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SNIPER", state, private.ActionHandler)

	-- Create the auction buy scan
	private.auctionBuyScan = AuctionBuyScan.NewSniper(L["Sniper"], private.IsPlayer)

	-- Register this page with the Auction UI
	local function GetFrame()
		return private.GetSniperFrame(state)
	end
	local function OnItemLinked(_, itemLink)
		if state.selectionFrameShown then
			return false
		end
		private.manager:ProcessAction("ACTION_BACK_BUTTON_CLICKED")
		TSM.UI.AuctionUI.SetOpenPage(L["Browse"])
		TSM.UI.AuctionUI.Shopping.StartItemSearch(itemLink)
		return true
	end
	TSM.UI.AuctionUI.RegisterTopLevelPage(L["Sniper"], GetFrame, OnItemLinked)
end



-- ============================================================================
-- Sniper UI
-- ============================================================================

---@param state SniperUIState
function private.GetSniperFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "sniper")
	if not private.auctionBuyScan:GetSearchContext() then
		state.contentPath = "selection"
	end
	local frame = UIElements.New("ViewContainer", "sniper")
		:SetContext(state)
		:SetNavCallback(private.GetSniperContentFrame)
		:AddPath("selection")
		:AddPath("buyoutScan")
		:AddPath("bidScan")
		:SetPath(state.contentPath)
		:SetManager(private.manager)
	state.frame = frame
	return frame
end

function private.GetSniperContentFrame(viewContainer, path)
	local state = viewContainer:GetContext() ---@type SniperUIState
	state.contentPath = path
	if path == "selection" then
		return private.GetSelectionFrame(state)
	elseif path == "buyoutScan" then
		return private.GetScanFrame(state, true)
	elseif path == "bidScan" then
		return private.GetScanFrame(state, false)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state SniperUIState
function private.GetSelectionFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "sniper", "selection")
	state.selectionFrameShown = true
	return UIElements.New("Frame", "selection")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AddChildIf(private.hasBidSniping, UIElements.New("Text", "text")
			:SetHeight(20)
			:SetMargin(8, 8, 12, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetJustifyH("CENTER")
			:SetText(L["Start either a 'Buyout' or 'Bid' sniper using the buttons above."])
		)
		:AddChild(UIElements.New("Frame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetHeight(24)
			:SetMargin(8, 8, 12, 12)
			:AddChild(UIElements.New("ActionButton", "buyoutScanBtn")
				:SetMargin(0, private.hasBidSniping and 8 or 0, 0, 0)
				:SetText(L["Run Buyout Sniper"])
				:SetAction("OnClick", "ACTION_START_BUYOUT_SEARCH")
			)
			:AddChildIf(private.hasBidSniping, UIElements.New("ActionButton", "bidScanBtn")
				:SetText(L["Run Bid Sniper"])
				:SetAction("OnClick", "ACTION_START_BID_SEARCH")
			)
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_SELECTION_FRAME_HIDDEN"))
end

---@param state SniperUIState
function private.GetScanFrame(state, isBuyout)
	UIUtils.AnalyticsRecordPathChange("auction", "sniper", "scan")
	local frame = UIElements.New("Frame", "scan")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetHeight(48)
			:SetPadding(8, 8, 14, 14)
			:AddChild(UIElements.New("ActionButton", "backBtn")
				:SetSize(64, 24)
				:SetMargin(0, 16, 0, 0)
				:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey("iconPack.14x14/Chevron/Right"))..BACK)
				:SetAction("OnClick", "ACTION_BACK_BUTTON_CLICKED")
			)
			:AddChild(UIElements.New("Text", "title")
				:SetFont("BODY_BODY2_MEDIUM")
				:SetJustifyH("CENTER")
				:SetText(isBuyout and L["Buyout Sniper"] or L["Bid Sniper"])
			)
			:AddChild(UIElements.New("ActionButton", "restartBtn")
				:SetSize(80, 24)
				:SetText(L["Restart"])
				:SetAction("OnClick", "ACTION_RESTART_SEARCH")
			)
		)
		:AddChild(UIElements.New("SniperScrollTable", "auctions")
			:SetSettings(private.settings, "sniperScrollingTable")
			:SetCreatedGroupName(L["Sniper"].." - "..L["Scan Results"])
			:SetIsPlayerFunction(PlayerInfo.AuctionOwnerIsPlayer)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(private.auctionBuyScan:CreateBottomUIFrameForSniper(isBuyout))
		:SetScript("OnUpdate", private.ScanFrameOnUpdate)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_SCAN_FRAME_HIDDEN"))
	state.scanFrame = frame
	return frame
end

function private.ScanFrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.auctionBuyScan:SetAuctionScrollTable(frame:GetElement("auctions"))
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state SniperUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SELECTION_FRAME_HIDDEN" then
		state.selectionFrameShown = false
	elseif action == "ACTION_START_BUYOUT_SEARCH" then
		manager:ProcessAction("ACTION_START_SEARCH", "buyoutScan", TSM.Sniper.BuyoutSearch.GetSearchContext())
	elseif action == "ACTION_START_BID_SEARCH" then
		manager:ProcessAction("ACTION_START_SEARCH", "bidScan", TSM.Sniper.BidSearch.GetSearchContext())
	elseif action == "ACTION_START_SEARCH" then
		local contentPath, searchContext = ...
		state.frame:SetPath("selection", true)
		if not private.auctionBuyScan:PrepareStartSearch() then
			return
		end
		state.frame:SetPath(contentPath, true)
		private.auctionBuyScan:StartSearch(searchContext)
	elseif action == "ACTION_SCAN_FRAME_HIDDEN" then
		state.scanFrame = nil
		private.auctionBuyScan:SetAuctionScrollTable(nil)
	elseif action == "ACTION_RESTART_SEARCH" then
		local searchContext = private.auctionBuyScan:GetSearchContext()
		private.auctionBuyScan:EndSearch()
		manager:ProcessAction("ACTION_START_SEARCH", state.contentPath, searchContext)
	elseif action == "ACTION_BACK_BUTTON_CLICKED" then
		state.frame:SetPath("selection", true)
		private.auctionBuyScan:EndSearch()
	else
		error("Unknown action: "..tostring(action))
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.IsPlayer(character, includeAlts)
	if includeAlts then
		return PlayerInfo.IsPlayer(character, true, true, true)
	else
		return PlayerInfo.IsPlayer(character)
	end
end
