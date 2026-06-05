-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Banking = TSM:NewPackage("Banking")
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local String = TSM.LibTSMUtil:Include("Lua.String")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local ChatMessage = TSM.LibTSMService:Include("UI.ChatMessage")
local Container = TSM.LibTSMWoW:Include("API.Container")
local Guild = TSM.LibTSMWoW:Include("API.Guild")
local DefaultUI = TSM.LibTSMWoW:Include("UI.DefaultUI")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local private = {
	moveThread = nil,
	moveItems = {},
	restoreItems = {},
	restoreFrame = nil,
	callback = nil,
	openFrame = nil,
	frameCallbacks = {},
	bankFrameOpen = false,
}
local MOVE_WAIT_TIMEOUT = 2



-- ============================================================================
-- Module Functions
-- ============================================================================

function Banking.OnInitialize()
	private.moveThread = Threading.New("BANKING_MOVE", private.MoveThread)

	if ClientInfo.IsRetail() then
		Event.Register("BANKFRAME_OPENED", private.BankFrameOpened)
		Event.Register("BANKFRAME_CLOSED", private.BankFrameClosed)
		-- luacheck: globals Addon_SetBankType
		if Addon_SetBankType then
			hooksecurefunc("Addon_SetBankType", function(self)
				private.BankVisibilityChanged(BankFrame:IsShown())
			end)
		elseif BankFrame.BankPanel then
			hooksecurefunc(BankFrame.BankPanel, "SetBankType", function(self)
				private.BankVisibilityChanged(BankFrame:IsShown())
			end)
		end
	end

	DefaultUI.RegisterBankVisibleCallback(private.BankVisibilityChanged)
	DefaultUI.RegisterAccountBankVisibleCallback(private.BankVisibilityChanged)
	if ClientInfo.HasFeature(ClientInfo.FEATURES.GUILD_BANK) then
		DefaultUI.RegisterGuildBankVisibleCallback(private.GuildBankVisibilityChanged)
	end
end

function Banking.RegisterFrameCallback(callback)
	tinsert(private.frameCallbacks, callback)
end

function Banking.IsGuildBankOpen()
	return private.openFrame == "GUILD_BANK"
end

function Banking.IsBankOpen()
	return private.openFrame == "BANK"
end

function Banking.IsWarBankOpen()
	return private.openFrame == "WARBANK"
end

function Banking.MoveToBag(items, callback)
	assert(private.openFrame)
	local context = Banking.IsGuildBankOpen() and Banking.MoveContext.GetGuildBankToBag() or (Banking.IsWarBankOpen() and Banking.MoveContext.GetWarbankToBag() or Banking.MoveContext.GetBankToBag())
	private.StartMove(items, context, callback)
end

function Banking.MoveToBank(items, callback)
	assert(private.openFrame)
	local context = Banking.IsGuildBankOpen() and Banking.MoveContext.GetBagToGuildBank() or (Banking.IsWarBankOpen() and Banking.MoveContext.GetBagToWarbank() or Banking.MoveContext.GetBagToBank())
	private.StartMove(items, context, callback)
end

function Banking.EmptyBags(callback)
	assert(private.openFrame)
	local items = TempTable.Acquire()
	for _, _, _, itemString, quantity in Banking.Util.BagIterator(false) do
		items[itemString] = (items[itemString] or 0) + quantity
	end
	wipe(private.restoreItems)
	private.restoreFrame = private.openFrame
	private.callback = callback
	local context = Banking.IsGuildBankOpen() and Banking.MoveContext.GetBagToGuildBank() or (Banking.IsWarBankOpen() and Banking.MoveContext.GetBagToWarbank() or Banking.MoveContext.GetBagToBank())
	private.StartMove(items, context, private.EmptyBagsThreadCallbackWrapper)
	TempTable.Release(items)
end

