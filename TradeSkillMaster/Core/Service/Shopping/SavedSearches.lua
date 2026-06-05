-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local SavedSearches = TSM.Shopping:NewPackage("SavedSearches") ---@type AddonPackage
local Log = TSM.LibTSMUtil:Include("Util.Log")
local Database = TSM.LibTSMUtil:Include("Database")
local TempTable = TSM.LibTSMUtil:Include("BaseType.TempTable")
local private = {
	settings = nil,
	db = nil,
}
local MAX_RECENT_SEARCHES = 2000



-- ============================================================================
-- Module Functions
-- ============================================================================

function SavedSearches.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("global", "userData", "savedShoppingSearches")

	-- remove duplicates
	local seen = TempTable.Acquire()
	for i = #private.settings.savedShoppingSearches.filters, 1, -1 do
		local filter = private.settings.savedShoppingSearches.filters[i]
		local filterLower = strlower(private.settings.savedShoppingSearches.filters[i])
		if seen[filterLower] then
			tremove(private.settings.savedShoppingSearches.filters, i)
			private.settings.savedShoppingSearches.name[filter] = nil
			private.settings.savedShoppingSearches.isFavorite[filter] = nil
		else
			seen[filterLower] = true
		end
	end
	TempTable.Release(seen)

	-- remove old recent searches
	local remainingRecentSearches = MAX_RECENT_SEARCHES
	local numRemoved = 0
	for i = #private.settings.savedShoppingSearches.filters, 1, -1 do
		local filter = private.settings.savedShoppingSearches.filters
		if not private.settings.savedShoppingSearches.isFavorite[filter] then
			if remainingRecentSearches > 0 then
				remainingRecentSearches = remainingRecentSearches - 1
			else
				tremove(private.settings.savedShoppingSearches.filters, i)
				private.settings.savedShoppingSearches.name[filter] = nil
				numRemoved = numRemoved + 1
			end
		end
	end
	if numRemoved > 0 then
		Log.Info("Removed %d old recent searches", numRemoved)
	end

	private.db = Database.NewSchema("SHOPPING_SAVED_SEARCHES")
		:AddUniqueNumberField("index")
		:AddStringField("name")
		:AddBooleanField("isFavorite")
		:AddStringField("filter")
		:AddIndex("index")
		:AddIndex("name")
		:Commit()
	private.RebuildDB()
end

function SavedSearches.CreateRecentSearchesQuery()
	return private.db:NewQuery()
		:OrderBy("index", false)
end

function SavedSearches.CreateFavoriteSearchesQuery()
	return private.db:NewQuery()
		:Equal("isFavorite", true)
		:OrderBy("name", true)
end

function SavedSearches.SetSearchIsFavorite(index, isFavorite)
	private.db:SetUniqueRowField("index", index, "isFavorite", isFavorite)
	local filter = private.db:GetUniqueRowField("index", index, "filter")
	private.settings.savedShoppingSearches.isFavorite[filter] = isFavorite or nil
end

function SavedSearches.RenameSearch(index, newName)
	private.db:SetUniqueRowField("index", index, "name", newName)
	local filter = private.db:GetUniqueRowField("index", index, "filter")
	private.settings.savedShoppingSearches.name[filter] = newName ~= filter and newName or nil
end

function SavedSearches.DeleteSearch(index, filter)
	tremove(private.settings.savedShoppingSearches.filters, index)
	private.settings.savedShoppingSearches.name[filter] = nil
	private.settings.savedShoppingSearches.isFavorite[filter] = nil
	private.RebuildDB()
end

function SavedSearches.RecordFilterSearch(filter)
	for i, existingFilter in ipairs(private.settings.savedShoppingSearches.filters) do
		if strlower(existingFilter) == strlower(filter) then
			-- move this to the end of the list and rebuild the DB
			-- insert the existing filter so we don't need to update the isFavorite and name tables
			tremove(private.settings.savedShoppingSearches.filters, i)
			tinsert(private.settings.savedShoppingSearches.filters, existingFilter)
			private.RebuildDB()
			return
		end
	end

	-- didn't find an existing entry, so add a new one
	tinsert(private.settings.savedShoppingSearches.filters, filter)
	private.db:NewRow()
		:SetField("index", #private.settings.savedShoppingSearches.filters)
		:SetField("name", filter)
		:SetField("isFavorite", false)
		:SetField("filter", filter)
		:Create()
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.RebuildDB()
	private.db:TruncateAndBulkInsertStart()
	for index, filter in ipairs(private.settings.savedShoppingSearches.filters) do
		local name = private.settings.savedShoppingSearches.name[filter] or filter
		local isFavorite = private.settings.savedShoppingSearches.isFavorite[filter] and true or false
		private.db:BulkInsertNewRow(index, name, isFavorite, filter)
	end
	private.db:BulkInsertEnd()
end
