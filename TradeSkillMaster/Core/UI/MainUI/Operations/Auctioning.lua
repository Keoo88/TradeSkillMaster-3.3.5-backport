-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Auctioning = TSM.MainUI.Operations:NewPackage("Auctioning")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local L = TSM.Locale.GetTable()
local String = TSM.LibTSMUtil:Include("Lua.String")
local AuctioningOperation = TSM.LibTSMSystem:Include("AuctioningOperation")
local Operation = TSM.LibTSMTypes:Include("Operation")
local UIElements = TSM.LibTSMUI:Include("Util.UIElements")
local UIUtils = TSM.LibTSMUI:Include("Util.UIUtils")
local AuctionHouse = TSM.LibTSMWoW:Include("API.AuctionHouse")
local private = {
	currentOperationName = nil,
	currentTab = nil,
}
local IGNORE_DURATION_OPTIONS = {
	L["None"],
	AUCTION_TIME_LEFT1.." ("..AUCTION_TIME_LEFT1_DETAIL..")",
	AUCTION_TIME_LEFT2.." ("..AUCTION_TIME_LEFT2_DETAIL..")",
	AUCTION_TIME_LEFT3.." ("..AUCTION_TIME_LEFT3_DETAIL..")",
}
local BELOW_MIN_ITEMS = { L["Don't Post Items"], L["Post at Minimum Price"], L["Post at Maximum Price"], L["Post at Normal Price"], L["Ignore Auctions Below Min"] }
local BELOW_MIN_KEYS = { "none", "minPrice", "maxPrice", "normalPrice", "ignore" }
local ABOVE_MAX_ITEMS = { L["Don't Post Items"], L["Post at Minimum Price"], L["Post at Maximum Price"], L["Post at Normal Price"] }
local ABOVE_MAX_KEYS = { "none", "minPrice", "maxPrice", "normalPrice" }
local POST_CAP_VALIDATE_CONTEXT = {
	isNumber = true,
}
local STACK_SIZE_VALIDATE_CONTEXT = {
	isNumber = true,
}
local KEEP_QUANTITY_VALIDATE_CONTEXT = {
	isNumber = true,
}
local MAX_EXPIRES_VALIDATE_CONTEXT = {
	isNumber = true,
}
local UNDERCUT_VALIDATE_CONTEXT = {
	isUndercut = true,
}
local PRICE_VALIDATE_CONTEXT = {
	badSources = {
		auctioningopmin = true,
		auctioningopmax = true,
		auctioningopnormal = true,
	}
}
local SETTING_TOOLTIPS = {
	ignoreLowDuration = L["When posting and canceling, auctions at or below the selected duration will be completely ignored."],
	matchStackSize = L["Enables this causes TSM to ignores auctions which aren't of the same stack size as you have set in the Posting settings and only undercut other auctions which match your stack size."],
	stackSizeIsCap = L["Whether or not to post a partial stack if you don't have a full stack in your inventory."],
	stackSize = L["The stack size to post on the AH."],
	duration = L["How long auctions are listed for on the AH."],
	postCap = ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and L["The maximum number of stacks to post on the AH."] or L["The maximum number of items to post on the AH."],
	keepQuantity = L["The number of items to keep in your bags and not post on the AH. Set this to 0 to disable it."],
	maxExpires = L["After an item has expired this many times, it will no longer be posted on the AH. Set this to 0 to disable it."],
	bidPercent = L["When posting auctions, the bid price will be calculated as a percentage of the buyout price based on this setting."],
	undercut = L["The amount to undercut the lowest auction by when running a post scan. It's highly recommended to leave this at the default value."],
	minPrice = L["The lowest price you want TSM to consider posting your auctions for"].." "..L["TSM will always attempt to undercut the cheapest auction as long as it's between your minimum and maximum prices."],
	priceReset = L["This defines what TSM does when the lowest auction on the AH is below the minimum price you have set."],
	maxPrice = L["The highest price you want TSM to consider posting your auctions for."].." "..L["TSM will always attempt to undercut the cheapest auction as long as it's between your minimum and maximum prices."],
	aboveMax = L["This defines what TSM does when the lowest auction on the AH is above the maximum price you have set."],
	normalPrice = L["The price you want to post your auctions for when there's no competition on the AH."],
	cancelUndercut = L["Cancel auctions which have been undercut when running a Cancel Scan."],
	cancelRepost = L["Cancel auctions which can be reposted higher when running a Cancel Scan."],
	cancelRepostThreshold = L["Only cancel auctions which can be posted at least this much higher."],
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Auctioning.OnInitialize()
	-- Set min and max values
	POST_CAP_VALIDATE_CONTEXT.minValue, POST_CAP_VALIDATE_CONTEXT.maxValue = AuctioningOperation.GetMinMaxValues("postCap")
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		STACK_SIZE_VALIDATE_CONTEXT.minValue, STACK_SIZE_VALIDATE_CONTEXT.maxValue = AuctioningOperation.GetMinMaxValues("stackSize")
	end
	KEEP_QUANTITY_VALIDATE_CONTEXT.minValue, KEEP_QUANTITY_VALIDATE_CONTEXT.maxValue = AuctioningOperation.GetMinMaxValues("keepQuantity")
	MAX_EXPIRES_VALIDATE_CONTEXT.minValue, MAX_EXPIRES_VALIDATE_CONTEXT.maxValue = AuctioningOperation.GetMinMaxValues("maxExpires")
	TSM.MainUI.Operations.RegisterModule("Auctioning", private.GetAuctioningOperationSettings)
end



-- ============================================================================
-- Auctioning Operation Settings UI
-- ============================================================================

function private.GetAuctioningOperationSettings(operationName)
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning")
	private.currentOperationName = operationName
	private.currentTab = private.currentTab or L["Details"]
	return UIElements.New("TabGroup", "tabs")
		:SetMargin(0, 0, 8, 0)
		:SetNavCallback(private.GetAuctioningSettings)
		:AddPath(L["Details"])
		:AddPath(L["Posting"])
		:AddPath(L["Canceling"])
		:SetPath(private.currentTab)
end

function private.GetDetailsSettings()
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning", "details")
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetBackgroundColor("PRIMARY_BG")
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Auctioning", "generalOptions", L["General Options"], L["Adjust some general settings."])
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("VERTICAL")
				:AddChildrenWithFunction(private.AddMaxStackSizeSetting)
				:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("ignoreLowDuration", L["Ignore auctions by duration"])
					:SetMargin(0, 0, 0, 16)
					:AddChild(UIElements.New("ListDropdown", "dropdown")
						:SetHeight(24)
						:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, "ignoreLowDuration"))
						:SetItems(IGNORE_DURATION_OPTIONS)
						:SetSelectedItemByIndex(operation.ignoreLowDuration + 1, true)
						:SetScript("OnSelectionChanged", private.IgnoreLowDurationOnSelectionChanged)
						:SetTooltip(SETTING_TOOLTIPS.ignoreLowDuration)
					)
				)
				:AddChildrenWithFunction(private.AddBlacklistPlayers)
			)
		)
		:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Auctioning", private.currentOperationName))
