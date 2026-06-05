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
	-- TODO: implement editing stack sizes
	self:AddChild(UIElements.New("Frame", "numStacks")
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Text", "label")
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY2")
			:SetText(AUCTION_NUM_STACKS..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetSize(62, 24)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetValidateFunc("NUMBER", "1:5000")
			:SetDisabled(true)
			:SetValuePublisher(self._state:PublisherForKeyChange("numStacks")
				:IgnoreNil()
			)
		)
	)
	self:AddChild(UIElements.New("Frame", "stackSize")
		:SetLayout("HORIZONTAL")
		:SetHeight(20)
		:SetMargin(0, 0, 0, 16)
		:AddChild(UIElements.New("Text", "label")
			:SetMargin(0, 8, 0, 0)
			:SetFont("BODY_BODY2")
			:SetText(AUCTION_STACK_SIZE..":")
		)
		:AddChild(UIElements.New("Input", "input")
			:SetSize(62, 24)
			:SetBackgroundColor("PRIMARY_BG_ALT")
			:SetValidateFunc("NUMBER", "1:5000")
			:SetDisabled(true)
			:SetValuePublisher(self._state:PublisherForKeyChange("stackSize")
				:IgnoreNil()
			)
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
	self:GetElement("price"):SetAuction(itemString, bid, buyout, stackSize)
	self:GetElement("duration.toggle"):SetOption(AuctionHouse.DURATIONS[postTime])
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function AuctioningEditDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_PRICE_IS_VALID_CHANGED" then
		state.priceIsValid = ...
	elseif action == "ACTION_SAVE_CLICKED" then
		local bid, buyout, perItem = self:GetElement("price"):GetPrices()
		local duration = Table.KeyByValue(AuctionHouse.DURATIONS, self:GetElement("duration.toggle"):GetValue())
		self:_SendActionScript("OnSaveClicked", bid, buyout, perItem, duration)
		manager:ProcessAction("ACTION_CLOSE_DIALOG")
	else
		error("Unknown action: "..tostring(action))
	end
end
