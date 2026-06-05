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
local Math = LibTSMUI:From("LibTSMUtil"):Include("Lua.Math")
local Money = LibTSMUI:From("LibTSMUtil"):Include("UI.Money")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")



-- ============================================================================
-- Element Definition
-- ============================================================================

local AuctionItemBuyConfirmationDialog = UIElements.Define("AuctionItemBuyConfirmationDialog", "Frame")
AuctionItemBuyConfirmationDialog:_ExtendStateSchema()
	:AddBooleanField("isBuy", true)
	:AddNumberField("quantity", 0)
	:Commit()
AuctionItemBuyConfirmationDialog:_AddActionScripts("OnBuyoutClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function AuctionItemBuyConfirmationDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("AUCTION_ITEM_BUY_CONFIRMATION", self._state, self:__closure("_ActionHandler"))
end

function AuctionItemBuyConfirmationDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(12)
	self:SetMouseEnabled(true)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self._state:SetAutoStorePaused(true)
	self:AddChild(UIElements.New("Frame", "header")
		:SetLayout("HORIZONTAL")
		:SetHeight(24)
		:SetMargin(0, 0, -4, 10)
		:SetManager(self._childManager)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Text", "title")
			:SetWidth(240)
			:SetMargin(24, 0, 0, 0)
			:SetJustifyH("CENTER")
			:SetFont("BODY_BODY1_BOLD")
			:SetText(L["Buyout"])
		)
		:AddChild(UIElements.New("Spacer", "spacer"))
		:AddChild(UIElements.New("Button", "closeBtn")
			:SetMargin(0, -4, 0, 0)
			:SetBackgroundAndSize("iconPack.24x24/Close/Default")
			:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
		)
	)
	self:AddChild(UIElements.New("Frame", "content")
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
				)
				:AddChild(UIElements.New("Text", "name")
					:SetHeight(36)
					:SetFont("ITEM_BODY1")
				)
			)
			:AddChild(UIElements.New("Frame", "stacks")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 16)
				:AddChild(UIElements.New("Text", "desc")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2")
					:SetTextPublisher(self._state:PublisherForKeyChange("isBuy")
						:MapBooleanWithValues(L["Purchasing Auction"]..":", L["Bidding Auction"]..":")
					)
				)
				:AddChild(UIElements.New("Text", "number")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_TABLE1")
				)
			)
			:AddChild(UIElements.New("Frame", "price")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:SetMargin(0, 0, 0, 16)
				:AddChild(UIElements.New("Text", "desc")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2")
					:SetText(L["Unit Price"]..":")
				)
				:AddChild(UIElements.New("Text", "money")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_TABLE1")
				)
			)
			:AddChild(UIElements.New("Frame", "total")
				:SetLayout("HORIZONTAL")
				:SetHeight(20)
				:AddChild(UIElements.New("Text", "desc")
					:SetWidth("AUTO")
					:SetFont("BODY_BODY2")
					:SetText(L["Total Price"]..":")
				)
				:AddChild(UIElements.New("Text", "money")
					:SetJustifyH("RIGHT")
					:SetFont("TABLE_TABLE1")
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
			)
			:AddChild(UIElements.NewNamed("ActionButton", "confirmBtn", "TSMBidBuyConfirmBtn")
				:SetHeight(24)
				:SetTextPublisher(self._state:PublisherForKeyChange("isBuy")
					:MapBooleanWithValues(L["Buy Auction"], L["Bid Auction"])
				)
				:SetAction("OnClick", "ACTION_BUY_AUCTION")
			)
		)
	)
	self._state:SetAutoStorePaused(false)
end

function AuctionItemBuyConfirmationDialog:Release()
	self.__super:Release()
end

---Configures the confirmation details.
---@param isBuy boolean Whether this is a buy (vs. a bid) confirmation
---@param subRow AuctionSubRow The sub row
---@param quantity number The quantity
---@param auctionNum number The auction number
---@param numFound number The total number found
---@param marketValue? number The market value
---@return AuctionItemBuyConfirmationDialog
function AuctionItemBuyConfirmationDialog:Configure(isBuy, subRow, quantity, auctionNum, numFound, marketValue)
	self._state.isBuy = isBuy
	self._state.quantity = quantity

	local buyout = nil
	if isBuy then
		buyout = subRow:GetBuyouts()
	else
		buyout = subRow:GetRequiredBid(subRow)
	end
	local displayItemBuyout = ceil(buyout / quantity)
	local displayTotalBuyout = (LibTSMUI.IsVanillaClassic() or LibTSMUI.IsBCClassic() or LibTSMUI.IsWrathClassic()) and buyout or ceil(buyout / quantity)
	local itemString = subRow:GetItemString()
	local pct = marketValue and marketValue > 0 and displayItemBuyout > 0 and Math.Round(100 * displayItemBuyout / marketValue) or nil

	local contentLeftFrame = self:GetElement("content.left")
	contentLeftFrame:GetElement("item.icon")
		:SetBackground(ItemInfo.GetTexture(itemString))
		:SetTooltip(itemString)
	contentLeftFrame:GetElement("item.name")
		:SetText(UIUtils.GetDisplayItemName(itemString))
	contentLeftFrame:GetElement("stacks.number")
		:SetText(auctionNum.."/"..numFound)
	contentLeftFrame:GetElement("price.money")
		:SetText(format("%s (%s)", Money.ToStringForAH(displayItemBuyout), AuctionHouseUIUtils.GetMarketValuePercentText(pct)))
	contentLeftFrame:GetElement("total.money")
		:SetText(Money.ToStringForAH(displayTotalBuyout))

	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

---@param manager UIManager
function AuctionItemBuyConfirmationDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CONFIGURE" then
	elseif action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_BUY_AUCTION" then
		self:_SendActionScript("OnBuyoutClicked", state.quantity)
		self:GetBaseElement():HideDialog()
	else
		error("Unknown action: "..tostring(action))
	end
end
