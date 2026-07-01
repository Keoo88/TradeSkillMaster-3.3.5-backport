-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Destroying = TSM:NewPackage("Destroying") ---@type AddonPackage
local ClientInfo = TSM.LibTSMWoW:Include("Util.ClientInfo")
local Container = TSM.LibTSMWoW:Include("API.Container")
local Spell = TSM.LibTSMWoW:Include("API.Spell")
local TradeSkill = TSM.LibTSMWoW:Include("API.TradeSkill")
local Database = TSM.LibTSMUtil:Include("Database")
local Event = TSM.LibTSMWoW:Include("Service.Event")
local SlotId = TSM.LibTSMWoW:Include("Type.SlotId")
local Table = TSM.LibTSMUtil:Include("Lua.Table")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Conversion = TSM.LibTSMTypes:Include("Item.Conversion")
local Reactive = TSM.LibTSMUtil:Include("Reactive")
local Future = TSM.LibTSMUtil:IncludeClassType("Future")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local BinarySearch = TSM.LibTSMUtil:Include("Util.BinarySearch")
local Threading = TSM.LibTSMTypes:Include("Threading")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local Conversions = TSM.LibTSMApp:Include("Service.Conversions")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local private = {
	combineThread = nil,
	destroyThread = nil,
	destroyThreadRunning = false,
	settings = nil,
	canDestroyCache = {},
	destroyQuantityCache = {},
	pendingCombines = {},
	newBagUpdate = false,
	pendingSpellId = nil,
	ignoreDB = nil,
	destroyInfoDB = nil,
	destroySpellId = nil,
	itemSpellId = nil,
	destroyResultCache = {},
	disenchantSkillLevel = nil,
	jewelcraftSkillLevel = nil,
	inscriptionSkillLevel = nil,
	combineFuture = Future.New("DESTROYING_COMBINE_FUTURE"),
	destroyFuture = Future.New("DESTROYING_DESTROY_FUTURE"),
	state = nil,
}
local SPELL_IDS = {
	milling = 51005,
	prospect = 31252,
	disenchant = 13262,
}
local ITEM_SUB_CLASS_METAL_AND_STONE = 7
local ITEM_SUB_CLASS_HERB = 9
local TARGET_SLOT_ID_MULTIPLIER = 1000000
local CLEANUP_TIME_THRESHOLD = 60 * 24 * 60 * 60
local CLEANUP_MAX_ENTRIES = 100
local GEM_CHIPS = {
	["i:129099"] = "i:129100",
	["i:130200"] = "i:129100",
	["i:130201"] = "i:129100",
	["i:130202"] = "i:129100",
	["i:130203"] = "i:129100",
	["i:130204"] = "i:129100",
}
local START_MESSAGE = newproxy()
local STATE_SCHEMA = Reactive.CreateStateSchema("DESTROYING_STATE")
	:AddBooleanField("canCombine", false)
	:Commit()



-- ============================================================================
-- Module Functions
-- ============================================================================

