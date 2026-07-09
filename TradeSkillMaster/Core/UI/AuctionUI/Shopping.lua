-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Shopping = TSM.UI.AuctionUI:NewPackage("Shopping") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local TextureAtlas = TSM.LibTSMService:Include("UI.TextureAtlas")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local PlayerInfo = TSM.LibTSMApp:Include("Service.PlayerInfo")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local UIManager = TSM.LibTSMUtil:IncludeClassType("UIManager")
local AuctionPostContext = TSM.LibTSMService:IncludeClassType("AuctionPostContext")
local AuctionBuyScan = TSM.LibTSMUI:IncludeClassType("AuctionBuyScan")
local private = {
	auctionBuyScan = nil,
	manager = nil,
	settings = nil,
	selectedGroups = {},
	itemPostContext = AuctionPostContext.New(),
	updateCallbacks = {},
}
local STATE_SCHEMA = Reactive.CreateStateSchema("SHOPPING_UI_STATE")
	:AddOptionalTableField("frame")
	:AddOptionalTableField("scanFrame")
	:AddStringField("contentPath", "selection")
	:AddStringField("searchName", "")
	:AddBooleanField("filterIsValid", (not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic()))
	:AddBooleanField("groupSelectionCleared", true)
	:AddOptionalStringField("greatDealsFilter")
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Shopping.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "auctionUIContext", "shoppingSelectionDividedContainer")
		:AddKey("global", "auctionUIContext", "shoppingAuctionScrollingTable")
		:AddKey("global", "auctionUIContext", "shoppingSearchesTabGroup")
		:AddKey("global", "shoppingOptions", "searchAutoFocus")
		:AddKey("global", "shoppingOptions", "buyoutConfirm")
		:AddKey("global", "shoppingOptions", "buyoutAlertSource")
		:AddKey("char", "auctionUIContext", "shoppingGroupTree")

	-- Create the state / manager
	local state = STATE_SCHEMA:CreateState()
	private.manager = UIManager.Create("SHOPPING", state, private.ActionHandler)
		:SuppressActionLog("ACTION_FILTER_INPUT_CHANGED")

	-- Create the auction buy scan
	private.auctionBuyScan = AuctionBuyScan.NewBrose(L["Browse"], private.IsPlayer, private.GetAlertThreshold)

	-- Register this page with the Auction UI
	local function GetFrame()
		return private.GetShoppingFrame(state)
	end
	local function OnItemLinked(_, itemLink)
		if not state.frame then return end
		if state.frame:GetPath() == "selection" and state.frame:GetElement("selection.content"):GetPath() == "advanced" then
			-- They are on the advanced search UI, so just populate the filter dialog instead of starting a search
			state.frame:GetElement("selection.content.advanced.search.header.keyword")
				:SetValue(ItemInfo.GetName(ItemString.GetBase(itemLink)))
				:Draw()
			return false
		end

		private.manager:ProcessAction("ACTION_START_ITEM_SEARCH", itemLink)
		return true
	end
	TSM.UI.AuctionUI.RegisterTopLevelPage(L["Browse"], GetFrame, OnItemLinked)
end

function Shopping.StartGatheringSearch(items, stateCallback, buyCallback, mode)
	assert(Shopping.IsVisible())
	private.manager:ProcessAction("ACTION_START_GATHERING_SEARCH", items, stateCallback, buyCallback, mode)
end

function Shopping.StartItemSearch(itemLink)
	private.manager:ProcessAction("ACTION_START_ITEM_SEARCH", itemLink)
end

function Shopping.IsVisible()
	return TSM.UI.AuctionUI.IsPageOpen(L["Browse"])
end

function Shopping.RegisterUpdateCallback(callback)
	tinsert(private.updateCallbacks, callback)
end



-- ============================================================================
-- Shopping UI
-- ============================================================================

---@param state ShoppingUIState
function private.GetShoppingFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "shopping")
	if not private.auctionBuyScan:GetSearchContext() then
		state.contentPath = "selection"
	end
	local frame = UIElements.New("ViewContainer", "shopping")
		:SetContext(state)
		:SetNavCallback(private.GetShoppingContentFrame)
		:AddPath("selection")
		:AddPath("scan")
		:SetPath(state.contentPath)
		:SetManager(private.manager)
		:SetScript("OnHide", private.manager:CallbackToProcessAction("ACTION_FRAME_HIDDEN"))
	state.frame = frame
	for _, callback in ipairs(private.updateCallbacks) do
		callback()
	end
	return frame
