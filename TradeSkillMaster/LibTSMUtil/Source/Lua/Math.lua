-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                          https://tradeskillmaster.com                          --
--    All Rights Reserved - Detailed license information included with addon.     --
-- ------------------------------------------------------------------------------ --

local LibTSMUtil = select(2, ...).LibTSMUtil
local Math = LibTSMUtil:Init("Lua.Math")
local NAN = math.huge * 0
local IS_NAN_GT_INF = (NAN or 0) > math.huge
local NAN_STR = tostring(NAN)



-- ============================================================================
-- Module Functions
-- ============================================================================

---Returns NAN.
---@return number
function Math.GetNan()
	assert(NAN)
	return NAN
end

---Checks if a value is NAN.
---@param value number The number to check
---@return boolean @Whether or not the value is NAN
function Math.IsNan(value)
	if not NAN then
		error("NAN not set")
	end
	if IS_NAN_GT_INF then
		-- Optimization if NAN > math.huge (which it is in Wow's version of lua)
		return value > math.huge and tostring(value) == NAN_STR
	else
		return tostring(value) == NAN_STR
	end
end

---Rounds a value to a specified significant value.
---@param value number The number to be rounded
---@param sig? number The value to round to the nearest multiple of (defaults to 1)
---@return number
function Math.Round(value, sig)
	sig = sig or 1
	return floor((value / sig) + 0.5) * sig
end

---Rounds a value down to a specified significant value.
---@param value number The number to be rounded
---@param sig? number The value to round down to the nearest multiple of (defaults to 1)
---@return number
function Math.Floor(value, sig)
	sig = sig or 1
	return floor(value / sig) * sig
end

---Rounds a value up to a specified significant value.
---@param value number The number to be rounded
---@param sig? number The value to round up to the nearest multiple of (defaults to 1)
---@return number
function Math.Ceil(value, sig)
	sig = sig or 1
	return ceil(value / sig) * sig
end

---Scales a value from one range to another.
---@param value number The number to be scaled
---@param fromStart number The start value of the range to scale from
---@param fromEnd number The end value of the range to scale from (can be less than fromStart)
---@param toStart number The start value of the range to scale to
---@param toEnd number The end value of the range to scale to (can be less than toStart)
---@return number
function Math.Scale(value, fromStart, fromEnd, toStart, toEnd)
	assert(value >= min(fromStart, fromEnd) and value <= max(fromStart, fromEnd))
	return toStart + ((value - fromStart) / (fromEnd - fromStart)) * (toEnd - toStart)
end

---Bounds a number between a min and max value.
---@param value number The number to be bounded
---@param minValue number The min value
---@param maxValue number The max value
---@return number
function Math.Bound(value, minValue, maxValue)
	return min(max(value, minValue), maxValue)
end
