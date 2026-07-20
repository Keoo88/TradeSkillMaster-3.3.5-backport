-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local AuctionBuyScan = LibTSMUI:DefineClassType("AuctionBuyScan")
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local AuctionPostContext = LibTSMUI:From("LibTSMService"):IncludeClassType("AuctionPostContext")
local AuctionScan = LibTSMUI:From("LibTSMService"):Include("AuctionScan")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local Mail = LibTSMUI:From("LibTSMService"):Include("Mail")
local TextureAtlas = LibTSMUI:From("LibTSMService"):Include("UI.TextureAtlas")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")
local Currency = LibTSMUI:From("LibTSMWoW"):Include("API.Currency")
local AuctionHouseWrapper = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouseWrapper")
local DelayTimer = LibTSMUI:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local DefaultUI = LibTSMUI:From("LibTSMWoW"):Include("UI.DefaultUI")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local EnumType = LibTSMUI:From("LibTSMUtil"):Include("BaseType.EnumType")
local Reactive = LibTSMUI:From("LibTSMUtil"):Include("Reactive")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Log = LibTSMUI:From("LibTSMUtil"):Include("Util.Log")
local private = {
	confirmationVisible = false,
}
local SCAN_TYPE = EnumType.New("AUCTION_BUY_SCAN_TYPE", {
	BROWSE = EnumType.NewValue(),
	SNIPER = EnumType.NewValue(),
})
local RETAIL_FIND_RESULT_PLACEHOLDER = {}
local COPPER_PER_SILVER = 100
local STATE_SCHEMA = Reactive.CreateStateSchema("AUCTION_BUY_SCAN_STATE")
	:AddOptionalEnumField("scanType", SCAN_TYPE)
	:AddStringField("scanTypeName", "")
	:AddOptionalTableField("bottomFrame")
	:AddBooleanField("canSendAuctionQuery", true)
	:AddOptionalTableField("auctionScrollTable")
	:AddNumberField("scanProgress", 0)
	:AddOptionalNumberField("scanNumItems")
	:AddOptionalBooleanField("scanIsPaused")
	:AddOptionalBooleanField("pausePending")
	:AddBooleanField("selectionChanging", false)
	:AddOptionalTableField("selectedAuction")
	:AddBooleanField("selectionCanBid", false)
	:AddBooleanField("selectionCanBuy", false)
	:AddBooleanField("selectionCanCancel", false)
	:AddBooleanField("selectionCanPost", false)
	:AddOptionalTableField("auctionScan")
	:AddOptionalTableField("searchContext")
	:AddOptionalStringField("findHash")
	:AddOptionalTableField("findResult")
	:AddBooleanField("findHashIsSelection", false)
	:AddBooleanField("isSearchingForSelection", false)
	:AddNumberField("numFound", 0)
	:AddNumberField("maxQuantity", 0)
	:AddNumberField("defaultBuyQuantity", 0)
	:AddNumberField("lastBuyQuantity", 0)
	:AddOptionalNumberField("lastBuyIndex")
	:AddOptionalTableField("pendingFuture")
	:AddBooleanField("isConfirming", false)
	:AddNumberField("numCanBuy", 0)
	:AddNumberField("numBought", 0)
	:AddNumberField("numBid", 0)
	:AddNumberField("numBidOrBought", 0)
	:AddNumberField("numConfirmed", 0)
	:AddBooleanField("canPost", false)
	:AddBooleanField("canCancel", false)
	:AddBooleanField("cancelShown", false)
	:AddBooleanField("postDialogShown", false)
	:AddNumberField("postDuration", 2)
	:AddBooleanField("pendingBuyOnFind", false)
	:AddBooleanField("pendingBidOnFind", false)
	-- 3.3.5: marker that current findResult is a sentinel from the click-handler
	-- (subRow selected but no real find performed yet). Cleared once a real find runs.
	:AddBooleanField("findDeferred", false)
	:AddBooleanField("isGatheringScan", false)
	:Commit()



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new auction buy scan object for a shopping scan.
---@param scanTypeName string The name of the type of scan to use for locking
---@param isPlayerFunc fun(characterName: string, includeAlts: boolean): boolean Function which checks if a character belongs to the player
---@param alertThresholdFunc fun(itemString: string): number Function to get the confirmation alert threshold for an item
---@return AuctionBuyScan
function AuctionBuyScan.__static.NewBrose(scanTypeName, isPlayerFunc, alertThresholdFunc)
	return AuctionBuyScan(SCAN_TYPE.BROWSE, scanTypeName, isPlayerFunc, alertThresholdFunc)
end

