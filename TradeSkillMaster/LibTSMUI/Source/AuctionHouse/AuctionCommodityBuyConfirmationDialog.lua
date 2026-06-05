-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local AuctionHouseUIUtils = LibTSMUI:Include("AuctionHouse.AuctionHouseUIUtils")
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMUI:From("LibTSMService"):Include("UI.ChatMessage")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")
local Currency = LibTSMUI:From("LibTSMWoW"):Include("API.Currency")
local DelayTimer = LibTSMUI:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local Log = LibTSMUI:From("LibTSMUtil"):Include("Util.Log")
local private = {}
local COPPER_PER_SILVER = 100



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctionCommodityBuyConfirmationDialog = UIElements.Define("AuctionCommodityBuyConfirmationDialog", "Frame")
AuctionCommodityBuyConfirmationDialog:_ExtendStateSchema()
	:AddNumberField("money", 0)
	:AddOptionalTableField("auctionScan")
	:AddOptionalTableField("subRow")
	:AddOptionalStringField("itemString")
	:AddNumberField("quantity", 1)
	:AddNumberField("maxQuantity", 1)
	:AddNumberField("marketValue", 0)
	:AddNumberField("totalPrice", 0)
	:AddNumberField("maxPrice", 0)
	:AddNumberField("marketThreshold", math.huge)
	:AddNumberField("alertThreshold", math.huge)
	:AddOptionalTableField("future")
	:AddOptionalNumberField("prepareQuantity")
	:AddOptionalNumberField("prepareTotalBuyout")
	:AddBooleanField("prepareSuccess", false)
	:AddNumberField("quoteDuration", 0)
	:AddBooleanField("requireManualClick", false)
	:Commit()
AuctionCommodityBuyConfirmationDialog:_AddActionScripts("OnBuyoutClicked", "OnCommodityPriceUpdated")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctionCommodityBuyConfirmationDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("AUCTION_COMMODITY_BUY_CONFIRMATION", self._state, self:__closure("_ActionHandler"))
		:SuppressActionLog("ACITON_QUANTITY_INPUT_CHANGED")
	self._quoteTimer = DelayTimer.New("COMMODITY_QUOTE_TIMER", self:__closure("_HandleQuoteTick"))
	self._closeTimer = DelayTimer.New("COMMODITY_CLOSE_TIMER", self:__closure("_HandleCloseDelayed"))
	self._marketValueFunc = nil
end

function AuctionCommodityBuyConfirmationDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(12)
	self:SetMouseEnabled(true)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:AddChild(UIElements.New("ViewContainer", "view")
		:SetManager(self._childManager)
		:SetNavCallback(self:__closure("_GetContentFrame"))
		:AddPath("loading", true)
		:AddPath("details")
		:AddPath("confirm")
	)
	self._state.money = Currency.GetMoney()
	self._state:PublisherForExpression([[maxPrice >= marketThreshold or maxPrice >= alertThreshold]])
		:AssignToTableKey(self._state, "requireManualClick")
end

function AuctionCommodityBuyConfirmationDialog:Release()
	self._marketValueFunc = nil
	if self._state.future then
		self._childManager:CancelFuture("future")
	end
	self._quoteTimer:Cancel()
	self._closeTimer:Cancel()
	self.__super:Release()
end

