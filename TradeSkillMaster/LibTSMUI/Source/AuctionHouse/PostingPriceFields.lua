-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local AuctionHouseUIUtils = LibTSMUI:Include("AuctionHouse.AuctionHouseUIUtils")
local UIElements = LibTSMUI:Include("Util.UIElements")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")



-- ============================================================================
-- Element Definition
-- ============================================================================

local PostingPriceFields = UIElements.Define("PostingPriceFields", "Frame")
PostingPriceFields:_ExtendStateSchema()
	:AddBooleanField("perItem", true)
	:AddBooleanField("isCommodity", false)
	:AddBooleanField("bidIsValid", true)
	:AddBooleanField("buyoutIsValid", true)
	:AddOptionalNumberField("bidValue")
	:AddOptionalNumberField("buyoutValue")
	:AddOptionalNumberField("stackSize")
	:Commit()
PostingPriceFields:_AddActionScripts("IsValidChanged", "OnPriceChanged")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function PostingPriceFields:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("POSTING_PRICE_FIELDS", self._state, self:__closure("_ActionHandler"))
end

function PostingPriceFields:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("Frame", "per")
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 8)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Button", "item")
			:SetWidth("AUTO")
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY2_MEDIUM")
			:SetJustifyH("RIGHT")
			:SetText(L["Per Item"])
			:SetTextColorPublisher(self._state:PublisherForKeyChange("perItem")
				:MapBooleanWithValues("INDICATOR", "TEXT")
			)
			:SetAction("OnClick", "ACTION_PER_ITEM_TOGGLE")
		)
		:AddChildIf(ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS), UIElements.New("Button", "stack")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetJustifyH("RIGHT")
			:SetText(L["Per Stack"])
			:SetTextColorPublisher(self._state:PublisherForKeyChange("perItem")
				:MapBooleanWithValues("TEXT", "INDICATOR")
			)
			:SetAction("OnClick", "ACTION_PER_ITEM_TOGGLE")
		)
	)
	self:AddChild(UIElements.New("Frame", "bid")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 10)
		:AddChild(UIElements.New("Text", "desc")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2")
			:SetText(L["Bid Price"]..":")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Input", "input")
			:SetWidth(132)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetFont("TABLE_TABLE1")
			:SetValidateFunc(self:__closure("_BidBuyoutValidateFunc"))
			:SetJustifyH("RIGHT")
			:SetTabPaths("__parent.__parent.buyout.input", "__parent.__parent.buyout.input")
			:SetDisabledPublisher(self._state:PublisherForKeyChange("isCommodity"))
			:SetManager(self._childManager)
			:SetAction("OnValidationChanged", "ACTION_UPDATE_BID_BUYOUT_IS_VALID")
			:SetAction("OnValueChanged", "ACTION_BID_VALUE_CHANGED")
			:SetAction("OnEnterPressed", "ACTION_BID_ENTER_PRESSED")
		)
	)
	self:AddChild(UIElements.New("Frame", "buyout")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Text", "desc")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2")
			:SetText(L["Buyout Price"]..":")
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Input", "input")
			:SetWidth(132)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetFont("TABLE_TABLE1")
			:SetValidateFunc(self:__closure("_BidBuyoutValidateFunc"))
			:SetJustifyH("RIGHT")
			:SetTabPaths("__parent.__parent.bid.input", "__parent.__parent.bid.input")
			:SetManager(self._childManager)
			:SetAction("OnValidationChanged", "ACTION_UPDATE_BID_BUYOUT_IS_VALID")
			:SetAction("OnValueChanged", "ACTION_BUYOUT_VALUE_CHANGED")
			:SetAction("OnEnterPressed", "ACTION_BUYOUT_ENTER_PRESSED")
		)
	)
	self._state:SetAutoStorePaused(false)

	self._state:PublisherForKeyChange("bidValue")
		:IgnoreNil()
		:CallFunction(self:__closure("_UpdateBidInput"))

	self._state:PublisherForKeyChange("buyoutValue")
		:IgnoreNil()
		:CallFunction(self:__closure("_UpdateBuyoutInput"))

	self._state:PublisherForExpression([[bidIsValid and buyoutIsValid and buyoutValue and bidValue and (buyoutValue == 0 or bidValue <= buyoutValue)]])
		:CallFunction(self:__closure("_SendIsValidChanged"))

	self._state:PublisherForKeys("bidValue", "buyoutValue", "perItem")
		:IgnoreIfKeyEquals("bidValue", nil)
		:IgnoreIfKeyEquals("buyoutValue", nil)
		:CallFunction(self:__closure("_SendOnPriceChanged"))
