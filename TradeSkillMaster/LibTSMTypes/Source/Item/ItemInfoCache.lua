-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local ItemInfoCache = LibTSMTypes:DefineClassType("ItemInfoCache")
local ItemInfoSerializer = LibTSMTypes:Include("Item.ItemInfoSerializer")
local ItemString = LibTSMTypes:Include("Item.ItemString")
local Table = LibTSMTypes:From("LibTSMUtil"):Include("Lua.Table")
local LongString = LibTSMTypes:From("LibTSMUtil"):Include("BaseType.LongString")
local Analytics = LibTSMTypes:From("LibTSMUtil"):Include("Util.Analytics")
local Log = LibTSMTypes:From("LibTSMUtil"):Include("Util.Log")
local Database = LibTSMTypes:From("LibTSMUtil"):Include("Database")
local Reactive = LibTSMTypes:From("LibTSMUtil"):Include("Reactive")
local private = {}
local SEP_CHAR = "\002"
local MAX_LONG_STRING_ENTRIES = 1000

---@class SavedItemInfoCache
---@field versionStr string
---@field data string
---@field names string|string[]|nil
---@field itemStrings string|string[]|nil



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Creates a new ItemInfoCache.
---@return ItemInfoCache
function ItemInfoCache.__static.New()
	return ItemInfoCache()
end

---Asserts that a value is valid for the specified field.
---@param key string They key of the field
---@param value number The value
function ItemInfoCache.__static.CheckFieldValue(key, value)
	ItemInfoSerializer.CheckFieldValue(key, value)
end

---Gets the max value for a field.
---@param key string The key of the field
---@return number
function ItemInfoCache.__static.GetFieldMaxValue(key)
	return ItemInfoSerializer.GetFieldMaxValue(key)
end



-- ============================================================================
-- Class Meta Methods
-- ============================================================================

function ItemInfoCache.__private:__init()
	self._names = nil ---@type string[]
	self._itemStrings = nil ---@type string[]
	self._hasChanged = false
	self._db = Database.NewSchema("ITEM_INFO")
		:AddUniqueStringField("itemString")
		:AddStringField("name")
		:AddNumberField("itemLevel")
		:AddNumberField("minLevel")
		:AddNumberField("maxStack")
		:AddNumberField("vendorSell")
		:AddNumberField("invSlotId")
		:AddNumberField("texture")
		:AddNumberField("classId")
		:AddNumberField("subClassId")
		:AddNumberField("quality")
		:AddNumberField("isBOP")
		:AddNumberField("isCraftingReagent")
		:AddNumberField("expansionId")
		:AddNumberField("craftedQuality")
		:AddTrigramIndex("name")
		:Commit()
	self._stream = Reactive.CreateStream()
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

---Loads the DB and returns whether or not it was valid.
---@param saved SavedItemInfoCache The persistent DB to load
---@param versionStr string The version string
---@return boolean
function ItemInfoCache:Load(saved, versionStr)
	assert(type(saved) == "table" and type(versionStr) == "string")
	local isValid = nil
	if not self:_ValidateSavedDB(saved, versionStr) then
		isValid = false
		self._names = {}
		self._itemStrings = {}
	elseif not self:_LoadNamesItemStrings(saved) then
		isValid = false
	else
		isValid = true
	end
	if not isValid then
		wipe(saved)
		saved.data = ""
		self._hasChanged = true
	end

	self:_LoadData(saved)

	if not Table.IsSorted(self._names, private.NameSortHelper) then
		-- We'll sort our data on save to make filtering it a bit more efficient
		self._hasChanged = true
	end

	self._stream:Send(nil)
	return isValid
end