---Configures the commodity buy confirmation dialog.
---@param auctionScan AuctionScanManager The auction scan
---@param subRow AuctionSubRow The sub row
---@param defaultQuantity number The defualt quantity
---@param maxQuantity number The max quantity
---@param marketValueFunc fun(subRow: AuctionSubRow): number? The market value function
---@param marketThreshold? number The market value threshold
---@param alertThreshold? number The alert threshold
---@return AuctionCommodityBuyConfirmationDialog
function AuctionCommodityBuyConfirmationDialog:Configure(auctionScan, subRow, defaultQuantity, maxQuantity, marketValueFunc, marketThreshold, alertThreshold)
	self._state.auctionScan = auctionScan
	self._state.subRow = subRow
	self._state.itemString = subRow:GetItemString()
	self._marketValueFunc = marketValueFunc
	self._state.quantity = defaultQuantity
	self._state.maxQuantity = maxQuantity
	self._state.marketThreshold = marketThreshold or math.huge
	self._state.alertThreshold = alertThreshold or math.huge
	self._state.marketValue = marketValueFunc(subRow) or 0
	private.UpdateStatePrices(self._state)
	self:GetElement("view"):SetPath("details", true)
	self._childManager:ProcessAction("ACTION_PREPARE")
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AuctionCommodityBuyConfirmationDialog.__private:_GetContentFrame(_, path)
	local state = self._state
	if path == "loading" then
		-- Just a placeholder before everything is configured
		return UIElements.New("Frame", "loading")
	elseif path == "details" then
		private.UpdateStatePrices(state)
		private.UpdateStateQuoteDuration(state)
		self._state:SetAutoStorePaused(true)
		local details = UIElements.New("Frame", "details")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, -4, 10)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "title")
					:SetWidth(240)
					:SetMargin(24, 0, 0, 0)
					:SetJustifyH("CENTER")
					:SetFont("BODY_BODY1_BOLD")
					:SetText(L["Order Confirmation"])
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Button", "closeBtn")
					:SetMargin(0, -4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("Frame", "content")
				:SetLayout("HORIZONTAL")
				:SetManager(self._childManager)
				:AddChild(UIElements.New("Frame", "left")
					:SetLayout("VERTICAL")
					:AddChild(UIElements.New("Frame", "item")
						:SetLayout("HORIZONTAL")
						:SetPadding(6)
						:SetMargin(0, 0, 0, 16)
						:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
						:AddChild(UIElements.New("Button", "icon")
							:SetSize(36, 36)
							:SetMargin(0, 8, 0, 0)
							:SetBackground(ItemInfo.GetTexture(state.itemString))
							:SetTooltip(state.itemString)
						)
						:AddChild(UIElements.New("Text", "name")
							:SetHeight(36)
							:SetFont("ITEM_BODY1")
							:SetText(UIUtils.GetDisplayItemName(state.itemString))
						)
					)
					:AddChild(UIElements.New("Frame", "quantity")
						:SetLayout("HORIZONTAL")
						:SetHeight(24)
						:SetMargin(0, 0, 0, 16)
						:AddChild(UIElements.New("Text", "desc")
							:SetFont("BODY_BODY2")
							:SetText(AUCTION_HOUSE_QUANTITY_LABEL..":")
						)
						:AddChild(UIElements.New("Input", "input")
							:SetWidth(140)
							:SetJustifyH("RIGHT")
							:SetBackgroundColor("PRIMARY_BG_ALT")
							:SetValidateFunc("NUMBER", "1:"..state.maxQuantity)
							:SetValue(state.quantity)
							:SetAction("OnValueChanged", "ACITON_QUANTITY_INPUT_CHANGED")
						)
					)
					:AddChild(UIElements.New("Frame", "price")
						:SetLayout("HORIZONTAL")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 16)
						:AddChild(UIElements.New("Text", "desc")
							:SetWidth("AUTO")
							:SetFont("BODY_BODY2")
							:SetText(AUCTION_HOUSE_UNIT_PRICE_LABEL..":")
						)
						:AddChild(UIElements.New("Text", "money")
							:SetJustifyH("RIGHT")
							:SetFont("TABLE_TABLE1")
							:SetTextPublisher(state:PublisherForKeys("quantity", "totalPrice", "marketValue")
								:MapWithFunction(private.StateToPriceString)
							)
						)
					)
					:AddChild(UIElements.New("Frame", "total")
						:SetLayout("HORIZONTAL")
						:SetHeight(20)
						:AddChild(UIElements.New("Text", "desc")
							:SetWidth("AUTO")
							:SetFont("BODY_BODY2")
							:SetText(AUCTION_HOUSE_TOTAL_PRICE_LABEL..":")
						)
						:AddChild(UIElements.New("Text", "money")
							:SetJustifyH("RIGHT")
							:SetFont("TABLE_TABLE1")
							:SetTextPublisher(state:PublisherForKeyChange("totalPrice")
								:MapWithFunction(Money.ToStringForAH)
							)
						)
					)
					:AddChild(UIElements.New("Spacer", "spacer"))
					:AddChild(UIElements.New("Text", "warning")
						:SetHeight(20)
						:SetMargin(0, 0, 0, 6)
						:SetFont("BODY_BODY3")
						:SetJustifyH("CENTER")
						:SetTextColor("FEEDBACK_YELLOW")
						:SetText("")
						:SetTextPublisher(state:PublisherForKeys("requireManualClick", "maxPrice", "marketThreshold")
							:MapWithFunction(private.StateToWarningText)
						)
					)
					:AddChild(UIElements.NewNamed("ActionButton", "confirmBtn", "TSMBidBuyConfirmBtn")
						:SetHeight(24)
						:SetTextPublisher(state:PublisherForKeys("money", "totalPrice", "quantity", "maxQuantity", "prepareSuccess", "prepareQuantity", "quoteDuration")
							:MapWithFunction(private.StateToBuyText)
						)
						:SetDisabledPublisher(state:PublisherForExpression([[future ~= nil or money < totalPrice or totalPrice <= 0 or quantity < 1 or quantity > maxQuantity or (not prepareSuccess and prepareQuantity ~= nil)]]))
						:SetRequireManualClickPublisher(state:PublisherForKeyChange("requireManualClick"))
						:SetAction("OnClick", "ACTION_BUYOUT_CLICKED")
					)
				)
				:AddChild(UIElements.New("Frame", "item")
					:SetLayout("HORIZONTAL")
					:SetWidth(266)
					:SetMargin(12, 0, 0, 0)
					:SetPadding(4, 4, 8, 8)
					:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
					:AddChild(UIElements.New("CommodityList", "items")
						:SetBackgroundColor("PRIMARY_BG_ALT")
						:SetData(state.subRow:GetResultRow())
						:SelectQuantity(state.quantity)
						:SetMarketValueFunction(self._marketValueFunc)
						:SetMarketThreshold(state.marketThreshold)
						:SetAlertThreshold(state.alertThreshold)
						:SetAction("OnRowClick", "ACTION_COMMODITY_ROW_CLICKED")
					)
				)
			)
		self._state:SetAutoStorePaused(false)
		return details
	elseif path == "confirm" then
		private.UpdateStatePrices(state)
		private.UpdateStateQuoteDuration(state)
		self._state:SetAutoStorePaused(true)
		local confirm = UIElements.New("Frame", "confirm")
			:SetLayout("VERTICAL")
			:SetMargin(0, 0, -4, 10)
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 10)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "title")
					:SetWidth(240)
					:SetJustifyH("CENTER")
					:SetFont("BODY_BODY1_BOLD")
					:SetText(L["Buyout Above Threshold"])
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Button", "closeBtn")
					:SetMargin(0, -4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("Frame", "item")
				:SetLayout("HORIZONTAL")
				:SetPadding(6)
				:SetMargin(0, 0, 0, 16)
				:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
				:AddChild(UIElements.New("Button", "icon")
					:SetSize(36, 36)
					:SetMargin(0, 8, 0, 0)
					:SetBackground(ItemInfo.GetTexture(state.itemString))
					:SetTooltip(state.itemString)
				)
				:AddChild(UIElements.New("Text", "name")
					:SetHeight(36)
					:SetFont("ITEM_BODY1")
					:SetText(UIUtils.GetDisplayItemName(state.itemString))
				)
			)
			:AddChild(UIElements.New("Frame", "quantity")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, 0, 16)
				:AddChild(UIElements.New("Text", "desc")
					:SetFont("BODY_BODY2")
					:SetText(AUCTION_HOUSE_QUANTITY_LABEL..":")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "text")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_TABLE1")
					:SetText(state.quantity)
				)
			)
			:AddChild(UIElements.New("Frame", "price")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 16)
				:AddChild(UIElements.New("Text", "desc")
					:SetFont("BODY_BODY2")
					:SetText(AUCTION_HOUSE_UNIT_PRICE_LABEL..":")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "text")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_TABLE1")
					:SetTextPublisher(state:PublisherForKeys("quantity", "totalPrice", "marketValue")
						:MapWithFunction(private.StateToPriceString)
					)
				)
			)
			:AddChild(UIElements.New("Frame", "total")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 34)
				:AddChild(UIElements.New("Text", "desc")
					:SetFont("BODY_BODY2")
					:SetText(AUCTION_HOUSE_TOTAL_PRICE_LABEL..":")
				)
				:AddChild(UIElements.New("Spacer", "spacer"))
				:AddChild(UIElements.New("Text", "text")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_TABLE1")
					:SetTextPublisher(state:PublisherForKeyChange("totalPrice")
						:MapWithFunction(Money.ToStringForAH)
					)
				)
			)
			:AddChild(UIElements.New("Frame", "footer")
				:SetLayout("HORIZONTAL")
				:SetMargin(0, 0, 0, 16)
				:AddChild(UIElements.New("ActionButton", "cancelBtn")
					:SetSize(298, 24)
					:SetMargin(0, 8, 0, 0)
					:SetText(L["No, cancel"])
					:SetAction("OnClick", "ACTION_CANCEL_CONFIRMATION")
				)
				:AddChild(UIElements.NewNamed("ActionButton", "confirmBtn", "TSMBidBuyConfirmBtn")
					:SetHeight(24)
					:SetTextPublisher(state:PublisherForKeyChange("quoteDuration")
						:MapWithFunction(private.QuoteDurationToConfirmText)
					)
					:SetDisabledPublisher(state:PublisherForKeyChange("future"):MapBooleanNotEquals(nil))
					:SetAction("OnClick", "ACTION_BUYOUT_CONFIRMED")
				)
			)
		self._state:SetAutoStorePaused(false)
		return confirm
	else
		error("Invalid path: "..tostring(path))
	end
