-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Auctioning = TSM.UI.AuctionUI:NewPackage("Auctioning") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local Money = TSM.LibTSMUtil:Include("UI.Money")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local AuctionHouseWrapper = TSM.LibTSMWoW:Include("API.AuctionHouseWrapper")
local AuctionHouse = TSM.LibTSMWoW:Include("API.AuctionHouse")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local SoundAlert = TSM.LibTSMWoW:Include("UI.SoundAlert")
local Group = TSM.LibTSMTypes:Include("Group")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local AuctionHouseUIUtils = TSM.LibTSMUI:Include("AuctionHouse.AuctionHouseUIUtils")
local AuctionScan = TSM.LibTSMService:Include("AuctionScan")
local private = {
	manager = nil, ---@type UIManager
	settings = nil,
	scanContext = {},
}
local SECONDS_PER_MIN = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MIN
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR
local STATE_SCHEMA = Reactive.CreateStateSchema("AUCTIONING_UI_STATE")
	:AddStringField("contentPath", "selection")
	:AddOptionalTableField("selectionFrame")
	:AddOptionalTableField("scanFrame")
	:AddOptionalStringField("scanType")
	:AddStringField("scanTab", "log")
	:AddBooleanField("hasLastScan", false)
	:AddOptionalStringField("scanThreadId")
	:AddBooleanField("isScanning", false)
	:AddBooleanField("doneScanning", false)
	:AddOptionalTableField("auctionScan")
	:AddOptionalNumberField("scanNumItems")
	:AddNumberField("scanProgress", 0)
	:AddOptionalBooleanField("scanIsPaused")
	:AddOptionalTableField("pendingFuture")
	:AddBooleanField("canStartNewScan", false)
	:AddOptionalBooleanField("pausePending")
	:AddBooleanField("canProcess", false)
	:AddOptionalTableField("currentRowCancellable")
	:AddOptionalNumberField("currentRowDepositCost")
	:AddOptionalStringField("currentRowItemString")
	:AddBooleanField("currentRowIsCommodity", false)
	:AddOptionalNumberField("currentRowDuration")
	:AddOptionalNumberField("currentRowBid")
	:AddOptionalNumberField("currentRowItemBid")
	:AddOptionalNumberField("currentRowBuyout")
	:AddOptionalNumberField("currentRowItemBuyout")
	:AddOptionalNumberField("currentRowNumProcessed")
	:AddOptionalNumberField("currentRowNumStacks")
	:AddOptionalNumberField("currentRowStackSize")
	:AddOptionalNumberField("currentRowAuctionId")
	:AddOptionalStringField("currentRowOperationName")
	:AddOptionalTableField("statusCancellable")
	:AddOptionalNumberField("statusNumProcessed")
	:AddOptionalNumberField("statusNumConfirmed")
	:AddOptionalNumberField("statusNumFailed")
	:AddOptionalNumberField("statusTotalNum")
	:AddNumberField("playerMoney", 0)
	:Commit()
