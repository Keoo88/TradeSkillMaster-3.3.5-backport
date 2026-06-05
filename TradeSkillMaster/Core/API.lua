-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

--- Public TSM API functions
-- @module TSM_API

local TSM = select(2, ...) ---@type TSM
local API = TSM:NewPackage("API") ---@type AddonPackage
local Money = TSM.LibTSMUtil:Include("UI.Money")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local ItemString = TSM.LibTSMTypes:Include("Item.ItemString")
local Group = TSM.LibTSMTypes:Include("Group")
local GroupOperation = TSM.LibTSMTypes:Include("GroupOperation")
local CustomString = TSM.LibTSMTypes:Include("CustomString")
local ItemInfo = TSM.LibTSMService:Include("Item.ItemInfo")
local CustomPrice = TSM.LibTSMApp:Include("Service.CustomPrice")
local AltTracking = TSM.LibTSMApp:Include("Service.AltTracking")
local Auction = TSM.LibTSMService:Include("Auction")
local BagTracking = TSM.LibTSMService:Include("Inventory.BagTracking")
local WarbankTracking = TSM.LibTSMService:Include("Inventory.WarbankTracking")
local Mail = TSM.LibTSMService:Include("Mail")
local Guild = TSM.LibTSMService:Include("Guild")
-- luacheck: globals TSM_API
TSM_API = {}
local private = {
	settingsDB = nil,
	settings = nil,
	groupItemQuery = nil,
	groupItemCallbacks = {},
}
local TIME_WARNING_THRESHOLD = 0.02



-- ============================================================================
-- Module Loading
-- ============================================================================

function API.OnInitialize(settingsDB)
	private.settingsDB = settingsDB
	private.settings = settingsDB:NewView()
		:AddKey("global", "coreOptions", "regionWide")
end



-- ============================================================================
-- UI
-- ============================================================================

--- Checks if a TSM UI is currently visible.
-- @within UI
-- @tparam string uiName A string which represents the UI ("AUCTION", "CRAFTING", "MAILING", or "VENDORING")
-- @treturn boolean Whether or not the TSM UI is visible
function TSM_API.IsUIVisible(uiName)
	private.CheckCallMethod(uiName)
	if uiName == "AUCTION" then
		return TSM.UI.AuctionUI.IsVisible()
	elseif uiName == "CRAFTING" then
		return TSM.UI.CraftingUI.IsVisible()
	elseif uiName == "MAILING" then
		return TSM.UI.MailingUI.IsVisible()
	elseif uiName == "VENDORING" then
		return TSM.UI.VendoringUI.IsVisible()
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end

--- Registers a callback function to be called when a TSM UI is shown or hidden
-- @within UI
-- @tparam string uiName A string which represents the UI (currently only "CRAFTING" is supported)
-- @tparam string addonTag An arbitrary string which uniquely identifies the addon making this call and its usage (i.e. "MyAddon:CraftingButton")
-- @tparam function func The function to call - passed `false` when hidden, and `true, frame` when shown
function TSM_API.RegisterUICallback(uiName, addonTag, func)
	private.CheckCallMethod(uiName)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(func, "function", "func")
	if uiName == "CRAFTING" then
		TSM.UI.CraftingUI.RegisterApiCallback(addonTag, func)
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end

--- Shifts a TSM button which is shown on the default UI by the requested offset (relative to its default position)
-- @within UI
-- @tparam string uiName A string which represents the UI (currently only "VENDORING" is supported)
-- @tparam string addonTag A string which uniquely identifies the addon making this call (i.e. "MyAddon")
-- @tparam number xOffset The amount to shift the TSM button by (relative to its default position)
function TSM_API.ShiftDefaultUIButton(uiName, addonTag, xOffset)
	private.CheckCallMethod(uiName)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(xOffset, "number", "xOffset")
	if uiName == "VENDORING" then
		TSM.UI.VendoringUI.ShiftDefaultUIButton(addonTag, xOffset)
	else
		error("Invalid uiName: "..tostring(uiName), 2)
	end
end