end

function private.GetShoppingContentFrame(viewContainer, path)
	local state = viewContainer:GetContext() ---@type ShoppingUIState
	state.contentPath = path
	if path == "selection" then
		return private.GetSelectionFrame(state)
	elseif path == "scan" then
		return private.GetScanFrame(state)
	else
		error("Unexpected path: "..tostring(path))
	end
end

---@param state ShoppingUIState
function private.GetSelectionFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "shopping", "selection")
	local frame = UIElements.New("DividedContainer", "selection")
		:SetSettingsContext(private.settings, "shoppingSelectionDividedContainer")
		:SetMinWidth(220, 350)
		:SetBackgroundColor("PRIMARY_BG")
		:SetLeftChild(UIElements.New("Frame", "groupSelection")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("ApplicationGroupTreeWithControls", "groupTree")
				:SetOperationType("Shopping")
				:SetSettingsContext(private.settings, "shoppingGroupTree")
				:SetAction("OnGroupSelectionChanged", "ACTION_GROUP_SELECTION_CHANGED")
			)
			:AddChild(UIElements.New("HorizontalLine", "line2"))
			:AddChild(UIElements.New("Frame", "bottom")
				:SetLayout("VERTICAL")
				:SetHeight(40)
				:SetBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("ActionButton", "scanBtn")
					:SetHeight(24)
					:SetMargin(8)
					:SetText(L["Run Shopping Scan"])
					:SetDisabledPublisher(state:PublisherForKeyChange("groupSelectionCleared"))
					:SetAction("OnClick", "ACTION_START_GROUP_SEARCH")
				)
			)
		)
		:SetRightChild(UIElements.New("ViewContainer", "content")
			:SetContext(state)
			:SetNavCallback(private.GetSelectionContent)
			:AddPath("search", true)
			:AddPath("advanced")
		)
	state.groupSelectionCleared = frame:GetElement("groupSelection.groupTree"):IsSelectionCleared()
	return frame
end

function private.GetSelectionContent(frame, path)
	local state = frame:GetContext() ---@type ShoppingUIState
	if path == "search" then
		state.greatDealsFilter = TSM.Shopping.GreatDealsSearch.GetFilter()
		return UIElements.New("Frame", "search")
			:SetLayout("VERTICAL")
			:SetPadding(8, 8, 8, 0)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 20)
				:AddChild(UIElements.New("Input", "filterInput")
					:SetIconTexture("iconPack.18x18/Search")
					:SetClearButtonEnabled(true)
					:SetFocused(private.settings.searchAutoFocus)
					:SetHintText(L["Search the auction house"])
					:SetAction("OnValueChanged", "ACTION_FILTER_INPUT_CHANGED")
					:SetAction("OnEnterPressed", "ACTION_START_FILTER_INPUT_SEARCH")
				)
				:AddChild(UIElements.New("ActionButton", "search")
					:SetWidth(90)
					:SetMargin(8, 0, 0, 0)
					:SetText(L["Search"])
					:SetDisabledPublisher(state:PublisherForKeyChange("filterIsValid"):InvertBoolean())
					:SetAction("OnClick", "ACTION_START_FILTER_INPUT_SEARCH")
				)
			)
			:AddChild(UIElements.New("Frame", "buttonsLine1")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 10)
				:AddChild(UIElements.New("ActionButton", "advSearchBtn")
					:SetMargin(0, 8, 0, 0)
					:SetText(L["Advanced Item Search"])
					:SetAction("OnClick", "ACTION_SHOW_ADVANCED_SEARCH")
				)
				:AddChild(UIElements.New("ActionButton", "vendorBtn")
					:SetText(L["Vendor Search"])
					:SetAction("OnClick", "ACTION_START_VENDOR_SEARCH")
				)
			)
			:AddChild(UIElements.New("Frame", "buttonsLine2")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:AddChild(UIElements.New("ActionButton", "disenchantBtn")
					:SetMargin(0, 8, 0, 0)
					:SetText(L["Disenchant Search"])
					:SetAction("OnClick", "ACTION_START_DISENCHANT_SEARCH")
				)
				:AddChild(UIElements.New("ActionButton", "dealsBtn")
					:SetText(L["Great Deals Search"])
					:SetDisabledPublisher(state:PublisherForKeyChange("greatDealsFilter")
						:MapBooleanEquals(nil)
					)
					:SetAction("OnClick", "ACTION_START_DEALS_SEARCH")
				)
			)
			:AddChild(UIElements.New("TabGroup", "buttons")
				:SetMargin(-8, -8, 21, 0)
				:SetNavCallback(private.GetSearchesElement)
				:SetSettingsContext(private.settings, "shoppingSearchesTabGroup")
				:AddPath(L["Recent Searches"])
				:AddPath(L["Favorite Searches"])
			)
	elseif path == "advanced" then
		return UIElements.New("ShoppingAdvancedSearch", "advanced")
			:SetAction("OnBackClicked", "ACTION_ADVANCED_SEARCH_BACK")
			:SetAction("OnStartScanClicked", "ACTION_START_ADVANCED_SEARCH")
	else
		error("Unexpected path: "..tostring(path))
	end
