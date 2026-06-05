-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local MyAuctions = TSM.UI.AuctionUI:NewPackage("MyAuctions") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local Money = TSM.LibTSMUtil:Include("UI.Money")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Hash = TSM.LibTSMUtil:Include("Util.Hash")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Theme = TSM.LibTSMService:Include("UI.Theme")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local private = {
	manager = nil, ---@type UIManager
	settings = nil,
	filters = {
		duration = nil,
		keyword = nil,
		groups = {},
		bid = nil,
		sold = false,
	}
}
local DURATION_LIST = {
	L["None"],
	AUCTION_TIME_LEFT1_DETAIL,
	AUCTION_TIME_LEFT2_DETAIL,
	AUCTION_TIME_LEFT3_DETAIL,
	AUCTION_TIME_LEFT4_DETAIL,
}
local STATE_SCHEMA = Reactive.CreateStateSchema("MY_AUCTIONS_UI_STATE")
	:AddOptionalTableField("frame")
	:AddOptionalTableField("query")
	:AddOptionalTableField("queryCancellable")
	:AddBooleanField("hasFilter", false)
	:AddOptionalNumberField("selectedAuctionId")
	:AddBooleanField("canCancel", false)
	:AddNumberField("numPosted", 0)
	:AddNumberField("numSold", 0)
	:AddNumberField("postedGold", 0)
	:AddNumberField("soldGold", 0)
	:AddNumberField("numPending", 0)
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function MyAuctions.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctionUIContext", "myAuctionsScrollingTable")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("MY_AUCTIONS", state, private.ActionHandler)
		:SuppressActionLog("ACTION_DATA_UPDATED")
		:SuppressActionLog("ACTION_FILTER_UPDATED")

	-- Register this page with the Auction UI
	local function GetFrame()
		return private.GetMyAuctionsFrame(state)
	end
	local function OnItemLinked(name)
		private.manager:ProcessAction("ACTION_ITEM_LINKED", name)
		return true
	end
	TSM.UI.AuctionUI.RegisterTopLevelPage(L["My Auctions"], GetFrame, OnItemLinked)

	-- Set up some computed state properties
	if ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		private.manager:SetStateFromPublisher("canCancel", state:PublisherForKeyChange("selectedAuctionId")
			:MapBooleanNotEquals(nil)
		)
	else
		private.manager:SetStateFromPublisher("canCancel", state:PublisherForExpression([[numPending == 0 and selectedAuctionId or nil]])
			:MapNonNilWithFunction(C_AuctionHouse.GetCancelCost)
			:MapWithFunction(function(cancelCost) return (cancelCost or math.huge) <= GetMoney() end)
		)
	end
end



-- ============================================================================
-- MyAuctions UI
-- ============================================================================