local COMMON_CURRENT_ROW_STATE_FIELDS = {
	itemString = "currentRowItemString",
	bid = "currentRowBid",
	itemBid = "currentRowItemBid",
	buyout = "currentRowBuyout",
	itemBuyout = "currentRowItemBuyout",
	numProcessed = "currentRowNumProcessed",
	numStacks = "currentRowNumStacks",
	stackSize = "currentRowStackSize",
	auctionId = "currentRowAuctionId",
	operationName = "currentRowOperationName",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Auctioning.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctionUIContext", "auctioningSelectionDividedContainer")
		:AddKey("global", "auctionUIContext", "auctioningSelectionVerticalDividedContainer")
		:AddKey("global", "auctionUIContext", "auctioningBagScrollingTable")
		:AddKey("global", "auctionUIContext", "auctioningLogScrollingTable")
		:AddKey("global", "auctionUIContext", "auctioningAuctionScrollingTable")
		:AddKey("global", "auctionUIContext", "auctioningTabGroup")
		:AddKey("char", "auctionUIContext", "auctioningGroupTree")
		:AddKey("global", "auctioningOptions", "scanCompleteSound")
		:AddKey("global", "auctioningOptions", "confirmCompleteSound")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("AUCTIONING", state, private.ActionHandler)
		:SuppressActionLog("ACTION_SCAN_PROGRESS_UPDATED")

	-- Register this page with the Auction UI
	local function GetFrame()
		return private.GetAuctioningFrame(state)
	end
	local function OnItemLinked(_, itemLink)
		return private.StartLinkedItemScan(state, itemLink)
	end
	TSM.UI.AuctionUI.RegisterTopLevelPage(L["Auctioning"], GetFrame, OnItemLinked)

	-- Set up some state publishers
	private.manager:AddCancellable(state:PublisherForKeys("scanFrame", "scanTab", "currentRowItemString")
		:IgnoreIfKeyNotEquals("scanTab", "log")
		:IgnoreIfKeyEquals("scanFrame", nil)
		:CallFunction(private.UpdateLogSelectedIndex)
	)
	private.manager:SetStateFromPublisher("currentRowIsCommodity", state:PublisherForKeyChange("currentRowItemString")
		:MapNonNilWithFunction(ItemInfo.IsCommodity)
		:MapNilToValue(false)
	)
	private.manager:SetStateFromPublisher("doneScanning", state:PublisherForExpression([[scanProgress == 1 and not isScanning]]))
	private.manager:SetStateFromPublisher("canProcess", state:PublisherForExpression([[not pausePending and (doneScanning or scanIsPaused) or false]]))

	-- Set up some event handlers
	Event.Register("PLAYER_MONEY", function() state.playerMoney = GetMoney() end)
	DefaultUI.RegisterAuctionHouseVisibleCallback(function() private.manager:ProcessAction("ACTION_AUCTION_HOUSE_CLOSED") end, false)
end



-- ============================================================================
-- Auctioning UI
-- ============================================================================

function private.GetAuctioningFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning")
	if not state.hasLastScan then
		state.contentPath = "selection"
	end
	return UIElements.New("ViewContainer", "auctioning")
		:SetContext(state)
		:SetNavCallback(private.GetAuctioningContentFrame)
		:AddPath("selection")
		:AddPath("scan")
		:SetPath(state.contentPath)
end

function private.GetAuctioningContentFrame(frame, path)
	local state = frame:GetContext() ---@type AuctioningUIState
	state.contentPath = path
	if path == "selection" then
		return private.GetAuctioningSelectionFrame()
	elseif path == "scan" then
		return private.GetAuctioningScanFrame(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

function private.GetAuctioningSelectionFrame()
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "selection")
	local frame = UIElements.New("DividedContainer", "selection")
		:SetSettingsContext(private.settings, "auctioningSelectionDividedContainer")
		:SetMinWidth(220, 250)
		:SetBackgroundColor("PRIMARY_BG")
		:SetManager(private.manager)
		:SetLeftChild(UIElements.New("Frame", "groupSelection")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
				:SetOperationType("Auctioning")
				:SetSettingsContext(private.settings, "auctioningGroupTree")
				:SetAction("OnGroupSelectionChanged", "ACTION_GROUP_SELECTION_CHANGED")
			)
			:AddChild(UIElements.New("HorizontalLine", "line"))
			:AddChild(UIElements.New("Frame", "bottom")
				:SetLayout("VERTICAL")
				:SetHeight(72)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("ActionButton", "postScanBtn")
					:SetHeight(24)
					:SetMargin(8)
					:SetText(L["Run Post Scan"])
					:SetAction("OnClick", "ACTION_START_GROUP_POST_SCAN")
				)
				:AddChild(UIElements.New("ActionButton", "cancelScanBtn")
					:SetHeight(24)
					:SetMargin(8, 8, 0, 8)
					:SetText(L["Run Cancel Scan"])
					:SetAction("OnClick", "ACTION_START_GROUP_CANCEL_SCAN")
				)
			)
		)
		:SetRightChild(UIElements.New("DividedContainer", "content")
			:SetVertical()
			:SetMargin(0, 0, 6, 0)
			:SetSettingsContext(private.settings, "auctioningSelectionVerticalDividedContainer")
			:SetMinWidth(50, 100)
			:SetBackgroundColor("PRIMARY_BG")
			:SetTopChild(UIElements.New("Frame", "top")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("TabGroup", "buttons")
					:SetNavCallback(private.GetScansElement)
					:SetSettingsContext(private.settings, "auctioningTabGroup")
					:AddPath(L["Recent Scans"])
					:AddPath(L["Favorite Scans"])
				)
			)
			:SetBottomChild(UIElements.New("Frame", "bottom")
				:SetLayout("VERTICAL")
				:AddChild(UIElements.New("Frame", "bottom")
					:SetLayout("VERTICAL")
					:SetHeight(37)
					:SetBackgroundColor("PRIMARY_BG_ALT")
					:AddChild(UIElements.New("Text", "label")
						:SetHeight(24)
						:SetMargin(4, 0, 6, 6)
						:SetFont("BODY_BODY1_BOLD")
						:SetText(L["Post Items from Bags"])
					)
				)
				:AddChild(UIElements.New("AuctioningBagScrollTable", "bagScrollingTable")
					:SetSettings(private.settings, "auctioningBagScrollingTable")
					:SetQuery(TSM.Auctioning.PostScan.CreateBagsQuery())
					:SetScript("OnSelectionChanged", private.BagOnSelectionChanged)
				)
				:AddChild(UIElements.New("HorizontalLine", "line"))
				:AddChild(UIElements.New("Frame", "button")
					:SetLayout("HORIZONTAL")
					:SetHeight(40)
					:SetPadding(8)
					:SetBackgroundColor("PRIMARY_BG_ALT")
					:AddChild(UIElements.New("ActionButton", "postSelected")
						:SetHeight(24)
						:SetMargin(0, 8, 0, 0)
						:SetDisabled(true)
						:SetText(L["Post Selected"])
						:SetAction("OnClick", "ACTION_START_BAGS_POST_SCAN")
					)
					:AddChild(UIElements.New("Button", "selectAll")
						:SetSize("AUTO", 20)
						:SetMargin(0, 8, 0, 0)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Select All"])
						:SetAction("OnClick", "ACTION_BAG_SELECT_ALL")
					)
					:AddChild(UIElements.New("VerticalLine", "line")
						:SetHeight(20)
						:SetMargin(0, 8, 0, 0)
					)
					:AddChild(UIElements.New("Button", "clearAll")
						:SetSize("AUTO", 20)
						:SetFont("BODY_BODY3_MEDIUM")
						:SetText(L["Clear All"])
						:SetDisabled(true)
						:SetAction("OnClick", "ACTION_BAG_CLEAR_ALL")
					)
				)
			)
		)
		:SetScript("OnUpdate", private.SelectionOnUpdate)
		:SetScript("OnHide", private.SelectionOnHide)
	local selectionCleared = frame:GetElement("groupSelection.groupTree"):IsSelectionCleared()
	frame:GetElement("groupSelection.bottom.postScanBtn"):SetDisabled(selectionCleared)
	frame:GetElement("groupSelection.bottom.cancelScanBtn"):SetDisabled(selectionCleared)
	return frame
end

function private.GetScansElement(_, button)
	if button == L["Recent Scans"] then
		return UIElements.New("SearchList", "list")
			:SetEditEnabled(false)
			:SetQuery(TSM.Auctioning.SavedSearches.CreateRecentSearchesQuery())
			:SetAction("OnFavoriteChanged", "ACTION_SET_SEARCH_FAVORITE")
			:SetAction("OnDelete", "ACTION_RECENT_SEARCH_DELETE")
			:SetAction("OnRowClick", "ACTION_RECENT_SEARCH_LIST_ROW_CLICK")
	elseif button == L["Favorite Scans"] then
		return UIElements.New("SearchList", "list")
			:SetEditEnabled(true)
			:SetQuery(TSM.Auctioning.SavedSearches.CreateFavoriteSearchesQuery())
			:SetAction("OnFavoriteChanged", "ACTION_SET_SEARCH_FAVORITE")
			:SetAction("OnEdit", "ACTION_FAVORITE_SEARCH_EDIT")
			:SetAction("OnDelete", "ACTION_FAVORITE_SEARCH_DELETE")
			:SetAction("OnRowClick", "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK")
	else
		error("Unexpected button: "..tostring(button))
	end
end