-- ============================================================================
-- Groups
-- ============================================================================

--- Gets a current list of TSM group paths.
-- @within Group
-- @tparam table result A table to store the result in
-- @treturn table The passed table, populated with group paths
function TSM_API.GetGroupPaths(result)
	private.CheckCallMethod(result)
	private.ValidateArgumentType(result, "table", "result")
	for _, groupPath in GroupOperation.GroupIterator() do
		tinsert(result, groupPath)
	end
	return result
end

--- Formats a TSM group path into a human-readable form
-- @within Group
-- @tparam string path The group path to be formatted
-- @treturn string The formatted group path
function TSM_API.FormatGroupPath(path)
	private.CheckCallMethod(path)
	private.ValidateGroupPath(path)
	return Group.FormatPath(path)
end

--- Splits a TSM group path into its parent path and group name components.
-- @within Group
-- @tparam string path The group path to be split
-- @treturn string The path of the parent group or nil if the specified path has no parent
-- @treturn string The name of the group
function TSM_API.SplitGroupPath(path)
	private.CheckCallMethod(path)
	private.ValidateGroupPath(path)
	local parentPath, groupName = Group.SplitPath(path)
	if parentPath == Group.GetRootPath() then
		parentPath = nil
	end
	return parentPath, groupName
end

--- Gets the path to the group which a specific item is in.
-- @within Group
-- @tparam string itemString The TSM item string to get the group path of
-- @treturn string The path to the group which the item is in, or nil if it's not in a group
function TSM_API.GetGroupPathByItem(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	local path = Group.GetPathByItem(itemString)
	return path ~= Group.GetRootPath() and path or nil
end

--- Gets all the items within a group.
-- @within Group
-- @tparam string path The group path to get the items for
-- @tparam boolean includeSubGroups Whether or not to include items in subgroups
-- @tparam table result A table to store the result in
-- @treturn table The passed table, populated with group paths
function TSM_API.GetGroupItems(path, includeSubGroups, result)
	private.CheckCallMethod(path, result)
	private.ValidateGroupPath(path)
	private.ValidateArgumentType(includeSubGroups, "boolean", "includeSubGroups")
	private.ValidateArgumentType(result, "table", "result")
	for _, itemString in Group.ItemIterator(path, includeSubGroups) do
		tinsert(result, itemString)
	end
	return result
end

--- Registers a callback function to be called when the items within any group changes.
-- @within UI
-- @tparam string addonTag An arbitrary string which uniquely identifies the addon making this call and its usage (i.e. "MyAddon:CraftingButton")
-- @tparam function func The function to call
function TSM_API.RegisterGroupItemCallback(addonTag, func)
	private.CheckCallMethod(addonTag)
	private.ValidateArgumentType(addonTag, "string", "addonTag")
	if addonTag == "" then
		error("Invalid `addonTag` argument (cannot be an empty string)", 2)
	end
	private.ValidateArgumentType(func, "function", "func")
	if private.groupItemCallbacks[addonTag] then
		error("Callback already registered for addonTag: "..tostring(addonTag), 3)
	end
	private.groupItemQuery = private.groupItemQuery or Group.CreateItemsQuery()
		:SetUpdateCallback(private.GroupsUpdated)
	private.groupItemCallbacks[addonTag] = func
end



-- ============================================================================
-- Profiles
-- ============================================================================

--- Gets a current list of TSM profiles.
-- @within Profile
-- @tparam table result A table to store the result in
-- @treturn table The passed table, populated with group paths
function TSM_API.GetProfiles(result)
	private.CheckCallMethod(result)
	for _, profileName in private.settingsDB:ScopeKeyIterator("profile") do
		tinsert(result, profileName)
	end
	return result
end

--- Gets the active TSM profile.
-- @within Profile
-- @treturn string The name of the currently active profile
function TSM_API.GetActiveProfile()
	return private.settingsDB:GetCurrentProfile()
end

--- Sets the active TSM profile.
-- @within Profile
-- @tparam string profile The name of the profile to make active
function TSM_API.SetActiveProfile(profile)
	private.CheckCallMethod(profile)
	if type(profile) ~= "string" then
		error("Invalid 'profile' argument type (must be a string): "..tostring(profile), 2)
	elseif not private.settingsDB:ProfileExists(profile) then
		error("Profile does not exist: "..profile, 2)
	elseif profile == private.settingsDB:GetCurrentProfile() then
		error("Profile is already active: "..profile, 2)
	end
	return private.settingsDB:SetProfile(profile)
end



-- ============================================================================
-- Prices
-- ============================================================================

--- Gets a list of price source keys which can be used in TSM custom prices.
-- @within Price
-- @tparam table result A table to store the result in
-- @treturn table The passed table, populated with price source keys
function TSM_API.GetPriceSourceKeys(result)
	private.CheckCallMethod(result)
	private.ValidateArgumentType(result, "table", "result")
	for _, key in CustomString.SourceIterator() do
		tinsert(result, key)
	end
	return result
end

--- Gets the localized description of a given price source key.
-- @within Price
-- @tparam string key The price source key
-- @treturn string The localized description
function TSM_API.GetPriceSourceDescription(key)
	private.CheckCallMethod(key)
	private.ValidateArgumentType(key, "string", "key")
	local _, label = CustomString.GetSourceInfo(key)
	if not label then
		error("Unknown price source key: "..tostring(key), 2)
	end
	return label
end

--- Gets whether or not a custom price string is valid.
-- @within Price
-- @tparam string customPriceStr The custom price string
-- @treturn boolean Whether or not the custom price is valid
-- @treturn string The (localized) error message or nil if the custom price was valid
function TSM_API.IsCustomPriceValid(customPriceStr)
	private.CheckCallMethod(customPriceStr)
	private.ValidateArgumentType(customPriceStr, "string", "customPriceStr")
	return CustomPrice.Validate(customPriceStr)
end

--- Evalulates a custom price string or price source key for a given item
-- @within Price
-- @tparam string customPriceStr The custom price string or price source key to get the value of
-- @tparam string itemString The TSM item string to get the value for
-- @treturn number The value in copper or nil if the custom price string is not valid
-- @treturn string The (localized) error message if the custom price string is not valid or nil if it is valid
function TSM_API.GetCustomPriceValue(customPriceStr, itemString)
	private.CheckCallMethod(customPriceStr)
	private.ValidateArgumentType(customPriceStr, "string", "customPriceStr")
	itemString = private.ValidateTSMItemString(itemString)
	return CustomPrice.GetValue(customPriceStr, itemString)
end



-- ============================================================================
-- Money
-- ============================================================================

--- Converts a money value to a formatted, human-readable string.
-- @within Money
-- @tparam number value The money value in copper to be converted
-- @treturn string The formatted money string
function TSM_API.FormatMoneyString(value)
	private.CheckCallMethod(value)
	private.ValidateArgumentType(value, "number", "value")
	local result = Money.ToStringExact(value)
	assert(result)
	return result
end

--- Converts a formatted, human-readable money string to a value.
-- @within Money
-- @tparam string str The formatted money string
-- @treturn number The money value in copper
function TSM_API.ParseMoneyString(str)
	private.CheckCallMethod(str)
	private.ValidateArgumentType(str, "string", "str")
	local result = Money.FromString(str)
	assert(result)
	return result
end



-- ============================================================================
-- Item
-- ============================================================================

--- Converts an item to a TSM item string.
-- @within Item
-- @tparam string item Either an item link, TSM item string, or WoW item string
-- @treturn string The TSM item string or nil if the specified item could not be converted
function TSM_API.ToItemString(item)
	private.CheckCallMethod(item)
	private.ValidateArgumentType(item, "string", "item")
	return ItemString.Get(item)
end

--- Gets an item's name from a given TSM item string.
-- @within Item
-- @tparam string itemString The TSM item string
-- @treturn string The name of the item or nil if it couldn't be determined
function TSM_API.GetItemName(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	return ItemInfo.GetName(itemString)
end

--- Gets an item link from a given TSM item string.
-- @within Item
-- @tparam string itemString The TSM item string
-- @treturn string The item link or an "[Unknown Item]" link
function TSM_API.GetItemLink(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	local result = ItemInfo.GetLink(itemString)
	assert(result)
	return result
end



-- ============================================================================
-- Inventory
-- ============================================================================

--- Gets the quantity of an item in a character's bags.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString or baseItemString)
-- @tparam ?string character The character to get data for (defaults to the current character if not set)
-- @tparam ?string factionrealm The factionrealm to get data for (defaults to the current factionrealm if not set)
-- @treturn number The quantity of the specified item
function TSM_API.GetBagQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return BagTracking.GetBagQuantity(itemString)
	else
		return AltTracking.GetBagQuantity(itemString, character, factionrealm)
	end
end

--- Gets the quantity of an item in a character's bank.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString or baseItemString)
-- @tparam ?string character The character to get data for (defaults to the current character if not set)
-- @tparam ?string factionrealm The factionrealm to get data for (defaults to the current factionrealm if not set)
-- @treturn number The quantity of the specified item
function TSM_API.GetBankQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return BagTracking.GetBankQuantity(itemString)
	else
		return AltTracking.GetBankQuantity(itemString, character, factionrealm)
	end
end

--- Gets the quantity of an item posted to the auction house by a character.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString or baseItemString)
-- @tparam ?string character The character to get data for (defaults to the current character if not set)
-- @tparam ?string factionrealm The factionrealm to get data for (defaults to the current factionrealm if not set)
-- @treturn number The quantity of the specified item
function TSM_API.GetAuctionQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return Auction.GetQuantity(itemString)
	else
		return AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
	end
end

--- Gets the quantity of an item in a character's mailbox.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString or baseItemString)
-- @tparam ?string character The character to get data for (defaults to the current character if not set)
-- @tparam ?string factionrealm The factionrealm to get data for (defaults to the current factionrealm if not set)
-- @treturn number The quantity of the specified item
function TSM_API.GetMailQuantity(itemString, character, factionrealm)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(character == nil or type(character) == "string")
	assert(factionrealm == nil or type(factionrealm) == "string")
	if not character then
		assert(not factionrealm)
		return Mail.GetQuantity(itemString)
	else
		return AltTracking.GetMailQuantity(itemString, character, factionrealm)
	end
end

--- Gets the quantity of an item in a guild's bank.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString or baseItemString)
-- @tparam ?string guild The guild to get data for (defaults to the current character's guild if not set)
-- @treturn number The quantity of the specified item
function TSM_API.GetGuildQuantity(itemString, guild)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	assert(guild == nil or type(guild) == "string")
	if not guild then
		return Guild.GetQuantity(itemString)
	else
		return AltTracking.GetGuildQuantity(itemString, guild)
	end
end

--- Gets the quantity of an item in the warbank.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString or baseItemString)
-- @treturn number The quantity of the specified item
function TSM_API.GetWarbankQuantity(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	return WarbankTracking.GetQuantity(itemString)
end

--- Get some total quantities for an item.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString baseItemString)
-- @treturn number The total quantity the current player has (bags, bank, mail)
-- @treturn number The total quantity alt characters have (bags, bank, mail)
-- @treturn number The total quantity the current player has on the auction house
-- @treturn number The total quantity alt characters have on the auction house
function TSM_API.GetPlayerTotals(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	local numPlayer, numAlts, numAuctions, numAltAuctions = 0, 0, 0, 0
	numPlayer = numPlayer + BagTracking.GetBagQuantity(itemString)
	numPlayer = numPlayer + BagTracking.GetBankQuantity(itemString)
	numPlayer = numPlayer + Mail.GetQuantity(itemString)
	numAuctions = numAuctions + Auction.GetQuantity(itemString)
	for _, factionrealm in private.settingsDB:AccessibleRealmIterator("factionrealm", not private.settings.regionWide) do
		for _, character in private.settingsDB:AccessibleCharacterIterator(nil, factionrealm, true) do
			numAlts = numAlts + AltTracking.GetBagQuantity(itemString, character, factionrealm)
			numAlts = numAlts + AltTracking.GetBankQuantity(itemString, character, factionrealm)
			numAlts = numAlts + AltTracking.GetMailQuantity(itemString, character, factionrealm)
			numAltAuctions = numAltAuctions + AltTracking.GetAuctionQuantity(itemString, character, factionrealm)
		end
	end
	return numPlayer, numAlts, numAuctions, numAltAuctions
end

--- Get the total number of items in all tracked guild banks.
-- @within Inventory
-- @tparam string itemString The TSM item string (inventory is tracked by either levelItemString baseItemString)
-- @treturn number The total quantity in all tracked guild banks
function TSM_API.GetGuildTotal(itemString)
	private.CheckCallMethod(itemString)
	itemString = private.ValidateTSMItemString(itemString)
	return AltTracking.GetTotalGuildQuantity(itemString)
end



-- ============================================================================
-- Crafting
-- ============================================================================

--- Iterates over all items in the crafting queue.
-- @within Crafting
-- @treturn function An iterator with fields: `index`, `recipeString`, `itemString`, `num`
function TSM_API.CraftingQueueIterator()
	local result = {}
	local query = TSM.Crafting.Queue.CreateQuery()
		:Select("recipeString", "craftString", "num")
	for _, recipeString, craftString, num in query:Iterator() do
		local itemString = TSM.Crafting.GetItemString(craftString) or ""
		tinsert(result, recipeString)
		tinsert(result, itemString)
		tinsert(result, num)
	end
	query:Release()
	return private.CraftingQueueIteratorHelper, result, 0
end

--- Gets the materials needed for a specific queued recipe.
-- @within Crafting
-- @tparam string recipeString The recipe string from the crafting queue iterator
-- @tparam table result A table to populate with materials, where keys are item strings and values are quantities
function TSM_API.GetCraftingQueueItemMaterials(recipeString, result)
	private.CheckCallMethod(recipeString)
	private.ValidateArgumentType(recipeString, "string", "recipeString")
	if not strmatch(recipeString, "^r:%d+") then
		error("Invalid 'recipeString' argument (must be a valid recipe string): "..tostring(recipeString), 2)
	end
	private.ValidateArgumentType(result, "table", "result")
	for _, itemString, quantity in TSM.Crafting.MatIteratorByRecipeString(recipeString) do
		result[itemString] = quantity
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ValidateArgumentType(val, expectedType, name)
	if type(val) ~= expectedType then
		error("Invalid '"..name.."' argument type (must be a "..expectedType.."): "..tostring(val), 3)
	end
end

function private.ValidateTSMItemString(itemString)
	if type(itemString) ~= "string" or not strmatch(itemString, "^[ip]:%d+") then
		error("Invalid 'itemString' argument type (must be a TSM item string): "..tostring(itemString), 3)
	end
	local newItemString = ItemString.Get(itemString)
	if not newItemString then
		error("Invalid TSM itemString: "..itemString, 3)
	end
	return newItemString
end

function private.ValidateGroupPath(path)
	if type(path) ~= "string" then
		error("Invalid 'path' argument type (must be a string): "..tostring(path), 3)
	elseif path == "" then
		error("Invalid 'path' argument (empty string)", 3)
	end
end

function private.CheckCallMethod(firstArg)
	if firstArg == TSM_API then
		error("Invalid usage of colon operator to call TSM_API function", 3)
	end
end

function private.CraftingQueueIteratorHelper(tbl, index)
	index = index + 3
	if index > #tbl then
		return
	end
	return index, tbl[index - 2], tbl[index - 1], tbl[index]
end

function private.GroupsUpdated()
	for addonTag, func in pairs(private.groupItemCallbacks) do
		local startTime = GetTimePreciseSec()
		func()
		local timeTaken = GetTimePreciseSec() - startTime
		if timeTaken > TIME_WARNING_THRESHOLD then
			Log.Info("API function (%s) took %0.5fs", addonTag, GetTimePreciseSec() - timeTaken)
		end
	end
end
