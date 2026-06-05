-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUI = select(2, ...).LibTSMUI
local ItemLinked = LibTSMUI:Init("Util.ItemLinked")
local Table = LibTSMUI:From("LibTSMUtil"):Include("Lua.Table")
local Item = LibTSMUI:From("LibTSMWoW"):Include("API.Item")
local ItemInfo = LibTSMUI:From("LibTSMService"):Include("Item.ItemInfo")
local private = {
	callbacks = {},
	priorityLookup = {},
}



-- ============================================================================
-- Module Loading
-- ============================================================================

ItemLinked:OnModuleLoad(function()
	Item.HookLink(private.ItemLinkedHook)
end)



-- ============================================================================
-- Module Functions
-- ============================================================================

function ItemLinked.RegisterCallback(callback, highPriority)
	assert(type(callback) == "function")
	tinsert(private.callbacks, callback)
	private.priorityLookup[callback] = highPriority and 0 or 1
	Table.SortWithValueLookup(private.callbacks, private.priorityLookup, false, private.SecondarySort)
end

function ItemLinked.UnregisterCallback(callback)
	assert(type(callback) == "function")
	private.priorityLookup[callback] = nil
	assert(Table.RemoveByValue(private.callbacks, callback) == 1)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ItemLinkedHook(itemLink)
	local name = ItemInfo.GetName(itemLink)
	if not name then
		return false
	end
	for _, callback in ipairs(private.callbacks) do
		if callback(name, itemLink) then
			return true
		end
	end
	return false
end

function private.SecondarySort(a, b)
	-- Just make the sort unstable
	return false
end