---@param state AuctioningUIState
function private.GetAuctioningScanFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "scan")
	return UIElements.New("Frame", "scan")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("PRIMARY_BG")
		:SetManager(private.manager)
		:AddChild(UIElements.New("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetPadding(8)
			:SetHeight(92)
			:AddChild(UIElements.New("Frame", "back")
				:SetLayout("VERTICAL")
				:SetWidth(54)
				:SetHeight(76)
				:SetMargin(0, 8, 0, 0)
				:SetPadding(0, 0, 4, 0)
				:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("Button", "backBtn")
					:SetMargin(0, 0, 2, 0)
					:SetSize(28, 28)
					:SetBackground("iconPack.24x24/Close/Default")
					:SetScript("OnEnter", private.ExitScanButtonOnEnter)
					:SetScript("OnLeave", private.ExitScanButtonOnLeave)
					:SetAction("OnClick", "ACTION_STOP_SCANNING")
				)
				:AddChild(UIElements.New("Text", "text")
					:SetHeight(18)
					:SetFont("BODY_BODY3_MEDIUM")
					:SetJustifyH("CENTER")
					:SetText(L["Exit"])
				)
				:AddChild(UIElements.New("Text", "text")
					:SetHeight(18)
					:SetFont("BODY_BODY3_MEDIUM")
					:SetJustifyH("CENTER")
					:SetText(L["Scan"])
				)
				:SetScript("OnEnter", private.ExitScanFrameOnEnter)
				:SetScript("OnLeave", private.ExitScanFrameOnLeave)
				:SetScript("OnMouseUp", private.manager:CallbackToProcessAction("ACTION_STOP_SCANNING"))
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetPadding(8, 8, 4, 4)
				:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("Frame", "item")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Frame", "content")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:SetMargin(0, 0, 0, 4)
						:AddChild(UIElements.New("Button", "icon")
							:SetSize(18, 18)
							:SetBackgroundPublisher(state:PublisherForKeyChange("currentRowItemString")
								:MapNonNilWithFunction(ItemInfo.GetTexture)
							)
							:SetTooltipPublisher(state:PublisherForKeyChange("currentRowItemString"))
						)
						:AddChild(UIElements.New("Button", "text")
							:SetMargin(4, 0, 0, 0)
							:SetFont("ITEM_BODY1")
							:SetJustifyH("LEFT")
							:SetTextPublisher(state:PublisherForKeyChange("currentRowItemString")
								:MapNonNilWithFunction(UIUtils.GetDisplayItemName)
								:MapNilToValue("-")
							)
							:SetTooltipPublisher(state:PublisherForKeyChange("currentRowItemString"))
						)
					)
					:AddChild(UIElements.New("Frame", "cost")
						:SetLayout("HORIZONTAL")
						:SetHeight(20)
						:AddChild(UIElements.New("Text", "desc")
							:SetWidth("AUTO")
							:SetFont("BODY_BODY3_MEDIUM")
							:SetText(L["Deposit Cost"]..":")
						)
						:AddChild(UIElements.New("Text", "text")
							:SetMargin(4, 0, 0, 0)
							:SetFont("TABLE_TABLE1")
							:SetTextPublisher(state:PublisherForKeyChange("currentRowDepositCost")
								:MapNonNilWithFunction(Money.ToStringForUI)
								:MapNilToValue("-")
							)
						)
					)
					:AddChild(UIElements.New("Frame", "operation")
						:SetLayout("HORIZONTAL")
						:SetHeight(20)
						:AddChild(UIElements.New("Text", "desc")
							:SetWidth("AUTO")
							:SetFont("BODY_BODY3_MEDIUM")
							:SetText(L["Operation"]..":")
						)
						:AddChild(UIElements.New("Text", "text")
							:SetMargin(4, 0, 0, 0)
							:SetFont("BODY_BODY3_MEDIUM")
							:SetTextPublisher(state:PublisherForKeyChange("currentRowOperationName")
								:MapNilToValue("-")
							)
						)
					)
				)
				:AddChild(UIElements.New("Frame", "details")
					:SetLayout("VERTICAL")
					:SetWidth(371)
					:SetMargin(16, 0, 0, 0)
					:AddChild(UIElements.New("Frame", "header")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:AddChild(UIElements.New("Text", "text")
							:SetMargin(0, 10, 0, 0)
							:SetSize("AUTO", 16)
							:SetFont("BODY_BODY1")
							:SetText(L["Auctioning Details"])
						)
						:AddChild(UIElements.New("ActionButton", "editBtn")
							:SetHeight(16)
							:SetFont("BODY_BODY3_MEDIUM")
							:SetText(L["Edit Post"])
							:SetDisabledPublisher(state:PublisherForExpression([[scanType ~= "POST" or not currentRowItemString]]))
							:SetAction("OnClick", "ACTION_EDIT_BUTTON_CLICKED")
						)
					)
					:AddChild(UIElements.New("Frame", "details")
						:SetLayout("HORIZONTAL")
						:SetMargin(0, 0, 4, 0)
						:AddChild(UIElements.New("Frame", "details1")
							:SetLayout("VERTICAL")
							:SetWidth(200)
							:SetMargin(0, 8, 0, 0)
							:AddChild(UIElements.New("Frame", "bid")
								:SetLayout("HORIZONTAL")
								:SetHeight(20)
								:AddChild(UIElements.New("Text", "desc")
									:SetWidth("AUTO")
									:SetFont("BODY_BODY3_MEDIUM")
									:SetText(L["Bid Price"]..":")
								)
								:AddChild(UIElements.New("Text", "text")
									:SetMargin(4, 0, 0, 0)
									:SetFont("TABLE_TABLE1")
									:SetTextPublisher(state:PublisherForExpression([[currentRowIsCommodity and currentRowItemBuyout or currentRowBid]])
										:MapNonNilWithFunction(Money.ToStringForAH)
										:MapNilToValue("-")
									)
								)
							)
							:AddChild(UIElements.New("Frame", "buyout")
								:SetLayout("HORIZONTAL")
								:SetHeight(20)
								:AddChild(UIElements.New("Text", "desc")
									:SetWidth("AUTO")
									:SetFont("BODY_BODY3_MEDIUM")
									:SetText(L["Buyout Price"]..":")
								)
								:AddChild(UIElements.New("Text", "text")
									:SetMargin(4, 0, 0, 0)
									:SetFont("TABLE_TABLE1")
									:SetTextPublisher(state:PublisherForExpression([[currentRowIsCommodity and currentRowItemBuyout or currentRowBuyout]])
										:MapNonNilWithFunction(Money.ToStringForAH)
										:MapNilToValue("-")
									)

								)
							)
						)
						:AddChild(UIElements.New("Frame", "details2")
							:SetLayout("VERTICAL")
							:AddChild(UIElements.New("Frame", "quantity")
								:SetLayout("HORIZONTAL")
								:SetHeight(20)
								:AddChild(UIElements.New("Text", "desc")
									:SetWidth("AUTO")
									:SetFont("BODY_BODY3_MEDIUM")
									:SetText((ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and L["Stack / Quantity"] or L["Quantity"])..":")
								)
								:AddChild(UIElements.New("Text", "text")
									:SetMargin(4, 0, 0, 0)
									:SetFont("TABLE_TABLE1")
									:SetTextPublisher(state:PublisherForKeys("currentRowNumStacks", "currentRowNumProcessed", "currentRowStackSize")
										:MapWithFunction(private.StateToQuantityText)
										:MapNilToValue("-")
									)
								)

							)
							:AddChild(UIElements.New("Frame", "duration")
								:SetLayout("HORIZONTAL")
								:SetHeight(20)
								:AddChild(UIElements.New("Text", "desc")
									:SetWidth("AUTO")
									:SetFont("BODY_BODY3_MEDIUM")
									:SetText(L["Duration"]..":")
								)
								:AddChild(UIElements.New("Text", "text")
									:SetMargin(4, 0, 0, 0)
									:SetFont("TABLE_TABLE1")
									:SetTextPublisher(state:PublisherForKeys("scanType", "currentRowDuration")
										:MapWithFunction(private.StateToAuctionDuration)
										:MapNilToValue("-")
									)
								)
							)
						)
					)
				)
			)
		)
		:AddChild(UIElements.New("TabGroup", "tabs")
			:SetTheme("SIMPLE")
			:SetContext(state)
			:SetNavCallback(private.ScanNavCallback)
			:AddPath(L["Auctioning Log"], true)
			:AddPath(L["All Auctions"])
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(UIElements.New("Frame", "bottom")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("ActionButton", "pauseResumeBtn")
				:SetSize(24, 24)
				:SetMargin(0, 8, 0, 0)
				:SetText(TextureAtlas.GetTextureLink("iconPack.18x18/PlayPause"))
				:SetDisabledPublisher(state:PublisherForExpression([[pausePending or doneScanning or (scanIsPaused and statusNumProcessed ~= statusNumConfirmed) or statusNumProcessed == statusTotalNum]]))
				:SetHighlightLockedPublisher(state:PublisherForExpression([[pausePending]]))
				:SetAction("OnClick", "ACTION_TOGGLE_SCAN_PAUSED")
			)
			:AddChild(UIElements.New("ProgressBar", "progressBar")
				:SetHeight(24)
				:SetMargin(0, 8, 0, 0)
				:SetTextPublisher(state:PublisherForKeys("canProcess", "scanType", "pausePending", "scanIsPaused", "scanNumItems", "statusNumConfirmed", "statusTotalNum", "statusNumProcessed")
					:MapWithFunction(private.StateToProgressText)
				)
				:SetProgressPublisher(state:PublisherForExpression([[(not canProcess and scanProgress) or (statusTotalNum > 0 and (statusNumProcessed / statusTotalNum)) or 1]]))
				:SetProgressIconHiddenPublisher(state:PublisherForExpression([[canProcess and (statusNumConfirmed == statusTotalNum or (statusNumProcessed ~= statusTotalNum and statusNumProcessed == statusNumConfirmed))]]))
			)
			:AddChild(UIElements.NewNamed("ActionButton", "processBtn", "TSMAuctioningBtn")
				:SetSize(160, 24)
				:SetMargin(0, 8, 0, 0)
				:DisableClickCooldown(true)
				:SetTextPublisher(state:PublisherForKeyChange("scanType")
					:MapBooleanEquals("POST")
					:MapBooleanWithValues(L["Post"], CANCEL)
				)
				:SetDisabledPublisher(state:PublisherForExpression([[(not canProcess or statusNumProcessed == statusTotalNum or (currentRowDepositCost and currentRowDepositCost > playerMoney) or pendingFuture) and true or false]]))
				:SetAction("OnClick", "ACTION_PROCESS_AUCTION")
			)
			:AddChild(UIElements.New("ActionButton", "skipBtn")
				:SetSize(160, 24)
				:SetText(L["Skip"])
				:DisableClickCooldown(true)
				:SetDisabledPublisher(state:PublisherForExpression([[not canProcess or statusNumProcessed == statusTotalNum]]))
				:SetAction("OnClick", "ACTION_SKIP_AUCTION")
			)
			:AddChild(UIElements.New("ActionButton", "rescanBtn")
				:SetWidth(160, 24)
				:SetText(L["Rescan"])
				:SetShown(false)
				:SetAction("OnClick", "ACTION_RESCAN")
			)
		)
		:SetScript("OnUpdate", private.ScanFrameOnUpdate)
		:SetScript("OnHide", private.ScanFrameOnHide)