end

---@param manager UIManager
function AuctionCommodityBuyConfirmationDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACITON_QUANTITY_INPUT_CHANGED" then
		state.quantity = tonumber(self:GetElement("view.details.content.left.quantity.input"):GetValue())
		self:_UpdateDetails(state, false)
	elseif action == "ACTION_BUYOUT_CLICKED" then
		if not state.prepareSuccess then
			-- This is a prepare click
			return manager:ProcessAction("ACTION_PREPARE")
		end
		assert(state.prepareQuantity == state.quantity)
		private.UpdateStatePrices(state)
		if state.maxPrice >= state.marketThreshold or state.maxPrice >= state.alertThreshold then
			self:GetElement("view"):SetPath("confirm", true)
			return
		end
		self:_SendActionScript("OnBuyoutClicked", state.quantity)
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_COMMODITY_ROW_CLICKED" then
		local index = ...
		local input = self:GetElement("view.details.content.left.quantity.input")
		local quantity = self:GetElement("view.details.content.item.items"):GetTotalQuantity(index)
		input:SetValue(quantity)
			:Draw()
		state.quantity = quantity
		manager:ProcessAction("ACTION_PREPARE")
		self:_UpdateDetails(state, true)
	elseif action == "ACTION_PREPARE" then
		if state.quantity == state.prepareQuantity then
			return
		end
		if state.future then
			manager:CancelFuture("future")
		end
		state.prepareQuantity = state.quantity
		state.prepareSuccess = false
		private.UpdateStatePrices(state)
		state.prepareTotalBuyout = state.totalPrice
		local itemBuyout = state.quantity > 0 and Math.Ceil(state.totalPrice / state.quantity, LibTSMUI.IsPandaClassic() and 1 or COPPER_PER_SILVER)
		local result, future = state.auctionScan:PrepareForBidOrBuyout(nil, state.subRow, true, state.quantity, itemBuyout)
		if not result then
			state.prepareQuantity = nil
			return
		elseif future then
			self._childManager:ManageFuture("future", future, "ACTION_FUTURE_DONE")
		end
		private.UpdateStateQuoteDuration(state)
		if state.prepareSuccess then
			self._quoteTimer:RunForTime(20)
		else
			self._quoteTimer:Cancel()
		end
	elseif action == "ACTION_FUTURE_DONE" then
		local result = ...
		if not result or result ~= state.prepareTotalBuyout then
			-- The unit price changed
			ChatMessage.PrintUser(L["Failed to buy auction."])
			self:_SendActionScript("OnCommodityPriceUpdated")
			self._closeTimer:RunForFrames(0)
			return
		end
		state.prepareSuccess = state.quantity == state.prepareQuantity
		private.UpdateStatePrices(state)
		private.UpdateStateQuoteDuration(state)
		if state.prepareSuccess then
			self._quoteTimer:RunForTime(20)
		else
			self._quoteTimer:Cancel()
		end
	elseif action == "ACTION_CANCEL_CONFIRMATION" then
		self:GetElement("view"):SetPath("details", true)
		self:_UpdateDetails(state, true)
	elseif action == "ACTION_BUYOUT_CONFIRMED" then
		local inputQuantity = state.quantity
		self:_SendActionScript("OnBuyoutClicked", inputQuantity)
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end

