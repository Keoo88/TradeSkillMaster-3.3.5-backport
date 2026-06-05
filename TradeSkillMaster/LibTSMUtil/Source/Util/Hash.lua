-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Hash = LibTSMUtil:Init("Util.Hash")
local TempTable = LibTSMUtil:Include("BaseType.TempTable")
local private = {
	keysTemp = {},
}



-- ============================================================================
-- Module Functions
-- ============================================================================

---Calculates the hash of the specified data.
---
-- This can handle data of type string or number. It can also handle a table being passed as the data assuming all
-- keys and values of the table are also hashable (strings, numbers, or tables with the same restriction). This
-- function uses the [djb2 algorithm](http://www.cse.yorku.ca/~oz/hash.html).
---@param data any The data to be hased
---@param hash? number The initial value of the hash
---@return number
function Hash.Calculate(data, hash)
	hash = hash or 5381
	local maxValue = 2 ^ 24
	local dataType = type(data)
	if dataType == "string" then
		-- iterate through 8 bytes at a time
		for i = 1, ceil(strlenutf8(data) / 8) do
			local b1, b2, b3, b4, b5, b6, b7, b8 = strbyte(data, (i - 1) * 8 + 1, i * 8)
			hash = (hash * 33 + b1) % maxValue
			if not b2 then break end
			hash = (hash * 33 + b2) % maxValue
			if not b3 then break end
			hash = (hash * 33 + b3) % maxValue
			if not b4 then break end
			hash = (hash * 33 + b4) % maxValue
			if not b5 then break end
			hash = (hash * 33 + b5) % maxValue
			if not b6 then break end
			hash = (hash * 33 + b6) % maxValue
			if not b7 then break end
			hash = (hash * 33 + b7) % maxValue
			if not b8 then break end
			hash = (hash * 33 + b8) % maxValue
		end
	elseif dataType == "number" then
		assert(data == floor(data), "Invalid number")
		if data < 0 then
			data = data * -1
			hash = (hash * 33 + 59) % maxValue
		end
		while data > 0 do
			hash = (hash * 33 + data % 256) % maxValue
			data = floor(data / 256)
		end
	elseif dataType == "table" then
		local keys = nil
		if private.keysTemp.inUse then
			keys = TempTable.Acquire()
		else
			keys = private.keysTemp
			private.keysTemp.inUse = true
		end
		for k in pairs(data) do
			tinsert(keys, k)
		end
		sort(keys)
		for _, key in ipairs(keys) do
			hash = Hash.Calculate(key, hash)
			hash = Hash.Calculate(data[key], hash)
		end
		if keys == private.keysTemp then
			wipe(private.keysTemp)
		else
			TempTable.Release(keys)
		end
	elseif dataType == "boolean" then
		hash = (hash * 33 + (data and 1 or 0)) % maxValue
	elseif dataType == "nil" then
		hash = (hash * 33 + 17) % maxValue
	else
		error("Invalid data")
	end
	return hash
end