end

function private.ScanNavCallback(frame, path)
	local state = frame:GetContext() ---@type AuctioningUIState
	if path == L["Auctioning Log"] then
		UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "scan", "log")
		return UIElements.New("Frame", "logFrame")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("AuctioningLogScrollTable", "log")
				:SetSettings(private.settings, "auctioningLogScrollingTable")
				:SetQuery(TSM.Auctioning.Log.CreateQuery()
					:VirtualField("indexIcon", "string", private.LogIndexIconVirtualField)
				)
			)
			:SetScript("OnUpdate", private.LogTabOnUpdate)
	elseif path == L["All Auctions"] then
		UIUtils.AnalyticsRecordPathChange("auction", "auctioning", "scan", "auctions")
		return UIElements.New("Frame", "auctionsFrame")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("AuctionScrollTable", "auctions")
				:SetSettings(private.settings, "auctioningAuctionScrollingTable")
				:SetCreatedGroupName(L["Auctioning"].." - "..L["All Auctions"])
				:SetBrowseResultsVisible(true)
				:SetMarketValueFunction(private.MarketValueFunction)
				:SetIsPlayerFunction(PlayerInfo.AuctionOwnerIsPlayer)
				:SetAuctionScan(state.auctionScan)
			)
			:SetScript("OnUpdate", private.AuctionsTabOnUpdate)
	else
		error("Unexpected path: "..tostring(path))
	end
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.SelectionOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.manager:ProcessAction("ACTION_SELECTION_FRAME_SHOWN", frame)
end