---Creates a new auction buy scan object for a sniper scan.
---@param scanTypeName string The name of the type of scan to use for locking
---@param isPlayerFunc fun(characterName: string, includeAlts: boolean): boolean Function which checks if a character belongs to the player
---@return AuctionBuyScan
function AuctionBuyScan.__static.NewSniper(scanTypeName, isPlayerFunc)
	return AuctionBuyScan(SCAN_TYPE.SNIPER, scanTypeName, isPlayerFunc)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function AuctionBuyScan.__private:__init(scanType, scanTypeName, isPlayerFunc, alertThresholdFunc)
	self._isPlayerFunc = isPlayerFunc ---@type fun(characterName: string, includeAlts: boolean): boolean
	self._alertThresholdFunc = alertThresholdFunc

	local state = STATE_SCHEMA:CreateState()
	state.scanType = scanType
	state.scanTypeName = scanTypeName
	self._state = state
	self._manager = UIManager.Create("AUCTION_BUY_"..scanTypeName, state, self:__closure("_ActionHandler"))
		:SuppressActionLog("ACTION_SCAN_PROGRESS_UPDATED")
		:SuppressActionLog("ACTION_BAG_QUANTITY_UPDATED")
		:SuppressActionLog("ACTION_AUCTION_ID_UPDATED")
		:SuppressActionLog("ACTION_AUCTION_SELECTION_CHANGED")
	self._selectionPostContext = AuctionPostContext.New()
	self._selectionDelayTimer = DelayTimer.New("AUCTION_BUY_SCAN_SELECTION_DELAY_"..scanTypeName, self._manager:CallbackToProcessAction("ACTION_AUCTION_SELECTION_CHANGED_DELAYED"))
	self._restartDelayTimer = DelayTimer.New("AUCTION_BUY_SCAN_RESTART_DELAY_"..scanTypeName, self._manager:CallbackToProcessAction("ACTION_RESTART_DELAYED"))

	BagTracking.RegisterQuantityCallback(self._manager:CallbackToProcessAction("ACTION_BAG_QUANTITY_UPDATED"))
	AuctionHouseWrapper.RegisterAuctionIdUpdateCallback(self._manager:CallbackToProcessAction("ACTION_AUCTION_ID_UPDATED"))
	if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
		AuctionHouseWrapper.RegisterCanSendAuctionQueryCallback(function(canSendAuctionQuery)
			state.canSendAuctionQuery = canSendAuctionQuery
		end)
	end
	DefaultUI.RegisterAuctionHouseVisibleCallback(self._manager:CallbackToProcessAction("ACTION_END_SEARCH"), false)

	self._manager:SetStateFromExpression("numBidOrBought", [[numBid + numBought]])
	self._manager:SetStateFromExpression("isSearchingForSelection", [[selectedAuction ~= nil and not findResult]])
	self._manager:SetStateFromExpression("numCanBuy", [[not findHashIsSelection and 0 or (numFound - numBidOrBought)]])
	self._manager:SetStateFromExpression("isConfirming", [[numConfirmed < numBidOrBought]])
	self._manager:SetStateFromExpression("canPost", [[auctionScan ~= nil and pausePending ~= true and not isSearchingForSelection and selectionCanPost and not isConfirming and (selectedAuction ~= nil or (not scanIsPaused and scanProgress == 1)) or false]])
	self._manager:SetStateFromExpression("canCancel", [[auctionScan ~= nil and pausePending ~= true and not isSearchingForSelection and selectionCanCancel]])
	self._manager:SetStateFromExpression("cancelShown", [[canCancel and not pendingFuture and canSendAuctionQuery]])

	self._manager:ProcessActionFromPublisher("ACTION_HIDE_POST_DIALOG", state:PublisherForKeyChange("canPost")
		:IgnoreIfNotEquals(false)
	)
	self._manager:ProcessActionFromPublisher("ACTION_UPDATE_CANCEL_BUTTON", state:PublisherForKeyChange("cancelShown"))
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Creates the buttom UI frame element for a browse scan with the state hooked up to the AuctionBuyScan object.
---@return Frame
function AuctionBuyScan:CreateBottomUIFrameForBrowse()
	local bottomFrame = UIElements.New("Frame", "bottom")
		:SetLayout("HORIZONTAL")
		:SetHeight(40)
		:SetPadding(8)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:SetManager(self._manager)
		:AddChild(UIElements.New("ActionButton", "pauseResumeBtn")
			:SetSize(24, 24)
			:SetMargin(0, 8, 0, 0)
			:SetText(TextureAtlas.GetTextureLink("iconPack.18x18/PlayPause"))
			:SetDisabledPublisher(self._state:PublisherForExpression([[(not scanIsPaused and scanProgress == 1) or pausePending ~= nil]]))
			:SetHighlightLockedPublisher(self._state:PublisherForExpression([[pausePending ~= nil]]))
			:SetAction("OnClick", "ACTION_PAUSE_RESUME_CLICKED")
		)
		:AddChild(UIElements.New("ProgressBar", "progressBar")
			:SetHeight(24)
			:SetMargin(0, 8, 0, 0)
			:SetProgressPublisher(self._state:PublisherForExpression([[((not auctionScan or isSearchingForSelection) and 0) or (selectedAuction and numConfirmed / (numFound > 0 and numFound or 1)) or (scanProgress == 1 and 0) or scanProgress]]))
			:SetTextPublisher(self._state:PublisherForKeys("auctionScan", "isSearchingForSelection", "pausePending", "selectedAuction", "isConfirming", "numCanBuy", "numBidOrBought", "numFound", "numConfirmed", "selectionCanBuy", "pendingFuture", "canPost", "canCancel", "scanIsPaused", "scanProgress", "scanNumItems")
				:MapWithFunction(private.StateToProgressText)
			)
			:SetProgressIconHiddenPublisher(self._state:PublisherForExpression([[auctionScan ~= nil and not pausePending and not isSearchingForSelection and not isConfirming and not pendingFuture and (selectedAuction ~= nil or scanProgress == 1 or scanIsPaused) or false]]))
		)
		:AddChild(UIElements.New("ActionButton", "postBtn")
			:SetSize(107, 24)
			:SetMargin(0, 8, 0, 0)
			:SetText(L["Post"])
			:SetDisabledPublisher(self._state:PublisherForExpression([[not canPost or pendingFuture ~= nil or not canSendAuctionQuery]]))
			:SetAction("OnClick", "ACTION_POST_AUCTION")
		)
		:AddChild(UIElements.New("VerticalLine", "line")
			:SetHeight(24)
			:SetMargin(0, 8, 0, 0)
		)
		:AddChild(UIElements.New("ActionButton", "bidBtn")
			:SetSize(107, 24)
			:SetMargin(0, 8, 0, 0)
			:SetText(L["Bid"])
			:SetDisabledPublisher(self._state:PublisherForExpression([[not auctionScan or pausePending == true or isSearchingForSelection or not selectionCanBid or pendingFuture ~= nil or (isConfirming and numCanBuy == 0) or not canSendAuctionQuery]]))
			:SetAction("OnClick", "ACTION_BID_AUCTION")
		)
		:AddChild(UIElements.NewNamed("ActionButton", "buyoutBtn", "TSMShoppingBuyoutBtn")
			:SetSize(107, 24)
			:SetText(L["Buyout"])
			:DisableClickCooldown(true)
			:SetDisabledPublisher(self._state:PublisherForExpression([[not auctionScan or pausePending == true or isSearchingForSelection or not selectionCanBuy or pendingFuture ~= nil or (isConfirming and numCanBuy == 0) or not canSendAuctionQuery]]))
			:SetAction("OnClick", "ACTION_BUY_AUCTION")
		)
		:AddChild(UIElements.New("ActionButton", "cancelBtn")
			:SetSize(107, 24)
			:SetText(L["Cancel"])
			:DisableClickCooldown(true)
			:SetDisabledPublisher(self._state:PublisherForKeyChange("cancelShown"):InvertBoolean())
			:SetAction("OnClick", "ACTION_CANCEL_AUCTION")
		)
		:SetScript("OnUpdate", self._manager:CallbackToProcessAction("ACTION_BOTTOM_FRAME_SHOWN"))
		:SetScript("OnHide", self._manager:CallbackToProcessAction("ACTION_BOTTOM_FRAME_HIDDEN"))
	assert(not self._state.bottomFrame)
	self._state.bottomFrame = bottomFrame
	return bottomFrame
end

---Creates the buttom UI frame element with the state hooked up to the AuctionBuyScan object.
---@param showBuyoutButton boolean Whether to show the buyout button (vs. the bid button)
---@return Frame
function AuctionBuyScan:CreateBottomUIFrameForSniper(showBuyoutButton)
	local bottomFrame = UIElements.New("Frame", "bottom")
		:SetLayout("HORIZONTAL")
		:SetHeight(40)
		:SetPadding(8)
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:SetManager(self._manager)
		:AddChild(UIElements.New("ActionButton", "pauseResumeBtn")
			:SetSize(24, 24)
			:SetMargin(0, 8, 0, 0)
			:SetText(TextureAtlas.GetTextureLink("iconPack.18x18/PlayPause"))
			:SetHighlightLockedPublisher(self._state:PublisherForExpression([[pausePending ~= nil]]))
			:SetAction("OnClick", "ACTION_PAUSE_RESUME_CLICKED")
		)
		:AddChild(UIElements.New("ProgressBar", "progressBar")
			:SetHeight(24)
			:SetMargin(0, 8, 0, 0)
			:SetProgressPublisher(self._state:PublisherForExpression([[((not auctionScan or isSearchingForSelection) and 0) or (selectedAuction and numConfirmed / (numFound > 0 and numFound or 1)) or (scanProgress == 1 and 0) or scanProgress]]))
			:SetTextPublisher(self._state:PublisherForKeys("auctionScan", "isSearchingForSelection", "pausePending", "selectedAuction", "isConfirming", "numCanBuy", "numBidOrBought", "numFound", "numConfirmed", "selectionCanBuy", "pendingFuture", "canPost", "canCancel", "scanIsPaused", "scanProgress", "scanNumItems")
				:MapWithFunction(private.StateToProgressText)
			)
			:SetProgressIconHiddenPublisher(self._state:PublisherForExpression([[auctionScan ~= nil and not pausePending and not isSearchingForSelection and not isConfirming and not pendingFuture and (selectedAuction ~= nil or scanProgress == 1 or scanIsPaused) or false]]))
		)
		:AddChild(UIElements.NewNamed("ActionButton", showBuyoutButton and "buyoutBtn" or "bidBtn", "TSMSniperBtn")
			:SetSize(165, 24)
			:SetText(showBuyoutButton and L["Buyout"] or L["Bid"])
			:SetDisabledPublisher(self._state:PublisherForExpression([[not auctionScan or pausePending == true or isSearchingForSelection or not selectionCanBuy or pendingFuture ~= nil or (isConfirming and numCanBuy == 0) or not canSendAuctionQuery]]))
			:SetAction("OnClick", showBuyoutButton and "ACTION_BUY_AUCTION" or "ACTION_BID_AUCTION")
		)
		:SetScript("OnUpdate", self._manager:CallbackToProcessAction("ACTION_BOTTOM_FRAME_SHOWN"))
		:SetScript("OnHide", self._manager:CallbackToProcessAction("ACTION_BOTTOM_FRAME_HIDDEN"))
	assert(not self._state.bottomFrame)
	self._state.bottomFrame = bottomFrame
	return bottomFrame
end

---Attempts to prepare to start a search and returns whether or not it was successful.
---@return boolean
function AuctionBuyScan:PrepareStartSearch()
	return AuctionScan.AcquireLock(self._state.scanTypeName)
end

---Sets a new search.
---@param searchContext AuctionSearchContext The search context
function AuctionBuyScan:StartSearch(searchContext)
	self._manager:ProcessAction("ACTION_START_SEARCH", searchContext)
end

---Ends the current search.
function AuctionBuyScan:EndSearch()
	self._manager:ProcessAction("ACTION_END_SEARCH")
end

---Sets the auction scroll table element
---@param auctionScrollTable AuctionScrollTable
function AuctionBuyScan:SetAuctionScrollTable(auctionScrollTable)
	self._manager:ProcessAction("ACTION_SET_SCROLL_TABLE", auctionScrollTable)
end

---Show the posting dialog to post an auction.
function AuctionBuyScan:PostAuction()
	self._manager:ProcessAction("ACTION_POST_AUCTION")
end