end

function private.GetSearchesElement(_, button)
	if button == L["Recent Searches"] then
		return UIElements.New("SearchList", "list")
			:SetEditEnabled(false)
			:SetQuery(TSM.Shopping.SavedSearches.CreateRecentSearchesQuery())
			:SetAction("OnFavoriteChanged", "ACTION_SET_SEARCH_FAVORITE")
			:SetAction("OnDelete", "ACTION_RECENT_SEARCH_DELETE")
			:SetAction("OnRowClick", "ACTION_RECENT_SEARCH_LIST_ROW_CLICK")
	elseif button == L["Favorite Searches"] then
		return UIElements.New("SearchList", "list")
			:SetEditEnabled(true)
			:SetQuery(TSM.Shopping.SavedSearches.CreateFavoriteSearchesQuery())
			:SetAction("OnFavoriteChanged", "ACTION_SET_SEARCH_FAVORITE")
			:SetAction("OnEdit", "ACTION_FAVORITE_SEARCH_EDIT")
			:SetAction("OnDelete", "ACTION_FAVORITE_SEARCH_DELETE")
			:SetAction("OnRowClick", "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK")
	else
		error("Unexpected button: "..tostring(button))
	end
end

---@param state ShoppingUIState
function private.GetScanFrame(state)
	UIUtils.AnalyticsRecordPathChange("auction", "shopping", "scan")
	local frame = UIElements.New("Frame", "scan")
		:SetLayout("VERTICAL")
		:SetBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("Frame", "searchFrame")
			:SetLayout("HORIZONTAL")
			:SetHeight(40)
			:SetPadding(8)
			:AddChild(UIElements.New("Frame", "back")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 8, 0, 0)
				:AddChild(UIElements.New("ActionButton", "button")
					:SetWidth(64)
					:SetText(TextureAtlas.GetTextureLink(TextureAtlas.GetFlippedHorizontallyKey("iconPack.14x14/Chevron/Right"))..L["Back"])
					:SetAction("OnClick", "ACTION_SCAN_BACK_BUTTON_CLICKED")
				)
			)
			:AddChild(UIElements.New("Input", "filterInput")
				:SetIconTexture("iconPack.18x18/Search")
				:SetClearButtonEnabled(true)
				:SetHintText(L["Enter Filter"])
				:SetValue(state.searchName)
				:SetAction("OnEnterPressed", "ACTION_START_FILTER_INPUT_SEARCH")
			)
			:AddChild(UIElements.New("ActionButton", "rescanBtn")
				:SetWidth(140)
				:SetMargin(8, 0, 0, 0)
				:SetText(L["Rescan"])
				:SetDisabledPublisher(state:PublisherForKeyChange("searchName")
					:MapBooleanEquals(L["Gathering Search"])
				)
				:SetAction("OnClick", "ACTION_RESCAN")
			)
		)
		:AddChild(UIElements.New("AuctionScrollTable", "auctions")
			:SetSettings(private.settings, "shoppingAuctionScrollingTable")
			:SetCreatedGroupName(L["Browse"].." - "..state.searchName)
			:SetBrowseResultsVisible(true)
			:SetIsPlayerFunction(PlayerInfo.AuctionOwnerIsPlayer)
		)
		:AddChild(UIElements.New("HorizontalLine", "line"))
		:AddChild(private.auctionBuyScan:CreateBottomUIFrameForBrowse())
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
---@param state ShoppingUIState
function private.ActionHandler(manager, state, action, ...)
	if action == "ACTION_FRAME_HIDDEN" then
		if not state.frame then return end
		-- In 3.3.5 OnHide can be called spuriously during frame setup
		-- Only clear state.frame if the frame is actually hidden
		if state.frame:_GetBaseFrame():IsShown() then
			return
		end
		state.frame = nil
		for _, callback in ipairs(private.updateCallbacks) do
			callback()
		end
	elseif action == "ACTION_SCAN_FRAME_HIDDEN" then
		state.scanFrame = nil
		private.auctionBuyScan:SetAuctionScrollTable(nil)
	elseif action == "ACTION_SHOW_ADVANCED_SEARCH" then
		if not state.frame then return end
		state.frame:GetElement("selection.content"):SetPath("advanced", true)
	elseif action == "ACTION_ADVANCED_SEARCH_BACK" then
		if not state.frame then return end
		state.frame:GetElement("selection.content"):SetPath("search", true)
	elseif action == "ACTION_START_GROUP_SEARCH" then
		if not state.frame then return end
		manager:ProcessAction("ACTION_START_SEARCH", private.GetGroupSearchContext(state))
	elseif action == "ACTION_START_ADVANCED_SEARCH" then
		local filter = ...
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.FilterSearch.GetSearchContext(filter))
	elseif action == "ACTION_SET_SEARCH_FAVORITE" then
		local index, isFavorite = ...
		TSM.Shopping.SavedSearches.SetSearchIsFavorite(index, isFavorite)
	elseif action == "ACTION_RECENT_SEARCH_DELETE" then
		local index = ...
		TSM.Shopping.SavedSearches.DeleteSearch(index, private.GetSearchListFields("RECENT", index, "filter"))
	elseif action == "ACTION_FAVORITE_SEARCH_DELETE" then
		local index = ...
		TSM.Shopping.SavedSearches.DeleteSearch(index, private.GetSearchListFields("FAVORITE", index, "filter"))
	elseif action == "ACTION_FAVORITE_SEARCH_EDIT" then
		if not state.frame then return end
		local index = ...
		local dialog = UIElements.New("SavedSearchEditDialog", "frame")
			:SetSize(600, 187)
			:AddAnchor("CENTER")
			:SetName(private.GetSearchListFields("FAVORITE", index, "name"), index)
			:SetManager(manager)
			:SetAction("OnNameChanged", "ACTION_RENAMED_SAVED_SEARCH")
		state.frame:GetBaseElement():ShowDialogFrame(dialog)
		dialog:GetElement("nameInput"):SetFocused(true)
	elseif action == "ACTION_RENAMED_SAVED_SEARCH" then
		local name, index = ...
		TSM.Shopping.SavedSearches.RenameSearch(index, name)
	elseif action == "ACTION_RECENT_SEARCH_LIST_ROW_CLICK" then
		local index = ...
		local filter = private.GetSearchListFields("RECENT", index, "filter")
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.FilterSearch.GetSearchContext(filter))
	elseif action == "ACTION_FAVORITE_SEARCH_LIST_ROW_CLICK" then
		local index = ...
		local filter = private.GetSearchListFields("FAVORITE", index, "filter")
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.FilterSearch.GetSearchContext(filter))
	elseif action == "ACTION_GROUP_SELECTION_CHANGED" then
		if not state.frame then return end
		state.groupSelectionCleared = state.frame:GetElement("selection.groupSelection.groupTree"):IsSelectionCleared()
	elseif action == "ACTION_START_GATHERING_SEARCH" then
		local items, stateCallback, buyCallback, mode = ...
		manager:ProcessAction("ACTION_START_SEARCH", private.GetGatheringSearchContext(state, items, stateCallback, buyCallback, mode))
	elseif action == "ACTION_START_ITEM_SEARCH" then
		local itemLink = ...
		manager:ProcessAction("ACTION_START_SEARCH", private.GetLinkedItemSearchContext(state, ItemInfo.GetName(itemLink), itemLink))
	elseif action == "ACTION_START_VENDOR_SEARCH" then
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.VendorSearch.GetSearchContext())
	elseif action == "ACTION_START_DISENCHANT_SEARCH" then
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.DisenchantSearch.GetSearchContext())
	elseif action == "ACTION_START_DEALS_SEARCH" then
		assert(state.greatDealsFilter)
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.FilterSearch.GetGreatDealsSearchContext(state.greatDealsFilter))
	elseif action == "ACTION_FILTER_INPUT_CHANGED" then
		if not state.frame then return end
		local value = state.frame:GetElement("selection.content.search.header.filterInput"):GetValue()
		state.filterIsValid = (not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic()) or value ~= ""
	elseif action == "ACTION_START_FILTER_INPUT_SEARCH" then
		if not state.frame then return end
		local path = state.frame:GetPath()
		local filter = nil
		if path == "selection" then
			filter = state.frame:GetElement("selection.content.search.header.filterInput"):GetValue()
		elseif path == "scan" then
			filter = state.frame:GetElement("scan.searchFrame.filterInput"):GetValue()
		else
			error("Invalid path: "..tostring(path))
		end
		if (ClientInfo.IsVanillaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic()) and filter == "" then
			return
		end
		manager:ProcessAction("ACTION_START_SEARCH", TSM.Shopping.FilterSearch.GetSearchContext(filter))
	elseif action == "ACTION_START_SEARCH" then
		local searchContext = ...
		if not state.frame then return end
		state.frame:SetPath("selection", true)
		if not searchContext then
			return
		end
		if not private.auctionBuyScan:PrepareStartSearch() then
			return
		end
		local name = searchContext:GetName()
		assert(name)
		state.searchName = name
		state.frame:SetPath("scan", true)
		private.auctionBuyScan:StartSearch(searchContext)
	elseif action == "ACTION_SCAN_BACK_BUTTON_CLICKED" then
		state.searchName = ""
		state.frame:SetPath("selection", true)
		private.auctionBuyScan:EndSearch()
	elseif action == "ACTION_RESCAN" then
		manager:ProcessAction("ACTION_START_SEARCH", private.auctionBuyScan:GetSearchContext())
	else
		error("Unknown action: "..tostring(action))
	end