function private.SelectionOnHide()
	private.manager:ProcessAction("ACTION_SELECTION_FRAME_HIDDEN")
end

function private.ScanFrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.manager:ProcessAction("ACTION_SCAN_FRAME_SHOWN", frame)
end

function private.ScanFrameOnHide()
	private.manager:ProcessAction("ACTION_SCAN_FRAME_HIDDEN")
end

function private.LogTabOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.manager:ProcessAction("ACTION_SCAN_TAB_CHANGED", "log")
end

function private.AuctionsTabOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	private.manager:ProcessAction("ACTION_SCAN_TAB_CHANGED", "auctions")
end

function private.BagOnSelectionChanged(scrollTable)
	local allSelected, noneSelected = scrollTable:GetSelectionState()
	local buttonFrame = scrollTable:GetElement("__parent.button")
	buttonFrame:GetElement("postSelected"):SetDisabled(noneSelected)
	buttonFrame:GetElement("selectAll"):SetDisabled(allSelected)
	buttonFrame:GetElement("clearAll"):SetDisabled(noneSelected)
end

function private.ExitScanButtonOnEnter(button)
	private.ExitScanFrameOnEnter(button:GetParentElement())
end

function private.ExitScanButtonOnLeave(button)
	private.ExitScanFrameOnLeave(button:GetParentElement())
end

function private.ExitScanFrameOnEnter(frame)
	frame:SetRoundedBackgroundColor("PRIMARY_BG_ALT+HOVER")
		:Draw()
end

function private.ExitScanFrameOnLeave(frame)
	frame:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
		:Draw()
end



-- ============================================================================
-- Action Handler
-- ============================================================================

