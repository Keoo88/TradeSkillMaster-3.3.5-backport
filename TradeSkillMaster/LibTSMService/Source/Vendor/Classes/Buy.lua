-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Buy = LibTSMService:Init("Vendor.Buy")
local Log = LibTSMService:From("LibTSMUtil"):Include("Util.Log")
local ItemString = LibTSMService:From("LibTSMTypes"):Include("Item.ItemString")
local Merchant = LibTSMService:From("LibTSMWoW"):Include("API.Merchant")
local DelayTimer = LibTSMService:From("LibTSMWoW"):IncludeClassType("DelayTimer")
local ChatEvent = LibTSMService:From("LibTSMWoW"):Include("Service.ChatEvent")
local DefaultUI = LibTSMService:From("LibTSMWoW"):Include("UI.DefaultUI")
local private = {
	timeoutTimer = nil,
	pendingIndex = nil,
	pendingQuantity = 0,
	pendingItemString = nil,
	retryCount = 0,
}
local FIRST_BUY_TIMEOUT = 5
local FIRST_BUY_TIMEOUT_PER_STACK = 1
local CONSECUTIVE_BUY_TIMEOUT = 5
-- 3.3.5 fix: cap timeout-driven re-buys. If loot messages are lost/filtered the old
-- code re-bought the full remaining quantity every timeout, forever, massively
-- overbuying until the merchant window was closed.
local MAX_BUY_RETRIES = 2



-- ============================================================================
-- Module Loading
-- ============================================================================

Buy:OnModuleLoad(function()
	private.timeoutTimer = DelayTimer.New("VENDOR_BUY_TIMEOUT", private.BuyTimeout)
	DefaultUI.RegisterMerchantVisibleCallback(private.ClearPendingContext, false)
	ChatEvent.RegisterLootHandler(private.LootHandler)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Buys an item from the vendor.
---@param index number The index of the item to buy
---@param quantity number The quantity to buy
---@param itemString? string The intended item (guards against the merchant slot shifting)
function Buy.BuyIndex(index, quantity, itemString)
	private.retryCount = 0
	private.BuyIndex(index, quantity, itemString)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.BuyIndex(index, quantity, itemString)
	-- On 3.3.5 private servers the merchant item order can shift (via MERCHANT_UPDATE)
	-- between when this buy index was captured (e.g. when the quantity dialog was opened)
	-- and when we actually buy, which would silently buy the wrong item. If we know which
	-- item was intended, make sure the slot still holds it and re-resolve the index if it
	-- moved. Never buy a mismatched item.
	if itemString then
		local resolvedIndex = private.ResolveIndex(index, itemString)
		if not resolvedIndex then
			Log.Warn("Vendor item is no longer at the expected slot (%s); aborting buy", tostring(itemString))
			return
		end
		index = resolvedIndex
	end
	-- 3.3.5 fix: the "buy unit" delivered by BuyMerchantItem(index, 1) is the merchant
	-- BATCH size (4th return of GetMerchantItemInfo: 200 for ammo, 5 for water, 1 for
	-- singly-sold items) - NOT GetMerchantItemMaxStack, which is the item's inventory
	-- stack size (e.g. 20 for potions = the max count for ONE call). Using maxStack
	-- here made the code think one call delivered 20 potions when it delivered 1, so
	-- pendingQuantity never drained and the timeout kept drip-buying every few seconds
	-- until the merchant window was closed (asked for 20, got 40+).
	local _, batchSize = Merchant.GetItemInfo(index)
	batchSize = (batchSize and batchSize > 0) and batchSize or 1
	private.ClearPendingContext()
	private.pendingIndex = index
	private.pendingItemString = itemString
	-- 3.3.5: BuyMerchantItem(index, count) с count > 1 на приватных серверах
	-- отклоняется фейковыми ошибками ("inventory full", "not enough money").
	-- Эмулируем дефолтный UI: count=1 за вызов, повторяем batchesToBuy раз.
	local batchesToBuy = math.ceil(quantity / batchSize)
	local numBatches = 0
	for _ = 1, batchesToBuy do
		Merchant.BuyItem(index, 1)
		private.pendingQuantity = private.pendingQuantity + batchSize
		numBatches = numBatches + 1
		if numBatches > 100 then
			break
		end
	end
	Log.Info("Buying %d of %d (%d batches)", private.pendingQuantity, index, numBatches)
	private.timeoutTimer:RunForTime(numBatches * FIRST_BUY_TIMEOUT_PER_STACK + FIRST_BUY_TIMEOUT)
end

function private.LootHandler(msgItemLink, quantity)
	if not private.pendingIndex then
		return
	end
	local link = Merchant.GetItemLink(private.pendingIndex)
	if not link then
		Log.Err("Failed to get link (%s)", private.pendingIndex)
		private.ClearPendingContext()
		return
	end
	if ItemString.GetBase(msgItemLink) ~= ItemString.GetBase(link) then
		Log.Info("Unknown item link (%s, %s)", msgItemLink, link)
		return
	end
	Log.Info("Got CHAT_MSG_LOOT(%s) with a quantity of %s (%d pending)", msgItemLink, quantity, private.pendingQuantity)
	private.pendingQuantity = private.pendingQuantity - quantity
	-- Progress is being made, so reset the retry counter
	private.retryCount = 0
	if private.pendingQuantity <= 0 then
		-- We're done
		private.ClearPendingContext()
		return
	end

	-- Reset the timeout
	private.timeoutTimer:Cancel()
	private.timeoutTimer:RunForTime(CONSECUTIVE_BUY_TIMEOUT)
end

function private.BuyTimeout()
	if not private.pendingIndex then
		return
	end
	private.retryCount = private.retryCount + 1
	if private.retryCount > MAX_BUY_RETRIES then
		-- Loot messages likely lost/filtered; re-buying again risks overbuying.
		Log.Warn("Buy timed out %d times with %d still pending; giving up", private.retryCount - 1, private.pendingQuantity)
		private.ClearPendingContext()
		return
	end
	Log.Warn("Retrying buying (%d, %d)", private.pendingIndex, private.pendingQuantity)
	private.BuyIndex(private.pendingIndex, private.pendingQuantity, private.pendingItemString)
end

function private.ClearPendingContext()
	private.pendingIndex = nil
	private.pendingQuantity = 0
	private.pendingItemString = nil
	private.timeoutTimer:Cancel()
end

---Verifies that the given merchant slot still holds the intended item, re-resolving the
---index if the merchant list shifted. Returns nil if the item can't be found.
---@param index number The previously captured merchant slot index
---@param itemString string The intended item
---@return number?
function private.ResolveIndex(index, itemString)
	local wantBase = ItemString.GetBase(itemString)
	if not wantBase then
		return index
	end
	local link = Merchant.GetItemLink(index)
	if link and ItemString.GetBase(link) == wantBase then
		return index
	end
	-- The slot moved (or its link wasn't cached yet); find the current slot for this item.
	for i = 1, Merchant.GetNumItems() do
		local iLink = Merchant.GetItemLink(i)
		if iLink and ItemString.GetBase(iLink) == wantBase then
			return i
		end
	end
	return nil
end