end

function private.AddMaxStackSizeSetting(frame)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		frame:AddChild(private.CreateToggleLine("matchStackSize", L["Match stack size"]))
	end
end

function private.GetPostingSettings()
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning", "posting")
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:SetBackgroundColor("PRIMARY_BG")
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Auctioning", "postingSettings", L["Posting Options"], L["Adjust the settings below to set how groups attached to this operation will be auctioned."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("duration", L["Auction duration"])
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("ListDropdown", "dropdown")
					:SetHeight(24)
					:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, "duration"))
					:SetItems(AuctionHouse.DURATIONS)
					:SetSettingInfo(operation, "duration")
					:SetTooltip(SETTING_TOOLTIPS.duration)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("postCap", L["Post cap"], POST_CAP_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.postCap)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChildrenWithFunction(private.AddStackSizeSettings)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("keepQuantity", L["Amount kept in bags"], KEEP_QUANTITY_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.keepQuantity)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("maxExpires", L["Don't post after this many expires"], MAX_EXPIRES_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.maxExpires)
				:SetMargin(0, 0, 0, 4)
			)
		)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Auctioning", "priceSettings", L["Posting Price"], L["Adjust the settings below to set how groups attached to this operation will be priced."])
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("bidPercent", L["Set bid as percentage of buyout"])
				:SetMargin(0, 0, 0, 12)
				:AddChild(UIElements.New("Frame", "content")
					:SetLayout("HORIZONTAL")
					:SetHeight(24)
					:AddChild(UIElements.New("Input", "input")
						:SetMargin(0, 8, 0, 0)
						:SetBackgroundColor("ACTIVE_BG")
						:SetValidateFunc(private.BidPercentValidateFunc)
						:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, "bidPercent"))
						:SetValue((operation.bidPercent * 100).."%")
						:SetScript("OnValueChanged", private.BidPercentOnValueChanged)
						:SetTooltip(SETTING_TOOLTIPS.bidPercent, "__parent")
					)
					:AddChild(UIElements.New("Text", "label")
						:SetWidth("AUTO")
						:SetFont("BODY_BODY3")
						:SetFormattedText(L["Enter a value from %d - %d%%"], 0, 100)
						:SetTextColor(Operation.HasRelationship("Auctioning", private.currentOperationName, "bidPercent") and "TEXT_DISABLED" or "TEXT")
					)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("undercut", L["Undercut amount"], UNDERCUT_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.undercut)
				:SetMargin(0, 0, 0, 12)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("minPrice", L["Minimum price"], PRICE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.minPrice))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("priceReset", L["When below minimum:"])
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 12, 12)
				:AddChild(UIElements.New("SelectionDropdown", "dropdown")
					:SetWidth(240)
					:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, "priceReset"))
					:SetItems(BELOW_MIN_ITEMS, BELOW_MIN_KEYS)
					:SetSettingInfo(operation, "priceReset")
					:SetTooltip(SETTING_TOOLTIPS.priceReset)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("maxPrice", L["Maximum price"], PRICE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.maxPrice))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("aboveMax", L["When above maximum:"])
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 12, 12)
				:AddChild(UIElements.New("SelectionDropdown", "dropdown")
					:SetWidth(240)
					:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, "aboveMax"))
					:SetItems(ABOVE_MAX_ITEMS, ABOVE_MAX_KEYS)
					:SetSettingInfo(operation, "aboveMax")
					:SetTooltip(SETTING_TOOLTIPS.aboveMax)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("normalPrice", L["Normal price"], PRICE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.normalPrice))
		)
