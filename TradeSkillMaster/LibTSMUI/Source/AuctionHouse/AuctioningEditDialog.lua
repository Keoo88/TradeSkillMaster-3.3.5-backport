-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local UIUtils = LibTSMUI:Include("Util.UIUtils")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local AuctionHouse = LibTSMUI:From("LibTSMWoW"):Include("API.AuctionHouse")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctioningEditDialog = UIElements.Define("AuctioningEditDialog", "Frame")
AuctioningEditDialog:_ExtendStateSchema()
	:AddOptionalStringField("itemString")
	:AddBooleanField("priceIsValid", true)
	:AddOptionalNumberField("numStacks")
	:AddOptionalNumberField("stackSize")
	:AddNumberField("bagQuantity", 0)
	:Commit()
AuctioningEditDialog:_AddActionScripts("OnSaveClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctioningEditDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("AUCTIONING_EDIT_DIALOG", self._state, self:__closure("_ActionHandler"))
end

function AuctioningEditDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(12)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:SetMouseEnabled(true)
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, -4, 10)
		:AddChild(UIElements.New("Spacer", "spacer")
			:SetWidth(24)
		)
		:AddChild(UIElements.New("Text", "title")
			:SetFont("BODY_BODY2_MEDIUM")
			:SetJustifyH("CENTER")
			:SetText(L["Edit Post"])
		)
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetMargin(0, -4, 0, 0)
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
		)
	)
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("Frame", "item")
		:SetLayout("HORIZONTAL")
		:SetPadding(6)
		:SetMargin(0, 0, 0, 16)
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
	)
	self:AddChild(UIElements.New("Frame", "numStacks")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Text", "label")
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY2")
			:SetText(AUCTION_NUM_STACKS..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetSize(62, 24)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetJustifyH("RIGHT")
			:SetValidateFunc("NUMBER", "1:5000")
			:SetManager(self._childManager)
			:SetValuePublisher(self._state:PublisherForKeyChange("numStacks")
				:IgnoreNil()
			)
			:SetAction("OnValueChanged", "ACTION_NUM_STACKS_CHANGED")
		)
		:AddChild(UIElements.New("ActionButton", "maxBtn")
			:SetSize(48, 24)
			:SetMargin(8, 0, 0, 0)
			:SetText(L["Max"])
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_MAX_NUM_STACKS")
		)
	)
	self:AddChild(UIElements.New("Frame", "stackSize")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Text", "label")
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY2")
			:SetText(AUCTION_STACK_SIZE..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetSize(62, 24)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetJustifyH("RIGHT")
			:SetValidateFunc("NUMBER", "1:5000")
			:SetManager(self._childManager)
			:SetValuePublisher(self._state:PublisherForKeyChange("stackSize")
				:IgnoreNil()
			)
			:SetAction("OnValueChanged", "ACTION_STACK_SIZE_CHANGED")
		)
		:AddChild(UIElements.New("ActionButton", "maxBtn")
			:SetSize(48, 24)
			:SetMargin(8, 0, 0, 0)
			:SetText(L["Max"])
			:SetManager(self._childManager)
			:SetAction("OnClick", "ACTION_MAX_STACK_SIZE")
		)
	)
	self:AddChild(UIElements.New("Frame", "duration")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, 0, 24)
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
		)
	)
	self:AddChild(UIElements.New("PostingPriceFields", "price")
		:SetManager(self._childManager)
		:SetAction("IsValidChanged", "ACTION_PRICE_IS_VALID_CHANGED")
	)
	self:AddChild(UIElements.New("ActionButton", "saveBtn")
		:SetHeight(24)
		:SetText(SAVE)
		:SetDisabledPublisher(self._state:PublisherForKeyChange("priceIsValid"):InvertBoolean())
		:SetManager(self._childManager)
		:SetAction("OnClick", "ACTION_SAVE_CLICKED")
	)
	self._state:SetAutoStorePaused(false)
end