function Banking.RestoreBags(callback)
	assert(private.openFrame)
	private.callback = callback
	local context = Banking.IsGuildBankOpen() and Banking.MoveContext.GetGuildBankToBag() or (Banking.IsWarBankOpen() and Banking.MoveContext.GetWarbankToBag() or Banking.MoveContext.GetBankToBag())
	private.StartMove(private.restoreItems, context, private.RestoreBagsThreadCallbackWrapper)
end

function Banking.CanRestoreBags()
	assert(private.openFrame)
	return private.openFrame == private.restoreFrame
end

function Banking.PutByFilter(filterStr)
	if not private.openFrame then
		return
	end
	local filterItemString = ItemString.Get(filterStr)
	filterStr = String.Escape(strlower(filterStr))

	local items = TempTable.Acquire()
	for _, _, _, itemString, quantity in Banking.Util.BagIterator(false) do
		items[itemString] = (items[itemString] or 0) + quantity
	end

	for itemString in pairs(items) do
		if not private.MatchesFilter(itemString, filterStr, filterItemString) then
			-- Remove this item
			items[itemString] = nil
		end
	end

	Banking.MoveToBank(items, private.GetPutCallback)
	TempTable.Release(items)
end

function Banking.GetByFilter(filterStr)
	if not private.openFrame then
		return
	end
	local filterItemString = ItemString.Get(filterStr)
	filterStr = String.Escape(strlower(filterStr))

	local items = TempTable.Acquire()
	for _, _, _, itemString, quantity in Banking.Util.OpenBankIterator(false) do
		items[itemString] = (items[itemString] or 0) + quantity
	end

	for itemString in pairs(items) do
		if not private.MatchesFilter(itemString, filterStr, filterItemString) then
			-- Remove this item
			items[itemString] = nil
		end
	end

	Banking.MoveToBag(items, private.GetPutCallback)
	TempTable.Release(items)
end



-- ============================================================================
-- Threads
-- ============================================================================

function private.MoveThread(context, callback)
	local numMoves = 0
	local emptySlotIds = Threading.AcquireSafeTempTable()
	context:GetEmptySlotsThreaded(emptySlotIds)
	local slotIds = Threading.AcquireSafeTempTable()
	local slotItemString = Threading.AcquireSafeTempTable()
	local slotMoveQuantity = Threading.AcquireSafeTempTable()
	local slotEndQuantity = Threading.AcquireSafeTempTable()
	for itemString, numQueued in pairs(private.moveItems) do
		for _, slotId, quantity in context:SlotIdIterator(itemString) do
			if numQueued > 0 then
				-- Find a suitable empty slot
				local targetSlotId = context:GetTargetSlotId(itemString, emptySlotIds, slotId)
				if targetSlotId then
					assert(not slotIds[slotId])
					slotIds[slotId] = targetSlotId
					slotItemString[slotId] = itemString
					slotMoveQuantity[slotId] = min(quantity, numQueued)
					slotEndQuantity[slotId] = max(quantity - numQueued, 0)
					numQueued = numQueued - slotMoveQuantity[slotId]
					numMoves = numMoves + 1
				else
					Log.Err("No target slot")
				end
			end
		end
		if numQueued > 0 then
			Log.Err("No slots with item (%s)", itemString)
		end
	end

	local numDone = 0
	while next(slotIds) do
		local movedSlotId = nil
		-- Do all the pending moves
		for slotId, targetSlotId in pairs(slotIds) do
			context:MoveSlot(slotId, targetSlotId, slotMoveQuantity[slotId])
			Threading.Yield()
			if private.openFrame == "GUILD_BANK" then
				movedSlotId = slotId
				break
			end
		end

		-- Wait for at least one to finish or the timeout to elapse
		local didMove = false
		local timeout = GetTime() + MOVE_WAIT_TIMEOUT
		while not didMove and GetTime() < timeout do
			-- Check which moves are done
			for slotId in pairs(slotIds) do
				if private.openFrame ~= "GUILD_BANK" or slotId == movedSlotId then
					if context:GetSlotQuantity(slotId) <= slotEndQuantity[slotId] then
						didMove = true
						slotIds[slotId] = nil
						numDone = numDone + 1
						callback("MOVED", slotItemString[slotId], slotMoveQuantity[slotId])
					end
					if didMove and slotId == movedSlotId then
						break
					end
					Threading.Yield()
				end
			end
			if didMove then
				callback("PROGRESS", numDone / numMoves)
			end
			Threading.Yield(true)
		end
	end

	if private.openFrame == "GUILD_BANK" then
		Guild.QueryTab(Guild.GetCurrentTab())
	end

	TempTable.Release(slotIds)
	TempTable.Release(slotItemString)
	TempTable.Release(slotMoveQuantity)
	TempTable.Release(slotEndQuantity)
	TempTable.Release(emptySlotIds)
	callback("DONE")
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GlobalMouseUp(_, button)
	if button == "LeftButton" then
		local isWarBank = Container.CanAccessWarbank() and BankFrame:GetActiveBankType() == Enum.BankType.Account or false
		private.BankVisibilityChanged(BankFrame:IsShown(), isWarBank)
	end