end

function private.AddStackSizeSettings(frame)
	if not ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		return
	end
	frame:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("stackSize", L["Stack size"], STACK_SIZE_VALIDATE_CONTEXT, nil, nil, SETTING_TOOLTIPS.stackSize)
		:SetMargin(0, 0, 0, 12)
	)
	frame:AddChild(private.CreateToggleLine("stackSizeIsCap", L["Allow partial stack"]))
end

function private.GetCancelingSettings()
	UIUtils.AnalyticsRecordPathChange("main", "operations", "auctioning", "canceling")
	return UIElements.New("ScrollFrame", "settings")
		:SetPadding(8, 8, 8, 0)
		:AddChild(TSM.MainUI.Operations.CreateExpandableSection("Auctioning", "priceSettings", L["Canceling Options"], L["Adjust the settings below to set how groups attached to this operation will be cancelled."])
			:AddChild(private.CreateToggleLine("cancelUndercut", L["Cancel undercut auctions"]))
			:AddChild(private.CreateToggleLine("cancelRepost", L["Cancel to repost higher"]))
			:AddChild(TSM.MainUI.Operations.CreateLinkedPriceInput("cancelRepostThreshold", L["Repost threshold"], nil, nil, nil, SETTING_TOOLTIPS.cancelRepostThreshold))
		)
