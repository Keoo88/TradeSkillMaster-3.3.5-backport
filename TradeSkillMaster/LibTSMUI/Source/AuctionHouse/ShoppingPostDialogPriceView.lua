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
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")
local Currency = LibTSMUI:From("LibTSMWoW"):Include("API.Currency")
local ClientInfo = LibTSMUI:From("LibTSMWoW"):Include("Util.ClientInfo")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ShoppingPostDialogPriceView = UIElements.Define("ShoppingPostDialogPriceView", "Frame")
ShoppingPostDialogPriceView:_ExtendStateSchema()
	:AddOptionalStringField("itemString")
	:AddBooleanField("priceIsValid", true)
	:AddBooleanField("stackSizeIsValid", true)
	:AddOptionalNumberField("stackSize")
	:AddOptionalNumberField("numStacks")
	:AddOptionalNumberField("duration")
	:AddOptionalNumberField("depositCost")
	:AddBooleanField("noMoney", false)
	:AddNumberField("bagQuantity", 0)
	:AddNumberField("baseItemBagQuantity", 0)
	:AddNumberField("undercut", 0)
	:AddNumberField("maxPostStack", 0)
	:AddNumberField("maxItemStack", 0)
	:Commit()
ShoppingPostDialogPriceView:_AddActionScripts("OnItemEditClicked", "OnPostClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingPostDialogPriceView:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("SHOPPING_POST_DIALOG_PRICE_VIEW", self._state, self:__closure("_ActionHandler"))
	self._originalPrices = {
		bid = nil,
		buyout = nil,
	}
	self._bagQuery = nil
	self._baseItemBagQuery = nil
end

function ShoppingPostDialogPriceView:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, -4, 10)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Spacer", "spacer")
			:SetWidth(24)
		)
		:AddChild(UIElements.New("Text", "title")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetJustifyH("CENTER")
			:SetText(L["Post from Shopping Scan"])
		)
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetMargin(0, -4, 0, 0)
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
		)
	)
	self:AddChild(UIElements.New("Frame", "item")
		:SetLayout("HORIZONTAL")
		:SetPadding(6)
		:SetMargin(0, 0, 0, 16)
		:SetManager(self._childManager)
		:SetRoundedBackgroundColor("PRIMARY_BG_ALT")
		:AddChild(UIElements.New("Button", "icon")
			:SetSize(36, 36)
			:SetMargin(0, 8, 0, 0)
			:SetBackgroundPublisher(self._state:PublisherForKeyChange("itemString")
				:MapNonNilWithFunction(ItemInfo.GetTexture)
			)
			:SetTooltipPublisher(self._state:PublisherForKeyChange("itemString"))
		)
		:AddChild(UIElements.New("Text", "name")
			:SetHeight(36)
			:SetFont("ITEM_BODY1")
			:SetTextPublisher(self._state:PublisherForKeyChange("itemString")
				:MapNonNilWithFunction(UIUtils.GetDisplayItemName)
				:MapNilToValue("")
			)
		)
		:AddChild(UIElements.New("Button", "editBtn")
			:SetMargin(8, 0, 0, 0)
			:SetBackgroundAndSize("iconPack.18x18/Edit")
			:SetAction("OnClick", "ACTION_ITEM_EDIT_CLICKED")
		)
	)
	self:AddChildIf(ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS), UIElements.New("Frame", "numStacks")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 12)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Text", "desc")
			:SetFont("BODY_BODY2")
			:SetText(AUCTION_NUM_STACKS..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetWidth(62)
			:SetMargin(0, 8, 0, 0)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetJustifyH("RIGHT")
			:SetValidateFunc("NUMBER", "0:5000")
			:SetValuePublisher(self._state:PublisherForKeyChange("numStacks")
				:IgnoreNil()
			)
			:SetAction("OnValueChanged", "ACTION_NUM_STACKS_VALUE_CHANGED")
		)
		:AddChild(UIElements.New("ActionButton", "maxBtn")
			:SetWidth(48)
			:SetText(L["Max"])
			:SetAction("OnClick", "ACTION_MAX_NUM_STACKS")
		)
	)
	self:AddChild(UIElements.New("Frame", "stackSize")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 12)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Text", "desc")
			:SetFont("BODY_BODY2")
			:SetText((ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) and AUCTION_STACK_SIZE or AUCTION_HOUSE_QUANTITY_LABEL)..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetWidth(62)
			:SetMargin(0, 8, 0, 0)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetJustifyH("RIGHT")
			:SetValidateFunc("NUMBER", "0:5000")
			:SetValuePublisher(self._state:PublisherForKeyChange("stackSize")
				:IgnoreNil()
			)
			:SetAction("OnValueChanged", "ACTION_STACK_SIZE_VALUE_CHANGED")
		)
		:AddChild(UIElements.New("ActionButton", "maxBtn")
			:SetWidth(48)
			:SetText(L["Max"])
			:SetAction("OnClick", "ACTION_MAX_STACK_SIZE")
		)
	)
	self:AddChild(UIElements.New("Frame", "duration")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 8)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Text", "desc")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2")
			:SetText(L["Duration"]..":")
		)
		:AddChild(UIElements.New("Toggle", "toggle")
			:SetMargin(0, 48, 0, 0)
			:AddOption(AuctionHouse.DURATIONS[1])
			:AddOption(AuctionHouse.DURATIONS[2])
			:AddOption(AuctionHouse.DURATIONS[3])
			:SetAction("OnValueChanged", "ACTION_DURATION_CHANGED")
		)
	)
	self:AddChild(UIElements.New("Spacer", "spacer"))
	self:AddChild(UIElements.New("PostingPriceFields", "price")
		:SetManager(self._childManager)
		:SetAction("IsValidChanged", "ACTION_PRICE_IS_VALID_CHANGED")
		:SetAction("OnPriceChanged", "ACTION_PRICE_CHANGED")
	)
	self:AddChild(UIElements.New("Frame", "deposit")
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 15)
		:AddChild(UIElements.New("Text", "desc")
			:SetWidth("AUTO")
			:SetFont("BODY_BODY2")
			:SetText(L["Deposit Cost"]..":")
		)
		:AddChild(UIElements.New("Text", "text")
			:SetFont("TABLE_TABLE1")
			:SetJustifyH("RIGHT")
			:SetTextPublisher(self._state:PublisherForExpression([[priceIsValid and stackSizeIsValid and depositCost or 0]])
				:MapWithFunction(Money.ToStringForUI)
			)
		)
	)
	self:AddChild(UIElements.New("ActionButton", "confirmBtn")
		:SetHeight(26)
		:SetText(L["Post Auction"])
		:SetManager(self._childManager)
		:SetTextPublisher(self._state:PublisherForKeyChange("noMoney")
			:MapBooleanWithValues(L["Not Enough Money"], L["Post Auction"])
		)
		:SetDisabledPublisher(self._state:PublisherForExpression([[not priceIsValid or not stackSizeIsValid or not depositCost or noMoney]]))
		:SetAction("OnClick", "ACTION_POST_AUCTION")
	)
	self._state:SetAutoStorePaused(false)

	self._state:PublisherForExpression([[(depositCost or 0) > ]]..Currency.GetMoney())
		:AssignToTableKey(self._state, "noMoney")

	self._state:PublisherForExpression([[stackSize and numStacks and (stackSize * numStacks) <= bagQuantity or false]])
		:AssignToTableKey(self._state, "stackSizeIsValid")

	if LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic() then
		self._state:PublisherForKeyChange("itemString")
			:IgnoreNil()
			:MapWithFunction(ItemInfo.GetMaxStack)
			:AssignToTableKey(self._state, "maxItemStack")
		self._state:PublisherForExpression([[baseItemBagQuantity > maxItemStack and maxItemStack or baseItemBagQuantity]])
			:AssignToTableKey(self._state, "maxPostStack")
	else
		self._state:PublisherForExpression([[bagQuantity > 5000 and 5000 or bagQuantity]])
			:AssignToTableKey(self._state, "maxPostStack")
	end

	self._state:PublisherForExpression([[stackSize and stackSize > maxPostStack and maxPostStack or nil]])
		:IgnoreNil()
		:AssignToTableKey(self._state, "stackSize")

	self._state:PublisherForKeyChange("stackSize")
		:IgnoreNil()
		:CallMethod(self:GetElement("price"), "SetStackSize")