function AuctionCommodityBuyConfirmationDialog.__private:_UpdateDetails(state, noListUpdate)
	private.UpdateStatePrices(state)
	if not noListUpdate then
		self:GetElement("view.details.content.item.items"):SelectQuantity(state.quantity)
	end
	if state.quantity ~= state.prepareQuantity then
		state.prepareSuccess = false
		state.prepareQuantity = nil
	end
	private.UpdateStateQuoteDuration(state)
	if state.prepareSuccess then
		self._quoteTimer:RunForTime(20)
	else
		self._quoteTimer:Cancel()
	end
end

function AuctionCommodityBuyConfirmationDialog.__private:_HandleQuoteTick()
	local state = self._state
	private.UpdateStateQuoteDuration(state)
	if state.quoteDuration <= 0 then
		Log.Info("Commodity quote timed out")
		local view = self:GetElement("view")
		if view:GetPath() == "confirm" then
			view:SetPath("details", true)
		end
		state.prepareSuccess = false
		state.prepareQuantity = nil
		self._quoteTimer:Cancel()
		private.UpdateStateQuoteDuration(state)
	else
		self._quoteTimer:RunForTime(1)
	end
end

function AuctionCommodityBuyConfirmationDialog.__private:_HandleCloseDelayed()
	self._childManager:ProcessAction("ACTION_CLOSE_DIALOG")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.UpdateStatePrices(state)
	local remainingQuantity = state.quantity
	local totalPrice, maxPrice = 0, 0
	for _, query in state.auctionScan:QueryIterator() do
		for _, subRow in query:ItemSubRowIterator(state.itemString) do
			if remainingQuantity > 0 then
				local _, itemBuyout = subRow:GetBuyouts()
				local _, numOwnerItems = subRow:GetOwnerInfo()
				local quantityAvailable = subRow:GetQuantities() - numOwnerItems
				local quantityToBuy = min(quantityAvailable, remainingQuantity)
				totalPrice = totalPrice + (itemBuyout * quantityToBuy)
				remainingQuantity = remainingQuantity - quantityToBuy
				maxPrice = max(maxPrice, itemBuyout)
			end
		end
	end
	state.totalPrice = totalPrice
	state.maxPrice = maxPrice