end

---Sets the auction being editted.
---@param itemString string The item string
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param numStacks number The number of stacks being posted
---@param stackSize number The stack size being posted
---@return PostingPriceFields
function PostingPriceFields:SetAuction(itemString, bid, buyout, numStacks, stackSize)
	self._state.isCommodity = ItemInfo.IsCommodity(itemString)
	self._state.bidValue = bid
	self._state.buyoutValue = buyout
	self._state.stackSize = stackSize
	return self
end

---Sets the current stack size.
---@param stackSize number The stack size being posted
---@return PostingPriceFields
function PostingPriceFields:SetStackSize(stackSize)
	self._state.stackSize = stackSize
	return self
end

---Gets the current price values.
---@return number bidValue
---@return number buyoutValue
---@return boolean perItem
function PostingPriceFields:GetPrices()
	local bidValue = self._state.bidValue
	local buyoutValue = self._state.buyoutValue
	if self._state.isCommodity then
		bidValue = buyoutValue
	end
	if buyoutValue > 0 and bidValue > buyoutValue then
		if self:GetElement("bid.input"):HasFocus() then
			-- Update the buyout to match
			buyoutValue = bidValue
		else
			-- Update the bid to match
			bidValue = buyoutValue
		end
	end
	return bidValue, buyoutValue, self._state.perItem
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function PostingPriceFields.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_UPDATE_BID_BUYOUT_IS_VALID" then
		state.bidIsValid = self:GetElement("bid.input"):IsValid()
		state.buyoutIsValid = self:GetElement("buyout.input"):IsValid()
	elseif action == "ACTION_PER_ITEM_TOGGLE" then
		if not ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
			return
		end
		state.perItem = not state.perItem
		if state.perItem then
			state.buyoutValue = state.buyoutValue / state.stackSize
			state.bidValue = state.bidValue / state.stackSize
		else
			state.buyoutValue = state.buyoutValue * state.stackSize
			state.bidValue = state.bidValue * state.stackSize
		end
		self:GetElement("bid.input")
			:SetFocused(false)
			:Draw()
		self:GetElement("buyout.input")
			:SetFocused(false)
			:Draw()
	elseif action == "ACTION_BID_VALUE_CHANGED" then
		state.bidValue = AuctionHouseUIUtils.ParseAuctionPrice(self:GetElement("bid.input"):GetValue(), false)
	elseif action == "ACTION_BUYOUT_VALUE_CHANGED" then
		state.buyoutValue = AuctionHouseUIUtils.ParseAuctionPrice(self:GetElement("buyout.input"):GetValue(), not state.isCommodity)
	elseif action == "ACTION_BID_ENTER_PRESSED" then
		if state.buyoutValue > 0 and state.bidValue > state.buyoutValue then
			-- Update the buyout to match
			state.buyoutValue = state.bidValue
			self:GetElement("buyout.input"):Draw()
		end
	elseif action == "ACTION_BUYOUT_ENTER_PRESSED" then
		if state.isCommodity or (state.buyoutValue > 0 and state.buyoutValue < state.bidValue) then
			-- Update the bid to match
			state.bidValue = state.buyoutValue
			self:GetElement("bid.input"):Draw()
		end
	else
		error("Unknown action: "..tostring(action))
	end
end

function PostingPriceFields.__private:_BidBuyoutValidateFunc(input, value)
	local errMsg = nil
	value, errMsg = AuctionHouseUIUtils.ParseAuctionPrice(value, input == self:GetElement("buyout.input") and not self._state.isCommodity)
	if not value then
		return false, L["Invalid price."].." "..errMsg
	end
	return true
end

function PostingPriceFields.__private:_UpdateBidInput()
	self:GetElement("bid.input")
		:SetValue(Money.ToStringForAH(self._state.bidValue, nil, self._state.isCommodity))
		:Draw()
end

function PostingPriceFields.__private:_UpdateBuyoutInput()
	self:GetElement("buyout.input")
		:SetValue(Money.ToStringForAH(self._state.buyoutValue))
		:Draw()
end

function PostingPriceFields.__private:_SendIsValidChanged(isValid)
	self:_SendActionScript("IsValidChanged", isValid)
end

function PostingPriceFields.__private:_SendOnPriceChanged()
	self:_SendActionScript("OnPriceChanged")
end