function Destroying.OnInitialize(settingsDB)
	private.state = STATE_SCHEMA:CreateState()
	private.combineThread = Threading.New("COMBINE_STACKS", private.CombineThread)
	Threading.SetCallback(private.combineThread, private.CombineThreadDone)
	private.destroyThread = Threading.New("DESTROY", private.DestroyThread)
	Threading.SetCallback(private.destroyThread, private.DestroyThreadDone)
	BagTracking.RegisterCallback(private.UpdateBagDB)

	private.settings = settingsDB:NewView()
		:AddKey("global", "internalData", "destroyingHistory")
		:AddKey("global", "destroyingOptions", "deAbovePrice")
		:AddKey("global", "destroyingOptions", "deMaxQuality")
		:AddKey("global", "destroyingOptions", "includeSoulbound")
		:AddKey("global", "userData", "destroyingIgnore")
		:RegisterCallback("deAbovePrice", private.UpdateBagDB)
		:RegisterCallback("deMaxQuality", private.UpdateBagDB)
		:RegisterCallback("includeSoulbound", private.UpdateBagDB)

	local cleanupTime = time() - CLEANUP_TIME_THRESHOLD
	for spellId, entries in pairs(private.settings.destroyingHistory) do
		-- Rely on the entries being sorted in ascending time
		local index, insertIndex = BinarySearch.Table(entries, cleanupTime, private.GetHistoryEntryTime)
		local removeThroughIndex = max((index or insertIndex) - 1, #entries - CLEANUP_MAX_ENTRIES)
		if removeThroughIndex > 0 then
			Log.Info("Removing %d old entries for %s", removeThroughIndex, tostring(spellId))
			Table.RemoveRange(entries, 1, removeThroughIndex)
		end
	end

	private.ignoreDB = Database.NewSchema("DESTROYING_IGNORE")
		:AddUniqueStringField("itemString")
		:AddBooleanField("ignoreSession")
		:AddBooleanField("ignorePermanent")
		:Commit()
	private.ignoreDB:BulkInsertStart()
	local used = TempTable.Acquire()
	for itemString in pairs(private.settings.destroyingIgnore) do
		itemString = ItemString.Get(itemString)
		if not used[itemString] then
			used[itemString] = true
			private.ignoreDB:BulkInsertNewRow(itemString, false, true)
		end
	end
	TempTable.Release(used)
	private.ignoreDB:BulkInsertEnd()

	private.destroyInfoDB = Database.NewSchema("DESTROYING_INFO")
		:AddUniqueStringField("itemString")
		:AddNumberField("minQuantity")
		:AddNumberField("spellId")
		:Commit()

	Event.Register("LOOT_READY", private.SendEventToThread)
	Event.Register("LOOT_CLOSED", private.SendEventToThread)
	BagTracking.RegisterCallback(function()
		private.SendEventToThread("BAG_UPDATE_DELAYED")
	end)
	Event.Register("UNIT_SPELLCAST_START", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_FAILED", private.SpellCastEventHandler)
	-- UNIT_SPELLCAST_FAILED_QUIET was added in MoP; it does not exist on 3.3.5a/Classic
	-- (registering an unknown event errors there) and UNIT_SPELLCAST_FAILED already
	-- covers failures, so only register it on versions where it's valid.
	if not ClientInfo.IsVanillaClassic() and not ClientInfo.IsBCClassic() and not ClientInfo.IsWrathClassic() then
		Event.Register("UNIT_SPELLCAST_FAILED_QUIET", private.SpellCastEventHandler)
	end
	Event.Register("UNIT_SPELLCAST_INTERRUPTED", private.SpellCastEventHandler)
	Event.Register("UNIT_SPELLCAST_SUCCEEDED", private.SpellCastEventHandler)

	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) then
		TradeSkill.SecureHookCraftSalvage(function(spellId, _, itemLocation)
			private.destroySpellId = spellId
			private.itemSpellId = Container.GetItemId(itemLocation.bagID, itemLocation.slotIndex)
		end)
		Event.Register("TRADE_SKILL_ITEM_CRAFTED_RESULT", private.TradeSkillCraftResultHandler)
		Event.Register("TRADE_SKILL_LIST_UPDATE", private.TradeSkillListUpdateHandler)
	end

	private.destroyFuture:SetScript("OnCleanup", function()
		private.destroyThreadRunning = false
		Threading.Kill(private.destroyThread)
	end)
	private.combineFuture:SetScript("OnCleanup", function()
		Threading.Kill(private.combineThread)
	end)
end

function Destroying.CreateBagQuery()
	return BagTracking.CreateQueryBags()
		:LeftJoin(private.ignoreDB, "itemString")
		:InnerJoin(private.destroyInfoDB, "itemString")
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:NotEqual("ignoreSession", true)
		:NotEqual("ignorePermanent", true)
		:GreaterThanOrEqual("quantity", Database.OtherFieldQueryParam("minQuantity"))
		:OrderBy("name", true)
		:OrderBy("slotId", true)
end

function Destroying.CanCombinePublisher()
	return private.state:PublisherForKeyChange("canCombine")
end

function Destroying.StartCombine()
	private.combineFuture:Start()
	Threading.Start(private.combineThread)
	return private.combineFuture
end

function Destroying.StartDestroy(button, itemString, slotId)
	private.destroyFuture:Start()
	private.destroyThreadRunning = true
	Threading.Start(private.destroyThread, button, itemString, slotId)
	-- we need the thread to run now so send it a sync message
	Threading.SendSyncMessage(private.destroyThread, START_MESSAGE)
	return private.destroyFuture
end

function Destroying.IgnoreItemSession(itemString)
	local row = private.ignoreDB:GetUniqueRow("itemString", itemString)
	if row then
		assert(not row:GetField("ignoreSession"))
		row:SetField("ignoreSession", true)
		row:Update()
		row:Release()
	else
		private.ignoreDB:NewRow()
			:SetField("itemString", itemString)
			:SetField("ignoreSession", true)
			:SetField("ignorePermanent", false)
			:Create()
	end
end

function Destroying.IgnoreItemPermanent(itemString)
	assert(not private.settings.destroyingIgnore[itemString])
	private.settings.destroyingIgnore[itemString] = true

	local row = private.ignoreDB:GetUniqueRow("itemString", itemString)
	if row then
		assert(not row:GetField("ignorePermanent"))
		row:SetField("ignorePermanent", true)
		row:Update()
		row:Release()
	else
		private.ignoreDB:NewRow()
			:SetField("itemString", itemString)
			:SetField("ignoreSession", false)
			:SetField("ignorePermanent", true)
			:Create()
	end
end

function Destroying.ForgetIgnoreItemPermanent(itemString)
	assert(private.settings.destroyingIgnore[itemString])
	private.settings.destroyingIgnore[itemString] = nil

	local row = private.ignoreDB:GetUniqueRow("itemString", itemString)
	assert(row and row:GetField("ignorePermanent"))
	if row:GetField("ignoreSession") then
		row:SetField("ignorePermanent", false)
		row:Update()
	else
		private.ignoreDB:DeleteRow(row)
	end
	row:Release()
end

function Destroying.CreateIgnoreQuery()
	-- 3.3.5: ItemInfo.GetTexture возвращает строку-путь (на retail число fileID).
	-- Подхватываем фактический тип чтобы schema не падал на assert defaultValue.
	local unknownTexture = ItemInfo.GetTexture(ItemString.GetUnknown())
	local textureFieldType = type(unknownTexture) == "number" and "number" or "string"
	return private.ignoreDB:NewQuery()
		:VirtualField("name", "string", ItemInfo.GetName, "itemString", "?")
		:VirtualField("texture", textureFieldType, ItemInfo.GetTexture, "itemString", unknownTexture)
		:Equal("ignorePermanent", true)
		:OrderBy("name", true)
end



-- ============================================================================
-- Combine Stacks Thread
-- ============================================================================

function private.CombineThread()
	while private.state.canCombine do
		for _, combineSlotId in ipairs(private.pendingCombines) do
			local sourceBag, sourceSlot, targetBag, targetSlot = private.CombineSlotIdToBagSlot(combineSlotId)
			Container.PickupItem(sourceBag, sourceSlot)
			Container.PickupItem(targetBag, targetSlot)
		end
		-- wait for the bagDB to change
		private.newBagUpdate = false
		Threading.WaitForFunction(private.HasNewBagUpdate)
	end
end

function private.CombineSlotIdToBagSlot(combineSlotId)
	local sourceSlotId = combineSlotId % TARGET_SLOT_ID_MULTIPLIER
	local targetSlotId = floor(combineSlotId / TARGET_SLOT_ID_MULTIPLIER)
	local sourceBag, sourceSlot = SlotId.Split(sourceSlotId)
	local targetBag, targetSlot = SlotId.Split(targetSlotId)
	return sourceBag, sourceSlot, targetBag, targetSlot
end

function private.HasNewBagUpdate()
	return private.newBagUpdate
end

function private.CombineThreadDone(result)
	private.combineFuture:Done(result)
end



-- ============================================================================
-- Destroy Thread
-- ============================================================================

---Finds the slotId of a bag slot that currently holds the given item, preferring
---one whose stack is at least minQuantity. Used to recover from a stale scroll
---table selection so the destroy macro always targets a slot that really has the
---item (otherwise a follow-up click can point at a just-emptied slot).
function private.FindBagSlotId(itemString, minQuantity)
	local fallbackSlotId = nil
	for slotId in Container.GetBagSlotIterator() do
		local bag, slot = SlotId.Split(slotId)
		local link = Container.GetItemLink(bag, slot)
		if link and ItemString.Get(link) == itemString then
			local stackCount = Container.GetStackCount(bag, slot) or 0
			if not minQuantity or stackCount >= minQuantity then
				return slotId
			end
			fallbackSlotId = fallbackSlotId or slotId
		end
	end
	return fallbackSlotId
end

---Finds the next destroyable item currently in the bags (one whose stack is at
---least its minQuantity). Used as a fallback when the scroll table's selection is
---stale and the originally selected item is gone entirely, so the "Destroy Next"
---button keeps working on rapid consecutive clicks. Returns the item, its slotId,
---spellId and minQuantity, or nil if nothing destroyable remains.
function private.FindNextDestroyable()
	for slotId in Container.GetBagSlotIterator() do
		local bag, slot = SlotId.Split(slotId)
		local link = Container.GetItemLink(bag, slot)
		local itemString = link and ItemString.Get(link)
		if itemString then
			local spellId = private.destroyInfoDB:GetUniqueRowField("itemString", itemString, "spellId")
			local minQuantity = private.destroyInfoDB:GetUniqueRowField("itemString", itemString, "minQuantity")
			if spellId and minQuantity and (Container.GetStackCount(bag, slot) or 0) >= minQuantity then
				return itemString, slotId, spellId, minQuantity
			end
		end
	end
	return nil
end

function private.DestroyThread(button, itemString, slotId)
	-- We get sent a sync message so we run right away
	assert(Threading.ReceiveMessage() == START_MESSAGE)

	local bag, slot = SlotId.Split(slotId)
	local spellId = private.destroyInfoDB:GetUniqueRowField("itemString", itemString, "spellId")
	local minQuantity = private.destroyInfoDB:GetUniqueRowField("itemString", itemString, "minQuantity")
	-- The slotId comes from the scroll table's current selection, which is very
	-- often stale on a follow-up click: the previous destroy just emptied this slot
	-- and neither the bag DB nor the scroll selection has refreshed yet, so we are
	-- handed the item we just destroyed (an empty slot). Building the macro against
	-- that empty slot casts on nothing and spins the button until the 10s timeout.
	-- First try to re-resolve a slot that still holds this exact item; if the item
	-- is gone entirely, fall back to the next destroyable item in the bags so the
	-- "Destroy Next" button keeps chewing through items on rapid consecutive clicks.
	local existingLink = Container.GetItemLink(bag, slot)
	if not existingLink or ItemString.Get(existingLink) ~= itemString then
		local resolvedSlotId = private.FindBagSlotId(itemString, minQuantity)
		if resolvedSlotId then
			slotId = resolvedSlotId
			bag, slot = SlotId.Split(slotId)
		else
			local nextItem, nextSlotId, nextSpellId, nextMinQuantity = private.FindNextDestroyable()
			if not nextItem then
				-- Nothing to destroy. We must NOT return synchronously here: StartDestroy
				-- runs this thread via SendSyncMessage, so finishing the future right now
				-- (before the UI's action handler calls ManageFuture) trips an assert in
				-- Future:SetScript("OnDone") on an already-done future. Force a yield so the
				-- future is still in the STARTED state when ManageFuture runs, then bail.
				Threading.Yield(true)
				return false
			end
			itemString = nextItem
			slotId = nextSlotId
			spellId = nextSpellId
			minQuantity = nextMinQuantity
			bag, slot = SlotId.Split(slotId)
		end
	end
	local startQuantity = Container.GetStackCount(bag, slot)
	button:SetMacroText(format("/cast %s;\n/use %d %d", Spell.GetInfo(spellId), bag, slot))

	-- Wait for the destroy to complete. On retail a loot window opens with the
	-- results, but on 3.3.5a milling, prospecting and disenchanting deposit the mats
	-- straight into the bags with NO loot window, and the UNIT_SPELLCAST_START
	-- message is not reliably delivered to this thread. The original code blocked on
	-- ReceiveMessage() waiting for UNIT_SPELLCAST_START (and later for loot events),
	-- which never arrives here, leaving the Destroy button stuck on "Destroying..."
	-- forever. Instead we never block on a message: we poll, treating the destroyed
	-- item being removed from its slot as the authoritative "done" signal, while
	-- still draining spell/loot messages to capture loot results and to notice a
	-- genuinely failed cast.
	private.pendingSpellId = spellId
	local lootResult = nil
	local timeout = GetTime() + 10
	while true do
		local castFailed = false
		while Threading.HasPendingMessage() do
			local event = Threading.ReceiveMessage()
			if event == "LOOT_READY" then
				if not lootResult and GetNumLootItems() > 0 then
					lootResult = {}
					for i = 1, GetNumLootItems() do
						local lootItemString = ItemString.Get(GetLootSlotLink(i))
						local _, _, quantity = GetLootSlotInfo(i)
						if lootItemString and (quantity or 0) > 0 then
							lootItemString = GEM_CHIPS[lootItemString] or lootItemString
							lootResult[lootItemString] = quantity
						end
					end
				end
			elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
				castFailed = true
			else
				-- UNIT_SPELLCAST_START / UNIT_SPELLCAST_SUCCEEDED / LOOT_CLOSED /
				-- BAG_UPDATE_DELAYED are expected progress events; the bag-quantity
				-- check below confirms actual completion.
			end
		end
		-- The destroyed item being consumed from its slot is the authoritative
		-- completion signal (works even when no loot window / events fire on 3.3.5a)
		-- and always wins over a stray failure message.
		if startQuantity ~= Container.GetStackCount(bag, slot) then
			break
		end
		if castFailed then
			ClearCursor()
			return false
		end
		if GetTime() > timeout then
			return false
		end
		Threading.Sleep(0.1)
	end

	-- The item has been consumed. We intentionally do NOT refresh the bags here. The
	-- rescan empties the destroying list, which synchronously hides the Destroying frame,
	-- whose OnHide cancels the destroy future and calls Threading.Kill on THIS thread.
	-- Doing that while we're still the running coroutine makes Kill -> _Exit ->
	-- coroutine.yield blow up with "attempt to yield across metamethod/C-call boundary"
	-- (frame:Hide is a C-call boundary). The rescan is instead done in DestroyThreadDone,
	-- which runs after the thread has fully exited and is dead, so the Kill is a no-op.

	-- Add to the log
	local newEntry = {
		item = itemString,
		time = time(),
		result = lootResult or {},
	}
	private.settings.destroyingHistory[spellId] = private.settings.destroyingHistory[spellId] or {}
	tinsert(private.settings.destroyingHistory[spellId], newEntry)

	-- We're done
	return true
end

function private.SendEventToThread(event)
	if not private.destroyThreadRunning then
		return
	end
	Threading.SendMessage(private.destroyThread, event)
end

function private.SpellCastEventHandler(event, unit, arg2, arg3)
	if unit ~= "player" then
		return
	end
	-- Resolve the cast's spell id across game versions:
	--  * Retail fires UNIT_SPELLCAST_* as (unit, castGUID, spellID), so the spell id is
	--    the 3rd payload arg (a number).
	--  * 3.3.5a fires (unit, spellName, spellRank, castID) with NO spell id in the
	--    payload, so match the pending destroy spell by comparing the cast's name.
	local spellId = nil
	if type(arg3) == "number" then
		spellId = arg3
	elseif private.pendingSpellId and type(arg2) == "string" and arg2 == Spell.GetInfo(private.pendingSpellId) then
		spellId = private.pendingSpellId
	end
	if ClientInfo.HasFeature(ClientInfo.FEATURES.C_TRADE_SKILL_UI) and private.destroySpellId and private.destroySpellId == spellId and event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_SUCCEEDED" then
		private.destroySpellId = nil
		private.itemSpellId = nil
	end
	if spellId ~= private.pendingSpellId then
		return
	end
	private.SendEventToThread(event)
end

function private.DestroyThreadDone(result)
	private.destroyThreadRunning = false
	private.destroyFuture:Done(result)
	-- Refresh the bags AFTER the thread has fully exited (we're back in normal stack
	-- context now, not inside the thread's coroutine). On 3.3.5a the BAG_UPDATE event for
	-- non-backpack bags is unreliable, so we must rescan ourselves or the destroying list
	-- won't drop the consumed item. This must happen here rather than inside the thread:
	-- emptying the list hides the Destroying frame, whose OnHide cancels the destroy future
	-- and calls Threading.Kill on the destroy thread. By now the thread is already dead, so
	-- that Kill is a harmless no-op instead of a yield-across-C-call-boundary crash.
	BagTracking.RescanAllBags()
	private.UpdateBagDB()
end

function private.TradeSkillCraftResultHandler(event, resultTable)
	if not private.destroySpellId or not private.itemSpellId then
		return
	end
	private.destroyResultCache[ItemString.Get(resultTable.itemID)] = resultTable.quantity
end

function private.TradeSkillListUpdateHandler()
	if not private.destroySpellId or not private.itemSpellId or not next(private.destroyResultCache) then
		return
	end

	-- Add to the log
	local newEntry = {
		item = ItemString.Get(private.itemSpellId),
		time = time(),
		result = CopyTable(private.destroyResultCache),
	}
	private.settings.destroyingHistory[private.destroySpellId] = private.settings.destroyingHistory[private.destroySpellId] or {}
	tinsert(private.settings.destroyingHistory[private.destroySpellId], newEntry)

	wipe(private.destroyResultCache)
end



-- ============================================================================
-- Bag Update Functions
-- ============================================================================

function private.UpdateBagDB()
	wipe(private.pendingCombines)
	private.destroyInfoDB:TruncateAndBulkInsertStart()
	local itemPrevSlotId = TempTable.Acquire()
	local checkedItem = TempTable.Acquire()
	local query = BagTracking.CreateQueryBags()
		:OrderBy("slotId", true)
		:Select("slotId", "itemString", "quantity")
	if not private.settings.includeSoulbound then
		query:Equal("isBound", false)
	end
	if TSM.Crafting and TSM.Crafting.PlayerProfessions then
	if ClientInfo.IsPandaClassic() then
		local disenchantName = Spell.GetInfo(7411)
		local jewelcraftName = Spell.GetInfo(28897)
		local inscriptionName = Spell.GetInfo(45357)
		private.disenchantSkillLevel = TSM.Crafting.PlayerProfessions.GetProfessionSkill(UnitName("player"), disenchantName)
		private.jewelcraftSkillLevel = TSM.Crafting.PlayerProfessions.GetProfessionSkill(UnitName("player"), jewelcraftName)
		private.inscriptionSkillLevel = TSM.Crafting.PlayerProfessions.GetProfessionSkill(UnitName("player"), inscriptionName)
	elseif ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
		local disenchantName = Spell.GetInfo(7411)
		local jewelcraftName = Spell.GetInfo(28897)
		private.disenchantSkillLevel = TSM.Crafting.PlayerProfessions.GetProfessionSkill(UnitName("player"), disenchantName)
		private.jewelcraftSkillLevel = TSM.Crafting.PlayerProfessions.GetProfessionSkill(UnitName("player"), jewelcraftName)
	end
	end
	for _, slotId, itemString, quantity in query:Iterator() do
		local minQuantity = nil
		if checkedItem[itemString] then
			minQuantity = private.destroyInfoDB:GetUniqueRowField("itemString", itemString, "minQuantity")
		else
			checkedItem[itemString] = true
			local spellId = nil
			minQuantity, spellId = private.ProcessBagItem(itemString)
			if minQuantity then
				private.destroyInfoDB:BulkInsertNewRow(itemString, minQuantity, spellId)
			end
		end
		if minQuantity and quantity % minQuantity ~= 0 then
			if itemPrevSlotId[itemString] then
				-- We can combine this with the previous partial stack
				tinsert(private.pendingCombines, itemPrevSlotId[itemString] * TARGET_SLOT_ID_MULTIPLIER + slotId)
				itemPrevSlotId[itemString] = nil
			else
				itemPrevSlotId[itemString] = slotId
			end
		end
	end
	query:Release()
	TempTable.Release(checkedItem)
	TempTable.Release(itemPrevSlotId)
	private.destroyInfoDB:BulkInsertEnd()
	private.state.canCombine = #private.pendingCombines > 0
	private.newBagUpdate = true
end

function private.ProcessBagItem(itemString)
	if private.ignoreDB:HasUniqueRow("itemString", itemString) then
		return
	end

	local spellId, minQuantity = private.IsDestroyable(itemString)
	if not spellId then
		return
	elseif spellId == SPELL_IDS.disenchant then
		local deAbovePrice = CustomString.GetValue(private.settings.deAbovePrice, itemString) or 0
		local deValue = CustomString.GetValue("Destroy", itemString) or math.huge
		if deValue < deAbovePrice then
			return
		end
	end
	return minQuantity, spellId
end

function private.IsDestroyable(itemString)
	if private.destroyQuantityCache[itemString] then
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	-- Disenchanting
	local quality = ItemInfo.GetQuality(itemString)
	if ItemInfo.IsDisenchantable(itemString) and quality <= private.settings.deMaxQuality then
		local hasSourceItem = true
		if ClientInfo.IsPandaClassic() or ClientInfo.IsBCClassic() or ClientInfo.IsWrathClassic() then
			local classId = ItemInfo.GetClassId(itemString)
			local itemLevel = ItemInfo.GetItemLevel(ItemString.GetBase(itemString))
			hasSourceItem = false
			for targetItemString in Conversion.DisenchantTargetItemIterator() do
				local _, _, _, _, skillRequired = Conversions.GetDisenchantTargetItemSourceInfo(targetItemString, classId, quality, itemLevel)
				if private.disenchantSkillLevel and skillRequired and private.disenchantSkillLevel >= skillRequired then
					hasSourceItem = true
				end
			end
		end
		if hasSourceItem then
			private.canDestroyCache[itemString] = IsSpellKnown(SPELL_IDS.disenchant) and SPELL_IDS.disenchant
			private.destroyQuantityCache[itemString] = 1
			return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
		end
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	local conversionMethod, destroySpellId = nil, nil
	local classId = ItemInfo.GetClassId(itemString)
	local subClassId = ItemInfo.GetSubClassId(itemString)
	-- Workaround for Fire Leaf (i:39970) not being treated as an herb (at least in classsic)
	if (classId == Enum.ItemClass.Tradegoods and subClassId == ITEM_SUB_CLASS_HERB) or itemString == "i:39970" then
		conversionMethod = Conversion.METHOD.MILL
		destroySpellId = SPELL_IDS.milling
	elseif classId == Enum.ItemClass.Tradegoods and subClassId == ITEM_SUB_CLASS_METAL_AND_STONE then
		conversionMethod = Conversion.METHOD.PROSPECT
		destroySpellId = SPELL_IDS.prospect
	else
		private.canDestroyCache[itemString] = false
		private.destroyQuantityCache[itemString] = nil
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	local hasSourceItem = false
	for _, _, _, _, _, _, _, skillRequired in Conversion.TargetItemsByMethodIterator(itemString, conversionMethod) do
		if not skillRequired or (conversionMethod == Conversion.METHOD.PROSPECT and private.jewelcraftSkillLevel and skillRequired and private.jewelcraftSkillLevel >= skillRequired) or (conversionMethod == Conversion.METHOD.MILL and private.inscriptionSkillLevel and skillRequired and private.inscriptionSkillLevel >= skillRequired) then
			hasSourceItem = true
		end
	end
	if hasSourceItem then
		private.canDestroyCache[itemString] = IsSpellKnown(destroySpellId) and destroySpellId
		private.destroyQuantityCache[itemString] = 5
		return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
	end

	return private.canDestroyCache[itemString], private.destroyQuantityCache[itemString]
end

function private.GetHistoryEntryTime(entry)
	return entry.time
end