end

function private.BankFrameOpened()
	if private.bankFrameOpen then
		return
	end
	private.bankFrameOpen = true
	Event.Register("GLOBAL_MOUSE_UP", private.GlobalMouseUp)
end

function private.BankFrameClosed()
	if not private.bankFrameOpen then
		return
	end
	private.bankFrameOpen = false
	Event.Unregister("GLOBAL_MOUSE_UP", private.GlobalMouseUp)
end

function private.BankVisibilityChanged(visible)
	local isWarBank = private.IsWarBankTabActive()
	if visible then
		if private.openFrame == (isWarBank and "WARBANK" or "BANK") then
			return
		end
		private.openFrame = isWarBank and "WARBANK" or "BANK"
	else
		if not private.openFrame then
			return
		end
		private.openFrame = nil
		private.StopMove()
	end
	for _, callback in ipairs(private.frameCallbacks) do
		callback(private.openFrame)
	end
end

function private.IsWarBankTabActive()
	if not Container.CanAccessWarbank() then
		return false
	end
	-- luacheck: globals Addon_GetBankType
	if Addon_GetBankType then
		return Addon_GetBankType() == Enum.BankType.Account
	else
		return BankFrame:GetActiveBankType() == Enum.BankType.Account
	end
end

function private.GuildBankVisibilityChanged(visible)
	if visible then
		if private.openFrame == "GUILD_BANK" then
			return
		end
		assert(not private.openFrame)
		private.openFrame = "GUILD_BANK"
	else
		if not private.openFrame then
			return
		end
		private.openFrame = nil
		private.StopMove()
	end
	for _, callback in ipairs(private.frameCallbacks) do
		callback(private.openFrame)
	end
end

function private.StartMove(items, context, callback)
	private.StopMove()
	wipe(private.moveItems)
	for itemString, quantity in pairs(items) do
		private.moveItems[itemString] = quantity
	end
	Threading.Start(private.moveThread, context, callback)
end

function private.StopMove()
	Threading.Kill(private.moveThread)
end

function private.EmptyBagsThreadCallbackWrapper(event, ...)
	if event == "MOVED" then
		local itemString, numMoved = ...
		private.restoreItems[itemString] = (private.restoreItems[itemString] or 0) + numMoved
	elseif event == "DONE" then
		if not next(private.restoreItems) then
			private.restoreFrame = private.openFrame
		end
	end
	private.callback(event, ...)
end

function private.RestoreBagsThreadCallbackWrapper(event, ...)
	if event == "DONE" then
		wipe(private.restoreItems)
		private.restoreFrame = nil
	end
	private.callback(event, ...)
end

function private.GetPutCallback(event)
	if event == "DONE" then
		ChatMessage.PrintUser(DONE)
	end
end

function private.MatchesFilter(itemString, filterStr, filterItemString)
	local name = strlower(ItemInfo.GetName(itemString) or "")
	return strmatch(ItemString.GetBase(itemString), filterStr) or strmatch(name, filterStr) or (filterItemString and itemString == filterItemString)
end
