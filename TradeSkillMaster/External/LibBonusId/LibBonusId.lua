--- LibBonusId (https://github.com/TradeSkillMaster/LibBonusId)
--- This library provides API for accurately calculating item levels with bonus IDs taken into account.
--- LibBonusId is provided under the MIT license. See LICENSE.txt for more information.

local Lib = LibStub:NewLibrary("LibBonusId", 1) ---@class LibBonusId
if not Lib then return end
local private = {
	data = nil, ---@type BonusIdData
	squishMax = nil,
	bonusIdsTemp = {}, ---@type number[]
	bonusesTemp = {}, ---@type BonusEntry[]
	filterTemp = {}, ---@type number[]
}
local DATA_VERSION = 2
local OP_GROUP = { scale = "level", set = "level", add = "add" }
local DEFAULT_DROP_LEVEL = 80
local TREE_BONUS_ID = 3524

---@alias BonusIdCurve table<number,number>

---@alias BonusContentTuningOp {[1]: string, [2]: number, [3]: number?, [4]: number?}

---@class BonusContentTuning
---@field op BonusContentTuningOp?
---@field scalingConfig BonusContentTuningOp?
---@field scalingConfig2 BonusContentTuningOp?
---@field stat BonusContentTuningOp?

---@class BonusEntry
---@field op string
---@field amount number?
---@field itemLevel number?
---@field curveId number?
---@field offset number?
---@field defaultLevel number?
---@field contentTuningKey string?
---@field contentTuningId number?
---@field contentTuningDefaultOnly boolean?
---@field midnight string?
---@field extraAmount number?
---@field priority number?
---@field sortPriority number?
---@field indirect boolean?
---@field redirect number?

---@class BonusIdData
---@field version number
---@field build string
---@field squishMax number
---@field squishCurve BonusIdCurve
---@field bonuses table<number, BonusEntry>
---@field curves BonusIdCurve[]
---@field contentTuning table<number, BonusContentTuning>
---@field itemRangeStarts number[]
---@field itemRangeLevels number[]
---@field midnightItems table<number, boolean>
---@field tooltipBonuses table<number, boolean>
---@field treeBonusLists number[][]
---@field itemTreeBonuses table<number, number>
---@field levelToBonusString table<number, string>



-- ============================================================================
-- Lib Functions
-- ============================================================================

---@param version number
---@param build string
---@return boolean
---@private
function Lib.ShouldLoadData(version, build)
	if version ~= DATA_VERSION then
		return false
	elseif not private.data then
		return true
	end
	local patch, buildNum = GetBuildInfo()
	local currentBuild = patch.."."..buildNum
	if private.data.build == currentBuild then
		return false
	end
	return build == currentBuild
end

---@param data BonusIdData
---@private
function Lib.LoadData(data)
	assert(Lib.ShouldLoadData(data.version, data.build))
	private.data = data
end

---Returns a bonus string (partial item link format) that produces the given item level.
---@param itemLevel number The target item level
---@return string?
function Lib.GetBonusStringForLevel(itemLevel)
	return private.data.levelToBonusString[itemLevel]
end

---Filters a list of bonus IDs to only those that impact the calculated item level.
---@param bonusIds number[] The bonus IDs to filter
function Lib.FilterItemLevelBonusIds(bonusIds)
	for i = #bonusIds, 1, -1 do
		local bonusId = bonusIds[i]
		if bonusId ~= TREE_BONUS_ID and not private.data.bonuses[bonusId] then
			tremove(bonusIds, i)
		end
	end
end

---Removes TREE_BONUS_ID from the list if the item has no tree bonuses.
---@param bonusIds number[] The bonus IDs to filter
---@param itemId number The item ID
function Lib.FilterTreeBonusId(bonusIds, itemId)
	if not private.data.itemTreeBonuses[itemId] then
		for i = #bonusIds, 1, -1 do
			if tonumber(bonusIds[i]) == TREE_BONUS_ID then
				tremove(bonusIds, i)
			end
		end
	end
end

---Filters a list of bonus IDs to only those that have any effect (item level or tooltip).
---Removes bonus IDs that have no visible effect on the item whatsoever.
---@param bonusIds number[] The bonus IDs to filter
function Lib.FilterEffectiveBonusIds(bonusIds)
	for i = #bonusIds, 1, -1 do
		local bonusId = bonusIds[i]
		if bonusId ~= TREE_BONUS_ID and not private.data.bonuses[bonusId] and not private.data.tooltipBonuses[bonusId] then
			tremove(bonusIds, i)
		end
	end
end

---Calculates the item level for an item from its parsed link components.
---@param itemId number The item ID
---@param bonusIds number[] The bonus IDs applied to the item
---@param modifierDropLevel number? The drop level for the item (modifier 9)
---@param modifierContentTuningId number? The content tuning ID for the item (modifier 28)
---@return number
function Lib.CalculateItemLevelFromItemInfo(itemId, bonusIds, modifierDropLevel, modifierContentTuningId)
	assert(not next(private.bonusIdsTemp))
	for _, bonusId in ipairs(bonusIds) do
		tinsert(private.bonusIdsTemp, bonusId)
	end
	return private.Calculate(itemId, modifierDropLevel, modifierContentTuningId)
end

---Calculates the item level for an item from its link.
---@param link string The item link
---@return number
function Lib.CalculateItemLevelFromItemLink(link)
	assert(not next(private.bonusIdsTemp))
	local itemId, modifierDropLevel, modifierContentTuningId = private.ParseLink(link, private.bonusIdsTemp)
	return private.Calculate(itemId, modifierDropLevel, modifierContentTuningId)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.ParseLink(link, bonusIds)
	assert(#bonusIds == 0)
	local itemIdStr, bonusModiferStr = strmatch(link, "^\124cnIQ[0-9]:\124Hitem:(%d+):%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:%d*:(.+)\124h%[.+%]\124h\124r$")
	if not bonusModiferStr then
		return nil, nil, nil
	end
	local itemId = tonumber(itemIdStr)
	local dropLevel, contentTuningId = nil, nil
	local numBonusIds, numModifiers, modifierOffset, currentModifierType = nil, nil, nil, nil
	for part in gmatch(bonusModiferStr, "(%d*):") do
		part = tonumber(part)
		if not numBonusIds then
			numBonusIds = part or 0
		elseif #bonusIds < numBonusIds then
			if not part then
				return nil, nil, nil
			end
			tinsert(bonusIds, part)
		elseif not numModifiers then
			numModifiers = part or 0
			modifierOffset = 0
		elseif modifierOffset < numModifiers * 2 then
			if not part then
				return nil, nil, nil
			end
			if modifierOffset % 2 == 0 then
				currentModifierType = part
			else
				assert(currentModifierType)
				if currentModifierType == 9 and part ~= 0 then
					dropLevel = part
				elseif currentModifierType == 28 and part ~= 0 then
					contentTuningId = part
				end
				currentModifierType = nil
			end
			modifierOffset = modifierOffset + 1
		else
			break
		end
	end
	return itemId, dropLevel, contentTuningId
end

function private.Calculate(itemId, modifierDropLevel, modifierContentTuningId)
	local itemLevel = private.GetItemLevel(itemId)
	local hasMidnightScaling = private.data.midnightItems[itemId] or false
	private.ResolveBonusIds(private.bonusIdsTemp, itemId)

	-- Collect indirect first, then direct (direct overrides via dedup)
	assert(not next(private.bonusesTemp))
	for _, bonusId in ipairs(private.bonusIdsTemp) do
		local bonus = private.data.bonuses[bonusId]
		if bonus and not bonus.redirect then
			if bonus.indirect then
				private.CollectBonus(bonus)
			end
			hasMidnightScaling = hasMidnightScaling or bonus.midnight == "set"
		end
	end
	for _, bonusId in ipairs(private.bonusIdsTemp) do
		local bonus = private.data.bonuses[bonusId]
		if bonus and not bonus.redirect and not bonus.indirect then
			private.CollectBonus(bonus)
		end
	end
	wipe(private.bonusIdsTemp)

	if #private.bonusesTemp == 0 then
		if not hasMidnightScaling then
			itemLevel = private.GetSquishValue(itemLevel)
		end
		return itemLevel
	end

	for _, bonus in ipairs(private.bonusesTemp) do
		local midnightOp = bonus.midnight
		local op = bonus.op
		if op == "legacyAdd" then
			itemLevel = itemLevel + bonus.amount
		elseif op == "add" then
			if midnightOp == "force" and not hasMidnightScaling then
				hasMidnightScaling = true
				itemLevel = private.GetSquishValue(itemLevel)
			end
			itemLevel = itemLevel + bonus.amount
		elseif op == "set" then
			itemLevel = bonus.itemLevel
			assert(itemLevel)
		elseif op == "scale" then
			local dropLevel = bonus.defaultLevel or modifierDropLevel or DEFAULT_DROP_LEVEL
			if not bonus.defaultLevel and bonus.contentTuningKey and (not bonus.contentTuningDefaultOnly or not modifierDropLevel) then
				local contentTuningId = modifierContentTuningId or bonus.contentTuningId
				dropLevel = private.ApplyContentTuning(dropLevel, contentTuningId, bonus.contentTuningKey)
			end
			itemLevel = private.GetCurveValue(bonus.curveId, dropLevel) + (bonus.offset or 0)
		else
			error("Unknown bonus op: "..tostring(op))
		end

		if bonus.extraAmount then
			itemLevel = itemLevel + bonus.extraAmount
		end

		-- Post-op midnight handling
		if midnightOp == "set" then
			hasMidnightScaling = true
		elseif midnightOp == "squish" and hasMidnightScaling then
			itemLevel = private.GetSquishValue(itemLevel)
		end
	end
	wipe(private.bonusesTemp)

	itemLevel = max(itemLevel, 1)
	if not hasMidnightScaling then
		itemLevel = private.GetSquishValue(itemLevel)
	end
	return itemLevel
end

function private.GetItemLevel(itemId)
	local starts = private.data.itemRangeStarts
	local low, high = 1, #starts
	while low <= high do
		local mid = floor((low + high) / 2)
		if starts[mid] <= itemId then
			low = mid + 1
		else
			high = mid - 1
		end
	end
	if high >= 1 then
		return private.data.itemRangeLevels[high]
	end
	return 0
end

function private.ResolveBonusIds(ids, itemId)
	-- Expand bonus 3524 into the item's tree bonus IDs
	for i = #ids, 1, -1 do
		if ids[i] == TREE_BONUS_ID then
			local listIndex = private.data.itemTreeBonuses[itemId]
			tremove(ids, i)
			if listIndex then
				local treeBonuses = private.data.treeBonusLists[listIndex]
				for j = #treeBonuses, 1, -1 do
					tinsert(ids, i, treeBonuses[j])
				end
			end
		end
	end
	-- Follow simple redirects
	for i, id in ipairs(ids) do
		local bonus = private.data.bonuses[id]
		if bonus and bonus.redirect then
			ids[i] = bonus.redirect
		end
	end
	sort(ids, private.SortBonusIds)
	return ids
end

function private.SortBonusIds(a, b)
	local bonusA = private.data.bonuses[a]
	local bonusB = private.data.bonuses[b]
	local priorityA = bonusA and bonusA.sortPriority or 0
	local priorityB = bonusB and bonusB.sortPriority or 0
	if priorityA ~= priorityB then
		return priorityA < priorityB
	end
	return a < b
end

---@param bonus BonusEntry
function private.CollectBonus(bonus)
	local group = OP_GROUP[bonus.op]
	if not group then
		tinsert(private.bonusesTemp, bonus)
		return
	end

	local prevIndex = private.bonusesTemp[group]
	if not prevIndex then
		tinsert(private.bonusesTemp, bonus)
		private.bonusesTemp[group] = #private.bonusesTemp
		return
	end

	-- This new bonus overrides the previous one if it's higher priority (lower value)
	-- or just if it comes afterwards and there's no priority set
	local prevPriority = private.bonusesTemp[prevIndex].priority
	local newPriority = bonus.priority
	if not prevPriority or not newPriority or newPriority <= prevPriority then
		private.bonusesTemp[prevIndex] = bonus
	end
end

function private.ApplyContentTuning(dropLevel, contentTuningId, contentTuningKey)
	local contentTuning = private.data.contentTuning[contentTuningId]
	local op = contentTuning and (contentTuning[contentTuningKey] or contentTuning.op)
	if not op then
		return dropLevel
	end
	local name = op[1]
	if name == "cap" then
		return min(dropLevel, op[2])
	elseif name == "clamp" then
		return min(max(dropLevel, op[2]), op[3])
	elseif name == "const" then
		return op[2]
	elseif name == "capAdd" then
		return min(dropLevel, op[2]) + op[3]
	elseif name == "capAddFloor" then
		return max(min(dropLevel, op[2]) + op[3], op[4])
	else
		error("Unknown content tuning op: "..name)
	end
end

function private.GetSquishValue(value)
	if value > private.data.squishMax then
		return 1
	end
	return private.Interpolate(private.data.squishCurve, value)
end

function private.GetCurveValue(curveId, value)
	return private.Interpolate(private.data.curves[curveId + 1], value)
end

---@param curve BonusIdCurve
function private.Interpolate(curve, value)
	local lowerBound, upperBound = -math.huge, math.huge
	for level, itemLevel in pairs(curve) do
		if level == value then
			return floor(itemLevel + 0.5)
		elseif level < value then
			lowerBound = max(lowerBound, level)
		else
			upperBound = min(upperBound, level)
		end
	end
	if lowerBound == -math.huge then
		return floor(curve[upperBound] + 0.5)
	elseif upperBound == math.huge then
		return floor(curve[lowerBound] + 0.5)
	end
	return floor(curve[lowerBound] + (value - lowerBound) / (upperBound - lowerBound) * (curve[upperBound] - curve[lowerBound]) + 0.5)
end