---Saves the DB.
---@param saved SavedItemInfoCache The persistent DB to save into
---@param versionStr string The version string
function ItemInfoCache:Save(saved, versionStr)
	if not self._hasChanged then
		-- Nothing changed since loading, so don't need to do anything
		return
	end
	local data, names, itemStrings = self:_EncodeData()
	if not data then
		Log.Err("Failed to save data")
		wipe(saved)
		return
	end
	saved.data = data
	saved.names = LongString.Encode(names, SEP_CHAR, MAX_LONG_STRING_ENTRIES)
	saved.itemStrings = LongString.Encode(itemStrings, SEP_CHAR, MAX_LONG_STRING_ENTRIES)
	saved.versionStr = versionStr
end

---Creates a new database query.
---@return DatabaseQuery
function ItemInfoCache:NewQuery()
	return self._db:NewQuery()
end

---Creates a publisher for item info changes.
---@return ReactivePublisher
function ItemInfoCache:Publisher()
	return self._stream:Publisher()
end

---Gets the value of a field for an item.
---@param itemString string The item string
---@param key string The field key
---@return number|string|nil
function ItemInfoCache:GetField(itemString, key)
	local value = self._db:GetUniqueRowField("itemString", itemString, key)
	if value == -1 or value == "" then
		return nil
	end
	return value
end

---Updates the value of a field for an item.
---@param itemString string The item string
---@param key string The field key
---@param value number|string
function ItemInfoCache:UpdateField(itemString, key, value)
	if self._db:GetUniqueRowField("itemString", itemString, key) == value then
		return
	end
	self:_PrepareRow(itemString)
	self._db:SetUniqueRowField("itemString", itemString, key, value)
	self:StreamSend(itemString)
	self._hasChanged = true
end

---Bulk prepares item cache rows for insertion / modification.
---@param itemStrings table<string,any> Table with item strings as keys
---@param includeBaseItems boolean Whether or not to prepare base items
function ItemInfoCache:BulkPrepareRows(itemStrings, includeBaseItems)
	self._db:BulkInsertStart()
	for itemString in pairs(itemStrings) do
		self:_PrepareRow(itemString, true)
		if includeBaseItems then
			local baseItemString = ItemString.GetBaseFast(itemString)
			if baseItemString ~= itemString then
				self:_PrepareRow(baseItemString, true)
			end
		end
	end
	self._db:BulkInsertEnd()
end

---Sets whether or not DB query updates are paused.
---@param paused boolean Whether or not query updates should be paused
function ItemInfoCache:SetQueryUpdatesPaused(paused)
	self._db:SetQueryUpdatesPaused(paused)
end

---Sets fields for an item which are preloaded by the game.
---@param itemString string The item string
---@param texture number The texture ID
---@param classId number The class ID
---@param subClassId number The subclass ID
---@param invSlotId number The inventory slot ID
function ItemInfoCache:SetPreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	self:_PrepareRow(itemString)
	self:_UpdatePreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	self:StreamSend(itemString)
	local baseItemString = ItemString.GetBaseFast(itemString)
	if baseItemString ~= itemString then
		-- Also set the base item
		self:_PrepareRow(baseItemString)
		self:_UpdatePreloadedFields(baseItemString, texture, classId, subClassId, invSlotId)
		self:StreamSend(baseItemString)
	end
	self._hasChanged = true
end

---Sets fields for an item which are queried from the game.
---@param itemString string The item string
---@param name string The name
---@param minLevel number The minimum required level
---@param itemLevel number The item level
---@param maxStack number The max stack size
---@param vendorSell number The vendor sell price
---@param quality number The quality
---@param isBOP number Whether or not hte item is bind on pickup
---@param isCraftingReagent number Whether or not the item is a crafting reagent
---@param expansionId number The expansion ID
---@param craftedQuality number The crafted quality
function ItemInfoCache:SetQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:_PrepareRow(itemString)
	self:_UpdateQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:StreamSend(itemString)
	self._hasChanged = true
end