---Sets the auction being editted.
---@param itemString string The item string
---@param postTime number The auction duration
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param numStacks number The number of stacks being posted
---@param stackSize number The stack size being posted
---@return AuctioningEditDialog
function AuctioningEditDialog:SetAuction(itemString, postTime, bid, buyout, numStacks, stackSize)
	self._state.itemString = itemString
	self._state.numStacks = numStacks
	self._state.stackSize = stackSize
	self._originalBid = bid
	self._originalBuyout = buyout
	assert(not self._bagQuery)
	self._bagQuery = BagTracking.CreateQueryBagsItemAuctionable(itemString)
	self:AddCancellable(self._bagQuery:Publisher()
		:MapToValue(self._bagQuery)
		:MapWithMethod("Sum", "quantity")
		:AssignToTableKey(self._state, "bagQuantity")
	)
	self:GetElement("price"):SetAuction(itemString, bid, buyout, stackSize)
	self:GetElement("duration.toggle"):SetOption(AuctionHouse.DURATIONS[postTime])
	return self
end

function AuctioningEditDialog:Release()
	-- Release the super first so the bag query's publisher (added via AddCancellable)
	-- is cancelled before we release the query itself (Query:_Release asserts no publishers).
	self.__super:Release()
	if self._bagQuery then
		self._bagQuery:Release()
		self._bagQuery = nil
	end
	self._originalBid = nil
	self._originalBuyout = nil
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AuctioningEditDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_PRICE_IS_VALID_CHANGED" then
		state.priceIsValid = ...
	elseif action == "ACTION_NUM_STACKS_CHANGED" then
		state.numStacks = tonumber(self:GetElement("numStacks.input"):GetValue())
	elseif action == "ACTION_STACK_SIZE_CHANGED" then
		state.stackSize = tonumber(self:GetElement("stackSize.input"):GetValue())
		if not state.stackSize then
			return
		end
		self:GetElement("price"):SetStackSize(state.stackSize)
		self:_RescalePerStackPrice(state)
	elseif action == "ACTION_MAX_NUM_STACKS" then
		if state.stackSize and state.stackSize > 0 then
			state.numStacks = max(min(floor(state.bagQuantity / state.stackSize), 5000), 1)
			self:GetElement("numStacks.input")
				:SetFocused(false)
				:Draw()
		end
	elseif action == "ACTION_MAX_STACK_SIZE" then
		local maxStack = ItemInfo.GetMaxStack(state.itemString) or 1
		state.stackSize = max(min(state.bagQuantity, maxStack, 5000), 1)
		self:GetElement("price"):SetStackSize(state.stackSize)
		-- Keep numStacks within what the bags can supply at the new size
		state.numStacks = max(min(state.numStacks or 1, floor(state.bagQuantity / state.stackSize)), 1)
		self:GetElement("stackSize.input")
			:SetFocused(false)
			:Draw()
		self:GetElement("numStacks.input")
			:SetFocused(false)
			:Draw()
		self:_RescalePerStackPrice(state)
	elseif action == "ACTION_SAVE_CLICKED" then
		local bid, buyout, perItem = self:GetElement("price"):GetPrices()
		local duration = Table.KeyByValue(AuctionHouse.DURATIONS, self:GetElement("duration.toggle"):GetValue())
		self:_SendActionScript("OnSaveClicked", bid, buyout, perItem, duration, state.numStacks, state.stackSize)
		manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end

---Rescales the per-stack price from the per-item original when the price is shown per stack.
function AuctioningEditDialog.__private:_RescalePerStackPrice(state)
	if not state.stackSize then
		return
	end
	local _, _, perItem = self:GetElement("price"):GetPrices()
	if perItem then
		-- Per-item price is independent of the stack size, nothing to rescale
		return
	end
	local bid = self._originalBid * state.stackSize
	local buyout = self._originalBuyout * state.stackSize
	self:GetElement("price"):SetAuction(state.itemString, bid, buyout, state.numStacks, state.stackSize)
end
