-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local L = LibTSMUI.Locale.GetTable()
local UIElements = LibTSMUI:Include("Util.UIElements")
local BagTracking = LibTSMUI:From("LibTSMService"):Include("Inventory.BagTracking")
local ItemString = LibTSMUI:From("LibTSMTypes"):Include("Item.ItemString")
local UIManager = LibTSMUI:From("LibTSMUtil"):IncludeClassType("UIManager")



-- ============================================================================
-- Element Definition
-- ============================================================================

local ShoppingPostDialog = UIElements.Define("ShoppingPostDialog", "Frame")
ShoppingPostDialog:_AddActionScripts("OnPostClicked")



-- ============================================================================
-- Public Class Methods
-- ============================================================================

function ShoppingPostDialog:__init(frame)
	self.__super:__init(frame)
	self._childManager = UIManager.Create("SHOPPING_POST_DIALOG", self._state, self:__closure("_ActionHandler"))
	self._auction = {
		itemString = nil,
		bid = nil,
		buyout = nil,
		stackSize = nil,
		undercut = nil,
		duration = nil,
	}
end

function ShoppingPostDialog:Acquire()
	self.__super:Acquire()
	self:SetLayout("VERTICAL")
	self:SetPadding(12)
	self:SetRoundedBackgroundColor("FRAME_BG")
	self:SetMouseEnabled(true)
	self:AddChild(UIElements.New("ViewContainer", "view")
		:SetManager(self._childManager)
		:SetNavCallback(self:__closure("_GetViewContentFrame"))
		:AddPath("posting", true)
		:AddPath("selection")
	)
end

function ShoppingPostDialog:Release()
	self.__super:Release()
	wipe(self._auction)
end

---Sets the auction being posted.
---@param itemString string The item string
---@param bid number The per-item bid
---@param buyout number The per-item buyout
---@param stackSize number The stack size being posted
---@param undercut number The amount to undercut by
---@param duration number The auction duration
---@return ShoppingPostDialog
function ShoppingPostDialog:SetAuction(itemString, bid, buyout, stackSize, undercut, duration)
	self._auction.itemString = itemString
	self._auction.bid = bid
	self._auction.buyout = buyout
	self._auction.stackSize = stackSize
	self._auction.undercut = undercut
	self._auction.duration = duration
	self:GetElement("view.posting"):SetAuction(self._auction.itemString, self._auction.duration, self._auction.bid, self._auction.buyout, 1, self._auction.stackSize, self._auction.undercut)
	return self
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ShoppingPostDialog.__private:_GetViewContentFrame(_, path)
	if path == "posting" then
		local frame = UIElements.New("ShoppingPostDialogPriceView", "posting")
			:SetAction("OnItemEditClicked", "ACTION_ITEM_EDIT_CLICKED")
			:SetAction("OnPostClicked", "ACTION_POST_CLICKED")
		if self._auction.itemString then
			frame:SetAuction(self._auction.itemString, self._auction.duration, self._auction.bid, self._auction.buyout, 1, self._auction.stackSize, self._auction.undercut)
		end
		return frame
	elseif path == "selection" then
		return UIElements.New("Frame", "selection")
			:SetLayout("VERTICAL")
			:AddChild(UIElements.New("Frame", "header")
				:SetLayout("HORIZONTAL")
				:SetHeight(24)
				:SetMargin(0, 0, -4, 10)
				:AddChild(UIElements.New("Spacer", "spacer")
					:SetWidth(24)
				)
				:AddChild(UIElements.New("Text", "title")
					:SetFont("BODY_BODY2_MEDIUM")
					:SetJustifyH("CENTER")
					:SetText(L["Item Selection"])
				)
				:AddChild(UIElements.New("Button", "closeBtn")
					:SetMargin(0, -4, 0, 0)
					:SetBackgroundAndSize("iconPack.24x24/Close/Default")
					:SetAction("OnClick", "ACTION_CLOSE_DIALOG")
				)
			)
			:AddChild(UIElements.New("SimpleItemList", "items")
				:SetQuery(BagTracking.CreateQueryBagsItemAuctionable(ItemString.GetBase(self._auction.itemString)))
				:SetAction("OnItemClick", "ACTION_ITEM_CLICKED")
			)
			:AddChild(UIElements.New("ActionButton", "backBtn")
				:SetMargin(0, 0, 9, 0)
				:SetHeight(26)
				:SetText(BACK)
				:SetAction("OnClick", "ACTION_ITEM_BACK")
			)
	else
		error("Unexpected path: "..tostring(path))
	end
end

function ShoppingPostDialog.__private:_ActionHandler(manager, state, action, ...)
	if action == "ACTION_CLOSE_DIALOG" then
		self:GetBaseElement():HideDialog()
	elseif action == "ACTION_ITEM_EDIT_CLICKED" then
		self:GetElement("view"):SetPath("selection", true)
	elseif action == "ACTION_POST_CLICKED" then
		self:_SendActionScript("OnPostClicked", ...)
		manager:ProcessAction("ACTION_CLOSE_DIALOG")
	elseif action == "ACTION_ITEM_CLICKED" then
		self._auction.itemString = ...
		manager:ProcessAction("ACTION_ITEM_BACK")
	elseif action == "ACTION_ITEM_BACK" then
		self:GetElement("view"):SetPath("posting", true)
	else
		error("Unknown action: "..tostring(action))
	end
end
