-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMApp = select(2, ...).LibTSMApp
local L = LibTSMApp.Locale.GetTable()
local AuctionChatMessage = LibTSMApp:Init("Service.AuctionChatMessage")
local AddonSettings = LibTSMApp:Include("Service.AddonSettings")
local TempTable = LibTSMApp:From("LibTSMUtil"):Include("BaseType.TempTable")
local Money = LibTSMApp:From("LibTSMUtil"):Include("UI.Money")
local AuctionHouse = LibTSMApp:From("LibTSMWoW"):Include("API.AuctionHouse")
local ChatFrame = LibTSMApp:From("LibTSMWoW"):Include("API.ChatFrame")
local SoundAlert = LibTSMApp:From("LibTSMWoW"):Include("UI.SoundAlert")
local ClientInfo = LibTSMApp:From("LibTSMWoW"):Include("Util.ClientInfo")
local Lifecycle = LibTSMApp:From("LibTSMWoW"):Include("Util.Lifecycle")
local Auction = LibTSMApp:From("LibTSMService"):Include("Auction")
local ItemInfo = LibTSMApp:From("LibTSMService"):Include("Item.ItemInfo")
local ChatMessage = LibTSMApp:From("LibTSMService"):Include("UI.ChatMessage")
local Theme = LibTSMApp:From("LibTSMService"):Include("UI.Theme")
local private = {
	settings = nil,
	prevLineId = nil,
}



-- ============================================================================
-- Module Loading
-- ============================================================================

AuctionChatMessage:OnModuleLoad(function()
	AddonSettings.RegisterOnLoad("Service.AuctionChatMessage", function(db)
		private.settings = db:NewView()
			:AddKey("char", "internalData", "auctionPrices")
			:AddKey("char", "internalData", "auctionMessages")
			:AddKey("global", "coreOptions", "auctionSaleSound")

		Auction.RegisterThrottledIndexCallback(private.HandleThrottledAuctionsUpdate)

		-- Setup enhanced sale / buy messages
		if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
			AuctionHouse.RegisterNotificationCallback(private.HandleNotification)
		else
			ChatFrame.AddMessageFilter(private.FilterSystemMsg)
			-- Setup auction created / cancelled filtering
			-- NOTE: This is delayed until the game is loaded to avoid taint issues
			Lifecycle.RegisterCallback(private.HandleLogin, Lifecycle.EVENT.LOGIN)
		end
	end)
end)



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.HandleLogin()
	ChatFrame.SuppressAuctionMessages()
	return true
end

function private.HandleThrottledAuctionsUpdate()
	local INVALID_STACK_SIZE = -1
	-- Recycle tables from private.settings.auctionPrices if we can so we're not creating a ton of garbage
	local freeTables = TempTable.Acquire()
	for _, tbl in pairs(private.settings.auctionPrices) do
		wipe(tbl)
		tinsert(freeTables, tbl)
	end
	wipe(private.settings.auctionPrices)
	wipe(private.settings.auctionMessages)
	local auctionPrices = TempTable.Acquire()
	local auctionStackSizes = TempTable.Acquire()
	local query = Auction.NewIndexQuery()
		:Select("itemLink", "stackSize", "buyout", "isSold")
		:Equal("isSold", false)
		:GreaterThan("buyout", 0)
		:OrderBy("index", true)
	for _, link, stackSize, buyout, isSold in query:IteratorAndRelease() do
		if buyout > 0 and not isSold then
			auctionPrices[link] = auctionPrices[link] or tremove(freeTables) or {}
			if stackSize ~= auctionStackSizes[link] then
				auctionStackSizes[link] = stackSize
			end
			tinsert(auctionPrices[link], buyout)
		end
	end
	for link, prices in pairs(auctionPrices) do
		local name = ItemInfo.GetName(link)
		if auctionStackSizes[link] ~= INVALID_STACK_SIZE then
			sort(prices)
			private.settings.auctionPrices[link] = prices
			if ClientInfo.HasFeature(ClientInfo.FEATURES.C_AUCTION_HOUSE) then
				private.settings.auctionMessages[name] = link
			else
				private.settings.auctionMessages[AuctionHouse.GetPurchaseMessage(name)] = link
			end
		end
	end
	TempTable.Release(freeTables)
	TempTable.Release(auctionPrices)
	TempTable.Release(auctionStackSizes)
end

function private.FilterSystemMsg(_, _, msg, ...)
	local lineID = select(10, ...)
	if lineID == private.prevLineId then
		return
	end
	private.prevLineId = lineID
	local chatMsg = nil
	if private.LastPurchaseMatchesAuctionWonMessage(msg) then
		-- We just bought an auction
		chatMsg = private.GetAuctionWonMessage()
	elseif private.settings.auctionMessages[msg] then
		-- We just sold an auction
		chatMsg = private.GetAuctionSoldMessage(msg)
	end
	if chatMsg then
		return nil, chatMsg, ...
	end
end

function private.LastPurchaseMatchesAuctionWonMessage(msg)
	local _, name, quantity = private.GetLastPurchase()
	return name and AuctionHouse.IsPurchaseMessage(msg, name, quantity) or false
end

function private.GetLastPurchase()
	local link, name, quantity, buyout = AuctionHouse.GetLastPurchase()
	if type(link) == "number" then
		link = ItemInfo.GetLink("i:"..link)
	end
	if not link then
		return nil, nil, nil, nil
	end
	name = ItemInfo.GetName(link) or name
	return link, name, quantity, buyout
end

function private.HandleNotification(notification, arg)
	local chatMsg = nil
	if notification == AuctionHouse.NOTIFICATION.BUY then
		chatMsg = private.GetAuctionWonMessage(arg)
	elseif notification == AuctionHouse.NOTIFICATION.SOLD then
		chatMsg = private.GetAuctionSoldMessage(arg)
	elseif notification == AuctionHouse.NOTIFICATION.OUTBID then
		chatMsg = arg
	elseif notification == AuctionHouse.NOTIFICATION.EXPIRED then
		chatMsg = arg
	elseif notification == AuctionHouse.NOTIFICATION.BID then
		chatMsg = arg
	elseif notification == AuctionHouse.NOTIFICATION.CANCELLED then
		chatMsg = arg
	end
	if not chatMsg then
		return
	end
	ChatMessage.PrintUserRaw(Theme.GetColor("BLIZZARD_YELLOW"):ColorText(chatMsg))
end

function private.GetAuctionSoldMessage(msg)
	local link = private.settings.auctionMessages[msg]
	local price = nil
	if link then
		price = tremove(private.settings.auctionPrices[link], 1)
		if #private.settings.auctionPrices[link] == 0 then
			-- This was the last auction
			private.settings.auctionMessages[msg] = nil
		end
	else
		link = msg
	end
	SoundAlert.Play(private.settings.auctionSaleSound)
	if price then
		return format(L["Your auction of %s has sold for %s!"], link, Money.ToStringForAH(price, "|cffffffff"))
	else
		return format(L["Your auction of %s has sold!"], link)
	end
end

function private.GetAuctionWonMessage(forceQuantity)
	local link, _, quantity, buyout = private.GetLastPurchase()
	if not link then
		return nil
	end
	return format(L["You won an auction for %sx%d for %s"], link, forceQuantity or quantity, Money.ToStringForAH(buyout, "|cffffffff"))
end