end

---@param state ShoppingUIState
function private.GetGroupSearchContext(state)
	wipe(private.selectedGroups)
	for _, groupPath in state.frame:GetElement("selection.groupSelection.groupTree"):SelectedGroupsIterator() do
		if groupPath ~= "" and not strmatch(groupPath, "^`") then
			tinsert(private.selectedGroups, groupPath)
		end
	end
	local searchContext = TSM.Shopping.GroupSearch.GetSearchContext(private.selectedGroups)
	assert(searchContext)
	return searchContext
end

---@param state ShoppingUIState
function private.GetGatheringSearchContext(state, items, stateCallback, buyCallback, mode)
	local filterList = TempTable.Acquire()
	for itemString, quantity in pairs(items) do
		tinsert(filterList, itemString.."/x"..quantity)
	end
	local filter = table.concat(filterList, ";")
	TempTable.Release(filterList)
	local searchContext = TSM.Shopping.FilterSearch.GetGatheringSearchContext(filter, mode)
	assert(searchContext)
	searchContext:SetCallbacks(buyCallback, stateCallback)
	return searchContext
end

---@param state ShoppingUIState
function private.GetLinkedItemSearchContext(state, name, itemLink)
	local itemString = ItemString.Get(itemLink)
	local baseItemString = ItemString.GetBaseFast(itemString)
	local baseName = ItemInfo.GetName(baseItemString)
	if itemString == baseItemString then
		baseName = baseName.."/exact"
	end
	state.frame:SetPath("selection")
	state.frame:GetBaseElement():HideDialog()
	private.itemPostContext:PopulateForItem(itemString)
	return TSM.Shopping.FilterSearch.GetSearchContext(baseName, private.itemPostContext)
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

function private.GetAlertThreshold(itemString)
	return private.settings.buyoutConfirm and (CustomString.GetValue(private.settings.buyoutAlertSource, itemString) or 0) or nil
end

function private.GetSearchListFields(listType, index, ...)
	local query = nil
	if listType == "RECENT" then
		query = TSM.Shopping.SavedSearches.CreateRecentSearchesQuery()
	elseif listType == "FAVORITE" then
		query = TSM.Shopping.SavedSearches.CreateFavoriteSearchesQuery()
	else
		error("Invalid search list type: "..tostring(listType))
	end
	return query
		:Select(...)
		:Equal("index", index)
		:GetFirstResultAndRelease()
end