end

function private.GetAuctioningSettings(self, button)
	private.currentTab = button
	if button == L["Details"] then
		return private.GetDetailsSettings()
	elseif button == L["Posting"] then
		return private.GetPostingSettings()
	elseif button == L["Canceling"] then
		return private.GetCancelingSettings()
	else
		error("Unknown button!")
	end
end

function private.AddBlacklistPlayers(frame)
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
		return
	end
	frame:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("blacklist", L["Blacklisted players"])
		:AddChild(UIElements.New("Input", "input")
			:SetHeight(24)
			:SetBackgroundColor("ACTIVE_BG")
			:SetHintText(L["Enter player name"])
			:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, "blacklist"))
			:SetScript("OnEnterPressed", private.BlacklistInputOnEnterPressed)
		)
	)
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	if operation.blacklist == "" then return end
	local containerFrame = UIElements.New("Frame", "blacklistFrame")
		:SetLayout("FLOW")
	local index = 1
	for player in String.SplitIterator(operation.blacklist, ",") do
		containerFrame:AddChild(UIElements.New("Frame", "blacklist"..index)
			:SetLayout("HORIZONTAL")
			:SetSize(100, 20)
			:SetMargin(0, 12, 0, 0)
			:AddChild(UIElements.New("Text", "text")
				:SetWidth("AUTO")
				:SetMargin(0, 2, 0, 0)
				:SetFont("BODY_BODY2_MEDIUM")
				:SetText(player)
			)
			:AddChild(UIElements.New("Button", "removeBtn")
				:SetBackgroundAndSize("iconPack.14x14/Close/Circle")
				:SetContext(player)
				:SetScript("OnClick", private.RemoveBlacklistOnClick)
			)
			:AddChild(UIElements.New("Spacer", "spacer"))
		)
		index = index + 1
	end
	frame:AddChild(containerFrame)
end

function private.CreateToggleLine(key, label)
	local tooltip = SETTING_TOOLTIPS[key]
	assert(tooltip)
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	return TSM.MainUI.Operations.CreateLinkedSettingLine(key, label)
		:SetMargin(0, 0, 0, 12)
		:AddChild(UIElements.New("ToggleYesNo", "toggle")
			:SetHeight(18)
			:SetDisabled(Operation.HasRelationship("Auctioning", private.currentOperationName, key))
			:SetSettingInfo(operation, key)
			:SetTooltip(tooltip)
		)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.IgnoreLowDurationOnSelectionChanged(dropdown)
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	operation.ignoreLowDuration = dropdown:GetSelectedItemIndex() - 1
end

function private.BlacklistInputOnEnterPressed(input)
	local newPlayer = input:GetValue()
	if newPlayer == "" or strfind(newPlayer, ",") or newPlayer ~= String.Escape(newPlayer) then
		-- this is an invalid player name
		return
	end
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	if String.SeparatedContains(operation.blacklist, ",", newPlayer) then
		-- this player is already added
		input:SetValue("")
		return
	end
	operation.blacklist = (operation.blacklist == "") and newPlayer or (operation.blacklist..","..newPlayer)
	input:GetElement("__parent.__parent.__parent.__parent.__parent.__parent"):ReloadContent()
end

function private.RemoveBlacklistOnClick(button)
	AuctioningOperation.RemoveBlacklistPlayer(private.currentOperationName, button:GetContext())
	button:GetElement("__parent.__parent.__parent.__parent.__parent.__parent.__parent"):ReloadContent()
end

function private.BidPercentValidateFunc(_, value)
	value = strmatch(value, "^([0-9]+) *%%?$")
	value = tonumber(value)
	if not value or value < 0 or value > 100 then
		return false, L["Bid percent must be between 0 and 100."]
	end
	return true
end

function private.BidPercentOnValueChanged(input)
	local operation = Operation.GetSettings("Auctioning", private.currentOperationName)
	local value = strmatch(input:GetValue(), "^([0-9]+) *%%?$")
	value = tonumber(value) / 100
	operation.bidPercent = value
end
