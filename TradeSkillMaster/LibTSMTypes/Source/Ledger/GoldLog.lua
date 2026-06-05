-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMTypes = select(2, ...).LibTSMTypes
local GoldLog = LibTSMTypes:DefineClassType("GoldLog")
local CSV = LibTSMTypes:From("LibTSMUtil"):Include("Format.CSV")
local BinarySearch = LibTSMTypes:From("LibTSMUtil"):Include("Util.BinarySearch")
local private = {}
local CSV_KEYS = { "minute", "copper" }
local COPPER_PER_GOLD = 100 * 100
local MAX_COPPER_VALUE = 10 * 1000 * 1000 * COPPER_PER_GOLD
local ERRONEOUS_ZERO_THRESHOLD = 5 * 1000 * COPPER_PER_GOLD



-- ============================================================================
-- Static Class Functions
-- ============================================================================

---Loads a gold log from the serialized string.
---@param data string The serialized string
---@return GoldLog?
function GoldLog.__static.Load(data)
	local minutes, values = private.Decode(data)
	if not minutes then
		return nil
	end
	return GoldLog(minutes, values)
end

---Creates a new empty gold log.
---@return GoldLog
function GoldLog.__static.New()
	return GoldLog({}, {})
end



-- ============================================================================
-- Meta Class Methods
-- ============================================================================

function GoldLog.__private:__init(minutes, values)
	self._minutes = minutes
	self._values = values
	self._startMinute = self._minutes[1] or nil
	self._endMinute = self._minutes[#self._minutes] or nil
end



-- ============================================================================
-- Public Class Methods
-- ============================================================================

-- Clean up any erroneous 0 entries, entries which are too high, and duplicate entries
function GoldLog:Clean()
	local didChange = true
	while didChange do
		didChange = false
		for i = #self._minutes - 1, 2, -1 do
			local prevValue = self._values[i - 1]
			local value = self._values[i]
			local nextValue = self._values[i + 1]
			if prevValue > ERRONEOUS_ZERO_THRESHOLD and value == 0 and nextValue > ERRONEOUS_ZERO_THRESHOLD then
				-- This is likely an erroneous 0 value
				didChange = true
				tremove(self._minutes, i)
				tremove(self._values, i)
			end
		end
		for i = #self._minutes, 2, -1 do
			local prevValue = self._values[i - 1]
			local value = self._values[i]
			if prevValue == value or value > MAX_COPPER_VALUE then
				-- This is either a duplicate or invalid value
				didChange = true
				tremove(self._minutes, i)
				tremove(self._values, i)
			end
		end
	end
	local numRows = #self._minutes
	if numRows > 0 then
		self._startMinute = self._minutes[1]
		self._endMinute = self._minutes[numRows]
	else
		self._startMinute = nil
		self._endMinute = nil
	end
end

---Gets the value at the specified minute.
---@param minute number The minute to get the value at
---@return number
function GoldLog:GetValue(minute)
	if (self._startMinute or math.huge) > minute then
		-- Specified time is before we had any data
		return 0
	elseif minute > (self._endMinute or math.huge) then
		-- Specified time is after the last data point
		return self._values[#self._values]
	end
	local index, insertIndex = BinarySearch.Table(self._minutes, minute)
	-- If we didn't find an exact match, the index is the previous one (compared to the insert index)
	-- as that point's gold value is true up until the next point
	index = index or (insertIndex - 1)
	return self._values[index]
end

---Gets the first minute included in the log.
---@return number?
function GoldLog:GetStartMinute()
	return self._startMinute
end

---Gets the last minute included in the log.
---@return number?
function GoldLog:GetEndMinute()
	return self._endMinute
end

---Appends a new entry to the gold log, combining it with the last one as applicable.
---@param minute number The minute
---@param copper number The copper value
function GoldLog:Append(minute, copper)
	local prevRowIndex = #self._minutes
	local isFirstRow = prevRowIndex == 0
	if prevRowIndex > 0 and copper == self._values[prevRowIndex] then
		-- Amount of gold hasn't changed, so nothing to do
	elseif prevRowIndex > 0 and minute == self._minutes[prevRowIndex] then
		-- Gold has changed and the previous record is for the current minute so just modify it
		self._values[prevRowIndex] = copper
	else
		-- Amount of gold changed and we're in a new minute, so insert a new record
		while prevRowIndex > 0 and self._minutes[prevRowIndex] > minute - 1 do
			-- The clock may have changed - just delete everything that's too recent
			tremove(self._minutes, prevRowIndex)
			tremove(self._values, prevRowIndex)
			prevRowIndex = #self._minutes
		end
		tinsert(self._minutes, minute)
		tinsert(self._values, copper)
		if isFirstRow then
			self._startMinute = minute
		end
		self._endMinute = self._minutes[#self._minutes]
	end
end

---Serializes the gold log so it can be saved.
---@return string
function GoldLog:Serialize()
	local context = CSV.EncodeStart(CSV_KEYS)
	for i = 1, #self._minutes do
		CSV.EncodeAddRowDataRaw(context, self._minutes[i], self._values[i])
	end
	return CSV.EncodeEnd(context)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.Decode(data)
	-- Extract to a list
	local decodeContext = CSV.DecodeStart(data, CSV_KEYS)
	if not decodeContext then
		return nil, nil
	end
	local minutes = {}
	local values = {}
	for minute, copper in CSV.DecodeIterator(decodeContext) do
		tinsert(minutes, tonumber(minute))
		tinsert(values, tonumber(copper))
	end
	CSV.DecodeEnd(decodeContext)
	return minutes, values
end