---@param manager UIManager
---@param state AuctioningUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_SELECTION_FRAME_SHOWN" then
		local frame = ...
		state.selectionFrame = frame
	elseif action == "ACTION_SELECTION_FRAME_HIDDEN" then
		state.selectionFrame = nil
	elseif action == "ACTION_SCAN_FRAME_SHOWN" then
		local frame = ...
		state.scanFrame = frame
		private.UpdateScanFrame(state)
	elseif action == "ACTION_SCAN_FRAME_HIDDEN" then
		state.scanFrame = nil
	elseif action == "ACTION_SCAN_TAB_CHANGED" then
		local tab = ...
		state.scanTab = tab
	elseif action == "ACTION_GROUP_SELECTION_CHANGED" then
		local selectionCleared = state.selectionFrame:GetElement("groupSelection.groupTree"):IsSelectionCleared()
		state.selectionFrame:GetElement("groupSelection.bottom.postScanBtn")
			:SetDisabled(selectionCleared)
			:Draw()
		state.selectionFrame:GetElement("groupSelection.bottom.cancelScanBtn")
			:SetDisabled(selectionCleared)
			:Draw()
	elseif action == "ACTION_BAG_SELECT_ALL" then
		state.selectionFrame:GetElement("content.bottom.bagScrollingTable"):SetSelectionState(true)
	elseif action == "ACTION_BAG_CLEAR_ALL" then
		state.selectionFrame:GetElement("content.bottom.bagScrollingTable"):SetSelectionState(false)
	elseif action == "ACTION_RENAMED_SAVED_SEARCH" then
		local name, index = ...
		TSM.Auctioning.SavedSearches.RenameSearch(index, name)
	elseif action == "ACTION_START_GROUP_POST_SCAN" then
		private.StartGroupScan(state, "POST")
	elseif action == "ACTION_START_GROUP_CANCEL_SCAN" then
		private.StartGroupScan(state, "CANCEL")
	elseif action == "ACTION_START_BAGS_POST_SCAN" then
		private.StartPostBagsScan(state)
	elseif action == "ACTION_SET_SEARCH_FAVORITE" then
		local index, isFavorite = ...
		TSM.Auctioning.SavedSearches.SetSearchIsFavorite(index, isFavorite)
	elseif action == "ACTION_RECENT_SEARCH_DELETE" then
		local index = ...
		TSM.Auctioning.SavedSearches.DeleteSearch(index, private.GetSearchListFields("RECENT", index, "filter"))
	elseif action == "ACTION_FAVORITE_SEARCH_DELETE" then
		local index = ...
		TSM.Auctioning.SavedSearches.DeleteSearch(index, private.GetSearchListFields("FAVORITE", index, "filter"))
	elseif action == "ACTION_FAVORITE_SEARCH_EDIT" then
		local index = ...
		local dialog = UIElements.New("SavedSearchEditDialog", "frame")
			:SetSize(600, 187)
			:AddAnchor("CENTER")
			:SetName(private.GetSearchListFields("FAVORITE", index, "name"), index)
			:SetManager(private.manager)
			:SetAction("OnNameChanged", "ACTION_RENAMED_SAVED_SEARCH")
		state.selectionFrame:GetBaseElement():ShowDialogFrame(dialog)
		dialog:GetElement("nameInput"):SetFocused(true)
	elseif action == "ACTION_RECENT_SEARCH_LIST_ROW_CLICK" then
		local index = ...
		private.StartSearchListScan(state, "RECENT", index)
	elseif action == "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK" then
		local index = ...
		private.StartSearchListScan(state, "FAVORITE", index)
	elseif action == "ACTION_START_SCAN" then
		local scanType, scanContext = ...
		local viewContainer = nil
		if state.scanFrame then
			viewContainer = state.scanFrame:GetParentElement()
			viewContainer:SetPath("selection", true)
		elseif state.selectionFrame then
			viewContainer = state.selectionFrame:GetParentElement()
		else
			error("Invalid state")
		end
		viewContainer:SetPath("scan", true)
		state.scanFrame = viewContainer:GetElement("scan")
		manager:ProcessAction("ACTION_RESET_STATE")
		state.playerMoney = GetMoney()
		state.scanType = scanType
		state.hasLastScan = true
		local currentRowPublisher, statusPublisher = nil, nil
		if state.scanType == "POST" then
			state.scanThreadId = TSM.Auctioning.PostScan.Prepare()
			currentRowPublisher = TSM.Auctioning.PostScan.CurrentRowPublisher() ---@type ReactivePublisher
				:Share(Table.Count(COMMON_CURRENT_ROW_STATE_FIELDS) + 2)
				:MapWithFunction(private.CurrentRowToDepositCost)
				:AssignToTableKey(state, "currentRowDepositCost")
				:MapNonNilWithMethod("GetField", "postTime")
				:AssignToTableKey(state, "currentRowDuration")
			statusPublisher = TSM.Auctioning.PostScan.StatusQueryPublisher() ---@type ReactivePublisher
		elseif state.scanType == "CANCEL" then
			state.scanThreadId = TSM.Auctioning.CancelScan.Prepare()
			currentRowPublisher = TSM.Auctioning.CancelScan.CurrentRowPublisher() ---@type ReactivePublisher
				:Share(Table.Count(COMMON_CURRENT_ROW_STATE_FIELDS) + 1)
				:MapNonNilWithMethod("GetField", "duration")
				:AssignToTableKey(state, "currentRowDuration")
			statusPublisher = TSM.Auctioning.CancelScan.StatusQueryPublisher() ---@type ReactivePublisher
			state.currentRowDepositCost = nil
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		for rowField, stateField in pairs(COMMON_CURRENT_ROW_STATE_FIELDS) do
			currentRowPublisher:MapNonNilWithMethod("GetField", rowField)
				:AssignToTableKey(state, stateField)
		end
		state.currentRowCancellable = currentRowPublisher:Stored()
		state.statusCancellable = statusPublisher:CallFunction(manager:CallbackToProcessAction("ACTION_STATUS_UPDATED"))
			:Stored()
		state.auctionScan = AuctionScan.GetManager()
			:SetResolveSellers(ClientInfo.HasFeature(ClientInfo.FEATURES.AH_SELLERS))
			:SetUIManager(manager)
			:SetAction("OnProgressUpdate", "ACTION_SCAN_PROGRESS_UPDATED")
			:SetAction("OnNumItemsChanged", "ACTION_SCAN_NUM_ITEMS_CHANGED")
		Threading.SetCallback(state.scanThreadId, manager:CallbackToProcessAction("ACTION_SCAN_COMPLETED"))
		Threading.Start(state.scanThreadId, state.auctionScan, scanContext)
		state.isScanning = true
		private.UpdateScanFrame(state)
	elseif action == "ACTION_SCAN_PROGRESS_UPDATED" then
		local scanProgress, scanIsPaused = state.auctionScan:GetProgress()
		if state.pausePending == scanIsPaused then
			state.pausePending = nil
		end
		-- Clear pausePending if scan is done (3.3.5 fix: scan may not send final progress update)
		if scanProgress == 1 and not state.isScanning and state.pausePending then
			state.pausePending = nil
		end
		if scanIsPaused and not state.pausePending then
			state.isScanning = false
		end
		-- Set isScanning to false when scan is complete (progress = 1)
		if scanProgress == 1 and not scanIsPaused then
			state.isScanning = false
		end
		state.scanProgress = scanProgress
		state.scanIsPaused = scanIsPaused
		private.UpdateScanFrame(state)
	elseif action == "ACTION_SCAN_NUM_ITEMS_CHANGED" then
		state.scanNumItems = state.auctionScan:GetNumItems()
	elseif action == "ACTION_SCAN_COMPLETED" then
		AuctionScan.ReleaseLock(L["Auctioning"])
		state.scanThreadId = nil
		SoundAlert.Play(private.settings.scanCompleteSound)
		state.pausePending = nil  -- Clear pausePending on scan completion
		state.scanProgress = 1
		state.isScanning = false
		if state.statusTotalNum == 0 then
			state.canStartNewScan = true
		end
		private.UpdateScanFrame(state)
	elseif action == "ACTION_STATUS_UPDATED" then
		local numProcessed, numConfirmed, numFailed, totalNum = TempTable.UnpackAndRelease(...)
		state.statusNumProcessed = numProcessed
		state.statusNumConfirmed = numConfirmed
		state.statusNumFailed = numFailed
		state.statusTotalNum = totalNum
	elseif action == "ACTION_TOGGLE_SCAN_PAUSED" then
		assert(not state.pausePending)
		state.pausePending = state.isScanning
		state.auctionScan:SetPaused(state.pausePending)
		state.isScanning = true
		private.UpdateScanFrame(state)
	elseif action == "ACTION_EDIT_BUTTON_CLICKED" then
		if state.scanType ~= "POST" or not state.currentRowItemString then
			return
		end
		state.scanFrame:GetBaseElement():ShowDialogFrame(UIElements.New("AuctioningEditDialog", "frame")
			:SetSize(328, 364)
			:SetPadding(12)
			:AddAnchor("CENTER")
			:SetAuction(state.currentRowItemString, state.currentRowDuration, state.currentRowItemBid, state.currentRowItemBuyout, state.currentRowNumStacks, state.currentRowStackSize)
			:SetManager(manager)
			:SetAction("OnSaveClicked", "ACTION_EDIT_DIALOG_SAVED")
		)
	elseif action == "ACTION_EDIT_DIALOG_SAVED" then
		local bid, buyout, perItem, duration, numStacks, stackSize = ...
		assert(state.scanType == "POST" and state.currentRowItemString)
		if buyout > 0 then
			bid = min(bid, buyout)
		end
		-- Apply stack size first so the per-stack price math below uses the new size
		if stackSize and stackSize ~= state.currentRowStackSize then
			TSM.Auctioning.PostScan.ChangePostDetail("stackSize", stackSize)
		end
		if numStacks and numStacks ~= state.currentRowNumStacks then
			TSM.Auctioning.PostScan.ChangePostDetail("numStacks", numStacks)
		end
		if duration ~= state.currentRowDuration then
			TSM.Auctioning.PostScan.ChangePostDetail("postTime", duration)
		end

		-- Update buyout first since doing so may change the bid
		if buyout ~= (perItem and state.currentRowItemBuyout or state.currentRowBuyout) then
			TSM.Auctioning.PostScan.ChangePostDetail(perItem and "itemBuyout" or "buyout", buyout)
		end

		if not state.currentRowIsCommodity and bid ~= (perItem and state.currentRowItemBid or state.currentRowBid) then
			TSM.Auctioning.PostScan.ChangePostDetail(perItem and "itemBid" or "bid", bid)
		end

		private.UpdateScanFrame(state)
	elseif action == "ACTION_PROCESS_AUCTION" then
		state.scanFrame:GetBaseElement():HideDialog()
		local result, noRetry = nil, nil
		if state.scanType == "POST" then
			result, noRetry = TSM.Auctioning.PostScan.DoProcess()
		elseif state.scanType == "CANCEL" then
			result, noRetry = TSM.Auctioning.CancelScan.DoProcess()
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		if not result then
			-- We failed to post / cancel
			return manager:ProcessAction("ACTION_HANDLE_PROCESS_RESULT", false, not noRetry)
		end
		manager:ManageFuture("pendingFuture", result, "ACTION_FUTURE_DONE")
		private.UpdateScanFrame(state)
	elseif action == "ACTION_FUTURE_DONE" then
		local value = ...
		return manager:ProcessAction("ACTION_HANDLE_PROCESS_RESULT", value == true, value == false)
	elseif action == "ACTION_HANDLE_PROCESS_RESULT" then
		local success, canRetry = ...
		local isDone = false
		if state.scanType == "POST" then
			TSM.Auctioning.PostScan.HandleConfirm(success, canRetry)
			if state.statusNumConfirmed == state.statusTotalNum then
				if state.statusNumFailed > 0 then
					ChatMessage.PrintfUser(L["Retrying %d auction(s) which failed."], state.statusNumFailed)
					TSM.Auctioning.PostScan.PrepareFailedPosts()
				else
					isDone = true
				end
			end
		elseif state.scanType == "CANCEL" then
			TSM.Auctioning.CancelScan.HandleConfirm(success, canRetry)
			if state.statusNumConfirmed == state.statusTotalNum then
				if state.statusNumFailed > 0 then
					ChatMessage.PrintfUser(L["Retrying %d auction(s) which failed."], state.statusNumFailed)
					TSM.Auctioning.CancelScan.PrepareFailedCancels()
				else
					isDone = true
				end
			end
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		if isDone and state.scanIsPaused then
			-- Unpause the scan now that we're done
			assert(not state.pausePending)
			state.pausePending = false
			state.auctionScan:SetPaused(false)
			state.isScanning = true
		elseif isDone then
			state.canStartNewScan = true
			AuctionHouseWrapper.AutoQueryOwnedAuctions()
			SoundAlert.Play(private.settings.confirmCompleteSound)
		end
		private.UpdateScanFrame(state)
	elseif action == "ACTION_SKIP_AUCTION" then
		if state.scanType == "POST" then
			TSM.Auctioning.PostScan.DoSkip()
		elseif state.scanType == "CANCEL" then
			TSM.Auctioning.CancelScan.DoSkip()
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		local isDone = state.statusNumConfirmed == state.statusTotalNum and state.statusNumFailed == 0
		if isDone and state.scanIsPaused then
			-- Unpause the scan now that we're done
			assert(not state.pausePending)
			state.pausePending = false
			state.auctionScan:SetPaused(false)
			state.isScanning = true
		elseif isDone then
			state.canStartNewScan = true
			AuctionHouseWrapper.AutoQueryOwnedAuctions()
			SoundAlert.Play(private.settings.confirmCompleteSound)
		end
		private.UpdateScanFrame(state)
	elseif action == "ACTION_RESCAN" then
		if not state.scanFrame or not AuctionScan.AcquireLock(L["Auctioning"]) then
			return
		end
		return manager:ProcessAction("ACTION_START_SCAN", state.scanType, private.scanContext)
	elseif action == "ACTION_STOP_SCANNING" then
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
			ClearCursor()
			ClickAuctionSellItemButton(AuctionsItemButton, "LeftButton")
			ClearCursor()
		end
		manager:ProcessAction("ACTION_RESET_STATE")
		if state.scanFrame then
			state.scanFrame:GetParentElement():SetPath("selection", true)
		end
		AuctionScan.ReleaseLock(L["Auctioning"])
	elseif action == "ACTION_RESET_STATE" then
		if state.currentRowCancellable then
			state.currentRowCancellable:Cancel()
			state.currentRowCancellable = nil
		end
		if state.statusCancellable then
			state.statusCancellable:Cancel()
			state.statusCancellable = nil
		end
		TSM.Auctioning.Log.Truncate()
		TSM.Auctioning.PostScan.Reset()
		TSM.Auctioning.CancelScan.Reset()
		if state.pendingFuture then
			manager:CancelFuture("pendingFuture")
		end
		if state.scanThreadId then
			Threading.Kill(state.scanThreadId)
			state.scanThreadId = nil
		end
		if state.auctionScan then
			state.auctionScan:Release()
			state.auctionScan = nil
		end
		state.hasLastScan = false
		state.scanNumItems = nil
		state.scanProgress = 0
		state.scanIsPaused = nil
		state.pausePending = nil
		state.isScanning = false
		state.scanType = nil
		state.canStartNewScan = false
	elseif action == "ACTION_AUCTION_HOUSE_CLOSED" then
		manager:ProcessAction("ACTION_SELECTION_FRAME_HIDDEN")
		manager:ProcessAction("ACTION_SCAN_FRAME_HIDDEN")
		manager:ProcessAction("ACTION_STOP_SCANNING")
	else
		error("Unknown action: "..tostring(action))
	end