---Gets the current search context.
---@return AuctionSearchContext
function AuctionBuyScan:GetSearchContext()
	return self._state.searchContext
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager
---@param state AuctionBuyScanState
function AuctionBuyScan.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_START_SEARCH" then
		local searchContext = ...
		local resolveSellers = nil
		if state.scanType == SCAN_TYPE.BROWSE then
			resolveSellers = LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()
		elseif state.scanType == SCAN_TYPE.SNIPER then
			resolveSellers = false
		else
			error("Invalid scan type: "..tostring(state.scanType))
		end
		manager:ProcessAction("ACTION_RESET_STATE")
		state.searchContext = searchContext
		state.isGatheringScan = searchContext:GetGatheringResultsFunc() ~= nil
		assert(not state.auctionScan)
		state.auctionScan = AuctionScan.GetManager()
			:SetUIManager(manager)
			:SetResolveSellers(resolveSellers)
			:SetAction("OnProgressUpdate", "ACTION_SCAN_PROGRESS_UPDATED")
			:SetAction("OnNumItemsChanged", "ACTION_SCAN_NUM_ITEMS_CHANGED")
		if state.isGatheringScan then
			state.auctionScan:SetAction("OnQueryDone", "ACTION_GATHERING_QUERY_DONE")
		end
		searchContext:StartThread(manager:CallbackToProcessAction("ACTION_SCAN_COMPLETE"), state.auctionScan)
		searchContext:OnStateChanged("SCANNING")
	elseif action == "ACTION_RESET_STATE" then
		if state.searchContext then
			state.searchContext:KillThread()
			state.searchContext:OnStateChanged("DONE")
			state.searchContext = nil
		end
		if state.pendingFuture then
			manager:CancelFuture("pendingFuture")
		end
		state.findHash = nil
		state.findResult = nil
		state.scanNumItems = nil
		state.scanProgress = 0
		state.scanIsPaused = false
		state.pausePending = nil
		state.numFound = 0
		state.maxQuantity = 0
		state.defaultBuyQuantity = 0
		state.lastBuyQuantity = 0
		state.lastBuyIndex = nil
		state.numBought = 0
		state.numBid = 0
		state.numConfirmed = 0
		if state.auctionScrollTable then
			state.auctionScrollTable:SetBatchUpdateMode(false)
		end
		if state.auctionScan then
			state.auctionScan:Release()
			state.auctionScan = nil
		end
		state.isGatheringScan = false
		self._scanPausedForSelection = false
		manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
	elseif action == "ACTION_SET_SCROLL_TABLE" then
		local auctionScrollTable = ...
		if state.auctionScrollTable and state.auctionScrollTable ~= auctionScrollTable then
			state.auctionScrollTable:SetBatchUpdateMode(false)
		end
		state.auctionScrollTable = auctionScrollTable
		if not auctionScrollTable then
			return manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
		end
		auctionScrollTable
			:SetAuctionScan(state.auctionScan)
			:SetMarketValueFunction(state.searchContext:GetMarketValueFunc())
			:SetPctTooltip(state.searchContext:GetPctTooltip())
			:SetSelectionDisabledPublisher(state:PublisherForKeyChange("isConfirming"))
			:SetManager(manager)
			:SetAction("OnSelectionChanged", "ACTION_AUCTION_SELECTION_CHANGED")
		if state.isGatheringScan then
			auctionScrollTable:SetBatchUpdateMode(true)
		end
		if state.scanType == SCAN_TYPE.SNIPER then
			auctionScrollTable:SetAction("OnRowRemoved", "ACTION_AUCTION_ROW_REMOVED")
		end
		if state.scanProgress == 1 then
			auctionScrollTable:ExpandSingleResult()
		end
		if state.selectedAuction and not auctionScrollTable:GetSelectedRow() then
			auctionScrollTable:SetSelectedRow(state.selectedAuction)
		end
	elseif action == "ACTION_SCAN_PROGRESS_UPDATED" then
		local scanProgress, scanIsPaused = state.auctionScan:GetProgress()
		if state.scanType == SCAN_TYPE.SNIPER then
			-- Ignore scan progress for sniper scans
			scanProgress = 0
		end
		state.scanProgress = scanProgress
		state.scanIsPaused = scanIsPaused
		if state.pausePending ~= nil and state.scanIsPaused == state.pausePending then
			state.pausePending = nil
			-- 3.3.5 sniper FIRST-selection hang fix: the selection handler now starts the
			-- find directly, so only fire it here when one hasn't already been started for
			-- the current selection (findHashIsSelection is set true by
			-- ACTION_FIND_SELECTED_AUCTION). Re-firing would reset findResult and flicker
			-- the buttons back to "Finding Selected Auction". Browse still relies on this
			-- path: findHashIsSelection is false for a fresh browse selection, so it fires.
			if state.scanIsPaused and state.selectedAuction and not state.findHashIsSelection then
				manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			end
		end
	elseif action == "ACTION_SCAN_NUM_ITEMS_CHANGED" then
		state.scanNumItems = state.auctionScan:GetNumItems()
	elseif action == "ACTION_PAUSE_RESUME_CLICKED" then
		-- 3.3.5 sniper: the pause/resume button isn't disabled while a transition
		-- is pending (unlike browse), and pausePending can get stuck (sniper pins
		-- scanProgress to 0, so the scan thread may never re-enter _Pause to fire
		-- the reconciling progress update). A click while pending would otherwise
		-- re-enter ACTION_PAUSE_SCAN / ACTION_RESUME_SCAN and trip their assert.
		-- Treat such a click as an unstick: resync to live progress, clear the
		-- stale pending flag, and if the actual state differs from the pending one,
		-- continue to toggle the scan state.
		if state.pausePending ~= nil then
			local scanProgress, scanIsPaused = state.auctionScan:GetProgress()
			state.scanProgress = scanProgress
			state.scanIsPaused = scanIsPaused
			local pending = state.pausePending
			state.pausePending = nil
			if scanIsPaused == pending then
				return
			end
		end
		if state.selectedAuction then
			state.auctionScan:Cancel()
			AuctionScan.StopFindThread(true)
			state.findHash = nil
			manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
			if state.auctionScrollTable then
				state.auctionScrollTable:SetSelectedRow(nil)
			end
		end
		-- 3.3.5 off-page buyout fix: this click manages the pause itself, so drop the
		-- selection-pause marker to avoid a later double-resume.
		self._scanPausedForSelection = false
		manager:ProcessAction(state.scanIsPaused and "ACTION_RESUME_SCAN" or "ACTION_PAUSE_SCAN")
	elseif action == "ACTION_PAUSE_SCAN" then
		-- 3.3.5 sniper: a stale pending transition can survive (the reconciling
		-- progress update may never arrive when scanProgress is pinned to 0), and
		-- the sniper pause/resume button isn't disabled while pending, so this can
		-- be re-entered with pausePending set. Clear it instead of asserting.
		if state.pausePending ~= nil then
			state.pausePending = nil
		end
		state.pausePending = true
		state.auctionScan:SetPaused(true)
		-- 3.3.5: a completed browse scan has no live thread left to actually pause,
		-- so no further progress update arrives to clear pausePending and the
		-- progress text gets stuck on "Pausing Scan...". Reconcile now from live progress.
		do
			local scanProgress, scanIsPaused = state.auctionScan:GetProgress()
			state.scanProgress = scanProgress
			state.scanIsPaused = scanIsPaused
			if scanProgress == 1 and not scanIsPaused then
				state.pausePending = nil
			elseif state.scanType == SCAN_TYPE.SNIPER and scanIsPaused then
				-- 3.3.5: sniper pins scanProgress to 0, so the scanProgress==1 path above
				-- never fires. The scan loops between passes and may not enter _Pause(),
				-- meaning no further progress update is guaranteed. If the live paused flag
				-- already matches the requested pause, reconcile now so the progress text
				-- doesn't get stuck on "Pausing Scan...". The find for a selected lot is now
				-- started directly by the selection handler, so we must NOT also fire it here
				-- -- doing both double-fires the find and flickers the buttons back to
				-- "Finding Selected Auction".
				state.pausePending = nil
			end
		end
	elseif action == "ACTION_RESUME_SCAN" then
		-- 3.3.5 sniper: clear a stale pending transition instead of asserting
		-- (see ACTION_PAUSE_SCAN); pausePending can be left set when the
		-- reconciling progress update never arrives on a pinned-progress sniper.
		if state.pausePending ~= nil then
			state.pausePending = nil
		end
		state.pausePending = false
		state.auctionScan:SetPaused(false)
		-- 3.3.5: if the scan already finished (single quick browse on classic),
		-- SetPaused won't trigger another progress update, so pausePending would
		-- stay false forever and the UI would be stuck on "Resuming Scan...".
		-- Reconcile immediately from the live scan progress.
		do
			local scanProgress, scanIsPaused = state.auctionScan:GetProgress()
			state.scanProgress = scanProgress
			state.scanIsPaused = scanIsPaused
			if scanProgress == 1 and not scanIsPaused then
				state.pausePending = nil
			elseif state.scanType == SCAN_TYPE.SNIPER and not scanIsPaused then
				-- 3.3.5: sniper pins scanProgress to 0, so the scanProgress==1 path above
				-- never fires. When the scan wasn't actually paused (common race after a
				-- find-on-demand buy), the scan thread never re-enters _Pause() and no
				-- further OnProgressUpdate arrives, leaving pausePending stuck at false and
				-- the bottom bar frozen on "Resuming Scan...". The live paused flag already
				-- reflects the resumed state, so reconcile now.
				state.pausePending = nil
			end
		end
	elseif action == "ACTION_GATHERING_QUERY_DONE" then
		if state.auctionScrollTable then
			state.auctionScrollTable:FlushBatchUpdate()
		end
	elseif action == "ACTION_SCAN_COMPLETE" then
		local success = ...
		assert(state.scanType == SCAN_TYPE.BROWSE)
		if state.auctionScrollTable then
			state.auctionScrollTable:FlushBatchUpdate()
			state.auctionScrollTable:SetBatchUpdateMode(false)
		end
		AuctionScan.ReleaseLock(state.scanTypeName)
		state.searchContext:OnStateChanged("RESULTS")
		local postContext = self:_GetPostContext()
		if postContext then
			postContext:UpdateFromScan(state.auctionScan)
			state.selectionCanPost = postContext:CanPost() or false
		end
		if success and state.auctionScrollTable then
			state.auctionScrollTable:ExpandSingleResult()
		end
		if not success then
			state.scanProgress = 1
		end
	elseif action == "ACTION_RESTART_DELAYED" then
		if state.selectedAuction or not state.auctionScan then
			return
		end
		state.searchContext:StartThread(manager:CallbackToProcessAction("ACTION_SCAN_COMPLETE"), state.auctionScan)
		state.searchContext:OnStateChanged("SCANNING")
	elseif action == "ACTION_BOTTOM_FRAME_SHOWN" then
		local frame = ...
		frame:SetScript("OnUpdate", nil)
		if not state.cancelShown and state.bottomFrame and state.bottomFrame:HasChildById("cancelBtn") then
			state.bottomFrame:GetElement("cancelBtn"):Hide()
			state.bottomFrame:Draw()
		end
	elseif action == "ACTION_BOTTOM_FRAME_HIDDEN" then
		state.bottomFrame = nil
	elseif action == "ACTION_UPDATE_CANCEL_BUTTON" then
		if state.cancelShown then
			AuctionHouseWrapper.AutoQueryOwnedAuctions()
		end
		if state.bottomFrame and state.bottomFrame:HasChildById("cancelBtn") then
			state.bottomFrame:GetElement("buyoutBtn"):SetShown(not state.cancelShown)
			state.bottomFrame:GetElement("cancelBtn"):SetShown(state.cancelShown)
			state.bottomFrame:Draw()
		end
	elseif action == "ACTION_AUCTION_ROW_REMOVED" then
		local row = ...
		if not row:IsSubRow() then
			return
		end
		row:GetResultRow():RemoveSubRow(row)
	elseif action == "ACTION_AUCTION_SELECTION_CHANGED" then
		-- Delay selection updates so we can completely cancel find queries before starting new ones
		state.selectionChanging = true
		self._selectionDelayTimer:RunForFrames(0)
	elseif action == "ACTION_AUCTION_SELECTION_CHANGED_DELAYED" then
		state.selectionChanging = false
		if not state.auctionScrollTable then
			return
		end
		local selection = state.auctionScrollTable:GetSelectedRow()
		state.numBid = 0
		state.numBought = 0
		state.numConfirmed = 0
		if not selection then
			if state.selectedAuction then
				AuctionScan.StopFindThread(false)
				manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
			end
			-- 3.3.5 off-page buyout fix: if we paused the sniper to query/keep the
			-- selected lot on the native list, resume it now that nothing is selected.
			if self._scanPausedForSelection then
				self._scanPausedForSelection = false
				if state.scanIsPaused or state.pausePending == true then
					manager:ProcessAction("ACTION_RESUME_SCAN")
				end
			end
			return
		end
		manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", selection)
		if state.scanProgress < 1 then
			if state.pausePending == true then
				-- Wait for the pause / resume to complete
				return
			end
			-- 3.3.5: FindAuctionClassic ищет на current page и при необходимости делает
			-- свой per-item query — не нужно ждать паузы основного скана. Это убирает
			-- задержку в 1-2 сек между кликом и активацией кнопок Buy/Bid.
			if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
				if not selection:IsSubRow() then
					-- Just wait until we scan this row
					if state.scanIsPaused then
						-- Resume the scan
						manager:ProcessAction("ACTION_RESUME_SCAN")
					end
				else
					-- 3.3.5 sniper buyout fix (reliable path): PAUSE the scan so its GetAll
					-- browse stops rewriting the native "list", then locate the selected lot
					-- on the now-settled list. Pausing fires ACTION_FIND_SELECTED_AUCTION via
					-- the pause-complete handler; on classic that find stays on the current
					-- page with NO extra query when the lot is already there, and only does a
					-- per-item query for an off-page accumulated lot -- which is safe now
					-- because the scan stays paused, so nothing overwrites the list before the
					-- click. The Buy/Bid CLICK then re-validates the index and places the
					-- protected PlaceAuctionBid synchronously in its OWN hardware-event stack --
					-- the only timing Warmane accepts. This is the exact flow the working
					-- Browse tab uses. The earlier no-pause sentinel raced the live scan: at
					-- click the list wasn't settled, the synchronous locate found nothing, and
					-- the click fell back to the async find whose bid Warmane silently drops
					-- (the "BUYDBG ... NO new query" line that still ended in "Failed to buy").
					-- Keep the scan paused until the buy finishes; it is resumed on
					-- success / deselect / pause-button.
					self._scanPausedForSelection = true
					-- 3.3.5 sniper FIRST-selection hang fix: do NOT depend on the pause-complete
					-- progress update to start the find. ACTION_PAUSE_SCAN's reconcile clears
					-- pausePending the instant raw scanProgress reads 1 (which the sniper hits
					-- between GetAll passes), so the later real-pause progress update finds
					-- pausePending already nil and never fires the find -- the FIRST selected lot
					-- then sticks forever on "Finding Selected Auction" and only recovers when
					-- another lot is clicked (scan already paused -> direct-find path). The find
					-- thread waits for CanSendQuery itself, so request the pause (to stop the
					-- GetAll rewriting the native list) and start the find right away.
					if not state.scanIsPaused then
						manager:ProcessAction("ACTION_PAUSE_SCAN")
					end
					manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
				end
			elseif not selection:IsSubRow() then
				-- Just wait until we scan this row
				if state.scanIsPaused then
					-- Resume the scan
					manager:ProcessAction("ACTION_RESUME_SCAN")
				end
			elseif state.scanIsPaused then
				-- Scan already paused, so just find the new selection
				manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			else
				-- Pause the scan first
				manager:ProcessAction("ACTION_PAUSE_SCAN")
			end
		else
			assert(selection:IsSubRow())
			-- Find the auction
			manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
		end
	elseif action == "ACTION_SET_SELECTED_AUCTION" then
		local selection = ... ---@type AuctionRow|AuctionSubRow|nil
		-- 3.3.5 multi-buy fix: new selection, so re-arm the one-shot stale-index refind
		-- and the consecutive buy-failure counter
		self._vanishRefindDone = nil
		self._buyoutRetries = nil
		self._findForceQuery = nil
		if selection and selection:IsSubRow() then
			local ownerStr = selection:GetOwnerInfo()
			local isPlayerOrAlt = self._isPlayerFunc(ownerStr, true)
			state.selectedAuction = selection
			state.selectionCanBid = not isPlayerOrAlt and state.auctionScan:CanBid(selection)
			state.selectionCanBuy = not isPlayerOrAlt and state.auctionScan:CanBuy(selection)
			state.selectionCanCancel = (not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and self._isPlayerFunc(ownerStr, false)
			state.findHashIsSelection = state.findHash == selection:GetHashes()
		else
			state.selectedAuction = selection
			state.selectionCanBid = false
			state.selectionCanBuy = false
			state.selectionCanCancel = false
			state.findHashIsSelection = false
			state.findResult = nil
		end
		local postContext = self:_GetPostContext()
		state.selectionCanPost = postContext and postContext:CanPost() or false
	elseif action == "ACTION_FIND_SELECTED_AUCTION" then
		if not AuctionScan.AcquireLock(state.scanTypeName) then
			return
		end
		assert(state.selectedAuction and state.selectedAuction:IsSubRow())
		state.findHash = state.selectedAuction:GetHashes()
		state.findHashIsSelection = true
		state.findResult = nil
		-- 3.3.5 buy-after-buy fix: after a failed buy the client "list" is stale
		-- (bought rows reflowed the server list), so the retry find must skip the
		-- current-page shortcut and do a fresh per-item query. One-shot.
		local forceQuery = self._findForceQuery
		self._findForceQuery = nil
		state.auctionScan:FindAuction(state.selectedAuction, manager:CallbackToProcessAction("ACTION_HANDLE_FIND_RESULT"), false, forceQuery)
	elseif action == "ACTION_HANDLE_FIND_RESULT" then
		local result = ...
		AuctionScan.ReleaseLock(state.scanTypeName)
		if not state.selectedAuction then
			assert(not state.selectedAuction)
			return
		end
		-- Update the selection in case the result rows changed
		if state.findHash ~= state.selectedAuction:GetHashes() then
			-- 3.3.5: hash может меняться async (seller resolve меняет _ownerStr).
			-- Не делаем рекурсивный find — это вызывает infinite loop.
			if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
				state.findHash = state.selectedAuction:GetHashes()
			else
				-- Find the new selected auction
				return manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			end
		end
		if result then
			local itemString = state.selectedAuction:GetItemString()
			local maxQuantity = state.searchContext:GetMaxCanBuy(itemString)
			if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
				state.findResult = result
				state.numFound = min(#result, maxQuantity and Math.Ceil(maxQuantity / state.selectedAuction:GetQuantities()) or math.huge)
				state.maxQuantity = maxQuantity and min(maxQuantity, state.numFound) or 1
				state.defaultBuyQuantity = state.numFound
			else
				local maxCommodity = state.selectedAuction:IsCommodity() and state.selectedAuction:GetResultRow():GetMaxQuantities()
				local numCanBuy = min(maxCommodity or result, maxQuantity or math.huge)
				state.findResult = numCanBuy > 0 and RETAIL_FIND_RESULT_PLACEHOLDER or nil
				state.numFound = numCanBuy
				state.maxQuantity = maxCommodity or 1
				state.defaultBuyQuantity = maxQuantity and min(numCanBuy, maxQuantity) or 1
			end
			state.numBid = 0
			state.numBought = 0
			state.numConfirmed = 0
			-- 3.3.5: продолжаем отложенный buy/bid если find был запущен из кнопки покупки
			if state.pendingBuyOnFind then
				state.pendingBuyOnFind = false
				-- ACTION_BUY_AUCTION will run resume-after-buy on its own success path;
				-- if scan was paused only for find-on-demand, leave the flag so a later
				-- BUYOUT_FUTURE_DONE can resume cleanly.
				return manager:ProcessAction("ACTION_BUY_AUCTION")
			elseif state.pendingBidOnFind then
				state.pendingBidOnFind = false
				return manager:ProcessAction("ACTION_BID_AUCTION")
			end
			if self._resumeAfterFind then
				self._resumeAfterFind = false
				manager:ProcessAction("ACTION_RESUME_SCAN")
			end
		else
			state.pendingBuyOnFind = false
			state.pendingBidOnFind = false
			if self._resumeAfterFind then
				self._resumeAfterFind = false
				manager:ProcessAction("ACTION_RESUME_SCAN")
			end
			if state.selectedAuction:IsSubRow() then
				-- 3.3.5 sniper fix: the find-on-demand reported "not found", but on
				-- Warmane a per-item NAME query can be throttled or seller-resolve can
				-- race, producing a FALSE negative for a lot that is still on the AH.
				-- Before deleting a (possibly real) row, re-check the live native
				-- "list" by identity and only remove it if the lot is genuinely gone.
				local stillThere = false
				if GetNumAuctionItems then
					for i = 1, (GetNumAuctionItems("list") or 0) do
						if state.selectedAuction:EqualsIndex(i, false) or state.selectedAuction:EqualsIndex(i, true) then
							stillThere = true
							break
						end
					end
				end
				if stillThere then
					-- Keep the lot in the results; just drop the selection and resume
					-- so the sniper isn't left stuck on "Finding" / "Scan Paused".
					state.findHash = nil
					if state.auctionScrollTable then
						state.auctionScrollTable:SetSelectedRow(nil)
					end
					manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
					if self._scanPausedForSelection then
						self._scanPausedForSelection = false
						manager:ProcessAction("ACTION_RESUME_SCAN")
					end
				else
					-- Failed to find this auction, so remove it
					local _, rawLink = state.selectedAuction:GetLinks()
					state.selectedAuction:GetResultRow():RemoveSubRow(state.selectedAuction)
					ChatMessage.PrintfUser(L["Failed to find auction for %s, so removing it from the results."], rawLink)
					-- 3.3.5 off-page buyout fix: if the sniper was paused for this selection,
					-- clear it and resume so the scan doesn't stay stuck on "Scan Paused".
					if self._scanPausedForSelection then
						self._scanPausedForSelection = false
						state.findHash = nil
						if state.auctionScrollTable then
							state.auctionScrollTable:SetSelectedRow(nil)
						end
						manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
						manager:ProcessAction("ACTION_RESUME_SCAN")
					end
				end
			elseif state.scanIsPaused then
				-- Clear the selection and resume the scan
				state.findHash = nil
				if state.auctionScrollTable then
					state.auctionScrollTable:SetSelectedRow(nil)
				end
				manager:ProcessAction("ACTION_RESUME_SCAN")
			end
		end
	elseif action == "ACTION_BAG_QUANTITY_UPDATED" then
		if not state.searchContext then
			return
		end
		local postContext = self:_GetPostContext()
		state.selectionCanPost = postContext and postContext:CanPost() or false
	elseif action == "ACTION_AUCTION_ID_UPDATED" then
		if state.selectionChanging then
			return
		end
		local oldAuctionId, newAuctionId, newResultInfo = ...
		if not state.selectedAuction or select(2, state.selectedAuction:GetListingInfo()) ~= oldAuctionId then
			return
		end
		state.selectedAuction:UpdateResultInfo(newAuctionId, newResultInfo)
		state.findHash = state.selectedAuction:GetHashes()
		state.findHashIsSelection = true
	elseif action == "ACTION_BUY_AUCTION" then
		local selection = state.auctionScrollTable:GetSelectedRow()
		-- 3.3.5: proactive find disabled. If findDeferred is set, run find-on-demand
		-- now and have ACTION_HANDLE_FIND_RESULT replay the buy via pendingBuyOnFind.
		-- Pause the main scan first — FindThread shares the AuctionScanManager and
		-- can't send its per-item query while the main scan still holds requestFuture.
		if (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic())
			and (state.findDeferred or not state.findResult) then
			-- 3.3.5 sniper buyout fix: Warmane gates PlaceAuctionBid as a protected
			-- function (ADDON_ACTION_BLOCKED); it only succeeds when called inside the
			-- synchronous call stack of the hardware-event button click. The old path ran
			-- an async find-on-demand thread between the click and the bid, so by the time
			-- PlaceAuctionBid fired (from the scheduler) the hardware-event blessing was
			-- gone and the bid was silently dropped (no gold, no event, 5s timeout).
			-- Mirror TSM 2.8 DoBuyout: locate the lot on the live native "list"
			-- synchronously here, then fall through to bid in the same stack. Only fall
			-- back to the async find when the lot isn't on the current native page.
			local matches = nil
			if selection and selection:IsSubRow() and GetNumAuctionItems then
				for i = 1, (GetNumAuctionItems("list") or 0) do
					if selection:EqualsIndex(i, false) or selection:EqualsIndex(i, true) then
						matches = matches or {}
						tinsert(matches, i)
					end
				end
			end
			if matches then
				state.findDeferred = false
				state.pendingBuyOnFind = false
				self._resumeAfterFind = false
				state.findHash = selection:GetHashes()
				state.findHashIsSelection = true
				state.findResult = matches
				local maxQuantity = state.searchContext:GetMaxCanBuy(selection:GetItemString())
				state.numFound = min(#matches, maxQuantity and Math.Ceil(maxQuantity / selection:GetQuantities()) or math.huge)
				state.maxQuantity = maxQuantity and min(maxQuantity, state.numFound) or 1
				state.defaultBuyQuantity = state.numFound
				state.numBid = 0
				state.numBought = 0
				state.numConfirmed = 0
			else
				state.findDeferred = false
				state.findResult = nil
				state.pendingBuyOnFind = true
				self._resumeAfterFind = not state.scanIsPaused and state.pausePending == nil
				if self._resumeAfterFind then
					manager:ProcessAction("ACTION_PAUSE_SCAN")
				end
				return manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			end
		end
		if not self:_ShowConfirmation(true) then
			-- No confirmation needed
			local numToBuy = selection:GetQuantities()
			manager:ProcessAction("ACTION_BUY_AUCTION_CONFIRMED", numToBuy)
		end
	elseif action == "ACTION_COMMODITY_PRICE_UPDATED" then
		return manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
	elseif action == "ACTION_BUY_AUCTION_CONFIRMED" then
		local quantity = ...
		state.lastBuyQuantity = 0
		state.lastBuyIndex = nil
		-- 3.3.5 fail-loop fix: do NOT reset _buyoutRetries here — every retry click
		-- re-enters this action, so resetting per-click made the consecutive-failure
		-- limit in ACTION_BUYOUT_FUTURE_DONE unreachable. It is reset on success and
		-- on selection change instead.
		local index = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and tremove(state.findResult, #state.findResult) or nil
		if (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and not index then
			-- Didn't find the full amount
			return manager:ProcessAction("ACTION_BUYOUT_FUTURE_DONE", false)
		end
		-- Buy the auction
		local buyout = state.selectedAuction:GetBuyouts()
		if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
			-- Re-validate index right before placing the buy. The list of auctions may
			-- have changed between find-on-demand and the user clicking confirm:
			-- page reflow, other clients, partial buyouts, async seller resolve, etc.
			-- EqualsIndex covers baseItemString + buyout + stackSize + seller.
			-- Two-pass: strict first, then noSeller if the find originally went pass 2.
			local ok = state.selectedAuction:EqualsIndex(index, false)
			if not ok then
				ok = state.selectedAuction:EqualsIndex(index, true)
			end
			if not ok then
				-- 3.3.5 sniper buyout fix (part 4): the lot is no longer at the stored
				-- index because the native "list" shifted during the post-find throttle
				-- wait (seller-resolve / list refresh). Re-locate it by identity across the
				-- whole current list WITHOUT a new query (so the server bid-throttle we just
				-- waited out stays cleared) and bid at the new index instead of giving up.
				local liveTotal = GetNumAuctionItems and GetNumAuctionItems("list") or 0
				for i = 1, liveTotal do
					if state.selectedAuction:EqualsIndex(i, false) or state.selectedAuction:EqualsIndex(i, true) then
						index = i
						ok = true
						break
					end
				end
			end
			if not ok then
				-- 3.3.5 multi-buy fix: when buying several identical lots, the first
				-- successful buyout reflows the AH list (indexes shift, remaining lots
				-- may now live on a different page), so the stored find indexes go stale
				-- and the live-list re-locate above can legitimately miss a REAL lot.
				-- Before giving up, re-run the find once (fresh page walk) and replay
				-- the buy automatically via pendingBuyOnFind. One-shot guarded to avoid
				-- refind loops when the lot is genuinely gone.
				if not self._vanishRefindDone then
					self._vanishRefindDone = true
					state.findHash = nil
					state.findResult = nil
					state.findDeferred = false
					state.pendingBuyOnFind = true
					-- 3.3.5 buy-after-buy fix: the lot vanished from the stored index because
					-- the list reflowed after a buyout — the refind must requery, not re-walk
					-- the same stale current page.
					self._findForceQuery = true
					return manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
				end
				-- Lot vanished between find and confirm. Don't loop through another find
				-- (which would set findResult=nil and freeze the buttons grey for the full
				-- per-item walk). Just remove the row and clear the selection — same UX
				-- as a real find failure, but immediate.
				local _, rawLink = state.selectedAuction:GetLinks()
				ChatMessage.PrintfUser(L["Failed to buy auction of %s."], rawLink)
				if state.selectedAuction:IsSubRow() then
					state.selectedAuction:GetResultRow():RemoveSubRow(state.selectedAuction)
				end
				state.findHash = nil
				state.findResult = nil
				state.findDeferred = false
				state.pendingBuyOnFind = false
				state.pendingBidOnFind = false
				if state.auctionScrollTable then
					state.auctionScrollTable:SetSelectedRow(nil)
				end
				manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
				if self._resumeAfterFind then
					self._resumeAfterFind = false
					manager:ProcessAction("ACTION_RESUME_SCAN")
				end
				return
			end
		end
		local future = state.auctionScan:PlaceBidOrBuyout(index, buyout, state.selectedAuction, quantity)
		if not future then
			return manager:ProcessAction("ACTION_BUYOUT_FUTURE_DONE", false)
		end
		state.lastBuyQuantity = quantity
		state.lastBuyIndex = index
		state.numBought = state.numBought + ((not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and quantity or 1)
		manager:ManageFuture("pendingFuture", future, "ACTION_BUYOUT_FUTURE_DONE")
	elseif action == "ACTION_BUYOUT_FUTURE_DONE" then
		local result = ...
		if not state.selectedAuction then
			-- The selection got cleared while the buy was in flight (e.g. a page
			-- reflow / row removal / leaving the tab), so drop this stale completion
			-- instead of erroring mid-handler, and reset the buy counters so
			-- isConfirming can't get stuck true (which would disable row selection)
			state.numBid = 0
			state.numBought = 0
			state.numConfirmed = 0
			return
		end
		if result then
			-- 3.3.5 multi-buy fix: successful buy, so re-arm the one-shot
			-- stale-index refind and the consecutive-failure counter
			self._vanishRefindDone = nil
			self._buyoutRetries = nil
			Mail.HandleAuctionPurchase(ItemString.ToLevel(state.selectedAuction:GetItemString()), state.lastBuyQuantity)
			state.numConfirmed = min(state.numConfirmed + ((not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and state.lastBuyQuantity or 1), state.numFound)
			manager:ProcessAction("ACTION_REMOVE_BOUGHT_AUCTIONS", state.lastBuyQuantity)
			if state.numConfirmed == state.numFound then
				state.numBid = 0
				state.numBought = 0
				state.numConfirmed = 0
				-- 3.3.5 off-page buyout fix: the buy sequence is done, so resume the
				-- sniper we paused for this selection.
				if self._scanPausedForSelection then
					self._scanPausedForSelection = false
					manager:ProcessAction("ACTION_RESUME_SCAN")
				end
			end
		else
			local _, rawLink = state.selectedAuction:GetLinks()
			ChatMessage.PrintfUser(L["Failed to buy auction of %s."], rawLink)
			-- 3.3.5 fail-loop fix: count consecutive failed buys of the SAME selected
			-- lot. After a long rapid buy streak the lot can be genuinely gone (bought
			-- by someone else / server-side reject) while its stale index still matches
			-- an on-page row, so the old put-index-back-and-refind path retried forever
			-- ("Failed to buy" spam every click). After 3 consecutive failures treat the
			-- lot as vanished: drop it from the results and clear the selection.
			self._buyoutRetries = (self._buyoutRetries or 0) + 1
			if self._buyoutRetries >= 3 then
				self._buyoutRetries = nil
				self._vanishRefindDone = nil
				if state.selectedAuction:IsSubRow() then
					state.selectedAuction:GetResultRow():RemoveSubRow(state.selectedAuction)
				end
				state.numBid = 0
				state.numBought = 0
				state.numConfirmed = 0
				state.lastBuyQuantity = 0
				state.lastBuyIndex = nil
				state.findHash = nil
				state.findResult = nil
				state.findDeferred = false
				state.pendingBuyOnFind = false
				state.pendingBidOnFind = false
				if state.auctionScrollTable then
					state.auctionScrollTable:SetSelectedRow(nil)
				end
				manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
				if self._scanPausedForSelection then
					self._scanPausedForSelection = false
					manager:ProcessAction("ACTION_RESUME_SCAN")
				end
				return
			end
			-- 3.3.5: the buyout future resolved false (server dropped the bid). Do NOT
			-- re-bid re-entrantly here: this handler runs from Future:_HandleFutureDone,
			-- which only clears state.pendingFuture AFTER we return, so calling
			-- ManageFuture("pendingFuture", ...) now would trip assert(not state[stateKey])
			-- in UIManager (the crash). Put the index back and let the normal rescan retry.
			if state.lastBuyQuantity > 0 then
				state.numBought = state.numBought - ((not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and state.lastBuyQuantity or 1)
				if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
					-- findResult can be nil if the selection got cleared while the buy
					-- future was pending (e.g. the search ended); don't crash on the
					-- failure path in that case
					if state.findResult and state.lastBuyIndex then
						tinsert(state.findResult, state.lastBuyIndex)
					end
				end
				state.lastBuyQuantity = 0
				state.lastBuyIndex = nil
			end
			-- Rescan for this item
			-- 3.3.5 buy-after-buy fix: the failed bid means the stored index no longer
			-- matches the server's list (stale after a prior buyout reflowed it). The
			-- current-page shortcut would re-match the same stale page and fail again
			-- (the "Failed to buy" x3 -> lot dropped pattern), so force the retry find
			-- to run a fresh per-item query which resyncs the native list.
			self._findForceQuery = true
			if state.auctionScrollTable and state.auctionScrollTable:GetSelectedRow() then
				manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			end
		end
	elseif action == "ACTION_REMOVE_BOUGHT_AUCTIONS" then
		local quantity = ...
		-- Remove the one we just bought
		assert(quantity > 0)
		local itemString = state.selectedAuction:GetItemString()
		assert(itemString)
		state.selectedAuction:DecrementQuantity(quantity)
		state.searchContext:OnBuy(itemString, state.lastBuyQuantity)
		state.auctionScrollTable:UpdateData() -- TODO: Remove this
		local selection = state.auctionScrollTable:GetSelectedRow()
		if selection and not selection:IsSubRow() then
			state.findHash = nil
			manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
		else
			local maxQuantity = state.searchContext:GetMaxCanBuy(itemString)
			if maxQuantity then
				if (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and selection then
					maxQuantity = maxQuantity / selection:GetQuantities()
				end
				state.defaultBuyQuantity = min(state.defaultBuyQuantity, maxQuantity)
			end
		end
	elseif action == "ACTION_BID_AUCTION" then
		local selection = state.auctionScrollTable:GetSelectedRow()
		if (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic())
			and (state.findDeferred or not state.findResult) then
			-- 3.3.5 sniper bid fix: mirror ACTION_BUY_AUCTION. PlaceAuctionBid is a
			-- protected call on Warmane and only succeeds inside the synchronous
			-- hardware-event click stack, so locate the lot on the live native "list"
			-- here and fall through to bid in the same stack. Fall back to the async
			-- find only when the lot isn't on the current native page.
			local matches = nil
			if selection and selection:IsSubRow() and GetNumAuctionItems then
				for i = 1, (GetNumAuctionItems("list") or 0) do
					if selection:EqualsIndex(i, false) or selection:EqualsIndex(i, true) then
						matches = matches or {}
						tinsert(matches, i)
					end
				end
			end
			if matches then
				state.findDeferred = false
				state.pendingBidOnFind = false
				self._resumeAfterFind = false
				state.findHash = selection:GetHashes()
				state.findHashIsSelection = true
				state.findResult = matches
				local maxQuantity = state.searchContext:GetMaxCanBuy(selection:GetItemString())
				state.numFound = min(#matches, maxQuantity and Math.Ceil(maxQuantity / selection:GetQuantities()) or math.huge)
				state.maxQuantity = maxQuantity and min(maxQuantity, state.numFound) or 1
				state.defaultBuyQuantity = state.numFound
				state.numBid = 0
				state.numBought = 0
				state.numConfirmed = 0
			else
			state.findDeferred = false
			state.findResult = nil
			state.pendingBidOnFind = true
			-- 3.3.5: see ACTION_BUY_AUCTION — only pause when no transition is pending
			-- so we don't re-trip assert(pausePending == nil) in ACTION_PAUSE_SCAN.
			self._resumeAfterFind = not state.scanIsPaused and state.pausePending == nil
			if self._resumeAfterFind then
				manager:ProcessAction("ACTION_PAUSE_SCAN")
			end
			return manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			end
		end
		if not self:_ShowConfirmation(false) then
			-- No confirmation needed
			local numToBuy = selection:GetQuantities()
			manager:ProcessAction("ACTION_BID_AUCTION_CONFIRMED", numToBuy)
		end
	elseif action == "ACTION_BID_AUCTION_CONFIRMED" then
		local quantity = ...
		state.lastBuyQuantity = 0
		state.lastBuyIndex = nil
		local index = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and tremove(state.findResult, #state.findResult) or nil
		if (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and not index then
			-- No index left to bid on; bail without asserting (mirror ACTION_BUY_AUCTION_CONFIRMED).
			return manager:ProcessAction("ACTION_BID_FUTURE_DONE", false)
		end
		if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
			-- 3.3.5 sniper bid fix: re-validate the index right before placing the bid,
			-- exactly like ACTION_BUY_AUCTION_CONFIRMED. The native "list" can shift
			-- between find and confirm (page reflow, async seller resolve, other clients),
			-- so a stale index would bid on the wrong lot or be silently dropped.
			local ok = state.selectedAuction:EqualsIndex(index, false)
			if not ok then
				ok = state.selectedAuction:EqualsIndex(index, true)
			end
			if not ok then
				-- Re-locate by identity across the whole current list WITHOUT a new query
				-- (keeps the server bid-throttle cleared) and bid at the new index.
				local liveTotal = GetNumAuctionItems and GetNumAuctionItems("list") or 0
				for i = 1, liveTotal do
					if state.selectedAuction:EqualsIndex(i, false) or state.selectedAuction:EqualsIndex(i, true) then
						index = i
						ok = true
						break
					end
				end
			end
			if not ok then
				-- Lot is no longer on the live list. Unlike buyout we do NOT remove the row
				-- here: a bid leaves the auction in place, so keep the item and just fail
				-- this attempt + rescan (buttons re-enable instead of freezing).
				return manager:ProcessAction("ACTION_BID_FUTURE_DONE", false)
			end
		end
		-- Bid on the auction
		local result, future = state.auctionScan:PrepareForBidOrBuyout(index, state.selectedAuction, false, quantity)
		assert(not future)
		future = result and state.auctionScan:PlaceBidOrBuyout(index, state.selectedAuction:GetRequiredBid(), state.selectedAuction, quantity)
		if not future then
			return manager:ProcessAction("ACTION_BID_FUTURE_DONE", false)
		end
		state.lastBuyQuantity = quantity
		state.lastBuyIndex = index
		state.numBid = state.numBid + ((not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and quantity or 1)
		manager:ManageFuture("pendingFuture", future, "ACTION_BID_FUTURE_DONE")
	elseif action == "ACTION_BID_FUTURE_DONE" then
		local result = ...
		if not state.selectedAuction then
			-- See ACTION_BUYOUT_FUTURE_DONE: drop stale completions safely
			state.numBid = 0
			state.numBought = 0
			state.numConfirmed = 0
			return
		end
		if result then
			state.numConfirmed = state.numConfirmed + 1
			if state.numConfirmed == state.numFound then
				state.numBid = 0
				state.numBought = 0
				state.numConfirmed = 0
			end
			state.selectedAuction:ProcessBid()
			state.auctionScrollTable:UpdateData() -- TODO: Remove this
			state.auctionScrollTable:SetSelectedRow(nil)
			manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
			-- 3.3.5 off-page buyout fix: resume the sniper we paused for this selection.
			if self._scanPausedForSelection then
				self._scanPausedForSelection = false
				manager:ProcessAction("ACTION_RESUME_SCAN")
			end
		else
			local _, rawLink = state.selectedAuction:GetLinks()
			ChatMessage.PrintfUser(L["Failed to bid on auction of %s."], rawLink)
			if state.lastBuyQuantity > 0 then
				state.numBid = state.numBid - 1
				state.lastBuyQuantity = 0
				state.lastBuyIndex = nil
			end
			-- 3.3.5 buy-after-buy fix: same stale-list resync as the buyout failure path
			self._findForceQuery = true
			-- Rescan for this item
			if state.auctionScrollTable and state.auctionScrollTable:GetSelectedRow() then
				manager:ProcessAction("ACTION_FIND_SELECTED_AUCTION")
			end
		end
	elseif action == "ACTION_CANCEL_AUCTION" then
		assert((not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and state.selectedAuction and state.selectedAuction:IsSubRow())
		local _, auctionId = state.selectedAuction:GetListingInfo()
		Log.Info("Canceling (auctionId=%d)", auctionId)
		local future = AuctionHouseWrapper.CancelAuction(auctionId)
		if future then
			manager:ManageFuture("pendingFuture", future, "ACTION_CANCEL_FUTURE_DONE")
		else
			manager:ProcessAction("ACTION_CANCEL_FUTURE_DONE", false)
		end
	elseif action == "ACTION_CANCEL_FUTURE_DONE" then
		local result = ...
		if result then
			state.selectedAuction:GetResultRow():RemoveSubRow(state.selectedAuction)
			state.auctionScrollTable:SetSelectedRow(nil)
			manager:ProcessAction("ACTION_SET_SELECTED_AUCTION", nil)
		else
			ChatMessage.PrintUser(L["Failed to cancel auction due to the auction house being busy. Ensure no other addons are scanning the AH and try again."])
		end
	elseif action == "ACTION_POST_AUCTION" then
		local postContext = self:_GetPostContext()
		local itemString, itemDisplayedBid, itemBuyout, quantity, ownerStr = postContext:GetInfo()
		if not itemString then
			-- Should never get here
			return
		end

		local undercut = ((not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) or self._isPlayerFunc(ownerStr, true)) and 0 or 1
		local bid = itemDisplayedBid - undercut
		local buyout = itemBuyout - undercut
		if LibTSMUI.IsRetail() then
			bid = Math.Round(bid, COPPER_PER_SILVER)
			buyout = Math.Round(buyout, COPPER_PER_SILVER)
		end
		bid = Math.Bound(bid, 1, MAXIMUM_BID_PRICE)
		buyout = Math.Bound(buyout, 0, MAXIMUM_BID_PRICE)

		state.auctionScrollTable:GetBaseElement():ShowDialogFrame(UIElements.New("ShoppingPostDialog", "dialog")
			:SetSize(326, (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and 380 or 344)
			:AddAnchor("CENTER")
			:SetAuction(itemString, bid, buyout, quantity, undercut, state.postDuration)
			:SetManager(manager)
			:SetAction("OnPostClicked", "ACTION_POST_AUCTION_CONFIRMED")
			:SetScript("OnHide", manager:CallbackToProcessAction("ACITON_HANDLE_POST_DIALOG_HIDDEN"))
		)
		state.postDialogShown = true
	elseif action == "ACTION_POST_AUCTION_CONFIRMED" then
		local itemString, duration, stackSize, numStacks, bid, buyout = ...
		state.postDuration = duration
		local postBag, postSlot = BagTracking.CreateQueryBagsAuctionable()
			:OrderBy("slotId", true)
			:Select("bag", "slot")
			:Equal("itemString", itemString)
			:GetFirstResultAndRelease()
		if not postBag or not postSlot then
			return
		end
		if not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic() then
			numStacks = 1
		elseif ItemString.IsPet(itemString) then
			stackSize = 1
			numStacks = 1
		end
		local future = AuctionHouseWrapper.PostAuction(postBag, postSlot, duration, stackSize, numStacks, bid, buyout)
		if future then
			manager:ManageFuture("pendingFuture", future, "ACTION_POST_FUTURE_DONE")
		else
			manager:ProcessAction("ACTION_POST_FUTURE_DONE", false)
		end
	elseif action == "ACTION_POST_FUTURE_DONE" then
		local result = ...
		if result then
			AuctionHouseWrapper.AutoQueryOwnedAuctions()
		else
			ChatMessage.PrintUser(L["Failed to post auction due to the auction house being busy. Ensure no other addons are scanning the AH and try again."])
		end
	elseif action == "ACITON_HANDLE_POST_DIALOG_HIDDEN" then
		state.postDialogShown = false
	elseif action == "ACTION_HIDE_POST_DIALOG" then
		if state.postDialogShown then
			state.auctionScrollTable:GetBaseElement():HideDialog()
		end
	elseif action == "ACTION_END_SEARCH" then
		manager:ProcessAction("ACTION_RESET_STATE")
		AuctionScan.ReleaseLock(state.scanTypeName)
	else
		error("Unknown action: "..tostring(action))
	end
end

---@return AuctionPostContext
function AuctionBuyScan.__private:_GetPostContext()
	if self._state.selectedAuction and self._state.selectedAuction:IsSubRow() then
		self._selectionPostContext:PopulateForRow(self._state.selectedAuction)
		return self._selectionPostContext
	else
		return self._state.searchContext and self._state.searchContext:GetPostContext()
	end
end

function AuctionBuyScan.__private:_ShowConfirmation(isBuy)
	local alertThreshold = self._alertThresholdFunc and self._alertThresholdFunc(self._state.selectedAuction:GetItemString()) or nil
	local result, dialogFrame = private.GetConfirmationDialog(self._state, isBuy, alertThreshold)
	if dialogFrame then
		self._state.auctionScrollTable:GetBaseElement():ShowDialogFrame(dialogFrame
			:SetManager(self._manager)
			:SetScript("OnHide", private.ConfirmationDialogOnHide)
		)
	end
	return result
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

---@param state AuctionBuyScanState
function private.StateToProgressText(state)
	if not state.auctionScan then
		return L["Starting Scan..."]
	elseif state.isSearchingForSelection then
		return L["Finding Selected Auction"]
	elseif state.pausePending ~= nil and state.scanProgress ~= 1 then
		-- 3.3.5: once the scan has fully completed (progress == 1) there is no live
		-- thread to pause/resume, so a stale pausePending must NOT mask the real
		-- "Scan Complete" / selection state in the branches below.
		return state.pausePending and L["Pausing Scan..."] or L["Resuming Scan..."]
	elseif state.selectedAuction then
		local progressText = nil
		if state.isConfirming and state.numCanBuy > 0 then
			-- We can buy more while confirming
			progressText = format(L["Buy %d / %d (Confirming %d / %d)"], state.numBidOrBought + 1, state.numFound, state.numConfirmed + 1, state.numFound)
		elseif state.isConfirming then
			-- We're just confirming
			progressText = format(L["Confirming %d / %d"], state.numConfirmed + 1, state.numFound)
		elseif state.selectionCanBuy then
			progressText = format(L["Buy %d / %d"], state.numBidOrBought + 1, state.numFound)
		elseif state.pendingFuture then
			progressText = L["Confirming..."]
		else
			progressText = (state.canPost and state.canCancel and L["Cancel or Post"]) or (state.canPost and L["Post"]) or (state.canCancel and L["Cancel Auction"]) or L["Scan Complete"]
		end
		if state.scanIsPaused then
			return L["Scan Paused"].." | "..progressText
		else
			return progressText
		end
	elseif state.scanIsPaused then
		return L["Scan Paused"]
	elseif state.scanProgress ~= 1 then
		local pct = math.floor((state.scanProgress or 0) * 100 + 0.5)
		if state.scanNumItems then
			return format(L["Scanning (%d Items)"].." %d%%", state.scanNumItems, pct)
		else
			return format(L["Scanning"].." %d%%", pct)
		end
	else
		return L["Scan Complete"]
	end
end

---@param state AuctionBuyScanState
function private.GetConfirmationDialog(state, isBuy, alertThreshold)
	local buyout = state.selectedAuction:GetBuyouts()
	if not isBuy then
		buyout = state.selectedAuction:GetRequiredBid(state.selectedAuction)
	end
	local quantity = state.selectedAuction:GetQuantities()
	local itemString = state.selectedAuction:GetItemString()
	local _, _, _, isHighBidder = state.selectedAuction:GetBidInfo()
	local isCommodity = (not LibTSMUI.IsVanillaClassic() and not LibTSMUI.IsBCClassic() and not LibTSMUI.IsWrathClassic()) and state.selectedAuction:IsCommodity()
	assert(not isCommodity or isBuy)
	local marketValueFunc = state.searchContext:GetMarketValueFunc()
	if not isCommodity and (not isBuy or not isHighBidder) and (not alertThreshold or ceil(buyout / quantity) < alertThreshold) then
		-- Don't need to confirm this
		return false, nil
	elseif private.confirmationVisible then
		-- Already showing a confirmation
		return true, nil
	end

	local dialogFrame = nil
	if isCommodity then
		local gatheringResultsFunction = state.searchContext:GetGatheringResultsFunc()
		local defaultQuantity, marketThreshold = state.defaultBuyQuantity, nil
		if gatheringResultsFunction then
			defaultQuantity = gatheringResultsFunction(state.auctionScan, marketValueFunc, itemString, defaultQuantity, state.maxQuantity)
			marketThreshold = marketValueFunc(state.selectedAuction) or 0
		end
		dialogFrame = UIElements.New("AuctionCommodityBuyConfirmationDialog", "frame")
			:SetSize(600, 272)
			:AddAnchor("CENTER")
			:Configure(state.auctionScan, state.selectedAuction, defaultQuantity, state.maxQuantity, marketValueFunc, marketThreshold, alertThreshold)
			:SetAction("OnBuyoutClicked", "ACTION_BUY_AUCTION_CONFIRMED")
			:SetAction("OnCommodityPriceUpdated", "ACTION_COMMODITY_PRICE_UPDATED")
	else
		local auctionNum = min(state.numConfirmed + 1, state.defaultBuyQuantity)
		dialogFrame = UIElements.New("AuctionItemBuyConfirmationDialog", "frame")
			:SetSize(340, 262)
			:AddAnchor("CENTER")
			:Configure(isBuy, state.selectedAuction, quantity, auctionNum, state.defaultBuyQuantity, marketValueFunc(state.selectedAuction))
			:SetAction("OnBuyoutClicked", isBuy and "ACTION_BUY_AUCTION_CONFIRMED" or "ACTION_BID_AUCTION_CONFIRMED")
	end
	private.confirmationVisible = true
	return true, dialogFrame
end

function private.ConfirmationDialogOnHide()
	private.confirmationVisible = false
end