end

function ShoppingPostDialogPriceView:Release()
	self.__super:Release()
	wipe(self._originalPrices)
	if self._bagQuery then
		self._bagQuery:Release()
		self._bagQuery = nil
	end
	if self._baseItemBagQuery then
		self._baseItemBagQuery:Release()
		self._baseItemBagQuery = nil
	end
end

---Sets the auction being editted.
---@param itemString string The item string
---@param duration number The auction duration
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param stackSize number The stack size being posted
---@param undercut number The amount to undercut by
---@return ShoppingPostDialogPriceView
function ShoppingPostDialogPriceView:SetAuction(itemString, duration, bid, buyout, stackSize, undercut)
	assert(not self._bagQuery and not self._baseItemBagQuery)
	self._bagQuery = BagTracking.CreateQueryBagsItemAuctionable(itemString)
	self:AddCancellable(self._bagQuery:Publisher()
		:MapToValue(self._bagQuery)
		:MapWithMethod("Sum", "quantity")
		:AssignToTableKey(self._state, "bagQuantity")
	)
	self._baseItemBagQuery = BagTracking.CreateQueryBagsItemAuctionable(ItemString.GetBase(itemString))
	self:AddCancellable(self._baseItemBagQuery:Publisher()
		:MapToValue(self._baseItemBagQuery)
		:MapWithMethod("Sum", "quantity")
		:AssignToTableKey(self._state, "baseItemBagQuantity")
	)
	self._state.itemString = itemString
	self._state.numStacks = 1
	self._state.stackSize = stackSize
	self._state.duration = duration
	self._state.undercut = undercut
	self._originalPrices.bid = bid
	self._originalPrices.buyout = buyout
	self:GetElement("price"):SetAuction(itemString, bid, buyout, self._state.numStacks, self._state.stackSize)
	self:GetElement("duration.toggle"):SetOption(AuctionHouse.DURATIONS[duration])
	self:GetElement("stackSize.input")
		:SetValidateFunc("NUMBER", "0:"..self._state.maxPostStack)
		:Draw()
	if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
		self:GetElement("numStacks.input"):Draw()
	end

	self:_UpdateDepositCost(self._state)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ShoppingPostDialogPriceView.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_DURATION_CHANGED" then
		state.duration = Table.KeyByValue(AuctionHouse.DURATIONS, self:GetElement("duration.toggle"):GetValue())
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_PRICE_IS_VALID_CHANGED" then
		state.priceIsValid = ...
	elseif action == "ACTION_PRICE_CHANGED" then
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_NUM_STACKS_VALUE_CHANGED" then
		state.numStacks = tonumber(self:GetElement("numStacks.input"):GetValue())
	elseif action == "ACTION_STACK_SIZE_VALUE_CHANGED" then
		state.stackSize = tonumber(self:GetElement("stackSize.input"):GetValue())
		self:_UpdateDepositCost(state)
		local _, _, perItem = self:GetElement("price"):GetPrices()
		if perItem then
			return
		end
		local bid = self._originalPrices.bid * state.stackSize - state.undercut
		local buyout = self._originalPrices.buyout * state.stackSize - state.undercut
		self:GetElement("price"):SetAuction(state.itemString, bid, buyout, state.numStacks, state.stackSize)
	elseif action == "ACTION_MAX_NUM_STACKS" then
		local maxNumStacks = min(floor(state.bagQuantity / state.stackSize), 5000)
		state.numStacks = maxNumStacks
		self:GetElement("numStacks.input")
			:SetFocused(false)
			:Draw()
		self:GetElement("stackSize.input")
			:SetFocused(false)
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_MAX_STACK_SIZE" then
		state.stackSize = state.maxPostStack
		if ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
			local maxNumStacks = min(floor(state.bagQuantity / state.stackSize), 5000)
			state.numStacks = min(state.numStacks, maxNumStacks)
			self:GetElement("numStacks.input")
				:SetFocused(false)
				:Draw()
		end
		self:GetElement("stackSize.input")
			:SetFocused(false)
			:Draw()
		self:_UpdateDepositCost(state)
	elseif action == "ACTION_ITEM_EDIT_CLICKED" then
		self:_SendActionScript("OnItemEditClicked")
	elseif action == "ACTION_POST_AUCTION" then
		local bid, buyout, perItem = self:GetElement("price"):GetPrices()
		if perItem and ClientInfo.HasFeature(ClientInfo.FEATURES.AH_STACKS) then
			bid = bid * state.stackSize
			buyout = buyout * state.stackSize
		end
		self:_SendActionScript("OnPostClicked", state.itemString, state.duration, state.stackSize, state.numStacks, bid, buyout)
	else
		error("Unknown action: "..tostring(action))
	end
end

function ShoppingPostDialogPriceView.__private:_UpdateDepositCost(state)
	if not state.itemString or not state.priceIsValid or not state.stackSizeIsValid then
		return
	end
	local bid, buyout, perItem = self:GetElement("price"):GetPrices()
	if perItem then
		bid = bid * state.stackSize
		buyout = buyout * state.stackSize
	end
	state.depositCost = AuctionHouseUIUtils.CalculateDeposit(state.itemString, false, state.duration, state.stackSize, bid, buyout)
end