end

function private.UpdateStateQuoteDuration(state)
	state.quoteDuration = AuctionHouse.GetQuoteDurationRemaining()
end

function private.StateToPriceString(state)
	local itemBuyout = state.quantity > 0 and Math.Ceil(state.totalPrice / state.quantity, LibTSMUI.IsPandaClassic() and 1 or COPPER_PER_SILVER) or 0
	local pct = state.marketValue > 0 and itemBuyout > 0 and Math.Round(100 * itemBuyout / state.marketValue) or nil
	local marketValueStr = AuctionHouseUIUtils.GetMarketValuePercentText(pct)
	return format("%s (%s)", Money.ToStringForAH(itemBuyout), marketValueStr)
end

function private.StateToBuyText(state)
	if state.money < state.totalPrice then
		return L["Not Enough Money"]
	elseif state.totalPrice <= 0 or state.quantity < 1 or state.quantity > state.maxQuantity then
		return L["Invalid Quantity"]
	elseif state.prepareSuccess then
		return state.quoteDuration <= 10 and format(L["Buy Commodity (%02d)"], state.quoteDuration) or L["Buy Commodity"]
	elseif state.prepareQuantity then
		return L["Preparing..."]
	else
		return L["Prepare Buy"]
	end
end

function private.QuoteDurationToConfirmText(quoteDuration)
	return quoteDuration <= 10 and format(L["Yes, I'm sure (%02d)"], quoteDuration) or L["Yes, I'm sure"]
end

function private.StateToWarningText(state)
	if not state.requireManualClick then
		return ""
	elseif state.maxPrice >= state.marketThreshold then
		return L["Contains auctions above your material value!"]
	else
		return L["Contains auctions above your alert threshold!"]
	end
end