end

function private.StartLinkedItemScan(state, itemLink)
	if not state.selectionFrame and not state.canStartNewScan then
		return false
	elseif not AuctionScan.AcquireLock(L["Auctioning"]) then
		return false
	end
	wipe(private.scanContext)
	private.scanContext.isItems = true
	tinsert(private.scanContext, Group.TranslateItemString(ItemString.Get(itemLink)))
	private.StartScanHelper(state, "POST")
	return true
end

---@param state AuctioningUIState
function private.StartGroupScan(state, scanType)
	if not AuctionScan.AcquireLock(L["Auctioning"]) then
		return
	end
	wipe(private.scanContext)
	for _, groupPath in state.selectionFrame:GetElement("groupSelection.groupTree"):SelectedGroupsIterator() do
		tinsert(private.scanContext, groupPath)
	end
	private.StartScanHelper(state, scanType)
end

---@param state AuctioningUIState
function private.StartPostBagsScan(state)
	if not AuctionScan.AcquireLock(L["Auctioning"]) then
		return
	end
	wipe(private.scanContext)
	private.scanContext.isItems = true
	for autoBaseItemString in state.selectionFrame:GetElement("content.bottom.bagScrollingTable"):SelectedItemsIterator() do
		tinsert(private.scanContext, autoBaseItemString)
	end
	private.StartScanHelper(state, "POST")