---Sets all fields for an item.
---@param itemString string The item string
---@param texture number The texture ID
---@param classId number The class ID
---@param subClassId number The subclass ID
---@param invSlotId number The inventory slot ID
---@param name string The name
---@param minLevel number The minimum required level
---@param itemLevel number The item level
---@param maxStack number The max stack size
---@param vendorSell number The vendor sell price
---@param quality number The quality
---@param isBOP number Whether or not hte item is bind on pickup
---@param isCraftingReagent number Whether or not the item is a crafting reagent
---@param expansionId number The expansion ID
---@param craftedQuality number The crafted quality
function ItemInfoCache:SetAllFields(itemString, texture, classId, subClassId, invSlotId, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:_PrepareRow(itemString)
	self:_UpdatePreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	self:_UpdateQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	self:StreamSend(itemString)
	self._hasChanged = true
end

---Sends an item string to the cache's stream to notify consumers of an update.
---@param itemString string
function ItemInfoCache:StreamSend(itemString)
	self._stream:Send(itemString)
end



-- ============================================================================
-- Private Class Methods
-- ============================================================================

function ItemInfoCache.__private:_ValidateSavedDB(saved, versionStr)
	if saved.versionStr ~= versionStr then
		Log.Err("Version changed from '%s' to '%s'", tostring(saved.versionStr), versionStr)
		return false
	elseif not ItemInfoSerializer.IsEncodedDataValue(saved.data) then
		Analytics.Action("CORRUPTED_ITEM_INFO", "DATA", #saved.data)
		return false
	else
		return true
	end
end

function ItemInfoCache.__private:_LoadNamesItemStrings(saved)
	local names = LongString.Decode(saved.names, SEP_CHAR)
	local itemStrings = LongString.Decode(saved.itemStrings, SEP_CHAR)
	if #names == #itemStrings then
		self._names = names
		self._itemStrings = itemStrings
		return true
	else
		Analytics.Action("CORRUPTED_ITEM_INFO", "NAMES_ITEM_STRINGS", #names, #itemStrings)
		self._names = {}
		self._itemStrings = {}
		return false
	end
end

function ItemInfoCache.__private:_LoadData(saved)
	local function RowHandler(...)
		self._db:BulkInsertNewRowFast15(...)
	end
	self._db:BulkInsertStart()
	ItemInfoSerializer.DecodeData(saved.data, self._names, self._itemStrings, RowHandler)
	self._db:BulkInsertEnd()
	Log.Info("Imported %d items worth of data", #self._names)
end

function ItemInfoCache.__private:_EncodeData()
	local names, itemStrings, dataParts = ItemInfoSerializer.EncodeData(self._db:GetRawData(), self._db:GetNumRows())

	-- We'll sort our data on save to make filtering it a bit more efficient
	if not Table.IsSorted(names, private.NameSortHelper) then
		local lowerNames = {}
		local sortedIndexes = {}
		for i = 1, #names do
			if names[i] ~= nil then
				tinsert(sortedIndexes, i)
				lowerNames[i] = strlower(names[i])
			end
		end
		Table.SortWithValueLookup(sortedIndexes, lowerNames)
		local sortedNames = {}
		local sortedItemStrings = {}
		local sortedDataParts = {}
		for i, oldIndex in ipairs(sortedIndexes) do
			sortedNames[i] = names[oldIndex]
			sortedItemStrings[i] = itemStrings[oldIndex]
			sortedDataParts[i] = dataParts[oldIndex]
		end
		names = sortedNames
		itemStrings = sortedItemStrings
		dataParts = sortedDataParts
	end

	local data = table.concat(dataParts)
	if not ItemInfoSerializer.IsEncodedDataValue(data) then
		return nil, nil, nil
	end
	return data, names, itemStrings
end

function ItemInfoCache.__private:_PrepareRow(itemString, isBulkInsert)
	if self._db:HasUniqueRow("itemString", itemString) then
		return
	end
	if isBulkInsert then
		self._db:BulkInsertNewRow(itemString, "", -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1)
	else
		self._db:NewRow()
			:SetField("itemString", itemString)
			:SetField("name", "")
			:SetField("minLevel", -1)
			:SetField("itemLevel", -1)
			:SetField("maxStack", -1)
			:SetField("vendorSell", -1)
			:SetField("quality", -1)
			:SetField("isBOP", -1)
			:SetField("isCraftingReagent", -1)
			:SetField("texture", -1)
			:SetField("classId", -1)
			:SetField("subClassId", -1)
			:SetField("invSlotId", -1)
			:SetField("expansionId", -1)
			:SetField("craftedQuality", -1)
			:Create()
	end
	self._hasChanged = true
end

function ItemInfoCache.__private:_UpdatePreloadedFields(itemString, texture, classId, subClassId, invSlotId)
	-- 3.3.5: custom-server polyfills of GetItemInfoInstant occasionally return
	-- a string (subClass name like "Miscellaneous", "Cloth", "") in numeric ID slots.
	-- Coerce non-numbers to -1 (the missing-value sentinel) so the DB type guard passes
	-- and the field will be re-resolved on the next GetItemInfo cycle.
	if type(texture) ~= "number" then texture = -1 end
	if type(classId) ~= "number" then classId = -1 end
	if type(subClassId) ~= "number" then subClassId = -1 end
	if type(invSlotId) ~= "number" then invSlotId = -1 end
	ItemInfoSerializer.CheckFieldValue("texture", texture)
	ItemInfoSerializer.CheckFieldValue("classId", classId)
	ItemInfoSerializer.CheckFieldValue("subClassId", subClassId)
	ItemInfoSerializer.CheckFieldValue("invSlotId", invSlotId)
	self._db:SetUniqueRowField("itemString", itemString, "texture", texture)
	self._db:SetUniqueRowField("itemString", itemString, "classId", classId)
	self._db:SetUniqueRowField("itemString", itemString, "subClassId", subClassId)
	self._db:SetUniqueRowField("itemString", itemString, "invSlotId", invSlotId)
end

function ItemInfoCache.__private:_UpdateQueriedFields(itemString, name, minLevel, itemLevel, maxStack, vendorSell, quality, isBOP, isCraftingReagent, expansionId, craftedQuality)
	ItemInfoSerializer.CheckFieldValue("minLevel", minLevel)
	ItemInfoSerializer.CheckFieldValue("itemLevel", itemLevel)
	ItemInfoSerializer.CheckFieldValue("maxStack", maxStack)
	ItemInfoSerializer.CheckFieldValue("vendorSell", vendorSell)
	ItemInfoSerializer.CheckFieldValue("quality", quality)
	ItemInfoSerializer.CheckFieldValue("isBOP", isBOP)
	ItemInfoSerializer.CheckFieldValue("isCraftingReagent", isCraftingReagent)
	ItemInfoSerializer.CheckFieldValue("expansionId", expansionId)
	ItemInfoSerializer.CheckFieldValue("craftedQuality", craftedQuality)
	self._db:SetUniqueRowField("itemString", itemString, "name", name)
	self._db:SetUniqueRowField("itemString", itemString, "minLevel", minLevel)
	self._db:SetUniqueRowField("itemString", itemString, "itemLevel", itemLevel)
	self._db:SetUniqueRowField("itemString", itemString, "maxStack", maxStack)
	self._db:SetUniqueRowField("itemString", itemString, "vendorSell", vendorSell)
	self._db:SetUniqueRowField("itemString", itemString, "quality", quality)
	self._db:SetUniqueRowField("itemString", itemString, "isBOP", isBOP)
	self._db:SetUniqueRowField("itemString", itemString, "isCraftingReagent", isCraftingReagent)
	self._db:SetUniqueRowField("itemString", itemString, "expansionId", expansionId)
	self._db:SetUniqueRowField("itemString", itemString, "craftedQuality", craftedQuality)
end




-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.NameSortHelper(a, b)
	return strlower(a) < strlower(b)
end
