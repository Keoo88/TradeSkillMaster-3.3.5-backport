-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMWoW = select(2, ...).LibTSMWoW
local DefaultUI = LibTSMWoW:Init("UI.DefaultUI")
local Event = LibTSMWoW:Include("Service.Event")
local EnumType = LibTSMWoW:From("LibTSMUtil"):Include("BaseType.EnumType")
local private = {
	visible = {},
	callbacks = {},
	callbackFilter = {},
}
local FRAMES = EnumType.New("DEFAULT_UI_FRAMES", {
	MAIL = EnumType.NewValue(),
	AUCTION_HOUSE = EnumType.NewValue(),
	BANK = EnumType.NewValue(),
	ACCOUNTBANK = EnumType.NewValue(),
	GUILDBANK = EnumType.NewValue(),
	MERCHANT = EnumType.NewValue(),
})



-- ============================================================================
-- Module Loading
-- ============================================================================

DefaultUI:OnModuleLoad(function()
	for _, frame in pairs(FRAMES) do
		private.visible[frame] = false
		private.callbacks[frame] = {}
		private.callbackFilter[frame] = {}
	end
	Event.Register("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", private.PlayerInteractionShowHandler)
	hooksecurefunc(PlayerInteractionFrameManager, "ShowFrame", private.PlayerInteractionShowHandler)
	Event.Register("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(_, frameType)
		if frameType == Enum.PlayerInteractionType.MailInfo then
			private.HandleEvent(FRAMES.MAIL, false)
		elseif frameType == Enum.PlayerInteractionType.Auctioneer then
			private.HandleEvent(FRAMES.AUCTION_HOUSE, false)
		elseif frameType == Enum.PlayerInteractionType.Banker then
			private.HandleEvent(FRAMES.BANK, false)
		elseif frameType == Enum.PlayerInteractionType.AccountBanker then
			private.HandleEvent(FRAMES.ACCOUNTBANK, false)
		elseif frameType == Enum.PlayerInteractionType.GuildBanker then
			private.HandleEvent(FRAMES.GUILDBANK, false)
		elseif frameType == Enum.PlayerInteractionType.Merchant then
			private.HandleEvent(FRAMES.MERCHANT, false)
		end
	end)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns whether or not the mail UI is visible.
---@return boolean
function DefaultUI.IsMailVisible()
	return private.visible[FRAMES.MAIL]
end

---Returns whether or not the auction house UI is visible.
---@return boolean
function DefaultUI.IsAuctionHouseVisible()
	return private.visible[FRAMES.AUCTION_HOUSE]
end

---Returns whether or not the default UI owned auctions are visible.
---@return boolean
function DefaultUI.IsDefaultOwnedAuctionTabVisible()
	return AuctionFrame and AuctionFrame:IsVisible() and AuctionFrame.selectedTab == 3
end

---Returns whether or not the bank UI is visible.
---@return boolean
function DefaultUI.IsBankVisible()
	return private.visible[FRAMES.BANK]
end

---Returns whether or not the account bank UI is visible.
---@return boolean
function DefaultUI.IsAccountBankVisible()
	return private.visible[FRAMES.ACCOUNTBANK]
end

---Returns whether or not the guild bank UI is visible.
---@return boolean
function DefaultUI.IsGuildBankVisible()
	return private.visible[FRAMES.GUILDBANK]
end

---Returns whether or not the merchant UI is visible.
---@return boolean
function DefaultUI.IsMerchantVisible()
	return private.visible[FRAMES.MERCHANT]
end

---Registers a callback for when the mail UI is visible.
---@param callback fun(visible: boolean)|fun() Callback function
---@param visibleFilter? boolean Only call the callback when the UI is visible
function DefaultUI.RegisterMailVisibleCallback(callback, visibleFilter)
	private.RegisterCallback(FRAMES.MAIL, callback, visibleFilter)
end

---Registers a callback for when the auction house UI is visible.
---@param callback fun(visible: boolean)|fun() Callback function
---@param visibleFilter? boolean Only call the callback when the UI is visible
function DefaultUI.RegisterAuctionHouseVisibleCallback(callback, visibleFilter)
	private.RegisterCallback(FRAMES.AUCTION_HOUSE, callback, visibleFilter)
end

---Registers a callback for when the bank UI is visible.
---@param callback fun(visible: boolean)|fun() Callback function
---@param visibleFilter? boolean Only call the callback when the UI is visible
function DefaultUI.RegisterBankVisibleCallback(callback, visibleFilter)
	private.RegisterCallback(FRAMES.BANK, callback, visibleFilter)
end

---Registers a callback for when the account bank UI is visible.
---@param callback fun(visible: boolean)|fun() Callback function
---@param visibleFilter? boolean Only call the callback when the UI is visible
function DefaultUI.RegisterAccountBankVisibleCallback(callback, visibleFilter)
	private.RegisterCallback(FRAMES.ACCOUNTBANK, callback, visibleFilter)
end

---Registers a callback for when the guild bank UI is visible.
---@param callback fun(visible: boolean)|fun() Callback function
---@param visibleFilter? boolean Only call the callback when the UI is visible
function DefaultUI.RegisterGuildBankVisibleCallback(callback, visibleFilter)
	private.RegisterCallback(FRAMES.GUILDBANK, callback, visibleFilter)
end

---Registers a callback for when the merchant UI is visible.
---@param callback fun(visible: boolean)|fun() Callback function
---@param visibleFilter? boolean Only call the callback when the UI is visible
function DefaultUI.RegisterMerchantVisibleCallback(callback, visibleFilter)
	private.RegisterCallback(FRAMES.MERCHANT, callback, visibleFilter)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.PlayerInteractionShowHandler(_, interactionType)
	if interactionType == Enum.PlayerInteractionType.MailInfo then
		private.HandleEvent(FRAMES.MAIL, true)
	elseif interactionType == Enum.PlayerInteractionType.Auctioneer then
		private.HandleEvent(FRAMES.AUCTION_HOUSE, true)
	elseif interactionType == Enum.PlayerInteractionType.Banker then
		private.HandleEvent(FRAMES.BANK, true)
	elseif interactionType == Enum.PlayerInteractionType.AccountBanker then
		private.HandleEvent(FRAMES.ACCOUNTBANK, true)
	elseif interactionType == Enum.PlayerInteractionType.GuildBanker then
		private.HandleEvent(FRAMES.GUILDBANK, true)
	elseif interactionType == Enum.PlayerInteractionType.Merchant then
		private.HandleEvent(FRAMES.MERCHANT, true)
	end
end

function private.RegisterCallback(frame, callback, visibleFilter)
	tinsert(private.callbacks[frame], callback)
	private.callbackFilter[frame][callback] = visibleFilter
end

function private.HandleEvent(frame, visible)
	assert(type(visible) == "boolean")
	if private.visible[frame] == visible then
		return
	end
	private.visible[frame] = visible
	for _, callback in ipairs(private.callbacks[frame]) do
		local filter = private.callbackFilter[frame][callback]
		if filter == nil then
			callback(visible)
		elseif filter == visible then
			callback()
		end
	end
end