---@param state MyAuctionsUIState
function private.GetMyAuctionsFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "my_auctions")
	return UIElements.New("Frame", "myAuctions")
		:SetLayout("VERTICAL")
		:SetManager(private.manager)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("VERTICAL")
			:SetHeight(72)
			:SetPadding(8)
			:AddChild(UIElements.New("Frame", "filters")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("ListDropdown", "duration")
					:SetWidth(232)
					:SetItems(DURATION_LIST)
					:SetHintText(L["Filter by duration"])
					:SetAction("OnSelectionChanged", "ACTION_FILTER_UPDATED")
				)
				:AddChild(UIElements.New("GroupSelector", "group")
					:SetWidth(232)
					:SetMargin(8, 8, 0, 0)
					:SetHintText(L["Filter by groups"])
					:SetAction("OnSelectionChanged", "ACTION_FILTER_UPDATED")
				)
				:AddChild(UIElements.New("Input", "keyword")
					:SetIconTexture("iconPack.18x18/Search")
					:AllowItemInsert(false)
					:SetClearButtonEnabled(true)
					:SetHintText(L["Filter by keyword"])
					:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
				)
			)
			:AddChild(UIElements.New("Frame", "buttons")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("Checkbox", "ignoreBid")
					:SetWidth("AUTO")
					:SetText(L["Hide auctions with bids"])
					:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
				)
				:AddChild(UIElements.New("Checkbox", "onlyBid")
					:SetMargin(16, 0, 0, 0)
					:SetWidth("AUTO")
					:SetText(L["Show only auctions with bids"])
					:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
				)
				:AddChild(UIElements.New("Checkbox", "onlySold")
					:SetMargin(16, 0, 0, 0)
					:SetWidth("AUTO")
					:SetText(L["Only show sold auctions"])
					:SetAction("OnValueChanged", "ACTION_FILTER_UPDATED")
				)
				:AddChild(UIElements.New("Spacer"))
				:AddChild(UIElements.New("ActionButton", "clearfilter")
					:SetSize(142, 24)
					:SetText(L["Clear Filters"])
					:SetDisabledPublisher(state:PublisherForKeyChange("hasFilter"):InvertBoolean())
					:SetAction("OnClick", "ACTION_CLEAR_FILTERS")
				)
			)
		)
		:AddChild(UIElements.New("MyAuctionsScrollTable", "auctions")
			:SetSortingDisabled(ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic())
			:SetSettings(private.settings, "myAuctionsScrollingTable")
			:SetQuery(TSM.MyAuctions.CreateQuery())
			:SetAction("OnSelectionChanged", "ACTION_SELECTION_CHANGED")
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "bottom")
			:SetLayout("VERTICAL")
			:SetHeight(68)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Frame", "row1")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 8)
				:AddChild(UIElements.New("Text", "sold")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY3_MEDIUM")
					:SetTextPublisher(state:PublisherForKeys("hasFilter", "numSold")
						:MapWithFunction(private.StateToSoldText)
					)
				)
				:AddChild(UIElements.New("Text", "soldValue")
					:SetWidth("AUTO")
					:SetFont("TABLE_TABLE1")
					:SetTextPublisher(state:PublisherForKeyChange("soldGold")
						:MapWithFunction(Money.ToStringForAH)
					)
				)
				:AddChild(UIElements.New("Texture", "vline")
					:SetWidth(1)
					:SetMargin(8, 8, 0, 0)
					:SetColor("ACTIVE_BG_ALT")
				)
				:AddChild(UIElements.New("Text", "posted")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY3_MEDIUM")
					:SetTextPublisher(state:PublisherForKeys("hasFilter", "numPosted")
						:MapWithFunction(private.StateToPostedText)
					)
				)
				:AddChild(UIElements.New("Text", "postedValue")
					:SetWidth("AUTO")
					:SetFont("TABLE_TABLE1")
					:SetTextPublisher(state:PublisherForKeyChange("postedGold")
						:MapWithFunction(Money.ToStringForAH)
					)
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
			)
			:AddChild(UIElements.New("Frame", "row2")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("ProgressBar", "progressBar")
					:SetMargin(0, 8, 0, 0)
					:SetProgress(0)
					:SetTextPublisher(state:PublisherForKeys("numPending", "selectedAuctionId")
						:MapWithFunction(private.StateToProgressText)
					)
					:SetProgressIconHiddenPublisher(state:PublisherForKeyChange("numPending"):MapBooleanEquals(0))
				)
				:AddChild(UIElements.NewNamed("ActionButton", "cancelBtn", "TSMCancelAuctionBtn")
					:SetSize(110, 24)
					:SetMargin(0, 8, 0, 0)
					:SetText(CANCEL)
					:SetDisabled(true)
					:DisableClickCooldown(true)
					:SetDisabledPublisher(state:PublisherForKeyChange("canCancel"):InvertBoolean())
					:SetAction("OnClick", "ACTION_CANCEL_AUCTION")
				)
				:AddChild(UIElements.New("ActionButton", "skipBtn")
					:SetSize(110, 24)
					:SetText(L["Skip"])
					:SetDisabled(true)
					:DisableClickCooldown(true)
					:SetDisabledPublisher(state:PublisherForKeyChange("selectedAuctionId"):MapBooleanEquals(nil))
					:SetAction("OnClick", "ACTION_SKIP_AUCTION")
				)
			)
		)
		:SetScript("OnUpdate", private.FrameOnUpdate)
		:SetScript("OnHide", private.FrameOnHide)
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state MyAuctionsUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_SHOW" then
		local frame = ...
		state.frame = frame
		assert(not state.query and not state.queryCancellable)
		state.query = TSM.MyAuctions.CreateQuery() ---@type DatabaseQuery
		state.queryCancellable = state.query:Publisher()
			:MapToValue("ACTION_DATA_UPDATED")
			:CallMethod(manager, "ProcessAction")
			:Stored()
		state.frame:GetElement("auctions"):SetFilters(private.filters.keyword, private.filters.duration, private.filters.groups, private.filters.bid, private.filters.sold)
		private.UpdateQueryTotals(state)
		state.selectedAuctionId = state.frame:GetElement("auctions"):GetSelectedAuction()
	elseif action == "ACTION_FRAME_HIDE" then
		if not state.frame then
			return
		end
		state.frame = nil
		state.queryCancellable:Cancel()
		state.queryCancellable = nil
		state.query:Release()
		state.query = nil
		private.filters.duration = nil
		private.filters.keyword = nil
		wipe(private.filters.groups)
		private.filters.bid = nil
		private.filters.sold = false
		state.hasFilter = false
		state.selectedAuctionId = nil
		state.numPending = 0
	elseif action == "ACTION_DATA_UPDATED" then
		if not state.frame then
			return
		end
		private.UpdateQueryTotals(state)
		state.selectedAuctionId = state.frame:GetElement("auctions"):GetSelectedAuction()
		state.numPending = TSM.MyAuctions.GetNumPending()
	elseif action == "ACTION_FILTER_UPDATED" then
		private.UpdateFilters(state)
		private.UpdateQueryTotals(state)
	elseif action == "ACTION_SELECTION_CHANGED" then
		state.selectedAuctionId = state.frame:GetElement("auctions"):GetSelectedAuction()
	elseif action == "ACTION_CANCEL_AUCTION" then
		local auctionId = state.frame:GetElement("auctions"):GetSelectedAuction()
		if TSM.MyAuctions.CanCancel(auctionId) then
			TSM.MyAuctions.CancelAuction(auctionId)
		end
		state.numPending = TSM.MyAuctions.GetNumPending()
	elseif action == "ACTION_SKIP_AUCTION" then
		state.frame:GetElement("auctions"):SelectNextRow()
	elseif action == "ACTION_ITEM_LINKED" then
		local name = ...
		state.frame:GetElement("header.filters.keyword")
			:SetValue(name)
			:Draw()
		private.manager:ProcessAction("ACTION_FILTER_UPDATED")
	elseif action == "ACTION_CLEAR_FILTERS" then
		state.frame:GetElement("header.filters.duration")
			:SetSelectedItem(nil, true)
		state.frame:GetElement("header.filters.group")
			:ClearSelectedGroups(true)
			:Draw()
		state.frame:GetElement("header.filters.keyword")
			:SetValue("")
			:SetFocused(false)
		state.frame:GetElement("header.buttons.ignoreBid")
			:SetChecked(false, true)
		state.frame:GetElement("header.buttons.onlyBid")
			:SetChecked(false, true)
		state.frame:GetElement("header.buttons.onlySold")
			:SetChecked(false, true)
		private.manager:ProcessAction("ACTION_FILTER_UPDATED")
	else
		error("Unknown action: "..tostring(action))
	end
