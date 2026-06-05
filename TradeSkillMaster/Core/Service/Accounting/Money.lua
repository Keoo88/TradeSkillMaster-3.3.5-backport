-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...) ---@type TSM
local Money = TSM.Accounting:NewPackage("Money") ---@type AddonPackage
local Database = TSM.LibTSMUtil:Include("Database")
local CSV = TSM.LibTSMUtil:Include("Format.CSV")
local Log = TSM.LibTSMUtil:Include("Util.Log")
local SessionInfo = TSM.LibTSMWoW:Include("Util.SessionInfo")
local private = {
	settings = nil,
	db = nil,
	dataChanged = false,
}
local CSV_KEYS = { "type", "amount", "otherPlayer", "player", "time" }
local COMBINE_TIME_THRESHOLD = 300 -- Group expenses within 5 minutes together
local SECONDS_PER_DAY = 24 * 60 * 60



-- ============================================================================
-- Module Functions
-- ============================================================================

function Money.OnInitialize(settingsDB)
	private.settings = settingsDB:NewView()
		:AddKey("realm", "internalData", "csvExpense")
		:AddKey("realm", "internalData", "csvIncome")
		:AddKey("global", "coreOptions", "regionWide")
	private.db = Database.NewSchema("ACCOUNTING_MONEY")
		:AddStringField("recordType")
		:AddStringField("type")
		:AddNumberField("amount")
		:AddStringField("otherPlayer")
		:AddStringField("player")
		:AddNumberField("time")
		:AddBooleanField("isCurrentRealm")
		:AddIndex("recordType")
		:Commit()
	private.db:BulkInsertStart()
	for _, csvExpense, realm in private.settings:AccessibleValueIterator("csvExpense") do
		private.LoadData("expense", csvExpense, realm == SessionInfo.GetRealmName())
	end
	for _, csvIncome, realm in private.settings:AccessibleValueIterator("csvIncome") do
		private.LoadData("income", csvIncome, realm == SessionInfo.GetRealmName())
	end
	private.db:BulkInsertEnd()
end

function Money.OnDisable()
	if not private.dataChanged then
		-- Nothing changed, so just keep the previous saved values
		return
	end
	private.settings.csvExpense = private.SaveData("expense")
	private.settings.csvIncome = private.SaveData("income")
end

function Money.InsertMoneyTransferExpense(amount, destination)
	private.InsertRecord("expense", "Money Transfer", amount, destination, time())
end

function Money.InsertPostageExpense(amount, destination)
	private.InsertRecord("expense", "Postage", amount, destination, time())
end

function Money.InsertRepairBillExpense(amount)
	private.InsertRecord("expense", "Repair Bill", amount, "Merchant", time())
end

function Money.InsertMoneyTransferIncome(amount, source, timestamp)
	private.InsertRecord("income", "Money Transfer", amount, source, timestamp)
end

function Money.InsertGarrisonIncome(amount)
	private.InsertRecord("income", "Garrison", amount, "Mission", time())
end

function Money.InsertCraftingOrderExpense(amount, seller, timestamp)
	private.InsertRecord("expense", "Crafting Order", amount, seller, timestamp)
end

function Money.InsertCraftingOrderIncome(amount, buyer, timestamp)
	private.InsertRecord("income", "Crafting Order", amount, buyer, timestamp)
end

function Money.CreateQuery()
	return private.db:NewQuery()
end

function Money.CharacterIterator(recordType)
	return private.db:NewQuery()
		:Equal("recordType", recordType)
		:Distinct("player")
		:Select("player")
		:IteratorAndRelease()
end

function Money.RemoveOldData(days)
	private.dataChanged = true
	local query = private.db:NewQuery()
		:LessThan("time", time() - days * SECONDS_PER_DAY)
		:Equal("isCurrentRealm", true)
	local numRecords = 0
	private.db:SetQueryUpdatesPaused(true)
	for _, row in query:Iterator() do
		private.db:DeleteRow(row)
		numRecords = numRecords + 1
	end
	query:Release()
	private.db:SetQueryUpdatesPaused(false)
	return numRecords
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.LoadData(recordType, csvRecords, isCurrentRealm)
	local decodeContext = CSV.DecodeStart(csvRecords, CSV_KEYS)
	if not decodeContext then
		if isCurrentRealm then
			Log.Err("Failed to decode %s records (%d)", recordType, #csvRecords)
		end
		private.dataChanged = isCurrentRealm
		return
	end

	for type, amount, otherPlayer, player, timestamp in CSV.DecodeIterator(decodeContext) do
		amount = tonumber(amount)
		timestamp = tonumber(timestamp)
		if amount and timestamp then
			local newTimestamp = floor(timestamp)
			if newTimestamp ~= timestamp then
				-- Make sure all timestamps are stored as integers
				timestamp = newTimestamp
				private.dataChanged = isCurrentRealm
			end
			private.db:BulkInsertNewRowFast7(recordType, type, amount, otherPlayer, player, timestamp, isCurrentRealm)
		else
			private.dataChanged = isCurrentRealm
		end
	end

	if not CSV.DecodeEnd(decodeContext) then
		if isCurrentRealm then
			Log.Err("Failed to decode %s records", recordType)
		end
		private.dataChanged = isCurrentRealm
	end
end

function private.SaveData(recordType)
	local query = private.db:NewQuery()
		:Equal("recordType", recordType)
		:Equal("isCurrentRealm", true)
	local encodeContext = CSV.EncodeStart(CSV_KEYS)
	for _, row in query:Iterator() do
		CSV.EncodeAddRowData(encodeContext, row)
	end
	query:Release()
	return CSV.EncodeEnd(encodeContext)
end

function private.InsertRecord(recordType, type, amount, otherPlayer, timestamp)
	private.dataChanged = true
	assert(type and amount and amount > 0 and otherPlayer and timestamp)
	timestamp = floor(timestamp)
	local matchingRow = private.db:NewQuery()
		:Equal("recordType", recordType)
		:Equal("type", type)
		:Equal("otherPlayer", otherPlayer)
		:Equal("player", UnitName("player"))
		:GreaterThan("time", timestamp - COMBINE_TIME_THRESHOLD)
		:LessThan("time", timestamp + COMBINE_TIME_THRESHOLD)
		:Equal("isCurrentRealm", true)
		:GetFirstResultAndRelease()
	if matchingRow then
		matchingRow:SetField("amount", matchingRow:GetField("amount") + amount)
		matchingRow:Update()
		matchingRow:Release()
	else
		private.db:NewRow()
			:SetField("recordType", recordType)
			:SetField("type", type)
			:SetField("amount", amount)
			:SetField("otherPlayer", otherPlayer)
			:SetField("player", UnitName("player"))
			:SetField("time", timestamp)
			:SetField("isCurrentRealm", true)
			:Create()
	end
end
