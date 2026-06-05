-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMService = select(2, ...).LibTSMService
local Guild = LibTSMService:Init("Guild")
local Scanner = LibTSMService:Include("Guild.Scanner")



-- ============================================================================
-- Module Functions
-- ============================================================================

---Loads and sets the stored data tables.
---@param quantityData table<string,number> Guild bank item quantities
function Guild.Load(quantityData)
	Scanner.Load(quantityData)
end

---Starts running the guild code.
function Guild.Start()
	Scanner.Start()
end

---Registers a function to call when the player's guild name is loaded or changes.
---@param func fun(name?: string)
function Guild.RegisterNameCallback(func)
	return Scanner.RegisterNameCallback(func)
end

---Creates a query against the index DB.
---@return DatabaseQuery
function Guild.NewIndexQuery()
	return Scanner.NewIndexQuery()
end

---Creates a query against the index DB for a specific item.
---@param itemString string The item string
---@return DatabaseQuery
function Guild.NewIndexQueryItem(itemString)
	return Scanner.NewIndexQueryItem(itemString)
end

---Gets the quantity of a given item.
---@param itemString string The item string
---@return number
function Guild.GetQuantity(itemString)
	return Scanner.GetQuantity(itemString)
end