end

function private.UpdateQueryTotals(state)
	local numPosted, numSold, postedGold, soldGold = state.frame:GetElement("auctions"):GetTotals()
	state.numPosted = numPosted
	state.numSold = numSold
	state.postedGold = postedGold
	state.soldGold = soldGold
end

function private.UpdateFilters(state)
	local didChange = false
	local durationDropdown = state.frame:GetElement("header.filters.duration")
	local ignoreBidToggle = state.frame:GetElement("header.buttons.ignoreBid")
	local onlyBidToggle = state.frame:GetElement("header.buttons.onlyBid")
	local onlySoldToggle = state.frame:GetElement("header.buttons.onlySold")

	-- Uncheck the other toggle in the pair of "bid" toggles
	if ignoreBidToggle:IsChecked() and private.filters.bid == true then
		onlyBidToggle:SetChecked(false, true)
			:Draw()
	elseif onlyBidToggle:IsChecked() and private.filters.bid == false then
		ignoreBidToggle:SetChecked(false, true)
			:Draw()
	end
	-- Uncheck the other toggle in the pair of "only" toggles
	if onlyBidToggle:IsChecked() and private.filters.sold then
		onlySoldToggle:SetChecked(false, true)
			:Draw()
	elseif onlySoldToggle:IsChecked() and private.filters.bid then
		onlyBidToggle:SetChecked(false, true)
			:Draw()
	end

	-- Clear the duration selection if "None" is selected
	if durationDropdown:GetSelectedItemIndex() == 1 then
		durationDropdown:SetSelectedItem(nil, true)
	end

	local duration = durationDropdown:GetSelectedItemIndex()
	duration = duration and (duration - 1) or nil
	if duration ~= private.filters.duration then
		private.filters.duration = duration
		didChange = true
	end

	local keyword = state.frame:GetElement("header.filters.keyword"):GetValue()
	keyword = keyword ~= "" and String.Escape(keyword) or nil
	if keyword ~= private.filters.keyword then
		private.filters.keyword = keyword
		didChange = true
	end

	local groups = TempTable.Acquire()
	for groupPath in state.frame:GetElement("header.filters.group"):SelectedGroupIterator() do
		groups[groupPath] = true
	end
	if Hash.Calculate(groups) ~= Hash.Calculate(private.filters.groups) then
		didChange = true
		wipe(private.filters.groups)
		for groupPath in pairs(groups) do
			private.filters.groups[groupPath] = true
		end
	end
	TempTable.Release(groups)

	local bid = nil
	if ignoreBidToggle:IsChecked() then
		bid = false
	elseif onlyBidToggle:IsChecked() then
		bid = true
	end
	if bid ~= private.filters.bid then
		private.filters.bid = bid
		didChange = true
	end

	local sold = onlySoldToggle:IsChecked()
	if sold ~= private.filters.sold then
		private.filters.sold = sold
		didChange = true
	end

	state.hasFilter = (duration or keyword or next(private.filters.groups) or bid ~= nil or sold) and true or false
	if didChange then
		state.frame:GetElement("auctions"):SetFilters(private.filters.keyword, private.filters.duration, private.filters.groups, private.filters.bid, private.filters.sold)
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.FrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.manager:ProcessAction("ACTION_FRAME_SHOW", frame)
end

function private.FrameOnHide()
	private.manager:ProcessAction("ACTION_FRAME_HIDE")
end

function private.StateToProgressText(state)
	if state.numPending > 0 then
		return format(L["Canceling %d Auctions..."], state.numPending)
	elseif state.selectedAuctionId then
		return L["Ready to Cancel"]
	else
		return L["Select Auction to Cancel"]
	end
end

function private.StateToSoldText(state)
	return format((state.hasFilter and L["%s Sold Auctions (Filtered)"] or L["%s Sold Auctions"])..":", Theme.GetColor("INDICATOR"):ColorText(state.numSold))
end

function private.StateToPostedText(state)
	return format((state.hasFilter and L["%s Posted Auctions (Filtered)"] or L["%s Posted Auctions"])..":", Theme.GetColor("INDICATOR_ALT"):ColorText(state.numPosted))
end