end

---@param state AuctioningUIState
function private.StartSearchListScan(state, listType, index)
	if not AuctionScan.AcquireLock(L["Auctioning"]) then
		return
	end
	local searchType, filter = private.GetSearchListFields(listType, index, "searchType", "filter")
	wipe(private.scanContext)
	private.scanContext.isItems = searchType == "postItems" or nil
	TSM.Auctioning.SavedSearches.FiltersToTable(filter, private.scanContext)
	private.StartScanHelper(state, searchType == "cancelGroups" and "CANCEL" or "POST")
end

---@param state AuctioningUIState
function private.StartScanHelper(state, scanType)
	private.manager:ProcessAction("ACTION_START_SCAN", scanType, private.scanContext)
end

---@param state AuctioningUIState
function private.UpdateScanFrame(state)
	if not state.scanFrame then
		return
	end

	local bottom = state.scanFrame:GetElement("bottom")
	state.scanFrame:GetElement("header.content.item.cost"):SetShown(state.scanType == "POST")
	if state.canProcess then
		bottom:GetElement("processBtn"):SetShown(not state.canStartNewScan)
		bottom:GetElement("skipBtn"):SetShown(not state.canStartNewScan)
		bottom:GetElement("rescanBtn"):SetShown(state.canStartNewScan)
	else
		bottom:GetElement("processBtn"):SetShown(true)
		bottom:GetElement("skipBtn"):SetShown(true)
		bottom:GetElement("rescanBtn"):SetShown(false)
	end
	bottom:Draw()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param state AuctioningUIState
function private.UpdateLogSelectedIndex(state)
	state.scanFrame:GetElement("tabs.logFrame.log"):SetSelectedIndex(state.currentRowAuctionId)
end

---@param state AuctioningUIState
function private.StateToAuctionDuration(state)
	if not state.scanType or not state.currentRowDuration then
		return nil
	end
	if state.scanType == "POST" then
		return AuctionHouse.DURATIONS[state.currentRowDuration]
	elseif state.scanType == "CANCEL" then
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
			return _G["AUCTION_TIME_LEFT"..state.currentRowDuration]
		end
		local duration = state.currentRowDuration - time()
		if duration < SECONDS_PER_MIN then
			return duration.."s"
		elseif duration < SECONDS_PER_HOUR then
			return floor(duration / SECONDS_PER_MIN).."m"
		elseif duration < SECONDS_PER_DAY then
			return floor(duration / SECONDS_PER_HOUR).."h"
		else
			return floor(duration / SECONDS_PER_DAY).."d"
		end
	else
		error("Invalid scanType: "..tostring(state.scanType))
	end
end

---@param state AuctioningUIState
function private.StateToQuantityText(state)
	if not state.currentRowNumStacks or not state.currentRowNumProcessed or not state.currentRowStackSize then
		return "-"
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		return format(L["%d of %d"], state.currentRowNumStacks - state.currentRowNumProcessed, state.currentRowStackSize)
	else
		return tostring(state.currentRowStackSize)
	end
end

---@param currentRow DatabaseRow
function private.CurrentRowToDepositCost(currentRow)
	if not currentRow then
		return nil
	end
	local itemString, postTime, stackSize, bid, buyout = currentRow:GetFields("itemString", "postTime", "stackSize", "bid", "buyout")
	return AuctionHouseUIUtils.CalculateDeposit(itemString, true, postTime, stackSize, bid, buyout)
end

---@param state AuctioningUIState
function private.StateToProgressText(state)
	if not state.canProcess then
		-- We're scanning or pausing
		if state.pausePending then
			return state.scanIsPaused and L["Resuming Scan..."] or L["Pausing Scan..."]
		else
			return state.scanNumItems and format(L["Scanning (%d Items)"], state.scanNumItems) or L["Starting Scan..."]
		end
	elseif state.statusNumConfirmed == state.statusTotalNum then
		-- We're completely done
		if state.scanType == "POST" then
			return L["Done Posting"]
		elseif state.scanType == "CANCEL" then
			return L["Done Canceling"]
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
	elseif state.statusNumProcessed == state.statusTotalNum then
		-- We're done processing and just confirming
		return format(L["Confirming %d / %d"], state.statusNumConfirmed + 1, state.statusTotalNum)
	else
		-- We're done (or paused) scanning so start Posting/Canceling
		local progressFmtStr = nil
		if state.scanType == "POST" then
			progressFmtStr = (state.scanIsPaused and (L["Scan Paused"].." | ") or "")..L["Posting %d / %d"]
		elseif state.scanType == "CANCEL" then
			progressFmtStr = (state.scanIsPaused and (L["Scan Paused"].." | ") or "")..L["Canceling %d / %d"]
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		if state.statusNumProcessed == state.statusNumConfirmed then
			return format(progressFmtStr, state.statusNumProcessed + 1, state.statusTotalNum)
		else
			return format(progressFmtStr.." ("..L["Confirming %d / %d"]..")", state.statusNumProcessed + 1, state.statusTotalNum, state.statusNumConfirmed + 1, state.statusTotalNum)
		end
	end
end

function private.LogIndexIconVirtualField(row)
	if row:GetField("state") == "PENDING" then
		-- color the circle icon to match the color of the text
		return TextureAtlas.GetColoredKey("iconPack.12x12/Circle", TSM.Auctioning.Log.GetColorFromReasonKey(row:GetField("reasonKey")))
	else
		return "iconPack.12x12/Checkmark/Default"
	end
end

function private.MarketValueFunction(row)
	local value = CustomString.GetValue("dbmarket", row:GetItemString() or row:GetBaseItemString())
	return value
end

function private.GetSearchListFields(listType, index, ...)
	local query = nil
	if listType == "RECENT" then
		query = TSM.Auctioning.SavedSearches.CreateRecentSearchesQuery()
	elseif listType == "FAVORITE" then
		query = TSM.Auctioning.SavedSearches.CreateFavoriteSearchesQuery()
	else
		error("Invalid search list type: "..tostring(listType))
	end
	return query
		:Select(...)
		:Equal("index", index)
		:GetFirstResultAndRelease()
end
